#ifndef _g_data_h
#define _g_data_h
// Default data-kind recovery (see l.h for the contract). The five DATA_SENTINEL
// bodies (data.c) are laid out contiguously and in enum order in the
// .gwen_data section by data.ld (host) or the equivalent inline
// block in the kernel's full linker script (arch/<a>/<a>.lds). g_typ()
// reads a kind straight out of an ap's slot index: every sentinel shares one
// body and size, so they tile the section evenly and the slot is
// (ap - start) / unit, unit = span / count (the ARM Thumb low bit on ap washes
// out in the divide). The slot (0..4) then selects the kind from slot_kind[] in
// data.c go() order (tuple, big, str, sym, two) -- a table, not a +KTuple shift,
// since the KArr* kinds (g_kind only) leave the data kinds non-contiguous in enum q.
// wasm has no flat code address space and supplies its own copy (wasm/inc/data.h).
extern char __start_gwen_data[], __stop_gwen_data[];
static g_inline bool in_data(void *a) {
 return (uintptr_t) a >= (uintptr_t) __start_gwen_data
     && (uintptr_t) a <  (uintptr_t) __stop_gwen_data; }
static g_inline enum q g_typ(union u *o) {
 static const enum q slot_kind[g_data_n] = { KTuple, KBig, KString, KSym, KTwo };
 uintptr_t base = (uintptr_t) __start_gwen_data,
           unit = ((uintptr_t) __stop_gwen_data - base) / g_data_n;
 return slot_kind[((uintptr_t) o->ap - base) / unit]; }
#endif
