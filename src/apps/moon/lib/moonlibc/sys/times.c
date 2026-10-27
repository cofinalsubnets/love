#include "../impl.h"
#include <sys/times.h>
#include <sys/resource.h>

/* in CLK_TCK's hundredths: the rusages, and the monotonic clock for the answer */
static clock_t __tk(struct timeval t) { return (clock_t) t.tv_sec * 100 + t.tv_usec / 10000; }
clock_t times(struct tms *t) {
  struct rusage s, c;
  if (getrusage(RUSAGE_SELF, &s) < 0 || getrusage(RUSAGE_CHILDREN, &c) < 0) return (clock_t) -1;
  if (t) {
    t->tms_utime = __tk(s.ru_utime); t->tms_stime = __tk(s.ru_stime);
    t->tms_cutime = __tk(c.ru_utime); t->tms_cstime = __tk(c.ru_stime); }
  struct timespec m;
  clock_gettime(CLOCK_MONOTONIC, &m);
  return (clock_t) m.tv_sec * 100 + m.tv_nsec / 10000000; }
