#include "../impl.h"

/* pthread_atfork's, 0 before, 1 in the parent, 2 in the child; 0 with none registered */
void (*__love_forkhook)(int);

static int __fork0(void) {
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
  return (int) er(sc5(NR_clone, SIGCHLD, 0, 0, 0, 0)); }   /* clone(SIGCHLD) */
int fork(void) {
  void (*h)(int) = __love_forkhook;
  if (h) h(0);
  int r = __fork0(), e = errno;
  if (h) h(r == 0 ? 2 : 1), errno = e;
  return r; }
/* a full fork: the child's own copy is what vfork may give */
int vfork(void) { return fork(); }
