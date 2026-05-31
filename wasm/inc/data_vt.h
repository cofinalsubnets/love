#ifndef _g_data_vt_h
#define _g_data_vt_h
// wasm has no flat code address space, so the host's slot-index trick (recover
// a kind from where an ap lands in the .gwen_data_vt section -- see g/data_vt.h)
// doesn't apply: function pointers aren't ordered integers here. Instead compare
// the ap against each self-quote sentinel directly. ap is a g_vm_t* (function
// pointer), so this is equality on pointers, not a switch (which C forbids on
// non-integer types). Keep these in enum q order (i.h: two/vec/sym/tbl/text).
static g_inline bool in_data_vt(void *a) {
 g_vm_t *p = a;
 return p == g_vm_two || p == g_vm_vec || p == g_vm_sym
     || p == g_vm_tbl || p == g_vm_text; }

static g_inline enum q g_typ(union u *o) {
 g_vm_t *p = o->ap;
 return p == g_vm_two ? two_q :
        p == g_vm_vec ? vec_q :
        p == g_vm_sym ? sym_q :
        p == g_vm_tbl ? tbl_q :
                        text_q; }
#endif
