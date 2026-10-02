// Nucleo-F446RE firmware -- every C file compiled by mooncc -t thumb2sp (the
// F446's Cortex-M4 has a single-precision FPU, the playdate's exact shape:
// f64 transfers on the d-regs, f64 arithmetic through __aeabi_* libgcc).
//
// NOT love: the 128 KB SRAM is the same wall the rp2040 hit (a prel-only
// bake wants a >512 KB arena) -- this is the TOOLCHAIN on silicon. Boot,
// first-light the LED, banner the self-reported core clock over the ST-LINK
// VCP, then run an on-board self-check battery: softened doubles, floats,
// 64-bit pairs, the lm math floor (bit-exact expectations, the same values
// test_thumb2sp pins against gcc on qemu-M4), composites and varargs. Every
// check prints; the tally is the story. A -D QSMOKE build leaves through
// qemu semihosting with the tally as the exit code (100+n names the first
// miss, 98 a fault) -- booted BY HAND (`make -C src/inle/nucleo446 smoke`, then
// qemu's STM32F405 cousin), since test_thumb2sp gates this lane's arithmetic
// against gcc and `make test_nucleo446` only builds and verifies the image.
// The device build blinks instead: slow = all green, fast = a miss.
#include <stdint.h>
#include "nucleo446.h"
#include "../bput.h"
#include <stdarg.h>

static void puts_(const char *s) {
  for (; *s; s++) { if (*s == '\n') serial_putc('\r'); serial_putc(*s); } }

static void putu(uint32_t v) { bput_n(serial_putc, v, 10); }

// --- the battery ----------------------------------------------------------
// volatile inputs keep every operand a runtime value; expectations are exact
// (the lm values are the bit-identical ones harnesslm.c pins vs gcc).
static volatile double da = 2.5, db = -1.25, one = 1.0, two = 2.0, big = 1e9;
static volatile float ff = 1.5f;
static volatile long long p64 = 0x123456789ABLL, q64 = 100000LL;
static volatile unsigned long long u64 = 0xFEDCBA9876543210ULL;
static volatile int i7 = 7, i2 = 2;

double lm_sin(double), lm_cos(double), lm_sqrt(double), lm_exp(double),
       lm_log(double), lm_atan2(double, double);

struct zn { double re, im; };
static struct zn zmake(double re, double im) {
  struct zn z; z.re = re; z.im = im; return z; }         // memory-returned
static double znorm(struct zn z) { return z.re*z.re + z.im*z.im; }
struct ii { short a, b; };
static struct ii imake(int a, int b) {
  struct ii r; r.a = (short)a; r.b = (short)b; return r; }
static int isum(struct ii v) { return v.a + v.b; }
static int vsum(int n, ...) {
  va_list ap; int s = 0;
  va_start(ap, n);
  for (int i = 0; i < n; i++) s += va_arg(ap, int);
  va_end(ap); return s; }
static int run(void) {
  int ok = 0;
#define CK(x) do { ok++; \
    puts_("; check "); putu((uint32_t)ok); \
    if (x) puts_(" ok\n"); else { puts_(" FAIL\n"); return 100 + ok; } } while (0)
  // softened doubles: arith, compares, conversions (__aeabi_d*)
  CK(da + db == 1.25);
  CK(da - db == 3.75);
  CK(da * db == -3.125);
  CK(da / db == -2.0);
  CK(da > db);
  CK(db < 0.0);
  CK((long long)(da * 4.0) == 10);
  CK((double)i7 / (double)i2 == 3.5);
  // bare floats (the FPU's own lane under thumb2sp)
  CK(ff * ff == 2.25f);
  CK((double)ff == 1.5);
  CK(ff + ff == 3.0f);
  // 64-bit pairs: mul, unsigned div-mod, shifts, sign (SIGNED 64 divide is
  // thumb2's one standing refusal -- an open compiler item, not a port one)
  CK(u64 % 1000ULL == 720ULL);
  CK(-p64 == -1250999896491LL);
  CK(p64 * 3 == 3752999689473LL);
  CK(u64 >> 16 == 0xFEDCBA987654ULL);
  CK((long long)u64 == -81985529216486896LL);
  CK(u64 / 1000ULL == 18364758544493064ULL);
  // the lm math floor, bit-exact (harnesslm.c's values)
  CK(lm_sin(one) == 0.8414709848078965);
  CK(lm_cos(two) == -0.41614683654714241);
  CK(lm_sqrt(two) == 1.4142135623730951);
  CK(lm_exp(one) == 2.7182818284590455);
  CK(lm_log(two) == 0.69314718055994529);
  CK(lm_atan2(one, two) == 0.46364760900080609);
  CK(lm_sin(big) == 0.54584344944869956);      // the big-argument reduction
  // composites + varargs (the AAPCS-VFP shapes test_thumb2sp gates vs gcc)
  { struct zn z = zmake(da, db);
    CK(z.re == da && z.im == db);
    CK(znorm(z) == da*da + db*db); }
  CK(isum(imake(-7, 1000)) == 993);
  CK(vsum(3, 10, 20, 12) == 42);
  return ok; }   // 28 (mooncc varargs are anonymous WORDS only -- love.c's shape)

int main(void) {
  // first light before anything else: a board that dies later still shows
  // the vector table + crt0 + clocks worked.
  led_init(); led_put(1);
  timer_init();
  puts_("\n; mooncc/nucleo446\n; core ");
  putu(clock_mhz());
  puts_(" MHz\n");
  int r = run();
  puts_(r <= 100 ? "; all " : "; FAILED at ");
  putu((uint32_t)(r <= 100 ? r : r - 100));
  puts_(r <= 100 ? "/28 green\n" : "\n");
#ifdef QSMOKE
  sh_exit((uint32_t)r);
#endif
  // LED = the status channel when no terminal is watching: slow blink green,
  // fast blink a miss. The button flips it solid while held (a live input).
  uint32_t half = r <= 100 ? 500u : 120u;
  for (;;) {
    led_put(1); { uint32_t t = clock_ms(); while (clock_ms() - t < half && !btn_get()) {} }
    led_put(0); { uint32_t t = clock_ms(); while (clock_ms() - t < half && !btn_get()) {} } } }
