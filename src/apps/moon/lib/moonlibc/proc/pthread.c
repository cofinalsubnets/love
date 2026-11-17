#include "../impl.h"
#include <pthread.h>
#include <sched.h>

/* a thread's record, at the top of its own stack and its thread pointer: self first, as %fs:0
 * reads it, a program's tls template copied just under it. a64's template lies above the
 * thread pointer, so there tp is a control block under the record, its first word the record.
 * linux clears tid and wakes its futex when the thread is gone, which is all a join waits
 * for; freebsd's thr_exit sets gone instead, and netbsd's _lwp_wait waits on tid */
struct __pthread { void *self; void *(*fn)(void *); void *arg; void *ret; void *map; unsigned long len; volatile int tid;
                   volatile long gone; int err, herr; volatile int detached, done; long ktid;
                   struct __pthread *rnext; char name[16]; void *tsd[128]; };
#define PtStack (8UL << 20)
#define PtFlags 0x3d0f00L   /* VM FS FILES SIGHAND THREAD SYSVSEM SETTLS PARENT_SETTID CHILD_CLEARTID */
#define PtMain ((pthread_t) 1)  /* the first thread: no record, and no record sits at 1 */

/* the BSDs' threads, on the 64-bit ISAs. freebsd's thr_new calls the start on the new stack
 * with the tls base set; netbsd's _lwp_create takes a ucontext, its own getcontext's with the
 * pc, sp, first argument and tls base laid in -- its general registers' places per ISA */
#if defined(LvOsTranslate) && !defined(__ILP32__)
# define LvBsdThreads 1
struct __fb_thrp { void (*fn)(void *); void *arg; char *sb; unsigned long ss; char *tb; unsigned long ts;
                   long *ctid, *ptid; int flags; void *rtp, *spare[3]; };
_Static_assert(sizeof(struct __fb_thrp) == 104, "freebsd's thr_param is 104 bytes");
# if defined(__x86_64__)
enum { NbUc = 784, NbGr = 56, NbPc = 21, NbSp = 24, NbArg = 0, NbTls = -1, NbRa = -1 };   /* tls apart, at 264 */
# elif defined(__aarch64__)
enum { NbUc = 944, NbGr = 64, NbPc = 32, NbSp = 31, NbArg = 0, NbTls = 34, NbRa = 30 };
# else
enum { NbUc = 632, NbGr = 56, NbPc = 31, NbSp = 1, NbArg = 9, NbTls = 3, NbRa = 0 };
# endif
#endif

pthread_t pthread_self(void) {
  if (!__love_mt.threads) return PtMain;
  void *tp = __love_tp();                       /* x64's first thread has a base by now */
  if (!tp || tp == __love_mt.mtp) return PtMain;
#if defined(__aarch64__)
  if (__love_mt.tlsimg) tp = *(void **) tp;
#endif
  return (pthread_t) tp; }

int pthread_equal(pthread_t a, pthread_t b) { return a == b; }

/* errno.c's hook once a thread starts: the calling thread's errno (0) or h_errno (1) */
static int *__pt_errat(int w) {
  pthread_t t = pthread_self();
  if (t == PtMain) return w ? &__h_errno_v : &__errno_v;
  struct __pthread *d = (struct __pthread *) t;
  return w ? &d->herr : &d->err; }
int pthread_attr_init(pthread_attr_t *a) { a->__detach = 0, a->__stack = 0; return 0; }
int pthread_attr_destroy(pthread_attr_t *a) { return 0; }
int pthread_attr_setstacksize(pthread_attr_t *a, size_t n) {
  if (n < PTHREAD_STACK_MIN) return EINVAL;
  a->__stack = n;
  return 0; }
int pthread_attr_getstacksize(pthread_attr_t const *a, size_t *n) { *n = a->__stack ? a->__stack : PtStack; return 0; }
int pthread_attr_setdetachstate(pthread_attr_t *a, int s) {
  if (s != PTHREAD_CREATE_JOINABLE && s != PTHREAD_CREATE_DETACHED) return EINVAL;
  a->__detach = s;
  return 0; }
int pthread_attr_getdetachstate(pthread_attr_t const *a, int *s) { *s = a->__detach; return 0; }

/* a joinable thread made detached: its stack goes to the reaper; the first thread's never goes */
int pthread_detach(pthread_t t) {
  if (t == PtMain) return 0;
  struct __pthread *d = (struct __pthread *) t;
  if (d->detached) return EINVAL;
  d->detached = 1;
  __pt_reapadd(d);
  __pt_reap();
  return 0; }

