#pragma once
#include <time.h>
struct timeval { long tv_sec; long tv_usec; };
int gettimeofday(struct timeval*, void*), utimes(char const*, struct timeval const*);
struct itimerval { struct timeval it_interval, it_value; };
#define ITIMER_REAL    0
#define ITIMER_VIRTUAL 1
#define ITIMER_PROF    2
int getitimer(int, struct itimerval*), setitimer(int, struct itimerval const*, struct itimerval*);
