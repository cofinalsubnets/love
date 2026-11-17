#include "../impl.h"
#include <pwd.h>
#include <grp.h>

/* /etc/passwd and /etc/group, read a line at a time. the _r forms lay a record in the
 * caller's buffer: a found one answers 0 with *res set, a miss 0 with *res null, a short
 * buffer ERANGE. the plain forms are them over libc's own record and a buffer that grows */

static int pwid(char const *s, unsigned int *v) {         /* a field of digits, no more */
  if (!*s) return -1;
  unsigned long n = 0;
  for (; *s; s++) { if (*s < '0' || *s > '9') return -1; n = n * 10 + (unsigned) (*s - '0'); }
  return *v = (unsigned int) n, 0; }
/* split a copy of ln at ':' into f, exactly k fields; 0 or -1 */
static int pwcut(char *ln, char **f, int k) {
  int i = 0;
  f[i++] = ln;
  for (char *p = ln; *p; p++) if (*p == ':') { if (i == k) return -1; *p = 0, f[i++] = p + 1; }
  return i == k ? 0 : -1; }
/* one passwd line into p and buf: 0 laid, -1 malformed, ERANGE short */
static int pwlay(char const *ln, struct passwd *p, char *buf, size_t n) {
  size_t l = strlen(ln) + 1;
  char *f[7];
  if (l > n) return ERANGE;
  memcpy(buf, ln, l);
  unsigned int u, g;
  if (pwcut(buf, f, 7) || pwid(f[2], &u) || pwid(f[3], &g)) return -1;
  p->pw_name = f[0], p->pw_passwd = f[1], p->pw_uid = u, p->pw_gid = g;
  p->pw_gecos = f[4], p->pw_dir = f[5], p->pw_shell = f[6];
  return 0; }
/* one group line: the member pointers first, aligned, then the text */
static int grlay(char const *ln, struct group *g, char *buf, size_t n) {
  size_t l = strlen(ln) + 1, k = 2;
  for (char const *p = ln; *p; p++) k += *p == ',';
  char **mem = (char **) (((unsigned long) buf + sizeof(char *) - 1) & ~(sizeof(char *) - 1));
  char *t = (char *) (mem + k), *f[4];
  if ((size_t) (t - buf) + l > n) return ERANGE;
  memcpy(t, ln, l);
  unsigned int id;
  if (pwcut(t, f, 4) || pwid(f[2], &id)) return -1;
  size_t m = 0;
  if (*f[3]) for (char *p = f[3];;) {
    mem[m++] = p;
    while (*p && *p != ',') p++;
    if (!*p) break;
    *p++ = 0; }
  mem[m] = 0;
  g->gr_name = f[0], g->gr_passwd = f[1], g->gr_gid = id, g->gr_mem = mem;
  return 0; }

/* a file's next good record from fp: 0 laid, ENOENT at its end, ERANGE short (the line
 * rewound to, so a bigger buffer asks for it again). ok() picks the one wanted */
static int dbnext(FILE *fp, int grp, void *rec, char *buf, size_t n,
                  int (*ok)(void const *rec, void const *key), void const *key) {
  char *ln = 0;
  size_t cap = 0;
  for (;;) {
    long at = ftell(fp), r = getline(&ln, &cap, fp);
    if (r < 0) { free(ln); return ENOENT; }
    if (r && ln[r - 1] == '\n') ln[r - 1] = 0;
    if (*ln == '+' || *ln == '-' || *ln == '#' || !*ln) continue;   /* nis marks and blanks */
    int e = grp ? grlay(ln, rec, buf, n) : pwlay(ln, rec, buf, n);
    if (e == ERANGE) { fseek(fp, at, SEEK_SET); free(ln); return ERANGE; }
    if (!e && (!ok || ok(rec, key))) { free(ln); return 0; } } }
static int dbfind(char const *path, int grp, void *rec, char *buf, size_t n, void **res,
                  int (*ok)(void const *, void const *), void const *key) {
  int sv = errno;
  FILE *fp = fopen(path, "re");
  *res = 0;
  if (!fp) return errno == ENOENT ? (errno = sv, 0) : errno;
  int e = dbnext(fp, grp, rec, buf, n, ok, key);
  fclose(fp);
  if (!e) *res = rec;
  return e == ENOENT ? 0 : e; }

