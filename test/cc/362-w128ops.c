// __int128 on every target that has it: divide by any divisor, every shift,
// steps, compares and calls whose pair runs out of registers
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

__attribute__((noinline)) i128 pass7(long a, long b, long c, long d, long e, long f, long g, i128 x) { return x + a + b + c + d + e + f + g; }
__attribute__((noinline)) i128 pass8(long a, long b, long c, long d, long e, long f, long g, long h, i128 x, long y) { return x * 2 + a + b + c + d + e + f + g + h + y; }
__attribute__((noinline)) i128 pass6(long a, long b, long c, long d, long e, long f, i128 x, i128 y) { return x - y + a + b + c + d + e + f; }

volatile u128 vals[] = {
  0, 1, 2, 3, 7, 10, 1000, 0xffffffff, 0x100000000ULL, 0xffffffffffffffffULL, W(1, 0), W(1, 1), W(0x123456789abcdefULL, 0xfedcba9876543210ULL),
  W(0x7fffffffffffffffULL, 0xffffffffffffffffULL), W(0x8000000000000000ULL, 0), W(0xffffffffffffffffULL, 0xffffffffffffffffULL),
  W(0xffffffffffffffffULL, 0xfffffffffffffff9ULL), W(3, 0x8000000000000000ULL),
};
#define N ((int) (sizeof vals / sizeof vals[0]))

int main(void) {
  u128 h = 0;
#define MIX(x) (h = h * 0x100000001b3ULL ^ (u128) (x))
  for (int i = 0; i < N; i++) for (int j = 0; j < N; j++) {
    u128 a = vals[i], b = vals[j];
    i128 sa = a, sb = b;
    MIX(a + b); MIX(a - b); MIX(a * b); MIX(a & b); MIX(a | b); MIX(a ^ b);
    MIX(a < b); MIX(a <= b); MIX(a > b); MIX(a >= b); MIX(a == b); MIX(a != b);
    MIX(sa < sb); MIX(sa <= sb); MIX(sa > sb); MIX(sa >= sb);
    if (b) {
      MIX(a / b); MIX(a % b);
      if (a != W(0x8000000000000000ULL, 0) || sb != -1) { MIX(sa / sb); MIX(sa % sb); }
    }
  }
  pu(h);
  h = 0;
  for (int i = 0; i < N; i++) for (int s = 0; s < 128; s++) {
    u128 a = vals[i];
    i128 sa = a;
    volatile int vs = s;
    MIX(a << vs); MIX(a >> vs); MIX(sa >> vs);
  }
  pu(h);
  u128 k = W(0x123456789abcdefULL, 0xfedcba9876543210ULL);
  i128 m = -(i128) k;
  pu(k << 1); pu(k << 63); pu(k << 64); pu(k << 65); pu(k << 127);
  pu(k >> 1); pu(k >> 63); pu(k >> 64); pu(k >> 65); pu(k >> 127);
  pu(m >> 1); pu(m >> 63); pu(m >> 64); pu(m >> 65); pu(m >> 127);

  u128 st = 0xffffffffffffffffULL;
  pu(++st); pu(st++); pu(--st); pu(st--); pu(-st); pu(~st);
  st += 5; pu(st); st *= st; pu(st); st /= 3; pu(st); st %= 1000; pu(st); st <<= 70; pu(st); st >>= 3; pu(st);
  if (st) mix(1); if (!st) mix(2);
  i128 ms = -1; pu((unsigned) -1); pu((long long) ms); pu((unsigned long long) ms);
  mix((int) (k >> 60)); mix((long long) m);

  pu(pass7(1, 2, 3, 4, 5, 6, 7, k));
  pu(pass8(1, 2, 3, 4, 5, 6, 7, 8, k, 9));
  pu(pass6(1, 2, 3, 4, 5, 6, k, m));
  return answer();
}
