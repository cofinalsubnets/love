/* the C locale's multibyte face, as glibc's: one byte a character, ascii only. every byte
 * through btowc / mbrtowc / mbtowc, characters around the edges through wctob / wcrtomb /
 * wctomb, the string forms with their stopping points, and every wctype class and case map
 * over the same characters. a program starts in the C locale until it calls setlocale. */
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <wchar.h>
#include <wctype.h>
#include "say.h"

int main(void) {
  say_n("MB_CUR_MAX", (long) MB_CUR_MAX);
  for (int b = 0; b < 256; b += 3) {
    char c = (char) b; wchar_t w = 7; mbstate_t st; memset(&st, 0, sizeof st);
    errno = 0;
    say_n("byte", b); say_n("  btowc", (long) btowc(b));
    say_n("  mbrtowc", (long) mbrtowc(&w, &c, 1, &st)); say_n("  w", (long) w); say_n("  errno", errno);
    errno = 0; say_n("  mbtowc", mbtowc(&w, &c, 1)); say_n("  mblen", mblen(&c, 1)); say_n("  errno", errno); }
  wchar_t ws[] = {0, 9, 'a', 'Z', '5', ' ', 0x7f, 0x80, 0xe9, 0xff, 0x100, 0x20ac, -1};
  for (unsigned i = 0; i < sizeof ws / sizeof *ws; i++) {
    char b[8] = {0}; mbstate_t st; memset(&st, 0, sizeof st); wint_t w = ws[i];
    errno = 0;
    say_n("wide", (long) w); say_n("  wctob", wctob(w));
    say_n("  wcrtomb", (long) wcrtomb(b, ws[i], &st)); say_n("  errno", errno);
    errno = 0; say_n("  wctomb", wctomb(b, ws[i])); say_n("  errno", errno);
    char const *nm[] = {"alnum", "alpha", "blank", "cntrl", "digit", "graph", "lower", "print", "punct", "space", "upper", "xdigit"};
    for (int k = 0; k < 12; k++) { say_s("  class", nm[k]); say_n("    is", iswctype(w, wctype(nm[k])) != 0); }
    say_n("  iswalpha", iswalpha(w) != 0); say_n("  iswprint", iswprint(w) != 0); say_n("  iswspace", iswspace(w) != 0);
    say_n("  towupper", (long) towupper(w)); say_n("  towlower", (long) towlower(w)); }
  say_n("wctype.none", wctype("nope"));
  say_n("mbrtowc.null", (long) mbrtowc(0, 0, 0, 0)); say_n("mbtowc.null", mbtowc(0, 0, 0)); say_n("wctomb.null", wctomb(0, 'a'));
  say_n("mbrtowc.n0", (long) mbrtowc(0, "a", 0, 0)); say_n("mbsinit", mbsinit(0) != 0);
  wchar_t wb[16]; char cb[16];
  say_n("mbstowcs", (long) mbstowcs(wb, "hello", 16)); say_n("  wb4", wb[4]); say_n("wcslen", (long) wcslen(wb));
  say_n("mbstowcs.count", (long) mbstowcs(0, "hello world", 0));
  say_n("mbstowcs.short", (long) mbstowcs(wb, "hello", 3));
  errno = 0; say_n("mbstowcs.ill", (long) mbstowcs(wb, "ab\xc3\xa9", 16)); say_n("  errno", errno);
  say_n("wcstombs", (long) wcstombs(cb, wb, 16)); say_s("  cb", cb);
  wchar_t bad[] = {'a', 0x20ac, 0};
  errno = 0; say_n("wcstombs.ill", (long) wcstombs(cb, bad, 16)); say_n("  errno", errno);
  char const *src = "abc"; mbstate_t st; memset(&st, 0, sizeof st);
  say_n("mbsrtowcs", (long) mbsrtowcs(wb, &src, 2, &st)); say_n("  src.off", (long) (src ? src - "abc" + 0 : -1));
  return 0; }
