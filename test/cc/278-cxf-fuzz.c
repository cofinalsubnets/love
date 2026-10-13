/* float _Complex arithmetic in float: + - * on two float complexes round as C's float does
 * (FLT_EVAL_METHOD 0) -- re = ac - bd is three single roundings, not one double one. a random
 * walk, every result's bits hashed into the exit code; a mixed float/double complex rides the
 * double lane. / stays out: gcc's __divsc3 scales, and no naive formula is its twin */
static unsigned st = 99u;
static unsigned rnd(void) { st ^= st << 13; st ^= st >> 17; st ^= st << 5; return st; }
static float rf(void) { union { unsigned u; float f; } x; unsigned r = rnd();
  x.u = (r & 0x807fffffu) | ((120u + (r >> 8) % 16u) << 23); return x.f; }
static unsigned h = 2166136261u;
typedef union { float _Complex z; float p[2]; } FC;
typedef union { double _Complex z; double p[2]; } DC;
static void mf(float f) { union { float f; unsigned u; } x; x.f = f; h = (h ^ x.u) * 16777619u; }
static void mz(float _Complex z) { FC u; u.z = z; mf(u.p[0]); mf(u.p[1]); }
static void md(double _Complex z) { DC u; u.z = z; for (int k = 0; k < 2; k++) { union { double d; unsigned long long w; } x; x.d = u.p[k]; h = (h ^ (unsigned) (x.w >> 20)) * 16777619u; } }
static float _Complex fz(void) { FC u; u.p[0] = rf(); u.p[1] = rf(); return u.z; }
static double _Complex dz(void) { DC u; u.p[0] = rf(); u.p[1] = rf(); return u.z; }
int main(void) {
  for (int i = 0; i < 20000; i++) {
    float _Complex a = fz(), b = fz();
    double _Complex c = dz();
    mz(a + b); mz(a - b); mz(a * b);
    md(a * c); md(c - a);                        /* mixed: double complex */
    float _Complex t = a; t *= b; t += a; t -= b; mz(t);
  }
  return (h ^ h >> 8 ^ h >> 16 ^ h >> 24) & 127;   /* under 128: no exit reads as a signal */
}
