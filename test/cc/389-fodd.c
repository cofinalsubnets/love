// thumb2sp's odd singles: more live floats than d registers, float args in odd s slots, a double
// among them that wants a whole d, and calls the odd halves must survive
#include <stdint.h>

__attribute__((noinline)) static float pick(float a, float b, float c, float d, float e, float f, float g, float h, float i) {
 return a - b * 2 + c * 3 - d * 4 + e * 5 - f * 6 + g * 7 - h * 8 + i * 9;
}
__attribute__((noinline)) static double half(double x, float y) { return x * 0.5 + y; }
__attribute__((noinline)) static float many(const float *p, int n) {
 float a = p[0], b = p[1], c = p[2], d = p[3], e = p[4], f = p[5], g = p[6], h = p[7];
 float i = p[8], j = p[9], k = p[10], l = p[11], m = p[12], o = p[13], q = p[14], r = p[15];
 float s = p[16], t = p[17], u = p[18];
 double w = 1.5;
 for (int z = 0; z < n; z++) {
  a = a + b * c; b = b - c * d; c = c + d * e; d = d - e * f; e = e + f * g; f = f - g * h;
  g = g + h * i; h = h - i * j; i = i + j * k; j = j - k * l; k = k + l * m; l = l - m * o;
  m = m + o * q; o = o - q * r; q = q + r * s; r = r - s * t; s = s + t * u; t = t - u * a;
  u = u + a * 0.25f;
  w = half(w, a - u);
  a = pick(a, b, c, d, e, f, g, h, i) * 0.001f;
 }
 return a + b + c + d + e + f + g + h + i + j + k + l + m + o + q + r + s + t + u + (float) w;
}

int main(void) {
 float p[19];
 for (int i = 0; i < 19; i++) p[i] = (float) ((i * 7) % 11) * 0.125f - 0.5f;
 int32_t r = (int32_t) (many(p, 6) * 1000);
 return (int) ((uint32_t) r % 251);
}
