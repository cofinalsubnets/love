#include "../impl.h"

void *reallocarray(void *p, size_t n, size_t sz) {
  if (sz && n > (size_t) -1 / sz) { errno = ENOMEM; return 0; }
  return realloc(p, n * sz); }
