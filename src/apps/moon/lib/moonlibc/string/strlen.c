#include "../impl.h"

/* (w - ones) & ~w & highs is nonzero iff some byte of w is zero. the align loop is required:
 * an unaligned word could cross past the NUL into an unmapped page, an aligned one cannot */
size_t strlen(char const *s) {
  char const *p = s;
  while ((unsigned long) p & (sizeof(unsigned long) - 1)) {
    if (!*p) return (size_t) (p - s);
    p++; }
  for (;;) {
    unsigned long w = *(unsigned long const *) p;
    if ((w - LvOnes) & ~w & LvHighs) break;
    p += sizeof(unsigned long); }
  while (*p) p++;
  return (size_t) (p - s); }
