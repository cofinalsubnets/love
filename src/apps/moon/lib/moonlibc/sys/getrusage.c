#include "../impl.h"
#include <sys/resource.h>

/* netbsd answers ENOSYS */
int getrusage(int who, struct rusage *ru) {
  return (int) er(sc2(NR_getrusage, who, (long) ru)); }
