#include "../impl.h"

void *mmap(void *a, long n, int prot, int fl, int fd, long off) {
  long r;
#ifdef LvOsTranslate
  if (__love_osv == 3)
    /* netbsd keeps the classic pad: (addr len prot flags fd PAD pos), the
     * seventh riding the stack through the wide door */
    r = __love_fb7(197, (long) a, n, prot, (int) __love_mapfb(fl), fd, 0, off);
  else
#endif
  {
    if (__love_osv == 2) fl = (int) __love_mapfb(fl);
    r = sc6(NR_mmap, (long) a, n, prot, fl, fd, off); }
  if ((unsigned long) r > (unsigned long) -4096L) { __errno_v = (int) -r; return (void *) -1; }
  return (void *) r; }
