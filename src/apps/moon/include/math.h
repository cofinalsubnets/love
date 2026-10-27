#ifndef _LOVE_MATH_H
#define _LOVE_MATH_H
/* long double is double here */
typedef float float_t;
typedef double double_t;
#define HUGE_VAL 1e999   /* overflows to +inf */
#define HUGE_VALF 1e999f
#define HUGE_VALL 1e999
#define INFINITY 1e999f
#define NAN (0.0f / 0.0f)
#define FP_NAN 0
#define FP_INFINITE 1
#define FP_ZERO 2
#define FP_SUBNORMAL 3
#define FP_NORMAL 4
#define FP_ILOGB0 (-2147483647 - 1)
#define FP_ILOGBNAN (-2147483647 - 1)
#define MATH_ERRNO 1
#define MATH_ERREXCEPT 2
#define math_errhandling 0
int __fpclassify(double), __fpclassifyf(float), __signbit(double), __signbitf(float);
#define fpclassify(x) (sizeof (x) == sizeof (float) ? __fpclassifyf(x) : __fpclassify(x))
#define signbit(x) (sizeof (x) == sizeof (float) ? __signbitf(x) : __signbit(x))
#define isnan(x) ((x) != (x))
#define isinf(x) (fpclassify(x) == FP_INFINITE)
#define isfinite(x) (fpclassify(x) > FP_INFINITE)
#define isnormal(x) (fpclassify(x) == FP_NORMAL)
#define isunordered(x, y) (isnan(x) || isnan(y))
#define isgreater(x, y) (!isunordered(x, y) && (x) > (y))
#define isgreaterequal(x, y) (!isunordered(x, y) && (x) >= (y))
#define isless(x, y) (!isunordered(x, y) && (x) < (y))
#define islessequal(x, y) (!isunordered(x, y) && (x) <= (y))
#define islessgreater(x, y) (!isunordered(x, y) && (x) != (y))
#define M_E        2.7182818284590452354
#define M_LOG2E    1.4426950408889634074
#define M_LOG10E   0.43429448190325182765
#define M_LN2      0.69314718055994530942
#define M_LN10     2.30258509299404568402
#define M_PI       3.14159265358979323846
#define M_PI_2     1.57079632679489661923
#define M_PI_4     0.78539816339744830962
#define M_1_PI     0.31830988618379067154
#define M_2_PI     0.63661977236758134308
#define M_2_SQRTPI 1.12837916709551257390
#define M_SQRT2    1.41421356237309504880
#define M_SQRT1_2  0.70710678118654752440
double sin(double), cos(double), tan(double);
double asin(double), acos(double), atan(double);
double sinh(double), cosh(double), tanh(double), asinh(double), acosh(double), atanh(double);
double exp(double), exp2(double), expm1(double), log(double), log2(double), log10(double), log1p(double);
double sqrt(double), cbrt(double), hypot(double, double), fabs(double), floor(double), ceil(double);
double trunc(double), round(double), rint(double), nearbyint(double);
long lrint(double), lround(double);
long long llrint(double), llround(double);
double atan2(double, double), pow(double, double), fmod(double, double);
double remainder(double, double), remquo(double, double, int *);
double frexp(double, int *), ldexp(double, int), modf(double, double *);
double scalbn(double, int), scalbln(double, long), logb(double);
int ilogb(double);
double copysign(double, double), nextafter(double, double), nexttoward(double, long double), nan(char const *);
double fmax(double, double), fmin(double, double), fdim(double, double), fma(double, double, double);
double erf(double), erfc(double), tgamma(double), lgamma(double);
extern int signgam;
/* the float twins: the double face narrowed once at the return */
float sinf(float), cosf(float), tanf(float);
float asinf(float), acosf(float), atanf(float), asinhf(float), acoshf(float), atanhf(float);
float expf(float), exp2f(float), expm1f(float), logf(float), log2f(float), log10f(float), log1pf(float);
float sqrtf(float), cbrtf(float), hypotf(float, float), fabsf(float), floorf(float), ceilf(float);
float truncf(float), roundf(float), rintf(float), nearbyintf(float);
long lrintf(float), lroundf(float);
long long llrintf(float), llroundf(float);
float atan2f(float, float), powf(float, float), fmodf(float, float);
float remainderf(float, float), remquof(float, float, int *);
float frexpf(float, int *), ldexpf(float, int), modff(float, float *), scalbnf(float, int), logbf(float);
int ilogbf(float);
float copysignf(float, float), nextafterf(float, float), nexttowardf(float, long double), nanf(char const *);
float fmaxf(float, float), fminf(float, float), fdimf(float, float), fmaf(float, float, float);
float erff(float), erfcf(float), tgammaf(float), lgammaf(float);
/* long double twins, where a port asks for one */
long double ldexpl(long double, int), frexpl(long double, int *);
#endif
