#include "../impl.h"

/* pointers that agree mod the word (the xor) copy words after a byte head; ones that disagree
 * shift two aligned source words per stored word (little-endian), so no load is unaligned */
void *memcpy(void *d, void const *s, size_t n) {
  unsigned char *dp = d; unsigned char const *sp = s;
  if ((((unsigned long) dp ^ (unsigned long) sp) & (sizeof(unsigned long) - 1)) == 0) {
    while (n && ((unsigned long) dp & (sizeof(unsigned long) - 1))) {
      *dp++ = *sp++; n--; }
    unsigned long *dw = (unsigned long *) dp;
    unsigned long const *sw = (unsigned long const *) sp;
    while (n >= 4 * sizeof(unsigned long)) {
      dw[0] = sw[0]; dw[1] = sw[1]; dw[2] = sw[2]; dw[3] = sw[3];
      dw += 4; sw += 4; n -= 4 * sizeof(unsigned long); }
    while (n >= sizeof(unsigned long)) { *dw++ = *sw++; n -= sizeof(unsigned long); }
    dp = (unsigned char *) dw; sp = (unsigned char const *) sw; }
  else if (n >= 4 * sizeof(unsigned long)) {
    while ((unsigned long) dp & (sizeof(unsigned long) - 1)) { *dp++ = *sp++; n--; }
    unsigned long o = (unsigned long) sp & (sizeof(unsigned long) - 1);
    unsigned l = 8 * (unsigned) o, r = 8 * sizeof(unsigned long) - l;
    unsigned long *dw = (unsigned long *) dp;
    unsigned long const *sw = (unsigned long const *) (sp - o);
    unsigned long w = sw[0];            /* every load is an aligned word holding a byte copied */
    while (n >= 4 * sizeof(unsigned long)) {
      unsigned long a = sw[1], b = sw[2], c = sw[3], e = sw[4];
      dw[0] = w >> l | a << r; dw[1] = a >> l | b << r;
      dw[2] = b >> l | c << r; dw[3] = c >> l | e << r;
      w = e; dw += 4; sw += 4; n -= 4 * sizeof(unsigned long); }
    while (n >= sizeof(unsigned long)) {
      unsigned long a = *++sw;
      *dw++ = w >> l | a << r; w = a; n -= sizeof(unsigned long); }
    dp = (unsigned char *) dw; sp = (unsigned char const *) sw + o; }
  while (n--) *dp++ = *sp++;
  return d; }
