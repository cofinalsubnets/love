/* errno and h_errno are each thread's own: every thread and main set theirs, a spin with no
 * libc call between waits until all have, and then each reads back what it set */
#include <errno.h>
#include <netdb.h>
#include <pthread.h>
#include <unistd.h>
#include "say.h"

#define N 6
static int arrived;

static void meet(void) {
  __atomic_fetch_add(&arrived, 1, __ATOMIC_SEQ_CST);
  while (__atomic_load_n(&arrived, __ATOMIC_SEQ_CST) < N + 1) ; }

static int want(long i) { return i & 1 ? (int) (100 + i) : EBADF; }

static void *one(void *arg) {
  long i = (long) arg;
  errno = 0;
  if (i & 1) errno = want(i);
  else close(-1);                    /* a failing call sets it */
  h_errno = (int) i + 1;
  meet();
  return (void *) (long) (errno == want(i) && h_errno == i + 1); }

static void *fresh(void *arg) { return (void *) (long) (errno == 0 && h_errno == 0); }

int main(void) {
  pthread_t t[N];
  for (long i = 0; i < N; i++) pthread_create(&t[i], 0, one, (void *) i);
  errno = EINTR;
  h_errno = TRY_AGAIN;
  meet();
  say_n("main keeps its own", errno == EINTR && h_errno == TRY_AGAIN);
  long ok = 0;
  for (int i = 0; i < N; i++) { void *r; pthread_join(t[i], &r); ok += (long) r; }
  say_n("threads keep their own", ok);
  /* a fresh thread starts at zero, whatever main's holds */
  errno = ENOENT;
  pthread_t z;
  void *r;
  pthread_create(&z, 0, fresh, 0);
  pthread_join(z, &r);
  say_n("a new thread starts at zero", (long) r);
  return 0; }
