#include "../impl.h"
#include <sys/resource.h>

/* the resource numbers are linux's: the BSDs part after RSS (memlock 6, nproc 7, nofile 8,
 * as 10, macos's 5) and spell infinity as the top signed value where linux has the top unsigned; both
 * translate here, so a caller reads one shape whichever kernel answers. */
int __love_rlres(int r) {
  if (__love_osv < 2) return r;
  switch (r) { case RLIMIT_MEMLOCK: return 6; case RLIMIT_NPROC: return 7;
               case RLIMIT_NOFILE: return 8; case RLIMIT_AS: return __love_osv == 4 ? 5 : 10; default: return r; } }
int getrlimit(int r, struct rlimit *l) {
#ifdef __ILP32__
  if (__love_osv >= 2) {               /* the BSDs' is two 64-bit words, rlim_t ours 32 here */
    unsigned long long k[2];
    int e = (int) er(sc2(NR_getrlimit, __love_rlres(r), (long) k));
    if (!e) {
      l->rlim_cur = k[0] >= RLIM_INFINITY ? RLIM_INFINITY : (rlim_t) k[0];
      l->rlim_max = k[1] >= RLIM_INFINITY ? RLIM_INFINITY : (rlim_t) k[1]; }
    return e; }
#endif
  int e = (int) er(sc2(NR_getrlimit, __love_rlres(r), (long) l));
  if (!e && __love_osv >= 2) {
    if (l->rlim_cur == 0x7fffffffffffffffUL) l->rlim_cur = RLIM_INFINITY;
    if (l->rlim_max == 0x7fffffffffffffffUL) l->rlim_max = RLIM_INFINITY; }
  return e; }
