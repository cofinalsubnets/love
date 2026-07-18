; thumb2 -- the ARMv7E-M (Cortex-M7) BACKEND for the neutral assembler (crew/holo/holo.l), the third
; target. like arm64.l it pins a {lower,patch} pair (here under 'thumb2 and 'cortex-m7) and the driver,
; IR forms, and byte plumbing stay untouched -- but the ISA is a different animal from aarch64 despite
; the shared "ARM" name. this is 32-bit Thumb-2: MIXED 16/32-bit little-endian instructions, r0..r15
; (r13=sp, r14=lr, r15=pc), a two-address-ish data-processing surface. every word here was checked
; against `llvm-mc --triple=thumbv7em-none-eabi` (--disassemble / --show-encoding). load after holo.l.
;
; the byte order trap: a 32-bit Thumb-2 instruction is TWO 16-bit halfwords, the HIGH halfword FIRST
; in memory, each halfword little-endian. so word W = (hw1<<16)|hw2 lays as le16(hw1) ++ le16(hw2) --
; NOT le32(W). `t32` does exactly that; `t16` is one narrow halfword.
;
; the layout stays byte-granular (holo.l's chunk-len counts bytes, a fixup carries its byte width), so
; the mixed 16/32 widths just fall out -- each lowered form reports its own length, no special-casing.
;
; register file: abstract r0..r12 -> hardware r0..r12 (identity); sp->13, lr->14, pc->15, fp->11. we
; use the WIDE (32-bit) encodings uniformly for the data-processing ops (they reach r0..r12 evenly,
; where the narrow 16-bit forms only see r0..r7) -- correctness over compactness for this rung.
;
; immediates: add/sub take a plain 12-bit ADDW/SUBW (0..4095, a negative flips the op); cmp takes an
; 8-bit modified-immediate (0..255 rides through untouched). the logicals (and/or/xor) have only the
; Thumb modified-immediate form, so an immediate there RAISES -- moon's `immok` seam blocks it upstream
; and materializes the value into a register instead (mirrors arm64.l's bitmask stance).

(: ;; -- registers. abstract number = hardware number for r0..r12; sp/lr/pc/fp are named. r12 (IP) is
   ;;    the AAPCS intra-call scratch; the indexed stores borrow it as an unnamed address temp. --
   thumb-regs (tablet 0)
   _ (foldl (\ _ p (pin thumb-regs <p >p)) 0
        `((>< 'sp 13) (>< 'lr 14) (>< 'pc 15) (>< 'fp 11)
           (>< 'r0 0) (>< 'r1 1) (>< 'r2 2) (>< 'r3 3)  (>< 'r4 4)
           (>< 'r5 5) (>< 'r6 6) (>< 'r7 7) (>< 'r8 8)  (>< 'r9 9)
           (>< 'r10 10) (>< 'r11 11) (>< 'r12 12)))
   (rn r) (: e (peep thumb-regs r -1) (? (< e 0) (scare 'badreg r) e))

   ;; -- condition codes: IR name -> the AArch32 cond field (same 4-bit encoding aarch64 uses). --
   thumb-cc (tablet 0)
   _ (foldl (\ _ p (pin thumb-cc <p >p)) 0
        `((>< 'eq 0) (>< 'ne 1) (>< 'ae 2) (>< 'below 3) (>< 's 4) (>< 'ns 5)
           (>< 'vs 6) (>< 'vc 7) (>< 'p 6) (>< 'np 7)
           (>< 'above 8) (>< 'be 9) (>< 'ge 10) (>< 'lt 11) (>< 'gt 12) (>< 'le 13)))

   ;; -- emit: a narrow halfword, or a 32-bit word as hi-halfword-first little-endian pair. --
   (t16 w) (le16 w)
   (t32 w) (+ (le16 (>> w 16)) (le16 (& w 65535)))

   ;; (li d imm): MOVW the low 16, then MOVT the high 16 if nonzero. imm normalizes into [0,2^32).
   (thumb-movw d imm16)                                       ; MOVW Rd, #imm16  (T3)
      (: dn (rn d)
         hw1 (| 0xF240 (| (<< (& (>> imm16 11) 1) 10) (& (>> imm16 12) 15)))    ; i (bit11), imm4 (bits15:12)
         hw2 (| (<< (& (>> imm16 8) 7) 12) (| (<< dn 8) (& imm16 255)))         ; imm3 (bits10:8), Rd, imm8
         (t32 (| (<< hw1 16) hw2)))
   (thumb-movt d imm16)                                       ; MOVT Rd, #imm16  (T1) -- sets the top halfword
      (: dn (rn d)
         hw1 (| 0xF2C0 (| (<< (& (>> imm16 11) 1) 10) (& (>> imm16 12) 15)))
         hw2 (| (<< (& (>> imm16 8) 7) 12) (| (<< dn 8) (& imm16 255)))
         (t32 (| (<< hw1 16) hw2)))
   (thumb-li d imm)
      (: u (? (< imm 0) (+ imm 4294967296) imm) lo (& u 65535) hi (& (>> u 16) 65535)
         (+ (thumb-movw d lo) (? (= hi 0) () (thumb-movt d hi))))

   (thumb-mov d s) (: dn (rn d) sn (rn s) (t32 (| 0xEA4F0000 (| (<< dn 8) sn))))   ; MOV.W Rd, Rm (ORR Rd,Rn=15,Rm)

   ;; -- ALU register form (wide, three-address): op -> the hw1 base (S=0). d = a OP b. --
   thumb-alu (tablet 0)
   _ (foldl (\ _ p (pin thumb-alu <p >p)) 0
        `((>< 'add 0xEB00) (>< 'sub 0xEBA0) (>< 'and 0xEA00) (>< 'or 0xEA40) (>< 'xor 0xEA80)
           (>< 'adds 0xEB10) (>< 'subs 0xEBB0)))               ; the S-variant: set the flags
   (thumb-alu-rrr base d a b)                                 ; hw1 = base|Rn(a); hw2 = Rd<<8 | Rm(b)
      (: dn (rn d) an (rn a) bn (rn b) (t32 (| (<< (| base an) 16) (| (<< dn 8) bn))))
   ;; add/sub #imm12 via ADDW/SUBW (T4): a plain 12-bit unsigned; a negative flips the op.
   (thumb-addsub-imm op d a imm)
      (: pos (? (< imm 0) (- 0 imm) imm)
         fop (? (< imm 0) (? (= op 'add) 'sub (= op 'sub) 'add op) op)
         _   (? (<= pos 4095) 0 (scare 'imm12-range imm))
         base (? (= fop 'add) 0xF200 0xF2A0)                   ; ADDW / SUBW hw1 base
         dn (rn d) an (rn a)
         hw1 (| base (| (<< (& (>> pos 11) 1) 10) an))         ; i = imm12 bit 11
         hw2 (| (<< (& (>> pos 8) 7) 12) (| (<< dn 8) (& pos 255)))   ; imm3, Rd, imm8
         (t32 (| (<< hw1 16) hw2)))
   (thumb-aluop op d a b)
      (: base (peep thumb-alu op 0)
         (? (reg? b) (thumb-alu-rrr base d a b)
            (member? op '(add sub)) (thumb-addsub-imm op d a b)
            (scare 'thumb-logimm `(op d a b))))                ; and/or/xor #imm: materialize instead (immok blocks it)

   (thumb-cmp a b)                                            ; CMP.W Rn, Rm  /  CMP Rn, #imm8 (T2)
      (: an (rn a)
         (? (reg? b) (: bn (rn b) (t32 (| (<< (| 0xEBB0 an) 16) (| 0x0F00 bn))))
            (: pos (? (< b 0) (- 0 b) b)
               _ (? (<= pos 255) 0 (scare 'cmp-imm-range b))
               ; a negative compares via CMN (SUB->ADD): hw1 base 0xF110 vs CMP's 0xF1B0
               (t32 (| (<< (| (? (< b 0) 0xF110 0xF1B0) an) 16) (| 0x0F00 pos))))))

   (thumb-imul d a b)                                         ; MUL Rd, Rn, Rm (T2); no immediate form
      (? (reg? b) (: dn (rn d) an (rn a) bn (rn b) (t32 (| (<< (| 0xFB00 an) 16) (| 0xF000 (| (<< dn 8) bn)))))
         (scare 'thumb-mul-imm `('imul d a b)))

   ;; loads/stores. LDR/STR Rt,[Rn,#imm12] (T3, positive 0..4095) else the T4 8-bit signed offset
   ;; (a frame slot's small negative). the FAR lane (offsets past that, via an r12 materialize) is
   ;; M1-deferred -- trivial-function frames stay well inside. disp is a raw byte offset.
   (thumb-mem-r lbase ubase dt bn off)                       ; dt/bn already encodings
      (? (&& (>= off 0) (<= off 4095))
         (t32 (| (<< (| ubase bn) 16) (| (<< dt 12) off)))
         (&& (>= off -255) (< off 0))
         (t32 (| (<< (| lbase bn) 16) (| (<< dt 12) (| 0xC00 (- 0 off)))))   ; T4: P=1 U=0 W=0 = 0b1100, imm8=|off|
         (scare 'mem-range off))
   (thumb-mem lbase ubase d base off) (thumb-mem-r lbase ubase (rn d) (rn base) off)
   ;; the word ops (`ld`/`st`) are 32-bit here (a 32-bit target's word); the sized family follows.
   (thumb-ld d base off)  (thumb-mem 0xF850 0xF8D0 d base off)   ; LDR.W  (T4 neg / T3 pos)
   (thumb-st base off s)  (thumb-mem 0xF840 0xF8C0 s base off)   ; STR.W
   (thumb-ld4 d base off) (thumb-mem 0xF850 0xF8D0 d base off)   ; int == word on a 32-bit target
   (thumb-st4 base off s) (thumb-mem 0xF840 0xF8C0 s base off)
   (thumb-ldu1 d base off) (thumb-mem 0xF810 0xF890 d base off)  ; LDRB (zero-extend)
   (thumb-ldu2 d base off) (thumb-mem 0xF830 0xF8B0 d base off)  ; LDRH
   (thumb-ld1 d base off)  (thumb-mem 0xF910 0xF990 d base off)  ; LDRSB (sign-extend)
   (thumb-ld2 d base off)  (thumb-mem 0xF930 0xF9B0 d base off)  ; LDRSH
   (thumb-st1 base off s)  (thumb-mem 0xF800 0xF880 s base off)  ; STRB
   (thumb-st2 base off s)  (thumb-mem 0xF820 0xF8A0 s base off)  ; STRH

   (thumb-lea d base off)  (thumb-addsub-imm 'add d base off)

   (thumb-push s) (: st (rn s) (t32 (| 0xF84D0000 (| (<< st 12) (| 0xD00 4)))))   ; STR Rt,[sp,#-4]!  P=1 U=0 W=1, imm8=4
   (thumb-pop  d) (: dt (rn d) (t32 (| 0xF85D0000 (| (<< dt 12) (| 0xB00 4)))))   ; LDR Rt,[sp],#4    P=0 U=1 W=1 (bit11=1), imm8=4

   (thumb-neg d) (: dn (rn d) (t32 (| (<< (| 0xF1C0 dn) 16) (<< dn 8))))          ; RSB Rd, Rd, #0
   (thumb-not d) (: dn (rn d) (t32 (| 0xEA6F0000 (| (<< dn 8) dn))))              ; MVN.W Rd, Rm
   (thumb-inc d) (thumb-addsub-imm 'add d d 1)
   (thumb-dec d) (thumb-addsub-imm 'sub d d 1)

   ;; shifts by an immediate: MOV.W Rd, Rm, <type> #count  (type: lsl 0 lsr 1 asr 2 ror 3). in place.
   (thumb-shift op d c)
      (: dn (rn d)
         ty (? (= op 'shl) 0 (= op 'shr) 1 (= op 'sar) 2 (= op 'ror) 3 (scare 'badshift op))
         hw2 (| (<< (& (>> c 2) 7) 12) (| (<< dn 8) (| (<< (& c 3) 6) (| (<< ty 4) dn))))
         (t32 (| 0xEA4F0000 hw2)))
   ;; shift by a register (count in r1, the IR contract; d in place, d != r1): LSL/LSR/ASR.W Rd,Rd,Rc.
   (thumb-shiftv op d c)
      (: _ (? (reg-eq c 'r1) 0 (scare 'shiftv-count-not-r1 `(op d c)))
         dn (rn d) cn (rn c)
         base (? (= op 'shlv) 0xFA00 (= op 'shrv) 0xFA20 (= op 'sarv) 0xFA40 (scare 'badshiftv op))
         (t32 (| (<< (| base dn) 16) (| 0xF000 (| (<< dn 8) cn)))))

   ;; signed/unsigned divide (T1); remainder = a - (a/b)*b via MLS and a scratch t.
   (thumb-div d a b)  (: dn (rn d) an (rn a) bn (rn b) (t32 (| (<< (| 0xFB90 an) 16) (| 0xF0F0 (| (<< dn 8) bn)))))   ; SDIV
   (thumb-udiv d a b) (: dn (rn d) an (rn a) bn (rn b) (t32 (| (<< (| 0xFBB0 an) 16) (| 0xF0F0 (| (<< dn 8) bn)))))   ; UDIV
   (thumb-mls d n m a) (: dn (rn d) nn (rn n) mn (rn m) an (rn a) (t32 (| (<< (| 0xFB00 nn) 16) (| (<< an 12) (| (<< dn 8) (| 0x10 mn))))))
   (thumb-rem d a b t)  (+ (thumb-div t a b)  (thumb-mls d t b a))      ; t=a/b ; d = a - t*b
   (thumb-urem d a b t) (+ (thumb-udiv t a b) (thumb-mls d t b a))

   ;; test a, b -> TST.W (ANDS Rn, Rm, Rd discarded to pc/15). register only for M1.
   (thumb-test a b)
      (? (reg? b) (: an (rn a) bn (rn b) (t32 (| (<< (| 0xEA10 an) 16) (| 0x0F00 bn))))
         (scare 'thumb-test-imm `('test a b)))

   ;; set: d <- (cond) ? 1 : 0, via an IT block. MOV d,#0 ; IT cond ; MOV d,#1 (the conditional one).
   ;; MOVW reaches all of r0..r12 (the narrow MOV only r0..r7), so use it uniformly.
   (thumb-set cond d)
      (: cc (peep thumb-cc cond -1) _ (? (< cc 0) (scare 'badcc cond) 0)
         (catall `((thumb-movw d 0) (t16 (| 0xBF08 (<< cc 4))) (thumb-movw d 1))))

   ;; control. B/BL carry a scrambled pc-relative offset in a bitfield; the fixup stashes the cond (or 0)
   ;; in aux and `patch` builds the whole 4-byte word. an unconditional B (jmp) rides T4, a conditional
   ;; one (br) rides T3, and BL (call) rides T1 -- all 32-bit, all 4-byte fixups.
   (thumb-jmp  label) `((fix 4 'b   label 0))
   (thumb-call label) `((fix 4 'bl  label 0))
   (thumb-br cond label) (: cc (peep thumb-cc cond -1) _ (? (< cc 0) (scare 'badcc cond) 0)
                            `((fix 4 'bcc label cc)))
   (thumb-jmpr d)  (: dn (rn d) (t16 (| 0x4700 (<< dn 3))))    ; BX Rm
   (thumb-callr d) (: dn (rn d) (t16 (| 0x4780 (<< dn 3))))    ; BLX Rm

   (thumb-lower ins)
      (: op <ins
         (? (= op 'li)   (thumb-li   (at ins 1) (at ins 2))
            (= op 'mov)  (thumb-mov  (at ins 1) (at ins 2))
            (= op 'cmp)  (thumb-cmp  (at ins 1) (at ins 2))
            (= op 'imul) (thumb-imul (at ins 1) (at ins 2) (at ins 3))
            (= op 'ld)   (thumb-ld   (at ins 1) (at ins 2) (at ins 3))
            (= op 'st)   (thumb-st   (at ins 1) (at ins 2) (at ins 3))
            (= op 'ld1)  (thumb-ld1  (at ins 1) (at ins 2) (at ins 3))
            (= op 'ld2)  (thumb-ld2  (at ins 1) (at ins 2) (at ins 3))
            (= op 'ld4)  (thumb-ld4  (at ins 1) (at ins 2) (at ins 3))
            (= op 'st1)  (thumb-st1  (at ins 1) (at ins 2) (at ins 3))
            (= op 'st2)  (thumb-st2  (at ins 1) (at ins 2) (at ins 3))
            (= op 'st4)  (thumb-st4  (at ins 1) (at ins 2) (at ins 3))
            (= op 'ldu1) (thumb-ldu1 (at ins 1) (at ins 2) (at ins 3))
            (= op 'ldu2) (thumb-ldu2 (at ins 1) (at ins 2) (at ins 3))
            (= op 'ldu4) (thumb-ld4  (at ins 1) (at ins 2) (at ins 3))   ; 32-bit zero-extend == word load here
            (member? op '(shlv shrv sarv)) (thumb-shiftv op (at ins 1) (at ins 2))
            (= op 'lea)  (thumb-lea  (at ins 1) (at ins 2) (at ins 3))
            (= op 'lean) (thumb-lea  (at ins 1) (at ins 2) (at ins 3))
            (= op 'push) (thumb-push (at ins 1))
            (= op 'pop)  (thumb-pop  (at ins 1))
            (= op 'neg)  (thumb-neg  (at ins 1))
            (= op 'not)  (thumb-not  (at ins 1))
            (= op 'inc)  (thumb-inc  (at ins 1))
            (= op 'dec)  (thumb-dec  (at ins 1))
            (= op 'jmp)  (thumb-jmp  (at ins 1))
            (= op 'br)   (thumb-br   (at ins 1) (at ins 2))
            (= op 'jmpr) (thumb-jmpr (at ins 1))
            (= op 'callr) (thumb-callr (at ins 1))
            (= op 'set)  (thumb-set  (at ins 1) (at ins 2))
            (member? op '(shl shr sar rol ror)) (thumb-shift op (at ins 1) (at ins 2))
            (= op 'test) (thumb-test (at ins 1) (at ins 2))
            (= op 'div)  (thumb-div  (at ins 1) (at ins 2) (at ins 3))
            (= op 'rem)  (thumb-rem  (at ins 1) (at ins 2) (at ins 3) (at ins 4))
            (= op 'udiv) (thumb-udiv (at ins 1) (at ins 2) (at ins 3))
            (= op 'urem) (thumb-urem (at ins 1) (at ins 2) (at ins 3) (at ins 4))
            (= op 'call) (thumb-call (at ins 1))
            (= op 'raw)  (at ins 1)                            ; splice pre-encoded bytes verbatim
            (= op 'ret)  (t16 0x4770)                          ; BX lr
            (= op 'sys)  (t16 0xDF00)                          ; SVC #0
            (= op 'nop)  (t16 0xBF00)
            (= op 'trap) (t16 0xBE00)                          ; BKPT #0
            (imm? (peep thumb-alu op ())) (thumb-aluop op (at ins 1) (at ins 2) (at ins 3))   ; add/sub/and/or/xor/adds/subs
            (scare 'bad-op op)))

   ;; a relocation. Thumb pc reads as (site + 4), and the branch fields hold a /2 (halfword) offset
   ;; scrambled across S/J1/J2. patch computes the byte offset O = target-(site+4) then packs it.
   ;;   b   (T4, unconditional, jmp):  imm25 = S:I1:I2:imm10:imm11:0, I1=~(J1^S), I2=~(J2^S)
   ;;   bl  (T1, call):                same offset packing, hw2 base 0xD000 (vs B's 0x9000)
   ;;   bcc (T3, conditional br):      imm21 = S:J2:J1:imm6:imm11:0 (no ~), cond in hw1, aux carries it
   (thumb-patch kind target site width aux)
      (: o (- target (+ site 4))
         (? (member? kind '(b bl))
            (: imm11 (& (>> o 1) 2047)  imm10 (& (>> o 12) 1023)
               i2 (& (>> o 22) 1)  i1 (& (>> o 23) 1)  s (& (>> o 24) 1)
               j1 (& (^ (^ i1 1) s) 1)  j2 (& (^ (^ i2 1) s) 1)
               hw1 (| 0xF000 (| (<< s 10) imm10))
               hw2 (| (? (= kind 'bl) 0xD000 0x9000) (| (<< j1 13) (| (<< j2 11) imm11)))
               (t32 (| (<< hw1 16) hw2)))
            (= kind 'bcc)
            (: imm11 (& (>> o 1) 2047)  imm6 (& (>> o 12) 63)
               j1 (& (>> o 18) 1)  j2 (& (>> o 19) 1)  s (& (>> o 20) 1)
               hw1 (| 0xF000 (| (<< s 10) (| (<< aux 6) imm6)))
               hw2 (| 0x8000 (| (<< j1 13) (| (<< j2 11) imm11)))
               (t32 (| (<< hw1 16) hw2)))
            (scare 'badfix kind)))

   thumb2 (tablet 0)
   _ (pin thumb2 'lower thumb-lower)
   _ (pin thumb2 'patch thumb-patch)
   _ (pin thumb2 'nop `(0 191))                ; the ('align n) filler unit: NOP (16-bit) bf00 LE
   _ (defbackend 'thumb2 thumb2)
   _ (defbackend 'cortex-m7 thumb2))
