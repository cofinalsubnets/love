#include "../impl.h"

/* the fill and stride ride sizeof(long): a literal shift by 32 is undefined on 32-bit targets */
void *memset(void *d, int c, size_t n) {
  unsigned char *dp = d;
  unsigned char b = (unsigned char) c;
  unsigned long v = b;
  for (size_t k = 8; k < sizeof(unsigned long) * 8; k <<= 1) v |= v << k;
  while (n && ((unsigned long) dp & (sizeof(unsigned long) - 1))) { *dp++ = b; n--; }
  {
    unsigned long *dw = (unsigned long *) dp;
    while (n >= 4 * sizeof(unsigned long)) {
      dw[0] = v; dw[1] = v; dw[2] = v; dw[3] = v;
      dw += 4; n -= 4 * sizeof(unsigned long); }
    while (n >= sizeof(unsigned long)) { *dw++ = v; n -= sizeof(unsigned long); }
    dp = (unsigned char *) dw; }
  while (n--) *dp++ = b;
  return d; }
