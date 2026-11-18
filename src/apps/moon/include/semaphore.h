#pragma once
#include <time.h>
/* an unnamed, process-private counting semaphore; glibc's 32 bytes */
typedef struct { int __v, __w; char __pad[24]; } sem_t;
#define SEM_FAILED ((sem_t *) 0)
int sem_init(sem_t *, int, unsigned), sem_destroy(sem_t *), sem_post(sem_t *), sem_wait(sem_t *),
    sem_trywait(sem_t *), sem_timedwait(sem_t *, struct timespec const *),
    sem_getvalue(sem_t *, int *);
