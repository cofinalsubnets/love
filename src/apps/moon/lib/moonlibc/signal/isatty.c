#include "../impl.h"

/* freebsd's termios is 44 bytes */
int isatty(int fd) {
  if (__love_osv >= 2) {
    char t[44];
    return fb3(NR_fb_ioctl, fd, 0x402c7413L, (long) t) == 0; }   /* TIOCGETA */
  struct termios t;
  return sc3(NR_ioctl, fd, 21505, (long) &t) == 0; }             /* TCGETS */
