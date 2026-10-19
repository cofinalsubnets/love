; src/inle/mkvec.l -- lay vec.o, the kernel's interrupt tail: the exception and IRQ entry points,
; register-exact leaves C cannot say. one scaffold with a payload per ISA.
;
;   (lay-vec dst "x64")   the IDT, the ISR tables, exc_stub_0..31, the three IRQ handlers,
;                         archinit (IDT + PIC + PIT), k_reset/k_halt
;   (lay-vec dst "a64")   the 2 KiB-aligned 16 x 0x80 vector table, the IRQ save/restore path,
;                         the fault report path
;   (lay-vec dst "rv64")  the one direct-mode trap entry: save, k_trap, restore, sret
;
; runs after src/love/holo/{elf,obj}.l in a (borrow 'holo) cat. registers are holo's -- x86: r0=rax r1=rcx r2=rdx r3=rbx r4=rbp r5=rsi r6=rdi r7..r14=r8..r15; a64:
; rN = xN; riscv: r0..r7 = a0..a7, r8..r12 = t0..t4, lr = ra. x86 port i/o is register-contracted
; (dx the port, al the datum), so every `out` is a `li r2 <port>` then `outb`.
(:
   ;; list helpers: `iota` answers an array
   (v-upto n)  (:- (go 0) (go i) (n > i ? (i . go (i + 1))))
   (v-rep n x) (n >= 1 ? (x . v-rep (n - 1) x))
   (v-zeros n) (v-rep n 0)
   (v-mapi f l) (:- (go l 0) (go l2 i) (two? l2 ? (f i <l2 . go >l2 (i + 1))))

   ;; -- x64 ------------------------------------------------------------
   ;; the vectors the CPU pushes an error code for; the stubs push a dummy 0 for the rest,
   ;; so every frame reaching k_exception has one shape
   xerr-vecs '(8 10 11 12 13 14 17 21 29 30)
   ;; every GPR but rsp, in struct k_frame's order (arch.c), lowest address last pushed
   x-save '(r4 r0 r3 r1 r2 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14)   ; rbp rax rbx rcx rdx rsi rdi r8..r15
   x-push (map (r \ ['push r]) x-save)
   x-pop  (map (r \ ['pop r]) (rev x-save))
   ;; ..and the xmm file with mxcsr by fxsave64 / fxrstor64, since a handler's C may spend any
   ;; of them. the gp frame leaves sp 16-aligned, as fxsave wants
   x-fsave [['sub 'sp 'sp 512] ['raw [0x48 0x0f 0xae 0x04 0x24]]]
   x-fload [['raw [0x48 0x0f 0xae 0x0c 0x24]] ['add 'sp 'sp 512]]
   ;; an EOI to the primary PIC
   x-eoi '((li r0 0x20) (li r2 0x20) (outb))
   (x-stub v)
    ([['label (nom $ "exc_stub_" + show v)]]
     + (elem v xerr-vecs ? () [['push 0]])       ; the dummy error code
     + [['push v] ['jmp 'exc_common]])
   (sn1 v) ("exc_stub_" + show v)
   x-stub-names (map sn1 (v-upto 32))

   ;; the ISR table archinit walks: 0..31 the exception stubs, then the 16 remapped PIC
   ;; vectors. isrs ends right before isr_types, which the loop's exit test needs: keep them adjacent
   x-isrs (map (name * sn1) (v-upto 32)
           + '(timer_isr        ; 32: IRQ0  PIT
               keyboard_isr     ; 33: IRQ1  PS/2
               k_reset          ; 34: IRQ2
               k_reset          ; 35: IRQ3
               uart_isr)        ; 36: IRQ4  COM1
           + v-rep 11 'k_reset)                         ; 37..47: a stray IRQ reboots
   x-trap 0x8f                                        ; present, DPL 0, 64-bit TRAP gate
   x-intr 0x8e                                        ; ..and INTERRUPT gate (clears IF on entry)
   x-types ([x-trap x-trap x-intr]                    ; 0 #DE, 1 #DB, 2 NMI
            + v-rep 29 x-trap                           ; 3..31
            + [x-intr x-intr x-trap x-trap x-intr]    ; 32 PIT, 33 PS/2, 34, 35, 36 COM1
            + v-rep 11 x-trap)                          ; 37..47

   ;; the lockstep tables, then the LIDT operands. .data, not .rodata: under the -pie artifact
   ;; __love_reloc writes these absolute pointers at a hosted start, and there is no relro
   (x-quad nm) ['raw [['fix 8 'abs64 nm 0]]]
   x-rodata
    ([['label 'isrs]]
     + map x-quad x-isrs
     + [['label 'isr_types] ['raw x-types]]
     ;; the LIDT operands: a 2-byte limit then the 8-byte base
     + [['align 2] ['label 'idtreg] ['raw (le16 4095)]]       ; the limit: sizeof idt - 1
     + [(x-quad 'idt)]
     + [['label 'idtreg_null] ['raw [0 0]]]                   ; an EMPTY IDT: int 0 triple-faults
     + [['raw (v-zeros 8)]]
     ;; the machine's own GDT: the kernel's code and data at 0x08/0x10, a process's data and
     ;; code at 0x18/0x20 (sysret's order, STAR below), the TSS at 0x28, its base laid by
     ;; archinit
     + [['align 8] ['label 'gdt64]]
     + [['raw (le64 0)] ['raw (le64 0x00209A0000000000)] ['raw (le64 0x0000920000000000)]
        ['raw (le64 0x0000F20000000000)] ['raw (le64 0x0020FA0000000000)]
        ['raw (le64 0x0000890000000067)] ['raw (le64 0)]]
     + [['label 'gdtreg64] ['raw (le16 55)] (x-quad 'gdt64)]
     ;; the TSS: rsp0, the stack an interrupt from a process lands on (src/inle/x64/proc.c
     ;; writes it), and no I/O map -- its offset past the limit
     + [['align 16] ['label 'k_tss] ['raw (v-zeros 102)] ['raw (le16 104)]]
     ;; the cpu block, gs's while the kernel runs: [0] the running process's kernel stack,
     ;; [8] its stack while the entry has nowhere else to hold it
     + [['align 16] ['label 'k_cpu] ['raw (v-zeros 32)]])

   ;; .bss: the IDT, 256 entries of 16 bytes, filled by archinit before LIDT
   x-bss [['label 'idt] ['raw (v-zeros 4096)]]

   x-text
    (foldl (a \ v \ a + x-stub v) () (v-upto 32)
     ;; the common tail. past the float save the stack is struct k_frame, so rdi points at it;
     ;; five qwords from the CPU, two from the stub, fifteen saved -- 176 bytes, 16-aligned
     + [['align 8] ['label 'exc_common]]
     + x-push
     + x-fsave
     ;; a fault from a process (cs's low bits, past the two frames) arrives on its gs:
     ;; the kernel's comes back, and k_exception ends the process rather than the machine
     + '((ld r0 sp 656) (and r0 r0 3) (cmp r0 0) (br eq exc_kern) (swapgs) (label exc_kern)
         (lea r6 sp 512) (call k_exception))
     + x-fload
     + x-pop
     + '((add sp sp 16)          ; discard the vector + error code
         (iretq))                ; (the fatal handler never returns)
     ;; the timer (IRQ0): bump kticks through two saved registers. a tick in a process (cs
     ;; past the two pushes) also counts down its turn, and k_proc_tick may switch from there
     + [['align 8] ['label 'timer_isr]]
     + '((push r0) (push r2)
         (la r0 kticks) (ld r2 r0 0) (add r2 r2 1) (st r0 0 r2))
     + x-eoi
     + '((ld r0 sp 24) (and r0 r0 3) (cmp r0 0) (br eq timer_kern)
         (pop r2) (pop r0))
     + x-push
     + x-fsave
     + '((swapgs) (call k_proc_tick) (swapgs))
     + x-fload
     + x-pop
     + '((iretq)
         (label timer_kern)
         (pop r2) (pop r0) (iretq))
     ;; the PS/2 keyboard (IRQ1): read the scancode off port 0x60, hand it to kb_int
     + [['align 8] ['label 'keyboard_isr]]
     + x-push
     + x-fsave
     + '((li r2 0x60) (inb)        ; al <- scancode
         (mov r6 r0) (zx1 r6)    ; rdi = (uint8_t) al
         (call kb_int))
     + x-eoi
     + x-fload
     + x-pop
     + '((iretq))
     ;; COM1 RX (IRQ4)
     + [['align 8] ['label 'uart_isr]]
     + x-push
     + x-fsave
     + '((call k_uart))
     + x-eoi
     + x-fload
     + x-pop
     + '((iretq))
     ;; a process's `syscall` (LSTAR): rcx its pc, r11 its flags, IF masked. its stack goes
     ;; aside through gs; the frame is struct k_sysf (x64/proc.c), and every register but rax
     ;; comes back as it was, as linux keeps them
     + [['align 8] ['label 'k_syscall_entry]]
     + [['swapgs]
        ['raw [0x65 0x48 0x89 0x24 0x25 8 0 0 0]]      ; mov %rsp, %gs:8
        ['raw [0x65 0x48 0x8b 0x24 0x25 0 0 0 0]]      ; mov %gs:0, %rsp
        ['raw [0x65 0xff 0x34 0x25 8 0 0 0]]]          ; push %gs:8
     + '((push r10) (push r1) (push r8) (push r7) (push r9) (push r2) (push r5) (push r6) (push r0))
     + x-fsave
     + '((lea r6 sp 512) (call k_syscall))
     + x-fload
     + '((add sp sp 8)
         (pop r6) (pop r5) (pop r2) (pop r9) (pop r7) (pop r8) (pop r1) (pop r10)
         (pop sp)
         (swapgs))
     + [['raw [0x48 0x0f 0x07]]]                         ; sysretq
     ;; k_kswap(save, load): one kernel stack to another. callee-saved registers, flags and
     ;; float file go on the leaving stack, its top to *save. a first turn arrives at k_ufirst
     + [['align 8] ['label 'k_kswap]]
     + '((pushf) (cli)
         (push r3) (push r4) (push r11) (push r12) (push r13) (push r14))
     + x-fsave
     + '((st r6 0 sp) (mov sp r5))
     + x-fload
     + '((pop r14) (pop r13) (pop r12) (pop r11) (pop r4) (pop r3)
         (popf)
         (ret))
     ;; r12 the process's struct k_uctx (x64/proc.c): [8] its pc, [16] its stack, cr3 already
     ;; up. ring 3 at the pc, nothing of the kernel's in a register
     + [['align 8] ['label 'k_ufirst]]
     + '((mov r6 r11)
         (ld r1 r6 8) (li r10 0x202) (ld r2 r6 16)
         (mov sp r2)
         (xor r0 r0 r0) (xor r2 r2 r2) (xor r3 r3 r3) (xor r4 r4 r4) (xor r5 r5 r5)
         (xor r6 r6 r6) (xor r7 r7 r7) (xor r8 r8 r8) (xor r9 r9 r9) (xor r11 r11 r11)
         (xor r12 r12 r12) (xor r13 r13 r13) (xor r14 r14 r14)
         (swapgs))
     + [['raw [0x48 0x0f 0x07]]]                         ; sysretq
     ;; archinit: the GDT and TSS (so the gates name its code selector), the syscall MSRs,
     ;; then each (handler, type) pair into a 16-byte IDT descriptor, LIDT, the PIT and the PIC.
     ;; x87/SSE is on from kmain's top
     + [['align 8] ['label 'archinit]]
     + '((la r0 k_tss)           ; the TSS descriptor's base, split as the CPU reads it
         (la r6 gdt64)
         (st2 r6 42 r0)
         (mov r3 r0) (shr r3 16) (st1 r6 44 r3)
         (shr r3 8) (st1 r6 47 r3)
         (shr r3 8) (st4 r6 48 r3)
         (la r0 gdtreg64) (lgdt r0 0)
         (li r0 0x10) (stseg 3 r0) (stseg 0 r0) (stseg 2 r0)    ; ds es ss
         (push 8) (la r0 gdt_cs) (push r0))
     + [['raw [0x48 0xcb]]]                              ; lretq: cs = 0x08
     + '((label gdt_cs)
         (li r0 0x28) (ltr r0)
         ;; EFER.SCE; STAR: syscall's cs 0x08, sysret's base 0x13 (+16 code, +8 data), rpl 3
         ;; spelled out or iret refuses ss 0x18; FMASK masks IF, TF, DF, AC, NT. gs: the cpu
         ;; block in the kernel, a process's own (0) in the swapgs twin
         (li r1 0xC0000080) (rdmsr) (or r0 r0 1) (wrmsr)
         (li r1 0xC0000081) (li r0 0) (li r2 0x00130008) (wrmsr)
         (li r1 0xC0000082) (la r0 k_syscall_entry) (mov r2 r0) (shr r2 32) (wrmsr)
         (li r1 0xC0000084) (li r0 0x47700) (li r2 0) (wrmsr)
         (li r1 0xC0000101) (la r0 k_cpu) (mov r2 r0) (shr r2 32) (wrmsr)
         (li r1 0xC0000102) (li r0 0) (li r2 0) (wrmsr)
         (la r6 idt)             ; rdi = the entry being filled
         (la r1 isrs)            ; rcx = the handler cursor
         (la r2 isr_types)       ; rdx = the type cursor
         (mov r0 r2)             ; rax = the sentinel: rcx reaches isr_types when done
         (ldseg r8 1)            ; r9 = cs, the selector the gates name
         (label idt_entry)
         (ld r3 r1 0)            ; rbx = the handler address
         (st2 r6 0 r3)           ; [rdi]    = its low 16
         (sar r3 16)
         (st2 r6 6 r3)           ; [rdi+6]  = its mid 16
         (sar r3 16)
         (st4 r6 8 r3)           ; [rdi+8]  = its high 32
         (st4 r6 2 r8)           ; [rdi+2]  = selector + IST/zero (the attr byte lands below)
         (ldu1 r3 r2 0)          ; the type byte
         (st1 r6 5 r3)           ; [rdi+5]  = type/attr
         (inc r2)
         (add r1 r1 8)
         (add r6 r6 16)
         (cmp r1 r0)
         (br ne idt_entry)
         (la r0 idtreg)
         (lidt r0 0)
         ;; PIT channel 0, rate-generator mode (0x36), divisor 0x2e9b -> ~100 Hz
         (li r0 0x36) (li r2 0x43) (outb)
         (li r2 0x40) (li r0 0x9b) (outb) (li r0 0x2e) (outb)
         ;; PIC ICW1, both controllers
         (li r0 0x11) (li r2 0x20) (outb) (li r2 0xa0) (outb)
         ;; primary ICW2/ICW3: vector base 0x20, secondary cascaded on IRQ2
         (li r2 0x21) (li r0 0x20) (outb) (li r0 4) (outb)
         ;; secondary ICW2/ICW3: vector base 0x28, cascade id 2
         (li r2 0xa1) (li r0 0x28) (outb) (li r0 2) (outb)
         ;; ICW4 (8086 mode) on both, then an all-zero mask: everything unmasked
         (li r0 1) (li r2 0x21) (outb) (li r2 0xa1) (outb)
         (li r0 0) (li r2 0x21) (outb) (li r2 0xa1) (outb)
         (sti)
         (ret))
     ;; reset by triple fault: LIDT a zero-size IDT, then int 0
     + [['align 8] ['label 'k_reset]]
     + '((la r0 idtreg_null)
         (lidt r0 0)
         (int 0)
         (label k_halt)
         (cli) (hlt) (jmp k_halt)))

   ;; -- a64 -----------------------------------------------------------
   ;; 16 entries of 0x80 bytes, 2 KiB-aligned. at EL1 on SP_EL1 only the "current EL with
   ;; SP_ELx" group fires; IRQ goes to k_irq, all else to a_fault, so a surprise reports
   a-slots '(a_fault a_fault a_fault a_fault      ; current EL, SP_EL0: sync IRQ FIQ SError
             a_fault a_irq   a_fault a_fault      ; current EL, SP_ELx
             a_fault a_fault a_fault a_fault      ; lower EL, a64
             a_fault a_fault a_fault a_fault)     ; lower EL, aarch32
   ;; the IRQ path saves the caller-saved x0..x18 plus x29/x30 (k_irq is AAPCS); 176 keeps sp
   ;; 16-aligned. single str/ldr keeps every offset in the scaled imm12, so nothing borrows x16
   a-save '(r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14 r15 r16 r17 r18 fp lr)
   ;; ..then q0..q31 at 176 (whole, k_irq's C may spend any), fpsr/fpcr at 688/696 through
   ;; x0, spent last on the way in, first on the way out
   a-frame 704
   (a-slot-off i) (8 * i)
   (a-q base i) ['raw (le32 (base | (11 + i) << 10 | 31 << 5 | i))]
   a-push (v-mapi (\ i r ['st 'sp (a-slot-off i) r]) a-save + map (a-q 0x3D800000) (v-upto 32)
           + [['raw (le32 0xD53B4420)] ['st 'sp 688 'r0] ['raw (le32 0xD53B4400)] ['st 'sp 696 'r0]])    ; mrs x0, fpsr / fpcr
   a-pop  ([['ld 'r0 'sp 696] ['raw (le32 0xD51B4400)] ['ld 'r0 'sp 688] ['raw (le32 0xD51B4420)]]       ; msr fpcr / fpsr, x0
           + map (a-q 0x3DC00000) (v-upto 32) + v-mapi (\ i r ['ld r 'sp (a-slot-off i)]) a-save)
   ;; the align rides after each slot, the last included, so the handlers start past the table
   a-text
    (foldl (a \ s \ a + [['jmp s] ['align 128]]) [['label 'vectors]] a-slots
     ;; DAIF.I is masked on entry, so ELR_EL1/SPSR_EL1 hold across the call
     + [['label 'a_irq] ['sub 'sp 'sp a-frame]]
     + a-push
     + '((call k_irq))
     + a-pop
     + [['add 'sp 'sp a-frame] ['eret]]
     ;; the fault path: ESR/ELR/FAR to k_fault, which reports and halts
     + '((label a_fault)
         (mrs r0 esr_el1)
         (mrs r1 elr_el1)
         (mrs r2 far_el1)
         (call k_fault)
         (label a_halt)
         (wfi)
         (jmp a_halt)))

   ;; -- rv64 ------------------------------------------------------------
   ;; one direct-mode entry, 4-aligned. SIE is masked on entry, so sepc/scause/stval hold.
   ;; k_trap returns from an interrupt, reports and halts on a fault.
   ;; saved: ra, t0..t4, a0..a7 and the unnamed scratches x30/x31 (x30 holds a cmp's flags
   ;; until its br); then f0..f19 at 128, fcsr at 288 through a0. 304 keeps sp 16-aligned
   r-save '(lr r8 r9 r10 r11 r12 r0 r1 r2 r3 r4 r5 r6 r7)
   r-fregs (map (i \ name ("f" + show i)) (v-upto 20))
   r-frame 304
   ;; sd/ld of the unnamed registers against sp, as words
   (r-sd rs2 off) (le32 (off >> 5 << 25 | rs2 << 20 | 2 << 15 | 3 << 12
                         | (off & 31) << 7 | 0x23))
   (r-ld rd off)  (le32 (off << 20 | 2 << 15 | 3 << 12 | rd << 7 | 0x03))
   r-push (v-mapi (\ i r ['st 'sp (8 * i) r]) r-save
           + [['raw (r-sd 30 112)] ['raw (r-sd 31 120)]]
           + v-mapi (\ i r ['stsd 'sp (128 + 8 * i) r]) r-fregs
           + [['raw (le32 0x00302573)] ['st 'sp 288 'r0]])               ; frcsr a0
   r-pop  ([['ld 'r0 'sp 288] ['raw (le32 0x00351073)]]                 ; fscsr a0
           + v-mapi (\ i r ['ld r 'sp (8 * i)]) r-save
           + [['raw (r-ld 30 112)] ['raw (r-ld 31 120)]]
           + v-mapi (\ i r ['ldsd r 'sp (128 + 8 * i)]) r-fregs)
   r-text
    ([['label 'vectors] ['sub 'sp 'sp r-frame]]
     + r-push
     + '((csrr r0 scause)
         (csrr r1 sepc)
         (csrr r2 stval)
         (call k_trap))
     + r-pop
     + [['add 'sp 'sp r-frame] ['sret]])

   ;; -- the two objects ---------------------------------------------------
   ;; SHF flags: 2 ALLOC, 3 ALLOC|WRITE, 6 ALLOC|EXEC. types: 1 PROGBITS, 8 NOBITS.
   ;; .text.vectors is 2048-aligned since VBAR_EL1 ignores the low 11 bits
   (lay-vec dst arch) (write-bytes dst (lay-vec-bytes arch))
   (lay-vec-bytes arch)
    (arch @ "x64"
       (objsecs 'x64
                [[".text"   1 6 16 x-text]
                 [".data"   1 3 8  x-rodata]
                 [".bss"    8 3 16 x-bss]]
                '("archinit" "k_reset" "k_halt" "timer_isr" "keyboard_isr" "uart_isr"
                  "k_kswap" "k_ufirst")
                '("k_tss" "k_cpu")       ; x64/proc.c's; idt/isrs/idtreg/gdt64 are ours alone
                ()
                ;; local function symbols, so nm, gdb and a backtrace name them
                (x-stub-names + '("exc_common" "k_syscall_entry")))
       "a64"
       (objsecs 'a64
                [[".text.vectors" 1 6 2048 a-text]]
                '("vectors")             ; arch.c: extern uint8_t vectors[] -> VBAR_EL1
                () ()
                '("a_irq" "a_fault"))
       "rv64"
       (objsecs 'rv64
                [[".text" 1 6 16 r-text]]
                '("vectors")             ; arch.c: extern uint8_t vectors[] -> stvec
                () () ())
       (scare 'mkvec-arch arch)))
