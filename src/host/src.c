// src/host/src.c -- the artifact's own source, handed back out. auto-globbed and
// AiNif-registered, the fs.c discipline: (source-gz ()) -> the embedded
// love-<ver>.tar.gz bytes | () when none is baked in. tools/mksrc.l lays the
// archive as two .rodata symbols, the dist link pulls it in, src/core/boot/post.l's
// `source` inflates what this answers. doc/misc/dist.md.
// presence rides the kind, not the net: absence is the zero point and any archive
// is a string, so `string?` separates even at zero bytes where `(! s)` would not.
// the blobs are weak here and the dist link overrides them strong -- so they are
// always defined and the length alone says whether there is source. a weak
// *undefined* datum would not do: we link -pie and ours emits a plain rip-relative
// lea, which answers LOAD_BASE + 0 and never null.
#include "love.h"
#include <string.h>

__attribute__((weak)) const unsigned char ai_srcgz[1] = {0};
__attribute__((weak)) const uintptr_t ai_srcgz_len = 0;

// inlined into their wrappers: no buffer and nothing address-taken, so the tail still jumps
static ai_inline struct ai *host_srcgz(struct ai *g) {
 const unsigned char *p = ai_srcgz;
 uintptr_t n = ai_srcgz_len;
 if (!n) return g->sp[0] = ZeroPoint, g;
 if (!ai_ok(g = str0(g, n))) return g;             // pushes: the archive over the arg
 memcpy(txt(g->sp[0]), p, (size_t) n);             // .rodata: no re-read after the collect
 g->sp[1] = g->sp[0];
 g->sp += 1;
 return g; }

static lvm(lvm_srcgz) LvmCall(g, host_srcgz)

static union u const nif_srcgz[] = {{lvm_srcgz}, {lvm_ret0}};
AiNif("source-gz", nif_srcgz);

// (runtime-gz "x64"|"a64"|"rv64") -> that ISA's nolibc archive, deflated;
// (runtime-gz "id") -> the pure tree-slice hash the archives were cut from
// (moon.l's rtcid). () when none is carried. tools/mkrt.l lays them, the
// same weak/strong law as the source blob above; moon.l's rtcarried consumes.
__attribute__((weak)) const unsigned char ai_rtgz_x64[1] = {0};
__attribute__((weak)) const uintptr_t ai_rtgz_x64_len = 0;
__attribute__((weak)) const unsigned char ai_rtgz_a64[1] = {0};
__attribute__((weak)) const uintptr_t ai_rtgz_a64_len = 0;
__attribute__((weak)) const unsigned char ai_rtgz_rv64[1] = {0};
__attribute__((weak)) const uintptr_t ai_rtgz_rv64_len = 0;
__attribute__((weak)) const unsigned char ai_rtgz_id[1] = {0};
__attribute__((weak)) const uintptr_t ai_rtgz_id_len = 0;

static ai_inline struct ai *host_rtgz(struct ai *g) {
 const unsigned char *p = 0;
 uintptr_t n = 0;
 word a = g->sp[0];
 if (strp(a)) {
  const char *s = (const char*) txt(a);
  uintptr_t sl = len(a);
  // the canonical ISA words (src/core/boot/prel.l's arch-canon); the width is spelled
  // beside the name and has to travel with it -- a shorter word here answers nothing
  if      (sl == 3 && !memcmp(s, "x64",   3)) p = ai_rtgz_x64,   n = ai_rtgz_x64_len;
  else if (sl == 3 && !memcmp(s, "a64",   3)) p = ai_rtgz_a64,   n = ai_rtgz_a64_len;
  else if (sl == 4 && !memcmp(s, "rv64",  4)) p = ai_rtgz_rv64,  n = ai_rtgz_rv64_len;
  else if (sl == 2 && !memcmp(s, "id",    2)) p = ai_rtgz_id,    n = ai_rtgz_id_len; }
 if (!n) return g->sp[0] = ZeroPoint, g;
 if (!ai_ok(g = str0(g, n))) return g;
 memcpy(txt(g->sp[0]), p, (size_t) n);          // .rodata: no re-read after the collect
 g->sp[1] = g->sp[0];
 g->sp += 1;
 return g; }

static lvm(lvm_rtgz) LvmCall(g, host_rtgz)

static union u const nif_rtgz[] = {{lvm_rtgz}, {lvm_ret0}};
AiNif("runtime-gz", nif_rtgz);
