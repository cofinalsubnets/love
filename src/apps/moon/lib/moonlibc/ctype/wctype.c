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

/* the twelve classes by name, in wctype's order: wctype_t is the index + 1 */
static struct { char const *k; int (*f)(int); } const cls[] = {
  {"alnum", isalnum}, {"alpha", isalpha}, {"blank", isblank}, {"cntrl", iscntrl},
  {"digit", isdigit}, {"graph", isgraph}, {"lower", islower}, {"print", isprint},
  {"punct", ispunct}, {"space", isspace}, {"upper", isupper}, {"xdigit", isxdigit}};
static wctype_t ctname(char const *nm, size_t n) {
  for (int i = 0; i < 12; i++) if (strlen(cls[i].k) == n && !memcmp(nm, cls[i].k, n)) return i + 1;
  return 0; }
/* a bracket's [:name:], not nul-ended -> its byte test, NULL for no class: regex and fnmatch */
int (*__ctclass(char const *nm, size_t n))(int) {
  wctype_t t = ctname(nm, n);
  return t ? cls[t - 1].f : NULL; }
wctype_t wctype(char const *nm) { return ctname(nm, strlen(nm)); }
int iswctype(wint_t w, wctype_t t) { return t >= 1 && t <= 12 && ASC(w) && cls[t - 1].f((int) w); }
