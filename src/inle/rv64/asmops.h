// asmops -- the rv64 privileged instructions, one inline each, in the GNU templates mooncc
// lowers through holo/gas.l (abi names, off(base), csr pseudos); call sites say the name
#pragma once
#include <stdint.h>

static inline void k_wait(void)  { asm volatile ("wfi"); }
// fence iorw, iorw: around a DMA ring's publish and read
static inline void k_fence(void) { asm volatile ("fence" ::: "memory"); }

static inline uint64_t k_rd_time(void) {
  uint64_t v; asm volatile ("csrr %0, time" : "=r"(v)); return v; }
static inline void k_wr_stvec(uintptr_t v) {
  asm volatile ("csrw stvec, %0" :: "r"(v) : "memory"); }
static inline void k_sie_set(uint64_t bits) {
  asm volatile ("csrs sie, %0" :: "r"(bits) : "memory"); }
// sstatus.SIE is bit 2 to the immediate forms
static inline void k_sie_on(void)  { asm volatile ("csrsi sstatus, 2" ::: "memory"); }
static inline void k_sie_off(void) { asm volatile ("csrci sstatus, 2" ::: "memory"); }

// sbi: a7 the extension, a6 the function, a0/a1 in, (error, value) out
#define SBI_TIME 0x54494D45
#define SBI_SRST 0x53525354
static inline int64_t k_sbi(uint64_t ext, uint64_t fn, uint64_t a0, uint64_t a1) {
  register uint64_t x10 asm("a0") = a0, x11 asm("a1") = a1,
                    x16 asm("a6") = fn, x17 asm("a7") = ext;
  asm volatile ("ecall" : "+r"(x10), "+r"(x11) : "r"(x16), "r"(x17) : "memory");
  return (int64_t) x10; }

// the `fault` builtin's backend
static inline void k_ebreak(void) { asm volatile ("ebreak"); }
// the 32-bit unimp: a csrrw to the read-only cycle csr
static inline void k_unimp(void)  { asm volatile ("unimp"); }
