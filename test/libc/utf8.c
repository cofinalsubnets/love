/* the C.UTF-8 locale's multibyte face, as glibc's: setlocale's answers, utf-8 through mbrtowc
 * (whole, torn across calls, every way a sequence can be wrong), wcrtomb at the edges, the
 * string forms, then every wctype class and case map over a stride of code points and the
 * cases that move. the C locale comes back at the end, and with it one byte a character. */
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <locale.h>
#include <wchar.h>
#include <wctype.h>
#include "say.h"

static void mb(char const *tag, char const *s, size_t n) {
  wchar_t w = 7; mbstate_t st; memset(&st, 0, sizeof st);
  errno = 0;
  say_s("mb", tag); say_n("  r", (long) mbrtowc(&w, s, n, &st)); say_n("  w", (long) w);
  say_n("  errno", errno); say_n("  init", mbsinit(&st) != 0); }

static void cls(wint_t w) {
  char const *nm[] = {"alnum", "alpha", "blank", "cntrl", "digit", "graph", "lower", "print", "punct", "space", "upper", "xdigit"};
  long m = 0;
  for (int k = 0; k < 12; k++) m = m * 2 + (iswctype(w, wctype(nm[k])) != 0);
  say_n("cp", (long) w); say_n("  classes", m);
  say_n("  upper", (long) towupper(w)); say_n("  lower", (long) towlower(w)); }

int main(void) {
  say_n("MB_CUR_MAX.C", (long) MB_CUR_MAX);
  say_s("setlocale", setlocale(LC_ALL, "C.UTF-8"));
  say_s("query", setlocale(LC_CTYPE, 0));
  say_n("MB_CUR_MAX", (long) MB_CUR_MAX);
  say_n("refused", setlocale(LC_ALL, "no-such-locale") == 0);
  mb("ascii", "a", 1); mb("nul", "", 1);
  mb("e-acute", "\xc3\xa9", 2); mb("euro", "\xe2\x82\xac", 3); mb("emoji", "\xf0\x9f\x91\x8d", 4);
  mb("last", "\xf4\x8f\xbf\xbf", 4); mb("short", "\xe2\x82", 2); mb("n1", "\xe2\x82\xac", 1);
  mb("overlong2", "\xc0\xaf", 2); mb("overlong3", "\xe0\x80\xaf", 3); mb("overlong4", "\xf0\x80\x80\xaf", 4);
  mb("surrogate", "\xed\xa0\x80", 3); mb("past", "\xf4\x90\x80\x80", 4); mb("f5", "\xf5\x80\x80\x80", 4);
  mb("lone-tail", "\x80", 1); mb("bad-tail", "\xc3\x41", 2);
  mb("five", "\xf8\x88\x80\x80\x80", 5); mb("six", "\xfd\xbf\xbf\xbf\xbf\xbf", 6);
  mb("overlong5", "\xf8\x87\xbf\xbf\xbf", 5); mb("overlong6", "\xfc\x83\xbf\xbf\xbf\xbf", 6);
  mb("fe", "\xfe\x80", 2);
  /* one character fed a byte at a time */
  { mbstate_t st; memset(&st, 0, sizeof st); wchar_t w = 0; char const *e = "\xf0\x9f\x91\x8d";
    for (int i = 0; i < 4; i++) { say_n("torn", i); say_n("  r", (long) mbrtowc(&w, e + i, 1, &st)); }
    say_n("  w", (long) w); }
  wchar_t ws[] = {0, 'a', 0x7f, 0x80, 0xe9, 0x7ff, 0x800, 0x20ac, 0xd7ff, 0xd800, 0xdfff, 0xe000, 0xffff,
                  0x10000, 0x1f44d, 0x10ffff, 0x110000, 0x1fffff, 0x200000, 0x3ffffff, 0x4000000, 0x7fffffff, -1};
  for (unsigned i = 0; i < sizeof ws / sizeof *ws; i++) {
    char b[8] = {0}; mbstate_t st; memset(&st, 0, sizeof st);
    errno = 0;
    say_n("wide", (long) ws[i]); say_n("  wcrtomb", (long) wcrtomb(b, ws[i], &st)); say_n("  errno", errno);
    say_n("  b0", (unsigned char) b[0]); say_n("  b3", (unsigned char) b[3]); say_n("  b5", (unsigned char) b[5]);
    say_n("  wctob", wctob((wint_t) ws[i])); say_n("  btowc", (long) btowc((int) ws[i])); }
  say_n("mblen", mblen("\xe2\x82\xac", 3)); say_n("mblen.short", mblen("\xe2\x82", 2));
  wchar_t wb[16]; char cb[32];
  say_n("mbstowcs", (long) mbstowcs(wb, "a\xc3\xa9\xe2\x82\xac", 16)); say_n("  wb2", wb[2]);
  errno = 0; say_n("mbstowcs.ill", (long) mbstowcs(wb, "ab\xc3", 16)); say_n("  errno", errno);
  say_n("wcstombs", (long) wcstombs(cb, (wchar_t[]) {'a', 0xe9, 0x20ac, 0x1f44d, 0}, 32));
  say_n("  cb1", (unsigned char) cb[1]); say_n("  cb9", (unsigned char) cb[9]);
  say_n("wcstombs.short", (long) wcstombs(cb, (wchar_t[]) {'a', 0x20ac, 0}, 3));
  for (wint_t w = 0; w < 0x110000; w += 97) cls(w);
  wint_t edge[] = {0xb5, 0xdf, 0x130, 0x131, 0x17f, 0x1c5, 0x3c2, 0x1e9e, 0x2126, 0x212a, 0x1c80, 0xff21, 0x10400, 0x1e900, 0x2160, 0x24b6};
  for (unsigned i = 0; i < sizeof edge / sizeof *edge; i++) cls(edge[i]);
  say_s("back", setlocale(LC_ALL, "C"));
  say_n("MB_CUR_MAX.back", (long) MB_CUR_MAX); mb("back", "\xc3\xa9", 2); cls(0xe9);
  return 0; }
