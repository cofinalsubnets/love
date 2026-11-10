// 128-bit divides and float conversions, by the names gcc's and clang's objects call
#ifdef __SIZEOF_INT128__
#include <stdint.h>
typedef unsigned __int128 u128;
typedef __int128 i128;

static int32_t clz128(u128 x) {
  uint64_t h = x >> 64;
  return h ? __builtin_clzll(h) : (uint64_t) x ? 64 + __builtin_clzll((uint64_t) x) : 128; }

static u128 udm(u128 n, u128 d, u128 *rem) {
  u128 q = 0;
  if (!(n >> 64) && !(d >> 64) && (uint64_t) d) {
    *rem = (uint64_t) n % (uint64_t) d;
    return (uint64_t) n / (uint64_t) d; }
  int32_t s = clz128(d) - clz128(n);
  if (s >= 0 && d) {
    d <<= s;
    for (; s >= 0; s--, d >>= 1) {
      q <<= 1;
      if (n >= d) n -= d, q |= 1; } }
  *rem = n;
  return q; }

u128 __udivti3(u128 n, u128 d) { u128 r; return udm(n, d, &r); }
u128 __umodti3(u128 n, u128 d) { u128 r; udm(n, d, &r); return r; }
i128 __divti3(i128 n, i128 d) {
  u128 r, q = udm(n < 0 ? -(u128) n : n, d < 0 ? -(u128) d : d, &r);
  return (n < 0) != (d < 0) ? -q : q; }
i128 __modti3(i128 n, i128 d) {
  u128 r;
  udm(n < 0 ? -(u128) n : n, d < 0 ? -(u128) d : d, &r);
  return n < 0 ? -r : r; }

// the top 64 bits, what falls off sticking to the last, round once
static uint64_t top64(u128 x, int32_t *s) {
  *s = 64 - __builtin_clzll((uint64_t) (x >> 64));
  return (uint64_t) (x >> *s) | ((x & (((u128) 1 << *s) - 1)) != 0); }
#define SCALE(s) ((double) (1ULL << (s) / 2) * (double) (1ULL << ((s) - (s) / 2)))

double __floatuntidf(u128 x) {
  if (!(x >> 64)) return (uint64_t) x;
  int32_t s;
  uint64_t t = top64(x, &s);
  return (double) t * SCALE(s); }
float __floatuntisf(u128 x) {
  if (!(x >> 64)) return (uint64_t) x;
  int32_t s;
  uint64_t t = top64(x, &s);
  return (float) t * (float) SCALE(s); }
double __floattidf(i128 x) { return x < 0 ? -__floatuntidf(-(u128) x) : __floatuntidf(x); }
float __floattisf(i128 x) { return x < 0 ? -__floatuntisf(-(u128) x) : __floatuntisf(x); }

u128 __fixunsdfti(double d) {
  if (!(d >= 1)) return 0;
  uint64_t h = d / 18446744073709551616.0;
  return (u128) h << 64 | (uint64_t) (d - (double) h * 18446744073709551616.0); }
i128 __fixdfti(double d) { return d < 0 ? -__fixunsdfti(-d) : __fixunsdfti(d); }
u128 __fixunssfti(float f) { return __fixunsdfti(f); }
i128 __fixsfti(float f) { return __fixdfti(f); }
#endif
