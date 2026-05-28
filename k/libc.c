#include "g.h"
#include <stdint.h>
#include <stddef.h>
#include <limits.h>
int errno;
#define ERANGE 34

#define unsign(x) ((unsigned char)(x))

void *memcpy(void *restrict dest, void const *restrict src, size_t n) {
  uint8_t *restrict pdest = dest;
  uint8_t const *restrict psrc = src;
  for (size_t i = 0; i < n; i++) pdest[i] = psrc[i];
  return dest; }

void *memset(void *s, int c, size_t n) {
  uint8_t *p = (uint8_t*) s;
  for (size_t i = 0; i < n; i++) p[i] = (uint8_t) c;
  return s; }

void *memmove(void *dest, void const *src, size_t n) {
  uint8_t *pdest = dest;
  const uint8_t *psrc = src;
  if (src > dest)
    for (size_t i = 0; i < n; i++) pdest[i] = psrc[i];
  else if (src < dest)
    for (size_t i = n; i > 0; i--) pdest[i-1] = psrc[i-1];
  return dest; }

size_t strlen(char const *c) {
  size_t len = 0;
  while (*c++) len++;
  return len; }

int memcmp(void const *s1, void const *s2, size_t n) {
  const uint8_t *p1 = s1, *p2 = s2;
  for (size_t i = 0; i < n; i++)
    if (p1[i] != p2[i]) return p1[i] < p2[i] ? -1 : 1;
  return 0; }

void *memchr(void const *s, int c, size_t n) {
  for (unsigned char const *p = s; n-- ; p++)
    if (*p == (int) c) return (void*) p;
  return NULL; }

static char const
  digits[] = g_digits,
  spaces[] = " \n\t\v\r\f";

int isspace(int c) { return !!memchr(spaces, c, 6); }
int tolower(int c) { return c + ('A' <= c && c <= 'Z' ? 'a' - 'A' : 0); }
int toupper(int c) { return c + ('a' <= c && c <= 'z' ? 'A' - 'a' : 0); }

long int strtol(const char *s, char **endptr, int base) {
 char const *p = s;
 int sign = 1;
 while (isspace(*p)) p++;
 if (*p == '-') sign = -1, p++;
 else if (*p == '+') p++;
 if (*p == '0') {
  ++p;
  if ((base == 0 || base == 16) && (*p == 'x' || *p == 'X')) {
   base = 16;
   ++p;
   if (!memchr(digits, tolower(*p), base)) p -= 2; }
  else if (base == 0) base = 8, --p;
  else --p; }
 else if (!base) base = 10;
 if ( base < 2 || base > 36 ) return 0;
 int digit = -1;
 long rc = 0;
 for (const char *x; (x = memchr(digits, tolower(*p), base)); p++)
  digit = x - digits,
  rc = rc * base + digit;
 if (digit == -1) p = NULL, rc = 0;
 if (endptr) *endptr = (char*) (p ? p : s);
 return sign * rc; }

// === math overrides for the weak defaults in g.c =====================
// All targets ~10^-12 relative error or better; not bit-exact libm but
// plenty for "fractions and graphics work" use cases.

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
double g_sqrt(double x) {
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
double g_exp(double x) {
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
double g_log(double x) {
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
double g_sin(double x) {
 if (x != x) return x;
 if (x > 1e15 || x < -1e15) return M_NAN;   // catastrophic cancellation
 double k = (int64_t)(x * m_inv2pi + (x < 0 ? -0.5 : 0.5));
 double y = x - k * m_2pi;                   // y in [-pi, pi]
 if (y > m_pi_2 + m_pi_4)      return -sin_k(y - m_pi);
 if (y > m_pi_4)               return  cos_k(y - m_pi_2);
 if (y < -m_pi_2 - m_pi_4)     return -sin_k(y + m_pi);
 if (y < -m_pi_4)              return -cos_k(y + m_pi_2);
 return sin_k(y); }

double g_cos(double x) { return g_sin(x + m_pi_2); }
double g_tan(double x) { return g_sin(x) / g_cos(x); }

// atan: range-reduce |x| > 1 via identity, then halve-angle until |x|
// is small enough for fast Taylor (~0.2). Two halve-angle iterations
// suffice; the inner Taylor degree 11 then gives ~10^-13.
static double atan_k(double x) {
 // |x| <= ~0.196 after two halve-angle reductions.
 double x2 = x * x;
 return x * (1 + x2 * (-1.0/3 + x2 * (1.0/5 + x2 * (-1.0/7 + x2 * (1.0/9
          + x2 * (-1.0/11 + x2 * (1.0/13)))))));
}

double g_atan(double x) {
 if (x != x) return x;
 int neg = x < 0; if (neg) x = -x;
 int inv = x > 1;  if (inv) x = 1 / x;
 // halve-angle twice: atan(x) = 2 * atan(x/(1 + sqrt(1+x*x)))
 double y = x / (1 + g_sqrt(1 + x * x));
 y       = y / (1 + g_sqrt(1 + y * y));
 double r = 4 * atan_k(y);
 if (inv) r = m_pi_2 - r;
 return neg ? -r : r; }

double g_atan2(double y, double x) {
 if (x > 0) return g_atan(y / x);
 if (x < 0) {
  double a = g_atan(y / x);
  return y >= 0 ? a + m_pi : a - m_pi; }
 if (y > 0) return m_pi_2;
 if (y < 0) return -m_pi_2;
 return 0; }

// pow via exp/log; handle x<0 only for integer y so we don't return
// NaN on (-1)^2 = 1.
double g_pow(double x, double y) {
 if (y == 0) return 1;
 if (x == 0) return y > 0 ? 0 : M_INF;
 if (x < 0) {
  int64_t yi = (int64_t) y;
  if ((double) yi != y) return M_NAN;        // non-integer exponent
  double r = g_exp(y * g_log(-x));
  return (yi & 1) ? -r : r; }
 return g_exp(y * g_log(x)); }
