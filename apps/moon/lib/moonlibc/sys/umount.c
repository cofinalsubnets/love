#include "../impl.h"

/* linux's umount2; freebsd spells it unmount and takes (path, flags) at another
 * number, so that one is off the map and a BSD kernel answers ENOSYS -- the same
 * standing this member's opposite number, mount, already has. */
int umount2(char const *tgt, int fl) {
  return (int) er(sc2(NR_umount2, (long) tgt, (long) fl)); }
int umount(char const *tgt) { return umount2(tgt, 0); }
