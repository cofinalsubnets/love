#include "../impl.h"
/* linux only; a BSD answers ENOSYS */
int signalfd(int fd, sigset_t const *m, int fl) {
  unsigned long long km = m->__v[0];
  return (int) er(sc4(NR_signalfd4, fd, (long) &km, 8, fl)); }
