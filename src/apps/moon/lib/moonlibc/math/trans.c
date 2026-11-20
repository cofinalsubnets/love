/* src/apps/moon/lib/moonlibc/math/trans.c -- hypot, cbrt, exp2, log1p, expm1, the inverse hyperbolics, and log2f, log10f */
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
/* the float forms. double in software: in float alone, each within 1.5 ulp */
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
/* exact a*b and a+b as hi+lo */
static void fsplit(float a, float *hi, float *lo) { float c = a * 4097.0f; *hi = c - (c - a); *lo = a - *hi; }
static void fmul2(float a, float b, float *hi, float *lo) {
  float ah, al, bh, bl;
  fsplit(a, &ah, &al); fsplit(b, &bh, &bl);
  *hi = a * b;
  *lo = ((ah * bh - *hi) + ah * bl + al * bh) + al * bl; }
static void fsum2(float a, float b, float *s, float *e) { *s = a + b; float bb = *s - a; *e = (a - (*s - bb)) + (b - bb); }
/* lm_logf's kernel: ln(1 + f) = f - hfsq + this, f in [sqrt2/2 - 1, sqrt2 - 1] */
static float klog(float f, float *hfsq) {
  float s = f / (2.0f + f), z = s * s;
  *hfsq = 0.5f * f * f;
  return s * (*hfsq + z * (0x1.555556p-1f + z * (0x1.99999ap-2f + z * (0x1.24924ap-2f + z * 0x1.c71c72p-3f)))); }
/* x = 2^k m, m in [sqrt2/2, sqrt2): ln m as hi + lo, hi with 12 bits so its products are exact */
static int lsplit(float x, float *hi, float *lo) {
  int k; float m = frexpf(x, &k);
  if (m < 0x1.6a09e6p-1f) m *= 2.0f, k--;
  float f = m - 1.0f, hf, sr = klog(f, &hf);
  *hi = flt(fbits(f - hf) & 0xfffff000u);
  *lo = (f - *hi) - hf + sr;
  return k; }
float log2f(float x) {
  if (!(x > 0) || x - x != 0) return lm_logf(x);
  float hi, lo; int k = lsplit(x, &hi, &lo);
  float vh = hi * 1.4428710938e+00f, vl = (lo + hi) * -1.7605285393e-04f + lo * 1.4428710938e+00f;
  float y = (float) k, w = y + vh;
  vl += (y - w) + vh;
  return vl + w; }
float log10f(float x) {
  if (!(x > 0) || x - x != 0) return lm_logf(x);
  float hi, lo; int k = lsplit(x, &hi, &lo);
  float vh = hi * 4.3432617188e-01f, y = (float) k * 3.0102920532e-01f;
  float vl = (float) k * 7.9034151668e-07f + (lo + hi) * -3.1689971365e-05f + lo * 4.3432617188e-01f;
  float w = y + vh;
  vl += (y - w) + vh;
  return vl + w; }
/* ln(1 + x + xl), xl below x's ulp: the kernel on x itself near 0, else on 1 + x's m with
 * the rounding of 1 + x as a correction */
static float log1p2(float x, float xl) {
  unsigned u = fbits(x);
  float hf, sr;
  if (x != x || u == 0x7f800000u) return x;
  if (x <= -1.0f) return x == -1.0f ? -1.0f / 0.0f : (x - x) / (x - x);
  if ((u & ~FSGN) < 0x33800000u) return x;                     /* below 2^-24 */
  if (x < 0x1.a827ap-2f && x > -0x1.2bec34p-2f) { sr = klog(x, &hf); return x - (hf - (sr + xl / (1.0f + x))); }
  float v = 1.0f + x, c = v > 2.0f ? 1.0f - (v - x) : x - (v - 1.0f);
  c = (c + xl) / v;
  int k; float m = frexpf(v, &k);
  if (m < 0x1.6a09e6p-1f) m *= 2.0f, k--;
  float f = m - 1.0f;
  sr = klog(f, &hf);
  return (float) k * 0x1.62e4p-1f - ((hf - (sr + ((float) k * 0x1.7f7d1cp-20f + c))) - f); }
