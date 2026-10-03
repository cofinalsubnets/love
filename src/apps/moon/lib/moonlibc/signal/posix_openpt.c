#include "../impl.h"

/* ---- the pty quartet ---- */
int posix_openpt(int fl) {
  if (__love_osv == 2) return (int) er(fb1(NR_fb_posix_openpt, __love_ofb(fl)));   /* a real syscall there; no /dev/ptmx */
  return open("/dev/ptmx", fl, 0); }
