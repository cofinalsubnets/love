#include <sys/event.h>
#include "../impl.h"

/* the BSD door; a linux kernel has no such fd (signalfd is the twin there,
 * and posix.c's sigfd holds both). callers guard on the OS. */
int kqueue(void) {
  if (__love_osv < 2) { __errno_v = ENOSYS; return -1; }
  return (int) er(fb1(__love_osv == 3 ? 344 : NR_fb_kqueue, 0)); }
