/* x64's "x": an asm operand in an xmm register -- a double as its value, an integer as its
 * bits, in, out and in-out -- and the indexed addresses `d(%b,%i,s)` an asm line may spell.
 * elsewhere the same answers come from plain C, so every lane agrees on the exit. */
typedef unsigned long long u64;

#if defined(__x86_64__)
static double quot(double a, double b) { double r; __asm__("movsd %1, %0\n\tdivsd %2, %0" : "=&x"(r) : "x"(a), "x"(b)); return r; }
static double add3(double a, double b, double c) {
  __asm__("addsd %1, %0\n\taddsd %2, %0" : "+x"(a) : "x"(b), "x"(c)); return a; }
static float halve(float f) { float h = 0.5f; __asm__("mulss %1, %0" : "+x"(f) : "x"(h)); return f; }
static u64 viax(u64 x) { u64 r; __asm__("movq %1, %%xmm7\n\tmovq %%xmm7, %0" : "=x"(r) : "r"(x) : "xmm7"); return r; }
/* the last 16 bytes through one indexed load and store, and an indexed lea */
static void tail16(unsigned char *d, unsigned char const *s, long n) {
  __asm__ volatile("movdqu -16(%1,%2), %%xmm4\n\tmovdqu %%xmm4, -16(%0,%2)" : : "r"(d), "r"(s), "r"(n) : "xmm4", "memory"); }
static long at(long const *a, long i) { long r; __asm__("movq 8(%1,%2,8), %0" : "=r"(r) : "r"(a), "r"(i)); return r; }
static long *past(long *a, long i) { long *r; __asm__("leaq -8(%1,%2,8), %0" : "=r"(r) : "r"(a), "r"(i)); return r; }
static void put(long *a, long i, long v) { __asm__ volatile("movq %2, (%0,%1,4)" : : "r"(a), "r"(i), "r"(v) : "memory"); }
#else
static double quot(double a, double b) { return a / b; }
static double add3(double a, double b, double c) { return a + b + c; }
static float halve(float f) { return f * 0.5f; }
static u64 viax(u64 x) { return x; }
static void tail16(unsigned char *d, unsigned char const *s, long n) { for (long i = n - 16; i < n; i++) d[i] = s[i]; }
static long at(long const *a, long i) { return a[i + 1]; }
static long *past(long *a, long i) { return a + i - 1; }
static void put(long *a, long i, long v) { char *p = (char *) a + 4 * i, *q = (char *) &v; for (unsigned k = 0; k < sizeof v; k++) p[k] = q[k]; }
#endif

static u64 dbits(double x) { union { double d; u64 u; } v; v.d = x; return v.u; }
static unsigned fbits(float x) { union { float f; unsigned u; } v; v.f = x; return v.u; }

int main(void) {
  unsigned char s[40], d[40];
  long a[8] = {10, 11, 12, 13, 14, 15, 16, 17};
  for (int i = 0; i < 40; i++) s[i] = (unsigned char) (i * 7 + 1), d[i] = 0;
  tail16(d, s, 37);
  put(a, 6, 99);
  unsigned h = 0;
  for (int i = 0; i < 40; i++) h = h * 31 + d[i];
  u64 q = dbits(quot(2.0, 3.0)), t = dbits(add3(0.1, 0.2, 0.3)), v = viax(0x123456789abcdef0ull);
  h = h * 31 + (unsigned) q; h = h * 31 + (unsigned) (q >> 32);
  h = h * 31 + (unsigned) t; h = h * 31 + (unsigned) (t >> 32);
  h = h * 31 + (unsigned) v; h = h * 31 + (unsigned) (v >> 32);
  h = h * 31 + fbits(halve(3.0f));
  h = h * 31 + (unsigned) at(a, 2); h = h * 31 + (unsigned) *past(a, 5); h = h * 31 + (unsigned) a[3];
  return (int) ((h ^ h >> 7 ^ h >> 14 ^ h >> 21) & 127); }
