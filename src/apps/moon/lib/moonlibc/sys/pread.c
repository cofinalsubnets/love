#include "../impl.h"

long pread(int fd, void *b, unsigned long n, off_t off) {
#ifdef __i386__
  return er(sc5(NR_pread64, fd, (long) b, (long) n, (long) off, (long) (off >> 32)));   /* lo, hi */
#elif defined(__ARM_EABI__)
  return er(sc6(NR_pread64, fd, (long) b, (long) n, 0, (long) off, (long) (off >> 32)));   /* eabi: an even pair */
#else
  if (__love_osv == 3) return er(sc5(NR_pread64, fd, (long) b, (long) n, 0, off));   /* netbsd's pad */
  return er(sc4(NR_pread64, fd, (long) b, (long) n, off));
#endif
}
