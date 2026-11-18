#pragma once
/* threads on linux and the 64-bit BSDs (macos's create answers EAGAIN), 8M stacks unless an
   attribute says, a mutex's kind ignored. errno is each thread's; stdio takes no lock */
#include <sys/types.h>
#include <time.h>
typedef unsigned long pthread_t;
typedef struct { int __detach; unsigned long __stack; } pthread_attr_t;
typedef struct { int __lock, __seq; unsigned __n, __in; } pthread_barrier_t;
typedef struct { int __unused; } pthread_barrierattr_t;
typedef volatile int pthread_spinlock_t;
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
#define PTHREAD_STACK_MIN 16384
#define PTHREAD_CREATE_JOINABLE 0
#define PTHREAD_CREATE_DETACHED 1
#define PTHREAD_BARRIER_SERIAL_THREAD (-1)
#define PTHREAD_PROCESS_PRIVATE 0
int pthread_mutex_init(pthread_mutex_t *, pthread_mutexattr_t const *),
    pthread_mutex_destroy(pthread_mutex_t *), pthread_mutex_lock(pthread_mutex_t *),
    pthread_mutex_trylock(pthread_mutex_t *),
    pthread_mutex_timedlock(pthread_mutex_t *, struct timespec const *),
    pthread_mutex_unlock(pthread_mutex_t *), pthread_mutexattr_init(pthread_mutexattr_t *),
    pthread_mutexattr_destroy(pthread_mutexattr_t *),
    pthread_mutexattr_settype(pthread_mutexattr_t *, int),
    pthread_mutexattr_gettype(pthread_mutexattr_t const *, int *),
    pthread_cond_init(pthread_cond_t *, pthread_condattr_t const *),
    pthread_cond_destroy(pthread_cond_t *), pthread_cond_wait(pthread_cond_t *, pthread_mutex_t *),
    pthread_cond_timedwait(pthread_cond_t *, pthread_mutex_t *, struct timespec const *),
    pthread_cond_signal(pthread_cond_t *), pthread_cond_broadcast(pthread_cond_t *),
    pthread_condattr_init(pthread_condattr_t *), pthread_condattr_destroy(pthread_condattr_t *),
    pthread_rwlock_init(pthread_rwlock_t *, pthread_rwlockattr_t const *),
    pthread_rwlock_destroy(pthread_rwlock_t *), pthread_rwlock_rdlock(pthread_rwlock_t *),
    pthread_rwlock_wrlock(pthread_rwlock_t *), pthread_rwlock_tryrdlock(pthread_rwlock_t *),
    pthread_rwlock_trywrlock(pthread_rwlock_t *), pthread_rwlock_unlock(pthread_rwlock_t *),
    pthread_rwlockattr_init(pthread_rwlockattr_t *),
    pthread_rwlockattr_destroy(pthread_rwlockattr_t *),
    pthread_once(pthread_once_t *, void (*)(void)),
    pthread_key_create(pthread_key_t *, void (*)(void *)), pthread_key_delete(pthread_key_t);
void *pthread_getspecific(pthread_key_t);
int pthread_setspecific(pthread_key_t, void const *),
    pthread_create(pthread_t *, pthread_attr_t const *, void *(*)(void *), void *),
    pthread_join(pthread_t, void **);
void pthread_exit(void *) __attribute__((noreturn));
pthread_t pthread_self(void);
int pthread_equal(pthread_t, pthread_t), pthread_attr_init(pthread_attr_t *),
    pthread_attr_destroy(pthread_attr_t *), pthread_attr_setstacksize(pthread_attr_t *, size_t),
    pthread_attr_getstacksize(pthread_attr_t const *, size_t *),
    pthread_attr_setdetachstate(pthread_attr_t *, int), pthread_attr_getdetachstate(pthread_attr_t const *, int *),
    pthread_detach(pthread_t), pthread_kill(pthread_t, int),
    pthread_atfork(void (*)(void), void (*)(void), void (*)(void)),
    pthread_setname_np(pthread_t, char const *), pthread_getname_np(pthread_t, char *, size_t),
    pthread_barrier_init(pthread_barrier_t *, pthread_barrierattr_t const *, unsigned),
    pthread_barrier_wait(pthread_barrier_t *), pthread_barrier_destroy(pthread_barrier_t *),
    pthread_spin_init(pthread_spinlock_t *, int), pthread_spin_lock(pthread_spinlock_t *),
    pthread_spin_trylock(pthread_spinlock_t *), pthread_spin_unlock(pthread_spinlock_t *),
    pthread_spin_destroy(pthread_spinlock_t *);
