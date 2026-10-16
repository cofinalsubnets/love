// asmops -- droid has no privileged instructions: the machine is a linux process (arch.c)
#pragma once
#include <stdint.h>

// kmain's kwait: a poll on the keys until the next tick
void k_idle(void);
static inline void k_wait(void) { k_idle(); }
