// asmops -- the wasm "privileged instructions". there are none: the machine is the
// page's worker, and everything the kernel would say in assembler goes out through the
// module's one import, __ai_sys, as a hypercall wearing linux's number (inle/wasm/arch.c).
// what the other three asmops.h say once per operation, this one says once per name.
#pragma once
#include <stdint.h>

// the idle wait, kmain's kwait: the x64 twin is `hlt`, the a64 one `wfi`. here it is a
// hypercall that returns at the next tick or key, and arch.c drains the keys behind it.
void k_idle(void);
static inline void k_wait(void) { k_idle(); }
