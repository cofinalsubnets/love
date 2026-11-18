#include "../impl.h"

int remove(char const *p) {                        /* a directory falls to rmdir */
  int r = unlink(p);
  return r == 0 ? 0 : rmdir(p); }
