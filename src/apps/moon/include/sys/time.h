#pragma once
#include <time.h>
struct timeval { long tv_sec; long tv_usec; };
int gettimeofday(struct timeval*, void*);
int utimes(char const*, struct timeval const*);
