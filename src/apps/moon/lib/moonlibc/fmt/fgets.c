#include "../impl.h"

/* over getc, so an ungetc pushback is honoured */
char *fgets(char *buf, int n, FILE *f) {
  int i = 0;
  while (i < n - 1) {
    int c = getc(f);
    if (c == EOF) { if (i == 0) return 0; break; }
    buf[i++] = (char) c;
    if (c == 10) break; }
  buf[i] = 0;
  return buf; }
