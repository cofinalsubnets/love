#include "../impl.h"

/* linux's two magic words; freebsd's reboot differs, so a BSD answers ENOSYS */
int reboot(int cmd) {
  return (int) er(sc4(NR_reboot, (long) 0xfee1dead, 672274793L, (long) (unsigned) cmd, 0)); }
