#include "../impl.h"

int rmdir(char const *p) {
  long fl = __love_osv >= 2 ? 0x800 : AT_REMOVEDIR;   /* the BSDs' AT_REMOVEDIR */
  return (int) er(sc3(NR_unlinkat, AT_FDCWD, (long) p, fl)); }
