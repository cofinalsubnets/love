#include "../impl.h"
int fork(void) {
#ifdef __ARM_EABI__
  if (__love_osv == 2) {                   /* from arm state: mksys says why */
    long r = __love_fbfork();
    return (int) er(__love_parked(r) ? -__love_errfb(-r - 4096) : r); }
#endif
#ifdef LvMac
  if (__love_osv == 4) {                   /* libSystem's, or the leaf says the child's 0 */
    long r = __love_door(2, 0, 0, 0, 0, 0, 0);
    if (r == LvNoDoor) r = __love_macfork();
    return (int) er(__love_parked(r) ? -__love_errfb(-r - 4096) : r); }
#endif
  if (__love_osv >= 2) return (int) er(fb1(NR_fb_fork, 0));
  return (int) er(sc5(NR_clone, 17, 0, 0, 0, 0)); }   /* clone(SIGCHLD) */
