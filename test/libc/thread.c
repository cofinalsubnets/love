/* threads: each runs on its own stack and answers through join (a return, or pthread_exit),
 * pthread_self tells them apart, and several allocate and free at once -- the arena's lock.
 * the answers are sums and matches, never tids or addresses, so both libcs print the same */
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include "say.h"

static pthread_t main_id;

static void *sum(void *arg) {
  long n = (long) arg, t = 0;
  for (long i = 1; i <= n; i++) t += i;
  return (void *) t; }

static void *quits(void *arg) {
  pthread_exit((void *) ((long) arg * 3));
  return 0; }

static void *whoami(void *arg) {
  return (void *) (long) (!pthread_equal(pthread_self(), main_id) && pthread_equal(pthread_self(), pthread_self())); }

static void *churn(void *arg) {
  long seed = (long) arg, ok = 1;
  for (int r = 0; r < 2000; r++) {
    int n = (int) ((seed * 7 + r * 13) % 300) + 1;
    char *p = malloc(n);
    if (!p) return 0;
    memset(p, (int) (seed + r) & 255, n);
    for (int i = 0; i < n; i++) if (p[i] != (char) ((seed + r) & 255)) ok = 0;
    free(p); }
  return (void *) ok; }

int main(void) {
  main_id = pthread_self();
  say_n("self.main", pthread_equal(main_id, pthread_self()));
  pthread_t t[8];
  for (long i = 0; i < 8; i++) say_n("create", pthread_create(&t[i], 0, sum, (void *) (1000 * (i + 1))));
  for (int i = 0; i < 8; i++) { void *r; say_n("join", pthread_join(t[i], &r)); say_n("  sum", (long) r); }
  pthread_t q; void *r;
  pthread_create(&q, 0, quits, (void *) 14); pthread_join(q, &r); say_n("pthread_exit", (long) r);
  pthread_create(&q, 0, whoami, 0); pthread_join(q, &r); say_n("self.thread", (long) r);
  pthread_t c[6]; long all = 1;
  for (long i = 0; i < 6; i++) pthread_create(&c[i], 0, churn, (void *) (i + 1));
  for (int i = 0; i < 6; i++) { pthread_join(c[i], &r); all &= (long) r; }
  say_n("churn", all);
  pthread_attr_t a; say_n("attr", pthread_attr_init(&a) + pthread_attr_destroy(&a));
  return 0; }
