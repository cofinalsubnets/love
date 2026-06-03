#include "i.h"
#define data_vt(idx, name) \
 __attribute__((section("gwen_data_vt." #idx), used)) g_vm(name) { \
  word x = word(Ip); \
  return Ip = cell(*++Sp), *Sp = x, Continue(); }

#define go(_)\
  _(00, g_vm_two) _(01, g_vm_vec) _(02, g_vm_sym)\
  _(03, g_vm_tbl) _(04, g_vm_text)

go(data_vt)
