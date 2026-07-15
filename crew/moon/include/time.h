#ifndef _AI_TIME_H
#define _AI_TIME_H
typedef long time_t;
struct timespec { long tv_sec; long tv_nsec; };
#define CLOCK_REALTIME  0
#define CLOCK_MONOTONIC 1
int clock_gettime(int, struct timespec*);
int nanosleep(struct timespec const*, struct timespec*);
time_t time(time_t*);
#endif
