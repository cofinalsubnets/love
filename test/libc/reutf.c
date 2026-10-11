/* regcomp and regexec under C.UTF-8, as glibc's: a literal, `.`, a bracket and \w \s take a
 * whole character, a repeat repeats all of one, classes and -i reach past ascii, word edges
 * read characters. each pattern's compile, then every text's match and groups, in bytes. a
 * range past ascii ([à-ü]) is not here: glibc's C.UTF-8 refuses it, grep's dialect takes it. */
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <regex.h>
#include "say.h"

static char const *const txt[] = {
  "", "a", "é", "aéb", "éé", "café au lait", "CAFÉ", "Ωmega ωmega", "ПРИВЕТ привет", "日本語テキスト",
  "x€y", "naïve façade", "ŝtono ĉevalo", "straße STRASSE", "σς Σ", "the ﬁne print", "a_b é_ê", "12 ٣٤",
  "tab\there", "line\nnext", "👍🏽 ok", "ÀÉÎÕÜ àéîõü", 0};

static void one(char const *pat, int fl) {
  regex_t re;
  int rc = regcomp(&re, pat, fl);
  say_s("pattern", pat); say_n("  flags", fl); say_n("  regcomp", rc);
  if (rc) return;
  say_u("  nsub", re.re_nsub);
  for (int t = 0; txt[t]; t++) {
    regmatch_t m[4];
    int r = regexec(&re, txt[t], 4, m, 0);
    if (r) continue;
    say_s("  text", txt[t]);
    for (int i = 0; i < 4; i++) { say_n("    so", m[i].rm_so); say_n("    eo", m[i].rm_eo); } }
  regfree(&re); }

int main(void) {
  say_s("setlocale", setlocale(LC_ALL, "C.UTF-8"));
  static char const *const ere[] = {
    "é", "é+", "aé*b", ".", "..", "^.$", "^..$", ".b", "a.b", "[é]", "[^é]", "[^a]+",
    "[[:alpha:]]+", "[[:upper:]]+", "[[:lower:]]+", "[[:punct:]]", "[[:digit:]]+",
    "[[:space:]]", "[[:alnum:]_]+", "\\w+", "\\W+", "\\s", "\\bé", "é\\b", "\\<\\w", "\\w\\>", "\\Bé",
    "(é)\\1", "(.)\\1", "(\\w+) \\1", "ω|Ω", "(ω|Ω)mega", "日本", "[日本]+", "テ.ス", "€",
    "[€$]", "x.y", "ß", "ss", "ﬁ", "σ", "ς", "Σ", "[σς]+", "👍", ".🏽", "[^[:ascii:]]", "[[:print:]]+",
    "é{2}", "(é|e)+", "[éa-c]+", "c[aá]f[eé]", 0};
  for (int k = 0; ere[k]; k++) one(ere[k], REG_EXTENDED);
  static char const *const ic[] = {
    "é", "É", "café", "CAFÉ", "[é]", "[É]", "ω", "Ω", "привет", "ПРИВЕТ",
    "straße", "σ", "Σ", "ς", "[[:upper:]]+", "[[:lower:]]+", "(é)\\1", "ŝ", "Ĉ", 0};
  for (int k = 0; ic[k]; k++) one(ic[k], REG_EXTENDED | REG_ICASE);
  static char const *const bre[] = {"é*", "\\(é\\)\\1", "^.\\{2\\}", "[[:alpha:]]\\+", 0};
  for (int k = 0; bre[k]; k++) one(bre[k], 0);
  return 0; }
