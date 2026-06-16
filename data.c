#include "ai.h"
#include <data.h>

// The data-type sentinels. Each is the `ap` (first word) of a data kind's
// heap objects, and its ADDRESS is the type tag: the linker pins the
// sentinels in order in the ai_data section, and ai_typ recovers a kind as
// the slot index (one shift). Applying a data value lands on its sentinel,
// which tail-jumps through the apply matrix in ai.c.
//
// All dispatch lives in ONE shared callee, data_apply, so the sentinel
// bodies are tiny, byte-identical tail calls. That is deliberate: the
// section STRIDE is the body size, and ai_typ's stride is baked into the
// generated data.h (tools/gen_data.l) -- a body that inlined ai_typ would
// size-depend on the header derived from its own size. Bodies stay distinct
// only by address (ai_noicf in the lvm macro blocks identical-code folding;
// no body may use a per-sentinel literal, or the sizes would diverge).
static lvm(data_apply) {
 return Ap(ai_apply_mx[ai_typ(Ip)][ai_kind(Sp[0])], g); }
// ELF: each sentinel goes in its own ai_data.NN input subsection; the linker
// (data.ld) sorts them into one enum-ordered block and ai_typ recovers a kind
// from an ap's slot index. mach-o has no SORT_BY_NAME / __start_ symbol
// equivalent and rejects a single-name "section" attribute, so there the
// sentinels are ordinary functions and ai_typ (the __APPLE__ path in data.h)
// compares an ap against their five addresses -- no layout dependency.
#if defined(__APPLE__)
#define data(idx, name) __attribute__((used)) lvm(name) { return Ap(data_apply, g); }
#else
#define data(idx, name) \
 __attribute__((section("ai_data." #idx), used)) lvm(name) { return Ap(data_apply, g); }
#endif

#define go(_)\
  _(00, lvm_vec) _(01, lvm_big) _(02, lvm_str)\
  _(03, lvm_sym) _(04, lvm_two)

go(data)
