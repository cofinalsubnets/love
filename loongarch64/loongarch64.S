// loongarch64 exception/interrupt vector. archinit (arch.c) writes
// &trap_vec into EENTRY (CSR 0xC) with ECFG.VS=0, which routes every
// exception class -- timer interrupt, BRK, INE, page faults, etc. --
// through this single entry point; k_trap_c switches on ESTAT.Ecode.
// LoongArch keeps a single SP across PLVs and we already run on the
// kernel stack, so trap entry just reserves a frame on it. CRMD.IE is
// cleared automatically on entry (PRMD captures the prior PIE), so no
// nesting can occur and ESTAT/ERA/BADV stay stable across the call.
//
// TLB refill exceptions are handled separately: they go through
// TLBRENTRY (CSR 0x88), which Limine pre-configures with its own
// refill handler that walks the page tables Limine set up. We leave
// that alone, so this vector only sees regular synchronous exceptions
// and interrupts.
//
// k_trap_c is LP64 ELF v2 ABI: it preserves callee-saved regs ($s0-$s8,
// $fp) itself, so the stub only saves the caller-saved set ($ra,
// $a0-$a7, $t0-$t8). ertn restores PLV/IE from PRMD and PC from ERA.
//
// EENTRY must be 4KiB-aligned.

.section .text.vectors, "ax"
.balign 4096
.global trap_vec
trap_vec:
  addi.d  $sp, $sp, -160                // 18 saved + 2 slots padding -> 16B-aligned
  st.d    $ra, $sp, 0
  st.d    $a0, $sp, 8
  st.d    $a1, $sp, 16
  st.d    $a2, $sp, 24
  st.d    $a3, $sp, 32
  st.d    $a4, $sp, 40
  st.d    $a5, $sp, 48
  st.d    $a6, $sp, 56
  st.d    $a7, $sp, 64
  st.d    $t0, $sp, 72
  st.d    $t1, $sp, 80
  st.d    $t2, $sp, 88
  st.d    $t3, $sp, 96
  st.d    $t4, $sp, 104
  st.d    $t5, $sp, 112
  st.d    $t6, $sp, 120
  st.d    $t7, $sp, 128
  st.d    $t8, $sp, 136

  csrrd   $a0, 0x5                      // ESTAT  (cause)
  csrrd   $a1, 0x6                      // ERA    (return PC)
  csrrd   $a2, 0x7                      // BADV   (faulting VA, if any)
  bl      k_trap_c

  ld.d    $ra, $sp, 0
  ld.d    $a0, $sp, 8
  ld.d    $a1, $sp, 16
  ld.d    $a2, $sp, 24
  ld.d    $a3, $sp, 32
  ld.d    $a4, $sp, 40
  ld.d    $a5, $sp, 48
  ld.d    $a6, $sp, 56
  ld.d    $a7, $sp, 64
  ld.d    $t0, $sp, 72
  ld.d    $t1, $sp, 80
  ld.d    $t2, $sp, 88
  ld.d    $t3, $sp, 96
  ld.d    $t4, $sp, 104
  ld.d    $t5, $sp, 112
  ld.d    $t6, $sp, 120
  ld.d    $t7, $sp, 128
  ld.d    $t8, $sp, 136
  addi.d  $sp, $sp, 160
  ertn
