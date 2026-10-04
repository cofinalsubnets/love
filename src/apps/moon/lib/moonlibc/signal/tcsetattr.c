#include "../impl.h"

int tcsetattr(int fd, int act, struct termios const *t) {
  if (act < 0 || act > 2) { __errno_v = EINVAL; return -1; }
  if (__love_osv >= 2) {
    struct __fb_termios f, cur;
    __love_tiofb(t, &f);
    if (fb3(NR_fb_ioctl, fd, 0x402c7413L, (long) &cur) >= 0) __love_tiokeep(&f, &cur);   /* TIOCGETA */
    return (int) er(fb3(NR_fb_ioctl, fd, 0x802c7414L + act, (long) &f)); }   /* TIOCSETA/AW/AF */
  return ioctl(fd, (unsigned long) (21506 + act), t); }                      /* TCSETS/W/F */
