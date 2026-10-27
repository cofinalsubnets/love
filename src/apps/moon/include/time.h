#ifndef _LOVE_TIME_H
#define _LOVE_TIME_H
#ifdef __ILP32__
typedef long long time_t;
#else
typedef long time_t;
#endif
typedef long clock_t;
#define CLOCKS_PER_SEC 1000000
#ifdef __ILP32__  /* the kernel's 16-byte time64 record */
struct timespec { time_t tv_sec; long tv_nsec; long __pad; };
#else
struct timespec { long tv_sec; long tv_nsec; };
#endif
/* glibc's layout, gnu's tm_gmtoff and tm_zone included */
struct tm { int tm_sec; int tm_min; int tm_hour; int tm_mday; int tm_mon;
            int tm_year; int tm_wday; int tm_yday; int tm_isdst;
            long tm_gmtoff; char const* tm_zone; };
/* no timezone database: the zone is always utc and tzset a no-op */
void tzset(void);
extern char *tzname[2];
extern long timezone;
extern int daylight;
struct tm* localtime(time_t const*);
struct tm* gmtime(time_t const*);
struct tm* localtime_r(time_t const*, struct tm*);
struct tm* gmtime_r(time_t const*, struct tm*);
time_t     mktime(struct tm*);
char*      ctime(time_t const*);
char*      ctime_r(time_t const*, char*);
char*      asctime(struct tm const*);
char*      asctime_r(struct tm const*, char*);
double     difftime(time_t, time_t);
unsigned long strftime(char*, unsigned long, char const*, struct tm const*);
#define CLOCK_REALTIME  0
#define CLOCK_MONOTONIC 1
int clock_gettime(int, struct timespec*);
int nanosleep(struct timespec const*, struct timespec*);
time_t time(time_t*);
clock_t clock(void);
#endif
