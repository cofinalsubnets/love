/* src/apps/moon/lib/moonlibc/math/fmod.c -- fmod and remquo, exact on the bits; the float forms go through double */
#include "../impl.h"
#include <math.h>
#include "fpbits.h"

/* ---- fmod and remquo, exact: long division on the mantissas, a bit an exponent step ---- */
static int __unpack(u64 *u, int e) {              /* -> the exponent, *u the integer mantissa */
  if (e) { *u = (*u & (~0ULL >> 12)) | 1ULL << 52; return e; }
  int k = 0; u64 i = *u << 12;
  for (; i >> 63 == 0; k--, i <<= 1);
  *u <<= -k + 1; return k; }
static double __pack(u64 m, int e, u64 sx) {
  for (; m >> 52 == 0; m <<= 1, e--);
  if (e > 0) m = (m - (1ULL << 52)) | (u64) e << 52;
  else m >>= -e + 1;
  return dbl(m | sx); }
double fmod(double x, double y) {
  u64 ux = bits(x), uy = bits(y), sx = ux & SGN;
  int ex = (int) (ux >> 52 & 2047), ey = (int) (uy >> 52 & 2047);
  if ((uy << 1) == 0 || ex == 2047 || y != y) return (x * y) / (x * y);
  if ((ux << 1) <= (uy << 1)) return (ux << 1) == (uy << 1) ? 0 * x : x;
  ex = __unpack(&ux, ex); ey = __unpack(&uy, ey);
  for (; ex > ey; ex--) {
    u64 i = ux - uy;
    if (i >> 63 == 0) { if (i == 0) return 0 * x; ux = i; }
    ux <<= 1; }
  u64 i = ux - uy;
  if (i >> 63 == 0) { if (i == 0) return 0 * x; ux = i; }
  return __pack(ux, ex, sx); }
double remquo(double x, double y, int *quo) {
  u64 ux = bits(x), uy = bits(y);
  int sx = (int) (ux >> 63), sy = (int) (uy >> 63);
  int ex = (int) (ux >> 52 & 2047), ey = (int) (uy >> 52 & 2047);
  unsigned q = 0;
  *quo = 0;
  if ((uy << 1) == 0 || ex == 2047 || y != y) return (x * y) / (x * y);
  if ((ux << 1) == 0) return x;
  ex = __unpack(&ux, ex); ey = __unpack(&uy, ey);
  if (ex + 1 < ey) return x;                       /* far under y: x is its own remainder */
  if (ex >= ey) {
    for (; ex > ey; ex--) {
      u64 i = ux - uy;
      if (i >> 63 == 0) { ux = i; q++; }
      ux <<= 1; q <<= 1; }
    u64 i = ux - uy;
    if (i >> 63 == 0) { ux = i; q++; }
    if (ux == 0) ex = -60;
    else for (; ux >> 52 == 0; ux <<= 1, ex--); }
  if (ex > 0) ux = (ux - (1ULL << 52)) | (u64) ex << 52;
  else ux >>= -ex + 1;
  x = dbl(ux);                                    /* |x| reduced; then x or x - |y|, the nearer */
  double ay = fabs(y);
  if (ex == ey || (ex + 1 == ey && (2 * x > ay || (2 * x == ay && (q & 1))))) { x -= ay; q++; }
  q &= 0x7fffffff;
  *quo = sx ^ sy ? -(int) q : (int) q;
  return sx ? -x : x; }
double remainder(double x, double y) { int q; return remquo(x, y, &q); }
float remquof(float x, float y, int *q) { return (float) remquo(x, y, q); }
float remainderf(float x, float y) { int q; return (float) remquo(x, y, &q); }
