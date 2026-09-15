#include "../impl.h"
#include <sys/resource.h>

/* who: RUSAGE_SELF or RUSAGE_CHILDREN, both spelled the same on every kernel here.
 * freebsd rides the map; netbsd has no row and answers ENOSYS. */
int getrusage(int who, struct rusage *ru) {
  return (int) er(sc2(NR_getrusage, who, (long) ru)); }
