#include "../impl.h"

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
  if (ioctl(fd, LvTCGETS, t) < 0) return -1;
  unsigned int c = t->c_cflag & CBAUD, ci = (t->c_cflag & CIBAUD) >> 16;
  struct __lx_termios2 k;
  if ((c == BOTHER || ci == BOTHER) && !ioctl(fd, LvTCGETS2, &k)) {
    t->c_ispeed = k.c_ispeed, t->c_ospeed = k.c_ospeed;
    return 0; }
  t->c_ospeed = __love_bnum(c);
  t->c_ispeed = ci ? __love_bnum(ci) : t->c_ospeed;
  return 0; }
