#pragma once
#include <sys/types.h>
/* linux x86-64's values, in decimal, on every kernel; the bsds take them translated */
#define O_RDONLY         0
#define O_WRONLY         1
#define O_RDWR           2
#define O_CREAT         64
#define O_EXCL         128
#define O_NOCTTY       256
#define O_TRUNC        512
#define O_APPEND      1024
#define O_NONBLOCK    2048
/* a64 keeps 32-bit arm's values for these two; rv64 takes asm-generic's, which are x86-64's */
#if defined(__aarch64__) || defined(__arm__)
#define O_DIRECTORY  16384   /* arm/a64 040000 */
#define O_NOFOLLOW   32768   /* arm/a64 0100000 */
#else
#define O_DIRECTORY  65536   /* x86-64, rv64, asm-generic 0200000 */
#define O_NOFOLLOW  131072   /* x86-64, rv64, asm-generic 0400000 */
#endif
#define O_CLOEXEC   524288
#ifdef __i386__
#define O_LARGEFILE 32768  /* off_t is 64-bit, so every open asks for it */
#elif defined(__ARM_EABI__)
#define O_LARGEFILE 131072 /* arm's 0400000 */
#else
#define O_LARGEFILE 0      /* glibc's on 64-bit: every open is large already */
#endif
#define O_SEARCH   O_RDONLY   /* linux has no O_SEARCH */
#define O_BINARY         0    /* dos-isms: no-ops here */
#define O_TEXT           0
#define AT_FDCWD      (-100)
#define AT_SYMLINK_NOFOLLOW 256
#define AT_REMOVEDIR        512
/* linux only, for fexecve */
#define AT_EMPTY_PATH      4096
#define F_DUPFD          0
#define F_GETFD          1
#define F_SETFD          2
#define F_GETFL          3
#define F_SETFL          4
#define FD_CLOEXEC       1
#define F_DUPFD_CLOEXEC 1030   /* F_LINUX_SPECIFIC_BASE (1024) + 6 */
/* posix record locks */
#define F_GETLK          5
#define F_SETLK          6
#define F_SETLKW         7
#define F_RDLCK          0
#define F_WRLCK          1
#define F_UNLCK          2
struct flock {
  short l_type;
  short l_whence;
  off_t l_start;   /* i386: flock64's record, asked for by F_*LK64 */
  off_t l_len;
  int   l_pid;
};
int open(char const*, int, ...);
int openat(int, char const*, int, ...);
int creat(char const*, unsigned int);
int fcntl(int, int, ...);