void **__pt_tsd(void) {
  pthread_t t = pthread_self();
  return t == PtMain ? __love_mt.tsd : ((struct __pthread *) t)->tsd; }

void pthread_exit(void *v) {
  pthread_t t = pthread_self();
  if (t != PtMain) ((struct __pthread *) t)->ret = v;
  void **tsd = __pt_tsd();
  for (int r = 0, more = 1; more && r < PTHREAD_DESTRUCTOR_ITERATIONS; r++) {
    more = 0;
    for (int k = 0; k < PTHREAD_KEYS_MAX; k++)
      if (tsd[k] && __love_mt.key[k] && __love_mt.dtor[k]) { void *x = tsd[k]; tsd[k] = 0; __love_mt.dtor[k](x); more = 1; } }
  if (t != PtMain) ((struct __pthread *) t)->done = 1;   /* netbsd's reaper waits from here */
#ifdef LvBsdThreads
  if (__love_osv == 2)                      /* thr_exit: gone set and woken for the join */
    for (;;) fb1(431, t == PtMain ? 0 : (long) &((struct __pthread *) t)->gone);
  if (__love_osv == 3) for (;;) fb1(310, 0);   /* _lwp_exit */
#endif
  for (;;) sc1(NR_exit, 0); }               /* this thread alone */

/* clone's child lands here on its new stack */
static void __pt_start(struct __pthread *d) { pthread_exit(d->fn(d->arg)); }

/* a detached thread's stack goes once the thread is wholly off it: linux clears tid in the
 * kernel, freebsd's thr_exit sets gone, netbsd's _lwp_wait answers after done */
static void __pt_rtake(void) { while (__sync_lock_test_and_set(&__love_mt.rlock, 1)) sched_yield(); }
static void __pt_rgive(void) { __sync_lock_release(&__love_mt.rlock); }
static int __pt_off(struct __pthread *d) {
#ifdef LvBsdThreads
  if (__love_osv == 2) return d->gone != 0;
  if (__love_osv == 3) {
    if (!d->done) return 0;
    fb2(312, d->tid, 0);                        /* _lwp_wait: off its stack now */
    return 1; }
#endif
  return d->tid == 0; }
static void __pt_reap(void) {
  __pt_rtake();
  struct __pthread **pp = (struct __pthread **) &__love_mt.reap;
  while (*pp) {
    struct __pthread *d = *pp;
    if (__pt_off(d)) { *pp = d->rnext; munmap(d->map, (long) d->len); }
    else pp = &d->rnext; }
  __pt_rgive(); }
static void __pt_reapadd(struct __pthread *d) {
  __pt_rtake();
  d->rnext = __love_mt.reap, __love_mt.reap = d;
  __pt_rgive(); }

#ifdef LvBsdThreads
/* the BSD's own start: d's record at the top of m, the stack from just under it */
static long __pt_bsd(struct __pthread *d, void **sp, void *tp) {
  if (__love_osv == 2) {
    long kt = 0;
    struct __fb_thrp p;
    memset(&p, 0, sizeof p);
    p.fn = (void (*)(void *)) __pt_start, p.arg = d;
    p.sb = d->map, p.ss = (unsigned long) ((char *) sp - (char *) d->map);
#ifdef __riscv
    p.tb = (char *) tp - 16;                    /* riscv's kernel lays tp 16 past the base (TP_OFFSET) */
#else
    p.tb = (char *) tp;
#endif
    p.ctid = &kt, p.ptid = &d->ktid;            /* the parent's copy: thr_kill's id before the child runs */
    return fb2(455, (long) &p, sizeof p); }     /* thr_new */
  unsigned long ucw[NbUc / 8];
  unsigned char *uc = (unsigned char *) ucw;
  memset(ucw, 0, sizeof ucw);
  long r = fb1(307, (long) uc);                 /* getcontext: a valid cpu state to start from */
  if (r < 0) return r;
  unsigned long *gr = (unsigned long *) (uc + NbGr);
  gr[NbPc] = (unsigned long) __pt_start, gr[NbArg] = (unsigned long) d;
# if defined(__x86_64__)
  gr[NbSp] = (unsigned long) sp - 8;            /* as a call leaves it: the return slot below 16 */
  *(unsigned long *) (uc + 264) = (unsigned long) tp;
# else
  gr[NbSp] = (unsigned long) sp, gr[NbRa] = 0, gr[NbTls] = (unsigned long) tp;
# endif
  *(unsigned *) uc |= 0x80004;                  /* _UC_TLSBASE | _UC_CPU */
  return fb3(309, (long) uc, 0, (long) &d->tid); }   /* _lwp_create, joinable */
