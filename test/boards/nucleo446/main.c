// Nucleo-F446RE firmware, all mooncc -t thumb2sp (single-precision FPU, f64 through __aeabi_*).
// not love (128 KB SRAM): the toolchain on silicon, a self-check battery over the ST-LINK VCP.
// -D QSMOKE exits through qemu semihosting with the tally (100+n the first miss, 98 a fault),
// booted by hand (`make -C test/boards/nucleo446 smoke`); the device blinks slow green, fast a miss
#include <stdint.h>
#include "nucleo446.h"
#include "../battery.h"

int main(void) {
  // first light: a board that dies later still shows crt0 and the clocks worked
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
  // slow blink green, fast a miss; the button holds it solid
  uint32_t half = r <= 100 ? 500u : 120u;
  for (;;) {
    led_put(1); { uint32_t t = clock_ms(); while (clock_ms() - t < half && !btn_get()) {} }
    led_put(0); { uint32_t t = clock_ms(); while (clock_ms() - t < half && !btn_get()) {} } } }
