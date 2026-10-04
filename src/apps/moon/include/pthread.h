#ifndef _LOVE_PTHREAD_H
#define _LOVE_PTHREAD_H
/* the minimal threads: create, join, exit, self, equal -- linux only (clone, a futex join); on
   another kernel pthread_create answers EAGAIN. each thread gets an 8M stack and ignores its
   attributes. malloc and free lock once a second thread exists; errno is one for the whole
   process, and stdio streams take no lock. mutexes (normal, errorcheck, recursive), conditions,
   rwlocks, once and keys are futex words, process-private; their attributes but a mutex's kind
   are taken and ignored. */
#include <sys/types.h>
#include <time.h>
typedef unsigned long pthread_t;
typedef struct { int __unused; } pthread_attr_t;
typedef struct { int __lock, __kind, __count; unsigned long __owner; } pthread_mutex_t;
typedef struct { int __kind; } pthread_mutexattr_t;
typedef struct { int __seq; } pthread_cond_t;
typedef struct { int __unused; } pthread_condattr_t;
typedef struct { int __lock, __seq, __readers, __writer; } pthread_rwlock_t;
typedef struct { int __unused; } pthread_rwlockattr_t;
typedef int pthread_once_t;
typedef unsigned int pthread_key_t;
#define PTHREAD_MUTEX_NORMAL 0
#define PTHREAD_MUTEX_RECURSIVE 1
#define PTHREAD_MUTEX_ERRORCHECK 2
#define PTHREAD_MUTEX_DEFAULT PTHREAD_MUTEX_NORMAL
#define PTHREAD_MUTEX_INITIALIZER { 0, 0, 0, 0 }
#define PTHREAD_COND_INITIALIZER { 0 }
#define PTHREAD_RWLOCK_INITIALIZER { 0, 0, 0, 0 }
#define PTHREAD_ONCE_INIT 0
#define PTHREAD_KEYS_MAX 128
#define PTHREAD_DESTRUCTOR_ITERATIONS 4
int pthread_mutex_init(pthread_mutex_t *, pthread_mutexattr_t const *);
int pthread_mutex_destroy(pthread_mutex_t *);
int pthread_mutex_lock(pthread_mutex_t *);
int pthread_mutex_trylock(pthread_mutex_t *);
int pthread_mutex_timedlock(pthread_mutex_t *, struct timespec const *);
int pthread_mutex_unlock(pthread_mutex_t *);
int pthread_mutexattr_init(pthread_mutexattr_t *);
int pthread_mutexattr_destroy(pthread_mutexattr_t *);
int pthread_mutexattr_settype(pthread_mutexattr_t *, int);
int pthread_mutexattr_gettype(pthread_mutexattr_t const *, int *);
int pthread_cond_init(pthread_cond_t *, pthread_condattr_t const *);
int pthread_cond_destroy(pthread_cond_t *);
int pthread_cond_wait(pthread_cond_t *, pthread_mutex_t *);
int pthread_cond_timedwait(pthread_cond_t *, pthread_mutex_t *, struct timespec const *);
int pthread_cond_signal(pthread_cond_t *);
int pthread_cond_broadcast(pthread_cond_t *);
int pthread_condattr_init(pthread_condattr_t *);
int pthread_condattr_destroy(pthread_condattr_t *);
int pthread_rwlock_init(pthread_rwlock_t *, pthread_rwlockattr_t const *);
int pthread_rwlock_destroy(pthread_rwlock_t *);
int pthread_rwlock_rdlock(pthread_rwlock_t *);
int pthread_rwlock_wrlock(pthread_rwlock_t *);
int pthread_rwlock_tryrdlock(pthread_rwlock_t *);
int pthread_rwlock_trywrlock(pthread_rwlock_t *);
int pthread_rwlock_unlock(pthread_rwlock_t *);
int pthread_rwlockattr_init(pthread_rwlockattr_t *);
int pthread_rwlockattr_destroy(pthread_rwlockattr_t *);
int pthread_once(pthread_once_t *, void (*)(void));
int pthread_key_create(pthread_key_t *, void (*)(void *));
int pthread_key_delete(pthread_key_t);
void *pthread_getspecific(pthread_key_t);
int pthread_setspecific(pthread_key_t, void const *);
int pthread_create(pthread_t *, pthread_attr_t const *, void *(*)(void *), void *);
int pthread_join(pthread_t, void **);
void pthread_exit(void *) __attribute__((noreturn));
pthread_t pthread_self(void);
int pthread_equal(pthread_t, pthread_t);
int pthread_attr_init(pthread_attr_t *);
int pthread_attr_destroy(pthread_attr_t *);
#endif
