/* t/gate/softfp.c -- the compiler runtime against the hardware that has the
 * instruction. a/moon/lib/rt.c is what an FPU-less ARM calls for a double, a 64-bit
 * multiply or a leading-zero count; here it is compiled for a machine with all three, so
 * `a + b` and `__aeabi_dadd(a, b)` sit side by side and must agree BIT FOR BIT -- not to
 * an ulp, not to a printed decimal. Rounding is round-to-nearest-even on both sides, so
 * exact agreement is the only honest bar, and it is the one a board needs: on the Pico
 * those entries ARE double arithmetic.
 *
 * Every runtime entry trades bit patterns rather than floats (rt.c's head says why), so
 * the union conversions here are the test's, not the runtime's.
 *
 * The one place bits are not compared is a NaN result: which quiet NaN a machine hands
 * back is its own business (x86 and arm disagree about the sign alone), so a NaN is held
 * only to being a NaN. Out-of-range float-to-integer is undefined in C and the machines
 * disagree there too, so the conversion rows stay inside the destination's range.
 *
 * The sample is the special values crossed with each other and with randoms drawn to land
 * where the code branches: denormals, the tie cases a round-to-even has to break, near-
 * equal operands whose subtraction cancels to nothing, and exponents far enough apart that
 * one operand is pure sticky. */
#include <stdio.h>
#include <stdint.h>
#include "a/moon/lib/rt.c"

#define NSPEC  38
#define NVAL  360
#define NINT 4000

typedef union { double d; uint64_t u; } db;
typedef union { float f; uint32_t u; } fb;
typedef struct { long n; long bad; } tally;

static uint64_t bits(double d) { db b; b.d = d; return b.u; }
static uint32_t fbits(float f) { fb b; b.f = f; return b.u; }
static int nanu(uint64_t u) { return (u & ~SGNB) > DINF; }
static int nanw(uint32_t u) { return (u & 0x7fffffffu) > 0x7f800000u; }

static uint64_t rnd(uint64_t *s) {
 uint64_t x = *s;
 x ^= x << 13; x ^= x >> 7; x ^= x << 17;
 *s = x;
 return x; }

static void say(tally *t, const char *op, uint64_t a, uint64_t b, uint64_t got, uint64_t want) {
 t->bad++;
 if (t->bad <= 10)
   printf("  %s(%016llx, %016llx) = %016llx want %016llx\n", op,
          (unsigned long long) a, (unsigned long long) b,
          (unsigned long long) got, (unsigned long long) want); }

/* a double result: bits, except that a NaN is only held to being one */
static void chkd(tally *t, const char *op, uint64_t a, uint64_t b, uint64_t got, double want) {
 uint64_t w = bits(want);
 t->n++;
 if (nanu(w) ? !nanu(got) : got != w) say(t, op, a, b, got, w); }

static void chku(tally *t, const char *op, uint64_t a, uint64_t b, uint64_t got, uint64_t want) {
 t->n++;
 if (got != want) say(t, op, a, b, got, want); }

/* the specials, and then values drawn where the code branches */
static void fill(uint64_t *v, uint64_t *s) {
 static const uint64_t spec[NSPEC] = {
  0x0000000000000000ull, 0x8000000000000000ull,           /* +-0 */
  0x3ff0000000000000ull, 0xbff0000000000000ull,           /* +-1 */
  0x4000000000000000ull, 0x3fe0000000000000ull,           /* 2, 1/2 */
  0x7ff0000000000000ull, 0xfff0000000000000ull,           /* +-inf */
  0x7ff8000000000000ull, 0xfff4000000000000ull,           /* quiet and signalling nan */
  0x0000000000000001ull, 0x8000000000000001ull,           /* +-the smallest denormal */
  0x000fffffffffffffull, 0x800fffffffffffffull,           /* the largest denormal */
  0x0010000000000000ull, 0x8010000000000000ull,           /* the smallest normal */
  0x7fefffffffffffffull, 0xffefffffffffffffull,           /* +-DBL_MAX */
  0x0008000000000000ull, 0x0000000000000003ull,           /* mid and tiny denormals */
  0x3fefffffffffffffull, 0x3ff0000000000001ull,           /* the neighbours of 1 */
  0x4330000000000000ull, 0x4330000000000001ull,           /* 2^52, the integer rim */
  0x4340000000000000ull, 0x433fffffffffffffull,           /* 2^53 and below it */
  0x41dfffffffffffffull, 0x41e0000000000000ull,           /* the 2^31 rim */
  0x43dfffffffffffffull, 0x43e0000000000000ull,           /* the 2^63 rim */
  0x0010000000000001ull, 0x000ffffffffffffeull,
  0x3cb0000000000000ull, 0x4b30000000000000ull,           /* 2^-52, 2^180: pure sticky partners */
  0x7fe0000000000000ull, 0x0020000000000000ull };         /* the overflow and underflow rims */
 int i;
 for (i = 0; i < NSPEC; i++) v[i] = spec[i];
 for (i = NSPEC; i < NVAL; i++) {
   uint64_t r = rnd(s);
   switch ((int) (r & 3)) {
   case 0:  v[i] = r; break;                                              /* any pattern at all */
   case 1:  v[i] = (r & 0x800fffffffffffffull)
                 | ((uint64_t) (0x3f5 + (rnd(s) % 24)) << 52); break;     /* near 1: cancellation */
   case 2:  v[i] = r & 0x800fffffffffffffull; break;                      /* denormal */
   default: v[i] = (r & 0x800fffffffffffffull)
                 | ((uint64_t) (1 + rnd(s) % 0x7fe) << 52); break; } } }  /* any finite exponent */

