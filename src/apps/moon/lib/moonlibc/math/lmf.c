// the math floor's float twins: real functions, not macros, since love takes their address.
// sqrt exp log pow sin cos, and tan where double is soft, run in binary32 alone, for a machine
// whose fpu has no double; the rest round the double's answer
#include <stdint.h>
#include "fpbits.h"

double lm_sqrt(double), lm_pow(double, double), lm_sin(double), lm_cos(double),
       lm_atan2(double, double), lm_asin(double), lm_acos(double);
typedef union { float f; uint32_t u; } fb;
static float mkf(uint32_t u) { fb b; b.u = u; return b.f; }
static uint32_t muf(float f) { fb b; b.f = f; return b.u; }
// exact a*b as hi+lo: 12+12 bit halves
static void fsplit(float a, float *hi, float *lo) { float c = a * 4097.0f; *hi = c - (c - a); *lo = a - *hi; }
static void fmul2(float a, float b, float *hi, float *lo) {
 float ah, al, bh, bl;
 fsplit(a, &ah, &al); fsplit(b, &bh, &bl);
 *hi = a * b;
 *lo = ((ah * bh - *hi) + ah * bl + al * bh) + al * bl; }
static void fsum2(float a, float b, float *s, float *e) { *s = a + b; float bb = *s - a; *e = (a - (*s - bb)) + (b - bb); }

float lm_atan2f(float y, float x) { return (float) lm_atan2(y, x); }
float lm_asinf(float x) { return (float) lm_asin(x); }
float lm_acosf(float x) { return (float) lm_acos(x); }

// the integer root of the mantissa, rounded by its remainder (a tie cannot happen); the cpu's
// where it has one, as lm_sqrt
float lm_sqrtf(float x) {
 uint32_t u = muf(x);
 if (x != x || !(u << 1) || u == 0x7f800000u) return x;   // nan, +-0, +inf
 if (u >> 31) return mkf(0x7fc00000u);
#if defined(__x86_64__)
 { uint32_t r; __asm__("movd %1, %%xmm0\n\tsqrtss %%xmm0, %%xmm0\n\tmovd %%xmm0, %0" : "=r"(r) : "r"(u) : "xmm0"); return mkf(r); }
#elif defined(__aarch64__)
 { float y; __asm__("fsqrt %s0, %s1" : "=w"(y) : "w"(x)); return y; }
#endif
 int e = (int) (u >> 23);
 uint32_t m = u & 0x7fffffu;
 if (e) m |= 0x800000u;
 else for (e = 1; !(m & 0x800000u); m <<= 1) e--;          // subnormal: normalize
 e -= 127;
 if (e & 1) m <<= 1, e--;
 uint64_t M = (uint64_t) m << 23, r = 0;
 for (uint64_t b = 1ull << 48; b; b >>= 2)
  if (M >= r + b) M -= r + b, r = (r >> 1) + b;
  else r >>= 1;
 return mkf((uint32_t) (e / 2 + 126) * 0x800000u + (uint32_t) r + (M > r)); }

// x = k ln2 + r, |r| <= ln2/2; e^r by taylor to r^9 (tail < 2^-27), then 2^k
static const float LN2F_HI = 0x1.62e4p-1f, LN2F_LO = 0x1.7f7d1cp-20f, LOG2EF = 0x1.715476p+0f;
static float scale2kf(float y, int k) {                      // y * 2^k, k in [-252, 254]
 if (k > 127) y *= 0x1p127f, k -= 127;
 if (k < -126) y *= 0x1p-126f, k += 126;
 return y * mkf((uint32_t) (k + 127) << 23); }
float lm_expf(float x) {
 if (x != x) return x;
 if (x > 0x1.62e42ep+6f) return mkf(0x7f800000u);           // past ln FLT_MAX
 if (x < -0x1.9fe368p+6f) return 0.0f;                       // under half the least subnormal
 if (x < 0x1p-25f && x > -0x1p-25f) return 1.0f + x;
 int k = (int) (x * LOG2EF + (x > 0 ? 0.5f : -0.5f));
 float r = (x - (float) k * LN2F_HI) - (float) k * LN2F_LO;
 float p = r + r * r * (0.5f
      + r * (0x1.555556p-3f
      + r * (0x1.555556p-5f
      + r * (0x1.111112p-7f
      + r * (0x1.6c16c2p-10f
      + r * (0x1.a01a02p-13f
      + r * (0x1.a01a02p-16f
      + r *  0x1.71de3ap-19f)))))));
 return scale2kf(1.0f + p, k); }

