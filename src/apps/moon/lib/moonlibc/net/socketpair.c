#include "../impl.h"

int socketpair(int d, int t, int p, int sv[2]) {
  long k = t;
  if (__love_osv >= 2) d = (int) __love_affb(d), k = __love_sotype(t);
  int r = (int) er(sc4(NR_socketpair, d, k, p, (long) sv));
#ifdef LvMac
#ifdef LvMac
  if (!r && __love_osv == 4) __love_macsofl(sv[0], t), __love_macsofl(sv[1], t);
#endif
#endif
  return r; }
