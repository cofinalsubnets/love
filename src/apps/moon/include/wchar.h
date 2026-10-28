#pragma once
#include <stddef.h>
/* the c locale's restartable conversions only: ascii, a byte past 0x7f is EILSEQ */
typedef unsigned int wint_t;
typedef struct { int count; unsigned value; } mbstate_t;
#define WEOF      ((wint_t) 0xffffffffu)
#ifdef __WCHAR_MAX__
#define WCHAR_MIN __WCHAR_MIN__
#define WCHAR_MAX __WCHAR_MAX__
#else
#define WCHAR_MIN (-2147483647 - 1)
#define WCHAR_MAX 2147483647
#endif
wint_t btowc(int);
int wctob(wint_t);
int mbsinit(mbstate_t const *);
size_t mbrlen(char const *, size_t, mbstate_t *);
size_t mbrtowc(wchar_t *, char const *, size_t, mbstate_t *);
size_t wcrtomb(char *, wchar_t, mbstate_t *);
size_t mbsrtowcs(wchar_t *, char const **, size_t, mbstate_t *);
size_t wcsrtombs(char *, wchar_t const **, size_t, mbstate_t *);
size_t wcslen(wchar_t const *);
