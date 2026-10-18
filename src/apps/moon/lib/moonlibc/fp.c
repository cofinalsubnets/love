/* src/apps/moon/lib/moonlibc/fp.c -- the rest of c99's <math.h>: classification and the
 * functions that are exact on the bits (rounding, fmod, remquo, fma, the exponent pickers),
 * then the transcendentals lm.c does not carry, each a careful identity over its floor.
 * the float forms go through double, which holds every float exactly. */
#include "impl.h"
#include <math.h>
#include <fenv.h>
#include <limits.h>

typedef unsigned long long u64;
static u64 bits(double x) { union { double d; u64 u; } b; b.d = x; return b.u; }
static double dbl(u64 u) { union { double d; u64 u; } b; b.u = u; return b.d; }
static unsigned fbits(float x) { union { float f; unsigned u; } b; b.f = x; return b.u; }
static float flt(unsigned u) { union { float f; unsigned u; } b; b.u = u; return b.f; }
#define SGN (1ULL << 63)

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

/* ---- rounding: trunc clears the fraction bits; the rest build on it ---- */
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
double nearbyint(double x) { return rint(x); }
long lrint(double x) { return (long) rint(x); }
long long llrint(double x) { return (long long) rint(x); }
long lround(double x) { return (long) round(x); }
long long llround(double x) { return (long long) round(x); }
float truncf(float x) { return (float) trunc(x); }
float roundf(float x) { return (float) round(x); }
float rintf(float x) { return (float) rint(x); }
float nearbyintf(float x) { return (float) rint(x); }
long lrintf(float x) { return (long) rint(x); }
long long llrintf(float x) { return (long long) rint(x); }
long lroundf(float x) { return (long) round(x); }
long long llroundf(float x) { return (long long) round(x); }

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

/* ---- the exponent ---- */
double scalbn(double x, int n) { return ldexp(x, n); }
double scalbln(double x, long n) { return ldexp(x, n > INT_MAX ? INT_MAX : n < INT_MIN ? INT_MIN : (int) n); }
float scalbnf(float x, int n) { return (float) ldexp(x, n); }
float ldexpf(float x, int n) { return (float) ldexp(x, n); }
float frexpf(float x, int *e) { return (float) frexp(x, e); }
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

/* ---- fma, rounded once: the 106-bit product and the addend aligned in 128 bits, a sticky
 * bit for what falls off the bottom, one round to nearest even (a subnormal shifted first) ---- */
typedef struct { u64 hi, lo; } u128;
static u128 __mul64(u64 a, u64 b) {
  u64 a0 = a & 0xffffffff, a1 = a >> 32, b0 = b & 0xffffffff, b1 = b >> 32;
  u64 p00 = a0 * b0, p01 = a0 * b1, p10 = a1 * b0, p11 = a1 * b1;
  u64 mid = (p00 >> 32) + (p01 & 0xffffffff) + (p10 & 0xffffffff);
  u128 r = { p11 + (p01 >> 32) + (p10 >> 32) + (mid >> 32), (mid << 32) | (p00 & 0xffffffff) };
  return r; }
static int __clz128(u128 a) {
  int n = 0; u64 w = a.hi;
  if (!w) { n = 64; w = a.lo; }
  for (; !(w >> 63); w <<= 1) n++;
  return n; }
static u128 __shl(u128 a, int s) {
  if (s == 0) return a;
  if (s >= 64) { u128 r = { a.lo << (s - 64), 0 }; return r; }
  u128 r = { a.hi << s | a.lo >> (64 - s), a.lo << s }; return r; }
static u128 __shr(u128 a, int s, int *st) {        /* right, what falls off into *st */
  if (s == 0) return a;
  if (s >= 128) { *st |= (a.hi | a.lo) != 0; u128 z = { 0, 0 }; return z; }
  if (s >= 64) {
    *st |= (a.lo | (s > 64 ? a.hi << (128 - s) : 0)) != 0;
    u128 r = { 0, a.hi >> (s - 64) }; return r; }
  *st |= (a.lo << (64 - s)) != 0;
  u128 r = { a.hi >> s, a.lo >> s | a.hi << (64 - s) }; return r; }
