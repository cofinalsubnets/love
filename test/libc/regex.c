/* regcomp, regexec, regerror: the compile's answer and re_nsub, then every match's answer
 * and all of pmatch, over patterns a kconfig search, a grep or a hostprog would write (BRE
 * and ERE, classes, intervals, back-references, the gnu escapes, REG_ICASE REG_NEWLINE
 * REG_NOSUB REG_NOTBOL REG_NOTEOL), every refusal and regerror's words for it, then a seeded
 * sweep. the sweep passes over a pattern holding an empty-matching group in a loop or an
 * empty group -- (a*)* () -- where which iteration a group reports is glibc's own
 * resolution and not posix's; whether and where such a pattern matches agrees. */
#include <stdlib.h>
#include <string.h>
#include <regex.h>
#include "say.h"

static void one(char const *pat, int fl, char const *const *txt, int ef) {
  regex_t re;
  int rc = regcomp(&re, pat, fl);
  say_s("pattern", pat); say_n("  flags", fl); say_n("  regcomp", rc);
  if (rc) {
    char buf[80];
    say_n("  regerror.len", (long) regerror(rc, &re, buf, sizeof buf)); say_s("  regerror", buf);
    return; }
  say_u("  nsub", re.re_nsub);
  for (; *txt; txt++) {
    regmatch_t m[6];
    say_s("  text", *txt);
    int r = regexec(&re, *txt, 6, m, ef);
    say_n("    regexec", r);
    if (!r && !(fl & REG_NOSUB))
      for (int i = 0; i < 6; i++) { say_n("    so", m[i].rm_so); say_n("    eo", m[i].rm_eo); } }
  regfree(&re); }

struct cs { char const *pat; int fl, ef; char const *txt[6]; };
static struct cs const C[] = {
  {"^CONFIG_", REG_EXTENDED, 0, {"CONFIG_NET", "XCONFIG_NET", "config_net"}},
  {"net", REG_EXTENDED | REG_ICASE, 0, {"CONFIG_NET_CORE", "ethernet", "nope"}},
  {"(usb|pci)_[a-z]+", REG_EXTENDED, 0, {"drivers/usb_core", "pci_hotplug x", "pcie"}},
  {"^([A-Z_]+)=(y|m)$", REG_EXTENDED, 0, {"CONFIG_A=y", "CONFIG_B=m", "CONFIG_C=n", "X=y\n"}},
  {"\\(ab\\)*c\\1", 0, 0, {"ababcab", "cab", "abcx"}},
  {"a\\{2,3\\}", 0, 0, {"a", "aa", "aaaa"}},
  {"x\\+y\\?", 0, 0, {"xxxy", "y", "xz"}},
  {"[[:digit:]]+\\.[[:digit:]]*", REG_EXTENDED, 0, {"v6.19.14", "6.", ".5"}},
  {"[^[:space:]]+$", REG_EXTENDED, 0, {"a b c", "trailing ", ""}},
  {"\\<word\\>", 0, 0, {"a word here", "swordfish", "word"}},
  {"\\bfoo\\B", REG_EXTENDED, 0, {"foobar", "foo bar", "a foox"}},
  {"^b", REG_EXTENDED | REG_NEWLINE, 0, {"a\nb", "ab", "b"}},
  {"a$", REG_EXTENDED | REG_NEWLINE, 0, {"a\nb", "ba", "b"}},
  {"^a", REG_EXTENDED, REG_NOTBOL, {"a", "ba", "a\na"}},
  {"a$", REG_EXTENDED, REG_NOTEOL, {"a", "ab"}},
  {"a.c", REG_EXTENDED | REG_NEWLINE, 0, {"abc", "a\nc"}},
  {"[]a-]+", REG_EXTENDED, 0, {"x]-ay", "b"}},
  {"(a|ab)(c|bcd)(d*)", REG_EXTENDED, 0, {"abcd"}},
  {"(.)\\1", REG_EXTENDED | REG_ICASE, 0, {"aA", "abc", "xyzz"}},
  {"a*", REG_EXTENDED | REG_NOSUB, 0, {"", "baaa"}},
  {"[[=a=]][[.-.]]", REG_EXTENDED, 0, {"a-", "b-"}},
  {"(a(b(c)))d", REG_EXTENDED, 0, {"xabcd"}},
  {"a{,2}b", REG_EXTENDED, 0, {"aaab", "b"}},
  /* refusals */
  {"a[", REG_EXTENDED, 0, {0}}, {"a(", REG_EXTENDED, 0, {0}}, {"a\\(", 0, 0, {0}}, {"a\\)", 0, 0, {0}},
  {"a{2", REG_EXTENDED, 0, {0}}, {"a{2,1}", REG_EXTENDED, 0, {0}}, {"a{x}", REG_EXTENDED, 0, {0}},
  {"*a", REG_EXTENDED, 0, {0}}, {"a**", 0, 0, {0}}, {"[[:nope:]]", 0, 0, {0}}, {"[z-a]", 0, 0, {0}},
  {"\\2(a)", REG_EXTENDED, 0, {0}}, {"a\\", 0, 0, {0}}, {"[[.ab.]]", 0, 0, {0}}, {"(a)|\\1", REG_EXTENDED, 0, {0}},
};

