// asmops -- the rv64 privileged instructions in GNU's template, one static
// inline each: the half of src/inle/asmops.h every compiler but mooncc takes.
// the x64 twin (src/inle/x64/asmops.h) opens with the why; the short version is
// that mooncc reads these lines too (src/core/holo/gas.l: the ABI register
// names, off(base) memory, the csr pseudos by name), and test/gate/asmops.sh
// compares them against the neutral half.
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
// answers (error, value) in a0/a1 and preserves the rest. the registers pin
// by declaration.
#define SBI_TIME 0x54494D45
#define SBI_SRST 0x53525354
static inline int64_t k_sbi(uint64_t ext, uint64_t fn, uint64_t a0, uint64_t a1) {
  register uint64_t x10 asm("a0") = a0, x11 asm("a1") = a1,
                    x16 asm("a6") = fn, x17 asm("a7") = ext;
  asm volatile ("ecall" : "+r"(x10), "+r"(x11) : "r"(x16), "r"(x17) : "memory");
  return (int64_t) x10; }

// --- deliberate faults (the `fault` builtin's backend) -----------------
static inline void k_ebreak(void) { asm volatile ("ebreak"); }
// the illegal instruction: the 32-bit `unimp` is a csrrw against `cycle`, a
// csr that cannot be written.
static inline void k_unimp(void)  { asm volatile ("unimp"); }
