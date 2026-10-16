#include "../impl.h"

/* on the BSDs the numbers, flags and record translate, and a shim hands the user's
 * handler, kept here by BSD number, the canonical signal */
static void (*__sighand[64])(int);
static unsigned char __sigsi[64];
/* the kernel passes three args; the siginfo, translated, goes only to an SA_SIGINFO handler */
static void __love_sigshim(int s, void *si, void *ctx) {
  void (*h)(int) = (s > 0 && s < 64) ? __sighand[s] : 0;
  if (!h) return;
  int can = (int) __love_sigcan(s);
  if (__sigsi[s] && si) {
    siginfo_t c;
    __love_sicanon(si, &c);
    ((void (*)(int, siginfo_t *, void *)) h)(can, &c, ctx); }
  else h(can); }

int sigaction(int sig, struct sigaction const *a, struct sigaction *old) {
  if (__love_osv == 2) {
    long fs = __love_sigfb(sig);
    if (fs <= 0) { __errno_v = EINVAL; return -1; }
    struct __fb_sigact ka, ko;
    memset(&ko, 0, sizeof ko);
    void (*prev)(int) = __sighand[fs];
    unsigned char prevsi = __sigsi[fs];
    if (a) {
      memset(&ka, 0, sizeof ka);
      void (*h)(int) = a->sa_handler;
      if (h == (void (*)(int)) 0 || h == (void (*)(int)) 1) {
        ka.h = (void *) h; __sighand[fs] = 0; __sigsi[fs] = 0; }
      else {
        ka.h = (void *) __love_sigshim; __sighand[fs] = h;
        __sigsi[fs] = (a->sa_flags & SA_SIGINFO) ? 1 : 0; }
      ka.flags = (int) __love_safb(a->sa_flags);
      ka.mask[0] = (unsigned int) __love_maskfb((unsigned long) a->sa_mask.__v[0]);
      ka.mask[1] = (unsigned int) (__love_maskfb((unsigned long) a->sa_mask.__v[0]) >> 32); }
    long r = sc3(NR_rt_sigaction, fs, a ? (long) &ka : 0, old ? (long) &ko : 0);
    if (r < 0) { if (a) __sighand[fs] = prev, __sigsi[fs] = prevsi;
                 __errno_v = (int) -r; return -1; }
    if (old) {
      memset(old, 0, sizeof *old);
      old->sa_handler = (ko.h == (void *) __love_sigshim) ? prev : (void (*)(int)) ko.h;
      old->sa_flags = (int) __love_sacan(ko.flags);
      old->sa_mask.__v[0] = (long) __love_maskcan((unsigned long) ko.mask[0]
                                                | ((unsigned long) ko.mask[1] << 32)); }
    return 0; }
#ifdef LvOsTranslate
  if (__love_osv == 3) {
#ifndef LvNbTramp
    /* no netbsd signal return path on this ISA */
    __errno_v = ENOSYS; return -1;
#else
    /* netbsd's record puts the mask before the flags, and the kernel has no return
     * path: __love_nb_sigtramp (version 2) is registered with each call */
    long fs = __love_sigfb(sig);
    if (fs <= 0) { __errno_v = EINVAL; return -1; }
    struct __nb_sigact ka, ko;
    memset(&ko, 0, sizeof ko);
    void (*prev)(int) = __sighand[fs];
    unsigned char prevsi = __sigsi[fs];
    if (a) {
      memset(&ka, 0, sizeof ka);
      void (*h)(int) = a->sa_handler;
      if (h == (void (*)(int)) 0 || h == (void (*)(int)) 1) {
        ka.h = (void *) h; __sighand[fs] = 0; __sigsi[fs] = 0; }
      else {
        ka.h = (void *) __love_sigshim; __sighand[fs] = h;
        __sigsi[fs] = (a->sa_flags & SA_SIGINFO) ? 1 : 0; }
      ka.flags = (int) __love_safb(a->sa_flags);
      ka.mask[0] = (unsigned int) __love_maskfb((unsigned long) a->sa_mask.__v[0]);
      ka.mask[1] = (unsigned int) (__love_maskfb((unsigned long) a->sa_mask.__v[0]) >> 32); }
    long r = __love_fb(NR_nb_sigaction_sigtramp, fs, a ? (long) &ka : 0, old ? (long) &ko : 0,
                     (long) __love_nb_sigtramp, 2, 0);
    if (r < 0) { if (a) __sighand[fs] = prev, __sigsi[fs] = prevsi;
                 __errno_v = (int) -r; return -1; }
    if (old) {
      memset(old, 0, sizeof *old);
      old->sa_handler = (ko.h == (void *) __love_sigshim) ? prev : (void (*)(int)) ko.h;
      old->sa_flags = (int) __love_sacan(ko.flags);
      old->sa_mask.__v[0] = (long) __love_maskcan((unsigned long) ko.mask[0]
                                                | ((unsigned long) ko.mask[1] << 32)); }
    return 0;
#endif
  }
#endif
  struct __ksigaction ka, ko;
  memset(&ko, 0, sizeof ko);
  if (a) {
    ka.h = (void *) a->sa_handler;
#if defined(__aarch64__) || defined(__riscv)
    ka.flags = (unsigned long) (unsigned int) a->sa_flags;
    ka.restorer = 0;
#else
    ka.flags = (unsigned long) (unsigned int) a->sa_flags | 67108864UL;   /* SA_RESTORER */
    ka.restorer = (void *) __love_sigret;
#endif
    ka.mask = a->sa_mask.__v[0]; }
  long r = sc4(NR_rt_sigaction, sig, a ? (long) &ka : 0, old ? (long) &ko : 0, 8);
  if (r < 0) { __errno_v = (int) -r; return -1; }
  if (old) {
    memset(old, 0, sizeof *old);
    old->sa_handler = (void (*)(int)) ko.h;
    old->sa_flags = (int) ko.flags;
    old->sa_mask.__v[0] = ko.mask; }
  return 0; }
