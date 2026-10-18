#ifndef _LOVE_SYS_SENDFILE_H
#define _LOVE_SYS_SENDFILE_H
#include <sys/types.h>
ssize_t sendfile(int, int, off_t*, size_t);
#endif
