#include "../impl.h"
#include <sys/vfs.h>

/* linux's, and linux's alone: the struct is off the map on both BSDs, so this asks
 * by the canonical number and a BSD hears the map's ENOSYS back. */
int statfs(char const *p, struct statfs *b) {
  return (int) er(sc2(NR_statfs, (long) p, (long) b)); }

int fstatfs(int fd, struct statfs *b) {
  return (int) er(sc2(NR_fstatfs, fd, (long) b)); }
