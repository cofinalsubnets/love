#include "../impl.h"

unsigned char __ibuf[4096];

long __rfill(FILE *f) {
  f->rp = f->rl = 0;
  for (;;) {
    long k = read(f->fd, f->rb, f->rcap);
    if (k < 0) { if (__errno_v == EINTR) continue; f->err = 1; return -1; }
    if (k == 0) f->eof = 1;
    f->rl = (int) k;
    return k; } }

long __rahead(FILE *f) { return (long) (f->rl - f->rp) + (f->un != 0); }

/* POSIX: a flushed input stream leaves the fd at the stream's position, its read-ahead and
 * pushback dropped. a pipe cannot seek back, so it keeps what it holds, as glibc does */
int __rsync(FILE *f) {
  long a = __rahead(f);
  if (a == 0) return 0;
  if (lseek(f->fd, -a, SEEK_CUR) < 0) return __errno_v == ESPIPE ? 0 : EOF;
  f->rp = f->rl = 0; f->un = 0;
  return 0; }
