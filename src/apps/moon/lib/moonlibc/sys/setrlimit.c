#include "../impl.h"
#include <sys/resource.h>

int __love_rlres(int r);
int setrlimit(int r, const struct rlimit *l) {
#ifdef __ILP32__
  if (__love_osv >= 2) {
    unsigned long long k[2] = { l->rlim_cur == RLIM_INFINITY ? 0x7fffffffffffffffULL : l->rlim_cur,
                                l->rlim_max == RLIM_INFINITY ? 0x7fffffffffffffffULL : l->rlim_max };
    return (int) er(sc2(NR_setrlimit, __love_rlres(r), (long) k)); }
#endif
  struct rlimit b = *l;
  if (__love_osv >= 2) {           /* our infinity, spelled as the BSDs' */
    if (b.rlim_cur == RLIM_INFINITY) b.rlim_cur = 0x7fffffffffffffffUL;
    if (b.rlim_max == RLIM_INFINITY) b.rlim_max = 0x7fffffffffffffffUL; }
  return (int) er(sc2(NR_setrlimit, __love_rlres(r), (long) &b)); }
