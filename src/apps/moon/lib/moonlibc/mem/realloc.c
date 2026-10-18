#include "../impl.h"
#include <sys/mman.h>

/* grows in place where it can: an arena block into its free neighbour, a mapping by
 * mremap (linux only); anything else copies */
void *realloc(void *p, size_t n) {
  if (!p) return malloc(n);
  if (n == 0) { free(p); return 0; }
  size_t old = malloc_usable_size(p);
  if (old >= n) return p;
  if (n > ((size_t) -1 >> 1) - 65536) { __errno_v = ENOMEM; return 0; }
  __mhdr *b = __mblock(p, "realloc");
  size_t nu = (n + sizeof(__mhdr) - 1) / sizeof(__mhdr) + 1;
  if (p == (void *) (b + 1)) {
    if (b->next == __MLive) { if (__mgrow(b, nu)) return p; }
    else if (b->next == __MDirect) {
      int e = __errno_v;
      size_t len = b->size * sizeof(__mhdr), nlen = (nu * sizeof(__mhdr) + 4095UL) & ~4095UL;
      void *m = mremap(b, len, nlen, MREMAP_MAYMOVE);
      if (m != (void *) -1) { __mhdr *u = m; u->size = nlen / sizeof(__mhdr); return (void *) (u + 1); }
      __errno_v = e; } }
  void *q = malloc(n);
  if (!q) return 0;
  memcpy(q, p, old);
  free(p);
  return q; }
