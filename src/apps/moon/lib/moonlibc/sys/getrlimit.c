#include "../impl.h"
#include <sys/resource.h>

/* the resource numbers are linux's: the BSDs part after RSS (memlock 6, nproc 7, nofile 8,
 * as 10) and spell infinity as the top signed value where linux has the top unsigned; both
 * translate here, so a caller reads one shape whichever kernel answers. */
int __ai_rlres(int r) {
  if (__ai_osv < 2) return r;
  switch (r) { case RLIMIT_MEMLOCK: return 6; case RLIMIT_NPROC: return 7;
               case RLIMIT_NOFILE: return 8; case RLIMIT_AS: return 10; default: return r; } }
int getrlimit(int r, struct rlimit *l) {
  int e = (int) er(sc2(NR_getrlimit, __ai_rlres(r), (long) l));
  if (!e && __ai_osv >= 2) {
    if (l->rlim_cur == 0x7fffffffffffffffUL) l->rlim_cur = RLIM_INFINITY;
    if (l->rlim_max == 0x7fffffffffffffffUL) l->rlim_max = RLIM_INFINITY; }
  return e; }
