#include "../impl.h"
#include <sys/vfs.h>

/* linux only; a BSD answers ENOSYS */
int statfs(char const *p, struct statfs *b) {
#ifdef __ILP32__
  return (int) er(sc3(NR_statfs64, (long) p, sizeof *b, (long) b));
#else
  return (int) er(sc2(NR_statfs, (long) p, (long) b));
#endif
}

int fstatfs(int fd, struct statfs *b) {
#ifdef __ILP32__
  return (int) er(sc3(NR_fstatfs64, fd, sizeof *b, (long) b));
#else
  return (int) er(sc2(NR_fstatfs, fd, (long) b));
#endif
}
