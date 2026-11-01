#include "../impl.h"

/* gnu: the first n-byte needle in h, an empty one at h */
void *memmem(void const *h, size_t hn, void const *n, size_t nn) {
  char const *p = h;
  if (!nn) return (void *) p;
  for (char const *e = p + hn; nn <= (size_t) (e - p); p++) {
    p = memchr(p, *(unsigned char const *) n, e - p - nn + 1);
    if (!p) return 0;
    if (!memcmp(p, n, nn)) return (void *) p; }
  return 0; }
