// asmops for 32-bit arm (the cortex-m kernels): one static inline each
#pragma once
#include <stdint.h>

static inline void k_wait(void) { asm volatile ("wfi"); }
static inline void k_dsb(void)  { asm volatile ("dsb" ::: "memory"); }
static inline void k_isb(void)  { asm volatile ("isb" ::: "memory"); }
