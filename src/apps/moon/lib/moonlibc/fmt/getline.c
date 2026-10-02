#include "../impl.h"

/* posix 2008: *buf grows by realloc to hold the record and its nul; -1 at eof with none read */
ssize_t getdelim(char **buf, size_t *cap, int delim, FILE *f) {
  size_t i = 0;
  if (!buf || !cap) { errno = EINVAL; return -1; }
  if (!*buf) *cap = 0;
  for (;;) {
    int c = getc(f);
    if (c == EOF && i == 0) return -1;
    if (i + 2 > *cap) {
      size_t n = *cap < 64 ? 128 : *cap * 2;
      char *p = realloc(*buf, n);
      if (!p) { errno = ENOMEM; return -1; }
      *buf = p; *cap = n; }
    if (c == EOF) break;
    (*buf)[i++] = (char) c;
    if (c == delim) break; }
  (*buf)[i] = 0;
  return (ssize_t) i; }

ssize_t getline(char **buf, size_t *cap, FILE *f) { return getdelim(buf, cap, 10, f); }
