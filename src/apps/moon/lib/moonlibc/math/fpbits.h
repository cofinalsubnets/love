/* the <math.h> members' view of a float's bits */
#pragma once
typedef unsigned long long u64;
static inline u64 bits(double x) { union { double d; u64 u; } b; b.d = x; return b.u; }
static inline double dbl(u64 u) { union { double d; u64 u; } b; b.u = u; return b.d; }
static inline unsigned fbits(float x) { union { float f; unsigned u; } b; b.f = x; return b.u; }
static inline float flt(unsigned u) { union { float f; unsigned u; } b; b.u = u; return b.f; }
#define SGN (1ULL << 63)
