#include "../impl.h"

/* the file grows to o + n if it is shorter; blocks are the filesystem's to give */
int posix_fallocate(int fd, off_t o, off_t n) {
  struct stat st;
  if (o < 0 || n <= 0) return EINVAL;
  if (fstat(fd, &st)) return errno;
  if (st.st_size >= o + n) return 0;
  return ftruncate(fd, o + n) ? errno : 0; }
