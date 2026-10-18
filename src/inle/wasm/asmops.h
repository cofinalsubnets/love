// asmops for wasm: there are no privileged instructions, so each goes out as a hypercall
// through the module's one import, __love_sys, under linux's number (arch.c)
#pragma once
#include <stdint.h>

// kmain's kwait (hlt, wfi): returns at the next tick or key; arch.c drains the keys
void k_idle(void);
static inline void k_wait(void) { k_idle(); }
