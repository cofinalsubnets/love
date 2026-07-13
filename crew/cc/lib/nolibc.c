/* crew/cc/lib/nolibc.c -- the raw-syscall libc under the gcc-free ai (rung 4).
 * Everything the host objects ask of glibc, answered straight off the Linux
 * x86-64 syscall table through __ai_sys (crew/cc/lib/mksys.l lays that leaf,
 * with __sigsetjmp/siglongjmp/__ai_sigret/sqrt beside it; crew/cc/lib/math/
 * carries the fdlibm set). One file, aicc-compiled, our own linker binds it:
 *   aicc ai.o (host objects) nolibc.o (math objects) sys.o -o ai
 * The shapes here MATCH crew/cc/include/ (which mirrors glibc's x86-64 ABI,
 * which mirrors the kernel's where it can): struct stat and dirent are the
 * kernel layouts verbatim, termios rides TCGETS raw the way musl does, and
 * only sigaction needs a real translation (glibc's 152-byte struct to the
 * kernel's 32-byte one, restorer supplied). Single-threaded by design, like
 * ai itself: errno is one int, no locks anywhere. */
#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <setjmp.h>
#include <poll.h>
#include <time.h>
#include <dirent.h>
#include <termios.h>
#include <netdb.h>
#include <link.h>
#include <sched.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/mount.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <sys/signalfd.h>

extern long __ai_sys(long n, long a, long b, long c, long d, long e, long f);
extern void __ai_sigret(void);
extern int main(int, char**);

char **environ;
static long *__auxv;

/* ---- errno: one int (ai is single-threaded), kernel -errno unwrapped ---- */
static int __errno_v;
int *__errno_location(void) { return &__errno_v; }
static long er(long r) {
  if ((unsigned long) r > (unsigned long) -4096L) { __errno_v = (int) -r; return -1; }
  return r; }

static long sc0(long n) { return __ai_sys(n, 0, 0, 0, 0, 0, 0); }
static long sc1(long n, long a) { return __ai_sys(n, a, 0, 0, 0, 0, 0); }
static long sc2(long n, long a, long b) { return __ai_sys(n, a, b, 0, 0, 0, 0); }
static long sc3(long n, long a, long b, long c) { return __ai_sys(n, a, b, c, 0, 0, 0); }
static long sc4(long n, long a, long b, long c, long d) { return __ai_sys(n, a, b, c, d, 0, 0); }
static long sc5(long n, long a, long b, long c, long d, long e) { return __ai_sys(n, a, b, c, d, e, 0); }
static long sc6(long n, long a, long b, long c, long d, long e, long f) { return __ai_sys(n, a, b, c, d, e, f); }

/* ---- memory/string: word-wide where the pointers agree (the GC image and
 * string lanes move real volume through these) ---- */
void *memcpy(void *d, void const *s, size_t n) {
  unsigned char *dp = d; unsigned char const *sp = s;
  if ((((unsigned long) dp | (unsigned long) sp) & 7) == 0)
    while (n >= 8) { *(unsigned long *) dp = *(unsigned long const *) sp; dp += 8; sp += 8; n -= 8; }
  while (n--) *dp++ = *sp++;
  return d; }
void *memmove(void *d, void const *s, size_t n) {
  unsigned char *dp = d; unsigned char const *sp = s;
  if (dp == sp || n == 0) return d;
  if (dp < sp) return memcpy(d, s, n);
  dp += n; sp += n;
  while (n--) *--dp = *--sp;
  return d; }
void *memset(void *d, int c, size_t n) {
  unsigned char *dp = d;
  unsigned char b = (unsigned char) c;
  unsigned long w = b; w |= w << 8; w |= w << 16; w |= w << 32;
  if (((unsigned long) dp & 7) == 0)
    while (n >= 8) { *(unsigned long *) dp = w; dp += 8; n -= 8; }
  while (n--) *dp++ = b;
  return d; }
int memcmp(void const *a, void const *b, size_t n) {
  unsigned char const *x = a, *y = b;
  while (n--) { if (*x != *y) return (int) *x - (int) *y; x++; y++; }
  return 0; }
size_t strlen(char const *s) { size_t n = 0; while (*s++) n++; return n; }
int strcmp(char const *a, char const *b) {
  while (*a && *a == *b) { a++; b++; }
  return (int) (unsigned char) *a - (int) (unsigned char) *b; }

