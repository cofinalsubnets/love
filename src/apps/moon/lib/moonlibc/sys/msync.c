#include "../impl.h"

/* linux's flags are netbsd's; freebsd spells MS_SYNC as 0, its default */
int msync(void *p, unsigned long n, int fl) {
  if (__ai_osv == 2) fl &= ~MS_SYNC;
  return (int) er(sc3(NR_msync, (long) p, (long) n, fl)); }
