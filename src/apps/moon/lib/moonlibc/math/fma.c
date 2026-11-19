/* src/apps/moon/lib/moonlibc/math/fma.c -- fma, rounded once */
#include "../impl.h"
#include <math.h>
#include "fpbits.h"

/* ---- fma, rounded once: the 106-bit product and the addend aligned in 128 bits, a sticky
 * bit for what falls off the bottom, one round to nearest even (a subnormal shifted first).
 * a64 fuses in one instruction, to the same bits ---- */
#if defined(__aarch64__)
double fma(double a, double b, double c) { double r; __asm__("fmadd %d0, %d1, %d2, %d3" : "=w"(r) : "w"(a), "w"(b), "w"(c)); return r; }
float fmaf(float a, float b, float c) { float r; __asm__("fmadd %s0, %s1, %s2, %s3" : "=w"(r) : "w"(a), "w"(b), "w"(c)); return r; }
#else
typedef struct { u64 hi, lo; } u128;
static u128 __mul64(u64 a, u64 b) {
  u64 a0 = a & 0xffffffff, a1 = a >> 32, b0 = b & 0xffffffff, b1 = b >> 32;
  u64 p00 = a0 * b0, p01 = a0 * b1, p10 = a1 * b0, p11 = a1 * b1;
  u64 mid = (p00 >> 32) + (p01 & 0xffffffff) + (p10 & 0xffffffff);
  u128 r = { p11 + (p01 >> 32) + (p10 >> 32) + (mid >> 32), (mid << 32) | (p00 & 0xffffffff) };
  return r; }
static int __clz128(u128 a) {
  int n = 0; u64 w = a.hi;
  if (!w) { n = 64; w = a.lo; }
  for (; !(w >> 63); w <<= 1) n++;
  return n; }
static u128 __shl(u128 a, int s) {
  if (s == 0) return a;
  if (s >= 64) { u128 r = { a.lo << (s - 64), 0 }; return r; }
  u128 r = { a.hi << s | a.lo >> (64 - s), a.lo << s }; return r; }
static u128 __shr(u128 a, int s, int *st) {        /* right, what falls off into *st */
  if (s == 0) return a;
  if (s >= 128) { *st |= (a.hi | a.lo) != 0; u128 z = { 0, 0 }; return z; }
  if (s >= 64) {
    *st |= (a.lo | (s > 64 ? a.hi << (128 - s) : 0)) != 0;
    u128 r = { 0, a.hi >> (s - 64) }; return r; }
  *st |= (a.lo << (64 - s)) != 0;
  u128 r = { a.hi >> s, a.lo >> s | a.hi << (64 - s) }; return r; }
static int __split(double x, u64 *m) {             /* x = m * 2^e, m a positive integer */
  u64 u = bits(x); int e = (int) (u >> 52 & 2047);
  *m = u & (~0ULL >> 12);
  if (e) { *m |= 1ULL << 52; return e - 1075; }
  return -1074; }
double fma(double a, double b, double c) {
  if (a - a != 0 || b - b != 0 || c - c != 0 || a == 0 || b == 0 || c == 0) return a * b + c;
  u64 ma, mb, mc;
  int ea = __split(a, &ma), eb = __split(b, &mb), ec = __split(c, &mc);
  int sp = __signbit(a) ^ __signbit(b), sc = __signbit(c), st = 0;
  u128 p = __mul64(ma, mb), q = { 0, mc };
  int lp = __clz128(p), lq = __clz128(q);
  p = __shl(p, lp); q = __shl(q, lq);
  int Ep = ea + eb - lp + 127, Eq = ec - lq + 127;  /* value = M * 2^(E - 127), M's top bit 127 */
  if (Ep < Eq || (Ep == Eq && (p.hi < q.hi || (p.hi == q.hi && p.lo < q.lo)))) {
    u128 t = p; p = q; q = t; int e = Ep; Ep = Eq; Eq = e; int s = sp; sp = sc; sc = s; }
  q = __shr(q, Ep - Eq, &st);
  int E = Ep;
  u128 r;
  if (sp == sc) {
    r.lo = p.lo + q.lo; r.hi = p.hi + q.hi + (r.lo < p.lo);
    if (r.hi < p.hi || (r.hi == p.hi && r.lo < p.lo)) {   /* a carry out of bit 127 */
      r = __shr(r, 1, &st); r.hi |= SGN; E++; } }
  else {
    u64 bw = st;                                  /* a sticky subtrahend is a little larger */
    r.lo = p.lo - q.lo - bw;
    r.hi = p.hi - q.hi - (p.lo < q.lo || (p.lo == q.lo && bw));
    if (!r.hi && !r.lo && !st) return 0.0;
    int z = __clz128(r);
    r = __shl(r, z); E -= z; }
  if (E < -1022) { r = __shr(r, -1022 - E, &st); E = -1022; }
  u64 m = r.hi >> 11, g = (r.hi >> 10) & 1;
  int rest = (r.hi & 0x3ff) || r.lo || st;
  if (g && (rest || (m & 1))) m++;
  if (m >> 53) { m >>= 1; E++; }
  u64 s = (u64) sp << 63;
  if (E > 1023) return dbl(s | 0x7ff0000000000000ULL);
  if (m >> 52) return dbl(s | (u64) (E + 1023) << 52 | (m & (~0ULL >> 12)));
  return dbl(s | m); }
/* fmaf: the product is exact in double; the sum rounds to odd there, so the float round is the one.
 * an infinite or nan sum stands: its error term is a nan */
float fmaf(float a, float b, float c) {
  double p = (double) a * b, s = p + c, bb = s - p, e = (p - (s - bb)) + (c - bb);
  if (s - s == 0 && e != 0 && !(bits(s) & 1)) s = dbl(bits(s) + ((e > 0) == (s > 0) ? 1 : -1));
  return (float) s; }
#endif
