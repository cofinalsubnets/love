#include "../impl.h"

/* ---- sockets ---- */
/* linux's signature; freebsd's differs, so its number is off the map and a
 * freebsd kernel answers ENOSYS until a body lands. */
ssize_t sendfile(int out, int in, off_t *off, size_t n) {
  return er(sc4(NR_sendfile, out, in, (long) off, (long) n)); }
