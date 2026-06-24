; asmtest -- the gate for the neutral assembler + its x86-64 backend. each golden below is the exact
; hex the assembler emits, and EVERY one was checked against the real toolchain: emit the bytes,
; `objdump -d -M intel`, confirm the mnemonic. so this file is the frozen record of that round-trip
; -- if a golden drifts, either the encoder broke or the disassembler disagrees, and either is a bug.
; run: out/host/ai -l asm/asm.l -l asm/x64.l -l asm/arm64.l -l asm/text.l -l asm/elf.l asm/asmtest.l
; (exits nonzero on any miss). it gates both backends, the text front-end, and the ELF linker.

(: pass (tablet 0) _ (pin pass 0 0)
   fail (tablet 0) _ (pin fail 0 0)
   (bump t)  (pin t 0 (+ 1 (peep t 0 0)))
   (sayln s) (: _ (puts s) (flush out))
   (chk-eq name want got)
      (? (= want got) (bump pass)
         (: _ (bump fail)
            (sayln (+ "FAIL " (+ name (+ ": want " (+ (show want) (+ " got " (+ (show got) "\n")))))))))
   (chk2 name want target prog) (chk-eq name want (asm-hex target prog))
   (chk name want prog) (chk2 name want 'x64 prog)

   ;; -- the golden table: (name  expected-hex  IR-program). --
   tests (L
      ;; immediates
      (L "li.small"    "48c7c03c000000"        '((li r0 60)))
      (L "li.neg1"     "48c7c0ffffffff"        '((li r0 -1)))
      (L "li.movabs"   "48b84c9c8cdac1fc0300"  '((li r0 1122334455667788)))
      ;; register moves (low + REX-extended)
      (L "mov.rr"      "4889d8"                '((mov r0 r3)))
      (L "mov.ext"     "4d89f8"                '((mov r7 r14)))
      ;; ALU, register source
      (L "add.rr"      "4801d8"                '((add r0 r0 r3)))
      (L "sub.rr"      "4829c8"                '((sub r0 r0 r1)))
      (L "xor.zero"    "4831c0"                '((xor r0 r0 r0)))
      (L "or.rr"       "4809c8"                '((or  r0 r0 r1)))
      (L "and.rr"      "4821c8"                '((and r0 r0 r1)))
      ;; ALU, immediate source (0x81 group)
      (L "add.imm"     "4881c005000000"        '((add r0 r0 5)))
      (L "cmp.imm"     "4881f807000000"        '((cmp r0 7)))
      (L "cmp.rr"      "4839d8"                '((cmp r0 r3)))
      ;; three-address -> two-address lowering
      (L "alu.movop"   "4889c24829da"          '((sub r2 r0 r3)))   ; mov rdx,rax ; sub rdx,rbx
      (L "alu.swap"    "4801d8"                '((add r0 r3 r0)))   ; commutes -> add rax,rbx, no mov
      ;; imul (true 3-operand imm form; rr folds two-address)
      (L "imul.rr"     "480fafc3"              '((imul r0 r0 r3)))
      (L "imul.imm"    "4869d007000000"        '((imul r2 r0 7)))
      ;; memory: the rsp(SIB) and rbp(forced-disp) base quirks, disp8 + disp32
      (L "ld.base"     "488b07"                '((ld r0 r6 0)))
      (L "ld.disp8"    "488b4708"              '((ld r0 r6 8)))
      (L "ld.rbp0"     "488b4500"              '((ld r0 r4 0)))     ; rbp base forces a 0 disp byte
      (L "ld.rbp.d8"   "488b4564"              '((ld r0 r4 100)))
      (L "st.sib"      "4889442410"            '((st sp 16 r0)))    ; rsp base needs a SIB byte
      (L "st.disp32"   "48899c2400010000"      '((st sp 256 r3)))
      (L "lea.disp8"   "488d4710"              '((lea r0 r6 16)))
      (L "lea.neg"     "488d6424e0"            '((lea sp sp -32)))
      ;; stack
      (L "push.pop"    "5059"                  '((push r0) (pop r1)))
      (L "push.ext"    "41504158"              '((push r7) (pop r7)))
      ;; shifts & rotates: D1 /ext for a count of 1, C1 /ext ib otherwise
      (L "sar.1"       "48d1f8"                '((sar r0 1)))      ; the fixnum untag (rax)
      (L "shr.1.ext"   "49d1e9"                '((shr r8 1)))      ; r8 -> x86 r9 (REX.B): shr r9,1
      (L "shl.imm"     "48c1e004"              '((shl r0 4)))
      (L "rol.32"      "48c1c020"              '((rol r0 32)))     ; the hash rotate (rol rax,32)
      (L "sar.imm.ext" "49c1fd05"              '((sar r12 5)))     ; r12 -> x86 r13: sar r13,5
      ;; test: 0x85 /r reg,reg ; 0xF7 /0 id reg,imm32
      (L "test.rr"     "4885c0"                '((test r0 r0)))    ; test rax,rax (divide-by-zero check)
      (L "test.imm"    "48f7c001000000"        '((test r0 1)))     ; test rax,1   (the fixnum low-bit guard)
      ;; SIB memory: [base + index*scale + disp]. r7->x86 r8, r10->x86 r11 (the map-probe's slot regs)
      (L "leax.1.1"    "488d4c0001"            '((leax r1 r0 r0 1 1)))   ; lea rcx,[rax+rax*1+1]
      (L "leax.dbl"    "4c8d1c12"              '((leax r10 r2 r2 1 0)))  ; lea r11,[rdx+rdx*1]
      (L "ldx.scale8"  "4b8b04d8"              '((ldx r0 r7 r10 8 0)))   ; mov rax,[r8+r11*8]
      (L "ldx.s8.d8"   "4b8b44d808"            '((ldx r0 r7 r10 8 8)))   ; mov rax,[r8+r11*8+8]
      (L "stx.scale4"  "48890c98"              '((stx r0 r3 4 0 r1)))    ; mov [rax+rbx*4],rcx
      ;; unary in-place
      (L "neg"         "48f7d8"                '((neg r0)))
      (L "not"         "48f7d3"                '((not r3)))
      (L "inc"         "48ffc0"                '((inc r0)))
      (L "dec"         "48ffcf"                '((dec r6)))
      ;; zero-operand
      (L "ret"         "c3"                    '((ret)))
      (L "sys"         "0f05"                  '((sys)))
      (L "nop"         "90"                    '((nop)))
      (L "trap"        "cc"                    '((trap)))
      ;; control flow with label fixups (rel32, measured from end of field)
      (L "call.fwd"    "e800000000c3"          '((call foo) (label foo) (ret)))
      (L "loop"        "4839c80f840800000048ffc8e9efffffffc3"
                       '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret)))
      (L "jcc.all"
         "0f8c240000000f851e0000000f8f180000000f8d120000000f8e0c0000000f87060000000f8200000000c3"
         '((br lt a) (br ne a) (br gt a) (br ge a) (br le a) (br above a) (br below a) (label a) (ret)))
      ;; a whole program: write(1, buf, 13); exit(0)  -- r0=rax carries the syscall number
      (L "syscall.prog"
         "48c7c00100000048c7c70100000048c7c60010000048c7c20d0000000f0548c7c03c00000048c7c7000000000f05"
         '((li r0 1) (li r6 1) (li r5 4096) (li r2 13) (sys) (li r0 60) (li r6 0) (sys))))
   _ (foldl (\ _ t (chk (at t 0) (at t 1) (at t 2))) 0 tests)

   ;; -- label addresses are exposed on the assemble result, for a loader/linker to read. --
   loopres (assemble 'x64 '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret)))
   _ (chk-eq "addr.top"  0  (label-at loopres 'top))
   _ (chk-eq "addr.done" 17 (label-at loopres 'done))

   ;; -- the encoder REFUSES a three-way alias it cannot honestly encode (d <- a OP d, d != a,
   ;; non-commutative): it raises 'alias-dst rather than emit subtly wrong bytes. we trap the scare
   ;; with a help that delegates everything else (incl the reader's own eof/more) back to welp. --
   caught (tablet 0) _ (pin caught 0 0)
   _ (: help (\ s a b (? (= a 'alias-dst) (: _ (pin caught 0 1) ()) (welp s a b))))
   _ (asm 'x64 '((sub r0 r3 r0)))
   _ (chk-eq "alias.refused" 1 (peep caught 0 0))

   ;; -- the text front-end (asm/text.l) parses to the same IR, so it assembles byte-identically. --
   _ (chk-eq "text.basic" (asm-hex 'x64 '((li r0 60) (ret)))
                          (asm-text-hex 'x64 "li r0, 60\nret"))
   _ (chk-eq "text.full"
        (asm-hex 'x64 '((add r0 r0 r1) (label loop) (dec r0) (br ne loop) (ret)))
        (asm-text-hex 'x64 "add r0, r0, r1   ; with a comment\nlabel loop\n  dec r0\n  br ne, loop\n\n  ret\n"))

   ;; -- the ELF linker (asm/elf.l) wraps assembled bytes in a well-formed static executable. --
   elfprog '((li r0 60) (li r6 0) (sys))
   elfres  (elf64 'x64 (\ a elfprog) (L 65 66 67))
   elfimg  (peep elfres 'bytes 0)
   _ (chk-eq "elf.magic"   127     (at elfimg 0))        ; \x7f E L F
   _ (chk-eq "elf.machine" 62      (at elfimg 18))       ; e_machine = x86-64
   _ (chk-eq "elf.entry"   4194424 (peep elfres 'entry 0))
   _ (chk-eq "elf.size"    (+ 120 (+ (tally (asm 'x64 elfprog)) 3)) (tally elfimg))
   _ (chk-eq "elf.arm64-machine" 183 (at (peep (elf64 'arm64 (\ a elfprog) ()) 'bytes 0) 18))

   ;; -- the aarch64 backend (asm/arm64.l): the SAME neutral IR, a second target. fixed 32-bit
   ;; little-endian words; every golden checked vs llvm-mc / llvm-objdump. --
   a64tests (L
      (L "a64.li"     "800780d2"          '((li r0 60)))
      (L "a64.movk"   "00cf8ad28046a2f2"  '((li r0 305419896)))    ; 0x12345678: movz + movk
      (L "a64.mov"    "e00301aa"          '((mov r0 r1)))
      (L "a64.add"    "2000028b"          '((add r0 r1 r2)))        ; native 3-address, no dance
      (L "a64.sub"    "200002cb"          '((sub r0 r1 r2)))
      (L "a64.and"    "2000028a"          '((and r0 r1 r2)))
      (L "a64.or"     "200002aa"          '((or  r0 r1 r2)))
      (L "a64.xor"    "200002ca"          '((xor r0 r1 r2)))        ; -> eor
      (L "a64.addi"   "20140091"          '((add r0 r1 5)))
      (L "a64.subi"   "201400d1"          '((sub r0 r1 5)))
      (L "a64.addneg" "201400d1"          '((add r0 r1 -5)))        ; negative imm flips add->sub
      (L "a64.cmp"    "1f0001eb"          '((cmp r0 r1)))
      (L "a64.cmpi"   "1f1c00f1"          '((cmp r0 7)))
      (L "a64.mul"    "207c029b"          '((imul r0 r1 r2)))
      (L "a64.neg"    "e00300cb"          '((neg r0)))
      (L "a64.not"    "e00320aa"          '((not r0)))              ; -> mvn
      (L "a64.ldr"    "200040f9"          '((ld r0 r1 0)))
      (L "a64.ldr8"   "200440f9"          '((ld r0 r1 8)))
      (L "a64.str"    "e30b00f9"          '((st sp 16 r3)))
      (L "a64.ldur"   "20805ff8"          '((ld r0 r1 -8)))         ; unaligned/neg -> LDUR
      (L "a64.push"   "e00f1ff8"          '((push r0)))             ; str x0,[sp,#-16]!
      (L "a64.pop"    "e00741f8"          '((pop r0)))              ; ldr x0,[sp],#16
      (L "a64.lea"    "ff8300d1"          '((lea sp sp -32)))
      (L "a64.ret"    "c0035fd6"          '((ret)))
      (L "a64.svc"    "010000d4"          '((sys)))
      (L "a64.nop"    "1f2003d5"          '((nop)))
      (L "a64.brk"    "000020d4"          '((trap)))
      (L "a64.loop"   "1f0001eb60000054000400d1fdffff17c0035fd6"
                      '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret))))
   _ (foldl (\ _ t (chk2 (at t 0) (at t 1) 'arm64 (at t 2))) 0 a64tests)

   ;; -- summary; nonzero exit on any miss, so `make`-style gates see the failure. --
   np (peep pass 0 0) nf (peep fail 0 0)
   _ (sayln (+ "asm/asmtest: " (+ (show np) (+ " passed, " (+ (show nf) " failed\n")))))
   _ (? (= 0 nf) 0 (nap 1)))
