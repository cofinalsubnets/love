#include "../impl.h"

int openat(int dfd, char const *p, int fl, ...) {
  va_list ap; va_start(ap, fl);
  int mode = va_arg(ap, int);
  va_end(ap);
  if (__love_osv >= 2) fl = (int) __love_ofb(fl);
  else fl |= O_LARGEFILE;
  return (int) er(sc4(NR_openat, dfd, (long) p, fl, mode)); }
