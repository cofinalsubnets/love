#include "../impl.h"

size_t strnlen(char const *s, size_t n) {
  size_t i = 0;
  while (i < n && s[i]) i++;
  return i; }

char *strndup(char const *s, size_t n) {
  size_t k = strnlen(s, n);
  char *d = malloc(k + 1);
  if (d) { memcpy(d, s, k); d[k] = 0; }
  return d; }
