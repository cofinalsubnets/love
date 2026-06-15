#include "ai.h"
#include <data.h>

// The data-type sentinels. Each is the `ap` (first word) of a data kind's
// heap objects, and its ADDRESS is the type tag: the linker pins the
// sentinels in order in the love_data section, and g_typ recovers a kind as
// the slot index (one shift). Applying a data value lands on its sentinel,
// which tail-jumps through the apply matrix in love.c.
//
// All dispatch lives in ONE shared callee, data_apply, so the sentinel
// bodies are tiny, byte-identical tail calls. That is deliberate: the
// section STRIDE is the body size, and g_typ's stride is baked into the
// generated data.h (tools/gen_data.l) -- a body that inlined g_typ would
// size-depend on the header derived from its own size. Bodies stay distinct
// only by address (g_noicf in the lvm macro blocks identical-code folding;
// no body may use a per-sentinel literal, or the sizes would diverge).
static lvm(data_apply) {
 return Ap(g_apply_mx[g_typ(Ip)][g_kind(Sp[0])], g); }
#define data(idx, name) \
 __attribute__((section("love_data." #idx), used)) lvm(name) { return Ap(data_apply, g); }

#define go(_)\
  _(00, lvm_tuple) _(01, lvm_big) _(02, lvm_str)\
  _(03, lvm_sym) _(04, lvm_two)

go(data)
