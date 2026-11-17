#include "../impl.h"

/* the pty's slave path into b: 0, ENOTTY off a pty, ERANGE short */
int ptsname_r(int fd, char *b, size_t n) {
  char k[1024];
  int l;
  if (__love_osv == 3) {
    struct { int cfd, sfd; char cn[1024], sn[1024]; } g;      /* ptmget */
    if (fb3(NR_fb_ioctl, fd, 0x48087448L, (long) &g) < 0) return ENOTTY;   /* TIOCPTSNAME */
    l = snprintf(k, sizeof k, "%s", g.sn); }
  else if (__love_osv == 4) {
    char m[128];
    if (fb3(NR_fb_ioctl, fd, 0x40807453L, (long) m) < 0) return ENOTTY;   /* TIOCPTYGNAME: the whole path */
    l = snprintf(k, sizeof k, "%s", m); }
  else if (__love_osv == 2) {
    struct { int len; void *buf; } a = { (int) sizeof k - 5, k + 5 };
    if (fb3(NR_fb_ioctl, fd, (long) (0x80006678UL | sizeof a << 16), (long) &a) < 0) return ENOTTY;   /* FIODGNAME, sized by the struct */
    memcpy(k, "/dev/", 5), l = (int) strlen(k); }               /* the kernel answers "pts/N" */
  else {
    int p = 0;
    if (ioctl(fd, 2147767344UL, &p) < 0) return ENOTTY;      /* TIOCGPTN */
    l = snprintf(k, sizeof k, "/dev/pts/%d", p); }
  if ((size_t) l >= n) return ERANGE;
  memcpy(b, k, (size_t) l + 1);
  return 0; }
/* ..and into libc's own */
char *ptsname(int fd) {
  static char nb[64];
  int e = ptsname_r(fd, nb, sizeof nb);
  return e ? (__errno_v = e, (char *) 0) : nb; }
