/* mipstp: the thread pointer rdhwr $29 reads is 0 in main, before a thread and after, and a
 * thread's own handle in the thread; main's errno stays its own */
#include <stdio.h>
#include <errno.h>
#include <pthread.h>

void *__love_tp(void);
static void *seen;
static void *run(void *a) { seen = __love_tp(); errno = 7; return a; }

int main(void) {
  printf("main tp 0 before: %d\n", __love_tp() == 0);
  pthread_t t;
  printf("create: %d\n", pthread_create(&t, 0, run, 0));
  pthread_join(t, 0);
  printf("thread tp its handle: %d\n", seen == (void *) t);
  printf("main tp 0 after: %d\n", __love_tp() == 0);
  errno = 3;
  printf("main errno its own: %d\n", errno == 3);
  return 0; }
