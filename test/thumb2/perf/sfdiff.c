/* differential: a candidate rt.c (moon_*) against the tree's (old_*), bit for bit; libgcc only noted -- it mis-rounds some far subtracts. any nan meets any nan */
typedef unsigned long long u64;
u64 moon_dmul(u64, u64), moon_dadd(u64, u64), moon_dsub(u64, u64), moon_ddiv(u64, u64);
u64 old_dmul(u64, u64), old_dadd(u64, u64), old_dsub(u64, u64), old_ddiv(u64, u64);
/* the compares and conversions, each side's: one word out of each, so all share one shape */
#define CV(p) int p##_dcmpeq(u64, u64), p##_dcmplt(u64, u64), p##_dcmple(u64, u64), p##_dcmpun(u64, u64); \
  u64 p##_i2d(int), p##_ui2d(unsigned), p##_l2d(long long), p##_f2d(unsigned); \
  int p##_d2iz(u64); unsigned p##_d2uiz(u64), p##_d2f(u64); long long p##_d2lz(u64);
CV(moon) CV(old)
#define CVS(p, a, b) { (u64) p##_dcmpeq(a, b), (u64) p##_dcmplt(a, b), (u64) p##_dcmple(a, b), (u64) p##_dcmpun(a, b), \
  p##_i2d((int) b), p##_ui2d((unsigned) b), p##_l2d((long long) b), p##_f2d((unsigned) b), \
  (u64) (unsigned) p##_d2iz(a), (u64) p##_d2uiz(a), (u64) p##_d2f(a), (u64) p##_d2lz(a) }
static const char *const cvn[12] = { "dcmpeq", "dcmplt", "dcmple", "dcmpun", "i2d", "ui2d", "l2d", "f2d", "d2iz", "d2uiz", "d2f", "d2lz" };
static u64 rs = 88172645463325252ull;
static u64 rnd(void) { rs ^= rs << 13; rs ^= rs >> 7; rs ^= rs << 17; return rs; }
static int isnan_(u64 x) { return (x & 0x7ff0000000000000ull) == 0x7ff0000000000000ull && (x & 0x000fffffffffffffull); }
static u64 bits(double d) { union { double d; u64 u; } v; v.d = d; return v.u; }
static double dbl(u64 u) { union { double d; u64 u; } v; v.u = u; return v.d; }
static void sh(int op, const void *a) { register int r0 __asm__("r0") = op; register const void *r1 __asm__("r1") = a;
  __asm__ volatile ("bkpt 0xab" : "+r"(r0) : "r"(r1) : "memory"); }
static void puts_(const char *s) { sh(4, s); }
static void hex(u64 x) { char b[19]; b[0] = ' '; for (int i = 0; i < 16; i++) b[1 + i] = "0123456789abcdef"[(x >> (60 - 4 * i)) & 15]; b[17] = 0; puts_(b); }
static const u64 sp[] = { 0, 0x8000000000000000ull, 0x3ff0000000000000ull, 0xbff0000000000000ull, 0x7ff0000000000000ull, 0xfff0000000000000ull,
  0x7ff8000000000000ull, 1, 0x000fffffffffffffull, 0x0010000000000000ull, 0x7fefffffffffffffull, 0x3fe0000000000000ull,
  0x4340000000000000ull, 0x3ca0000000000000ull, 0x0000000000000003ull, 0x001fffffffffffffull, 0x7fe0000000000000ull, 0x0020000000000000ull };
static u64 pick(int k) {
  u64 r = rnd();
  switch (k & 7) {
  case 0: return r;                                        /* any word: nan, inf, denormal now and then */
  case 1: return sp[r % (sizeof sp / sizeof sp[0])];
  case 2: return (r & 0x800fffffffffffffull) | ((u64) (1023 + (int) (r >> 52 & 63) - 32) << 52);   /* near one */
  case 3: return (r & 0x800fffffffffffffull) | ((u64) ((r >> 52) & 0x3f) << 52);                      /* tiny */
  case 4: return (r & 0x800fffffffffffffull) | ((u64) (0x7c0 + ((r >> 52) & 0x3e)) << 52);            /* huge */
  default: return (r & 0x800fffffffffffffull) | ((u64) (1000 + (int) (r >> 52 & 63)) << 52); } }
static int same(u64 a, u64 b) { return a == b || (isnan_(a) && isnan_(b)); }
int run(void) {
  int bad = 0, gcc = 0;
  for (int i = 0; i < 40000 && bad < 6; i++) {
    u64 a = pick(i), b = (i & 8) ? (a ^ (rnd() & 0x80000000000003ffull)) : pick(i >> 3);    /* half the pairs near-equal */
    u64 w[4] = { bits(dbl(a) * dbl(b)), bits(dbl(a) + dbl(b)), bits(dbl(a) - dbl(b)), bits(dbl(a) / dbl(b)) };
    u64 m[4] = { moon_dmul(a, b), moon_dadd(a, b), moon_dsub(a, b), moon_ddiv(a, b) };
    u64 r[4] = { old_dmul(a, b), old_dadd(a, b), old_dsub(a, b), old_ddiv(a, b) };
    { u64 cm[12] = CVS(moon, a, b), co[12] = CVS(old, a, b);
      for (int o = 0; o < 12; o++)
        if (cm[o] != co[o] && !(o == 10 && (co[o] & 0x7f800000) == 0x7f800000 && (co[o] & 0x7fffff) && (cm[o] & 0x7f800000) == 0x7f800000 && (cm[o] & 0x7fffff))) {
          bad++; puts_("\nmiss "); puts_(cvn[o]); hex(a); hex(b); puts_(" old"); hex(co[o]); puts_(" new"); hex(cm[o]); } }
    for (int o = 0; o < 4; o++) {
      if (!same(r[o], m[o])) { bad++; puts_("\nmiss "); puts_(o == 0 ? "mul" : o == 1 ? "add" : o == 2 ? "sub" : "div"); hex(a); hex(b); puts_(" old"); hex(r[o]); puts_(" new"); hex(m[o]); }
      if (!same(w[o], m[o]) && gcc < 4) { gcc++; puts_("\nlibgcc differs "); puts_(o == 0 ? "mul" : o == 1 ? "add" : o == 2 ? "sub" : "div"); hex(a); hex(b); puts_(" libgcc"); hex(w[o]); puts_(" new"); hex(m[o]); } } }
  puts_(bad ? "\nFAIL\n" : "\nnew agrees with old\n");
  return bad ? 1 : 0; }
