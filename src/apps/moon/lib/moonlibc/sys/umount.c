#include "../impl.h"

/* linux's; freebsd's unmount differs, so a BSD answers ENOSYS */
int umount2(char const *tgt, int fl) {
  return (int) er(sc2(NR_umount2, (long) tgt, (long) fl)); }
int umount(char const *tgt) { return umount2(tgt, 0); }
