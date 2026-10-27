#include "../impl.h"

int unlinkat(int dfd, char const *p, int fl) {
  if (__love_osv >= 2 && (fl & AT_REMOVEDIR)) fl = (fl & ~AT_REMOVEDIR) | 0x800;   /* the BSDs' bit */
  return (int) er(sc3(NR_unlinkat, dfd, (long) p, fl)); }
