#include "../impl.h"

/* C: the next input of any kind sees an ungetc'd byte, so fread takes the pushback first */
size_t fread(void *p, size_t sz, size_t n, FILE *f) {
  size_t total = sz * n, got = 0;
  unsigned char *d = p;
  if (total && f->un) { d[got++] = (unsigned char) (f->un - 1); f->un = 0; }
  while (got < total && f->rcap) {           /* the read-ahead first; a span past a buffer reads direct */
    if (f->rp < f->rl) {
      size_t k = (size_t) (f->rl - f->rp);
      if (k > total - got) k = total - got;
      memcpy(d + got, f->rb + f->rp, k);
      f->rp += (int) k; got += k; continue; }
    if (total - got >= (size_t) f->rcap) break;
    if (__rfill(f) <= 0) return sz ? got / sz : 0; }
  while (got < total) {
    long k = read(f->fd, d + got, (long) (total - got));
    if (k < 0) { if (__errno_v == EINTR) continue; f->err = 1; break; }
    if (k == 0) { f->eof = 1; break; }
    got += (size_t) k; }
  return sz ? got / sz : 0; }
