#include "../impl.h"

/* linux reads a null path as the fd itself; the BSDs and xnu have their own call */
int futimens(int fd, struct timespec const *ts) {
  if (__love_osv == 2 || __love_osv == 3) {
    struct timespec t2[2];
    if (ts && __love_osv == 2) {                   /* freebsd's UTIME_NOW/OMIT are -1/-2 */
      t2[0] = ts[0]; t2[1] = ts[1];
      for (int i = 0; i < 2; i++)
        if (t2[i].tv_nsec == UTIME_NOW) t2[i].tv_nsec = -1;
        else if (t2[i].tv_nsec == UTIME_OMIT) t2[i].tv_nsec = -2;
      ts = t2; }
    return (int) er(fb2(__love_osv == 2 ? 546 : 472, fd, (long) ts)); }
  if (__love_osv == 4) {                           /* futimes, at microseconds */
    struct timeval tv[2];
    if (ts) for (int i = 0; i < 2; i++) {
      if (ts[i].tv_nsec == UTIME_NOW || ts[i].tv_nsec == UTIME_OMIT) { __errno_v = EINVAL; return -1; }
      tv[i].tv_sec = ts[i].tv_sec, tv[i].tv_usec = ts[i].tv_nsec / 1000; }
    return (int) er(fb2(139, fd, ts ? (long) tv : 0)); }
  return utimensat(fd, 0, ts, 0); }
