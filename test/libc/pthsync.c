/* the pthread waits: a mutex keeps a shared count whole under eight threads, the three kinds
 * answer as POSIX has them, a condition carries a queue between threads, once runs once, keys
 * hold a value per thread and destroy it at exit, an rwlock admits readers together and a
 * writer alone. sums and error numbers only, so both libcs print the same */
#include <pthread.h>
#include <time.h>
#include "say.h"

static pthread_mutex_t mu = PTHREAD_MUTEX_INITIALIZER;
static long count;
static void *bump(void *arg) {
  for (int i = 0; i < 20000; i++) { pthread_mutex_lock(&mu); count++; pthread_mutex_unlock(&mu); }
  return 0; }

static pthread_mutex_t ec;
static void *foreign(void *arg) {
  long r = pthread_mutex_unlock(&ec);                   /* not its owner */
  return (void *) (r * 100 + pthread_mutex_trylock((pthread_mutex_t *) arg)); }

static pthread_mutex_t qm = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t qc = PTHREAD_COND_INITIALIZER;
static int q[64], qn, qdone;
static void *produce(void *arg) {
  for (int i = 1; i <= 500; i++) {
    pthread_mutex_lock(&qm);
    while (qn == 64) pthread_cond_wait(&qc, &qm);
    q[qn++] = i;
    pthread_cond_broadcast(&qc);
    pthread_mutex_unlock(&qm); }
  pthread_mutex_lock(&qm); qdone = 1; pthread_cond_broadcast(&qc); pthread_mutex_unlock(&qm);
  return 0; }

static pthread_once_t once = PTHREAD_ONCE_INIT;
static int onces;
static void init_once(void) { onces++; }
static void *call_once(void *arg) { pthread_once(&once, init_once); return 0; }

static pthread_key_t key;
static int destroyed;
static long dsum;
static void dtor(void *v) { destroyed++; dsum += (long) v; }
static void *keep(void *arg) {
  pthread_setspecific(key, arg);
  return (void *) (long) (pthread_getspecific(key) == arg); }

static pthread_rwlock_t rw = PTHREAD_RWLOCK_INITIALIZER;
static void *tryw(void *arg) { return (void *) (long) pthread_rwlock_trywrlock(&rw); }
static void *tryr(void *arg) {
  long r = pthread_rwlock_tryrdlock(&rw);
  if (!r) pthread_rwlock_unlock(&rw);
  return (void *) r; }

