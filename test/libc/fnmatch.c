/* fnmatch against glibc's: every pattern against every name under each flag set, one line a
 * pattern and flag set, a 1 or 0 a name. the patterns reach star runs, ?, brackets (ranges,
 * negation both ways, classes, a ] first, an unclosed [), escapes, and the slash and leading
 * period rules */
#include <fnmatch.h>
#include <stdio.h>
#include "say.h"

static char const *pats[] = {
  "", "*", "**", "?", "a", "a*", "*a", "a*b", "a?b", "a**b", "*.c", ".*", "*/*", "a/*", "a/*/b",
  "*b*", "?*", "*?", "[abc]", "[a-c]x", "[!a]*", "[^a]*", "[]a]", "[!]]", "[a-]", "[-a]", "[[:digit:]]*",
  "[[:alpha:][:digit:]]?", "[[:space:]]", "[[:upper:]]*", "[[:punct:]]", "[[:xdigit:]][[:xdigit:]]",
  "[[:bogus:]]", "[a", "a[", "\\*", "\\?x", "a\\", "\\a", "[\\]]", "[\\!a]", "a/b", "a/b/c", "*/c",
  "a*/c", ".a", "*a.c", "A*", "[A-C]*", "[a-c]*", "x/[.]y", "x/.*", "x/*", "*x", "[*]", "[?]",
  "a[/]b", "a?c", "*/*/*", "[0-9][0-9]*", "\\[a]", "[]-a]*" };
static char const *names[] = {
  "", "a", "b", "ab", "abc", "acb", "a/b", "a/c", "a/b/c", "a/x/b", ".a", ".", "..", "x.c", ".c",
  "a.c", "aXc", "a]", "]", "!", "-", "*", "?", "\\", "a\\", "[", "a[", "1", "12a", "ABC", "x/.y",
  "x/y", "a/" };
static int const flags[] = { 0, FNM_PATHNAME, FNM_PERIOD, FNM_PATHNAME | FNM_PERIOD, FNM_NOESCAPE,
  FNM_CASEFOLD, FNM_LEADING_DIR, FNM_PATHNAME | FNM_LEADING_DIR, FNM_PATHNAME | FNM_PERIOD | FNM_CASEFOLD };

int main(void) {
  int np = sizeof pats / sizeof *pats, nn = sizeof names / sizeof *names, nf = sizeof flags / sizeof *flags;
  char row[64];
  for (int f = 0; f < nf; f++)
    for (int p = 0; p < np; p++) {
      for (int n = 0; n < nn; n++) row[n] = fnmatch(pats[p], names[n], flags[f]) == 0 ? '1' : '0';
      row[nn] = 0;
      say_s(pats[p], row); }
  say_n("nomatch", FNM_NOMATCH);
  return 0; }
