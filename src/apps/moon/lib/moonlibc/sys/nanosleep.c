#include "../impl.h"

int nanosleep(struct timespec const *req, struct timespec *rem) {
#ifdef __i386__
  return (int) er(sc4(NR_clock_nanosleep, 0, 0, (long) req, (long) rem));   /* CLOCK_REALTIME, relative */
#else
  return (int) er(sc2(NR_nanosleep, (long) req, (long) rem));
#endif
}
