#include "../impl.h"

int sigprocmask(int how, sigset_t const *s, sigset_t *o) {
  if (__love_osv >= 2) {
    /* the BSDs: a 16-byte set, how is ours + 1, and the bits translate */
    unsigned long ks[2] = {0, 0}, ko[2] = {0, 0};
    if (s) ks[0] = __love_maskfb((unsigned long) s->__v[0]);
    long r = sc3(NR_rt_sigprocmask, how + 1, s ? (long) ks : 0, o ? (long) ko : 0);
    if (r < 0) { __errno_v = (int) -r; return -1; }
    if (o) { memset(o, 0, sizeof *o); o->__v[0] = (long) __love_maskcan(ko[0]); }
    return 0; }
  unsigned long long ks = s ? s->__v[0] : 0, ko = 0;
  long r = sc4(NR_rt_sigprocmask, how, s ? (long) &ks : 0, o ? (long) &ko : 0, 8);
  if (r < 0) { __errno_v = (int) -r; return -1; }
  if (o) { memset(o, 0, sizeof *o); o->__v[0] = ko; }
  return 0; }
