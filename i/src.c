// i/src.c -- the archives the artifact carries: its own source, and moonlibc per ISA
#include "love.h"
#include <string.h>

// (source-gz ()) -> the embedded love-<ver>.tar.gz | (); post.l's `source` inflates it.
// (runtime-gz "x64"|"a64"|"rv64") -> that ISA's moonlibc archive, deflated;
// (runtime-gz "id") -> the pure tree-slice hash they were cut from (moon.l's rtcid),
// which moon.l's rtcarried consumes. () when none is carried.
// tools/mksrc.l lays the first and tools/mkrt.l the rest; a link that takes neither
// object names i/noblob.c instead, so the length alone says whether anything is aboard.
extern const unsigned char
 ai_rtgz_x64[], ai_rtgz_a64[], ai_rtgz_rv64[], ai_rtgz_id[], ai_srcgz[];
extern const uintptr_t
 ai_rtgz_x64_len, ai_rtgz_a64_len, ai_rtgz_rv64_len, ai_rtgz_id_len, ai_srcgz_len;

// inlined into their wrappers: no buffer and nothing address-taken, so the tail still jumps
static ai_inline struct ai *host_srcgz(struct ai *g) {
 const unsigned char *p = ai_srcgz;
 uintptr_t n = ai_srcgz_len;
 if (!n) return g->sp[0] = ZeroPoint, g;
 if (!ai_ok(g = str0(g, n))) return g;             // pushes: the archive over the arg
 memcpy(txt(g->sp[0]), p, (size_t) n);             // .rodata: no re-read after the collect
 return g->sp[1] = g->sp[0], g->sp += 1, g; }


static ai_inline struct ai *host_rtgz(struct ai *g) {
 const unsigned char *p = 0;
 uintptr_t n = 0;
 word a = g->sp[0];
 if (strp(a)) {
  const char *s = (const char*) txt(a);
  uintptr_t sl = len(a);
  // the canonical ISA words (l/boot/prel.l's arch-canon); the width is spelled
  // beside the name and has to travel with it -- a shorter word here answers nothing
  if      (sl == 3 && !memcmp(s, "x64",   3)) p = ai_rtgz_x64,   n = ai_rtgz_x64_len;
  else if (sl == 3 && !memcmp(s, "a64",   3)) p = ai_rtgz_a64,   n = ai_rtgz_a64_len;
  else if (sl == 4 && !memcmp(s, "rv64",  4)) p = ai_rtgz_rv64,  n = ai_rtgz_rv64_len;
  else if (sl == 2 && !memcmp(s, "id",    2)) p = ai_rtgz_id,    n = ai_rtgz_id_len; }
 if (!n) return g->sp[0] = ZeroPoint, g;
 if (!ai_ok(g = str0(g, n))) return g;
 memcpy(txt(g->sp[0]), p, (size_t) n);          // .rodata: no re-read after the collect
 return g->sp[1] = g->sp[0], g->sp += 1, g; }

static lvm(lvm_rtgz) LvmCall(g, host_rtgz)
static lvm(lvm_srcgz) LvmCall(g, host_srcgz)

static union u const
 nif_srcgz[] = {{lvm_srcgz}, {lvm_ret0}},
 nif_rtgz[] = {{lvm_rtgz}, {lvm_ret0}};

AiNif("source-gz", nif_srcgz, NULL);
AiNif("runtime-gz", nif_rtgz, NULL);
