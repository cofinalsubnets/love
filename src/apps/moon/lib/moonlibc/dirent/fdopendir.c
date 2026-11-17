#include "../impl.h"

DIR *fdopendir(int fd) {
  struct stat st;
  if (fstat(fd, &st) < 0) return 0;
  if (!S_ISDIR(st.st_mode)) { errno = ENOTDIR; return 0; }
  DIR *d = malloc(sizeof(DIR));
  if (!d) return 0;
  d->fd = fd; d->pos = 0; d->len = 0;
  return d; }
