#include "i.h"
#define DATA_SENTINEL(idx, name) \
 __attribute__((section("gwen_data_vt." #idx), used)) g_vm(name) { \
  word x = word(Ip); \
  Ip = cell(*++Sp); \
  *Sp = x; \
  return Continue(); }

DATA_SENTINEL(00, g_vm_two)   // two_q
DATA_SENTINEL(01, g_vm_vec)   // vec_q
DATA_SENTINEL(02, g_vm_sym)   // sym_q
DATA_SENTINEL(03, g_vm_tbl)   // tbl_q
DATA_SENTINEL(04, g_vm_text)  // text_q
