#include "../impl.h"
#include <pthread.h>

/* a thread's record, laid at the top of its own stack. on linux the kernel writes tid at the
 * clone (CLONE_PARENT_SETTID) and clears it, waking the futex, once the thread is gone
 * (CLONE_CHILD_CLEARTID): that is all a join waits for, and only then is the stack unmapped.
 * freebsd's thr_exit sets gone and wakes it instead; netbsd's _lwp_wait waits on tid itself */
struct __pthread { void *(*fn)(void *); void *arg; void *ret; void *map; unsigned long len; volatile int tid;
                   volatile long gone; void *tsd[128]; };
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
#if defined(__x86_64__)
  void *tp = 0;
  if (__love_osv == 2) fb2(165, 128, (long) &tp);             /* sysarch(AMD64_GET_FSBASE) */
  else if (__love_osv == 3) tp = (void *) fb1(316, 0);        /* _lwp_getprivate */
  else sc2(NR_arch_prctl, 0x1003, (long) &tp);                /* ARCH_GET_FS */
#else
  void *tp = __love_tp();
#endif
  return tp ? (pthread_t) tp : PtMain; }

int pthread_equal(pthread_t a, pthread_t b) { return a == b; }
int pthread_attr_init(pthread_attr_t *a) { a->__unused = 0; return 0; }
int pthread_attr_destroy(pthread_attr_t *a) { return 0; }

/* a thread's value slots: the first thread's sit in __love_mt, every other's in its record */
void **__pt_tsd(void) {
  pthread_t t = pthread_self();
  return t == PtMain ? __love_mt.tsd : ((struct __pthread *) t)->tsd; }

void pthread_exit(void *v) {
  pthread_t t = pthread_self();
  if (t != PtMain) ((struct __pthread *) t)->ret = v;
  void **tsd = __pt_tsd();
  for (int r = 0, more = 1; more && r < PTHREAD_DESTRUCTOR_ITERATIONS; r++) {   /* a destructor may set values again */
    more = 0;
    for (int k = 0; k < PTHREAD_KEYS_MAX; k++)
      if (tsd[k] && __love_mt.key[k] && __love_mt.dtor[k]) { void *x = tsd[k]; tsd[k] = 0; __love_mt.dtor[k](x); more = 1; } }
#ifdef LvBsdThreads
  if (__love_osv == 2)                      /* thr_exit: gone set and woken for the join */
    for (;;) fb1(431, t == PtMain ? 0 : (long) &((struct __pthread *) t)->gone);
  if (__love_osv == 3) for (;;) fb1(310, 0);   /* _lwp_exit */
#endif
  for (;;) sc1(NR_exit, 0); }               /* this thread alone; the last one out ends the process */

/* where clone's child lands: sys.o calls it on the new stack, and it never returns */
static void __pt_start(struct __pthread *d) { pthread_exit(d->fn(d->arg)); }

#ifdef LvBsdThreads
/* the BSD's own start: d's record at the top of m, the stack from just under it */
static long __pt_bsd(struct __pthread *d, void **sp) {
  if (__love_osv == 2) {
    long kt = 0;
    struct __fb_thrp p;
    memset(&p, 0, sizeof p);
    p.fn = (void (*)(void *)) __pt_start, p.arg = d;
    p.sb = d->map, p.ss = (unsigned long) ((char *) sp - (char *) d->map);
#ifdef __riscv
    p.tb = (char *) d - 16;                     /* riscv's kernel lays tp 16 past the base (TP_OFFSET) */
#else
    p.tb = (char *) d;
#endif
    p.ctid = p.ptid = &kt;
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
  *(unsigned long *) (uc + 264) = (unsigned long) d;
# else
  gr[NbSp] = (unsigned long) sp, gr[NbRa] = 0, gr[NbTls] = (unsigned long) d;
# endif
  *(unsigned *) uc |= 0x80004;                  /* _UC_TLSBASE | _UC_CPU */
  return fb3(309, (long) uc, 0, (long) &d->tid); }   /* _lwp_create, joinable */
#endif

int pthread_create(pthread_t *t, pthread_attr_t const *at, void *(*fn)(void *), void *arg) {
#ifdef LvBsdThreads
  if (__love_osv >= 4) return EAGAIN;           /* macos: bsdthread_create is not spoken here */
#else
  if (__love_osv >= 2) return EAGAIN;           /* the BSDs' threads are the 64-bit ISAs' */
#endif
  void *m = mmap(0, (long) PtStack, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (m == (void *) -1) return EAGAIN;
  mprotect(m, 4096, PROT_NONE);               /* a guard page under the stack */
  struct __pthread *d = (struct __pthread *) (((unsigned long) m + PtStack - sizeof *d) & ~15UL);
  d->fn = fn; d->arg = arg; d->ret = 0; d->map = m; d->len = PtStack; d->tid = 0; d->gone = 0;
  memset(d->tsd, 0, sizeof d->tsd);
  void **sp = (void **) (((unsigned long) d - 16) & ~15UL);
  sp[0] = (void *) __pt_start; sp[1] = d;     /* the leaf calls sp[0](sp[1]) */
#ifdef __i386__
  /* i386's thread pointer is a segment: one GDT entry, asked for once, based per thread at
   * sp[1] -- the word holding d, so gs:0 reads the record. the leaf loads gs from sp[2] */
  struct { unsigned entry, base, limit, flags; } u = { ~0u, 0, 0xfffff, 0x51 };   /* 32-bit, 4K pages, usable */
  if (!__love_mt.tls) {
    if (sc1(NR_set_thread_area, (long) &u) < 0) { munmap(m, (long) PtStack); return EAGAIN; }
    __love_mt.tls = (int) u.entry; }
  u.entry = (unsigned) __love_mt.tls; u.base = (unsigned) &sp[1];
  sp[2] = (void *) (long) (__love_mt.tls * 8 + 3);
  void *tls = &u;
#else
  void *tls = d;
#endif
  __love_mt.threads = 1;                        /* before the child can reach malloc */
#ifdef LvBsdThreads
  long r = __love_osv >= 2 ? __pt_bsd(d, (void **) (((unsigned long) d - 16) & ~15UL))
                           : __love_clone(PtFlags, sp, (int *) &d->tid, (int *) &d->tid, tls);
#else
  long r = __love_clone(PtFlags, sp, (int *) &d->tid, (int *) &d->tid, tls);
#endif
  if (r < 0) { munmap(m, (long) PtStack); return EAGAIN; }
  *t = (pthread_t) d;
  return 0; }

int pthread_join(pthread_t t, void **ret) {
  if (t == PtMain || t == pthread_self()) return EDEADLK;
  struct __pthread *d = (struct __pthread *) t;
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
