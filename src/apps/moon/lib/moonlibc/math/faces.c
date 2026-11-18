#include "../impl.h"

/* libc math over lm.c; tan, log2, log10 and the hyperbolics are derived, a few ulp looser */
double lm_sqrt(double), lm_exp(double), lm_log(double);
double lm_sin(double), lm_cos(double), lm_atan2(double, double), lm_pow(double, double);
double lm_asin(double), lm_acos(double);
double sqrt(double x) { return lm_sqrt(x); }
double exp(double x) { return lm_exp(x); }
double log(double x) { return lm_log(x); }
double sin(double x) { return lm_sin(x); }
double cos(double x) { return lm_cos(x); }
double tan(double x) { return lm_sin(x) / lm_cos(x); }
double pow(double x, double y) { return lm_pow(x, y); }
double atan2(double y, double x) { return lm_atan2(y, x); }
double atan(double x) { return lm_atan2(x, 1.0); }
double asin(double x) { return lm_asin(x); }
double acos(double x) { return lm_acos(x); }
double log2(double x) { return lm_log(x) * 1.4426950408889634; }
double log10(double x) { return lm_log(x) * 0.4342944819032518; }
double sinh(double x) { double e = lm_exp(x); return (e - 1.0 / e) / 2.0; }
double cosh(double x) { double e = lm_exp(x); return (e + 1.0 / e) / 2.0; }
double tanh(double x) { double e = lm_exp(2.0 * x); return (e - 1.0) / (e + 1.0); }
double fabs(double x) { return x <= 0 ? 0.0 - x : x; }
double floor(double), ceil(double), fmod(double, double); /* fp.c's */
/* float twins: the double result narrowed once */
float sinf(float x) { return (float) sin(x); }
float cosf(float x) { return (float) cos(x); }
float tanf(float x) { return (float) tan(x); }
float asinf(float x) { return (float) asin(x); }
float acosf(float x) { return (float) acos(x); }
float atanf(float x) { return (float) atan(x); }
float expf(float x) { return (float) exp(x); }
float logf(float x) { return (float) log(x); }
float log2f(float x) { return (float) log2(x); }
float log10f(float x) { return (float) log10(x); }
float sqrtf(float x) { return (float) sqrt(x); }
float fabsf(float x) { return (float) fabs(x); }
float floorf(float x) { return (float) floor(x); }
float ceilf(float x) { return (float) ceil(x); }
float atan2f(float y, float x) { return (float) atan2(y, x); }
float powf(float x, float y) { return (float) pow(x, y); }
float fmodf(float x, float y) { return (float) fmod(x, y); }
double frexp(double x, int *e) {
  union { double d; unsigned long long u; } b;
  b.d = x;
  int ex = (int) ((b.u >> 52) & 2047);
  *e = 0;
  if (ex == 2047 || x == 0) return x;              /* inf/nan/0 ride through, *e 0 */
  if (ex == 0) {                                   /* denormal: normalize by 2^64 first */
    b.d = x * 18446744073709551616.0;
    ex = (int) ((b.u >> 52) & 2047) - 64; }
  *e = ex - 1022;
  b.u = (b.u & 0x800fffffffffffffull) | 0x3fe0000000000000ull;
  return b.d; }
static double __e2d(int n) {                       /* 2^n for normal n */
  union { double d; unsigned long long u; } b;
  b.u = ((unsigned long long) (n + 1023)) << 52;
  return b.d; }
double ldexp(double x, int n) {                    /* x * 2^n, clamped through the rim in steps */
  if (n > 1023) { x *= __e2d(1023); n -= 1023;
    if (n > 1023) { x *= __e2d(1023); n -= 1023; if (n > 1023) n = 1023; } }
  else if (n < -1022) { x *= __e2d(-969); n += 969;
    if (n < -1022) { x *= __e2d(-969); n += 969; if (n < -1022) n = -1022; } }
  return x * __e2d(n); }
