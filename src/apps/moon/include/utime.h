#ifndef _AI_UTIME_H
#define _AI_UTIME_H
#include <sys/types.h>   /* time_t */
struct utimbuf { time_t actime; time_t modtime; };
int utime(char const*, struct utimbuf const*);
#endif
