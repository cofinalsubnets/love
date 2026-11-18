#include "../impl.h"

/* an error number back, errno untouched. the BSDs sleep the realtime and monotonic
 * clocks by nanosleep, an absolute time first made a span off the clock */
int clock_nanosleep(int c, int fl, struct timespec const *req, struct timespec *rem) {
  if (__love_osv >= 2) {
    if (c != CLOCK_REALTIME && c != CLOCK_MONOTONIC) return EINVAL;
    if (req->tv_nsec < 0 || req->tv_nsec >= 1000000000) return EINVAL;
    int e = errno, r;
    if (fl & TIMER_ABSTIME) {
      struct timespec now, d;
      if (clock_gettime(c, &now) < 0) return errno;
      long ns = (req->tv_sec - now.tv_sec) * 1000000000L + req->tv_nsec - now.tv_nsec;
      if (ns <= 0) return 0;
      d.tv_sec = ns / 1000000000L, d.tv_nsec = ns % 1000000000L;
      r = nanosleep(&d, 0) < 0 ? errno : 0; }
    else r = nanosleep(req, rem) < 0 ? errno : 0;
    errno = e;
    return r; }
  long r = sc4(NR_clock_nanosleep, c, fl, (long) req, (long) rem);
  return r < 0 ? (int) -r : 0; }
