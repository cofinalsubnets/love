#include "../impl.h"

/* xor with the needle in every lane turns its bytes to zeros, found by strlen's
 * (w - ones) & ~w & highs test; n bounds every load, so aligning is only for speed */
void *memchr(void const *p, int c, size_t n) {
  unsigned char const *s = p;
  unsigned char ch = (unsigned char) c;
  unsigned long k = LvOnes * ch;
  while (n && ((unsigned long) s & (sizeof(unsigned long) - 1))) {
    if (*s == ch) return (void *) s;
    s++; n--; }
  while (n >= sizeof(unsigned long)) {
    unsigned long w = *(unsigned long const *) s ^ k;
    if ((w - LvOnes) & ~w & LvHighs) break;
    s += sizeof(unsigned long); n -= sizeof(unsigned long); }
  for (; n; n--, s++) if (*s == ch) return (void *) s;
  return 0; }
