/* <math.h> and <fenv.h> past the lm floor, against glibc's libm. the exact functions --
 * classification, the rounding family, fmod, remquo, fma, the exponent pickers -- answer
 * their bits; the transcendentals answer twelve digits, where an ulp apart reads the same. */
#include <math.h>
#include <fenv.h>
#include <stdlib.h>
#include <string.h>
#include "say.h"

static unsigned long ub(double x) { unsigned long u; memcpy(&u, &x, 8); return u; }
static unsigned uf(float x) { unsigned u; memcpy(&u, &x, 4); return u; }
static double db(unsigned long u) { double d; memcpy(&d, &u, 8); return d; }
static char b[64];
#define X(nm, v) say_u(nm, ub(v))
#define N(nm, v) do { snprintf(b, sizeof b, "%.12g", (double) (v)); say_s(nm, b); } while (0)

static double const vs[] = { -2.5, -1.5, -0.5, -0.4, -0.0, 0.0, 0.4, 0.5, 0.49999999999999994, 1.5,
                             2.5, 3.5, -3.5, 4503599627370495.5, 1e300, -7.0 };
static unsigned long seed = 88172645463325252UL;
static double rnd(void) {                          /* a double of any exponent near 1 */
  seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17;
  return db((seed & 0x800fffffffffffffUL) | ((1023UL - 30 + (seed >> 52) % 60) << 52)); }

