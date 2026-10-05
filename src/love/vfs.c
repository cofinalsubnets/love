// src/love/vfs.c -- the tree both seats serve (vfs.h): the entry table over baked rows, the
// lookups, and the copies a write makes. inle's whole namespace rides it, and the host's /love.
#include "vfs.h"
#include "lib/ustar.h"
#include <errno.h>
#include <string.h>

// one ustar pass over a seat's tar: count with rows NULL, fill on the second. a symlink
// lands as a row whose target rides lnks[k].
static int vfs_tar_walk(struct vfs *v, unsigned char const *t, uintptr_t n, struct vfs_brow *rows, char **lnks) {
 int k = 0;
 for (uintptr_t o = 0; o + 512 <= n && t[o];) {
  unsigned char const *h = t + o;
  uintptr_t sz = ustar_octal(h + 124, 12);
  if (ustar_member(h)) {
   if (rows) {
    char nm[256];
    uintptr_t ln = ustar_name(h, nm, sizeof nm);
    char *p = vfs_strdup(v, nm, ln);
    if (!p) return -1;
    rows[k] = (struct vfs_brow) { { .path = p, .bytes = (char const *) t + o + 512,
                                    .len = sz, .ms = 1000 * ustar_octal(h + 136, 12) }, NULL };
    if (ustar_islink(h)) {
     char tgt[101], cn[256];
     tgt[ustar_link(h, tgt, sizeof tgt - 1)] = 0;
     uintptr_t cl = lnk_canon(p, tgt, cn, sizeof cn);
     if (!(lnks[k] = vfs_strdup(v, cn, cl))) return -1; } }
   k++; }
  o += 512 + ((sz + 511) & ~(uintptr_t) 511); }
 return k; }

bool vfs_untar(struct vfs *v, char const *pre, unsigned char const *z, uintptr_t zn,
               unsigned char const *tar, uintptr_t tn) {
 if (!tree_open(&v->src, z, zn, v->grab)) return false;
 int n1 = (int) v->src.n;
 if (n1 <= 0) return false;
 int n2 = tn ? vfs_tar_walk(v, tar, tn, NULL, NULL) : 0;
 if (n2 < 0) return false;
 int n = n1 + n2;
 uintptr_t pn = strlen(pre);
 struct vfs_brow *rows = v->grab((uintptr_t) n * sizeof *rows);
 char **lnks = v->grab((uintptr_t) n * sizeof *lnks);
 if (!rows || !lnks) return false;
 memset(lnks, 0, (uintptr_t) n * sizeof *lnks);
 for (int i = 0; i < n1; i++) {
  struct tree_row const *r = v->src.rows + i;
  uintptr_t ln = strlen(r->path);
  char *p = v->grab(pn + 1 + ln + 1);
  if (!p) return false;
  memcpy(p, pre, pn), p[pn] = '/';
  memcpy(p + pn + 1, r->path, ln + 1);
  rows[i] = (struct vfs_brow) { { .path = p, .len = r->len, .ms = 1000 * (uintptr_t) r->mtime }, r }; }
 if (n2 && vfs_tar_walk(v, tar, tn, rows + n1, lnks + n1) != n2) return false;
 // the tar's links resolved against the rows (two passes cover a link to a link), then the
 // table compacted: a dangling or directory link has no bytes to serve
 for (int pass = 0; pass < 2; pass++)
  for (int i = 0; i < n; i++)
   if (lnks[i])
    for (int j = 0; j < n; j++)
     if (!lnks[j] && !strcmp(rows[j].f.path, lnks[i])) {
      char const *p = rows[i].f.path;
      rows[i] = rows[j], rows[i].f.path = p;
      lnks[i] = NULL;
      break; }
 int m = 0;
 for (int i = 0; i < n; i++)
  if (!lnks[i]) rows[m++] = rows[i];
 v->drop(lnks);
 v->bakes = rows, v->bakes_n = m;
 return true; }

struct vfs_file const *vfs_bake_row(struct vfs const *v, int i) {
 return i < v->bakes_n ? &v->bakes[i].f : &v->extra[i - v->bakes_n]; }
