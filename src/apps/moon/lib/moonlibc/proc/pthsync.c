#include "../impl.h"
#include <pthread.h>

/* a mutex word is 0 free, 1 held, 2 held maybe with waiters; only exchange moves it, so an
 * unlock that takes back a 2 wakes one. the unlock releases, or on arm64 and riscv the
 * holder's writes land after the next holder reads */
#define FxWait 128
#define FxWake 129
/* netbsd's __futex speaks linux's (os.c's row); freebsd's word is _umtx_op's private
 * WAIT_UINT and WAKE, its timeout the size of a timespec and then the timespec */
static int __fx_wait(int *w, int v, struct timespec const *rel) {
  if (__love_osv == 2) return (int) fb6(454, (long) w, 15, v, rel ? (long) sizeof *rel : 0, (long) rel, 0);
  return (int) sc4(NR_futex, (long) w, FxWait, v, (long) rel); }
static void __fx_wake(int *w, int n) {
  if (__love_osv == 2) fb6(454, (long) w, 16, n, 0, 0, 0);
  else sc4(NR_futex, (long) w, FxWake, n, 0); }

/* abstime (CLOCK_REALTIME) as the time left, or 0 when it has passed */
static int __pt_left(struct timespec const *abs, struct timespec *rel) {
  struct timespec now;
  clock_gettime(CLOCK_REALTIME, &now);
  rel->tv_sec = abs->tv_sec - now.tv_sec;
  rel->tv_nsec = abs->tv_nsec - now.tv_nsec;
  if (rel->tv_nsec < 0) { rel->tv_nsec += 1000000000L; rel->tv_sec--; }
  return rel->tv_sec >= 0; }

static void __pt_take(int *w) {
  if (__sync_lock_test_and_set(w, 1) == 0) return;
  while (__sync_lock_test_and_set(w, 2) != 0) __fx_wait(w, 2, 0); }
static int __pt_taketill(int *w, struct timespec const *abs) {
  if (__sync_lock_test_and_set(w, 1) == 0) return 0;
  struct timespec rel;
  while (__sync_lock_test_and_set(w, 2) != 0) {
    if (!__pt_left(abs, &rel)) return ETIMEDOUT;
    __fx_wait(w, 2, &rel); }
  return 0; }
static void __pt_give(int *w) { if (__atomic_exchange_n(w, 0, __ATOMIC_RELEASE) == 2) __fx_wake(w, 1); }

int pthread_mutexattr_init(pthread_mutexattr_t *a) { a->__kind = PTHREAD_MUTEX_DEFAULT; return 0; }
int pthread_mutexattr_destroy(pthread_mutexattr_t *a) { return 0; }
int pthread_mutexattr_settype(pthread_mutexattr_t *a, int k) {
  if (k < PTHREAD_MUTEX_NORMAL || k > PTHREAD_MUTEX_ERRORCHECK) return EINVAL;
  a->__kind = k; return 0; }
int pthread_mutexattr_gettype(pthread_mutexattr_t const *a, int *k) { *k = a->__kind; return 0; }

int pthread_mutex_init(pthread_mutex_t *m, pthread_mutexattr_t const *a) {
  m->__lock = 0; m->__count = 0; m->__owner = 0; m->__kind = a ? a->__kind : PTHREAD_MUTEX_DEFAULT;
  return 0; }
int pthread_mutex_destroy(pthread_mutex_t *m) { return m->__lock ? EBUSY : 0; }

static int __pt_mine(pthread_mutex_t *m) {
  if (m->__kind == PTHREAD_MUTEX_NORMAL || m->__owner != pthread_self()) return -1;
  if (m->__kind == PTHREAD_MUTEX_ERRORCHECK) return EDEADLK;
  m->__count++; return 0; }
static int __pt_got(pthread_mutex_t *m) {
  if (m->__kind != PTHREAD_MUTEX_NORMAL) { m->__owner = pthread_self(); m->__count = 1; }
  return 0; }
int pthread_mutex_lock(pthread_mutex_t *m) {
  int r = __pt_mine(m);
  if (r >= 0) return r;
  __pt_take(&m->__lock);
  return __pt_got(m); }
int pthread_mutex_timedlock(pthread_mutex_t *m, struct timespec const *abs) {
  int r = __pt_mine(m);
  if (r >= 0) return r;
  if ((r = __pt_taketill(&m->__lock, abs))) return r;
  return __pt_got(m); }
