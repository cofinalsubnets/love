#include "gwen.h"
#include <data.h>

// The data-type sentinels. Each is the `ap` (first word) of a data kind's heap
// objects; its ADDRESS is the type tag (g_typ recovers the kind as the slot index
// in the pinned gwen_data section -- a single shift). Applying a data value
// lands on its sentinel, which tail-jumps through the apply matrix with one static
// index (its own kind, g_typ(Ip)) and one dynamic index (the argument's kind,
// g_kind(Sp[0])). The matrix and its handlers live in gwen.c. Bodies are byte-
// identical on purpose: they are kept distinct only by address (the section pins
// the order/stride; g_noicf in the g_vm macro blocks identical-code folding), so
// nothing here may use a per-sentinel literal.
#define data(idx, name) \
 __attribute__((section("gwen_data." #idx), used)) g_vm(name) { \
  return Ap(g_apply_mx[g_typ(Ip)][g_kind(Sp[0])], f); }

#define go(_)\
  _(00, g_vm_tuple) _(01, g_vm_big) _(02, g_vm_str)\
  _(03, g_vm_sym) _(04, g_vm_two)

go(data)
