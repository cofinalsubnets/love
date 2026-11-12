#include "../impl.h"

static __exitfn __atex[32];
static int __natex;
int atexit(void (*f)(void)) {
  if (__natex >= 32) return -1;
  __atex[__natex++] = f;
  return 0; }
extern __exitfn __fini_array_start[], __fini_array_end[];
void exit(int c) {
  while (__natex > 0) __atex[--__natex]();
  for (__exitfn *f = __fini_array_end; f > __fini_array_start; ) (*--f)();   /* the destructors, last first */
  fflush(0);
  _exit(c); }
