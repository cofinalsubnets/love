#pragma once
#include <wchar.h>
/* the c locale: past ascii a wide character has no class, as in glibc */
typedef int wctype_t;
typedef int wctrans_t;
int iswalnum(wint_t), iswalpha(wint_t), iswblank(wint_t), iswcntrl(wint_t), iswdigit(wint_t),
    iswgraph(wint_t), iswlower(wint_t), iswprint(wint_t), iswpunct(wint_t), iswspace(wint_t),
    iswupper(wint_t), iswxdigit(wint_t);
wint_t towlower(wint_t), towupper(wint_t);
wctype_t wctype(char const *);
int iswctype(wint_t, wctype_t);
