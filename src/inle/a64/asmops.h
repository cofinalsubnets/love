// asmops -- the a64 privileged instructions, one static inline each, in GNU's template, which
// mooncc lowers through holo (src/love/holo/gas.l). `mov` with sp lowers to the ADD form (31 is
// xzr in ORR); a whole-system tlbi fills holo's zero-register slot
#pragma once
#include <stdint.h>

static inline void k_isb(void)     { asm volatile ("isb" ::: "memory"); }
static inline void k_dsb_ish(void) { asm volatile ("dsb ish" ::: "memory"); }
static inline void k_wait(void)    { asm volatile ("wfi"); }

static inline uint64_t k_rd_ctr_el0(void) {
  uint64_t v; asm volatile ("mrs %0, ctr_el0" : "=r"(v)); return v; }
static inline uint64_t k_rd_mair_el1(void) {
  uint64_t v; asm volatile ("mrs %0, mair_el1" : "=r"(v)); return v; }
static inline uint64_t k_rd_ttbr1_el1(void) {
  uint64_t v; asm volatile ("mrs %0, ttbr1_el1" : "=r"(v)); return v; }
static inline uint64_t k_rd_cntfrq_el0(void) {
  uint64_t v; asm volatile ("mrs %0, cntfrq_el0" : "=r"(v)); return v; }

static inline void k_wr_cntp_tval_el0(uint64_t v) {
  asm volatile ("msr cntp_tval_el0, %0" :: "r"(v)); }
static inline void k_wr_cntp_ctl_el0(uint64_t v) {
  asm volatile ("msr cntp_ctl_el0, %0" :: "r"(v)); }
static inline void k_wr_vbar_el1(uintptr_t v) {
  asm volatile ("msr vbar_el1, %0\n isb" :: "r"(v) : "memory"); }

static inline void k_daif_mask_all(void) {          // D, A, I, F all masked
  asm volatile ("msr daifset, #0xf"); }

static inline void k_daif_unmask_irq(void) {        // DAIF.I = 0
  asm volatile ("msr daifclr, #2"); }

// AT answers in PAR_EL1, readable after the isb
static inline uint64_t k_at_s1e1w_par(void *va) {
  uint64_t par;
  asm volatile ("at s1e1w, %1\n isb\n mrs %0, par_el1"
                : "=r"(par) : "r"(va) : "memory");
  return par; }

static inline void k_tlbi_all(void) {
  asm volatile ("dsb ish\n tlbi vmalle1is\n dsb ish\n isb" ::: "memory"); }

// __clear_cache's two halves
static inline void k_dc_cvau(uintptr_t p) {         // clean D to unification
  asm volatile ("dc cvau, %0" :: "r"(p) : "memory"); }
static inline void k_ic_ivau(uintptr_t p) {         // invalidate I
  asm volatile ("ic ivau, %0" :: "r"(p) : "memory"); }

// EL1t -> EL1h: exception entry uses SP_EL1, which msr cannot write at EL1, so capture sp,
// select SP_EL1, write sp -- in one asm block, so sp is never garbage across a memory access
static inline void k_sp_to_el1h(void) {
  asm volatile ("mov x9, sp\n msr spsel, #1\n mov sp, x9"
                ::: "x9", "memory"); }

// CPACR_EL1.FPEN = 0b11: a bootloader may leave fp trapping at EL1
static inline void k_fpen_enable(void) {
  asm volatile ("mrs x9, cpacr_el1\n"
                "orr x9, x9, #(3 << 20)\n"
                "msr cpacr_el1, x9\n"
                "isb"
                ::: "x9", "memory"); }

// the `fault` builtin's backend
static inline void k_brk0(void) { asm volatile ("brk #0"); }
static inline void k_udf0(void) { asm volatile ("udf #0"); }

// semihosting SYS_EXIT: x0 the operation, x1 the {reason, code} block
static inline void k_semihost_exit(volatile uint64_t *block) {
  register uint64_t op asm("x0") = 0x18;
  register uint64_t arg asm("x1") = (uint64_t) (uintptr_t) block;
  asm volatile ("hlt #0xf000" :: "r"(op), "r"(arg) : "memory"); }

// PSCI SYSTEM_RESET over hvc, as qemu's virt exposes it
static inline void k_psci_system_reset(void) {
  register uint64_t r0 asm("x0") = 0x84000009;
  asm volatile ("hvc #0" : "+r"(r0) :: "memory");
  (void) r0; }
