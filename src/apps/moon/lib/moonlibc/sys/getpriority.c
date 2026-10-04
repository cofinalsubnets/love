#include "../impl.h"
#include <sys/resource.h>

/* linux's raw call answers 20 - nice so no answer looks like an error; a BSD answers the
 * nice itself, which may be negative, so its carry is read here rather than through er. */
int getpriority(int w, id_t who) {
  if (__love_osv >= 2) {
    long r = __love_sys(NR_fb_getpriority, w, (long) who, 0, 0, 0, 0);
    if (r < -4096L) { __errno_v = (int) __love_errfb(-r - 4096); return -1; }
    return (int) r; }
  long r = er(sc2(NR_getpriority, w, (long) who));
  return r < 0 ? -1 : (int) (20 - r); }
int setpriority(int w, id_t who, int n) {
  return (int) er(sc3(NR_setpriority, w, (long) who, n)); }
