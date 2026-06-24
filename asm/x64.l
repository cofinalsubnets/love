; x64 -- the x86-64 BACKEND for the neutral assembler (asm/asm.l). it lowers each IR form to a list
; of machine-code bytes (and label fixups), in 64-bit operand mode throughout. every encoding here
; was checked against `objdump -d -M intel`: emit the bytes, disassemble, confirm the mnemonic.
;
; the abstract register file maps onto the 16 GPRs, reserving rsp as `sp` so r0..r14 are a clean
; general pool. the mapping is deliberate: r0=rax (so li/sys/ret land the result where the Linux
; syscall and SysV-return ABIs expect it):
;   sp->rsp  r0->rax r1->rcx r2->rdx r3->rbx  r4->rbp r5->rsi r6->rdi
;   r7->r8 r8->r9 r9->r10 r10->r11 r11->r12 r12->r13 r13->r14 r14->r15
; the two awkward x86 base registers therefore surface as sp (rsp, needs a SIB byte) and r4 (rbp,
; whose disp-less form is illegal) -- `mem` handles both, so [sp+off] and [r4+off] encode right.
;
; three-address ALU forms lower to x86's destructive two-address shape: (add d a b) becomes
; `mov d,a; add d,b`, elided when d==a, and swapped when d aliases b under a commutative op. a
; genuine three-way alias on a non-commutative op (d==b, d!=a) has no two-instruction encoding, so
; it raises rather than emit something subtly wrong.
;
; the data tables (registers, the ALU group, the condition codes) come FIRST: the emit functions
; read them by mutation-visible reference, the way tele's tape is defined before its users.

