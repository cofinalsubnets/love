#ifndef _g_data_h
#define _g_data_h
// wasm has no flat code address space, so the host's slot-index trick (recover
// a kind from where an ap lands in the .ai_data section -- see kernel/data.h)
// doesn't apply: function pointers aren't ordered integers here. Instead compare
// the ap against each self-quote sentinel directly. ap is a lvm_t* (function
// pointer), so this is equality on pointers, not a switch (which C forbids on
// non-integer types). Keep these in enum q order (l.h: vec/big/two/text/sym).
static ai_inline bool in_data(void *a) {
 lvm_t *p = a;
 return p == lvm_two || p == lvm_vec || p == lvm_sym
     || p == lvm_str || p == lvm_big || p == lvm_flo; }

static ai_inline enum q ai_typ(union u *o) {
 lvm_t *p = o->ap;
 return p == lvm_two ? KTwo :
        p == lvm_vec ? KVec :
        p == lvm_sym ? KSym :
        p == lvm_str ? KString :
        p == lvm_flo ? KFlo :
                        KBig; }
#endif
