#include "../impl.h"

int ftruncate(int fd, off_t n) {
#if defined(__ARM_EABI__) || defined(__i386__)
  if (__love_osv >= 2) {                   /* (fd [PAD] len) */
    if (__love_osv == 3 || LvFbPad) return (int) er(sc4(NR_ftruncate, fd, 0, (long) n, (long) (n >> 32)));
    return (int) er(sc3(NR_ftruncate, fd, (long) n, (long) (n >> 32))); }
#endif
#ifdef __i386__
  return (int) er(sc3(NR_ftruncate, fd, (long) n, (long) (n >> 32)));   /* ftruncate64: lo, hi */
#elif defined(__ARM_EABI__)
  return (int) er(sc4(NR_ftruncate, fd, 0, (long) n, (long) (n >> 32)));   /* eabi lays a 64-bit arg on an even pair */
#else
  if (__love_osv == 3) return (int) er(sc3(NR_ftruncate, fd, 0, n));   /* the classic PAD */
  return (int) er(sc2(NR_ftruncate, fd, n));
#endif
}
