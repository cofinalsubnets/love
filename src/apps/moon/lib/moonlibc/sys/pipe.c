#include "../impl.h"

int pipe(int *fds) {
#ifdef LvMac
  if (__love_osv == 4) {                   /* no pipe2: libSystem's pipe, or the ends in registers */
    long r = __love_door(42, (long) fds, 0, 0, 0, 0, 0);
    if (r != LvNoDoor) return __love_parked(r) ? (__errno_v = (int) __love_errfb(-r - 4096), -1) : 0;
    r = __love_macpipe();
    if (__love_parked(r)) { __errno_v = (int) __love_errfb(-r - 4096); return -1; }
    fds[0] = (int) r, fds[1] = (int) (r >> 32);
    return 0; }
#endif
  return (int) er(sc2(NR_pipe2, (long) fds, 0)); }