float log1pf(float x) { return log1p2(x, 0.0f); }
/* fdlibm's: x = k ln2 + r, e^r - 1 by a rational in r^2, then 2^k with care near k = 0 */
float expm1f(float x) {
  unsigned hx = fbits(x) & ~FSGN; int neg = fbits(x) >> 31, k; float hi, lo, c = 0, y;
  if (hx >= 0x4195b844u) {                                     /* past 27 ln2 */
    if (hx > 0x7f800000u) return x + x;
    if (neg) return -1.0f;
    if (x > 0x1.62e42ep+6f) return 1.0f / 0.0f; }                 /* past ln FLT_MAX */
  if (hx > 0x3eb17218u) {                                      /* past ln2 / 2 */
    if (hx < 0x3f851592u) k = neg ? -1 : 1, hi = x - (float) k * 6.9313812256e-01f, lo = (float) k * 9.0580006145e-06f;
    else { k = (int) (1.4426950216e+00f * x + (neg ? -0.5f : 0.5f));
      hi = x - (float) k * 6.9313812256e-01f; lo = (float) k * 9.0580006145e-06f; }
    x = hi - lo; c = (hi - x) - lo; }
  else if (hx < 0x33000000u) return x;
  else k = 0;
  float hfx = 0.5f * x, hxs = x * hfx, r1 = 1.0f + hxs * (-3.3333212137e-2f + hxs * 1.5807170421e-3f);
  float t = 3.0f - r1 * hfx, e = hxs * ((r1 - t) / (6.0f - x * t));
  if (k == 0) return x - (x * e - hxs);
  e = x * (e - c) - c; e -= hxs;
  if (k == -1) return 0.5f * (x - e) - 0.5f;
  if (k == 1) return x < -0.25f ? -2.0f * (e - (x + 0.5f)) : 1.0f + 2.0f * (x - e);
  if (k <= -2 || k > 56) {
    y = 1.0f - (e - x);
    y = k == 128 ? y * 2.0f * 0x1p127f : y * flt((unsigned) (0x7f + k) << 23);
    return y - 1.0f; }
  if (k < 23) y = flt(0x3f800000u - (0x1000000u >> k)) - (e - x);
  else y = (x - (e + flt((unsigned) (0x7f - k) << 23))) + 1.0f;
  return y * flt((unsigned) (0x7f + k) << 23); }
/* sqrt(vh + vl) as s + *sl, the root's residual once */
static float sqrt2(float vh, float vl, float *sl) {
  float s = lm_sqrtf(vh), ph, pl;
  fmul2(s, s, &ph, &pl);
  *sl = (((vh - ph) - pl) + vl) / (2.0f * s);
  return s; }
float asinhf(float x) {
  unsigned ix = fbits(x) & ~FSGN; float a = fabsf(x), w;
  if (ix >= 0x7f800000u) return x + x;
  if (ix < 0x39800000u) return x;
  if (ix > 0x4d800000u) w = lm_logf(a) + 0x1.62e430p-1f;
  else if (ix > 0x40000000u) w = lm_logf(2.0f * a + 1.0f / (lm_sqrtf(a * a + 1.0f) + a));
  else {                                                       /* log1p(a + a^2 / (1 + sqrt(1 + a^2))) */
    float th, tl, vh, vl, uh, ul, rl, r;
    fmul2(a, a, &th, &tl);
    fsum2(1.0f, th, &vh, &vl); vl += tl;
    r = sqrt2(vh, vl, &rl);
    fsum2(a, th / (1.0f + (r + rl)), &uh, &ul);
    w = log1p2(uh, ul); }
  return x < 0 ? -w : w; }
float acoshf(float x) {
  unsigned hx = fbits(x);
  if (!(x >= 1.0f)) return (x - x) / (x - x);
  if (hx >= 0x4d800000u) return hx >= 0x7f800000u ? x + x : lm_logf(x) + 0x1.62e430p-1f;
  if (x == 1.0f) return 0.0f;
  if (hx > 0x40000000u) return lm_logf(2.0f * x - 1.0f / (x + lm_sqrtf(x * x - 1.0f)));
  float t = x - 1.0f, th, tl, vh, vl, uh, ul, rl;              /* log1p(t + sqrt(2t + t^2)), t exact */
  fmul2(t, t, &th, &tl);
  fsum2(2.0f * t, th, &vh, &vl); vl += tl;
  fsum2(t, sqrt2(vh, vl, &rl), &uh, &ul);
  return log1p2(uh, ul + rl); }
float atanhf(float x) {
  float a = fabsf(x), dh, dl, ph, pl;
  if (!(a <= 1.0f)) return (x - x) / (x - x);
  if (a == 1.0f) return x / 0.0f;
  if (a < 0x1p-12f) return x;
  fsum2(1.0f, -a, &dh, &dl);                                   /* log1p(2a / (1 - a)) / 2 */
  float q = 2.0f * a / dh;
  fmul2(q, dh, &ph, &pl);
  float t = 0.5f * log1p2(q, (((2.0f * a - ph) - pl) - q * dl) / dh);
  return x < 0 ? -t : t; }
#else
float hypotf(float x, float y) { double a = x, b = y; return (float) sqrt(a * a + b * b); }
float cbrtf(float x) { return (float) cbrt(x); }
float exp2f(float x) { return (float) pow(2.0, x); }
float log1pf(float x) { return (float) log1p(x); }
float expm1f(float x) { return (float) expm1(x); }
float asinhf(float x) { return (float) asinh(x); }
float acoshf(float x) { return (float) acosh(x); }
float atanhf(float x) { return (float) atanh(x); }
float log2f(float x) { return (float) log2(x); }
float log10f(float x) { return (float) log10(x); }
#endif
