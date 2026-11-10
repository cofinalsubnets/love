// a copy's two sides share a register only where they never live at once: chains, swaps, clamps
#include <stdint.h>

__attribute__((noinline)) static int clamp(double f, int b) { int v = (int) f + b; v = v < 0 ? 0 : v > 255 ? 255 : v; return v; }
__attribute__((noinline)) static int lim(int e, int k) { int d = 323 - e; int r = k == 101 ? (e < 323 ? e : 323) : d; return r + (k == 101 ? e : 323); }
__attribute__((noinline)) static uint32_t fib(int n) { uint32_t a = 0, b = 1; for (int i = 0; i < n; i++) { uint32_t t = a + b; a = b; b = t; } return a; }
__attribute__((noinline)) static uint32_t swap(int n, uint32_t x, uint32_t y) { for (int i = 0; i < n; i++) { uint32_t t = x; x = y ^ (uint32_t) i; y = t; } return x * 3 + y; }
__attribute__((noinline)) static uint32_t chain(const uint8_t *p, int n) {
 uint32_t s = 0, c = 0, d;
 for (int i = 0; i < n; i++) { d = p[i]; c = d > 128 ? d - 128 : d; s = s * 7 + (c < 64 ? c : 64 - c); d = s; s = d >> 1 ^ d; }
 return s + c;
}

__attribute__((noinline)) static uint32_t px(const double *f, int n, int b, int e) {
 uint32_t s = 0, h = 7; int k = b;
 for (int i = 0; i < n; i++) {
  double a = f[i & 7] * (i + 1);
  int v = (int) a + k, w = (int) (a * 0.5) - k, d = e - i;
  v = v < 0 ? 0 : v > 255 ? 255 : v;
  w = w < 0 ? 0 : w > 255 ? 255 : w;
  int r = (i & 1) == 0 ? (d < 323 ? d : 323) : 323 - d;
  int t = v; v = w; w = t;
  s = s * 31 + (uint32_t) (v * 3 + w) + (uint32_t) r;
  h = h ^ (s >> 3) ^ (uint32_t) k; k = k + (v > w ? 1 : -1);
 }
 return s + h + (uint32_t) k;
}

int main(void) {
 static const double fs[] = { -9.5, 0.2, 77.9, 254.6, 300.1, 1e3, -1e3, 12.25, 3.5 };
 uint8_t buf[64]; uint32_t s = 0;
 for (int i = 0; i < 64; i++) buf[i] = (uint8_t) (i * 37 + 11);
 for (int i = 0; i < 6; i++) s = s * 31 + (uint32_t) clamp(fs[i], i * 3 - 4) + (uint32_t) lim(i * 90, i & 1 ? 101 : 7);
 s += fib(40) + swap(13, 5, 9) + swap(14, 5, 9) + chain(buf, 64);
 s += px(fs, 1000, 3, 400) + px(fs + 1, 333, -7, 9);
 return (int) (s % 251);
}