/* ---- the plain syscall tail: one line each ---- */
long read(int fd, void *b, long n) { return er(sc3(0, fd, (long) b, n)); }
long write(int fd, void const *b, long n) { return er(sc3(1, fd, (long) b, n)); }
int close(int fd) { return (int) er(sc1(3, fd)); }
long lseek(int fd, long off, int wh) { return er(sc3(8, fd, off, wh)); }
int open(char const *p, int fl, ...) {
  va_list ap; va_start(ap, fl);
  int mode = va_arg(ap, int);
  va_end(ap);
  return (int) er(sc3(2, (long) p, fl, mode)); }
int fcntl(int fd, int cmd, ...) {
  va_list ap; va_start(ap, cmd);
  long arg = va_arg(ap, long);
  va_end(ap);
  return (int) er(sc3(72, fd, cmd, arg)); }
int ioctl(int fd, unsigned long req, ...) {
  va_list ap; va_start(ap, req);
  long arg = va_arg(ap, long);
  va_end(ap);
  return (int) er(sc3(16, fd, (long) req, arg)); }
int stat(char const *p, struct stat *st) { return (int) er(sc2(4, (long) p, (long) st)); }
int fstat(int fd, struct stat *st) { return (int) er(sc2(5, fd, (long) st)); }
int lstat(char const *p, struct stat *st) { return (int) er(sc2(6, (long) p, (long) st)); }
int poll(struct pollfd *fds, nfds_t n, int ms) { return (int) er(sc3(7, (long) fds, (long) n, ms)); }
int pipe(int *fds) { return (int) er(sc1(22, (long) fds)); }
int dup2(int a, int b) { return (int) er(sc2(33, a, b)); }
int getpid(void) { return (int) sc0(39); }
unsigned int getuid(void) { return (unsigned int) sc0(102); }
unsigned int getgid(void) { return (unsigned int) sc0(104); }
int fork(void) { return (int) er(sc0(57)); }
int waitpid(int pid, int *st, int opt) { return (int) er(sc4(61, pid, (long) st, opt, 0)); }
int kill(pid_t pid, int sig) { return (int) er(sc2(62, pid, sig)); }
int raise(int sig) { return kill(getpid(), sig); }
int fsync(int fd) { return (int) er(sc1(74, fd)); }
int ftruncate(int fd, long n) { return (int) er(sc2(77, fd, n)); }
char *getcwd(char *b, unsigned long n) {
  long r = sc2(79, (long) b, (long) n);
  if (r < 0) { __errno_v = (int) -r; return 0; }
  return b; }
int chdir(char const *p) { return (int) er(sc1(80, (long) p)); }
int rename(char const *a, char const *b) { return (int) er(sc2(82, (long) a, (long) b)); }
int mkdir(char const *p, unsigned int m) { return (int) er(sc2(83, (long) p, m)); }
int rmdir(char const *p) { return (int) er(sc1(84, (long) p)); }
int link(char const *a, char const *b) { return (int) er(sc2(86, (long) a, (long) b)); }
int unlink(char const *p) { return (int) er(sc1(87, (long) p)); }
int symlink(char const *a, char const *b) { return (int) er(sc2(88, (long) a, (long) b)); }
long readlink(char const *p, char *b, unsigned long n) { return er(sc3(89, (long) p, (long) b, (long) n)); }
int chmod(char const *p, unsigned int m) { return (int) er(sc2(90, (long) p, m)); }
int fchmod(int fd, unsigned int m) { return (int) er(sc2(91, fd, m)); }
int chown(char const *p, unsigned int u, unsigned int g) { return (int) er(sc3(92, (long) p, u, g)); }
unsigned int umask(unsigned int m) { return (unsigned int) sc1(95, m); }
int setpgid(pid_t p, pid_t g) { return (int) er(sc2(109, p, g)); }
int getpgrp(void) { return (int) sc0(111); }
int setsid(void) { return (int) er(sc0(112)); }
int mount(char const *src, char const *tgt, char const *ty, unsigned long fl, void const *d) {
  return (int) er(sc5(165, (long) src, (long) tgt, (long) ty, (long) fl, (long) d)); }
