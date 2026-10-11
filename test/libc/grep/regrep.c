/* regcomp's REG_GREP against gnu grep: seeded patterns over a fixed set of lines. `regrep lines`
 * prints the lines; `regrep` prints a pattern a row -- grep's flags, the pattern, and the lines it
 * matches, numbered as grep -n does (`bad` for a refusal). a repeat after an ERE anchor, or a
 * brace at a branch's head, is left out: grep reads those two ways, its dfa dropping the whole
 * interval and its regex just the brace, and which answers depends on the line. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <regex.h>

static unsigned s = 4242;
static unsigned rnd(unsigned n) { s = s * 1103515245u + 12345u; return (s >> 16) % n; }
#define N(a) (sizeof a / sizeof *a)
static char const *const ere[] = {"a", "b", ".", "*", "+", "?", "|", "(", ")", "[ab]", "[^a]", "{2}", "{1,2}",
  "{,2}", "{", "}", "{x", "{}", "^", "$", "[[:alpha:]]", "\\w", "\\b", "\\<", "(a|b)", "a*", "é", "É", "[^é]", "(.)\\1"};
static char const *const bre[] = {"a", "b", ".", "*", "\\+", "\\?", "\\|", "\\(", "\\)", "[ab]", "\\{2\\}", "\\{1,2\\}",
  "\\{", "\\}", "\\{x", "^", "$", "\\w", "\\<", "\\b", "\\(a\\|b\\)", "a*", "+", "{", "é", "É", "\\(.\\)\\1"};
static char const *const tx[] = {"a", "b", "A", "x", "1", " ", "_", "é", "É", "{", "}", "2", ",", "+", "*", "(", ")"};

/* the two-way shape: a sigil after ^ $ \< \> \b \B, or a brace at a branch's head, where only
 * skipped sigils stand before it */
static int twoway(char const *p) {
  for (int i = 0, head = 1; p[i]; i++) {
    int c = p[i], q = i ? p[i - 1] : 0, anc = q == '^' || q == '$' || (i > 1 && p[i - 2] == '\\' && strchr("<>bB", q));
    if (strchr("*+?{", c) && anc && (q != '^' || i < 2 || p[i - 2] != '[')) return 1;
    if (c == '{' && head) return 1;
    head = c == '(' || c == '|' || (head && strchr("*+?", c)); }
  return 0; }

int main(int argc, char **argv) {
  static char ln[48][32];
  for (int k = 0; k < 48; k++) for (int n = rnd(8); n--; ) strcat(ln[k], tx[rnd(N(tx))]);
  if (argc > 1) { for (int k = 0; k < 48; k++) printf("%s\n", ln[k]); return 0; }
  setlocale(LC_ALL, "C.UTF-8");
  for (int k = 0; k < 1500; ) {
    int ext = rnd(2), ic = rnd(4) == 0;
    char p[96] = "";
    for (int n = 1 + rnd(4); n--; ) strcat(p, ext ? ere[rnd(N(ere))] : bre[rnd(N(bre))]);
    if (ext && twoway(p)) continue;
    k++;
    regex_t re;
    printf("%s%s\t%s\t", ext ? "-E" : "-G", ic ? " -i" : "", p);
    if (regcomp(&re, p, REG_GREP | (ext ? REG_EXTENDED : 0) | (ic ? REG_ICASE : 0) | REG_NOSUB)) { printf("bad\n"); continue; }
    for (int i = 0; i < 48; i++) if (!regexec(&re, ln[i], 0, 0, 0)) printf("%d,", i + 1);
    printf("\n");
    regfree(&re); }
  return 0; }
