#include "../impl.h"
#include <fnmatch.h>
#include <ctype.h>

static int __fnfold(int c, int fl) { return (fl & FNM_CASEFOLD) ? tolower(c) : c; }

/* a bracket at p (just past the '['): matched -> 1, not -> 0, and *end past its ']'; a bracket
 * that never closes answers -1, and the '[' is then an ordinary character */
static int __fnbracket(char const *p, int c, int fl, char const **end) {
  int neg = *p == '!' || *p == '^', hit = 0;
  if (neg) p++;
  int first = 1;
  for (;;) {
    if (!*p) return -1;
    if (*p == ']' && !first) break;
    first = 0;
    if (*p == '[' && p[1] == ':') {
      char const *q = p + 2;
      while (*q && !(*q == ':' && q[1] == ']')) q++;
      if (*q) {
        int (*f)(int) = __ctclass(p + 2, (size_t) (q - p - 2));
        if (f) { hit |= f(c) != 0; p = q + 2; continue; } } }
    int lo = (unsigned char) *p;
    if (lo == '\\' && !(fl & FNM_NOESCAPE) && p[1]) lo = (unsigned char) *++p;
    if ((fl & FNM_PATHNAME) && lo == '/') return -1;
    p++;
    int hi = lo;
    if (*p == '-' && p[1] && p[1] != ']') {
      hi = (unsigned char) p[1];
      if (hi == '\\' && !(fl & FNM_NOESCAPE) && p[2]) { hi = (unsigned char) p[2]; p++; }
      p += 2; }
    if (fl & FNM_CASEFOLD) { int f = tolower(c); if ((tolower(lo) <= f && f <= tolower(hi)) || (lo <= c && c <= hi)) hit = 1; }
    else if (lo <= c && c <= hi) hit = 1; }
  *end = p + 1;
  return hit ^ neg; }

/* is the name's character at s the leading period FNM_PERIOD protects? */
static int __fnlead(char const *n0, char const *s, int fl) {
  return (fl & FNM_PERIOD) && *s == '.' && (s == n0 || ((fl & FNM_PATHNAME) && s[-1] == '/')); }

/* only the last star backtracks: a later star's starts cover what moving an earlier one
 * would give, and under FNM_PATHNAME none crosses a '/' */
static int __fnm(char const *p, char const *s, char const *n0, int fl) {
  char const *sp = 0, *ss = 0;                       /* past the last star, and where it ends */
  for (;;) {
    int c = (unsigned char) *p;
    if (c == '*') {
      while (p[1] == '*') p++;
      if (__fnlead(n0, s, fl)) return FNM_NOMATCH;
      if (!p[1]) {                                   /* a trailing star */
        if (!(fl & FNM_PATHNAME) || (fl & FNM_LEADING_DIR)) return 0;
        return strchr(s, '/') ? FNM_NOMATCH : 0; }
      sp = ++p, ss = s;
      continue; }
    if (!c) {
      if (*s == 0 || ((fl & FNM_LEADING_DIR) && *s == '/')) return 0;
      goto back; }
    if (!*s) goto back;
    if ((fl & FNM_PATHNAME) && *s == '/' && c != '/') goto back;
    if (c == '?') { if (__fnlead(n0, s, fl)) goto back; p++, s++; continue; }
    if (c == '[') {
      char const *end;
      if (__fnlead(n0, s, fl)) goto back;
      int m = __fnbracket(p + 1, (unsigned char) *s, fl, &end);
      if (m >= 0) { if (!m) goto back; p = end, s++; continue; } }   /* unclosed: a literal [ */
    if (c == '\\' && !(fl & FNM_NOESCAPE)) {       /* an escape with nothing after it matches nothing */
      if (!p[1]) goto back;
      c = (unsigned char) *++p; }
    if (__fnfold(c, fl) != __fnfold((unsigned char) *s, fl)) goto back;
    p++, s++;
    continue;
   back:                                             /* the last star takes one more character */
    if (!sp || !*ss || ((fl & FNM_PATHNAME) && *ss == '/')) return FNM_NOMATCH;
    p = sp, s = ++ss; } }

int fnmatch(char const *pat, char const *name, int fl) { return __fnm(pat, name, name, fl); }
