// a select whose arms cost past two operators branches, either arm laid in place: both answer as written
#include <stdint.h>

struct br { uint64_t c; unsigned u; };
__attribute__((noinline)) static uint64_t peek(struct br const *r, unsigned k) { return r->u >= 64 ? 0 : (r->c << r->u) >> (64 - k); }
__attribute__((noinline)) static int dith(int k, int d) { return d ? (k & 0xf8) | (k >> 5) : k; }
__attribute__((noinline)) static long both(long a, long b, int c) { return c ? a * 3 + (b ^ 5) : (a - b) * (b | 1); }
__attribute__((noinline)) static long nest(long x) { return x < 0 ? -x * 2 + 1 : x > 99 ? (x >> 2) + (x & 7) - 1 : x; }
__attribute__((noinline)) static unsigned cheap(unsigned x) { return x > 255 ? 255 : x; }

int main(void) {
 uint32_t s = 0;
 for (unsigned i = 0; i < 90; i++) {
  struct br r = { 0x9e3779b97f4a7c15ull * (i + 1), i % 70 };
  s = s * 33 + (uint32_t) peek(&r, i % 31 + 1) + (uint32_t) dith((int) i * 3, (int) i & 3);
  s = s * 33 + (uint32_t) both((long) i - 40, (long) i * 7, (int) i % 3) + (uint32_t) nest((long) i * 5 - 200) + cheap(i * 7);
 }
 return (int) (s % 251);
}