int main(void) {
  pthread_t t[8]; void *r;
  for (int i = 0; i < 8; i++) pthread_create(&t[i], 0, bump, 0);
  for (int i = 0; i < 8; i++) pthread_join(t[i], 0);
  say_n("mutex.count", count);

  pthread_mutex_lock(&mu);
  say_n("normal.trylock.held", pthread_mutex_trylock(&mu));
  struct timespec past = { 1, 0 };
  say_n("timedlock.past", pthread_mutex_timedlock(&mu, &past));
  pthread_mutex_unlock(&mu);
  say_n("normal.trylock.free", pthread_mutex_trylock(&mu));
  pthread_mutex_unlock(&mu);

  pthread_mutexattr_t a; int k;
  pthread_mutexattr_init(&a);
  say_n("attr.settype.bad", pthread_mutexattr_settype(&a, 99));
  pthread_mutexattr_settype(&a, PTHREAD_MUTEX_ERRORCHECK);
  pthread_mutexattr_gettype(&a, &k); say_n("attr.gettype", k == PTHREAD_MUTEX_ERRORCHECK);
  pthread_mutex_init(&ec, &a);
  say_n("errorcheck.lock", pthread_mutex_lock(&ec));
  say_n("errorcheck.relock", pthread_mutex_lock(&ec));
  say_n("errorcheck.trylock", pthread_mutex_trylock(&ec));
  pthread_mutex_t rm;
  pthread_mutexattr_settype(&a, PTHREAD_MUTEX_RECURSIVE);
  pthread_mutex_init(&rm, &a);
  say_n("recursive.lock", pthread_mutex_lock(&rm) + pthread_mutex_lock(&rm) + pthread_mutex_trylock(&rm));
  pthread_t f; pthread_create(&f, 0, foreign, &rm); pthread_join(f, &r);
  say_n("foreign.unlock*100+trylock", (long) r);
  say_n("recursive.unlock", pthread_mutex_unlock(&rm) + pthread_mutex_unlock(&rm));
  say_n("recursive.destroy.held", pthread_mutex_destroy(&rm));
  say_n("recursive.unlock.last", pthread_mutex_unlock(&rm));
  say_n("recursive.unlock.extra", pthread_mutex_unlock(&rm));
  pthread_create(&f, 0, foreign, &rm); pthread_join(f, &r);
  say_n("foreign.after", (long) r);
  say_n("errorcheck.unlock", pthread_mutex_unlock(&ec));
  pthread_mutexattr_destroy(&a);

  pthread_t p; long got = 0; int n = 0;
  pthread_create(&p, 0, produce, 0);
  pthread_mutex_lock(&qm);
  for (;;) {
    while (qn == 0 && !qdone) pthread_cond_wait(&qc, &qm);
    if (qn == 0) break;
    got += q[--qn]; n++;
    pthread_cond_broadcast(&qc); }
  pthread_mutex_unlock(&qm);
  pthread_join(p, 0);
  say_n("cond.items", n); say_n("cond.sum", got);
  pthread_mutex_lock(&qm);
  say_n("cond.timedwait.past", pthread_cond_timedwait(&qc, &qm, &past));
  struct timespec soon; clock_gettime(CLOCK_REALTIME, &soon);
  soon.tv_nsec += 20000000; if (soon.tv_nsec >= 1000000000) { soon.tv_nsec -= 1000000000; soon.tv_sec++; }
  say_n("cond.timedwait.soon", pthread_cond_timedwait(&qc, &qm, &soon));
  say_n("cond.signal.none", pthread_cond_signal(&qc));
  pthread_mutex_unlock(&qm);

  for (int i = 0; i < 8; i++) pthread_create(&t[i], 0, call_once, 0);
  for (int i = 0; i < 8; i++) pthread_join(t[i], 0);
  pthread_once(&once, init_once);
  say_n("once", onces);

  say_n("key.create", pthread_key_create(&key, dtor));
  pthread_setspecific(key, (void *) 7);
  long kept = 1;
  for (long i = 0; i < 4; i++) pthread_create(&t[i], 0, keep, (void *) (i + 1));
  for (int i = 0; i < 4; i++) { pthread_join(t[i], &r); kept &= (long) r; }
  say_n("key.kept", kept);
  say_n("key.destroyed", destroyed); say_n("key.dsum", dsum);
  say_n("key.main", (long) pthread_getspecific(key));
  say_n("key.delete", pthread_key_delete(key));

  say_n("rw.rd", pthread_rwlock_rdlock(&rw) + pthread_rwlock_rdlock(&rw));
  pthread_create(&f, 0, tryw, 0); pthread_join(f, &r); say_n("rw.trywr.readers", (long) r);
  pthread_create(&f, 0, tryr, 0); pthread_join(f, &r); say_n("rw.tryrd.readers", (long) r);
  pthread_rwlock_unlock(&rw); pthread_rwlock_unlock(&rw);
  say_n("rw.wr", pthread_rwlock_wrlock(&rw));
  pthread_create(&f, 0, tryr, 0); pthread_join(f, &r); say_n("rw.tryrd.writer", (long) r);
  pthread_create(&f, 0, tryw, 0); pthread_join(f, &r); say_n("rw.trywr.writer", (long) r);
  say_n("rw.unlock", pthread_rwlock_unlock(&rw));
  say_n("rw.destroy", pthread_rwlock_destroy(&rw));
  return 0; }
