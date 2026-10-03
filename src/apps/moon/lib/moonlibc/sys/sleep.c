#include "../impl.h"

/* an interrupted sleep answers the seconds left, a part second rounding up */
unsigned int sleep(unsigned int s) {
  struct timespec ts = {s, 0};
  return er(sc2(NR_nanosleep, (long) &ts, (long) &ts)) < 0 ? (unsigned int) ts.tv_sec + (ts.tv_nsec > 0) : 0; }
