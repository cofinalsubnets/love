#include "../impl.h"

void *mmap(void *a, long n, int prot, int fl, int fd, off_t off) {
  long r;
#if defined(__ARM_EABI__) || defined(__i386__)
  if (__love_osv >= 2) {                   /* (addr len prot flags fd [PAD] pos), pos a pair */
    long nr = __love_osv == 3 ? 197 : NR_fb_mmap, f2 = (int) __love_mapfb(fl), lo = (long) off, hi = (long) (off >> 32);
    r = __love_osv == 3 || LvFbPad ? __love_fb8(nr, (long) a, n, prot, f2, fd, 0, lo, hi)
                                   : __love_fb8(nr, (long) a, n, prot, f2, fd, lo, hi, 0); }
  else
#elif defined(LvOsTranslate)
  if (__love_osv == 3)
    /* netbsd pads before pos, so pos is a seventh arg */
    r = __love_fb7(197, (long) a, n, prot, (int) __love_mapfb(fl), fd, 0, off);
  else
#endif
  {
    if (__love_osv >= 2) fl = (int) __love_mapfb(fl);   /* netbsd took its own door above */
#ifdef __ILP32__
    if (off & 4095) { __errno_v = EINVAL; return (void *) -1; }
    r = sc6(NR_mmap, (long) a, n, prot, fl, fd, (long) (off >> 12));   /* mmap2: the offset in pages */
#else
    r = sc6(NR_mmap, (long) a, n, prot, fl, fd, off);
#endif
  }
  if ((unsigned long) r > (unsigned long) -4096L) { __errno_v = (int) -r; return (void *) -1; }
  return (void *) r; }
