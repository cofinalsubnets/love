#include "../impl.h"
#include <wchar.h>

/* wchar_t compares as its own type, signed here as in glibc */
int wcscmp(wchar_t const *a, wchar_t const *b) {
  while (*a && *a == *b) a++, b++;
  return *a < *b ? -1 : *a > *b; }
wchar_t *wcsstr(wchar_t const *h, wchar_t const *n) {
  if (!*n) return (wchar_t *) h;
  for (; *h; h++) {
    size_t i = 0;
    while (n[i] && h[i] == n[i]) i++;
    if (!n[i]) return (wchar_t *) h; }
  return 0; }