unsigned char const *vfs_bake_bytes(struct vfs *v, int i) {
 return i < v->bakes_n && v->bakes[i].tree ? tree_bytes(&v->src, v->bakes[i].tree)
      : (unsigned char const *) vfs_bake_row(v, i)->bytes; }

int vfs_lay(struct vfs *v, int more) {
 int n = v->bakes_n + v->extra_n, cap = n + more;
 struct vfs_ent *t = v->grab((uintptr_t) cap * sizeof *t);
 if (!t) return -1;
 uintptr_t now = v->now();
 for (int i = 0; i < n; i++) {
  struct vfs_file const *f = vfs_bake_row(v, i);
  // a dateless row reads as now: the carried tree stamps 0, and 0 is how a stat says "not
  // there" -- cook then refuses to make a leaf that is right there
  t[i] = (struct vfs_ent) { .path = f->path, .bake = i, .ms = f->ms ? f->ms : now,
                            .mode = 0644, .live = true }; }
 memset(t + n, 0, (uintptr_t) more * sizeof *t);
 v->ents = t, v->n = cap, v->cap = cap;
 return n; }

unsigned char const *vfs_blob(struct vfs *v, int i, uintptr_t *len) {
 struct vfs_ent const *e = &v->ents[i];
 if (e->own) return *len = e->len, e->bytes;
 unsigned char const *b = vfs_bake_bytes(v, e->bake);
 return *len = b ? vfs_bake_row(v, e->bake)->len : 0, b ? b : (unsigned char const*) ""; }
uintptr_t vfs_size(struct vfs const *v, int i) {
 struct vfs_ent const *e = &v->ents[i];
 return e->own ? e->len : vfs_bake_row(v, e->bake)->len; }

intptr_t vfs_canon(struct vfs const *v, char const *p, uintptr_t pn, char *out) {
 uintptr_t n = 0;
 if (!(pn && p[0] == '/')) memcpy(out, v->cwd, n = v->cwd_n);
 return path_canon(out, n, p, pn, 256); }

// the mount is nobody's to write: every mutating door refuses it and what lies under
bool vfs_ro(struct vfs const *v, char const *cp, uintptr_t cn) {
 if (!v->ro) return false;
 uintptr_t r = strlen(v->ro);
 return cn >= r && !memcmp(cp, v->ro, r) && (cn == r || cp[r] == '/'); }

// ..and a move or a removal leaves these be besides: a special row, and every directory
// above one or above the mount, whose rename would carry them out from under their names
bool vfs_pinned(struct vfs const *v, char const *cp, uintptr_t cn) {
 if (vfs_ro(v, cp, cn)) return true;
 for (uintptr_t i = 0; cn && i <= v->npins; i++) {
  char const *q = i < v->npins ? v->pins[i] : v->ro;
  if (!q) continue;
  uintptr_t const n = strlen(q);
  if (cn <= n && !memcmp(cp, q, cn) && (cn == n || q[cn] == '/')) return true; }
 return false; }

// canonical path -> its live entry. linear: the rows are a few thousand at most
int vfs_find(struct vfs const *v, char const *p, uintptr_t n) {
 for (int i = 0; i < v->n; i++) {
  char const *q = v->ents[i].path;
  if (v->ents[i].live && q && strlen(q) == n && !memcmp(q, p, n)) return i; }
 return -1; }

