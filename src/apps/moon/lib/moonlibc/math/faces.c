#include "../impl.h"
#include "fpbits.h"

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
/* float twins: the double result narrowed once, but where double is soft: there in float
 * alone, each within 1.5 ulp */
#if fp_dsoft
float lm_sinf(float), lm_cosf(float), lm_tanf(float), lm_expf(float), lm_logf(float), lm_sqrtf(float),
      lm_powf(float, float);
float sinf(float x) { return lm_sinf(x); }
float cosf(float x) { return lm_cosf(x); }
float expf(float x) { return lm_expf(x); }
float logf(float x) { return lm_logf(x); }
float sqrtf(float x) { return lm_sqrtf(x); }
float powf(float x, float y) { return lm_powf(x, y); }
float tanf(float x) { return lm_tanf(x); }
/* atan by fdlibm's four ranges about 1/2, 1, 3/2 and past, each atan(c) a pair */
static const float atanhi[] = {4.6364760399e-01f, 7.8539812565e-01f, 9.8279368877e-01f, 1.5707962513e+00f};
static const float atanlo[] = {5.0121582440e-09f, 3.7748947079e-08f, 3.4473217170e-08f, 7.5497894159e-08f};
float atanf(float x) {
  unsigned ix = fbits(x) & ~FSGN; int id;
  if (ix >= 0x4c800000u) return ix > 0x7f800000u ? x + x : x > 0 ? atanhi[3] + atanlo[3] : -atanhi[3] - atanlo[3];
  float a = flt(ix);
  if (ix < 0x3ee00000u) { if (ix < 0x39800000u) return x; id = -1; a = x; }
  else if (ix < 0x3f300000u) id = 0, a = (2.0f * a - 1.0f) / (2.0f + a);
  else if (ix < 0x3f980000u) id = 1, a = (a - 1.0f) / (a + 1.0f);
  else if (ix < 0x401c0000u) id = 2, a = (a - 1.5f) / (1.0f + 1.5f * a);
  else id = 3, a = -1.0f / a;
  float z = a * a, w = z * z;
  float s = z * (3.3333328366e-01f + w * (1.4253635705e-01f + w * 6.1687607318e-02f))
          + w * (-1.9999158382e-01f + w * -1.0648017377e-01f);
  if (id < 0) return a - a * s;
  z = atanhi[id] - ((a * s - atanlo[id]) - a);
  return x < 0 ? -z : z; }
static const float pif = 3.1415927410e+00f, pif_lo = -8.7422776573e-08f, pio2f = 1.5707963705e+00f,
                   pio2_hi = 1.5707962513e+00f, pio2_lo = 7.5497894159e-08f;
float atan2f(float y, float x) {
  if (x != x || y != y) return x + y;
  if (x == 1.0f) return atanf(y);
  int m = (int) (fbits(y) >> 31 | (fbits(x) >> 31) << 1);   /* bit 0 y's sign, bit 1 x's */
  unsigned ix = fbits(x) & ~FSGN, iy = fbits(y) & ~FSGN;
  float z;
  if (!iy) return m < 2 ? y : m == 2 ? pif : -pif;
  if (!ix || (iy == 0x7f800000u && ix != iy)) return m & 1 ? -pio2f : pio2f;
  if (ix == 0x7f800000u) z = iy == ix ? (m < 2 ? 0x1.921fb6p-1f : 0x1.2d97c8p+1f) : m < 2 ? 0.0f : pif;
  else {
    int k = (int) (iy >> 23) - (int) (ix >> 23);
    if (k > 26) z = pio2f + 0.5f * pif_lo, m &= 1;
    else if (k < -26 && m > 1) z = 0.0f;
    else z = atanf(flt(fbits(y / x) & ~FSGN));
    if (m > 1) z = m == 2 ? pif - (z - pif_lo) : (z - pif_lo) - pif, m = 0; }
  return m & 1 ? -z : z; }
/* asin and acos by fdlibm's rational in t = (1 - |x|)/2 past 1/2, sqrt t split so its
 * square is exact */
static float Rf(float z) { return z * (1.6666586697e-01f + z * (-4.2743422091e-02f + z * -8.6563630030e-03f))
                                  / (1.0f + z * -7.0662963390e-01f); }
float asinf(float x) {
  unsigned ix = fbits(x) & ~FSGN;
  if (ix >= 0x3f800000u) return ix == 0x3f800000u ? x * pio2_hi + x * pio2_lo : (x - x) / (x - x);
  if (ix < 0x3f000000u) return ix < 0x39800000u ? x : x + x * Rf(x * x);
  float t = (1.0f - flt(ix)) * 0.5f, s = lm_sqrtf(t), df = flt(fbits(s) & 0xfffff000u);
  float c = (t - df * df) / (s + df), v = (pio2_hi - 2.0f * df) + (pio2_lo - 2.0f * (Rf(t) * s + c));
  return x < 0 ? -v : v; }
float acosf(float x) {
  unsigned ix = fbits(x) & ~FSGN;
  if (ix >= 0x3f800000u) return ix != 0x3f800000u ? (x - x) / (x - x) : x > 0 ? 0.0f : 2.0f * pio2_hi + 2.0f * pio2_lo;
  if (ix < 0x3f000000u) return ix <= 0x32800000u ? pio2_hi + pio2_lo : pio2_hi - (x - (pio2_lo - x * Rf(x * x)));
  if (x < 0) { float z = (1.0f + x) * 0.5f, s = lm_sqrtf(z); return 2.0f * (pio2_hi - (s + (Rf(z) * s - pio2_lo))); }
  float z = (1.0f - x) * 0.5f, s = lm_sqrtf(z), df = flt(fbits(s) & 0xfffff000u), c = (z - df * df) / (s + df);
  return 2.0f * (df + (Rf(z) * s + c)); }
#else
float sinf(float x) { return (float) sin(x); }
float cosf(float x) { return (float) cos(x); }
float expf(float x) { return (float) exp(x); }
float logf(float x) { return (float) log(x); }
float sqrtf(float x) { return (float) sqrt(x); }
float powf(float x, float y) { return (float) pow(x, y); }
float tanf(float x) { return (float) tan(x); }
float asinf(float x) { return (float) asin(x); }
float acosf(float x) { return (float) acos(x); }
float atanf(float x) { return (float) atan(x); }
float atan2f(float y, float x) { return (float) atan2(y, x); }
#endif
float fabsf(float x) { return x <= 0 ? 0.0f - x : x; }
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
