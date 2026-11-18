#include "../impl.h"
#include <sys/time.h>

/* the real timer, as glibc lays it: the seconds left, a part second rounding up */
unsigned int alarm(unsigned int s) {
  struct itimerval v = { { 0, 0 }, { (long) s, 0 } }, old = { { 0, 0 }, { 0, 0 } };
  if (setitimer(ITIMER_REAL, &v, &old) < 0) return 0;
  return (unsigned int) old.it_value.tv_sec + (old.it_value.tv_usec >= 500000 || (!old.it_value.tv_sec && old.it_value.tv_usec)); }
