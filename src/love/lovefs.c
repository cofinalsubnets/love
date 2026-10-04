// src/love/lovefs.c -- /love on the host: the tree the binary carries (srctree), served to
// this process alone. posix.c's open, stat, lstat, readdir and readlink ask here before the
// OS; inle's kernel serves /love itself, so on that seat nothing here answers. a child that
// is not love cannot see it. the same open tree backs src.c's tree nifs and the bake (main.c).
#include "love.h"
#include "lib/srctree.h"
#include "lib/ustar.h"
#include <errno.h>
#include <string.h>
#include <time.h>

// the tree, opened at the first ask: the binary's own does not move while it runs, so one
// per process stands (the rare static). its sections decode as their rows are first read.
static struct lovefs { struct tree t; bool tried, ok; } lovefs;

static void *lovefs_grab(uintptr_t n) { return alloc(NULL, n); }

struct tree *tree_carried(void) {
 if (!lovefs.tried) {
  lovefs.tried = true;
  lovefs.ok = srctree_len && tree_open(&lovefs.t, srctree, srctree_len, lovefs_grab);
  // a dateless row reads as the moment the tree opened, once, so two stats agree
  struct timespec now;
  clock_gettime(CLOCK_REALTIME, &now);
  for (uintptr_t i = 0; lovefs.ok && i < lovefs.t.n; i++)
   if (!lovefs.t.rows[i].mtime) lovefs.t.rows[i].mtime = (uint32_t) now.tv_sec; }
 return lovefs.ok ? &lovefs.t : NULL; }

// a path -> where it falls: -1 not the tree's (the OS answers), -2 absent under /love,
// -3 a directory, else the row it names. rel takes the tree-relative name (cap 256), ""
// for /love itself. absolute paths only: the host's cwd is never under /love.
intptr_t lovefs_at(char const *p, char *rel, uintptr_t *rn) {
 if (__love_osv < 0 || !p || p[0] != '/' || !srctree_len) return -1;
 char c[256];
 intptr_t cn = path_canon(c, 0, p, strlen(p), sizeof c);
 if (cn < 4 || memcmp(c, "love", 4) || (cn > 4 && c[4] != '/')) return -1;
 uintptr_t r = cn > 4 ? (uintptr_t) cn - 5 : 0;
 memcpy(rel, c + (cn > 4 ? 5 : 4), r);
 rel[r] = 0, *rn = r;
 struct tree *t = tree_carried();
 if (!t) return -1;                               // a tree that will not open: the OS's
 if (!r) return -3;
 intptr_t i = tree_find(t, rel, r);
 if (i >= 0) return i;
 for (uintptr_t j = 0, n = t->n; j < n; j++)
  if (strlen(t->rows[j].path) > r && !memcmp(t->rows[j].path, rel, r) && t->rows[j].path[r] == '/')
   return -3;
 return -2; }

// a read port over row i's bytes, its section decoded now if no read has yet. they stay for
// the life of the process, so the cell holds their address and the cursor as charms,
// nothing to trace. a section that will not decode is EIO.
struct lovefs_port { struct io io; word at, len, pos; };
static struct g *lovefs_flush(struct g *g) { return g; }
static intptr_t lovefs_readn(struct g *g, unsigned char *dst, uintptr_t n) {
 struct lovefs_port *q = (struct lovefs_port*) g->io;
 uintptr_t pos = (uintptr_t) getcharm(q->pos), len = (uintptr_t) getcharm(q->len);
 if (pos >= len) return -1;
 uintptr_t k = len - pos < n ? len - pos : n;
 memcpy(dst, (unsigned char const*) getcharm(q->at) + pos, k);
 q->pos = putcharm((intptr_t) (pos + k));
 return (intptr_t) k; }
static uintptr_t lovefs_athand(struct g *g, uintptr_t n) {
 struct lovefs_port *q = (struct lovefs_port*) g->io;
 uintptr_t left = (uintptr_t) (getcharm(q->len) - getcharm(q->pos));
 return left < n ? left : n; }
static struct port_vt const lovefs_vt = { lovefs_flush, NULL, lovefs_readn, lovefs_athand };

struct g *lovefs_port(struct g *g, uintptr_t i) {
 struct tree_row const *r = lovefs.t.rows + i;
 unsigned char const *b = tree_bytes(&lovefs.t, r);
 if (!b) return push(g, 1, love_err(g, EIO));
 uintptr_t const n = Width(struct lovefs_port);
 if (!ok(g = have(g, n + Width(struct tag) + 1))) return g;
 union u *k = bump(g, n + Width(struct tag));
 struct lovefs_port *q = (struct lovefs_port*) k;
 q->io.ap = lvm_port_io;
 q->io.vt = &lovefs_vt;
 q->io.ungetc_buf = putcharm(EOF);
 q->at = putcharm((intptr_t) b);
 q->len = putcharm((intptr_t) r->len);
 q->pos = putcharm(0);
 *--g->sp = (word) tagthread(k, n);
 return g; }
