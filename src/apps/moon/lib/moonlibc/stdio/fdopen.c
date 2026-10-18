#include "../impl.h"

/* the mode is trusted, not checked against the fd's flags: a wrong one is the caller's bug */
FILE *fdopen(int fd, char const *mode) {
  int wr = 0;
  if (mode[0] == 'w' || mode[0] == 'a') wr = 1;
  for (char const *m = mode + 1; *m; m++)
    if (*m == '+') wr = 1;
  if (fd < 0) return 0;
  FILE *f = malloc(sizeof(FILE) + 4096);
  if (!f) return 0;
  memset(f, 0, sizeof(FILE));
  f->fd = fd;
  f->wr = wr;
  f->heap = 1;
  if (wr) { f->buf = (unsigned char *) (f + 1); f->cap = 4096; }
  else { f->rb = (unsigned char *) (f + 1); f->rcap = 4096; }
  __love_fopened(f);
  return f; }
