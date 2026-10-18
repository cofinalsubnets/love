#ifndef _LOVE_STDLIB_H
#define _LOVE_STDLIB_H
#ifndef NULL
#define NULL ((void*)0)
#endif
#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1
typedef unsigned long size_t;
typedef int wchar_t;
void *malloc(size_t);
void *calloc(size_t, size_t);
void *realloc(void*, size_t);
void *reallocarray(void*, size_t, size_t);
void  free(void*);
void *aligned_alloc(size_t, size_t);
int   posix_memalign(void**, size_t, size_t);
const char *getprogname(void);
void  exit(int);
void  abort(void);
int   atexit(void (*)(void));
void  qsort(void*, size_t, size_t, int (*)(void const*, void const*));
void *bsearch(void const*, void const*, size_t, size_t, int (*)(void const*, void const*));
char *getenv(char const*);
char *mktemp(char*);
int   mkstemp(char*);
int   setenv(char const*, char const*, int);
int   unsetenv(char const*);
int   atoi(char const*);
long  atol(char const*);
double atof(char const*);
long  strtol(char const*, char**, int);
unsigned long strtoul(char const*, char**, int);
long long strtoll(char const*, char**, int);
unsigned long long strtoull(char const*, char**, int);
double strtod(char const*, char**);
int   system(char const*);
int   abs(int);
long  labs(long);
long long llabs(long long);
/* the pty quartet lives here in glibc */
int   posix_openpt(int);
int   grantpt(int);
int   unlockpt(int);
char *ptsname(int);
/* our own generators: a seed does not give glibc's sequence */
#define RAND_MAX 32767
int  rand(void);
void srand(unsigned int);
long random(void);
void srandom(unsigned int);
/* multibyte: one byte a character until setlocale names a utf-8 LC_CTYPE */
extern int __love_utf8;
#define MB_CUR_MAX ((size_t) (__love_utf8 ? 6 : 1))
int mblen(char const *, size_t);
int mbtowc(wchar_t *, char const *, size_t);
int wctomb(char *, wchar_t);
size_t mbstowcs(wchar_t *, char const *, size_t);
size_t wcstombs(char *, wchar_t const *, size_t);
#endif
