#include "../impl.h"

/* the BSDs have fexecve; linux spells it execveat on an empty path */
int fexecve(int fd, char *const *av, char *const *ev) {
  if (__love_osv >= 2) return (int) er(sc3(NR_execveat, fd, (long) av, (long) ev));
  return (int) er(sc5(NR_execveat, fd, (long) "", (long) av, (long) ev, AT_EMPTY_PATH)); }
