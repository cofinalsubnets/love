#ifndef _g_data_h
#define _g_data_h
// Default data-kind recovery (see gwen.h for the contract). The five DATA_SENTINEL
// bodies (data.c) are laid out contiguously and in enum order in the
// .gwen_data section by data.ld (host) or the equivalent inline
// block in each frontend's own full linker script (free/, playdate/). g_typ()
// reads a kind straight out of an ap's slot index: every sentinel shares one
// body and size, so they tile the section evenly and the slot is
// (ap - start) / unit, unit = span / count (the ARM Thumb low bit on ap washes
// out in the divide). The +K_TUPLE shifts the slot (0..4) onto the kind
// (K_TUPLE..K_SYM), so g_kind needs no further adjustment.
// wasm has no flat code address space and supplies its own copy (wasm/inc/data.h).
extern char __start_gwen_data[], __stop_gwen_data[];
static g_inline bool in_data(void *a) {
 return (uintptr_t) a >= (uintptr_t) __start_gwen_data
     && (uintptr_t) a <  (uintptr_t) __stop_gwen_data; }
static g_inline enum q g_typ(union u *o) {
 uintptr_t base = (uintptr_t) __start_gwen_data,
           unit = ((uintptr_t) __stop_gwen_data - base) / G_DATA_N;
 return (enum q) (K_TUPLE + ((uintptr_t) o->ap - base) / unit); }
#endif
