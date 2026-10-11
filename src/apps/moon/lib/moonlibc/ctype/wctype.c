#include "../impl.h"
#include <wctype.h>
#include "ucd.h"

/* ---- wctype: a wide character in ascii classifies as its byte does. past ascii the C locale
 * gives it no class and no case, and a UTF-8 LC_CTYPE (num.c's setlocale) the unicode floor's
 * (ucd.c), glibc's C.UTF-8: digits stay 0-9, and graph and punct are print's less the rest ---- */
#define ASC(w) ((w) < 128)
#define UNI(w) (__love_utf8 && (w) <= 0x10ffff)
static int walpha(wint_t w) { return __ucd_in(ucd_alpha, w); }
static int wupper(wint_t w) { return __ucd_in(ucd_upper, w); }
static int wlower(wint_t w) { return __ucd_in(ucd_lower, w); }
static int wprint(wint_t w) { return __ucd_in(ucd_print, w); }
static int wspace(wint_t w) { return __ucd_in(ucd_space, w); }
static int wblank(wint_t w) { return __ucd_in(ucd_blank, w); }
static int wcntrl(wint_t w) { return __ucd_in(ucd_cntrl, w); }
static int wgraph(wint_t w) { return wprint(w) && !wspace(w); }
static int wpunct(wint_t w) { return wgraph(w) && !walpha(w); }
static int wnone(wint_t w) { (void) w; return 0; }

/* the twelve classes by name, in wctype's order (wctype_t is the index + 1): the byte test,
 * and the one past ascii */
static struct { char const *k; int (*f)(int); int (*u)(wint_t); } const cls[] = {
  {"alnum", isalnum, walpha}, {"alpha", isalpha, walpha}, {"blank", isblank, wblank},
  {"cntrl", iscntrl, wcntrl}, {"digit", isdigit, wnone}, {"graph", isgraph, wgraph},
  {"lower", islower, wlower}, {"print", isprint, wprint}, {"punct", ispunct, wpunct},
  {"space", isspace, wspace}, {"upper", isupper, wupper}, {"xdigit", isxdigit, wnone}};
static int is(int t, wint_t w) { return ASC(w) ? cls[t].f((int) w) != 0 : UNI(w) && cls[t].u(w); }
int iswalnum(wint_t w) { return is(0, w); }
int iswalpha(wint_t w) { return is(1, w); }
int iswblank(wint_t w) { return is(2, w); }
int iswcntrl(wint_t w) { return is(3, w); }
int iswdigit(wint_t w) { return is(4, w); }
int iswgraph(wint_t w) { return is(5, w); }
int iswlower(wint_t w) { return is(6, w); }
int iswprint(wint_t w) { return is(7, w); }
int iswpunct(wint_t w) { return is(8, w); }
int iswspace(wint_t w) { return is(9, w); }
int iswupper(wint_t w) { return is(10, w); }
int iswxdigit(wint_t w) { return is(11, w); }
wint_t towlower(wint_t w) { return ASC(w) ? (wint_t) tolower((int) w) : UNI(w) ? __ucd_map(0, w) : w; }
wint_t towupper(wint_t w) { return ASC(w) ? (wint_t) toupper((int) w) : UNI(w) ? __ucd_map(1, w) : w; }

/* a class by name, not nul-ended -> wctype's index, 0 for none; then for regex and fnmatch
 * its byte test, and its test past ascii whatever the locale */
wctype_t __ctname(char const *nm, size_t n) {
  for (int i = 0; i < 12; i++) if (strlen(cls[i].k) == n && !memcmp(nm, cls[i].k, n)) return i + 1;
  return 0; }
int (*__ctclass(char const *nm, size_t n))(int) {
  wctype_t t = __ctname(nm, n);
  return t ? cls[t - 1].f : NULL; }
int __ctwide(wctype_t t, wint_t w) { return t >= 1 && t <= 12 && w <= 0x10ffff && cls[t - 1].u(w); }
wctype_t wctype(char const *nm) { return __ctname(nm, strlen(nm)); }
int iswctype(wint_t w, wctype_t t) { return t >= 1 && t <= 12 && is(t - 1, w); }
