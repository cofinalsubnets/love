// src/love/src.c -- the archives the artifact carries: its own source, and moonlibc per ISA
#include "love.h"
#include "lib/srctree.h"
#include <string.h>

// (tree-tar name) -> that section of the carried source as a tar of its own; (tree-tar 0) ->
// every section joined, the whole tar the tree cut to. () where none is carried, the name
// is no section's, or it will not decode.
// (tree-head 0) -> the sections, [name codec raw packed crc32 decoded?] each, the index first.
// (runtime-gz "x64"|"a64"|"rv64") -> that ISA's moonlibc archive, deflated;
// (runtime-gz "id") -> the pure tree-slice hash they were cut from (moon.l's rtcid),
// which moon.l's rtcarried consumes. () when none is carried.
// src/tools/mksrc.l lays the source and src/tools/mkrt.l the rest; a link that takes neither
// object names src/love/noblob.c instead, so the length alone says whether anything is aboard.
// the source opens through src/love/lovefs.c, the tree /love serves.
extern const unsigned char
 rtgz_x64[], rtgz_a64[], rtgz_rv64[], rtgz_id[];
extern const uintptr_t
 rtgz_x64_len, rtgz_a64_len, rtgz_rv64_len, rtgz_id_len;

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

// inlined into its wrapper: no buffer and nothing address-taken, so the tail still jumps
static love_inline struct g *host_rtgz(struct g *g) {
 const unsigned char *p = 0;
 uintptr_t n = 0;
 word a = g->sp[0];
 if (strp(a)) {
  const char *s = (const char*) txt(a);
  uintptr_t sl = len(a);
  // the canonical ISA words (src/love/boot/prel.l's arch-canon); the width is spelled
  // beside the name and has to travel with it -- a shorter word here answers nothing
  if      (sl == 3 && !memcmp(s, "x64",   3)) p = rtgz_x64,   n = rtgz_x64_len;
  else if (sl == 3 && !memcmp(s, "a64",   3)) p = rtgz_a64,   n = rtgz_a64_len;
  else if (sl == 4 && !memcmp(s, "rv64",  4)) p = rtgz_rv64,  n = rtgz_rv64_len;
  else if (sl == 2 && !memcmp(s, "id",    2)) p = rtgz_id,    n = rtgz_id_len; }
 if (!n) return g->sp[0] = ZeroPoint, g;
 if (!ok(g = str0(g, n))) return g;
 memcpy(txt(g->sp[0]), p, (size_t) n);          // .rodata: no re-read after the collect
 return g->sp[1] = g->sp[0], g->sp += 1, g; }

static lvm(lvm_rtgz) LvmCall(g, host_rtgz)
static LvmWrap(lvm_tree_tar, host_tree_tar)
static LvmWrap(lvm_tree_head, host_tree_head)

static union u const
 nif_tree_tar[] = {{lvm_tree_tar}, {lvm_ret0}},
 nif_tree_head[] = {{lvm_tree_head}, {lvm_ret0}},
 nif_rtgz[] = {{lvm_rtgz}, {lvm_ret0}};

LvNif("tree-tar", nif_tree_tar, NULL);
LvNif("tree-head", nif_tree_head, NULL);
LvNif("runtime-gz", nif_rtgz, NULL);
