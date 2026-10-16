; the neutral assembler, every backend, the text and gas fronts and the elf linker. each golden is
; the exact hex, checked against objdump or llvm-mc (the mnemonic trails the row). the sources are
; cat in, not borrowed: the host bakes its native backend only.

(borrow 'holo) ; the cat's wrapped sources just registered the module

(: pass {0 0} fail {0 0}
   (bump t)  (pin t 0 $ 1 + peep t 0 0)
   (sayln s) (puts s, flush out)
   (chk-eq name want got)
      (want = got ? (bump pass)
       (bump fail,
        sayln $ "FAIL " + name + ": want " + show want + " got " + show got + "\n"))
   (chk2 name want target prog) (chk-eq name want (holo-hex target prog))
   (chk name want prog) (chk2 name want 'x64 prog)

   ;; -- the golden table: (name  expected-hex  IR-program). --
   tests '(
      ;; immediates
      ("li.small"    "b83c000000"            ((li r0 60)))             ; mov eax,60 (zero-extends)
      ("li.hireg"    "41b83c000000"          ((li r7 60)))             ; mov r8d,60 (REX.B alone)
      ("li.u32"      "b800000090"            ((li r0 2415919104)))     ; mov eax,0x90000000 -- zero-extend, no movabs
      ("li.neg1"     "48c7c0ffffffff"        ((li r0 -1)))
      ("li.movabs"   "48b84c9c8cdac1fc0300"  ((li r0 1122334455667788)))
      ;; register moves (low + REX-extended)
      ("mov.rr"      "4889d8"                ((mov r0 r3)))
      ("mov.ext"     "4d89f8"                ((mov r7 r14)))
      ;; ALU, register source
      ("add.rr"      "4801d8"                ((add r0 r0 r3)))
      ("sub.rr"      "4829c8"                ((sub r0 r0 r1)))
      ("xor.zero"    "31c0"                ((xor r0 r0 r0)))
      ("or.rr"       "4809c8"                ((or  r0 r0 r1)))
      ("and.rr"      "4821c8"                ((and r0 r0 r1)))
      ;; ALU, immediate source (0x81 group)
      ("add.imm"     "4883c005"              ((add r0 r0 5)))      ; 0x83 ib: the byte-immediate short form
      ("cmp.imm"     "4883f807"              ((cmp r0 7)))
      ("cmp.rr"      "4839d8"                ((cmp r0 r3)))
      ;; three-address -> two-address lowering
      ("alu.movop"   "4889c24829da"          ((sub r2 r0 r3)))    ; mov rdx,rax ; sub rdx,rbx
      ("alu.swap"    "4801d8"                ((add r0 r3 r0)))    ; commutes -> add rax,rbx, no mov
      ("add.movop"   "488d1418"              ((add r2 r0 r3)))    ; a fresh dest is one lea rdx,[rax+rbx] (the emit-alu note)
      ("add.movop.i" "488d4805"              ((add r1 r0 5)))     ; lea rcx,[rax+5]
      ;; ('align n) pads to the boundary with the backend's nop unit (lay-level, no lowering)
      ("align.pad"   "c3909090c3"            ((ret) (align 4) (label x) (ret)))
      ("align.zero"  "c3"                    ((align 16) (ret)))   ; already on the boundary: no pad
      ;; imul (true 3-operand imm form; rr folds two-address)
      ("imul.rr"     "480fafc3"              ((imul r0 r0 r3)))
      ("imul.imm"    "4869d007000000"        ((imul r2 r0 7)))
      ;; memory: the rsp(SIB) and rbp(forced-disp) base quirks, disp8 + disp32
      ("ld.base"     "488b07"                ((ld r0 r6 0)))
      ("ld.disp8"    "488b4708"              ((ld r0 r6 8)))
      ("ld.rbp0"     "488b4500"              ((ld r0 r4 0)))      ; rbp base forces a 0 disp byte
      ("ld.rbp.d8"   "488b4564"              ((ld r0 r4 100)))
      ;; the sized family: movsx/movsxd loads, truncating stores, in-register extends, cl shifts
      ("ld1.rbp"     "480fbe45f8"            ((ld1 r0 r4 -8)))      ; movsx  rax, byte [rbp-8]
      ("ld2.sp"      "480fbf5c2410"          ((ld2 r3 sp 16)))      ; movsx  rbx, word [rsp+16]
      ("ld4.rbp"     "4c63459c"              ((ld4 r7 r4 -100)))    ; movsxd r8, DWORD [rbp-100]
      ("st1.rbp"     "8845f8"              ((st1 r4 -8 r0)))      ; mov byte [rbp-8], al
      ("st2.sp"      "66895c2410"          ((st2 sp 16 r3)))      ; mov word [rsp+16], bx
      ("st4.rbp"     "4489459c"              ((st4 r4 -100 r7)))    ; mov DWORD [rbp-100], r8d
      ("sx1"         "480fbec0"              ((sx1 r0)))            ; movsx rax, al
      ("sx2.hi"      "4d0fbfc0"              ((sx2 r7)))            ; movsx r8, r8w
      ("sx4"         "4863db"                ((sx4 r3)))            ; movsxd rbx, ebx
      ("ldu1.rbp"    "480fb645f8"            ((ldu1 r0 r4 -8)))     ; movzx rax, byte [rbp-8]  (unsigned char)
      ("ldu2.sp"     "480fb75c2410"          ((ldu2 r3 sp 16)))     ; movzx rbx, word [rsp+16] (unsigned short)
      ("ldu4.rbp"    "448b459c"              ((ldu4 r7 r4 -100)))   ; mov r8d, DWORD [rbp-100] (unsigned int, zero-extends)
      ("zx1"         "480fb6c0"              ((zx1 r0)))            ; movzx rax, al
      ("zx2.hi"      "4d0fb7c0"              ((zx2 r7)))            ; movzx r8, r8w
      ("zx4"         "8bdb"                ((zx4 r3)))            ; mov ebx, ebx (zero-extends)
      ;; port i/o: the dx-port forms, and the rep-prefixed string walks
      ("io.in"       "ec66eded"              ((inb) (inw) (inl)))
      ("io.out"      "ee66efef"              ((outb) (outw) (outl)))
      ("io.str"      "fcf36cf3666d6d"        ((cld) (rep) (str ins 1) (rep) (str ins 2) (str ins 4)))
      ("io.strout"   "6e666ff26f"            ((str outs 1) (str outs 2) (repne) (str outs 4)))
      ("str.movs"    "a466a5a548a5"          ((str movs 1) (str movs 2) (str movs 4) (str movs 8)))
      ("str.rest"    "a6ab48adae"            ((str cmps 1) (str stos 4) (str lods 8) (str scas 1)))
      ;; the system lane: flag/halt nullaries, the msr pair, the interrupt return, int n (int3 is `trap`)
      ("sys.flags"   "fafbf4"                ((cli) (sti) (hlt)))
      ("sys.smap"    "0f01cb0f01ca"          ((stac) (clac)))
      ("sys.pkru"    "0f01ee0f01ef"          ((rdpkru) (wrpkru)))
      ("sys.xcr"     "0f01d00f01d1"          ((xgetbv) (xsetbv)))
      ("sys.cache"   "0f090f08"              ((wbinvd) (invd)))
      ("sys.mwait"   "0f01c80f01c9"          ((monitor) (mwait)))
      ("sys.mwaitx"  "0f01f90f01fa0f01fb"    ((rdtscp) (monitorx) (mwaitx)))
      ("sys.rdrand"  "480fc7f00fc7f8"        ((rdig () (15 199) 6 8 r0) (rdig () (15 199) 7 4 r0)))   ; rdrand rax ; rdseed eax
      ("sys.alurm"   "480306481346081b0b4c3b4010"
                     ((alurm add 8 r0 r5 0) (alurm adc 8 r0 r5 8) (alurm sbb 4 r1 r3 0) (alurm cmp 8 r7 r0 16)))   ; add (%rsi),%rax ; adc 8(%rsi),%rax ; sbb (%rbx),%ecx ; cmp 16(%rax),%r8
      ("sys.rrop"    "0f02c1440f03c0"        ((rrop (15 2) 4 r0 r1) (rrop (15 3) 4 r7 r0)))   ; lar %ecx,%eax ; lsl %eax,%r8d
      ("sys.prefetch" "0f0d080f184b08"       ((mdig (15 13) 1 4 r0 0) (mdig (15 24) 1 4 r3 8)))   ; prefetchw (%rax) ; prefetcht0 8(%rbx)
      ("sys.cx16"    "480fc70f0fc74b08"      ((mdig (15 199) 1 8 r6 0) (mdig (15 199) 1 4 r3 8)))   ; cmpxchg16b (%rdi) ; cmpxchg8b 8(%rbx)
      ("sys.rdig"    "0f00c8660f00c8f3480faed00f00d1"  ((rdig () (15 0) 1 4 r0) (rdig () (15 0) 1 2 r0) (rdig (243) (15 174) 2 8 r0) (rdig () (15 0) 2 4 r1)))   ; str eax ; str ax ; wrfsbase rax ; lldt cx
      ("mem.ind"     "ff10ff6308"            ((mdig (255) 2 4 r0 0) (mdig (255) 4 4 r3 8)))   ; call [rax] ; jmp [rbx+8]
      ("mem.pushpop" "ff30ff73088f00"        ((mdig (255) 6 4 r0 0) (mdig (255) 6 4 r3 8) (mdig (143) 0 4 r0 0)))   ; push [rax] ; push [rbx+8] ; pop [rax]
      ("movnti"      "480fc3030f33"          ((movntim 8 r3 0 r0) (rdpmc)))
      ("fpu.nil"     "dbe3dbe29b0f77"        ((fninit) (fnclex) (fwait) (emms)))
      ("fpu.mdig"    "dd30480fae4308"        ((mdig (221) 6 4 r0 0) (mdig (15 174) 0 8 r3 8)))   ; fnsave [rax] ; fxsave64 [rbx+8]
      ("fpu.flush"   "0fae38660fae38660fae30" ((mdig (15 174) 7 4 r0 0) (mdig (15 174) 7 2 r0 0) (mdig (15 174) 6 2 r0 0)))   ; clflush clflushopt clwb [rax]
      ("sys.verw"    "0f00280f0020"          ((mdig (15 0) 5 4 r0 0) (mdig (15 0) 4 4 r0 0)))   ; verw verr [rax]
      ("sys.pushf"   "9c9d"                  ((pushf) (popf)))
      ("sys.seg"     "65488b0064488b00"      ((seg gs) (ld r0 r0 0) (seg fs) (ld r0 r0 0)))
      ("sys.segnull" "3e262e36"              ((seg ds) (seg es) (seg cs) (seg ss)))
      ("sys.rmw"     "0fc102480fb14f088606ff0048830001660908480fba2803fe4b04"
                     ((xaddm 4 r2 0 r0) (cmpxchgm 8 r6 8 r1) (xchgm 1 r5 0 r0) (unm inc 4 r0 0)
                      (alum add 8 r0 0 1) (alum or 2 r0 0 r1) (btm bts 8 r0 0 3) (unm dec 1 r3 4)))
      ("sys.testm"   "f60020854b08"          ((testm 1 r0 0 32) (testm 4 r3 8 r1)))
      ("sys.bscan"   "480fbdc10fbcc1f3480fbdc1f30fbcc1f3490fb8c0f3900faef00faee80faef8"
                     ((bscan bsr 8 r0 r1) (bscan bsf 4 r0 r1) (bscan lzcnt 8 r0 r1) (bscan tzcnt 4 r0 r1)
                      (bscan popcnt 8 r0 r7) (pause) (mfence) (lfence) (sfencex)))
      ("sys.ud2"     "0f0b"                  ((ud2)))
      ("sys.iretq"   "48cf"                  ((iretq)))
      ("sys.swapgs"  "0f01f8"                ((swapgs)))
      ("sys.msr"     "0f320f30"              ((rdmsr) (wrmsr)))
      ("sys.cpuid"   "0fa20f31"              ((cpuid) (rdtsc)))
      ("sys.svm"     "0f01d80f01da0f01db0f01dc0f01dd"
                                             ((vmrun) (vmload) (vmsave) (stgi) (clgi)))
      ;; VMX: the two bare ops, the three prefixed pointer ops over [rax], the field pair
      ;; (ModRM.reg is the FIELD both ways, so both read cb), and sgdt/sidt over [rax].
      ("sys.vmx"     "0f01c20f01c4f30fc730660fc7300fc7300f78cb0f79cb0f01000f0108"
                                             ((vmlaunch) (vmxoff)
                                              (vmxon r0 0) (vmclear r0 0) (vmptrld r0 0)
                                              (vmread r3 r1) (vmwrite r1 r3)
                                              (sgdt r0 0) (sidt r0 0)))
      ("sys.int"     "cd00cd20"              ((int 0) (int 32)))
      ;; the control registers: the cr number rides Modrm.reg, so REX.R reaches cr8 and REX.B
      ;; reaches r8 -- and neither carries REX.W, a cr move being 64-bit already
      ("sys.ldcr"    "0f20c00f20e3"          ((ldcr r0 0) (ldcr r3 4)))      ; mov rax,cr0 ; mov rbx,cr4
      ("sys.ldcr.hi" "410f20d8440f20c0"      ((ldcr r7 3) (ldcr r0 8)))      ; mov r8,cr3 ; mov rax,cr8
      ("sys.stcr"    "0f22c00f22db"          ((stcr 0 r0) (stcr 3 r3)))      ; mov cr0,rax ; mov cr3,rbx
      ("sys.stcr.hi" "410f22e0440f22c0"      ((stcr 4 r7) (stcr 8 r0)))      ; mov cr4,r8 ; mov cr8,rax
      ("sys.dr"      "0f21f80f23f3410f21c0"  ((lddr r0 7) (stdr 6 r3) (lddr r7 0)))   ; mov rax,dr7 ; mov dr6,rbx ; mov r8,dr0
      ("invpcid"     "660f388208660f38820b"  ((invpcid r1 r0 0) (invpcid r1 r3 0)))   ; invpcid rcx,[rax] ; invpcid rcx,[rbx]
      ;; the descriptor tables and invlpg: one opcode, 0F 01, told apart by the Modrm digit.
      ("sys.lgdt"    "0f01170f015710"        ((lgdt r6 0) (lgdt r6 16)))     ; lgdt [rdi] ; lgdt [rdi+16]
      ("sys.lidt"    "0f015e08"              ((lidt r5 8)))                  ; lidt [rsi+8]
      ("sys.invlpg"  "0f013f410f017808"      ((invlpg r6 0) (invlpg r7 8)))  ; invlpg [rdi] ; invlpg [r8+8]
      ("sys.ltr"     "0f00d8410f00d8"        ((ltr r0) (ltr r7)))            ; ltr ax ; ltr r8w
      ;; the segment registers, ldcr's twin: 8C /r with the sreg number in Modrm.reg.
      ;; REX.W widens the destination to the whole register, zero-extended -- no movzx.
      ("sys.ldseg"   "488cc8498cc9"          ((ldseg r0 1) (ldseg r8 1)))    ; mov rax,cs ; mov r9,cs
      ;; push imm: 6A ib / 68 id, sign-extended into the 64-bit slot
      ("push.imm"    "6a006a1f682c010000"    ((push 0) (push 31) (push 300)))
      ("push.reg"    "504150"                ((push r0) (push r7)))
      ;; lia: the label's linked address, movabs b8+rd io, the eight zeros an abs64 placeholder.
      ;; `la` answers where it runs; the two differ where code is linked high and runs low.
      ("lia"         "48b8000000000000000049b90000000000000000"
                                             ((label k) (lia r0 k) (lia r8 k)))
      ;; tp: the thread pointer -- mov d, fs:[0]
      ("tp"          "64488b042500000000"    ((tp r0)))             ; mov rax, fs:[0]
      ("tp.hi"       "644c8b142500000000"    ((tp r9)))             ; mov r10, fs:[0]
      ;; cas: lock cmpxchg, the accumulator operand wired to r0 (rax)
      ("cas.rsi"     "f0480fb10e"            ((cas r0 r1 r5)))      ; lock cmpxchg [rsi], rcx
      ("cas.hi"      "f04d0fb111"            ((cas r0 r9 r8)))      ; lock cmpxchg [r9], r10
      ("cas4.rdi"    "f00fb10f"            ((cas4 r0 r1 r6)))     ; lock cmpxchg DWORD [rdi], ecx
      ("cas4.rbp"    "f0440fb15500"          ((cas4 r0 r9 r4)))     ; lock cmpxchg DWORD [rbp], r10d (forced 0 disp)
      ("udiv"        "524889d831d248f7f65a4889c3"              ((udiv r3 r3 r5)))    ; xor rdx + div (unsigned)
      ("urem"        "524889d831d248f7f64889d05a4889c3"        ((urem r3 r3 r5 r2)))   ; unsigned rem (rdx; the scratch t is rdx's job here, ignored)
      ;; the divisor's homes that cannot be a div operand (rax the dividend, rdx the high half)
      ;; divide from a stack cell: rax pushes one, rdx already has one
      ("udiv.rax"    "52504889d831d248f734244883c4085a4889c3"  ((udiv r3 r3 r0)))    ; push rax ; div [rsp] ; add rsp,8
      ("udiv.rdx"    "524889d831d248f734245a4889c3"            ((udiv r3 r3 r2)))    ; the saved rdx IS the cell; pop balances
      ("shlv"        "48d3e0"                ((shlv r0 r1)))        ; shl rax, cl
      ("shrv.hi"     "49d3e8"                ((shrv r7 r1)))        ; shr r8, cl
      ("sarv"        "48d3fb"                ((sarv r3 r1)))        ; sar rbx, cl
      ;; la: rip-relative lea onto a data label laid with (label)+(raw ..)
      ("la.data"     "488d05070000004c8d050000000041424300"
                      ((la r0 x) (la r7 x) (label x) (raw (65 66 67 0))))   ; lea rax/r8, [rip -> x]
      ;; abs64: a label's 8-byte address baked into data; at org 0 tgt sits at 8, so the word reads 8
      ("abs64.data"  "0800000000000000c3"
                      ((raw ((fix 8 abs64 tgt 0))) (label tgt) (ret)))
      ("st.sib"      "4889442410"            ((st sp 16 r0)))     ; rsp base needs a SIB byte
      ("st.disp32"   "48899c2400010000"      ((st sp 256 r3)))
      ("lea.disp8"   "488d4710"              ((lea r0 r6 16)))
      ("lea.neg"     "488d6424e0"            ((lea sp sp -32)))
      ("lean"        "488d4710"              ((lean r0 r6 16)))        ; cc's consumed frame address: lea's bytes, off the sibcall gate's books
      ;; stack
      ("push.pop"    "5059"                  ((push r0) (pop r1)))
      ("push.ext"    "41504158"              ((push r7) (pop r7)))
      ;; shifts & rotates: d1 /ext for a count of 1, c1 /ext ib otherwise
      ("sar.1"       "48d1f8"                ((sar r0 1)))       ; the fixnum untag (rax)
      ("shr.1.ext"   "49d1e9"                ((shr r8 1)))       ; r8 -> x86 r9 (REX.B): shr r9,1
      ("shl.imm"     "48c1e004"              ((shl r0 4)))
      ("rol.32"      "48c1c020"              ((rol r0 32)))      ; the hash rotate (rol rax,32)
      ("sar.imm.ext" "49c1fd05"              ((sar r12 5)))      ; r12 -> x86 r13: sar r13,5
      ;; test: 0x85 /r reg,reg ; 0xf7 /0 id reg,imm32
      ("test.rr"     "4885c0"                ((test r0 r0)))     ; test rax,rax (divide-by-zero check)
      ("test.imm"    "48f7c001000000"        ((test r0 1)))      ; test rax,1   (the fixnum low-bit guard)
      ;; SIB memory: [base + index*scale + disp]. r7->x86 r8, r10->x86 r11 (the map-probe's slot regs)
      ("leax.1.1"    "488d4c0001"            ((leax r1 r0 r0 1 1)))    ; lea rcx,[rax+rax*1+1]
      ("leax.dbl"    "4c8d1c12"              ((leax r10 r2 r2 1 0)))   ; lea r11,[rdx+rdx*1]
      ("ldx.scale8"  "4b8b04d8"              ((ldx r0 r7 r10 8 0)))    ; mov rax,[r8+r11*8]
      ("ldx.s8.d8"   "4b8b44d808"            ((ldx r0 r7 r10 8 8)))    ; mov rax,[r8+r11*8+8]
      ("stx.scale4"  "48890c98"              ((stx r0 r3 4 0 r1)))     ; mov [rax+rbx*4],rcx
      ("ldxb.s1.d16" "480fb6440310"          ((ldxb r0 r3 r0 1 16)))   ; movzx rax,byte [rbx+rax*1+16]  (the string-lane peep read)
      ("stxb.s1.d16" "88440310"            ((stxb r3 r0 1 16 r0)))   ; mov byte [rbx+rax*1+16],al     (the cask-lane pin store)
      ;; unary in-place
      ("neg"         "48f7d8"                ((neg r0)))
      ("not"         "48f7d3"                ((not r3)))
      ("inc"         "48ffc0"                ((inc r0)))
      ("dec"         "48ffcf"                ((dec r6)))
      ;; zero-operand
      ("ret"         "c3"                    ((ret)))
      ("sys"         "0f05"                  ((sys)))
      ("nop"         "90"                    ((nop)))
      ("trap"        "cc"                    ((trap)))
      ;; control flow with label fixups (rel32, measured from end of field). plain assemble
      ;; lays every branch long-form; the relaxing layout is its own entry (laylax, below).
      ("call.fwd"    "e800000000c3"          ((call foo) (label foo) (ret)))
      ("loop"        "4839c80f840800000048ffc8e9efffffffc3"
                      ((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret)))
      ("jcc.all"
        "0f8c240000000f851e0000000f8f180000000f8d120000000f8e0c0000000f87060000000f8200000000c3"
        ((br lt a) (br ne a) (br gt a) (br ge a) (br le a) (br above a) (br below a) (label a) (ret)))
      ;; indirect jump, flag-setting add/sub (+ vs/vc), overflow-checked multiply, condition -> 0/1
      ("jmpr.rax"    "ffe0"                  ((jmpr r0)))               ; jmp rax  (Continue/deopt tail)
      ("jmpr.r8"     "41ffe0"                ((jmpr r7)))               ; jmp r8
      ("callr.rax"   "ffd0"                  ((callr r0)))             ; call rax (through a fn pointer)
      ("callr.r8"    "41ffd0"                ((callr r7)))             ; call r8
      ("set.eq"      "0f94c0480fb6c0"        ((set eq r0)))            ; sete al ; movzx rax,al
      ("set.lt"      "0f9cc0480fb6c0"        ((set lt r0)))            ; setl al ; movzx rax,al
      ("set.p"       "0f9ac0480fb6c0"        ((set p r0)))             ; setp al ; movzx rax,al (ucomisd unordered)
      ("set.np"      "0f9bc1480fb6c9"        ((set np r1)))            ; setnp cl ; movzx rcx,cl
      ("adds"        "4c01c0"                ((adds r0 r0 r7)))        ; add rax,r8  (sets OF -> br vs)
      ("subs"        "4c29c0"                ((subs r0 r0 r7)))        ; sub rax,r8  (sets OF)
      ("mulo.prog"   "490fafc00f8005000000e902000000ffe6c3"           ; imul rax,r8 ; jo ovf ; jmp done ; jmp rsi ; ret
                       ((mulo r0 r0 r7 r4 ovf) (jmp done) (label ovf) (jmpr r5) (label done) (ret)))
      ("mulh.reg"    "524c89c049f7eb4889d05a"  ((mulh r0 r7 r10)))   ; push rdx ; mov rax,r8 ; imul r11 ; mov rax,rdx ; pop rdx
      ("mulh.mem"    "52524c89c048f72c244889d04883c4085a" ((mulh r0 r7 r2)))   ; b on the fixed pair: push rdx ; push rdx ; mov rax,r8 ; imul [rsp] ; mov rax,rdx ; add rsp,8 ; pop rdx
      ("div"         "52489949f7f85a"          ((div r0 r0 r7)))            ; push rdx;cqo;idiv r8;pop rdx
      ("rem"         "52489949f7f84889d05a"    ((rem r0 r0 r7 r4)))         ; ... mov rax,rdx (remainder) ...
      ("divq"        "48f7f6"                 ((divq r5)))           ; div rsi (rn r5 = rsi): f7 /6
      ("divl"        "f7f1"                   ((divl r1)))           ; div ecx: the 32-bit twin, no REX.W
      ("dv128"       "4889c1488b0424488b54240848890c244889c14889d031d248f73424489148f734244889ca" ((dv128 sp)))
      ("rm128"       "4889c1488b0424488b54240848890c244889c14889d031d248f73424489148f734244889d031d2" ((rm128 sp)))
      ;; the 128-bit pair kit (hi rdx : lo rax, left operand at [rsp] lo / [rsp+8] hi)
      ("a128"        "480304244813542408"     ((a128 sp)))            ; add rax,[rsp]; adc rdx,[rsp+8]
      ("s128"        "482904244819542408488b0424488b542408" ((s128 sp)))   ; sub/sbb into the cell, reload
      ("mw128"       "48f72424"               ((mw128 sp)))           ; mul QWORD [rsp]
      ("m128"        "480faf1424488b4c2408480fafc84801d148f724244801ca" ((m128 sp)))
      ;; the register twins: left rides two registers (lo hi), right keeps rdx:rax
      ("a128r"       "4c01c04c11ca"           ((a128r r7 r8)))         ; add rax,r8; adc rdx,r9
      ("s128r"       "4929c04919d14c89c04c89ca" ((s128r r7 r8)))       ; sub r8,rax; sbb r9,rdx; pair back
      ("mw128r"      "49f7e0"                 ((mw128r r7)))           ; mul r8
      ("m128r"       "490fafd04c89c9480fafc84801d149f7e04801ca" ((m128r r7 r8)))
      ("c128r.eq"    "4c31c04c31ca4809d00f94c0480fb6c0" ((c128r eq r7 r8)))
      ("c128r.lt"    "4c89c14829c14c89c94819d10f9cc0480fb6c0" ((c128r lt r7 r8)))
      ("c128r.gt"    "4c29c04c19ca0f9cc0480fb6c0" ((c128r gt r7 r8)))
      ("sx128"       "4899"                   ((sx128)))              ; cqo
      ("n128"        "48f7d248f7d84883daff"   ((n128)))               ; not;neg;sbb -1
      ("shl128.5"    "480fa4c20548c1e005"     ((shl128 5)))           ; shld 5; shl 5
      ("shl128.64"   "4889c231c0"             ((shl128 64)))          ; mov rdx,rax; xor eax
      ("shl128.100"  "4889c248c1e22431c0"     ((shl128 100)))
      ("shr128.5"    "480facd00548c1ea05"     ((shr128 5)))           ; shrd 5; shr 5
      ("shr128.64"   "4889d031d2"             ((shr128 64)))
      ("sar128.100"  "4889d048c1f82448c1fa3f" ((sar128 100)))         ; lo=hi>>36; hi floods
      ("shl128v"     "80f940720a4889c248d3e231c0eb07480fa5c248d3e0" ((shl128v)))
      ("shr128v"     "80f940720a4889d048d3e831d2eb07480fadd048d3ea" ((shr128v)))
      ("sar128v"     "80f940720c4889d048d3f848c1fa3feb07480fadd048d3fa" ((sar128v)))
      ("c128.eq"     "4833042448335424084809d00f94c0480fb6c0" ((c128 eq sp)))
      ("c128.below"  "488b0c244829c1488b4c24084819d10f92c0480fb6c0" ((c128 below sp)))
      ("c128.gt"     "482b0424481b5424080f9cc0480fb6c0" ((c128 gt sp)))
      ;; a whole program: write(1, buf, 13); exit(0)  -- r0=rax carries the syscall number
      ("syscall.prog"
        "b801000000bf01000000be00100000ba0d0000000f05b83c00000031ff0f05"
        ((li r0 1) (li r6 1) (li r5 4096) (li r2 13) (sys) (li r0 60) (li r6 0) (sys)))
      ;; sse2 / double lane (the float glaze). reg-reg binops, gp<->xmm moves, and the xmm<->[mem]
      ;; spill/box ops + ucomisd that the glaze's float-result lane uses. objdump-verified (-M intel).
      ("addsd"       "f20f58c1"               ((addsd f0 f1)))          ; addsd xmm0,xmm1
      ("mulsd"       "f20f59c1"               ((mulsd f0 f1)))          ; mulsd xmm0,xmm1
      ("cvtsi2sd"    "f2480f2ac0"             ((cvtsi2sd f0 r0)))       ; cvtsi2sd xmm0,rax
      ("cvttsd2si"   "f2480f2cc0"             ((cvttsd2si r0 f0)))      ; cvttsd2si rax,xmm0 (truncate)
      ("movqxr"      "66480f6ec0"             ((movqxr f0 r0)))         ; movq xmm0,rax
      ("ucomisd"     "660f2ec8"               ((ucomisd f1 f0)))        ; ucomisd xmm1,xmm0 (sets flags)
      ("stsd.disp"   "f20f114208"             ((stsd r2 8 f0)))         ; movsd [rdx+8],xmm0   (box store)
      ("stsd.rsp"    "f20f110424"             ((stsd sp 0 f0)))         ; movsd [rsp],xmm0     (spill)
      ("ldsd.rsp"    "f20f100c24"             ((ldsd f1 sp 0)))         ; movsd xmm1,[rsp]     (reload)
      ;; the 4-byte single lane (the C `float` slot): widen/narrow + movss load/store
      ("cvtss2sd"    "f30f5ac1"               ((cvtss2sd f0 f1)))       ; cvtss2sd xmm0,xmm1 (single->double)
      ("cvtsd2ss"    "f20f5ac8"               ((cvtsd2ss f1 f0)))       ; cvtsd2ss xmm1,xmm0 (double->single)
      ("stss"        "f30f114208"             ((stss r2 8 f0)))         ; movss [rdx+8],xmm0
      ("ldss"        "f30f100b"               ((ldss f1 r3 0)))         ; movss xmm1,[rbx]
      ;; the single lane's arithmetic (native float): F3 for F2, ucomiss without the 66. gas-verified
      ("addss"       "f30f58c1"               ((addss f0 f1)))          ; addss xmm0,xmm1
      ("mulss"       "f30f59c1"               ((mulss f0 f1)))
      ("subss"       "f30f5cc8"               ((subss f1 f0)))
      ("divss"       "f30f5ec8"               ((divss f1 f0)))
      ("minss"       "f30f5dc1"               ((minss f0 f1)))
      ("maxss"       "f30f5fc1"               ((maxss f0 f1)))
      ("addss.rex"   "f3440f58c1"             ((addss f8 f1)))          ; addss xmm8,xmm1
      ("ucomiss"     "0f2ec8"                 ((ucomiss f1 f0)))
      ("cvtsi2ss"    "f3480f2ac0"             ((cvtsi2ss f0 r0)))       ; cvtsi2ss xmm0,rax
      ("cvttss2si"   "f3480f2cc0"             ((cvttss2si r0 f0)))      ; cvttss2si rax,xmm0
      ("movdxr"      "660f6ec0"               ((movdxr f0 r0)))         ; movd xmm0,eax
      ("movdrx"      "660f7ec0"               ((movdrx r0 f0)))         ; movd eax,xmm0
      ("movdxr.rex"  "66450f6eca"             ((movdxr f9 r9)))         ; movd xmm9,r10d
      ("movdrx.rex"  "66450f7eca"             ((movdrx r9 f9))))        ; movd r10d,xmm9
   _ (foldl (_ \ t \ chk (t 0) (t 1) (t 2)) 0 tests)

   ;; -- label addresses are exposed on the assemble result, for a loader/linker to read. --
   loopres (assemble 'x64 '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret)))
   _ (chk-eq "addr.top"  0  (label-at loopres 'top))
   _ (chk-eq "addr.done" 17 (label-at loopres 'done))

   ;; -- the relaxing layout (laylax): in-range jmp/br take the 2-byte short forms (EB / 7x rel8);
   ;; an external or weak-marked target stays rel32. the same (items . labels) shape as lay.
   rx-be (peep backends 'x64 ())
   (rx prog longs)
      (laylax prog rx-be 0 {} longs @ p
       (hexs (resolve <p >p rx-be 0)))
   _ (chk-eq "rlx.loop" "4839c8740548ffc8ebf6c3"
        (rx '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret)) {}))
   _ (chk-eq "rlx.jcc.all" "7c0c750a7f087d067e0477027200c3"
        (rx '((br lt a) (br ne a) (br gt a) (br ge a) (br le a) (br above a) (br below a) (label a) (ret)) {}))
   _ (chk-eq "rlx.mulo" "490fafc00f8002000000eb02ffe6c3"                ; the mulo-inner jo stays rel32; the jmp lands short
        (rx '((mulo r0 r0 r7 r4 ovf) (jmp done) (label ovf) (jmpr r5) (label done) (ret)) {}))
   _ (chk-eq "rlx.weak-stays-long" "e90b0000004839c80f8402000000ffe6c3" ; both wf-targets held long by the longs set
        ({} @ lg (pin lg 'wf 1,
                          rx '((jmp wf) (cmp r0 r1) (br eq wf) (jmpr r5) (label wf) (ret)) lg)))
   _ (chk-eq "rlx.labels" 10
        (laylax '((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret))
                rx-be 0 {} {} @ p
         (peep >p 'done ())))

   ;; -- d <- a OP d with d != a, non-commutative, cannot be encoded: it raises 'alias-dst.
   ;; the help traps that scare and hands the rest back to welp. --
   caught {} _ (pin caught 0 0)
   _ (hear (a \ b \ a = 'alias-dst ? (pin caught 0 1, ()) (welp a b)))
   _ (holo-bytes 'x64 '((sub r0 r3 r0)))
   _ (chk-eq "alias.refused" 1 (peep caught 0 0))

   ;; -- a64's register-form alu reads 31 as xzr in every slot, so `(sub sp sp r0)` would lay
   ;; `neg xzr, x0` and leave sp alone: it raises; moving sp is `lea`'s job. --
   spcaught {} _ (pin spcaught 0 0)
   _ (hear (a \ b \ a = 'a64-alu-sp ? (pin spcaught 0 1, ()) (welp a b)))
   _ (holo-bytes 'a64 '((sub sp sp r0)))
   _ (chk-eq "a64.alu.sp.refused" 1 (peep spcaught 0 0))

   ;; -- ..and a logical immediate of all ones, spelled as the unsigned 2^64-1 a C mask reads as, has no
   ;; bitmask encoding (a run filling its element is reserved): it raises, never lays the reserved word --
   bmcaught {} _ (pin bmcaught 0 0)
   _ (hear (a \ b \ a = 'a64-bitmask-imm ? (pin bmcaught 0 1, ()) (welp a b)))
   _ (holo-bytes 'a64 '((and r0 r0 18446744073709551615)))
   _ (chk-eq "a64.and.allones.refused" 1 (peep bmcaught 0 0))

   ;; -- a64's far memory lane: past imm12's scaled reach and ldur's 256 bytes, x16 builds by add/sub
   ;; immediate (Rn=31 is sp there), two words to 4095 and three to 2^24; past that movz/movk and a
   ;; register add, which reads 31 as xzr -- so sp that far raises. the words are llvm-mc's --
   _ (chk-eq "a64.far"
        ("b0a30fd1000240f9" + "f027409110023191010200f9" + "b0b304d102024039" + "301053d110022dd1030240f9" +
         "b00740d1040240f9" + "10a085d23026a0f23000108b000240f9")
        (holo-hex 'a64 '((ld r0 fp -1000) (st sp 40000 r1) (ldu1 r2 fp -300) (ld r3 r1 -5000000)
                         (ld r4 fp -4096) (ld r0 r1 20000000))))
   ;; -- ..and the three-register twins, a source apart from the destination: lsl/lsr/asr, mvn, the
   ;; extends (uxt* as 64-bit ubfx, the same bits). llvm-mc's words --
   _ (chk-eq "a64.twins"
        "20dc78d362fc4bd3a4fc7f93e60327aa281d40d36a3d40d3ac7d40d3ee1d4093603e4093b47e4093"
        (holo-hex 'a64 '((lsl r0 r1 8) (lsr r2 r3 11) (asr r4 r5 63) (mvn r6 r7) (uxtb r8 r9)
                         (uxth r10 r11) (uxtw r12 r13) (sxtb r14 r15) (sxth r0 r19) (sxtw r20 r21))))
   ;; -- li starts at the first lane that needs a word, by movz or by movn when more lanes are all ones
   ;; than zero; cmp takes imm12 lsl 12 as well. llvm-mc's words --
   _ (chk-eq "a64.li"
        "0020a0d201008092620c8092e3ffdf9204cf8ad28446c2f2050080d2e630959286b9bdf2"
        (holo-hex 'a64 '((li r0 16777216) (li r1 -1) (li r2 -100) (li r3 -281470681743361)
                         (li r4 20014547621496) (li r5 0) (li r6 -305375624))))
   _ (chk-eq "a64.cmp.lsl12" "7f0640f13f0840b1" (holo-hex 'a64 '((cmp r19 4096) (cmp r1 -8192))))
   fscaught {} _ (pin fscaught 0 0)
   _ (hear (a \ b \ a = 'far-base-sp ? (pin fscaught 0 1, ()) (welp a b)))
   _ (holo-bytes 'a64 '((ld r0 sp 20000000)))
   _ (chk-eq "a64.far.sp.refused" 1 (peep fscaught 0 0))

   ;; -- the text front-end (src/love/holo/text.l) parses to the same IR, so it assembles byte-identically. --
   _ (chk-eq "text.basic" (holo-hex 'x64 '((li r0 60) (ret)))
                          (holo-hex 'x64 (asm-text "li r0, 60\nret")))
   _ (chk-eq "text.full"
        (holo-hex 'x64 '((add r0 r0 r1) (label loop) (dec r0) (br ne loop) (ret)))
        (holo-hex 'x64 (asm-text "add r0, r0, r1   ; with a comment\nlabel loop\n  dec r0\n  br ne, loop\n\n  ret\n")))
   ;; the system lane rides the text front-end unchanged: an operation name and a system
   ;; register are ordinary symbols, underscores and all
   _ (chk-eq "text.sys.x64" (holo-hex 'x64 '((cli) (ldcr r0 2) (lidt r6 0) (iretq)))
                            (holo-hex 'x64 (asm-text "cli\nldcr r0, 2\nlidt r6, 0\niretq")))
   _ (chk-eq "text.sys.a64"
        (holo-hex 'a64 '((mrs r0 ttbr1_el1) (dsb ish) (tlbi vmalle1is zr) (isb) (eret)))
        (holo-hex 'a64 (asm-text "mrs r0, ttbr1_el1\ndsb ish\ntlbi vmalle1is, zr\nisb\neret")))
   _ (chk-eq "text.sys.rv64"
        (holo-hex 'rv64 '((csrr r0 mstatus) (csrw stvec r0) (sfence zr zr) (fencei) (sret)))
        (holo-hex 'rv64 (asm-text "csrr r0, mstatus\ncsrw stvec, r0\nsfence zr, zr\nfencei\nsret")))

   ;; -- the gnu-dialect front (gas.l) lowers at&t, arm, riscv and thumb to the same ir, so every
   ;; line here is a form the tables above already froze. inline asm parses through it.
   _ (chk-eq "gas.x64.cr"
        '((ldcr r0 0) (and r0 r0 -5) (or r0 r0 1536) (stcr 0 r0))
        (gas-text 'x64 "mov %cr0, %rax\n and $~(1 << 2), %rax\n or $((1 << 9) | (1 << 10)), %rax\n mov %rax, %cr0"))
   _ (chk-eq "gas.x64.semi"                        ; `;` separates, 32-bit forms ride the 64-bit op
        '((xor r2 r2 r2) (li r0 1) (xor r1 r1 r1) (divl r1))
        (gas-text 'x64 "xorl %edx,%edx; movl $1,%eax; xorl %ecx,%ecx; divl %ecx"))
   _ (chk-eq "gas.x64.labels"                      ; GNU's numeric local labels: 1: / 1f / 2f
        '((mov r0 sp) (li r1 27668) (vmwrite r1 r0) (la r0 l1.1) (li r10 1) (vmlaunch) (jmp l2.1)
          (label l1.1) (mov r9 r0) (li r10 0) (label l2.1))
        (gas-text 'x64 "movq %rsp, %rax\nmovq $0x6c14, %rcx\nvmwrite %rax, %rcx\nleaq 1f(%rip), %rax\nmovq $1, %r11\nvmlaunch\njmp 2f\n1:\nmovq %rax, %r10\nmovq $0, %r11\n2:"))
   _ (chk-eq "gas.x64.contracted"                  ; register-contracted ops drop their named operands
        '((outb) (inl) (rdmsr) (vmrun) (vmread r9 r10) (sgdt r10 0) (vmxon sp 8) (trap) (int 3) (divq r1) (sys))
        (gas-text 'x64 "outb %al, %dx\n inl %dx, %eax\n rdmsr\n vmrun %rax\n vmread %r11, %r10\n sgdt (%r11)\n vmxon 8(%rsp)\n int3\n int $3\n divq %rcx\n syscall"))
   _ (chk-eq "gas.x64.core"
        '((lgdt r6 0) (stcr 3 r6) (ld r1 r0 0) (ldu4 r1 r0 4) (st r0 8 r1) (ldu1 r1 r0 0) (add sp sp 8)
          (cmp r1 r0) (br ne l1.0) (shl r0 3) (shrv r2 r1) (not r0) (push r3) (pop r3) (callr r0) (ret))
        (gas-text 'x64 "lgdt (%rdi)\nmov %rdi, %cr3\nmov (%rax), %rcx\nmovl 4(%rax), %ecx\nmov %rcx, 8(%rax)\nmovzbl (%rax), %ecx\nadd $8, %rsp\ncmp %rax, %rcx\njne 1b\nshl $3, %rax\nshr %cl, %rdx\nnot %rax\npush %rbx\npop %rbx\ncall *%rax\nret"))
   _ (chk-eq "gas.x64.flags"                       ; the flags word through the stack, both spellings
        '((pushf) (pop r0) (pushf) (popf))
        (gas-text 'x64 "# __raw_save_flags\n\tpushf ; pop %rax\npushfq\npopfq"))
   _ (chk-eq "gas.x64.seg"                         ; percpu: the override before its access; an absolute one loads through the destination
        '((seg gs) (ld r0 r9 0) (seg gs) (ldu1 r0 r2 0) (seg gs) (st r1 8 r0)
          (lia r6 current_task) (seg gs) (ld r6 r6 0) (li r0 40) (seg fs) (ld r0 r0 0))
        (gas-text 'x64 "mov %gs:(%r10), %rax\nmovb %gs:(%rdx), %al\nmov %rax, %gs:8(%rcx)\nmovq %gs:current_task, %rdi\nmov %fs:40, %rax"))
   _ (chk-eq "gas.x64.rmw"                         ; atomics and counters on memory; no suffix takes the register's width
        '((lock) (xaddm 4 r2 0 r0) (cmpxchgm 8 r6 8 r1) (xchgm 1 r5 0 r0) (unm inc 4 r0 0)
          (alum add 8 r0 0 1) (alum or 2 r0 0 r1) (btm bts 8 r0 0 3) (unm dec 1 r3 4))
        (gas-text 'x64 "lock xaddl %eax, (%rdx)\ncmpxchgq %rcx, 8(%rdi)\nxchg (%rsi), %al\nincl (%rax)\naddq $1, (%rax)\norw %cx, (%rax)\nbtsq $3, (%rax)\ndecb 4(%rbx)"))
   _ (chk-eq "gas.x64.rip"                         ; an absolute or rip-relative memory operand rides rip: cpu features' `testb $m, caps+1`
        '((testm 1 rip (caps 1) 32) (alum add 4 rip (cnt 0) 1))
        (gas-text 'x64 "testb $32, caps+1\naddl $1, cnt(%rip)"))
   _ (chk-eq "gas.x64.bscan"                       ; the kernel's fls/ffs/hweight, pause and the fences
        '((bscan bsr 8 r0 r1) (bscan bsr 4 r2 r0) (bscan tzcnt 8 r0 r1) (bscan popcnt 4 r0 r1) (pause) (mfence))
        (gas-text 'x64 "bsr %rcx, %rax\nbsrl %eax, %edx\ntzcnt %rcx, %rax\npopcntl %ecx, %eax\npause\nmfence"))
   ; gas's comparisons answer -1 for true: the alternatives' `-(d > 0) * d` is d when d > 0, else 0
   _ (chk-eq "gimm.cmp" [3 0 -1 0] [(gimm (gtoks "-((5-2) > 0) * (5-2)")) (gimm (gtoks "-((2-5) > 0) * (2-5)"))
                                    (gimm (gtoks "1 < 2")) (gimm (gtoks "2 < 1"))])
   _ (chk-eq "gimm.eq" [-1 0 -1 -1] [(gimm (gtoks "(1 != 2)")) (gimm (gtoks "3 == 4")) (gimm (gtoks "2 >= 2")) (gimm (gtoks "1 <= 2"))])
   ; gas's macro language unrolls before gas-top reads: a keyword call, .irp, .ifc, .set values
   _ (chk-eq "gas.expand"
        '(".long 11 + (1 << 8)")
        (gf-expand 'x64 (gf-lines 'x64 ".macro m t:req r:req\n.set .Ln, 0\n.irp s,rax,rcx\n.ifc \\r, %\\s\n.long \\t + (.Ln << 8)\n.endif\n.set .Ln, .Ln+1\n.endr\n.endm\nm r=%rcx, t=11\n.purgem m")))
   ; an .elseif chain takes its first true arm, and >> is gas's logical shift
   _ (chk-eq "gas.elseif"
        '(".long 2" ".long 6")
        (gf-expand 'x64 (gf-lines 'x64 ".if 0\n.long 1\n.elseif 1\n.long 2\n.elseif 1\n.long 3\n.else\n.long 4\n.endif\n.if 0\n.long 5\n.elseif 0\n.long 7\n.else\n.long 6\n.endif")))
   _ (chk-eq "gimm.not" [0 1 1 256] [(gimm (gtoks "!5")) (gimm (gtoks "!0")) (gimm (gtoks "!!(7)")) (gimm (gtoks "(!!(3)) << 8"))])
   _ (chk-eq "gimm.shr" [15 15] [(gimm (gtoks "~0 >> 60")) (gimm (gtoks "0xf0 >> 4"))])
   ;; gas's ranks, as llvm-mc reads them: << with *, | & ^ above + -, comparisons below + -, then
   ;; && then ||, which answer 1; a value wraps at 64 bits, signed
   _ (chk-eq "gimm.rank" [17 3 8 2 -1 1 0 1 -1 0]
        (map (x \ gimm (gtoks x)) ["1 + 2 << 3" "6 & 3 + 1" "8 >> 1 * 2" "5 - 1 | 2" "1 + 2 == 3" "1 || 0 && 0"
                                   "1 + 2 != 3 || 0" "3 == 3 || 0" "(-5) >> 0 < 0" "1 << 63 << 1"]))
   _ (chk-eq "gimm.movq" [1 0]
        (map (x \ gimm (gtoks x)) ["(((195938833) >> 31) == 0 || ((195938833) >> 31) == 8589934591)"
                                   "(((3684054920433006693) >> 31) == 0 || ((3684054920433006693) >> 31) == 8589934591)"]))
   ; a symbol-less rip displacement is the address past the lea (_THIS_IP_): its own bytes
   _ (chk-eq "gas.x64.thisip"
        '((raw (76 141 29 0 0 0 0)) (raw (72 141 5 8 0 0 0)))
        (gas-text 'x64 "lea 0(%rip), %r11\nlea 8(%rip), %rax"))
   ; ..and its fix measures from the instruction's end, past the immediate
   _ (chk-eq "x64.rip.tail"
        "f6050000000020"                           ; d sits right at the end: disp 0, not 1
        (holo-hex 'x64 '((testm 1 rip (d 0) 32) (label d))))
   _ (chk-eq "gas.x64.mov32"                       ; movl zero-extends: the 64-bit mov, then zx4
        '((mov r1 r0) (zx4 r1) (li r0 4294967295))
        (gas-text 'x64 "movl %eax, %ecx\nmovl $-1, %eax"))
   _ (chk-eq "gas.a64.sys"
        '((msri daifset 15) (tlbi vmalle1is zr) (dsb ish) (lea r9 sp 0) (msri spsel 1) (lea sp r9 0)
          (mrs r9 cpacr_el1) (or r9 r9 3145728) (msr cpacr_el1 r9) (isb) (brk 0) (udf 0) (dbrk 61440) (hvc 0)
          (at s1e1w r1) (dc cvau r0) (ic ivau r0) (msr vbar_el1 r0) (wfi) (mrs r0 ctr_el0))
        (gas-text 'a64 "msr daifset, #0xf\n tlbi vmalle1is\n dsb ish\n mov x9, sp\n msr spsel, #1\n mov sp, x9\n mrs x9, cpacr_el1\n orr x9, x9, #(3 << 20)\n msr cpacr_el1, x9\n isb\n brk #0\n udf #0\n hlt #0xf000\n hvc #0\n at s1e1w, x1\n dc cvau, x0\n ic ivau, x0\n msr vbar_el1, x0\n wfi\n mrs x0, ctr_el0"))
   _ (chk-eq "gas.a64.core"
        '((add r0 r1 4) (sub r0 r0 r2) (cmp r0 0) (br eq l1.1) (ld r1 r0 8) (st4 r0 0 r1) (ldu1 r2 r0 1) (jmp l2.1)
          (label l1.1) (raw (224 0 128 210)) (ret) (label l2.1) (sys) (xor r3 r3 r3)
          (raw (0 240 125 211)) (raw (225 3 1 203)))
        (gas-text 'a64 "add x0, x1, #4\n sub x0, x0, x2\n cmp x0, #0\n b.eq 1f\n ldr x1, [x0, #8]\n str w1, [x0]\n ldrb w2, [x0, #1]\n b 2f\n1:\n mov x0, #7\n ret\n2:\n svc #0\n eor x3, x3, x3\n lsl x0, x0, #3\n neg x1, x1"))
   ;; what the IR's 64-bit rows cannot say lands as its own word, held to llvm-mc's: a W register
   ;; op, a written-back or register-indexed address, a W sign-extending load, `ret xN`
   _ (chk-eq "gas.a64.w"
        ["c8018052" "00008012" "e0ffbf52" "e09f0832" "e003032a" "7f280071" "bf01086b" "9f0c0072" "210c0012" "213c0052" "62000132" "21f00112" "41044011" "8a280051" "6000054b" "42400071" "0801090b" "207c021b" "ad7d0453" "41701d53" "417c1f13" "101b9813" "4124c31a" "e103034b" "e103232a"]
        (map (l \ holo-hex 'a64 (gas-text 'a64 l)) ["mov w8, #14" "mov w0, #-1" "mov w0, #0xffff0000" "mov w0, #0xff00ff00" "mov w0, w3" "cmp w3, #10" "cmp w13, w8" "tst w4, #0xf" "and w1, w1, #0xf" "eor w1, w1, #0xffff" "orr w2, w3, #0x80000000" "and w1, w1, #0xaaaaaaaa" "add w1, w2, #4096" "sub w10, w4, #10" "sub w0, w3, w5" "subs w2, w2, #16" "add w8, w8, w9" "mul w0, w1, w2" "lsr w13, w13, #4" "lsl w1, w2, #3" "asr w1, w2, #31" "ror w16, w24, #6" "lsr w1, w2, w3" "neg w1, w3" "mvn w1, w3"]))
   _ (chk-eq "gas.a64.mem"
        ["d08540f8" "23144038" "c3240078" "200c5ff8" "e00f1ff8" "9c6b74f8" "08682e38" "207862f8" "205862b8" "20786238" "200cc039" "20d0df78" "40005fd6"]
        (map (l \ holo-hex 'a64 (gas-text 'a64 l)) ["ldr x16, [x14], #8" "ldrb w3, [x1], #1" "strh w3, [x6], #2" "ldr x0, [x1, #-16]!" "str x0, [sp, #-16]!" "ldr x28, [x28, x20]" "strb w8, [x0, x14]" "ldr x0, [x1, x2, lsl #3]" "ldr w0, [x1, w2, uxtw #2]" "ldrb w0, [x1, x2, lsl #0]" "ldrsb w0, [x1, #3]" "ldrsh w0, [x1, #-3]" "ret x2"]))
   ; ..and an X op the IR would lay as two or more words takes gas's one: lengths are held too
   _ (chk-eq "gas.a64.x"
        ["00008092" "0000b0d2" "e07f40b2" "0000b092" "ebc300b2" "22fc7f93" "64fc60d3" "6005cb93" "e40301cb" "e40321aa" "4120c39a"]
        (map (l \ holo-hex 'a64 (gas-text 'a64 l)) ["mov x0, #-1" "mov x0, #2147483648" "mov x0, #0xffffffff" "mov x0, #0xffffffff7fffffff" "mov x11, #72340172838076673" "asr x2, x1, #63" "lsr x4, x3, #32" "ror x0, x11, #1" "neg x4, x1" "mvn x4, x1" "lsl x1, x2, x3"]))
   ;; ..and a line with an operand nothing reads, or a width mix, is refused, never dropped
   _ (chk-eq "gas.a64.refuse"
        '(gas-a64-operand gas-a64-operand gas-a64-width gas-a64-width gas-a64-operand gas-a64-operand
          a64-bitmask-imm gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ gas-text 'a64 x) l (\ a b a))
             ["cmp x0, x1, ror #2" "neg x1, x2, lsl #64" "add w0, x1, w2" "ldrsw w0, [x1]" "add w0, wzr, #1"
              "ret x2, x3" "and w0, w0, #0" "ldr x0, [x1, x2, lsl #2]" "ldr x0, [x1], #300" "lsl w0, w1, #32"]))
   ;; the hints, the inverted logicals, the carry pair, the reversals, uaccess's unprivileged
   ;; pair and the kernel's system registers and operations, each word llvm-mc's
   _ (chk-eq "gas.a64.more"
        ["3f2003d5" "9f2003d5" "bf2003d5" "9f2203d5" "1f2203d5" "3f2303d5" "bf2303d5" "ff2003d5" "5f2403d5"
         "1f2403d5" "5f2403d5" "df2403d5" "2000228a" "2000220a" "830025ea" "2000222a" "200022ca" "20dc7892"
         "205c1812" "2000029a" "2000025a" "200002ba" "8300057a" "2000c0da" "2008c05a" "2004c0da" "2008c0da"
         "2010c05a" "2014c0da" "200800f8" "208800b8" "20080038" "20e81f78" "20f84ff8" "20084038" "200880b8"
         "004138d5" "414238d5" "62d01bd5" "030738d5" "84f038d5" "20421bd5" "1f7108d5" "a08308d5" "217c0bd5"]
        (map (l \ holo-hex 'a64 (gas-text 'a64 l))
             ["yield" "sev" "sevl" "csdb" "esb" "paciasp" "autiasp" "xpaclri" "hint #34" "bti" "bti c" "bti jc"
              "bic x0, x1, x2" "bic w0, w1, w2" "bics x3, x4, x5" "orn w0, w1, w2" "eon x0, x1, x2"
              "bic x0, x1, #0xff" "bic w0, w1, #0xff" "adc x0, x1, x2" "sbc w0, w1, w2" "adcs x0, x1, x2"
              "sbcs w3, w4, w5" "rbit x0, x1" "rev w0, w1" "rev16 x0, x1" "rev32 x0, x1" "clz w0, w1"
              "cls x0, x1" "sttr x0, [x1]" "sttr w0, [x1, #8]" "sttrb w0, [x1]" "sttrh w0, [x1, #-2]"
              "ldtr x0, [x1, #255]" "ldtrb w0, [x1]" "ldtrsw x0, [x1]" "mrs x0, sp_el0" "mrs x1, CurrentEL"
              "msr tpidrro_el0, x2" "mrs x3, id_aa64mmfr0_el1" "mrs x4, s3_0_c15_c0_4" "msr daif, x0"
              "ic ialluis" "tlbi vale1is, x0" "dc cvap, x1"]))
   ;; the generic spelling below op0 2: the system-instruction space, as llvm-mc lays it
   _ (chk-eq "gas.a64.sgen"
        ["201003d5" "211023d5" "020008d5" "a3342ad5" "e5ff07d5" "1f2003d5"]
        (map (l \ holo-hex 'a64 (gas-text 'a64 l))
             ["msr s0_3_c1_c0_1, x0" "mrs x1, s0_3_c1_c0_1" "msr s1_0_c0_c0_0, x2" "mrs x3, s1_2_c3_c4_5"
              "msr s0_7_c15_c15_7, x5" "msr s0_3_c2_c0_0, xzr"]))
   ;; the exclusive pair and acquire/release, the atomics' and the spinlocks' loads and stores
   _ (chk-eq "gas.a64.ex"
        ["207c5fc8" "207c5f88" "207c5f08" "20fc5f48" "207c02c8" "207c0288" "20fc0208" "20fcdfc8" "20fc9f88"]
        (map (l \ holo-hex 'a64 (gas-text 'a64 l))
             ["ldxr x0, [x1]" "ldxr w0, [x1]" "ldxrb w0, [x1]" "ldaxrh w0, [x1]" "stxr w2, x0, [x1]"
              "stxr w2, w0, [x1]" "stlxrb w2, w0, [x1]" "ldar x0, [x1]" "stlr w0, [x1]"]))
   ;; the vector file the sha2 extension rides: q loads and stores, the byte turn, the block copy,
   ;; the lane add and the four schedule and round words; a wrong arrangement is refused
   _ (chk-eq "gas.a64.simd"
        ["3000c03d" "3104c03d" "3204c43c" "0000803d" "0104803d" "100a206e" "021ca04e" "0486b44e" "2040045e"
         "4150045e" "302a285e" "5062135e" "000638d5" "410cdf3c" "4100df3c" "0380c03c"]
        (map (l \ holo-hex 'a64 (gas-text 'a64 l))
             ["ldr q16, [x1]" "ldr q17, [x1, #16]" "ldr q18, [x1], #64" "str q0, [x0]" "str q1, [x0, #16]"
              "rev32 v16.16b, v16.16b" "mov v2.16b, v0.16b" "add v4.4s, v16.4s, v20.4s" "sha256h q0, q1, v4.4s"
              "sha256h2 q1, q2, v4.4s" "sha256su0 v16.4s, v17.4s" "sha256su1 v16.4s, v18.4s, v19.4s"
              "mrs x0, id_aa64isar0_el1" "ldr q1, [x2, #-16]!" "ldr q1, [x2, #-16]" "ldr q3, [x0, #8]"]))
   _ (chk-eq "gas.a64.simd.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ gas-text 'a64 x) l (\ a b a))
             ["sha256h q0, q1, v4.16b" "sha256su0 v16.4s" "ldr q0, [x1, #300]"]))
   ;; the prefetches, scaled or not; and a move to or from sp, which is add #0 (orr's 31 is xzr)
   _ (chk-eq "gas.a64.prfm"
        ["200080f9" "310080f9" "510480f9" "0a0080f9" "260080f9" "20809ff8"]
        (map (l \ holo-hex 'a64 (gas-text 'a64 l))
             ["prfm pldl1keep, [x1]" "prfm pstl1strm, [x1]" "prfm pstl1strm, [x2, #8]" "prfm plil2keep, [x0]"
              "prfm #6, [x1]" "prfum pldl1keep, [x1, #-8]"]))
   _ (chk-eq "a64.mov.sp" "e00300911f000091" (holo-hex 'a64 '((mov r0 sp) (mov sp r0))))
   ;; cbz/cbnz branch on a register and leave the flags; the label resolves as b.cond's does
   _ (chk-eq "gas.a64.cbz" "410000351f2003d5020000b4"
        (holo-hex 'a64 (gas-text 'a64 "cbnz w1, 1f\n nop\n1:\n cbz x2, 1b")))
   ;; ..and what no row reads still refuses by name
   _ (chk-eq "gas.a64.more.refuse"
        '(gas-a64-operand gas-a64-operand gas-a64-operand badsysreg badsysreg badsysreg-wo "25cc18d5")
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["hint #200" "sttr x0, [x1, #300]" "bti q" "mrs x0, s4_0_c0_c0_0" "mrs x0, no_such_el1"
              "mrs x5, icc_eoir1_el1" "msr icc_eoir1_el1, x5"]))
   ;; the lse atomics, spelled ld<op>/st<op>/swp/cas + a|l|al + b|h
   _ (chk-eq "gas.a64.lse"
        ["a40023f8" "4100e0b8" "a4102338" "a430a378" "a44063f8" "a47023b8" "a480e3f8" "3f0020b8" "3f1060f8"
         "3f302038" "e47fa3c8" "a4fce348" "417ce088"]
        (map (l \ holo-hex 'a64 (gas-text 'a64 l))
             ["ldadd x3, x4, [x5]" "ldaddal w0, w1, [x2]" "ldclrb w3, w4, [x5]" "ldsetah w3, w4, [x5]"
              "ldsmaxl x3, x4, [x5]" "ldumin w3, w4, [x5]" "swpal x3, x4, [x5]" "stadd w0, [x1]" "stclrl x0, [x1]"
              "stsetb w0, [x1]" "cas x3, x4, [sp]" "casalh w3, w4, [x5]" "casa w0, w1, [x2]"]))
   ;; the range tlbis (v8.4) and the outer-shareable and el2 rows
   _ (chk-eq "gas.a64.tlbi.range"
        ["208608d5" "e08208d5" "a08508d5" "608108d5" "40800cd5" "a0820cd5" "20830cd5"]
        (map (l \ holo-hex 'a64 (gas-text 'a64 l))
             ["tlbi rvae1, x0" "tlbi rvaale1is, x0" "tlbi rvale1os, x0" "tlbi vaae1os, x0" "tlbi ripas2e1is, x0"
              "tlbi rvale2is, x0" "tlbi vae2is, x0"]))
   ;; a branch to `.`, `.+k`, `.-k` is its own pc-relative word, never a symbol named `.`
   _ (chk-eq "gas.a64.dot"
        ["00000014" "01000054" "000000b5" "41000034" "02000014" "ffffff97" "0bfeff54" "030080b5"
         'gas-a64-branch 'gas-a64-branch]
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["b ." "b.ne ." "cbnz x0, ." "cbz w1, .+8" "b .+8" "bl .-4" "b.lt .-0x40" "cbnz x3, .-1048576"
              "b .+2" "cbz x0, .+1048576"]))
   ;; `name .req reg` (the kernel's wx\n per register, from an .irp) and .unreq
   _ (chk-eq "gas.a64.req"
        '(((".text" 1 6 ((raw (225 3 0 42)) (add r3 r3 1)))) () () ())
        (gas-top 'a64 "\t.irp n,0,1\nwx\\n .req w\\n\n\t.endr\ntmp .req x3\n\tmov wx1, wx0\n\tadd tmp, tmp, #1\n\t.unreq tmp\n"))
   ;; backward local labels measured at expansion: the alternative's `nops (662b-661b) / 4`
   ;; and an .if over the same distance; a directive between them, or a forward label, refuses
   _ (chk-eq "gas.a64.lbldist"
        '(((".text" 1 6 ((label l661.1) (raw (32 0 128 210)) (add r0 r0 2) (ld r1 r0 0) (label l662.1)
                          (nop) (nop) (nop) (raw (130 1 128 210))))) () () ())
        (gas-top 'a64 "661:\tmov x0, #1\n\tadd x0, x0, #2\n\tldr x1, [x0]\n662:\n\t.rept (662b-661b) / 4\n\tnop\n\t.endr\n\t.if (662b - 661b) == 12\n\tmov x2, #12\n\t.endif\n"))
   _ (chk-eq "gas.ifb" '("nop" "b x" "")
        (gf-expand 'a64 (gf-lines 'a64 ".macro m f\n.ifb \\f\nnop\n.endif\n.ifnb \\f\nb \\f\n.endif\n.endm\nm\nm x\n")))
   ;; labels then a macro call on one line: the labels, then the call's lines
   _ (chk-eq "gas.macro.lbl" '("g:" "\tmov x0, #4" "1:" "h:" "\tmov x1, #4" "k: ret")
        (gf-expand 'a64 (gf-lines 'a64 "\t.macro m, r\n\tmov \\r, #4\n\t.endm\ng:\tm x0\n1: h: m x1\nk: ret")))
   _ (chk-eq "gas.macro.at" "(((\".text\" 1 6 ((jmp .Lx0) (label .Lx0) (jmp .Lx1) (label .Lx1)))) () () ())"
        (show (gas-top 'a64 "\t.macro m\n\tb .Lx\\@\n.Lx\\@:\n\t.endm\n\tm\n\tm\n")))
   _ (chk-eq "gas.a64.lbldist.refuse" '(gas-immediate gas-immediate)
        (map (x \ trap (y \ gas-top 'a64 y) x (\ a b a))
             ["661: nop\n .align 4\n662:\n .rept (662b-661b)/4\n nop\n .endr\n" ".rept (2f-1f)/4\n nop\n .endr\n1: nop\n2:\n"]))
   ;; the bitfield moves, raw words as llvm-mc lays them; widths that differ, an immediate past
   ;; the width, sp, a short or register operand refuse
   _ (chk-eq "gas.a64.bfm" "214c50d3621c0013e4037fb3207c1f53"
        (holo-hex 'a64 (gas-text 'a64 "ubfm x1, x1, #16, #19\n sbfm w2, w3, #0, #7\n bfm x4, xzr, #63, #0\n ubfm w0, w1, #31, #31")))
   _ (chk-eq "gas.a64.bfm.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["ubfm x1, w1, #1, #2" "ubfm w1, w1, #32, #2" "ubfm sp, x1, #1, #2" "ubfm x1, x1, #1" "ubfm x1, x1, x2, #1"]))
   ;; the memory copy and set ops: a copy's [d]!, [s]!, n!, a set's [d]!, n!, v; a register
   ;; twice, zr in brackets, sp, a W register or an unbracketed address refuse
   _ (chk-eq "gas.a64.mops" "40040119a304841d4094011d2004df192074c2192004c21de0070119"
        (holo-hex 'a64 (gas-text 'a64 "cpyfp [x0]!, [x1]!, x2!\n cpye [x3]!, [x4]!, x5!\n cpypwtrn [x0]!, [x1]!, x2!\n setp [x0]!, x1!, xzr\n setmtn [x0]!, x1!, x2\n setgp [x0]!, x1!, x2\n cpyfp [x0]!, [x1]!, xzr!")))
   _ (chk-eq "gas.a64.mops.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-op)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["cpyfp [x0]!, [x0]!, x2!" "setp [x0]!, xzr!, xzr" "cpyfp [xzr]!, [x1]!, x2!" "setp [x0]!, x1!, sp"
              "cpyfp [w0]!, [x1]!, x2!" "cpyfp [x0]!, x1!, x2!" "ldr x0, [x1]!" "cpyfx [x0]!, [x1]!, x2!"]))
   ;; the pair loads and stores, x w s d q, at an offset, pre- and post-indexed, as llvm-mc lays
   ;; them; a misaligned or far offset, a written-back ldnp, a mixed pair, a load of one register
   ;; twice, a written-back base that is also a data register, and a W base refuse
   _ (chk-eq "gas.a64.pair" "400440a9fd7bbfa9fd7bc1a8020c30a8000441ad0084402d4004416940046029200000a9ff7f01a940046029"
        (holo-hex 'a64 (gas-text 'a64 "ldp x0, x1, [x2]\n stp x29, x30, [sp, #-16]!\n ldp x29, x30, [sp], #16\n stnp x2, x3, [x0, #-256]\n ldp q0, q1, [x0, #32]\n ldp s0, s1, [x0, #4]\n ldpsw x0, x1, [x2, #8]\n ldp w0, w1, [x2, #-256]\n stp x0, x0, [x1]\n stp xzr, xzr, [sp, #16]\n ldp w0, w1, [x2, -256]")))
   _ (chk-eq "gas.a64.pair.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["ldp x0, x1, [x2, #4]" "ldp x0, x1, [x2, #512]" "ldnp x0, x1, [x2, #16]!" "ldp x0, w1, [x2]"
              "ldp x3, x3, [x2]" "stp x0, x1, [x0, #16]!" "ldp x0, x1, [w2]" "ldr x0, [w2, #8]"]))
   ;; test bit and branch to a label, back and forward and by `.`, and ands at X: llvm-mc's words.
   ;; a bit past the width, sp, a register bit, an odd or far `.` offset, no bitmask refuse
   _ (chk-eq "gas.a64.tbz" "000000366400f837d0ffffb61f2003d5201c40f2620004ea850c007241002836e2ff0fb7"
        (holo-hex 'a64 (gas-text 'a64 "1:\n tbz x0, #0, 1b\n tbnz w4, #31, 2f\n tbz x16, 63, 1b\n nop\n2:\n ands x0, x1, #0xff\n ands x2, x3, x4\n ands w5, w4, #15\n tbz x1, #5, .+8\n tbnz x2, #33, .-4\n")))
   _ (chk-eq "gas.a64.tbz.refuse"
        '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-branch gas-a64-branch gas-a64-operand a64-bitmask-imm)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["tbz w0, #32, .+8" "tbz x0, #64, .+8" "tbz sp, #1, .+8" "tbz x0, x1, .+8" "tbz x0, #1, .+2" "tbz x0, #1, .+32768"
              "ands sp, x1, #1" "ands x0, x1, #0"]))
   ;; conditional compare and the conditional selects with their aliases, al and nv as conditions:
   ;; llvm-mc's words. sp, a mixed width, a far immediate or nzcv, al/nv in an alias refuse
   _ (chk-eq "gas.a64.ccmp" "200042fa2f185f7a64e845ba20f042faf7529f9ac5809f5a2034829a20a482dae0079f9ae1139f5a62a4839a62d083daa424855a"
        (holo-hex 'a64 (gas-text 'a64 "ccmp x1, x2, #0, eq\n ccmp w1, #31, #15, ne\n ccmn x3, #5, #4, al\n ccmp x1, x2, 0, nv\n csel x23, x23, xzr, pl\n csinv w5, w6, wzr, hi\n csinc x0, x1, x2, lo\n csneg x0, x1, x2, ge\n cset x0, ne\n csetm w1, eq\n cinc x2, x3, lt\n cinv x2, x3, gt\n cneg w4, w5, lo")))
   _ (chk-eq "gas.a64.ccmp.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["ccmp sp, x1, #0, eq" "ccmp x1, #32, #0, eq" "ccmp x1, x2, #16, eq" "csel x0, w1, x2, eq" "csel sp, x1, x2, eq"
              "cset x0, al" "ccmp x1, x2, #0, zz"]))
   ;; sys and sysl by their fields, the `#` optional, xzr when sys leaves rt off; a W or sp
   ;; register, a field past its range, sysl without its register, and too few operands refuse
   _ (chk-eq "gas.a64.sys" "207c0bd5257d0bd51f7508d5832329d5ffff0fd51f0028d5"
        (holo-hex 'a64 (gas-text 'a64 "sys 3, c7, c12, 1, x0\n sys #3, C7, c13, #1, x5\n sys #0, c7, c5, #0\n sysl x3, #1, c2, c3, #4\n sys #7, c15, c15, #7, xzr\n sysl xzr, #0, c0, c0, #0")))
   _ (chk-eq "gas.a64.sys.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["sys 3, c7, c12, 1, w0" "sys #8, c7, c12, #1, x0" "sys #3, c16, c12, #1, x0" "sys #3, c7, c12, #8"
              "sys #3, c7, c12, #1, sp" "sysl x0, #3, c7, c12" "sys 3, c7, c12"]))
   ;; gas's dotless conditional branches, bne as b.ne, back and by `.`
   _ (chk-eq "gas.a64.bne" "00000054e1ffff54c2ffff54a3ffff5481ffff5441000054"
        (holo-hex 'a64 (gas-text 'a64 "1:\nbeq 1b\nbne 1b\nbcs 1b\nblo 1b\nb.ne 1b\nbne .+8\n")))
   ;; a shifted register (the `#` optional), an extended one, #imm with lsl #12, the aliases,
   ;; and the wide moves at a shift: llvm-mc's words. ror on arith, a far shift or extend, sp
   ;; in a shifted form, an X register with a W extend, and a wide move off its lanes refuse
   _ (chk-eq "gas.a64.shift" "000c448b207c824b20fcc2aae90f01cbe00b612abf1c08ea5f0c4feb20c8228bff6f218be043218be07321ab2060220b200440911ffc7ff12000a0f2e0ffbf52a000e0921f04212b20e0228b000c448b200080d2"
        (holo-hex 'a64 (gas-text 'a64 "add x0, x0, x4, lsr #3\n sub w0, w1, w2, asr #31\n orr x0, x1, x2, ror #63\n neg x9, x1, lsl #3\n mvn w0, w1, lsr #2\n tst x5, x8, lsl #7\n cmp x2, x15, lsr #3\n add x0, x1, w2, sxtw #2\n add sp, sp, x1, lsl #3\n add x0, sp, w1, uxtw\n adds x0, sp, x1, uxtx #4\n add w0, w1, w2, uxtx\n add x0, x1, #1, lsl #12\n cmp x0, #4095, lsl #12\n movk x0, #1, lsl #16\n movz w0, #0xffff, lsl #16\n movn x0, #5, lsl #48\n cmn w0, w1, uxtb #1\n add x0, x1, x2, sxtx\n add x0, x0, x4, lsr 3\n movz x0, #1")))
   _ (chk-eq "gas.a64.shift.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["add x0, x1, x2, ror #1" "add x0, x1, x2, lsl #64" "and sp, x1, x2, lsl #1" "add x0, x1, x2, uxtw"
              "add x0, x1, w2, uxtw #5" "movk w0, #1, lsl #32" "movz x0, #0x10000"]))
   ;; a constant's 16-bit group: mov_q's movz/movk, a negative _s laying movn; a group past its
   ;; range or register, _s on movk, and a symbol (a relocation) refuse
   _ (chk-eq "gas.a64.absg" "a075a1d2204299f20000a0920064e6d2c08dccf2002eacf2a00c8ff280008092e0ffaf92"
        (holo-hex 'a64 (gas-text 'a64 "movz x0, :abs_g1_s:0xbadca11\n movk x0, :abs_g0_nc:0xbadca11\n movz x0, :abs_g1_s:-2\n movz x0, :abs_g3:0x3320646e61707865\n movk x0, :abs_g2_nc:0x3320646e61707865\n movk x0, :abs_g1_nc:0x3320646e61707865\n movk x0, #:abs_g0_nc:0x3320646e61707865\n movz x0, :abs_g0_s:-5\n movz x0, :abs_g1_s:-0x80000000")))
   _ (chk-eq "gas.a64.absg.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-movw-symbol)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["movz x0, :abs_g0:0x10000" "movz w0, :abs_g2:1" "movk x0, :abs_g1_s:1" "movz x0, :abs_g0_s:-65536" "movz x0, :abs_g1:sym"]))
   ;; a macro call's arguments split at a space as at a comma, unless an operator sits beside it
   _ (chk-eq "gas.macro.space" '("add x0, x1, #8" "add x0, x1, #(1 + 2)" "add x0, x1, #(1) | (2)" "add x0, x1, #3" "add x0, x1, #1 + 2")
        (gf-expand 'a64 (gf-lines 'a64 ".macro m a, b, c\nadd \\a, \\b, \\c\n.endm\nm x0 x1 #8\nm x0, x1, #(1 + 2)\nm x0 x1 #(1) | (2)\nm x0, x1 , #3\nm x0 x1 #1 + 2")))
   ;; a parameter's default with its `=` spaced or not, taken for an argument left off or empty
   _ (chk-eq "gas.macro.default" '("mov x1, x2" "mov x3, #1" "mov w0, w0" "mov x3, #2" "mov w0, w0" "mov x3, #3" "mov x0, #1" "mov x1, #2" "mov x2, #3" "mov x3, #4" "mov x0, #12" "mov x0, #5" "")
        (gf-expand 'a64 (gf-lines 'a64 ".macro m, el, regsize = 64\n.if \\regsize == 32\nmov w0, w0\n.else\nmov x1, x2\n.endif\nmov x3, #\\el\n.endm\nm 1\nm 2, 32\nm 3, regsize=32\n.macro n a=1, b =2, c= 3, d\nmov x0, #\\a\nmov x1, #\\b\nmov x2, #\\c\nmov x3, #\\d\n.endm\nn , , , 4\n.macro p a=, b\nmov x0, #1\\a\\b\n.endm\np , 2\n.macro q a = 5\nmov x0, #\\a\n.endm\nq\n")))
   ;; a register form beside sp is the extended word at uxtx/uxtw #0, a w mov beside wsp add #0,
   ;; and cmn/negs by register; sp as rm, a flag-setting sp, a logical on sp, a shift past 4
   ;; beside it, a w rm beside sp and zr beside wsp refuse
   _ (chk-eq "gas.a64.spreg" "ff63208bff6320cbe063218b9f60258be06321abff6321ebff6322abff43200be143224bef0300113f0000113f0002abe903036b"
        (holo-hex 'a64 (gas-text 'a64 "add sp, sp, x0\n sub sp, sp, x0\n add x0, sp, x1\n add sp, x4, x5\n adds x0, sp, x1\n cmp sp, x1\n cmn sp, x2\n add wsp, wsp, w0\n sub w1, wsp, w2\n mov w15, wsp\n mov wsp, w1\n cmn x1, x2\n negs w9, w3")))
   _ (chk-eq "gas.a64.spreg.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["add sp, sp, x0, lsl #5" "add sp, sp, sp" "adds sp, x0, x1" "and sp, sp, x0" "add sp, sp, w0" "mov wsp, wzr"]))
   ;; msr and mrs through an x register or xzr; sp (31 would read as xzr) and a w register refuse
   _ (chk-eq "gas.a64.msrzr" "7fd01bd55fd03bd51ff218d543d01bd525003bd5df4203d59ed038d51d4118d5"
        (holo-hex 'a64 (gas-text 'a64 "msr tpidrro_el0, xzr\n mrs xzr, tpidr_el0\n msr s3_0_c15_c2_0, xzr\n msr tpidr_el0, x3\n mrs x5, ctr_el0\n msr daifset, #2\n mrs x30, tpidr_el1\n msr sp_el0, x29\n")))
   _ (chk-eq "gas.a64.msrzr.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["msr tpidr_el0, sp" "mrs sp, tpidr_el0" "msr tpidr_el0, wzr" "mrs w0, tpidr_el0" "msr tpidr_el0, w3"]))
   ;; the advanced simd lane, one line of each form, a register glued to its arrangement; each
   ;; refusal is llvm-mc's but ext's wider index, which llvm-mc masks in silence
   _ (chk-eq "gas.a64.neon" "6c85fe7e3379450e4e86ff5e51bb200ed80f014e6d1c790e021a0f0e8308206ec457270fd506374fe1bbe06e18e4002f1f3f1e0e871fbc0ee1c7070f4ce5056fe8239f4cbc0aa04e3a58904e2c85720eacbaa06e7618ce4ee11f074e303a150efa239f0cfd0d096ed32ad14eefaf400c0b180d2e2226d24c237e000c27a4000ff61daf4e5a27096f370d084e3017416f36477a6fc91df72e7d6b1d4ed605134ec305084e27aed40c1820004c305a202e2327370f5f84e44efe1cf84ef4577c6f257a400cef5bd44ef81c3b4e8c78ca4e9e59204e8826724fc81e726e95440a6fca285c4ee5876a6e4714220f45540a6f172c404c2159206e071fb20ee726456fac1b200e5917392f25a8404c"
        (holo-hex 'a64 (gas-text 'a64 "sub d12, d11, d30\n zip2 v19.4h, v9.4h, v5.4h\n add d14, d18, d31\n abs v17.8b, v26.8b\n dup v24.16b, w30\n bic v13.8b, v3.8b, v25.8b\n uzp1 v2.8b, v16.8b, v15.8b\n rev32 v3.16b, v4.16b\n shl v4.2s, v30.2s, #7\n sshr v21.4s, v22.4s, #9\n neg v1.2d, v31.2d\n movi d24, #0\n umov wzr, v24.h[7]\n mov v7.2s, v28.2s\n movi v1.2s, #255, msl #8\n movi v12.2d, #0xff00ff00ff00ff00\n st1 { v8.16b, v9.16b, v10.16b, v11.16b }, [sp], xzr\n rev64 v28.4s, v21.4s\n uzp2 v26.4s, v1.4s, v16.4s\n add v12.4h, v9.4h, v18.4h\n neg v12.4s, v21.4s\n uzp1 v22.2d, v3.2d, v14.2d\n ins v1.b[3], wzr\n zip1 v16.8b, v17.8b, v21.8b\n st1 { v26.8b - v29.8b }, [sp], xzr\n mov v29.b[4], v15.b[1]\n trn1 v19.2d, v22.2d, v17.2d\n ld1 { v15.1d - v16.1d }, [sp]\n ext v11.8b, v0.8b, v13.8b, #3\n ld1 { v2.8h - v5.8h }, [x17], x18\n st1 { v3.1d }, [x17]\n movi v7.4h, #1, lsl #8\n mov v22.2d, v15.2d\n urshr v26.16b, v26.16b, #7\n dup v23.2d, x9\n usra v16.2d, v25.2d, #63\n sri v22.2d, v25.2d, #6\n bif v9.8b, v14.8b, v23.8b\n trn2 v29.16b, v27.16b, v29.16b\n dup v22.16b, v14.b[9]\n dup v3.2d, v14.d[0]\n ld1 { v7.1d, v8.1d }, [x17], x20\n st1 { v24.16b - v27.16b }, [x0]\n not v16.8b, v17.8b\n srshr v3.2s, v25.2s, #9\n add v31.2d, v2.2d, v4.2d\n orn v30.16b, v7.16b, v24.16b\n sli v20.2d, v31.2d, #60\n ld1 { v5.2s }, [x17]\n uzp2 v15.2d, v31.2d, v20.2d\n and v24.16b, v7.16b, v27.16b\n zip2 v12.2d, v4.2d, v10.2d\n cnt v30.16b, v12.16b\n srshr v8.2d, v20.2d, #14\n bsl v8.16b, v22.16b, v18.16b\n sri v21.16b, v4.16b, #6\n trn1 v10.8h, v6.8h, v28.8h\n sub v5.8h, v31.8h, v10.8h\n ssra v7.2s, v2.2s, #30\n sli v5.16b, v2.16b, #2\n ld1 { v23.2d - v26.2d }, [x0]\n mvn v1.16b, v9.16b\n orr v7.8b, v24.8b, v18.8b\n urshr v7.2d, v23.2d, #59\n rev16 v12.8b, v29.8b\n usra v25.2s, v26.2s, #7\n ld1 { v5 .4s, v6 .4s }, [x1]\n")))
   _ (chk-eq "gas.a64.neon.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["movi v0.1d, #0" "ushr v15.8b, v1.8b, #58" "mov xzr, v6.s[12]" "not v17.1d, v21.1d" "uzp2 v15.1d, v6.1d, v0.1d" "ext v26.8h, v24.8h, v7.8h, #11" "ins v19.b[0], wsp" "sshr v13.16b, v28.16b, #32" "dup v24.8b, v4.s[2]" "umov xzr, v4.d[4]" "shl v11.8h, v18.8h, #46" "cnt v8.4h, v28.4h" "rev64 v19.2d, v5.2d" "bic v7.2d, v31.2d, v31.2d" "orn v19.2s, v9.2s, v12.2s" "sli v28.4h, v6.4h, #46" "ext v1.8b, v2.8b, v3.8b, #8" "ld1 { v30.8b - v30.8b }, [x0]"]))
   ;; `ldr rt, =expr`: a constant one movz holds is that movz, else a word in the section's pool,
   ;; one per width and expression, laid at .ltorg or the section's end, and a literal load of it;
   ;; a .set read before it is made reads its first value
   _ (chk-eq "gas.a64.litpool" "((((\".text\" 1 6 ((raw (128 70 130 210)) (afix ld19 1476395009 .Llit0 0) (afix ld19 1476395010 .Llit1 0) (afix ld19 1476395011 .Llit1 0) (afix ld19 402653188 .Llit2 0) (nop) (dalign 8) (label .Llit0) (raw (69 35 1 0 0 0 0 0)) (dalign 8) (label .Llit1) (raw ((fix 8 abs64 foo 0))) (dalign 4) (label .Llit2) (raw ((fix 4 abs32 foo 4))) (afix ld19 1476395013 l1.1 0) (label l1.1) (raw ((fix 4 abs32 bar 0))))) (\".x\" 1 6 ((afix ld19 1476395014 .Llit3 0) (dalign 8) (label .Llit3) (raw (255 255 255 255 255 255 255 255))))) () () ()) (((\".text\" 1 6 ((raw (2 0 0 0)) (raw (3 0 0 0))))) () () ()))"
        (show [(gas-top 'a64 " ldr x0, =0x1234\n ldr x1, =0x12345\n ldr x2, =foo\n ldr x3, =foo\n ldr w4, =foo + 4\n nop\n .ltorg\n ldr x5, 1f\n1: .long bar\n.section .x, \"ax\"\n ldr x6, =-1\n")
               (gas-top 'a64 ".long .La\n.set .La, 2\n.set .La, 3\n.long .La\n")]))
   ;; a64's `//` starts a comment outside a string only
   _ (chk-eq "gas.a64.cutquote" '(".ascii \"a//b\" " ".ascii \"q\\\"//\" " "nop ")
        (gf-lines 'a64 ".ascii \"a//b\" // c\n.ascii \"q\\\"//\" //x\nnop // d"))
   ;; fp and lr, llvm-mc's names for x29 and x30, in every X operand, as llvm-mc lays them
   _ (chk-eq "gas.a64.lrfp" "fd7bbfa9fd030091be0740f9e0031eaafd430091c0033fd6c0035fd6fd7bc1a8"
        (holo-hex 'a64 (gas-text 'a64 "stp fp, lr, [sp, #-16]!\n mov fp, sp\n ldr lr, [fp, #8]\n mov x0, lr\n add fp, sp, #16\n blr lr\n ret lr\n ldp fp, lr, [sp], #16\n")))
   ;; adr to a label in its section, `.+k` and an addend, and a literal load's addend, as llvm-mc
   ;; lays them; sp, a W register, a byte past 1MB and a third operand refuse
   _ (chk-eq "gas.a64.adr" '("1f2003d51f2003d522000010e3ffff58e4ffff103f000010" (gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand))
        [(holo-hex 'a64 (gas-text 'a64 "f:\n nop\n nop\n adr x2, f+12\n ldr x3, f+8\n adr x4, . - 4\n adr xzr, 1f\n1:\n"))
         (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
              ["adr sp, f\nf:" "adr w0, f\nf:" "adr x0, . + 1048576" "adr x0, f, f\nf:"])])
   ;; the multiply-adds, zr in a logical immediate and a load or store, and an X immediate's one word,
   ;; as llvm-mc lays them; a writeback onto its own data register, sp as data, a long op's X factor
   ;; and an immediate no word holds refuse
   _ (chk-eq "gas.a64.mla" '("200c029b200ca29b20fc229b207c429be01f40b21f0040f93f040039c80740b1"
                             (gas-a64-unpredictable gas-a64-unpredictable gas-a64-operand gas-a64-operand imm12-range))
        [(holo-hex 'a64 (gas-text 'a64 "madd x0, x1, x2, x3\n umaddl x0, w1, w2, x3\n smnegl x0, w1, w2\n smulh x0, x1, x2\n orr x0, xzr, #0xff\n ldr xzr, [x0]\n strb wzr, [x1, #1]\n adds x8, x30, #4096\n"))
         (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
              ["str x0, [x0, #-8]!" "ldr x0, [x0], #8" "ldr sp, [x1]" "smull x0, x1, w2" "sub x27, x4, #21845"])])
   ;; the exclusive pairs and casp, and w31 as llvm-mc reads it; a status that is a data register
   ;; or the base refuses, as casp's odd pair
   _ (chk-eq "gas.a64.xp" '("40047fc840847f88400423c8eaaf29c8827c2048feff6608e0073fc8ff03002a"
                           (gas-a64-unpredictable gas-a64-unpredictable gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-register))
        [(holo-hex 'a64 (gas-text 'a64 "ldxp x0, x1, [x2]\n ldaxp w0, w1, [x2, #0]\n stxp w3, x0, x1, [x2]\n stlxp w9, x10, x11, [sp]\n casp x0, x1, x2, x3, [x4]\n caspal w6, w7, w30, wzr, [sp]\n stxp wzr, x0, x1, [sp]\n mov w31, w0\n"))
         (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
              ["stxp w0, x0, x1, [x2]" "stxp w2, x0, x1, [x2]" "ldxp x0, w1, [x2]" "ldxp x0, x1, [xzr]" "casp x1, x2, x3, x4, [x5]" "mov w32, w0"])])
   ;; a register variable's or clobber's name takes gcc's r0..r30 for x0..x30; asm text keeps
   ;; llvm-mc's names, where r0 refuses
   _ (chk-eq "gas.a64.ccnames" '((r0 r28 fp lr () r0) gas-a64-register)
        [(map (s \ gas-regname 'a64 s) ["r0" "r28" "r29" "r30" "r31" "x0"])
         (trap (x \ gas-text 'a64 x) "mov r0, r1" (\ a b a))])
   ;; a note section is sht_note; an alias of an alias follows the chain to its label, whichever
   ;; was set first, and a cycle refuses; .weak exports and answers its names, .globl too, once
   _ (chk-eq "gas.note.weak" """((((".note.L" 7 2 ((raw (1 0 0 0))))) () () ()) (((".text" 1 6 ((label f) (label h) (label g) (label w) (ret) (raw ((fix 8 abs64 u 0)))))) ("f" "g" "w") () ("w" "u" "f")) gas-alias)"""
        (show [(gas-top 'a64 ".pushsection .note.L, \"a\", @note\n.long 1\n.popsection\n")
               (gas-top 'a64 ".globl f\nf: ret\n.globl g\n.set g, h\n.weak w\n.set w, g\n.set h, f\n.weak u\n.quad u\n.weak f\n")
               (trap (x \ gas-top 'a64 x) ".set a, b\n.set b, a\n.globl a\n" (\ a b a))]))
   ;; a binary literal, 0b or 0B and binary digits; a bare 0b is still the label behind, and a
   ;; digit or letter glued past the bits refuses
   _ (chk-eq "gas.a64.binlit" "((((\".text\" 1 6 ((raw (1 0 0 0 0 0 0 0 3 0 0 0 0 0 0 0 11 0 0 0 0 0 0 0)) (raw (160 0 128 210)) (raw (255)) (raw (18 0 0 0 0 0 0 0))))) () () ()) \"1f2003d5ffffff1701000014\" (gas-data gas-data gas-data gas-data gas-immediate))"
        (show [(gas-top 'a64 ".quad 0b01, 0B11, 0b1011\nmov x0, #0b101\n.byte 0b11111111\n.quad (0b1 << 4) | 0b10\n")
               (holo-hex 'a64 (gas-text 'a64 "0:\n nop\n b 0b\n b 0f\n0:\n"))
               (map (l \ trap (x \ gas-top 'a64 x) l (\ a b a)) [".quad 0b2\n" ".quad 0b1x\n" ".quad 0b_1\n" ".quad 0b1_0\n" "mov x0, #0b12\n"])]))
   ;; an argument that is one quoted string passes its inside, positional or by name
   _ (chk-eq "gas.macro.quote" '("nop" "dmb sy" ".ascii \"x y\"" "mov x0, x1" "mov x0, x1" "mov x2, x3" "nop" "")
        (gf-expand 'a64 (gf-lines 'a64 ".macro alt insn1, insn2, cap, enable = 1\n\\insn1\n\\insn2\n.endm\nalt nop, \"dmb sy\", 90\n.macro s a\n.ascii \"\\a\"\n.endm\ns \"x y\"\n.macro t a, b\nmov \\a, \\b\n.endm\nt \"x0\", \"x1\"\nt x0 \"x1\"\nt a=\"x2\", b=x3\n.macro w a\n.ifc \\a,dmb sy\nnop\n.endif\n.endm\nw \"dmb sy\"\n")))
   ;; .org to a label with instructions between: zeros up to it once layout holds; one behind
   ;; where it stands refuses
   _ (chk-eq "gas.a64.org" "((((\".text\" 1 6 ((label a) (nop) (jmp a) (mov r0 r1) (label .Lorg0) (raw (0 0 0 0)) (nop)))) () () ()) (((\".text\" 1 6 ((label .Ls0) (nop) (jmp .Ls0) (label .Lorg0) (raw (0 0 0 0 0 0 0 0)) (label .Ls1) (nop) (jmp .Ls1) (label .Lorg1) (raw (0 0 0 0 0 0 0 0))))) () () ()) gas-org-back)"
        (show (map (x \ trap (y \ gas-top 'a64 y) x (\ a b a))
                   ["a: nop\n b a\n mov x0, x1\n .org a + 16\n nop\n"
                    ".macro v\n.Ls\\@: nop\n b .Ls\\@\n .org .Ls\\@ + 16\n.endm\n v\n v\n"
                    "a: nop\n nop\n nop\n .org a + 4\n nop\n"])))
   ;; the bitfield aliases as llvm-mc lays them; a field past the register refuses
   _ (chk-eq "gas.a64.bfa" "21ac68d3201c031320fc40b3201c7cd320000113201470b320140033e00f78b3e3030133"
        (holo-hex 'a64 (gas-text 'a64 "ubfx x1, x1, #40, #4\n sbfx w0, w1, #3, #5\n bfxil x0, x1, #0, #64\n ubfiz x0, x1, #4, #8\n sbfiz w0, w1, #31, #1\n bfi x0, x1, #16, #6\n bfi w0, w1, #0, #6\n bfc x0, #8, #4\n bfc w3, #31, #1")))
   _ (chk-eq "gas.a64.bfa.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["ubfx x0, x1, #60, #5" "ubfx x0, x1, #0, #0" "bfi w0, w1, #32, #1" "ubfx x0, w1, #1, #1"]))
   ;; adrp to a symbol's page and :lo12: of it on add and the loads and stores: address fixes, the
   ;; word as llvm-mc lays it, the access size naming the kind, the addend aboard
   _ (chk-eq "gas.a64.adrp"
        "((afix adrp21 2415919105 id_override 0) (afix addlo12 2432696353 id_override 0) (afix lo12s8 4181721120 sym 0) (afix lo12s1 960495648 sym 3) (afix lo12s4 3103785058 sym 0) (afix adrp21 2415919121 .Lpt 16))"
        (show (gas-text 'a64 "adrp x1, id_override\n add x1, x1, :lo12:id_override\n ldr x0, [x1, :lo12:sym]\n ldrb w0, [x1, :lo12:sym+3]\n str w2, [x3, #:lo12:sym]\n adrp x17, .Lpt + 16")))
   ;; a register form naming zr, which the IR's rows cannot hold, is its own word
   _ (chk-eq "gas.a64.zr" "e0031faaff0301aa3f001feb20001f8be20303aa3f001f6ae4031fcbe503064a3f0002cb"
        (holo-hex 'a64 (gas-text 'a64 "mov x0, xzr\n mov xzr, x1\n cmp x1, xzr\n add x0, x1, xzr\n orr x2, xzr, x3\n tst w1, wzr\n neg x4, xzr\n eor w5, wzr, w6\n sub xzr, x1, x2")))
   _ (chk-eq "gas.a64.adrp.refuse" '(gas-a64-operand gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ gas-text 'a64 x) l (\ a b a))
             ["adrp w1, sym" "add w1, w1, :lo12:sym" "ldr x0, [x1, :lo12:sym]!" "ldr x0, [x1, :got:sym]"]))
   _ (chk-eq "gas.a64.lse.refuse"
        '(gas-a64-operand gas-a64-op gas-a64-operand gas-a64-operand gas-a64-operand)
        (map (l \ trap (x \ holo-hex 'a64 (gas-text 'a64 x)) l (\ a b a))
             ["ldaddb x3, x4, [x5]" "stadda x3, [x5]" "ldadd x3, w4, [x5]" "stadd x1, x2, [x3]" "ldadd x1, x2, [x3, #8]"]))
   _ (chk-eq "gas.rv64"
        '((csrr r0 time) (csrw stvec r0) (csrs sie r0) (csrsi sstatus 2) (csrci sstatus 2) (sys) (trap) (csrw cycle zr)
          (fence) (wfi) (sfence zr zr) (sfence r0 r1) (li r0 5) (mov r1 r0) (add sp sp -16) (ld r2 sp 8) (st sp 0 r2)
          (cmp r0 r1) (br eq l1.1) (jmp l2.1) (label l1.1) (ret) (label l2.1) (nop))
        (gas-text 'rv64 "csrr a0, time\n csrw stvec, a0\n csrs sie, a0\n csrsi sstatus, 2\n csrci sstatus, 2\n ecall\n ebreak\n unimp\n fence\n wfi\n sfence.vma\n sfence.vma a0, a1\n li a0, 5\n mv a1, a0\n addi sp, sp, -16\n ld a2, 8(sp)\n sd a2, 0(sp)\n beq a0, a1, 1f\n j 2f\n1:\n ret\n2:\n nop"))
   _ (chk-eq "gas.thumb"
        '((trap) (brk 3) (nop) (wfi) (li r0 5) (add r0 r0 r1) (ld r1 r0 4) (ret))
        (gas-text 'thumb2 "bkpt #0\n bkpt #3\n nop\n wfi\n mov r0, #5\n add r0, r0, r1\n ldr r1, [r0, #4]\n bx lr"))
   ;; ..and the spellings the substitution hands a template: a register at a width (with GNU's
   ;; modifier letter), an immediate, a memory operand, and the way back from a clobber's name
   _ (chk-eq "gas.spell.x64" '("%rax" "%r8d" "%dx" "%al" "%r11w" "%rsp" "$3" "3" "(%r11)")
        [(gas-reg 'x64 'r0 8 0) (gas-reg 'x64 'r7 4 0) (gas-reg 'x64 'r2 2 0) (gas-reg 'x64 'r0 1 0)
         (gas-reg 'x64 'r10 8 119) (gas-reg 'x64 'sp 8 0) (gas-imm 'x64 3 0) (gas-imm 'x64 3 99) (gas-mem 'x64 'r10)])
   _ (chk-eq "gas.spell.arm" '("x0" "w9" "x9" "sp" "a0" "t0" "r3" "3" "#3" "[x1]" "0(a1)")
        [(gas-reg 'a64 'r0 8 0) (gas-reg 'a64 'r9 4 0) (gas-reg 'a64 'r9 4 120) (gas-reg 'a64 'sp 8 0)
         (gas-reg 'rv64 'r0 8 0) (gas-reg 'rv64 'r8 8 0) (gas-reg 'thumb2 'r3 4 0)
         (gas-imm 'a64 3 0) (gas-imm 'thumb2 3 0) (gas-mem 'a64 'r1) (gas-mem 'rv64 'r1)])
   _ (chk-eq "gas.regname" '(r0 r14 r2 sp () r9 r0 r7 () r5)
        [(gas-regname 'x64 "rax") (gas-regname 'x64 "r15") (gas-regname 'x64 "edx") (gas-regname 'x64 "rsp")
         (gas-regname 'x64 "nope") (gas-regname 'a64 "x9") (gas-regname 'a64 "x0") (gas-regname 'rv64 "a7")
         (gas-regname 'rv64 "t6") (gas-regname 'thumb2 "r5")])

   ;; -- the ELF linker (src/love/holo/elf.l) wraps assembled bytes in a well-formed static executable. --
   elfprog '((li r0 60) (li r6 0) (sys))
   elfres  (elf64 'x64 (a \ elfprog) '(65 66 67))
   elfimg  (peep elfres 'bytes 0)
   _ (chk-eq "elf.magic"   127     (elfimg 0))        ; \x7f E L F
   _ (chk-eq "elf.machine" 62      (elfimg 18))       ; e_machine = x86-64
   _ (chk-eq "elf.entry"   4194424 (peep elfres 'entry 0))
   _ (chk-eq "elf.size"    (120 + (#(holo-bytes 'x64 elfprog) + 3)) #elfimg)
   _ (chk-eq "elf.a64-machine" 183 (peep (elf64 'a64 (a \ elfprog) ()) 'bytes 0 18))

   ;; ..and the elf32 twin: a 52-byte header and a 32-byte phdr; p_flags sits seventh in an
   ;; Elf32_Phdr (at 76, where an Elf64_Phdr has p_offset), and e_entry carries the thumb bit
   t32prog '((li r0 42) (li r7 1) (sys))
   e32     (elf32 'thumb2 (a \ t32prog) ())
   e32img  (peep e32 'bytes 0)
   _ (chk-eq "elf32.class"      1  (e32img 4))          ; elfclass32
   _ (chk-eq "elf32.machine"    40 (e32img 18))         ; EM_ARM
   _ (chk-eq "elf32.thumb-bit"  1  (e32img 24 & 1))     ; e_entry bit 0: enter in Thumb state
   _ (chk-eq "elf32.eabi5"      5  (e32img 39))         ; e_flags top byte: eabi version 5
   _ (chk-eq "elf32.ehsize"     52 (e32img 40))
   _ (chk-eq "elf32.phentsize"  32 (e32img 42))
   _ (chk-eq "elf32.p-offset"   0  (e32img 56))         ; the 64-bit order would put p_flags here
   _ (chk-eq "elf32.p-flags"    7  (e32img 76))         ; ..and it sits here instead
   _ (chk-eq "elf32.size" (84 + #(holo-bytes 'thumb2 t32prog)) #e32img)

   ;; -- `refix`, the linker's door onto the encoders. arm is rel: the field it hands back carries
   ;; the addend and the aux the encoding hides. the four thumb2 kinds, one law each. --
   t2be (peep backends 'thumb2 ())
   (rfx k bs t s) (hexs (refix-with t2be k bs t s 4))
   ;; the placeholders left in a .o: branches hold their base encoding with the -4 pipeline
   ;; addend baked in (gas's fff7feff for `bl sym`), movw/movt hold rd and a zero imm16
   base-bl '(255 247 254 255)  base-b '(255 247 254 191)
   base-mw '(64 242 0 2)       base-mt '(192 242 0 2)             ; movw/movt r2, #0
   ;; a resolved branch is the bytes `patch` lays for the same pair: one scatter
   _ (chk-eq "refix.bl" (hexs (patch-with t2be 'bl 4096 256 4 0)) (rfx 'bl base-bl 4096 256))
   _ (chk-eq "refix.b"  (hexs (patch-with t2be 'b  4096 256 4 0)) (rfx 'b  base-b  4096 256))
   ;; the thumb bit rides in the target and every branch field shifts it out, so odd and even agree
   _ (chk-eq "refix.thumb-bit" (rfx 'bl base-bl 4096 256) (rfx 'bl base-bl 4097 256))
   ;; movw16/movt16 read their rd back out of hw2
   _ (chk-eq "refix.movw" (hexs (patch-with t2be 'movw16 2271560481 0 4 2)) (rfx 'movw16 base-mw 2271560481 0))
   _ (chk-eq "refix.movt" (hexs (patch-with t2be 'movt16 2271560481 0 4 2)) (rfx 'movt16 base-mt 2271560481 0))
   ;; ..and a field carrying an addend this backend never bakes refuses: the base encoding is
   ;; rebuilt and compared, so no inverse scatter is needed
   rfcaught {} _ (pin rfcaught 0 0)
   _ (hear (a \ b \ a = 'thumb-refix-addend ? (pin rfcaught 0 1, ()) (welp a b)))
   _ (rfx 'bl '(255 247 255 255) 4096 256)                       ; ..the same bl two bytes further on
   _ (chk-eq "refix.addend.refused" 1 (peep rfcaught 0 0))

   ;; -- the a64 backend: fixed 32-bit little-endian words, checked vs llvm-mc / llvm-objdump. --
   a64tests '(
      ("a64.li"     "800780d2"          ((li r0 60)))
      ("a64.movk"   "00cf8ad28046a2f2"  ((li r0 305419896)))     ; 0x12345678: movz + movk
      ("a64.mov"    "e00301aa"          ((mov r0 r1)))
      ("a64.add"    "2000028b"          ((add r0 r1 r2)))         ; native 3-address, no dance
      ("a64.sub"    "200002cb"          ((sub r0 r1 r2)))
      ("a64.and"    "2000028a"          ((and r0 r1 r2)))
      ("a64.or"     "200002aa"          ((or  r0 r1 r2)))
      ("a64.xor"    "200002ca"          ((xor r0 r1 r2)))         ; -> eor
      ("a64.addi"   "20140091"          ((add r0 r1 5)))
      ("a64.subi"   "201400d1"          ((sub r0 r1 5)))
      ("a64.addneg" "201400d1"          ((add r0 r1 -5)))         ; negative imm flips add->sub
      ("a64.cmp"    "1f0001eb"          ((cmp r0 r1)))
      ("a64.cmpi"   "1f1c00f1"          ((cmp r0 7)))
      ("a64.mul"    "207c029b"          ((imul r0 r1 r2)))
      ("a64.mulh"   "a47c4a9b"          ((mulh r4 r5 r10)))                ; smulh x4, x5, x10
      ("a64.neg"    "e00300cb"          ((neg r0)))
      ("a64.not"    "e00320aa"          ((not r0)))               ; -> mvn
      ("a64.ldr"    "200040f9"          ((ld r0 r1 0)))
      ("a64.ldr8"   "200440f9"          ((ld r0 r1 8)))
      ("a64.str"    "e30b00f9"          ((st sp 16 r3)))
      ("a64.ldur"   "20805ff8"          ((ld r0 r1 -8)))          ; unaligned/neg -> LDUR
      ("a64.push"   "e00f1ff8"          ((push r0)))              ; str x0,[sp,#-16]!
      ("a64.pop"    "e00741f8"          ((pop r0)))               ; ldr x0,[sp],#16
      ("a64.lea"    "ff8300d1"          ((lea sp sp -32)))
      ("a64.ret"    "c0035fd6"          ((ret)))
      ("a64.svc"    "010000d4"          ((sys)))
      ("a64.nop"    "1f2003d5"          ((nop)))
      ("a64.align"  "c0035fd61f2003d51f2003d51f2003d5c0035fd6" ((ret) (align 16) (label x) (ret)))   ; nop-word fill
      ("a64.brk"    "000020d4"          ((trap)))
      ("a64.loop"   "1f0001eb60000054000400d1fdffff17c0035fd6"
                     ((label top) (cmp r0 r1) (br eq done) (dec r0) (jmp top) (label done) (ret)))
      ;; adds/subs are the s-variants (set nzcv); set is cset; mulo is smulh + cmp vs asr #63
      ("a64.jmpr"   "00001fd6"          ((jmpr r0)))                  ; br x0
      ("a64.callr"  "00003fd6"          ((callr r0)))                 ; blr x0  (through a fn pointer)
      ("a64.abs64"  "0800000000000000c0035fd6"                        ; an 8-byte absolute label address, then ret
                      ((raw ((fix 8 abs64 tgt 0))) (label tgt) (ret)))
      ("a64.set.eq" "e0179f9a"          ((set eq r0)))                ; cset x0, eq
      ("a64.set.vs" "e0779f9a"          ((set vs r0)))                ; cset x0, vs  (overflow -> 0/1)
      ("a64.adds"   "000007ab"          ((adds r0 r0 r7)))            ; adds x0,x0,x7
      ("a64.subs"   "600007eb"          ((subs r0 r3 r7)))            ; subs x0,x3,x7
      ("a64.mulo.prog" "047c479b007c079b9ffc80eb4100005402000014a0001fd6c0035fd6"   ; smulh x4,x0,x7; mul x0,x0,x7; cmp x4,x0,asr#63; b.ne ovf; b done; br x5; ret
                      ((mulo r0 r0 r7 r4 ovf) (jmp done) (label ovf) (jmpr r5) (label done) (ret)))
      ;; shifts, test, div/rem, indexed
      ("a64.sar"    "00fc4193"          ((sar r0 1)))                 ; asr x0,x0,#1   (untag)
      ("a64.shr"    "e7fc41d3"          ((shr r7 1)))                 ; lsr x7,x7,#1
      ("a64.shl"    "00f07dd3"          ((shl r0 3)))                 ; lsl x0,x0,#3
      ("a64.rol"    "0080c093"          ((rol r0 32)))                ; ror x0,x0,#32  (the hash rotate)
      ("a64.ror"    "0020c093"          ((ror r0 8)))                 ; ror x0,x0,#8
      ("a64.test.r" "1f0007ea"          ((test r0 r7)))               ; tst x0,x7
      ("a64.test.i" "1f0040f2"          ((test r0 1)))                ; tst x0,#1  (the gap/fixnum low-bit check)
      ("a64.and.i"  "00084092"          ((and r0 r0 7)))              ; and x0,x0,#7  (bitmask immediate)
      ("a64.div"    "000cc79a"          ((div r0 r0 r7)))             ; sdiv x0,x0,x7
      ("a64.rem"    "040cc79a8080079b"  ((rem r0 r0 r7 r4)))          ; sdiv x4,x0,x7 ; msub x0,x4,x7,x0
      ("a64.ldx"    "e00c008b000440f9"  ((ldx r0 r7 r0 8 8)))         ; add x0,x7,x0,lsl#3 ; ldr x0,[x0,#8]
      ("a64.leax"   "2101098b21040091"  ((leax r1 r9 r9 1 1)))        ; add x1,x9,x9 ; add x1,x1,#1
      ("a64.stx"    "f00c008b080600f9"  ((stx r7 r0 8 8 r8)))         ; add x16,x7,x0,lsl#3 ; str x8,[x16,#8]
      ("a64.ldxb"   "6000008b00404039"  ((ldxb r0 r3 r0 1 16)))       ; add x0,x3,x0 ; ldrb w0,[x0,#16]   (string-lane peep read)
      ("a64.stxb"   "7000008b00420039"  ((stxb r3 r0 1 16 r0)))       ; add x16,x3,x0 ; strb w0,[x16,#16] (cask-lane pin store)
      ("a64.ldxb-1" "6000008b00f05f38"  ((ldxb r0 r3 r0 1 -1)))       ; add x0,x3,x0 ; ldurb w0,[x0,#-1]  (a negative disp: the unscaled lane)
      ("a64.stxb-1" "7000008b00f21f38"  ((stxb r3 r0 1 -1 r0)))       ; add x16,x3,x0 ; sturb w0,[x16,#-1] (gnulib's ((small_t *) p)[-1])
      ("a64.li.big" "a0828fd240e9aff22037cff2e0c6f3f2"               ; movz + 3 movk (bignum-safe lane via //%)
                      ((li r0 0x9e3779b97f4a7c15)))
      ;; the link register (x30) by name -- a callee spills it across nested calls (BL clobbers it).
      ("a64.push.lr" "fe0f1ff8"         ((push lr)))                 ; str x30, [sp,#-16]!
      ("a64.pop.lr"  "fe0741f8"         ((pop lr)))                  ; ldr x30, [sp],#16
      ("a64.grpfn"  "fe0f1ff8040000940000038bfe0741f8c0035fd6e00303aac0035fd6"   ; the nested-call shape: save lr; bl sib; work; restore lr; ret; sib: ...
                      ((push lr) (call sib) (add r0 r0 r3) (pop lr) (ret) (label sib) (mov r0 r3) (ret)))
      ;; sp moves are `lea` (add #0): orr's `mov` reads and writes xzr for 31. the deopt anchor:
      ("a64.anchor"  "f7030091"          ((lea r23 sp 0)))            ; mov x23, sp
      ("a64.abandon" "ff020091"          ((lea sp r23 0)))            ; mov sp, x23
      ;; a whole glaze leaf for (\ x (x + 1)): g/Ip/Hp/Sp in x0..x3, acc x4, temp x5. guard and
      ;; untag Sp[0]; +1 with overflow -> deopt; putfix; store; continue (Ip += 16; br [Ip]); deopt
      ;; tail-applies interp (value[1] at [Ip+8]).
      ("a64.glaze.leaf"
        "640040f99f0040f26001005484fc4193840400b106010054840004abc6000054840040b2640000f921400091250040f9a0001fd6250440f9e10305aa250040f9a0001fd6"
        ((ld r4 r3 0) (test r4 1) (br eq deopt) (sar r4 1) (adds r4 r4 1) (br vs deopt)
          (adds r4 r4 r4) (br vs deopt) (or r4 r4 1) (st r3 0 r4) (add r1 r1 16) (ld r5 r1 0) (jmpr r5)
          (label deopt) (ld r5 r1 8) (mov r1 r5) (ld r5 r1 0) (jmpr r5)))
      ;; scalar double: f0..f15 -> d0..d15, the sse-named two-address ir on a64's scalar-double forms
      ("a64.cvttsd2si" "0400789e"        ((cvttsd2si r4 f0)))           ; fcvtzs x4, d0 (toward zero)
      ("a64.cvtsi2sd" "8000629e"          ((cvtsi2sd f0 r4)))           ; scvtf d0, x4
      ("a64.movqxr"   "8100679e"          ((movqxr f1 r4)))             ; fmov  d1, x4  (gpr bits -> fpr)
      ("a64.movqrx"   "0400669e"          ((movqrx r4 f0)))             ; fmov  x4, d0  (fpr -> gpr bits)
      ("a64.movsd"    "2040601e"          ((movsd f0 f1)))              ; fmov  d0, d1
      ("a64.addsd"    "0028611e"          ((addsd f0 f1)))              ; fadd  d0, d0, d1
      ("a64.subsd"    "2138601e"          ((subsd f1 f0)))              ; fsub  d1, d1, d0
      ("a64.mulsd"    "0008611e"          ((mulsd f0 f1)))              ; fmul  d0, d0, d1
      ("a64.divsd"    "2118601e"          ((divsd f1 f0)))              ; fdiv  d1, d1, d0
      ("a64.ucomisd"  "0020611e"          ((ucomisd f0 f1)))            ; fcmp  d0, d1
      ("a64.stsd"     "400400fd"          ((stsd r2 8 f0)))             ; str   d0, [x2, #8]
      ("a64.ldsd"     "610040fd"          ((ldsd f1 r3 0)))             ; ldr   d1, [x3]
      ("a64.cvtss2sd" "20c0221e"          ((cvtss2sd f0 f1)))           ; fcvt  d0, s1  (single -> double)
      ("a64.cvtsd2ss" "0140621e"          ((cvtsd2ss f1 f0)))           ; fcvt  s1, d0  (double -> single)
      ("a64.stss"     "400800bd"          ((stss r2 8 f0)))             ; str   s0, [x2, #8]
      ("a64.ldss"     "610040bd"          ((ldss f1 r3 0)))             ; ldr   s1, [x3]
      ("a64.addss"    "0028211e"          ((addss f0 f1)))              ; fadd  s0, s0, s1 (the single lane, llvm-mc)
      ("a64.subss"    "0038211e"          ((subss f0 f1)))
      ("a64.mulss"    "0008211e"          ((mulss f0 f1)))
      ("a64.divss"    "0018211e"          ((divss f0 f1)))
      ("a64.cvtsi2ss" "8000229e"          ((cvtsi2ss f0 r4)))           ; scvtf s0, x4
      ("a64.cvttss2si" "0400389e"         ((cvttss2si r4 f0)))          ; fcvtzs x4, s0
      ("a64.movdxr"   "8000271e"          ((movdxr f0 r4)))             ; fmov s0, w4
      ("a64.movdrx"   "0400261e"          ((movdrx r4 f0)))             ; fmov w4, s0
      ("a64.xorpd"    "841c242e"          ((xorpd f4 f4)))              ; eor   v4.8b, v4.8b, v4.8b  (zero a double)
      ;; the sized family, checked vs llvm-objdump
      ("a64.ld1"      "80809f38"          ((ld1 r0 r4 -8)))             ; ldursb x0, [x4, #-8]
      ("a64.ld2"      "e3238079"          ((ld2 r3 sp 16)))             ; ldrsh  x3, [sp, #16]
      ("a64.ld4"      "87c099b8"          ((ld4 r7 r4 -100)))           ; ldursw x7, [x4, #-100]
      ("a64.st1"      "80801f38"          ((st1 r4 -8 r0)))             ; sturb  w0, [x4, #-8]
      ("a64.st2"      "e3230079"          ((st2 sp 16 r3)))             ; strh   w3, [sp, #16]
      ("a64.st4"      "87c019b8"          ((st4 r4 -100 r7)))           ; stur   w7, [x4, #-100]
      ("a64.sx1"      "001c4093"          ((sx1 r0)))                   ; sxtb x0, w0
      ("a64.sx2"      "e73c4093"          ((sx2 r7)))                   ; sxth x7, w7
      ("a64.sx4"      "637c4093"          ((sx4 r3)))                   ; sxtw x3, w3
      ("a64.ldu1"     "80204039"          ((ldu1 r0 r4 8)))             ; ldrb w0, [x4, #8] (zero-extends)
      ("a64.ldu2"     "83204079"          ((ldu2 r3 r4 16)))            ; ldrh w3, [x4, #16]
      ("a64.ldu4"     "870840b9"          ((ldu4 r7 r4 8)))             ; ldr w7, [x4, #8] (zero-extends to x7)
      ("a64.zx1"      "001c40d3"          ((zx1 r0)))                   ; ubfx x0, x0, #0, #8  (uxtb)
      ("a64.zx2"      "633c40d3"          ((zx2 r3)))                   ; ubfx x3, x3, #0, #16 (uxth)
      ("a64.zx4"      "e77c40d3"          ((zx4 r7)))                   ; ubfx x7, x7, #0, #32 (uxtw)
      ("a64.udiv"     "6308c59a"          ((udiv r3 r3 r5)))            ; udiv x3, x3, x5
      ("a64.urem"     "6208c59a438c059b"  ((urem r3 r3 r5 r2)))         ; udiv x2,x3,x5 ; msub x3,x2,x5,x3
      ("a64.shlv"     "0020c19a"          ((shlv r0 r1)))               ; lsl x0, x0, x1
      ("a64.shrv"     "e724c19a"          ((shrv r7 r1)))               ; lsr x7, x7, x1
      ("a64.sarv"     "6328c19a"          ((sarv r3 r1)))               ; asr x3, x3, x1
      ;; lean; the 24-bit add/sub split; the far memory lane (movz x16 + add/sub off the base); fp
      ;; ldur/stur + far (frame slots run negative); f16+; cmp's cmn flip; p/np as vs/vc (fcmp
      ;; parks unordered in v)
      ("a64.lean"     "808000d1"          ((lean r0 r4 -32)))           ; sub x0, x4, #32 (lea's alias)
      ("a64.addi.24"  "2040409100100091"  ((add r0 r1 65540)))          ; add x0,x1,#16,lsl#12 ; add x0,x0,#4
      ("a64.far.ld"   "30b004d1000240f9" ((ld r0 r1 -300)))             ; sub x16, x1, #300 ; ldr x0, [x16]
      ("a64.stur.d"   "40801ffc"          ((stsd r2 -8 f0)))            ; stur d0, [x2, #-8]
      ("a64.ldur.d"   "83005ffc"          ((ldsd f3 r4 -16)))           ; ldur d3, [x4, #-16]
      ("a64.far.fld"  "30b004d1000240fd" ((ldsd f0 r1 -300)))           ; sub x16, x1, #300 ; ldr d0, [x16]
      ("a64.freg.hi"  "500400fd"          ((stsd r2 8 f16)))            ; str d16, [x2, #8] (the narrow scratch)
      ("a64.cmn"      "1f1c00b1"          ((cmp r0 -7)))                ; cmn x0, #7 (negative imm flips)
      ("a64.set.np"   "e0679f9a"          ((set np r0)))                ; cset x0, vc (np aliases vc)
      ("a64.la"       "000000900040009107000090e740009141424300"
                       ((la r0 x) (la r7 x) (label x) (raw (65 66 67 0))))   ; adrp+add pair: x at +16, page delta 0, lo12 16
      ;; the system lane: mrs/msr and the sys family share one encoding; these walk both op0 banks
      ;; (el1 at op1=0, el0 at op1=3) and both l directions
      ("a64.mrs"      "091038d5007438d523003bd5"
                       ((mrs r9 sctlr_el1) (mrs r0 par_el1) (mrs r3 ctr_el0)))
      ("a64.mrs.lr"   "be0038d5"          ((mrs lr mpidr_el1)))         ; mrs x30, mpidr_el1
      ("a64.msr"      "031018d5222018d500c018d5"
                       ((msr sctlr_el1 r3) (msr ttbr1_el1 r2) (msr vbar_el1 r0)))
      ("a64.msr.el0"  "2ee21bd5"          ((msr cntp_ctl_el0 r14)))     ; msr cntp_ctl_el0, x14
      ;; MSR (immediate): a pstate field, the 4-bit immediate in crm -- interrupts off, irq
      ;; back on, and the stack-pointer select.
      ("a64.msri"     "df4f03d5ff4203d5bf4100d5"
                       ((msri daifset 15) (msri daifclr 2) (msri spsel 1)))
      ("a64.barrier"  "9f3b03d59f3f03d5bf3b03d5df3f03d5"
                       ((dsb ish) (dsb sy) (dmb ish) (isb)))
      ;; the sys operations. the whole-system forms take no register -- that operand is `zr`,
      ;; which is Rt = 31 (XZR), exactly what the assembler puts there.
      ("a64.tlbi"     "1f8308d51f8708d5208308d5"
                       ((tlbi vmalle1is zr) (tlbi vmalle1 zr) (tlbi vae1is r0)))
      ("a64.cache"    "1f7508d520750bd5217b0bd5227e0bd5237608d524740bd5"
                       ((ic iallu zr) (ic ivau r0) (dc cvau r1) (dc civac r2) (dc ivac r3) (dc zva r4)))
      ("a64.at"       "217808d5007808d5"  ((at s1e1w r1) (at s1e1r r0)))
      ;; exception generation. `dbrk` is a64's hlt, the debugger halt (hlt #0xf000 is semihosting),
      ;; not x86's `hlt`, which stops the core
      ("a64.exc"      "000020d4409a20d400005ed4020000d4030000d400000000"
                       ((brk 0) (brk 1234) (dbrk 61440) (hvc 0) (smc 0) (udf 0)))
      ("a64.wait"     "7f2003d55f2003d5e0039fd6"  ((wfi) (wfe) (eret)))
      ;; the sp move: orr reads 31 as xzr, so it is `lea .. 0` (add #0), and `mov` scares on sp
      ("a64.sp.read"  "e9030091"          ((lea r9 sp 0)))              ; mov x9, sp
      ("a64.sp.write" "3f010091"          ((lea sp r9 0)))              ; mov sp, x9
      ;; lia: the linked address, as `ldr xd, =sym` assembles it, a literal inline:
      ;;   ldr xd, .+8 ; b .+12 ; .quad <the abs64 placeholder>
      ("a64.lia"      "4900005803000014000000000000000040000058030000140000000000000000"
                                          ((label k) (lia r9 k) (lia r0 k)))
      ;; x16/x17/x18 by name (an irq path saves x0..x18); x16 is also the indexed/far scratch,
      ;; these plain stores are in range
      ("a64.ip.regs"  "f00300f9f10700f9f20b00f9"
                                          ((st sp 0 r16) (st sp 8 r17) (st sp 16 r18)))
      ;; the 128-bit pair kit (hi x2 : lo x0, the left operand at [sp] lo / [sp+8] hi or -- the
      ;; r-twins -- in rl:rh). x16/x17 are the borrowed scratch, as in the far-memory lane.
      ("a64.a128"     "f04740a9000010ab4200119a"  ((a128 sp)))        ; ldp x16,x17,[sp]; adds x0,x0,x16; adc x2,x2,x17
      ("a64.s128"     "f04740a9000200eb220202da"  ((s128 sp)))        ; subs x0,x16,x0; sbc x2,x17,x2
      ("a64.mw128"    "f00340f9027cd09b007c109b"  ((mw128 sp)))       ; ldr x16,[sp]; umulh x2,x0,x16; mul x0,x0,x16
      ("a64.m128"     "f04740a9317e009b1146029b027ec09b4200118b007e009b" ((m128 sp)))
      ("a64.c128.eq"  "f04740a9100200ca310202ca100211aa1f0200f1e0179f9a" ((c128 eq sp)))
      ("a64.c128.below" "f04740a91f0200eb3f0202fae0279f9a" ((c128 below sp)))   ; cmp x16,x0; sbcs xzr,x17,x2; cset x0,lo
      ("a64.c128.gt"  "f04740a91f0010eb5f0011fae0a79f9a" ((c128 gt sp)))        ; the reversed subtraction, read as lt
      ;; the divide pair: udiv/msub on the high half, then 64 restoring steps for the low
      ("a64.dv128"    "f04740a9220ac09a51c4009be20300f9010880d23f0241f231fed09310fa7fd3220240fa220200cb5120919a1036909a210400f101ffff54e00310aae20340f9" ((dv128 sp)))
      ("a64.rm128"    "f04740a9220ac09a51c4009be20300f9010880d23f0241f231fed09310fa7fd3220240fa220200cb5120919a1036909a210400f101ffff54e00311aae2031faa" ((rm128 sp)))
      ("a64.a128r"    "000007ab4200089a"  ((a128r r7 r8)))            ; adds x0,x0,x7; adc x2,x2,x8
      ("a64.s128r"    "e00000eb020102da"  ((s128r r7 r8)))            ; subs x0,x7,x0; sbc x2,x8,x2 -- no dance through the pair
      ("a64.mw128r"   "027cc79b007c079b"  ((mw128r r7)))              ; umulh x2,x0,x7; mul x0,x0,x7
      ("a64.m128r"    "107d009bf040029be27cc09b4200108be07c009b" ((m128r r7 r8)))
      ("a64.c128r.eq" "f00000ca110102ca100211aa1f0200f1e0179f9a" ((c128r eq r7 r8)))
      ("a64.c128r.lt" "ff0000eb1f0102fae0a79f9a" ((c128r lt r7 r8)))
      ("a64.c128r.gt" "1f0007eb5f0008fae0a79f9a" ((c128r gt r7 r8)))
      ("a64.sx128"    "02fc7f93"          ((sx128)))                  ; asr x2, x0, #63
      ("a64.n128"     "e00300ebe20302da"  ((n128)))                   ; negs x0,x0; ngc x2,x2
      ("a64.inc128"   "000400b142001f9a"  ((inc128)))                 ; adds x0,x0,#1; adc x2,x2,xzr
      ("a64.dec128"   "000400f142001fda"  ((dec128)))                 ; subs x0,x0,#1; sbc x2,x2,xzr
      ("a64.shl128.5" "42ecc09300e87bd3"  ((shl128 5)))               ; extr x2,x2,x0,#59; lsl x0,x0,#5
      ("a64.shl128.64" "02fc40d3e0031faa" ((shl128 64)))              ; the halves move (a shift by 0); x0 = 0
      ("a64.shl128.100" "026c5cd3e0031faa" ((shl128 100)))            ; lsl x2,x0,#36; x0 = 0
      ("a64.shr128.5" "4014c09342fc45d3"  ((shr128 5)))               ; extr x0,x2,x0,#5; lsr x2,x2,#5
      ("a64.shr128.64" "40fc40d3e2031faa" ((shr128 64)))
      ("a64.sar128.100" "40fc649342fc7f93" ((sar128 100)))            ; asr x0,x2,#36; the sign floods x2
      ;; the v-forms: both bands compute (a variable shift reads its count MOD 64) and csel picks
      ("a64.shl128v"  "f00301cb1024d09a5120c19a310210aa3f0000f15100919a300001d11020d09a3f0001f10222919a0020c19ae023809a" ((shl128v)))
      ("a64.shr128v"  "f00301cb5020d09a1124c19a310210aa3f0000f11100919a300001d15024d09a3f0001f10022919a4224c19ae223829a" ((shr128v)))
      ("a64.sar128v"  "f00301cb5020d09a1124c19a310210aa3f0000f11100919a300001d15028d09a3f0001f10022919a51fc7f934228c19a2222829a" ((sar128v))))
   _ (foldl (_ \ t \ chk2 (t 0) (t 1) 'a64 (t 2)) 0 a64tests)

   ;; -- the thumb2 backend: armv7e-m, mixed 16/32-bit little-endian, a 32-bit word laid hi-halfword
   ;; first. goldens from llvm-mc --triple=thumbv7em-none-eabi; the branch scrambling (s/j1/j2/i1/i2)
   ;; checked over spans across the imm11 boundary. --
   t2tests '(
      ("t2.li"      "40f20500"          ((li r0 5)))                  ; movw r0, #5
      ("t2.movt"    "45f27861c1f23421"  ((li r1 305419896)))          ; 0x12345678: movw + movt
      ("t2.li.neg"  "4ff6ff72cff6ff72"  ((li r2 -1)))                 ; movw #0xffff ; movt #0xffff
      ("t2.mov"     "4fea0300"          ((mov r0 r3)))                ; mov.w r0, r3
      ;; ..but mov.w is orr with rn=15 and cannot name sp or pc, so those take the 16-bit hi-register
      ;; t1. unpredictable is not a fault: a wrong encoding here can run green on a board.
      ("t2.movfromsp" "6846"            ((mov r0 sp)))                ; mov r0, sp
      ("t2.movtosp"   "8d46"            ((mov sp r1)))                ; mov sp, r1
      ("t2.add"     "01eb0200"          ((add r0 r1 r2)))             ; add.w r0, r1, r2
      ("t2.sub"     "a5eb0604"          ((sub r4 r5 r6)))             ; sub.w r4, r5, r6
      ("t2.and"     "01ea0200"          ((and r0 r1 r2)))             ; and.w r0, r1, r2
      ("t2.or"      "41ea0200"          ((or  r0 r1 r2)))             ; orr.w r0, r1, r2
      ("t2.xor"     "88ea0907"          ((xor r7 r8 r9)))             ; eor.w r7, r8, r9
      ("t2.addi"    "01f26400"          ((add r0 r1 100)))            ; addw r0, r1, #100
      ("t2.subi"    "a1f26400"          ((sub r0 r1 100)))            ; subw r0, r1, #100
      ("t2.addneg"  "a1f20800"          ((add r0 r1 -8)))             ; negative imm flips add->subw
      ("t2.cmp"     "b0eb010f"          ((cmp r0 r1)))                ; cmp.w r0, r1
      ("t2.cmpi"    "b0f12a0f"          ((cmp r0 42)))                ; cmp.w r0, #42
      ("t2.mul"     "01fb02f0"          ((imul r0 r1 r2)))            ; mul r0, r1, r2
      ("t2.ldr"     "d1f80800"          ((ld r0 r1 8)))               ; ldr.w r0, [r1, #8]
      ("t2.str"     "c1f80800"          ((st r1 8 r0)))               ; str.w r0, [r1, #8]
      ("t2.ldr.neg" "51f8040c"          ((ld r0 r1 -4)))             ; ldr r0, [r1, #-4] (T4)
      ("t2.ld1"     "91f90300"          ((ld1 r0 r1 3)))              ; ldrsb.w r0, [r1, #3]
      ("t2.st1"     "81f80300"          ((st1 r1 3 r0)))              ; strb.w r0, [r1, #3]
      ("t2.lea"     "01f20800"          ((lea r0 r1 8)))              ; addw r0, r1, #8
      ("t2.lea.mov" "dd46"              ((lea sp fp 0)))              ; mov sp, r11 -- lea #0 to sp rides the sp-legal 16-bit mov
      ("t2.push"    "4df8044d"          ((push r4)))                  ; str r4, [sp, #-4]!
      ("t2.pop"     "5df8044b"          ((pop r4)))                   ; ldr r4, [sp], #4
      ("t2.sx1"     "4ffa80f0"          ((sx1 r0)))                   ; sxtb.w r0, r0
      ("t2.sx2"     "0ffa83f3"          ((sx2 r3)))                   ; sxth.w r3, r3
      ("t2.zx1"     "5ffa80f0"          ((zx1 r0)))                   ; uxtb.w r0, r0
      ("t2.zx2"     "1ffa87f7"          ((zx2 r7)))                   ; uxth.w r7, r7
      ("t2.sx4"     ""                  ((sx4 r0)))                   ; no-op: an int is already the full 32-bit word
      ("t2.neg"     "c0f10000"          ((neg r0)))                   ; rsb.w r0, r0, #0
      ("t2.not"     "6fea0000"          ((not r0)))                   ; mvn.w r0, r0
      ("t2.inc"     "00f20100"          ((inc r0)))                   ; addw r0, r0, #1
      ("t2.dec"     "a0f20100"          ((dec r0)))                   ; subw r0, r0, #1
      ("t2.shl"     "4feac000"          ((shl r0 3)))                 ; lsl.w r0, r0, #3
      ("t2.shr"     "4fead000"          ((shr r0 3)))                 ; lsr.w r0, r0, #3
      ("t2.sar"     "4feae000"          ((sar r0 3)))                 ; asr.w r0, r0, #3
      ("t2.shlv"    "00fa01f0"          ((shlv r0 r1)))               ; lsl.w r0, r0, r1 (count in r1)
      ("t2.sdiv"    "91fbf2f0"          ((div r0 r1 r2)))             ; sdiv r0, r1, r2
      ("t2.udiv"    "b1fbf2f0"          ((udiv r0 r1 r2)))            ; udiv r0, r1, r2
      ("t2.test"    "10ea010f"          ((test r0 r1)))               ; tst.w r0, r1
      ("t2.jmpr"    "1847"              ((jmpr r3)))                  ; bx r3
      ("t2.callr"   "9847"              ((callr r3)))                 ; blx r3
      ("t2.ret"     "7047"              ((ret)))                      ; bx lr
      ("t2.sys"     "00df"              ((sys)))                      ; svc #0
      ("t2.nop"     "00bf"              ((nop)))                      ; nop
      ("t2.set"     "40f2000008bf40f20100" ((set eq r0)))             ; movw r0,#0 ; it eq ; movweq r0,#1
      ;; branches: t4 (jmp), t3 conditional (br), t1 (call). the pc-relative offset is a bitfield
      ;; scrambled across S/j1/j2 -- the fixup lays the whole 32-bit word in `patch`.
      ("t2.jmp.fwd" "00f001b800bf" ((jmp l) (nop) (label l)))         ; b.w  -> +2 (past the nop)
      ("t2.jmp.bwd" "00bffff7fdbf" ((label l) (nop) (jmp l)))         ; b.w  -> -6 (back to l)
      ("t2.br.fwd"  "00f0018000bf" ((br eq l) (nop) (label l)))       ; beq.w -> +2
      ("t2.call.fwd" "00f001f800bf" ((call l) (nop) (label l)))       ; bl    -> +2
      ;; a whole trivial leaf end to end: r0 = r0 + r1 ; return.
      ("t2.leaf"    "00eb01007047" ((add r0 r0 r1) (ret)))            ; add.w r0,r0,r1 ; bx lr
      ;; a counted loop (the small-loop battery): the forward beq reaches `done`, the backward bne
      ;; reaches `top`, both fixed 32-bit t3 landing byte-exact on their labels.
      ("t2.loop"    "01eb0000b0eb020f00f0068001f20101b1eb020f7ff4f6af7047"
                     ((add r0 r1 r0) (label top) (cmp r0 r2) (br eq done)
                       (add r1 r1 1) (cmp r1 r2) (br ne top) (label done) (ret)))
      ;; la: the MOVW/MOVT absolute pair (movw16/movt16 fixups, always both) -- x at +16, so
      ;; movw #16 ; movt #0, twice (r0 then r7). the thumb2 answer to a64's adrp+add.
      ("t2.la"      "40f21000c0f2000040f21007c0f2000741424300"
                     ((la r0 x) (la r7 x) (label x) (raw (65 66 67 0))))
      ;; the 64-bit pair lanes: the carry alu family, the widening multiplies, clz, and a variable
      ;; shift whose count is not r1
      ("t2.adc"     "43eb0101"          ((adc r1 r3 r1)))             ; adc.w r1, r3, r1
      ("t2.adcs"    "53eb0303"          ((adcs r3 r3 r3)))            ; adcs.w r3, r3, r3
      ("t2.sbc"     "63eb0101"          ((sbc r1 r3 r1)))             ; sbc.w r1, r3, r1
      ("t2.sbcs"    "75eb0107"          ((sbcs r7 r5 r1)))            ; sbcs.w r7, r5, r1
      ("t2.ors"     "5cea020c"          ((ors r12 r12 r2)))           ; orrs.w r12, r12, r2
      ("t2.umull"   "a2fb000c"          ((umull r0 r12 r2 r0)))       ; umull r0, r12, r2, r0
      ("t2.mla"     "02fb0133"          ((mla r3 r2 r1 r3)))          ; mla r3, r2, r1, r3
      ("t2.clz"     "b1fa81f0"          ((clz r0 r1)))                ; clz r0, r1
      ("t2.shlv.r2" "01fa02f1"          ((shlv r1 r2)))               ; lsl.w r1, r1, r2
      ;; indexed addressing: add.W shifted (leax), LDR/LDRB register-offset (ldx/ldxb at disp 0),
      ;; and the disp!=0 synthesis off the dest.
      ("t2.leax"    "01eb8200"          ((leax r0 r1 r2 4 0)))        ; add.w r0, r1, r2, lsl #2
      ("t2.leax.d"  "04ebcc0909f20409"  ((leax r9 r4 r12 8 4)))       ; add.w r9,r4,r12,lsl#3 ; addw r9,r9,#4
      ("t2.ldx"     "51f82200"          ((ldx r0 r1 r2 4 0)))         ; ldr.w r0, [r1, r2, lsl #2]
      ("t2.ldxb"    "11f80250"          ((ldxb r5 r1 r2 1 0)))        ; ldrb.w r5, [r1, r2]
      ("t2.ldx.d"   "00eb0300d0f80400"  ((ldx r0 r0 r3 1 4)))         ; disp!=0: add.w r0,r0,r3 ; ldr.w r0,[r0,#4]
      ;; the scalar-double vfp lane: f0..f15 -> d0..d15, s[2n] the single views; movqxr/movqrx move
      ;; a gp pair (named reg lo, +1 hi). llvm-mc (eabihf, +vfp4d16).
      ("t2.addsd"   "30ee010b"          ((addsd f0 f1)))              ; vadd.f64 d0, d0, d1
      ("t2.subsd"   "32ee432b"          ((subsd f2 f3)))              ; vsub.f64 d2, d2, d3
      ("t2.mulsd"   "20ee010b"          ((mulsd f0 f1)))              ; vmul.f64 d0, d0, d1
      ("t2.divsd"   "80ee010b"          ((divsd f0 f1)))              ; vdiv.f64 d0, d0, d1
      ("t2.movsd"   "b0ee443b"          ((movsd f3 f4)))              ; vmov.f64 d3, d4
      ("t2.ucomisd" "b4ee410bf1ee10fa"  ((ucomisd f0 f1)))            ; vcmp.f64 ; vmrs apsr_nzcv
      ("t2.cvtsi2sd" "02ee100ab8eec22b" ((cvtsi2sd f2 r0)))           ; vmov s4, r0 ; vcvt.f64.s32 d2, s4
      ("t2.cvtui2sd" "02ee100ab8ee422b" ((cvtui2sd f2 r0)))           ; vmov s4, r0 ; vcvt.f64.u32 d2, s4
      ("t2.cvttsd2si" "bdeec1fb1fee100a" ((cvttsd2si r0 f1)))         ; vcvt.s32.f64 s30, d1 ; vmov r0, s30
      ("t2.cvttsd2ui" "bceec1fb1fee100a" ((cvttsd2ui r0 f1)))         ; vcvt.u32.f64 s30, d1 ; vmov r0, s30
      ("t2.movqxr"  "41ec150b"          ((movqxr f5 r0)))             ; vmov d5, r0, r1 (the pair in)
      ("t2.movqrx"  "53ec152b"          ((movqrx r2 f5)))             ; vmov r2, r3, d5 (the pair out)
      ("t2.ldsd"    "94ed021b"          ((ldsd f1 r4 8)))             ; vldr d1, [r4, #8]
      ("t2.ldsd.n"  "14ed041b"          ((ldsd f1 r4 -16)))           ; vldr d1, [r4, #-16]
      ("t2.stsd"    "80ed002b"          ((stsd r0 0 f2)))             ; vstr d2, [r0]
      ("t2.ldss"    "94ed011a"          ((ldss f1 r4 4)))             ; vldr s2, [r4, #4]
      ("t2.addss"   "30ee010a"          ((addss f0 f1)))              ; vadd.f32 s0, s0, s2 (llvm-mc)
      ("t2.subss"   "30ee410a"          ((subss f0 f1)))
      ("t2.mulss"   "20ee010a"          ((mulss f0 f1)))
      ("t2.divss"   "80ee010a"          ((divss f0 f1)))
      ("t2.cvtsi2ss" "00ee103ab8eec00a" ((cvtsi2ss f0 r3)))          ; vmov s0, r3 ; vcvt.f32.s32 s0, s0
      ("t2.cvttss2si" "bdeec0fa1fee103a" ((cvttss2si r3 f0)))        ; vcvt.s32.f32 s30, s0 ; vmov r3, s30
      ("t2.movdxr"  "00ee103a"          ((movdxr f0 r3)))             ; vmov s0, r3
      ("t2.movdrx"  "10ee103a"          ((movdrx r3 f0)))             ; vmov r3, s0
      ("t2.stss"    "04ed021a"          ((stss r4 -8 f1)))            ; vstr s2, [r4, #-8]
      ("t2.cvtss2sd" "b7eec11a"         ((cvtss2sd f1 f1)))           ; vcvt.f64.f32 d1, s2
      ("t2.cvtsd2ss" "b7eec11b"         ((cvtsd2ss f1 f1)))           ; vcvt.f32.f64 s2, d1
      ("t2.smull"   "80fb0102"          ((smull r0 r2 r0 r1)))        ; smull r0, r2, r0, r1
      ;; the system lane. m-profile has one shareability domain, so `sy` is the only barrier option
      ("t2.dsb"     "bff34f8f"          ((dsb sy)))                   ; dsb sy
      ("t2.isb"     "bff36f8f"          ((isb)))                      ; isb sy
      ("t2.brk"     "abbe"              ((brk 171)))                  ; bkpt 0xab -- the semihosting call
      ("t2.trap"    "00be"              ((trap)))                     ; ..the same instruction at 0
      ("t2.wfi"     "30bf"              ((wfi)))                      ; wfi
      ;; MRS: the two stack pointers, which a fault handler asks after to find the frame.
      ("t2.mrsmsp"  "eff30880"          ((mrs r0 msp)))               ; mrs r0, msp
      ("t2.mrspsp"  "eff30983"          ((mrs r3 psp)))               ; mrs r3, psp
      ;; the 64-bit unsigned divide/remainder: r2:r3 / r0:r1 -> r0:r1, a 64-step restoring loop,
      ;; fixed narrow branches (bhs +8 / blo +10 / bne -52), r4-r7 saved
      ("t2.udivll"  "4df8044d4df8045d4df8046d4df8047d40f2000440f2000540f2400612eb020253eb030354eb040455eb050504d2b4eb000775eb010705d3b4eb000475eb010502f20102a6f20106b6f1000fe6d1104619465df8047b5df8046b5df8045b5df8044b"
                     ((udivll)))
      ("t2.uremll"  "4df8044d4df8045d4df8046d4df8047d40f2000440f2000540f2400612eb020253eb030354eb040455eb050504d2b4eb000775eb010705d3b4eb000475eb010502f20102a6f20106b6f1000fe6d1204629465df8047b5df8046b5df8045b5df8044b"
                     ((uremll))))
   _ (foldl (_ \ t \ chk2 (t 0) (t 1) 'thumb2 (t 2)) 0 t2tests)

   ;; -- the thumb1 backend: armv6-m. 16-bit thumb-1, two-address, low registers, no movw/movt (`li`
   ;; byte-builds), no wide alu, no it (`set` branches over), no divide. goldens from llvm-mc
   ;; --triple=thumbv6m-none-eabi; the halfword-scaled offset checked forward and backward. --
   t1tests '(
      ("t1.li"      "0520"              ((li r0 5)))                  ; movs r0, #5
      ("t1.li.neg1" "0020c043"          ((li r0 -1)))                 ; movs r0,#0 ; mvns r0,r0
      ("t1.li.negN" "ff22d243"          ((li r2 -256)))               ; movs r2,#255 ; mvns r2,r2 (~255)
      ("t1.li.big"  "1221090234310902563109027831" ((li r1 305419896)))   ; 0x12345678 byte-build (no litpool)
      ("t1.mov"     "1846"              ((mov r0 r3)))                ; mov r0, r3 (hi-form)
      ("t1.add"     "8818"              ((add r0 r1 r2)))             ; adds r0, r1, r2 (3-addr)
      ("t1.sub"     "ac1b"              ((sub r4 r5 r6)))             ; subs r4, r5, r6
      ("t1.addi3"   "481d"              ((add r0 r1 5)))              ; adds r0, r1, #5 (imm3, 3-addr)
      ("t1.addi8"   "6430"              ((add r0 r0 100)))            ; adds r0, #100 (imm8, 2-addr)
      ("t1.subneg"  "0838"              ((add r0 r0 -8)))             ; negative imm flips add->subs #8
      ("t1.and"     "1040"              ((and r0 r0 r2)))             ; ands r0, r2 (2-addr)
      ("t1.or"      "1143"              ((or  r1 r1 r2)))             ; orrs r1, r2
      ("t1.xor"     "6340"              ((xor r3 r3 r4)))             ; eors r3, r4
      ("t1.mul"     "5043"              ((imul r0 r0 r2)))            ; muls r0, r2
      ("t1.cmp"     "8842"              ((cmp r0 r1)))                ; cmp r0, r1
      ("t1.cmpi"    "2a28"              ((cmp r0 42)))                ; cmp r0, #42
      ("t1.test"    "0842"              ((test r0 r1)))               ; tst r0, r1
      ("t1.ld"      "8868"              ((ld r0 r1 8)))               ; ldr r0, [r1, #8]
      ("t1.st"      "8860"              ((st r1 8 r0)))               ; str r0, [r1, #8]
      ("t1.ldsp"    "0498"              ((ld r0 sp 16)))              ; ldr r0, [sp, #16] (T2)
      ("t1.ldb"     "c878"              ((ldu1 r0 r1 3)))             ; ldrb r0, [r1, #3]
      ("t1.ldh"     "8888"              ((ldu2 r0 r1 4)))             ; ldrh r0, [r1, #4]
      ("t1.ld1"     "c87840b2"          ((ld1 r0 r1 3)))              ; ldrb + sxtb (no signed-imm load on v6-M)
      ("t1.ld2"     "888800b2"          ((ld2 r0 r1 4)))              ; ldrh + sxth
      ("t1.stb"     "c870"              ((st1 r1 3 r0)))              ; strb r0, [r1, #3]
      ("t1.sx1"     "40b2"              ((sx1 r0)))                   ; sxtb r0, r0
      ("t1.sx2"     "1bb2"              ((sx2 r3)))                   ; sxth r3, r3
      ("t1.zx1"     "c0b2"              ((zx1 r0)))                   ; uxtb r0, r0
      ("t1.zx2"     "bfb2"              ((zx2 r7)))                   ; uxth r7, r7
      ("t1.sx4"     ""                  ((sx4 r0)))                   ; no-op: an int is already the full word
      ("t1.neg"     "4042"              ((neg r0)))                   ; rsbs r0, r0, #0
      ("t1.not"     "c043"              ((not r0)))                   ; mvns r0, r0
      ("t1.inc"     "401c"              ((inc r0)))                   ; adds r0, r0, #1
      ("t1.dec"     "401e"              ((dec r0)))                   ; subs r0, r0, #1
      ("t1.shl"     "c000"              ((shl r0 3)))                 ; lsls r0, r0, #3
      ("t1.shr"     "c008"              ((shr r0 3)))                 ; lsrs r0, r0, #3
      ("t1.sar"     "c010"              ((sar r0 3)))                 ; asrs r0, r0, #3
      ("t1.shlv"    "8840"              ((shlv r0 r1)))               ; lsls r0, r0, r1 (count in r1)
      ("t1.shrv"    "c840"              ((shrv r0 r1)))               ; lsrs r0, r0, r1
      ("t1.sarv"    "0841"              ((sarv r0 r1)))               ; asrs r0, r0, r1
      ("t1.shrv.r2" "d040"              ((shrv r0 r2)))               ; lsrs r0, r0, r2 (any low count reg)
      ;; the carry family (the pair kit): adcs commutes on d==b; sbcs d==b borrows a saved scratch
      ;; (push/pop/hi-MOV never touch the carry). the f4 logicals commute on d==b the same way.
      ("t1.adc"     "5941"              ((adc r1 r3 r1)))             ; adcs r1, r3 (d==b commutes)
      ("t1.sbc"     "1a468a41"          ((sbc r2 r3 r1)))             ; mov r2,r3 ; sbcs r2,r1
      ("t1.sbc.db"  "01b408461946814101bc" ((sbc r1 r3 r1)))          ; push{r0};mov r0,r1;mov r1,r3;sbcs r1,r0;pop{r0}
      ("t1.ors"     "0843"              ((ors r0 r0 r1)))             ; orrs r0, r1
      ("t1.and.db"  "1040"              ((and r0 r2 r0)))             ; ands r0, r2 (d==b commutes)
      ("t1.lea0"    "bd46"              ((lea sp fp 0)))              ; mov sp, r7 (fp=r7 on v6-M; lea #0 rides the sp-legal MOV)
      ("t1.leasp"   "04a8"              ((lea r0 sp 16)))             ; add r0, sp, #16
      ("t1.leaa3"   "081d"              ((lea r0 r1 4)))              ; adds r0, r1, #4
      ("t1.allocsp" "84b0"              ((lea sp sp -16)))            ; sub sp, sp, #16 (frame alloc)
      ;; indexed address (leax) + the fused indexed loads (ldx/ldxb). scale>1 shifts index; scale 1 is a
      ;; bare ADDS. the dest may alias base or index -- d==base with scale>1 borrows a saved low temp (r2).
      ("t1.leax"    "90000818"          ((leax r0 r1 r2 4 0)))        ; lsls r0,r2,#2 ; adds r0,r1,r0
      ("t1.leax.s1" "6319"              ((leax r3 r4 r5 1 0)))        ; scale 1: adds r3,r4,r5 outright
      ("t1.leax.base" "04b48a00801804bc" ((leax r0 r0 r1 4 0)))      ; d==base: push r2;lsls r2,r1,#2;adds r0,r0,r2;pop r2
      ("t1.leax.disp" "900008180830"    ((leax r0 r1 r2 4 8)))        ; ... ; adds r0,#8 (trailing disp)
      ("t1.ldx"     "900008180068"      ((ldx r0 r1 r2 4 0)))         ; addr synth ; ldr r0,[r0]
      ("t1.ldxb"    "88180078"          ((ldxb r0 r1 r2 1 0)))        ; adds r0,r1,r2 ; ldrb r0,[r0]
      ("t1.push"    "10b4"              ((push r4)))                  ; push {r4}
      ("t1.pushlr"  "00b5"              ((push lr)))                  ; push {lr}
      ("t1.pop"     "10bc"              ((pop r4)))                   ; pop {r4}
      ("t1.poppc"   "00bd"              ((pop pc)))                   ; pop {pc}
      ("t1.set"     "01d0002000e00120"  ((set eq r0)))               ; beq .one ; movs r0,#0 ; b .end ; .one: movs r0,#1 (branch FIRST: movs sets N/Z on v6-M)
      ;; the far/hi memory lane: out-of-reach imm5 offsets and hi registers synthesize the address.
      ("t1.ld.far"  "802008440068"      ((ld r0 r1 128)))            ; movs r0,#128 ; add r0,r1 ; ldr r0,[r0]
      ("t1.ld.hi"   "01b4082020440068844601bc" ((ld r12 r4 8)))      ; push{r0};movs r0,#8;add r0,r4;ldr r0,[r0];mov r12,r0;pop{r0}
      ("t1.st.far"  "04b4c8220a44106004bc" ((st r1 200 r0)))          ; push{r2};movs r2,#200;add r2,r1;str r0,[r2];pop{r2}
      ("t1.jmpr"    "1847"              ((jmpr r3)))                  ; bx r3
      ("t1.callr"   "9847"              ((callr r3)))                 ; blx r3
      ("t1.ret"     "7047"              ((ret)))                      ; bx lr
      ("t1.sys"     "00df"              ((sys)))                      ; svc #0
      ("t1.nop"     "00bf"              ((nop)))                      ; nop
      ("t1.trap"    "00be"              ((trap)))                     ; bkpt #0
      ;; branches: every label branch is wide (BL, +-16MB; lr is dead mid-frame) -- the short
      ;; B/Bcc can't cross a big function. br = the inverted-Bcc hop over the bl.
      ("t1.jmp.fwd" "00f001f800bf"      ((jmp l) (nop) (label l)))    ; bl .+2 -> past the nop
      ("t1.jmp.bwd" "00bffff7fdff"      ((label l) (nop) (jmp l)))    ; bl .-6 -> back to l
      ("t1.br.fwd"  "01d100f001f800bf"  ((br eq l) (nop) (label l)))  ; bne .+4 (hop) ; bl l
      ("t1.br.bwd"  "00bf01d0fff7fcff"  ((label l) (nop) (br ne l)))  ; beq .+4 (hop) ; bl l
      ("t1.call.fwd" "00f001f800bf"     ((call l) (nop) (label l)))   ; bl #2
      ;; a whole trivial leaf end to end: r0 = r0 + r1 ; return.
      ("t1.leaf"    "40187047"          ((add r0 r0 r1) (ret)))       ; adds r0,r0,r1 ; bx lr
      ;; div/rem: no hardware divide, so the inline restoring shift-subtract (t1-udivmod), and for the
      ;; signed pair the abs-and-refix sleeve; fixed self-contained branches (blo/bne)
      ("t1.udiv" "0022202349005241824201d3121a491c5b1ef7d1"
                 ((udiv r1 r1 r0)))                                   ; the 32-step unsigned core
      ("t1.urem" "0022202349005241824201d3121a491c5b1ef7d11100"
                 ((urem r1 r1 r0 r3)))                                ; core ; movs r1,r2 (remainder)
      ("t1.div"  "ca17c3175140891a5840c01a5a4004b40022202349005241824201d3121a491c5b1ef7d108bc5940c91a"
                 ((div r1 r1 r0)))                                    ; |a|,|b| ; qsign=sa^sb ; core ; refix
      ("t1.rem"  "ca17c3175140891a5840c01a04b40022202349005241824201d3121a491c5b1ef7d108bc11005940c91a"
                 ((rem r1 r1 r0 r3))))                                ; |a|,|b| ; core ; sign=sa ; refix
   _ (foldl (_ \ t \ chk2 (t 0) (t 1) 'thumb1 (t 2)) 0 t1tests)

   ;; -- the riscv backend: rv64imfd, three-address, no flags register: cmp/test/ucomisd emit
   ;; nothing (or an immediate into x30) and br/set fuse them into beq/blt/slt/feq, so flag goldens
   ;; pair the compare with its consumer. label branches are wide; call/la are the auipc pair.
   ;; the rows are compressed (rvc taken wherever it fits), so decoding needs +c, and the trailing
   ;; text is the disassembler's alias. goldens from llvm-mc --triple=riscv64 --mattr=+m,+f,+d,+c,
   ;; each read back by riscv64 objdump too: a torn instruction desyncs a stream, it does not fail. --
   rvtests '(
      ;; immediates: addi / lui+addiw (the 32-bit wraparound pair) / the shift-add chunk chain
      ("rv.li"       "1305c003"          ((li r0 60)))                 ; li a0, 60
      ("rv.li.neg1"  "7d55"              ((li r0 -1)))                 ; li a0, -1
      ("rv.li.t"     "9302c003"          ((li r8 60)))                 ; li t0, 60
      ("rv.li.32"    "375534121b058567"  ((li r0 305419896)))          ; lui a0,74565 ; addiw a0,a0,1656
      ("rv.li.edge"  "370500807d35"      ((li r0 2147483647)))         ; lui a0,524288 ; addiw a0,a0,-1 (the wraparound)
      ("rv.li.big"   "3775e3f91b05c57932051305f59732051305854a3205130555c1"
                      ((li r0 11400714819323198485)))                  ; the hash mult, bignum-safe: lui+addiw+3x(slli 12; addi)
      ("rv.mov"      "3685"              ((mov r0 r3)))                ; mv a0, a3
      ("rv.mov.sp"   "0a84"              ((mov fp sp)))                ; mv s0, sp
      ;; ALU: native three-address; immediates ride addi/andi/ori/xori, else materialize in x31
      ("rv.add"      "3385c500"          ((add r0 r1 r2)))             ; add a0, a1, a2
      ("rv.sub"      "33870741"          ((sub r4 r5 r6)))             ; sub a4, a5, a6
      ("rv.and"      "33f5c500"          ((and r0 r1 r2)))             ; and a0, a1, a2
      ("rv.or"       "b3e86200"          ((or r7 r8 r9)))              ; or a7, t0, t1
      ("rv.xor"      "33c99900"          ((xor r13 r14 r15)))          ; xor s2, s3, s1 (the callee-saved homes)
      ("rv.mul"      "3385c502"          ((imul r0 r1 r2)))            ; mul a0, a1, a2
      ("rv.addi"     "13854506"          ((add r0 r1 100)))            ; addi a0, a1, 100
      ("rv.subi"     "1385c5f9"          ((sub r0 r1 100)))            ; addi a0, a1, -100 (sub flips)
      ("rv.andi"     "1d89"              ((and r0 r0 7)))              ; andi a0, a0, 7
      ("rv.addi.big" "b70f0100912f3385f501"     ((add r0 r1 65540)))   ; lui t6,16 ; addiw t6,t6,4 ; add a0,a1,t6
      ("rv.neg"      "3305a040"          ((neg r0)))                   ; neg a0 (sub a0, x0, a0)
      ("rv.not"      "93c6f6ff"          ((not r3)))                   ; not a3 (xori -1)
      ;; shifts and rotates (no rotate in the base ISA: srli/slli/or through x31)
      ("rv.shl"      "0e05"              ((shl r0 3)))                 ; slli a0, a0, 3
      ("rv.sar"      "8586"              ((sar r3 1)))                 ; srai a3, a3, 1 (the tag math)
      ("rv.rol"      "935f050202153365f501"     ((rol r0 32)))         ; srli t6,a0,32 ; slli a0,a0,32 ; or (the map hash)
      ("rv.shlv"     "3315b500"          ((shlv r0 r1)))               ; sll a0, a0, a1 (count pinned to r1)
      ("rv.sarv"     "b3d6b640"          ((sarv r3 r1)))               ; sra a3, a3, a1
      ;; memory: 12-bit offsets ride the instruction; a far one builds base+hi in x31
      ("rv.ld"       "03358800"          ((ld r0 r6 8)))               ; ld a0, 8(a6)
      ("rv.st"       "88e5"              ((st r1 8 r0)))               ; sd a0, 8(a1)
      ("rv.ld.neg"   "03b545ed"          ((ld r0 r1 -300)))            ; ld a0, -300(a1)
      ("rv.ld.far"   "b7ef0100ae9f03b50f24"     ((ld r0 r1 123456)))   ; lui t6,30 ; add t6,t6,a1 ; ld a0,576(t6)
      ("rv.ld1"      "030587ff"          ((ld1 r0 r4 -8)))             ; lb a0, -8(a4) (sign-extends)
      ("rv.ld2"      "83160101"          ((ld2 r3 sp 16)))             ; lh a3, 16(sp)
      ("rv.ld4"      "8328c7f9"          ((ld4 r7 r4 -100)))           ; lw a7, -100(a4)
      ("rv.ldu1"     "03458700"          ((ldu1 r0 r4 8)))             ; lbu a0, 8(a4) (zero-extends)
      ("rv.ldu4"     "83688700"          ((ldu4 r7 r4 8)))             ; lwu a7, 8(a4)
      ("rv.st1"      "230ca7fe"          ((st1 r4 -8 r0)))             ; sb a0, -8(a4)
      ("rv.st4"      "232e17f9"          ((st4 r4 -100 r7)))           ; sw a7, -100(a4)
      ("rv.sx1"      "62156195"          ((sx1 r0)))                   ; slli a0,a0,56 ; srai a0,a0,56
      ("rv.sx4"      "8126"              ((sx4 r3)))                   ; sext.w a3 (one addiw)
      ("rv.zx1"      "1375f50f"          ((zx1 r0)))                   ; andi a0, a0, 255
      ("rv.zx4"      "821893d80802"      ((zx4 r7)))                   ; slli a7,a7,32 ; srli a7,a7,32
      ;; indexed addressing: synthesized through x31 (ldx borrows d, stx borrows x30 far)
      ("rv.ldx"      "931f3500c69f03b58f00"     ((ldx r0 r7 r0 8 8)))  ; slli t6,a0,3 ; add t6,t6,a7 ; ld a0,8(t6)
      ("rv.stx"      "931f3500c69f23b45f00"     ((stx r7 r0 8 8 r8)))  ; slli ; add ; sd t0,8(t6)
      ("rv.ldxb"     "b30fd50003c50f01"  ((ldxb r0 r3 r0 1 16)))       ; add t6,a0,a3 ; lbu a0,16(t6) (string-lane peep)
      ("rv.stxb"     "b30fd5002388af00"  ((stxb r3 r0 1 16 r0)))       ; add t6,a0,a3 ; sb a0,16(t6) (cask-lane pin)
      ("rv.leax"     "b30563008505"      ((leax r1 r9 r9 1 1)))        ; add a1,t1,t1 ; addi a1,a1,1
      ("rv.lea"      "130507fe"          ((lea r0 r4 -32)))            ; addi a0, a4, -32
      ;; the stack pair (16-byte aligned like a64), and lr by name across nested calls
      ("rv.push"     "41112ae0"          ((push r0)))                  ; addi sp,sp,-16 ; sd a0,0(sp)
      ("rv.pop"      "82664101"          ((pop r3)))                   ; ld a3,0(sp) ; addi sp,sp,16
      ("rv.push.lr"  "411106e0"          ((push lr)))                  ; addi sp,sp,-16 ; sd ra,0(sp)
      ;; M division: rounds toward zero like x86, never traps; rem/urem ignore the scratch t
      ("rv.div"      "33451503"          ((div r0 r0 r7)))             ; div a0, a0, a7
      ("rv.rem"      "33651503"          ((rem r0 r0 r7 r4)))          ; rem a0, a0, a7
      ("rv.udiv"     "b3d6f602"          ((udiv r3 r3 r5)))            ; divu a3, a3, a5
      ("rv.urem"     "b3f6f602"          ((urem r3 r3 r5 r2)))         ; remu a3, a3, a5
      ;; the flag memory in anger: cmp emits nothing (or an imm into x30) and br/set fuse it.
      ;; every label branch is the inverted fused branch hopping a jal (j21 fixup, +-1MB).
      ("rv.br.eq"    "6314b5006f00800013000000" ((cmp r0 r1) (br eq l) (nop) (label l)))    ; bne a0,a1,+8 ; j l ; nop
      ("rv.br.bwd"   "130000006304b5006ff09fff" ((label l) (nop) (cmp r0 r1) (br ne l)))    ; beq hop ; j -8
      ("rv.br.lt"    "6354b5006f004000"  ((cmp r0 r1) (br lt l) (label l)))      ; bge a0,a1,+8 ; j l
      ("rv.br.above" "63f4a5006f004000"  ((cmp r0 r1) (br above l) (label l)))   ; bgeu a1,a0,+8 (swapped) ; j l
      ("rv.br.s"     "b30fb54063d40f006f004000" ((cmp r0 r1) (br s l) (label l)))    ; sub t6,a0,a1 ; bgez t6,+8 ; j l
      ("rv.cmp.z"    "631405006f004000"  ((cmp r0 0) (br eq l) (label l)))       ; bnez a0,+8 ; j l (x0, free)
      ("rv.cmp.i"    "130fa0026354e5016f004000" ((cmp r0 42) (br lt l) (label l)))    ; li t5,42 ; bge a0,t5,+8 ; j l
      ("rv.cmp.2br"  "6354b5006f00c0006314b5006f004000"                          ; one cmp, two brs -- the memory persists
                       ((cmp r0 r1) (br lt l) (br eq l) (label l)))
      ("rv.test"     "137f150063040f006f004000" ((test r0 1) (br ne l) (label l)))    ; andi t5,a0,1 ; beqz t5,+8 ; j l
      ("rv.set.eq"   "b34fb50093b61f00"  ((cmp r0 r1) (set eq r3)))              ; xor t6,a0,a1 ; seqz a3,t6
      ("rv.set.eqz"  "93361500"          ((cmp r0 0) (set eq r3)))               ; seqz a3, a0
      ("rv.set.lt"   "b326b500"          ((cmp r0 r1) (set lt r3)))              ; slt a3, a0, a1
      ("rv.set.ge"   "b326b50093c61600"  ((cmp r0 r1) (set ge r3)))              ; slt ; xori a3,a3,1 (the complement)
      ("rv.set.ab"   "b3b6a500"          ((cmp r0 r1) (set above r3)))           ; sltu a3, a1, a0 (swapped)
      ;; adds/subs: the op plus its overflow bit computed into x30 ((d^a)&(d^b) / (a^b)&(a^d));
      ;; br vs/vc read x30's sign, eq/ne/lt read d against x0
      ("rv.adds.vs"  "2e8faa8f3385ef01b34ff501334fe501337fff0163540f006f004000"
                      ((adds r0 r0 r1) (br vs l) (label l)))
      ("rv.subs.vc"  "2e8faa8f3385ef4133cfef01b3cfaf00337fff0163440f006f004000"
                      ((subs r0 r0 r1) (br vc l) (label l)))
      ;; mulo: mulh vs the low half's sign fill (t clobbered, != a,b,d), flag-free
      ("rv.mulo"     "b396c5023385c502935ff5436384f6016f004000" ((mulo r0 r1 r2 r3 l) (label l)))
      ("rv.mulh"     "33977702" ((mulh r4 r5 r10)))                        ; mulh x14, x15, x7
      ;; control: jal wide jumps, the auipc pairs (one 8-byte pcrel fixup each), indirect jalr
      ("rv.jmp"      "6f00800013000000"  ((jmp l) (nop) (label l)))              ; j l ; nop
      ("rv.call"     "97000000e780c00013000000" ((call l) (nop) (label l)))      ; auipc ra,0 ; jalr 12(ra) ; nop
      ("rv.jmpr"     "8287"              ((jmpr r5)))                  ; jr a5
      ("rv.callr"    "e7800600"          ((callr r3)))                 ; jalr a3
      ("rv.grpfn"    "411106e097000000e7800001369582604101828036858280"
                      ((push lr) (call sib) (add r0 r0 r3) (pop lr) (ret) (label sib) (mov r0 r3) (ret)))
      ("rv.la"       "1705000013050501970800009388880041424300"
                      ((la r0 x) (la r7 x) (label x) (raw (65 66 67 0))))        ; auipc+addi pairs: x at +16, +8
      ("rv.ret"      "8280"              ((ret)))                      ; ret (jalr x0, 0(ra))
      ("rv.sys"      "73000000"          ((sys)))                      ; ecall
      ("rv.trap"     "73001000"          ((trap)))                     ; ebreak
      ;; the system lane: Zicsr, the fences, the privileged returns -- what a kernel says and
      ;; codegen never does. every CSR access is one I-form, the pseudos writing x0 into the slot
      ;; they do not name, so a disassembler prints them all back as csrrs/csrrw/csrrc.
      ("rv.csrr"     "73250030"          ((csrr r0 mstatus)))          ; csrr a0, mstatus
      ("rv.csrr.ctr" "732510c0"          ((csrr r0 time)))             ; csrr a0, time (the counters)
      ("rv.csrw"     "73105530"          ((csrw mtvec r0)))            ; csrw mtvec, a0
      ("rv.csrw.num" "7310157c"          ((csrw 1985 r0)))             ; csrw 0x7c1, a0 -- an unnamed csr
      ("rv.csrs"     "73200510"          ((csrs sstatus r0)))          ; csrs sstatus, a0
      ("rv.csrc"     "73b04610"          ((csrc sie r3)))              ; csrc sie, a3
      ("rv.csrwi"    "73503000"          ((csrwi fcsr 0)))             ; csrwi fcsr, 0
      ("rv.csrsi"    "73600110"          ((csrsi sstatus 2)))          ; csrsi sstatus, 2 (SIE on)
      ("rv.csrci"    "73700110"          ((csrci sstatus 2)))          ; csrci sstatus, 2 (..and off)
      ("rv.csrrw"    "73110114"          ((csrrw sp sscratch sp)))     ; csrrw sp, sscratch, sp (the trap swap)
      ("rv.csrrs"    "73a50530"          ((csrrs r0 mstatus r1)))      ; csrrs a0, mstatus, a1
      ("rv.csrrc"    "73b54510"          ((csrrc r0 sie r1)))          ; csrrc a0, sie, a1
      ("rv.csrrwi"   "73d54f30"          ((csrrwi r0 mie 31)))         ; csrrwi a0, mie, 31
      ("rv.csrrsi"   "73650110"          ((csrrsi r0 sstatus 2)))      ; csrrsi a0, sstatus, 2
      ("rv.csrrci"   "73750110"          ((csrrci r0 sstatus 2)))      ; csrrci a0, sstatus, 2 (mask, keep the old)
      ("rv.sfence"   "73000012"          ((sfence zr zr)))             ; sfence.vma (the whole map)
      ("rv.sfence.a" "7300b512"          ((sfence r0 r1)))             ; sfence.vma a0, a1
      ("rv.wfi"      "73005010"          ((wfi)))                      ; wfi
      ("rv.sret"     "73002010"          ((sret)))                     ; sret
      ("rv.mret"     "73002030"          ((mret)))                     ; mret
      ("rv.fence"    "0f00f00f"          ((fence)))                    ; fence iorw, iorw
      ("rv.fencei"   "0f100000"          ((fencei)))                   ; fence.i
      ;; the pad after a compressed ret: 2 bytes laid, 6 to the boundary, so the filler is c.nop; a
      ;; torn wide nop leaves 0013, which says 32-bit and eats the ret behind it
      ("rv.align"    "82800100010001008280"     ((ret) (align 8) (label x) (ret)))    ; ret ; 3x c.nop ; ret
      ;; scalar-double fp (D): f0..f7 -> fa0..fa7, f8..f15 -> ft0..ft7. SSE-named IR two-address;
      ;; ucomisd joins the flag memory (feq/flt/fle compute the predicate at the br/set)
      ("rv.movsd"    "5385b522"          ((movsd f0 f1)))              ; fmv.d fa0, fa1
      ("rv.addsd"    "5375b502"          ((addsd f0 f1)))              ; fadd.d fa0, fa0, fa1
      ("rv.subsd"    "d3f5a50a"          ((subsd f1 f0)))              ; fsub.d fa1, fa1, fa0
      ("rv.mulsd"    "5375b512"          ((mulsd f0 f1)))              ; fmul.d fa0, fa0, fa1
      ("rv.divsd"    "d3f5a51a"          ((divsd f1 f0)))              ; fdiv.d fa1, fa1, fa0
      ("rv.f.temps"  "53707002"          ((addsd f8 f15)))             ; fadd.d ft0, ft0, ft7 (the temp file)
      ("rv.cvtsi2sd" "537527d2"          ((cvtsi2sd f0 r4)))           ; fcvt.d.l fa0, a4
      ("rv.addss"    "5375b500"          ((addss f0 f1)))              ; fadd.s fa0, fa0, fa1 (llvm-mc)
      ("rv.mulss"    "5375b510"          ((mulss f0 f1)))
      ("rv.cvtsi2ss" "537527d0"          ((cvtsi2ss f0 r4)))           ; fcvt.s.l fa0, a4
      ("rv.cvttss2si" "531725c0"         ((cvttss2si r4 f0)))          ; fcvt.l.s a4, fa0, rtz
      ("rv.movdxr"   "530507f0"          ((movdxr f0 r4)))             ; fmv.w.x fa0, a4
      ("rv.movdrx"   "530705e0"          ((movdrx r4 f0)))             ; fmv.x.w a4, fa0
      ("rv.cvttsd2si" "531725c2"         ((cvttsd2si r4 f0)))          ; fcvt.l.d a4, fa0, rtz (toward zero)
      ("rv.movqxr"   "d30507f2"          ((movqxr f1 r4)))             ; fmv.d.x fa1, a4
      ("rv.movqrx"   "530705e2"          ((movqrx r4 f0)))             ; fmv.x.d a4, fa0
      ("rv.cvtss2sd" "53850542"          ((cvtss2sd f0 f1)))           ; fcvt.d.s fa0, fa1
      ("rv.cvtsd2ss" "d3751540"          ((cvtsd2ss f1 f0)))           ; fcvt.s.d fa1, fa0
      ("rv.xorpd"    "530700f2"          ((xorpd f4 f4)))              ; fmv.d.x fa4, zero (zero a double)
      ("rv.stsd"     "08a6"              ((stsd r2 8 f0)))             ; fsd fa0, 8(a2)
      ("rv.ldsd"     "8c22"              ((ldsd f1 r3 0)))             ; fld fa1, 0(a3)
      ("rv.stss"     "2724a600"          ((stss r2 8 f0)))             ; fsw fa0, 8(a2)
      ("rv.ldss"     "87a50600"          ((ldss f1 r3 0)))             ; flw fa1, 0(a3)
      ("rv.fld.far"  "b77ffbffae9f07b50fc2"     ((ldsd f0 r1 -300000)))    ; lui ; add ; fld fa0,-992(t6)
      ("rv.fbr.ab"   "d39fa5a263840f006f004000" ((ucomisd f0 f1) (br above l) (label l)))    ; flt.d t6,fa1,fa0 ; beqz hop ; j
      ("rv.fbr.be"   "d39fa5a263940f006f004000" ((ucomisd f0 f1) (br be l) (label l)))       ; flt.d ; bnez hop (the complement)
      ("rv.fbr.p"    "d32fa5a253afb5a2b3ffef0163940f006f004000"                              ; both-ordered check, hop if set
                       ((ucomisd f0 f1) (br p l) (label l)))
      ("rv.fset.ab"  "d39fa5a27e85"      ((ucomisd f0 f1) (set above r0)))       ; flt.d t6,fa1,fa0 ; mv a0,t6
      ("rv.fset.be"  "d39fa5a213b51f00"  ((ucomisd f0 f1) (set be r0)))          ; flt.d ; seqz a0,t6
      ("rv.tp"       "1285"              ((tp r0))))                   ; mv a0, tp (the thread pointer)
   _ (foldl (_ \ t \ chk2 (t 0) (t 1) 'rv64 (t 2)) 0 rvtests)

   ;; -- the i386 backend and its 16-bit twin (.code16gcc). bytes are gas's for the trailing text
   ;; (`as --32`), or disassemble to the same words where gas picks another encoding. --
   i3tests '(
      ("i3.li" "b83c000000" ((li r0 60)))                      ; mov $60,%eax
      ("i3.li.neg" "bbffffffff" ((li r3 -1)))                  ; mov $-1,%ebx
      ("i3.li.u32" "bfffffffff" ((li r6 4294967295)))          ; mov $0xffffffff,%edi
      ("i3.mov" "89d8" ((mov r0 r3)))                          ; mov %ebx,%eax
      ("i3.mov.sp" "89e5" ((mov r4 sp)))                       ; mov %esp,%ebp
      ("i3.add" "01d8" ((add r0 r0 r3)))                       ; add %ebx,%eax
      ("i3.add.i8" "83c105" ((add r1 r1 5)))                   ; add $5,%ecx
      ("i3.add.i32" "81c1e8030000" ((add r1 r1 1000)))         ; add $1000,%ecx
      ("i3.add.lea" "8d0411" ((add r0 r1 r2)))                 ; lea (%ecx,%edx),%eax
      ("i3.add.leai" "8d4108" ((add r0 r1 8)))                 ; lea 8(%ecx),%eax
      ("i3.sub.lea" "8d41f8" ((sub r0 r1 8)))                  ; lea -8(%ecx),%eax
      ("i3.sub" "29f2" ((sub r2 r2 r5)))                       ; sub %esi,%edx
      ("i3.and.i" "83e00f" ((and r0 r0 15)))                   ; and $15,%eax
      ("i3.or" "09f7" ((or r6 r6 r5)))                         ; or %esi,%edi
      ("i3.xor.zero" "31d2" ((xor r2 r2 r2)))                  ; xor %edx,%edx
      ("i3.and.zx1" "0fb6c3" ((and r0 r3 255)))                ; movzbl %bl,%eax
      ("i3.and.zx2" "0fb7c6" ((and r0 r5 65535)))              ; movzwl %si,%eax
      ("i3.sub.3" "89c829d0" ((sub r0 r1 r2)))                 ; mov %ecx,%eax ; sub %edx,%eax
      ("i3.add.comm" "01ca" ((add r2 r1 r2)))                  ; add %ecx,%edx
      ("i3.imul.rr" "0fafc1" ((imul r0 r0 r1)))                ; imul %ecx,%eax
      ("i3.imul.ri" "69c10a000000" ((imul r0 r1 10)))          ; imul $10,%ecx,%eax
      ("i3.imul.3" "89c80fafc2" ((imul r0 r1 r2)))             ; mov %ecx,%eax ; imul %edx,%eax
      ("i3.cmp" "39c8" ((cmp r0 r1)))                          ; cmp %ecx,%eax
      ("i3.cmp.0" "85f6" ((cmp r5 0)))                         ; test %esi,%esi
      ("i3.cmp.i" "83fe07" ((cmp r5 7)))                       ; cmp $7,%esi
      ("i3.test" "85c8" ((test r0 r1)))                        ; test %ecx,%eax
      ("i3.test.i" "f7c000010000" ((test r0 256)))             ; test $256,%eax
      ("i3.ld" "8b03" ((ld r0 r3 0)))                          ; mov (%ebx),%eax
      ("i3.ld.ebp" "8b4500" ((ld r0 r4 0)))                    ; mov 0(%ebp),%eax
      ("i3.ld.big" "8b8600100000" ((ld r0 r5 4096)))           ; mov 4096(%esi),%eax
      ("i3.st" "897c2404" ((st sp 4 r6)))                      ; mov %edi,4(%esp)
      ("i3.lea" "8d442410" ((lea r0 sp 16)))                   ; lea 16(%esp),%eax
      ("i3.ld1" "0fbe4101" ((ld1 r0 r1 1)))                    ; movsbl 1(%ecx),%eax
      ("i3.ld2" "0fbf4102" ((ld2 r0 r1 2)))                    ; movswl 2(%ecx),%eax
      ("i3.ld4" "8b4104" ((ld4 r0 r1 4)))                      ; mov 4(%ecx),%eax
      ("i3.ldu1" "0fb67101" ((ldu1 r5 r1 1)))                  ; movzbl 1(%ecx),%esi
      ("i3.ldu2" "0fb77102" ((ldu2 r5 r1 2)))                  ; movzwl 2(%ecx),%esi
      ("i3.st1" "885f03" ((st1 r6 3 r3)))                      ; mov %bl,3(%edi)
      ("i3.st1.esi" "87f1880887f1" ((st1 r0 0 r5)))            ; xchg %esi,%ecx ; mov %cl,(%eax) ; xchg %esi,%ecx
      ("i3.set.edi" "970f94c00fb6c097" ((set eq r6)))          ; xchg %edi,%eax ; sete %al ; movzbl %al,%eax ; xchg %edi,%eax
      ("i3.zx1.esi" "960fb6c096" ((zx1 r5)))                   ; xchg %esi,%eax ; movzbl %al,%eax ; xchg %esi,%eax
      ("i3.sx1.edi" "970fbec097" ((sx1 r6)))                   ; xchg %edi,%eax ; movsbl %al,%eax ; xchg %edi,%eax
      ("i3.st2" "66897702" ((st2 r6 2 r5)))                    ; mov %si,2(%edi)
      ("i3.st4" "8937" ((st4 r6 0 r5)))                        ; mov %esi,(%edi)
      ("i3.si" "c745f8d2040000" ((si r4 -8 1234)))             ; movl $1234,-8(%ebp)
      ("i3.si1" "c645ff07" ((si1 r4 -1 7)))                    ; movb $7,-1(%ebp)
      ("i3.si2" "66c745fe2c01" ((si2 r4 -2 300)))              ; movw $300,-2(%ebp)
      ("i3.ldx" "8b449108" ((ldx r0 r1 r2 4 8)))               ; mov 8(%ecx,%edx,4),%eax
      ("i3.stx" "890411" ((stx r1 r2 1 0 r0)))                 ; mov %eax,(%ecx,%edx,1)
      ("i3.leax" "8d44d500" ((leax r0 r4 r2 8 0)))             ; lea 0(%ebp,%edx,8),%eax
      ("i3.ldxb" "0fb60411" ((ldxb r0 r1 r2 1 0)))             ; movzbl (%ecx,%edx),%eax
      ("i3.stxb" "880411" ((stxb r1 r2 1 0 r0)))               ; mov %al,(%ecx,%edx)
      ("i3.ldxsp" "8b0494" ((ldx r0 sp r2 4 0)))               ; mov (%esp,%edx,4),%eax
      ("i3.andx4" "230491" ((andx4 r0 r1 r2 4 0)))             ; and (%ecx,%edx,4),%eax
      ("i3.orm4" "0b4104" ((orm4 r0 r1 4)))                    ; or 4(%ecx),%eax
      ("i3.cmpm.r" "3945fc" ((cmpm r4 -4 r0)))                 ; cmp %eax,-4(%ebp)
      ("i3.cmpm.i8" "837dfc09" ((cmpm r4 -4 9)))               ; cmpl $9,-4(%ebp)
      ("i3.cmpm.i32" "817dfc84030000" ((cmpm r4 -4 900)))      ; cmpl $900,-4(%ebp)
      ("i3.cmprm" "3b45fc" ((cmprm r0 r4 -4)))                 ; cmp -4(%ebp),%eax
      ("i3.sx1" "0fbec0" ((sx1 r0)))                           ; movsbl %al,%eax
      ("i3.sx2" "0fbff6" ((sx2 r5)))                           ; movswl %si,%esi
      ("i3.zx1" "0fb6db" ((zx1 r3)))                           ; movzbl %bl,%ebx
      ("i3.zx2" "0fb7ff" ((zx2 r6)))                           ; movzwl %di,%edi
      ("i3.shl" "c1e003" ((shl r0 3)))                         ; shl $3,%eax
      ("i3.shr1" "d1ea" ((shr r2 1)))                          ; shr %edx
      ("i3.sar" "c1ff1f" ((sar r6 31)))                        ; sar $31,%edi
      ("i3.rol" "c1c008" ((rol r0 8)))                         ; rol $8,%eax
      ("i3.ror4" "c1c808" ((ror4 r0 8)))                       ; ror $8,%eax
      ("i3.shlv" "d3e0" ((shlv r0 r1)))                        ; shl %cl,%eax
      ("i3.sarv" "d3fe" ((sarv r5 r1)))                        ; sar %cl,%esi
      ("i3.push" "53" ((push r3)))                             ; push %ebx
      ("i3.push.i8" "6a05" ((push 5)))                         ; push $5
      ("i3.push.i32" "6870110100" ((push 70000)))              ; push $70000
      ("i3.pop" "5d" ((pop r4)))                               ; pop %ebp
      ("i3.neg" "f7d8" ((neg r0)))                             ; neg %eax
      ("i3.not" "f7d1" ((not r1)))                             ; not %ecx
      ("i3.inc" "ffc2" ((inc r2)))                             ; incl %edx
      ("i3.dec" "ffce" ((dec r5)))                             ; decl %esi
      ("i3.set" "0f9cc00fb6c0" ((set lt r0)))                  ; setl %al ; movzbl %al,%eax
      ("i3.set1" "0f95c1" ((set1 ne r1)))                      ; setne %cl
      ("i3.cmov" "0f4dc6" ((cmov ge r0 r5)))                   ; cmovge %esi,%eax
      ("i3.jmpr" "ffe0" ((jmpr r0)))                           ; jmp *%eax
      ("i3.callr" "ffd2" ((callr r2)))                         ; call *%edx
      ("i3.jmpm" "ff6008" ((jmpm r0 8)))                       ; jmp *8(%eax)
      ("i3.div" "5289c899f7fb5a89c1" ((div r1 r1 r3)))         ; push %edx ; mov %ecx,%eax ; cltd ; idiv %ebx ; pop %edx ; mov %eax,%ecx
      ("i3.udiv.cell" "525289f031d2f7342483c4045a" ((udiv r0 r5 r2))) ; push %edx ; push %edx ; mov %esi,%eax ; xor %edx,%edx ; divl (%esp) ; add $4,%esp ; pop %edx
      ("i3.rem" "5299f7ff89d05a89c3" ((rem r3 r0 r6 r1)))      ; push %edx ; cltd ; idiv %edi ; mov %edx,%eax ; pop %edx ; mov %eax,%ebx
      ("i3.umulh" "5289c8f7e389d05a89c1" ((umulh r1 r1 r3)))   ; push %edx ; mov %ecx,%eax ; mul %ebx ; mov %edx,%eax ; pop %edx ; mov %eax,%ecx
      ("i3.divl" "f7f3" ((divl r3)))                           ; div %ebx
      ("i3.cas" "f00fb10a" ((cas r0 r1 r2)))                   ; lock cmpxchg %ecx,(%edx)
      ("i3.tp" "658b0500000000" ((tp r0)))                     ; .byte 0x65,0x8b,0x05,0,0,0,0
      ("i3.xaddm" "0fc101" ((xaddm 4 r1 0 r0)))                ; xadd %eax,(%ecx)
      ("i3.xchgm1" "8601" ((xchgm 1 r1 0 r0)))                 ; xchg %al,(%ecx)
      ("i3.alum" "015108" ((alum add 4 r1 8 r2)))              ; add %edx,8(%ecx)
      ("i3.alum.i" "66830903" ((alum or 2 r1 0 3)))            ; orw $3,(%ecx)
      ("i3.alum.b" "802903" ((alum sub 1 r1 0 3)))             ; subb $3,(%ecx)
      ("i3.alurm" "0306134608661b0b" ((alurm add 4 r0 r5 0) (alurm adc 4 r0 r5 8) (alurm sbb 2 r1 r3 0)))   ; add (%esi),%eax ; adc 8(%esi),%eax ; sbb (%ebx),%cx
      ("i3.rrop" "0f02c1" ((rrop (15 2) 4 r0 r1)))             ; lar %ecx,%eax
      ("i3.carry" "11c8" ((carry adc 4 r0 r1)))                ; adc %ecx,%eax
      ("i3.carry.i" "83da00" ((carry sbb 4 r2 0)))             ; sbb $0,%edx
      ("i3.unm" "ff01" ((unm inc 4 r1 0)))                     ; incl (%ecx)
      ("i3.btm" "0fba2905" ((btm bts 4 r1 0 5)))               ; btsl $5,(%ecx)
      ("i3.testm" "f60104" ((testm 1 r1 0 4)))                 ; testb $4,(%ecx)
      ("i3.ldseg" "8cc8" ((ldseg r0 1)))                       ; mov %cs,%eax
      ("i3.pushseg" "6606660fa01f0fa9" ((pushseg 0 2) (pushseg 4 2) (popseg 3 4) (popseg 5 4)))   ; pushw %es ; pushw %fs ; popl %ds ; popl %gs
      ("i3.stseg" "8ed8" ((stseg 3 r0)))                       ; mov %eax,%ds
      ("i3.ldcr" "0f20c0" ((ldcr r0 0)))                       ; mov %cr0,%eax
      ("i3.stcr" "0f22d9" ((stcr 3 r1)))                       ; mov %ecx,%cr3
      ("i3.lgdt" "0f0110" ((lgdt r0 0)))                       ; lgdt (%eax)
      ("i3.invlpg" "0f0139" ((invlpg r1 0)))                   ; invlpg (%ecx)
      ("i3.str" "a5" ((str movs 4)))                           ; movsl
      ("i3.strb" "aa" ((str stos 1)))                          ; stosb
      ("i3.bscan" "0fbdc1" ((bscan bsr 4 r0 r1)))              ; bsr %ecx,%eax
      ("i3.popcnt" "66f30fb8c1" ((bscan popcnt 2 r0 r1)))      ; popcnt %cx,%ax
      ("i3.int" "cd80" ((int 128)))                            ; int $0x80
      ("i3.sys" "cd80" ((sys)))                                ; int $0x80
      ("i3.ret" "c3" ((ret)))                                  ; ret
      ("i3.pushf" "9c" ((pushf)))                              ; pushf
      ("i3.inl" "ed" ((inl)))                                  ; in (%dx),%eax
      ("i3.outw" "66ef" ((outw)))                              ; out %ax,(%dx)
      ("i3.iret" "cf" ((iretq)))                               ; iret
      ("i3.call" "e80000000090" ((call L) (label L) (nop)))    ; call L
      ("i3.jmp" "e90000000090" ((jmp L) (label L) (nop)))      ; {disp32} jmp L
      ("i3.br" "0f840000000090" ((br eq L) (label L) (nop)))   ; {disp32} je L
      ("i3.mulo" "0fafc10f800000000090" ((mulo r0 r0 r1 r2 L) (label L) (nop))) ; imul %ecx,%eax ; {disp32} jo L
      ("i3.lar" "e8000000005b81c30700000090" ((lar r3 L) (label L) (nop))) ; call 1f ; 1: pop %ebx ; add $(L-1b),%ebx
      ("i3.addss" "f30f58c1" ((addss f0 f1)))                 ; addss %xmm1,%xmm0
      ("i3.ucomiss" "0f2ec8" ((ucomiss f1 f0)))                ; ucomiss %xmm0,%xmm1
      ("i3.cvtsi2ss" "f30f2ac0" ((cvtsi2ss f0 r0)))            ; cvtsi2ss %eax,%xmm0
      ("i3.cvttss2si" "f30f2cc0" ((cvttss2si r0 f0)))          ; cvttss2si %xmm0,%eax
      ("i3.movdxr" "660f6ec0" ((movdxr f0 r0)))                ; movd %eax,%xmm0
      ("i3.movdrx" "660f7ec0" ((movdrx r0 f0)))                ; movd %xmm0,%eax
      ("i3.cvtui2ss" "8d6424f8890424c744240400000000df2c24d91c24f30f1004248d642408"
        ((cvtui2ss f0 r0)))                                     ; fild qword, fstp dword, movss: one rounding
      ("i3.cvttss2ui" "8d6424f8f30f110424d90424dd0c248b04248d642408"
        ((cvttss2ui r0 f0)))                                    ; movss out, fld dword, fisttp qword
      )
   _ (foldl (_ \ t \ chk2 (t 0) (t 1) 'i386 (t 2)) 0 i3tests)
   i3m16tests '(
      ("i3m16.li" "66b83c000000" ((li r0 60)))                 ; mov $60,%eax
      ("i3m16.ld" "67668b03" ((ld r0 r3 0)))                   ; mov (%ebx),%eax
      ("i3m16.st" "6766897c2404" ((st sp 4 r6)))               ; mov %edi,4(%esp)
      ("i3m16.lea" "67668d442410" ((lea r0 sp 16)))            ; lea 16(%esp),%eax
      ("i3m16.st1" "67885f03" ((st1 r6 3 r3)))                 ; mov %bl,3(%edi)
      ("i3m16.st2" "67897702" ((st2 r6 2 r5)))                 ; mov %si,2(%edi)
      ("i3m16.si1" "67c645ff07" ((si1 r4 -1 7)))               ; movb $7,-1(%ebp)
      ("i3m16.si2" "67c745fe2c01" ((si2 r4 -2 300)))           ; movw $300,-2(%ebp)
      ("i3m16.ldx" "67668b449108" ((ldx r0 r1 r2 4 8)))        ; mov 8(%ecx,%edx,4),%eax
      ("i3m16.stx" "6766890411" ((stx r1 r2 1 0 r0)))          ; mov %eax,(%ecx,%edx,1)
      ("i3m16.push" "6653" ((push r3)))                        ; push %ebx
      ("i3m16.push.i8" "666a05" ((push 5)))                    ; push $5
      ("i3m16.pop" "665d" ((pop r4)))                          ; pop %ebp
      ("i3m16.set" "0f9cc0660fb6c0" ((set lt r0)))             ; setl %al ; movzbl %al,%eax
      ("i3m16.jmpr" "66ffe0" ((jmpr r0)))                      ; jmp *%eax
      ("i3m16.callr" "66ffd2" ((callr r2)))                    ; call *%edx
      ("i3m16.div" "66526689c8669966f7fb665a6689c1" ((div r1 r1 r3))) ; push %edx ; mov %ecx,%eax ; cltd ; idiv %ebx ; pop %edx ; mov %eax,%ecx
      ("i3m16.udiv.cell" "665266526689f06631d26766f734246683c404665a" ((udiv r0 r5 r2))) ; push %edx ; push %edx ; mov %esi,%eax ; xor %edx,%edx ; divl (%esp) ; add $4,%esp ; pop %edx
      ("i3m16.cas" "f067660fb10a" ((cas r0 r1 r2)))            ; lock cmpxchg %ecx,(%edx)
      ("i3m16.alum.i" "67830903" ((alum or 2 r1 0 3)))         ; orw $3,(%ecx)
      ("i3m16.ldseg" "668cc8" ((ldseg r0 1)))                  ; mov %cs,%eax
      ("i3m16.pushseg" "060fa0661f660fa9" ((pushseg 0 2) (pushseg 4 2) (popseg 3 4) (popseg 5 4)))   ; pushw %es ; pushw %fs ; popl %ds ; popl %gs
      ("i3m16.str" "66a5" ((str movs 4)))                      ; movsl
      ("i3m16.strb" "aa" ((str stos 1)))                       ; stosb
      ("i3m16.ret" "66c3" ((ret)))                             ; ret
      ("i3m16.pushf" "669c" ((pushf)))                         ; pushf
      ("i3m16.inl" "66ed" ((inl)))                             ; in (%dx),%eax
      ("i3m16.outw" "ef" ((outw)))                             ; out %ax,(%dx)
      ("i3m16.call" "66e80000000090" ((call L) (label L) (nop))) ; call L
      ("i3m16.jmp" "e9000090" ((jmp L) (label L) (nop)))       ; {disp32} jmp L
      ("i3m16.br" "0f84000090" ((br eq L) (label L) (nop)))    ; {disp32} je L
      ("i3m16.lar" "66e800000000665b6681c30900000090" ((lar r3 L) (label L) (nop))) ; call 1f ; 1: pop %ebx ; add $(L-1b),%ebx
      )
   _ (foldl (_ \ t \ chk2 (t 0) (t 1) 'i386m16 (t 2)) 0 i3m16tests)
   ;; ..and what has no 32-bit face refuses: a register past r6
   i3caught {}
   _ (hear (a \ b \ a = 'i386-badreg ? (pin i3caught 0 a, ()) (welp a b)))
   _ (pin i3caught 0 0, holo-bytes 'i386 '((mov r0 r7)))
   _ (chk-eq "i3.r7.refused" 'i386-badreg (peep i3caught 0 0))

   ;; -- the wasm module writer: each row the bytes binaryen's wasm-as lays for the text (memory64). --
   wtests '(
      ("w.i64.const.-1"   "427f"                   ((i64.const -1)))
      ("w.i64.const.128"  "428001"                 ((i64.const 128)))
      ("w.i64.const.-129" "42ff7e"                 ((i64.const -129)))
      ("w.i64.const.max"  "42ffffffffffffffffff00" ((i64.const 9223372036854775807)))
      ("w.i64.const.min"  "428080808080808080807f" ((i64.const -9223372036854775808)))
      ("w.i64.const.u64"  "427f"                   ((i64.const 18446744073709551615)))   ; a u64 pattern reads as its i64
      ("w.i32.const.u32"  "417f"                   ((i32.const 4294967295)))
      ("w.f64.const"      "44000000000000f83f"     ((f64.const 4609434218613702656)))    ; 1.5's bits
      ("w.store8.off"     "3c00ac02"               ((i64.store8 0 300)))
      ("w.ld.st"          "3703082903081100001000" ((i64.store 3 8) (i64.load 3 8) (call_indirect 0 0) (call 0)))
      ("w.locals.add"     "200020017c"             ((local.get 0) (local.get 1) (i64.add)))
      ("w.br_table"       "0e02010000"             ((br_table (1 0) 0)))
      ("w.blocks"         "02400340047e050b"       ((block) (loop) (if i64) (else) (end)))
      ("w.memory"         "3f004000"               ((memory.size) (memory.grow)))
      ("w.fc"             "fc0b00fc0a0000fc02"     ((memory.fill) (memory.copy) (i32.trunc_sat_f64_s)))
      ("w.tail"           "12030000"               ((return_call 3) (unreachable) (unreachable))))
   _ (foldl (_ \ t \ chk-eq (t 0) (t 1) (wins-hex (t 2))) 0 wtests)
   ;; the container: leb, names, a memory64 limit, a data segment's i64 offset
   _ (chk-eq "w.uleb" '(172 2) (uleb 300))
   _ (chk-eq "w.sleb" '(192 0) (sleb 64))
   _ (chk-eq "w.name" "03616464" (hexs (wname "add")))
   _ (chk-eq "w.module.empty" "0061736d01000000" (wasm-hex {}))
   _ (chk-eq "w.module.mem64" "0061736d010000000504010501040b08010042080b026869"
             (wasm-hex {'memory '(1 4) 'data '((8 104 105))}))
   _ (chk-eq "w.module.func" "0061736d0100000001070160027e7e017e030201000707010361646400000a09010700200020017c0b"
             (wasm-hex {'types '(((i64 i64) (i64))) 'funcs '((0 () ((local.get 0) (local.get 1) (i64.add))))
                        'exports '(("add" func 0))}))
   ;; the relooper off holo's IR: a reducible graph wears structured control -- no label at all
   ;; is straight line, and a self-loop is a wasm loop whose br_if carries the condition
   _ (chk-eq "w.fn.skeleton"
             '(((29 i64) (1 i32) (3 i64) (22 f64))
               (i64.const 5) (local.set 0) (local.get 0) (return) (unreachable))
             (wasm-fn '((li r0 5) (ret)) 0 {}))
   _ (chk-eq "w.fn.label"
             '(((28 i64) (1 i32) (3 i64) (22 f64))
               (local.get 0) (local.set 30) (i64.const 0) (local.set 31)
               (loop) (local.get 30) (local.get 31) (i64.eq) (br_if 0) (br 0) (end) (unreachable))
             (wasm-fn '((cmp r0 0) (label top) (br eq top) (jmp top)) 1 {}))
   ;; ..and an irreducible one -- two blocks entered from outside and jumping to each other --
   ;; keeps the dispatch loop: the label local, one br_table, a jmp setting it and branching out
   _ (chk-eq "w.fn.irreducible"
             '(((27 i64) (1 i32) (3 i64) (22 f64))
               (i32.const 0) (local.set 29) (loop) (block) (block) (block)
               (local.get 29) (br_table (0 1 2) 0)
               (end) (local.get 0) (local.set 30) (i64.const 0) (local.set 31)
               (local.get 30) (local.get 31) (i64.eq) (if) (i32.const 2) (local.set 29) (br 3) (end)
               (end) (i32.const 2) (local.set 29) (br 1)
               (end) (i32.const 1) (local.set 29) (br 0) (end) (unreachable))
             (wasm-fn '((cmp r0 0) (br eq bb) (label aa) (jmp bb) (label bb) (jmp aa)) 2 {}))

   ;; -- summary; nonzero exit on any miss, so `make`-style gates see the failure. --
   np (peep pass 0 0) nf (peep fail 0 0)
   _ (sayln $ "test/holo/golden: " + show np + " passed, " + show nf + " failed\n")
   _ (0 = nf ? 0 (quit 1)))
