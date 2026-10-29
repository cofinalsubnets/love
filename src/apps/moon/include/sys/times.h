#pragma once
#include <sys/types.h>
typedef long clock_t;
struct tms { clock_t tms_utime, tms_stime, tms_cutime, tms_cstime; };
clock_t times(struct tms*);
