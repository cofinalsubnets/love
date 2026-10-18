#include "../impl.h"

int posix_openpt(int fl) {
  if (__love_osv == 2) return (int) er(fb1(NR_fb_posix_openpt, __love_ofb(fl)));   /* freebsd has no /dev/ptmx */
  return open("/dev/ptmx", fl, 0); }
