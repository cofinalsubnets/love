#include "../impl.h"
#include <setjmp.h>

void longjmp(jmp_buf b, int v) { siglongjmp(b, v); }
void _longjmp(jmp_buf b, int v) { siglongjmp(b, v); }

#ifdef __wasm__
// wasmfn lays the calls of these two names itself: a throw, and the save of an activation
__attribute__((noinline)) void __love_wthrow(long *b) { (void) b; }
int __sigsetjmp(sigjmp_buf b, int save) { (void) b; (void) save; return 0; }
void siglongjmp(sigjmp_buf b, int v) {
  b[3] = v ? v : 1;
  __love_wthrow(b);
  for (;;); }
#endif
