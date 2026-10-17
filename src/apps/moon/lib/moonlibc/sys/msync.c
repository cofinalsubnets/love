#include "../impl.h"

/* linux's flags are netbsd's; freebsd spells MS_SYNC as 0, its default, and macos 0x10 */
int msync(void *p, unsigned long n, int fl) {
  if (__love_osv == 2) fl &= ~MS_SYNC;
  if (__love_osv == 4 && (fl & MS_SYNC)) fl = (fl & ~MS_SYNC) | 0x10;
  return (int) er(sc3(NR_msync, (long) p, (long) n, fl)); }
