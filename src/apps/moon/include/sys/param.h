#ifndef _AI_SYS_PARAM_H
#define _AI_SYS_PARAM_H
/* freestanding sys/param.h for cc: the BSD-ish path/word constants and the little
 * arithmetic macros old unix code reaches for. */
#include <limits.h>
#ifndef MAXPATHLEN
#define MAXPATHLEN PATH_MAX
#endif
#ifndef MAXNAMLEN
#define MAXNAMLEN NAME_MAX
#endif
#define NOFILE 256
#define NBBY   8
#define howmany(x, y) (((x) + ((y) - 1)) / (y))
#define roundup(x, y) ((((x) + ((y) - 1)) / (y)) * (y))
#ifndef MIN
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#endif
#ifndef MAX
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#endif
#endif
