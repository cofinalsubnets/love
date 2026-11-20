#include "../impl.h"
/* linux only; a BSD answers ENOSYS */
int signalfd(int fd, sigset_t const *m, int fl) {
  unsigned long km[LvSigsz / sizeof(long)];
  __love_ksig(km, m);
  return (int) er(sc4(NR_signalfd4, fd, (long) km, LvSigsz, fl)); }
