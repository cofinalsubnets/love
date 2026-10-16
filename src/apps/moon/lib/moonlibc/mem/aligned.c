#include "../impl.h"

/* a stand-in header tagged __MAlign before the aligned pointer leads back to the block */
void *aligned_alloc(size_t al, size_t n) {
  if (!al || (al & (al - 1))) { __errno_v = EINVAL; return 0; }
  if (al <= sizeof(__mhdr)) return malloc(n);
  if (n > ((size_t) -1 >> 1) - al) { __errno_v = ENOMEM; return 0; }
  char *p = malloc(n + al - sizeof(__mhdr));
  if (!p) return 0;
  char *a = (char *) (((unsigned long) p + al - 1) & ~(unsigned long) (al - 1));
  if (a != p) { __mhdr *s = (__mhdr *) a - 1; s->next = __MAlign; s->size = (size_t) (a - p) / sizeof(__mhdr); }
  return a; }
void *memalign(size_t al, size_t n) { return aligned_alloc(al, n); }
/* errno untouched */
int posix_memalign(void **pp, size_t al, size_t n) {
  if (!al || (al & (al - 1)) || al % sizeof(void *)) return EINVAL;
  int e = __errno_v;
  void *p = aligned_alloc(al, n);
  __errno_v = e;
  if (!p) return ENOMEM;
  *pp = p;
  return 0; }
size_t malloc_usable_size(void *p) {
  if (!p) return 0;
  __mhdr *b = __mblock(p, "malloc_usable_size");
  return (__munits(b) - 1) * sizeof(__mhdr) - (size_t) ((char *) p - (char *) (b + 1)); }
