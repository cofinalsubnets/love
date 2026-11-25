// xiao nrf52840 firmware, all mooncc -t thumb2sp (single-precision FPU, f64 through __aeabi_*).
// not love (256 KB SRAM): the toolchain on silicon, the boards' battery over the chip's own usb
// serial port, from sram, where loader.c puts it. the battery runs once a host opens the port,
// and each host that opens it gets the report; the LED shows slow green all green, fast red a
// miss. 134 baud there resets the board into the loader
#include <stdint.h>
#include "nrf52840.h"
#include "../battery.h"

void usb_reboot(void) { reset(); }

int main(void) {
  // first light: a board that dies later still shows crt0 and the clocks worked
  led_init(); led_put(LED_BLUE, 1);
  usb_init();
  while (!usb_up()) usb_poll();
  int const r = run();
  led_put(LED_BLUE, 0);
  uint32_t const pin = r <= 100 ? LED_GREEN : LED_RED, half = r <= 100 ? 500u : 120u;
  for (int on = 1;; on = !on) {
    puts_("\n; mooncc/nrf52840\n; core 64 MHz, ");
    puts_(clock_xtal() ? "crystal\n" : "rc -- no crystal\n");
    puts_((uintptr_t) main >> 28 == 2u ? "; from sram\n" : "; from flash\n");   // where this code runs
    puts_(r <= 100 ? "; all " : "; FAILED at ");
    putu((uint32_t) (r <= 100 ? r : r - 100));
    puts_(r <= 100 ? "/28 green\n" : "\n");
    usb_flush();
    while (usb_up())
      for (uint32_t t = clock_ms(); clock_ms() - t < half && usb_up(); ) usb_poll(), (void) usb_rx_ready();
    while (!usb_up()) {
      led_put(pin, on), on = !on;
      for (uint32_t t = clock_ms(); clock_ms() - t < half; ) usb_poll(), (void) usb_rx_ready(); } } }
