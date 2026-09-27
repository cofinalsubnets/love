#include "../impl.h"

/* a downward move is memcpy's lanes walked backwards: same agreement test, same
 * byte head (off the tail this time), same quad, and pointers that disagree shift
 * two aligned words together per stored word. each quad loads before it stores,
 * so an overlap never reads a word it has written. */
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
  else if (n >= 4 * sizeof(unsigned long)) {
    while ((unsigned long) dp & (sizeof(unsigned long) - 1)) { *--dp = *--sp; n--; }
    unsigned long o = (unsigned long) sp & (sizeof(unsigned long) - 1);
    unsigned l = 8 * (unsigned) o, r = 8 * sizeof(unsigned long) - l;
    unsigned long *dw = (unsigned long *) dp;
    unsigned long const *sw = (unsigned long const *) (sp - o);
    unsigned long w = sw[0];            /* its low o bytes are the source's last */
    while (n >= 4 * sizeof(unsigned long)) {
      unsigned long a = sw[-1], b = sw[-2], c = sw[-3], e = sw[-4];
      dw[-1] = a >> l | w << r; dw[-2] = b >> l | a << r;
      dw[-3] = c >> l | b << r; dw[-4] = e >> l | c << r;
      w = e; dw -= 4; sw -= 4; n -= 4 * sizeof(unsigned long); }
    while (n >= sizeof(unsigned long)) {
      unsigned long a = *--sw;
      *--dw = a >> l | w << r; w = a; n -= sizeof(unsigned long); }
    dp = (unsigned char *) dw; sp = (unsigned char const *) sw + o; }
  while (n--) *--dp = *--sp;
  return d; }
