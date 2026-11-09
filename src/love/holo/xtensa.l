; xtensa -- the xtensa LX backend for holo (the esp32's LX6), on the CALL0 abi: a0 the return
; address, a1 sp, a2..a7 the arguments and a2/a3 the answer, a12..a15 callee-saved. every
; instruction is a 24-bit little-endian word; none of the 16-bit density forms yet.
; what xtensa lacks:
;   * flags      -> cmp/test keep their operands, br and set compare inside the branch
;   * push/pop   -> sp moves by 16, the abi's grain
;   * a far imm  -> li builds any word from movi, slli and addmi/addi, no literal; la is moon's
;                   aligned literal and (lapool d), an l32r one word back
; a8 is holo's own scratch, outside the IR's names.

(module 'holo
(: xt-regs {'lr 0 'sp 1 'fp 15
            'r0 2 'r1 3 'r2 4 'r3 5 'r4 6 'r5 7
            'r6 9 'r7 10 'r8 11 'r9 12 'r10 13 'r11 14}
   (xn r) (r = 'x8 ? 8 (look xt-regs r 'badreg))

   (x24 w) [(w & 255) (w >> 8 & 255) (w >> 16 & 255)]
   (x-rrr op2 op1 r s t) (x24 (op2 << 20 | op1 << 16 | r << 12 | s << 8 | t << 4))
   (x-rri8 r s t imm op0) (x24 ((imm & 255) << 16 | r << 12 | s << 8 | t << 4 | op0))
   (x-bri12 imm s m n) (x24 ((imm & 4095) << 12 | s << 8 | m << 6 | n << 4 | 6))

   (s8? k) (-128 <= k <= 127)
   (sx8 k) (((k & 255) ^ 128) - 128)
   (sx4 k) (((k & 15) ^ 8) - 8)
   (sx12 k) (((k & 4095) ^ 2048) - 2048)

   (x-movi d k) (x-rri8 10 (k >> 8 & 15) d k 2)             ; movi at, -2048..2047
   (x-addi d s k) (x-rri8 12 s d k 2)                       ; addi at, as, -128..127
   (x-addmi d s k) (x-rri8 13 s d k 2)                      ; addmi at, as, (-128..127) << 8
   (x-slli d s c) (x-rrr ((32 - c) >> 4) 1 d s (32 - c & 15))   ; slli ar, as, 1..31
   (x-or d s t) (x-rrr 2 0 d s t)

   ;; any word: v = ((a << 4) + b) << 16 + m << 8 + l, b a signed nibble, m and l signed bytes
   (xt-li-n d v)
      (: l (sx8 v) r ((v - l) >> 8) m (sx8 r) u ((r - m) >> 8) b (sx4 u) a (sx12 ((u - b) >> 4))
         hi (? (-2048 <= u <= 2047) (x-movi d u)
               (catall [(x-movi d a) (x-slli d d 4) (b = 0 ? () (x-addi d d b))]))
         (catall [hi (x-slli d d 16) (m = 0 ? () (x-addmi d d m)) (l = 0 ? () (x-addi d d l))]))
   (xt-li d imm)
      (: v (sx32 imm) dn (xn d)
         (-2048 <= v <= 2047 ? (x-movi dn v) (xt-li-n dn v)))
   (sx32 k) (((k & 4294967295) ^ 2147483648) - 2147483648)

   (xt-mov d s) (reg-eq d s ? () (x-or (xn d) (xn s) (xn s)))
   (reg-eq a b) (xn a = xn b)

   ;; d = s + k in place of a register: addi, addmi, the pair, else k through a8, or through
   ;; d when a8 is s
   (xt-addk dn sn k)
      (: l (sx8 k) m ((k - l) >> 8)
         (? (k = 0) (dn = sn ? () (x-or dn sn sn))
            (s8? k) (x-addi dn sn k)
            (s8? m) (catall [(x-addmi dn sn m) (l = 0 ? () (x-addi dn dn l))])
            (dn = 8 && sn = 8) (scare 'xt-far-off k)
            (sn = 8) (catall [(xt-li-n dn (sx32 k)) (x-rrr 8 0 dn dn 8)])
            (catall [(xt-li-n 8 (sx32 k)) (x-rrr 8 0 dn sn 8)])))

   xt-alu {'add 8 'sub 12 'and 1 'or 2 'xor 3}
   (xt-alu3 op d a b)
      (: dn (xn d) an (xn a)
         (? (reg? b) (x-rrr (xt-alu op) 0 dn an (xn b))
            (op = 'add) (xt-addk dn an (sx32 b))
            (op = 'sub) (xt-addk dn an (sx32 (0 - b)))
            (catall [(xt-li 'x8 b) (x-rrr (xt-alu op) 0 dn an 8)])))
   (xt-rst2 op2 d a b)                                      ; mull, quou, quos, remu, rems
      (: dn (xn d) an (xn a)
         (reg? b ? (x-rrr op2 2 dn an (xn b)) (catall [(xt-li 'x8 b) (x-rrr op2 2 dn an 8)])))

   (xt-neg d) (xn d @ dn (x-rrr 6 0 dn 0 dn))               ; neg ar, at
   (xt-not d) (xn d @ dn (catall [(x-movi 8 -1) (x-rrr 3 0 dn dn 8)]))

   (xt-shift op d c)
      (: dn (xn d) k (c & 31)
         (? (k = 0) ()
            (op = 'shl) (x-slli dn dn k)
            (op = 'sar) (x-rrr (2 + (k >> 4)) 1 dn (k & 15) dn)         ; srai ar, at, sa
            (k <= 15) (x-rrr 4 1 dn k dn)                               ; srli ar, at, 0..15
            (x-rrr (31 - k) (4 + (k >> 4)) dn (k & 15) dn)))            ; extui ar, at, k, 32-k
   ;; ssl/ssr set SAR from the count; sll, srl, sra shift by it
   (xt-shiftv op d c)
      (: dn (xn d) cn (xn c)
         (op @ 'shlv (catall [(x-rrr 4 0 1 cn 0) (x-rrr 10 1 dn dn 0)])
               'shrv (catall [(x-rrr 4 0 0 cn 0) (x-rrr 9 1 dn 0 dn)])
               (catall [(x-rrr 4 0 0 cn 0) (x-rrr 11 1 dn 0 dn)])))

   ;; a rotate right is src over the register twice, by ssai's or ssr's SAR
   (xt-ror4 d c) (: dn (xn d) k (c & 31)
                    (k = 0 ? () (catall [(x-rrr 4 0 4 (k & 15) (k >> 4)) (x-rrr 8 1 dn dn dn)])))
   (xt-rorv4 d c) (: dn (xn d) (catall [(x-rrr 4 0 0 (xn c) 0) (x-rrr 8 1 dn dn dn)]))

   (xt-sext dn sn bit) (x-rrr 2 3 dn sn (bit - 7))           ; sext ar, as, 7..22
   (xt-extui dn tn sh w) (x-rrr (w - 1) (4 + (sh >> 4)) dn (sh & 15) tn)
   (xt-sx w d) (xn d @ dn (w @ 1 (xt-sext dn dn 7) 2 (xt-sext dn dn 15) ()))
   (xt-zx w d) (xn d @ dn (w @ 1 (xt-extui dn dn 0 8) 2 (xt-extui dn dn 0 16) ()))

   ;; lsai: r the op, an unsigned imm8 scaled by the width. past it, the address through a8
   (xt-mem r sh tn base off)
      (: bn (xn base) u (off >> sh)
         (off >= 0 && 0 = off & (1 << sh) - 1 && u <= 255 ?
            (x-rri8 r bn tn u 2)
            (catall [(xt-addk 8 bn off) (x-rri8 r 8 tn 0 2)])))
   (xt-ld d base off) (xt-mem 2 2 (xn d) base off)
   (xt-st base off s) (xt-mem 6 2 (xn s) base off)
   (xt-ldu1 d base off) (xt-mem 0 0 (xn d) base off)
   (xt-ldu2 d base off) (xt-mem 1 1 (xn d) base off)
   (xt-ld2 d base off) (xt-mem 9 1 (xn d) base off)
   (xt-ld1 d base off) (xt-ldu1 d base off + xt-sx 1 d)
   (xt-st1 base off s) (xt-mem 4 0 (xn s) base off)
   (xt-st2 base off s) (xt-mem 5 1 (xn s) base off)

   (xt-lea d base off) (xt-addk (xn d) (xn base) (sx32 off))
   ;; d = base + index * scale + disp: addx2/4/8 shift the index in one op
   (xt-ea dn base index scale)
      (: bn (xn base) in (xn index)
         (scale @ 1 (x-rrr 8 0 dn in bn) 2 (x-rrr 9 0 dn in bn) 4 (x-rrr 10 0 dn in bn) 8 (x-rrr 11 0 dn in bn)
                  (scare 'xt-badscale scale)))
   (xt-leax d base index scale disp) (xt-ea (xn d) base index scale + xt-addk (xn d) (xn d) disp)
   (xt-memx r sh tn base index scale disp) (xt-ea 8 base index scale + xt-mem r sh tn 'x8 disp)
   (xt-ldx d base index scale disp) (xt-memx 2 2 (xn d) base index scale disp)
   (xt-ldxb d base index scale disp) (xt-memx 0 0 (xn d) base index scale disp)
   (xt-ldxh d base index scale disp) (xt-memx 1 1 (xn d) base index scale disp)
   (xt-stx base index scale disp s) (xt-memx 6 2 (xn s) base index scale disp)
   (xt-stxb base index scale disp s) (xt-memx 4 0 (xn s) base index scale disp)

   ;; [base+off] less one, stored, its value against zero
   (xt-decm base off)
      (: bn (xn base)
         (off >= 0 && 0 = off & 3 && off >> 2 <= 255 ? 0 (scare 'xt-decm-far off),
          pin xt-flags 'a 8, pin xt-flags 'b -1,
          catall [(x-rri8 2 bn 8 (off >> 2) 2) (x-addi 8 8 -1) (x-rri8 6 bn 8 (off >> 2) 2)]))
   (xt-push s) (catall [(x-addi 1 1 -16) (x-rri8 6 1 (xn s) 0 2)])
   (xt-pop d) (catall [(x-rri8 2 1 (xn d) 0 2) (x-addi 1 1 16)])

   ;; the last cmp/test: 'a and 'b register numbers, 'b -1 against zero
   xt-flags {}
   (xt-cmp a b)
      (xn a @ an
         (? (reg? b) (pin xt-flags 'a an, pin xt-flags 'b (xn b), ())
            (b = 0) (pin xt-flags 'a an, pin xt-flags 'b -1, ())
            (pin xt-flags 'a 8, pin xt-flags 'b -2, pin xt-flags 'k an, xt-li 'x8 b)))
   (xt-test a b)
      (: an (xn a)
         bs (reg? b ? (x-rrr 1 0 8 an (xn b)) (catall [(xt-li 'x8 b) (x-rrr 1 0 8 an 8)]))
         (pin xt-flags 'a 8, pin xt-flags 'b -1, bs))
   ;; -> [r s t] of the B group's rri8, taken when cond holds; a cmp against an immediate kept
   ;; it in a8 and its register in 'k, so a8 is the right side
   (xt-pair u) (: a (xt-flags 'a) b (xt-flags 'b)
                (? (b = -2) [(xt-flags 'k) 8] (b = -1) [a -1] [a b]))
   (xt-bcc cond a b)
      (cond @ 'eq [1 a b] 'ne [9 a b] 'lt [2 a b] 'ge [10 a b] 'gt [2 b a] 'le [10 b a]
              'below [3 a b] 'ae [11 a b] 'above [3 b a] 'be [11 b a]
              (scare 'xt-badcc cond))
   xt-inv {'eq 'ne 'ne 'eq 'lt 'ge 'ge 'lt 'gt 'le 'le 'gt 'below 'ae 'ae 'below 'above 'be 'be 'above
           's 'ns 'ns 's}
   ;; a branch taken on cond, imm8 bytes past pc + 4; zero's conds by bri12 where there is one,
   ;; else against a8 = 0
   (xt-b cond imm)
      (xt-pair 0 @ [a b]
         (? (b >= 0) (xt-bcc cond a b @ [r s t] (x-rri8 r s t imm 7))
            (cond @ 'eq (x-bri12 imm a 0 1) 'ne (x-bri12 imm a 1 1)
                    ('lt || 's) (x-bri12 imm a 2 1) ('ge || 'ns) (x-bri12 imm a 3 1)
                    'below (cond-never imm) 'ae (cond-always imm)
                    'above (x-bri12 imm a 1 1) 'be (x-bri12 imm a 0 1)
                    (a = 8 ? (scare 'xt-zero-cc cond)
                       (catall [(x-movi 8 0) (xt-bcc cond a 8 @ [r s t] (x-rri8 r s t imm 7))])))))
   (cond-never imm) (x24 0x20F0)                            ; nop
   (cond-always imm) (xt-j18 imm)
   (xt-j18 o) (x24 ((o & 262143) << 6 | 6))

   ;; an inverted hop over the j; a zero cond with its own movi hops from three bytes on
   (xt-br cond label)
      (: hop (xt-b (xt-inv cond) 2)
         (cat hop [(fix 3 'j18 label 0)]))
   ;; Bcond .one ; movi d,0 ; j .end ; .one: movi d,1 ; .end:
   (xt-set cond d)
      (: dn (xn d) b (xt-b cond 5)
         (catall [b (x-movi dn 0) (xt-j18 2) (x-movi dn 1)]))

   (xt-jmp label) [(fix 3 'j18 label 0)]
   (xt-call label) [(fix 3 'call0 label 0)]
   (xt-callr d) (x24 (0xC0 | xn d << 8))                    ; callx0 as
   (xt-jmpr d) (x24 (0xA0 | xn d << 8))                     ; jx as
   (xt-jmpt d tl labs) (xt-jmpr d)
   (xt-lapool d) (x24 (0xFFFF << 8 | xn d << 4 | 1))        ; l32r at, the word just before
   (xt-l32r d label) [(fix 3 'l32r label (xn d))]            ; l32r at, a pooled word behind it

   (xt-div d a b) (xt-rst2 13 d a b)
   (xt-udiv d a b) (xt-rst2 12 d a b)
   (xt-rem d a b t) (xt-rst2 15 d a b)
   (xt-urem d a b t) (xt-rst2 14 d a b)

   xt-emitters (emsof
        [('li . xt-li) ('mov . xt-mov) ('cmp . xt-cmp) ('test . xt-test)
          ('add . xt-alu3 'add) ('sub . xt-alu3 'sub) ('and . xt-alu3 'and)
          ('or . xt-alu3 'or) ('xor . xt-alu3 'xor) ('imul . xt-rst2 8)
          ('umulh . xt-rst2 10) ('mulh . xt-rst2 11)                     ; muluh, mulsh
          ('ror4 . xt-ror4) ('rorv4 . xt-rorv4) ('decm . xt-decm)
          ('div . xt-div) ('rem . xt-rem) ('udiv . xt-udiv) ('urem . xt-urem)
          ('ld . xt-ld) ('ld4 . xt-ld) ('ldu4 . xt-ld) ('st . xt-st) ('st4 . xt-st)
          ('ldu1 . xt-ldu1) ('ldu2 . xt-ldu2) ('ld1 . xt-ld1) ('ld2 . xt-ld2)
          ('st1 . xt-st1) ('st2 . xt-st2)
          ('sx1 . xt-sx 1) ('sx2 . xt-sx 2) ('sx4 . xt-sx 4)
          ('zx1 . xt-zx 1) ('zx2 . xt-zx 2) ('zx4 . xt-zx 4)
          ('shl . xt-shift 'shl) ('shr . xt-shift 'shr) ('sar . xt-shift 'sar)
          ('shlv . xt-shiftv 'shlv) ('shrv . xt-shiftv 'shrv) ('sarv . xt-shiftv 'sarv)
          ('lea . xt-lea) ('lean . xt-lea) ('leax . xt-leax)
          ('ldx . xt-ldx) ('ldxb . xt-ldxb) ('ldxh . xt-ldxh) ('stx . xt-stx) ('stxb . xt-stxb)
          ('push . xt-push) ('pop . xt-pop)
          ('neg . xt-neg) ('not . xt-not)
          ('inc . (d \ xt-addk (xn d) (xn d) 1)) ('dec . (d \ xt-addk (xn d) (xn d) -1))
          ('set . xt-set) ('jmp . xt-jmp) ('br . xt-br) ('call . xt-call)
          ('jmpr . xt-jmpr) ('jmpt . xt-jmpt) ('callr . xt-callr)
          ('lapool . xt-lapool) ('l32r . xt-l32r)
          ('raw . 1)
          ('ret . x24 0x80)                                 ; ret
          ('sys . x24 0x5000)                               ; syscall
          ('nop . x24 0x20F0)                               ; nop
          ('trap . x24 0)])                                 ; ill
   (xt-lower ins) (lower-via @ f (lit? f ? (f xt-emitters ins) (scare 'holo-bake-stale 'lower-via)))

   ;; j counts bytes from pc + 4, call0 words from the call's own word + 4 to a word target
   (xt-patch kind target site width aux)
      (? (kind = 'j18)
         (target - (site + 4) @ o
            (-131072 <= o <= 131071 ? 0 (scare 'xt-j-range o), xt-j18 o))
         (kind = 'call0)
         (target - ((site >> 2 << 2) + 4) @ o
            (0 = target & 3 ? 0 (scare 'xt-call0-align target),
             -524288 <= o <= 524287 ? 0 (scare 'xt-call0-range o),
             x24 ((o >> 2 & 262143) << 6 | 5)))
         (kind = 'abs32) (le32 (target + aux))
         ; l32r counts words back from its own word, rounded up: aux is its register
         (kind = 'l32r)
         (target - ((site + 3) >> 2 << 2) @ o
            (0 = target & 3 ? 0 (scare 'xt-l32r-align target),
             -262144 <= o < 0 ? 0 (scare 'xt-l32r-range o),
             x24 (((o >> 2) & 65535) << 8 | aux << 4 | 1)))
         (scare 'badfix kind))
   ; a link's slot0 field: the opcode it holds says j or call0
   (xt-refix kind bs target site width)
      (? (kind = 'slot0) (xt-refix (bs 0 & 15 = 5 ? 'call0 'j18) bs target site width)
         (kind = 'j18 && !(-131072 <= target - (site + 4) <= 131071)) ()
         (kind = 'call0 && !(-524288 <= target - ((site >> 2 << 2) + 4) <= 524287)) ()
         (kind = 'l32r && !(-262144 <= target - ((site + 3) >> 2 << 2) < 0)) ()
         (xt-patch kind target site width (kind = 'l32r ? (bs 0 >> 4 & 15) 0)))

   xt {'lower xt-lower 'patch xt-patch 'refix xt-refix 'nop '(240 32 0)}
   (defbackend 'xtensa xt))
) ; module 'holo
