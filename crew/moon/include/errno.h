#ifndef _AI_ERRNO_H
#define _AI_ERRNO_H
/* glibc's errno is thread-local behind a call */
int *__errno_location(void);
#define errno (*__errno_location())
#define EPERM            1
#define ENOENT           2
#define EINTR            4
#define EIO              5
#define EBADF            9
#define ECHILD          10
#define EAGAIN          11
#define EWOULDBLOCK     11
#define ENOMEM          12
#define EACCES          13
#define EFAULT          14
#define EBUSY           16
#define EEXIST          17
#define ENOTDIR         20
#define EISDIR          21
#define EINVAL          22
#define ENOSPC          28
#define EPIPE           32
#define ERANGE          34
#define ENAMETOOLONG    36
#define ENOSYS          38
#define ENOTEMPTY       39
#define ECONNRESET     104
#define ENOTCONN       107
#define ETIMEDOUT      110
#define ECONNREFUSED   111
#define EINPROGRESS    115
#define ETXTBSY         26
#endif