static void arith(tally *t, const uint64_t *v) {
 int i, j;
 for (i = 0; i < NVAL; i++)
   for (j = 0; j < NVAL; j++) {
     db x, y;
     x.u = v[i]; y.u = v[j];
     chkd(t, "dadd", v[i], v[j], __aeabi_dadd(v[i], v[j]), x.d + y.d);
     chkd(t, "dsub", v[i], v[j], __aeabi_dsub(v[i], v[j]), x.d - y.d);
     chkd(t, "dmul", v[i], v[j], __aeabi_dmul(v[i], v[j]), x.d * y.d);
     chkd(t, "ddiv", v[i], v[j], __aeabi_ddiv(v[i], v[j]), x.d / y.d); } }

static void compare(tally *t, const uint64_t *v) {
 int i, j;
 for (i = 0; i < NVAL; i++)
   for (j = 0; j < NVAL; j++) {
     db x, y;
     x.u = v[i]; y.u = v[j];
     chku(t, "dcmpeq", v[i], v[j], (uint64_t) __aeabi_dcmpeq(v[i], v[j]), (uint64_t) (x.d == y.d));
     chku(t, "dcmplt", v[i], v[j], (uint64_t) __aeabi_dcmplt(v[i], v[j]), (uint64_t) (x.d <  y.d));
     chku(t, "dcmple", v[i], v[j], (uint64_t) __aeabi_dcmple(v[i], v[j]), (uint64_t) (x.d <= y.d));
     chku(t, "dcmpge", v[i], v[j], (uint64_t) __aeabi_dcmpge(v[i], v[j]), (uint64_t) (x.d >= y.d));
     chku(t, "dcmpgt", v[i], v[j], (uint64_t) __aeabi_dcmpgt(v[i], v[j]), (uint64_t) (x.d >  y.d));
     chku(t, "dcmpun", v[i], v[j], (uint64_t) __aeabi_dcmpun(v[i], v[j]),
          (uint64_t) (nanu(v[i]) || nanu(v[j]))); } }

/* the conversions. each integer row stays inside the destination's range -- outside it C
 * says nothing and the machines answer differently. */
