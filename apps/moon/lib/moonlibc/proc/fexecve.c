#include "../impl.h"

/* ---- fexecve: exec an image by OPEN FD, so it need not be reachable by name ----
 * which is the whole point of it: after a chroot, or an unlink, or a mount move,
 * the path a process was started from names nothing, and the fd still names the
 * image. the BSDs carry the call; linux spells the same act as execveat over an
 * empty path with AT_EMPTY_PATH. the NUMBER rides os.c's map either way, so what
 * parts here is only the shape. */
int fexecve(int fd, char *const *av, char *const *ev) {
  if (__ai_osv >= 2) return (int) er(sc3(NR_execveat, fd, (long) av, (long) ev));
  return (int) er(sc5(NR_execveat, fd, (long) "", (long) av, (long) ev, AT_EMPTY_PATH)); }
