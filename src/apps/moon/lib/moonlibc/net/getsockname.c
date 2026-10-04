#include "../impl.h"

int getsockname(int fd, struct sockaddr *a, socklen_t *n) {
  int r = (int) er(sc3(NR_getsockname, fd, (long) a, (long) n));
  if (r >= 0 && __love_osv >= 2) __love_saout(a, *n);
  return r; }
