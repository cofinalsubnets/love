/* src/apps/moon/lib/moonlibc/math/erfgamma.c -- erf, erfc, tgamma and lgamma; the float forms go through double */
#include "../impl.h"
#include <math.h>

/* erf by its series below 2, erfc by its continued fraction above, each the other's complement */
static double __erfser(double x) {
  double t = x, s = x, x2 = x * x;
  for (int n = 1; n < 60; n++) {
    t *= -x2 / n;
    double d = t / (2 * n + 1);
    s += d;
    if (fabs(d) < 1e-17 * fabs(s)) break; }
  return s * 1.1283791670955126; }               /* 2/sqrt(pi) */
static double __erfccf(double x) {                 /* x >= 2, Lentz */
  double tiny = 1e-300, f = x, C = x, D = 0;
  for (int n = 1; n < 300; n++) {
    double an = n / 2.0;
    D = x + an * D; if (D == 0) D = tiny; D = 1 / D;
    C = x + an / C; if (C == 0) C = tiny;
    double dl = C * D; f *= dl;
    if (fabs(dl - 1) < 1e-16) break; }
  return exp(-x * x) / f * 0.5641895835477563; } /* 1/sqrt(pi) */
double erf(double x) {
  if (x != x) return x;
  double a = fabs(x);
  if (a < 2.0) return __erfser(x);
  if (a > 6.0) return copysign(1.0, x);
  return copysign(1.0 - __erfccf(a), x); }
double erfc(double x) {
  if (x != x) return x;
  if (x < 2.0) return 1.0 - erf(x);
  if (x > 27.3) return 0.0;
  return __erfccf(x); }
float erff(float x) { return (float) erf(x); }
float erfcf(float x) { return (float) erfc(x); }
/* gamma by lanczos (g 7, nine terms), reflected below a half */
static double const __lz[9] = {
  0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313,
  -176.61502916214059, 12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6,
  1.5056327351493116e-7 };
static double __lanczos(double x, double *t) {     /* x >= 0.5: the series at x - 1 */
  x -= 1;
  double a = __lz[0];
  for (int i = 1; i < 9; i++) a += __lz[i] / (x + i);
  *t = x + 7.5;
  return a; }
double tgamma(double x) {
  if (x != x) return x;
  if (x == 0) return copysign(1.0 / 0.0, x);
  if (x - x != 0) return x > 0 ? x : (x - x) / (x - x);
  if (x < 0 && x == floor(x)) return (x - x) / (x - x);
  if (x > 171.7) return 1.0 / 0.0;
  if (x < 0.5) return M_PI / (sin(M_PI * x) * tgamma(1 - x));
  if (x == floor(x) && x <= 19) { double r = 1; for (int k = 2; k < (int) x; k++) r *= k; return r; }
  double t, a = __lanczos(x, &t);
  return 2.5066282746310002 * pow(t, x - 0.5) * exp(-t) * a; }
int signgam;
double lgamma(double x) {
  signgam = 1;
  if (x != x) return x;
  if (x - x != 0) return fabs(x);
  if (x <= 0 && x == floor(x)) return 1.0 / 0.0;
  if (x == 1 || x == 2) return 0.0;
  if (x < 0.5) {
    double s = sin(M_PI * x), r = log(M_PI / fabs(s)) - lgamma(1 - x);
    signgam = s < 0 ? -1 : 1;                     /* after the inner call, which sets it too */
    return r; }
  double t, a = __lanczos(x, &t);
  return 0.9189385332046728 + (x - 0.5) * log(t) - t + log(a); }   /* log(sqrt(2 pi)) */
float tgammaf(float x) { return (float) tgamma(x); }
float lgammaf(float x) { return (float) lgamma(x); }
