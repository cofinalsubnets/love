#include "../impl.h"

int killpg(int pg, int s) {
  if (pg < 0) { errno = EINVAL; return -1; }
  return kill(-pg, s); }
