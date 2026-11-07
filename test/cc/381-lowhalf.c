// a 32-bit truncation goes only where every reader takes the low half: a 32-bit op, a narrow store
#include <stdint.h>

__attribute__((noinline)) static unsigned add(uint64_t x, unsigned b) { return b + (unsigned) x; }
__attribute__((noinline)) static unsigned mix(uint64_t x, uint64_t y) { unsigned a = (unsigned) x, c = (unsigned) y; return a * 7 - c ^ (a | 3); }
__attribute__((noinline)) static void put(uint32_t *p, uint64_t x) { *p = (unsigned) x + 1; }
__attribute__((noinline)) static void put2(uint16_t *p, uint64_t x) { *p = (uint16_t) ((unsigned) x * 3); }
__attribute__((noinline)) static uint64_t wide(uint64_t x) { return (unsigned) x; }
__attribute__((noinline)) static uint64_t shr(uint64_t x) { return (uint64_t) (unsigned) x >> 4; }
__attribute__((noinline)) static int idx(const int *t, uint64_t x) { return t[(unsigned) x & 3]; }
__attribute__((noinline)) static int big(uint64_t x) { uint64_t v = (unsigned) x; return v > 0xffffff00u; }
__attribute__((noinline)) static uint64_t sum(const uint64_t *v, int n) { unsigned s = 0; for (int i = 0; i < n; i++) s += (unsigned) v[i]; return s; }
__attribute__((noinline)) static uint64_t lsum(const uint64_t *v, int n) { uint64_t s = 0; for (int i = 0; i < n; i++) s += (unsigned) v[i]; return s; }
__attribute__((noinline)) static unsigned pick(uint64_t x, int c) { uint64_t v = c ? x >> 3 : 0; return 9 + (unsigned) v; }

int main(void) {
 static const int t[4] = { 5, 11, 17, 23 };
 static const uint64_t xs[] = { 0, 1, 0xffffffffu, 0x100000000u, 0xfffffffffffffff0u, 0x123456789abcdefu, 0x80000000u, 0xdeadbeefcafef00du };
 uint32_t s = 0, w; uint16_t h;
 for (unsigned i = 0; i < sizeof xs / sizeof *xs; i++) {
  uint64_t x = xs[i];
  put(&w, x); put2(&h, x);
  s = s * 31 + add(x, i) + mix(x, x >> 7) + w + h + (uint32_t) (wide(x) >> 16) + (uint32_t) shr(x) + (uint32_t) (shr(x) >> 28);
  s = s * 31 + (uint32_t) idx(t, x) + (uint32_t) big(x) + pick(x, (int) i & 1) + (uint32_t) (wide(x) >> 32);
 }
 s += (uint32_t) sum(xs, 8) + (uint32_t) (lsum(xs, 8) >> 32) + (uint32_t) lsum(xs, 8);
 return (int) (s % 251);
}
