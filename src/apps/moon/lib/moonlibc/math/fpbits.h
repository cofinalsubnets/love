/* the <math.h> members' view of a float's bits */
#pragma once
typedef unsigned long long u64;
static inline u64 bits(double x) { union { double d; u64 u; } b; b.d = x; return b.u; }
static inline double dbl(u64 u) { union { double d; u64 u; } b; b.u = u; return b.d; }
static inline unsigned fbits(float x) { union { float f; unsigned u; } b; b.f = x; return b.u; }
static inline float flt(unsigned u) { union { float f; unsigned u; } b; b.u = u; return b.f; }
#define SGN (1ULL << 63)
#define FSGN 0x80000000u
/* double in software (thumb1, thumb2sp, soft rv32 and xtensa): the float forms run on float
 * bits. with a double unit, widening to the double twin is smaller and as fast */
#if (defined(__arm__) && !(defined(__ARM_FP) && (__ARM_FP & 8))) || defined(__riscv_float_abi_soft) \
    || defined(__XTENSA_SOFT_FLOAT__)
#define fp_dsoft 1
#else
#define fp_dsoft 0
#endif
