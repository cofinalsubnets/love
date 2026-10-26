/* moonlibc's numbers, math faces, process and stdio odds and ends */
#include "impl.h"
#include <inttypes.h>

static int __digval(int c) {
  if (c >= 48 && c <= 57) return c - 48;
  if (c >= 97 && c <= 122) return c - 87;
  if (c >= 65 && c <= 90) return c - 55;
  return 99; }
/* every strto* integer: the magnitude accumulates unsigned and saturates at the limit,
 * as the standard asks; *neg says a minus led, *over that it saturated */
static unsigned long long __strtom(char const *s, char **endptr, int base, unsigned long long mx,
                                   unsigned long long mxneg, int *neg, int *over) {
  char const *p = s;
  *neg = 0; *over = 0;
  while (*p == 32 || (*p >= 9 && *p <= 13)) p++;
  if (*p == '-') { *neg = 1; p++; }
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
  if (endptr) *endptr = (char *) s;
  if (base < 2 || base > 36) return 0;
  unsigned long long lim = *neg ? mxneg : mx, b = (unsigned long long) base,
                     cut = lim / b, cutd = lim % b, rc = 0;
  int any = 0;
  for (int d; (d = __digval(*p)) < base; p++) {
    any = 1;
    if (*over || rc > cut || (rc == cut && (unsigned long long) d > cutd)) *over = 1;
    else rc = rc * b + (unsigned long long) d; }
  if (endptr) *endptr = (char *) (any ? p : s);
  if (!any) return 0;
  if (*over) { errno = ERANGE; return lim; }
  return rc; }
/* the minus reaches one further */
static long long __strtoi(char const *s, char **endptr, int base, unsigned long long mx) {
  int neg, over;
  unsigned long long m = __strtom(s, endptr, base, mx, mx + 1, &neg, &over);
  return (long long) (neg ? 0ULL - m : m); }
/* a leading minus negates modulo the width, as the standard asks */
static unsigned long long __strtou(char const *s, char **endptr, int base, unsigned long long mx) {
  int neg, over;
  unsigned long long m = __strtom(s, endptr, base, mx, mx, &neg, &over);
  return over || !neg ? m : (0ULL - m) & mx; }
