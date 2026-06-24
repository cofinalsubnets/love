; arm64 -- the aarch64 BACKEND for the neutral assembler (asm/asm.l), the second target. it shows
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
; the value in a register. load after asm.l.

(: ;; -- registers: r0..r14 -> x0..x14, sp -> 31 (the SP/XZR slot; we only use 31 as SP). --
   arm64-regs (tablet 0)
   _ (foldl (\ _ p (pin arm64-regs (cap p) (cup p))) 0
        (L (link 'sp 31)
           (link 'r0 0) (link 'r1 1) (link 'r2 2) (link 'r3 3)  (link 'r4 4)
           (link 'r5 5) (link 'r6 6) (link 'r7 7) (link 'r8 8)  (link 'r9 9)
           (link 'r10 10) (link 'r11 11) (link 'r12 12) (link 'r13 13) (link 'r14 14)))

   ;; -- ALU: op -> (reg-reg base word . imm base word | 0 if no immediate form). --
   arm64-alu (tablet 0)
   _ (foldl (\ _ p (pin arm64-alu (cap p) (cup p))) 0
        (L (link 'add (L 0x8B000000 0x91000000)) (link 'sub (L 0xCB000000 0xD1000000))
           (link 'and (L 0x8A000000 0)) (link 'or (L 0xAA000000 0)) (link 'xor (L 0xCA000000 0))))

   ;; -- condition codes: IR name -> the A64 cond field (B.cond bits[3:0]). --
   arm64-cc (tablet 0)
   _ (foldl (\ _ p (pin arm64-cc (cap p) (cup p))) 0
        (L (link 'eq 0) (link 'ne 1) (link 'ae 2) (link 'below 3) (link 's 4) (link 'ns 5)
           (link 'above 8) (link 'be 9) (link 'ge 10) (link 'lt 11) (link 'gt 12) (link 'le 13)))

   (rn r) (: e (peep arm64-regs r -1) (? (< e 0) (scare 'badreg r) e))

   ;; (li d imm): MOVZ the low 16 bits, then MOVK each higher nonzero 16-bit lane (hw = lane index).
   (arm64-lane imm k) (& (>> imm (* 16 k)) 65535)
   (arm64-li d imm)
      (: dn (rn d) l0 (arm64-lane imm 0) l1 (arm64-lane imm 1) l2 (arm64-lane imm 2) l3 (arm64-lane imm 3)
         (catall (L
            (le32 (| 0xD2800000 (| (<< l0 5) dn)))                              ; movz d, l0
            (? (= l1 0) () (le32 (| 0xF2800000 (| (<< 1 21) (| (<< l1 5) dn)))))  ; movk d, l1, lsl 16
            (? (= l2 0) () (le32 (| 0xF2800000 (| (<< 2 21) (| (<< l2 5) dn)))))  ; movk d, l2, lsl 32
            (? (= l3 0) () (le32 (| 0xF2800000 (| (<< 3 21) (| (<< l3 5) dn)))))))) ; movk d, l3, lsl 48

   (arm64-mov d s) (: dn (rn d) sn (rn s) (le32 (| 0xAA0003E0 (| (<< sn 16) dn))))   ; orr d, xzr, s

   ;; ALU. register form is the native three-address; immediate is add/sub only.
   (alu-rrr base d a b) (: dn (rn d) an (rn a) bn (rn b) (le32 (| base (| (<< bn 16) (| (<< an 5) dn)))))
   (alu-rri base d a imm) (: dn (rn d) an (rn a) (le32 (| base (| (<< imm 10) (| (<< an 5) dn)))))
   (arm64-addsub-imm op d a imm)                              ; a negative immediate flips add<->sub
      (: pos  (? (< imm 0) (- 0 imm) imm)
         flip (< imm 0)
         base (? (= op 'add) (? flip 0xD1000000 0x91000000) (? flip 0x91000000 0xD1000000))
         _ (? (<= pos 4095) 0 (scare 'imm12-range imm))
         (alu-rri base d a pos))
   (arm64-aluop op d a b)
      (: meta (peep arm64-alu op 0) rrb (at meta 0) rib (at meta 1)
         (? (reg? b)    (alu-rrr rrb d a b)
            (= rib 0)   (scare 'arm64-logical-imm (L op d a b))   ; and/or/xor #imm: bitmask, unsupported
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
   (arm64-mem lbase ubase d base off)
      (: dt (rn d) bn (rn base)
         (? (&& (= 0 (% off 8)) (&& (>= off 0) (<= (// off 8) 4095)))
            (le32 (| ubase (| (<< (// off 8) 10) (| (<< bn 5) dt))))
            (? (&& (>= off -256) (<= off 255))
               (le32 (| lbase (| (<< (& off 511) 12) (| (<< bn 5) dt))))
               (scare 'mem-range off))))
   (arm64-ld d base off)   (arm64-mem 0xF8400000 0xF9400000 d base off)
   (arm64-st base off s)   (arm64-mem 0xF8000000 0xF9000000 s base off)
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
   (arm64-br cond label) (: cc (peep arm64-cc cond -1) _ (? (< cc 0) (scare 'badcc cond) 0)
                            (L (fix 4 'b19 label (| 0x54000000 cc))))

   (arm64-lower ins)
      (: op (cap ins)
         (? (= op 'li)   (arm64-li   (at ins 1) (at ins 2))
            (= op 'mov)  (arm64-mov  (at ins 1) (at ins 2))
            (= op 'cmp)  (arm64-cmp  (at ins 1) (at ins 2))
            (= op 'imul) (arm64-imul (at ins 1) (at ins 2) (at ins 3))
            (= op 'ld)   (arm64-ld   (at ins 1) (at ins 2) (at ins 3))
            (= op 'st)   (arm64-st   (at ins 1) (at ins 2) (at ins 3))
            (= op 'lea)  (arm64-lea  (at ins 1) (at ins 2) (at ins 3))
            (= op 'push) (arm64-push (at ins 1))
            (= op 'pop)  (arm64-pop  (at ins 1))
            (= op 'neg)  (arm64-neg  (at ins 1))
            (= op 'not)  (arm64-not  (at ins 1))
            (= op 'inc)  (arm64-inc  (at ins 1))
            (= op 'dec)  (arm64-dec  (at ins 1))
            (= op 'jmp)  (arm64-jmp  (at ins 1))
            (= op 'br)   (arm64-br   (at ins 1) (at ins 2))
            (= op 'call) (arm64-call (at ins 1))
            (= op 'ret)  (le32 0xD65F03C0)                     ; ret x30
            (= op 'sys)  (le32 0xD4000001)                     ; svc #0
            (= op 'nop)  (le32 0xD503201F)
            (= op 'trap) (le32 0xD4200000)                     ; brk #0
            (two? (peep arm64-alu op ())) (arm64-aluop op (at ins 1) (at ins 2) (at ins 3))
            (scare 'bad-op op)))

   ;; a relocation: the offset is (target - site)/4, ORed into the base word `aux`.
   (arm64-patch kind target site width aux)
      (: rel (// (- target site) 4)
         (? (= kind 'b26) (le32 (| aux (& rel 67108863)))             ; 26-bit field, bits[25:0]
            (= kind 'b19) (le32 (| aux (<< (& rel 524287) 5)))        ; 19-bit field, bits[23:5]
            (scare 'badfix kind)))

   arm64 (tablet 0)
   _ (pin arm64 'lower arm64-lower)
   _ (pin arm64 'patch arm64-patch)
   _ (defbackend 'arm64 arm64)
   _ (defbackend 'aarch64 arm64))
