/* src/apps/moon/lib/moonlibc/math/expo.c -- the exponent: scalbn, ilogb, logb, modf; the float forms go through double */
#include "../impl.h"
#include <math.h>
#include <limits.h>

/* ---- the exponent ---- */
double scalbn(double x, int n) { return ldexp(x, n); }
double scalbln(double x, long n) { return ldexp(x, n > INT_MAX ? INT_MAX : n < INT_MIN ? INT_MIN : (int) n); }
float scalbnf(float x, int n) { return (float) ldexp(x, n); }
float ldexpf(float x, int n) { return (float) ldexp(x, n); }
float frexpf(float x, int *e) { return (float) frexp(x, e); }
long double ldexpl(long double x, int n) { return ldexp(x, n); }
long double frexpl(long double x, int *e) { return frexp(x, e); }
int ilogb(double x) {
  if (x != x || x == 0) return INT_MIN;
  if (x - x != 0) return INT_MAX;
  int e; frexp(x, &e); return e - 1; }
int ilogbf(float x) { return ilogb(x); }
double logb(double x) {
  if (x != x) return x;
  if (x == 0) return -1.0 / 0.0;
  if (x - x != 0) return fabs(x);
  return (double) ilogb(x); }
float logbf(float x) { return (float) logb(x); }
double modf(double x, double *ip) {
  if (x != x) { *ip = x; return x; }
  if (x - x != 0) { *ip = x; return copysign(0.0, x); }
  double t = trunc(x); *ip = t; return copysign(x - t, x); }
float modff(float x, float *ip) { double i; double f = modf(x, &i); *ip = (float) i; return (float) f; }