long strtol(char const *s, char **endptr, int base) { return (long) __strtoi(s, endptr, base, LONG_MAX); }
long long strtoll(char const *s, char **endptr, int base) { return __strtoi(s, endptr, base, LLONG_MAX); }
intmax_t strtoimax(char const *s, char **endptr, int base) { return __strtoi(s, endptr, base, LLONG_MAX); }
unsigned long strtoul(char const *s, char **endptr, int base) { return (unsigned long) __strtou(s, endptr, base, ULONG_MAX); }
unsigned long long strtoull(char const *s, char **endptr, int base) { return __strtou(s, endptr, base, ULLONG_MAX); }
uintmax_t strtoumax(char const *s, char **endptr, int base) { return __strtou(s, endptr, base, ULLONG_MAX); }
double atof(char const *s) { return strtod(s, 0); }
/* libc math over lm.c; tan, log2, log10 and the hyperbolics are derived, a few ulp looser */
double lm_sqrt(double), lm_exp(double), lm_log(double);
double lm_sin(double), lm_cos(double), lm_atan2(double, double), lm_pow(double, double);
double lm_asin(double), lm_acos(double);
double sqrt(double x) { return lm_sqrt(x); }
double exp(double x) { return lm_exp(x); }
double log(double x) { return lm_log(x); }
double sin(double x) { return lm_sin(x); }
double cos(double x) { return lm_cos(x); }
double tan(double x) { return lm_sin(x) / lm_cos(x); }
double pow(double x, double y) { return lm_pow(x, y); }
double atan2(double y, double x) { return lm_atan2(y, x); }
double atan(double x) { return lm_atan2(x, 1.0); }
double asin(double x) { return lm_asin(x); }
double acos(double x) { return lm_acos(x); }
double log2(double x) { return lm_log(x) * 1.4426950408889634; }
double log10(double x) { return lm_log(x) * 0.4342944819032518; }
double sinh(double x) { double e = lm_exp(x); return (e - 1.0 / e) / 2.0; }
double cosh(double x) { double e = lm_exp(x); return (e + 1.0 / e) / 2.0; }
double tanh(double x) { double e = lm_exp(2.0 * x); return (e - 1.0) / (e + 1.0); }
double fabs(double x) { return x <= 0 ? 0.0 - x : x; }
double floor(double), ceil(double), fmod(double, double); /* fp.c's */
/* float twins: the double result narrowed once */
float sinf(float x) { return (float) sin(x); }
float cosf(float x) { return (float) cos(x); }
float tanf(float x) { return (float) tan(x); }
float asinf(float x) { return (float) asin(x); }
float acosf(float x) { return (float) acos(x); }
float atanf(float x) { return (float) atan(x); }
float expf(float x) { return (float) exp(x); }
float logf(float x) { return (float) log(x); }
float log2f(float x) { return (float) log2(x); }
float log10f(float x) { return (float) log10(x); }
float sqrtf(float x) { return (float) sqrt(x); }
float fabsf(float x) { return (float) fabs(x); }
float floorf(float x) { return (float) floor(x); }
float ceilf(float x) { return (float) ceil(x); }
float atan2f(float y, float x) { return (float) atan2(y, x); }
float powf(float x, float y) { return (float) pow(x, y); }
float fmodf(float x, float y) { return (float) fmod(x, y); }
double frexp(double x, int *e) {
  union { double d; unsigned long long u; } b;
  b.d = x;
  int ex = (int) ((b.u >> 52) & 2047);
  *e = 0;
  if (ex == 2047 || x == 0) return x;              /* inf/nan/0 ride through, *e 0 */
  if (ex == 0) {                                   /* denormal: normalize by 2^64 first */
    b.d = x * 18446744073709551616.0;
    ex = (int) ((b.u >> 52) & 2047) - 64; }
  *e = ex - 1022;
  b.u = (b.u & 0x800fffffffffffffull) | 0x3fe0000000000000ull;
  return b.d; }
static double __e2d(int n) {                       /* 2^n for normal n */
  union { double d; unsigned long long u; } b;
  b.u = ((unsigned long long) (n + 1023)) << 52;
  return b.d; }
double ldexp(double x, int n) {                    /* x * 2^n, clamped through the rim in steps */
  if (n > 1023) { x *= __e2d(1023); n -= 1023;
    if (n > 1023) { x *= __e2d(1023); n -= 1023; if (n > 1023) n = 1023; } }
  else if (n < -1022) { x *= __e2d(-969); n += 969;
    if (n < -1022) { x *= __e2d(-969); n += 969; if (n < -1022) n = -1022; } }
  return x * __e2d(n); }
double lm_strtod(char const *, char **);   /* correctly rounded; reads a bare token, no leading space */
float lm_strtof(char const *, char **);    /* ..and to binary32, rounded once from the digits */
/* inf, infinity, nan(chars) in any case after a sign, as bits so a minus signs nan too; 0 if neither */
static char const *__strtospecial(char const *p, double *v) {
  int neg = *p == '-';
  if (*p == '-' || *p == '+') p++;
  unsigned long long bits;
  if ((p[0] | 32) == 'i' && (p[1] | 32) == 'n' && (p[2] | 32) == 'f') {
    p += 3;
    if ((p[0] | 32) == 'i' && (p[1] | 32) == 'n' && (p[2] | 32) == 'i' && (p[3] | 32) == 't' && (p[4] | 32) == 'y') p += 5;
    bits = 0x7ff0000000000000ULL; }
  else if ((p[0] | 32) == 'n' && (p[1] | 32) == 'a' && (p[2] | 32) == 'n') {
    p += 3;
    if (*p == '(') {
      char const *q = p + 1;
      while ((*q | 32) >= 'a' && (*q | 32) <= 'z' || (*q >= '0' && *q <= '9') || *q == '_') q++;
      if (*q == ')') p = q + 1; }
    bits = 0x7ff8000000000000ULL; }
  else return 0;
  if (neg) bits |= 0x8000000000000000ULL;
  memcpy(v, &bits, sizeof *v);
  return p; }
