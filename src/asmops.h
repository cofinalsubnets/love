// asmops -- the privileged instructions, one static inline each. one folder means one
// name per file, so this picks the machine's set rather than a per-arch -I doing it.
#if defined(__x86_64__)
#include "x64_asmops.h"
#elif defined(__aarch64__)
#include "a64_asmops.h"
#elif defined(__riscv)
#include "rv64_asmops.h"
#endif
