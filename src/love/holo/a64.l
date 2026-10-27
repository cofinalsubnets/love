; a64 -- the aarch64 backend for holo. fixed 32-bit words, three-address ALU, rN = xN, sp = 31.
; a branch offset is a bitfield, so its fixup carries the base word in aux and patch ors it in.
; immediates: add/sub/cmp take imm12 (a negative flips the op), and/or/xor/test a bitmask
; immediate; mul has none, and an immediate that cannot encode scares.

(module 'holo
(: ;; r19..r28 are callee-saved. x16 (IP0) is borrowed by the indexed stores, the far-memory lane
   ;; and the 128-bit kit, x17 by the kit: mooncc allocates neither, so a hand-written lay naming
   ;; them must keep clear of those
   a64-regs {'sp 31 'fp 29 'lr 30
             'r0 0 'r1 1 'r2 2 'r3 3  'r4 4
             'r5 5 'r6 6 'r7 7 'r8 8  'r9 9
             'r10 10 'r11 11 'r12 12 'r13 13 'r14 14 'r15 15
             'r16 16 'r17 17 'r18 18
             'r19 19 'r20 20 'r21 21 'r22 22 'r23 23 'r24 24
             'r25 25 'r26 26 'r27 27 'r28 28}

   ;; op -> [register-form base, immediate-form base or 0]
   a64-alu {'add [0x8B000000 0x91000000] 'sub [0xCB000000 0xD1000000]
            'and [0x8A000000 0] 'or [0xAA000000 0] 'xor [0xCA000000 0]
            'adds [0xAB000000 0xB1000000] 'subs [0xEB000000 0xF1000000]}

   (rn r) (look a64-regs r 'badreg)
   (reg-eq a b) (rn a = rn b)       ; a64's own, or x64.l's would read x64 registers

   ;; //% and not &/>>: u can be a bignum >= 2^63, where & drops the high limb
   (a64-lane u k) ((u // k 65536) % 65536)                                     ; (k 65536) is 65536^k
   ;; a symbol survives arithmetic, so the immediate is checked a number
   (a64-li d imm)
      (: _ (constellation? imm ? 0 (scare 'badimm imm))
         dn (rn d) u (u64 imm)
         ls (map (k \ a64-lane u k) ^4)
         ; movn when more lanes are all ones than zero; movk patches the rest
         neg (#(filter (l \ l != 65535) ls) < #(filter (l \ l != 0) ls))
         skip (neg ? 65535 0)
         i0 (: (go k) (? (k = 4) 0 (ls k != skip) k (go (k + 1))) (go 0))
         (catall ((neg ? (le32 (0x92800000 | (i0 << 21 | ((65535 - ls i0) << 5 | dn))))    ; movn d, ~l, lsl 16i
                         (le32 (0xD2800000 | (i0 << 21 | (ls i0 << 5 | dn)))))              ; movz d, l, lsl 16i
                  . map (k \ (k != i0 && ls k != skip ? (le32 (0xF2800000 | (k << 21 | (ls k << 5 | dn)))) ()))
                        ^4)))                                                                 ; movk d, l, lsl 16k

   ;; mov is ORR from xzr, where 31 reads as xzr, so a move to or from sp lays add #0
   (a64-mov d s) (: dn (rn d) sn (rn s)
      (? (elem 'zr [d s] && elem 'sp [d s]) (scare 'a64-mov-sp [d s])
         (d = 'sp || s = 'sp) (le32 (0x91000000 | (sn << 5 | dn)))               ; add d, s, #0
         (le32 (0xAA0003E0 | (sn << 16 | dn)))))                                  ; orr d, xzr, s

   ;; the shifted-register form reads 31 as xzr in every slot, so sp scares: move sp with lea
   ;; and do the arithmetic in a plain register
   (alu-rrr base d a b) (: dn (rn d) an (rn a) bn (rn b)
      (dn = 31 || an = 31 || bn = 31 ? (scare 'a64-alu-sp [d a b]) 0,
       le32 (base | (bn << 16 | (an << 5 | dn)))))
   (alu-rri base d a imm) (: dn (rn d) an (rn a) (le32 (base | (imm << 10 | (an << 5 | dn)))))
   ;; imm12, or up to 24 bits as the LSL #12 form plus the low tail (add/sub only: a split S-form
   ;; would leave the tail's flags)
   (a64-addsub-imm op d a imm)
      (: pos  (imm < 0 ? (0 - imm) imm)
         fop  (imm < 0 ? (? (op = 'add) 'sub (op = 'sub) 'add (op = 'adds) 'subs 'adds) op)
         base (peep a64-alu fop 0 1)
         (? (pos <= 4095) (alu-rri base d a pos)
            (pos <= 16777215 && elem fop '(add sub))
             (catall [(alu-rri (base | 0x400000) d a (pos >> 12))
                       (pos % 4096 = 0 ? () (alu-rri base d d (pos % 4096)))])
            (scare 'imm12-range imm)))
   ;; a bitmask immediate -> N:immr:imms at bits [22:10]: a rotated run of ones repeated over a
   ;; 2..64-bit element. 0, -1 and anything else scare.
   ;; bit tests, never a 64-bit mask: (1 << 63) - 1 leaves fixnum range and & on the big misreads
   (bmbit v k)  (v >> k & 1)
   (bmones v i) ((: (go k) (i + k = 64 || 0 = bmbit v (i + k) ? k (go (k + 1)))) 0)
   (bmctz v)    ((: (go k) (k = 64 || 1 = bmbit v k ? k (go (k + 1)))) 0)
   (bmclo v)    ((: (go k) (k = 64 || 0 = bmbit v (63 - k) ? k (go (k + 1)))) 0)
   (bmrun? v)   (v = 0 ? 0 (: i (bmctz v) n (bmones v i) (i + n = 64 || 0 = v >> (i + n))))
   (bmelem v)   ((: (go e) (e = 2 ? 2 (: h (e // 2) m ((1 << h) - 1)
                                          (v & m = v >> h & m ? (go h) e)))) 64)
   (bitmask-field imm)
      (imm = 0 || imm = -1 ? (scare 'a64-bitmask-imm imm)
         (: e (bmelem imm)
            m (e = 64 ? -1 ((1 << e) - 1))
            v (imm & m)
            r (bmrun? v ? (bmctz v @ i [i (bmones v i)])
                 (: w (v | m ^ -1)                         ; the run wraps the element: ask of its complement
                    (bmrun? (w ^ -1) ?
                       (bmclo w @ c [(64 - c) (c + bmones w 0 - (64 - e))]))))
            (r = () || r 1 = e ? (scare 'a64-bitmask-imm imm)    ; a run filling its element is all ones: reserved
               (: i <r
                  ct <>r
                  immr (e - i & e - 1)
                  nimms ((e - 1 ^ -1) << 1 | ct - 1)    ; the size prefix, then imms = ones-1
                  n (nimms >> 6 & 1 ^ 1)
                  (n << 22 | (immr << 16 | (nimms & 0x3f) << 10))))))
   (a64-logimm-base op) (? (op = 'and) 0x92000000 (op = 'or) 0xB2000000 (op = 'xor) 0xD2000000 (scare 'badlog op))
   (a64-logical-imm op d a b) (: dn (rn d) an (rn a) (le32 (a64-logimm-base op | (bitmask-field b | (an << 5 | dn)))))
   (a64-aluop op d a b)
      (: meta (peep a64-alu op 0) rrb (meta 0) rib (meta 1)
         (? (reg? b)    (alu-rrr rrb d a b)
            (rib = 0)   (a64-logical-imm op d a b)
            (a64-addsub-imm op d a b)))

   (a64-cmp a b)                                            ; subs xzr, a, b; cmn for a negative imm
      (rn a @ an
         (reg? b ? (rn b @ bn (le32 (0xEB00001F | (bn << 16 | an << 5))))
            (: pos (b < 0 ? (0 - b) b) base (b < 0 ? 0xB100001F 0xF100001F)
               (? (pos <= 4095) (le32 (base | (pos << 10 | an << 5)))
                  (pos % 4096 = 0 && pos >> 12 <= 4095) (le32 (base | 0x400000 | (pos >> 12 << 10 | an << 5)))   ; imm12, lsl 12
                  (scare 'imm12-range b)))))

   (a64-mulh d a b) (: dn (rn d) an (rn a) bn (rn b) (le32 (0x9B407C00 | (bn << 16 | (an << 5 | dn)))))   ; smulh
   (a64-umulh d a b) (: dn (rn d) an (rn a) bn (rn b) (le32 (0x9BC07C00 | (bn << 16 | (an << 5 | dn)))))  ; umulh
   (a64-imul d a b)                                         ; madd d, a, b, xzr
      (reg? b ? (: dn (rn d) an (rn a) bn (rn b) (le32 (0x9B007C00 | (bn << 16 | (an << 5 | dn)))))
         (scare 'a64-mul-imm ['imul d a b]))

   ;; past imm12 and imm9: x16 = bn +- |off|, then op Rt, [x16, #0]
   (a64-far ubase dt bn off)
      (: u (off < 0 ? (0 - off) off)
         l0 (u % 65536) l1 (u // 65536)
         ai (off < 0 ? 0xD1000000 0x91000000)             ; add/sub immediate, where Rn=31 reads SP
         hi (u >> 12) lo (u % 4096)
         (bn = 16 ? (scare 'far-base-x16 off) 0,
          u <= 16777215 ?
            (catall [
              (hi = 0 ? () (le32 (ai | 0x400000 | (hi << 10 | (bn << 5 | 16)))))          ; x16 = base +- hi, lsl 12
              (lo = 0 ? () (le32 (ai | (lo << 10 | ((hi = 0 ? bn 16) << 5 | 16)))))      ; x16 = (base | x16) +- lo
              (le32 (ubase | (16 << 5 | dt)))])
            (u < 4294967296 ? 0 (scare 'mem-range off),
             bn = 31 ? (scare 'far-base-sp off) 0,       ; shifted-reg add reads Rn=31 as XZR, not SP
             catall [
              (le32 (0xD2800000 | (l0 << 5 | 16)))                                    ; movz x16, l0
              (l1 = 0 ? () (le32 (0xF2A00000 | (l1 << 5 | 16))))                    ; movk x16, l1, lsl 16
              (le32 ((off < 0 ? 0xCB000000 0x8B000000) | (16 << 16 | (bn << 5 | 16))))    ; add/sub x16, base, x16
              (le32 (ubase | (16 << 5 | dt)))])))                                    ; op Rt, [x16, #0]
   ;; every load/store: LDR/STR imm12 in units of sc, else LDUR/STUR imm9, else far
   (a64-mem-raw lbase ubase sc dt bn off)
      (charm? off ? 0 (scare 'mem-disp off),
       0 = off % sc && off >= 0 && off // sc <= 4095 ?
         (le32 (ubase | (off // sc << 10 | (bn << 5 | dt))))
         (off >= -256 && off <= 255 ?
            (le32 (lbase | ((off & 511) << 12 | (bn << 5 | dt))))
            (a64-far ubase dt bn off)))
   (a64-mem-r lbase ubase dt bn off) (a64-mem-raw lbase ubase 8 dt bn off)
   (a64-mem lbase ubase d base off) (a64-mem-r lbase ubase (rn d) (rn base) off)
   (a64-ld d base off)   (a64-mem 0xF8400000 0xF9400000 d base off)
   (a64-st base off s)   (a64-mem 0xF8000000 0xF9000000 s base off)
   (a64-mem-sz lbase ubase sc d base off) (a64-mem-raw lbase ubase sc (rn d) (rn base) off)
   (a64-ld1 d base off) (a64-mem-sz 0x38800000 0x39800000 1 d base off)   ; ldrsb/ldursb Xt
   (a64-ld2 d base off) (a64-mem-sz 0x78800000 0x79800000 2 d base off)   ; ldrsh/ldursh Xt
   (a64-ld4 d base off) (a64-mem-sz 0xB8800000 0xB9800000 4 d base off)   ; ldrsw/ldursw Xt
   (a64-ldu1 d base off) (a64-mem-sz 0x38400000 0x39400000 1 d base off)  ; ldrb/ldurb Wt
   (a64-ldu2 d base off) (a64-mem-sz 0x78400000 0x79400000 2 d base off)  ; ldrh/ldurh Wt
   (a64-ldu4 d base off) (a64-mem-sz 0xB8400000 0xB9400000 4 d base off)  ; ldr/ldur Wt
   (a64-st1 base off s) (a64-mem-sz 0x38000000 0x39000000 1 s base off)   ; strb/sturb Wt
   (a64-st2 base off s) (a64-mem-sz 0x78000000 0x79000000 2 s base off)   ; strh/sturh Wt
   (a64-st4 base off s) (a64-mem-sz 0xB8000000 0xB9000000 4 s base off)   ; str/stur Wt
   (a64-sx w d) (a64-sxs w d d)
   (a64-sxs w d s)                                          ; sbfm: sxtb/sxth/sxtw Xd, Ws
      (: dn (rn d) sn (rn s)
         base (? (w = 1) 0x93401C00 (w = 2) 0x93403C00 0x93407C00)
         (le32 (base | (sn << 5 | dn))))
   (a64-zx w d) (a64-zxs w d d)
   (a64-zxs w d s)                                          ; ubfm: uxtb/uxth Xd, Xs (w=4 clears bits 32..63)
      (: dn (rn d) sn (rn s)
         base (? (w = 1) 0xD3401C00 (w = 2) 0xD3403C00 0xD3407C00)
         (le32 (base | (sn << 5 | dn))))
   (a64-shiftv op d c)                                      ; the IR pins the count to r1
      (: _ (reg-eq c 'r1 ? 0 (scare 'shiftv-count-not-r1 [op d c]))
         _ (reg-eq d 'r1 ? (scare 'shiftv-dst-is-r1 [op d c]) 0)
         dn (rn d) cn (rn c)
         base (? (op = 'shlv) 0x9AC02000 (op = 'shrv) 0x9AC02400 (op = 'sarv) 0x9AC02800
                 (op = 'rorv) 0x9AC02C00 0x1AC02C00)         ; rorv4: the W form, count mod 32
         (le32 (base | (cn << 16 | (dn << 5 | dn)))))
   (a64-lea d base off)  (a64-addsub-imm 'add d base off)

   (a64-push s) (rn s @ st (le32 (0xF81F0FE0 | st)))      ; str s, [sp, #-16]!
   (a64-pop  d) (rn d @ dt (le32 (0xF84107E0 | dt)))      ; ldr d, [sp], #16
   ;; the frame record: fp at [sp], lr at [sp+8], in the 32 bytes of two pushes
   a64-frpush (le32 0xA9BE7BFD)                           ; stp x29, x30, [sp, #-32]!
   a64-frpop  (le32 0xA8C27BFD)                           ; ldp x29, x30, [sp], #32

   (a64-neg d) (rn d @ dt (le32 (0xCB0003E0 | (dt << 16 | dt))))   ; sub d, xzr, d
   (a64-not d) (a64-mvn d d)
   (a64-mvn d s) (: dt (rn d) st (rn s) (le32 (0xAA2003E0 | (st << 16 | dt))))   ; orn d, xzr, s
   (a64-inc d) (a64-addsub-imm 'add d d 1)
   (a64-dec d) (a64-addsub-imm 'sub d d 1)
   (a64-decm base off) (a64-ld 'r17 base off + a64-addsub-imm 'subs 'r17 'r17 1 + a64-st base off 'r17)   ; [base+off] -= 1 through x17, the flags set

   ;; B/BL imm26 at [25:0], B.cond imm19 at [23:5], in words from the instruction itself
   (a64-jmp  label)    [(fix 4 'b26 label 0x14000000)]
   (a64-cbr w r label) [(fix 4 'b19 label (w | rn r))]   ; cbz/cbnz, X or W by the word
   (a64-tbr w r label) [(fix 4 'b14 label (w | rn r))]   ; tbz/tbnz, the bit and the op in the word
   (a64-afix k w label ad) [(fix 4 k label (w | (ad & 4294967295) << 32))]   ; adrp, :lo12:, the addend aboard
   (a64-call label)    [(fix 4 'b26 label 0x94000000)]
   ;; la: adrp + add (+-4GB), the pair ELF relocates as PG_HI21 + ABS_LO12_NC
   (a64-la d label)    (rn d @ dn
                          [(fix 4 'adrp21 label (0x90000000 | dn))
                            (fix 4 'addlo12 label (0x91000000 | (dn << 5 | dn)))])
   ;; lar: adr, byte pc-relative (+-1MB), right at any load address -- adrp is right only when
   ;; the image loads page-aligned, which a code blob in a runtime mapping is not
   (a64-lar d label)   (rn d @ dn [(fix 4 'adr21 label (0x10000000 | dn))])
   ;; lia: the linked address, not where the pc runs -- for a kernel linked high that runs low
   ;; until the MMU is on. an inline literal word: ldr xd, .+8 ; b .+12 ; .quad label.
   ;; put an ('align 8) before it: an unaligned literal faults on Device memory, as before the MMU
   (a64-lia d label)   (rn d @ dn
                          (le32 (0x58000040 | dn)         ; ldr xd, .+8
                           + le32 0x14000003              ; b .+12
                           + [(fix 8 'abs64 label 0)]))
   (a64-br cond label) (look arm-cc cond 'badcc @ cc
                          [(fix 4 'b19 label (0x54000000 | cc))])
   (a64-jmpr d) (rn d @ dn (le32 (0xD61F0000 | dn << 5)))                  ; br
   ;; the table and its targets are for the analyses, not the machine
   (a64-jmpt d tl labs) (a64-jmpr d)
   (a64-callr d) (rn d @ dn (le32 (0xD63F0000 | dn << 5)))                 ; blr
   ;; branch to lbl on signed overflow: smulh must equal the low half's sign fill. t must
   ;; differ from a, b and d
   (a64-mulo d a b t lbl)
      (: dn (rn d) an (rn a) bn (rn b) tn (rn t)
         (catall [(le32 (0x9B407C00 | (bn << 16 | (an << 5 | tn))))    ; smulh t, a, b
                   (le32 (0x9B007C00 | (bn << 16 | (an << 5 | dn))))    ; mul   d, a, b
                   (le32 (0xEB80FC1F | (dn << 16 | tn << 5)))           ; subs  xzr, t, d, asr #63
                   [(fix 4 'b19 lbl 0x54000001)]]))                        ; b.ne  lbl
   ;; cset = csinc Xd, xzr, xzr, cc^1 (cc^1 inverts)
   (a64-set cond d)
      (: cc (look arm-cc cond 'badcc) dn (rn d)
         (le32 (0x9A9F07E0 | ((cc ^ 1) << 12 | dn))))
   ;; lsl/lsr are ubfm, asr sbfm, ror extr Xd,Xn,Xn,#c, rol #c ror #(64-c).
   ;; a64-shs is the three-address form (the lsl/lsr/asr rows)
   (a64-shs op d s c)
      (: dn (rn d) sn (rn s)
         (? (op = 'shl) (le32 (0xD3400000 | ((64 - c & 63) << 16 | (63 - c << 10 | (sn << 5 | dn)))))   ; lsl = ubfm immr=(-c)&63, imms=63-c
            (op = 'shr) (le32 (0xD3400000 | (c << 16 | (63 << 10 | (sn << 5 | dn)))))                        ; lsr = ubfm immr=c, imms=63
            (le32 (0x93400000 | (c << 16 | (63 << 10 | (sn << 5 | dn)))))))                                 ; asr = sbfm immr=c, imms=63
   (a64-shift op d c)
      (rn d @ dn
         (? (elem op '(shl shr sar)) (a64-shs op d d c)
            (op = 'ror) (le32 (0x93C00000 | (dn << 16 | (c << 10 | (dn << 5 | dn)))))
            (op = 'rol) (le32 (0x93C00000 | (dn << 16 | ((64 - c & 63) << 10 | (dn << 5 | dn)))))
            (op = 'ror4) (le32 (0x13800000 | (dn << 16 | (c << 10 | (dn << 5 | dn)))))                       ; the W form, zero-extending
            (scare 'badshift op)))
   ;; tst = ands xzr, a, b; b a register or a bitmask immediate
   (a64-test a b)
      (reg? b ? (: an (rn a) bn (rn b) (le32 (0xEA00001F | (bn << 16 | an << 5))))
         (rn a @ an (le32 (0xF200001F | (bitmask-field b | an << 5)))))
   ;; rem = a - (a/b)*b by msub through t, which must differ from a and b
   (a64-div d a b)   (: dn (rn d) an (rn a) bn (rn b) (le32 (0x9AC00C00 | (bn << 16 | (an << 5 | dn)))))   ; sdiv d, a, b
   (a64-rem d a b t)
      (: dn (rn d) an (rn a) bn (rn b) tn (rn t)
         (catall [(le32 (0x9AC00C00 | (bn << 16 | (an << 5 | tn))))                    ; sdiv t, a, b
                   (le32 (0x9B008000 | (bn << 16 | (an << 10 | (tn << 5 | dn)))))]))   ; msub d, t, b, a
   (a64-udiv d a b)  (: dn (rn d) an (rn a) bn (rn b) (le32 (0x9AC00800 | (bn << 16 | (an << 5 | dn)))))   ; udiv d, a, b
   (a64-urem d a b t)
      (: dn (rn d) an (rn a) bn (rn b) tn (rn t)
         (catall [(le32 (0x9AC00800 | (bn << 16 | (an << 5 | tn))))                    ; udiv t, a, b
                   (le32 (0x9B008000 | (bn << 16 | (an << 10 | (tn << 5 | dn)))))]))   ; msub d, t, b, a
   ;; the 128-bit kit: a value is x2:x0 (hi:lo), a binop's left in a 16-byte cell at [sp] or, for
   ;; the r-twins, two registers. one IR form each, so no pass parts a carry pair. x16/x17 scratch
   a64-wldp (le32 0xA94047F0)                                                 ; ldp x16, x17, [sp]: left lo, hi
   (a64-w3 base d n m)    (le32 (base | (m << 16 | (n << 5 | d))))        ; op Xd, Xn, Xm
   (a64-w4 base d n m a)  (le32 (base | (m << 16 | (a << 10 | (n << 5 | d)))))    ; madd/msub Xd,Xn,Xm,Xa -- extr's imms shares the Ra field
   (a64-wsel d n m cond)  (: cc (look arm-cc cond 'badcc)                   ; csel Xd, Xn, Xm, cond
                               (le32 (0x9A800000 | (m << 16 | (cc << 12 | (n << 5 | d))))))
   (a64-wmov d m)         (a64-w3 0xAA000000 d 31 m)                        ; mov Xd, Xm
   (a64-wshi op d n c)                                                        ; lsl/lsr/asr Xd, Xn, #c
      (? (op = 'shl) (le32 (0xD3400000 | ((64 - c & 63) << 16 | (63 - c << 10 | (n << 5 | d)))))
         (op = 'shr) (le32 (0xD3400000 | (c << 16 | (63 << 10 | (n << 5 | d)))))
         (le32 (0x93400000 | (c << 16 | (63 << 10 | (n << 5 | d))))))
   (a64-a128 sp9) (a64-wldp + (a64-w3 0xAB000000 0 0 16 + a64-w3 0x9A000000 2 2 17))    ; adds x0,x0,x16; adc x2,x2,x17
   (a64-s128 sp9) (a64-wldp + (a64-w3 0xEB000000 0 16 0 + a64-w3 0xDA000000 2 17 2))    ; subs x0,x16,x0; sbc x2,x17,x2
   (a64-mw128 sp9) (le32 0xF94003F0                                           ; ldr x16,[sp]: the low word alone
                      + (a64-w3 0x9BC07C00 2 0 16 + a64-w3 0x9B007C00 0 0 16))   ; umulh x2,x0,x16; mul x0,x0,x16
   (a64-m128 sp9)                                                             ; low 128 of the product: the cross terms onto the widening one
      (a64-wldp + (a64-w3 0x9B007C00 17 17 0                                ; mul   x17, x17, x0        Lhi*Rlo
       + (a64-w4 0x9B000000 17 16 2 17                                        ; madd  x17, x16, x2, x17    + Llo*Rhi
       + (a64-w3 0x9BC07C00 2 16 0                                            ; umulh x2, x16, x0
       + (a64-w3 0x8B000000 2 2 17 + a64-w3 0x9B007C00 0 16 0)))))          ; add x2,x2,x17; mul x0,x16,x0
   ;; 0/1 <- (LEFT cond RIGHT). eq/ne fold the halves by eor; the ordered ones read the borrow
   ;; chain's flags, gt/above/le/be with the subtraction reversed
   (a64-w128cc cond chain rsub zch)
      (? (elem cond '(eq ne))       (zch + a64-set cond 'r0)
         (elem cond '(lt below ge ae)) (chain + a64-set cond 'r0)
         (cond = 'gt)    (rsub + a64-set 'lt 'r0)
         (cond = 'above) (rsub + a64-set 'below 'r0)
         (cond = 'le)    (rsub + a64-set 'ge 'r0)
         (cond = 'be)    (rsub + a64-set 'ae 'r0)
         (scare 'badcc128 cond))
   (a64-c128 cond sp9)
      (a64-wldp + a64-w128cc cond
         (a64-cmp 'r16 'r0 + a64-w3 0xFA000000 31 17 2)                     ; cmp x16,x0; sbcs xzr,x17,x2   (L-R)
         (a64-cmp 'r0 'r16 + a64-w3 0xFA000000 31 2 17)                     ; cmp x0,x16; sbcs xzr,x2,x17   (R-L)
         (a64-w3 0xCA000000 16 16 0 + (a64-w3 0xCA000000 17 17 2            ; eor x16,x16,x0; eor x17,x17,x2
          + (a64-w3 0xAA000000 16 16 17 + a64-cmp 'r16 0))))                ; orr x16,x16,x17; cmp x16,#0
   ;; u128 in the cell / u64 in x0: the high half by udiv/msub, the low by 64 restoring steps; the
   ;; cell parks the high quotient. ccmp folds the doubling's carry-out into the compare, for a
   ;; divisor past 2^63. a zero divisor does not trap: high quotient 0, low all ones
   a64-divloop
      (le32 0xF241023F + (le32 0x93D0FE31 + (le32 0xD37FFA10                    ; tst x17,#1<<63; extr x17,x17,x16,#63; lsl x16,x16,#1
       + (le32 0xFA400222 + (le32 0xCB000222                                    ; ccmp x17,x0,#2,eq (C on a carry-out); sub x2,x17,x0
       + (a64-wsel 17 2 17 'ae + (le32 0x9A903610                             ; csel x17,x2,x17,hs; cinc x16,x16,hs
       + (le32 0xF1000421 + le32 0x54FFFF01))))))))                             ; subs x1,x1,#1; b.ne -8
   a64-divpre
      (a64-wldp + (le32 0x9AC00A22 + (le32 0x9B00C451                         ; udiv x2,x17,x0; msub x17,x2,x0,x17
       + (le32 0xF90003E2 + (le32 0xD2800801 + a64-divloop)))))               ; str x2,[sp]; mov x1,#64
   (a64-dv128 sp9) (a64-divpre + (a64-wmov 0 16 + le32 0xF94003E2))
   (a64-rm128 sp9) (a64-divpre + (a64-wmov 0 17 + a64-wmov 2 31))       ; rem < d: high half 0
   ;; by a constant: extr is the funnel; from 64 the halves move. c = 0 lays nothing (extr has no #64)
   (a64-shl128 c)
      (? (c = 0) ()
         (c < 64) (a64-w4 0x93C00000 2 2 0 (64 - c) + a64-wshi 'shl 0 0 c)  ; extr x2,x2,x0,#64-c; lsl x0,x0,#c
         (a64-wshi 'shl 2 0 (c - 64) + a64-wmov 0 31))                      ; lsl x2,x0,#c-64; x0 = 0
   (a64-shr128 c)
      (? (c = 0) ()
         (c < 64) (a64-w4 0x93C00000 0 2 0 c + a64-wshi 'shr 2 2 c)         ; extr x0,x2,x0,#c; lsr x2,x2,#c
         (a64-wshi 'shr 0 2 (c - 64) + a64-wmov 2 31))                      ; lsr x0,x2,#c-64; x2 = 0
   (a64-sar128 c)
      (? (c = 0) ()
         (c < 64) (a64-w4 0x93C00000 0 2 0 c + a64-wshi 'sar 2 2 c)         ; extr x0,x2,x0,#c; asr x2,x2,#c
         (a64-wshi 'sar 0 2 (c - 64) + a64-wshi 'sar 2 2 63))               ; asr x0,x2,#c-64; the sign flood
   ;; by x1 (0..127): a shift reads its count mod 64, so both bands compute and csel hs picks.
   ;; c = 0 is guarded: the co-shift by 64-c would be by 0 and keep the whole word
   a64-shl128v
      (a64-w3 0xCB000000 16 31 1                                              ; neg  x16, x1        (= 64-c mod 64)
       + (a64-w3 0x9AC02400 16 0 16                                           ; lsr  x16, x0, x16
       + (a64-w3 0x9AC02000 17 2 1                                            ; lsl  x17, x2, x1
       + (a64-w3 0xAA000000 17 17 16                                          ; orr  x17, x17, x16
       + (a64-cmp 'r1 0 + (a64-wsel 17 2 17 'eq                             ; c = 0: the high half is unmoved
       + (a64-addsub-imm 'sub 'r16 'r1 64 + (a64-w3 0x9AC02000 16 0 16      ; sub x16,x1,#64; lsl x16,x0,x16
       + (a64-cmp 'r1 64 + (a64-wsel 2 16 17 'ae                            ; csel x2, x16, x17, hs
       + (a64-w3 0x9AC02000 0 0 1 + a64-wsel 0 31 0 'ae)))))))))))           ; lsl x0,x0,x1; csel x0,xzr,x0,hs
   a64-shr128v
      (a64-w3 0xCB000000 16 31 1                                              ; neg  x16, x1
       + (a64-w3 0x9AC02000 16 2 16                                           ; lsl  x16, x2, x16
       + (a64-w3 0x9AC02400 17 0 1                                            ; lsr  x17, x0, x1
       + (a64-w3 0xAA000000 17 17 16                                          ; orr  x17, x17, x16
       + (a64-cmp 'r1 0 + (a64-wsel 17 0 17 'eq                             ; c = 0: the low half is unmoved
       + (a64-addsub-imm 'sub 'r16 'r1 64 + (a64-w3 0x9AC02400 16 2 16      ; sub x16,x1,#64; lsr x16,x2,x16
       + (a64-cmp 'r1 64 + (a64-wsel 0 16 17 'ae                            ; csel x0, x16, x17, hs
       + (a64-w3 0x9AC02400 2 2 1 + a64-wsel 2 31 2 'ae)))))))))))           ; lsr x2,x2,x1; csel x2,xzr,x2,hs
   a64-sar128v
      (a64-w3 0xCB000000 16 31 1                                              ; neg  x16, x1
       + (a64-w3 0x9AC02000 16 2 16                                           ; lsl  x16, x2, x16
       + (a64-w3 0x9AC02400 17 0 1                                            ; lsr  x17, x0, x1
       + (a64-w3 0xAA000000 17 17 16                                          ; orr  x17, x17, x16
       + (a64-cmp 'r1 0 + (a64-wsel 17 0 17 'eq
       + (a64-addsub-imm 'sub 'r16 'r1 64 + (a64-w3 0x9AC02800 16 2 16      ; sub x16,x1,#64; asr x16,x2,x16
       + (a64-cmp 'r1 64 + (a64-wsel 0 16 17 'ae
       + (a64-wshi 'sar 17 2 63 + (a64-w3 0x9AC02800 2 2 1                  ; the sign flood, then asr x2,x2,x1
       + a64-wsel 2 17 2 'ae))))))))))))                                       ; csel x2, x17, x2, hs
   ;; the r-twins: the left in rl:rh (lo, hi), left untouched; the answer in x2:x0
   (a64-a128r rl rh) (: l (rn rl) h (charm? rh ? 31 (rn rh))                ; a number rh: xzr
      (a64-w3 0xAB000000 0 0 l + a64-w3 0x9A000000 2 2 h))                  ; adds x0,x0,rl; adc x2,x2,rh
   (a64-s128r rl rh) (: l (rn rl) h (rn rh)
      (a64-w3 0xEB000000 0 l 0 + a64-w3 0xDA000000 2 h 2))                  ; subs x0,rl,x0; sbc x2,rh,x2
   (a64-mw128r rl) (rn rl @ l
                      (a64-w3 0x9BC07C00 2 0 l + a64-w3 0x9B007C00 0 0 l))                  ; umulh x2,x0,rl; mul x0,x0,rl
   (a64-m128r rl rh) (: l (rn rl) h (rn rh)
      (a64-w3 0x9B007C00 16 h 0                                               ; mul   x16, rh, x0        Lhi*Rlo
       + (a64-w4 0x9B000000 16 l 2 16                                         ; madd  x16, rl, x2, x16    + Llo*Rhi
       + (a64-w3 0x9BC07C00 2 l 0                                             ; umulh x2, rl, x0
       + (a64-w3 0x8B000000 2 2 16 + a64-w3 0x9B007C00 0 l 0)))))           ; add x2,x2,x16; mul x0,rl,x0
   (a64-c128r cond rl rh) (: l (rn rl) h (rn rh)
      (a64-w128cc cond
         (a64-cmp rl 'r0 + a64-w3 0xFA000000 31 h 2)                        ; cmp rl,x0; sbcs xzr,rh,x2
         (a64-cmp 'r0 rl + a64-w3 0xFA000000 31 2 h)                        ; cmp x0,rl; sbcs xzr,x2,rh
         (a64-w3 0xCA000000 16 l 0 + (a64-w3 0xCA000000 17 h 2
          + (a64-w3 0xAA000000 16 16 17 + a64-cmp 'r16 0)))))
   a64-sx128  (a64-wshi 'sar 2 0 63)                                        ; asr x2, x0, #63
   a64-n128   (a64-w3 0xEB000000 0 31 0 + a64-w3 0xDA000000 2 31 2)       ; negs x0,x0; ngc x2,x2
   a64-inc128 (a64-addsub-imm 'adds 'r0 'r0 1 + a64-w3 0x9A000000 2 2 31) ; adds x0,x0,#1; adc x2,x2,xzr
   a64-dec128 (a64-addsub-imm 'subs 'r0 'r0 1 + a64-w3 0xDA000000 2 2 31) ; subs x0,x0,#1; sbc x2,x2,xzr

   ;; base + ix*scale by add lsl, in the dest for loads and leax, in x16 for stores
   (a64-shiftamt scale) (? (scale = 1) 0 (scale = 2) 1 (scale = 4) 2 (scale = 8) 3 (scare 'badscale scale))
   (a64-addsh dn bn ixn amt) (le32 (0x8B000000 | (ixn << 16 | (amt << 10 | (bn << 5 | dn)))))   ; add Xdn, Xbn, Xixn, lsl #amt
   ;; or one word, [Xn, Xm, LSL #s]: no displacement, scale 1 or the element size (S = 1)
   (a64-norof _) (getenv "MOON_ABLATE" @ s (string? s && (s = "rof" || s = "fsel,rof")))
   (a64-rof? scale disp sz) (disp = 0 && (scale = 1 || scale = sz) && !(a64-norof 0))
   (a64-rofs base dn bn ixn s) (le32 (base | (ixn << 16 | (3 << 13 | (s << 12 | (bn << 5 | dn))))))
   (a64-ldx d base index scale disp)
      (a64-rof? scale disp 8 ? (a64-rofs 0xF8600800 (rn d) (rn base) (rn index) (scale = 8 ? 1 0))   ; ldr Xd, [base, index, lsl #3]
         (rn d @ dn (catall [(a64-addsh dn (rn base) (rn index) (a64-shiftamt scale)) (a64-ld d d disp)])))
   (a64-leax d base index scale disp)
      (rn d @ dn (catall [(a64-addsh dn (rn base) (rn index) (a64-shiftamt scale)) (disp = 0 ? () (a64-addsub-imm 'add d d disp))]))
   (a64-stx base index scale disp s)
      (a64-rof? scale disp 8 ? (a64-rofs 0xF8200800 (rn s) (rn base) (rn index) (scale = 8 ? 1 0))   ; str Xs, [base, index, lsl #3]
         (catall [(a64-addsh 16 (rn base) (rn index) (a64-shiftamt scale))
                  (a64-mem-r 0xF8000000 0xF9000000 (rn s) 16 disp)]))
   (a64-fldx d base index scale disp)
      (a64-rof? scale disp 8 ? (a64-rofs 0xFC600800 (frn d) (rn base) (rn index) (scale = 8 ? 1 0))  ; ldr Dd, [base, index, lsl #3]
         (catall [(a64-addsh 16 (rn base) (rn index) (a64-shiftamt scale)) (a64-mem-raw 0xFC400000 0xFD400000 8 (frn d) 16 disp)]))
   (a64-fstx base index scale disp s)
      (a64-rof? scale disp 8 ? (a64-rofs 0xFC200800 (frn s) (rn base) (rn index) (scale = 8 ? 1 0))  ; str Ds, [base, index, lsl #3]
         (catall [(a64-addsh 16 (rn base) (rn index) (a64-shiftamt scale)) (a64-mem-raw 0xFC000000 0xFD000000 8 (frn s) 16 disp)]))
   (a64-fldsx d base index scale disp)
      (a64-rof? scale disp 4 ? (a64-rofs 0xBC600800 (frn d) (rn base) (rn index) (scale = 4 ? 1 0))  ; ldr Sd, [base, index, lsl #2]
         (catall [(a64-addsh 16 (rn base) (rn index) (a64-shiftamt scale)) (a64-mem-raw 0xBC400000 0xBD400000 4 (frn d) 16 disp)]))
   (a64-fstsx base index scale disp s)
      (a64-rof? scale disp 4 ? (a64-rofs 0xBC200800 (frn s) (rn base) (rn index) (scale = 4 ? 1 0))  ; str Ss, [base, index, lsl #2]
         (catall [(a64-addsh 16 (rn base) (rn index) (a64-shiftamt scale)) (a64-mem-raw 0xBC000000 0xBD000000 4 (frn s) 16 disp)]))
   ;; csel Xd, Xs, Xd, cond; d = s scares
   (a64-cmov cond d s) (: dn (rn d) sn (rn s) (dn = sn ? (scare 'cmov-alias d) (a64-wsel dn sn dn cond)))
   (a64-ldxb d base index scale disp)
      (rn d @ dn (catall [(a64-addsh dn (rn base) (rn index) (a64-shiftamt scale))
                          (a64-mem-raw 0x38400000 0x39400000 1 dn dn disp)]))              ; ldrb/ldurb Wd, [Xd, #disp]
   (a64-stxb base index scale disp s)
      (catall [(a64-addsh 16 (rn base) (rn index) (a64-shiftamt scale))
                (a64-mem-raw 0x38000000 0x39000000 1 (rn s) 16 disp)])                    ; strb/sturb Ws, [x16, #disp]

   ;; fp: fN is vN. the two-address IR repeats d as the first source
   a64-fregs (fregs 32)
   (frn r) (look a64-fregs r 'badfreg)
   a64-fp3 {'addsd 0x1E602800 'subsd 0x1E603800 'mulsd 0x1E600800 'divsd 0x1E601800
            'addss 0x1E202800 'subss 0x1E203800 'mulss 0x1E200800 'divss 0x1E201800}
   (a64-fp3op op d s) (: dn (frn d) sn (frn s) (le32 (peep a64-fp3 op 0 | (sn << 16 | (dn << 5 | dn)))))     ; Dd = Dd OP Ds
   (a64-fmov  d s) (: dn (frn d) sn (frn s) (le32 (0x1E604000 | (sn << 5 | dn))))           ; fmov Dd, Ds
   (a64-fcmp  a b) (: an (frn a) bn (frn b) (le32 (0x1E602000 | (bn << 16 | an << 5))))   ; fcmp Da, Db; unordered sets V
   (a64-fcmps a b) (: an (frn a) bn (frn b) (le32 (0x1E202000 | (bn << 16 | an << 5))))   ; fcmp Sa, Sb
   (a64-scvtf d g) (: dn (frn d) gn (rn g) (le32 (0x9E620000 | (gn << 5 | dn))))            ; scvtf Dd, Xg
   (a64-fcvtzs g d) (: gn (rn g) dn (frn d) (le32 (0x9E780000 | (dn << 5 | gn))))           ; fcvtzs Xg, Dd
   (a64-fmovxr d g) (: dn (frn d) gn (rn g) (le32 (0x9E670000 | (gn << 5 | dn))))           ; fmov Dd, Xg
   (a64-fmovrx g d) (: gn (rn g) dn (frn d) (le32 (0x9E660000 | (dn << 5 | gn))))           ; fmov Xg, Dd
   (a64-scvtfs d g) (: dn (frn d) gn (rn g) (le32 (0x9E220000 | (gn << 5 | dn))))           ; scvtf Sd, Xg
   (a64-fcvtzss g d) (: gn (rn g) dn (frn d) (le32 (0x9E380000 | (dn << 5 | gn))))          ; fcvtzs Xg, Sd
   (a64-fmovsw d g) (: dn (frn d) gn (rn g) (le32 (0x1E270000 | (gn << 5 | dn))))           ; fmov Sd, Wg
   (a64-fmovws g d) (: gn (rn g) dn (frn d) (le32 (0x1E260000 | (dn << 5 | gn))))           ; fmov Wg, Sd
   (a64-fst base disp s) (a64-mem-raw 0xFC000000 0xFD000000 8 (frn s) (rn base) disp)   ; STR/STUR Ds, [base, #disp]
   (a64-fld d base disp) (a64-mem-raw 0xFC400000 0xFD400000 8 (frn d) (rn base) disp)   ; LDR/LDUR Dd, [base, #disp]
   (a64-fcvt-widen  d s) (: dn (frn d) sn (frn s) (le32 (0x1E22C000 | (sn << 5 | dn))))            ; fcvt Dd, Ss
   (a64-fcvt-narrow d s) (: dn (frn d) sn (frn s) (le32 (0x1E624000 | (sn << 5 | dn))))            ; fcvt Sd, Ds
   (a64-fsts base disp s) (a64-mem-raw 0xBC000000 0xBD000000 4 (frn s) (rn base) disp)  ; STR/STUR Ss, [base, #disp]
   (a64-flds d base disp) (a64-mem-raw 0xBC400000 0xBD400000 4 (frn d) (rn base) disp)  ; LDR/LDUR Sd, [base, #disp]
   (a64-xorpd d s) (: dn (frn d) sn (frn s) (le32 (0x2E201C00 | (sn << 16 | (dn << 5 | dn)))))   ; eor Vd.8B, Vd.8B, Vs.8B

   ;; the system lane, for kernels. MRS/MSR and tlbi/ic/dc/at share one encoding: head 1101010100,
   ;; L (1 = read), and the selector op0:op1:crn:crm:op2 at [20:5] -- op0 2 or 3 a register, 1 a sys op
   (sreg o0 o1 cn cm o2) (o0 << 19 | (o1 << 16 | (cn << 12 | (cm << 8 | o2 << 5))))
   a64-sysregs {'sctlr_el1 (sreg 3 0 1 0 0) 'cpacr_el1 (sreg 3 0 1 0 2)
                'ttbr0_el1 (sreg 3 0 2 0 0) 'ttbr1_el1 (sreg 3 0 2 0 1)
                'tcr_el1 (sreg 3 0 2 0 2)
                'spsr_el1 (sreg 3 0 4 0 0) 'elr_el1 (sreg 3 0 4 0 1)
                'currentel (sreg 3 0 4 2 2)
                'esr_el1 (sreg 3 0 5 2 0) 'far_el1 (sreg 3 0 6 0 0)
                'par_el1 (sreg 3 0 7 4 0) 'mair_el1 (sreg 3 0 10 2 0)
                'vbar_el1 (sreg 3 0 12 0 0) 'mpidr_el1 (sreg 3 0 0 0 5)
                'ctr_el0 (sreg 3 3 0 0 1)
                'cntfrq_el0 (sreg 3 3 14 0 0) 'cntpct_el0 (sreg 3 3 14 0 1)
                'cntp_tval_el0 (sreg 3 3 14 2 0) 'cntp_ctl_el0 (sreg 3 3 14 2 1)
                'sp_el0 (sreg 3 0 4 1 0) 'sp_el1 (sreg 3 4 4 1 0) 'spsel (sreg 3 0 4 2 0)
                'daif (sreg 3 3 4 2 1) 'nzcv (sreg 3 3 4 2 0) 'fpcr (sreg 3 3 4 4 0) 'fpsr (sreg 3 3 4 4 1)
                'pan (sreg 3 0 4 2 3) 'uao (sreg 3 0 4 2 4) 'dit (sreg 3 3 4 2 5) 'ssbs (sreg 3 3 4 2 6)
                'tco (sreg 3 3 4 2 7) 'tpidr_el0 (sreg 3 3 13 0 2) 'tpidrro_el0 (sreg 3 3 13 0 3)
                'tpidr_el1 (sreg 3 0 13 0 4) 'tpidr_el2 (sreg 3 4 13 0 2) 'contextidr_el1 (sreg 3 0 13 0 1)
                'midr_el1 (sreg 3 0 0 0 0) 'revidr_el1 (sreg 3 0 0 0 6) 'id_aa64pfr0_el1 (sreg 3 0 0 4 0)
                'id_aa64pfr1_el1 (sreg 3 0 0 4 1) 'id_aa64zfr0_el1 (sreg 3 0 0 4 4)
                'id_aa64smfr0_el1 (sreg 3 0 0 4 5) 'id_aa64dfr0_el1 (sreg 3 0 0 5 0)
                'id_aa64dfr1_el1 (sreg 3 0 0 5 1) 'id_aa64isar0_el1 (sreg 3 0 0 6 0)
                'id_aa64isar1_el1 (sreg 3 0 0 6 1) 'id_aa64isar2_el1 (sreg 3 0 0 6 2)
                'id_aa64mmfr0_el1 (sreg 3 0 0 7 0) 'id_aa64mmfr1_el1 (sreg 3 0 0 7 1)
                'id_aa64mmfr2_el1 (sreg 3 0 0 7 2) 'id_aa64mmfr3_el1 (sreg 3 0 0 7 3)
                'ccsidr_el1 (sreg 3 1 0 0 0) 'clidr_el1 (sreg 3 1 0 0 1) 'csselr_el1 (sreg 3 2 0 0 0)
                'dczid_el0 (sreg 3 3 0 0 7) 'cntvct_el0 (sreg 3 3 14 0 2) 'cntkctl_el1 (sreg 3 0 14 1 0)
                'cntp_cval_el0 (sreg 3 3 14 2 2) 'cntv_tval_el0 (sreg 3 3 14 3 0)
                'cntv_ctl_el0 (sreg 3 3 14 3 1) 'cntv_cval_el0 (sreg 3 3 14 3 2)
                'cntvoff_el2 (sreg 3 4 14 0 3) 'cnthctl_el2 (sreg 3 4 14 1 0) 'mdscr_el1 (sreg 2 0 0 2 2)
                'oslar_el1 (sreg 2 0 1 0 4) 'osdlr_el1 (sreg 2 0 1 3 4) 'mdccsr_el0 (sreg 2 3 0 1 0)
                'pmcr_el0 (sreg 3 3 9 12 0) 'pmuserenr_el0 (sreg 3 3 9 14 0) 'afsr0_el1 (sreg 3 0 5 1 0)
                'afsr1_el1 (sreg 3 0 5 1 1) 'amair_el1 (sreg 3 0 10 3 0) 'disr_el1 (sreg 3 0 12 1 1)
                'zcr_el1 (sreg 3 0 1 2 0) 'rgsr_el1 (sreg 3 0 1 0 5) 'gcr_el1 (sreg 3 0 1 0 6)
                'tfsr_el1 (sreg 3 0 5 6 0) 'tfsre0_el1 (sreg 3 0 5 6 1) 'apiakeylo_el1 (sreg 3 0 2 1 0)
                'apiakeyhi_el1 (sreg 3 0 2 1 1) 'apibkeylo_el1 (sreg 3 0 2 1 2)
                'apibkeyhi_el1 (sreg 3 0 2 1 3) 'apdakeylo_el1 (sreg 3 0 2 2 0)
                'apdakeyhi_el1 (sreg 3 0 2 2 1) 'apdbkeylo_el1 (sreg 3 0 2 2 2)
                'apdbkeyhi_el1 (sreg 3 0 2 2 3) 'apgakeylo_el1 (sreg 3 0 2 3 0)
                'apgakeyhi_el1 (sreg 3 0 2 3 1) 'hcr_el2 (sreg 3 4 1 1 0) 'mdcr_el2 (sreg 3 4 1 1 1)
                'cptr_el2 (sreg 3 4 1 1 2) 'hstr_el2 (sreg 3 4 1 1 3) 'sctlr_el2 (sreg 3 4 1 0 0)
                'ttbr0_el2 (sreg 3 4 2 0 0) 'tcr_el2 (sreg 3 4 2 0 2) 'vttbr_el2 (sreg 3 4 2 1 0)
                'vtcr_el2 (sreg 3 4 2 1 2) 'spsr_el2 (sreg 3 4 4 0 0) 'elr_el2 (sreg 3 4 4 0 1)
                'esr_el2 (sreg 3 4 5 2 0) 'far_el2 (sreg 3 4 6 0 0) 'mair_el2 (sreg 3 4 10 2 0)
                'vbar_el2 (sreg 3 4 12 0 0) 'vpidr_el2 (sreg 3 4 0 0 0) 'vmpidr_el2 (sreg 3 4 0 0 5)
                'icc_pmr_el1 (sreg 3 0 4 6 0) 'icc_dir_el1 (sreg 3 0 12 11 1)
                'icc_rpr_el1 (sreg 3 0 12 11 3) 'icc_sgi1r_el1 (sreg 3 0 12 11 5)
                'icc_iar1_el1 (sreg 3 0 12 12 0) 'icc_eoir1_el1 (sreg 3 0 12 12 1)
                'icc_hppir1_el1 (sreg 3 0 12 12 2) 'icc_bpr1_el1 (sreg 3 0 12 12 3)
                'icc_ctlr_el1 (sreg 3 0 12 12 4) 'icc_sre_el1 (sreg 3 0 12 12 5)
                'icc_igrpen1_el1 (sreg 3 0 12 12 7) 'icc_sre_el2 (sreg 3 4 12 9 5)
                'actlr_el1 (sreg 3 0 1 0 1) 'aidr_el1 (sreg 3 1 0 0 7) 'isr_el1 (sreg 3 0 12 1 0)
                'hpfar_el2 (sreg 3 4 6 0 4) 'dacr32_el2 (sreg 3 4 3 0 0) 'ifsr32_el2 (sreg 3 4 5 0 1)
                'fpexc32_el2 (sreg 3 4 5 3 0) 'dbgvcr32_el2 (sreg 2 4 0 7 0)
                'spsr_irq (sreg 3 4 4 3 0) 'spsr_abt (sreg 3 4 4 3 1) 'spsr_und (sreg 3 4 4 3 2) 'spsr_fiq (sreg 3 4 4 3 3)
                'mdccint_el1 (sreg 2 0 0 2 0) 'oslsr_el1 (sreg 2 0 1 1 4) 'dbgdtrrx_el0 (sreg 2 3 0 5 0)
                'dbgauthstatus_el1 (sreg 2 0 7 14 6)
                'pmcntenset_el0 (sreg 3 3 9 12 1) 'pmcntenclr_el0 (sreg 3 3 9 12 2) 'pmovsclr_el0 (sreg 3 3 9 12 3)
                'pmswinc_el0 (sreg 3 3 9 12 4) 'pmselr_el0 (sreg 3 3 9 12 5) 'pmceid0_el0 (sreg 3 3 9 12 6)
                'pmceid1_el0 (sreg 3 3 9 12 7) 'pmccntr_el0 (sreg 3 3 9 13 0) 'pmxevtyper_el0 (sreg 3 3 9 13 1)
                'pmxevcntr_el0 (sreg 3 3 9 13 2) 'pmovsset_el0 (sreg 3 3 9 14 3) 'pmccfiltr_el0 (sreg 3 3 14 15 7)
                'pmintenset_el1 (sreg 3 0 9 14 1) 'pmintenclr_el1 (sreg 3 0 9 14 2)}
   ;; the numbered families: dbgb/w v/c r<n>_el1 (n < 16), pmevcntr/pmevtyper<n>_el0 (n < 31)
   (a64-sfam s)
    (: tl (snip s (#s - 4) #s)
       (num p) (snip s #p (#s - 4) @ d
                  (starts? s p && 0 < #d < 3 && foldl (a \ c \ a && 48 <= c <= 57) 1 (chars d) ?
                     (foldl (a \ c \ a * 10 + c - 48) 0 (chars d))))
       (dbg p o2) (tl = "_el1" ? (num p @ n (charm? n && n < 16 ? (sreg 2 0 0 n o2))))
       (pmev p cm) (tl = "_el0" ? (num p @ n (charm? n && n < 31 ? (sreg 3 3 14 (cm + (n >> 3)) (n & 7)))))
       (#s < 8 ? () (dbg "dbgbvr" 4 || dbg "dbgbcr" 5 || dbg "dbgwvr" 6 || dbg "dbgwcr" 7 ||
                     pmev "pmevcntr" 8 || pmev "pmevtyper" 12)))
   ;; gas's generic s<op0>_<op1>_c<n>_c<m>_<op2> names the rest (s0_3_c1_c0_1 is wfit). any case reads
   (a64-sgen s)
    (: (parts i j acc) (? (#s <= j) (rev ((snip s i j) . acc))
                          (s j = 95) (parts (j + 1) (j + 1) ((snip s i j) . acc))
                          (parts i (j + 1) acc))
       (dec t) (0 < #t && foldl (a \ c \ a && 48 <= c <= 57) 1 (chars t) ?
                  (foldl (a \ c \ a * 10 + c - 48) 0 (chars t)) -1)
       (crx t) (1 < #t && t 0 = 99 ? (dec (snip t 1 #t)) -1)
       ps (1 < #s && s 0 = 115 ? (parts 1 1 ()) ())
       (#ps != 5 ? ()
          (: o0 (dec <ps) o1 (dec (ps 1)) cn (crx (ps 2)) cm (crx (ps 3)) o2 (dec (ps 4))
             (0 <= o0 <= 3 && 0 <= o1 <= 7 && 0 <= cn <= 15 && 0 <= cm <= 15 && 0 <= o2 <= 7 ?
                (sreg o0 o1 cn cm o2) ()))))
   (a64-sysreg nm)
    (: s (lower (show nm))
       (peep a64-sysregs (name s) () @ v
          (charm? v ? v (a64-sgen s @ k (charm? k ? k (a64-sfam s @ f (charm? f ? f (scare 'badsysreg nm))))))))
   ;; mrs of a write-only register by name scares
   a64-wo {'oslar_el1 1 'icc_dir_el1 1 'icc_sgi1r_el1 1 'icc_eoir1_el1 1 'pmswinc_el0 1}
   (a64-mrs d nm) (? (peep a64-wo (name (lower (show nm))) ()) (scare 'badsysreg-wo nm)
                     (le32 (0xD5200000 | (a64-sysreg nm | a64-sysrt d))))  ; MRS Xd, <reg>
   (a64-msr nm s) (le32 (0xD5000000 | (a64-sysreg nm | a64-sysrt s)))  ; MSR <reg>, Xs

   ;; MSR (immediate) to a pstate field: op1/op2 name it, the imm4 rides crm
   a64-pstate {'spsel '(0 5) 'daifset '(3 6) 'daifclr '(3 7)}
   (a64-msri fld imm)
      (peep a64-pstate (name (lower (show fld))) () @ r
         (two? r ? 0 (scare 'badpstate fld),
          imm >= 0 && imm <= 15 ? 0 (scare 'a64-pstate-imm imm),
          le32 (0xD500401F | (<r << 16 | (imm << 8 | <>r << 5)))))

   ;; isb takes only sy, so it is nullary
   a64-barrier-opts {'oshld 1 'oshst 2 'osh 3 'nshld 5 'nshst 6 'nsh 7
                     'ishld 9 'ishst 10 'ish 11 'ld 13 'st 14 'sy 15}
   (a64-barrier base opt) (le32 (base | look a64-barrier-opts opt 'badbarrier << 8))
   (a64-dsb opt) (a64-barrier 0xD503309F opt)
   (a64-dmb opt) (a64-barrier 0xD50330BF opt)

   ;; one table per instruction: the operand names nearly collide (dc ivac, ic ivau). the
   ;; whole-system forms take zr
   a64-tlbi-ops {'vmalle1 (sreg 1 0 8 7 0) 'vmalle1is (sreg 1 0 8 3 0)
                 'vae1 (sreg 1 0 8 7 1) 'vae1is (sreg 1 0 8 3 1)
                 'aside1is (sreg 1 0 8 3 2) 'alle1 (sreg 1 4 8 7 4)
                 'aside1 (sreg 1 0 8 7 2) 'vale1 (sreg 1 0 8 7 5) 'vale1is (sreg 1 0 8 3 5)
                 'vaae1is (sreg 1 0 8 3 3) 'vaale1is (sreg 1 0 8 3 7)
                 'vmalle1os (sreg 1 0 8 1 0) 'vae1os (sreg 1 0 8 1 1) 'vale1os (sreg 1 0 8 1 5)
                 'aside1os (sreg 1 0 8 1 2) 'alle2 (sreg 1 4 8 7 0) 'alle2is (sreg 1 4 8 3 0)
                 'alle1is (sreg 1 4 8 3 4) 'vmalls12e1 (sreg 1 4 8 7 6) 'vmalls12e1is (sreg 1 4 8 3 6)
                 'ipas2e1is (sreg 1 4 8 0 1) 'vale2is (sreg 1 4 8 3 5) 'vae2 (sreg 1 4 8 7 1)
                 'vaae1os (sreg 1 0 8 1 3) 'vaale1os (sreg 1 0 8 1 7) 'ipas2le1is (sreg 1 4 8 0 5)
                 'vae2is (sreg 1 4 8 3 1) 'ripas2e1is (sreg 1 4 8 0 2) 'ripas2le1is (sreg 1 4 8 0 6)
                 ;; the ranges (v8.4): crm 6 local, 2 inner shareable, 5 outer
                 'rvae1 (sreg 1 0 8 6 1) 'rvaae1 (sreg 1 0 8 6 3) 'rvale1 (sreg 1 0 8 6 5) 'rvaale1 (sreg 1 0 8 6 7)
                 'rvae1is (sreg 1 0 8 2 1) 'rvaae1is (sreg 1 0 8 2 3) 'rvale1is (sreg 1 0 8 2 5) 'rvaale1is (sreg 1 0 8 2 7)
                 'rvae1os (sreg 1 0 8 5 1) 'rvaae1os (sreg 1 0 8 5 3) 'rvale1os (sreg 1 0 8 5 5) 'rvaale1os (sreg 1 0 8 5 7)
                 'rvae2is (sreg 1 4 8 2 1) 'rvale2is (sreg 1 4 8 2 5)
                 'ipas2e1 (sreg 1 4 8 4 1) 'ipas2le1 (sreg 1 4 8 4 5) 'ripas2e1 (sreg 1 4 8 4 2) 'ripas2le1 (sreg 1 4 8 4 6)
                 'ipas2e1os (sreg 1 4 8 4 0) 'ipas2le1os (sreg 1 4 8 4 4) 'ripas2e1os (sreg 1 4 8 4 3) 'ripas2le1os (sreg 1 4 8 4 7)
                 'vmalls12e1os (sreg 1 4 8 1 6) 'alle1os (sreg 1 4 8 1 4) 'vale2 (sreg 1 4 8 7 5)
                 'vaae1 (sreg 1 0 8 7 3) 'vaale1 (sreg 1 0 8 7 7)
                 'alle2os (sreg 1 4 8 1 0) 'vae2os (sreg 1 4 8 1 1) 'vale2os (sreg 1 4 8 1 5)
                 'rvae2 (sreg 1 4 8 6 1) 'rvale2 (sreg 1 4 8 6 5) 'rvae2os (sreg 1 4 8 5 1) 'rvale2os (sreg 1 4 8 5 5)
                 'alle3 (sreg 1 6 8 7 0) 'alle3is (sreg 1 6 8 3 0) 'alle3os (sreg 1 6 8 1 0)
                 'vae3 (sreg 1 6 8 7 1) 'vae3is (sreg 1 6 8 3 1) 'vae3os (sreg 1 6 8 1 1)
                 'vale3 (sreg 1 6 8 7 5) 'vale3is (sreg 1 6 8 3 5) 'vale3os (sreg 1 6 8 1 5)}
   a64-ic-ops {'iallu (sreg 1 0 7 5 0) 'ialluis (sreg 1 0 7 1 0) 'ivau (sreg 1 3 7 5 1)}
   a64-dc-ops {'ivac (sreg 1 0 7 6 1) 'zva (sreg 1 3 7 4 1) 'cvac (sreg 1 3 7 10 1)
               'cvau (sreg 1 3 7 11 1) 'civac (sreg 1 3 7 14 1)
               'cvap (sreg 1 3 7 12 1) 'cvadp (sreg 1 3 7 13 1) 'isw (sreg 1 0 7 6 2)
               'csw (sreg 1 0 7 10 2) 'cisw (sreg 1 0 7 14 2) 'gva (sreg 1 3 7 4 3) 'gzva (sreg 1 3 7 4 4)}
   a64-at-ops {'s1e1r (sreg 1 0 7 8 0) 's1e1w (sreg 1 0 7 8 1)}
   (a64-sysrt t) (t = 'zr ? 31 (rn t))
   (a64-sys tab bad op t) (le32 (0xD5000000 | (look tab op bad | a64-sysrt t)))

   ;; base | imm16 << 5. dbrk is a64's hlt (hlt #0xf000 semihosts), named apart from x86's hlt.
   ;; udf is the imm16 alone
   (a64-exc base imm)
      (imm >= 0 && imm <= 65535 ? 0 (scare 'a64-exc-imm imm),
       le32 (base | imm << 5))
   (a64-udf imm) (imm >= 0 && imm <= 65535 ? 0 (scare 'a64-exc-imm imm), le32 imm)

   a64-emitters (emsof
        [('li . a64-li) ('mov . a64-mov) ('cmp . a64-cmp) ('imul . a64-imul)
          ('ld . a64-ld) ('st . a64-st)
          ('ld1 . a64-ld1) ('ld2 . a64-ld2) ('ld4 . a64-ld4)
          ('st1 . a64-st1) ('st2 . a64-st2) ('st4 . a64-st4)
          ('ldu1 . a64-ldu1) ('ldu2 . a64-ldu2) ('ldu4 . a64-ldu4)
          ('sx1 . a64-sx 1) ('sx2 . a64-sx 2) ('sx4 . a64-sx 4)
          ('zx1 . a64-zx 1) ('zx2 . a64-zx 2) ('zx4 . a64-zx 4)
          ('shlv . a64-shiftv 'shlv) ('shrv . a64-shiftv 'shrv) ('sarv . a64-shiftv 'sarv)
          ('rorv . a64-shiftv 'rorv) ('rorv4 . a64-shiftv 'rorv4)
          ('shl . a64-shift 'shl) ('shr . a64-shift 'shr) ('sar . a64-shift 'sar)
          ('lsl . a64-shs 'shl) ('lsr . a64-shs 'shr) ('asr . a64-shs 'sar) ('mvn . a64-mvn)
          ('uxtb . a64-zxs 1) ('uxth . a64-zxs 2) ('uxtw . a64-zxs 4)
          ('sxtb . a64-sxs 1) ('sxth . a64-sxs 2) ('sxtw . a64-sxs 4)
          ('rol . a64-shift 'rol) ('ror . a64-shift 'ror) ('ror4 . a64-shift 'ror4)
          ('lea . a64-lea) ('lean . a64-lea)
          ('push . a64-push) ('pop . a64-pop) ('frpush . a64-frpush) ('frpop . a64-frpop) ('cbr . a64-cbr) ('tbr . a64-tbr) ('afix . a64-afix)
          ('neg . a64-neg) ('not . a64-not) ('inc . a64-inc) ('dec . a64-dec) ('decm . a64-decm)
          ('jmp . a64-jmp) ('br . a64-br) ('jmpr . a64-jmpr) ('jmpt . a64-jmpt) ('callr . a64-callr)
          ('mulo . a64-mulo) ('mulh . a64-mulh) ('umulh . a64-umulh) ('set . a64-set) ('test . a64-test)
          ('div . a64-div) ('rem . a64-rem) ('udiv . a64-udiv) ('urem . a64-urem)
          ('a128 . a64-a128) ('s128 . a64-s128)
          ('m128 . a64-m128) ('mw128 . a64-mw128)
          ('a128r . a64-a128r) ('s128r . a64-s128r) ('m128r . a64-m128r)
          ('mw128r . a64-mw128r) ('c128r . a64-c128r) ('c128 . a64-c128)
          ('shl128 . a64-shl128) ('shr128 . a64-shr128) ('sar128 . a64-sar128)
          ('shl128v . a64-shl128v) ('shr128v . a64-shr128v) ('sar128v . a64-sar128v)
          ('dv128 . a64-dv128) ('rm128 . a64-rm128)
          ('sx128 . a64-sx128) ('n128 . a64-n128)
          ('inc128 . a64-inc128) ('dec128 . a64-dec128)
          ('ldx . a64-ldx) ('stx . a64-stx) ('leax . a64-leax)
          ('ldxb . a64-ldxb) ('stxb . a64-stxb)
          ('ldsdx . a64-fldx) ('stsdx . a64-fstx) ('ldssx . a64-fldsx) ('stssx . a64-fstsx)
          ('cmov . a64-cmov)
          ('call . a64-call) ('la . a64-la) ('lar . a64-lar) ('lia . a64-lia)
          ('movsd . a64-fmov) ('movapd . a64-fmov) ('movss . a64-fmov)
          ('addsd . a64-fp3op 'addsd) ('subsd . a64-fp3op 'subsd)
          ('mulsd . a64-fp3op 'mulsd) ('divsd . a64-fp3op 'divsd)
          ('ucomisd . a64-fcmp) ('ucomiss . a64-fcmps) ('cvtsi2sd . a64-scvtf) ('cvttsd2si . a64-fcvtzs)
          ('addss . a64-fp3op 'addss) ('subss . a64-fp3op 'subss)
          ('mulss . a64-fp3op 'mulss) ('divss . a64-fp3op 'divss)
          ('cvtsi2ss . a64-scvtfs) ('cvttss2si . a64-fcvtzss) ('movdxr . a64-fmovsw) ('movdrx . a64-fmovws)
          ('movqxr . a64-fmovxr) ('movqrx . a64-fmovrx)
          ('stsd . a64-fst) ('ldsd . a64-fld) ('stss . a64-fsts) ('ldss . a64-flds)
          ('cvtss2sd . a64-fcvt-widen) ('cvtsd2ss . a64-fcvt-narrow)
          ('xorpd . a64-xorpd)
          ('raw . 1)
          ('mrs . a64-mrs) ('msr . a64-msr) ('msri . a64-msri)
          ('dsb . a64-dsb) ('dmb . a64-dmb)
          ('tlbi . a64-sys a64-tlbi-ops 'badtlbi)
          ('ic . a64-sys a64-ic-ops 'badic)
          ('dc . a64-sys a64-dc-ops 'baddc)
          ('at . a64-sys a64-at-ops 'badat)
          ('brk . a64-exc 0xD4200000) ('dbrk . a64-exc 0xD4400000)        ; brk / hlt
          ('hvc . a64-exc 0xD4000002) ('smc . a64-exc 0xD4000003)
          ('udf . a64-udf)
          ('isb . le32 0xD5033FDF)                          ; isb sy
          ('wfi . le32 0xD503207F) ('wfe . le32 0xD503205F)
          ('eret . le32 0xD69F03E0)
          ('ret . le32 0xD65F03C0)                          ; ret x30
          ('sys . le32 0xD4000001)                          ; svc #0
           ; netbsd/aarch64 takes the syscall number from svc's immediate, with no
           ; indirect syscall: a runtime number goes through a table of these
          ('svcn . a64-exc 0xD4000001)                    ; svc #imm
          ('nop . le32 0xD503201F)
          ('trap . le32 0xD4200000)])                       ; brk #0
   _ (map (k \ emrow a64-emitters k (a64-aluop k)) (keys a64-alu))
   (a64-lower ins) (lower-via @ f (lit? f ? (f a64-emitters ins) (scare 'holo-bake-stale 'lower-via)))

   ;; the offset (target - site)/4 ors into the base word aux
   (a64-patch kind target0 site width aux0)
      (: af (elem kind a64-afixk)                              ; an address fix carries its addend
         target (af ? (target0 + afix-ad aux0) target0) aux (af ? (afix-w aux0) aux0)
         rb (target - site)
         rel (rb // 4)
         (? (kind = 'b26) (le32 (aux | rel & 67108863))             ; bits[25:0]
            (elem kind '(b19 ld19)) (-262144 <= rel < 262144 ? (le32 (aux | (rel & 524287) << 5))   ; bits[23:5]
                             (scare 'a64-branch-range rel))
            (kind = 'b14) (-8192 <= rel < 8192 ? (le32 (aux | (rel & 16383) << 5))   ; bits[18:5]
                             (scare 'a64-branch-range rel))
            (kind = 'adrp21) (: pg (target // 4096 - site // 4096)   ; page delta, immlo[30:29] immhi[23:5]
                                (le32 (aux | ((pg & 3) << 29 | (pg >> 2 & 524287) << 5))))
            (kind = 'addlo12) (le32 (aux | target % 4096 << 10))
            ; a load/store's imm12 counts units of its access width
            (elem kind '(lo12s1 lo12s2 lo12s4 lo12s8 lo12s16))
             (le32 (aux | (target % 4096) // (kind @ 'lo12s1 1 'lo12s2 2 'lo12s4 4 'lo12s8 8 16) << 10))
            (kind = 'adr21) (-1048576 <= rb < 1048576 ?               ; bytes, immlo[30:29] immhi[23:5]
                               (rb & 2097151 @ u (le32 (aux | ((u & 3) << 29 | (u >> 2) << 5))))
                               (scare 'a64-branch-range rb))
            (kind = 'abs64) (le64 (target + aux))                    ; aux the byte addend
            (scare 'badfix kind)))

   ;; the linker's door. rela: bs holds the base word. () past the field's reach
   (a64-refix kind bs target site width)
    (: wd (bs 0 + (bs 1 << 8) + (bs 2 << 16) + (bs 3 << 24))
       rb (target - site) pg (target // 4096 - site // 4096)
       (? (kind = 'b26 && !(-134217728 <= rb <= 134217727)) ()
          (kind = 'adrp21 && !(-1048576 <= pg <= 1048575)) ()
          (kind = 'adr21 && !(-1048576 <= rb <= 1048575)) ()
          (a64-patch kind target site width wd)))

   a64 {}
   (pin a64 'lower a64-lower,
    pin a64 'patch a64-patch,
    pin a64 'refix a64-refix,
    pin a64 'nop '(31 32 3 213),           ; nop d503201f
    defbackend 'a64 a64))
) ; module 'holo
