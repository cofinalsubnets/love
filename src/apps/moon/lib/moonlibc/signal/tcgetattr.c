#include "../impl.h"

/* ---- the terminal ---- */
int tcgetattr(int fd, struct termios *t) {
#ifdef LvMac
  if (__love_osv == 4) {                   /* freebsd's bits, in long-wide words */
    struct __mac_termios m;
    struct __fb_termios f;
    long r = er(fb3(NR_fb_ioctl, fd, 0x40487413L, (long) &m));   /* TIOCGETA */
    if (r >= 0) __love_tiounmac(&m, &f), __love_tiocan(&f, t);
    return (int) r; }
#endif
  if (__love_osv >= 2) {
    struct __fb_termios f;
    long r = er(fb3(NR_fb_ioctl, fd, 0x402c7413L, (long) &f));   /* TIOCGETA */
    if (r >= 0) __love_tiocan(&f, t);
    return (int) r; }
  return ioctl(fd, 21505, t); }                                  /* TCGETS */