// an expansion restarts the walk rather than splicing, and the budget is spent per
// resolution, so a chain and a deep path draw on the same 32
#define vfs_hops 32
intptr_t vfs_walk(struct vfs const *v, char const *p, uintptr_t pn, char *out, bool leaf) {
 char in[256], nx[256];
 if (pn >= sizeof in) return -ENAMETOOLONG;
 memcpy(in, p, pn);
 uintptr_t inn = pn;
 for (int hop = 0; ; ) {
  uintptr_t n = 0;
  if (!(inn && in[0] == '/')) memcpy(out, v->cwd, n = v->cwd_n);
  bool again = false;
  for (uintptr_t i = 0; i < inn; ) {
   while (i < inn && in[i] == '/') i++;
   uintptr_t j = i;
   while (j < inn && in[j] != '/') j++;
   if (j == i) break;
   intptr_t r = path_canon(out, n, in + i, j - i, 256);   // "." and ".." included, so ".."
   if (r < 0) return -ENAMETOOLONG;                          // lands on the RESOLVED path
   n = (uintptr_t) r;
   i = j;
   uintptr_t k = i;
   while (k < inn && in[k] == '/') k++;
   if (k >= inn && !leaf) break;                // the last name, kept as written
   int e = n ? vfs_find(v, out, n) : -1;
   if (e < 0 || !v->ents[e].to) continue;
   if (++hop > vfs_hops) return -ELOOP;
   // the target is canonicalized here and loses the leading slash entry paths lack; the
   // rebuilt line wears one, or the walk seeds from the cwd
   uintptr_t tn = lnk_canon(out, v->ents[e].to, nx + 1, sizeof nx - 1) + 1;
   nx[0] = '/';
   uintptr_t rest = inn - k;
   if (tn + 1 + rest >= sizeof nx) return -ENAMETOOLONG;
   if (rest) nx[tn++] = '/', memcpy(nx + tn, in + k, rest), tn += rest;
   memcpy(in, nx, inn = tn);
   again = true;
   break; }
  if (!again) return (intptr_t) n; } }

char const *vfs_entry(struct vfs const *v, int i, char const *p, uintptr_t pn, uintptr_t *len) {
 if (!v->ents[i].live || !v->ents[i].path) return NULL;
 char const *q = v->ents[i].path;
 uintptr_t ql = strlen(q);
 if (pn) {
  if (ql <= pn + 1 || memcmp(q, p, pn) || q[pn] != '/') return NULL;
  q += pn + 1, ql -= pn + 1; }
 uintptr_t k = 0;
 while (k < ql && q[k] != '/') k++;
 return *len = k, q; }

bool vfs_kids(struct vfs const *v, char const *p, uintptr_t pn, uintptr_t *ms) {
 bool any = false;
 *ms = 0;
 for (int i = 0; i < v->n; i++) {
  uintptr_t k;
  if (!vfs_entry(v, i, p, pn, &k)) continue;
  any = true;
  if (v->ents[i].ms > *ms) *ms = v->ents[i].ms; }
 return any; }

bool vfs_dirp(struct vfs const *v, char const *p, uintptr_t pn) {
 if (!pn) return true;
 int i = vfs_find(v, p, pn);
 if (i >= 0) return v->ents[i].dir;
 uintptr_t junk;
 return vfs_kids(v, p, pn, &junk); }

int vfs_child(struct vfs const *v, char const *p, uintptr_t pn, int *cur, char const **name,
              uintptr_t *len, bool *dir) {
 for (int i = *cur; i < v->n; i++) {
  uintptr_t k;
  char const *e = vfs_entry(v, i, p, pn, &k);
  if (!e) continue;
  bool seen = false;                          // one name, at the entry that first carries it
  for (int j = 0; j < i && !seen; j++) {
   uintptr_t k2;
   char const *e2 = vfs_entry(v, j, p, pn, &k2);
   seen = e2 && k2 == k && !memcmp(e, e2, k); }
  if (seen) continue;
  *name = e, *len = k, *dir = e[k] == '/' || v->ents[i].dir, *cur = i + 1;
  return i; }
 return -1; }

int vfs_stat(struct vfs *v, char const *cp, uintptr_t cn, struct vfs_st *st) {
 int i = cn ? vfs_find(v, cp, cn) : -1;
 uintptr_t kid = 0;
 bool kids = vfs_kids(v, cp, cn, &kid);
 *st = (struct vfs_st) { i, 0, 0, 0, 0 };
 if (i >= 0) {
  struct vfs_ent const *e = &v->ents[i];
  st->kind = e->to ? 3 : e->dir ? 2 : 1, st->mode = e->mode, st->ms = e->ms;
  st->size = e->to ? strlen(e->to) : e->dir ? 0 : vfs_size(v, i);
  if (e->dir && kid > st->ms) st->ms = kid;
  return st->kind; }
 if (!cn || kids) return st->kind = 2, st->mode = 0755, st->ms = kid, 2;
 return 0; }

