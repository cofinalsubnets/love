#include "../impl.h"

int socket(int d, int t, int p) {
  long k = t;
  if (__love_osv >= 2) d = (int) __love_affb(d), k = __love_sotype(t);
  int r = (int) er(sc3(NR_socket, d, k, p));
#ifdef LvMac
#ifdef LvMac
  if (r >= 0 && __love_osv == 4) __love_macsofl(r, t);
#endif
#endif
  return r; }
