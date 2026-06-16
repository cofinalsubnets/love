// x86_64 low-level support: CPU exception stubs, IRQ stubs (timer /
// PS/2 keyboard / COM1), and archinit (IDT + PIC + PIT). Pairs with
// arch.c, which provides the C-side handlers. Translated 1-to-1 from
// the original NASM source so clang's integrated assembler can build
// it without nasm in the loop.
//
// Calls to C use SysV register order (rdi for arg0).

.intel_syntax noprefix

.set INTERRUPT, 0x8e
.set TRAP,      0x8f

.global archinit
.global k_reset
.global k_halt
.global keyboard_isr
.global uart_isr
.global timer_isr

// --- push15 / pop15 --------------------------------------------------
// Save/restore every GPR except rsp. The stack from rsp upward after
// push15 is the k_frame layout exc_common hands to k_exception.
.macro push15
  push rbp
  push rax
  push rbx
  push rcx
  push rdx
  push rsi
  push rdi
  push r8
  push r9
  push r10
  push r11
  push r12
  push r13
  push r14
  push r15
.endm

.macro pop15
  pop r15
  pop r14
  pop r13
  pop r12
  pop r11
  pop r10
  pop r9
  pop r8
  pop rdi
  pop rsi
  pop rdx
  pop rcx
  pop rbx
  pop rax
  pop rbp
.endm

// --- BSS: IDT + (vestigial) kbq scratch -----------------------------
.bss
.balign 8
idt:
  .skip 4096                          // 256 entries * 16 bytes
kbq:
  .skip 8
kbq_len:
  .skip 1

// --- Read-only ISR pointer / type tables ----------------------------
// archinit walks isrs[] and isr_types[] in lockstep; isrs ending right
// before isr_types is what lets the loop exit on `cmp rcx, rax`.
.section .rodata
.balign 8
isrs:
  .quad exc_stub_0,  exc_stub_1,  exc_stub_2,  exc_stub_3
  .quad exc_stub_4,  exc_stub_5,  exc_stub_6,  exc_stub_7
  .quad exc_stub_8,  exc_stub_9,  exc_stub_10, exc_stub_11
  .quad exc_stub_12, exc_stub_13, exc_stub_14, exc_stub_15
  .quad exc_stub_16, exc_stub_17, exc_stub_18, exc_stub_19
  .quad exc_stub_20, exc_stub_21, exc_stub_22, exc_stub_23
  .quad exc_stub_24, exc_stub_25, exc_stub_26, exc_stub_27
  .quad exc_stub_28, exc_stub_29, exc_stub_30, exc_stub_31
  .quad timer_isr                     // 32: IRQ0  PIT
  .quad keyboard_isr                  // 33: IRQ1  PS/2
  .quad k_reset                       // 34: IRQ2
  .quad k_reset                       // 35: IRQ3
  .quad uart_isr                      // 36: IRQ4  COM1
  .rept 11
    .quad k_reset                     // 37..47: stray IRQ -> reboot
  .endr

.balign 8
isr_types:
  .byte TRAP, TRAP                    // vec 0, 1
  .byte INTERRUPT                     // vec 2: NMI
  .rept 29
    .byte TRAP                        // vec 3..31
  .endr
  .byte INTERRUPT, INTERRUPT          // vec 32 PIT, 33 PS/2
  .byte TRAP, TRAP                    // vec 34, 35
  .byte INTERRUPT                     // vec 36 COM1
  .rept 11
    .byte TRAP                        // vec 37..47
  .endr

// LIDT operands. RIP-relative loads keep this PIC-friendly (the NASM
// original push'd `idt` as an imm32, which doesn't fit for relocatable
// images that may land above 4 GiB).
.balign 2
.Lidtreg:
  .word 4095                          // limit: sizeof idt - 1
  .quad idt
.Lidtreg_null:
  .word 0                             // empty IDT -> int 0 triple-faults
  .quad 0

// --- Exception stubs -------------------------------------------------
// Vectors with a CPU-pushed error code are 8, 10..14, 17, 21, 29, 30.
// The rest push a dummy 0 so every frame has the same shape.
.text
.macro exc_noerr vec
exc_stub_\vec:
  push 0                              // dummy error code
  push \vec                           // vector number
  jmp exc_common
.endm

.macro exc_err vec
exc_stub_\vec:
  push \vec                           // CPU already pushed error code
  jmp exc_common
.endm

  exc_noerr 0
  exc_noerr 1
  exc_noerr 2
  exc_noerr 3
  exc_noerr 4
  exc_noerr 5
  exc_noerr 6
  exc_noerr 7
  exc_err   8
  exc_noerr 9
  exc_err   10
  exc_err   11
  exc_err   12
  exc_err   13
  exc_err   14
  exc_noerr 15
  exc_noerr 16
  exc_err   17
  exc_noerr 18
  exc_noerr 19
  exc_noerr 20
  exc_err   21
  exc_noerr 22
  exc_noerr 23
  exc_noerr 24
  exc_noerr 25
  exc_noerr 26
  exc_noerr 27
  exc_noerr 28
  exc_err   29
  exc_err   30
  exc_noerr 31