int unshare(int fl) { return (int) er(sc1(272, fl)); }
int clock_gettime(int ck, struct timespec *ts) { return (int) er(sc2(228, ck, (long) ts)); }
long pwrite(int fd, void const *b, unsigned long n, long off) { return er(sc4(18, fd, (long) b, (long) n, off)); }
int memfd_create(char const *name, unsigned int fl) { return (int) er(sc2(319, (long) name, fl)); }
int utimensat(int dfd, char const *p, struct timespec const *ts, int fl) {
  return (int) er(sc4(280, dfd, (long) p, (long) ts, fl)); }
void *mmap(void *a, long n, int prot, int fl, int fd, long off) {
  long r = sc6(9, (long) a, n, prot, fl, fd, off);
  if ((unsigned long) r > (unsigned long) -4096L) { __errno_v = (int) -r; return (void *) -1; }
  return (void *) r; }
int munmap(void *a, long n) { return (int) er(sc2(11, (long) a, n)); }
int mprotect(void *a, long n, int prot) { return (int) er(sc3(10, (long) a, n, prot)); }
long sysconf(int name) {
  if (name == _SC_PAGESIZE) return 4096;
  __errno_v = EINVAL; return -1; }

/* ---- exit: the atexit chain, the stdio flush, then exit_group ---- */
typedef void (*__exitfn)(void);
static __exitfn __atex[32];
static int __natex;
int atexit(void (*f)(void)) {
  if (__natex >= 32) return -1;
  __atex[__natex++] = f;
  return 0; }
void _exit(int c) { for (;;) sc1(231, c); }
void exit(int c) {
  while (__natex > 0) __atex[--__natex]();
  fflush(0);
  _exit(c); }

/* ---- execvp: execve + the PATH walk ---- */
int execv(char const *p, char *const *av) {
  return (int) er(sc3(59, (long) p, (long) av, (long) environ)); }
int execvp(char const *f, char *const *av) {
  char const *s = f;
  while (*s) { if (*s == '/') return execv(f, av); s++; }
  char const *path = getenv("PATH");
  if (!path) path = "/usr/local/bin:/usr/bin:/bin";
  char buf[4096];
  size_t fn = strlen(f);
  while (*path) {
    size_t i = 0;
    while (path[i] && path[i] != ':') i++;
    if (i + 1 + fn + 1 < sizeof buf) {
      memcpy(buf, path, i);
      buf[i] = '/';
      memcpy(buf + i + 1, f, fn + 1);
      execv(buf, av); }                     /* returns only on failure; keep walking */
    path += i;
    if (*path == ':') path++; }
  __errno_v = ENOENT;
  return -1; }

/* ---- malloc: K&R's first-fit free list over 1MB mmap arenas. 16-byte units,
 * 16-byte alignment, coalescing free. ai mallocs pools (big, rare) and codec /
 * line buffers (small, freed) -- this shape covers both without ceremony. ---- */
typedef struct __mhdr { struct __mhdr *next; size_t size; } __mhdr;   /* size in units */
static __mhdr __mbase;
static __mhdr *__mfree;
void free(void *p) {
  if (!p) return;
  __mhdr *b = (__mhdr *) p - 1, *q = __mfree;
  for (; !(b > q && b < q->next); q = q->next)
    if (q >= q->next && (b > q || b < q->next)) break;   /* at the arena's wrap point */
  if (b + b->size == q->next) { b->size += q->next->size; b->next = q->next->next; }
  else b->next = q->next;
  if (q + q->size == b) { q->size += b->size; q->next = b->next; }
  else q->next = b;
  __mfree = q; }
