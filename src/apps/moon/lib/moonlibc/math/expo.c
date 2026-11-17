/* src/apps/moon/lib/moonlibc/math/expo.c -- the exponent: scalbn, ilogb, logb, modf */
#include "../impl.h"
#include <math.h>
#include <limits.h>
#include "fpbits.h"

/* ---- the exponent ---- */
double scalbn(double x, int n) { return ldexp(x, n); }
double scalbln(double x, long n) { return ldexp(x, n > INT_MAX ? INT_MAX : n < INT_MIN ? INT_MIN : (int) n); }
static float __e2f(int n) { return flt((unsigned) (n + 127) << 23); }   /* 2^n for normal n */
float ldexpf(float x, int n) {                   /* ldexp's steps, at float's rims */
  if (n > 127) { x *= __e2f(127); n -= 127;
    if (n > 127) { x *= __e2f(127); n -= 127; if (n > 127) n = 127; } }
  else if (n < -126) { x *= __e2f(-102); n += 102;
    if (n < -126) { x *= __e2f(-102); n += 102; if (n < -126) n = -126; } }
  return x * __e2f(n); }
float scalbnf(float x, int n) { return ldexpf(x, n); }
float frexpf(float x, int *e) {
  unsigned u = fbits(x); int ex = (int) (u >> 23 & 255);
  *e = 0;
  if (ex == 255 || x == 0) return x;
  if (ex == 0) { u = fbits(x * 4294967296.0f); ex = (int) (u >> 23 & 255) - 32; }   /* a denormal, by 2^32 */
  *e = ex - 126;
  return flt((u & 0x807fffffu) | 0x3f000000u); }
long double ldexpl(long double x, int n) { return ldexp(x, n); }
long double frexpl(long double x, int *e) { return frexp(x, e); }
int ilogb(double x) {
  if (x != x || x == 0) return INT_MIN;
  if (x - x != 0) return INT_MAX;
  int e; frexp(x, &e); return e - 1; }
int ilogbf(float x) {
  if (x != x || x == 0) return INT_MIN;
  if (x - x != 0) return INT_MAX;
  int e; frexpf(x, &e); return e - 1; }
double logb(double x) {
  if (x != x) return x;
  if (x == 0) return -1.0 / 0.0;
  if (x - x != 0) return fabs(x);
  return (double) ilogb(x); }
float logbf(float x) {
  if (x != x) return x;
  if (x == 0) return -1.0f / 0.0f;
  if (x - x != 0) return fabsf(x);
  return (float) ilogbf(x); }
double modf(double x, double *ip) {
  if (x != x) { *ip = x; return x; }
  if (x - x != 0) { *ip = x; return copysign(0.0, x); }
  double t = trunc(x); *ip = t; return copysign(x - t, x); }
float modff(float x, float *ip) {
  if (x != x) { *ip = x; return x; }
  if (x - x != 0) { *ip = x; return copysignf(0.0f, x); }
  float t = truncf(x); *ip = t; return copysignf(x - t, x); }
