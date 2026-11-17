#include "../impl.h"

/* a read-write stream reads unbuffered */
int getc(FILE *f) {
  unsigned char c;
  if (f->un) { int r = f->un - 1; f->un = 0; return r; }
  if (f->rcap) {
    if (f->rp == f->rl && __rfill(f) <= 0) return EOF;
    return f->rb[f->rp++]; }
  long k = read(f->fd, &c, 1);
  if (k <= 0) { if (k < 0) f->err = 1; else f->eof = 1; return EOF; }
  return c; }
int ungetc(int c, FILE *f) {
  if (c == EOF || f->un) return EOF;
  f->un = (c & 255) + 1;
  f->eof = 0;
  return c & 255; }
int fgetc(FILE *f) { return getc(f); }
int getchar(void) { return getc(stdin); }