static __mhdr *__mcore(size_t nu) {
  size_t need = (nu + 1) * sizeof(__mhdr);
  size_t len = need < (1UL << 20) ? (1UL << 20) : ((need + 4095UL) & ~4095UL);
  void *m = mmap(0, (long) len, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (m == (void *) -1) return 0;
  __mhdr *u = m;
  u->size = len / sizeof(__mhdr);
  free((void *) (u + 1));
  return __mfree; }
void *malloc(size_t n) {
  size_t nu = (n + sizeof(__mhdr) - 1) / sizeof(__mhdr) + 1;
  __mhdr *prev = __mfree;
  if (!prev) { __mbase.next = __mfree = prev = &__mbase; __mbase.size = 0; }
  for (__mhdr *q = prev->next; ; prev = q, q = q->next) {
    if (q->size >= nu) {
      if (q->size == nu) prev->next = q->next;
      else { q->size -= nu; q += q->size; q->size = nu; }
      __mfree = prev;
      return (void *) (q + 1); }
    if (q == __mfree)
      if (!(q = __mcore(nu))) { __errno_v = ENOMEM; return 0; } } }

/* ---- env ---- */
char *getenv(char const *k) {
  size_t n = strlen(k);
  if (!environ) return 0;
  for (char **e = environ; *e; e++)
    if (memcmp(*e, k, n) == 0 && (*e)[n] == '=') return *e + n + 1;
  return 0; }
static int __env_ours;                       /* the array itself came off our malloc */
int setenv(char const *k, char const *v, int ov) {
  size_t kn = strlen(k), vn = strlen(v);
  char *kv = malloc(kn + 1 + vn + 1);
  if (!kv) return -1;
  memcpy(kv, k, kn); kv[kn] = '=';
  memcpy(kv + kn + 1, v, vn + 1);
  size_t cnt = 0;
  if (environ)
    for (char **e = environ; *e; e++, cnt++)
      if (memcmp(*e, k, kn) == 0 && (*e)[kn] == '=') {
        if (!ov) { free(kv); return 0; }
        *e = kv;                             /* the old string may be the kernel's; leak it */
        return 0; }
  char **ne = malloc((cnt + 2) * sizeof(char *));
  if (!ne) { free(kv); return -1; }
  for (size_t i = 0; i < cnt; i++) ne[i] = environ[i];
  ne[cnt] = kv;
  ne[cnt + 1] = 0;
  if (__env_ours) free(environ);
  environ = ne;
  __env_ours = 1;
  return 0; }
int unsetenv(char const *k) {
  size_t kn = strlen(k);
  if (!environ) return 0;
  char **w = environ;
  for (char **e = environ; *e; e++)
    if (!(memcmp(*e, k, kn) == 0 && (*e)[kn] == '=')) *w++ = *e;
  *w = 0;
  return 0; }

/* ---- stdio: FILE is a fd plus (for write streams) a flush buffer. stdout is
 * the one hot stream -- ai's fd_putc sends EVERY output byte through fputc, so
 * it buffers 8KB (line-flushed on a tty, glibc's shape); stderr never buffers;
 * fopen'd streams buffer 4KB. reads are unbuffered (image.c freads whole
 * files), which keeps fseek/ftell honest as plain lseek. ---- */
struct _IO_FILE {
  int fd;
  int wr;                                    /* open for writing */
  int line;                                  /* flush on newline */
  int err;
  int heap;                                  /* buf and FILE both off malloc (fopen) */
  int len, cap;
  unsigned char *buf;
};
static unsigned char __obuf[8192];
static FILE __f_in, __f_out, __f_err;   /* separate, so each pointer is &global (image-safe), not &arr[i] */
FILE *stdin = &__f_in, *stdout = &__f_out, *stderr = &__f_err;

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
int fflush(FILE *f) {
  if (!f) {
    int r = __fdrain(stdout);
    return __fdrain(stderr) || r ? EOF : 0; }
  return __fdrain(f); }
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
  if ((size_t) (f->cap - f->len) < total && __fdrain(f)) return 0;
  memcpy(f->buf + f->len, p, total);
  f->len += (int) total;
  if (f->line) { unsigned char const *q = p; for (size_t i = 0; i < total; i++) if (q[i] == 10) { __fdrain(f); break; } }
  return n; }
size_t fread(void *p, size_t sz, size_t n, FILE *f) {
  size_t total = sz * n, got = 0;
  unsigned char *d = p;
  while (got < total) {
    long k = read(f->fd, d + got, (long) (total - got));
    if (k < 0) { if (__errno_v == EINTR) continue; f->err = 1; break; }
    if (k == 0) break;
    got += (size_t) k; }
  return sz ? got / sz : 0; }
FILE *fopen(char const *path, char const *mode) {
  int fl = O_RDONLY, wr = 0;
  if (mode[0] == 'w') { fl = O_WRONLY | O_CREAT | O_TRUNC; wr = 1; }
  else if (mode[0] == 'a') { fl = O_WRONLY | O_CREAT | O_APPEND; wr = 1; }
  for (char const *m = mode + 1; *m; m++)
    if (*m == '+') { fl = (fl & ~3) | O_RDWR; wr = 1; }
  int fd = open(path, fl, 438);              /* 0666, the umask trims it */
  if (fd < 0) return 0;
  FILE *f = malloc(sizeof(FILE) + 4096);
  if (!f) { close(fd); return 0; }
  memset(f, 0, sizeof(FILE));
  f->fd = fd;
  f->wr = wr;
  f->heap = 1;
  if (wr) { f->buf = (unsigned char *) (f + 1); f->cap = 4096; }
  return f; }
