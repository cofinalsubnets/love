#include "../impl.h"

void *bsearch(void const *key, void const *base, size_t n, size_t sz,
              int (*cmp)(void const *, void const *)) {
  char const *a = base;
  size_t lo = 0, hi = n;
  while (lo < hi) {
    size_t mid = lo + (hi - lo) / 2;
    int r = cmp(key, a + mid * sz);
    if (r == 0) return (void *) (a + mid * sz);
    if (r < 0) hi = mid; else lo = mid + 1; }
  return 0; }
