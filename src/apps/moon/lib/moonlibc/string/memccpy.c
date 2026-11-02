#include "../impl.h"

/* copy through the first c: answers past it, or 0 when n ran out */
void *memccpy(void *d, void const *s, int c, size_t n) {
  unsigned char *a = d;
  unsigned char const *b = s;
  for (size_t i = 0; i < n; i++)
    if ((a[i] = b[i]) == (unsigned char) c) return a + i + 1;
  return 0; }