int fclose(FILE *f) {
  int r = __fdrain(f);
  if (close(f->fd) < 0) r = EOF;
  if (f->heap) free(f);
  return r; }
int fseek(FILE *f, long off, int wh) {
  if (__fdrain(f)) return -1;
  return lseek(f->fd, off, wh) < 0 ? -1 : 0; }
long ftell(FILE *f) {
  if (__fdrain(f)) return -1;
  return lseek(f->fd, 0, SEEK_CUR); }
int fileno(FILE *f) { return f->fd; }

/* ---- the one formatter under fprintf and snprintf: %s %c %d %u %x with the
 * l/z widths -- the shapes the host actually speaks (no floats anywhere; ai
 * prints its own numbers). sink+ctx so neither caller stages a bound buffer. */
static void __femit(void *ctx, int c) { fputc(c, (FILE *) ctx); }
struct __sctx { char *p; size_t n, at; };
static void __semit(void *ctx, int c) {
  struct __sctx *s = ctx;
  if (s->at + 1 < s->n) s->p[s->at] = (char) c;
  s->at++; }
static void __fmtu(void (*put)(void *, int), void *ctx, unsigned long v, unsigned base, int neg) {
  char tmp[24];
  int i = 0;
  do { unsigned d = (unsigned) (v % base); tmp[i++] = (char) (d < 10 ? 48 + d : 87 + d); v /= base; } while (v);
  if (neg) put(ctx, 45);
  while (i) put(ctx, tmp[--i]); }
static void __fmt(void (*put)(void *, int), void *ctx, char const *fmt, va_list ap) {
  for (; *fmt; fmt++) {
    if (*fmt != '%') { put(ctx, *fmt); continue; }
    fmt++;
    int wide = 0;                            /* 0 int, 1 long/size_t */
    while (*fmt == 'l' || *fmt == 'z') { wide = 1; fmt++; }
    if (*fmt == 's') {
      char const *s = va_arg(ap, char const *);
      if (!s) s = "(null)";
      while (*s) put(ctx, *s++); }
    else if (*fmt == 'c') put(ctx, va_arg(ap, int));
    else if (*fmt == 'd') {
      long v = wide ? va_arg(ap, long) : (long) va_arg(ap, int);
      unsigned long u = (unsigned long) v;
      int neg = v < 0;
      if (neg) u = 0UL - u;
      __fmtu(put, ctx, u, 10, neg); }
    else if (*fmt == 'u')
      __fmtu(put, ctx, wide ? va_arg(ap, unsigned long) : (unsigned long) va_arg(ap, unsigned int), 10, 0);
    else if (*fmt == 'x')
      __fmtu(put, ctx, wide ? va_arg(ap, unsigned long) : (unsigned long) va_arg(ap, unsigned int), 16, 0);
    else if (*fmt == 'p') { put(ctx, 48); put(ctx, 120); __fmtu(put, ctx, (unsigned long) va_arg(ap, void *), 16, 0); }
    else if (*fmt == '%') put(ctx, 37);
    else { put(ctx, 37); if (*fmt) put(ctx, *fmt); else fmt--; } }
}
int fprintf(FILE *f, char const *fmt, ...) {
  va_list ap; va_start(ap, fmt);
  __fmt(__femit, f, fmt, ap);
  va_end(ap);
  return 0; }
int snprintf(char *p, size_t n, char const *fmt, ...) {
  struct __sctx s;
  s.p = p; s.n = n; s.at = 0;
  va_list ap; va_start(ap, fmt);
  __fmt(__semit, &s, fmt, ap);
  va_end(ap);
  if (n) p[s.at < n ? s.at : n - 1] = 0;
  return (int) s.at; }

/* ---- signals: glibc's 152-byte sigaction folded onto the kernel's 32-byte
 * rt_sigaction, our own restorer riding SA_RESTORER (sys.o's __ai_sigret). ---- */
struct __ksigaction { void *h; unsigned long flags; void *restorer; unsigned long mask; };
int sigemptyset(sigset_t *s) { memset(s, 0, sizeof *s); return 0; }
int sigaddset(sigset_t *s, int n) {
  s->__v[(n - 1) / 64] |= 1UL << ((unsigned) (n - 1) % 64);
  return 0; }
