/* src/apps/moon/lib/moonlibc/math/trans.c -- hypot, cbrt, exp2, log1p, expm1 and the inverse hyperbolics; the float forms go through double */
#include "../impl.h"
#include <math.h>

/* ---- the transcendentals past lm's floor ---- */
double hypot(double x, double y) {
  x = fabs(x); y = fabs(y);
  if (x - x != 0 && x == x) return x;
  if (y - y != 0 && y == y) return y;
  if (x != x || y != y) return x + y;
  if (x < y) { double t = x; x = y; y = t; }
  if (y == 0) return x;
  int e = ilogb(x);
  double a = ldexp(x, -e), b = ldexp(y, -e);
  return ldexp(sqrt(a * a + b * b), e); }
float hypotf(float x, float y) { double a = x, b = y; return (float) sqrt(a * a + b * b); }
double cbrt(double x) {
  if (x == 0 || x != x || x - x != 0) return x;
  double a = fabs(x), r = exp(log(a) / 3.0);
  r -= (r * r * r - a) / (3.0 * r * r);
  return copysign(r, x); }
float cbrtf(float x) { return (float) cbrt(x); }
double exp2(double x) { return pow(2.0, x); }
float exp2f(float x) { return (float) pow(2.0, x); }
/* Kahan's and Goldberg's: the rounding of 1+x undone by the same rounding inside log/exp */
double log1p(double x) {
  volatile double u = 1.0 + x;
  if (u == 1.0) return x;
  return log(u) * x / (u - 1.0); }
double expm1(double x) {
  if (fabs(x) < 1e-5) return x + x * x / 2 + x * x * x / 6;
  volatile double u = exp(x);
  if (u - u != 0) return u;
  if (u == 1.0) return x;
  if (u - 1.0 == -1.0) return -1.0;
  return (u - 1.0) * x / log(u); }
float log1pf(float x) { return (float) log1p(x); }
float expm1f(float x) { return (float) expm1(x); }
double asinh(double x) {
  double a = fabs(x);
  if (a > 268435456.0) return copysign(log(a) + M_LN2, x);
  return copysign(log1p(a + a * a / (1.0 + sqrt(1.0 + a * a))), x); }
double acosh(double x) {
  if (x < 1.0) return (x - x) / (x - x);
  if (x > 268435456.0) return log(x) + M_LN2;
  double t = x - 1.0;
  return log1p(t + sqrt(2.0 * t + t * t)); }
double atanh(double x) {
  double a = fabs(x);
  return copysign(0.5 * log1p(2.0 * a / (1.0 - a)), x); }
float asinhf(float x) { return (float) asinh(x); }
float acoshf(float x) { return (float) acosh(x); }
float atanhf(float x) { return (float) atanh(x); }
