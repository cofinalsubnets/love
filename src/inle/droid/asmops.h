// asmops -- the droid seat's privileged instructions: none. the machine is a linux process,
// and what the kernel would say in assembler is a real system call (src/inle/droid/arch.c).
#pragma once
#include <stdint.h>

// the idle wait, kmain's kwait: a poll on the keys until the next tick
void k_idle(void);
static inline void k_wait(void) { k_idle(); }