int main(void) {
  double inf = 1.0 / 0.0, nn = 0.0 / 0.0, sub = db(1);
  float fsub = 1e-40f;
  /* classification */
  double cl[] = { 0.0, -0.0, 1.0, sub, inf, -inf, nn, 1e-310 };
  for (int i = 0; i < 8; i++) {
    say_n("fpclassify", fpclassify(cl[i]) == FP_NAN ? 0 : fpclassify(cl[i]) == FP_INFINITE ? 1
                        : fpclassify(cl[i]) == FP_ZERO ? 2 : fpclassify(cl[i]) == FP_SUBNORMAL ? 3 : 4);
    say_n("isnan isinf isfinite isnormal signbit",
          !!isnan(cl[i]) * 10000 + !!isinf(cl[i]) * 1000 + !!isfinite(cl[i]) * 100 + !!isnormal(cl[i]) * 10 + !!signbit(cl[i])); }
  say_n("float subnormal", fpclassify(fsub) == FP_SUBNORMAL);
  say_n("isnan(NAN) isinf(INFINITY)", isnan(NAN) * 10 + !!isinf(INFINITY));
  say_n("isgreater nan", isgreater(nn, 1.0) * 100 + isless(1.0, 2.0) * 10 + isunordered(nn, 1.0));
  /* the rounding family */
  for (int i = 0; i < 16; i++) {
    double v = vs[i];
    X("trunc", trunc(v)); X("floor", floor(v)); X("ceil", ceil(v)); X("round", round(v));
    X("rint", rint(v)); X("nearbyint", nearbyint(v));
    if (fabs(v) < 1e18) { say_n("lrint", lrint(v)); say_n("lround", lround(v)); say_n("llround", llround(v)); }
    say_u("roundf", uf(roundf((float) v))); say_u("truncf", uf(truncf((float) v))); say_u("rintf", uf(rintf((float) v))); }
  say_n("lrintf", lrintf(2.5f)); say_n("lroundf", lroundf(-2.5f));
  X("trunc inf", trunc(inf)); X("floor -inf", floor(-inf)); X("round nan", round(nn) == round(nn));
  /* comparisons and neighbours */
  X("fmax", fmax(1.0, 2.0)); X("fmax nan", fmax(nn, 2.0)); X("fmin nan", fmin(3.0, nn)); X("fmin", fmin(-1.0, 1.0));
  X("fdim", fdim(5.0, 3.0)); X("fdim under", fdim(3.0, 5.0));
  say_u("fmaxf", uf(fmaxf(1.5f, -2.0f)));
  X("copysign", copysign(3.0, -0.0)); say_n("copysign nan", copysign(1.0, db(0xfff8000000000000UL)) < 0);
  say_n("-nan flips", (ub(-nn) ^ ub(nn)) == 0x8000000000000000UL); say_n("-nanf flips", (uf(-(float) nn) ^ uf((float) nn)) == 0x80000000u);
  X("nextafter 0", nextafter(0.0, 1.0)); X("nextafter 1 up", nextafter(1.0, 2.0)); X("nextafter 1 down", nextafter(1.0, 0.0));
  X("nextafter -0", nextafter(-0.0, -1.0)); X("nextafter max", nextafter(1.7976931348623157e308, inf));
  X("nextafter -sub", nextafter(-sub, 0.0));
  say_u("nextafterf", uf(nextafterf(1.0f, 2.0f)));
  /* the exponent */
  int e;
  double fr[] = { 1.0, 0.75, -3.0, sub, 1e-310, 1e300, 0.0 };
  for (int i = 0; i < 7; i++) {
    X("frexp", frexp(fr[i], &e)); say_n("frexp e", e);
    say_n("ilogb", ilogb(fr[i])); X("logb", logb(fr[i])); }
  X("ldexp", ldexp(0.75, 1024)); X("ldexp sub", ldexp(1.0, -1074)); X("ldexp under", ldexp(1.0, -1080));
  X("scalbn", scalbn(3.0, -1060)); say_u("ldexpf", uf(ldexpf(1.5f, -140)));
  say_u("frexpf", uf(frexpf(fsub, &e))); say_n("frexpf e", e);
  double ip;
  X("modf frac", modf(-3.25, &ip)); X("modf int", ip); X("modf whole", modf(-4.0, &ip));
  X("modf inf", modf(inf, &ip)); X("modf inf int", ip);
  say_n("ilogb inf", ilogb(inf) == 2147483647);
  /* fmod and remquo, exact */
  double fx[] = { 5.5, -5.5, 1e300, 3.0, 1.7976931348623157e308, 7.0, -7.0, 0.5, 2.0, sub, 1e-300, 6.0 };
  double fy[] = { 2.0, 2.0, 3.0, 1e-300, 0.7, 2.0, 2.0, 1.0, 2.0, sub, 3e-310, 4.0 };
  for (int i = 0; i < 12; i++) {
    int q = 0;
    X("fmod", fmod(fx[i], fy[i]));
    X("remainder", remainder(fx[i], fy[i]));
    X("remquo", remquo(fx[i], fy[i], &q)); say_n("remquo q low", q & 7);
    say_n("remquo q sign", q < 0); }
  X("fmod -0", fmod(-0.0, 1.0)); say_n("fmod by 0 nan", isnan(fmod(1.0, 0.0)));
  say_u("fmodf", uf(fmodf(7.5f, 2.0f))); say_u("remainderf", uf(remainderf(7.5f, 2.0f)));
  /* fma, rounded once */
  X("fma tenth", fma(0.1, 10.0, -1.0));
  X("fma cancel", fma(1.0 + db(0x3cb0000000000000UL), 1.0 - db(0x3ca0000000000000UL), -1.0));
  X("fma sub", fma(1e-300, 1e-10, 0.0)); X("fma sub2", fma(db(0x0010000000000001UL), 0.5, -db(0x0008000000000000UL)));
  X("fma over", fma(1e308, 10.0, -1e308)); X("fma sign", fma(-1.0, 1.0, 1.0));
  unsigned long h = 0, hf = 0;
  for (int i = 0; i < 400; i++) {
    double a = rnd(), c = rnd(), d = rnd();
    if (i & 1) d = -a * c * (1.0 + db(0x3cb0000000000000UL) * (i & 7));
    h = h * 1000003 + ub(fma(a, c, d));
    hf = hf * 1000003 + uf(fmaf((float) a, (float) c, (float) d)); }
  say_u("fma 400", h); say_u("fmaf 400", hf);
  /* the transcendentals, to twelve digits */
  double tx[] = { 0.001, 0.5, 1.0, 2.0, 3.7, 10.0, -0.3, 1e-8 };
  for (int i = 0; i < 8; i++) {
    double v = tx[i];
    N("hypot", hypot(v, 3.0)); N("cbrt", cbrt(v * 27)); N("exp2", exp2(v)); N("expm1", expm1(v));
    N("log1p", log1p(v)); N("asinh", asinh(v)); N("acosh", acosh(1.0 + fabs(v))); N("atanh", atanh(v / 11));
    N("erf", erf(v)); N("erfc", erfc(v)); N("tgamma", tgamma(v + 0.25)); N("lgamma", lgamma(v + 0.25)); }
  N("tgamma neg", tgamma(-2.5)); N("lgamma neg", lgamma(-2.5)); say_n("signgam", signgam);
  N("tgamma 19", tgamma(19.0)); N("erfc 5", erfc(5.0)); N("erf -1", erf(-1.0)); N("cbrt -8", cbrt(-8.0));
  N("hypot big", hypot(1e300, 1e300)); N("expm1 big", expm1(800.0)); N("log1p -1", log1p(-1.0));
  N("cbrtf", cbrtf(10.0f)); N("hypotf", hypotf(3.0f, 4.0f));
  /* fenv: nearest, and the others refused */
  say_n("fegetround nearest", fegetround() == FE_TONEAREST);
  say_n("fesetround nearest", fesetround(FE_TONEAREST));
  fenv_t env; say_n("fegetenv", fegetenv(&env)); say_n("fesetenv", fesetenv(&env));
  say_n("llabs", (long) (llabs(-5000000000LL) / 1000));
  return 0; }
