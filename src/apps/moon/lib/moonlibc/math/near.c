/* src/apps/moon/lib/moonlibc/math/near.c -- fmax, fmin, fdim, and the neighbours */
#include "../impl.h"
#include <math.h>
#include "fpbits.h"

/* ---- the comparisons: a nan loses to a number ---- */
double fmax(double x, double y) { return x >= y ? x : x < y ? y : y != y ? x : y; }
double fmin(double x, double y) { return x <= y ? x : x > y ? y : y != y ? x : y; }
double fdim(double x, double y) { return x != x || y != y ? x + y : x > y ? x - y : 0.0; }
float fmaxf(float x, float y) { return (float) fmax(x, y); }
float fminf(float x, float y) { return (float) fmin(x, y); }
float fdimf(float x, float y) { return (float) fdim(x, y); }

/* ---- the neighbours ---- */
double nextafter(double x, double y) {
  if (x != x || y != y) return x + y;
  if (x == y) return y;
  if (x == 0) return copysign(dbl(1), y);
  u64 u = bits(x);
  return dbl((x < y) == (x > 0) ? u + 1 : u - 1); }
float nextafterf(float x, float y) {
  if (x != x || y != y) return x + y;
  if (x == y) return y;
  if (x == 0) return copysignf(flt(1), y);
  unsigned u = fbits(x);
  return flt((x < y) == (x > 0) ? u + 1 : u - 1); }
double nexttoward(double x, long double y) { return nextafter(x, (double) y); }
float nexttowardf(float x, long double y) { return nextafterf(x, (float) y); }