// x = 2^k (1 + f), 1 + f in [sqrt2/2, sqrt2); ln(1 + f) = f - hfsq + s (hfsq + R), s = f/(2 + f)
// and R = 2 atanh s - 2s's series in s^2 to s^8
float lm_logf(float x) {
 uint32_t u = muf(x);
 if (x != x) return x;
 if (!(u << 1)) return mkf(0xff800000u);                     // +-0 -> -inf
 if (u >> 31) return mkf(0x7fc00000u);
 if (u == 0x7f800000u) return x;
 int k = 0;
 if (u < 0x800000u) x *= 0x1p25f, u = muf(x), k = -25;      // subnormal
 k += (int) (u >> 23) - 127;
 float m = mkf((u & 0x7fffffu) | 0x3f800000u);
 if ((u & 0x7fffffu) > 0x3504f3u) m *= 0.5f, k++;           // past sqrt2
 float f = m - 1.0f, s = f / (2.0f + f), z = s * s, hfsq = 0.5f * f * f;
 float R = z * (0x1.555556p-1f + z * (0x1.99999ap-2f + z * (0x1.24924ap-2f + z * 0x1.c71c72p-3f)));
 return (float) k * LN2F_HI - ((hfsq - (s * (hfsq + R) + (float) k * LN2F_LO)) - f); }

// x^y = e^(y ln x), ln x carried as a float pair: 2s and the s^3 term exact to a few
// ulp of their own, the rest of 2 atanh s in plain float; specials and |y| past 2^16 go
// through the double
float lm_powf(float x, float y) {
 if (y == 1.0f) return x;
 if (y == 2.0f) return x * x;
 if (y == -1.0f) return 1.0f / x;
 if (y == 0.5f && x > 0) return lm_sqrtf(x);
 uint32_t ux = muf(x) & 0x7fffffffu, uy = muf(y) & 0x7fffffffu;
 if (!ux || ux >= 0x7f800000u || !uy || uy >= 0x47800000u) return (float) lm_pow(x, y);
 int neg = 0;
 if (x < 0) {                                                // an integer y keeps the sign's parity
  float t = (float) (int32_t) y;
  if (uy >= 0x4b000000u) t = y;                              // past 2^23 every float is even
  if (t != y) return mkf(0x7fc00000u);
  neg = uy < 0x4b800000u && ((int32_t) y & 1);
  x = -x; }
 uint32_t u = muf(x);
 int k = 0;
 if (u < 0x800000u) x *= 0x1p25f, u = muf(x), k = -25;
 k += (int) (u >> 23) - 127;
 float m = mkf((u & 0x7fffffu) | 0x3f800000u);
 if ((u & 0x7fffffu) > 0x3504f3u) m *= 0.5f, k++;
 float f = m - 1.0f, dh, dl, sh, sl, ph, pl;
 fsum2(2.0f, f, &dh, &dl);
 sh = f / dh;                                                // s = f/(2 + f) as sh + sl
 fmul2(sh, dh, &ph, &pl);
 sl = (((f - ph) - pl) - sh * dl) / dh;
 float zh, zl, ch, cl;
 fmul2(sh, sh, &zh, &zl); zl += 2.0f * sh * sl;
 fmul2(sh, zh, &ch, &cl); cl += sh * zl + sl * zh;          // s^3
 float z = zh, th, tl;
 fmul2(ch, 0x1.555556p-1f, &th, &tl);                        // (2/3) s^3, 2/3 a pair
 tl += ch * -0x1.555556p-26f + cl * 0x1.555556p-1f;
 float rest = ch * z * (0x1.99999ap-2f + z * (0x1.24924ap-2f + z * (0x1.c71c72p-3f
            + z * (0x1.745d18p-3f + z * (0x1.3b13b2p-3f + z * (0x1.111112p-3f + z * 0x1.e1e1e2p-4f))))));
 float lh, ll, kh, kl;
 fsum2(2.0f * sh, th, &lh, &ll);                             // ln m
 ll += 2.0f * sl + tl + rest;
 fmul2((float) k, LN2F_HI, &kh, &kl);                        // + k ln2, its high part exact
 kl += (float) k * LN2F_LO;
 float sh2, sl2;
 fsum2(kh, lh, &sh2, &sl2);
 sl2 += kl + ll;
 fsum2(sh2, sl2, &lh, &ll);
 float wh, wl;
 fmul2(y, lh, &wh, &wl); wl += y * ll;
 if (wh > 0x1.62e42ep+6f) return mkf(neg ? 0xff800000u : 0x7f800000u);
 if (wh < -0x1.9fe368p+6f) return neg ? -0.0f : 0.0f;
 float e = lm_expf(wh);
 e = e + e * wl;
 return neg ? -e : e; }