int sigaction(int sig, struct sigaction const *a, struct sigaction *old) {
  struct __ksigaction ka, ko;
  memset(&ko, 0, sizeof ko);
  if (a) {
    ka.h = (void *) a->sa_handler;
    ka.flags = (unsigned long) (unsigned int) a->sa_flags | 67108864UL;   /* SA_RESTORER */
    ka.restorer = (void *) __ai_sigret;
    ka.mask = (unsigned long) a->sa_mask.__v[0]; }
  long r = sc4(13, sig, a ? (long) &ka : 0, old ? (long) &ko : 0, 8);
  if (r < 0) { __errno_v = (int) -r; return -1; }
  if (old) {
    memset(old, 0, sizeof *old);
    old->sa_handler = (void (*)(int)) ko.h;
    old->sa_flags = (int) ko.flags;
    old->sa_mask.__v[0] = (long) ko.mask; }
  return 0; }
void *signal(int sig, void *h) {
  struct sigaction sa, old;
  memset(&sa, 0, sizeof sa);
  sa.sa_handler = (void (*)(int)) h;
  sa.sa_flags = 268435456;                   /* SA_RESTART: glibc signal() semantics */
  if (sigaction(sig, &sa, &old)) return (void *) -1;
  return (void *) old.sa_handler; }
int sigprocmask(int how, sigset_t const *s, sigset_t *o) {
  unsigned long ks = s ? (unsigned long) s->__v[0] : 0, ko = 0;
  long r = sc4(14, how, s ? (long) &ks : 0, o ? (long) &ko : 0, 8);
  if (r < 0) { __errno_v = (int) -r; return -1; }
  if (o) { memset(o, 0, sizeof *o); o->__v[0] = (long) ko; }
  return 0; }
int signalfd(int fd, sigset_t const *m, int fl) {
  unsigned long km = (unsigned long) m->__v[0];
  return (int) er(sc4(289, fd, (long) &km, 8, fl)); }

/* ---- the terminal ---- */
int tcgetattr(int fd, struct termios *t) { return ioctl(fd, 21505, t); }            /* TCGETS */
int tcsetattr(int fd, int act, struct termios const *t) {
  if (act < 0 || act > 2) { __errno_v = EINVAL; return -1; }
  return ioctl(fd, (unsigned long) (21506 + act), t); }                             /* TCSETS/W/F */
int tcsetpgrp(int fd, pid_t pg) { int p = (int) pg; return ioctl(fd, 21520, &p); }  /* TIOCSPGRP */
int isatty(int fd) {
  struct termios t;
  return tcgetattr(fd, &t) == 0; }

/* ---- the pty quartet ---- */
int posix_openpt(int fl) { return open("/dev/ptmx", fl, 0); }
int grantpt(int fd) { (void) fd; return 0; }                    /* devpts grants at open */
int unlockpt(int fd) { int z = 0; return ioctl(fd, 1074025521UL, &z); }   /* TIOCSPTLCK */
char *ptsname(int fd) {
  static char nb[32];
  int n = 0;
  if (ioctl(fd, 2147767344UL, &n) < 0) return 0;                /* TIOCGPTN */
  snprintf(nb, sizeof nb, "/dev/pts/%d", n);
  return nb; }

/* ---- dirent over getdents64: the kernel record IS our struct dirent ---- */
struct __dirstream { int fd; int pos; int len; char buf[4096]; };
DIR *opendir(char const *p) {
  int fd = open(p, O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0);
  if (fd < 0) return 0;
  DIR *d = malloc(sizeof(DIR));
  if (!d) { close(fd); return 0; }
  d->fd = fd; d->pos = 0; d->len = 0;
  return d; }
struct dirent *readdir(DIR *d) {
  if (d->pos >= d->len) {
    long n = sc3(217, d->fd, (long) d->buf, sizeof d->buf);
    if (n <= 0) { if (n < 0) __errno_v = (int) -n; return 0; }
    d->len = (int) n; d->pos = 0; }
  struct dirent *e = (struct dirent *) (d->buf + d->pos);
  d->pos += e->d_reclen;
  return e; }
int closedir(DIR *d) {
  int r = close(d->fd);
  free(d);
  return r; }