static int __split(double x, u64 *m) {             /* x = m * 2^e, m a positive integer */
  u64 u = bits(x); int e = (int) (u >> 52 & 2047);
  *m = u & (~0ULL >> 12);
  if (e) { *m |= 1ULL << 52; return e - 1075; }
  return -1074; }
double fma(double a, double b, double c) {
  if (a - a != 0 || b - b != 0 || c - c != 0 || a == 0 || b == 0 || c == 0) return a * b + c;
  u64 ma, mb, mc;
  int ea = __split(a, &ma), eb = __split(b, &mb), ec = __split(c, &mc);
  int sp = __signbit(a) ^ __signbit(b), sc = __signbit(c), st = 0;
  u128 p = __mul64(ma, mb), q = { 0, mc };
  int lp = __clz128(p), lq = __clz128(q);
  p = __shl(p, lp); q = __shl(q, lq);
  int Ep = ea + eb - lp + 127, Eq = ec - lq + 127;  /* value = M * 2^(E - 127), M's top bit 127 */
  if (Ep < Eq || (Ep == Eq && (p.hi < q.hi || (p.hi == q.hi && p.lo < q.lo)))) {
    u128 t = p; p = q; q = t; int e = Ep; Ep = Eq; Eq = e; int s = sp; sp = sc; sc = s; }
  q = __shr(q, Ep - Eq, &st);
  int E = Ep;
  u128 r;
  if (sp == sc) {
    r.lo = p.lo + q.lo; r.hi = p.hi + q.hi + (r.lo < p.lo);
    if (r.hi < p.hi || (r.hi == p.hi && r.lo < p.lo)) {   /* a carry out of bit 127 */
      r = __shr(r, 1, &st); r.hi |= SGN; E++; } }
  else {
    u64 bw = st;                                  /* a sticky subtrahend is a little larger */
    r.lo = p.lo - q.lo - bw;
    r.hi = p.hi - q.hi - (p.lo < q.lo || (p.lo == q.lo && bw));
    if (!r.hi && !r.lo && !st) return 0.0;
    int z = __clz128(r);
    r = __shl(r, z); E -= z; }
  if (E < -1022) { r = __shr(r, -1022 - E, &st); E = -1022; }
  u64 m = r.hi >> 11, g = (r.hi >> 10) & 1;
  int rest = (r.hi & 0x3ff) || r.lo || st;
  if (g && (rest || (m & 1))) m++;
  if (m >> 53) { m >>= 1; E++; }
  u64 s = (u64) sp << 63;
  if (E > 1023) return dbl(s | 0x7ff0000000000000ULL);
  if (m >> 52) return dbl(s | (u64) (E + 1023) << 52 | (m & (~0ULL >> 12)));
  return dbl(s | m); }
/* fmaf: the product is exact in double; the sum rounds to odd there, so the float round is the one */
float fmaf(float a, float b, float c) {
  double p = (double) a * b, s = p + c, bb = s - p, e = (p - (s - bb)) + (c - bb);
  if (e != 0 && !(bits(s) & 1)) s = dbl(bits(s) + ((e > 0) == (s > 0) ? 1 : -1));
  return (float) s; }

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

/* ---- <fenv.h>: one rounding mode, nearest, and no flags kept ---- */
fenv_t const __fe_dfl_env = { FE_TONEAREST };
int fegetround(void) { return FE_TONEAREST; }
int fesetround(int r) { return r == FE_TONEAREST ? 0 : -1; }
int feclearexcept(int e) { (void) e; return 0; }
int feraiseexcept(int e) { (void) e; return 0; }
int fetestexcept(int e) { (void) e; return 0; }
int fegetexceptflag(fexcept_t *f, int e) { (void) e; *f = 0; return 0; }
int fesetexceptflag(fexcept_t const *f, int e) { (void) f; (void) e; return 0; }
int fegetenv(fenv_t *f) { f->__round = FE_TONEAREST; return 0; }
int fesetenv(fenv_t const *f) { return f == FE_DFL_ENV || f->__round == FE_TONEAREST ? 0 : -1; }
int feholdexcept(fenv_t *f) { return fegetenv(f); }
int feupdateenv(fenv_t const *f) { return fesetenv(f); }
