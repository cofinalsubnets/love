#pragma once
#include <wchar.h>
/* the c locale: past ascii a wide character has no class, as in glibc */
typedef int wctype_t;
typedef int wctrans_t;
int iswalnum(wint_t);
int iswalpha(wint_t);
int iswblank(wint_t);
int iswcntrl(wint_t);
int iswdigit(wint_t);
int iswgraph(wint_t);
int iswlower(wint_t);
int iswprint(wint_t);
int iswpunct(wint_t);
int iswspace(wint_t);
int iswupper(wint_t);
int iswxdigit(wint_t);
wint_t towlower(wint_t);
wint_t towupper(wint_t);
wctype_t wctype(char const *);
int iswctype(wint_t, wctype_t);
