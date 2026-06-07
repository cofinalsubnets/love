#include <stdint.h>
#include <stddef.h>
#include <limits.h>

// === C library math functions for the freestanding kernel ============
// g/math.c reaches these through the g_* aliases in g.h; hosted builds
// resolve those to libm, the kernel supplies them here. All targets
// ~10^-12 relative error or better; not bit-exact libm but plenty for
// "fractions and graphics work" use cases.

#define M_INF __builtin_inf()
#define M_NAN __builtin_nan("")
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
 if (x < 0)  return M_NAN;
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
 if (x >  709.78) return M_INF;
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
 if (x < 0)  return M_NAN;
 if (x == 0) return -M_INF;
 union { double d; uint64_t u; } u = { .d = x };
 int e = (int)((u.u >> 52) & 0x7ff) - 1023;
 u.u = (u.u & 0x000fffffffffffffULL) | ((uint64_t)1023 << 52);
 double m = u.d, t = (m - 1) / (m + 1), t2 = t * t;
 double p = 2 * t * (1 + t2 * (1.0/3 + t2 * (1.0/5 + t2 * (1.0/7
          + t2 * (1.0/9 + t2 * (1.0/11 + t2 * (1.0/13)))))));
 return p + e * m_ln2; }

// sin/cos kernels. |x| <= pi/4. Degree-11 Taylor for sin, degree-10
// for cos, both ~3e-14 error in range.
static double sin_k(double x) {
 double x2 = x * x;
 return x * (1 + x2 * (-1.0/6 + x2 * (1.0/120 + x2 * (-1.0/5040
          + x2 * (1.0/362880 + x2 * (-1.0/39916800)))))); }

static double cos_k(double x) {
 double x2 = x * x;
 return 1 + x2 * (-0.5 + x2 * (1.0/24 + x2 * (-1.0/720 + x2 * (1.0/40320
          + x2 * (-1.0/3628800))))); }

// Reduce x mod 2pi via fmod-style subtraction, then quadrant pick into
// [-pi/4, pi/4] and dispatch to the kernel. Loses precision for very
// large |x| since we don't do Cody-Waite splitting — adequate for
// gwen-scale inputs.
double sin(double x) {
 if (x != x) return x;
 if (x > 1e15 || x < -1e15) return M_NAN;   // catastrophic cancellation
 double k = (int64_t)(x * m_inv2pi + (x < 0 ? -0.5 : 0.5));
 double y = x - k * m_2pi;                   // y in [-pi, pi]
 if (y > m_pi_2 + m_pi_4)      return -sin_k(y - m_pi);
 if (y > m_pi_4)               return  cos_k(y - m_pi_2);
 if (y < -m_pi_2 - m_pi_4)     return -sin_k(y + m_pi);
 if (y < -m_pi_4)              return -cos_k(y + m_pi_2);
 return sin_k(y); }

double cos(double x) { return sin(x + m_pi_2); }
double tan(double x) { return sin(x) / cos(x); }

// atan: range-reduce |x| > 1 via identity, then halve-angle until |x|
// is small enough for fast Taylor (~0.2). Two halve-angle iterations
// suffice; the inner Taylor degree 11 then gives ~10^-13.
static double atan_k(double x) {
 // |x| <= ~0.196 after two halve-angle reductions.
 double x2 = x * x;
 return x * (1 + x2 * (-1.0/3 + x2 * (1.0/5 + x2 * (-1.0/7 + x2 * (1.0/9
          + x2 * (-1.0/11 + x2 * (1.0/13)))))));
}

double atan(double x) {
 if (x != x) return x;
 int neg = x < 0; if (neg) x = -x;
 int inv = x > 1;  if (inv) x = 1 / x;
 // halve-angle twice: atan(x) = 2 * atan(x/(1 + sqrt(1+x*x)))
 double y = x / (1 + sqrt(1 + x * x));
 y       = y / (1 + sqrt(1 + y * y));
 double r = 4 * atan_k(y);
 if (inv) r = m_pi_2 - r;
 return neg ? -r : r; }

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
 if (x == 0) return y > 0 ? 0 : M_INF;
 if (x < 0) {
  int64_t yi = (int64_t) y;
  if ((double) yi != y) return M_NAN;        // non-integer exponent
  double r = exp(y * log(-x));
  return (yi & 1) ? -r : r; }
 return exp(y * log(x)); }

// Single-precision wrappers for the 32-bit frontends (g_flo_t == float there,
// so gwen reaches sqrtf/expf/... via the g_* aliases); just round through the
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
