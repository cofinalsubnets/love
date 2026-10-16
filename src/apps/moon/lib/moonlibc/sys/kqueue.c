#include <sys/event.h>
#include "../impl.h"

/* the BSDs only */
int kqueue(void) {
  if (__love_osv < 2) { __errno_v = ENOSYS; return -1; }
  return (int) er(fb1(__love_osv == 3 ? 344 : NR_fb_kqueue, 0)); }
