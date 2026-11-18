#include "../impl.h"

/* the mask swapped in until a handler runs; it always answers -1 and EINTR. the BSDs take a
 * 16-byte set (freebsd's sigsuspend, netbsd's __sigsuspend14), macos the word itself */
int sigsuspend(sigset_t const *s) {
  if (__love_osv >= 2) {
    unsigned long ks[2] = { __love_maskfb((unsigned long) s->__v[0]), 0 };
    if (__love_osv == 4) return (int) er(fb1(111, (long) (unsigned) ks[0]));
    return (int) er(fb1(__love_osv == 3 ? 294 : 341, (long) ks)); }
  unsigned long long k = s->__v[0];
  return (int) er(sc2(NR_rt_sigsuspend, (long) &k, 8)); }
