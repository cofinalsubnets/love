#include "impl.h"

/* the leaves no kernel answers, where mksys lays only the jumps (a bare isa) or nothing
 * (wasm, whose door is the page loader's): every door ENOSYS, no thread but the first */
#ifdef LvBare
long __love_sys(long n, long a, long b, long c, long d, long e, long f) { return -38; }
long __love_sys8(long n, long a, long b, long c, long d, long e, long f, long g, long h) { return -38; }
long long __love_sysw(long n, long a, long b, long c, long d, long e, long f) { return -38; }
#endif
#if defined(LvBare) || defined(__wasm__)
void __love_sigret(void) {}
long __love_clone(long flags, void *sp, int *ptid, int *ctid, void *tls) { return -38; }
void *__love_tp(void) { return 0; }
#endif
