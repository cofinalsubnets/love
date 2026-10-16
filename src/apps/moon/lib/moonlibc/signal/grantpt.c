#include "../impl.h"

int grantpt(int fd) {
  if (__love_osv == 3) return (int) er(fb3(NR_fb_ioctl, fd, 0x20007447L, 0));   /* TIOCGRANTPT */
  return 0; }                    /* the others grant at open */
