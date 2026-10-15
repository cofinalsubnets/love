#include "../impl.h"

int nanosleep(struct timespec const *req, struct timespec *rem) {
#ifdef __ILP32__
#ifdef LvOsTranslate
  if (__love_osv >= 2) return (int) er(sc2(NR_nanosleep, (long) req, (long) rem));   /* the BSDs': a 64-bit time_t */
#endif
  return (int) er(sc4(NR_clock_nanosleep, 0, 0, (long) req, (long) rem));   /* CLOCK_REALTIME, relative */
#else
  return (int) er(sc2(NR_nanosleep, (long) req, (long) rem));
#endif
}
