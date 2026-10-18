#include "../impl.h"

/* the word compare says whether, never which way: little-endian words order their bytes
 * backwards, so the byte loop after the differing word gives the answer */
int memcmp(void const *a, void const *b, size_t n) {
  unsigned char const *x = a, *y = b;
  if ((((unsigned long) x | (unsigned long) y) & (sizeof(unsigned long) - 1)) == 0) {
    unsigned long const *xw = (unsigned long const *) x, *yw = (unsigned long const *) y;
    while (n >= sizeof(unsigned long) && *xw == *yw) {
      xw++; yw++; n -= sizeof(unsigned long); }
    x = (unsigned char const *) xw; y = (unsigned char const *) yw; }
  while (n--) { if (*x != *y) return (int) *x - (int) *y; x++; y++; }
  return 0; }
