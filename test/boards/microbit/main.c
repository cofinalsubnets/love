// micro:bit v2 firmware, all mooncc -t thumb2sp (single-precision FPU, f64 through __aeabi_*).
// not love (128 KB SRAM): the toolchain on silicon, the boards' battery over the daplink's
// vcp; the centre LED blinks slow all green, fast a miss
#include <stdint.h>
#include "microbit.h"
#include "../battery.h"

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
  uint32_t half = r <= 100 ? 500u : 120u;
  for (int on = 0;; on = !on) {
    led_put(on);
    for (uint32_t t = clock_ms(); clock_ms() - t < half; ) {} } }
