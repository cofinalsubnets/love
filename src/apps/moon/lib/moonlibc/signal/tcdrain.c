#include "../impl.h"
#include <termios.h>

/* linux's TCSBRK/TCXONC/TCFLSH, and the BSDs' and xnu's shared tty ioctls */
static int __tio(int fd, unsigned long lx, unsigned long bsd, long a) {
  return __love_osv >= 2 ? (int) er(fb3(NR_fb_ioctl, fd, (long) bsd, a)) : ioctl(fd, lx, a); }
int tcdrain(int fd) { return __tio(fd, 0x5409, 0x2000745eUL, 1); }
int tcflush(int fd, int q) {
  if (q < TCIFLUSH || q > TCIOFLUSH) { __errno_v = EINVAL; return -1; }
  if (__love_osv < 2) return ioctl(fd, 0x540b, q);
  int w = q == TCIFLUSH ? 1 : q == TCOFLUSH ? 2 : 3;    /* FREAD, FWRITE */
  return (int) er(fb3(NR_fb_ioctl, fd, 0x80047410L, (long) &w)); }
int tcflow(int fd, int a) {
  if (a < TCOOFF || a > TCION) { __errno_v = EINVAL; return -1; }
  if (__love_osv < 2) return ioctl(fd, 0x540a, a);
  if (a == TCOOFF) return __tio(fd, 0, 0x2000746fUL, 0);
  if (a == TCOON) return __tio(fd, 0, 0x2000746eUL, 0);
  struct termios t;                                     /* the stop or start character, sent */
  if (tcgetattr(fd, &t) < 0) return -1;
  unsigned char c = t.c_cc[a == TCIOFF ? VSTOP : VSTART];
  return write(fd, &c, 1) == 1 ? 0 : -1; }
int tcsendbreak(int fd, int d) {
  if (__love_osv < 2) return ioctl(fd, 0x5409, 0);
  if (__tio(fd, 0, 0x2000747bUL, 0) < 0) return -1;    /* TIOCSBRK, a 0.4 s break, TIOCCBRK */
  struct timespec h = { 0, 400000000 };
  nanosleep(&h, 0);
  return __tio(fd, 0, 0x2000747aUL, 0); }
