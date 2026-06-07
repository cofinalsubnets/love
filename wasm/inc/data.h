#ifndef _g_data_h
#define _g_data_h
// wasm has no flat code address space, so the host's slot-index trick (recover
// a kind from where an ap lands in the .gwen_data section -- see kernel/data.h)
// doesn't apply: function pointers aren't ordered integers here. Instead compare
// the ap against each self-quote sentinel directly. ap is a g_vm_t* (function
// pointer), so this is equality on pointers, not a switch (which C forbids on
// non-integer types). Keep these in enum q order (gwen.h: tuple/big/two/text/sym).
static g_inline bool in_data(void *a) {
 g_vm_t *p = a;
 return p == g_vm_two || p == g_vm_tuple || p == g_vm_sym
     || p == g_vm_str || p == g_vm_big; }

static g_inline enum q g_typ(union u *o) {
 g_vm_t *p = o->ap;
 return p == g_vm_two ? K_TWO :
        p == g_vm_tuple ? K_TUPLE :
        p == g_vm_sym ? K_SYM :
        p == g_vm_str ? K_STRING :
                        K_BIG; }
#endif
