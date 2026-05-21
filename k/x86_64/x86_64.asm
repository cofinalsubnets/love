global keyboard_isr
global uart_isr
global timer_isr
global archinit
global k_reset
global k_halt
extern kticks
extern kb_int
extern k_uart                 ; COM1 serial RX handler (arch.c)
extern k_exception            ; C exception dispatcher

%define INTERRUPT 0x8e
%define TRAP 0x8f

%macro push15 0
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
%endmacro

%macro pop15 0
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
%endmacro

%macro isr_stub 1
  push15
  call %1
  pop15
  iretq
%endmacro

; --- CPU exception stubs ---------------------------------------------
; vectors 0..31. on a fault some vectors push a CPU error code and some
; don't; each stub normalizes the stack to a uniform frame -- the
; no-error vectors push a dummy 0 -- then records the vector number and
; funnels to exc_common. error-code vectors: 8 10 11 12 13 14 17 21 29 30.

%macro exc_noerr 1
exc_stub_%1:
  push 0                      ; dummy error code: keep every frame uniform
  push %1                     ; vector number
  jmp exc_common
%endmacro

%macro exc_err 1
exc_stub_%1:
  push %1                     ; vector number (CPU already pushed error code)
  jmp exc_common
%endmacro

section .bss
align 8
idt:
  resq 512
kbq:
  resb 8
kbq_len:
  resb 1

section .rodata
align 8
isrs:
%assign v 0
%rep 32
  dq exc_stub_ %+ v           ; vectors 0..31: CPU exceptions
%assign v v+1
%endrep
  dq timer_isr                ; vector 32: IRQ0  PIT timer
  dq keyboard_isr             ; vector 33: IRQ1  PS/2 keyboard
  dq k_reset                  ; vector 34: IRQ2
  dq k_reset                  ; vector 35: IRQ3
  dq uart_isr                 ; vector 36: IRQ4  COM1 serial
  times 11 dq k_reset         ; vectors 37..47: unused IRQs -> reboot

align 8
isr_types:
  times  2 db TRAP
  times  1 db INTERRUPT ; NMI
  times 29 db TRAP
  times  2 db INTERRUPT ; vec 32,33: PIT timer & PS/2 keyboard
  times  2 db TRAP      ; vec 34,35: IRQ2, IRQ3
  times  1 db INTERRUPT ; vec 36: COM1 serial (IRQ4)
  times 11 db TRAP      ; vec 37..47

section .text

; generate exc_stub_0 .. exc_stub_31
%assign v 0
%rep 32
  %if v == 8 || v == 10 || v == 11 || v == 12 || v == 13 || v == 14 || v == 17 || v == 21 || v == 29 || v == 30
    exc_err v
  %else
    exc_noerr v
  %endif
%assign v v+1
%endrep

; common tail for every CPU exception. after push15 the stack from rsp
; upward is the k_frame the C handler receives in rdi:
;   r15 r14 r13 r12 r11 r10 r9 r8 rdi rsi rdx rcx rbx rax rbp  (push15)
;   vector  error                                              (stub)
;   rip cs rflags rsp ss                                       (CPU)
; rsp is 16-byte aligned at the call: the CPU aligns it on entry, and
; the exception frame + push15 preserve that, satisfying the SysV ABI.
align 8
exc_common:
  push15
  mov rdi, rsp                ; rdi -> k_frame
  call k_exception            ; <-- fill out in C; switch on frame->vector
  pop15
  add rsp, 16                 ; discard vector + error code
  iretq                       ; resume (a fatal handler simply never returns)

align 8
timer_isr:
; this is basically minimal. increment tick counter and reopen timer interrupts.
; if we want to do more we will probably need to push/pop15.
  inc qword [rel kticks]
  push rax
  mov al, 0x20
  out 0x20, al
  pop rax
  iretq

align 8
keyboard_isr:
  push15
  in al, 0x60
  movzx rdi, al
  call kb_int
  mov al, 0x20
  out 0x20, al
  pop15
  iretq

; COM1 serial receive (IRQ4 -> vector 36). k_uart drains the UART FIFO
; into the input queue; serial bytes share the keyboard path from there.
; push15 after the CPU's exception frame leaves rsp 16-byte aligned at
; the call, satisfying the SysV ABI.
align 8
uart_isr:
  push15
  call k_uart
  mov al, 0x20                ; EOI to the master PIC (IRQ4)
  out 0x20, al
  pop15
  iretq

align 8
archinit:
  ; populate IDT
  lea rdi, [rel idt]
  lea rcx, [rel isrs]
  lea rdx, [rel isr_types]
  mov rax, rdx
.idt_entry:
  ; store three parts of isr pointer
  mov rbx, qword [rcx]
  mov [rdi], word bx ; low
  sar rbx, 16
  mov [rdi + 6], word bx ; mid
  sar rbx, 16
  mov [rdi + 8], dword ebx ; high
  ; store other fields
  mov [rdi + 2], dword 0x28 ; 0x28 is the segment selector, mov dword zeroes out ist offset as well
  mov bl, byte [rdx] ; type attributes
  mov [rdi + 5], byte bl
  inc rdx
  add rcx, 8
  add rdi, 16
  cmp rcx, rax
  jne .idt_entry

  ; load IDT
  push idt
  push word 4095 ; sizeof idt - 1
  lidt [rsp]
  add rsp, 10

  ; configure PIT
  mov al, 0x36
  out 0x43, al
  mov dx, 0x40 ; store to dx instead of dl so dh is subsequently 0
  mov al, 0x9b
  out dx, al
  mov al, 0x2e
  out dx, al

  ; start PIC init -- each will now want 3 more bytes
  mov al, 0x11
  out 0x20, al
  out 0xa0, al

  ; first two bytes to master
  mov dl, 0x21 ; master PIC data port number in dx
  mov al, 0x20
  out dx, al
  mov al, 4
  out dx, al

  ; first two bytes to slave
  mov dl, 0xa1 ; slave PIC data port number in dx
  mov al, 0x28
  out dx, al
  mov al, 2
  out dx, al

  ; last byte to each
  mov al, 1
  out 0x21, al
  out dx, al
  mov al, 0
  out 0x21, al
  out dx, al

  ; enable interrupts
  sti
  ret

k_reset:
  push 0
  push 0
  lidt [rsp]
  int 0
k_halt:
  cli
  hlt
  jmp k_halt
