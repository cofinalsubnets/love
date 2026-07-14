#ifndef _AI_FCNTL_H
#define _AI_FCNTL_H
/* Linux x86-64 values (octal in the kernel; spelled decimal here) */
#define O_RDONLY         0
#define O_WRONLY         1
#define O_RDWR           2
#define O_CREAT         64
#define O_EXCL         128
#define O_NOCTTY       256
#define O_TRUNC        512
#define O_APPEND      1024
#define O_NONBLOCK    2048
#ifdef __aarch64__
#define O_DIRECTORY  16384   /* asm-generic 040000 */
#else
#define O_DIRECTORY  65536   /* x86 0200000 */
#endif
#define O_CLOEXEC   524288
#define AT_FDCWD      (-100)
#define F_GETFD          1
#define F_SETFD          2
#define F_GETFL          3
#define F_SETFL          4
#define FD_CLOEXEC       1
int open(char const*, int, ...);
int fcntl(int, int, ...);
#endif