// the parent a path wants to land in: 0 when it is a directory, else the errno the host
// would say (a hole ENOENT, a file in the way ENOTDIR)
int vfs_parent_ok(struct vfs const *v, char const *p, uintptr_t n) {
 uintptr_t dn = n;
 while (dn && p[dn - 1] != '/') dn--;
 if (dn) dn--;
 if (!dn) return 0;
 int i = vfs_find(v, p, dn);
 if (i >= 0) return v->ents[i].dir ? 0 : -ENOTDIR;
 uintptr_t junk;
 return vfs_kids(v, p, dn, &junk) ? 0 : -ENOENT; }

// a slot for a fresh entry: a retired one first, else the table doubles. -1 is a refusal.
int vfs_slot(struct vfs *v) {
 for (int i = 0; i < v->n; i++) if (!v->ents[i].path) return i;
 if (v->n == v->cap) {
  int cap = v->cap * 2;
  struct vfs_ent *t = v->grab((uintptr_t) cap * sizeof *t);
  if (!t) return -1;
  memcpy(t, v->ents, (uintptr_t) v->n * sizeof *t);
  v->drop(v->ents);
  v->ents = t, v->cap = cap; }
 return v->n++; }

char *vfs_strdup(struct vfs *v, char const *p, uintptr_t n) {
 char *q = v->grab(n + 1);
 if (q) memcpy(q, p, n), q[n] = 0;
 return q; }

// free a dead, unheld entry's storage and retire the slot. unlink and the last close both
// land here, so an open fd keeps its file until it lets go.
void vfs_gc(struct vfs *v, int i) {
 struct vfs_ent *e = &v->ents[i];
 if (e->live || e->refs || !e->path) return;
 if (e->own) v->drop(e->bytes);
 if (e->heap) v->drop((void*) e->path);
 if (e->to) v->drop((void*) e->to);
 *e = (struct vfs_ent) {0}; }

// a fresh live entry at canonical path p; the caller has asked vfs_parent_ok. -1 is memory.
int vfs_create(struct vfs *v, char const *p, uintptr_t n, bool dir, uintptr_t mode) {
 char *q = vfs_strdup(v, p, n);
 if (!q) return -1;
 int i = vfs_slot(v);
 if (i < 0) return v->drop(q), -1;
 v->ents[i] = (struct vfs_ent) { .path = q, .bake = -1, .ms = v->now(), .mode = mode,
                                 .own = true, .heap = true, .dir = dir, .live = true };
 return i; }

// room for `need` bytes in entry i's heap copy, the baked blob brought across at the first
// write. false is a refusal the caller must read and say; nothing is dropped quietly.
bool vfs_fit(struct vfs *v, int i, uintptr_t need) {
 struct vfs_ent *e = &v->ents[i];
 if (need > (uintptr_t) INTPTR_MAX) return false;   // the doubling below stays in range
 if (!e->own) {
  unsigned char const *b = vfs_bake_bytes(v, e->bake);
  if (!b) return false;
  uintptr_t n = vfs_bake_row(v, e->bake)->len, cap = n > need ? n : need;
  unsigned char *p = cap ? v->grab(cap) : NULL;
  if (cap && !p) return false;
  if (n) memcpy(p, b, n);
  e->bytes = p, e->len = n, e->cap = cap, e->own = true;
  return true; }
 if (e->cap >= need) return true;
 uintptr_t cap = e->cap ? e->cap : 64;
 while (cap < need) cap *= 2;
 unsigned char *p = v->grab(cap);
 if (!p) return false;
 if (e->len) memcpy(p, e->bytes, e->len);
 v->drop(e->bytes);
 e->bytes = p, e->cap = cap;
 return true; }
