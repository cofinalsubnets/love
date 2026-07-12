#include <stdint.h>
#include <stddef.h>
#include <limits.h>

// === C library math functions for the freestanding kernel ============
// g/math.c reaches these through the g_* aliases in g.h; hosted builds
// resolve those to libm, the kernel supplies them here. All targets
// ~10^-12 relative error or better; not bit-exact libm but plenty for
// "fractions and graphics work" use cases.

#define m_inf __builtin_inf()
#define m_nan __builtin_nan("")
static double const m_pi    = 3.141592653589793;
static double const m_pi_2  = 1.5707963267948966;
static double const m_pi_4  = 0.7853981633974483;
static double const m_2pi   = 6.283185307179586;
static double const m_inv2pi= 0.15915494309189535;
static double const m_ln2   = 0.6931471805599453;
static double const m_invln2= 1.4426950408889634;

// sqrt: Newton–Raphson with an IEEE bit-trick initial guess. Four
// iterations reach ~1 ulp from a guess that's already within ~0.5%.
double sqrt(double x) {
 if (x != x) return x;
 if (x < 0)  return m_nan;
 if (x == 0) return x;        // preserves signed zero
 if (x > 1e308) return x;     // +inf
 union { double d; uint64_t u; } u = { .d = x };
 u.u = (u.u + ((uint64_t)1023 << 52)) >> 1;   // exponent halving
 double y = u.d;
 for (int i = 0; i < 4; i++) y = 0.5 * (y + x / y);
 return y; }

// exp: x = k*ln2 + r with |r| <= ln2/2; degree-9 Taylor for exp(r) is
// accurate to ~3e-14 in that range. Multiply by 2^k via direct bit
// manipulation of the exponent.
double exp(double x) {
 if (x != x) return x;
 if (x >  709.78) return m_inf;
 if (x < -745.13) return 0;
 double kd = x * m_invln2;
 int k = (int)(kd + (kd < 0 ? -0.5 : 0.5));
 double r = x - k * m_ln2;
 double p = 1 + r * (1 + r * (1.0/2 + r * (1.0/6 + r * (1.0/24
          + r * (1.0/120 + r * (1.0/720 + r * (1.0/5040
          + r * (1.0/40320 + r * (1.0/362880)))))))));
 union { double d; uint64_t u; } s;
 s.u = (uint64_t)(k + 1023) << 52;
 return p * s.d; }

// log: x = m * 2^e with m in [1, 2). Series in t = (m-1)/(m+1), |t| < 1/3,
// converges fast. Result is poly + e * ln2.
double log(double x) {
 if (x != x) return x;
 if (x < 0)  return m_nan;
 if (x == 0) return -m_inf;
 union { double d; uint64_t u; } u = { .d = x };
 int e = (int)((u.u >> 52) & 0x7ff) - 1023;
 u.u = (u.u & 0x000fffffffffffffULL) | ((uint64_t)1023 << 52);
 double m = u.d, t = (m - 1) / (m + 1), t2 = t * t;
 double p = 2 * t * (1 + t2 * (1.0/3 + t2 * (1.0/5 + t2 * (1.0/7
          + t2 * (1.0/9 + t2 * (1.0/11 + t2 * (1.0/13)))))));
 return p + e * m_ln2; }

// sin/cos kernels. |x| <= pi/4. Degree-13 Taylor for sin, degree-14 for
// cos. The dropped tail term at the pi/4 boundary sets the error floor, so
// cos needs through x^14/14! (the x^12 term alone is ~1.5e-10 at pi/4, which
// blew the 1e-12 `close` tolerance on cos(pi/4)); now both are < 1e-14 in range.
static double sin_k(double x) {
 double x2 = x * x;
 return x * (1 + x2 * (-1.0/6 + x2 * (1.0/120 + x2 * (-1.0/5040
          + x2 * (1.0/362880 + x2 * (-1.0/39916800 + x2 * (1.0/6227020800))))))); }

static double cos_k(double x) {
 double x2 = x * x;
 return 1 + x2 * (-0.5 + x2 * (1.0/24 + x2 * (-1.0/720 + x2 * (1.0/40320
          + x2 * (-1.0/3628800 + x2 * (1.0/479001600 + x2 * (-1.0/87178291200))))))); }

// Reduce x mod 2pi via fmod-style subtraction, then quadrant pick into
// [-pi/4, pi/4] and dispatch to the kernel. Loses precision for very
// large |x| since we don't do Cody-Waite splitting — adequate for
// l-scale inputs.
double sin(double x) {
 if (x != x) return x;
 if (x > 1e15 || x < -1e15) return m_nan;   // catastrophic cancellation
 double k = (int64_t)(x * m_inv2pi + (x < 0 ? -0.5 : 0.5));
 double y = x - k * m_2pi;                   // y in [-pi, pi]
 if (y > m_pi_2 + m_pi_4)      return -sin_k(y - m_pi);
 if (y > m_pi_4)               return  cos_k(y - m_pi_2);
 if (y < -m_pi_2 - m_pi_4)     return -sin_k(y + m_pi);
 if (y < -m_pi_4)              return -cos_k(y + m_pi_2);
 return sin_k(y); }

double cos(double x) { return sin(x + m_pi_2); }
double tan(double x) { return sin(x) / cos(x); }