/* strtod's frame; fo, when given, takes the binary32 reading */
static double __strtodf(char const *s, char **end, float *fo) {
  char const *p = s;
  while (*p == 32 || (*p >= 9 && *p <= 13)) p++;
  double sv; char const *sp = __strtospecial(p, &sv);
  if (sp) { if (end) *end = (char *) sp; if (fo) *fo = (float) sv; return sv; }
  char *e = (char *) p;
  double v = fo ? (*fo = lm_strtof(p, &e)) : lm_strtod(p, &e);
  if (e == p) { if (end) *end = (char *) s; if (fo) *fo = 0; return 0.0; }   /* no conversion: the original s */
  if (end) *end = e;
  return v; }
double strtod(char const *s, char **end) { return __strtodf(s, end, 0); }
float strtof(char const *s, char **end) { float f; __strtodf(s, end, &f); return f; }
long double strtold(char const *s, char **end) { return __strtodf(s, end, 0); }
/* shellsort with halving gaps */
void qsort(void *base, size_t n, size_t sz, int (*cmp)(void const *, void const *)) {
  char *a = base;
  for (size_t gap = n / 2; gap > 0; gap /= 2)
    for (size_t i = gap; i < n; i++)
      for (size_t j = i; j >= gap && cmp(a + (j - gap) * sz, a + j * sz) > 0; j -= gap) {
        char *x = a + (j - gap) * sz, *y = a + j * sz;
        for (size_t k = 0; k < sz; k++) { char t = x[k]; x[k] = y[k]; y[k] = t; } } }
void *bsearch(void const *key, void const *base, size_t n, size_t sz,
              int (*cmp)(void const *, void const *)) {
  char const *a = base;
  size_t lo = 0, hi = n;
  while (lo < hi) {
    size_t mid = lo + (hi - lo) / 2;
    int r = cmp(key, a + mid * sz);
    if (r == 0) return (void *) (a + mid * sz);
    if (r < 0) hi = mid; else lo = mid + 1; }
  return 0; }

/* path 2: execle, the environment after the NULL */
static int __execl(char const *p, char const *a0, va_list ap, int path) {
  va_list c; va_copy(c, ap);
  size_t n = 1;
  while (va_arg(c, char *)) n++;
  va_end(c);
  char *av[n + 1];
  av[0] = (char *) a0;
  for (size_t i = 1; i <= n; i++) av[i] = va_arg(ap, char *);   /* the last is the NULL */
  if (path == 2) return execve(p, av, va_arg(ap, char **));
  return path ? execvp(p, av) : execv(p, av); }
int execl(char const *p, char const *a0, ...) {
  va_list ap; va_start(ap, a0);
  int r = __execl(p, a0, ap, 0);
  va_end(ap);
  return r; }
int execlp(char const *f, char const *a0, ...) {
  va_list ap; va_start(ap, a0);
  int r = __execl(f, a0, ap, 1);
  va_end(ap);
  return r; }
int execle(char const *p, char const *a0, ...) {
  va_list ap; va_start(ap, a0);
  int r = __execl(p, a0, ap, 2);
  va_end(ap);
  return r; }
/* the limits every filesystem here shares; a name it has none for is -1, errno kept */
long fpathconf(int fd, int n) {
  switch (n) {
  case _PC_LINK_MAX: return 127;
  case _PC_MAX_CANON: case _PC_MAX_INPUT: return 255;
  case _PC_NAME_MAX: return NAME_MAX;
  case _PC_PATH_MAX: return PATH_MAX;
  case _PC_PIPE_BUF: return 4096;
  case _PC_CHOWN_RESTRICTED: case _PC_NO_TRUNC: return 1;
  case _PC_VDISABLE: return 0; }
  errno = EINVAL;
  return -1; }
