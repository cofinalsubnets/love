#include "../impl.h"

int socketpair(int d, int t, int p, int sv[2]) {
  if (__love_osv >= 2) d = (int) __love_affb(d), t = (int) __love_sotype(t);
  return (int) er(sc4(NR_socketpair, d, t, p, (long) sv)); }
