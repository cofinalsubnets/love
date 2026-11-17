#pragma once
#ifndef NULL
#define NULL ((void*)0)
#endif
#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1
typedef unsigned long size_t;
typedef int wchar_t;
#include <alloca.h>   /* as glibc's default features lay it */
void *malloc(size_t), *calloc(size_t, size_t), *realloc(void*, size_t),
     *reallocarray(void*, size_t, size_t), free(void*), *aligned_alloc(size_t, size_t);
int   posix_memalign(void**, size_t, size_t);
const char *getprogname(void);
void exit(int), abort(void);
int   atexit(void (*)(void));
void qsort(void*, size_t, size_t, int (*)(void const*, void const*)),
     *bsearch(void const*, void const*, size_t, size_t, int (*)(void const*, void const*));
char *getenv(char const*), *mktemp(char*), *realpath(char const*, char*);
int   mkstemp(char*);
char *mkdtemp(char*);
int setenv(char const*, char const*, int), unsetenv(char const*), putenv(char*), atoi(char const*);
long  atol(char const*);
double atof(char const*);
long  strtol(char const*, char**, int);
unsigned long strtoul(char const*, char**, int);
long long strtoll(char const*, char**, int);
unsigned long long strtoull(char const*, char**, int);
double strtod(char const*, char**);
float strtof(char const*, char**);
long double strtold(char const*, char**);
int system(char const*), abs(int);
long  labs(long);
long long llabs(long long);
typedef struct { int quot, rem; } div_t;
typedef struct { long quot, rem; } ldiv_t;
typedef struct { long long quot, rem; } lldiv_t;
div_t   div(int, int);
ldiv_t  ldiv(long, long);
lldiv_t lldiv(long long, long long);
/* the pty quartet lives here in glibc */
int posix_openpt(int), grantpt(int), unlockpt(int);
char *ptsname(int);
int   ptsname_r(int, char*, size_t);
/* our own generators: a seed does not give glibc's sequence */
#define RAND_MAX 32767
int  rand(void);
void srand(unsigned int);
long random(void);
void srandom(unsigned int);
/* multibyte: one byte a character until setlocale names a utf-8 LC_CTYPE */
extern int __love_utf8;
#define MB_CUR_MAX ((size_t) (__love_utf8 ? 6 : 1))
int mblen(char const *, size_t), mbtowc(wchar_t *, char const *, size_t), wctomb(char *, wchar_t);
size_t mbstowcs(wchar_t *, char const *, size_t), wcstombs(char *, wchar_t const *, size_t);
