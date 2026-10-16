#include "../impl.h"

int madvise(void *p, long n, int adv) {
  if (__love_osv >= 2) {
    /* 0..4 agree; FREE is 8, fb 5, nb 6; DONTFORK/DOFORK have no twin (fb 10 is
     * MADV_PROTECT), so they no-op */
    if (adv == 8) adv = __love_osv == 3 ? 6 : 5;
    else if (adv == 10 || adv == 11) return 0; }
  return (int) er(sc3(NR_madvise, (long) p, n, adv)); }
