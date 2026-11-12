#include "../impl.h"

/* linux's two magic words; freebsd's reboot differs, so a BSD answers ENOSYS */
int reboot(int cmd) {
  return (int) er(sc4(NR_reboot, (long) 0xfee1dead, 672274793L, (long) (unsigned) cmd, 0)); }
/* linux's restart2: a restart with an argument for the firmware, a pi's "0 tryboot" */
int reboot2(char const *arg) {
  return (int) er(sc4(NR_reboot, (long) 0xfee1dead, 672274793L, (long) 0xa1b2c3d4u, (long) arg)); }
