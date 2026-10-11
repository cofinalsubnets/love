#include "../impl.h"

off_t lseek(int fd, off_t off, int wh) {
#ifdef __i386__
  off_t r;                                                    /* _llseek: the offset split, the answer laid */
  long e = er(sc5(NR__llseek, fd, (long) (off >> 32), (long) off, (long) &r, wh));
  return e < 0 ? -1 : r;
#else
  if (__love_osv == 3) return er(sc4(NR_lseek, fd, 0, off, wh));   /* the classic PAD */
  return er(sc3(NR_lseek, fd, off, wh));
#endif
}
