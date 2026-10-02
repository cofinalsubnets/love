// src/love/lovefs.c -- /love on the host: the tree the binary carries (ai_srcgz), served to
// this process alone. posix.c's open, stat, lstat, readdir and readlink ask here before the
// OS; inle's kernel serves /love itself, so on that seat nothing here answers. a child that
// is not love cannot see it.
#include "love.h"
#include "lib/ustar.h"
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>

// a NUL-ended name against a row's, in the members every seat's libc names
static bool lovefs_is(char const *a, char const *b) {
 uintptr_t n = strlen(a);
 return n == strlen(b) && !memcmp(a, b, n); }

// the rows, laid at the first ask and never changed after: the binary's own tree does not
// move while it runs, so one copy per process stands (the rare static). a link member
// takes its target's bytes, as the kernel's rows do; a dangling or directory link drops.
static struct lovefs { struct ai_lovefs const *e; uintptr_t n; bool tried; } lovefs;

static void lovefs_lay(void) {
 lovefs.tried = true;
 uintptr_t o = 0, un = 0;
 if (ai_srcgz_len < 18 || !ai_gz_body(ai_srcgz, ai_srcgz_len, &o, &un)) return;
 unsigned char *t = mmap(NULL, un ? un : 1, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
 if (t == MAP_FAILED) return;
 if (ai_inflate_raw(ai_srcgz + o, ai_srcgz_len - o - 8, t, un) != (intptr_t) un) {
  munmap(t, un);
  return; }
 uintptr_t n = 0, nb = 0;                         // the members, and their names' bytes
 for (uintptr_t at = 0; at + 512 <= un && t[at];) {
  unsigned char const *h = t + at;
  uintptr_t sz = ai_ustar_octal(h + 124, 12);
  if (ai_ustar_member(h)) n++, nb += 2 * 257;     // the name, and a link's target
  at += 512 + ((sz + 511) & ~(uintptr_t) 511); }
 uintptr_t rb = n * sizeof(struct ai_lovefs) + n * sizeof(char*) + nb;
 unsigned char *m = mmap(NULL, rb ? rb : 1, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
 if (m == MAP_FAILED) return;
 struct ai_lovefs *e = (struct ai_lovefs*) m;
 char **lnk = (char**) (e + n), *nm = (char*) (lnk + n);
 uintptr_t k = 0;
 for (uintptr_t at = 0; at + 512 <= un && t[at] && k < n;) {
  unsigned char const *h = t + at;
  uintptr_t sz = ai_ustar_octal(h + 124, 12);
  if (ai_ustar_member(h)) {
   uintptr_t ln = ai_ustar_name(h, nm, 256);
   nm[ln] = 0;
   e[k] = (struct ai_lovefs) { nm, t + at + 512, sz, 1000 * ai_ustar_octal(h + 136, 12) };
   lnk[k] = NULL;
   nm += ln + 1;
   if (ai_ustar_islink(h)) {
    char tgt[101];
    tgt[ai_ustar_link(h, tgt, sizeof tgt - 1)] = 0;
    uintptr_t cl = ai_lnk_canon(e[k].path, tgt, nm, 256);
    nm[cl] = 0;
    lnk[k] = nm, nm += cl + 1; }
   k++; }
  at += 512 + ((sz + 511) & ~(uintptr_t) 511); }
 // two passes cover a link to a link; then compact away what never resolved
 for (int pass = 0; pass < 2; pass++)
  for (uintptr_t i = 0; i < k; i++)
   if (lnk[i])
    for (uintptr_t j = 0; j < k; j++)
     if (!lnk[j] && lovefs_is(e[j].path, lnk[i])) {
      e[i].bytes = e[j].bytes, e[i].len = e[j].len, e[i].ms = e[j].ms;
      lnk[i] = NULL;
      break; }
 // a dateless row reads as the moment the tree was laid, once, so two stats agree
 struct timespec now;
 clock_gettime(CLOCK_REALTIME, &now);
 uintptr_t w = 0;
 for (uintptr_t i = 0; i < k; i++)
  if (!lnk[i]) {
   e[w] = e[i];
   if (!e[w].ms) e[w].ms = (uintptr_t) now.tv_sec * 1000;
   w++; }
 lovefs.e = e, lovefs.n = w; }

struct ai_lovefs const *ai_lovefs_rows(uintptr_t *n) {
 if (!lovefs.tried) lovefs_lay();
 return *n = lovefs.n, lovefs.e; }

// a path -> where it falls: -1 not the tree's (the OS answers), -2 absent under /love,
// -3 a directory, else the row it names. rel takes the tree-relative name (cap 256), ""
// for /love itself. absolute paths only: the host's cwd is never under /love.
intptr_t ai_lovefs_at(char const *p, char *rel, uintptr_t *rn) {
 if (__ai_osv < 0 || !p || p[0] != '/' || ai_srcgz_len < 18) return -1;
 char c[256];
 intptr_t cn = ai_path_canon(c, 0, p, strlen(p), sizeof c);
 if (cn < 4 || memcmp(c, "love", 4) || (cn > 4 && c[4] != '/')) return -1;
 uintptr_t n, r = cn > 4 ? (uintptr_t) cn - 5 : 0;
 memcpy(rel, c + (cn > 4 ? 5 : 4), r);
 rel[r] = 0, *rn = r;
 struct ai_lovefs const *e = ai_lovefs_rows(&n);
 if (!e) return -1;                               // a tree that will not lay: the OS's
 if (!r) return -3;
 for (uintptr_t i = 0; i < n; i++)
  if (lovefs_is(e[i].path, rel)) return (intptr_t) i;
 for (uintptr_t i = 0; i < n; i++)
  if (!memcmp(e[i].path, rel, r) && e[i].path[r] == '/') return -3;
 return -2; }

// a read port over row i's bytes, which live in the map above for the life of the
// process: the cell holds their address and the cursor as charms, nothing to trace.
struct lovefs_port { struct ai_io io; word at, len, pos; };
static struct ai *lovefs_flush(struct ai *g) { return g; }
static intptr_t lovefs_readn(struct ai *g, unsigned char *dst, uintptr_t n) {
 struct lovefs_port *q = (struct lovefs_port*) g->io;
 uintptr_t pos = (uintptr_t) getcharm(q->pos), len = (uintptr_t) getcharm(q->len);
 if (pos >= len) return -1;
 uintptr_t k = len - pos < n ? len - pos : n;
 memcpy(dst, (unsigned char const*) getcharm(q->at) + pos, k);
 q->pos = putcharm((intptr_t) (pos + k));
 return (intptr_t) k; }
static uintptr_t lovefs_athand(struct ai *g, uintptr_t n) {
 struct lovefs_port *q = (struct lovefs_port*) g->io;
 uintptr_t left = (uintptr_t) (getcharm(q->len) - getcharm(q->pos));
 return left < n ? left : n; }
static struct ai_port_vt const lovefs_vt = { lovefs_flush, NULL, lovefs_readn, lovefs_athand };

struct ai *ai_lovefs_port(struct ai *g, uintptr_t i) {
 uintptr_t const n = Width(struct lovefs_port);
 if (!ai_ok(g = ai_have(g, n + Width(struct ai_tag) + 1))) return g;
 union u *k = bump(g, n + Width(struct ai_tag));
 struct lovefs_port *q = (struct lovefs_port*) k;
 q->io.ap = lvm_port_io;
 q->io.vt = &lovefs_vt;
 q->io.ungetc_buf = putcharm(EOF);
 q->at = putcharm((intptr_t) lovefs.e[i].bytes);
 q->len = putcharm((intptr_t) lovefs.e[i].len);
 q->pos = putcharm(0);
 *--g->sp = (word) tagthread(k, n);
 return g; }