#endif

int pthread_create(pthread_t *t, pthread_attr_t const *at, void *(*fn)(void *), void *arg) {
#ifdef LvBsdThreads
  if (__love_osv >= 4) return EAGAIN;           /* macos: bsdthread_create is not spoken here */
#else
  if (__love_osv >= 2) return EAGAIN;           /* BSD threads only on the 64-bit ISAs */
#endif
  __pt_reap();
  unsigned long ss = at && at->__stack ? (at->__stack + 4095) & ~4095UL : PtStack;
  void *m = mmap(0, (long) ss, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (m == (void *) -1) return EAGAIN;
  mprotect(m, 4096, PROT_NONE);               /* a guard page under the stack */
  unsigned long al = __love_mt.tlsalign > 16 ? __love_mt.tlsalign : 16;
  struct __pthread *d = (struct __pthread *) (((unsigned long) m + ss - sizeof *d) & ~(al - 1));
  char *low = (char *) d;
  void *tls = d;
  d->self = d;
#if defined(__aarch64__)
  if (__love_mt.tlsimg) {
    low = (char *) (((unsigned long) d - __love_mt.tlsoff - __love_mt.tlsblk) & ~(al - 1));
    tls = low, __love_tlscopy(low), *(void **) low = d; }
#else
  if (__love_mt.tlsimg) __love_tlscopy(d), low -= __love_mt.tlsblk;
#endif
  d->fn = fn; d->arg = arg; d->ret = 0; d->map = m; d->len = ss; d->tid = 0; d->gone = 0;
  d->err = d->herr = 0, d->detached = at && at->__detach, d->done = 0, d->ktid = 0, d->name[0] = 0;
  memset(d->tsd, 0, sizeof d->tsd);
  void **sp = (void **) (((unsigned long) low - 16) & ~15UL);
  sp[0] = (void *) __pt_start; sp[1] = d;     /* the leaf calls sp[0](sp[1]) */
#ifdef __i386__
  /* i386's thread pointer is a gdt segment based at sp[1], so gs:0 reads d; the leaf
   * loads gs from sp[2] */
  struct { unsigned entry, base, limit, flags; } u = { ~0u, 0, 0xfffff, 0x51 };   /* 32-bit, 4K pages, usable */
  if (!__love_mt.tls) {
    if (sc1(NR_set_thread_area, (long) &u) < 0) { munmap(m, (long) ss); return EAGAIN; }
    __love_mt.tls = (int) u.entry; }
  u.entry = (unsigned) __love_mt.tls; u.base = (unsigned) &sp[1];
  sp[2] = (void *) (long) (__love_mt.tls * 8 + 3);
  tls = &u;
#endif
#if defined(__x86_64__)
  /* fs:0 must read a self in every thread before the first one starts: the first
   * thread with no tls template takes a one-word record */
  if (!__love_mt.mtp) {
    void *tp = __love_mt.mself = &__love_mt.mself;
    if (__love_osv == 2) fb2(165, 129, (long) &tp);           /* sysarch(AMD64_SET_FSBASE) */
    else if (__love_osv == 3) fb1(317, (long) tp);            /* _lwp_setprivate */
    else sc2(NR_arch_prctl, 0x1002, (long) tp);               /* ARCH_SET_FS */
    __love_mt.mtp = tp; }
#endif
#ifdef LvBsdThreads
  if (__love_osv == 2 && !__love_mt.mktid) fb1(432, (long) &__love_mt.mktid);   /* the first thread's id, while it is the caller */
#endif
  __love_errat = __pt_errat;
  __love_mt.threads = 1;                        /* before the child can reach malloc */
#ifdef LvBsdThreads
  long r = __love_osv >= 2 ? __pt_bsd(d, (void **) (((unsigned long) low - 16) & ~15UL), tls)
                           : __love_clone(PtFlags, sp, (int *) &d->tid, (int *) &d->tid, tls);
#else
  long r = __love_clone(PtFlags, sp, (int *) &d->tid, (int *) &d->tid, tls);
#endif
  if (r < 0) { munmap(m, (long) ss); return EAGAIN; }
  *t = (pthread_t) d;
  if (d->detached) __pt_reapadd(d);
  return 0; }

int pthread_join(pthread_t t, void **ret) {
  if (t == PtMain || t == pthread_self()) return EDEADLK;
  struct __pthread *d = (struct __pthread *) t;
  if (d->detached) return EINVAL;
#ifdef LvBsdThreads
  if (__love_osv == 2)                          /* _umtx_op WAIT on the long thr_exit sets */
    while (!d->gone) fb6(454, (long) &d->gone, 2, 0, 0, 0, 0);
  else if (__love_osv == 3)                     /* _lwp_wait: until the lwp is gone */
    while (fb2(312, d->tid, 0) == -EINTR) ;
  else
#endif
  for (int tid; (tid = d->tid) != 0; )
    sc4(NR_futex, (long) &d->tid, 0, tid, 0);   /* FUTEX_WAIT while it still reads tid */
  if (ret) *ret = d->ret;
  munmap(d->map, (long) d->len);
  return 0; }

/* a signal at one thread: linux's tgkill by its clone tid, freebsd's thr_kill, netbsd's
 * _lwp_kill (the first thread is lwp 1) */
int pthread_kill(pthread_t t, int s) {
  if (s < 0 || s > 64) return EINVAL;
  struct __pthread *d = t == PtMain ? 0 : (struct __pthread *) t;
  long r;
#ifdef LvBsdThreads
  if (__love_osv == 2) r = fb2(433, d ? d->ktid : __love_mt.mktid, __love_sigfb(s));
  else if (__love_osv == 3) r = fb2(318, d ? d->tid : 1, __love_sigfb(s));
  else
#endif
  {
    int tid = d ? d->tid : getpid();
    if (!tid) return ESRCH;
    r = sc3(NR_tgkill, getpid(), tid, s); }
  return r < 0 ? (int) -r : 0; }

/* a thread's name, 15 bytes and a nul: linux's prctl for the caller, else its comm file;
 * freebsd's thr_set_name and netbsd's _lwp_setname, the record keeping a copy to read */
int pthread_setname_np(pthread_t t, char const *nm) {
  size_t n = strlen(nm);
  if (n > 15) return ERANGE;
  struct __pthread *d = t == PtMain ? 0 : (struct __pthread *) t;
  if (d) memcpy(d->name, nm, n + 1);
  long r = 0;
#ifdef LvBsdThreads
  if (__love_osv == 2) r = fb2(464, d ? d->ktid : __love_mt.mktid, (long) nm);
  else if (__love_osv == 3) r = fb2(323, d ? d->tid : 1, (long) nm);
  else
#endif
  if (t == pthread_self()) r = sc2(NR_prctl, 15, (long) nm);   /* PR_SET_NAME */
  else {
    char p[64];
    snprintf(p, sizeof p, "/proc/self/task/%d/comm", d ? d->tid : getpid());
    int fd = open(p, O_WRONLY | O_CLOEXEC);
    if (fd < 0) return errno;
    r = write(fd, nm, n) < 0 ? -errno : 0;
    close(fd); }
  return r < 0 ? (int) -r : 0; }
int pthread_getname_np(pthread_t t, char *b, size_t n) {
  if (n < 16) return ERANGE;
  struct __pthread *d = t == PtMain ? 0 : (struct __pthread *) t;
#ifdef LvBsdThreads
  if (__love_osv == 3) { long r = fb3(324, d ? d->tid : 1, (long) b, (long) n); return r < 0 ? (int) -r : 0; }
  if (__love_osv == 2) { strcpy(b, d ? d->name : ""); return 0; }
#endif
  if (t == pthread_self()) { long r = sc2(NR_prctl, 16, (long) b); return r < 0 ? (int) -r : 0; }   /* PR_GET_NAME */
  char p[64];
  snprintf(p, sizeof p, "/proc/self/task/%d/comm", d ? d->tid : getpid());
  int fd = open(p, O_RDONLY | O_CLOEXEC);
  if (fd < 0) return errno;
  long k = read(fd, b, n - 1);
  close(fd);
  if (k < 0) return errno;
  while (k > 0 && b[k - 1] == '\n') k--;
  b[k] = 0;
  return 0; }
