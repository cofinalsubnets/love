#include "../impl.h"
#include <wchar.h>

/* the C locale is ascii only (past 0x7f is EILSEQ, as glibc); a UTF-8 LC_CTYPE reads up to six
 * bytes, no overlong, no surrogate. mbstate_t holds length << 4 | bytes owed, and the bits so far */
static int ill(void) { errno = EILSEQ; return -1; }

wint_t btowc(int c) { return c >= 0 && c < 128 ? (wint_t) c : WEOF; }
int wctob(wint_t w) { return w < 128 ? (int) w : EOF; }
int mbsinit(mbstate_t const *ps) { return !ps || !ps->count; }

/* a lead byte: its length and payload, 0 for none; a tail byte after it, owe still owed */
static unsigned lead(unsigned c, unsigned *v) {
  if (c < 0xc2 || c > 0xfd) return 0;
  unsigned len = c < 0xe0 ? 2 : c < 0xf0 ? 3 : c < 0xf8 ? 4 : c < 0xfc ? 5 : 6;
  *v = c & (0x7fu >> len);
  return len; }
/* the second byte also says no overlong and no surrogate */
static int tail(unsigned len, unsigned owe, unsigned v, unsigned c) {
  return (c & 0xc0) == 0x80 && !(owe == len - 1 && ((!v && c < (0x80u | 0x40u >> (len - 2))) || (len == 3 && v == 13 && c >= 0xa0))); }

/* one whole utf-8 character at s[0..n) whatever the locale -> its length, -1 for none */
int __utf8(char const *s, size_t n, unsigned *w) {
  unsigned c = n ? (unsigned char) *s : 0, v, len;
  if (!n) return -1;
  if (c < 128) { *w = c; return 1; }
  if (!(len = lead(c, &v)) || n < len) return -1;
  for (unsigned k = 1; k < len; k++) {
    if (!tail(len, len - k, v, (unsigned char) s[k])) return -1;
    v = v << 6 | ((unsigned char) s[k] & 0x3f); }
  *w = v;
  return (int) len; }

size_t mbrtowc(wchar_t *pw, char const *s, size_t n, mbstate_t *ps) {
  static mbstate_t own;
  if (!ps) ps = &own;
  if (!s) { ps->count = 0; return 0; }
  if (!n) return (size_t) -2;
  unsigned len = (unsigned) ps->count >> 4, owe = (unsigned) ps->count & 15, v = ps->value;
  size_t k = 0;
  if (!owe) {
    unsigned c = (unsigned char) s[k++];
    if (c < 128) { if (pw) *pw = (wchar_t) c; return c ? 1 : 0; }
    if (!__love_utf8 || !(len = lead(c, &v))) return (size_t) ill();
    owe = len - 1; }
  for (; owe && k < n; k++, owe--) {
    unsigned c = (unsigned char) s[k];
    if (!tail(len, owe, v, c)) { ps->count = 0; return (size_t) ill(); }
    v = v << 6 | (c & 0x3f); }
  if (owe) { ps->count = (int) (len << 4 | owe); ps->value = v; return (size_t) -2; }
  ps->count = 0;
  if (pw) *pw = (wchar_t) v;
  return k; }
size_t mbrlen(char const *s, size_t n, mbstate_t *ps) { return mbrtowc(0, s, n, ps); }

size_t wcrtomb(char *s, wchar_t w, mbstate_t *ps) {
  (void) ps;
  if (!s) return 1;
  if (w >= 0 && w < 128) { *s = (char) w; return 1; }
  if (!__love_utf8 || w < 0 || (w >= 0xd800 && w < 0xe000)) return (size_t) ill();
  unsigned u = (unsigned) w, n = u < 0x800 ? 2 : u < 0x10000 ? 3 : u < 0x200000 ? 4 : u < 0x4000000 ? 5 : 6;
  s[0] = (char) ((0xff00u >> n & 0xff) | u >> 6 * (n - 1));
  for (unsigned i = 1; i < n; i++) s[i] = (char) (0x80 | (u >> 6 * (n - 1 - i) & 0x3f));
  return n; }

int mbtowc(wchar_t *pw, char const *s, size_t n) {
  if (!s) return 0;
  mbstate_t st = {0};
  size_t r = mbrtowc(pw, s, n, &st);
  return r == (size_t) -2 ? ill() : (int) r; }
int mblen(char const *s, size_t n) { return mbtowc(0, s, n); }
int wctomb(char *s, wchar_t w) { return s ? (int) wcrtomb(s, w, 0) : 0; }

/* the string forms: to the nul or n written, (size_t) -1 at an unconvertible one */
size_t mbsrtowcs(wchar_t *d, char const **src, size_t n, mbstate_t *ps) {
  char const *s = *src;
  size_t k = 0;
  for (; !d || k < n; k++) {
    wchar_t w;
    size_t r = mbrtowc(&w, s, 6, ps);
    if (r == (size_t) -1) { if (d) *src = s; return r; }
    if (d) d[k] = w;
    if (!r) { if (d) *src = 0; return k; }
    s += r; }
  *src = s;
  return k; }
size_t wcsrtombs(char *d, wchar_t const **src, size_t n, mbstate_t *ps) {
  wchar_t const *s = *src;
  size_t k = 0;
  for (;; s++) {
    char b[6];
    size_t r = wcrtomb(b, *s, ps);
    if (r == (size_t) -1) { if (d) *src = s; return r; }
    if (d && k + r > n) break;
    if (d) memcpy(d + k, b, r);
    if (!*s) { if (d) *src = 0; return k; }
    k += r; }
  *src = s;
  return k; }
size_t mbstowcs(wchar_t *d, char const *s, size_t n) { return mbsrtowcs(d, &s, n, 0); }
size_t wcstombs(char *d, wchar_t const *s, size_t n) { return wcsrtombs(d, &s, n, 0); }
size_t wcslen(wchar_t const *s) { size_t n = 0; while (s[n]) n++; return n; }
