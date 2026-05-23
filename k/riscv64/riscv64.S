// riscv64 S-mode trap vector. archinit (arch.c) writes &trap_vec
// into stvec in direct mode -- one entry point for both interrupts
// and exceptions; k_trap_c switches on scause. RISC-V keeps a single
// SP across privilege modes, and we already run on the kernel stack,
// so trap entry just reserves a frame on it; sstatus.SIE is cleared
// automatically (SPIE captures the prior value), so no nesting can
// occur and the C handler sees a stable scause/sepc/stval.
//
// k_trap_c is AAPCS-compliant, so it preserves callee-saved regs by
// itself: the stub only saves the caller-saved ones (ra, t0-t6,
// a0-a7) belonging to the interrupted code. sret restores PC/PRIV
// from sepc/sstatus.SPP.

.section .text.trap, "ax"
.balign 4
.global trap_vec
trap_vec:
  addi  sp, sp, -128
  sd    ra,    0(sp)
  sd    t0,    8(sp)
  sd    t1,   16(sp)
  sd    t2,   24(sp)
  sd    t3,   32(sp)
  sd    t4,   40(sp)
  sd    t5,   48(sp)
  sd    t6,   56(sp)
  sd    a0,   64(sp)
  sd    a1,   72(sp)
  sd    a2,   80(sp)
  sd    a3,   88(sp)
  sd    a4,   96(sp)
  sd    a5,  104(sp)
  sd    a6,  112(sp)
  sd    a7,  120(sp)

  csrr  a0, scause
  csrr  a1, sepc
  csrr  a2, stval
  call  k_trap_c

  ld    ra,    0(sp)
  ld    t0,    8(sp)
  ld    t1,   16(sp)
  ld    t2,   24(sp)
  ld    t3,   32(sp)
  ld    t4,   40(sp)
  ld    t5,   48(sp)
  ld    t6,   56(sp)
  ld    a0,   64(sp)
  ld    a1,   72(sp)
  ld    a2,   80(sp)
  ld    a3,   88(sp)
  ld    a4,   96(sp)
  ld    a5,  104(sp)
  ld    a6,  112(sp)
  ld    a7,  120(sp)
  addi  sp, sp, 128
  sret
