// esp32 firmware, all mooncc -t xtensa (call0, soft float: every float and double through
// rt.o), on the classic's lx6 or the s3's lx7. not love: the toolchain on silicon, the boards'
// battery from the rom's ram download over the board's serial
#include <stdint.h>
#include "../battery.h"

#ifdef ESP32S3
#define CHIP "esp32s3\n; lx7"
#else
#define CHIP "esp32\n; lx6"
#endif

int main(void) {
  puts_("\n; mooncc/" CHIP " from iram\n");
  int r = run();
  puts_(r <= 100 ? "; all " : "; FAILED at ");
  putu((uint32_t)(r <= 100 ? r : r - 100));
  puts_(r <= 100 ? "/28 green\n" : "\n");
  return r; }
