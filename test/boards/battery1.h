// the thumb1 boards' battery: what mooncc lowers on a v6-M core, every divide, float and
// double a libcall, told over serial_putc. BATTERY1_LM adds the lm math floor's seven, for a
// board with room for lm.o. run answers the tally, or 100 + n at the first miss
#pragma once
#include <stdint.h>
#include "../../src/inle/bput.h"

void serial_putc(int c);

#ifdef BATTERY1_LM
#define BATTERY1_N 32
#else
#define BATTERY1_N 25
#endif

static void puts_(const char *s) {
  for (; *s; s++) { if (*s == '\n') serial_putc('\r'); serial_putc(*s); } }

static void putu(uint32_t v) { bput_n(serial_putc, v, 10); }

// volatile inputs, so nothing folds at compile time into its answer
static volatile double da = 2.5, db = -1.25, one = 1.0, two = 2.0, big = 1e9;
static volatile float ff = 1.5f;
static volatile long long p64 = 0x123456789ABLL;
static volatile unsigned long long u64 = 0xFEDCBA9876543210ULL;
static volatile int i7 = 7, i2 = 2, i1000 = 1000, im7 = -7;
static volatile unsigned u9 = 900000007u;

#ifdef BATTERY1_LM
double lm_sin(double), lm_cos(double), lm_sqrt(double), lm_exp(double),
       lm_log(double), lm_atan2(double, double);
#endif

struct zn { double re, im; };
static struct zn zmake(double re, double im) {
  struct zn z; z.re = re; z.im = im; return z; }         // memory-returned
static double znorm(struct zn z) { return z.re*z.re + z.im*z.im; }

static int run(void) {
  int ok = 0;
#define CK(x) do { ok++; \
    puts_("; check "); putu((uint32_t)ok); \
    if (x) puts_(" ok\n"); else { puts_(" FAIL\n"); return 100 + ok; } } while (0)
  // v6-M has NO divide instruction: every one of these is an __aeabi_ call
  CK(i1000 / i7 == 142);
  CK(i1000 % i7 == 6);
  CK(im7 / i2 == -3);                  // C truncates toward zero, not down
  CK(im7 % i2 == -1);
  CK(u9 / 7u == 128571429u);
  CK(u9 % 7u == 4u);
  // and no FPU: doubles are the full soft-float set
  CK(da + db == 1.25);
  CK(da - db == 3.75);
  CK(da * db == -3.125);
  CK(da / db == -2.0);
  CK(da > db);
  CK(db < 0.0);
  CK((long long)(da * 4.0) == 10);
  CK((double)i7 / (double)i2 == 3.5);
  // bare floats soften too (no FPv4 to fall back on, unlike the nucleo)
  CK(ff * ff == 2.25f);
  CK((double)ff == 1.5);
  CK(ff + ff == 3.0f);
  // 64-bit pairs on an 8-register machine
  CK(u64 % 1000ULL == 720ULL);
  CK(-p64 == -1250999896491LL);
  CK(p64 * 3 == 3752999689473LL);
  CK(u64 >> 16 == 0xFEDCBA987654ULL);
  CK((long long)u64 == -81985529216486896LL);
  CK(u64 / 1000ULL == 18364758544493064ULL);
#ifdef BATTERY1_LM
  // the lm math floor, bit-exact (the values harnesslm.c pins against gcc)
  CK(lm_sin(one) == 0.8414709848078965);
  CK(lm_cos(two) == -0.41614683654714241);
  CK(lm_sqrt(two) == 1.4142135623730951);
  CK(lm_exp(one) == 2.7182818284590455);
  CK(lm_log(two) == 0.69314718055994529);
  CK(lm_atan2(one, two) == 0.46364760900080609);
  CK(lm_sin(big) == 0.54584344944869956);      // the big-argument reduction
#endif
  // a composite through memory, the shape AAPCS returns via the sret pointer
  { struct zn z = zmake(da, db);
    CK(z.re == da && z.im == db);
    CK(znorm(z) == da*da + db*db); }
  return ok; }
