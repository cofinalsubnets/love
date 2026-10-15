#include "../impl.h"

void *realloc(void *p, size_t n) {
  if (!p) return malloc(n);
  if (n == 0) { free(p); return 0; }
  size_t old = malloc_usable_size(p);
  if (old >= n) return p;
  void *q = malloc(n);
  if (!q) return 0;
  memcpy(q, p, old);
  free(p);
  return q; }
