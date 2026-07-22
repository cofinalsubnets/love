@ mps2-an500 boot: the vector table (initial SP + reset), the FPU gate, and
@ the semihosting trampoline. qemu -kernel loads the ELF segments straight
@ into RAM (so .data needs no copy and fresh RAM is zero -- .bss included);
@ the M7 boots from the vectors at 0. CPACR must open CP10/CP11 before any
@ VFP instruction or the core locks up ("can't escalate 3 to HardFault").
.syntax unified
.cpu cortex-m7
.fpu fpv5-d16
.thumb

.section .vectors,"a"
.word __stack_top__
.word _start+1
.rept 14                    @ NMI..SysTick: any fault exits 98 -- loud, not a lockup
.word _fault+1
.endr

.text
.thumb_func
.global _start
_start:
  ldr r0, =0xE000ED88
  ldr r1, [r0]
  orr r1, r1, #0xF00000
  str r1, [r0]
  dsb
  isb
  bl main
  b .                       @ main never returns (m7_exit leaves through qemu)

@ uintptr_t sh_call(uintptr_t op, uintptr_t arg) -- AAPCS already placed
@ op/arg in r0/r1; the trap answers in r0.
.thumb_func
.global sh_call
sh_call:
  bkpt 0xAB
  bx lr

.thumb_func
_fault:                     @ hand the stacked frame to C: prints pc/lr, exits 98
  mov r0, sp
  bl fault_report
  b .
