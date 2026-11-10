// an extension goes only where its operand's bounds, through branches, selects and joins, fit it
#include <stdint.h>

__attribute__((noinline)) static int clamp(long k) { k = k < 0 ? 0 : k > 255 ? 255 : k; return (int) k; }
__attribute__((noinline)) static int dith(long k, int d) { k = k < 0 ? 0 : k > 255 ? 255 : k; return (int) (d ? (k & 0xf8) | (k >> 5) : k); }
__attribute__((noinline)) static int hi(long x) { return x < 100 ? (int) x : 7; }
__attribute__((noinline)) static int lo(long x) { return x >= -5 ? (int) x : 7; }
__attribute__((noinline)) static int ub(long x) { return (unsigned long) x < 100 ? (int) x : (int) (x >> 3); }
__attribute__((noinline)) static int join(const int *t, long i, int c) { int v = c ? t[i & 3] : 0; return v - 1; }
__attribute__((noinline)) static int neg(long x) { if (x < -9 || x > 9) return 0; return (int) (x * -1000 - 3) >> 1; }
__attribute__((noinline)) static short nar(long x) { long y = x > 40000 ? 40000 : x; return (short) (y < -40000 ? -40000 : y); }
__attribute__((noinline)) static int loop(long n) { long s = 0; for (long i = 0; i < n; i++) s += i * 3; return (int) s; }

int main(void) {
 static const int t[4] = { -7, 1 << 30, 3, -(1 << 30) };
 static const long xs[] = { -1L << 40, -300, -9, -6, -5, -1, 0, 5, 99, 100, 255, 256, 40001, 1L << 33, (1L << 40) + 77 };
 uint32_t s = 0;
 for (unsigned i = 0; i < sizeof xs / sizeof *xs; i++) {
  long x = (long) ((int64_t) xs[i] >> (sizeof(long) < 8 ? 12 : 0));
  s = s * 31 + (uint32_t) clamp(x) + (uint32_t) dith(x, (int) i & 1) + (uint32_t) hi(x) + (uint32_t) lo(x) + (uint32_t) ub(x);
  s = s * 31 + (uint32_t) join(t, x, (int) i % 3) + (uint32_t) neg(x) + (uint32_t) (uint16_t) nar(x);
 }
 s += (uint32_t) loop(30000);
 return (int) (s % 251);
}
