// src/love/src.c -- the archives the artifact carries: its own source, and moonlibc per ISA
#include "love.h"
#include "archive/srctree.h"
#include <string.h>

// (tree-tar name) -> that section of the carried source as a tar; (tree-tar 0) -> the whole
// tar. () where none is carried, no such section, or it won't decode
// (tree-head 0) -> the sections, [name codec raw packed crc32 decoded?] each, the index first.
// (runtime-ar isa) -> that ISA's moonlibc archive: its zstd frame read against its reference's
// archive, down to the base, the build ISA's, which rides a frame of its own; (runtime-ar "id")
// -> the tree-slice hash they were cut from (moon.l's rtcid); (runtime-ar 0) -> the ISAs
// carried, by name. () when none.
// mksrc.l and mkrt.l lay the blobs (mkrt.l's head has the table); a link without them takes
// noblob.c, so a length 0 is none
extern const unsigned char rtzst_tab[];
extern const uintptr_t rtzst_tab_len;

// the table's entries, in order: each one's name, its reference and its bytes
struct rtent { const unsigned char *nm, *ref, *p; uintptr_t n; };
static bool rtzst_at(uintptr_t *o, struct rtent *e) {
 if (*o + 40 > rtzst_tab_len || !rtzst_tab[*o]) return false;
 const unsigned char *h = rtzst_tab + *o;
 uintptr_t k = 0;
 for (int b = 0; b < 8; b++) k |= (uintptr_t) h[32 + b] << 8 * b;
 *e = (struct rtent) { h, h + 16, h + 40, k };
 *o += 40 + ((k + 7) & ~(uintptr_t) 7);
 return true; }
static bool rtzst_find(const char *s, uintptr_t sl, struct rtent *e) {
 if (!sl || sl >= 16) return false;
 for (uintptr_t o = 0; rtzst_at(&o, e);)
  if (!memcmp(e->nm, s, sl) && !e->nm[sl]) return true;
 return false; }
// an entry decoded against its chain, the base first -> alloc'd bytes, or 0. a chain longer
// than the table is a cycle
static unsigned char *rtzst_dec(struct rtent const *e, uintptr_t *on, int depth) {
 struct rtent r;
 uintptr_t rn = 0;
 unsigned char *d = NULL, *w;
 bool base = !e->ref[0];
 if (!base) {
  if (depth > 16 || !rtzst_find((const char*) e->ref, strlen((const char*) e->ref), &r)) return NULL;
  if (!(d = rtzst_dec(&r, &rn, depth + 1))) return NULL; }
 w = zstd_whole(e->p, e->n, d, rn, on);
 if (d) alloc(d, 0);
 return w; }

// the "c" section's crc32 and length, off the header undecoded: snap.c's header src. 0 = none
uint64_t image_carried_c(void) {
 unsigned char const *z = srctree;
 if (srctree_len < 12 || memcmp(z, "lovetree", 8)) return 0;
 uint32_t ns = (uint32_t) z[8] | (uint32_t) z[9] << 8 | (uint32_t) z[10] << 16 | (uint32_t) z[11] << 24;
 for (uint32_t i = 0; i < ns && 12 + 24 * (uintptr_t)(i + 1) <= srctree_len; i++) {
  unsigned char const *r = z + 12 + 24 * i;
  if (r[0] != 'c' || r[1]) continue;
  uint64_t v = 0;
  for (int b = 0; b < 4; b++) v |= (uint64_t) r[12 + b] << 8 * b | (uint64_t) r[20 + b] << (32 + 8 * b);
  return v; }
 return 0; }

