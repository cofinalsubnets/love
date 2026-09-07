; inle/mkvec.l -- lay vec.o, the kernel's interrupt tail: the exception and IRQ entry points,
; register-exact leaves C cannot say. mksys.l is the precedent and the shape is the same --
; one scaffold, a payload per ISA -- but this one is generated rather than transcribed, the
; 32 x86 stubs and the 16 a64 vector slots having been .macro/.rept loops in GAS.
;
;   (lay-vec dst "x64")   the IDT, the ISR tables, exc_stub_0..31, the three
;                            IRQ handlers, archinit (IDT + PIC + PIT), k_reset/k_halt
;   (lay-vec dst "a64")  the 2 KiB-aligned 16 x 0x80 vector table, the IRQ
;                            save/restore path, the fault report path
;   (lay-vec dst "rv64")  the one direct-mode trap entry: save, k_trap, restore, sret
;
; runs after core/holo/{elf,obj}.l in a (use 'holo) cat; the Makefile drives it. register
; vocabulary is holo's -- x86: r0=rax r1=rcx r2=rdx r3=rbx r4=rbp r5=rsi r6=rdi r7..r14=
; r8..r15; a64: rN = xN; riscv: r0..r7 = a0..a7, r8..r12 = t0..t4, lr = ra.
; x86 port i/o is register-contracted (dx the port, al the datum),
; so every `out 0x21, al` becomes a `li r2 <port>` then `outb` -- one instruction more than
; GAS's immediate form, and the same bus traffic.
(:
   ;; the four list helpers the loops want: `iota` answers an array, these are lists
   (v-upto n)  (: (go i) (n > i ? (i . go (i + 1))) (go 0))
   (v-rep n x) (n >= 1 ? (x . v-rep (n - 1) x))
   (v-zeros n) (v-rep n 0)
   (v-mapi f l) (: (go l2 i) (two? l2 ? (f i <l2 . go >l2 (i + 1))) (go l 0))

   ;; -- x64 ------------------------------------------------------------
   ;; the vectors the CPU pushes an error code for. every other one pushes a dummy 0 first,
   ;; so every frame reaching k_exception has one shape -- the whole reason the stubs exist.
   xerr-vecs '(8 10 11 12 13 14 17 21 29 30)
   ;; push15/pop15: every GPR but rsp, in struct k_frame's order (arch.c) -- lowest address
   ;; first is the reverse of the push order.
   x-save '(r4 r0 r3 r1 r2 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14)   ; rbp rax rbx rcx rdx rsi rdi r8..r15
   x-push (map (\ r ['push r]) x-save)
   x-pop  (map (\ r ['pop r]) (rev x-save))
   ;; an EOI to the primary PIC. the port rides dx, the datum al.
   x-eoi '((li r0 0x20) (li r2 0x20) (outb))
   (x-stub v)
    ([['label (intern ("exc_stub_" + (show v)))]]
     + (? (member? v xerr-vecs) () [['push 0]])       ; the dummy error code
     + [['push v] ['jmp 'exc_common]])
   (sn1 v) ("exc_stub_" + show v)
   x-stub-names (map sn1 (v-upto 32))

   ;; the ISR table archinit walks: 0..31 the exception stubs, then the 16 remapped PIC
   ;; vectors. isrs and isr_types are walked in lockstep and isrs ends right before
   ;; isr_types, which is what lets the loop exit on `cmp rcx, rax`: keep them adjacent.
   x-isrs (map (name * sn1) (v-upto 32)
           + '(timer_isr        ; 32: IRQ0  PIT
               keyboard_isr     ; 33: IRQ1  PS/2
               k_reset          ; 34: IRQ2
               k_reset          ; 35: IRQ3
               uart_isr)        ; 36: IRQ4  COM1
           + (v-rep 11 'k_reset))                       ; 37..47: a stray IRQ reboots
   x-trap 0x8f                                        ; present, DPL 0, 64-bit TRAP gate
   x-intr 0x8e                                        ; ..and INTERRUPT gate (clears IF on entry)
   x-types ([x-trap x-trap x-intr]                    ; 0 #DE, 1 #DB, 2 NMI
            + (v-rep 29 x-trap)                         ; 3..31
            + [x-intr x-intr x-trap x-trap x-intr]    ; 32 PIT, 33 PS/2, 34, 35, 36 COM1
            + (v-rep 11 x-trap))                        ; 37..47

   ;; the two lockstep tables, then the two LIDT operands. an entry is an 8-byte absolute
   ;; pointer, so a relocation in the .o. laid as .data and not .rodata: under the fused -pie
   ;; artifact these sites ride the love_rela table and __ai_reloc writes them at a hosted
   ;; start, where a read-only segment is a startup segfault and our linker has no relro
   ;; middle ground. metal never cared either way.
   (x-quad nm) ['raw [['fix 8 'abs64 nm 0]]]
   x-rodata
    ([['label 'isrs]]
     + map x-quad x-isrs
     + [['label 'isr_types] ['raw x-types]]
     ;; the LIDT operands: a 2-byte limit then the 8-byte base. the offset is already even,
     ;; so the align pads nothing and only says the requirement out loud.
     + [['align 2] ['label 'idtreg] ['raw (le16 4095)]]       ; the limit: sizeof idt - 1
     + [(x-quad 'idt)]
     + [['label 'idtreg_null] ['raw [0 0]]]                   ; an EMPTY IDT: int 0 triple-faults
     + [['raw (v-zeros 8)]])

   ;; .bss: the IDT itself, 256 entries of 16 bytes. NOBITS, so the loader hands it over
   ;; zeroed and archinit fills every entry before LIDT.
   x-bss [['label 'idt] ['raw (v-zeros 4096)]]

   ;; .text.
   x-text
    (foldl (\ a v (a + (x-stub v))) () (v-upto 32)
     ;; the common tail. after push15 the stack from rsp upward is struct k_frame, so
     ;; rdi = rsp is the whole argument marshalling, and rsp is 16-byte aligned at the call:
     ;; five qwords from the CPU, two from the stub, fifteen from push15 -- 176 bytes.
     + [['align 8] ['label 'exc_common]]
     + x-push
     + '((mov r6 sp) (call k_exception))
     + x-pop
     + '((add sp sp 16)          ; discard the vector + error code
         (iretq))                ; (the fatal handler never returns)
     ;; the timer (IRQ0). the neutral surface has no read-modify-write to memory, so the
     ;; counter bump is a load, an add and a store through two registers we save ourselves.
     ;; no call, so no stack-alignment duty.
     + [['align 8] ['label 'timer_isr]]
     + '((push r0) (push r2)
         (la r0 kticks) (ld r2 r0 0) (add r2 r2 1) (st r0 0 r2))
     + x-eoi
     + '((pop r2) (pop r0) (iretq))
     ;; the PS/2 keyboard (IRQ1): read the scancode off port 0x60, hand it to kb_int
     + [['align 8] ['label 'keyboard_isr]]
     + x-push
     + '((li r2 0x60) (inb)        ; al <- scancode
         (mov r6 r0) (zx1 r6)    ; rdi = (uint8_t) al
         (call kb_int))
     + x-eoi
     + x-pop
     + '((iretq))
     ;; COM1 RX (IRQ4).
     + [['align 8] ['label 'uart_isr]]
     + x-push
     + '((call k_uart))
     + x-eoi
     + x-pop
     + '((iretq))
     ;; archinit: walk isrs/isr_types in lockstep, packing each (handler, type) pair into a
     ;; 16-byte IDT descriptor, then LIDT, the PIT and the PIC. x87/SSE is enabled at the top
     ;; of kmain -- it must be on before any C runs -- so the FPU wants nothing here.
     + [['align 8] ['label 'archinit]]
     + '((la r6 idt)             ; rdi = the entry being filled
         (la r1 isrs)            ; rcx = the handler cursor
         (la r2 isr_types)       ; rdx = the type cursor
         (mov r0 r2)             ; rax = the sentinel: rcx reaches isr_types when done
         ;; the bootloader's code selector: an IDT entry must name a segment valid in the
         ;; current GDT, and the doors disagree (OVMF leaves cs = 0x38, our PVH stub 0x08),
         ;; so reading it is the only way that is true of both.
         (ldseg r8 1)            ; r9 = cs
         (label idt_entry)
         (ld r3 r1 0)            ; rbx = the handler address
         (st2 r6 0 r3)           ; [rdi]    = its low 16
         (sar r3 16)
         (st2 r6 6 r3)           ; [rdi+6]  = its mid 16
         (sar r3 16)
         (st4 r6 8 r3)           ; [rdi+8]  = its high 32
         (st4 r6 2 r8)           ; [rdi+2]  = selector + IST/zero (the attr byte lands below)
         (ldu1 r3 r2 0)          ; the type byte (rbx is dead here -- the address is spent)
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
     ;; reset by triple fault: LIDT a zero-size IDT, then int 0 -- the CPU cannot dispatch
     ;; the vector, escalates through #DF, and the host reboots.
     + [['align 8] ['label 'k_reset]]
     + '((la r0 idtreg_null)
         (lidt r0 0)
         (int 0)
         (label k_halt)
         (cli) (hlt) (jmp k_halt)))

   ;; -- a64 -----------------------------------------------------------
   ;; the table is 16 entries of 0x80 bytes, 2 KiB-aligned. we run at EL1 on SP_EL1, so only
   ;; the "current EL with SP_ELx" group can fire: 0x200 sync, 0x280 IRQ, 0x300 FIQ, 0x380
   ;; SError. IRQs funnel to k_irq, everything else to a_fault (report + halt) -- the twelve
   ;; that cannot fire included, so a surprise reports rather than running into padding.
   a-slots '(a_fault a_fault a_fault a_fault      ; current EL, SP_EL0: sync IRQ FIQ SError
             a_fault a_irq   a_fault a_fault      ; current EL, SP_ELx
             a_fault a_fault a_fault a_fault      ; lower EL, a64
             a_fault a_fault a_fault a_fault)     ; lower EL, aarch32
   ;; the IRQ path saves the caller-saved GPRs (x0..x18) plus x29/x30; k_irq is AAPCS, so it
   ;; preserves x19..x28 itself. 21 slots rounded to 176 keeps sp 16-byte aligned. single
   ;; str/ldr rather than stp/ldp: twice the words, no scratch, and every offset stays inside
   ;; the 12-bit scaled immediate, so the far lane never borrows x16.
   a-save '(r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14 r15 r16 r17 r18 fp lr)
   a-frame 176
   (a-slot-off i) (8 * i)
   a-push (v-mapi (\ i r ['st 'sp (a-slot-off i) r]) a-save)
   a-pop  (v-mapi (\ i r ['ld r 'sp (a-slot-off i)]) a-save)
   ;; the align rides after each slot, the last included, so the table is exactly the
   ;; 16 x 0x80 the architecture defines and the handlers start past it. packing the handler
   ;; into the sixteenth slot's tail would save 124 bytes; a whole table is worth them.
   a-text
    (foldl (\ a s (a + [['jmp s] ['align 128]])) [['label 'vectors]] a-slots
     ;; the CPU masks DAIF.I on entry, so the handler cannot nest and ELR_EL1/SPSR_EL1 stay
     ;; valid across the call; eret returns through them.
     + [['label 'a_irq] ['sub 'sp 'sp a-frame]]
     + a-push
     + '((call k_irq))
     + a-pop
     + [['add 'sp 'sp a-frame] ['eret]]
     ;; the fault path: ESR/ELR/FAR to k_fault, which reports and halts. like x64's
     ;; k_exception, faults are not resumed.
     + '((label a_fault)
         (mrs r0 esr_el1)
         (mrs r1 elr_el1)
         (mrs r2 far_el1)
         (call k_fault)
         (label a_halt)
         (wfi)
         (jmp a_halt)))

   ;; -- rv64 ------------------------------------------------------------
   ;; one entry, direct mode: stvec's low two bits pick it, so `vectors` only has to be
   ;; 4-aligned. the hart masks sstatus.SIE on the way in and sret restores it from SPIE,
   ;; so sepc/scause/stval hold across the call and the handler cannot nest. k_trap sorts
   ;; the cause: an interrupt returns here, a fault reports and halts.
   ;; saved: the caller-saved file -- ra, t0..t4, a0..a7 -- and the two scratches x30/x31,
   ;; which the abstract file does not name: x30 holds a cmp's flags until its br, and an
   ;; interrupt lands anywhere. k_trap is ABI, so s0..s11 are its own to keep. 16 slots
   ;; is 128 bytes, and sp stays 16-aligned.
   r-save '(lr r8 r9 r10 r11 r12 r0 r1 r2 r3 r4 r5 r6 r7)
   r-frame 128
   ;; sd/ld of the two unnamed registers against sp, as words: S-form splits the offset
   ;; 11:5 / 4:0, I-form carries it whole.
   (r-sd rs2 off) (le32 (((off >> 5) << 25) | (rs2 << 20) | (2 << 15) | (3 << 12)
                         | ((off & 31) << 7) | 0x23))
   (r-ld rd off)  (le32 ((off << 20) | (2 << 15) | (3 << 12) | (rd << 7) | 0x03))
   r-push (v-mapi (\ i r ['st 'sp (8 * i) r]) r-save
           + [['raw (r-sd 30 112)] ['raw (r-sd 31 120)]])
   r-pop  (v-mapi (\ i r ['ld r 'sp (8 * i)]) r-save
           + [['raw (r-ld 30 112)] ['raw (r-ld 31 120)]])
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
   ;; .text.vectors asks for 2048 because `vectors` goes straight into VBAR_EL1, which
   ;; ignores the low 11 bits: a table off its boundary dispatches into another entry.
   (lay-vec dst arch) (write-bytes dst (lay-vec-bytes arch))
   (lay-vec-bytes arch)
    (? (arch = "x64")
       (objsecs 'x64
                [[".text"   1 6 16 x-text]
                 [".data"   1 3 8  x-rodata]
                 [".bss"    8 3 16 x-bss]]
                '("archinit" "k_reset" "k_halt" "timer_isr" "keyboard_isr" "uart_isr")
                ()                       ; idt/isrs/idtreg are ours alone -- no C names them
                ()
                ;; the stubs and the common tail as local function symbols, so nm, gdb and
                ;; a fault backtrace all name them where a bare label could not.
                (x-stub-names + '("exc_common")))
       (arch = "a64")
       (objsecs 'a64
                [[".text.vectors" 1 6 2048 a-text]]
                '("vectors")             ; arch.c: extern uint8_t vectors[] -> VBAR_EL1
                () ()
                '("a_irq" "a_fault"))
       (arch = "rv64")
       (objsecs 'rv64
                [[".text" 1 6 16 r-text]]
                '("vectors")             ; arch.c: extern uint8_t vectors[] -> stvec
                () () ())
       (scare 'mkvec-arch arch)))
