// micro:bit v2 firmware, all mooncc -t thumb2sp (single-precision FPU, f64 through __aeabi_*).
// not love (128 KB SRAM): the toolchain on silicon, the boards' battery over the daplink's
// vcp; the matrix after it is lore's savers, slop's drift all green, matrix rain a miss, and a
// ble beacon names the result and the die's temperature. held, button A shows the moon's
// phases and B the game of life; a finger on the logo, or both buttons, turns the matrix to
// static and the speaker to white noise
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

// the moon: a sphere lit by a sun circling it once in 4 s, viewed from +z. a cell's normal is
// (x, y, z) in 64ths, the sun (sin, 0, -cos) of its phase, the light their dot; the dark side
// keeps earthshine
static void moon(uint8_t *lv, uint32_t t, int8_t const *sn, int8_t const *nx, int8_t const *nz) {
  uint32_t ph = t * 64u / 4000u;
  int s = sn[ph & 63], c = sn[(ph + 16u) & 63];
  for (int k = 0; k < LED_N * LED_N; k++) {
    if (nz[k] < 0) { lv[k] = 0; continue; }
    int d = (nx[k] * s - nz[k] * c) / 64;
    lv[k] = (uint8_t) (d <= 0 ? 1 : 1 + d * (LED_MAX - 1) / 64); } }

// life on the 5x5 torus, a cell a bit of a 25-bit board: born on three, kept on two or three
static uint32_t life_step(uint32_t b) {
  uint32_t n = 0;
  for (int y = 0; y < LED_N; y++)
    for (int x = 0; x < LED_N; x++) {
      int c = 0;
      for (int dy = LED_N - 1; dy <= LED_N + 1; dy++)
        for (int dx = LED_N - 1; dx <= LED_N + 1; dx++)
          if (dy != LED_N || dx != LED_N) c += (int) (b >> ((y + dy) % LED_N * LED_N + (x + dx) % LED_N) & 1u);
      if (c == 3 || (c == 2 && (b >> (y * LED_N + x) & 1u))) n |= 1u << (y * LED_N + x); }
  return n; }

// a board of the game: a generation every 250 ms, a cell just died shown dim; it runs on
// through still lifes and blinkers, and only a board gone empty reseeds, a generation after,
// off the noise's xorshift
static void life(uint8_t *lv, uint32_t t, uint32_t *g, uint32_t *z) {
  if (t - g[2] >= 250u || !(g[0] | g[1])) {
    uint32_t n = g[0] ? life_step(g[0]) : 0;
    g[1] = g[0], g[2] = t;
    if (!g[0]) {
      uint32_t x = *z;
      x ^= x << 13, x ^= x >> 17, x ^= x << 5, *z = x;
      n = x & ((1u << LED_N * LED_N) - 1u), g[1] = 0; }
    g[0] = n; }
  for (int k = 0; k < LED_N * LED_N; k++)
    lv[k] = (uint8_t) ((g[0] >> k & 1u) ? LED_MAX : (g[1] >> k & 1u) ? 2 : 0); }

// static: every cell a fresh level each pass, off the noise's own xorshift
static void snow(uint8_t *lv, uint32_t *z) {
  for (int k = 0; k < LED_N * LED_N; k++) {
    uint32_t x = *z;
    x ^= x << 13, x ^= x >> 17, x ^= x << 5, *z = x;
    lv[k] = (uint8_t) (x % (LED_MAX + 1)); } }

// digits of v at p, answering the end
static uint8_t *put_u(uint8_t *p, uint32_t v) {
  uint8_t d[10]; int n = 0;
  do d[n++] = (uint8_t) ('0' + v % 10); while (v /= 10);
  while (n) *p++ = d[--n];
  return p; }
static uint8_t *put_s(uint8_t *p, char const *s) { while (*s) *p++ = (uint8_t) *s++; return p; }

