// micro:bit v2 firmware, all mooncc -t thumb2sp (single-precision FPU, f64 through __aeabi_*).
// not love (128 KB SRAM): the toolchain on silicon, the boards' battery over the daplink's
// vcp; the matrix after it is lore's savers, slop's drift all green, matrix rain a miss
#include <stdint.h>
#include "microbit.h"
#include "../battery.h"

// a cell's own dice, saver.l's h32
static uint32_t h32(uint32_t a) {
  uint32_t h = (a ^ a >> 16) * 73244475u;
  h = (h ^ h >> 16) * 73244475u;
  return h ^ h >> 16; }
static uint32_t dice(uint32_t x, uint32_t k, uint32_t n) { return h32(x * 7919u + k * 104729u) % n; }

// matrix: each column a drop of its own speed, length and gap, a function of the column and the clock
static void rain(uint8_t *lv, uint32_t t) {
  static uint8_t const tail[4] = { LED_MAX, 6, 4, 2 };
  for (int k = 0; k < LED_N * LED_N; k++) lv[k] = 0;
  for (uint32_t x = 0; x < LED_N; x++) {
    uint32_t sp = 4 + dice(x, 0, 8), n = 2 + dice(x, 1, 3), per = LED_N + n + dice(x, 2, 6);
    uint32_t hd = (t * sp / 1000u + dice(x, 3, per)) % per;
    for (uint32_t d = 0; d < n; d++) {
      int y = (int) hd - (int) d;
      if (0 <= y && y < LED_N) lv[y * LED_N + x] = tail[d]; } } }

// slop: slop-drift's four sines, one a radial ripple, in 64ths of a turn off a table
static void slop(uint8_t *lv, uint32_t t, int8_t const *sn, uint8_t const *rr) {
  uint32_t ph = t / 120u;
  for (uint32_t y = 0; y < LED_N; y++)
    for (uint32_t x = 0; x < LED_N; x++) {
      int v = sn[(x * 12u + ph) & 63] + sn[(y * 14u - ph * 7u / 10u) & 63]
            + sn[((x + y) * 8u + ph * 4u / 10u) & 63] + sn[(rr[y * LED_N + x] - ph) & 63u];
      lv[y * LED_N + x] = (uint8_t) ((v + 256) * (LED_MAX + 1) / 513); } }

int main(void) {
  // first light: a board that dies later still shows crt0 and the clocks worked
  led_init(); led_put(1);
  timer_init();
  puts_("\n; mooncc/microbit\n; core 64 MHz, ");
  puts_(clock_xtal() ? "crystal\n" : "rc -- no crystal\n");
  int r = run();
  puts_(r <= 100 ? "; all " : "; FAILED at ");
  putu((uint32_t)(r <= 100 ? r : r - 100));
  puts_(r <= 100 ? "/28 green\n" : "\n");
  int8_t sn[64];
  uint8_t rr[LED_N * LED_N], lv[LED_N * LED_N];
  for (int k = 0; k < 64; k++) sn[k] = (int8_t) (lm_sin(k * (6.283185307179586 / 64)) * 64);
  for (int k = 0; k < LED_N * LED_N; k++) {
    double cx = (double) (k % LED_N - 2), cy = (double) (k / LED_N - 2);
    rr[k] = (uint8_t) (lm_sqrt(cx * cx + cy * cy) * 10); }
  led_put(0);
  for (;;) {
    uint32_t t = clock_ms();
    if (r <= 100) slop(lv, t, sn, rr);
    else rain(lv, t);
    led_scan(lv); } }
