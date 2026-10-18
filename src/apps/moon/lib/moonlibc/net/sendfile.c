#include "../impl.h"

/* linux's; freebsd's sendfile differs, so a BSD answers ENOSYS */
ssize_t sendfile(int out, int in, off_t *off, size_t n) {
  return er(sc4(NR_sendfile, out, in, (long) off, (long) n)); }