// x = k pi/2 + r below |k| 256, pi/2 as three parts (16+16+24 bits); taylor kernels on
// |r| <= pi/4; past that the double's reduction
static const float PIO2F_1 = 0x1.922p+0f, PIO2F_2 = -0x1.2aeep-18f, PIO2F_3 = -0x1.e973dcp-35f,
                   INVPIO2F = 0x1.45f306p-1f;
// each as its head (r, w = 1 - z/2) and the tail past it
static float ksintf(float r, float z) { return r * z * (-0x1.555556p-3f + z * (0x1.111112p-7f + z * (-0x1.a01a02p-13f + z * 0x1.71de3ap-19f))); }
static float kcostf(float z, float hz, float w) { return ((1.0f - w) - hz) + z * z * (0x1.555556p-5f + z * (-0x1.6c16c2p-10f + z * (0x1.a01a02p-16f + z * -0x1.27e4fcp-22f))); }
static float ksinf(float r) { return r + ksintf(r, r * r); }
static float kcosf(float r) { float z = r * r, hz = 0.5f * z, w = 1.0f - hz; return w + kcostf(z, hz, w); }
// r carried hi+lo: the first two products are exact, so only the subtractions round
static int rpio2f(float x, float *r, float *rlo) {
 int k = (int) (x * INVPIO2F + (x > 0 ? 0.5f : -0.5f));
 float w, wl, v = (float) k * PIO2F_3;
 fsum2(x - (float) k * PIO2F_1, -(float) k * PIO2F_2, &w, &wl);
 fsum2(w, -v, r, rlo);
 *rlo += wl;
 return k; }
// sin and cos of r + rlo: the low part through the other's first term
static float ksinlf(float r, float rl) { return ksinf(r) + rl * (1.0f - 0.5f * r * r); }
static float kcoslf(float r, float rl) { return kcosf(r) - rl * r; }
float lm_sinf(float x) {
 uint32_t a = muf(x) & 0x7fffffffu;
 if (a < 0x39800000u) return x;                              // below 2^-12
 if (a >= 0x43c90000u) return (float) lm_sin(x);             // 402 and past, inf, nan
 float r, rl; int k = rpio2f(x, &r, &rl);
 switch (k & 3) { case 0: return ksinlf(r, rl); case 1: return kcoslf(r, rl); case 2: return -ksinlf(r, rl); default: return -kcoslf(r, rl); } }
float lm_cosf(float x) {
 uint32_t a = muf(x) & 0x7fffffffu;
 if (a < 0x39800000u) return 1.0f;
 if (a >= 0x43c90000u) return (float) lm_cos(x);
 float r, rl; int k = rpio2f(x, &r, &rl);
 switch (k & 3) { case 0: return kcoslf(r, rl); case 1: return -ksinlf(r, rl); case 2: return -kcoslf(r, rl); default: return ksinlf(r, rl); } }
#if fp_dsoft
// sin over cos, each a pair of r and its tail, the quotient corrected once
float lm_tanf(float x) {
 uint32_t a = muf(x) & 0x7fffffffu;
 if (a < 0x39800000u) return x;
 if (a >= 0x43c90000u) return (float) (lm_sin(x) / lm_cos(x));
 float r, rl; int k = rpio2f(x, &r, &rl);
 float z = r * r, hz = 0.5f * z, w = 1.0f - hz, sh = r, ch = w, q, ph, pl;
 float sl = ksintf(r, z) + rl * (1.0f - hz), cl = kcostf(z, hz, w) - rl * r;
 if (k & 1) q = sh, sh = ch, ch = q, q = sl, sl = cl, cl = q;
 fsum2(sh, sl, &sh, &sl); fsum2(ch, cl, &ch, &cl);
 q = sh / ch;
 fmul2(q, ch, &ph, &pl);
 q += (((sh - ph) - pl) + sl - q * cl) / ch;
 return k & 1 ? -q : q; }
#endif
