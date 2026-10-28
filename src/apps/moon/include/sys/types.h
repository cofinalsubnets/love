#pragma once
typedef unsigned long size_t;
typedef long   ssize_t;
typedef int    pid_t;
typedef unsigned int uid_t;
typedef unsigned int gid_t;
typedef unsigned int id_t;
typedef unsigned int mode_t;
#ifdef __ILP32__
typedef long long off_t;
typedef unsigned long long dev_t;
typedef unsigned long long ino_t;
typedef long long time_t;
typedef long long blkcnt_t;
#else
typedef long   off_t;
typedef unsigned long dev_t;
typedef unsigned long ino_t;
typedef long   time_t;
typedef long   blkcnt_t;
#endif
typedef unsigned long nlink_t;
typedef long   suseconds_t;
typedef long   blksize_t;
typedef long   clock_t;
/* the bsd spellings glibc carries under _DEFAULT_SOURCE */
typedef unsigned char  u_char;
typedef unsigned short u_short;
typedef unsigned int   u_int;
typedef unsigned long  u_long;
typedef unsigned short ushort;
typedef unsigned int   uint;
typedef unsigned long  ulong;
typedef char          *caddr_t;
#include <sys/select.h>   /* as glibc does */
