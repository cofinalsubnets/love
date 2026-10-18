#include "../impl.h"

int lchown(char const *p, unsigned int u, unsigned int g) { return (int) er(sc5(NR_fchownat, AT_FDCWD, (long) p, u, g, __love_osv >= 2 ? 0x200 : AT_SYMLINK_NOFOLLOW)); }   /* the BSDs' bit */
