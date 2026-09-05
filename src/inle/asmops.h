// asmops -- the privileged instructions, one static inline each. the machine is picked
// off a predefine, not a per-arch -I, so every seat compiles with one flag set.
#if defined(__x86_64__)
#include "x64/asmops.h"
#elif defined(__aarch64__)
#include "a64/asmops.h"
#elif defined(__riscv)
#include "rv64/asmops.h"
#endif
