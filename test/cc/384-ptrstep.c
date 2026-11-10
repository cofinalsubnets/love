// a loop's indexed addresses stepped as pointers: counters signed and unsigned, from past zero, by
// two, over each width; a counter read after its loop, a continue, a break, no trips, a base the
// loop moves, and arrays that overlap
#include <stdint.h>

__attribute__((noinline)) static void vmul(float *r, const float *a, const float *b, unsigned n) { for (unsigned p = 0; p < n; p++) r[p] = a[p] * b[p]; }
__attribute__((noinline)) static void vadd(int *r, const int *a, int n) { for (int i = 0; i < n; i++) r[i] = a[i] + i; }
__attribute__((noinline)) static unsigned from(const unsigned *a, unsigned s, unsigned n) { unsigned t = 0; for (unsigned i = s; i < n; i++) t = t * 3 + a[i]; return t; }
__attribute__((noinline)) static unsigned two(const uint16_t *a, unsigned n) { unsigned t = 0; for (unsigned i = 0; i < n; i += 2) t += a[i] * (i + 1); return t; }
__attribute__((noinline)) static unsigned bytes(const uint8_t *a, uint8_t *b, unsigned n) { for (unsigned i = 0; i < n; i++) b[i] = (uint8_t) (a[i] ^ 0x5a); return b[n - 1]; }
__attribute__((noinline)) static double dbl(const double *a, unsigned n) { double t = 0; for (unsigned i = 0; i < n; i++) t += a[i]; return t; }
__attribute__((noinline)) static unsigned after(const float *a, unsigned n) { unsigned i; float t = 0; for (i = 0; i < n; i++) { if (a[i] == 77) break; t += a[i]; } return (unsigned) t * 1000 + i; }
__attribute__((noinline)) static unsigned skip(const float *a, float *b, unsigned n) { float t = 0; for (unsigned i = 0; i < n; i++) { if (a[i] > 5) continue; b[i] = a[i] / 2; t += b[i]; } return (unsigned) (t * 8); }
__attribute__((noinline)) static unsigned moves(const float *a, unsigned n) { float t = 0; for (unsigned i = 0; i < n; i++) { t += a[i]; if (t > 9) a = a + 1; } return (unsigned) t; }
__attribute__((noinline)) static void shift(float *a, unsigned n) { for (unsigned i = 0; i < n; i++) a[i + 1] = a[i] + 1; }
__attribute__((noinline)) static void lap(float *r, const float *a, unsigned n) { for (unsigned i = 0; i < n; i++) r[i] = a[i] + r[i]; }
__attribute__((noinline)) static unsigned dw(const float *a, unsigned n) { unsigned i = 0; float t = 0; do { t = t * 2 + a[i]; i++; } while (i < n); return (unsigned) t; }

int main(void) {
 float fa[9], fb[9], fr[9], ga[16], gb[16]; int ia[9], ir[9]; unsigned ua[16], ub[16], s = 0; uint16_t ha[9]; uint8_t ba[9], bb[9]; double da[9];
 for (int i = 0; i < 9; i++) fa[i] = (float) i * 0.5f, fb[i] = 3 - (float) i, ia[i] = i * 7 - 20, ha[i] = (uint16_t) (i * 300), ba[i] = (uint8_t) (i * 41), da[i] = i * 1.25;
 for (int i = 0; i < 16; i++) ua[i] = (unsigned) (i * 13 % 11), ub[i] = 0, ga[i] = (float) (i * 13 % 11), gb[i] = 0;
 ga[6] = 77;
 vmul(fr, fa, fb, 9); vmul(fr + 9, fa, fb, 0);
 for (int i = 0; i < 9; i++) s = s * 31 + (unsigned) (int) (fr[i] * 4);
 vadd(ir, ia, 9); vadd(ir, ia, -3);
 for (int i = 0; i < 9; i++) s = s * 31 + (unsigned) ir[i];
 s = s * 31 + from(ua, 3, 12) + from(ua, 9, 2) * 5 + two(ha, 9) + two(ha, 0) + bytes(ba, bb, 9) * 7 + (unsigned) dbl(da, 9);
 s = s * 31 + after(ga, 16) + after(ga, 4) * 3 + skip(ga, gb, 16) + (unsigned) (gb[4] + gb[5] * 9) + moves(ga, 10) + dw(ga, 11) + dw(ga, 1);
 lap(fr, fr + 1, 8); shift(ga, 8);
 for (int i = 0; i < 16; i++) s = s * 31 + (unsigned) ga[i];
 for (int i = 0; i < 9; i++) s = s * 31 + (unsigned) (int) (fr[i] * 4);
 return (int) (s % 251);
}
