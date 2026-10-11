#include "../impl.h"

int usleep(unsigned int us) {
  struct timespec ts = {0};
  ts.tv_sec = us / 1000000;
  ts.tv_nsec = (long) (us % 1000000) * 1000;
  return nanosleep(&ts, 0); }
