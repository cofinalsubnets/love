#include "../impl.h"
#include <sys/resource.h>

/* netbsd's own __getrusage50 (its 117 is the old 32-bit time): the same shape, but a timeval
 * whose usec is an int in a padded word, so the upper half is noise */
int getrusage(int who, struct rusage *ru) {
  if (__love_osv == 3) {
    long r = er(fb2(445, who, (long) ru));
    if (r == 0) ru->ru_utime.tv_usec = (int) ru->ru_utime.tv_usec, ru->ru_stime.tv_usec = (int) ru->ru_stime.tv_usec;
    return (int) r; }
  return (int) er(sc2(NR_getrusage, who, (long) ru)); }
