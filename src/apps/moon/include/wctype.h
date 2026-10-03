#ifndef _AI_WCTYPE_H
#define _AI_WCTYPE_H
#include <wchar.h>
/* C11 7.30 in the C locale: a wide character classifies as its ascii byte does, and past
   ascii it is no class at all, as glibc's C locale answers */
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
#endif
