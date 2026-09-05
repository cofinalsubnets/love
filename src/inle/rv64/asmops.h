// asmops -- the rv64 privileged instructions, one static inline each, in BOTH
// inline-asm spellings. the x64 twin (src/inle/x64/asmops.h) opens with the why;
// the short version is that the kernel says the same thing to clang in GNU's
// template and to mooncc in holo's NEUTRAL text (src/core/holo/text.l -- mnemonic,
// then operands, one instruction per LINE; r0..r7 = a0..a7, r8..r12 = t0..t4,
// zr = x0), so the spelling lives here and the call sites say the NAME.
//
// riscv shares nearly everything: `csrr`/`csrw`/`csrs`/`csrsi`/`csrci`/`wfi`/
// `fence` read identically once each compiler has put its own register into %0,
// and holo carries the csr names (src/core/holo/rv64.l). what diverges is small:
//
// * the ops holo NAMES differently: `sys` for ecall and `trap` for ebreak (the
//   neutral names every backend shares), `sfence` for sfence.vma (no dot in a
//   neutral identifier).
// * the illegal instruction: GNU has `unimp`; the neutral surface writes a csr
//   that cannot be written -- csrrw against `cycle` is the same word.
// * a multi-instruction template separates on \n, NEVER `;` -- the neutral reader
//   takes `;` as a comment to end of line.
#pragma once
#include <stdint.h>

// --- the wait, and the fence -------------------------------------------
// the idle wait, kmain's kwait; the x64 twin of this name is `hlt`.
static inline void k_wait(void)  { asm volatile ("wfi"); }
// fence iorw, iorw: what a DMA ring needs around its publish and its read.
static inline void k_fence(void) { asm volatile ("fence" ::: "memory"); }

// --- csr reads and writes ----------------------------------------------
static inline uint64_t k_rd_time(void) {
  uint64_t v; asm volatile ("csrr %0, time" : "=r"(v)); return v; }
static inline void k_wr_stvec(uintptr_t v) {
  asm volatile ("csrw stvec, %0" :: "r"(v) : "memory"); }
static inline void k_sie_set(uint64_t bits) {
  asm volatile ("csrs sie, %0" :: "r"(bits) : "memory"); }
// sstatus.SIE, the one interrupt switch; the immediate forms take the bit as 2.
static inline void k_sie_on(void)  { asm volatile ("csrsi sstatus, 2" ::: "memory"); }
static inline void k_sie_off(void) { asm volatile ("csrci sstatus, 2" ::: "memory"); }

// --- the SBI call ------------------------------------------------------
// a7 the extension, a6 the function, a0/a1 its two arguments; the firmware
// answers (error, value) in a0/a1 and preserves the rest. GNU pins by declaring
// the registers; the neutral surface pins by constraint name.
#define SBI_TIME 0x54494D45
#define SBI_SRST 0x53525354
static inline int64_t k_sbi(uint64_t ext, uint64_t fn, uint64_t a0, uint64_t a1) {
#ifdef __mooncc__
  asm volatile ("sys" : "+r0"(a0), "+r1"(a1) : "r6"(fn), "r7"(ext) : "memory");
#else
  register uint64_t x10 asm("a0") = a0, x11 asm("a1") = a1,
                    x16 asm("a6") = fn, x17 asm("a7") = ext;
  asm volatile ("ecall" : "+r"(x10), "+r"(x11) : "r"(x16), "r"(x17) : "memory");
  a0 = x10;
#endif
  return (int64_t) a0; }

// --- deliberate faults (the `fault` builtin's backend) -----------------
static inline void k_ebreak(void) {
#ifdef __mooncc__
  asm volatile ("trap");
#else
  asm volatile ("ebreak");
#endif
}

static inline void k_unimp(void) {
#ifdef __mooncc__
  asm volatile ("csrw cycle, zr");
#else
  asm volatile ("unimp");
#endif
}