(: ;; -- the register file: abstract name -> x86 encoding number (rsp kept aside as sp). --
   x64-regs (tablet 0)
   _ (foldl (\ _ p (pin x64-regs (cap p) (cup p))) 0
        (L (link 'sp 4)
           (link 'r0 0) (link 'r1 1) (link 'r2 2) (link 'r3 3)  (link 'r4 5)
           (link 'r5 6) (link 'r6 7) (link 'r7 8) (link 'r8 9)  (link 'r9 10)
           (link 'r10 11) (link 'r11 12) (link 'r12 13) (link 'r13 14) (link 'r14 15)))

   ;; -- the ALU table: op -> (rr-opcode  imm-/digit  commutative?). --
   x64-alu (tablet 0)
   _ (foldl (\ _ p (pin x64-alu (cap p) (cup p))) 0
        (L (link 'add (L 1 0 1)) (link 'or (L 9 1 1)) (link 'and (L 33 4 1))
           (link 'sub (L 41 5 0)) (link 'xor (L 49 6 1))))

   ;; -- condition codes: IR name -> the 0F 8x opcode low byte. --
   x64-cc (tablet 0)
   _ (foldl (\ _ p (pin x64-cc (cap p) (cup p))) 0
        (L (link 'eq 132) (link 'ne 133) (link 'lt 140) (link 'ge 141)
           (link 'le 142) (link 'gt 143) (link 'below 130) (link 'ae 131)
           (link 'be 134) (link 'above 135) (link 's 136) (link 'ns 137)))

   ;; -- the encoding bytes: REX.WRXB, ModRM(mod,reg,rm), SIB(scale,index,base). --
   (rex w r x b) (| 64 (| (<< w 3) (| (<< r 2) (| (<< x 1) b))))    ; 0x40 | wrxb
   (modrm m reg rm) (| (<< m 6) (| (<< (& reg 7) 3) (& rm 7)))
   (sib sc ix bs)   (| (<< sc 6) (| (<< (& ix 7) 3) (& bs 7)))
   (hi n) (>> n 3)                                                  ; the REX extension bit of a reg
   (lo n) (& n 7)                                                   ; its low 3 bits (the ModRM field)
   (rn r) (: e (peep x64-regs r -1) (? (< e 0) (scare 'badreg r) e))

   ;; -- reg<-reg and reg<-imm32 forms, shared by mov/the ALU/cmp. --
   ;; alu-rr: OPCODE /r with ModRM.reg = source, ModRM.rm = dest (the AT&T `op %src,%dst`).
   (alu-rr opcode d s)
      (: dn (rn d) sn (rn s)
         (L (rex 1 (hi sn) 0 (hi dn)) opcode (modrm 3 sn dn)))
   ;; alu-ri: 0x81 /ext id -- the immediate group, `ext` selecting add/or/and/sub/xor/cmp.
   (alu-ri ext d imm)
      (: dn (rn d)
         (cat (L (rex 1 0 0 (hi dn)) 129 (modrm 3 ext dn)) (le32 imm)))
   (alu-step rr ext d y) (? (reg? y) (alu-rr rr d y) (alu-ri ext d y))
   (reg-eq a b) (= (rn a) (rn b))

   (emit-mov d s) (alu-rr 137 d s)                                  ; 0x89 mov r/m64, r64
   (emit-cmp a b) (alu-step 57 7 a b)                               ; 0x39 cmp / 0x81 /7

   ;; (li d imm): C7 /0 id for a signed-32 immediate, else a 10-byte movabs (B8+rd io).
   (emit-li d imm)
      (: dn (rn d)
         (? (fits32 imm)
            (cat (L (rex 1 0 0 (hi dn)) 199 (modrm 3 0 dn)) (le32 imm))
            (cat (L (rex 1 0 0 (hi dn)) (| 184 (lo dn))) (le64 imm))))

   ;; the three-address ALU, lowered to two-address (see the header).
   (emit-alu op d a b)
      (: meta (peep x64-alu op 0) rr (at meta 0) ext (at meta 1) comm (at meta 2)
         (? (reg-eq d a)                  (alu-step rr ext d b)
            (&& (reg? b) (reg-eq d b))    (? comm (alu-step rr ext d a) (scare 'alias-dst (L op d a b)))
            (cat (emit-mov d a) (alu-step rr ext d b))))

   ;; imul: the 3-operand reg<-reg<-imm (0x69 /r id) is a true three-address insn, no dance; the
   ;; reg<-reg<-reg case folds onto the two-address 0F AF /r the same way the ALU does.
   (imul-rr d s) (: dn (rn d) sn (rn s) (L (rex 1 (hi dn) 0 (hi sn)) 15 175 (modrm 3 dn sn)))
   (imul-ri d a imm) (: dn (rn d) an (rn a)
                        (cat (L (rex 1 (hi dn) 0 (hi an)) 105 (modrm 3 dn an)) (le32 imm)))
   (emit-imul d a b)
      (? (reg? b)
         (? (reg-eq d a) (imul-rr d b)
            (reg-eq d b)  (imul-rr d a)
            (cat (emit-mov d a) (imul-rr d b)))
         (imul-ri d a b))

   ;; shift/rotate by an immediate count: C1 /ext ib in general, the 1-byte-shorter D1 /ext for a count
   ;; of 1 (what tag math -- sar/shr by 1 -- mostly wants). ext selects the op (shl/shr/sar/rol/ror).
   (shift-ext op) (? (= op 'shl) 4 (= op 'shr) 5 (= op 'sar) 7 (= op 'rol) 0 (= op 'ror) 1 (scare 'badshift op))
   (emit-shift op d c)
      (: dn (rn d) ext (shift-ext op)
         (? (= c 1) (L (rex 1 0 0 (hi dn)) 209 (modrm 3 ext dn))                       ; D1 /ext        (count 1)
            (cat (L (rex 1 0 0 (hi dn)) 193 (modrm 3 ext dn)) (L (byte c)))))           ; C1 /ext ib

   ;; test: set flags from a AND b, discarding the result. 0x85 /r for reg,reg; 0xF7 /0 id for reg,imm32.
   (emit-test a b)
      (? (reg? b) (: an (rn a) bn (rn b) (L (rex 1 (hi bn) 0 (hi an)) 133 (modrm 3 bn an)))   ; 85 test r/m64,r64
         (: an (rn a) (cat (L (rex 1 0 0 (hi an)) 247 (modrm 3 0 an)) (le32 b))))             ; F7 /0 id

   ;; an indexed memory operand [base + index*scale + disp], scale in {1,2,4,8}: ALWAYS a SIB byte. the
   ;; rbp/r13-base 0-disp quirk applies (force a disp byte); rsp can be a base but NOT an index (enc 4 =
   ;; "no index"), which the abstract file already keeps as `sp`, never a general r0..r14.
   (scale-bits s) (? (= s 1) 0 (= s 2) 1 (= s 4) 2 (= s 8) 3 (scare 'badscale s))
   (memx regf base index scale disp)
      (: bn (rn base) ixn (rn index) sc (scale-bits scale)
         md (? (&& (= disp 0) (! (= (lo bn) 5))) 0 (? (fits8 disp) 1 2))
         dispb (? (= md 0) () (? (= md 1) (L (byte disp)) (le32 disp)))
         (cat (L (modrm md (lo regf) 4) (sib sc ixn bn)) dispb))
   (emit-ldx d base index scale disp)                              ; 0x8B mov r64, [base+index*scale+disp]
      (: dn (rn d) bn (rn base) ixn (rn index)
         (cat (L (rex 1 (hi dn) (hi ixn) (hi bn)) 139) (memx dn base index scale disp)))
   (emit-stx base index scale disp s)                              ; 0x89 mov [base+index*scale+disp], r64
      (: sn (rn s) bn (rn base) ixn (rn index)
         (cat (L (rex 1 (hi sn) (hi ixn) (hi bn)) 137) (memx sn base index scale disp)))
   (emit-leax d base index scale disp)                             ; 0x8D lea r64, [base+index*scale+disp]
      (: dn (rn d) bn (rn base) ixn (rn index)
         (cat (L (rex 1 (hi dn) (hi ixn) (hi bn)) 141) (memx dn base index scale disp)))

   ;; a memory operand [base+disp]: ModRM (+ SIB for an rsp/r12 base) (+ displacement). picks the
   ;; shortest disp form, and forces a 0-disp byte for an rbp/r13 base (its disp-less slot is taken).
   (mem regf base disp)
      (: bn (rn base) blo (lo bn)
         md (? (&& (= disp 0) (! (= blo 5))) 0 (? (fits8 disp) 1 2))
         head (? (= blo 4) (L (modrm md (lo regf) 4) (sib 0 4 blo)) (L (modrm md (lo regf) blo)))
         dispb (? (= md 0) () (? (= md 1) (L (byte disp)) (le32 disp)))
         (cat head dispb))
   (emit-ld d base off)                                             ; 0x8B mov r64, [base+off]
      (: dn (rn d) bn (rn base) (cat (L (rex 1 (hi dn) 0 (hi bn)) 139) (mem dn base off)))
   (emit-st base off s)                                             ; 0x89 mov [base+off], r64
      (: sn (rn s) bn (rn base) (cat (L (rex 1 (hi sn) 0 (hi bn)) 137) (mem sn base off)))
   (emit-lea d base off)                                            ; 0x8D lea r64, [base+off]
      (: dn (rn d) bn (rn base) (cat (L (rex 1 (hi dn) 0 (hi bn)) 141) (mem dn base off)))

   ;; push/pop: 0x50+rd / 0x58+rd, a bare REX.B (0x41) for the extended registers, no REX.W.
   (emit-push s) (: sn (rn s) (? (>= sn 8) (L 65 (| 80 (lo sn))) (L (| 80 sn))))
   (emit-pop  d) (: dn (rn d) (? (>= dn 8) (L 65 (| 88 (lo dn))) (L (| 88 dn))))

   ;; in-place unary: F7 /3 neg, F7 /2 not, FF /0 inc, FF /1 dec.
   (emit-un opcode ext d) (: dn (rn d) (L (rex 1 0 0 (hi dn)) opcode (modrm 3 ext dn)))

   ;; control transfer. call/jmp are E8/E9 cd; a conditional is 0F 8x cd. each leaves a rel32 fixup
   ;; the driver fills once the target label's address is known.
   (jcc-op c) (: o (peep x64-cc c -1) (? (< o 0) (scare 'badcc c) o))
   (emit-call label)     (L 232 (fix 4 'rel32 label))
   (emit-jmp  label)     (L 233 (fix 4 'rel32 label))
   (emit-br cond label)  (L 15 (jcc-op cond) (fix 4 'rel32 label))

   ;; the dispatch: one IR form -> its byte/fixup chunk.
   (x64-lower ins)
      (: op (cap ins)
         (? (= op 'li)   (emit-li   (at ins 1) (at ins 2))
            (= op 'mov)  (emit-mov  (at ins 1) (at ins 2))
            (= op 'cmp)  (emit-cmp  (at ins 1) (at ins 2))
            (= op 'imul) (emit-imul (at ins 1) (at ins 2) (at ins 3))
            (= op 'ld)   (emit-ld   (at ins 1) (at ins 2) (at ins 3))
            (= op 'st)   (emit-st   (at ins 1) (at ins 2) (at ins 3))
            (= op 'lea)  (emit-lea  (at ins 1) (at ins 2) (at ins 3))
            (= op 'ldx)  (emit-ldx  (at ins 1) (at ins 2) (at ins 3) (at ins 4) (at ins 5))   ; (ldx d base index scale disp)
            (= op 'stx)  (emit-stx  (at ins 1) (at ins 2) (at ins 3) (at ins 4) (at ins 5))   ; (stx base index scale disp s)
            (= op 'leax) (emit-leax (at ins 1) (at ins 2) (at ins 3) (at ins 4) (at ins 5))   ; (leax d base index scale disp)
            (= op 'test) (emit-test (at ins 1) (at ins 2))
            (member? op '(shl shr sar rol ror)) (emit-shift op (at ins 1) (at ins 2))
            (= op 'push) (emit-push (at ins 1))
            (= op 'pop)  (emit-pop  (at ins 1))
            (= op 'neg)  (emit-un 247 3 (at ins 1))
            (= op 'not)  (emit-un 247 2 (at ins 1))
            (= op 'inc)  (emit-un 255 0 (at ins 1))
            (= op 'dec)  (emit-un 255 1 (at ins 1))
            (= op 'jmp)  (emit-jmp  (at ins 1))
            (= op 'br)   (emit-br   (at ins 1) (at ins 2))
            (= op 'call) (emit-call (at ins 1))
            (= op 'ret)  (L 195)
            (= op 'sys)  (L 15 5)
            (= op 'nop)  (L 144)
            (= op 'trap) (L 204)
            (two? (peep x64-alu op ())) (emit-alu op (at ins 1) (at ins 2) (at ins 3))
            (scare 'bad-op op)))

   ;; the only relocation kind: a 32-bit pc-relative field, measured from the END of the field.
   (x64-patch kind target site width)
      (? (= kind 'rel32) (le32 (- target (+ site width))) (scare 'badfix kind))

   ;; -- register the backend under its target names. --
   x64 (tablet 0)
   _ (pin x64 'lower x64-lower)
   _ (pin x64 'patch x64-patch)
   _ (defbackend 'x64 x64)
   _ (defbackend 'amd64 x64))
