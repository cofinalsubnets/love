#ifndef _AI_SYS_RESOURCE_H
#define _AI_SYS_RESOURCE_H
#include <sys/time.h>   /* struct timeval */
#define RUSAGE_SELF      0
#define RUSAGE_CHILDREN (-1)
/* the kernels agree on the two timevals and part company after them: the tail is
 * sized to linux's and read by nobody. `time` wants ru_utime and ru_stime. */
struct rusage {
  struct timeval ru_utime, ru_stime;
  long ru_maxrss, ru_ixrss, ru_idrss, ru_isrss, ru_minflt, ru_majflt, ru_nswap,
       ru_inblock, ru_oublock, ru_msgsnd, ru_msgrcv, ru_nsignals, ru_nvcsw, ru_nivcsw; };
int getrusage(int, struct rusage*);
/* the resource numbers are linux's; sys/getrlimit.c respells them for a BSD */
typedef unsigned long rlim_t;
#define RLIM_INFINITY (~(rlim_t) 0)
#define RLIMIT_CPU     0
#define RLIMIT_FSIZE   1
#define RLIMIT_DATA    2
#define RLIMIT_STACK   3
#define RLIMIT_CORE    4
#define RLIMIT_RSS     5
#define RLIMIT_NPROC   6
#define RLIMIT_NOFILE  7
#define RLIMIT_MEMLOCK 8
#define RLIMIT_AS      9
struct rlimit { rlim_t rlim_cur, rlim_max; };
int getrlimit(int, struct rlimit*);
int setrlimit(int, const struct rlimit*);
#endif
