; holotest -- the gate for the neutral assembler + its x86-64 backend. each golden below is the exact
; hex the assembler emits, and EVERY one was checked against the real toolchain: emit the bytes,
; `objdump -d -M intel`, confirm the mnemonic. so this file is the frozen record of that round-trip
; -- if a golden drifts, either the encoder broke or the disassembler disagrees, and either is a bug.
; run: out/host/ai -l crew/holo/holo.l -l crew/holo/x64.l -l crew/holo/arm64.l -l crew/holo/text.l -l crew/holo/elf.l crew/holo/holotest.l
; (exits nonzero on any miss). it gates both backends, the text front-end, and the ELF linker.

(: pass (tablet 0) _ (pin pass 0 0)
   fail (tablet 0) _ (pin fail 0 0)
   (bump t)  (pin t 0 (+ 1 (peep t 0 0)))
   (sayln s) (: _ (puts s) (flush out))
   (chk-eq name want got)
      (? (= want got) (bump pass)
         (: _ (bump fail)
            (sayln (+ "FAIL " (+ name (+ ": want " (+ (show want) (+ " got " (+ (show got) "\n")))))))))
   (chk2 name want target prog) (chk-eq name want (holo-hex target prog))
   (chk name want prog) (chk2 name want 'x64 prog)

   ;; -- the golden table: (name  expected-hex  IR-program). --
   tests (L
      ;; immediates
      (L "li.small"    "b83c000000"            '((li r0 60)))            ; mov eax,60 (zero-extends)
      (L "li.hireg"    "41b83c000000"          '((li r7 60)))            ; mov r8d,60 (REX.B alone)
      (L "li.u32"      "b800000090"            '((li r0 2415919104)))    ; mov eax,0x90000000 -- zero-extend, no movabs
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
      ;; the sized family (movsx/movsxd loads, truncating stores, in-register
      ;; extends, CL shifts) -- each checked vs objdump -M intel (mnemonics in
      ;; the trailing comments)
      (L "ld1.rbp"     "480fbe45f8"            '((ld1 r0 r4 -8)))     ; movsx  rax, BYTE [rbp-8]
      (L "ld2.sp"      "480fbf5c2410"          '((ld2 r3 sp 16)))     ; movsx  rbx, WORD [rsp+16]
      (L "ld4.rbp"     "4c63459c"              '((ld4 r7 r4 -100)))   ; movsxd r8, DWORD [rbp-100]
      (L "st1.rbp"     "408845f8"              '((st1 r4 -8 r0)))     ; mov BYTE [rbp-8], al
      (L "st2.sp"      "6640895c2410"          '((st2 sp 16 r3)))     ; mov WORD [rsp+16], bx
      (L "st4.rbp"     "4489459c"              '((st4 r4 -100 r7)))   ; mov DWORD [rbp-100], r8d
      (L "sx1"         "480fbec0"              '((sx1 r0)))           ; movsx rax, al
      (L "sx2.hi"      "4d0fbfc0"              '((sx2 r7)))           ; movsx r8, r8w
      (L "sx4"         "4863db"                '((sx4 r3)))           ; movsxd rbx, ebx
      (L "ldu1.rbp"    "480fb645f8"            '((ldu1 r0 r4 -8)))    ; movzx rax, BYTE [rbp-8]  (unsigned char)
      (L "ldu2.sp"     "480fb75c2410"          '((ldu2 r3 sp 16)))    ; movzx rbx, WORD [rsp+16] (unsigned short)
      (L "ldu4.rbp"    "448b459c"              '((ldu4 r7 r4 -100)))  ; mov r8d, DWORD [rbp-100] (unsigned int, zero-extends)
      (L "zx1"         "480fb6c0"              '((zx1 r0)))           ; movzx rax, al
      (L "zx2.hi"      "4d0fb7c0"              '((zx2 r7)))           ; movzx r8, r8w
      (L "zx4"         "408bdb"                '((zx4 r3)))           ; mov ebx, ebx (zero-extends)
      (L "udiv"        "52564889d831d248f734244883c4085a4889c3"      '((udiv r3 r3 r5)))   ; xor rdx + div (unsigned)
      (L "urem"        "52564889d831d248f734244889d04883c4085a4889c3" '((urem r3 r3 r5)))  ; unsigned rem (rdx)
      (L "shlv"        "48d3e0"                '((shlv r0 r1)))       ; shl rax, cl
      (L "shrv.hi"     "49d3e8"                '((shrv r7 r1)))       ; shr r8, cl
      (L "sarv"        "48d3fb"                '((sarv r3 r1)))       ; sar rbx, cl
      ;; la: rip-relative lea onto a data label laid with (label)+(raw ..)
      (L "la.data"     "488d05070000004c8d050000000041424300"
                       '((la r0 x) (la r7 x) (label x) (raw (65 66 67 0))))  ; lea rax/r8, [rip -> x]
      ;; abs64: an 8-byte ABSOLUTE address of a label baked into data (a static pointer). at org 0,
      ;; tgt sits at offset 8 (just past the fixup), so the word reads 8, then ret.
      (L "abs64.data"  "0800000000000000c3"
                       '((raw ((fix 8 abs64 tgt 0))) (label tgt) (ret)))
      (L "st.sib"      "4889442410"            '((st sp 16 r0)))    ; rsp base needs a SIB byte
      (L "st.disp32"   "48899c2400010000"      '((st sp 256 r3)))
      (L "lea.disp8"   "488d4710"              '((lea r0 r6 16)))
      (L "lea.neg"     "488d6424e0"            '((lea sp sp -32)))
      (L "lean"        "488d4710"              '((lean r0 r6 16)))       ; cc's consumed frame address: lea's bytes, off the sibcall gate's books
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
      (L "ldxb.s1.d16" "480fb6440310"          '((ldxb r0 r3 r0 1 16)))  ; movzx rax,byte [rbx+rax*1+16]  (the string-lane peep read)
      (L "stxb.s1.d16" "4088440310"            '((stxb r3 r0 1 16 r0)))  ; mov byte [rbx+rax*1+16],al     (the cask-lane pin store)
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
      ;; the P0 glaze ops -- indirect jump, flag-setting add/sub (+ the vs/vc conds), overflow-checked
      ;; multiply, condition->0/1. each objdump-verified (-M intel).
      (L "jmpr.rax"    "ffe0"                  '((jmpr r0)))              ; jmp rax  (Continue/deopt tail)
      (L "jmpr.r8"     "41ffe0"                '((jmpr r7)))              ; jmp r8
      (L "callr.rax"   "ffd0"                  '((callr r0)))            ; call rax (through a fn pointer)
      (L "callr.r8"    "41ffd0"                '((callr r7)))            ; call r8
      (L "set.eq"      "0f94c0480fb6c0"        '((set eq r0)))           ; sete al ; movzx rax,al
      (L "set.lt"      "0f9cc0480fb6c0"        '((set lt r0)))           ; setl al ; movzx rax,al
      (L "set.p"       "0f9ac0480fb6c0"        '((set p r0)))            ; setp al ; movzx rax,al (ucomisd unordered)
      (L "set.np"      "0f9bc1480fb6c9"        '((set np r1)))           ; setnp cl ; movzx rcx,cl
      (L "adds"        "4c01c0"                '((adds r0 r0 r7)))       ; add rax,r8  (sets OF -> br vs)
      (L "subs"        "4c29c0"                '((subs r0 r0 r7)))       ; sub rax,r8  (sets OF)
      (L "mulo.prog"   "490fafc00f8005000000e902000000ffe6c3"           ; imul rax,r8 ; jo ovf ; jmp done ; jmp rsi ; ret
                       '((mulo r0 r0 r7 r4 ovf) (jmp done) (label ovf) (jmpr r5) (label done) (ret)))
      (L "div"         "524150489948f73c244883c4085a"                   ; push rdx;push r8;cqo;idiv [rsp];add rsp,8;pop rdx
                       '((div r0 r0 r7)))
      (L "rem"         "524150489948f73c244889d04883c4085a"             ; ... mov rax,rdx (remainder) ...
                       '((rem r0 r0 r7 r4)))
      ;; a whole program: write(1, buf, 13); exit(0)  -- r0=rax carries the syscall number
      (L "syscall.prog"
         "b801000000bf01000000be00100000ba0d0000000f05b83c000000bf000000000f05"
         '((li r0 1) (li r6 1) (li r5 4096) (li r2 13) (sys) (li r0 60) (li r6 0) (sys)))
      ;; SSE2 / double lane (the float glaze). reg-reg binops, gp<->xmm moves, and the xmm<->[mem]
      ;; spill/box ops + ucomisd that the glaze's float-result lane uses. objdump-verified (-M intel).
      (L "addsd"       "f20f58c1"               '((addsd f0 f1)))         ; addsd xmm0,xmm1
      (L "mulsd"       "f20f59c1"               '((mulsd f0 f1)))         ; mulsd xmm0,xmm1
      (L "cvtsi2sd"    "f2480f2ac0"             '((cvtsi2sd f0 r0)))      ; cvtsi2sd xmm0,rax
      (L "cvttsd2si"   "f2480f2cc0"             '((cvttsd2si r0 f0)))     ; cvttsd2si rax,xmm0 (truncate)
      (L "movqxr"      "66480f6ec0"             '((movqxr f0 r0)))        ; movq xmm0,rax
      (L "ucomisd"     "660f2ec8"               '((ucomisd f1 f0)))       ; ucomisd xmm1,xmm0 (sets flags)
      (L "stsd.disp"   "f20f114208"             '((stsd r2 8 f0)))        ; movsd [rdx+8],xmm0   (box store)
      (L "stsd.rsp"    "f20f110424"             '((stsd sp 0 f0)))        ; movsd [rsp],xmm0     (spill)
      (L "ldsd.rsp"    "f20f100c24"             '((ldsd f1 sp 0)))        ; movsd xmm1,[rsp]     (reload)
      ;; the 4-byte single lane (the C `float` slot): widen/narrow + movss load/store
      (L "cvtss2sd"    "f30f5ac1"               '((cvtss2sd f0 f1)))      ; cvtss2sd xmm0,xmm1 (single->double)
      (L "cvtsd2ss"    "f20f5ac8"               '((cvtsd2ss f1 f0)))      ; cvtsd2ss xmm1,xmm0 (double->single)
      (L "stss"        "f30f114208"             '((stss r2 8 f0)))        ; movss [rdx+8],xmm0
      (L "ldss"        "f30f100b"               '((ldss f1 r3 0))))       ; movss xmm1,[rbx]
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
   _ (holo-bytes 'x64 '((sub r0 r3 r0)))
   _ (chk-eq "alias.refused" 1 (peep caught 0 0))

   ;; -- the text front-end (crew/holo/text.l) parses to the same IR, so it assembles byte-identically. --
   _ (chk-eq "text.basic" (holo-hex 'x64 '((li r0 60) (ret)))
                          (asm-text-hex 'x64 "li r0, 60\nret"))
   _ (chk-eq "text.full"
        (holo-hex 'x64 '((add r0 r0 r1) (label loop) (dec r0) (br ne loop) (ret)))
        (asm-text-hex 'x64 "add r0, r0, r1   ; with a comment\nlabel loop\n  dec r0\n  br ne, loop\n\n  ret\n"))

   ;; -- the ELF linker (crew/holo/elf.l) wraps assembled bytes in a well-formed static executable. --
   elfprog '((li r0 60) (li r6 0) (sys))
   elfres  (elf64 'x64 (\ a elfprog) (L 65 66 67))
   elfimg  (peep elfres 'bytes 0)
   _ (chk-eq "elf.magic"   127     (at elfimg 0))        ; \x7f E L F
   _ (chk-eq "elf.machine" 62      (at elfimg 18))       ; e_machine = x86-64
   _ (chk-eq "elf.entry"   4194424 (peep elfres 'entry 0))
   _ (chk-eq "elf.size"    (+ 120 (+ (tally (holo-bytes 'x64 elfprog)) 3)) (tally elfimg))
   _ (chk-eq "elf.arm64-machine" 183 (at (peep (elf64 'arm64 (\ a elfprog) ()) 'bytes 0) 18))

   ;; -- the aarch64 backend (crew/holo/arm64.l): the SAME neutral IR, a second target. fixed 32-bit
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
                      '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret)))
      ;; the P0 glaze ops -- each llvm-mc-verified (--triple=aarch64). adds/subs are the S-variant
      ;; (set NZCV); set is CSET; mulo is the SMULH+CMP-vs-ASR#63 overflow idiom (no flag-setting mul).
      (L "a64.jmpr"   "00001fd6"          '((jmpr r0)))                 ; br x0
      (L "a64.callr"  "00003fd6"          '((callr r0)))                ; blr x0  (through a fn pointer)
      (L "a64.abs64"  "0800000000000000c0035fd6"                        ; an 8-byte absolute label address, then ret
                      '((raw ((fix 8 abs64 tgt 0))) (label tgt) (ret)))
      (L "a64.set.eq" "e0179f9a"          '((set eq r0)))               ; cset x0, eq
      (L "a64.set.vs" "e0779f9a"          '((set vs r0)))               ; cset x0, vs  (overflow -> 0/1)
      (L "a64.adds"   "000007ab"          '((adds r0 r0 r7)))           ; adds x0,x0,x7
      (L "a64.subs"   "600007eb"          '((subs r0 r3 r7)))           ; subs x0,x3,x7
      (L "a64.mulo.prog" "047c479b007c079b9ffc80eb4100005402000014a0001fd6c0035fd6"   ; smulh x4,x0,x7; mul x0,x0,x7; cmp x4,x0,asr#63; b.ne ovf; b done; br x5; ret
                      '((mulo r0 r0 r7 r4 ovf) (jmp done) (label ovf) (jmpr r5) (label done) (ret)))
      ;; P1: shifts/test/div/rem/indexed -- the integer + map lanes on aarch64. llvm-mc-verified.
      (L "a64.sar"    "00fc4193"          '((sar r0 1)))                ; asr x0,x0,#1   (untag)
      (L "a64.shr"    "e7fc41d3"          '((shr r7 1)))                ; lsr x7,x7,#1
      (L "a64.shl"    "00f07dd3"          '((shl r0 3)))                ; lsl x0,x0,#3
      (L "a64.rol"    "0080c093"          '((rol r0 32)))               ; ror x0,x0,#32  (the hash rotate)
      (L "a64.ror"    "0020c093"          '((ror r0 8)))                ; ror x0,x0,#8
      (L "a64.test.r" "1f0007ea"          '((test r0 r7)))              ; tst x0,x7
      (L "a64.test.i" "1f0040f2"          '((test r0 1)))               ; tst x0,#1  (the gap/fixnum low-bit check)
      (L "a64.and.i"  "00084092"          '((and r0 r0 7)))             ; and x0,x0,#7  (bitmask immediate)
      (L "a64.div"    "000cc79a"          '((div r0 r0 r7)))            ; sdiv x0,x0,x7
      (L "a64.rem"    "040cc79a8080079b"  '((rem r0 r0 r7 r4)))         ; sdiv x4,x0,x7 ; msub x0,x4,x7,x0
      (L "a64.ldx"    "e00c008b000440f9"  '((ldx r0 r7 r0 8 8)))        ; add x0,x7,x0,lsl#3 ; ldr x0,[x0,#8]
      (L "a64.leax"   "2101098b21040091"  '((leax r1 r9 r9 1 1)))       ; add x1,x9,x9 ; add x1,x1,#1
      (L "a64.stx"    "f00c008b080600f9"  '((stx r7 r0 8 8 r8)))        ; add x16,x7,x0,lsl#3 ; str x8,[x16,#8]
      (L "a64.ldxb"   "6000008b00404039"  '((ldxb r0 r3 r0 1 16)))      ; add x0,x3,x0 ; ldrb w0,[x0,#16]   (string-lane peep read)
      (L "a64.stxb"   "7000008b00420039"  '((stxb r3 r0 1 16 r0)))      ; add x16,x3,x0 ; strb w0,[x16,#16] (cask-lane pin store)
      (L "a64.li.big" "a0828fd240e9aff22037cff2e0c6f3f2"               ; movz+3 movk = 0x9e3779b97f4a7c15 (bignum-safe lane via //%)
                      '((li r0 11400714819323198485)))
      ;; the link register (x30) by name -- a callee spills it across nested calls (BL clobbers it).
      (L "a64.push.lr" "fe0f1ff8"         '((push lr)))                ; str x30, [sp,#-16]!
      (L "a64.pop.lr"  "fe0741f8"         '((pop lr)))                 ; ldr x30, [sp],#16
      (L "a64.grpfn"  "fe0f1ff8040000940000038bfe0741f8c0035fd6e00303aac0035fd6"   ; the nested-call shape: save lr; bl sib; work; restore lr; ret; sib: ...
                      '((push lr) (call sib) (add r0 r0 r3) (pop lr) (ret) (label sib) (mov r0 r3) (ret)))
      ;; the OVF-anchor idiom -- mov to/from sp MUST be `lea` (add #0), not the ORR-based `mov` (which
      ;; reads/writes XZR for reg 31, never sp). set anchor = sp ; deopt abandons frames with sp = anchor.
      (L "a64.anchor"  "f7030091"          '((lea r23 sp 0)))           ; mov x23, sp
      (L "a64.abandon" "ff020091"          '((lea sp r23 0)))           ; mov sp, x23
      ;; a WHOLE glaze leaf for (\ x (+ x 1)) -- the integer leaf ABI end to end: g/Ip/Hp/Sp kept in
      ;; x0..x3, acc=x4, temp=x5. fetch+fixnum-guard Sp[0]; untag; +1 with overflow->deopt; putfix;
      ;; store Sp[0]; Continue (Ip+=16; br [Ip]); deopt tail-applies interp (value[1] at [Ip+8]).
      (L "a64.glaze.leaf"
         "640040f99f0040f26001005484fc4193840400b106010054840004abc6000054840040b2640000f921400091250040f9a0001fd6250440f9e10305aa250040f9a0001fd6"
         '((ld r4 r3 0) (test r4 1) (br eq deopt) (sar r4 1) (adds r4 r4 1) (br vs deopt)
           (adds r4 r4 r4) (br vs deopt) (or r4 r4 1) (st r3 0 r4) (add r1 r1 16) (ld r5 r1 0) (jmpr r5)
           (label deopt) (ld r5 r1 8) (mov r1 r5) (ld r5 r1 0) (jmpr r5)))
      ;; scalar-double FP (the float glaze lane): f0..f15 -> d0..d15. SSE-named IR, two-address, mapped to
      ;; the arm64 scalar-double form. each golden checked vs llvm-objdump (mnemonics in the trailing comment).
      (L "a64.cvttsd2si" "0400789e"        '((cvttsd2si r4 f0)))          ; fcvtzs x4, d0 (toward zero)
      (L "a64.cvtsi2sd" "8000629e"          '((cvtsi2sd f0 r4)))          ; scvtf d0, x4
      (L "a64.movqxr"   "8100679e"          '((movqxr f1 r4)))            ; fmov  d1, x4  (gpr bits -> fpr)
      (L "a64.movqrx"   "0400669e"          '((movqrx r4 f0)))            ; fmov  x4, d0  (fpr -> gpr bits)
      (L "a64.movsd"    "2040601e"          '((movsd f0 f1)))             ; fmov  d0, d1
      (L "a64.addsd"    "0028611e"          '((addsd f0 f1)))             ; fadd  d0, d0, d1
      (L "a64.subsd"    "2138601e"          '((subsd f1 f0)))             ; fsub  d1, d1, d0
      (L "a64.mulsd"    "0008611e"          '((mulsd f0 f1)))             ; fmul  d0, d0, d1
      (L "a64.divsd"    "2118601e"          '((divsd f1 f0)))             ; fdiv  d1, d1, d0
      (L "a64.ucomisd"  "0020611e"          '((ucomisd f0 f1)))           ; fcmp  d0, d1
      (L "a64.stsd"     "400400fd"          '((stsd r2 8 f0)))            ; str   d0, [x2, #8]
      (L "a64.ldsd"     "610040fd"          '((ldsd f1 r3 0)))            ; ldr   d1, [x3]
      (L "a64.cvtss2sd" "20c0221e"          '((cvtss2sd f0 f1)))          ; fcvt  d0, s1  (single -> double)
      (L "a64.cvtsd2ss" "0140621e"          '((cvtsd2ss f1 f0)))          ; fcvt  s1, d0  (double -> single)
      (L "a64.stss"     "400800bd"          '((stss r2 8 f0)))            ; str   s0, [x2, #8]
      (L "a64.ldss"     "610040bd"          '((ldss f1 r3 0)))            ; ldr   s1, [x3]
      (L "a64.xorpd"    "841c242e"          '((xorpd f4 f4)))             ; eor   v4.8b, v4.8b, v4.8b  (zero a double)
      ;; the sized family, checked vs llvm-objdump
      (L "a64.ld1"      "80809f38"          '((ld1 r0 r4 -8)))            ; ldursb x0, [x4, #-8]
      (L "a64.ld2"      "e3238079"          '((ld2 r3 sp 16)))            ; ldrsh  x3, [sp, #16]
      (L "a64.ld4"      "87c099b8"          '((ld4 r7 r4 -100)))          ; ldursw x7, [x4, #-100]
      (L "a64.st1"      "80801f38"          '((st1 r4 -8 r0)))            ; sturb  w0, [x4, #-8]
      (L "a64.st2"      "e3230079"          '((st2 sp 16 r3)))            ; strh   w3, [sp, #16]
      (L "a64.st4"      "87c019b8"          '((st4 r4 -100 r7)))          ; stur   w7, [x4, #-100]
      (L "a64.sx1"      "001c4093"          '((sx1 r0)))                  ; sxtb x0, w0
      (L "a64.sx2"      "e73c4093"          '((sx2 r7)))                  ; sxth x7, w7
      (L "a64.sx4"      "637c4093"          '((sx4 r3)))                  ; sxtw x3, w3
      (L "a64.ldu1"     "80204039"          '((ldu1 r0 r4 8)))            ; ldrb w0, [x4, #8] (zero-extends)
      (L "a64.ldu2"     "83204079"          '((ldu2 r3 r4 16)))           ; ldrh w3, [x4, #16]
      (L "a64.ldu4"     "870840b9"          '((ldu4 r7 r4 8)))            ; ldr w7, [x4, #8] (zero-extends to x7)
      (L "a64.zx1"      "001c40d3"          '((zx1 r0)))                  ; ubfx x0, x0, #0, #8  (uxtb)
      (L "a64.zx2"      "633c40d3"          '((zx2 r3)))                  ; ubfx x3, x3, #0, #16 (uxth)
      (L "a64.zx4"      "e77c40d3"          '((zx4 r7)))                  ; ubfx x7, x7, #0, #32 (uxtw)
      (L "a64.udiv"     "6308c59a"          '((udiv r3 r3 r5)))           ; udiv x3, x3, x5
      (L "a64.urem"     "6208c59a438c059b"  '((urem r3 r3 r5 r2)))        ; udiv x2,x3,x5 ; msub x3,x2,x5,x3
      (L "a64.shlv"     "0020c19a"          '((shlv r0 r1)))              ; lsl x0, x0, x1
      (L "a64.shrv"     "e724c19a"          '((shrv r7 r1)))              ; lsr x7, x7, x1
      (L "a64.sarv"     "6328c19a"          '((sarv r3 r1)))              ; asr x3, x3, x1
      ;; the cc-rung lanes (aicc -t arm64): lean; the 24-bit add/sub split; the FAR memory
      ;; lane (movz x16 + add/sub off the base); fp LDUR/STUR + far (frame slots run negative);
      ;; f16+ registers; cmp's cmn flip; p/np as vs/vc (FCMP parks unordered in V). llvm-mc-verified.
      (L "a64.lean"     "808000d1"          '((lean r0 r4 -32)))          ; sub x0, x4, #32 (lea's alias)
      (L "a64.addi.24"  "2040409100100091"  '((add r0 r1 65540)))         ; add x0,x1,#16,lsl#12 ; add x0,x0,#4
      (L "a64.far.ld"   "902580d2300010cb000240f9" '((ld r0 r1 -300)))    ; movz x16,#300 ; sub x16,x1,x16 ; ldr x0,[x16]
      (L "a64.stur.d"   "40801ffc"          '((stsd r2 -8 f0)))           ; stur d0, [x2, #-8]
      (L "a64.ldur.d"   "83005ffc"          '((ldsd f3 r4 -16)))          ; ldur d3, [x4, #-16]
      (L "a64.far.fld"  "902580d2300010cb000240fd" '((ldsd f0 r1 -300)))  ; movz x16,#300 ; sub x16,x1,x16 ; ldr d0,[x16]
      (L "a64.freg.hi"  "500400fd"          '((stsd r2 8 f16)))           ; str d16, [x2, #8] (the narrow scratch)
      (L "a64.cmn"      "1f1c00b1"          '((cmp r0 -7)))               ; cmn x0, #7 (negative imm flips)
      (L "a64.set.np"   "e0679f9a"          '((set np r0)))               ; cset x0, vc (np aliases vc)
      (L "a64.la"       "400000102700001041424300"
                        '((la r0 x) (la r7 x) (label x) (raw (65 66 67 0)))))  ; adr x0/x7, x
   _ (foldl (\ _ t (chk2 (at t 0) (at t 1) 'arm64 (at t 2))) 0 a64tests)

   ;; -- summary; nonzero exit on any miss, so `make`-style gates see the failure. --
   np (peep pass 0 0) nf (peep fail 0 0)
   _ (sayln (+ "crew/holo/holotest: " (+ (show np) (+ " passed, " (+ (show nf) " failed\n")))))
   _ (? (= 0 nf) 0 (quit 1)))