static unsigned seed = 777;
static unsigned rnd(unsigned n) { seed = seed * 1103515245u + 12345u; return (seed >> 16) % n; }

int main(void) {
  for (unsigned k = 0; k < sizeof C / sizeof *C; k++) one(C[k].pat, C[k].fl, C[k].txt, C[k].ef);
  char buf[64];
  for (int e = 0; e <= REG_ERPAREN; e++) {
    say_n("regerror.len", (long) regerror(e, 0, buf, sizeof buf)); say_s("regerror", buf);
    say_n("regerror.short", (long) regerror(e, 0, buf, 6)); say_s("regerror.cut", buf); }
  static char const *ere[] = {"a", "b", "c", ".", "*", "+", "?", "|", "(", ")", "[ab]", "[^a]", "{2}", "{1,2}", "{0,}",
    "^", "$", "\\1", "[[:alpha:]]", "\\w", "\\b", "x", "(a|b)", "a*", "[a-c]", "\\.", "{", "}", "]"};
  static char const *bre[] = {"a", "b", "c", ".", "*", "\\+", "\\?", "\\|", "\\(", "\\)", "[ab]", "[^a]", "\\{2\\}",
    "\\{1,2\\}", "^", "$", "\\1", "[[:digit:]]", "\\w", "\\<", "x", "\\(a\\|b\\)", "a*", "[a-c]", "\\.", "{", "+", "?"};
  for (int k = 0; k < 6000; k++) {
    int ext = rnd(2), ic = rnd(4) ? 0 : REG_ICASE, nl = rnd(4) ? 0 : REG_NEWLINE;
    int fl = (ext ? REG_EXTENDED : 0) | ic | nl;
    char pat[64] = ""; int np = 1 + rnd(6);
    for (int i = 0; i < np; i++) strcat(pat, ext ? ere[rnd(sizeof ere / sizeof *ere)] : bre[rnd(sizeof bre / sizeof *bre)]);
    static char tx[4][16]; char const *txt[5];
    int ef = rnd(5) ? 0 : REG_NOTBOL;
    for (int t = 0; t < 4; t++) {
      int nt = rnd(9);
      for (int i = 0; i < nt; i++) tx[t][i] = "abcAB.x\n1"[rnd(9)];
      tx[t][nt] = 0; txt[t] = tx[t]; }
    txt[4] = 0;
    if (strstr(pat, "()") || strstr(pat, "\\(\\)") || strstr(pat, "a*)*") || strstr(pat, "a*\\)*")) continue;
    one(pat, fl, txt, ef); }
  return 0; }
