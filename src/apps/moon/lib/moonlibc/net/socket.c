#include "../impl.h"

int socket(int d, int t, int p) {
  if (__love_osv >= 2) d = (int) __love_affb(d), t = (int) __love_sotype(t);
  return (int) er(sc3(NR_socket, d, t, p)); }
