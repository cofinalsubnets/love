/* src/apps/moon/lib/moonlibc/math/trans.c -- hypot, cbrt, exp2, log1p, expm1 and the inverse hyperbolics */
#include "../impl.h"
#include <math.h>
#include "fpbits.h"

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
double cbrt(double x) {
  if (x == 0 || x != x || x - x != 0) return x;
  double a = fabs(x), r = exp(log(a) / 3.0);
  r -= (r * r * r - a) / (3.0 * r * r);
  return copysign(r, x); }
double exp2(double x) { return pow(2.0, x); }
/* Kahan's and Goldberg's: the rounding of 1+x undone by the same rounding inside log/exp */
double log1p(double x) {
  volatile double u = 1.0 + x;
  if (u == 1.0) return x;
  return log(u) * (x / (u - 1.0)); }
double expm1(double x) {
  if (fabs(x) < 1e-5) return x + x * x / 2 + x * x * x / 6;
  volatile double u = exp(x);
  if (u - u != 0) return u;
  if (u == 1.0) return x;
  if (u - 1.0 == -1.0) return -1.0;
  return (u - 1.0) * (x / log(u)); }
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
/* the float forms. double in software: on lm's float twins, each within 1.5 ulp (expm1f
 * and the hyperbolics miss that, so they keep the double route everywhere) */
float expm1f(float x) { return (float) expm1(x); }
#if fp_dsoft
float lm_sqrtf(float), lm_expf(float), lm_logf(float), lm_powf(float, float);
float hypotf(float x, float y) {
  x = fabsf(x); y = fabsf(y);
  if (x - x != 0 && x == x) return x;
  if (y - y != 0 && y == y) return y;
  if (x != x || y != y) return x + y;
  if (x < y) { float t = x; x = y; y = t; }
  if (y == 0) return x;
  int e = ilogbf(x);
  float a = ldexpf(x, -e), b = ldexpf(y, -e);
  return ldexpf(lm_sqrtf(a * a + b * b), e); }
float cbrtf(float x) {
  if (x == 0 || x != x || x - x != 0) return x;
  float a = fabsf(x), r = lm_expf(lm_logf(a) / 3.0f);
  r -= (r - a / (r * r)) / 3.0f;
  return copysignf(r, x); }
float exp2f(float x) { return lm_powf(2.0f, x); }
/* log of the rounded 1+x, less what the rounding added */
float log1pf(float x) {
  volatile float u = 1.0f + x;
  if (u == 1.0f) return x;
  return lm_logf(u) - ((u - 1.0f) - x) / u; }
#else
float hypotf(float x, float y) { double a = x, b = y; return (float) sqrt(a * a + b * b); }
float cbrtf(float x) { return (float) cbrt(x); }
float exp2f(float x) { return (float) pow(2.0, x); }
float log1pf(float x) { return (float) log1p(x); }
#endif
