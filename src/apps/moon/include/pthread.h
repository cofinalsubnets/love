#ifndef _AI_PTHREAD_H
#define _AI_PTHREAD_H
/* the minimal threads: create, join, exit, self, equal -- linux only (clone, a futex join); on
   another kernel pthread_create answers EAGAIN. each thread gets an 8M stack and ignores its
   attributes. malloc and free lock once a second thread exists; errno is one for the whole
   process, and stdio streams take no lock. */
#include <sys/types.h>
typedef unsigned long pthread_t;
typedef struct { int __unused; } pthread_attr_t;
int pthread_create(pthread_t *, pthread_attr_t const *, void *(*)(void *), void *);
int pthread_join(pthread_t, void **);
void pthread_exit(void *) __attribute__((noreturn));
pthread_t pthread_self(void);
int pthread_equal(pthread_t, pthread_t);
int pthread_attr_init(pthread_attr_t *);
int pthread_attr_destroy(pthread_attr_t *);
#endif
