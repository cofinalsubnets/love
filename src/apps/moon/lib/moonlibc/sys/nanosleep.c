#include "../impl.h"

int nanosleep(struct timespec const *req, struct timespec *rem) {
#ifdef LvMac
  if (__love_osv == 4) {
    /* xnu has no nanosleep: select(2) with no fds sleeps a timeval, rounded up to the
     * microsecond, and an interrupted one owes the time left, read off the clock */
    if (req->tv_nsec < 0 || req->tv_nsec >= 1000000000) { __errno_v = EINVAL; return -1; }
    struct timespec t0, t1;
    struct timeval tv = { req->tv_sec, (req->tv_nsec + 999) / 1000 };
    clock_gettime(1, &t0);
    long r = fb6(93, 0, 0, 0, 0, (long) &tv, 0);
    if (r >= 0) return 0;
    if (r == -EINTR && rem) {
      clock_gettime(1, &t1);
      long ns = (req->tv_sec - (t1.tv_sec - t0.tv_sec)) * 1000000000L + req->tv_nsec - (t1.tv_nsec - t0.tv_nsec);
      if (ns < 0) ns = 0;
      rem->tv_sec = ns / 1000000000L, rem->tv_nsec = ns % 1000000000L; }
    __errno_v = (int) -r;
    return -1; }
#endif
#ifdef __ILP32__
#ifdef LvOsTranslate
  if (__love_osv >= 2) return (int) er(sc2(NR_nanosleep, (long) req, (long) rem));   /* the BSDs': a 64-bit time_t */
#endif
  return (int) er(sc4(NR_clock_nanosleep, 0, 0, (long) req, (long) rem));   /* CLOCK_REALTIME, relative */
#else
  return (int) er(sc2(NR_nanosleep, (long) req, (long) rem));
#endif
}
