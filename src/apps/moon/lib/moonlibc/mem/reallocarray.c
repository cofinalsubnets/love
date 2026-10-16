#include "../impl.h"

void *reallocarray(void *p, size_t n, size_t sz) {
  if (sz && n > (size_t) -1 / sz) { __errno_v = ENOMEM; return 0; }
  return realloc(p, n * sz); }