static void convert(tally *t, const uint64_t *v, uint64_t *s) {
 int i;
 for (i = 0; i < NVAL; i++) {
   db x;
   fb f;
   x.u = v[i];
   chkd(t, "f2d", v[i], 0, __aeabi_f2d(fbits((float) x.d)), (double) (float) x.d);
   { uint32_t g = __aeabi_d2f(v[i]), w = fbits((float) x.d);
     t->n++;
     if (nanw(w) ? !nanw(g) : g != w) say(t, "d2f", v[i], 0, g, w); }
   f.u = (uint32_t) (v[i] >> 32);                 /* an arbitrary float pattern, denormals included */
   chkd(t, "f2d-raw", f.u, 0, __aeabi_f2d(f.u), (double) f.f);
   if (x.d > -2147483649.0 && x.d < 2147483648.0)
     chku(t, "d2iz", v[i], 0, (uint64_t) (uint32_t) __aeabi_d2iz(v[i]), (uint64_t) (uint32_t) (int32_t) x.d);
   if (x.d > -1.0 && x.d < 4294967296.0)
     chku(t, "d2uiz", v[i], 0, (uint64_t) __aeabi_d2uiz(v[i]), (uint64_t) (uint32_t) x.d);
   if (x.d >= -9223372036854775808.0 && x.d < 9223372036854775808.0)
     chku(t, "d2lz", v[i], 0, (uint64_t) __aeabi_d2lz(v[i]), (uint64_t) (int64_t) x.d);
   if (x.d > -1.0 && x.d < 18446744073709551616.0)
     chku(t, "d2ulz", v[i], 0, __aeabi_d2ulz(v[i]), (uint64_t) x.d); }
 for (i = 0; i < NINT; i++) {
   uint64_t r = rnd(s);
   int32_t a = (int32_t) r;
   chkd(t, "i2d",  r, 0, __aeabi_i2d(a), (double) a);
   chkd(t, "ui2d", r, 0, __aeabi_ui2d((uint32_t) r), (double) (uint32_t) r);
   chkd(t, "l2d",  r, 0, __aeabi_l2d((int64_t) r), (double) (int64_t) r);
   chkd(t, "ul2d", r, 0, __aeabi_ul2d(r), (double) r);
   r = rnd(s) >> (rnd(s) % 64);                            /* every width, so every rounding */
   chkd(t, "l2d-w",  r, 0, __aeabi_l2d((int64_t) r), (double) (int64_t) r);
   chkd(t, "ul2d-w", r, 0, __aeabi_ul2d(r), (double) r); } }

/* the integer helpers, against the same operations the host has instructions for */
static void integer(tally *t, uint64_t *s) {
 int i;
 for (i = 0; i < NINT; i++) {
   uint64_t a = rnd(s) >> (rnd(s) % 64), b = rnd(s) >> (rnd(s) % 64);
   int32_t n = (int32_t) (rnd(s) % 64);
   chku(t, "lmul", a, b, (uint64_t) __aeabi_lmul((int64_t) a, (int64_t) b), a * b);
   chku(t, "llsl", a, (uint64_t) n, (uint64_t) __aeabi_llsl((int64_t) a, n), a << n);
   chku(t, "llsr", a, (uint64_t) n, (uint64_t) __aeabi_llsr((int64_t) a, n), a >> n);
   chku(t, "lasr", a, (uint64_t) n, (uint64_t) __aeabi_lasr((int64_t) a, n),
        (uint64_t) (((int64_t) a) >> n));
   if (b) {
     chku(t, "udivdi3", a, b, __udivdi3(a, b), a / b);
     chku(t, "umoddi3", a, b, __umoddi3(a, b), a % b);
     if (!((int64_t) b == -1 && (int64_t) a == (int64_t) 0x8000000000000000ull)) {
       chku(t, "divdi3", a, b, (uint64_t) __divdi3((int64_t) a, (int64_t) b),
            (uint64_t) ((int64_t) a / (int64_t) b));
       chku(t, "moddi3", a, b, (uint64_t) __moddi3((int64_t) a, (int64_t) b),
            (uint64_t) ((int64_t) a % (int64_t) b)); } } }
 /* clz/ctz against the answer by construction, over every single bit and its complement */
 for (i = 0; i < 32; i++) {
   uint32_t w = 1u << i;
   chku(t, "clzsi2", w, 0, (uint64_t) __clzsi2(w), (uint64_t) (31 - i));
   chku(t, "ctzsi2", w, 0, (uint64_t) __ctzsi2(w), (uint64_t) i);
   chku(t, "clzsi2", ~w, 0, (uint64_t) __clzsi2(~w), (uint64_t) (i == 31 ? 1 : 0));
   chku(t, "ctzsi2", ~w, 0, (uint64_t) __ctzsi2(~w), (uint64_t) (i == 0 ? 1 : 0)); }
 chku(t, "clzsi2", 0, 0, (uint64_t) __clzsi2(0), 32);
 chku(t, "ctzsi2", 0, 0, (uint64_t) __ctzsi2(0), 32); }

int main(void) {
 uint64_t v[NVAL], s = 0x9e3779b97f4a7c15ull;
 tally t;
 t.n = 0; t.bad = 0;
 fill(v, &s);
 arith(&t, v);
 compare(&t, v);
 convert(&t, v, &s);
 integer(&t, &s);
 printf("softfp: %ld checks, %ld wrong\n", t.n, t.bad);
 return t.bad != 0; }
