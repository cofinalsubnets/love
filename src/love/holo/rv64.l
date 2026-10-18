; riscv -- the rv64 backend for holo (the ox64's c906, qemu -M virt). rv64imfd plus Zicsr/Zifencei
; for kernels; no A (moon's __sync hands its atomic words in raw). words squeeze to C forms where
; they fit (rvc-of), so an image asks for rv64gc.
;
; no flags register: cmp/test/ucomisd emit at most an immediate load and remember their operands in
; rv-flags; br/set fuse them into beq/blt/slt/feq... the contract is x86's: a br/set must follow its
; cmp with the operands still live. adds/subs leave their overflow bit's sign in x30 for vs/vc.
;
; branches lay wide: an inverted fused branch hops a jal x0 (+-1MB); the 'short hook narrows them
; to the bare branch (+-4KB) or c.beqz/c.bnez/c.j. call/la/lar are an auipc pair (+-2GB, one 'pcrel
; fixup). immediates never scare: past 12 bits they go through a scratch.
;
; scratches outside the abstract file: x31 (t6) is dead after every lowered chunk; x30 (t5) carries
; a cmp's immediate, a test result or an overflow bit to its br/set. a far-displacement stx/stxb
; borrows x30, so it may not sit between a cmp and its br.

(module 'holo
(: ;; r0..r7 a0..a7, r8..r12 t0..t4, r13/r14/r15 s2/s3/s1, r19..r26 s4..s11; sp x2, fp s0, lr ra.
   ;; gp and tp are never touched. zr is x0, for the system lane (sfence zr, zr)
   rv-regs {'sp 2 'fp 8 'lr 1 'zr 0
            'r0 10 'r1 11 'r2 12 'r3 13 'r4 14
            'r5 15 'r6 16 'r7 17
            'r8 5 'r9 6 'r10 7 'r11 28 'r12 29
            'r13 18 'r14 19 'r15 9
            'r19 20 'r20 21 'r21 22 'r22 23
            'r23 24 'r24 25 'r25 26 'r26 27}
   (rvn r) (look rv-regs r 'badreg)
   (rv-reg-eq a b) (rvn a = rvn b)

   ;; f0..f7 fa0..fa7, f8..f15 ft0..ft7, f16..f19 ft8..ft11
   rv-fregs {'f0 10 'f1 11 'f2 12 'f3 13 'f4 14
             'f5 15 'f6 16 'f7 17
             'f8 0 'f9 1 'f10 2 'f11 3 'f12 4
             'f13 5 'f14 6 'f15 7
             'f16 28 'f17 29 'f18 30 'f19 31}
   (rvf r) (look rv-fregs r 'badfreg)

   ;; the formats. immediates arrive signed; & masks the two's-complement bits into the field
   (rv-r f7 rs2 rs1 f3 rd op) (le32 (f7 << 25 | (rs2 << 20 | (rs1 << 15 | (f3 << 12 | (rd << 7 | op))))))
   (rv-i imm rs1 f3 rd op)    (le32 ((imm & 4095) << 20 | (rs1 << 15 | (f3 << 12 | (rd << 7 | op)))))
   (rv-s imm rs1 rs2 f3)      (imm & 4095 @ u
                                 (le32 ((u >> 5) << 25 | (rs2 << 20 | (rs1 << 15 | (f3 << 12 | ((u & 31) << 7 | 0x23)))))))
   (rv-b f3 rs1 rs2 rel)      (: u (rel & 8191)          ; 13-bit two's complement, bit 0 always 0
                                 (le32 ((u >> 12 & 1) << 31 | ((u >> 5 & 63) << 25 | (rs2 << 20 | (rs1 << 15 | (f3 << 12 | ((u >> 1 & 15) << 8 | ((u >> 11 & 1) << 7 | 0x63)))))))))
   (rv-u imm20 rd op)         (le32 ((imm20 & 1048575) << 12 | (rd << 7 | op)))
   (rv-jword rel)             (: u (rel & 2097151)       ; 21-bit two's complement jal offset field
                                 ((u >> 20 & 1) << 31 | ((u >> 1 & 1023) << 21 | ((u >> 11 & 1) << 20 | (u >> 12 & 255) << 12))))

   (rv-fits12 n) (n >= -2048 && n <= 2047)
   ;; the low 12 bits, signed, so n - lo is a multiple of 4096
   (rv-lo12 n) (n & 4095 @ low (low > 2047 ? (low - 4096) low))

   ;; addi, lui+addiw, or the high chunks then slli 12 + addi. s64 folds an unsigned >= 2^63
   (rv-li-rec dn s)
      (? (rv-fits12 s) (rv-i s 0 0 dn 0x13)                                 ; addi d, x0, s
         (fits32 s)
         (: lo (rv-lo12 s) hi ((s - lo) // 4096)                            ; addiw wraps mod 2^32,
            (catall [                                                       ; so hi=2^19 is exact
(rv-u hi dn 0x37)                                                           ; lui d, hi
(lo = 0 ? () (rv-i lo dn 0 dn 0x1B))]))                                   ; addiw d, d, lo
         (rv-lo12 s @ lo
            (catall [
              (rv-li-rec dn ((s - lo) // 4096))
              (rv-i 12 dn 1 dn 0x13)                                      ; slli d, d, 12
              (lo = 0 ? () (rv-i lo dn 0 dn 0x13))])))                    ; addi d, d, lo
   (rv-li d imm) (rv-li-rec (rvn d) (s64 imm))

   (rv-mov d s) (rv-i 0 (rvn s) 0 (rvn d) 0x13)                             ; addi d, s, 0

   ;; op -> (funct3 funct7)
   rv-alu {'add '(0 0) 'sub '(0 32) 'and '(7 0) 'or '(6 0) 'xor '(4 0) 'imul '(0 1)}
   (rv-alu-rrr f3 f7 dn an bn) (rv-r f7 bn an f3 dn 0x33)
   (rv-aluop op d a b)
      (: meta (peep rv-alu op 0) f3 (meta 0) f7 (meta 1)
         dn (rvn d) an (rvn a)
         (? (reg? b) (rv-alu-rrr f3 f7 dn an (rvn b))
            (op = 'sub && rv-fits12 (0 - b)) (rv-i (0 - b) an 0 dn 0x13)
            (rv-fits12 b && elem op '(add and or xor))
             (rv-i b an (op = 'add ? 0 f3) dn 0x13)
            (catall [(rv-li-rec 31 b) (rv-alu-rrr f3 f7 dn an 31)])))

   ;; the last cmp/test/ucomisd/adds: 'a/'b hardware numbers (FPRs when 'f is 1 .d or 2 .s),
   ;; 'v the overflow register or -1
   rv-flags {}
   (rv-flag-set f a b v)
      (pin rv-flags 'f f, pin rv-flags 'a a, pin rv-flags 'b b, pin rv-flags 'v v, ())

   (rv-cmp a b)
      (rvn a @ an
         (? (reg? b) (rv-flag-set 0 an (rvn b) -1)
            (b = 0)  (rv-flag-set 0 an 0 -1)
            (rv-li-rec 30 b @ bs (rv-flag-set 0 an 30 -1, bs))))
   (rv-test a b)                                                             ; x30 = a and b, against x0
      (: an (rvn a)
         bs (? (reg? b) (rv-alu-rrr 7 0 30 an (rvn b))
               (rv-fits12 b) (rv-i b an 7 30 0x13)
               (catall [(rv-li-rec 31 b) (rv-alu-rrr 7 0 30 an 31)]))
         (rv-flag-set 0 30 0 -1,
          bs))

   ;; overflow sign in x30: (d^a)&(d^b) for add, (a^b)&(a^d) for sub, off saved operands so d
   ;; may alias. the other conds read d against x0
   (rv-addsub-s op d a b)
      (: dn (rvn d) an (rvn a)
         pre (reg? b ? (rv-i 0 (rvn b) 0 30 0x13) (rv-li-rec 30 b))        ; x30 = b's old value
         f7  (op = 'adds ? 0 32)
         (rv-flag-set 0 dn 0 30,
          catall [
           pre
           (rv-i 0 an 0 31 0x13)                                             ; x31 = a's old value
           (rv-alu-rrr 0 f7 dn 31 30)                                        ; d = a op b
           (op = 'adds ?
              (catall [(rv-alu-rrr 4 0 31 dn 31)                             ; x31 = d ^ a
                        (rv-alu-rrr 4 0 30 dn 30)])                          ; x30 = d ^ b
              (catall [(rv-alu-rrr 4 0 30 31 30)                             ; x30 = a ^ b
                        (rv-alu-rrr 4 0 31 31 dn)]))                         ; x31 = a ^ d
           (rv-alu-rrr 7 0 30 30 31)]))

   ;; cond -> (funct3 rs1 rs2), gt/le/above/be by swapping. f3 ^ 1 inverts
   (rv-int-b cond an bn)
      (? (cond = 'eq) [0 an bn] (cond = 'ne) [1 an bn]
         (cond = 'lt) [4 an bn] (cond = 'ge) [5 an bn]
         (cond = 'gt) [4 bn an] (cond = 'le) [5 bn an]
         (cond = 'below) [6 an bn] (cond = 'ae) [7 an bn]
         (cond = 'above) [6 bn an] (cond = 'be) [7 bn an]
         (scare 'rv-badcc cond))
   ;; -> [the predicate into x31, the sense: 1 taken when set, 0 when clear]. ucomisd's conds as
   ;; x86's; gt/ge are unordered-false and lt/le their complements (unordered-true), as a64's
   ;; fcmp, so lt == below and le == be
   (rv-fp-pred cond fa fb w)                                                 ; w 2: singles
     (: k (w = 2 ? 0x50 0x51)
      (? (cond = 'above) [(rv-r k fa fb 1 31 0x53) 1]                     ; flt.d x31, fb, fa
         (cond = 'gt)    [(rv-r k fa fb 1 31 0x53) 1]
         (cond = 'be)    [(rv-r k fa fb 1 31 0x53) 0]
         (cond = 'le)    [(rv-r k fa fb 1 31 0x53) 0]
         (cond = 'ae)    [(rv-r k fa fb 0 31 0x53) 1]                     ; fle.d x31, fb, fa
         (cond = 'ge)    [(rv-r k fa fb 0 31 0x53) 1]
         (cond = 'below) [(rv-r k fa fb 0 31 0x53) 0]
         (cond = 'lt)    [(rv-r k fa fb 0 31 0x53) 0]
         (cond = 'eq)    [(rv-r k fb fa 2 31 0x53) 1]                     ; feq.d x31, fa, fb
         (cond = 'ne)    [(rv-r k fb fa 2 31 0x53) 0]
         (cond = 'p)     [(catall [(rv-r k fa fa 2 31 0x53)               ; x31 = fa ordered
                                    (rv-r k fb fb 2 30 0x53)              ; x30 = fb ordered
                                    (rv-alu-rrr 7 0 31 31 30)]) 0]
         (cond = 'np)    [(catall [(rv-r k fa fa 2 31 0x53)
                                    (rv-r k fb fb 2 30 0x53)
                                    (rv-alu-rrr 7 0 31 31 30)]) 1]
         (scare 'rv-fp-badcc cond)))
   (rv-flag-read tag)
      (peep rv-flags 'a -1 @ a
         (a < 0 ? (scare 'rv-no-cmp tag) 0,
          [a (peep rv-flags 'b -1) (peep rv-flags 'f 0) (peep rv-flags 'v -1)]))

   ;; an inverted hop over the wide jal. s/ns take the sign of a-b in x31
   (rv-br cond label)
      (: st (rv-flag-read 'br) an (st 0) bn (st 1)
         jal [(fix 4 'j21 label 0x6F)]                                       ; jal x0, label
         (? (st 2)
            (rv-fp-pred cond an bn (st 2) @ p
               (catall [(p 0)
                         (rv-b (p 1 ? 0 1) 31 0 8)                      ; hop: beqz/bnez x31, +8
                         jal]))
            (elem cond '(s ns))
            (catall [(rv-alu-rrr 0 32 31 an bn)                              ; x31 = a - b
                      (rv-b (cond = 's ? 5 4) 31 0 8)                      ; hop: bgez/bltz x31, +8
                      jal])
            (elem cond '(vs vc))
            (st 3 @ v (v < 0 ? (scare 'rv-no-overflow cond) 0,
                       catall [(rv-b (cond = 'vs ? 5 4) v 0 8) jal]))
            (rv-int-b cond an bn @ t
               (catall [(rv-b (t 0 ^ 1) (t 1) (t 2) 8) jal]))))

   (rv-set cond d)
      (: st (rv-flag-read 'set) an (st 0) bn (st 1) dn (rvn d)
         (? (st 2)
            (rv-fp-pred cond an bn (st 2) @ p
               (catall [(p 0)
                         (p 1 ? (rv-i 0 31 0 dn 0x13)                   ; d = x31
                            (rv-i 1 31 3 dn 0x13))]))                        ; d = (x31 < 1)  (seqz)
            (elem cond '(eq ne))
            (: xs (bn = 0 ? () (rv-alu-rrr 4 0 31 an bn))                  ; x31 = a ^ b
               t  (bn = 0 ? an 31)
               (catall [xs (cond = 'eq ? (rv-i 1 t 3 dn 0x13)              ; sltiu d, t, 1
                              (rv-alu-rrr 3 0 dn 0 t))]))                    ; sltu d, x0, t
            (elem cond '(s ns))
            (catall [(rv-alu-rrr 0 32 31 an bn)
                      (rv-alu-rrr 2 0 dn 31 0)                               ; slt d, x31, x0
                      (cond = 's ? () (rv-i 1 dn 4 dn 0x13))])             ; xori d, d, 1
            (elem cond '(vs vc))
            (st 3 @ v (v < 0 ? (scare 'rv-no-overflow cond) 0,
                       catall [(rv-alu-rrr 2 0 dn v 0)
                                (cond = 'vs ? () (rv-i 1 dn 4 dn 0x13))]))
            (: neg (elem cond '(ge le ae be))
               t (rv-int-b (? (cond = 'ge) 'lt (cond = 'le) 'gt
                              (cond = 'ae) 'below (cond = 'be) 'above cond) an bn)
               (catall [(rv-alu-rrr (t 0 = 4 ? 2 3) 0 dn (t 1) (t 2))      ; slt/sltu
                         (neg ? (rv-i 1 dn 4 dn 0x13))]))))               ; xori d, d, 1

   ;; a far offset builds base+hi in x31 and rides the low 12
   (rv-mem-far bn off go)                                                    ; go: (basereg lo12) -> bytes
      (: lo (rv-lo12 off) hi ((off - lo) // 4096)
         (hi >= -524288 && hi <= 524287 ? 0 (scare 'rv-mem-range off),
          catall [(rv-u hi 31 0x37)                                          ; lui x31, hi
                   (rv-alu-rrr 0 0 31 31 bn)                                 ; add x31, x31, base
                   (go 31 lo)]))
   (rv-ld-f3 f3 opc dt bn off)
      (rv-fits12 off ? (rv-i off bn f3 dt opc)
         (rv-mem-far bn off (\ b lo (rv-i lo b f3 dt opc))))
   (rv-st-f3 f3 bn off st)
      (rv-fits12 off ? (rv-s off bn st f3)
         (rv-mem-far bn off (\ b lo (rv-s lo b st f3))))
   (rv-ld d base off)   (rv-ld-f3 3 0x03 (rvn d) (rvn base) off)             ; ld
   (rv-st base off s)   (rv-st-f3 3 (rvn base) off (rvn s))                  ; sd
   (rv-ld1 d base off)  (rv-ld-f3 0 0x03 (rvn d) (rvn base) off)             ; lb
   (rv-ld2 d base off)  (rv-ld-f3 1 0x03 (rvn d) (rvn base) off)             ; lh
   (rv-ld4 d base off)  (rv-ld-f3 2 0x03 (rvn d) (rvn base) off)             ; lw
   (rv-ldu1 d base off) (rv-ld-f3 4 0x03 (rvn d) (rvn base) off)             ; lbu
   (rv-ldu2 d base off) (rv-ld-f3 5 0x03 (rvn d) (rvn base) off)             ; lhu
   (rv-ldu4 d base off) (rv-ld-f3 6 0x03 (rvn d) (rvn base) off)             ; lwu
   (rv-st1 base off s)  (rv-st-f3 0 (rvn base) off (rvn s))                  ; sb
   (rv-st2 base off s)  (rv-st-f3 1 (rvn base) off (rvn s))                  ; sh
   (rv-st4 base off s)  (rv-st-f3 2 (rvn base) off (rvn s))                  ; sw
   (rv-fld d base off)  (rv-ld-f3 3 0x07 (rvf d) (rvn base) off)             ; fld
   (rv-fst base off s)  (: bn (rvn base) sn (rvf s)
                           (rv-fits12 off ? (off & 4095 @ u (le32 ((u >> 5) << 25 | (sn << 20 | (bn << 15 | (3 << 12 | ((u & 31) << 7 | 0x27)))))))
                              (rv-mem-far bn off (\ b lo (lo & 4095 @ u (le32 ((u >> 5) << 25 | (sn << 20 | (b << 15 | (3 << 12 | ((u & 31) << 7 | 0x27)))))))))))
   (rv-flds d base off) (rv-ld-f3 2 0x07 (rvf d) (rvn base) off)             ; flw
   (rv-fsts base off s) (: bn (rvn base) sn (rvf s)
                           (rv-fits12 off ? (off & 4095 @ u (le32 ((u >> 5) << 25 | (sn << 20 | (bn << 15 | (2 << 12 | ((u & 31) << 7 | 0x27)))))))
                              (rv-mem-far bn off (\ b lo (lo & 4095 @ u (le32 ((u >> 5) << 25 | (sn << 20 | (b << 15 | (2 << 12 | ((u & 31) << 7 | 0x27)))))))))))

   (rv-sx w d) (rvn d @ dn
                  (w = 4 ? (rv-i 0 dn 0 dn 0x1B)                           ; addiw d, d, 0 (sext.w)
                     (: c (w = 1 ? 56 48)
                        (catall [(rv-i c dn 1 dn 0x13)                       ; slli d, d, c
                                  (rv-i (1024 + c) dn 5 dn 0x13)]))))        ; srai d, d, c
   (rv-zx w d) (rvn d @ dn
                  (w = 1 ? (rv-i 255 dn 7 dn 0x13)                         ; andi d, d, 255
                     (: c (w = 2 ? 48 32)
                        (catall [(rv-i c dn 1 dn 0x13)                       ; slli d, d, c
                                  (rv-i c dn 5 dn 0x13)]))))                 ; srli d, d, c

   ;; no rotate without Zbb: rol/ror go through x31
   (rv-shift op d c)
      (rvn d @ dn
         (? (op = 'shl) (rv-i c dn 1 dn 0x13)                                ; slli
            (op = 'shr) (rv-i c dn 5 dn 0x13)                                ; srli
            (op = 'sar) (rv-i (1024 + c) dn 5 dn 0x13)                       ; srai
            (elem op '(rol ror))
            (: k (op = 'ror ? c (64 - c & 63))                           ; rol c = ror 64-c
               (catall [(rv-i k dn 5 31 0x13)                                ; srli x31, d, k
                         (rv-i (64 - k & 63) dn 1 dn 0x13)                 ; slli d, d, 64-k
                         (rv-alu-rrr 6 0 dn dn 31)]))                        ; or d, d, x31
            (scare 'rv-badshift op)))
   (rv-shiftv op d c)                                                        ; the IR pins the count to r1
      (: _ (rv-reg-eq c 'r1 ? 0 (scare 'shiftv-count-not-r1 [op d c]))
         _ (rv-reg-eq d 'r1 ? (scare 'shiftv-dst-is-r1 [op d c]) 0)
         dn (rvn d) cn (rvn c)
         (? (op = 'shlv) (rv-alu-rrr 1 0 dn dn cn)                           ; sll
            (op = 'shrv) (rv-alu-rrr 5 0 dn dn cn)                           ; srl
            (rv-alu-rrr 5 32 dn dn cn)))                                     ; sra

   (rv-lea d base off)
      (: dn (rvn d) bn (rvn base)
         (rv-fits12 off ? (rv-i off bn 0 dn 0x13)                          ; addi d, base, off
            (catall [(rv-li-rec 31 off) (rv-alu-rrr 0 0 dn bn 31)])))

   ;; x31 carries base + ix*scale; a far displacement's high half goes in ldx's own dest, or x30
   ;; for stx (see the header)
   (rv-shamt scale) (? (scale = 1) 0 (scale = 2) 1 (scale = 4) 2 (scale = 8) 3 (scare 'badscale scale))
   (rv-ixaddr bn ixn sc)                                                     ; x31 = base + ix*scale
      (rv-shamt sc @ amt
         (amt = 0 ? (rv-alu-rrr 0 0 31 ixn bn)
            (catall [(rv-i amt ixn 1 31 0x13)                                ; slli x31, ix, amt
                      (rv-alu-rrr 0 0 31 31 bn)])))                          ; add x31, x31, base
   (rv-ix-far dp tn go)                                                      ; tn carries hi; go lo -> bytes
      (rv-fits12 dp ? (go dp)
         (: lo (rv-lo12 dp) hi ((dp - lo) // 4096)
            (catall [(rv-u hi tn 0x37)                                       ; lui t, hi
                      (rv-alu-rrr 0 0 31 31 tn)                              ; add x31, x31, t
                      (go lo)])))
   (rv-ldx-f3 f3 d base index scale disp)
      (rvn d @ dn
         (catall [(rv-ixaddr (rvn base) (rvn index) scale)
                   (rv-ix-far disp dn (lo \ (rv-i lo 31 f3 dn 0x03)))]))
   (rv-ldx d base index scale disp)  (rv-ldx-f3 3 d base index scale disp)   ; ld
   (rv-ldxb d base index scale disp) (rv-ldx-f3 4 d base index scale disp)   ; lbu
   (rv-stx-f3 f3 base index scale disp s)
      (catall [(rv-ixaddr (rvn base) (rvn index) scale)
                (rv-ix-far disp 30 (lo \ (rv-s lo 31 (rvn s) f3)))])
   (rv-stx base index scale disp s)  (rv-stx-f3 3 base index scale disp s)   ; sd
   (rv-stxb base index scale disp s) (rv-stx-f3 0 base index scale disp s)   ; sb
   (rv-leax d base index scale disp)
      (: dn (rvn d) amt (rv-shamt scale)
         (catall [(amt = 0 ? (rv-alu-rrr 0 0 dn (rvn index) (rvn base))
                     (catall [(rv-i amt (rvn index) 1 31 0x13)
                               (rv-alu-rrr 0 0 dn 31 (rvn base))]))
                   (? (disp = 0) ()
                      (rv-fits12 disp) (rv-i disp dn 0 dn 0x13)
                      (catall [(rv-li-rec 31 disp) (rv-alu-rrr 0 0 dn dn 31)]))]))

   (rv-push s) (catall [(rv-i -16 2 0 2 0x13) (rv-s 0 2 (rvn s) 3)])         ; addi sp,sp,-16 ; sd s,0(sp)
   (rv-pop d)  (catall [(rv-i 0 2 3 (rvn d) 0x03) (rv-i 16 2 0 2 0x13)])     ; ld d,0(sp) ; addi sp,sp,16

   (rv-neg d) (rv-alu-rrr 0 32 (rvn d) 0 (rvn d))                            ; sub d, x0, d
   (rv-not d) (rv-i -1 (rvn d) 4 (rvn d) 0x13)                               ; xori d, d, -1
   (rv-inc d) (rv-i 1 (rvn d) 0 (rvn d) 0x13)
   (rv-dec d) (rv-i -1 (rvn d) 0 (rvn d) 0x13)

   ;; div/rem never trap: /0 answers -1 or the dividend. rem's t goes unused
   (rv-imul d a b) (rv-aluop 'imul d a b)
   (rv-mulh d a b) (rv-alu-rrr 1 1 (rvn d) (rvn a) (rvn b))               ; mulh
   (rv-umulh d a b) (rv-alu-rrr 3 1 (rvn d) (rvn a) (rvn b))              ; mulhu
   (rv-div d a b)     (rv-alu-rrr 4 1 (rvn d) (rvn a) (rvn b))               ; div
   (rv-rem d a b t)   (rv-alu-rrr 6 1 (rvn d) (rvn a) (rvn b))               ; rem
   (rv-udiv d a b)    (rv-alu-rrr 5 1 (rvn d) (rvn a) (rvn b))               ; divu
   (rv-urem d a b t)  (rv-alu-rrr 7 1 (rvn d) (rvn a) (rvn b))               ; remu

   ;; no overflow iff mulh equals the low half's sign fill. t must differ from a, b and d
   (rv-mulo d a b t lbl)
      (: dn (rvn d) an (rvn a) bn (rvn b) tn (rvn t)
         (catall [(rv-alu-rrr 1 1 tn an bn)                                  ; mulh t, a, b
                   (rv-alu-rrr 0 1 dn an bn)                                 ; mul  d, a, b
                   (rv-i 1087 dn 5 31 0x13)                                  ; srai x31, d, 63
                   (rv-b 0 tn 31 8)                                          ; beq t, x31, +8
                   [(fix 4 'j21 lbl 0x6F)]]))                                ; jal x0, lbl

   ;; the 'short hook: every rv-br ends in hop + jal; within +-4KB drop the jal, flip the hop back
   ;; and aim it at the label. a rewrite of the bytes, not a re-lower: by then rv-flags holds
   ;; the text's last cmp, not this br's
   (rvb-fits? rel) (rel >= -4096 && rel <= 4094)
   (rv-bword rel)  (: u (rel & 8191)                    ; the B-form's 13-bit field
                      ((u >> 12 & 1) << 31 | ((u >> 5 & 63) << 25
                        | ((u >> 1 & 15) << 8 | (u >> 11 & 1) << 7))))
   (rv-first k l)  (k < 1 || !(two? l) ? () (<l . rv-first (k - 1) >l))
   ;; tighter still, c.j and c.beqz/c.bnez: they turn on a distance, so the 'short hook lays
   ;; them, not rvc-squeeze
   (rvj-fits? rel)  (rel >= -2048 && rel <= 2046)
   (rvcb-fits? rel) (rel >= -256 && rel <= 254)
   (rv-cjword rel) (: u (rel & 4095)                    ; cj: imm[11|4|9:8|10|6|7|3:1|5]
                      ((u >> 11 & 1) << 12 | ((u >> 4 & 1) << 11
                        | ((u >> 8 & 3) << 9 | ((u >> 10 & 1) << 8
                          | ((u >> 6 & 1) << 7 | ((u >> 7 & 1) << 6
                            | ((u >> 1 & 7) << 3 | (u >> 5 & 1) << 2))))))))
   (rv-cbword rel) (: u (rel & 511)                     ; cb: imm[8|4:3] high, imm[7:6|2:1|5] low
                      ((u >> 8 & 1) << 12 | ((u >> 3 & 3) << 10
                        | ((u >> 6 & 3) << 5 | ((u >> 1 & 3) << 3
                          | (u >> 5 & 1) << 2)))))
   ;; a B-form -> its c.beqz/c.bnez base word, or (): beq/bne against x0, rs1 in x8..x15, +-256
   (rv-cbase w rel)
      (: f3 (w >> 12 & 7) rs1 (w >> 15 & 31)
         (f3 < 2 && (w >> 20 & 31 = 0 && (rvc-p? rs1 && rvcb-fits? rel)) ?
            (6 + f3 << 13 | (rvc-p rs1 << 7 | 1)) ()))
   (rv-shorten bs label rel)
      (#bs @ n
         (? (n < 5) ()
            !(fix? (bs (n - 1))) ()                  ; the jal fixup
            (: w (bs (n - 5) | (bs (n - 4) << 8
                   | (bs (n - 3) << 16 | bs (n - 2) << 24)))
               (!(w & 127 = 0x63) ? ()                ; after a B-form hop
                  (: base (w & 0x1FFF07F ^ 0x1000)    ; keep rs2/rs1/funct3/op, flip the cond
                     cb (rv-cbase base rel)
                     (rv-first (n - 5) bs
                      + (imm? cb ? [(fix 2 'cb label cb)]
                           [(fix 4 'b13 label base)])))))))

   (rv-jmp label)  [(fix 4 'j21 label 0x6F)]
   (rv-jmpr d)     (rv-i 0 (rvn d) 0 0 0x67)                                 ; jalr x0, 0(d)
   ;; the table and its targets are for the analyses, not the machine
   (rv-jmpt d tl labs) (rv-jmpr d)
   ;; auipc pairs: aux packs both base words, the auipc low. pc-relative, so la serves lar too
   (rv-call label) [(fix 8 'pcrel label ((1 << 15 | (1 << 7 | 0x67)) * 4294967296 + (0x17 | 1 << 7)))]
   (rv-callr d)    (rv-i 0 (rvn d) 0 1 0x67)                                 ; jalr ra, 0(d)
   (rv-la d label) (rvn d @ dn
                      [(fix 8 'pcrel label ((dn << 15 | (dn << 7 | 0x13)) * 4294967296 + (0x17 | dn << 7)))])

   ;; the two-address IR repeats d as the first source. rm in funct3: 7 dynamic, 1 toward zero
   rv-fp3 {'addsd 1 'subsd 5 'mulsd 9 'divsd 13 'addss 0 'subss 4 'mulss 8 'divss 12}   ; funct7: .d, then .s
   (rv-fp3op op d s) (rvf d @ dn (rv-r (peep rv-fp3 op 0) (rvf s) dn 7 dn 0x53))
   (rv-fmov d s)   (rvf s @ sn (rv-r 0x11 sn sn 0 (rvf d) 0x53))           ; fsgnj.d d, s, s
   (rv-fcmp a b)   (rv-flag-set 1 (rvf a) (rvf b) -1)
   (rv-fcmps a b)  (rv-flag-set 2 (rvf a) (rvf b) -1)
   (rv-scvtf d g)  (rv-r 0x69 2 (rvn g) 7 (rvf d) 0x53)                      ; fcvt.d.l d, g
   (rv-fcvtzs g d) (rv-r 0x61 2 (rvf d) 1 (rvn g) 0x53)                      ; fcvt.l.d g, d, rtz
   (rv-fmovxr d g) (rv-r 0x79 0 (rvn g) 0 (rvf d) 0x53)                      ; fmv.d.x
   (rv-fmovrx g d) (rv-r 0x71 0 (rvf d) 0 (rvn g) 0x53)                      ; fmv.x.d
   (rv-fwiden d s)  (rv-r 0x21 0 (rvf s) 0 (rvf d) 0x53)                     ; fcvt.d.s
   (rv-fnarrow d s) (rv-r 0x20 1 (rvf s) 7 (rvf d) 0x53)                     ; fcvt.s.d (rounds)
   (rv-scvtfs d g)  (rv-r 0x68 2 (rvn g) 7 (rvf d) 0x53)                     ; fcvt.s.l d, g
   (rv-fcvtzss g d) (rv-r 0x60 2 (rvf d) 1 (rvn g) 0x53)                     ; fcvt.l.s g, d, rtz
   (rv-fmovsw d g)  (rv-r 0x78 0 (rvn g) 0 (rvf d) 0x53)                     ; fmv.w.x
   (rv-fmovws g d)  (rv-r 0x70 0 (rvf d) 0 (rvn g) 0x53)                     ; fmv.x.w, sign-extending
   (rv-xorpd d s)                                                            ; zeroing only (d==s)
      (rvf d = rvf s ? (rv-r 0x79 0 0 0 (rvf d) 0x53)                      ; fmv.d.x d, x0
         (scare 'rv-xorpd-general [d s]))

   (rv-tp d) (rv-i 0 4 0 (rvn d) 0x13)                                       ; addi d, tp, 0

   ;; the system lane, for kernels: every CSR access is one I-form (the number in the immediate,
   ;; funct3 the op, opcode 0x73). no dots in names: sfence.vma is sfence, fence.i fencei,
   ;; ecall sys, ebreak trap. a bare CSR number passes through (csrw 1985 is the c906's mhcr)
   rv-csrnames {'fflags 0x001 'frm 0x002 'fcsr 0x003
                'cycle 0xC00 'time 0xC01 'instret 0xC02
                'sstatus 0x100 'sie 0x104 'stvec 0x105 'scounteren 0x106
                'sscratch 0x140 'sepc 0x141 'scause 0x142 'stval 0x143
                'sip 0x144 'satp 0x180
                'mstatus 0x300 'misa 0x301 'medeleg 0x302 'mideleg 0x303
                'mie 0x304 'mtvec 0x305 'mcounteren 0x306
                'mscratch 0x340 'mepc 0x341 'mcause 0x342 'mtval 0x343
                'mip 0x344
                'mvendorid 0xF11 'marchid 0xF12 'mimpid 0xF13 'mhartid 0xF14}
   (rv-csr c) (imm? c ? c (look rv-csrnames c 'badcsr))
   (rv-csru u) (0 <= u <= 31 ? u (scare 'rv-csr-uimm u))
   (rv-csrop f3 dn csr sn) (rv-i (rv-csr csr) sn f3 dn 0x73)
   ;; each pseudo is the full form with x0 in the slot it does not name
   (rv-csrr d csr)      (rv-csrop 2 (rvn d) csr 0)
   (rv-csrw csr s)      (rv-csrop 1 0 csr (rvn s))
   (rv-csrs csr s)      (rv-csrop 2 0 csr (rvn s))
   (rv-csrc csr s)      (rv-csrop 3 0 csr (rvn s))
   (rv-csrwi csr u)     (rv-csrop 5 0 csr (rv-csru u))
   (rv-csrsi csr u)     (rv-csrop 6 0 csr (rv-csru u))
   (rv-csrci csr u)     (rv-csrop 7 0 csr (rv-csru u))
   (rv-csrrw d csr s)   (rv-csrop 1 (rvn d) csr (rvn s))
   (rv-csrrs d csr s)   (rv-csrop 2 (rvn d) csr (rvn s))
   (rv-csrrc d csr s)   (rv-csrop 3 (rvn d) csr (rvn s))
   (rv-csrrwi d csr u)  (rv-csrop 5 (rvn d) csr (rv-csru u))
   (rv-csrrsi d csr u)  (rv-csrop 6 (rvn d) csr (rv-csru u))
   (rv-csrrci d csr u)  (rv-csrop 7 (rvn d) csr (rv-csru u))
   ;; rs1 an address, rs2 an ASID; x0 in either means all
   (rv-sfence a b) (rv-r 9 (rvn b) (rvn a) 0 0 0x73)                         ; sfence.vma a, b

   rv-emitters (emsof
        [('li . rv-li) ('mov . rv-mov) ('cmp . rv-cmp) ('test . rv-test)
          ('imul . rv-imul)
          ('ld . rv-ld) ('st . rv-st)
          ('ld1 . rv-ld1) ('ld2 . rv-ld2) ('ld4 . rv-ld4)
          ('st1 . rv-st1) ('st2 . rv-st2) ('st4 . rv-st4)
          ('ldu1 . rv-ldu1) ('ldu2 . rv-ldu2) ('ldu4 . rv-ldu4)
          ('sx1 . rv-sx 1) ('sx2 . rv-sx 2) ('sx4 . rv-sx 4)
          ('zx1 . rv-zx 1) ('zx2 . rv-zx 2) ('zx4 . rv-zx 4)
          ('shlv . rv-shiftv 'shlv) ('shrv . rv-shiftv 'shrv) ('sarv . rv-shiftv 'sarv)
          ('shl . rv-shift 'shl) ('shr . rv-shift 'shr) ('sar . rv-shift 'sar)
          ('rol . rv-shift 'rol) ('ror . rv-shift 'ror)
          ('lea . rv-lea) ('lean . rv-lea)
          ('push . rv-push) ('pop . rv-pop)
          ('neg . rv-neg) ('not . rv-not) ('inc . rv-inc) ('dec . rv-dec)
          ('jmp . rv-jmp) ('br . rv-br) ('jmpr . rv-jmpr) ('jmpt . rv-jmpt) ('callr . rv-callr)
          ('mulo . rv-mulo) ('mulh . rv-mulh) ('umulh . rv-umulh) ('set . rv-set)
          ('adds . rv-addsub-s 'adds) ('subs . rv-addsub-s 'subs)
          ('div . rv-div) ('rem . rv-rem) ('udiv . rv-udiv) ('urem . rv-urem)
          ('ldx . rv-ldx) ('stx . rv-stx) ('leax . rv-leax)
          ('ldxb . rv-ldxb) ('stxb . rv-stxb)
          ('call . rv-call) ('la . rv-la) ('lar . rv-la)
          ('tp . rv-tp)
          ('movsd . rv-fmov) ('movapd . rv-fmov) ('movss . rv-fmov)
          ('addsd . rv-fp3op 'addsd) ('subsd . rv-fp3op 'subsd)
          ('mulsd . rv-fp3op 'mulsd) ('divsd . rv-fp3op 'divsd)
          ('ucomisd . rv-fcmp) ('ucomiss . rv-fcmps) ('cvtsi2sd . rv-scvtf) ('cvttsd2si . rv-fcvtzs)
          ('addss . rv-fp3op 'addss) ('subss . rv-fp3op 'subss) ('mulss . rv-fp3op 'mulss) ('divss . rv-fp3op 'divss)
          ('cvtsi2ss . rv-scvtfs) ('cvttss2si . rv-fcvtzss) ('movdxr . rv-fmovsw) ('movdrx . rv-fmovws)
          ('movqxr . rv-fmovxr) ('movqrx . rv-fmovrx)
          ('stsd . rv-fst) ('ldsd . rv-fld) ('stss . rv-fsts) ('ldss . rv-flds)
          ('cvtss2sd . rv-fwiden) ('cvtsd2ss . rv-fnarrow)
          ('xorpd . rv-xorpd)
          ('raw . 1)
          ('ret . rv-i 0 1 0 0 0x67)                                        ; jalr x0, 0(ra)
          ('sys . le32 0x73)                                                ; ecall
          ('nop . le32 0x13)                                                ; addi x0, x0, 0
          ('trap . le32 0x100073)                                           ; ebreak
          ('csrr . rv-csrr) ('csrw . rv-csrw) ('csrs . rv-csrs) ('csrc . rv-csrc)
          ('csrwi . rv-csrwi) ('csrsi . rv-csrsi) ('csrci . rv-csrci)
          ('csrrw . rv-csrrw) ('csrrs . rv-csrrs) ('csrrc . rv-csrrc)
          ('csrrwi . rv-csrrwi) ('csrrsi . rv-csrrsi) ('csrrci . rv-csrrci)
          ('sfence . rv-sfence)
          ('wfi . le32 0x10500073)
          ('sret . le32 0x10200073) ('mret . le32 0x30200073)
          ('fence . le32 0x0FF0000F)                                        ; fence iorw, iorw
          ('fencei . le32 0x0000100F)])                                     ; fence.i
   _ (map (k \ emrow rv-emitters k (rv-aluop k)) (keys rv-alu))

   ;; rvc: a plain word (no fixup) collapses to a C form when its operands fit. it reads only
   ;; the word, never an address, so lay needs no relaxation for it
   (rvc-p? r)      (r >= 8 && r <= 15)              ; the 3-bit register window x8..x15
   (rvc-p r)       (r - 8)
   (rvc-s6? n)     (n >= -32 && n <= 31)
   (rvc-u? n k hi) (n >= 0 && (n <= hi && n % k = 0))
   (rvc-i12 w)     (w >> 20 & 4095 @ u (u > 2047 ? (u - 4096) u))
   (rvc-s12 w)     ((w >> 25 & 127) << 5 | (w >> 7) & 31 @ u (u > 2047 ? (u - 4096) u))

   (rvc-ci f3 op rd i)     (le16 (f3 << 13 | ((i >> 5 & 1) << 12 | (rd << 7 | ((i & 31) << 2 | op)))))
   (rvc-cr f4 rd rs2)      (le16 (f4 << 12 | (rd << 7 | (rs2 << 2 | 2))))
   (rvc-cl f3 lo hi9 i)    (le16 (f3 << 13 | ((i >> 3 & 7) << 10 | (rvc-p hi9 << 7 | ((i >> 6 & 3) << 5 | (rvc-p lo << 2 | 0))))))
   (rvc-css f3 rs2 i)      (le16 (f3 << 13 | ((i >> 3 & 7) << 10 | ((i >> 6 & 7) << 7 | (rs2 << 2 | 2)))))
   (rvc-cisp f3 rd i)      (le16 (f3 << 13 | ((i >> 5 & 1) << 12 | (rd << 7 | ((i >> 3 & 3) << 5 | ((i >> 6 & 7) << 2 | 2))))))
   (rvc-ca f2 rd rs2)      (le16 (35 << 10 | (rvc-p rd << 7 | (f2 << 5 | (rvc-p rs2 << 2 | 1)))))
   (rvc-cb f2 rd i)        (le16 (4 << 13 | ((i >> 5 & 1) << 12 | (f2 << 10 | (rvc-p rd << 7 | ((i & 31) << 2 | 1))))))
   ;; c.addi16sp (c.lui with rd sp): imm[9|4|6|8:7|5], scaled by 16
   (rvc-c16sp i)           (le16 (3 << 13 | ((i >> 9 & 1) << 12 | (2 << 7
                             | ((i >> 4 & 1) << 6 | ((i >> 6 & 1) << 5
                               | ((i >> 7 & 3) << 3 | ((i >> 5 & 1) << 2 | 1))))))))
   (rvc-s16? n)            (n >= -512 && (n <= 496 && n % 16 = 0))

   ;; the C word, or () where no form fits
   (rvc-of w)
    (: op (w & 127) rd (w >> 7 & 31) f3 (w >> 12 & 7)
       rs1 (w >> 15 & 31) rs2 (w >> 20 & 31) f7 (w >> 25 & 127)
       i (rvc-i12 w) s (rvc-s12 w) sh (rs2 | (f7 & 1) << 5)
       (? (op = 0x13)                                                    ; OP-IMM
           (? (f3 = 0 && (!(rd = 0) && (rs1 = rd && (!(i = 0) && rvc-s6? i))))
               (rvc-ci 0 1 rd i)                                         ; c.addi
              (f3 = 0 && (rd = 2 && (rs1 = 2 && (!(i = 0) && rvc-s16? i))))
               (rvc-c16sp i)                                             ; c.addi16sp
              (f3 = 0 && (!(rd = 0) && (rs1 = 0 && rvc-s6? i)))
               (rvc-ci 2 1 rd i)                                         ; c.li
              (f3 = 0 && (!(rd = 0) && (!(rs1 = 0) && (!(rs1 = rd) && i = 0))))
               (rvc-cr 8 rd rs1)                                         ; c.mv (addi rd, rs, 0)
              (f3 = 1 && (!(rd = 0) && (rs1 = rd && (f7 & 126 = 0 && !(sh = 0)))))
               (rvc-ci 0 2 rd sh)                                        ; c.slli
              (f3 = 5 && (rvc-p? rd && (rs1 = rd && (f7 & 126 = 32 && !(sh = 0)))))
               (rvc-cb 1 rd sh)                                          ; c.srai
              (f3 = 5 && (rvc-p? rd && (rs1 = rd && (f7 & 126 = 0 && !(sh = 0)))))
               (rvc-cb 0 rd sh)                                          ; c.srli
              (f3 = 7 && (rvc-p? rd && (rs1 = rd && rvc-s6? i)))
               (rvc-cb 2 rd i)                                           ; c.andi
              ())
          (op = 0x1b)                                                    ; OP-IMM-32
           (f3 = 0 && (!(rd = 0) && (rs1 = rd && rvc-s6? i)) ?
               (rvc-ci 1 1 rd i) ())                                     ; c.addiw
          (op = 0x33)                                                    ; OP
           (? (f3 = 0 && (f7 = 0 && (!(rd = 0) && (rs1 = rd && !(rs2 = 0)))))
               (rvc-cr 9 rd rs2)                                         ; c.add
              (f3 = 0 && (f7 = 0 && (!(rd = 0) && (rs1 = 0 && !(rs2 = 0)))))
               (rvc-cr 8 rd rs2)                                         ; c.mv (add rd, x0, rs2)
              (f3 = 0 && (f7 = 32 && (rvc-p? rd && (rs1 = rd && rvc-p? rs2))))
               (rvc-ca 0 rd rs2)                                         ; c.sub
              (f3 = 4 && (f7 = 0 && (rvc-p? rd && (rs1 = rd && rvc-p? rs2))))
               (rvc-ca 1 rd rs2)                                         ; c.xor
              (f3 = 6 && (f7 = 0 && (rvc-p? rd && (rs1 = rd && rvc-p? rs2))))
               (rvc-ca 2 rd rs2)                                         ; c.or
              (f3 = 7 && (f7 = 0 && (rvc-p? rd && (rs1 = rd && rvc-p? rs2))))
               (rvc-ca 3 rd rs2)                                         ; c.and
              ())
          (op = 0x03)                                                    ; LOAD
           (? (f3 = 3 && (rs1 = 2 && (!(rd = 0) && rvc-u? i 8 504)))
               (rvc-cisp 3 rd i)                                         ; c.ldsp
              (f3 = 3 && (rvc-p? rs1 && (rvc-p? rd && rvc-u? i 8 248)))
               (rvc-cl 3 rd rs1 i)                                       ; c.ld
              ())
          (op = 0x23)                                                    ; store
           (? (f3 = 3 && (rs1 = 2 && rvc-u? s 8 504))
               (rvc-css 7 rs2 s)                                         ; c.sdsp
              (f3 = 3 && (rvc-p? rs1 && (rvc-p? rs2 && rvc-u? s 8 248)))
               (rvc-cl 7 rs2 rs1 s)                                      ; c.sd
              ())
          (op = 0x07)                                                    ; LOAD-FP
           (? (f3 = 3 && (rs1 = 2 && rvc-u? i 8 504))
               (rvc-cisp 1 rd i)                                         ; c.fldsp
              (f3 = 3 && (rvc-p? rs1 && (rvc-p? rd && rvc-u? i 8 248)))
               (rvc-cl 1 rd rs1 i)                                       ; c.fld
              ())
          (op = 0x27)                                                    ; store-FP
           (? (f3 = 3 && (rs1 = 2 && rvc-u? s 8 504))
               (rvc-css 5 rs2 s)                                         ; c.fsdsp
              (f3 = 3 && (rvc-p? rs1 && (rvc-p? rs2 && rvc-u? s 8 248)))
               (rvc-cl 5 rs2 rs1 s)                                      ; c.fsd
              ())
          (op = 0x67)                                                    ; jalr
           (f3 = 0 && (rd = 0 && (!(rs1 = 0) && i = 0)) ?
               (rvc-cr 8 rs1 0) ())                                      ; c.jr, ret too
          ()))

   ;; word by word through a chunk: plain bytes come four to an instruction, a fixup is one
   ;; element. sound only while no chunk branches a fixed offset over a squeezable word: the hops
   ;; are B-forms clearing exactly a jal fixup
   (rvc-4? bs) (: (go i l) (? (i = 4) 1 !(two? l) 0 !(imm? <l) 0 (go (i + 1) >l))
                  (go 0 bs))
   (rvc-squeeze bs)
    (? !(two? bs) bs
       !(imm? <bs) (<bs . rvc-squeeze >bs)          ; a fixup: its own width, never squeezed
       !(rvc-4? bs) bs                               ; a ragged tail cannot be an instruction
       (: c (rvc-of (bs 0 | (bs 1 << 8 | (bs 2 << 16 | bs 3 << 24))))
          ((two? c ? c (rv-first 4 bs)) + rvc-squeeze >>>>bs)))

   (rv-lower ins) (lower-via @ f
                     (? !(lit? f) (scare 'holo-bake-stale 'lower-via)
                        (<ins = 'raw) (f rv-emitters ins)       ; raw is never squeezed
                        (rvc-squeeze (f rv-emitters ins))))

   ;; pcrel: hi20 into aux's low word (the auipc), lo12 into its high word, hi rounded for a signed lo
   (rv-patch kind target site width aux)
      (target - site @ rb
         (? (kind = 'j21)
            (rb >= -1048576 && rb <= 1048575 ? 0 (scare 'rv-jal-range rb),
             le32 (aux | rv-jword rb))
            (kind = 'pcrel)
            (: lo (rv-lo12 rb) hi ((rb - lo) // 4096)
               (hi >= -524288 && hi <= 524287 ? 0 (scare 'rv-pcrel-range rb),
                le32 (aux % 4294967296 | (hi & 1048575) << 12)
                + le32 (aux // 4294967296 | (lo & 4095) << 20)))
            (kind = 'b13)
            (rvb-fits? rb ? 0 (scare 'rv-b13-range rb),
             le32 (aux | rv-bword rb))
            (kind = 'cj)
            (rvj-fits? rb ? 0 (scare 'rv-cj-range rb),
             le16 (aux | rv-cjword rb))
            (kind = 'cb)
            (rvcb-fits? rb ? 0 (scare 'rv-cb-range rb),
             le16 (aux | rv-cbword rb))
            (kind = 'abs64) (le64 (target + aux))
            (scare 'badfix kind)))

   ;; the linker's door. rela: bs holds the base words (two for pcrel). () past the field's reach
   (rv-refix kind bs target site width)
    (: (w i) (bs i + (bs (i + 1) << 8) + (bs (i + 2) << 16) + (bs (i + 3) << 24))
       rb (target - site) hi ((rb - rv-lo12 rb) // 4096)
       (? (kind = 'j21 && !(-1048576 <= rb <= 1048575)) ()
          (kind = 'pcrel && !(-524288 <= hi <= 524287)) ()
          (rv-patch kind target site width (kind = 'pcrel ? (w 0 + w 4 * 4294967296) (w 0)))))

   rv {}
   (pin rv 'lower rv-lower,
    pin rv 'patch rv-patch,
    pin rv 'refix rv-refix,
   ;; a br's prefix before the hop is plain bytes, so its element count is its byte count
    pin rv 'short (\ ins c rel
      (? (<ins = 'jmp)
         (? (#c != 1) ()                 ; the chunk is the lone jal
            !(fix? <c) ()
            (fix-k <c != 'j21) ()
            (rvj-fits? rel) [(fix 2 'cj (ins 1) 0xA001)]
            ())
         (<ins != 'br) ()
         (#c - 5 @ pre
            (pre < 0 || !(rvb-fits? (rel - pre)) ? ()
               (rv-shorten c (ins 2) (rel - pre)))))),
   ;; c.nop pads: at 2 mod 4 a torn wide nop would read as a 32-bit opcode
    pin rv 'nop '(1 0),
   ;; for the rvc fuzz test only
    pin rv 'parts {'rvc-of rvc-of 'rv-patch rv-patch 'rv-cbase rv-cbase},
    defbackend 'rv64 rv))
) ; module 'holo
