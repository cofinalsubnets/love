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
#endif
