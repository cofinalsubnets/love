/* crew/cc/lib/math/m.h -- the one header under the vendored fdlibm set
 * (musl 1.1.21 src/math, MIT; bodies verbatim, only this include seam is
 * ours). The raw-syscall ai links these instead of -lm (toolchain rung 4);
 * table-free classic fdlibm, ~1 ulp, corpus-green against the glibc pins.
 * Compiled by aicc: no long double, no _Complex, no hex-float tables. */
#ifndef _AI_M_H
#define _AI_M_H

#include <stdint.h>

typedef double double_t;
typedef float float_t;

#define INFINITY  __builtin_inf()
#define NAN       __builtin_nan("")
#define DBL_EPSILON 2.22044604925031308085e-16

double fabs(double);
double floor(double);
double scalbn(double, int);
double sqrt(double);
double sin(double);
double cos(double);
double atan(double);
double atan2(double, double);
double exp(double);
double log(double);
double pow(double, double);

int __rem_pio2(double, double*);
int __rem_pio2_large(double*, double*, int, int, int);
double __sin(double, double, int);
double __cos(double, double);

#define isnan(x) ((x) != (x))
#define isinf(x) ((x) == INFINITY || (x) == -INFINITY)
#define isfinite(x) (!isnan(x) && !isinf(x))

/* the fdlibm word-access family, over one union shape */
union m_dbits { double f; uint64_t i; };

#define GET_HIGH_WORD(hi,d)                     \
do { union m_dbits __u; __u.f = (d);            \
     (hi) = (uint32_t)(__u.i >> 32); } while (0)

#define GET_LOW_WORD(lo,d)                      \
do { union m_dbits __u; __u.f = (d);            \
     (lo) = (uint32_t)__u.i; } while (0)

#define EXTRACT_WORDS(hi,lo,d)                  \
do { union m_dbits __u; __u.f = (d);            \
     (hi) = (uint32_t)(__u.i >> 32);            \
     (lo) = (uint32_t)__u.i; } while (0)

#define INSERT_WORDS(d,hi,lo)                   \
do { union m_dbits __u;                         \
     __u.i = ((uint64_t)(uint32_t)(hi) << 32) | (uint32_t)(lo); \
     (d) = __u.f; } while (0)

#define SET_HIGH_WORD(d,hi)                     \
do { union m_dbits __u; __u.f = (d);            \
     __u.i = (__u.i & 0xffffffffULL) | ((uint64_t)(uint32_t)(hi) << 32); \
     (d) = __u.f; } while (0)

#define SET_LOW_WORD(d,lo)                      \
do { union m_dbits __u; __u.f = (d);            \
     __u.i = (__u.i & 0xffffffff00000000ULL) | (uint32_t)(lo); \
     (d) = __u.f; } while (0)

/* force evaluation (fdlibm uses it to raise flags; a volatile store is the
 * portable spelling and the value is discarded) */
#define FORCE_EVAL(x)                           \
do { volatile double __v; __v = (x); (void)__v; } while (0)

#endif
