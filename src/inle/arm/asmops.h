// asmops for 32-bit arm (the cortex-m kernels): one static inline each
#pragma once
#include <stdint.h>

// kmain's wait: the board's own, as a polled seat may have nothing to interrupt a wfi
void k_idle(void);
static inline void k_wait(void) { k_idle(); }
static inline void k_isb(void)  { asm volatile ("isb" ::: "memory"); }
