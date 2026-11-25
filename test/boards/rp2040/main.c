// raspberry pi pico (RP2040) firmware, mooncc -t thumb1, no SDK. not love: 264 KB is under
// any bake's arena, so this runs the toolchain's battery on silicon (test_mps2_t1's ISA) --
// LED slow blink all green, fast a miss. console UART0 on GPIO0/1 at 115200 8N1; the chip's
// own usb serial port gives each host that opens it the report, and 134 baud there reboots it
// into the rom's drive
#include <stdint.h>
#include "rp2040.h"
#define BATTERY1_LM
#include "../battery1.h"

void usb_init(void);
void usb_poll(void);
void usb_putc(int c);
void usb_flush(void);
int usb_up(void);
int usb_rx_ready(void);

int main(void) {
  // first light before anything else
  gpio_init(LED_PIN); gpio_set_dir(LED_PIN, 1); gpio_put(LED_PIN, 1);
  serial_init();
  puts_("\n; mooncc/rp2040 (cortex-m0+, thumb1)\n");
  char const *at = ((uintptr_t) main >> 28 == 2u ? "; from sram\n" : "; from flash\n");   // where this code runs
  puts_(at);
  int r = run();
  puts_(r <= 100 ? "; all " : "; FAILED at ");
  putu((uint32_t)(r <= 100 ? r : r - 100));
  puts_(r <= 100 ? "/32 green\n" : "\n");
  // the LED is the status channel when no terminal is watching; the usb port tended between
  usb_init();
  uint32_t half = r <= 100 ? 500u : 120u, t = clock_ms();
  int told = 0;
  for (;;) {
    usb_poll(); (void) usb_rx_ready();
    if (usb_up() && !told) {
      for (const char *m = "\n; mooncc/rp2040 (cortex-m0+, thumb1)\n"; *m; m++) usb_putc(*m);
      for (const char *m = at; *m; m++) usb_putc(*m);
      for (const char *m = r <= 100 ? "; all " : "; FAILED at "; *m; m++) usb_putc(*m);
      bput_n(usb_putc, (uint32_t)(r <= 100 ? r : r - 100), 10);
      for (const char *m = r <= 100 ? "/32 green\n" : "\n"; *m; m++) usb_putc(*m);
      usb_flush(); told = 1; }
    if (!usb_up()) told = 0;
    if (clock_ms() - t >= half) { t = clock_ms(); gpio_put(LED_PIN, !gpio_get(LED_PIN)); } } }