/* ---- byte order ---- */
unsigned short htons(unsigned short v) { return (unsigned short) ((v << 8) | (v >> 8)); }
unsigned short ntohs(unsigned short v) { return htons(v); }
unsigned int htonl(unsigned int v) {
  return (v << 24) | ((v & 65280U) << 8) | ((v >> 8) & 65280U) | (v >> 24); }
unsigned int ntohl(unsigned int v) { return htonl(v); }

/* ---- getaddrinfo, the numeric slice: dotted-quad IPv4 + localhost + a decimal
 * port -- exactly what the host seam speaks (host/net.c resolves numbers; DNS
 * stays a post-rung nicety). one malloc'd block carries result + address. ---- */
struct __sain { unsigned short fam; unsigned short port; unsigned int addr; char pad[8]; };   /* sockaddr_in, 16 bytes */
struct __gai { struct addrinfo ai; struct __sain sa; };
static int __quad(char const *s, unsigned int *out) {
  unsigned int a = 0;
  for (int i = 0; i < 4; i++) {
    unsigned int b = 0, any = 0;
    while (*s >= 48 && *s <= 57) { b = b * 10 + (unsigned) (*s++ - 48); any = 1; if (b > 255) return -1; }
    if (!any) return -1;
    a = (a << 8) | b;
    if (i < 3 && *s++ != 46) return -1; }
  if (*s) return -1;
  *out = a;
  return 0; }
int getaddrinfo(char const *host, char const *serv, struct addrinfo const *hints, struct addrinfo **res) {
  unsigned int a4 = 2130706433U;             /* 127.0.0.1 */
  if (host) {
    if (strcmp(host, "localhost") != 0 && __quad(host, &a4) < 0) return -2;   /* EAI_NONAME */
  } else if (hints && (hints->ai_flags & AI_PASSIVE)) a4 = 0;                 /* INADDR_ANY */
  unsigned int port = 0;
  if (serv) {
    char const *s = serv;
    if (!*s) return -2;
    while (*s >= 48 && *s <= 57) port = port * 10 + (unsigned) (*s++ - 48);
    if (*s || port > 65535) return -2; }
  struct __gai *g = malloc(sizeof(struct __gai));
  if (!g) return -10;                        /* EAI_MEMORY */
  memset(g, 0, sizeof *g);
  g->sa.fam = AF_INET;
  g->sa.port = htons((unsigned short) port);
  g->sa.addr = htonl(a4);
  g->ai.ai_family = AF_INET;
  g->ai.ai_socktype = hints && hints->ai_socktype ? hints->ai_socktype : SOCK_STREAM;
  g->ai.ai_protocol = hints ? hints->ai_protocol : 0;
  g->ai.ai_addrlen = 16;
  g->ai.ai_addr = (struct sockaddr *) &g->sa;
  *res = &g->ai;
  return 0; }
void freeaddrinfo(struct addrinfo *r) { free(r); }

/* ---- sockets ---- */
int socket(int d, int t, int p) { return (int) er(sc3(41, d, t, p)); }
int connect(int fd, struct sockaddr const *a, socklen_t n) { return (int) er(sc3(42, fd, (long) a, n)); }
int accept(int fd, struct sockaddr *a, socklen_t *n) { return (int) er(sc3(43, fd, (long) a, (long) n)); }
long sendto(int fd, void const *b, unsigned long n, int fl, struct sockaddr const *a, socklen_t an) {
  return er(sc6(44, fd, (long) b, (long) n, fl, (long) a, an)); }
long recvfrom(int fd, void *b, unsigned long n, int fl, struct sockaddr *a, socklen_t *an) {
  return er(sc6(45, fd, (long) b, (long) n, fl, (long) a, (long) an)); }
long sendmsg(int fd, struct msghdr const *m, int fl) { return er(sc3(46, fd, (long) m, fl)); }
long recvmsg(int fd, struct msghdr *m, int fl) { return er(sc3(47, fd, (long) m, fl)); }
int shutdown(int fd, int how) { return (int) er(sc2(48, fd, how)); }
int bind(int fd, struct sockaddr const *a, socklen_t n) { return (int) er(sc3(49, fd, (long) a, n)); }
int listen(int fd, int bl) { return (int) er(sc2(50, fd, bl)); }
int setsockopt(int fd, int lv, int op, void const *v, socklen_t n) {
  return (int) er(sc5(54, fd, lv, op, (long) v, n)); }

