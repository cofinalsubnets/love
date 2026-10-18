#include <sys/event.h>
#include "../impl.h"

#ifdef LvMac
/* macos: freebsd's head in 32 bytes, no ext, repacked through a buffer like netbsd's */
static int __love_mackev(int kq, struct kevent const *ch, int nch,
                         struct kevent *ev, int nev, struct timespec const *ts) {
  struct __mac_kevent b[8];
  for (int at = 0; at < nch; at += 8) {
    int k = nch - at > 8 ? 8 : nch - at;
    for (int i = 0; i < k; i++) {
      struct kevent const *c = ch + at + i;
      long id = (long) c->ident;
      if (c->filter == EVFILT_SIGNAL && (id = __love_sigfb(id)) < 0) { __errno_v = EINVAL; return -1; }
      b[i].ident = (unsigned long) id; b[i].filter = c->filter;
      b[i].flags = c->flags; b[i].fflags = c->fflags;
      b[i].data = (long) c->data; b[i].udata = c->udata; }
    if (er(fb6(363, kq, (long) b, k, 0, 0, 0)) < 0) return -1; }
  if (nev <= 0) return 0;
  long got = er(fb6(363, kq, 0, 0, (long) b, nev > 8 ? 8 : nev, (long) ts));
  if (got < 0) return -1;
  for (long i = 0; i < got; i++) {
    long id = (long) b[i].ident;
    if (b[i].filter == EVFILT_SIGNAL) id = __love_sigcan(id);
    ev[i].ident = (unsigned long) id; ev[i].filter = b[i].filter;
    ev[i].flags = b[i].flags; ev[i].fflags = b[i].fflags;
    ev[i].data = b[i].data; ev[i].udata = b[i].udata;
    ev[i].ext[0] = ev[i].ext[1] = ev[i].ext[2] = ev[i].ext[3] = 0; }
  return (int) got; }
#endif

/* the record is freebsd's; netbsd repacks to __kevent50 with filter -f - 1. a signal
 * ident translates, and one with no BSD twin (STKFLT, PWR) is EINVAL */
int kevent(int kq, struct kevent const *ch, int nch,
           struct kevent *ev, int nev, struct timespec const *ts) {
  if (__love_osv < 2) { __errno_v = ENOSYS; return -1; }
#ifdef LvMac
  if (__love_osv == 4) return __love_mackev(kq, ch, nch, ev, nev, ts);
#endif
  int nb = __love_osv == 3;
  long nr = nb ? 435 : NR_fb_kevent;   /* __kevent50 */
  long tw = (long) ts;                 /* the timeout, in the kernel's own timespec */
#ifdef __i386__
  __fbts f32; __nbts n32;
  if (ts && nb) n32.tv_sec = ts->tv_sec, n32.tv_nsec = (long) ts->tv_nsec, tw = (long) &n32;
  else if (ts) {
    if (ts->tv_sec != (int) ts->tv_sec) { __errno_v = EOVERFLOW; return -1; }
    f32.tv_sec = (int) ts->tv_sec, f32.tv_nsec = (long) ts->tv_nsec, tw = (long) &f32; }
#endif
  /* changes first, 8 a call, then the wait */
  for (int at = 0; at < nch; at += 8) {
    struct kevent fc[8]; struct __nb_kevent nc[8];
    int k = nch - at > 8 ? 8 : nch - at;
    for (int i = 0; i < k; i++) {
      struct kevent const *c = ch + at + i;
      long id = (long) c->ident;
      if (c->filter == EVFILT_SIGNAL && (id = __love_sigfb(id)) < 0) {
        __errno_v = EINVAL; return -1; }
      if (nb) {
        memset(nc + i, 0, sizeof nc[i]);
        nc[i].ident = (unsigned long) id;
        nc[i].filter = (unsigned int) (-(long) c->filter - 1);
        nc[i].flags = c->flags; nc[i].fflags = c->fflags;
        nc[i].data = c->data; nc[i].udata = c->udata; }
      else fc[i] = *c, fc[i].ident = (unsigned long) id; }
    if (er(fb6(nr, kq, (long) (nb ? (void*) nc : (void*) fc), k, 0, 0, 0)) < 0)
      return -1; }
  if (nev <= 0) return 0;
  long got;
  if (!nb) {
    got = er(fb6(nr, kq, 0, 0, (long) ev, nev, tw));
    if (got < 0) return -1;
    for (long i = 0; i < got; i++)
      if (ev[i].filter == EVFILT_SIGNAL)
        ev[i].ident = (unsigned long) __love_sigcan((long) ev[i].ident); }
  else {
    /* up to 8 a call: a short answer is legal */
    struct __nb_kevent no[8];
    got = er(fb6(nr, kq, 0, 0, (long) no, nev > 8 ? 8 : nev, tw));
    if (got < 0) return -1;
    for (long i = 0; i < got; i++) {
      long f = -(long) no[i].filter - 1;
      long id = (long) no[i].ident;
      if (f == EVFILT_SIGNAL) id = __love_sigcan(id);
      ev[i].ident = (unsigned long) id; ev[i].filter = (short) f;
      ev[i].flags = (unsigned short) no[i].flags; ev[i].fflags = no[i].fflags;
      ev[i].data = no[i].data; ev[i].udata = no[i].udata;
      ev[i].ext[0] = ev[i].ext[1] = ev[i].ext[2] = ev[i].ext[3] = 0; } }
  return (int) got; }
