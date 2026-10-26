#include "../impl.h"
#include <glob.h>
#include <fnmatch.h>
#include <dirent.h>

/* a pattern expands one component at a time over the paths matched so far, so the walk is a
 * loop, never a recursion; a component with no wildcard is joined as is and checked at the end */
typedef struct { char **v; size_t n, cap; } gvec;
static int gv_put(gvec *g, char *s) {
  if (!s) return GLOB_NOSPACE;
  if (g->n == g->cap) {
    size_t c = g->cap ? g->cap * 2 : 16;
    char **v = realloc(g->v, c * sizeof *v);
    if (!v) { free(s); return GLOB_NOSPACE; }
    g->v = v; g->cap = c; }
  g->v[g->n++] = s; return 0; }
static void gv_free(gvec *g) { for (size_t i = 0; i < g->n; i++) free(g->v[i]); free(g->v); g->v = 0; g->n = g->cap = 0; }
static char *g_join(char const *p, char const *c, size_t cn, char const *tail) {
  size_t pn = strlen(p), tn = strlen(tail), sl = pn && p[pn - 1] != '/';
  char *s = malloc(pn + sl + cn + tn + 1);
  if (!s) return 0;
  memcpy(s, p, pn); if (sl) s[pn] = '/';
  memcpy(s + pn + sl, c, cn); memcpy(s + pn + sl + cn, tail, tn + 1);
  return s; }
static int g_magic(char const *c, size_t n, int esc) {
  for (size_t i = 0; i < n; i++) {
    if (esc && c[i] == '\\' && i + 1 < n) { i++; continue; }
    if (c[i] == '*' || c[i] == '?' || c[i] == '[') return 1; }
  return 0; }
static int g_isdir(char const *p) { struct stat st; return stat(p, &st) == 0 && S_ISDIR(st.st_mode); }
static int g_cmp(void const *a, void const *b) { return strcmp(*(char *const *) a, *(char *const *) b); }

int glob(char const *pat, int fl, int (*errf)(char const *, int), glob_t *gl) {
  int esc = !(fl & GLOB_NOESCAPE), r = 0;
  gvec cur = {0}, nxt = {0};
  char comp[PATH_MAX];
  if ((r = gv_put(&cur, g_join("", pat, *pat == '/', "")))) return r;
  char const *p = pat;
  int dirs = 0;                                  /* the pattern ends in /: directories only */
  while (*p) {
    while (*p == '/') p++;
    char const *b = p;
    while (*p && *p != '/') p++;
    size_t cn = (size_t) (p - b);
    if (!cn) { dirs = 1; break; }
    if (cn >= PATH_MAX) { r = GLOB_NOSPACE; goto out; }
    int mg = g_magic(b, cn, esc);
    if (!mg && esc) {                            /* a literal: its escapes come off */
      size_t k = 0;
      for (size_t i = 0; i < cn; i++) { if (b[i] == '\\' && i + 1 < cn) i++; comp[k++] = b[i]; }
      cn = k; }
    else memcpy(comp, b, cn);
    comp[cn] = 0;
    for (size_t i = 0; i < cur.n && !r; i++) {
      if (!mg) { r = gv_put(&nxt, g_join(cur.v[i], comp, cn, "")); continue; }
      char const *dn = *cur.v[i] ? cur.v[i] : ".";
      DIR *d = opendir(dn);
      if (!d) {
        if (__errno_v != ENOENT && __errno_v != ENOTDIR &&
            ((errf && errf(dn, __errno_v)) || (fl & GLOB_ERR))) r = GLOB_ABORTED;
        continue; }
      struct dirent *e;
      int ff = (esc ? 0 : FNM_NOESCAPE) | (fl & GLOB_PERIOD ? 0 : FNM_PERIOD);
      while (!r && (e = readdir(d))) {
        char const *nm = e->d_name;
        if (nm[0] == '.' && (!nm[1] || (nm[1] == '.' && !nm[2])) && comp[0] != '.') continue;
        if (!fnmatch(comp, nm, ff)) r = gv_put(&nxt, g_join(cur.v[i], nm, strlen(nm), "")); }
      closedir(d); }
    gv_free(&cur); cur = nxt; nxt = (gvec) {0};
    if (r) goto out; }
  /* keep what exists (a literal component was never looked at), marked as asked */
  gvec got = {0};
  for (size_t i = 0; i < cur.n && !r; i++) {
    struct stat st;
    char *s = cur.v[i]; cur.v[i] = 0;
    if (lstat(s, &st) < 0 || (dirs && !g_isdir(s))) { free(s); continue; }
    if ((dirs || (fl & GLOB_MARK)) && g_isdir(s) && s[strlen(s) - 1] != '/') {
      char *m = g_join(s, "", 0, ""); free(s); s = m; }   /* the join lays the / */
    r = gv_put(&got, s); }
  gv_free(&cur); cur = got;
  if (r) goto out;
  if (!cur.n) {
    if (!(fl & GLOB_NOCHECK)) { r = GLOB_NOMATCH; goto out; }
    char *s = malloc(strlen(pat) + 1);
    if ((r = gv_put(&cur, s ? strcpy(s, pat) : 0))) goto out; }
  if (!(fl & GLOB_NOSORT)) qsort(cur.v, cur.n, sizeof *cur.v, g_cmp);
  size_t offs = fl & GLOB_DOOFFS ? gl->gl_offs : 0, had = fl & GLOB_APPEND ? gl->gl_pathc : 0;
  if (!(fl & GLOB_APPEND)) gl->gl_pathv = 0;
  char **v = realloc(gl->gl_pathv, (offs + had + cur.n + 1) * sizeof *v);
  if (!v) { r = GLOB_NOSPACE; goto out; }
  if (!(fl & GLOB_APPEND)) for (size_t i = 0; i < offs; i++) v[i] = 0;
  memcpy(v + offs + had, cur.v, cur.n * sizeof *v);
  v[offs + had + cur.n] = 0;
  gl->gl_pathv = v; gl->gl_pathc = had + cur.n; gl->gl_flags = fl;
  free(cur.v);
  return 0;
out:
  gv_free(&cur); gv_free(&nxt);
  return r; }
void globfree(glob_t *gl) {
  size_t offs = gl->gl_flags & GLOB_DOOFFS ? gl->gl_offs : 0;
  if (gl->gl_pathv) for (size_t i = 0; i < gl->gl_pathc; i++) free(gl->gl_pathv[offs + i]);
  free(gl->gl_pathv);
  gl->gl_pathv = 0; gl->gl_pathc = 0; }
