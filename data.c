#include "love.h"
#include <data.h>

// ;;; FIXME the historical style gwen still appears in this file, update the instances.
// ;;; FIXME the following comment is way longer than the code which is odd, make it tight.
// The data-type sentinels. Each is the `ap` (first word) of a data kind's heap
// objects; its ADDRESS is the type tag (g_typ recovers the kind as the slot index
// in the pinned gwen_data section -- a single shift). Applying a data value lands
// on its sentinel, which tail-jumps through the apply matrix with one static index
// (its own kind, g_typ(Ip)) and one dynamic index (the argument's kind,
// g_kind(Sp[0])). The matrix and its handlers live in love.c.
//
// The dispatch (incl. g_typ) lives in ONE shared callee, data_apply; the sentinels
// are tiny, byte-identical tail calls into it. This is deliberate: the section
// STRIDE is the sentinel-body size, and g_typ divides by that stride to recover a
// kind -- but g_typ is reflected out of the stride into the generated data.h
// (tools/gen_data.l). If a sentinel body inlined g_typ, its size would depend on
// data.h, which depends on its size: a feedback loop where any change to g_typ /
// g_kind / opt flags resizes the bodies and silently desyncs the baked stride from
// the real one (a stale build then mis-routes every apply). Keeping g_typ out of
// the section makes the stride independent of data.h -- small, and constant across
// regenerations. (Bodies stay distinct only by address: the section pins the
// order/stride; g_noicf in the lvm macro blocks identical-code folding. No body
// here may use a per-sentinel literal, or the bodies would differ in size.)
static lvm(data_apply) {
 return Ap(g_apply_mx[g_typ(Ip)][g_kind(Sp[0])], g); }
#define data(idx, name) \
 __attribute__((section("gwen_data." #idx), used)) lvm(name) { return Ap(data_apply, g); }

#define go(_)\
  _(00, lvm_tuple) _(01, lvm_big) _(02, lvm_str)\
  _(03, lvm_sym) _(04, lvm_two)

go(data)