/* ---- strtol / strtod: the reader's number path. the bodies keep libc/str.c's
 * exact semantics (the kernel corpus runs them; the naive strtod measured
 * corpus-green against glibc's in the rung-4 differential). ---- */
static int __digval(int c) {
  if (c >= 48 && c <= 57) return c - 48;
  if (c >= 97 && c <= 122) return c - 87;
  if (c >= 65 && c <= 90) return c - 55;
  return 99; }
long strtol(char const *s, char **endptr, int base) {
  char const *p = s;
  int sign = 1;
  while (*p == 32 || (*p >= 9 && *p <= 13)) p++;
  if (*p == '-') { sign = -1; p++; }
  else if (*p == '+') p++;
  if (*p == '0') {
    ++p;
    if ((base == 0 || base == 16) && (*p == 'x' || *p == 'X')) {
      base = 16;
      ++p;
      if (__digval(*p) >= base) p -= 2; }
    else if (base == 0) { base = 8; --p; }
    else --p; }
  else if (!base) base = 10;
  if (base < 2 || base > 36) return 0;
  int any = 0;
  long rc = 0;
  for (int d; (d = __digval(*p)) < base; p++) { any = 1; rc = rc * base + d; }
  if (endptr) *endptr = (char *) (any ? p : s);
  return any ? sign * rc : 0; }
double strtod(char const *s, char **end) {
  char const *p = s;
  int sign = 1;
  if (*p == '-') { sign = -1; p++; }
  else if (*p == '+') p++;
  int any = 0;
  double v = 0;
  while (*p >= 48 && *p <= 57) { v = v * 10 + (*p++ - 48); any = 1; }
  if (*p == '.') {
    p++;
    double scale = 0.1;
    while (*p >= 48 && *p <= 57) { v += (*p++ - 48) * scale; scale *= 0.1; any = 1; } }
  if (!any) { if (end) *end = (char *) s; return 0; }
  if (*p == 'e' || *p == 'E') {
    char const *q = p++;
    int esign = 1;
    if (*p == '-') { esign = -1; p++; }
    else if (*p == '+') p++;
    if (!(*p >= 48 && *p <= 57)) p = q;
    else {
      int e = 0;
      while (*p >= 48 && *p <= 57) e = e * 10 + (*p++ - 48);
      double scale = 1;
      while (e--) scale *= 10;
      v = esign > 0 ? v * scale : v / scale; } }
  if (end) *end = (char *) p;
  return sign * v; }

/* ---- dl_iterate_phdr off the auxv (AT_PHDR/AT_PHNUM): our exes are ET_EXEC,
 * so the bias is 0 and one callback covers "the main program" -- all image.c's
 * bake walk wants. ---- */
int dl_iterate_phdr(int (*cb)(struct dl_phdr_info *, unsigned long, void *), void *data) {
  unsigned long phdr = 0, phnum = 0;
  for (long *a = __auxv; a && a[0]; a += 2) {
    if (a[0] == 3) phdr = (unsigned long) a[1];        /* AT_PHDR */
    if (a[0] == 5) phnum = (unsigned long) a[1]; }     /* AT_PHNUM */
  if (!phdr) return 0;
  struct dl_phdr_info in;
  memset(&in, 0, sizeof in);
  in.dlpi_addr = 0;
  in.dlpi_name = "";
  in.dlpi_phdr = (Elf64_Phdr const *) phdr;
  in.dlpi_phnum = (Elf64_Half) phnum;
  return cb(&in, sizeof in, data); }

/* ---- the entry: crt0 hands us the OS stack pointer (argc at [sp]); unpack
 * argv/envp/auxv, arm stdio, run main, exit with its answer. this STRONG
 * definition overrides crt0's weak call-main tail (the linker's weak machinery
 * is the whole switch -- no flags anywhere). ---- */
void __ai_start(long *sp) {
  long argc = sp[0];
  char **argv = (char **) (sp + 1);
  char **e = argv + argc + 1;
  environ = e;
  while (*e) e++;
  __auxv = (long *) (e + 1);
  stdout->fd = 1;
  stdout->wr = 1;
  stdout->buf = __obuf;
  stdout->cap = sizeof __obuf;
  stdout->line = isatty(1);
  stderr->fd = 2;
  stderr->wr = 1;
  exit(main((int) argc, argv)); }
