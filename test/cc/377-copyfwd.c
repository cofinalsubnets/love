// past a copy, reads of its source read the copy where that lets the source die there
#include <stdint.h>

__attribute__((noinline)) static long clamp(long k) { long t = k; if (k > 255) t = 255; k = t; return k < 0 ? 0 : k; }
__attribute__((noinline)) static long pick(long v, long c) { long t = v; if (c) t = v; return t + v; }
__attribute__((noinline)) static long redef(long v, long w) { long t = v; v = w * 3; return t - v + (t >> 2); }
__attribute__((noinline)) static long chain(long a, long b) { long c = a; long d = c; long e = d; return (e ^ b) + (e >> 3); }
__attribute__((noinline)) static uint32_t q8(uint32_t k, int d) { return d ? (k & 0xf8) | (k >> 5) : k; }

int main(void) {
 long s = 0;
 for (long i = -40; i < 400; i += 7) {
  s += clamp(i) + pick(i, i & 1) + redef(i, i ^ 5) + chain(i, i * 9) + q8((uint32_t) i, (int) i & 3);
 }
 return (int) ((unsigned long) s % 251);
}
