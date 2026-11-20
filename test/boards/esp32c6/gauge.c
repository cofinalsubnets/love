// the feather's neopixel as a thermometer on xbell's magma (gauge.h, laid by mkgauge.l), each
// second, and printed on the usb serial: tau's cpu while its feed is fresh, 30-90 c, else the
// die's own, 10-60 c; a failed battery blinks it red. the feed is a line "T" and tenths of a
// degree on the usb serial (src/tools/gaugefeed.l). the pixel is a ws2812 on gpio9 behind gpio20's power switch, clocked by rmt
// channel 0. registers by the esp32-c6 trm
#include <stdint.h>
#include "gauge.h"

#define R(a) (*(volatile uint32_t *)(uintptr_t)(a))
void serial_putc(int c);
int serial_rx(void);
uint32_t ticks(void);                                      // c6.c's, 16 a microsecond

#define PCR    0x60096000u
#define IOMUX  0x60090000u
#define GPIO   0x60091000u
#define RMT    0x60006000u
#define SARADC 0x6000E000u

enum { pix = 9, pixpow = 20, rmt_out0 = 71 };

static void us(uint32_t n) { uint32_t const t = ticks(); while (ticks() - t < n * 16u) {} }

// the host's lines, a byte at a time: "T" and tenths of a degree, fresh for ten seconds
struct feed { char b[12]; uint32_t n, age; int32_t t; };

static void feed_byte(struct feed *f, int c) {
  if (c != '\n' && c != '\r') {
    if (f->n < sizeof f->b) f->b[f->n] = (char) c;
    f->n++;
    return; }
  uint32_t const n = f->n, neg = n > 1 && f->b[1] == '-';
  int32_t v = 0;
  uint32_t i = 1 + neg, ok = n <= sizeof f->b && n > i && f->b[0] == 'T';
  for (; ok && i < n; i++) ok = f->b[i] >= '0' && f->b[i] <= '9', v = v * 10 + (f->b[i] - '0');
  if (ok) f->t = neg ? -v : v, f->age = 0;
  f->n = 0; }

// n milliseconds, the host's bytes read as they come (one left unread wedges its port)
static void ms(struct feed *f, uint32_t n) {
  uint32_t const t = ticks();
  while (ticks() - t < n * 16000u) {
    int const c = serial_rx();
    if (c >= 0 && f) feed_byte(f, c); } }

static void puts_(char const *s) { for (; *s; s++) serial_putc(*s); }
static void putd(int32_t v) {
  char b[12];
  int n = 0;
  if (v < 0) serial_putc('-'), v = -v;
  do b[n++] = (char) ('0' + v % 10), v /= 10; while (v);
  while (n) serial_putc(b[--n]); }

// a pin through the gpio matrix: io mux function 1 (gpio), its output signal sel, enabled
static void pin_out(uint32_t n, uint32_t sel) {
  R(IOMUX + 4u + 4u * n) = (R(IOMUX + 4u + 4u * n) & ~(7u << 12)) | 1u << 12;
  R(GPIO + 0x554u + 4u * n) = sel | 1u << 9;
  R(GPIO + 0x24u) = 1u << n; }

// rmt channel 0 at 20 mhz (xtal 40 mhz, the channel's divider 2): 50 ns a tick, no carrier,
// its ram written directly
static void rmt_init(void) {
  R(PCR + 0x2Cu) = 1u | 1u << 1;                            // apb clock on, held in reset
  R(PCR + 0x2Cu) = 1u;
  R(PCR + 0x30u) = 3u << 20 | 1u << 22;                     // xtal, divider 1, on
  R(RMT + 0x68u) |= 1u << 31 | 1u;                          // register clock, ram by address; its sclk bits kept
  R(RMT + 0x10u) = 2u << 8 | 1u << 16 | 1u << 6;            // divider 2, one block, idle low
  R(RMT + 0x10u) = 2u << 8 | 1u << 16 | 1u << 6 | 1u << 24; }

// a ws2812 bit as two levels: 0 is 0.4 us high then 0.85 low, 1 is 0.8 then 0.45
static uint32_t wsbit(uint32_t b) {
  uint32_t const hi = b ? 16u : 8u, lo = b ? 9u : 17u;
  return (1u << 15 | hi) | lo << 16; }

// one pixel, grb, msb first; then the latch, past the longest a part asks (280 us)
static void show(uint8_t const grb[3]) {
  volatile uint32_t *ram = (volatile uint32_t *)(uintptr_t) (RMT + 0x400u);
  for (uint32_t i = 0; i < 24; i++) ram[i] = wsbit(grb[i / 8] >> (7 - i % 8) & 1u);
  ram[24] = 0;
  R(RMT + 0x44u) = 1u;                                      // tx end, cleared
  uint32_t const c = 2u << 8 | 1u << 16 | 1u << 6;
  R(RMT + 0x10u) = c | 1u << 1 | 1u << 24;                  // read address from the start
  R(RMT + 0x10u) = c | 1u | 1u << 24;
  for (uint32_t k = 0; k < 100000u && !(R(RMT + 0x38u) & 1u); k++) {}
  us(1000); }

// the sensor clocked off the crystal, reset, sampling on its own timer and powered; its reading
// creeps toward the die's. the dac keeps its reset range, offset 0 (-10..80 c)
static void tsens_init(void) {
  R(PCR + 0x88u) |= 1u << 22 | 1u << 20;
  R(PCR + 0x88u) |= 1u << 23;
  R(PCR + 0x88u) &= ~(1u << 23);
  R(SARADC + 0x68u) |= 1u << 16;
  R(SARADC + 0x58u) |= 1u << 22;
  us(20000); }

// tenths of a degree, the trm's 0.4386 v - 20.52 at offset 0
static int32_t tenths(uint32_t *raw) {
  uint32_t const v = R(SARADC + 0x58u) & 0xFFu;
  *raw = v;
  return ((int32_t) (4386u * v) - 205200) / 1000; }

void gauge(int green) {
  pin_out(pixpow, 0x80u);
  R(GPIO + 0x08u) = 1u << pixpow;
  pin_out(pix, rmt_out0);
  rmt_init();
  if (!green) {
    uint8_t const red[3] = { 0, 64, 0 }, off[3] = { 0, 0, 0 };
    for (;;) show(red), ms(0, 500), show(off), ms(0, 500); }
  tsens_init();
  struct feed f = { .age = 10 };
  for (;;) {
    uint32_t raw;
    int32_t const die = tenths(&raw), tau = f.age < 10;
    int32_t const t = tau ? f.t : die, lo = tau ? 300 : 100, span = tau ? 600 : 500;
    int32_t k = (t - lo) * 255 / span;
    k = k < 0 ? 0 : k > 255 ? 255 : k;
    show(gauge_grb[k]);
    int32_t const a = t < 0 ? -t : t;
    puts_(tau ? "; tau " : "; die "), puts_(t < 0 ? "-" : ""), putd(a / 10), serial_putc('.'), putd(a % 10);
    puts_(" c (die raw "), putd((int32_t) raw), puts_(", magma "), putd(k), puts_(")\n");
    ms(&f, 1000);
    if (f.age < 10) f.age++; } }
