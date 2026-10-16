#include "../impl.h"

/* pselect6, as arm64 and riscv have no select. linux's 6th arg is a {set, size} pair,
 * a BSD's a bare sigset pointer */
int select(int n, fd_set *r, fd_set *w, fd_set *e, struct timeval *tv) {
  struct timespec ts, *tp = 0;
  long sm[2];
  if (tv) { ts.tv_sec = tv->tv_sec; ts.tv_nsec = tv->tv_usec * 1000; tp = &ts; }
  sm[0] = 0; sm[1] = 8;
  if (__love_osv >= 2)
    return (int) er(sc6(NR_pselect6, n, (long) r, (long) w, (long) e, (long) tp, 0));
  return (int) er(sc6(NR_pselect6, n, (long) r, (long) w, (long) e, (long) tp, (long) sm)); }
