#include "../impl.h"

/* linux's, and linux's alone: no row on the map, so a BSD asks and hears ENOSYS.
 * the one call that answers a birth time, which is why `stat`'s block reaches it. */
int statx(int fd, char const *p, int fl, unsigned int mask, struct statx *b) {
  return (int) er(sc5(NR_statx, fd, (long) p, fl, mask, (long) b)); }
