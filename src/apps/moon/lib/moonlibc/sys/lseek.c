#include "../impl.h"

off_t lseek(int fd, off_t off, int wh) {
#if defined(__ARM_EABI__) || defined(__i386__)
  if (__love_osv >= 2) {                   /* (fd [PAD] off whence), the answer in a register pair */
    long n = __love_nrfb(NR_lseek), lo = (long) off, hi = (long) (off >> 32);
    long long r = __love_osv == 3 || LvFbPad ? __love_sysw(n, fd, 0, lo, hi, wh, 0)
                                             : __love_sysw(n, fd, lo, hi, wh, 0, 0);
    if (r < -4096 && r >= -4096 - 256) { __errno_v = (int) __love_errfb((long) (-r - 4096)); return -1; }
    return r; }
#endif
#ifdef __ILP32__
  off_t r;                                                    /* _llseek: offset hi, lo; result by pointer */
  long e = er(sc5(NR__llseek, fd, (long) (off >> 32), (long) off, (long) &r, wh));
  return e < 0 ? -1 : r;
#else
  if (__love_osv == 3) return er(sc4(NR_lseek, fd, 0, off, wh));   /* netbsd pads before the offset */
  return er(sc3(NR_lseek, fd, off, wh));
#endif
}
