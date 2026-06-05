// aarch64 exception vectors. archinit (arch.c) points VBAR_EL1 here.
// the table is 16 entries of 0x80 bytes and must be 2KiB-aligned. we
// run at EL1 on SP_EL1, so only the "current EL with SP_ELx" group can
// fire: 0x200 sync, 0x280 IRQ, 0x300 FIQ, 0x380 SError. IRQs funnel to
// k_irq; everything else funnels to k_fault (report + halt). the other
// twelve entries cannot fire by construction but are routed to k_fault
// so a surprise still reports instead of running off into padding.

.section .text.vectors, "ax"
.balign 0x800
.global vectors
vectors:
.balign 0x80
  b   .Lfault             // current EL, SP_EL0: sync
.balign 0x80
  b   .Lfault             // current EL, SP_EL0: IRQ
.balign 0x80
  b   .Lfault             // current EL, SP_EL0: FIQ
.balign 0x80
  b   .Lfault             // current EL, SP_EL0: SError
.balign 0x80
  b   .Lfault             // current EL, SP_ELx: sync
.balign 0x80
  b   .Lirq               // current EL, SP_ELx: IRQ
.balign 0x80
  b   .Lfault             // current EL, SP_ELx: FIQ
.balign 0x80
  b   .Lfault             // current EL, SP_ELx: SError
.balign 0x80
  b   .Lfault             // lower EL, aarch64: sync
.balign 0x80
  b   .Lfault             // lower EL, aarch64: IRQ
.balign 0x80
  b   .Lfault             // lower EL, aarch64: FIQ
.balign 0x80
  b   .Lfault             // lower EL, aarch64: SError
.balign 0x80
  b   .Lfault             // lower EL, aarch32: sync
.balign 0x80
  b   .Lfault             // lower EL, aarch32: IRQ
.balign 0x80
  b   .Lfault             // lower EL, aarch32: FIQ
.balign 0x80
  b   .Lfault             // lower EL, aarch32: SError

// IRQ path. save the caller-saved GPRs (x0-x18) plus x29/x30 -- k_irq
// is AAPCS-compliant, so it preserves x19-x28 itself. the CPU masks
// DAIF.I on entry, so the handler cannot nest and ELR_EL1/SPSR_EL1
// stay valid across the call; eret returns through them.
.Lirq:
  sub  sp,  sp,  #(16*11)
  stp  x0,  x1,  [sp, #16*0]
  stp  x2,  x3,  [sp, #16*1]
  stp  x4,  x5,  [sp, #16*2]
  stp  x6,  x7,  [sp, #16*3]
  stp  x8,  x9,  [sp, #16*4]
  stp  x10, x11, [sp, #16*5]
  stp  x12, x13, [sp, #16*6]
  stp  x14, x15, [sp, #16*7]
  stp  x16, x17, [sp, #16*8]
  stp  x18, x29, [sp, #16*9]
  str  x30,      [sp, #16*10]
  bl   k_irq
  ldp  x0,  x1,  [sp, #16*0]
  ldp  x2,  x3,  [sp, #16*1]
  ldp  x4,  x5,  [sp, #16*2]
  ldp  x6,  x7,  [sp, #16*3]
  ldp  x8,  x9,  [sp, #16*4]
  ldp  x10, x11, [sp, #16*5]
  ldp  x12, x13, [sp, #16*6]
  ldp  x14, x15, [sp, #16*7]
  ldp  x16, x17, [sp, #16*8]
  ldp  x18, x29, [sp, #16*9]
  ldr  x30,      [sp, #16*10]
  add  sp,  sp,  #(16*11)
  eret

// fault path. pass ESR/ELR/FAR to k_fault, which reports and halts --
// like x86_64's k_exception, faults are not resumed.
.Lfault:
  mrs  x0, esr_el1
  mrs  x1, elr_el1
  mrs  x2, far_el1
  bl   k_fault
.Lhalt:
  wfi
  b    .Lhalt
