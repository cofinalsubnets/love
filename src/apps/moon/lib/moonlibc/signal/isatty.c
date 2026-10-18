#include "../impl.h"

/* freebsd's termios is 44 bytes, macos's 72; 0 means a tty answered */
int isatty(int fd) {
  if (__love_osv >= 2) {
    char t[72];
    return fb3(NR_fb_ioctl, fd, __love_osv == 4 ? 0x40487413L : 0x402c7413L, (long) t) == 0; }   /* TIOCGETA */
  struct termios t;
  return sc3(NR_ioctl, fd, 21505, (long) &t) == 0; }             /* TCGETS */