int pthread_mutex_trylock(pthread_mutex_t *m) {
  int r = __pt_mine(m);
  if (r >= 0) return r == EDEADLK ? EBUSY : r;
  if (m->__lock || __sync_lock_test_and_set(&m->__lock, 2) != 0) return EBUSY;
  return __pt_got(m); }
int pthread_mutex_unlock(pthread_mutex_t *m) {
  if (m->__kind != PTHREAD_MUTEX_NORMAL) {
    if (m->__owner != pthread_self() || !m->__count) return EPERM;
    if (--m->__count) return 0;
    m->__owner = 0; }
  __pt_give(&m->__lock);
  return 0; }

/* a condition is a sequence word that a signal moves; waking early is allowed */
int pthread_condattr_init(pthread_condattr_t *a) { a->__unused = 0; return 0; }
int pthread_condattr_destroy(pthread_condattr_t *a) { return 0; }
int pthread_cond_init(pthread_cond_t *c, pthread_condattr_t const *a) { c->__seq = 0; return 0; }
int pthread_cond_destroy(pthread_cond_t *c) { return 0; }
static int __pt_cwait(pthread_cond_t *c, pthread_mutex_t *m, struct timespec const *abs) {
  int s = c->__seq, kind = m->__kind, n = m->__count, r = 0;
  if (kind != PTHREAD_MUTEX_NORMAL && m->__owner != pthread_self()) return EPERM;
  m->__count = 0; m->__owner = 0;
  __pt_give(&m->__lock);
  struct timespec rel;
  if (!abs) __fx_wait(&c->__seq, s, 0);
  else if (!__pt_left(abs, &rel) || __fx_wait(&c->__seq, s, &rel) == -ETIMEDOUT) r = ETIMEDOUT;
  while (__sync_lock_test_and_set(&m->__lock, 2) != 0) __fx_wait(&m->__lock, 2, 0);   /* others may wait on it now */
  if (kind != PTHREAD_MUTEX_NORMAL) { m->__owner = pthread_self(); m->__count = n; }
  return r; }
int pthread_cond_wait(pthread_cond_t *c, pthread_mutex_t *m) { return __pt_cwait(c, m, 0); }
int pthread_cond_timedwait(pthread_cond_t *c, pthread_mutex_t *m, struct timespec const *abs) { return __pt_cwait(c, m, abs); }
int pthread_cond_signal(pthread_cond_t *c) { c->__seq++; __fx_wake(&c->__seq, 1); return 0; }
int pthread_cond_broadcast(pthread_cond_t *c) { c->__seq++; __fx_wake(&c->__seq, 0x7fffffff); return 0; }

int pthread_rwlockattr_init(pthread_rwlockattr_t *a) { a->__unused = 0; return 0; }
int pthread_rwlockattr_destroy(pthread_rwlockattr_t *a) { return 0; }
int pthread_rwlock_init(pthread_rwlock_t *l, pthread_rwlockattr_t const *a) {
  l->__lock = l->__seq = l->__readers = l->__writer = 0; return 0; }
int pthread_rwlock_destroy(pthread_rwlock_t *l) { return l->__readers || l->__writer ? EBUSY : 0; }
static int __pt_rw(pthread_rwlock_t *l, int wr, int try) {
  for (;;) {
    __pt_take(&l->__lock);
    if (!l->__writer && (!wr || !l->__readers)) {
      if (wr) l->__writer = 1; else l->__readers++;
      __pt_give(&l->__lock);
      return 0; }
    int s = l->__seq;
    __pt_give(&l->__lock);
    if (try) return EBUSY;
    __fx_wait(&l->__seq, s, 0); } }
int pthread_rwlock_rdlock(pthread_rwlock_t *l) { return __pt_rw(l, 0, 0); }
int pthread_rwlock_wrlock(pthread_rwlock_t *l) { return __pt_rw(l, 1, 0); }
int pthread_rwlock_tryrdlock(pthread_rwlock_t *l) { return __pt_rw(l, 0, 1); }
int pthread_rwlock_trywrlock(pthread_rwlock_t *l) { return __pt_rw(l, 1, 1); }
int pthread_rwlock_unlock(pthread_rwlock_t *l) {
  __pt_take(&l->__lock);
  if (l->__writer) l->__writer = 0; else if (l->__readers) l->__readers--;
  l->__seq++;
  __pt_give(&l->__lock);
  __fx_wake(&l->__seq, 0x7fffffff);
  return 0; }

