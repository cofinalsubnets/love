#include "../impl.h"
#include <wchar.h>

/* ---- the C locale's multibyte conversions: one byte a character, ascii only -- a byte or
 * a character past 0x7f is EILSEQ, as glibc's C locale answers. there is no shift state, so
 * an mbstate_t is only ever initial ---- */
static int ill(void) { errno = EILSEQ; return -1; }

wint_t btowc(int c) { return c >= 0 && c < 128 ? (wint_t) c : WEOF; }
int wctob(wint_t w) { return w < 128 ? (int) w : EOF; }
int mbsinit(mbstate_t const *ps) { (void) ps; return 1; }

size_t mbrtowc(wchar_t *pw, char const *s, size_t n, mbstate_t *ps) {
  (void) ps;
  if (!s) return 0;
  if (!n) return (size_t) -2;
  unsigned char c = (unsigned char) *s;
  if (c >= 128) return (size_t) ill();
  if (pw) *pw = c;
  return c ? 1 : 0; }
size_t mbrlen(char const *s, size_t n, mbstate_t *ps) { return mbrtowc(0, s, n, ps); }

size_t wcrtomb(char *s, wchar_t w, mbstate_t *ps) {
  (void) ps;
  if (!s) return 1;
  if (w < 0 || w >= 128) return (size_t) ill();
  *s = (char) w;
  return 1; }

int mbtowc(wchar_t *pw, char const *s, size_t n) {
  if (!s) return 0;
  if (!n) return -1;
  unsigned char c = (unsigned char) *s;
  if (c >= 128) return ill();
  if (pw) *pw = c;
  return c ? 1 : 0; }
int mblen(char const *s, size_t n) { return mbtowc(0, s, n); }
int wctomb(char *s, wchar_t w) {
  if (!s) return 0;
  if (w < 0 || w >= 128) return ill();
  *s = (char) w;
  return 1; }

/* the string forms: to the nul or n written, (size_t) -1 at an unconvertible one */
size_t mbsrtowcs(wchar_t *d, char const **src, size_t n, mbstate_t *ps) {
  (void) ps;
  char const *s = *src;
  size_t k = 0;
  for (; !d || k < n; k++, s++) {
    unsigned char c = (unsigned char) *s;
    if (c >= 128) { if (d) *src = s; return (size_t) ill(); }
    if (d) d[k] = c;
    if (!c) { if (d) *src = 0; return k; } }
  *src = s;
  return k; }
size_t wcsrtombs(char *d, wchar_t const **src, size_t n, mbstate_t *ps) {
  (void) ps;
  wchar_t const *s = *src;
  size_t k = 0;
  for (; !d || k < n; k++, s++) {
    wchar_t w = *s;
    if (w < 0 || w >= 128) { if (d) *src = s; return (size_t) ill(); }
    if (d) d[k] = (char) w;
    if (!w) { if (d) *src = 0; return k; } }
  *src = s;
  return k; }
size_t mbstowcs(wchar_t *d, char const *s, size_t n) { return mbsrtowcs(d, &s, n, 0); }
size_t wcstombs(char *d, wchar_t const *s, size_t n) { return wcsrtombs(d, &s, n, 0); }
size_t wcslen(wchar_t const *s) { size_t n = 0; while (s[n]) n++; return n; }
