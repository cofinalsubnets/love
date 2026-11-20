#pragma once
#include <sys/time.h>
#include <sys/types.h>
#define RUSAGE_SELF      0
#define RUSAGE_CHILDREN (-1)
/* the kernels agree only on the two timevals; the tail is linux's, read by nobody */
struct rusage {
  struct timeval ru_utime, ru_stime;
  long ru_maxrss, ru_ixrss, ru_idrss, ru_isrss, ru_minflt, ru_majflt, ru_nswap,
       ru_inblock, ru_oublock, ru_msgsnd, ru_msgrcv, ru_nsignals, ru_nvcsw, ru_nivcsw; };
int getrusage(int, struct rusage*);
/* linux's numbers, respelled for the bsds */
typedef unsigned long rlim_t;
#define RLIM_INFINITY (~(rlim_t) 0)
#define RLIMIT_CPU     0
#define RLIMIT_FSIZE   1
#define RLIMIT_DATA    2
#define RLIMIT_STACK   3
#define RLIMIT_CORE    4
#ifdef __mips__
#define RLIMIT_RSS     7
#define RLIMIT_NPROC   8
#define RLIMIT_NOFILE  5
#define RLIMIT_MEMLOCK 9
#define RLIMIT_AS      6
#else
#define RLIMIT_RSS     5
#define RLIMIT_NPROC   6
#define RLIMIT_NOFILE  7
#define RLIMIT_MEMLOCK 8
#define RLIMIT_AS      9
#endif
struct rlimit { rlim_t rlim_cur, rlim_max; };
int getrlimit(int, struct rlimit*), setrlimit(int, const struct rlimit*);
#define PRIO_PROCESS 0
#define PRIO_PGRP    1
#define PRIO_USER    2
int getpriority(int, id_t), setpriority(int, id_t, int);