/* once: 0 not yet, 1 running, 2 done; a claim that lands on a 2 puts it back. done is a
 * release, read with an acquire */
int pthread_once(pthread_once_t *o, void (*fn)(void)) {
  while (__atomic_load_n(o, __ATOMIC_ACQUIRE) != 2) {
    int was = __sync_lock_test_and_set(o, 1);
    if (was == 0) { fn(); __atomic_exchange_n(o, 2, __ATOMIC_RELEASE); __fx_wake(o, 0x7fffffff); return 0; }
    if (was == 2) { __atomic_exchange_n(o, 2, __ATOMIC_RELEASE); __fx_wake(o, 0x7fffffff); return 0; }
    __fx_wait(o, 1, 0); }
  return 0; }

void **__pt_tsd(void);
int pthread_key_create(pthread_key_t *k, void (*dtor)(void *)) {
  __pt_take(&__love_mt.klock);
  int i = 0;
  while (i < PTHREAD_KEYS_MAX && __love_mt.key[i]) i++;
  if (i < PTHREAD_KEYS_MAX) { __love_mt.key[i] = 1; __love_mt.dtor[i] = dtor; }
  __pt_give(&__love_mt.klock);
  if (i == PTHREAD_KEYS_MAX) return EAGAIN;
  __pt_tsd()[i] = 0;
  *k = (pthread_key_t) i; return 0; }
int pthread_key_delete(pthread_key_t k) {
  if (k >= PTHREAD_KEYS_MAX || !__love_mt.key[k]) return EINVAL;
  __love_mt.key[k] = 0; __love_mt.dtor[k] = 0; return 0; }
void *pthread_getspecific(pthread_key_t k) { return k < PTHREAD_KEYS_MAX ? __pt_tsd()[k] : 0; }
int pthread_setspecific(pthread_key_t k, void const *v) {
  if (k >= PTHREAD_KEYS_MAX || !__love_mt.key[k]) return EINVAL;
  __pt_tsd()[k] = (void *) v; return 0; }

/* semaphores: __v the count, __w the sleepers. a post raises __v then reads __w, a waiter
 * raises __w then sleeps only while __v is 0: seq_cst both, so one sees the other's store */
#include <semaphore.h>
int sem_init(sem_t *s, int shared, unsigned v) {
  if (shared) { __errno_v = ENOSYS; return -1; }          /* the futex ops are private */
  if (v > INT_MAX) { __errno_v = EINVAL; return -1; }
  s->__v = (int) v; s->__w = 0; return 0; }
int sem_destroy(sem_t *s) { return 0; }
int sem_post(sem_t *s) {
  __atomic_fetch_add(&s->__v, 1, __ATOMIC_SEQ_CST);
  if (__atomic_load_n(&s->__w, __ATOMIC_SEQ_CST)) __fx_wake(&s->__v, 1);
  return 0; }
static int __sem_take(sem_t *s) {
  int v = __atomic_load_n(&s->__v, __ATOMIC_ACQUIRE);
  while (v > 0)
    if (__atomic_compare_exchange_n(&s->__v, &v, v - 1, 0, __ATOMIC_ACQUIRE, __ATOMIC_ACQUIRE)) return 1;
  return 0; }
int sem_trywait(sem_t *s) { if (__sem_take(s)) return 0; __errno_v = EAGAIN; return -1; }
static int __sem_wait(sem_t *s, struct timespec const *abs) {
  for (;;) {
    if (__sem_take(s)) return 0;
    struct timespec rel;
    if (abs && !__pt_left(abs, &rel)) { __errno_v = ETIMEDOUT; return -1; }
    __atomic_fetch_add(&s->__w, 1, __ATOMIC_SEQ_CST);
    int r = __fx_wait(&s->__v, 0, abs ? &rel : 0);
    __atomic_fetch_sub(&s->__w, 1, __ATOMIC_SEQ_CST);
    if (r == -EINTR) { __errno_v = EINTR; return -1; } } }
int sem_wait(sem_t *s) { return __sem_wait(s, 0); }
int sem_timedwait(sem_t *s, struct timespec const *abs) {
  if (abs->tv_nsec < 0 || abs->tv_nsec >= 1000000000L) { __errno_v = EINVAL; return -1; }
  return __sem_wait(s, abs); }
int sem_getvalue(sem_t *s, int *v) { *v = __atomic_load_n(&s->__v, __ATOMIC_ACQUIRE); return 0; }
