#include "../impl.h"

/* a block with its own mapping arrives zeroed from the kernel */
void *calloc(size_t n, size_t sz) {
  if (sz && n > (size_t) -1 / sz) { __errno_v = ENOMEM; return 0; }
  size_t t = n * sz;
  void *p = malloc(t);
  if (p && ((__mhdr *) p - 1)->next != __MDirect) memset(p, 0, t);
  return p; }
