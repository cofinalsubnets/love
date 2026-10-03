#include "../impl.h"

/* ---- fgetpos, fsetpos: a position is ftell's offset ---- */
int fgetpos(FILE *f, fpos_t *p) {
  long o = ftell(f);
  if (o < 0) return -1;
  p->pos = o;
  return 0; }
int fsetpos(FILE *f, fpos_t const *p) { return fseek(f, p->pos, SEEK_SET); }
