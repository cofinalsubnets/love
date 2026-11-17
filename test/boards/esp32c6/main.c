// esp32-c6 firmware, all mooncc -t rv32 (rv32imac, soft float: every float and double
// through rt.o). not love: the toolchain on silicon, the boards' battery from ram over
// the chip's own usb serial. the flash is never written
#include <stdint.h>
#include "../battery.h"

int main(void) {
  puts_("\n; mooncc/esp32c6\n; rv32imac from hp sram\n");
  int r = run();
  puts_(r <= 100 ? "; all " : "; FAILED at ");
  putu((uint32_t)(r <= 100 ? r : r - 100));
  puts_(r <= 100 ? "/28 green\n" : "\n");
  return r; }
