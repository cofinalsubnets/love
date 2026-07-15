#ifndef _AI_STDLIB_H
#define _AI_STDLIB_H
#ifndef NULL
#define NULL ((void*)0)
#endif
typedef unsigned long size_t;
void *malloc(size_t);
void *calloc(size_t, size_t);
void *realloc(void*, size_t);
void  free(void*);
void  exit(int);
void  abort(void);
int   atexit(void (*)(void));
char *getenv(char const*);
int   setenv(char const*, char const*, int);
int   unsetenv(char const*);
int   atoi(char const*);
long  strtol(char const*, char**, int);
unsigned long strtoul(char const*, char**, int);
/* the pty quartet lives here in glibc (stdlib.h, not pty.h) */
int   posix_openpt(int);
int   grantpt(int);
int   unlockpt(int);
char *ptsname(int);
#endif