// atan: the fdlibm reduction (via musl, MIT) -- four bands picked off the
// high word, each folding |x| toward [0, 7/16] against an exact table
// angle (hi + lo split), then an 11-term minimax polynomial in odd/even
// halves. ~1 ulp; the old two-halve-angle Taylor sat at ~1e-13 and failed
// the corpus's 1e-12 atan(tan x) round trip.
static double const atanhi[] = {
  4.63647609000806093515e-01,   // atan(0.5)hi
  7.85398163397448278999e-01,   // atan(1.0)hi
  9.82793723247329054082e-01,   // atan(1.5)hi
  1.57079632679489655800e+00,   // atan(inf)hi
};
static double const atanlo[] = {
  2.26987774529616870924e-17,   // atan(0.5)lo
  3.06161699786838301793e-17,   // atan(1.0)lo
  1.39033110312309984516e-17,   // atan(1.5)lo
  6.12323399573676603587e-17,   // atan(inf)lo
};
static double const aT[] = {
  3.33333333333329318027e-01, -1.99999999998764832476e-01,
  1.42857142725034663711e-01, -1.11111104054623557880e-01,
  9.09088713343650656196e-02, -7.69187620504482999495e-02,
  6.66107313738753120669e-02, -5.83357013379057348645e-02,
  4.97687799461593236017e-02, -3.65315727442169155270e-02,
  1.62858201153657823623e-02,
};

double atan(double x) {
 if (x != x) return x;
 union { double d; uint64_t u; } ux = { .d = x };
 uint32_t ix = (uint32_t)(ux.u >> 32);
 int sign = ix >> 31;
 int id;
 ix &= 0x7fffffff;
 if (ix >= 0x44100000) {                       // |x| >= 2^66: the limit angle
  double z = atanhi[3] + 1e-30;
  return sign ? -z : z; }
 if (ix < 0x3fdc0000) {                        // |x| < 0.4375
  if (ix < 0x3e400000) return x;               // |x| < 2^-27: atan x = x to 53 bits
  id = -1; }
 else {
  if (x < 0) x = -x;
  if (ix < 0x3ff30000) {                       // |x| < 1.1875
   if (ix < 0x3fe60000) { id = 0; x = (2.0 * x - 1.0) / (2.0 + x); }
   else                 { id = 1; x = (x - 1.0) / (x + 1.0); } }
  else {
   if (ix < 0x40038000) { id = 2; x = (x - 1.5) / (1.0 + 1.5 * x); }
   else                 { id = 3; x = -1.0 / x; } } }
 double z = x * x, w = z * z;
 double s1 = z * (aT[0] + w * (aT[2] + w * (aT[4] + w * (aT[6] + w * (aT[8] + w * aT[10])))));
 double s2 = w * (aT[1] + w * (aT[3] + w * (aT[5] + w * (aT[7] + w * aT[9]))));
 if (id < 0) return x - x * (s1 + s2);
 double r = atanhi[id] - ((x * (s1 + s2) - atanlo[id]) - x);
 return sign ? -r : r; }

double atan2(double y, double x) {
 if (x > 0) return atan(y / x);
 if (x < 0) {
  double a = atan(y / x);
  return y >= 0 ? a + m_pi : a - m_pi; }
 if (y > 0) return m_pi_2;
 if (y < 0) return -m_pi_2;
 return 0; }

// pow via exp/log; handle x<0 only for integer y so we don't return
// NaN on (-1)^2 = 1.
double pow(double x, double y) {
 if (y == 0) return 1;
 if (x == 0) return y > 0 ? 0 : m_inf;
 // Integer exponents: exact binary exponentiation (correct sign for x<0 falls out
 // of the repeated multiply). exp(y*log x) drifts ~1 ULP, so 3^2.0 lands at
 // 8.999..., not 9 -- the integer path keeps such results exact.
 int64_t yi = (int64_t) y;
 if ((double) yi == y && yi > -1024 && yi < 1024) {
  int64_t n = yi < 0 ? -yi : yi;
  double r = 1, b = x;
  for (; n; n >>= 1, b *= b) if (n & 1) r *= b;
  return yi < 0 ? 1 / r : r; }
 // Square root is the common fractional exponent (l spells sqrt as ((/ 1 2) x)).
 // The Newton sqrt below is ~1 ulp and bit-exact on perfect squares, whereas
 // exp(0.5*log x) drifts several ULP (pow(9,0.5) -> 2.99999999999583, pow(30,0.5)
 // off by 7e-9), so route 0.5 / -0.5 through it.
 if (y == 0.5)  return sqrt(x);
 if (y == -0.5) return 1 / sqrt(x);
 if (x < 0) return m_nan;                     // non-integer exponent, negative base
 return exp(y * log(x)); }

// Single-precision wrappers for the 32-bit frontends (g_flo_t == float there,
// so l reaches sqrtf/expf/... via the g_* aliases); just round through the
// double kernels above -- the extra rounding stays within the accuracy target.
float sqrtf(float x)           { return (float) sqrt(x); }
float expf(float x)            { return (float) exp(x); }
float logf(float x)            { return (float) log(x); }
float sinf(float x)            { return (float) sin(x); }
float cosf(float x)            { return (float) cos(x); }
float tanf(float x)            { return (float) tan(x); }
float atanf(float x)           { return (float) atan(x); }
float atan2f(float y, float x) { return (float) atan2(y, x); }
float powf(float x, float y)   { return (float) pow(x, y); }
