; arm64 -- the aarch64 BACKEND for the neutral assembler (crew/holo/holo.l), the second target. it shows
; the IR really is arch-neutral: the driver, the IR forms, the text front-end and the ELF linker are
; all untouched -- this file just pins a {lower,patch} pair under 'arm64 and 'aarch64. every word
; here was checked against llvm-mc (--show-encoding) and llvm-objdump.
;
; aarch64 is a joy to target: fixed 32-bit little-endian instructions, native three-address ALU, 31
; GPRs. so the IR's (add d a b) maps ONE-TO-ONE -- no two-address dance like x86 needed. the register
; file is the obvious one: r0..r14 -> x0..x14, sp -> the stack pointer (encoding 31). the awkward bit
; is branches: the pc-relative offset is a BITFIELD inside the instruction word, not a run of bytes,
; so a fixup carries the base opcode word in its `aux` slot and `patch` ORs the offset in.
;
; immediates: add/sub/cmp take a 12-bit immediate directly (a negative one flips the opcode). the
; logical ops (and/or/xor) and multiply have no simple immediate form (they need bitmask-immediate
; encoding / a scratch register), so an immediate there RAISES rather than emit wrong bytes -- put
; the value in a register. load after holo.l.

(: ;; -- registers: r0..r14 -> x0..x14, sp -> 31 (the SP/XZR slot; we only use 31 as SP). x16 (IP0) is
   ;;    an UNNAMED scratch the indexed stores borrow. `lr` (x30) and `fp` (x29) are exposed by name so
   ;;    a callee that makes nested calls can spill its return address (BL clobbers x30) -- aarch64-only,
   ;;    no x86 analogue (CALL/RET there keep the return address on the stack implicitly). --
   ;; abstract number = hardware x-number (identity), so x15..x18 are simply ABSENT: x16/x17 are the
   ;; IP0/IP1 scratch (the indexed stores borrow x16) and x18 is platform-reserved. r19..r28 are the
   ;; CALLEE-SAVED bank -- a glaze's args + OVF anchor live here so they survive nested `bl` (call) sites.
   arm64-regs (tablet 0)
   _ (foldl (\ _ p (pin arm64-regs (cap p) (cup p))) 0
        (L (link 'sp 31) (link 'fp 29) (link 'lr 30)
           (link 'r0 0) (link 'r1 1) (link 'r2 2) (link 'r3 3)  (link 'r4 4)
           (link 'r5 5) (link 'r6 6) (link 'r7 7) (link 'r8 8)  (link 'r9 9)
           (link 'r10 10) (link 'r11 11) (link 'r12 12) (link 'r13 13) (link 'r14 14) (link 'r15 15)
           (link 'r19 19) (link 'r20 20) (link 'r21 21) (link 'r22 22) (link 'r23 23) (link 'r24 24)
           (link 'r25 25) (link 'r26 26) (link 'r27 27) (link 'r28 28)))

   ;; -- ALU: op -> (reg-reg base word . imm base word | 0 if no immediate form). --
   arm64-alu (tablet 0)
   _ (foldl (\ _ p (pin arm64-alu (cap p) (cup p))) 0
        (L (link 'add (L 0x8B000000 0x91000000)) (link 'sub (L 0xCB000000 0xD1000000))
           (link 'and (L 0x8A000000 0)) (link 'or (L 0xAA000000 0)) (link 'xor (L 0xCA000000 0))
           (link 'adds (L 0xAB000000 0xB1000000)) (link 'subs (L 0xEB000000 0xF1000000))))   ; the S-variant: set NZCV

   ;; -- condition codes: IR name -> the A64 cond field (B.cond bits[3:0]). --
   arm64-cc (tablet 0)
   _ (foldl (\ _ p (pin arm64-cc (cap p) (cup p))) 0
        (L (link 'eq 0) (link 'ne 1) (link 'ae 2) (link 'below 3) (link 's 4) (link 'ns 5)
           (link 'vs 6) (link 'vc 7)
           (link 'above 8) (link 'be 9) (link 'ge 10) (link 'lt 11) (link 'gt 12) (link 'le 13)))

   (rn r) (: e (peep arm64-regs r -1) (? (< e 0) (scare 'badreg r) e))

   ;; (li d imm): MOVZ the low 16 bits, then MOVK each higher nonzero 16-bit lane (hw = lane index). the
   ;; lane extract is //% not &/>> -- a movz constant can be a full 64-bit word >= 2^63 (a BIGNUM in ai,
   ;; e.g. the map hash mult), on which `&` drops the high limb (cf. le64). negatives normalize into [0,2^64).
   (arm64-lane u k) (% (// u (k 65536)) 65536)                                   ; the k-th 16-bit lane (65536^k via (k 65536))
   (arm64-li d imm)
      (: dn (rn d) u (? (< imm 0) (+ imm 18446744073709551616) imm)
         l0 (arm64-lane u 0) l1 (arm64-lane u 1) l2 (arm64-lane u 2) l3 (arm64-lane u 3)
         (catall (L
            (le32 (| 0xD2800000 (| (<< l0 5) dn)))                              ; movz d, l0
            (? (= l1 0) () (le32 (| 0xF2800000 (| (<< 1 21) (| (<< l1 5) dn)))))  ; movk d, l1, lsl 16
            (? (= l2 0) () (le32 (| 0xF2800000 (| (<< 2 21) (| (<< l2 5) dn)))))  ; movk d, l2, lsl 32
            (? (= l3 0) () (le32 (| 0xF2800000 (| (<< 3 21) (| (<< l3 5) dn)))))))) ; movk d, l3, lsl 48

   (arm64-mov d s) (: dn (rn d) sn (rn s) (le32 (| 0xAA0003E0 (| (<< sn 16) dn))))   ; orr d, xzr, s

   ;; ALU. register form is the native three-address; immediate is add/sub only.
   (alu-rrr base d a b) (: dn (rn d) an (rn a) bn (rn b) (le32 (| base (| (<< bn 16) (| (<< an 5) dn)))))
   (alu-rri base d a imm) (: dn (rn d) an (rn a) (le32 (| base (| (<< imm 10) (| (<< an 5) dn)))))
   (arm64-addsub-imm op d a imm)                              ; a negative immediate flips the op (add<->sub, adds<->subs)
      (: pos  (? (< imm 0) (- 0 imm) imm)
         fop  (? (< imm 0) (? (= op 'add) 'sub (= op 'sub) 'add (= op 'adds) 'subs 'adds) op)
         base (at (peep arm64-alu fop 0) 1)                   ; the (flipped) op's immediate base word (slot 1 of its alu row)
         _ (? (<= pos 4095) 0 (scare 'imm12-range imm))
         (alu-rri base d a pos))
   ;; a logical (bitmask) immediate -> the N:immr:imms field packed at bits [22:10]. the full encoding
   ;; admits any replicated rotated run of ones; we encode the case the glaze emits -- a BOTTOM-ALIGNED
   ;; run (imm = 2^n - 1, the fixnum/gap low-bit masks): N=1, immr=0, imms=n-1. a rotated/replicated
   ;; pattern raises (materialize it into a register instead).
   (bitmask-field imm)
      (? (&& (> imm 0) (= 0 (& imm (+ imm 1))))                                 ; imm = 2^n - 1 (n ones at the bottom)
         (| 0x400000 (<< (- ((: (go k v) (? (= v 0) k (go (+ k 1) (>> v 1)))) 0 imm) 1) 10))   ; N=1 (bit22), imms = n-1
         (scare 'arm64-bitmask-imm imm))
   (arm64-logimm-base op) (? (= op 'and) 0x92000000 (= op 'or) 0xB2000000 (= op 'xor) 0xD2000000 (scare 'badlog op))
   (arm64-logical-imm op d a b) (: dn (rn d) an (rn a) (le32 (| (arm64-logimm-base op) (| (bitmask-field b) (| (<< an 5) dn)))))
   (arm64-aluop op d a b)
      (: meta (peep arm64-alu op 0) rrb (at meta 0) rib (at meta 1)
         (? (reg? b)    (alu-rrr rrb d a b)
            (= rib 0)   (arm64-logical-imm op d a b)               ; and/or/xor #imm via the bitmask encoder
            (arm64-addsub-imm op d a b)))

   (arm64-cmp a b)                                            ; subs xzr, a, b   /   cmp imm (cmn if neg)
      (: an (rn a)
         (? (reg? b) (: bn (rn b) (le32 (| 0xEB00001F (| (<< bn 16) (<< an 5)))))
            (: pos (? (< b 0) (- 0 b) b) base (? (< b 0) 0xB100001F 0xF100001F)
               _ (? (<= pos 4095) 0 (scare 'imm12-range b))
               (le32 (| base (| (<< pos 10) (<< an 5)))))))

   (arm64-imul d a b)                                         ; madd d, a, b, xzr  (= mul); no imm form
      (? (reg? b) (: dn (rn d) an (rn a) bn (rn b) (le32 (| 0x9B007C00 (| (<< bn 16) (| (<< an 5) dn)))))
         (scare 'arm64-mul-imm (L 'imul d a b)))

   ;; loads/stores: LDR/STR scaled (offset a multiple of 8, unsigned) else LDUR/STUR unscaled (signed
   ;; 9-bit). lea is just add-immediate (aarch64 has no lea).
   (arm64-mem-r lbase ubase dt bn off)                       ; raw-encoding variant (dt/bn already encodings; for x16-based stores)
      (? (&& (= 0 (% off 8)) (&& (>= off 0) (<= (// off 8) 4095)))
         (le32 (| ubase (| (<< (// off 8) 10) (| (<< bn 5) dt))))
         (? (&& (>= off -256) (<= off 255))
            (le32 (| lbase (| (<< (& off 511) 12) (| (<< bn 5) dt))))
            (scare 'mem-range off)))
   (arm64-mem lbase ubase d base off) (arm64-mem-r lbase ubase (rn d) (rn base) off)
   (arm64-ld d base off)   (arm64-mem 0xF8400000 0xF9400000 d base off)
   (arm64-st base off s)   (arm64-mem 0xF8000000 0xF9000000 s base off)
   ;; the sized family: scaled-imm12 units follow the access width, not 8
   (arm64-mem-sz lbase ubase sc d base off)
      (: dt (rn d) bn (rn base)
         (? (&& (= 0 (% off sc)) (&& (>= off 0) (<= (// off sc) 4095)))
            (le32 (| ubase (| (<< (// off sc) 10) (| (<< bn 5) dt))))
            (? (&& (>= off -256) (<= off 255))
               (le32 (| lbase (| (<< (& off 511) 12) (| (<< bn 5) dt))))
               (scare 'mem-range off))))
   (arm64-ld1 d base off) (arm64-mem-sz 0x38800000 0x39800000 1 d base off)   ; ldrsb/ldursb Xt
   (arm64-ld2 d base off) (arm64-mem-sz 0x78800000 0x79800000 2 d base off)   ; ldrsh/ldursh Xt
   (arm64-ld4 d base off) (arm64-mem-sz 0xB8800000 0xB9800000 4 d base off)   ; ldrsw/ldursw Xt
   (arm64-ldu1 d base off) (arm64-mem-sz 0x38400000 0x39400000 1 d base off)  ; ldrb/ldurb Wt (zero-extends to Xt)
   (arm64-ldu2 d base off) (arm64-mem-sz 0x78400000 0x79400000 2 d base off)  ; ldrh/ldurh Wt
   (arm64-ldu4 d base off) (arm64-mem-sz 0xB8400000 0xB9400000 4 d base off)  ; ldr/ldur Wt (32-bit, zero-extends)
   (arm64-st1 base off s) (arm64-mem-sz 0x38000000 0x39000000 1 s base off)   ; strb/sturb Wt
   (arm64-st2 base off s) (arm64-mem-sz 0x78000000 0x79000000 2 s base off)   ; strh/sturh Wt
   (arm64-st4 base off s) (arm64-mem-sz 0xB8000000 0xB9000000 4 s base off)   ; str/stur Wt
   (arm64-sx w d)                                             ; sbfm: sxtb/sxth/sxtw Xd, Wd
      (: dn (rn d)
         base (? (= w 1) 0x93401C00 (= w 2) 0x93403C00 0x93407C00)
         (le32 (| base (| (<< dn 5) dn))))
   (arm64-zx w d)                                             ; ubfm: uxtb/uxth Xd, Xd (w=4 clears bits 32..63)
      (: dn (rn d)
         base (? (= w 1) 0xD3401C00 (= w 2) 0xD3403C00 0xD3407C00)
         (le32 (| base (| (<< dn 5) dn))))
   (arm64-shiftv op d c)                                      ; lslv/lsrv/asrv Xd, Xd, Xc -- count pinned to r1 (the IR contract)
      (: _ (? (reg-eq c 'r1) 0 (scare 'shiftv-count-not-r1 (L op d c)))
         _ (? (reg-eq d 'r1) (scare 'shiftv-dst-is-r1 (L op d c)) 0)
         dn (rn d) cn (rn c)
         base (? (= op 'shlv) 0x9AC02000 (= op 'shrv) 0x9AC02400 0x9AC02800)
         (le32 (| base (| (<< cn 16) (| (<< dn 5) dn)))))
   (arm64-lea d base off)  (arm64-addsub-imm 'add d base off)

   (arm64-push s) (: st (rn s) (le32 (| 0xF81F0FE0 st)))      ; str s, [sp, #-16]!
   (arm64-pop  d) (: dt (rn d) (le32 (| 0xF84107E0 dt)))      ; ldr d, [sp], #16

   (arm64-neg d) (: dt (rn d) (le32 (| 0xCB0003E0 (| (<< dt 16) dt))))   ; sub d, xzr, d
   (arm64-not d) (: dt (rn d) (le32 (| 0xAA2003E0 (| (<< dt 16) dt))))   ; orn d, xzr, d (mvn)
   (arm64-inc d) (arm64-addsub-imm 'add d d 1)
   (arm64-dec d) (arm64-addsub-imm 'sub d d 1)

   ;; control: B/BL carry a 26-bit offset (bits[25:0]); B.cond a 19-bit one (bits[23:5]). the offset
   ;; is pc-relative to the instruction's OWN address, in units of 4. the fix is the whole word.
   (arm64-jmp  label)    (L (fix 4 'b26 label 0x14000000))
   (arm64-call label)    (L (fix 4 'b26 label 0x94000000))
   (arm64-la d label)    (L (fix 4 'adr21 label (| 0x10000000 (rn d))))   ; adr Xd, label (byte-granular, +-1MB)
   (arm64-br cond label) (: cc (peep arm64-cc cond -1) _ (? (< cc 0) (scare 'badcc cond) 0)
                            (L (fix 4 'b19 label (| 0x54000000 cc))))
   ;; jmpr: BR Xn -- branch to the address held in a register (the glaze's Continue / deopt tail).
   (arm64-jmpr d) (: dn (rn d) (le32 (| 0xD61F0000 (<< dn 5))))
   ;; callr: BLR Xn -- call the address held in a register (a call through a function pointer),
   ;; linking x30. same field as BR with bit 21 set.
   (arm64-callr d) (: dn (rn d) (le32 (| 0xD63F0000 (<< dn 5))))
   ;; mulo: d <- a*b (low 64); branch to lbl on signed overflow. aarch64 has NO flag-setting multiply,
   ;; so detect it directly: SMULH t,a,b is the high 64 bits of the signed product; the result fits a
   ;; signed 64 iff that high half equals the sign-extension of the low half. so MUL d,a,b ; CMP t, d
   ;; ASR #63 (== SUBS xzr, t, d, asr#63) ; B.NE lbl. SMULH runs FIRST (before MUL overwrites d), so
   ;; the scratch `t` MUST differ from a, b, and d.
   (arm64-mulo d a b t lbl)
      (: dn (rn d) an (rn a) bn (rn b) tn (rn t)
         (catall (L (le32 (| 0x9B407C00 (| (<< bn 16) (| (<< an 5) tn))))   ; smulh t, a, b   (high 64)
                    (le32 (| 0x9B007C00 (| (<< bn 16) (| (<< an 5) dn))))   ; mul   d, a, b   (low 64)
                    (le32 (| 0xEB80FC1F (| (<< dn 16) (<< tn 5))))          ; subs  xzr, t, d, asr #63  (cmp)
                    (L (fix 4 'b19 lbl 0x54000001)))))                      ; b.ne  lbl
   ;; set: d <- (cond) ? 1 : 0  --  CSET Xd, cond = CSINC Xd, xzr, xzr, invert(cond); inverting a
   ;; cond is XOR 1 (the A64 cond encoding pairs eq/ne, vs/vc, lt/ge, gt/le on bit 0).
   (arm64-set cond d)
      (: cc (peep arm64-cc cond -1) _ (? (< cc 0) (scare 'badcc cond) 0) dn (rn d)
         (le32 (| 0x9A9F07E0 (| (<< (^ cc 1) 12) dn))))
   ;; shifts/rotates by an immediate (the tag math -- sar/shr by 1; the map hash's rol by 32). LSL/LSR
   ;; are UBFM, ASR is SBFM, ROR is EXTR Xd,Xn,Xn,#c; ROL #c = ROR #(64-c) (aarch64 has no ROL).
   (arm64-shift op d c)
      (: dn (rn d)
         (? (= op 'shl) (le32 (| 0xD3400000 (| (<< (& (- 64 c) 63) 16) (| (<< (- 63 c) 10) (| (<< dn 5) dn)))))   ; lsl = ubfm immr=(-c)&63, imms=63-c
            (= op 'shr) (le32 (| 0xD3400000 (| (<< c 16) (| (<< 63 10) (| (<< dn 5) dn)))))                        ; lsr = ubfm immr=c, imms=63
            (= op 'sar) (le32 (| 0x93400000 (| (<< c 16) (| (<< 63 10) (| (<< dn 5) dn)))))                        ; asr = sbfm immr=c, imms=63
            (= op 'ror) (le32 (| 0x93C00000 (| (<< dn 16) (| (<< c 10) (| (<< dn 5) dn)))))                        ; ror = extr Rm=Rn=d, imms=c
            (= op 'rol) (le32 (| 0x93C00000 (| (<< dn 16) (| (<< (& (- 64 c) 63) 10) (| (<< dn 5) dn)))))          ; rol #c = ror #(64-c)
            (scare 'badshift op)))
   ;; test a, b -> TST = ANDS XZR, a, b (set NZCV from a AND b). a register, or a bitmask immediate
   ;; (the map probe's `test r0 1` low-bit/gap check) via the bitmask encoder; Rd = xzr (31).
   (arm64-test a b)
      (? (reg? b) (: an (rn a) bn (rn b) (le32 (| 0xEA00001F (| (<< bn 16) (<< an 5)))))
         (: an (rn a) (le32 (| 0xF200001F (| (bitmask-field b) (<< an 5))))))   ; ands xzr, a, #imm
   ;; signed division: SDIV is clean three-address. remainder = a - (a/b)*b via MSUB and a scratch t
   ;; (clobbered, != a, b -- SDIV writes t before MSUB re-reads a, b). caller guards b != 0.
   (arm64-div d a b)   (: dn (rn d) an (rn a) bn (rn b) (le32 (| 0x9AC00C00 (| (<< bn 16) (| (<< an 5) dn)))))   ; sdiv d, a, b
   (arm64-rem d a b t)
      (: dn (rn d) an (rn a) bn (rn b) tn (rn t)
         (catall (L (le32 (| 0x9AC00C00 (| (<< bn 16) (| (<< an 5) tn))))                   ; sdiv t, a, b
                    (le32 (| 0x9B008000 (| (<< bn 16) (| (<< an 10) (| (<< tn 5) dn))))))))  ; msub d, t, b, a  ->  a - t*b
   (arm64-udiv d a b)  (: dn (rn d) an (rn a) bn (rn b) (le32 (| 0x9AC00800 (| (<< bn 16) (| (<< an 5) dn)))))   ; udiv d, a, b
   (arm64-urem d a b t)
      (: dn (rn d) an (rn a) bn (rn b) tn (rn t)
         (catall (L (le32 (| 0x9AC00800 (| (<< bn 16) (| (<< an 5) tn))))                   ; udiv t, a, b
                    (le32 (| 0x9B008000 (| (<< bn 16) (| (<< an 10) (| (<< tn 5) dn))))))))  ; msub d, t, b, a
   ;; indexed addressing: aarch64 has no [base + ix*scale + disp] single insn, so synthesize. ADD makes
   ;; base + ix*scale (LSL #log2 scale); ldx/leax borrow the dest as the address temp, stx uses x16 (IP0,
   ;; outside the r0..r14 file, so it never clashes with an IR register).
   (arm64-shiftamt scale) (? (= scale 1) 0 (= scale 2) 1 (= scale 4) 2 (= scale 8) 3 (scare 'badscale scale))
   (arm64-addsh dn bn ixn amt) (le32 (| 0x8B000000 (| (<< ixn 16) (| (<< amt 10) (| (<< bn 5) dn)))))   ; add Xdn, Xbn, Xixn, lsl #amt
   (arm64-ldx d base index scale disp)
      (: dn (rn d) (catall (L (arm64-addsh dn (rn base) (rn index) (arm64-shiftamt scale)) (arm64-ld d d disp))))
   (arm64-leax d base index scale disp)
      (: dn (rn d) (catall (L (arm64-addsh dn (rn base) (rn index) (arm64-shiftamt scale)) (? (= disp 0) () (arm64-addsub-imm 'add d d disp)))))
   (arm64-stx base index scale disp s)
      (catall (L (arm64-addsh 16 (rn base) (rn index) (arm64-shiftamt scale))               ; add x16, base, index lsl #amt
                 (arm64-mem-r 0xF8000000 0xF9000000 (rn s) 16 disp)))                         ; str s, [x16, #disp]
   ;; byte indexed load/store (the string/cask/map byte lanes). LDRB zero-extends to W (clearing the top
   ;; 32 of X, == x86 movzx); STRB stores the low byte. disp is a raw BYTE offset (no scaling), unsigned
   ;; 12-bit. Same address synthesis as ldx/stx: ldxb borrows the dest as the address temp, stxb uses x16.
   (arm64-ldxb d base index scale disp)                                                       ; d = (byte)[base + index*scale + disp]
      (: dn (rn d) (catall (L (arm64-addsh dn (rn base) (rn index) (arm64-shiftamt scale))    ; add Xd, base, index lsl #amt
                             (le32 (| 0x39400000 (| (<< disp 10) (| (<< dn 5) dn)))))))         ; ldrb Wd, [Xd, #disp]
   (arm64-stxb base index scale disp s)                                                       ; [base + index*scale + disp] = (byte)s
      (catall (L (arm64-addsh 16 (rn base) (rn index) (arm64-shiftamt scale))                 ; add x16, base, index lsl #amt
                 (le32 (| 0x39000000 (| (<< disp 10) (| (<< 16 5) (rn s)))))))                 ; strb Ws, [x16, #disp]

   ;; -- scalar-double FP (the float glaze lane). f0..f15 -> v0..v15 (d-register view), a SEPARATE file
   ;;    from the GPRs. the IR carries the SSE mnemonics (addsd/movsd/...) two-address (d = op(d,s)); we
   ;;    map each to the arm64 scalar-double form, repeating d as the first source where arm64 is
   ;;    three-address. type=01 (double) throughout; every word was objdump-checked.
   arm64-fregs (tablet 0)
   _ (foldl (\ _ i (pin arm64-fregs (intern (+ "f" (show i))) i)) 0 (jot 16))                  ; f0..f15 -> 0..15
   (frn r) (: e (peep arm64-fregs r -1) (? (< e 0) (scare 'badfreg r) e))
   arm64-fp3 (tablet 0)                                                                         ; SSE arith mnemonic -> the scalar-double base word (Dd = Dn OP Dm)
   _ (foldl (\ _ p (pin arm64-fp3 (cap p) (cup p))) 0
        (L (link 'addsd 0x1E602800) (link 'subsd 0x1E603800) (link 'mulsd 0x1E600800) (link 'divsd 0x1E601800)))
   (arm64-fp3op op d s) (: dn (frn d) sn (frn s) (le32 (| (peep arm64-fp3 op 0) (| (<< sn 16) (| (<< dn 5) dn)))))   ; Dd = Dd OP Ds
   (arm64-fmov  d s) (: dn (frn d) sn (frn s) (le32 (| 0x1E604000 (| (<< sn 5) dn))))           ; FMOV Dd, Ds
   (arm64-fcmp  a b) (: an (frn a) bn (frn b) (le32 (| 0x1E602000 (| (<< bn 16) (<< an 5)))))   ; FCMP Da, Db (sets NZCV; unordered -> VS)
   (arm64-scvtf d g) (: dn (frn d) gn (rn g) (le32 (| 0x9E620000 (| (<< gn 5) dn))))            ; SCVTF Dd, Xg  (signed int -> double)
   (arm64-fcvtzs g d) (: gn (rn g) dn (frn d) (le32 (| 0x9E780000 (| (<< dn 5) gn))))           ; FCVTZS Xg, Dd  (double -> signed int, toward zero)
   (arm64-fmovxr d g) (: dn (frn d) gn (rn g) (le32 (| 0x9E670000 (| (<< gn 5) dn))))           ; FMOV Dd, Xg   (gpr bits -> fpr)  == movqxr
   (arm64-fmovrx g d) (: gn (rn g) dn (frn d) (le32 (| 0x9E660000 (| (<< dn 5) gn))))           ; FMOV Xg, Dd   (fpr -> gpr bits)  == movqrx
   (arm64-fst base disp s) (: tn (frn s) bn (rn base) (le32 (| 0xFD000000 (| (<< (// disp 8) 10) (| (<< bn 5) tn)))))   ; STR Ds, [base, #disp]  (disp a multiple of 8)
   (arm64-fld d base disp) (: dn (frn d) bn (rn base) (le32 (| 0xFD400000 (| (<< (// disp 8) 10) (| (<< bn 5) dn)))))   ; LDR Dd, [base, #disp]
   ;; the 4-byte single lane (the C `float` slot): widen/narrow via FCVT, load/store an S-register (disp a multiple of 4).
   (arm64-fcvt-widen  d s) (: dn (frn d) sn (frn s) (le32 (| 0x1E22C000 (| (<< sn 5) dn))))            ; FCVT Dd, Ss  (single -> double)  == cvtss2sd
   (arm64-fcvt-narrow d s) (: dn (frn d) sn (frn s) (le32 (| 0x1E624000 (| (<< sn 5) dn))))            ; FCVT Sd, Ds  (double -> single)  == cvtsd2ss
   (arm64-fsts base disp s) (: tn (frn s) bn (rn base) (le32 (| 0xBD000000 (| (<< (// disp 4) 10) (| (<< bn 5) tn)))))  ; STR Ss, [base, #disp]  (disp a multiple of 4)
   (arm64-flds d base disp) (: dn (frn d) bn (rn base) (le32 (| 0xBD400000 (| (<< (// disp 4) 10) (| (<< bn 5) dn)))))  ; LDR Sd, [base, #disp]
   (arm64-xorpd d s) (: dn (frn d) sn (frn s) (le32 (| 0x2E201C00 (| (<< sn 16) (| (<< dn 5) dn)))))   ; EOR Vd.8B, Vd.8B, Vs.8B (zero a double when d==s; the grid's fvar-init)

   (arm64-lower ins)
      (: op (cap ins)
         (? (= op 'li)   (arm64-li   (at ins 1) (at ins 2))
            (= op 'mov)  (arm64-mov  (at ins 1) (at ins 2))
            (= op 'cmp)  (arm64-cmp  (at ins 1) (at ins 2))
            (= op 'imul) (arm64-imul (at ins 1) (at ins 2) (at ins 3))
            (= op 'ld)   (arm64-ld   (at ins 1) (at ins 2) (at ins 3))
            (= op 'st)   (arm64-st   (at ins 1) (at ins 2) (at ins 3))
            (= op 'ld1)  (arm64-ld1  (at ins 1) (at ins 2) (at ins 3))
            (= op 'ld2)  (arm64-ld2  (at ins 1) (at ins 2) (at ins 3))
            (= op 'ld4)  (arm64-ld4  (at ins 1) (at ins 2) (at ins 3))
            (= op 'st1)  (arm64-st1  (at ins 1) (at ins 2) (at ins 3))
            (= op 'st2)  (arm64-st2  (at ins 1) (at ins 2) (at ins 3))
            (= op 'st4)  (arm64-st4  (at ins 1) (at ins 2) (at ins 3))
            (= op 'ldu1) (arm64-ldu1 (at ins 1) (at ins 2) (at ins 3))
            (= op 'ldu2) (arm64-ldu2 (at ins 1) (at ins 2) (at ins 3))
            (= op 'ldu4) (arm64-ldu4 (at ins 1) (at ins 2) (at ins 3))
            (= op 'sx1)  (arm64-sx 1 (at ins 1))
            (= op 'sx2)  (arm64-sx 2 (at ins 1))
            (= op 'sx4)  (arm64-sx 4 (at ins 1))
            (= op 'zx1)  (arm64-zx 1 (at ins 1))
            (= op 'zx2)  (arm64-zx 2 (at ins 1))
            (= op 'zx4)  (arm64-zx 4 (at ins 1))
            (member? op '(shlv shrv sarv)) (arm64-shiftv op (at ins 1) (at ins 2))
            (= op 'lea)  (arm64-lea  (at ins 1) (at ins 2) (at ins 3))
            (= op 'push) (arm64-push (at ins 1))
            (= op 'pop)  (arm64-pop  (at ins 1))
            (= op 'neg)  (arm64-neg  (at ins 1))
            (= op 'not)  (arm64-not  (at ins 1))
            (= op 'inc)  (arm64-inc  (at ins 1))
            (= op 'dec)  (arm64-dec  (at ins 1))
            (= op 'jmp)  (arm64-jmp  (at ins 1))
            (= op 'br)   (arm64-br   (at ins 1) (at ins 2))
            (= op 'jmpr) (arm64-jmpr (at ins 1))
            (= op 'callr) (arm64-callr (at ins 1))
            (= op 'mulo) (arm64-mulo (at ins 1) (at ins 2) (at ins 3) (at ins 4) (at ins 5))   ; (mulo d a b t lbl)
            (= op 'set)  (arm64-set  (at ins 1) (at ins 2))
            (member? op '(shl shr sar rol ror)) (arm64-shift op (at ins 1) (at ins 2))
            (= op 'test) (arm64-test (at ins 1) (at ins 2))
            (= op 'div)  (arm64-div  (at ins 1) (at ins 2) (at ins 3))
            (= op 'rem)  (arm64-rem  (at ins 1) (at ins 2) (at ins 3) (at ins 4))
            (= op 'udiv) (arm64-udiv (at ins 1) (at ins 2) (at ins 3))
            (= op 'urem) (arm64-urem (at ins 1) (at ins 2) (at ins 3) (at ins 4))
            (= op 'ldx)  (arm64-ldx  (at ins 1) (at ins 2) (at ins 3) (at ins 4) (at ins 5))
            (= op 'stx)  (arm64-stx  (at ins 1) (at ins 2) (at ins 3) (at ins 4) (at ins 5))
            (= op 'ldxb) (arm64-ldxb (at ins 1) (at ins 2) (at ins 3) (at ins 4) (at ins 5))   ; (ldxb d base index scale disp) -- zero-extend byte load
            (= op 'stxb) (arm64-stxb (at ins 1) (at ins 2) (at ins 3) (at ins 4) (at ins 5))   ; (stxb base index scale disp s) -- low-byte store
            (= op 'leax) (arm64-leax (at ins 1) (at ins 2) (at ins 3) (at ins 4) (at ins 5))
            (= op 'call) (arm64-call (at ins 1))
            (= op 'la)   (arm64-la   (at ins 1) (at ins 2))
            (= op 'raw)  (at ins 1)                                   ; splice pre-encoded bytes verbatim (no fixups)
            (= op 'movsd)    (arm64-fmov   (at ins 1) (at ins 2))                 ; -- scalar-double FP --
            (member? op '(addsd subsd mulsd divsd)) (arm64-fp3op op (at ins 1) (at ins 2))
            (= op 'ucomisd)  (arm64-fcmp   (at ins 1) (at ins 2))
            (= op 'cvtsi2sd) (arm64-scvtf  (at ins 1) (at ins 2))
            (= op 'cvttsd2si) (arm64-fcvtzs (at ins 1) (at ins 2))
            (= op 'movqxr)   (arm64-fmovxr (at ins 1) (at ins 2))
            (= op 'movqrx)   (arm64-fmovrx (at ins 1) (at ins 2))
            (= op 'stsd)     (arm64-fst    (at ins 1) (at ins 2) (at ins 3))      ; (stsd base disp f)
            (= op 'ldsd)     (arm64-fld    (at ins 1) (at ins 2) (at ins 3))      ; (ldsd f base disp)
            (= op 'cvtss2sd) (arm64-fcvt-widen  (at ins 1) (at ins 2))           ; (cvtss2sd d s)  single -> double
            (= op 'cvtsd2ss) (arm64-fcvt-narrow (at ins 1) (at ins 2))           ; (cvtsd2ss d s)  double -> single
            (= op 'stss)     (arm64-fsts   (at ins 1) (at ins 2) (at ins 3))      ; (stss base disp f)  4-byte single
            (= op 'ldss)     (arm64-flds   (at ins 1) (at ins 2) (at ins 3))      ; (ldss f base disp)  4-byte single
            (= op 'xorpd)    (arm64-xorpd  (at ins 1) (at ins 2))                 ; zero a double (d==s)
            (= op 'ret)  (le32 0xD65F03C0)                     ; ret x30
            (= op 'sys)  (le32 0xD4000001)                     ; svc #0
            (= op 'nop)  (le32 0xD503201F)
            (= op 'trap) (le32 0xD4200000)                     ; brk #0
            (two? (peep arm64-alu op ())) (arm64-aluop op (at ins 1) (at ins 2) (at ins 3))
            (scare 'bad-op op)))

   ;; a relocation: the offset is (target - site)/4, ORed into the base word `aux`.
   (arm64-patch kind target site width aux)
      (: rb (- target site)
         rel (// rb 4)
         (? (= kind 'b26) (le32 (| aux (& rel 67108863)))             ; 26-bit field, bits[25:0]
            (= kind 'b19) (le32 (| aux (<< (& rel 524287) 5)))        ; 19-bit field, bits[23:5]
            (= kind 'adr21) (le32 (| aux (| (<< (& rb 3) 29)          ; adr: BYTE offset, immlo[30:29]
                                            (<< (& (>> rb 2) 524287) 5))))   ; immhi[23:5]
            (= kind 'abs64) (le64 target)                            ; an 8-byte ABSOLUTE address (data pointer)
            (scare 'badfix kind)))

   arm64 (tablet 0)
   _ (pin arm64 'lower arm64-lower)
   _ (pin arm64 'patch arm64-patch)
   _ (defbackend 'arm64 arm64)
   _ (defbackend 'aarch64 arm64))

; the module span closes here (opened by holo-mark in crew/holo/holo.l): the names bound since
; the mark are the assembler; crew/holo/export.l sweeps them into the `holo` book.
(: holo-load (names ()))
