#include "../impl.h"

/* the limits every filesystem here shares; a name it has none for is -1, errno kept */
long fpathconf(int fd, int n) {
  switch (n) {
  case _PC_LINK_MAX: return 127;
  case _PC_MAX_CANON: case _PC_MAX_INPUT: return 255;
  case _PC_NAME_MAX: return NAME_MAX;
  case _PC_PATH_MAX: return PATH_MAX;
  case _PC_PIPE_BUF: return 4096;
  case _PC_CHOWN_RESTRICTED: case _PC_NO_TRUNC: return 1;
  case _PC_VDISABLE: return 0; }
  errno = EINVAL;
  return -1; }
long pathconf(char const *p, int n) { return fpathconf(-1, n); }
