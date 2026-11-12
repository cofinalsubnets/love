#include "../impl.h"

/* linux's; freebsd's mount differs, so a BSD answers ENOSYS */
int mount(char const *src, char const *tgt, char const *ty, unsigned long fl, void const *d) {
  return (int) er(sc5(NR_mount, (long) src, (long) tgt, (long) ty, (long) fl, (long) d)); }
/* swap rides here, linux's too: a file or part laid by mkswap's rule */
int swapon(char const *p, int fl) { return (int) er(sc2(NR_swapon, (long) p, (long) fl)); }
int swapoff(char const *p) { return (int) er(sc1(NR_swapoff, (long) p)); }