static int pwnam(void const *r, void const *k) { return !strcmp(((struct passwd const *) r)->pw_name, k); }
static int pwuid(void const *r, void const *k) { return ((struct passwd const *) r)->pw_uid == *(uid_t const *) k; }
static int grnam(void const *r, void const *k) { return !strcmp(((struct group const *) r)->gr_name, k); }
static int grgid(void const *r, void const *k) { return ((struct group const *) r)->gr_gid == *(gid_t const *) k; }

int getpwnam_r(char const *nm, struct passwd *p, char *b, size_t n, struct passwd **res) {
  return dbfind("/etc/passwd", 0, p, b, n, (void **) res, pwnam, nm); }
int getpwuid_r(uid_t u, struct passwd *p, char *b, size_t n, struct passwd **res) {
  return dbfind("/etc/passwd", 0, p, b, n, (void **) res, pwuid, &u); }
int getgrnam_r(char const *nm, struct group *g, char *b, size_t n, struct group **res) {
  return dbfind("/etc/group", 1, g, b, n, (void **) res, grnam, nm); }
int getgrgid_r(gid_t id, struct group *g, char *b, size_t n, struct group **res) {
  return dbfind("/etc/group", 1, g, b, n, (void **) res, grgid, &id); }

/* the walks: one open stream each, the process's */
static FILE *__pwf, *__grf;
static int dbent(FILE **fp, char const *path, int grp, void *rec, char *b, size_t n, void **res) {
  *res = 0;
  if (!*fp && !(*fp = fopen(path, "re"))) return ENOENT;
  int e = dbnext(*fp, grp, rec, b, n, 0, 0);
  if (!e) *res = rec;
  return e; }
int getpwent_r(struct passwd *p, char *b, size_t n, struct passwd **res) {
  return dbent(&__pwf, "/etc/passwd", 0, p, b, n, (void **) res); }
int getgrent_r(struct group *g, char *b, size_t n, struct group **res) {
  return dbent(&__grf, "/etc/group", 1, g, b, n, (void **) res); }
void setpwent(void) { if (__pwf) rewind(__pwf); }
void endpwent(void) { if (__pwf) fclose(__pwf), __pwf = 0; }
void setgrent(void) { if (__grf) rewind(__grf); }
void endgrent(void) { if (__grf) fclose(__grf), __grf = 0; }

/* the plain forms: libc's one record each, its buffer doubled until the line fits */
static struct passwd __pw;
static struct group __gr;
static char *__pwb, *__grb;
static size_t __pwn, __grn;
static void *dbplain(int grp, int (*f)(void *rec, char *b, size_t n, void **res, void const *k), void const *k) {
  char **b = grp ? &__grb : &__pwb;
  size_t *n = grp ? &__grn : &__pwn;
  void *rec = grp ? (void *) &__gr : (void *) &__pw, *res = 0;
  if (!*b && !(*b = malloc(*n = 1024))) return 0;
  for (;;) {
    int e = f(rec, *b, *n, &res, k);
    if (e != ERANGE) { if (e && e != ENOENT) errno = e; return res; }
    char *q = realloc(*b, *n * 2);
    if (!q) { errno = ENOMEM; return 0; }
    *b = q, *n *= 2; } }
static int pnam(void *r, char *b, size_t n, void **res, void const *k) { return getpwnam_r(k, r, b, n, (struct passwd **) res); }
static int puid(void *r, char *b, size_t n, void **res, void const *k) { return getpwuid_r(*(uid_t const *) k, r, b, n, (struct passwd **) res); }
static int pent(void *r, char *b, size_t n, void **res, void const *k) { return getpwent_r(r, b, n, (struct passwd **) res); }
static int gnam(void *r, char *b, size_t n, void **res, void const *k) { return getgrnam_r(k, r, b, n, (struct group **) res); }
static int ggid(void *r, char *b, size_t n, void **res, void const *k) { return getgrgid_r(*(gid_t const *) k, r, b, n, (struct group **) res); }
static int gent(void *r, char *b, size_t n, void **res, void const *k) { return getgrent_r(r, b, n, (struct group **) res); }
struct passwd *getpwnam(char const *nm) { return dbplain(0, pnam, nm); }
struct passwd *getpwuid(uid_t u) { return dbplain(0, puid, &u); }
struct passwd *getpwent(void) { return dbplain(0, pent, 0); }
struct group *getgrnam(char const *nm) { return dbplain(1, gnam, nm); }
struct group *getgrgid(gid_t g) { return dbplain(1, ggid, &g); }
struct group *getgrent(void) { return dbplain(1, gent, 0); }