long pathconf(char const *p, int n) { return fpathconf(-1, n); }
/* no signal juggling: love is single-threaded */
int system(char const *cmd) {
  if (!cmd) return 1;                          /* a shell is available */
  int pid = fork();
  if (pid < 0) return -1;
  if (pid == 0) {
    char *av[4]; av[0] = "sh"; av[1] = "-c"; av[2] = (char *) cmd; av[3] = 0;
    execv("/bin/sh", av);
    _exit(127); }
  int st = 0;
  while (waitpid(pid, &st, 0) < 0) if (errno != EINTR) return -1;
  return st; }
/* the child pid rides the FILE for pclose's wait */
FILE *popen(char const *cmd, char const *mode) {
  int fds[2];
  int rd = mode[0] == 'r';
  if (pipe(fds) < 0) return 0;
  int pid = fork();
  if (pid < 0) { close(fds[0]); close(fds[1]); return 0; }
  if (pid == 0) {
    dup2(rd ? fds[1] : fds[0], rd ? 1 : 0);
    close(fds[0]); close(fds[1]);
    char *av[4]; av[0] = "sh"; av[1] = "-c"; av[2] = (char *) cmd; av[3] = 0;
    execv("/bin/sh", av);
    _exit(127); }
  close(rd ? fds[1] : fds[0]);
  FILE *f = malloc(sizeof(FILE) + 4096);
  if (!f) { close(rd ? fds[0] : fds[1]); return 0; }
  memset(f, 0, sizeof(FILE));
  f->fd = rd ? fds[0] : fds[1];
  f->wr = !rd;
  f->heap = 1;
  f->pid = pid;
  if (!rd) { f->buf = (unsigned char *) (f + 1); f->cap = 4096; }
  else { f->rb = (unsigned char *) (f + 1); f->rcap = 4096; }
  __love_fopened(f);
  return f; }
int pclose(FILE *f) {
  int pid = f->pid, st = 0;
  int r = fclose(f);
  if (r == EOF) return -1;
  while (waitpid(pid, &st, 0) < 0) if (errno != EINTR) return -1;
  return st; }
/* unlinked at once, so it lives as long as the FILE */
FILE *tmpfile(void) {
  char buf[16];
  strcpy(buf, "/tmp/aiXXXXXX");
  mktemp(buf);
  if (!buf[0]) return 0;
  FILE *f = fopen(buf, "w+");
  if (f) unlink(buf);
  return f; }
int remove(char const *p) {                        /* a directory falls to rmdir */
  int r = unlink(p);
  return r == 0 ? 0 : rmdir(p); }
char *tmpnam(char *s) {                         
  static char b[20];
  if (!s) s = b;
  strcpy(s, "/tmp/aiXXXXXX");
  mktemp(s);
  return s[0] ? s : 0; }
/* racy by design: the caller opens the name */
char *mktemp(char *tmpl) {
  size_t n = strlen(tmpl);
  if (n < 6 || strcmp(tmpl + n - 6, "XXXXXX")) { tmpl[0] = 0; return tmpl; }
  char *x = tmpl + n - 6;
  unsigned long v = (unsigned long) getpid();
  for (int k = 0; k < 100; k++, v += 7777) {
    unsigned long w = v;
    for (int i = 0; i < 6; i++) { x[i] = 'a' + w % 26; w /= 26; }
    if (access(tmpl, 0) < 0) return tmpl; }
  tmpl[0] = 0;
  return tmpl; }
/* O_EXCL is the test; 384 = 0600 */
int mkstemp(char *tmpl) {
  size_t n = strlen(tmpl);
  if (n < 6 || strcmp(tmpl + n - 6, "XXXXXX")) { errno = EINVAL; return -1; }
  char *x = tmpl + n - 6;
  unsigned long v = (unsigned long) getpid() * 2654435761u;
  for (int k = 0; k < 1000; k++, v += 7777) {
    unsigned long w = v;
    for (int i = 0; i < 6; i++) { x[i] = 'a' + w % 26; w /= 26; }
    int fd = open(tmpl, O_RDWR | O_CREAT | O_EXCL, 384);
    if (fd >= 0 || errno != EEXIST) return fd; }
  return -1; }
