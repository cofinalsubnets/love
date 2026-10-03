#include "../impl.h"

/* printf to a file descriptor: formatted whole, then written whole */
int vdprintf(int fd, char const *fmt, va_list ap) {
  char *b;
  int n = vasprintf(&b, fmt, ap);
  if (n < 0) return -1;
  for (int at = 0; at < n; ) {
    long k = write(fd, b + at, n - at);
    if (k < 0) { if (__errno_v == EINTR) continue; free(b); return -1; }
    at += (int) k; }
  free(b);
  return n; }
int dprintf(int fd, char const *fmt, ...) {
  va_list ap; va_start(ap, fmt);
  int n = vdprintf(fd, fmt, ap);
  va_end(ap);
  return n; }
