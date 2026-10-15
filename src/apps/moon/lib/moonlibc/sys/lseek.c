#include "../impl.h"

off_t lseek(int fd, off_t off, int wh) {
#ifdef __ARM_EABI__
  if (__love_osv >= 2) {                   /* both BSDs: (fd PAD off whence), the answer in r0:r1 */
    long long r = __love_sysw(__love_nrfb(NR_lseek), fd, 0, (long) off, (long) (off >> 32), wh, 0);
    if (r < -4096 && r >= -4096 - 256) { __errno_v = (int) __love_errfb((long) (-r - 4096)); return -1; }
    return r; }
#endif
#ifdef __ILP32__
  off_t r;                                                    /* _llseek: the offset split, the answer laid */
  long e = er(sc5(NR__llseek, fd, (long) (off >> 32), (long) off, (long) &r, wh));
  return e < 0 ? -1 : r;
#else
  if (__love_osv == 3) return er(sc4(NR_lseek, fd, 0, off, wh));   /* the classic PAD */
  return er(sc3(NR_lseek, fd, off, wh));
#endif
}