/* mkstemp's walk, a directory made (448 = 0700) in place of a file opened */
char *mkdtemp(char *tmpl) {
  size_t n = strlen(tmpl);
  if (n < 6 || strcmp(tmpl + n - 6, "XXXXXX")) { errno = EINVAL; return 0; }
  char *x = tmpl + n - 6;
  unsigned long v = (unsigned long) getpid() * 2654435761u;
  for (int k = 0; k < 1000; k++, v += 7777) {
    unsigned long w = v;
    for (int i = 0; i < 6; i++) { x[i] = 'a' + w % 26; w /= 26; }
    if (mkdir(tmpl, 448) == 0) return tmpl;
    if (errno != EEXIST) return 0; }
  return 0; }
/* every category is C, but LC_CTYPE may be utf-8 (a name ending .UTF-8 or .utf8).
 * "" reads LC_ALL, then the category's variable, then LANG */
int __love_utf8;
static int lc_utf8(char const *n) {
  char const *d = strrchr(n, '.');
  return d && (!strcasecmp(d + 1, "UTF-8") || !strcasecmp(d + 1, "utf8")); }
char *setlocale(int cat, char const *loc) {
  static char names[LC_ALL][32] = {"C", "C", "C", "C", "C", "C"};
  static char const *const env[LC_ALL] = {"LC_CTYPE", "LC_NUMERIC", "LC_TIME", "LC_COLLATE",
                                          "LC_MONETARY", "LC_MESSAGES"};
  if (cat < 0 || cat > LC_ALL) return 0;
  int lo = cat == LC_ALL ? 0 : cat, hi = cat == LC_ALL ? LC_ALL : cat + 1;
  if (loc) {
    char const *want[LC_ALL];
    for (int k = lo; k < hi; k++) {
      char const *n = loc;
      if (!*n && !((n = getenv("LC_ALL")) && *n) && !((n = getenv(env[k])) && *n) && !((n = getenv("LANG")) && *n)) n = "C";
      if (strlen(n) >= sizeof *names || (strcmp(n, "C") && strcmp(n, "POSIX") && !lc_utf8(n))) return 0;
      want[k] = n; }
    for (int k = lo; k < hi; k++) strcpy(names[k], want[k]);
    __love_utf8 = lc_utf8(names[LC_CTYPE]); }
  return names[lo]; }
struct lconv *localeconv(void) {                
  static struct lconv c = { (char *) ".", (char *) "", (char *) "",
    (char *) "", (char *) "", (char *) "", (char *) "", (char *) "",
    (char *) "", (char *) "", 127, 127, 127, 127, 127, 127, 127, 127 };
  return &c; }

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
int fputs(char const *s, FILE *f) { size_t n = strlen(s); return fwrite(s, 1, n, f) == n ? 0 : EOF; }
int putchar(int c) { return fputc(c, stdout); }
int puts(char const *s) { return fputs(s, stdout) == EOF || fputc('\n', stdout) == EOF ? EOF : 0; }
int fgetc(FILE *f) { return getc(f); }
int getchar(void) { return getc(stdin); }
int ferror(FILE *f) { return f->err; }
int feof(FILE *f) { return f->eof; }
void clearerr(FILE *f) { f->err = 0; f->eof = 0; }
/* no name database: every lookup misses, so callers fall back to numeric ids */
struct passwd *getpwuid(uid_t u) { return 0; }
struct passwd *getpwnam(char const *n) { return 0; }
struct group *getgrgid(gid_t g) { return 0; }
struct group *getgrnam(char const *n) { return 0; }
struct passwd *getpwent(void) { return 0; }
struct group *getgrent(void) { return 0; }
void setpwent(void) { }
void endpwent(void) { }
void setgrent(void) { }
void endgrent(void) { }
intmax_t imaxabs(intmax_t v) { return v < 0 ? -v : v; }
imaxdiv_t imaxdiv(intmax_t n, intmax_t d) { imaxdiv_t r = { n / d, n % d }; return r; }

