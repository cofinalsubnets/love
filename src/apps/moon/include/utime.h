#ifndef _LOVE_UTIME_H
#define _LOVE_UTIME_H
#include <sys/types.h>
struct utimbuf { time_t actime; time_t modtime; };
int utime(char const*, struct utimbuf const*);
#endif