// a section alone ends in the two zero blocks a tar ends with; the last carries its own
static love_noinline struct g *host_tree_tar(struct g *g) {
 struct tree *t = tree_carried();
 word a = g->sp[0];
 intptr_t one = -1;
 if (t && strp(a)) {
  char nm[9] = {0};
  if (len(a) < sizeof nm) memcpy(nm, txt(a), len(a)), one = tree_named(t, nm);
  if (one < 1) t = NULL; }
 uint32_t lo = one > 0 ? (uint32_t) one : 1, hi = one > 0 ? lo + 1 : t ? t->ns : 0;
 uintptr_t n = one > 0 ? 1024 : 0;
 for (uint32_t i = lo; t && i < hi; i++)
  if (tree_sec(t, i)) n += t->s[i].raw;
  else t = NULL;
 if (!t) return g->sp[0] = ZeroPoint, g;
 if (!ok(g = str0(g, n))) return g;             // pushes: the tar over the arg
 unsigned char *o = (unsigned char*) txt(g->sp[0]);
 for (uint32_t i = lo; i < hi; i++) memcpy(o, t->s[i].bytes, t->s[i].raw), o += t->s[i].raw;
 if (one > 0) memset(o, 0, 1024);
 return g->sp[1] = g->sp[0], g->sp += 1, g; }

static love_noinline struct g *host_tree_head(struct g *g) {
 struct tree *t = tree_carried();
 if (!t) return g->sp[0] = ZeroPoint, g;
 uintptr_t w = 0;
 for (uint32_t i = 0; i < t->ns; i++)
  w += str_width(strlen(t->s[i].name)) + 7 * Width(struct chain);
 if (!ok(g = have(g, w))) return g;
 word l = ZeroPoint;
 for (uint32_t i = t->ns; i--;) {
  struct tree_sec const *s = t->s + i;
  uintptr_t nl = strlen(s->name);
  struct str *nm = ini_str(bump(g, str_width(nl)), nl);
  memcpy(nm->bytes, s->name, nl);
  word f[6] = { (word) nm, putcharm(s->codec), putcharm(s->raw), putcharm(s->packed),
                putcharm(s->crc), putcharm(s->bytes ? 1 : 0) }, r = ZeroPoint;
  for (int k = 6; k--;) r = word(ini_chain(bump(g, Width(struct chain)), f[k], r));
  l = word(ini_chain(bump(g, Width(struct chain)), r, l)); }
 return g->sp[0] = l, g; }

// the names carried, as a list of strings
static struct g *rtzst_names(struct g *g) {
 struct rtent e;
 uintptr_t w = 0;
 for (uintptr_t o = 0; rtzst_at(&o, &e);) w += str_width(strlen((const char*) e.nm)) + Width(struct chain);
 if (!ok(g = have(g, w))) return g;
 word l = ZeroPoint, *tl = &l;
 for (uintptr_t o = 0; rtzst_at(&o, &e);) {
  uintptr_t nl = strlen((const char*) e.nm);
  if ((nl == 2 && !memcmp(e.nm, "id", 2)) || (nl == 4 && !memcmp(e.nm, "base", 4))) continue;
  struct str *nm = ini_str(bump(g, str_width(nl)), nl);
  memcpy(nm->bytes, e.nm, nl);
  struct chain *c = ini_chain(bump(g, Width(struct chain)), (word) nm, ZeroPoint);
  *tl = word(c), tl = &c->b; }
 return g->sp[0] = l, g; }

love_noinline static struct g *host_rtar(struct g *g) {
 struct rtent e;
 uintptr_t on = 0;
 word a = g->sp[0];
 if (!strp(a)) return rtzst_names(g);
 const char *s = (const char*) txt(a);
 uintptr_t sl = len(a);
 // the base is no isa's answer: it decodes the rest
 if ((sl == 4 && !memcmp(s, "base", 4)) || !rtzst_find(s, sl, &e) || !e.n) return g->sp[0] = ZeroPoint, g;
 bool id = sl == 2 && !memcmp(s, "id", 2);
 unsigned char *w = id ? NULL : rtzst_dec(&e, &on, 0);
 if (id) on = e.n;
 else if (!w) return g->sp[0] = ZeroPoint, g;
 if (ok(g = str0(g, on))) memcpy(txt(g->sp[0]), w ? w : e.p, (size_t) on), g->sp[1] = g->sp[0], g->sp++;   // pushes: out over the name
 if (w) alloc(w, 0);
 return g; }

static LvmWrap(lvm_rtar, host_rtar)
static LvmWrap(lvm_tree_tar, host_tree_tar)
static LvmWrap(lvm_tree_head, host_tree_head)

LvDef("tree-tar", tree_tar, 1, "tree");
LvDef("tree-head", tree_head, 1, "tree");
LvDef("runtime-ar", rtar, 1, "tree");
