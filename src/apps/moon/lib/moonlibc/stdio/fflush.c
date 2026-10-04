#include "../impl.h"

static long __wall(int fd, unsigned char const *p, long n) {
  long i = 0;
  while (i < n) {
    long k = write(fd, p + i, n - i);
    if (k < 0) { if (__errno_v == EINTR) continue; return -1; }
    i += k; }
  return i; }
static int __fdrain(FILE *f) {
  if (f->len == 0) return 0;
  long n = f->len;
  f->len = 0;
  if (__wall(f->fd, f->buf, n) < 0) { f->err = 1; return EOF; }
  return 0; }
/* the streams fopen, fdopen and popen open, so fflush(NULL) and exit reach every one: the one
 * piece of process-wide stdio state past the standard three, linked through the FILEs themselves */
static FILE *__love_files;
void __love_fopened(FILE *f) { f->next = __love_files; __love_files = f; }
static void __love_fclosed(FILE *f) {
  for (FILE **p = &__love_files; *p; p = &(*p)->next) if (*p == f) { *p = f->next; return; } }
int fflush(FILE *f) {
  if (!f) {
    int r = __fdrain(stdout);
    if (__fdrain(stderr)) r = EOF;
    for (FILE *o = __love_files; o; o = o->next) if (o->wr && __fdrain(o)) r = EOF;
    return r ? EOF : 0; }
  return f->wr ? __fdrain(f) : __rsync(f); }
void setbuf(FILE *f, char *buf) {          /* NULL = unbuffered (m4 -e); else a BUFSIZ block */
  __fdrain(f);
  if (!f->wr) { __rsync(f); f->rp = f->rl = 0; if (buf) f->rb = (unsigned char *) buf; f->rcap = buf ? 8192 : 0; return; }
  if (buf) { f->buf = (unsigned char *) buf; f->cap = 8192; f->line = 0; }
  else f->cap = 0; }
int setvbuf(FILE *f, char *buf, int mode, size_t size) {
  __fdrain(f);
  if (!f->wr) {                              /* a read stream: no buffer, or the caller's (else its own stays) */
    __rsync(f); f->rp = f->rl = 0;
    if (mode == _IONBF) f->rcap = 0;
    else if (buf && size) { f->rb = (unsigned char *) buf; f->rcap = (int) size; }
    return 0; }
  if (mode == _IONBF) { f->cap = 0; f->line = 0; return 0; }
  if (buf && size) { f->buf = (unsigned char *) buf; f->cap = (int) size; }
  f->line = mode == _IOLBF;
  return 0; }
/* a buffered stream is NEVER LEFT FULL -- len < cap between calls, so the store is in
 * bounds and the == below catches the fill. fwrite drains at <= for exactly this: left
 * exactly full, it writes one past the end AND this == never matches again. */
int fputc(int c, FILE *f) {
  unsigned char b = (unsigned char) c;
  if (!f->cap) { if (__wall(f->fd, &b, 1) < 0) { f->err = 1; return EOF; } return b; }
  f->buf[f->len++] = b;
  if (f->len == f->cap || (f->line && b == 10))
    if (__fdrain(f)) return EOF;
  return b; }
size_t fwrite(void const *p, size_t sz, size_t n, FILE *f) {
  size_t total = sz * n;
  if (total == 0) return 0;
  if (!f->cap || total >= (size_t) f->cap) {
    if (__fdrain(f)) return 0;
    if (__wall(f->fd, p, (long) total) < 0) { f->err = 1; return 0; }
    return n; }
  if ((size_t) (f->cap - f->len) <= total && __fdrain(f)) return 0;
  memcpy(f->buf + f->len, p, total);
  f->len += (int) total;
  if (f->line) { unsigned char const *q = p; for (size_t i = 0; i < total; i++) if (q[i] == 10) { __fdrain(f); break; } }
  return n; }
int fclose(FILE *f) {
  int r = f->wr ? __fdrain(f) : __rsync(f);
  if (close(f->fd) < 0) r = EOF;
  __love_fclosed(f);
  if (f->heap) free(f);
  return r; }
FILE *freopen(char const *path, char const *mode, FILE *f) {
  __fdrain(f);                                     /* the stream KEEPS its FILE (and its buffer) -- only the fd turns over */
  close(f->fd);
  int fl = O_RDONLY, wr = 0;
  if (mode[0] == 'w') { fl = O_WRONLY | O_CREAT | O_TRUNC; wr = 1; }
  else if (mode[0] == 'a') { fl = O_WRONLY | O_CREAT | O_APPEND; wr = 1; }
  for (char const *m = mode + 1; *m; m++)
    if (*m == '+') { fl = (fl & ~3) | O_RDWR; wr = 1; }
  int fd = open(path, fl, 438);
  if (fd < 0) return 0;
  f->fd = fd; f->wr = wr; f->err = 0; f->eof = 0; f->un = 0; f->len = 0; f->pid = 0;
  f->rp = f->rl = 0;
  if (wr) f->rcap = 0;
  return f; }
int fseek(FILE *f, long off, int wh) {
  if (__fdrain(f)) return -1;
  if (wh == SEEK_CUR) off -= __rahead(f);    /* relative to the stream, not the fd's read-ahead */
  f->un = 0;                                 /* ISO: a seek discards the pushback */
  f->rp = f->rl = 0;
  f->eof = 0;                                /* and clears the end-of-file flag */
  return lseek(f->fd, off, wh) < 0 ? -1 : 0; }
long ftell(FILE *f) {
  if (__fdrain(f)) return -1;
  long o = lseek(f->fd, 0, SEEK_CUR);
  return o < 0 ? -1 : o - __rahead(f); }
