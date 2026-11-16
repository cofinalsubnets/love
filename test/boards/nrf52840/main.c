// xiao nrf52840 firmware, all mooncc -t thumb2sp (single-precision FPU, f64 through __aeabi_*).
// not love (256 KB SRAM): the toolchain on silicon, nucleo446's self-check battery over UART0
// on D6/D7; the LED blinks slow green all green, fast red a miss. a line `uf2` on the UART
// reboots into the bootloader's drive
#include <stdint.h>
#include "nrf52840.h"
#include "../battery.h"

int main(void) {
  // first light: a board that dies later still shows crt0 and the clocks worked
  led_init(); led_put(LED_BLUE, 1);
  timer_init();
  puts_("\n; mooncc/nrf52840\n; core 64 MHz, ");
  puts_(clock_xtal() ? "crystal\n" : "rc -- no crystal\n");
  int r = run();
  puts_(r <= 100 ? "; all " : "; FAILED at ");
  putu((uint32_t)(r <= 100 ? r : r - 100));
  puts_(r <= 100 ? "/28 green\n" : "\n");
  led_put(LED_BLUE, 0);
  puts_("; send uf2 for the bootloader's drive\n");
  uint32_t pin = r <= 100 ? LED_GREEN : LED_RED, half = r <= 100 ? 500u : 120u;
  uint32_t last = 0;                                // the line's last three bytes
  for (int on = 1;; on = !on) {
    led_put(pin, on);
    for (uint32_t t = clock_ms(); clock_ms() - t < half; ) {
      if (!serial_rx_ready()) continue;
      int c = serial_getc();
      if ((c == '\r' || c == '\n') && last == ('u' << 16 | 'f' << 8 | '2')) {
        puts_("\n; to the uf2 drive\n"); reboot_uf2(); }
      last = c == '\r' || c == '\n' ? 0 : (last << 8 | (uint32_t) c) & 0xFFFFFFu; } } }
