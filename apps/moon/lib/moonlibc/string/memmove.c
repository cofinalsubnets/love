#include "../impl.h"

/* a downward move is memcpy's word lane walked backwards: same agreement test,
 * same byte head (off the tail this time), same quad. a plain byte loop here
 * costs 20x on any real overlap, and an image relocation is nothing else. */
void *memmove(void *d, void const *s, size_t n) {
  unsigned char *dp = d; unsigned char const *sp = s;
  if (dp == sp || n == 0) return d;
  if (dp < sp) return memcpy(d, s, n);
  dp += n; sp += n;
  if ((((unsigned long) dp ^ (unsigned long) sp) & (sizeof(unsigned long) - 1)) == 0) {
    while (n && ((unsigned long) dp & (sizeof(unsigned long) - 1))) {
      *--dp = *--sp; n--; }
    unsigned long *dw = (unsigned long *) dp;
    unsigned long const *sw = (unsigned long const *) sp;
    while (n >= 4 * sizeof(unsigned long)) {
      dw -= 4; sw -= 4; n -= 4 * sizeof(unsigned long);
      dw[3] = sw[3]; dw[2] = sw[2]; dw[1] = sw[1]; dw[0] = sw[0]; }
    while (n >= sizeof(unsigned long)) { *--dw = *--sw; n -= sizeof(unsigned long); }
    dp = (unsigned char *) dw; sp = (unsigned char const *) sw; }
  while (n--) *--dp = *--sp;
  return d; }
