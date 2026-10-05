#include "../impl.h"

/* linux's: two magic words before the command. freebsd's reboot(howto) is another shape, so
 * its number is off the map, as mount's is. */
int reboot(int cmd) {
  return (int) er(sc4(NR_reboot, (long) 0xfee1dead, 672274793L, (long) (unsigned) cmd, 0)); }
