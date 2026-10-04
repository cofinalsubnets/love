#include "../impl.h"
#include <pthread.h>

/* a thread's record, laid at the top of its own stack. the kernel writes tid at the clone
 * (CLONE_PARENT_SETTID) and clears it, waking the futex, once the thread is gone
 * (CLONE_CHILD_CLEARTID): that is all a join waits for, and only then is the stack unmapped */
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
  for (;;) sc1(NR_exit, 0); }               /* this thread alone; the last one out ends the process */

/* where clone's child lands: sys.o calls it on the new stack, and it never returns */
static void __pt_start(struct __pthread *d) { pthread_exit(d->fn(d->arg)); }

int pthread_create(pthread_t *t, pthread_attr_t const *at, void *(*fn)(void *), void *arg) {
  if (__love_osv >= 2) return EAGAIN;           /* the BSDs: thr_new and _lwp_create are not spoken here */
  void *m = mmap(0, (long) PtStack, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (m == (void *) -1) return EAGAIN;
  mprotect(m, 4096, PROT_NONE);               /* a guard page under the stack */
  struct __pthread *d = (struct __pthread *) (((unsigned long) m + PtStack - sizeof *d) & ~15UL);
  d->fn = fn; d->arg = arg; d->ret = 0; d->map = m; d->len = PtStack; d->tid = 0;
  memset(d->tsd, 0, sizeof d->tsd);
  void **sp = (void **) (((unsigned long) d - 16) & ~15UL);
  sp[0] = (void *) __pt_start; sp[1] = d;     /* the leaf calls sp[0](sp[1]) */
  __love_mt.threads = 1;                        /* before the child can reach malloc */
  long r = __love_clone(PtFlags, sp, (int *) &d->tid, (int *) &d->tid, d);
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
