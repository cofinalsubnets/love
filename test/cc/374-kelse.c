// an else of one constant or one register: the then may read the register, test it, or branch first
#include <stdint.h>
static const uint8_t t[16] = { 3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3 };

__attribute__((noinline)) static long k0(uint64_t u, int n) { return n < 64 ? (long) (u >> n) : 0; }
__attribute__((noinline)) static long kr(long v, long b, int c) { if (c) v = v * 3 + b; else v = 7; return v; }
__attribute__((noinline)) static long ko(long x) { return x > 5 ? x - 5 : -1; }
__attribute__((noinline)) static long km(long x, long b) { return x & 1 ? t[x & 15] : b; }
__attribute__((noinline)) static long kb(long x) { long r; if (x > 3) { r = x * 2; if (x > 9) r += t[x & 15]; } else r = 40; return r; }

int main(void) {
 long s = 0;
 for (int i = 0; i < 80; i++) {
  s += k0(0x9e3779b97f4a7c15ull, i) & 255;
  s += kr(i, 5, i % 3) + ko(i - 20) + km(i, 11) + kb(i - 10);
 }
 return (int) ((unsigned long) s % 251);
}
