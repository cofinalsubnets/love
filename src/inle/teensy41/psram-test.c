// PSRAM smoke test, a bake-free main: probe FlexSPI2, print the ids and size, pattern-test the
// span. report on LPUART6 at 115200; the LED: slow = pass, solid = fail, fast = no PSRAM.
// `make -C src/inle/teensy41 psramtest`
#include <stdint.h>
#include "teensy41.h"
#include "../bput.h"
#include "psram.h"

#define PSRAM ((volatile uint32_t *) 0x70000000u)

static void puts_(const char *s) { bput_s(uart_putc, s); }
static void puthex(uint32_t v) { bput_x(uart_putc, v, 8); }
static void putdec(uint32_t v) { bput_n(uart_putc, v, 10); }

// main.c is absent from this build; te_ms is teensy41.c's
uintptr_t te_ms(void);
static void sleep_ms(uintptr_t ms) {
  uintptr_t start = te_ms();
  while (te_ms() - start < ms) ; }

static void blink_forever(uint32_t ms) {
  for (;;) {
    gpio_put(LED_BIT, 1); sleep_ms(ms);
    gpio_put(LED_BIT, 0); sleep_ms(ms); } }

void te_main(void) {
  gpio_init(LED_BIT); gpio_set_dir(LED_BIT, 1); gpio_put(LED_BIT, 1);
  puts_("\r\n; psram probe\r\n");
  uint32_t mb = psram_init();
  puts_("; chip0 id "); puthex(psram_chip_id(0));
  puts_("  chip1 id "); puthex(psram_chip_id(1));
  puts_("\r\n; size "); putdec(mb); puts_(" MB\r\n");
  if (mb == 0) { puts_("; NO PSRAM -- check solder\r\n"); blink_forever(120); }

  uint32_t words = (mb << 20) / 4;
  uint32_t bad = 0, first_bad = 0, first_want = 0, first_got = 0;
  // pass 1: an address-tagged word every 1 KB, across both chips and their seam
  for (uint32_t i = 0; i < words; i += 256) PSRAM[i] = 0xA5000000u + i;
  for (uint32_t i = 0; i < words; i += 256) {
    uint32_t got = PSRAM[i], want = 0xA5000000u + i;
    if (got != want && !bad++) { first_bad = i; first_want = want; first_got = got; } }
  // pass 2: the first and last 64 KB dense, tag inverted so pass 1's residue can't fake it
  for (uint32_t i = 0; i < 16384; i++) {
    PSRAM[i] = ~(0x5A000000u + i);
    PSRAM[words - 1 - i] = ~(0xC3000000u + i); }
  for (uint32_t i = 0; i < 16384; i++) {
    uint32_t got = PSRAM[i], want = ~(0x5A000000u + i);
    if (got != want && !bad++) { first_bad = i; first_want = want; first_got = got; }
    got = PSRAM[words - 1 - i]; want = ~(0xC3000000u + i);
    if (got != want && !bad++) { first_bad = words - 1 - i; first_want = want; first_got = got; } }

  if (bad) {
    puts_("; FAIL "); putdec(bad); puts_(" bad words, first @ word ");
    puthex(first_bad); puts_(" want "); puthex(first_want);
    puts_(" got "); puthex(first_got); puts_("\r\n");
    gpio_put(LED_BIT, 1);
    for (;;) ; }
  puts_("; PASS "); putdec(mb); puts_(" MB clean\r\n");
  // heartbeat + echo: both wire directions
  { uint32_t t = 0; uintptr_t last = te_ms();
    puts_("; echo ready\r\n");
    for (;;) {
      if (uart_rx_ready()) {
        int c = uart_getc();
        puts_("; heard "); puthex((uint32_t) c); puts_("\r\n"); }
      if (te_ms() - last >= 2000) {
        last = te_ms();
        puts_("; tick "); putdec(t++); puts_("\r\n");
        gpio_put(LED_BIT, t & 1); } } } }
