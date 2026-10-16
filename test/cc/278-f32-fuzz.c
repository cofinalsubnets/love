/* float arithmetic under a seeded random differential: float expressions evaluate in float
 * (FLT_EVAL_METHOD 0), so a * b + c rounds twice to binary32, not once from double. result bits
 * hash into the exit code; operands stay clear of overflow and nan. */

static unsigned st = 0x9e3779b9u;
static unsigned rnd(void) { st ^= st << 13; st ^= st >> 17; st ^= st << 5; return st; }
static float rf(void) {
  union { unsigned u; float f; } x;
  unsigned r = rnd();
  x.u = (r & 0x807fffffu) | ((112u + (r >> 8) % 32u) << 23);   /* 2^-15 .. 2^16, either sign */
  return x.f;
}
static unsigned h = 2166136261u;
static void mix(float f) {
  union { float f; unsigned u; } x; x.f = f;
  h = (h ^ x.u) * 16777619u;
}
static void mixi(long long v) { h = (h ^ (unsigned) v ^ (unsigned) (v >> 32)) * 16777619u; }

static float fma3(float a, float b, float c) { return a * b + c; }
static float poly(float x, float a, float b, float c) { return (a * x + b) * x + c; }
static float ratio(float a, float b, float c, float d) { return (a + b) / (c - d); }
static double widen(float a, float b) { return a * b; }        /* float product, then widened */
static float back(double d, float f) { return d * f; }         /* double product, narrowed once */
static float (*volatile fp3)(float, float, float) = fma3;       /* a float answer through a pointer */
/* f literals near a float halfway point: decimal -> binary32 must round once (through double it misses) */
static const float lits[] = { 2207413077354431152343749e-24f, 164422649459672983053271039e-1f,
                              5627940207878139239464960001e-1f, 8290357515215873718261718749e-29f };

int main(void) {
  float acc = 0.0f;
  float arr[16];
  for (int i = 0; i < 16; i++) arr[i] = rf();
  for (int round = 0; round < 20000; round++) {
    float a = rf(), b = rf(), c = rf(), d = rf();
    int k = (int) (rnd() % 2001) - 1000;
    mix(a * b + c);
    mix(fma3(a, b, c));
    mix(poly(a, b, c, d));
    mix(ratio(a, b, c, d));
    mix(a * b * c);
    mix(a + b + c + d);
    mix(a - b * c / d);
    mix(a * k + b);                       /* int converts to float, not double */
    mix(k / a);
    mix((float) widen(a, b));
    mix(back(a, b));
    mix(a * 0.1f + b);                    /* a float constant */
    mix(a * 0.1 + b);                     /* a double constant: double arithmetic, narrowed once */
    mix(-a * b + c);
    mix(a < b ? a * c : b * d);
    { float t = a; t += b * c; t *= d; t -= a; t /= b; mix(t); }
    { float t = a; t++; t = t * b; mix(t); }
    acc = acc * 0.5f + a * b;
    arr[round & 15] = arr[(round + 3) & 15] * a + arr[(round + 7) & 15];
    mixi(a < b); mixi(a * b <= c); mixi(a + b == c + d); mixi(a * c != b * d);
    mixi((int) (a * 1000.0f)); mixi((long long) (b * c));
    mixi((unsigned) (a < 0.0f ? -a : a));
    mix(fp3(a, b, c));
    { long long v = (long long) ((unsigned long long) rnd() << 32 | rnd()) >> (rnd() & 31);
      mix((float) v); mix((float) (unsigned long long) v); }   /* 64-bit to float, one rounding */
    { int big = (int) (rnd() | 0x1000000u) >> (rnd() & 7);       /* past 2^24 an int rounds to compare */
      float fb = (float) big;
      mixi(big == fb); mixi(fb < big); mixi(big <= fb * 1.0000001f); if (fb != big) mixi(3); }
  }
  mix(acc); mixi(1);
  for (int i = 0; i < 4; i++) mix(lits[i]);
  mix(11534749899641763921919e-1f);
  for (int i = 0; i < 16; i++) mix(arr[i]);
  return (h ^ h >> 8 ^ h >> 16 ^ h >> 24) & 127;   /* under 128: no exit reads as a signal */
}
