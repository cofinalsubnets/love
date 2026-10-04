#include "../impl.h"
#include <wctype.h>

/* ---- wctype in the C locale: a wide character classifies as its ascii byte does, and
 * past ascii it is no class at all ---- */
#define ASC(w) ((w) < 128)
int iswalnum(wint_t w) { return ASC(w) && isalnum(w); }
int iswalpha(wint_t w) { return ASC(w) && isalpha(w); }
int iswblank(wint_t w) { return ASC(w) && isblank(w); }
int iswcntrl(wint_t w) { return ASC(w) && iscntrl(w); }
int iswdigit(wint_t w) { return ASC(w) && isdigit(w); }
int iswgraph(wint_t w) { return ASC(w) && isgraph(w); }
int iswlower(wint_t w) { return ASC(w) && islower(w); }
int iswprint(wint_t w) { return ASC(w) && isprint(w); }
int iswpunct(wint_t w) { return ASC(w) && ispunct(w); }
int iswspace(wint_t w) { return ASC(w) && isspace(w); }
int iswupper(wint_t w) { return ASC(w) && isupper(w); }
int iswxdigit(wint_t w) { return ASC(w) && isxdigit(w); }
wint_t towlower(wint_t w) { return ASC(w) ? (wint_t) tolower(w) : w; }
wint_t towupper(wint_t w) { return ASC(w) ? (wint_t) toupper(w) : w; }

static char const *const cls[] = {"alnum", "alpha", "blank", "cntrl", "digit", "graph",
                                  "lower", "print", "punct", "space", "upper", "xdigit"};
wctype_t wctype(char const *nm) {
  for (int i = 0; i < 12; i++) if (!strcmp(nm, cls[i])) return i + 1;
  return 0; }
int iswctype(wint_t w, wctype_t t) {
  switch (t) {
  case 1: return iswalnum(w); case 2: return iswalpha(w); case 3: return iswblank(w);
  case 4: return iswcntrl(w); case 5: return iswdigit(w); case 6: return iswgraph(w);
  case 7: return iswlower(w); case 8: return iswprint(w); case 9: return iswpunct(w);
  case 10: return iswspace(w); case 11: return iswupper(w); case 12: return iswxdigit(w);
  default: return 0; } }
