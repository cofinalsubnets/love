#include "../impl.h"

int fgetpos(FILE *f, fpos_t *p) {
  off_t o = ftello(f);
  if (o < 0) return -1;
  p->pos = o;
  return 0; }
int fsetpos(FILE *f, fpos_t const *p) { return fseeko(f, p->pos, SEEK_SET); }
