// __int128 to and from float and double, rounding once
#ifdef SHOW
#include <stdio.h>
#endif
static unsigned long long hash = 14695981039346656037ULL;
static void mix(unsigned long long x) {
#ifdef SHOW
  printf("%llx\n", x);
#endif
  for (int i = 0; i < 8; i++, x >>= 8) hash = (hash ^ (x & 255)) * 1099511628211ULL; }
static int answer(void) { return (int) ((hash ^ hash >> 32) % 251); }
typedef unsigned __int128 u128;
typedef __int128 i128;
#define W(h, l) (((u128) (h) << 64) | (unsigned long long) (l))
static void pu(u128 x) { mix(x >> 64); mix((unsigned long long) x); }
static void bits(const void *p, int n) { const unsigned char *b = p; for (int i = 0; i < n; i++) mix(b[i]); }
#define bd(x) do { double t_ = (x); bits(&t_, sizeof t_); } while (0)
#define bf(x) do { float t_ = (x); bits(&t_, sizeof t_); } while (0)
volatile u128 vals[] = {
  0, 1, 3, 1000, 0xffffffffffffffffULL, W(1, 0), W(1, 1), W(0x123456789abcdefULL, 0xfedcba9876543210ULL),
  W(0x7fffffffffffffffULL, 0xffffffffffffffffULL), W(0x8000000000000000ULL, 0), W(0xffffffffffffffffULL, 0xffffffffffffffffULL),
  W(0xffffffffffffffffULL, 0xfffffffffffffff9ULL), W(3, 0x8000000000000000ULL),
};
#define N ((int) (sizeof vals / sizeof vals[0]))
int main(void) {
  double ds[] = { 0.0, 0.5, 1.0, 1.5, -1.5, 1e10, -1e10, 1e19, 1.8446744073709552e19, 3.5e25, -3.5e25, 1.7e38, -1.7e38 };
  for (int i = 0; i < (int) (sizeof ds / sizeof ds[0]); i++) {
    volatile double d = ds[i];
    pu((i128) d);
    if (d >= 0) pu((u128) d);
    volatile float f = (float) d;
    pu((i128) f);
    if (f >= 0) pu((u128) f);
  }
  for (int i = 0; i < N; i++) {
    volatile u128 a = vals[i];
    volatile i128 sa = (i128) a;
    bd(a); bd(sa); bf(a); bf(sa);
  }
  // past the top 64 bits: the bits below decide the rounding
  volatile u128 r1 = W(0x20000000000001ULL, 0) | 1, r2 = W(0x20000000000001ULL, 0), r3 = W(0x1000001ULL << 32, 1), r4 = W(0x1000001ULL << 32, 0);
  bd(r1); bd(r2); bf(r3); bf(r4);

  return answer();
}
