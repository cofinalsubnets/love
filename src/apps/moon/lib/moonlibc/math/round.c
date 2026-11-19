/* src/apps/moon/lib/moonlibc/math/round.c -- trunc and the roundings built on it */
#include "../impl.h"
#include <math.h>
#include "fpbits.h"

/* ---- rounding: trunc clears the fraction bits; the rest build on it. a64 rounds each in one
 * instruction, to the same bits ---- */
#if defined(__aarch64__)
double trunc(double x) { __asm__("frintz %d0, %d1" : "=w"(x) : "w"(x)); return x; }
double floor(double x) { __asm__("frintm %d0, %d1" : "=w"(x) : "w"(x)); return x; }
double ceil(double x) { __asm__("frintp %d0, %d1" : "=w"(x) : "w"(x)); return x; }
double round(double x) { __asm__("frinta %d0, %d1" : "=w"(x) : "w"(x)); return x; }
double rint(double x) { __asm__("frintx %d0, %d1" : "=w"(x) : "w"(x)); return x; }
float truncf(float x) { __asm__("frintz %s0, %s1" : "=w"(x) : "w"(x)); return x; }
float floorf(float x) { __asm__("frintm %s0, %s1" : "=w"(x) : "w"(x)); return x; }
float ceilf(float x) { __asm__("frintp %s0, %s1" : "=w"(x) : "w"(x)); return x; }
float roundf(float x) { __asm__("frinta %s0, %s1" : "=w"(x) : "w"(x)); return x; }
float rintf(float x) { __asm__("frintx %s0, %s1" : "=w"(x) : "w"(x)); return x; }
#else
double trunc(double x) {
  u64 u = bits(x); int e = (int) (u >> 52 & 2047) - 1023;
  if (e >= 52) return x;                           /* integral, or inf, or nan */
  if (e < 0) return dbl(u & SGN);                  /* under one: a zero of x's sign */
  return dbl(u & ~((1ULL << (52 - e)) - 1)); }
double floor(double x) { double t = trunc(x); return t > x ? t - 1.0 : t; }
double ceil(double x) { double t = trunc(x); return t < x ? t + 1.0 : t; }
double round(double x) { double t = trunc(x); return fabs(x - t) >= 0.5 ? t + copysign(1.0, x) : t; }
/* to nearest, ties even: a sum at 2^52 rounds the fraction away */
double rint(double x) {
  u64 u = bits(x);
  if ((u >> 52 & 2047) >= 1023 + 52) return x;
  double s = u >> 63 ? -4503599627370496.0 : 4503599627370496.0;
  volatile double t = x + s;
  double y = t - s;
  return y == 0 ? copysign(0.0, x) : y; }
#if fp_dsoft
float truncf(float x) {
  unsigned u = fbits(x); int e = (int) (u >> 23 & 255) - 127;
  if (e >= 23) return x;
  if (e < 0) return flt(u & FSGN);
  return flt(u & ~((1u << (23 - e)) - 1)); }
float floorf(float x) { float t = truncf(x); return t > x ? t - 1.0f : t; }
float ceilf(float x) { float t = truncf(x); return t < x ? t + 1.0f : t; }
float roundf(float x) { float t = truncf(x); return fabsf(x - t) >= 0.5f ? t + copysignf(1.0f, x) : t; }
float rintf(float x) {
  unsigned u = fbits(x);
  if ((u >> 23 & 255) >= 127 + 23) return x;
  float s = u >> 31 ? -8388608.0f : 8388608.0f;
  volatile float t = x + s;
  float y = t - s;
  return y == 0 ? copysignf(0.0f, x) : y; }
#else
float truncf(float x) { return (float) trunc(x); }
float floorf(float x) { return (float) floor(x); }
float ceilf(float x) { return (float) ceil(x); }
float roundf(float x) { return (float) round(x); }
float rintf(float x) { return (float) rint(x); }
#endif
#endif
double nearbyint(double x) { return rint(x); }
long lrint(double x) { return (long) rint(x); }
long long llrint(double x) { return (long long) rint(x); }
long lround(double x) { return (long) round(x); }
long long llround(double x) { return (long long) round(x); }
float nearbyintf(float x) { return rintf(x); }
long lrintf(float x) { return (long) rintf(x); }
long long llrintf(float x) { return (long long) rintf(x); }
long lroundf(float x) { return (long) roundf(x); }
long long llroundf(float x) { return (long long) roundf(x); }
