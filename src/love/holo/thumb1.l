; thumb1 -- the armv6-M (Cortex-M0/M0+, RP2040) backend for holo: 16-bit Thumb-1, not thumb2.l's
; wide Thumb-2. most ops are two-address on r0..r7; r8..r15 only by MOV/ADD/CMP-hi, BX/BLX, push lr/pop pc.
; what v6-M lacks:
;   * MOVW/MOVT  -> li byte-builds the constant (MOVS + LSLS/ADDS); la loads from a literal pool
;   * sdiv/udiv  -> div/rem expand inline to a restoring shift-subtract loop owning r0..r3
;   * it blocks  -> set is a branch-over
;   * wide ALU   -> logicals and mul are two-address (mov-first when d != a)
;   * range      -> B +-2KB, Bcc +-256B; label branches go wide through BL (+-16MB)
;   * mem        -> imm5 unsigned offsets; others take a far lane. signed loads are unsigned + sxtb/sxth
; every instruction is one le16 halfword except BL (two, hi first).

(module 'holo
(: t1-regs {'sp 13 'lr 14 'pc 15 'fp 7    ; fp=r7, a low reg so slot loads reach it by imm5
            'r0 0 'r1 1 'r2 2 'r3 3  'r4 4
            'r5 5 'r6 6 'r7 7 'r8 8  'r9 9
            'r10 10 'r11 11 'r12 12}
   (rn r) (look t1-regs r 'badreg)
   (reg-eq a b) (rn a = rn b)
   (lo? r) (rn r <= 7)
   (need-lo r why) (lo? r ? 0 (scare why r))

   (ccn c) (look arm-cc c 'badcc)

   (t16 w) (le16 (w & 65535))

   (t1-movs d imm8) (: _ (need-lo d 'movs-hi) dn (rn d) (t16 (0x2000 | (dn << 8 | imm8 & 255))))
   (t1-mvns d s)    (: dn (rn d) sn (rn s) (t16 (0x43C0 | (sn << 3 | dn))))         ; mvns Rd, Rm  (Rd = ~Rm)
   (t1-lsls-imm d c) (rn d @ dn (t16 (0x0000 | ((c & 31) << 6 | (dn << 3 | dn)))))
   (t1-lsls-rri d m c) (: dn (rn d) mn (rn m) (t16 (0x0000 | ((c & 31) << 6 | (mn << 3 | dn)))))
   (t1-adds-i8 d imm8) (: _ (need-lo d 'adds-hi) dn (rn d) (t16 (0x3000 | (dn << 8 | imm8 & 255))))
   ;; MOVS the top byte, then LSLS 8; ADDS byte down the word: 7 halfwords
   (t1-li-synth d u)
      (catall [(t1-movs d (u >> 24 & 255))
               (t1-lsls-imm d 8) (t1-adds-i8 d (u >> 16 & 255))
               (t1-lsls-imm d 8) (t1-adds-i8 d (u >> 8 & 255))
               (t1-lsls-imm d 8) (t1-adds-i8 d (u & 255))])
   (t1-li d imm)
      (: u (imm < 0 ? (imm + 4294967296) imm)
         (? (u <= 255) (t1-movs d u)
            (-256 <= imm < 0)                          ; small negative: MOVS ~imm ; mvns
               (t1-movs d (-imm - 1 & 255) + t1-mvns d d)
            (t1-li-synth d u)))

   ;; MOV (register) hi-form: any of r0..r15, sp included, no flags
   (t1-movr d s) (: dn (rn d) sn (rn s) (t16 (0x4600 | ((dn >> 3 & 1) << 7 | (sn << 3 | dn & 7)))))
   ;; ADD Rdn,Rm hi-form: two-address, any register, no flags
   (t1-add-any d m) (: dn (rn d) mn (rn m) (t16 (0x4400 | ((dn >> 3 & 1) << 7 | (mn << 3 | dn & 7)))))

   (t1-add-rrr d a b) (: dn (rn d) an (rn a) bn (rn b) (t16 (0x1800 | (bn << 6 | (an << 3 | dn)))))
   (t1-sub-rrr d a b) (: dn (rn d) an (rn a) bn (rn b) (t16 (0x1A00 | (bn << 6 | (an << 3 | dn)))))
   (t1-addsub op d a b) (reg? b ? (op @ 'add (t1-add-rrr d a b) (t1-sub-rrr d a b))
                            (t1-addsub-imm op d a b))
   ;; #imm3 3-address, #imm8 two-address, else via a scratch. negative flips the op
   (t1-addsub-imm op d a imm)
      (: pos (abs imm)
         fop (imm < 0 ? (op @ 'add 'sub 'sub 'add op) op)
         dn (rn d) an (rn a)
         (? (dn = 13 && an = 13)                       ; ADD/SUB SP,SP,#imm7*4, the only sp arith:
               (: _ (0 = pos & 3 ? 0 (scare 'sp-adj-align imm))   ; a big frame chunks by 508
                  (chunks p acc)
                   (p <= 0 ? acc
                      (: c (508 < p ? 508 p)
                         (chunks (p - c) (acc + t16 ((fop @ 'add 0xB000 0xB080) | c >> 2)))))
                  (chunks pos ()))
            (pos <= 7) (t16 ((fop @ 'add 0x1C00 0x1E00) | (pos << 6 | (an << 3 | dn))))
            (pos <= 255) ((dn = an ? () (t1-movr d a))
                          + t16 ((fop @ 'add 0x3000 0x3800) | (dn << 8 | pos)))
            ; ADDS/SUBS set flags anyway, so t1-li's flag writes cost nothing
            (: _ (need-lo d 'addsub-far-hi) _ (need-lo a 'addsub-far-hi)
               s (t1-lowscratch d a '(r0 r1 r2 r3 r4 r5 r6 r7))
               (catall [(t1-push s) (t1-li s pos)
                        ((fop = 'add ? t1-add-rrr t1-sub-rrr) d a s) (t1-pop s)]))))
   ;; format-4 Rd = Rd OP Rm; all commute, so d==b swaps the operands
   t1-f4 {'and 0x4000 'or 0x4300 'xor 0x4040 'imul 0x4340}
   (t1-alu2 op d a b)
      (: base (peep t1-f4 op 0)
         dn (rn d)
         (? (reg-eq d a) (t16 (base | (rn b << 3 | dn)))
            (reg-eq d b) (t16 (base | (rn a << 3 | dn)))
            (t1-movr d a + t16 (base | (rn b << 3 | dn)))))
   ;; adcs/sbcs Rdn,Rm: MOV hi-form keeps the carry. sbcs with d==b borrows a saved low scratch
   ;; (push/pop keep flags)
   (t1-adc d a b)
      (rn d @ dn
         (? (reg-eq d a) (t16 (0x4140 | (rn b << 3 | dn)))
            (reg-eq d b) (t16 (0x4140 | (rn a << 3 | dn)))
            (t1-movr d a + t16 (0x4140 | (rn b << 3 | dn)))))
   (t1-sbc d a b)
      (rn d @ dn
         (? (reg-eq d a) (t16 (0x4180 | (rn b << 3 | dn)))
            (reg-eq d b)
             (t1-lowscratch d a '(r0 r1 r2 r3 r4 r5 r6 r7) @ s
                (catall [(t1-push s) (t1-movr s b) (t1-movr d a)
                         (t16 (0x4180 | (rn s << 3 | rn d))) (t1-pop s)]))
            (t1-movr d a + t16 (0x4180 | (rn b << 3 | dn)))))

   (t1-cmp a b)
      (reg? b ?
         (: an (rn a) bn (rn b)
            (an <= 7 && bn <= 7 ?
             (t16 (0x4280 | (bn << 3 | an)))
             (t16 (0x4500 | ((an >> 3 & 1) << 7 | (bn << 3 | an & 7))))))    ; hi form
         (b < 0 ? (scare 'cmp-neg-imm b), ; CMN is register-only
          b > 255 ? (scare 'cmp-imm-range b),
          need-lo a 'cmp-hi-imm,
          t16 (0x2800 | (rn a << 8 | b))))

   (t1-test a b)                                           ; tst is register-only
      (reg? b ? (: an (rn a) bn (rn b) (t16 (0x4200 | (bn << 3 | an))))
         (scare 'test-imm ['test a b]))

   ;; offsets: word imm5*4, half imm5*2, byte imm5; sp-relative imm8*4.
   ;; past reach, or a hi register: base+off into a register, then [Rn,#0] -- a low load dest distinct
   ;; from base builds it in place, else a saved low scratch. t1-li sets flags: sound only because a
   ;; mem op never sits between a cmp and its consumer
   (t1-mem-far base16 sh d base off ldq)
      (: (op1 rd rb) (t16 (base16 | (rn rb << 3 | rn rd)))
         (ldq && lo? d && !(reg-eq d base) ?
            (catall [(t1-li d off) (t1-add-any d base) (op1 d d)])
            (: s (t1-lowscratch d base '(r0 r1 r2 r3 r4 r5 r6 r7))
               o (reg-eq base 'sp ? (off + 4) off)          ; the push has moved sp a word down
               (ldq ?
                  (catall [(t1-push s) (t1-li s o) (t1-add-any s base) (op1 s s) (t1-movr d s) (t1-pop s)])
                  (need-lo d 'st-src-hi,
                   catall [(t1-push s) (t1-li s o) (t1-add-any s base) (op1 d s) (t1-pop s)])))))
   ;; base16 the [Rn,#imm5] op, sp16 the [sp,#imm8*4] op, or () where there is no sp form
   (t1-mem base16 sp16 sh d base off ldq)
      (rn d @ dn
         (reg-eq base 'sp && sp16 ?
            (off >= 0 && 0 = off & 3 && off >> 2 <= 255 ? 0 (scare 'mem-sp-range off), need-lo d 'mem-sp-hi,
             t16 (sp16 | (dn << 8 | off >> 2)))
            (: u (off >> sh)
               ok (lo? d && lo? base &&
                   off >= 0 && 0 = off & (1 << sh) - 1 && u <= 31)
               (ok ? (t16 (base16 | (u << 6 | (rn base << 3 | dn))))
                  (t1-mem-far base16 sh d base off ldq)))))
   (t1-ld  d base off) (t1-mem 0x6800 0x9800 2 d base off 1)
   (t1-st  base off s) (t1-mem 0x6000 0x9000 2 s base off ())
   ;; the byte and half rows have no sp form: sp rides the far lane
   (t1-ldb d base off) (t1-mem 0x7800 () 0 d base off 1)
   (t1-stb base off s) (t1-mem 0x7000 () 0 s base off ())
   (t1-ldh d base off) (t1-mem 0x8800 () 1 d base off 1)
   (t1-sth base off s) (t1-mem 0x8000 () 1 s base off ())
   (t1-sxb d) (rn d @ dn (t16 (0xB240 | (dn << 3 | dn))))
   (t1-sxh d) (rn d @ dn (t16 (0xB200 | (dn << 3 | dn))))
   (t1-uxb d) (rn d @ dn (t16 (0xB2C0 | (dn << 3 | dn))))
   (t1-uxh d) (rn d @ dn (t16 (0xB280 | (dn << 3 | dn))))
   (t1-lds1 d base off) (t1-ldb d base off + t1-sxb d)
   (t1-lds2 d base off) (t1-ldh d base off + t1-sxh d)

   ;; d <- base + index*scale (+disp) by LSLS+ADDS. d may alias base or index; shifting into d
   ;; would clobber a base in d, so that case borrows a saved low scratch
   (t1-lg2 scale) (scale @ 2 1 4 2 8 3 1 0 (scare 'badscale scale))
   (t1-lowscratch a b lst)                                ; first low reg not aliasing a or b
      (!lst ? (scare 'no-scratch [a b])
         (<lst @ r (reg-eq r a || reg-eq r b ? (t1-lowscratch a b >lst) r)))
   (t1-eaddr d base index scale)
      (t1-lg2 scale @ k
         (? (scale = 1) (t1-add-rrr d base index)
            !(reg-eq d base) (t1-lsls-rri d index k + t1-add-rrr d base d)
            (: s (t1-lowscratch d index '(r0 r1 r2 r3 r4 r5 r6 r7))
               (catall [(t1-push s) (t1-lsls-rri s index k) (t1-add-rrr d base s) (t1-pop s)]))))
   (t1-leax d base index scale disp)
      (t1-eaddr d base index scale + (disp @ 0 () (t1-addsub-imm 'add d d disp)))
   (t1-ldx  d base index scale disp) (t1-eaddr d base index scale + t1-ld  d d disp)
   (t1-ldxb d base index scale disp) (t1-eaddr d base index scale + t1-ldb d d disp)

   (t1-sx w d) (w @ 4 () 1 (t1-sxb d) (t1-sxh d))
   (t1-zx w d) (w @ 4 () 1 (t1-uxb d) (t1-uxh d))

   (t1-neg d) (rn d @ dn (t16 (0x4240 | (dn << 3 | dn))))   ; rsbs Rd,Rd,#0
   (t1-not d) (rn d @ dn (t16 (0x43C0 | (dn << 3 | dn))))   ; mvns Rd,Rd
   (t1-inc d) (t1-addsub-imm 'add d d 1)
   (t1-dec d) (t1-addsub-imm 'sub d d 1)

   ;; ror has no immediate form on v6-M
   (t1-shift op d c)
      (: dn (rn d)
         base (op @ 'shl 0x0000 'shr 0x0800 'sar 0x1000 (scare 'badshift op))
         (t16 (base | ((c & 31) << 6 | (dn << 3 | dn)))))
   ;; format-4 Rd,Rs: low registers, d != count
   (t1-shiftv op d c)
      (: _ (need-lo c 'shiftv-count-hi) _ (need-lo d 'shiftv-hi)
         _ (reg-eq d c ? (scare 'shiftv-dest-is-count [op d c]) 0)
         dn (rn d) cn (rn c)
         base (op @ 'shlv 0x4080 'shrv 0x40C0 'sarv 0x4100 (scare 'badshiftv op))
         (t16 (base | (cn << 3 | dn))))

   ;; div/rem: no hardware divide, so each site expands to a label-free blob owning r0..r3 (the op
   ;; clobbers them): dividend staged into r1, divisor into r0, the answer out of r1
   (t1-mv d s) (reg-eq d s ? () (t1-movr d s))
   (t1-div-in a b)
      (? (reg-eq a 'r0 && reg-eq b 'r1)            ; a true swap: r2 holds a across it
          (catall [(t1-movr 'r2 a) (t1-movr 'r0 b) (t1-movr 'r1 'r2)])
         (reg-eq a 'r0) (t1-mv 'r1 a + t1-mv 'r0 b)   ; land a before r0 is written
         (t1-mv 'r0 b + t1-mv 'r1 a))
   (t1-div-out d) (t1-mv d 'r1)
   ;; r1/r0 -> quotient r1, remainder r2; r0 kept, r3 spent. 32 restoring steps: LSLS shifts the
   ;; top bit into carry, adcs folds it into R, blo skips the subtract when R < D
   (t1-udivmod u)
      (catall [(t16 0x2200) (t16 0x2320)       ; movs r2,#0 ; movs r3,#32
               (t16 0x0049) (t16 0x4152)       ; L: lsls r1,r1,#1 ; adcs r2,r2,r2
               (t16 0x4282) (t16 0xD301)       ;    cmp r2,r0 ; blo S
               (t16 0x1A12) (t16 0x1C49)       ;    subs r2,r2,r0 ; adds r1,r1,#1
               (t16 0x1E5B) (t16 0xD1F7)])     ; S: subs r3,r3,#1 ; bne L
   ;; |r1|,|r0| by (x^m)-m, m = x>>31 arithmetic; leaves the masks sa in r2, sb in r3
   (t1-sabs u)
      (catall [(t16 0x17CA) (t16 0x17C3)       ; asrs r2,r1,#31 (sa) ; asrs r3,r0,#31 (sb)
               (t16 0x4051) (t16 0x1A89)       ; eors r1,r1,r2 ; subs r1,r1,r2  -> |a|
               (t16 0x4058) (t16 0x1AC0)])     ; eors r0,r0,r3 ; subs r0,r0,r3  -> |b|
   (t1-udiv d a b)   (t1-div-in a b + t1-udivmod () + t1-div-out d)
   (t1-urem d a b t) (t1-div-in a b + catall [(t1-udivmod ()) (t16 0x0011)] + t1-div-out d)   ; movs r1,r2
   ;; signed: abs, divide, re-sign. the quotient's mask is sa^sb, the remainder's sa (C truncates);
   ;; it rides the stack across the loop
   (t1-div d a b)
      (t1-div-in a b
       + catall [(t1-sabs ()) (t16 0x405A)         ; eors r2,r2,r3 -> qsign = sa^sb
                 (t1-push 'r2) (t1-udivmod ()) (t1-pop 'r3)
                 (t16 0x4059) (t16 0x1AC9)]        ; eors r1,r1,r3 ; subs r1,r1,r3
       + t1-div-out d)
   (t1-rem d a b t)
      (t1-div-in a b
       + catall [(t1-sabs ())                      ; sa already in r2
                 (t1-push 'r2) (t1-udivmod ()) (t1-pop 'r3)
                 (t16 0x0011)                      ; movs r1,r2  -> |rem|
                 (t16 0x4059) (t16 0x1AC9)]        ; eors r1,r1,r3 ; subs r1,r1,r3
       + t1-div-out d)

   ;; la is (align 4) (lapool Rd) (raw ((fix 4 abs32 lbl 0))): LDR Rd,[pc,#0] reads the word
   ;; just after, B #2 hops it. Rd must be low
   (t1-lapool d) (need-lo d 'lapool-hi, catall [(t16 (0x4800 | rn d << 8)) (t16 0xE001)])

   ;; Bcond .one ; MOVS d,#0 ; B .end ; .one: MOVS d,#1 ; .end:
   ;; the branch goes first: MOVS sets flags, and there is no flag-keeping MOV #imm
   (t1-set cond d)
      (ccn cond @ cc (need-lo d 'set-hi,
                      catall [(t16 (0xD000 | (cc << 8 | 1))) (t1-movs d 0) (t16 0xE000) (t1-movs d 1)]))

   ;; the far lanes' t1-li sets flags: a lea may not sit between a cmp and its branch
   (t1-lea d base off)
      (? (off = 0) (t1-movr d base)
         (reg-eq d 'sp && reg-eq base 'sp)
            (t1-addsub-imm 'add d base off)
         (reg-eq base 'sp && off > 0)
            (0 = off & 3 && off >> 2 <= 255 ? 0 (scare 'lea-sp-off-range off), need-lo d 'lea-hi,
             t16 (0xA800 | (rn d << 8 | off >> 2)))              ; ADD Rd,sp,#imm8*4
         (0 < off <= 255) (t1-addsub-imm 'add d base off)
         (!(reg-eq d base) && lo? d)
            (catall [(t1-li d off) (t1-add-any d base)])
         ;; a hi dest or d==base borrows a saved low scratch; not from sp, which the push moves
         !(reg-eq base 'sp)
            (: s (t1-lowscratch d base '(r0 r1 r2 r3 r4 r5 r6 r7))
               (catall [(t1-push s) (t1-li s off) (t1-add-any s base) (t1-movr d s) (t1-pop s)]))
         (scare 'lea-range [d base off]))

   ;; one-register lists: r0..r7, lr on push, pc on pop; r8..r12 scare
   (t1-push s) (rn s @ sn (? (sn = 14) (t16 (0xB400 | 256)) (sn <= 7) (t16 (0xB400 | 1 << sn)) (scare 'push-hi s)))
   (t1-pop  d) (rn d @ dn (? (dn = 15) (t16 (0xBC00 | 256)) (dn <= 7) (t16 (0xBC00 | 1 << dn)) (scare 'pop-hi d)))

   ;; label branches go wide, short ones can't cross a big function: jmp is BL (lr is dead
   ;; mid-frame: the prologue pushed it), br an inverted Bcc over a BL. cc^1 inverts
   (t1-jmp  label) [(fix 4 'bl  label 0)]
   (t1-br cond label) (ccn cond @ cc
                         (cat (t16 (0xD000 | ((cc ^ 1) << 8 | 1)))
                              [(fix 4 'bl label 0)]))
   (t1-call label) [(fix 4 'bl  label 0)]
   (t1-jmpr d)  (rn d @ dn (t16 (0x4700 | dn << 3)))       ; BX Rm
   ;; the table and its targets are for the analyses, not the machine
   (t1-jmpt d tl labs) (t1-jmpr d)
   (t1-callr d) (rn d @ dn (t16 (0x4780 | dn << 3)))       ; blx Rm

   ;; every ALU op sets flags on v6-M, so the S-names alias their plain rows
   t1-emitters (emsof
        [('li . t1-li) ('mov . t1-movr) ('cmp . t1-cmp) ('test . t1-test)
          ('add . t1-addsub 'add) ('adds . t1-addsub 'add)
          ('sub . t1-addsub 'sub) ('subs . t1-addsub 'sub)
          ('adc . t1-adc) ('adcs . t1-adc) ('sbc . t1-sbc) ('sbcs . t1-sbc)
          ('and . t1-alu2 'and) ('or . t1-alu2 'or) ('ors . t1-alu2 'or)
          ('xor . t1-alu2 'xor) ('imul . t1-alu2 'imul)
          ('ld . t1-ld) ('ld4 . t1-ld) ('ldu4 . t1-ld)
          ('st . t1-st) ('st4 . t1-st)
          ('ldu1 . t1-ldb) ('ldu2 . t1-ldh) ('ld1 . t1-lds1) ('ld2 . t1-lds2)
          ('st1 . t1-stb) ('st2 . t1-sth)
          ('sx1 . t1-sx 1) ('sx2 . t1-sx 2) ('sx4 . t1-sx 4)
          ('zx1 . t1-zx 1) ('zx2 . t1-zx 2) ('zx4 . t1-zx 4)
          ('shl . t1-shift 'shl) ('shr . t1-shift 'shr) ('sar . t1-shift 'sar)
          ('ror . (\ d c (scare 'v6m-no-ror-imm 'ror)))
          ('shlv . t1-shiftv 'shlv) ('shrv . t1-shiftv 'shrv) ('sarv . t1-shiftv 'sarv)
          ('lea . t1-lea) ('lean . t1-lea)
          ('leax . t1-leax) ('ldx . t1-ldx) ('ldxb . t1-ldxb)
          ('push . t1-push) ('pop . t1-pop)
          ('neg . t1-neg) ('not . t1-not) ('inc . t1-inc) ('dec . t1-dec)
          ('set . t1-set)
          ('jmp . t1-jmp) ('br . t1-br) ('jmpr . t1-jmpr) ('jmpt . t1-jmpt) ('callr . t1-callr) ('call . t1-call)
          ('div . t1-div) ('rem . t1-rem) ('udiv . t1-udiv) ('urem . t1-urem)
          ('lapool . t1-lapool)
          ('raw . 1)
          ('ret . t16 0x4770)                                ; BX lr
          ('sys . t16 0xDF00)                                ; svc #0
          ('nop . t16 0xBF00)
          ('trap . t16 0xBE00)])                             ; bkpt #0
   (t1-lower ins) (lower-via @ f (lit? f ? (f t1-emitters ins) (scare 'holo-bake-stale 'lower-via)))

   ;; pc reads as site + 4; branch fields count halfwords.
   ;;   b   0xe000 | imm11               +-2046
   ;;   bcc 0xd000 | cond<<8 | imm8      +-254, cond in aux
   ;;   bl  S:J1:J2:imm10:imm11 as thumb2.l, I1=~(J1^S), I2=~(J2^S)
   (t1-patch kind target site width aux)
      (target - (site + 4) @ o
         (kind @ 'b
            (-2046 <= o <= 2046 ? 0 (scare 'b-range-needs-veneer o),
             t16 (0xE000 | o >> 1 & 2047))
            'bcc
            (-254 <= o <= 254 ? 0 (scare 'bcc-range-needs-veneer o),
             t16 (0xD000 | (aux << 8 | (o >> 1) & 255)))
            'bl (tbw o 0xD000)
            'abs32                                 ; la's pooled word
            (le32 (target + aux))                           ; a .o leaves it an R_ARM_ABS32
            (scare 'badfix kind)))

   ;; no refix: rel field formats are the ABI's, shared with v7-M, so the one arm32 re-encoder
   ;; lives in thumb2.l and link.l finds it by family

   t1 {'lower t1-lower 'patch t1-patch 'nop '(0 191)}  ; nop bf00
   (defbackend 'thumb1 t1))
) ; module 'holo
