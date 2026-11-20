/* src/apps/moon/lib/moonlibc/math/fpclass.c -- classification, the sign bit, copysign and nan */
#include "../impl.h"
#include <math.h>
#include "fpbits.h"

int __fpclassify(double x) {
  u64 u = bits(x); int e = (int) (u >> 52 & 2047); u64 m = u << 12;
  return e == 2047 ? (m ? FP_NAN : FP_INFINITE) : e == 0 ? (m ? FP_SUBNORMAL : FP_ZERO) : FP_NORMAL; }
int __fpclassifyf(float x) {
  unsigned u = fbits(x); int e = (int) (u >> 23 & 255); unsigned m = u << 9;
  return e == 255 ? (m ? FP_NAN : FP_INFINITE) : e == 0 ? (m ? FP_SUBNORMAL : FP_ZERO) : FP_NORMAL; }
int __signbit(double x) { return (int) (bits(x) >> 63); }
int __signbitf(float x) { return (int) (fbits(x) >> 31); }

double copysign(double x, double y) { return dbl((bits(x) & ~SGN) | (bits(y) & SGN)); }
float copysignf(float x, float y) { return flt((fbits(x) & 0x7fffffffu) | (fbits(y) & 0x80000000u)); }
double nan(char const *s) { (void) s; return dbl(0x7ff8000000000000ULL); }
float nanf(char const *s) { (void) s; return flt(0x7fc00000u); }
