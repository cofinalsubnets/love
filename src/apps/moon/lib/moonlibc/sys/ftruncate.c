#include "../impl.h"

int ftruncate(int fd, off_t n) {
#if defined(__ARM_EABI__) || defined(__i386__)
  if (__love_osv >= 2) {                   /* (fd [PAD] len) */
    if (__love_osv == 3 || LvFbPad) return (int) er(sc4(NR_ftruncate, fd, 0, (long) n, (long) (n >> 32)));
    return (int) er(sc3(NR_ftruncate, fd, (long) n, (long) (n >> 32))); }
#endif
#if defined(__i386__) || defined(__riscv) && defined(__ILP32__)
  return (int) er(sc3(NR_ftruncate, fd, (long) n, (long) (n >> 32)));   /* ftruncate64: lo, hi */
#elif defined(__ARM_EABI__)
  return (int) er(sc4(NR_ftruncate, fd, 0, (long) n, (long) (n >> 32)));   /* eabi lays a 64-bit arg on an even pair */
#elif defined(__mips__)
  return (int) er(sc4(NR_ftruncate, fd, 0, (long) (n >> 32), (long) n));   /* o32: an even pair, hi first */
#else
  if (__love_osv == 3) return (int) er(sc3(NR_ftruncate, fd, 0, n));   /* netbsd pads before a 64-bit arg */
  return (int) er(sc2(NR_ftruncate, fd, n));
#endif
}
