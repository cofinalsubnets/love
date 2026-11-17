// src/love/src.c -- the archives the artifact carries: its own source, and moonlibc per ISA
#include "love.h"
#include "bytes.h"
#include "archive/srctree.h"
#include <string.h>

// (tree-tar name) -> that section of the carried source as a tar; (tree-tar 0) -> the whole
// tar. () where none is carried, no such section, or it won't decode
// (tree-head 0) -> the sections, [name codec raw packed crc32 decoded?] each, the index first.
// (runtime-ar "x64"|"a64"|"rv64"|"i386"|"arm"|"rv32"|"wasm") -> that ISA's moonlibc archive: its zstd
// frame read against the base, the build ISA's archive, which rides a frame of its own;
// (runtime-ar "id") -> the tree-slice hash they were cut from (moon.l's rtcid). () when none.
// mksrc.l and mkrt.l lay the blobs; a link without them takes noblob.c, so a length 0 is none
extern const unsigned char
 rtzst_base[], rtzst_x64[], rtzst_a64[], rtzst_rv64[], rtzst_i386[], rtzst_arm[], rtzst_rv32[], rtzst_wasm[], rtzst_id[];
extern const uintptr_t
 rtzst_base_len, rtzst_x64_len, rtzst_a64_len, rtzst_rv64_len, rtzst_i386_len, rtzst_arm_len, rtzst_rv32_len, rtzst_wasm_len, rtzst_id_len;

// the "c" section's crc32 and length, off the header undecoded: snap.c's header src. 0 = none
uint64_t image_carried_c(void) {
 unsigned char const *z = srctree;
 if (srctree_len < 12 || memcmp(z, "lovetree", 8)) return 0;
 uint32_t ns = ld32le(z + 8);
 for (uint32_t i = 0; i < ns && 12 + 24 * (uintptr_t)(i + 1) <= srctree_len; i++) {
  unsigned char const *r = z + 12 + 24 * i;
  if (r[0] != 'c' || r[1]) continue;
  return ld32le(r + 12) | (uint64_t) ld32le(r + 20) << 32; }
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

love_noinline static struct g *host_rtar(struct g *g) {
 const unsigned char *p = 0;
 uintptr_t n = 0, on = 0, bn = 0;
 word a = g->sp[0];
 if (strp(a)) {
  const char *s = (const char*) txt(a);
  uintptr_t sl = len(a);
  // prel.l's arch-canon words; the length test travels with each spelling
  if      (sl == 3 && !memcmp(s, "x64",   3)) p = rtzst_x64,   n = rtzst_x64_len;
  else if (sl == 3 && !memcmp(s, "a64",   3)) p = rtzst_a64,   n = rtzst_a64_len;
  else if (sl == 4 && !memcmp(s, "rv64",  4)) p = rtzst_rv64,  n = rtzst_rv64_len;
  else if (sl == 4 && !memcmp(s, "i386",  4)) p = rtzst_i386,  n = rtzst_i386_len;
  else if (sl == 3 && !memcmp(s, "arm",   3)) p = rtzst_arm,   n = rtzst_arm_len;
  else if (sl == 4 && !memcmp(s, "rv32",  4)) p = rtzst_rv32,  n = rtzst_rv32_len;
  else if (sl == 4 && !memcmp(s, "wasm",  4)) p = rtzst_wasm,  n = rtzst_wasm_len;
  else if (sl == 2 && !memcmp(s, "id",    2)) p = rtzst_id,    n = on = rtzst_id_len; }
 if (!n) return g->sp[0] = ZeroPoint, g;
 unsigned char *b = NULL, *w = NULL;
 if (p != rtzst_id) {
  b = rtzst_base_len ? zstd_whole(rtzst_base, rtzst_base_len, NULL, 0, &bn) : NULL;
  w = b ? zstd_whole(p, n, b, bn, &on) : NULL;
  if (b) alloc(b, 0);
  if (!w) return g->sp[0] = ZeroPoint, g; }
 if (ok(g = str0(g, on))) memcpy(txt(g->sp[0]), w ? w : p, (size_t) on), g->sp[1] = g->sp[0], g->sp++;   // pushes: out over the name
 if (w) alloc(w, 0);
 return g; }

static LvmWrap(lvm_rtar, host_rtar)
static LvmWrap(lvm_tree_tar, host_tree_tar)
static LvmWrap(lvm_tree_head, host_tree_head)

LvDef("tree-tar", tree_tar, 1, "tree");
LvDef("tree-head", tree_head, 1, "tree");
LvDef("runtime-ar", rtar, 1, "tree");
