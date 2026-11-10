// more singles and doubles live than the caller-saved file holds, across calls and recursion: a
// callee that takes a callee-saved float register puts it back
#include <stdint.h>

__attribute__((noinline)) static float churn(float x, int d) {
 float a = x + 1, b = x * 2, c = x - 3, e = x * x, f = a * b, g = c - e, h = f + g, k = h * 0.5f;
 float m = a * c, n = b * e, p = m - n, q = p * 0.25f;
 float r = d > 0 ? churn(x * 0.5f + q, d - 1) : x;
 return a + b + c + e + f + g + h + k + m + n + p + q + r;
}
__attribute__((noinline)) static double dchurn(double x, int d) {
 double a = x + 1, b = x * 2, c = x - 3, e = x * x, f = a * b, g = c - e, h = f + g, k = h * 0.5;
 double r = d > 0 ? dchurn(x * 0.25 + k * 0.001, d - 1) : x;
 return a + b + c + e + f + g + h + k + r;
}
__attribute__((noinline)) static float leaf(float x) { return x * 1.5f; }
__attribute__((noinline)) static float loop(const float *v, int n) {
 float s0 = 0, s1 = 1, s2 = 2, s3 = 3, s4 = 4, s5 = 5, s6 = 6, s7 = 7, s8 = 8, s9 = 9, s10 = 10, s11 = 11;
 for (int i = 0; i < n; i++) {
  float x = leaf(v[i]);
  s0 += x; s1 *= 1.01f; s2 -= x; s3 += s0; s4 += s1; s5 -= s2; s6 += x * s3 * 0.001f; s7 += s4 * 0.01f;
  s8 += s5; s9 -= s6; s10 += s7; s11 += leaf(s8) * 0.001f;
 }
 return s0 + s1 + s2 + s3 + s4 + s5 + s6 + s7 + s8 + s9 + s10 + s11;
}

int main(void) {
 float v[10];
 for (int i = 0; i < 10; i++) v[i] = (float) i * 0.5f - 1.75f;
 int32_t s = (int32_t) churn(0.75f, 6) * 7 + (int32_t) (dchurn(1.25, 5) * 10) + (int32_t) (loop(v, 10) * 10);
 return (int) ((uint32_t) s % 251);
}
