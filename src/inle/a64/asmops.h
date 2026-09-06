// asmops -- the a64 privileged instructions in GNU's ARM template, one static
// inline each: the half of src/inle/asmops.h every compiler but mooncc takes.
// the x64 twin (src/inle/x64/asmops.h) opens with the why; the short version is
// that mooncc reads these lines too (src/core/holo/gas.l: xN/sp/xzr, `#`
// immediates, [base, #off] memory, the sysreg and sys-op names as ARM spells
// them), and test/gate/asmops.sh compares them against the neutral half.
#pragma once
#include <stdint.h>

// --- barriers and the wait --------------------------------------------
static inline void k_isb(void)     { asm volatile ("isb" ::: "memory"); }
static inline void k_dsb_ish(void) { asm volatile ("dsb ish" ::: "memory"); }
// the idle wait, kmain's kwait; the x64 twin of this name is `hlt`.
static inline void k_wait(void)    { asm volatile ("wfi"); }

// --- system register reads --------------------------------------------
static inline uint64_t k_rd_ctr_el0(void) {
  uint64_t v; asm volatile ("mrs %0, ctr_el0" : "=r"(v)); return v; }
static inline uint64_t k_rd_mair_el1(void) {
  uint64_t v; asm volatile ("mrs %0, mair_el1" : "=r"(v)); return v; }
static inline uint64_t k_rd_ttbr1_el1(void) {
  uint64_t v; asm volatile ("mrs %0, ttbr1_el1" : "=r"(v)); return v; }
static inline uint64_t k_rd_cntfrq_el0(void) {
  uint64_t v; asm volatile ("mrs %0, cntfrq_el0" : "=r"(v)); return v; }

// --- system register writes -------------------------------------------
static inline void k_wr_cntp_tval_el0(uint64_t v) {
  asm volatile ("msr cntp_tval_el0, %0" :: "r"(v)); }
static inline void k_wr_cntp_ctl_el0(uint64_t v) {
  asm volatile ("msr cntp_ctl_el0, %0" :: "r"(v)); }
// the vector base, with the isb that makes it live before the next fetch.
static inline void k_wr_vbar_el1(uintptr_t v) {
  asm volatile ("msr vbar_el1, %0\n isb" :: "r"(v) : "memory"); }

// --- PSTATE fields (the msr-IMMEDIATE form) ---------------------------
static inline void k_daif_mask_all(void) {          // D, A, I, F all masked
  asm volatile ("msr daifset, #0xf"); }

static inline void k_daif_unmask_irq(void) {        // DAIF.I = 0
  asm volatile ("msr daifclr, #2"); }

// --- address translation and the TLB ----------------------------------
// AT writes its answer to PAR_EL1, and the isb is what makes it readable.
static inline uint64_t k_at_s1e1w_par(void *va) {
  uint64_t par;
  asm volatile ("at s1e1w, %1\n isb\n mrs %0, par_el1"
                : "=r"(par) : "r"(va) : "memory");
  return par; }

// invalidate the whole EL1 TLB, inner-shareable, with the barriers that make
// a just-written descriptor visible before and the new mapping usable after.
static inline void k_tlbi_all(void) {
  asm volatile ("dsb ish\n tlbi vmalle1is\n dsb ish\n isb" ::: "memory"); }

// --- cache maintenance (__clear_cache's two halves) -------------------
static inline void k_dc_cvau(uintptr_t p) {         // clean D to unification
  asm volatile ("dc cvau, %0" :: "r"(p) : "memory"); }
static inline void k_ic_ivau(uintptr_t p) {         // invalidate I
  asm volatile ("ic ivau, %0" :: "r"(p) : "memory"); }

// --- bring-up ---------------------------------------------------------
// EL1t -> EL1h: exception entry always switches to SP_EL1, so SP_EL1 must
// point at the current stack before anything can fault. SP_EL1 cannot be
// written by `msr` at EL1 (that is EL2+), so the idiom is capture SP, select
// SP_EL1, write SP. ONE asm block, so SP is never live-but-garbage across a
// memory access; the value is unchanged across the switch, so C carries on.
static inline void k_sp_to_el1h(void) {
  asm volatile ("mov x9, sp\n msr spsel, #1\n mov sp, x9"
                ::: "x9", "memory"); }

// CPACR_EL1.FPEN = 0b11, so C may use doubles. a bootloader can leave FPEN
// clear at EL1, which traps on the first FP register access.
static inline void k_fpen_enable(void) {
  asm volatile ("mrs x9, cpacr_el1\n"
                "orr x9, x9, #(3 << 20)\n"
                "msr cpacr_el1, x9\n"
                "isb"
                ::: "x9", "memory"); }

// --- deliberate faults (the `fault` builtin's backend) ----------------
static inline void k_brk0(void) { asm volatile ("brk #0"); }
static inline void k_udf0(void) { asm volatile ("udf #0"); }

// --- the two hypercall-shaped exits -----------------------------------
// ARM semihosting SYS_EXIT: x0 the operation, x1 the {reason, code} block,
// `hlt #0xf000` the trap. the two registers pin by declaration.
static inline void k_semihost_exit(volatile uint64_t *block) {
  register uint64_t op asm("x0") = 0x18;
  register uint64_t arg asm("x1") = (uint64_t) (uintptr_t) block;
  asm volatile ("hlt #0xf000" :: "r"(op), "r"(arg) : "memory"); }

// PSCI SYSTEM_RESET over HVC (what QEMU's 'virt' exposes). the function id
// rides x0 in and out.
static inline void k_psci_system_reset(void) {
  register uint64_t r0 asm("x0") = 0x84000009;
  asm volatile ("hvc #0" : "+r"(r0) :: "memory");
  (void) r0; }