// --- Common exception tail -----------------------------------------
// After push15 the stack (rsp upward) is the k_frame the C handler
// receives in rdi:
//   r15 r14 r13 r12 r11 r10 r9 r8 rdi rsi rdx rcx rbx rax rbp  (push15)
//   vector  error                                              (stub)
//   rip cs rflags rsp ss                                       (CPU)
// rsp is 16-byte aligned at the call: the CPU aligns it on entry, and
// the exception frame + push15 preserve that, satisfying SysV.
.balign 8
exc_common:
  push15
  mov rdi, rsp                        // arg0 = k_frame*
  call k_exception
  pop15
  add rsp, 16                         // discard vector + error code
  iretq                               // (fatal handler never returns)

// --- Timer (IRQ0) --------------------------------------------------
// Minimal: bump the tick counter, EOI the primary PIC. If we ever do
// more we'll need push15/pop15 to preserve registers.
.balign 8
timer_isr:
  inc qword ptr [rip + kticks]
  push rax
  mov al, 0x20
  out 0x20, al
  pop rax
  iretq

// --- PS/2 keyboard (IRQ1) ------------------------------------------
.balign 8
keyboard_isr:
  push15
  in al, 0x60                         // read scancode
  movzx rdi, al
  call kb_int
  mov al, 0x20
  out 0x20, al
  pop15
  iretq

// --- COM1 RX (IRQ4) ------------------------------------------------
.balign 8
uart_isr:
  push15
  call k_uart
  mov al, 0x20                        // EOI primary PIC (IRQ4)
  out 0x20, al
  pop15
  iretq

// --- archinit ------------------------------------------------------
// Walk isrs/isr_types in lockstep, packing each (handler, type) pair
// into a 16-byte IDT descriptor. Then LIDT, configure the PIT for the
// 100-Hz tick, remap the PIC to 0x20/0x28, unmask, and STI.
.balign 8
archinit:
  // x87/SSE is enabled earlier, at the top of kmain (it must be on before
  // any C runs, since even limine_to_kboot's struct copies vectorize to
  // SSE). Nothing to do for the FPU here.
  lea rdi, [rip + idt]
  lea rcx, [rip + isrs]
  lea rdx, [rip + isr_types]
  mov rax, rdx                        // sentinel: rcx hits rdx@start = isr_types
  // Capture the bootloader's code selector so IDT entries point at a
  // segment that's actually valid in the current GDT. Limine leaves
  // cs = 0x28; OVMF leaves it = 0x38; the rest of the loop is shared.
  mov r9w, cs
  movzx r9d, r9w
.Lidt_entry:
  mov rbx, [rcx]
  mov word ptr [rdi], bx              // low 16 bits of handler
  sar rbx, 16
  mov word ptr [rdi + 6], bx          // mid 16 bits
  sar rbx, 16
  mov dword ptr [rdi + 8], ebx        // high 32 bits
  mov dword ptr [rdi + 2], r9d        // selector + IST/zero (attr filled below)
  mov bl, byte ptr [rdx]
  mov byte ptr [rdi + 5], bl          // type/attr
  inc rdx
  add rcx, 8
  add rdi, 16
  cmp rcx, rax
  jne .Lidt_entry

  lidt [rip + .Lidtreg]

  // PIT channel 0 in rate-generator mode (0x36), divisor 0x2e9b -> ~100 Hz.
  mov al, 0x36
  out 0x43, al
  mov dx, 0x40                        // store via dx (not dl) so dh=0
  mov al, 0x9b
  out dx, al
  mov al, 0x2e
  out dx, al

  // PIC init (ICW1, both controllers)
  mov al, 0x11
  out 0x20, al
  out 0xa0, al

  // primary ICW2/ICW3: vector base 0x20, secondary on IRQ2
  mov dl, 0x21
  mov al, 0x20
  out dx, al
  mov al, 4
  out dx, al

  // secondary ICW2/ICW3: vector base 0x28, cascade id 2
  mov dl, 0xa1
  mov al, 0x28
  out dx, al
  mov al, 2
  out dx, al

  // ICW4 (8086 mode) + interrupt mask = 0 (all unmasked)
  mov al, 1
  out 0x21, al
  out dx, al
  mov al, 0
  out 0x21, al
  out dx, al

  sti
  ret

// --- reset (triple-fault) / halt -----------------------------------
// LIDT a zero-size IDT, then int 0 -- the CPU can't dispatch the
// vector, escalates through #DF to triple fault, host reboots.
.balign 8
k_reset:
  lidt [rip + .Lidtreg_null]
  int 0
k_halt:
  cli
  hlt
  jmp k_halt
