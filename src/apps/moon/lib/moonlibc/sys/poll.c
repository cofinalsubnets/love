#include "../impl.h"

int poll(struct pollfd *fds, nfds_t n, int ms) {
  if (__love_osv == 4) return (int) er(fb3(230, (long) fds, (long) n, ms));   /* no ppoll there: poll(2) */
  struct timespec ts;
  ts.tv_sec = ms / 1000;
  ts.tv_nsec = (long) (ms % 1000) * 1000000;
  return (int) er(sc5(NR_ppoll, (long) fds, (long) n, ms < 0 ? 0 : (long) &ts, 0, 8)); }
