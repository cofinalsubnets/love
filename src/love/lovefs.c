// src/love/lovefs.c -- /love on the host: the tree the binary carries, through the vfs inle's
// kernel serves its namespace with (vfs.h), to this process alone. posix.c's open, stat,
// lstat, readdir and readlink ask here before the OS; inle's kernel serves /love itself, so on
// that seat nothing here answers. a child that is not love cannot see it. the same open tree
// backs src.c's tree nifs and the bake (main.c).
#include "love.h"
#include "vfs.h"
#include "lib/srctree.h"
#include "lib/ustar.h"
#include <errno.h>
#include <string.h>
#include <time.h>

// the tree, opened at the first ask: the binary's own does not move while it runs, so one
// per process stands (the rare static). nothing here writes it, so nothing is let go.
static struct lovefs { struct vfs v; bool tried, ok; } lovefs;

static void *lovefs_grab(uintptr_t n) { return alloc(NULL, n); }
static void lovefs_drop(void *p) { (void) p; }
// a dateless row reads as the moment the tree opened: one clock read, so two stats agree
static uintptr_t lovefs_now(void) {
 struct timespec now;
 clock_gettime(CLOCK_REALTIME, &now);
 return (uintptr_t) now.tv_sec * 1000; }

static struct vfs *lovefs_vfs(void) {
 if (!lovefs.tried) {
  lovefs.tried = true;
  lovefs.v = (struct vfs) { .ro = "love", .grab = lovefs_grab, .drop = lovefs_drop, .now = lovefs_now };
  lovefs.ok = srctree_len && vfs_untar(&lovefs.v, "love", srctree, srctree_len, NULL, 0)
              && vfs_lay(&lovefs.v, 0) >= 0; }
 return lovefs.ok ? &lovefs.v : NULL; }

struct tree *tree_carried(void) {
 struct vfs *v = lovefs_vfs();
 return v ? &v->src : NULL; }

// a path -> where it falls: -1 not the tree's (the OS answers), -2 absent under /love, -3 a
// directory, else the entry it names. c takes the canonical path ("love/.."), cap 256.
// absolute paths only: the host's cwd is never under /love.
intptr_t lovefs_at(char const *p, char *c, uintptr_t *cn) {
 if (__love_osv < 0 || !p || p[0] != '/' || !srctree_len) return -1;
 intptr_t n = path_canon(c, 0, p, strlen(p), 256);
 if (n < 4 || memcmp(c, "love", 4) || (n > 4 && c[4] != '/')) return -1;
 struct vfs *v = lovefs_vfs();
 if (!v) return -1;                               // a tree that will not open: the OS's
 c[n] = 0, *cn = (uintptr_t) n;
 intptr_t i = vfs_find(v, c, (uintptr_t) n);
 return i >= 0 ? i : vfs_dirp(v, c, (uintptr_t) n) ? -3 : -2; }

// what the stat of a canonical path under /love says -> 0 for nothing there
int lovefs_stat_at(char const *c, uintptr_t cn, struct vfs_st *st) {
 struct vfs *v = lovefs_vfs();
 return v ? vfs_stat(v, c, cn, st) : 0; }

// the next name under a directory there, from *cur (0 to start) -> its entry, -1 after the last
int lovefs_child(char const *c, uintptr_t cn, int *cur, char const **name, uintptr_t *len, bool *dir) {
 struct vfs *v = lovefs_vfs();
 return v ? vfs_child(v, c, cn, cur, name, len, dir) : -1; }

// a read port over entry i's bytes, its section decoded now if no read has yet. they stay for
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
 struct vfs *v = &lovefs.v;
 unsigned char const *b = vfs_bake_bytes(v, v->ents[i].bake);
 if (!b) return push(g, 1, love_err(g, EIO));
 uintptr_t len = vfs_size(v, (int) i);
 uintptr_t const n = Width(struct lovefs_port);
 if (!ok(g = have(g, n + Width(struct tag) + 1))) return g;
 union u *k = bump(g, n + Width(struct tag));
 struct lovefs_port *q = (struct lovefs_port*) k;
 q->io.ap = lvm_port_io;
 q->io.vt = &lovefs_vt;
 q->io.ungetc_buf = putcharm(EOF);
 q->at = putcharm((intptr_t) b);
 q->len = putcharm((intptr_t) len);
 q->pos = putcharm(0);
 *--g->sp = (word) tagthread(k, n);
 return g; }
