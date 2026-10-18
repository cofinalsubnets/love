; thumb2 -- the armv7e-m (Cortex-M7) backend for holo, also 'thumb2sp and 'arm. mixed 16/32-bit
; Thumb-2; a 32-bit word (hw1<<16)|hw2 lays as le16(hw1) ++ le16(hw2), not le32 (t32 does it).
; data-processing uses the wide encodings throughout, reaching r0..r12 alike.
; immediates: add/sub take addw/subw #imm12 (a negative flips the op), cmp #imm8; and/or/xor have
; only the modified-immediate form, so an immediate there scares (immok keeps it in a register).

(module 'holo
(: ;; r12 (IP) is the far-memory and 128-bit scratch
   thumb-regs {'sp 13 'lr 14 'pc 15 'fp 11
               'r0 0 'r1 1 'r2 2 'r3 3  'r4 4
               'r5 5 'r6 6 'r7 7 'r8 8  'r9 9
               'r10 10 'r11 11 'r12 12}
   (rn r) (look thumb-regs r 'badreg)

   (t16 w) (le16 w)

   ;; li: MOVW the low 16, then MOVT the high 16 if nonzero. the scatter takes the hw register
   ;; number, so patch shares it
   (thumb-mw16 base dn imm16)                                 ; base 0xf240 = MOVW (T3), 0xf2c0 = MOVT (T1)
      (: hw1 (base | ((imm16 >> 11 & 1) << 10 | (imm16 >> 12) & 15))      ; i (bit11), imm4 (bits15:12)
         hw2 ((imm16 >> 8 & 7) << 12 | (dn << 8 | imm16 & 255))         ; imm3 (bits10:8), Rd, imm8
         (t32 (hw1 << 16 | hw2)))
   (thumb-movw d imm16) (thumb-mw16 0xF240 (rn d) imm16)
   (thumb-movt d imm16) (thumb-mw16 0xF2C0 (rn d) imm16)
   (thumb-li d imm)
      (: u (imm < 0 ? (imm + 4294967296) imm) lo (u & 65535) hi (u >> 16 & 65535)
         (thumb-movw d lo + (hi = 0 ? () (thumb-movt d hi))))

   ;; la: always the MOVW/MOVT pair, each a fixup with aux = Rd; a .o leaves
   ;; R_ARM_THM_MOVW_ABS_NC / R_ARM_THM_MOVT_ABS
   (thumb-la d label) (rn d @ dn [(fix 4 'movw16 label dn) (fix 4 'movt16 label dn)])
   ;; (align 4) (lapool Rd) (abs32 word): LDR.W Rd,[pc,#4] ; B.N over ; NOP pad. for playdate,
   ;; whose loader relocates abs32 words, never a MOVW/MOVT pair
   (thumb-lapool d) (rn d @ dn (catall [(t32 (0xF8DF0004 | dn << 12)) (t16 0xE002) (t16 0xBF00)]))

   ;; MOV.W (ORR Rn=15) with sp or pc is unpredictable, so those go by the 16-bit hi form
   (thumb-sppc? (13 || 15)) 1
   (thumb-mov d s)
      (: dn (rn d) sn (rn s)
         (thumb-sppc? dn || thumb-sppc? sn ? (thumb-movr d s)
            (t32 (0xEA4F0000 | (dn << 8 | sn)))))

   ;; the wide three-address register forms: op -> hw1 base
   thumb-alu {'add 0xEB00 'sub 0xEBA0 'and 0xEA00 'or 0xEA40 'xor 0xEA80
              'adds 0xEB10 'subs 0xEBB0
              'adc 0xEB40 'adcs 0xEB50
              'sbc 0xEB60 'sbcs 0xEB70
              'ors 0xEA50}
   (thumb-alu-rrr base d a b)                                 ; hw1 = base|Rn(a); hw2 = Rd<<8 | Rm(b)
      (: dn (rn d) an (rn a) bn (rn b) (t32 ((base | an) << 16 | (dn << 8 | bn))))
   ;; addw/subw (T4) #imm12; wider chunks by 4095 -- no flags written, and only the first step reads a
   (thumb-addsub-imm op d a imm)
      (: pos (imm < 0 ? -imm imm)
         fop (imm < 0 ? (op @ 'add 'sub 'sub 'add op) op)
         base (fop @ 'add 0xF200 0xF2A0)
         dn (rn d)
         (one src k)
          (: an (rn src)
             hw1 (base | ((k >> 11 & 1) << 10 | an))         ; i = imm12 bit 11
             hw2 ((k >> 8 & 7) << 12 | (dn << 8 | k & 255))   ; imm3, Rd, imm8
             (t32 (hw1 << 16 | hw2)))
         (chunks p src acc)
          (p <= 0 ? acc
             (: c (4095 < p ? 4095 p)
                (chunks (p - c) d (acc + one src c))))
         (pos <= 4095 ? (one a pos) (chunks pos a ())))
   (thumb-aluop op d a b)
      (peep thumb-alu op 0 @ base
         (? (reg? b) (thumb-alu-rrr base d a b)
            (elem op '(add sub)) (thumb-addsub-imm op d a b)
            (scare 'thumb-logimm [op d a b])))

   (thumb-cmp a b)
      (rn a @ an
         (reg? b ? (rn b @ bn (t32 ((0xEBB0 | an) << 16 | (0x0F00 | bn))))
            (abs b @ pos
               (pos <= 255 ? 0 (scare 'cmp-imm-range b),
               ; a negative compares by cmn
                t32 (((b < 0 ? 0xF110 0xF1B0) | an) << 16 | (0x0F00 | pos))))))

   (thumb-imul d a b)
      (reg? b ? (: dn (rn d) an (rn a) bn (rn b) (t32 ((0xFB00 | an) << 16 | (0xF000 | (dn << 8 | bn)))))
         (scare 'thumb-mul-imm ['imul d a b]))
   (thumb-umull dl dh a b)
      (: ln (rn dl) hn (rn dh) an (rn a) bn (rn b)
         (t32 ((0xFBA0 | an) << 16 | (ln << 12 | (hn << 8 | bn)))))
   (thumb-mla d a b acc)                                      ; d = a*b + acc
      (: dn (rn d) an (rn a) bn (rn b) cn (rn acc)
         (t32 ((0xFB00 | an) << 16 | (cn << 12 | (dn << 8 | bn)))))
   (thumb-clz d s) (: dn (rn d) sn (rn s) (t32 ((0xFAB0 | sn) << 16 | (0xF080 | (dn << 8 | sn)))))
   ;; 64-bit unsigned div/rem: dividend r2:r3, divisor r0:r1, answer r0:r1; r4..r7 saved round it.
   ;; 64 restoring steps doubling (rem:dividend); a carry out of rem forces the subtract.
   ;; label-free, offsets by byte count: loop at 28, bcs at 44, bcc at 54, bne at 76
   (t2-udivmod which)
      (catall [(thumb-push 'r4) (thumb-push 'r5) (thumb-push 'r6) (thumb-push 'r7)
                (thumb-movw 'r4 0) (thumb-movw 'r5 0) (thumb-movw 'r6 64)
                (thumb-aluop 'adds 'r2 'r2 'r2)                ; loop: (rem:dividend) <<= 1
                (thumb-aluop 'adcs 'r3 'r3 'r3)
                (thumb-aluop 'adcs 'r4 'r4 'r4)
                (thumb-aluop 'adcs 'r5 'r5 'r5)
                (t16 0xD204)                                   ; bcs -> the subtract
                (thumb-aluop 'subs 'r7 'r4 'r0)                ; trial rem - divisor
                (thumb-aluop 'sbcs 'r7 'r5 'r1)
                (t16 0xD305)                                   ; bcc -> next
                (thumb-aluop 'subs 'r4 'r4 'r0)
                (thumb-aluop 'sbcs 'r5 'r5 'r1)
                (thumb-addsub-imm 'add 'r2 'r2 1)              ; the quotient bit
                (thumb-addsub-imm 'sub 'r6 'r6 1)              ; next
                (thumb-cmp 'r6 0)
                (t16 0xD1E6)                                   ; bne loop
                (which @ 'div
                 (thumb-movr 'r0 'r2 + thumb-movr 'r1 'r3)
                 (thumb-movr 'r0 'r4 + thumb-movr 'r1 'r5))
                (thumb-pop 'r7) (thumb-pop 'r6) (thumb-pop 'r5) (thumb-pop 'r4)])

   ;; [Rn,#imm12] (T3), else [Rn,#-imm8] (T4), else r12 = base+off and [r12,#0]
   (thumb-mem-far bn off)                                    ; r12 = off ; r12 += Rbn
      (thumb-li 'r12 off + t32 (0xEB0C << 16 | (0x0C00 | bn)))
   (thumb-mem-r lbase ubase dt bn off)
      (? (0 <= off <= 4095)
         (t32 ((ubase | bn) << 16 | (dt << 12 | off)))
         (-255 <= off < 0)
         (t32 ((lbase | bn) << 16 | (dt << 12 | (0xC00 | -off))))   ; t4: P=1 U=0 W=0 = 0b1100, imm8=|off|
         (thumb-mem-far bn off + t32 ((ubase | 12) << 16 | dt << 12)))
   (thumb-mem lbase ubase d base off) (thumb-mem-r lbase ubase (rn d) (rn base) off)
   (thumb-ld d base off)  (thumb-mem 0xF850 0xF8D0 d base off)   ; LDR.W
   (thumb-st base off s)  (thumb-mem 0xF840 0xF8C0 s base off)   ; STR.W
   (thumb-ld4 d base off) (thumb-mem 0xF850 0xF8D0 d base off)
   (thumb-st4 base off s) (thumb-mem 0xF840 0xF8C0 s base off)
   (thumb-ldu1 d base off) (thumb-mem 0xF810 0xF890 d base off)  ; ldrb
   (thumb-ldu2 d base off) (thumb-mem 0xF830 0xF8B0 d base off)  ; ldrh
   (thumb-ld1 d base off)  (thumb-mem 0xF910 0xF990 d base off)  ; ldrsb
   (thumb-ld2 d base off)  (thumb-mem 0xF930 0xF9B0 d base off)  ; ldrsh
   (thumb-st1 base off s)  (thumb-mem 0xF800 0xF880 s base off)  ; strb
   (thumb-st2 base off s)  (thumb-mem 0xF820 0xF8A0 s base off)  ; strh

   ;; leax is ADD.W Rd,Rn,Rm,LSL #amt (d may alias either source); ldx/ldxb at disp 0 are one
   ;; register-offset load
   (thumb-shamt scale) (scale @ 1 0 2 1 4 2 8 3 (scare 'badscale scale))
   (thumb-addsh d b ix amt)                                   ; ADD.W Rd, Rb, Rix, LSL #amt
      (: dn (rn d) bn (rn b) xn (rn ix)
         (t32 ((0xEB00 | bn) << 16 | (dn << 8 | ((amt & 3) << 6 | xn)))))
   (thumb-leax d base ix scale disp)
      (catall [(thumb-addsh d base ix (thumb-shamt scale))
                (disp @ 0 () (thumb-addsub-imm 'add d d disp))])
   (thumb-memsh lbase d b ix amt)                             ; LDR/LDRB Rt, [Rn, Rm, LSL #amt]
      (: dn (rn d) bn (rn b) xn (rn ix)
         (t32 ((lbase | bn) << 16 | (dn << 12 | (amt << 4 | xn)))))
   (thumb-ldx d base ix scale disp)
      (disp @ 0 (thumb-memsh 0xF850 d base ix (thumb-shamt scale))
         (catall [(thumb-addsh d base ix (thumb-shamt scale)) (thumb-ld d d disp)]))
   (thumb-ldxb d base ix scale disp)
      (disp @ 0 (thumb-memsh 0xF810 d base ix (thumb-shamt scale))
         (catall [(thumb-addsh d base ix (thumb-shamt scale)) (thumb-ldu1 d d disp)]))

   ;; MOV (register) 16-bit hi form: any of r0..r15, and the only move that may target sp
   ;; (MOV.W / ADDW with Rd=sp, Rn!=sp are unpredictable on v7-M)
   (thumb-movr d s) (: dn (rn d) sn (rn s) (t16 (0x4600 | ((dn >> 3 & 1) << 7 | (sn << 3 | dn & 7)))))
   ;; offset 0 rides movr, so lea sp,fp,0 and lea fp,sp,0 stay legal
   (thumb-lea d base off)  (off @ 0 (thumb-movr d base) (thumb-addsub-imm 'add d base off))

   (thumb-push s) (rn s @ st (t32 (0xF84D0000 | (st << 12 | (0xD00 | 4)))))   ; STR Rt,[sp,#-4]!  P=1 U=0 W=1
   (thumb-pop  d) (rn d @ dt (t32 (0xF85D0000 | (dt << 12 | (0xB00 | 4)))))   ; LDR Rt,[sp],#4    P=0 U=1 W=1

   ;; w=4 is a no-op on a 32-bit target
   (thumb-sx w d) (w @ 4 () (rn d @ dn (t32 ((w @ 1 0xFA4FF080 0xFA0FF080) | (dn << 8 | dn)))))   ; sxtb / sxth Rd, Rd
   (thumb-zx w d) (w @ 4 () (rn d @ dn (t32 ((w @ 1 0xFA5FF080 0xFA1FF080) | (dn << 8 | dn)))))   ; uxtb / uxth Rd, Rd
   (thumb-neg d) (rn d @ dn (t32 ((0xF1C0 | dn) << 16 | dn << 8)))          ; rsb Rd, Rd, #0
   (thumb-not d) (rn d @ dn (t32 (0xEA6F0000 | (dn << 8 | dn))))              ; mvn.W Rd, Rm
   (thumb-inc d) (thumb-addsub-imm 'add d d 1)
   (thumb-dec d) (thumb-addsub-imm 'sub d d 1)

   ;; MOV.W Rd, Rm, <type> #count; type lsl 0 lsr 1 asr 2 ror 3. rol is ror the other way; a
   ;; whole-word rotate is no change (ror #0 would be rrx)
   (thumb-shift op d c)
      (? (op = 'rol) (thumb-shift 'ror d ((32 - c) & 31))
         (op = 'ror && (c & 31) = 0) ()
         (thumb-shift1 op d c))
   (thumb-shift1 op d c)
      (: dn (rn d)
         ty (op @ 'shl 0 'shr 1 'sar 2 'ror 3 (scare 'badshift op))
         hw2 ((c >> 2 & 7) << 12 | (dn << 8 | ((c & 3) << 6 | (ty << 4 | dn))))
         (t32 (0xEA4F0000 | hw2)))
   ;; any count register, unguarded: the pair shifts keep their high word in r1
   (thumb-shiftv op d c)
      (: dn (rn d) cn (rn c)
         base (op @ 'shlv 0xFA00 'shrv 0xFA20 'sarv 0xFA40 (scare 'badshiftv op))
         (t32 ((base | dn) << 16 | (0xF000 | (dn << 8 | cn)))))

   (thumb-div d a b)  (: dn (rn d) an (rn a) bn (rn b) (t32 ((0xFB90 | an) << 16 | (0xF0F0 | (dn << 8 | bn)))))   ; sdiv
   (thumb-udiv d a b) (: dn (rn d) an (rn a) bn (rn b) (t32 ((0xFBB0 | an) << 16 | (0xF0F0 | (dn << 8 | bn)))))   ; udiv
   (thumb-mls d n m a) (: dn (rn d) nn (rn n) mn (rn m) an (rn a) (t32 ((0xFB00 | nn) << 16 | (an << 12 | (dn << 8 | (0x10 | mn))))))
   (thumb-rem d a b t)  (thumb-div t a b + thumb-mls d t b a)          ; t=a/b ; d = a - t*b
   (thumb-urem d a b t) (thumb-udiv t a b + thumb-mls d t b a)

   ;; tst.W: ANDS with Rd=pc; register only
   (thumb-test a b)
      (reg? b ? (: an (rn a) bn (rn b) (t32 ((0xEA10 | an) << 16 | (0x0F00 | bn))))
         (scare 'thumb-test-imm ['test a b]))

   ;; MOVW d,#0 ; it cond ; MOVW d,#1 -- MOVW keeps the flags and reaches r0..r12
   (thumb-set cond d)
      (look arm-cc cond 'badcc @ cc
         (catall [(thumb-movw d 0) (t16 (0xBF08 | cc << 4)) (thumb-movw d 1)]))

   ;; vfp: f0..f15 -> d0..d15 (fpv5-d16). the IR's two-address d = op(d, s) repeats d as the
   ;; first source. a single is S[2n], the low half of Dn, so the odd-register bits never arise.
   ;; s30 is the converters' scratch: f15 is reserved. movqxr/movqrx move the gp pair r, r+1
   thumb-fregs (fregs 16)
   (frn r) (look thumb-fregs r 'badfreg)
   (t2-fp3 hi lo d m) (: dn (frn d) mn (frn m) (t32 ((hi | dn) << 16 | (dn << 12 | (lo | mn)))))
   (thumb-addsd d m) (t2-fp3 0xEE30 0xB00 d m)                ; vadd.F64 Dd, Dd, Dm
   (thumb-subsd d m) (t2-fp3 0xEE30 0xB40 d m)                ; vsub.F64
   (thumb-mulsd d m) (t2-fp3 0xEE20 0xB00 d m)                ; vmul.F64
   (thumb-divsd d m) (t2-fp3 0xEE80 0xB00 d m)                ; vdiv.F64
   (thumb-addss d m) (t2-fp3 0xEE30 0xA00 d m)                ; vadd.F32 S[2d], S[2d], S[2m]
   (thumb-subss d m) (t2-fp3 0xEE30 0xA40 d m)                ; vsub.F32
   (thumb-mulss d m) (t2-fp3 0xEE20 0xA00 d m)                ; vmul.F32
   (thumb-divss d m) (t2-fp3 0xEE80 0xA00 d m)                ; vdiv.F32
   (thumb-movsd d m) (: dn (frn d) mn (frn m) (t32 (0xEEB0 << 16 | (dn << 12 | (0xB40 | mn)))))
   (thumb-movss d m) (: dn (frn d) mn (frn m) (t32 (0xEEB0 << 16 | (dn << 12 | (0xA40 | mn)))))   ; VMOV.F32 S[2d], S[2m]
   (thumb-ucomisd a b)                                        ; VCMP.F64 Da, Db ; vmrs apsr_nzcv
      (: an (frn a) bn (frn b)                                ;   unordered sets V
         (t32 (0xEEB4 << 16 | (an << 12 | (0xB40 | bn))) + t32 0xEEF1FA10))
   (thumb-ucomiss a b)                                        ; VCMP.F32 S[2a], S[2b] ; vmrs apsr_nzcv
      (: an (frn a) bn (frn b)
         (t32 (0xEEB4 << 16 | (an << 12 | (0xA40 | bn))) + t32 0xEEF1FA10))
   (thumb-cvtxsd base f g)                                    ; vmov S[2f], Rg ; vcvt.F64.{S,U}32 Df, S[2f]
      (: fn (frn f) gn (rn g)
         (t32 ((0xEE00 | fn) << 16 | (gn << 12 | 0xA10))
          + t32 (0xEEB8 << 16 | ((fn << 12) | (base | fn)))))
   (thumb-cvtsi2sd f g) (thumb-cvtxsd 0xBC0 f g)              ; signed
   (thumb-cvtui2sd f g) (thumb-cvtxsd 0xB40 f g)              ; unsigned
   (thumb-cvtsdxi hi g f)                                     ; vcvt.{S,U}32.F64 s30, Df ; vmov Rg, s30
      (: gn (rn g) fn (frn f)
         (t32 (hi << 16 | (0xFBC0 | fn))
          + t32 (0xEE1F << 16 | (gn << 12 | 0xA10))))
   (thumb-cvttsd2si g f) (thumb-cvtsdxi 0xEEBD g f)           ; toward zero, signed
   (thumb-cvttsd2ui g f) (thumb-cvtsdxi 0xEEBC g f)           ; toward zero, unsigned
   (thumb-cvtsi2ss f g) (thumb-cvtxsd 0xAC0 f g)              ; vmov S[2f], Rg ; vcvt.F32.S32 S[2f], S[2f]
   (thumb-cvtui2ss f g) (thumb-cvtxsd 0xA40 f g)              ; ..F32.U32
   (thumb-cvtssxi hi g f)                                     ; vcvt.{S,U}32.F32 s30, S[2f] ; vmov Rg, s30
      (: gn (rn g) fn (frn f)
         (t32 (hi << 16 | (0xFAC0 | fn))
          + t32 (0xEE1F << 16 | (gn << 12 | 0xA10))))
   (thumb-cvttss2si g f) (thumb-cvtssxi 0xEEBD g f)
   (thumb-cvttss2ui g f) (thumb-cvtssxi 0xEEBC g f)
   (thumb-movdxr f g) (: fn (frn f) gn (rn g) (t32 ((0xEE00 | fn) << 16 | (gn << 12 | 0xA10))))   ; vmov S[2f], Rg
   (thumb-movdrx g f) (: fn (frn f) gn (rn g) (t32 ((0xEE10 | fn) << 16 | (gn << 12 | 0xA10))))   ; vmov Rg, S[2f]
   (thumb-movqxr f glo)                                       ; vmov Df, Rlo, Rlo+1 (the pair in)
      (: fn (frn f) gn (rn glo)
         (t32 ((0xEC40 | gn + 1) << 16 | (gn << 12 | (0xB10 | fn)))))
   (thumb-movqrx glo f)                                       ; vmov Rlo, Rlo+1, Df (the pair out)
      (: gn (rn glo) fn (frn f)
         (t32 ((0xEC50 | gn + 1) << 16 | (gn << 12 | (0xB10 | fn)))))
   ;; vldr/vstr: imm8 words, +-1020; past that r12 as thumb-mem
   (thumb-fmem pbase nbase lo tn bn off)
      (: _ (0 != off % 4 ? (scare 'fmem-align off))
         u (abs off)
         (u <= 1020 ?
          (t32 (((off < 0 ? nbase pbase) | bn) << 16 | (tn << 12 | (lo | u >> 2))))
          (thumb-mem-far bn off + t32 ((pbase | 12) << 16 | (tn << 12 | lo)))))
   ;; unaligned: word by word through r12. a far store would want r12 twice, so it keeps near
   (thumb-fmemu ld? n f base off)
      (catall (map (k \ (ld? ? (thumb-ld 'r12 base (off + 4 * k) + thumb-movsnxr (2 * frn f + k) 'r12)
                           (: _ (-255 <= off && off + 4 * k <= 4095 ? 0 (scare 'fmem-align off))
                              (thumb-movsnrx 'r12 (2 * frn f + k) + thumb-st base (off + 4 * k) 'r12))))
                   ^n))
   (thumb-stsd base off s) (0 != off % 4 ? (thumb-fmemu () 2 s base off) (thumb-fmem 0xED80 0xED00 0xB00 (frn s) (rn base) off))   ; vstr Ds
   (thumb-ldsd d base off) (0 != off % 4 ? (thumb-fmemu 1 2 d base off) (thumb-fmem 0xED90 0xED10 0xB00 (frn d) (rn base) off))   ; vldr Dd
   (thumb-stss base off s) (0 != off % 4 ? (thumb-fmemu () 1 s base off) (thumb-fmem 0xED80 0xED00 0xA00 (frn s) (rn base) off))   ; vstr S[2s]
   (thumb-ldss d base off) (0 != off % 4 ? (thumb-fmemu 1 1 d base off) (thumb-fmem 0xED90 0xED10 0xA00 (frn d) (rn base) off))   ; vldr S[2d]
   (thumb-cvtss2sd d s) (: dn (frn d) sn (frn s) (t32 (0xEEB7 << 16 | (dn << 12 | (0xAC0 | sn)))))   ; vcvt.F64.F32 Dd, S[2s]
   (thumb-cvtsd2ss d s) (: dn (frn d) sn (frn s) (t32 (0xEEB7 << 16 | (dn << 12 | (0xBC0 | sn)))))   ; vcvt.F32.F64 S[2d], Ds
   ;; VMOV Sk,Rt / Rt,Sk by number: an AAPCS-VFP argument may be odd. Vn = k >> 1, the odd bit N
   (thumb-movsnxr k g) (rn g @ gn (t32 ((0xEE00 | k >> 1) << 16 | (gn << 12 | (0xA10 | (k & 1) << 7)))))
   (thumb-movsnrx g k) (rn g @ gn (t32 ((0xEE10 | k >> 1) << 16 | (gn << 12 | (0xA10 | (k & 1) << 7)))))
   (thumb-smull dl dh a b)
      (: ln (rn dl) hn (rn dh) an (rn a) bn (rn b)
         (t32 ((0xFB80 | an) << 16 | (ln << 12 | (hn << 8 | bn)))))

   ;; the 128-bit kit: the value in r0..r3 low word first, a binop's left in a 16-byte cell at
   ;; [sp]. r12 is the scratch and a variable shift's count. one IR form each, so no pass parts a
   ;; carry chain
   thumb-w4 '(r0 r1 r2 r3)
   (thumb-wc k) (thumb-ld 'r12 'sp (4 * k))
   ;; op over the words, cell OP word (cfirst) or word OP cell
   (thumb-wchain ops cfirst)
      (catall (map (k \ (thumb-wc k + (cfirst ? (thumb-aluop (ops k) (thumb-w4 k) 'r12 (thumb-w4 k))
                                               (thumb-aluop (ops k) (thumb-w4 k) (thumb-w4 k) 'r12))))
                   ^4))
   thumb-addc '(adds adcs adcs adc)
   thumb-subc '(subs sbcs sbcs sbc)
   thumb-subf '(subs sbcs sbcs sbcs)                            ; the compare's chain keeps its last flags
   (thumb-a128 sp9) (thumb-wchain thumb-addc ())
   (thumb-s128 sp9) (thumb-wchain thumb-subc 1)                 ; the cell less the value
   ;; against zero in r12: negate, step by one
   (thumb-wk ops k) (thumb-movw 'r12 k + catall (map (i \ (i = 1 ? (thumb-movw 'r12 0) ())
                                                    + thumb-aluop (ops i) (thumb-w4 i) (thumb-w4 i) 'r12) ^4))
   thumb-n128 (thumb-movw 'r12 0 + catall (map (i \ thumb-aluop (thumb-subc i) (thumb-w4 i) 'r12 (thumb-w4 i)) ^4))
   thumb-inc128 (thumb-wk thumb-addc 1)
   thumb-dec128 (thumb-wk thumb-subc 1)
   thumb-sx128 (thumb-mov 'r2 'r1 + thumb-shift 'sar 'r2 31 + thumb-mov 'r3 'r2)   ; the pair's sign fills the high half
   ;; 0/1 <- (CELL cond VALUE). eq/ne fold the words by eor; the ordered ones read the borrow
   ;; chain's flags, gt/above/le/be with the operands reversed
   (thumb-c128 cond sp9)
      (? (elem cond '(eq ne))
          (thumb-wchain '(xor xor xor xor) ()
           + thumb-aluop 'or 'r0 'r0 'r1 + thumb-aluop 'or 'r0 'r0 'r2 + thumb-aluop 'or 'r0 'r0 'r3
           + thumb-cmp 'r0 0 + thumb-set cond 'r0)
         (elem cond '(lt below ge ae)) (thumb-wchain thumb-subf 1 + thumb-set cond 'r0)
         (thumb-wchain thumb-subf () + thumb-set (cond @ 'gt 'lt 'above 'below 'le 'ge 'be 'ae (scare 'badcc128 cond)) 'r0))
   ;; by a constant: whole words move, then the funnel by the rest through r12
   (thumb-wmove pairs) (catall (map (p \ (two? >p ? (thumb-mov <p <>p) (thumb-movw <p 0))) pairs))
   (thumb-funnel hi lo s)                                       ; hi = hi << s | lo >> (32 - s)
      (thumb-shift 'shl hi s + thumb-mov 'r12 lo + thumb-shift 'shr 'r12 (32 - s) + thumb-aluop 'or hi hi 'r12)
   (thumb-funnelr lo hi s)                                      ; lo = lo >> s | hi << (32 - s)
      (thumb-shift 'shr lo s + thumb-mov 'r12 hi + thumb-shift 'shl 'r12 (32 - s) + thumb-aluop 'or lo lo 'r12)
   (thumb-shl128 c)
      (: k (c // 32) s (c % 32) w thumb-w4
         (thumb-wmove (map (i \ (3 - i @ j (j < k ? [(w j)] [(w j) (w (j - k))]))) ^4)
          + (0 < s ? (catall (map (i \ (3 - i @ j (j < 1 ? (thumb-shift 'shl (w 0) s) (thumb-funnel (w j) (w (j - 1)) s)))) ^4)) ())))
   (thumb-shrx128 c sar?)
      (: k (c // 32) s (c % 32) w thumb-w4
         ((sar? ? (thumb-mov 'r12 'r3 + thumb-shift 'sar 'r12 31) ())
          + catall (map (j \ (3 - k < j ? (sar? ? (thumb-mov (w j) 'r12) (thumb-movw (w j) 0)) (k = 0 ? () (thumb-mov (w j) (w (j + k)))))) ^4)
          + (0 < s ? (catall (map (j \ (j = 3 ? (thumb-shift (sar? ? 'sar 'shr) 'r3 s) (thumb-funnelr (w j) (w (j + 1)) s))) ^4)) ())))
   (thumb-shr128 c) (thumb-shrx128 c ())
   (thumb-sar128 c) (thumb-shrx128 c 1)
   ;; by r12 (0..127), a bit a loop: lsl by the carry chain, or lsr/asr down through rrx
   (thumb-shs ty d m c) (t32 (0xEA5F0000 | ((c >> 2 & 7) << 12 | (rn d << 8 | ((c & 3) << 6 | (ty << 4 | rn m))))))   ; movs.w Rd, Rm, <ty> #c (ror #0 = rrx)
   (thumb-wloop body)
      (: b2 (body + thumb-addsub-imm 'sub 'r12 'r12 1)
         head (thumb-cmp 'r12 0)
         (head + t16 (0xD000 | #b2 // 2 & 255)                  ; beq past the b
          + b2 + t16 (0xE000 | (0 - (#head + #b2 + 6)) // 2 & 2047)))   ; b to the head
   (thumb-wchain2 ops) (catall (map (k \ thumb-aluop (ops k) (thumb-w4 k) (thumb-w4 k) (thumb-w4 k)) ^4))
   thumb-shl128v (thumb-wloop (thumb-wchain2 '(adds adcs adcs adc)))
   thumb-shr128v (thumb-wloop (thumb-shs 1 'r3 'r3 1 + thumb-shs 3 'r2 'r2 0 + thumb-shs 3 'r1 'r1 0 + thumb-shs 3 'r0 'r0 0))
   thumb-sar128v (thumb-wloop (thumb-shs 2 'r3 'r3 1 + thumb-shs 3 'r2 'r2 0 + thumb-shs 3 'r1 'r1 0 + thumb-shs 3 'r0 'r0 0))

   ;; jmp is B T4, br B T3 with the cond in aux, call BL T1; patch lays the whole word
   (thumb-jmp  label) [(fix 4 'b   label 0)]
   (thumb-call label) [(fix 4 'bl  label 0)]
   (thumb-br cond label) (look arm-cc cond 'badcc @ cc
                            [(fix 4 'bcc label cc)])
   (thumb-jmpr d)  (rn d @ dn (t16 (0x4700 | dn << 3)))    ; BX Rm
   ;; the table and its targets are for the analyses, not the machine
   (thumb-jmpt d tl labs) (thumb-jmpr d)
   (thumb-callr d) (rn d @ dn (t16 (0x4780 | dn << 3)))    ; blx Rm

   ;; M-profile has one shareability domain: a barrier takes only sy, never widened in silence
   (thumb-dsb opt) (opt @ 'sy (t32 0xF3BF8F4F) (scare 'thumb-barrier-opt opt))
   ;; bkpt #imm8: 0xab is the semihosting call, how a board without a uart exits qemu
   (thumb-brk imm) (0 <= imm <= 255 ? (t16 (0xBE00 | imm)) (scare 'thumb-brk-imm imm))
   ;; MRS Rd, <sysm>: only the two stack pointers, for a fault handler
   thumb-sysm {'msp 8 'psp 9}
   (thumb-mrs d sys)
      (look thumb-sysm sys 'badsysm @ sm
         (t32 (0xF3EF0000 | (0x8000 | rn d << 8 | sm))))

   thumb-emitters (emsof
        [('li . thumb-li) ('mov . thumb-mov) ('cmp . thumb-cmp) ('imul . thumb-imul)
          ('umull . thumb-umull) ('smull . thumb-smull) ('mla . thumb-mla)
          ('addsd . thumb-addsd) ('subsd . thumb-subsd) ('mulsd . thumb-mulsd)
          ('divsd . thumb-divsd) ('movsd . thumb-movsd) ('movss . thumb-movss) ('ucomisd . thumb-ucomisd) ('ucomiss . thumb-ucomiss)
          ('cvtsi2sd . thumb-cvtsi2sd) ('cvtui2sd . thumb-cvtui2sd)
          ('cvttsd2si . thumb-cvttsd2si) ('cvttsd2ui . thumb-cvttsd2ui)
          ('movqxr . thumb-movqxr) ('movqrx . thumb-movqrx)
          ('addss . thumb-addss) ('subss . thumb-subss) ('mulss . thumb-mulss) ('divss . thumb-divss)
          ('cvtsi2ss . thumb-cvtsi2ss) ('cvtui2ss . thumb-cvtui2ss)
          ('cvttss2si . thumb-cvttss2si) ('cvttss2ui . thumb-cvttss2ui)
          ('movdxr . thumb-movdxr) ('movdrx . thumb-movdrx)
          ('stsd . thumb-stsd) ('ldsd . thumb-ldsd) ('stss . thumb-stss) ('ldss . thumb-ldss)
          ('cvtss2sd . thumb-cvtss2sd) ('cvtsd2ss . thumb-cvtsd2ss)
          ('movsnxr . thumb-movsnxr) ('movsnrx . thumb-movsnrx)
          ('clz . thumb-clz)
          ('udivll . t2-udivmod 'div) ('uremll . t2-udivmod 'rem)        ; nullary: the whole expansion
          ('ld . thumb-ld) ('st . thumb-st)
          ('ld1 . thumb-ld1) ('ld2 . thumb-ld2) ('ld4 . thumb-ld4)
          ('st1 . thumb-st1) ('st2 . thumb-st2) ('st4 . thumb-st4)
          ('ldu1 . thumb-ldu1) ('ldu2 . thumb-ldu2)
          ('ldu4 . thumb-ld4)
          ('sx1 . thumb-sx 1) ('sx2 . thumb-sx 2) ('sx4 . thumb-sx 4)
          ('zx1 . thumb-zx 1) ('zx2 . thumb-zx 2) ('zx4 . thumb-zx 4)
          ('shlv . thumb-shiftv 'shlv) ('shrv . thumb-shiftv 'shrv) ('sarv . thumb-shiftv 'sarv)
          ('shl . thumb-shift 'shl) ('shr . thumb-shift 'shr) ('sar . thumb-shift 'sar)
          ('rol . thumb-shift 'rol) ('ror . thumb-shift 'ror)
          ('lea . thumb-lea) ('lean . thumb-lea)
          ('la . thumb-la) ('lapool . thumb-lapool)
          ('leax . thumb-leax) ('ldx . thumb-ldx) ('ldxb . thumb-ldxb)
          ('push . thumb-push) ('pop . thumb-pop)
          ('neg . thumb-neg) ('not . thumb-not) ('inc . thumb-inc) ('dec . thumb-dec)
          ('jmp . thumb-jmp) ('br . thumb-br) ('jmpr . thumb-jmpr) ('jmpt . thumb-jmpt) ('callr . thumb-callr)
          ('set . thumb-set) ('test . thumb-test)
          ('div . thumb-div) ('rem . thumb-rem) ('udiv . thumb-udiv) ('urem . thumb-urem)
          ('call . thumb-call)
          ('raw . 1)
          ('dsb . thumb-dsb) ('brk . thumb-brk)
          ('mrs . thumb-mrs)
          ('isb . t32 0xF3BF8F6F)                           ; isb sy
          ('a128 . thumb-a128) ('s128 . thumb-s128) ('c128 . thumb-c128)
          ('n128 . thumb-n128) ('inc128 . thumb-inc128) ('dec128 . thumb-dec128) ('sx128 . thumb-sx128)
          ('shl128 . thumb-shl128) ('shr128 . thumb-shr128) ('sar128 . thumb-sar128)
          ('shl128v . thumb-shl128v) ('shr128v . thumb-shr128v) ('sar128v . thumb-sar128v)
          ('wfi . t16 0xBF30)
          ('ret . t16 0x4770)                               ; BX lr
          ('sys . t16 0xDF00)                               ; svc #0
          ('nop . t16 0xBF00)
          ('trap . t16 0xBE00)])                            ; bkpt #0
   _ (map (k \ emrow thumb-emitters k (thumb-aluop k)) (keys thumb-alu))
   (thumb-lower ins) (lower-via @ f (lit? f ? (f thumb-emitters ins) (scare 'holo-bake-stale 'lower-via)))

   ;; pc reads as site + 4.
   ;;   b   T4: imm25 = S:I1:I2:imm10:imm11:0, I1=~(J1^S), I2=~(J2^S)
   ;;   bl  T1: the same, hw2 base 0xd000 (B's 0x9000)
   ;;   bcc T3: imm21 = S:J2:J1:imm6:imm11:0, cond in hw1 from aux
   (thumb-patch kind target site width aux)
      (target - (site + 4) @ o
         (kind @ ('b || 'bl) (tbw o (kind = 'bl ? 0xD000 0x9000))
            'bcc
            (: imm11 (o >> 1 & 2047)  imm6 (o >> 12 & 63)
               j1 (o >> 18 & 1)  j2 (o >> 19 & 1)  s (o >> 20 & 1)
               hw1 (0xF000 | (s << 10 | (aux << 6 | imm6)))
               hw2 (0x8000 | (j1 << 13 | (j2 << 11 | imm11)))
               (t32 (hw1 << 16 | hw2)))
            ; la's absolute halves, aux = Rd
            'movw16 (thumb-mw16 0xF240 aux (target & 65535))
            'movt16 (thumb-mw16 0xF2C0 aux (target >> 16 & 65535))
            (scare 'badfix kind)))

   ;; the linker's door. ARM is rel: movw16/movt16 read Rd back out of hw2, and the field must
   ;; equal patch's own zero-addend encoding or it refuses -- no inverse scatter. the thumb bit
   ;; in target passes through: every field shifts the offset right by at least one
   (thumb-refix kind bs target site width)
      (: aux (? (elem kind '(movw16 movt16)) (bs 3 & 15)      ; MOVW/MOVT t3: Rd, hw2 bits 11:8
                (kind = 'bcc) ((((bs 1 << 8) | bs 0) >> 6) & 15)  ; Bcc t3: the cond, hw1 bits 9:6
                0)
         (thumb-patch kind 0 0 width aux = bs ? 0 (scare 'thumb-refix-addend kind),
          thumb-patch kind target site width aux))

   thumb2 {'lower thumb-lower
           'patch thumb-patch
           'refix thumb-refix
           'nop '(0 191)}                ; nop bf00
   (defbackend 'thumb2 thumb2,
    defbackend 'thumb2sp thumb2,    ; single-precision fpu (playdate): gen softens f64
    defbackend 'arm thumb2))        ; linux armv7-a and up, in thumb-2
) ; module 'holo
