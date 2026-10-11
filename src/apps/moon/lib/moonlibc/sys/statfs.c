#include "../impl.h"
#include <sys/vfs.h>

/* linux's, and linux's alone: the struct is off the map on both BSDs, so this asks
 * by the canonical number and a BSD hears the map's ENOSYS back. */
int statfs(char const *p, struct statfs *b) {
#ifdef __i386__
  return (int) er(sc3(NR_statfs64, (long) p, sizeof *b, (long) b));
#else
  return (int) er(sc2(NR_statfs, (long) p, (long) b));
#endif
}

int fstatfs(int fd, struct statfs *b) {
#ifdef __i386__
  return (int) er(sc3(NR_fstatfs64, fd, sizeof *b, (long) b));
#else
  return (int) er(sc2(NR_fstatfs, fd, (long) b));
#endif
}
