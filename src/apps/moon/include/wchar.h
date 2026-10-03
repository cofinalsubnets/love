#ifndef _AI_WCHAR_H
#define _AI_WCHAR_H
#include <stddef.h>
/* C11 7.29: the types and limits, and the restartable conversions of the C locale -- plain
   ascii, as glibc's is: a byte or a character past 0x7f is EILSEQ. no wide strings or wide
   streams beyond these. */
typedef unsigned int wint_t;
typedef struct { int count; } mbstate_t;
#define WEOF      ((wint_t) 0xffffffffu)
#define WCHAR_MIN (-2147483647 - 1)
#define WCHAR_MAX 2147483647
wint_t btowc(int);
int wctob(wint_t);
int mbsinit(mbstate_t const *);
size_t mbrlen(char const *, size_t, mbstate_t *);
size_t mbrtowc(wchar_t *, char const *, size_t, mbstate_t *);
size_t wcrtomb(char *, wchar_t, mbstate_t *);
size_t mbsrtowcs(wchar_t *, char const **, size_t, mbstate_t *);
size_t wcsrtombs(char *, wchar_t const **, size_t, mbstate_t *);
size_t wcslen(wchar_t const *);
#endif