// the beacon's pdu: ADV_NONCONN_IND from a random address, then flags, the name
// ("mb 28/28 23.25C", or "mb FAIL 12 .."), and manufacturer data under the test company
// 0xFFFF: the temperature in quarter degrees (int16), the checks passed, the one failed or 0
static void adv_pdu(uint8_t *pdu, uint8_t const *addr, int r, int32_t q) {
  uint8_t *p = pdu + 2;
  for (int k = 0; k < 6; k++) *p++ = addr[k];
  *p++ = 2, *p++ = 0x01, *p++ = 0x06;
  uint8_t *nl = p; p += 2;
  p = put_s(p, "mb ");
  if (r <= 100) p = put_u(p, (uint32_t) r), *p++ = '/', p = put_u(p, 28);
  else p = put_s(p, "FAIL "), p = put_u(p, (uint32_t) (r - 100));
  *p++ = ' ';
  uint32_t a = (uint32_t) (q < 0 ? -q : q);
  if (q < 0) *p++ = '-';
  p = put_u(p, a / 4), *p++ = '.', *p++ = (uint8_t) ('0' + a % 4 * 25 / 10), *p++ = (uint8_t) ('0' + a % 4 * 5 % 10);
  *p++ = 'C';
  nl[0] = (uint8_t) (p - nl - 1), nl[1] = 0x09;
  *p++ = 7, *p++ = 0xFF, *p++ = 0xFF, *p++ = 0xFF;
  *p++ = (uint8_t) q, *p++ = (uint8_t) ((uint32_t) q >> 8);
  *p++ = (uint8_t) (r <= 100 ? r : 0), *p++ = (uint8_t) (r <= 100 ? 0 : r - 100);
  pdu[0] = 0x42, pdu[1] = (uint8_t) (p - pdu - 2); }

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
  int8_t nx[LED_N * LED_N], nz[LED_N * LED_N];
  for (int k = 0; k < 64; k++) sn[k] = (int8_t) (lm_sin(k * (6.283185307179586 / 64)) * 64);
  for (int k = 0; k < LED_N * LED_N; k++) {
    double cx = (double) (k % LED_N - 2), cy = (double) (k / LED_N - 2);
    rr[k] = (uint8_t) (lm_sqrt(cx * cx + cy * cy) * 10);
    double ux = cx / 2.6, uy = cy / 2.6, w = 1 - ux * ux - uy * uy;
    nx[k] = (int8_t) (ux * 64), nz[k] = (int8_t) (w < 0 ? -1 : lm_sqrt(w) * 64); }
  uint8_t addr[6], pdu[ADV_PDU_MAX];
  ble_init(); ble_addr(addr);
  int32_t q = temp_read();
  adv_pdu(pdu, addr, r, q);
  puts_("; beacon up\n");
  // the untouched pad's charge time, the median of nine; touched past twice it, released under
  // one and a half times it
  uint32_t bs[9];
  for (int k = 0; k < 9; k++) {
    uint32_t v = logo_us(), j = (uint32_t) k;
    for (; j && bs[j - 1] > v; j--) bs[j] = bs[j - 1];
    bs[j] = v; }
  uint32_t base = bs[4] ? bs[4] : 1, z = 0x9E3779B9u ^ clock_us();
  int touched = 0;
  uint32_t gl[3] = { 0, 0, 0 };   // life: the board, the one before, its clock
  puts_("; logo "), putu(base), puts_(" us\n");
  led_put(0);
  // the beacon every tenth pass, ~100 ms; the temperature read again each second
  for (uint32_t n = 0;; n++) {
    uint32_t t = clock_ms(), us = logo_us();
    touched = touched ? us * 2 > base * 3 : us > base * 2;
    int b = buttons(), hiss = touched || b == 3;
    if (hiss) snow(lv, &z);
    else if (b == 1) moon(lv, t, sn, nx, nz);
    else if (b == 2) life(lv, t, gl, &z);
    else if (r <= 100) slop(lv, t, sn, rr);
    else rain(lv, t);
    led_scan(lv, hiss ? &z : 0);
    if (n % 100 == 0) q = temp_read(), adv_pdu(pdu, addr, r, q);
    if (n % 10 == 0) ble_adv(pdu); } }
