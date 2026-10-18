#include "../impl.h"

void __pad(void (*put)(void *, int), void *ctx, int n, int ch) { while (n-- > 0) put(ctx, ch); }
int __fmtsgn(int neg, int fl) {
  return neg ? '-' : (fl & FfPlus) ? '+' : (fl & FfSpc) ? ' ' : 0; }
/* one integer field: the precision is a minimum digit count that retires the 0 flag, and
 * .0 of a zero is empty (C99 7.19.6.1p6) */
void __fmtnum(void (*put)(void *, int), void *ctx, unsigned long long v, unsigned base,
                     int neg, int prec, int width, int fl, int up) {
  char tmp[24];
  int nd = 0;
  int a = up ? 55 : 87;
  do { unsigned d = (unsigned) (v % base); tmp[nd++] = (char) (d < 10 ? 48 + d : a + d); v /= base; } while (v);
  if (!prec && nd == 1 && tmp[0] == '0') nd = 0;
  int zeros = prec > nd ? prec - nd : 0;
  int zf = (fl & FfZero) && prec < 0;
  int sgn = __fmtsgn(neg, fl);
  /* # shows the base, but not on digits already starting with a zero */
  char const *pre = "";
  if ((fl & FfAlt) && tmp[nd - 1] != '0') pre = base == 16 ? (up ? "0X" : "0x") : base == 8 ? "0" : "";
  int np = 0;
  while (pre[np]) np++;
  int len = nd + zeros + np + (sgn ? 1 : 0);
  int pad = width > len ? width - len : 0;
  if (!(fl & FfLeft) && !zf) __pad(put, ctx, pad, 32);
  if (sgn) put(ctx, sgn);
  for (int i = 0; i < np; i++) put(ctx, pre[i]);
  if (!(fl & FfLeft) && zf) __pad(put, ctx, pad, 48);
  __pad(put, ctx, zeros, 48);
  while (nd) put(ctx, tmp[--nd]);
  if (fl & FfLeft) __pad(put, ctx, pad, 32); }
