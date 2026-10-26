#include "../impl.h"

/* a write-only stream into a growing heap buffer; *bp and *sp follow every write, and the
 * buffer outlives fclose, the caller's to free */
FILE *open_memstream(char **bp, size_t *sp) {
  FILE *f = malloc(sizeof(FILE));
  unsigned char *b = malloc(64);
  if (!f || !b) { free(f); free(b); return 0; }
  memset(f, 0, sizeof(FILE));
  f->fd = -1;
  f->wr = 1;
  f->heap = 1;
  f->buf = b; f->cap = 64; b[0] = 0;
  f->mp = bp; f->ms = sp;
  *bp = (char *) b; *sp = 0;
  __love_fopened(f);
  return f; }
