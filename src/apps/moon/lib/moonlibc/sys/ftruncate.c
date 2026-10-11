#include "../impl.h"

int ftruncate(int fd, off_t n) {
#ifdef __i386__
  return (int) er(sc3(NR_ftruncate, fd, (long) n, (long) (n >> 32)));   /* ftruncate64: lo, hi */
#else
  if (__love_osv == 3) return (int) er(sc3(NR_ftruncate, fd, 0, n));   /* the classic PAD */
  return (int) er(sc2(NR_ftruncate, fd, n));
#endif
}
