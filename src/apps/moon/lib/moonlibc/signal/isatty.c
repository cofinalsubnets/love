#include "../impl.h"

/* the probe wants only the verdict, so it asks the kernel straight and keeps
 * struct termios out of it: freebsd's TIOCGETA reads 44 bytes, macos's 72 (its
 * flag words are longs), linux's TCGETS its own -- 0 means a tty answered. */
int isatty(int fd) {
  if (__love_osv >= 2) {
    char t[72];
    return fb3(NR_fb_ioctl, fd, __love_osv == 4 ? 0x40487413L : 0x402c7413L, (long) t) == 0; }   /* TIOCGETA */
  struct termios t;
  return sc3(NR_ioctl, fd, 21505, (long) &t) == 0; }             /* TCGETS */
