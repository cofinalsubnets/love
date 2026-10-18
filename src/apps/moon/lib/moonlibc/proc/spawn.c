#include "../impl.h"
#include <spawn.h>
#include <sys/wait.h>

/* inle has a spawn call, taking (op fd src) triples; elsewhere it is fork and exec */

int posix_spawn_file_actions_init(posix_spawn_file_actions_t *fa) {
  *fa = (posix_spawn_file_actions_t) {0};
  return 0; }
int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t *fa) {
  for (int i = 0; i < fa->n; i++) free(fa->a[i].path);
  free(fa->a);
  *fa = (posix_spawn_file_actions_t) {0};
  return 0; }
static int sp_add(posix_spawn_file_actions_t *fa, struct __spawn_act a) {
  if (a.fd < 0 || (a.kind == 1 && a.src < 0)) return EBADF;
  if (fa->n == fa->cap) {
    int m = fa->cap ? 2 * fa->cap : 8;
    struct __spawn_act *t = realloc(fa->a, (size_t) m * sizeof *t);
    if (!t) return ENOMEM;
    fa->a = t, fa->cap = m; }
  fa->a[fa->n++] = a;
  return 0; }
int posix_spawn_file_actions_adddup2(posix_spawn_file_actions_t *fa, int src, int fd) {
  return sp_add(fa, (struct __spawn_act) { .kind = 1, .fd = fd, .src = src }); }
int posix_spawn_file_actions_addclose(posix_spawn_file_actions_t *fa, int fd) {
  return sp_add(fa, (struct __spawn_act) { .kind = 2, .fd = fd }); }
int posix_spawn_file_actions_addopen(posix_spawn_file_actions_t *fa, int fd, char const *p,
                                     int fl, mode_t m) {
  char *c = strdup(p);
  if (!c) return ENOMEM;
  int r = sp_add(fa, (struct __spawn_act) { .kind = 3, .fd = fd, .flags = fl, .mode = m, .path = c });
  if (r) free(c);
  return r; }

int posix_spawnattr_init(posix_spawnattr_t *at) { *at = (posix_spawnattr_t) {0}; return 0; }
int posix_spawnattr_destroy(posix_spawnattr_t *at) { (void) at; return 0; }
int posix_spawnattr_setflags(posix_spawnattr_t *at, short f) { at->flags = f; return 0; }
int posix_spawnattr_getflags(posix_spawnattr_t const *at, short *f) { *f = at->flags; return 0; }
int posix_spawnattr_setpgroup(posix_spawnattr_t *at, pid_t g) { at->pgroup = g; return 0; }
int posix_spawnattr_getpgroup(posix_spawnattr_t const *at, pid_t *g) { *g = at->pgroup; return 0; }
int posix_spawnattr_setsigdefault(posix_spawnattr_t *at, sigset_t const *s) { at->def = *s; return 0; }
int posix_spawnattr_getsigdefault(posix_spawnattr_t const *at, sigset_t *s) { *s = at->def; return 0; }
int posix_spawnattr_setsigmask(posix_spawnattr_t *at, sigset_t const *s) { at->mask = *s; return 0; }
int posix_spawnattr_getsigmask(posix_spawnattr_t const *at, sigset_t *s) { *s = at->mask; return 0; }

static size_t sp_words(char *b, char *const *v) {   /* laid at b if b */
  size_t n = 0;
  for (; v && *v; v++) {
    size_t k = strlen(*v) + 1;
    if (b) memcpy(b + n, *v, k);
    n += k; }
  return n; }

static long sp_inle(char const *f, posix_spawn_file_actions_t const *fa,
                    char *const *av, char *const *ev) {
  int n = fa ? fa->n : 0, opened = 0;
  size_t fn = strlen(f) + 1, wn = fn + sp_words(NULL, av), en = sp_words(NULL, ev);
  char *w = malloc(wn), *e = malloc(en + 1);
  int *op = malloc((size_t) (n + 1) * 3 * sizeof *op), *tmp = malloc((size_t) (n + 1) * sizeof *tmp);
  long r = w && e && op && tmp ? 0 : -ENOMEM;
  for (int i = 0; !r && i < n; i++) {
    struct __spawn_act const *a = &fa->a[i];
    int src = a->src;
    if (a->kind == 3) {
      if ((src = open(a->path, a->flags | O_CLOEXEC, a->mode)) < 0) { r = -__errno_v; break; }
      tmp[opened++] = src; }
    op[3 * i] = a->kind == 2 ? 2 : 1, op[3 * i + 1] = a->fd, op[3 * i + 2] = src; }
  if (!r) {
    memcpy(w, f, fn), sp_words(w + fn, av), sp_words(e, ev);
    r = sc6(NR_inle_spawn, (long) w, (long) wn, (long) e, (long) en, (long) op, (long) n * 12); }
  while (opened) close(tmp[--opened]);
  free(w), free(e), free(op), free(tmp);
  return r; }

static int sp_go(pid_t *pid, char const *f, posix_spawn_file_actions_t const *fa,
                 posix_spawnattr_t const *at, char *const *av, char *const *ev, int path) {
  long r = sp_inle(f, fa, av, ev ? ev : environ);
  if (r != -ENOSYS) {
    if (r < 0) return (int) -r;
    if (pid) *pid = (pid_t) r;
    return 0; }
  pid_t c = fork();
  if (c < 0) return __errno_v;
  if (!c) {
    short fl = at ? at->flags : 0;
    if (fl & POSIX_SPAWN_SETPGROUP && setpgid(0, at->pgroup)) _exit(127);
    if (fl & POSIX_SPAWN_SETSIGMASK) sigprocmask(SIG_SETMASK, &at->mask, NULL);
    if (fl & POSIX_SPAWN_SETSIGDEF)
      for (int s = 1; s < 65; s++) if (sigismember(&at->def, s) == 1) signal(s, SIG_DFL);
    for (int i = 0; fa && i < fa->n; i++) {
      struct __spawn_act const *a = &fa->a[i];
      if (a->kind == 2) { close(a->fd); continue; }
      int s = a->kind == 3 ? open(a->path, a->flags, a->mode) : a->src;
      if (s < 0) _exit(127);
      if (s == a->fd) fcntl(s, F_SETFD, 0);
      else if (dup2(s, a->fd) < 0) _exit(127);
      if (a->kind == 3 && s != a->fd) close(s); }
    if (ev) environ = (char**) ev;
    path ? execvp(f, av) : execv(f, av);
    _exit(127); }
  if (pid) *pid = c;
  return 0; }

int posix_spawn(pid_t *pid, char const *p, posix_spawn_file_actions_t const *fa,
                posix_spawnattr_t const *at, char *const av[], char *const ev[]) {
  return sp_go(pid, p, fa, at, av, ev, 0); }
int posix_spawnp(pid_t *pid, char const *f, posix_spawn_file_actions_t const *fa,
                 posix_spawnattr_t const *at, char *const av[], char *const ev[]) {
  return sp_go(pid, f, fa, at, av, ev, 1); }
