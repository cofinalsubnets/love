/* the other compiler's half of the function pointer check: each answers 1 when every argument arrived.
   a double is held by its words: no helper, no pool */
#include <stdarg.h>
static int is(double d, unsigned hi) { union { double d; unsigned long long l; } u = {d}; return u.l == (unsigned long long) hi << 32; }
static int isf(float f, unsigned w) { union { float f; unsigned l; } u = {f}; return u.l == w; }
int nd(double x, ...) { return is(x, 0x40080000); }
int nf(float x, int y, ...) { return isf(x, 0x3fc00000) && y == 9; }
int nl(long long x, int y, ...) { return x == -5 && y == 9; }
int ns(short x, _Bool b, ...) { return x == 7 && b == 1; }
int un(int n, ...) {
  va_list a; va_start(a, n);
  double d = va_arg(a, double); int i = va_arg(a, int); double e = va_arg(a, double); va_end(a);
  return n == 3 && is(d, 0x3ff80000) && i == 7 && is(e, 0x40040000); }
int mix(double x, int n, ...) {
  va_list a; va_start(a, n); double d = va_arg(a, double); va_end(a);
  return is(x, 0x3fe00000) && n == 3 && is(d, 0x3ff80000); }
int many(int n, ...) {
  va_list a; va_start(a, n);
  int ok = 1;
  for (int i = 1; i <= n; i++) {   /* i's double, its high word */
    int e = i < 2 ? 0 : i < 4 ? 1 : i < 8 ? 2 : 3;
    if (!is(va_arg(a, double), (unsigned) (1023 + e) << 20 | ((unsigned) i << (20 - e) & 0xfffff))) ok = 0; }
  va_end(a);
  return ok; }
int fx(double x, int n, double y) { return is(x, 0x40080000) && n == 4 && is(y, 0x40040000); }
#ifndef SOFT   /* a K&R float narrows by a helper there */
int kr(a, b, c) float a; short b; double c; { return isf(a, 0x3fc00000) && b == 7 && is(c, 0x40040000); }
#endif
