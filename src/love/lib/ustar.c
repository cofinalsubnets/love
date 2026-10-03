// ustar.c -- see ustar.h. no allocation and no io: every one of these reads bytes the
// caller already has, so the hosted lane and the freestanding one take the same file.
#include "ustar.h"
#include <string.h>

uintptr_t ai_ustar_octal(unsigned char const *p, int n) {
  uintptr_t v = 0;
  for (int i = 0; i < n && p[i] >= '0' && p[i] <= '7'; i++) v = v * 8 + (uintptr_t)(p[i] - '0');
  return v; }

bool ai_ustar_member(unsigned char const *h) {
  return (h[156] == '0' || h[156] == 0 || h[156] == '2') && !memcmp(h + 257, "ustar", 5); }

uintptr_t ai_ustar_name(unsigned char const *h, char *out, uintptr_t cap) {
  char nm[256];
  uintptr_t ln = 0;
  for (int i = 345; i < 500 && h[i] && ln < 254; i++) nm[ln++] = (char) h[i];
  if (ln) nm[ln++] = '/';
  for (int i = 0; i < 100 && h[i] && ln < 255; i++) nm[ln++] = (char) h[i];
  uintptr_t cut = 0;                                   // past TOP/
  while (cut < ln && nm[cut] != '/') cut++;
  cut = cut < ln ? cut + 1 : 0;
  uintptr_t n = ln - cut;
  if (n > cap) n = cap;
  memcpy(out, nm + cut, n);
  return n; }

uintptr_t ai_ustar_link(unsigned char const *h, char *out, uintptr_t cap) {
 uintptr_t n = 0;
 while (n < 100 && n < cap && h[157 + n]) out[n] = (char) h[157 + n], n++;
 return n; }

intptr_t ai_path_canon(char *out, uintptr_t n, char const *p, uintptr_t pn, uintptr_t cap) {
  for (uintptr_t i = 0; i < pn;) {
    while (i < pn && p[i] == '/') i++;
    uintptr_t j = i;
    while (j < pn && p[j] != '/') j++;
    uintptr_t k = j - i;
    if (!k) break;
    if (k == 1 && p[i] == '.') { i = j; continue; }
    if (k == 2 && p[i] == '.' && p[i + 1] == '.') {
      while (n && out[n - 1] != '/') n--;
      if (n) n--;
      i = j;
      continue; }
    if (n + k + 2 > cap) return -1;
    if (n) out[n++] = '/';
    memcpy(out + n, p + i, k), n += k;
    i = j; }
  return (intptr_t) n; }

uintptr_t ai_lnk_canon(char const *at, char const *ln, char *out, uintptr_t cap) {
  uintptr_t n = 0;
  if (ln[0] != '/') {
    uintptr_t d = strlen(at);
    while (d && at[d - 1] != '/') d--;
    if (d && d <= cap) memcpy(out, at, n = d - 1); }        // dirname, no trailing slash
  intptr_t r = ai_path_canon(out, n, ln, strlen(ln), cap);
  return r < 0 ? 0 : (uintptr_t) r; }
