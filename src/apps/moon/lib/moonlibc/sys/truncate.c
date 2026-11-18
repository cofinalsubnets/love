#include "../impl.h"

/* by the fd, so ftruncate's per-kernel argument layouts serve both */
int truncate(char const *p, off_t n) {
  int fd = open(p, O_WRONLY | O_CLOEXEC);
  if (fd < 0) return -1;
  int r = ftruncate(fd, n), e = errno;
  close(fd);
  errno = e;
  return r; }
