#ifndef _g_data_vt_h
#define _g_data_vt_h
// Default data-kind recovery (see i.h for the contract). The five DATA_SENTINEL
// bodies (flow.c) are laid out contiguously and in enum order in the
// .gwen_data_vt section by g/gwen_data_vt.ld (host) or the equivalent inline
// block in each frontend's own full linker script (k/, pd/). g_typ() reads a
// kind straight out of an ap's slot index: every sentinel shares one body and
// size, so they tile the section evenly and the slot is (ap - start) / unit,
// unit = span / count (the ARM Thumb low bit on ap washes out in the divide).
// wasm has no flat code address space and supplies its own copy (wasm/data_vt.h).
extern char __start_gwen_data_vt[], __stop_gwen_data_vt[];
static g_inline bool in_data_vt(void *a) {
 return (uintptr_t) a >= (uintptr_t) __start_gwen_data_vt
     && (uintptr_t) a <  (uintptr_t) __stop_gwen_data_vt; }
static g_inline enum q g_typ(union u *o) {
 uintptr_t base = (uintptr_t) __start_gwen_data_vt,
           unit = ((uintptr_t) __stop_gwen_data_vt - base) / G_DATA_VT_N;
 return (enum q) (((uintptr_t) o->ap - base) / unit); }
#endif
