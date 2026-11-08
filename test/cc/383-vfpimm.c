// float literals that a vfp lays as an 8-bit immediate and ones it cannot, negated literals, and
// compares against zero, -0.0 and a nan on either side, and a float's truth as a value and a branch
#include <stdint.h>
#include <string.h>

static uint32_t bits(float f) { uint32_t u; memcpy(&u, &f, 4); return u; }
__attribute__((noinline)) static float lits(float x) {
 return x * 0.5f + 1.0f - 2.0f * x + 31.0f * x - 0.125f + x * 6.2831853f - 0.1f + 1.5f * x * 0.1875f - 17.0f; }
__attribute__((noinline)) static float negs(float x) { return x * -(float) 0.25 + -(float) 0.1666 - x * -(float) 31 + -(float) 0.0; }
__attribute__((noinline)) static float nz(void) { return -(float) 0.0; }
__attribute__((noinline)) static int cmps(float x) {
 return (x != 0) | (x == 0) << 1 | (x > 0) << 2 | (x >= 0) << 3 | (x < 0) << 4 | (x <= 0) << 5 | (0 < x) << 6 | (!x) << 7; }
__attribute__((noinline)) static float relu(float x) { return x > 0 ? x : 0; }

int main(void) {
 float zero = 0, nan = zero / zero;
 float xs[] = { 3.25f, -1.5f, 0.0f, -zero, nan, 1e-30f, -7.0f };
 uint32_t s = bits(nz()) >> 31;
 for (unsigned i = 0; i < sizeof xs / sizeof xs[0]; i++) {
  float x = xs[i];
  s = s * 31 + (uint32_t) cmps(x);
  if (x) s += 3;
  if (x == x) s = s * 31 + bits(lits(x)) + bits(negs(x)) * 3 + bits(relu(x)) * 5;
 }
 return (int) (s % 251);
}
