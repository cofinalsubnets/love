// a single's copy and the op after it laid as one three-operand op: sub and div keep their order
// either way round, a square, and a loop's running sums
#include <stdint.h>

__attribute__((noinline)) static float mix(float a, float b, float c) {
 float x = a - b, y = b - a, z = a / c, w = c / a;
 float u = x, v = y;
 u = u * u;
 v = v - v * 0.5f;
 return x * 3 + y * 5 + z * 7 + w * 11 + u + v * 13 + (a - c) / (b + c);
}
__attribute__((noinline)) static float fold(const float *p, int n) {
 float s = 0, t = 1;
 for (int i = 0; i < n; i++) { float q = p[i]; s = q - s; t = t / (q + 2); s = s * t - q; }
 return s + t;
}

int main(void) {
 float p[8];
 for (int i = 0; i < 8; i++) p[i] = (float) i * 0.75f + 0.5f;
 int32_t r = (int32_t) (mix(2.5f, 1.25f, -0.5f) * 1000) + (int32_t) (fold(p, 8) * 100000);
 return (int) ((uint32_t) r % 251);
}
