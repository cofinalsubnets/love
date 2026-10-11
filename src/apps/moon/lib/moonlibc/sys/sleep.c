#include "../impl.h"

/* an interrupted sleep answers the seconds left, a part second rounding up */
unsigned int sleep(unsigned int s) {
  struct timespec ts = {0};
  ts.tv_sec = s;
  return nanosleep(&ts, &ts) < 0 ? (unsigned int) ts.tv_sec + (ts.tv_nsec > 0) : 0; }
