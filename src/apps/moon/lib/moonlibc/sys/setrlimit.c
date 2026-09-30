#include "../impl.h"
#include <sys/resource.h>

int __ai_rlres(int r);
int setrlimit(int r, const struct rlimit *l) {
  struct rlimit b = *l;
  if (__ai_osv >= 2) {           /* our infinity, spelled as the BSDs' */
    if (b.rlim_cur == RLIM_INFINITY) b.rlim_cur = 0x7fffffffffffffffUL;
    if (b.rlim_max == RLIM_INFINITY) b.rlim_max = 0x7fffffffffffffffUL; }
  return (int) er(sc2(NR_setrlimit, __ai_rlres(r), (long) &b)); }
