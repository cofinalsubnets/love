#include "../impl.h"

/* bsd: always terminated, answers the length it tried to make */
size_t strlcpy(char *d, char const *s, size_t n) {
  size_t k = strlen(s);
  if (n) { size_t c = k < n ? k : n - 1; memcpy(d, s, c); d[c] = 0; }
  return k; }

size_t strlcat(char *d, char const *s, size_t n) {
  size_t m = strnlen(d, n);
  return m == n ? n + strlen(s) : m + strlcpy(d + m, s, n - m); }
