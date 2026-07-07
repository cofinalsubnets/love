#ifndef _AI_UNISTD_H
#define _AI_UNISTD_H
typedef long ssize_t;
long read(int, void*, long);
long write(int, void const*, long);
int close(int);
long lseek(int, long, int);
int open(char const*, int, int);
long sysconf(int);
#define _SC_PAGESIZE 30
#endif
