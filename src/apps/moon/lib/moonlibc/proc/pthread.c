#include "../impl.h"
#include <pthread.h>

/* a thread's record, at the top of its own stack. the kernel clears tid and wakes its
 * futex when the thread is gone, which is all a join waits for */
struct __pthread { void *(*fn)(void *); void *arg; void *ret; void *map; unsigned long len; volatile int tid; void *tsd[128]; };
#define PtStack (8UL << 20)
#define PtFlags 0x3d0f00L   /* VM FS FILES SIGHAND THREAD SYSVSEM SETTLS PARENT_SETTID CHILD_CLEARTID */
#define PtMain ((pthread_t) 1)  /* the first thread: no record, and no record sits at 1 */

pthread_t pthread_self(void) {
  if (!__love_mt.threads) return PtMain;
#if defined(__x86_64__)
  void *tp = 0;
  sc2(NR_arch_prctl, 0x1003, (long) &tp);   /* ARCH_GET_FS */
#else
  void *tp = __love_tp();
#endif
  return tp ? (pthread_t) tp : PtMain; }

int pthread_equal(pthread_t a, pthread_t b) { return a == b; }
int pthread_attr_init(pthread_attr_t *a) { a->__unused = 0; return 0; }
int pthread_attr_destroy(pthread_attr_t *a) { return 0; }

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
  for (;;) sc1(NR_exit, 0); }               /* this thread alone */

/* clone's child lands here on its new stack */
static void __pt_start(struct __pthread *d) { pthread_exit(d->fn(d->arg)); }

int pthread_create(pthread_t *t, pthread_attr_t const *at, void *(*fn)(void *), void *arg) {
  if (__love_osv >= 2) return EAGAIN;           /* no BSD threads */
  void *m = mmap(0, (long) PtStack, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (m == (void *) -1) return EAGAIN;
  mprotect(m, 4096, PROT_NONE);               /* a guard page under the stack */
  struct __pthread *d = (struct __pthread *) (((unsigned long) m + PtStack - sizeof *d) & ~15UL);
  d->fn = fn; d->arg = arg; d->ret = 0; d->map = m; d->len = PtStack; d->tid = 0;
  memset(d->tsd, 0, sizeof d->tsd);
  void **sp = (void **) (((unsigned long) d - 16) & ~15UL);
  sp[0] = (void *) __pt_start; sp[1] = d;     /* the leaf calls sp[0](sp[1]) */
#ifdef __i386__
  /* i386's thread pointer is a gdt segment based at sp[1], so gs:0 reads d; the leaf
   * loads gs from sp[2] */
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
  long r = __love_clone(PtFlags, sp, (int *) &d->tid, (int *) &d->tid, tls);
  if (r < 0) { munmap(m, (long) PtStack); return EAGAIN; }
  *t = (pthread_t) d;
  return 0; }

int pthread_join(pthread_t t, void **ret) {
  if (t == PtMain || t == pthread_self()) return EDEADLK;
  struct __pthread *d = (struct __pthread *) t;
  for (int tid; (tid = d->tid) != 0; )
    sc4(NR_futex, (long) &d->tid, 0, tid, 0);   /* FUTEX_WAIT while it still reads tid */
  if (ret) *ret = d->ret;
  munmap(d->map, (long) d->len);
  return 0; }
