#ifndef _g_data_h
#define _g_data_h
// Default data-kind recovery (see ai.h for the contract). The five DATA_SENTINEL
// bodies (data.c) are laid out contiguously and in enum order in the
// .ai_data section by data.ld (host) or the equivalent inline
// block in the kernel's full linker script (port/<a>/<a>.lds). ai_typ()
// reads a kind straight out of an ap's slot index: every sentinel shares one
// body and size, so they tile the section evenly and the slot is
// (ap - start) / unit, unit = span / count (the ARM Thumb low bit on ap washes
// out in the divide). The slot (0..4) then selects the kind from slot_kind[] in
// data.c go() order (tuple, big, str, sym, two) -- a table, not a +KTuple shift,
// since the KArr* kinds (ai_kind only) leave the data kinds non-contiguous in enum q.
// wasm has no flat code address space and supplies its own copy (wasm/inc/data.h).
#if defined(__APPLE__)
// mach-o port: no ordered custom code section and no __start_/__stop_ symbols
// (data.ld doesn't apply, and gen_data.l can't reflect a mach-o object), so a
// kind can't be read from a section slot. The five sentinels (data.c, declared
// in ai.h) are ordinary functions here; recover the kind by comparing an ap
// against their addresses, in data.c go() order: tuple, big, str, sym, two.
static ai_inline bool in_data(void *a) {
 uintptr_t p = (uintptr_t) a;
 return p == (uintptr_t) lvm_tuple || p == (uintptr_t) lvm_big
     || p == (uintptr_t) lvm_str   || p == (uintptr_t) lvm_sym
     || p == (uintptr_t) lvm_two; }
static ai_inline enum q ai_typ(union u *o) {
 uintptr_t ap = (uintptr_t) o->ap;
 return ap == (uintptr_t) lvm_tuple ? KTuple
      : ap == (uintptr_t) lvm_big   ? KBig
      : ap == (uintptr_t) lvm_str   ? KString
      : ap == (uintptr_t) lvm_sym   ? KSym
      :                               KTwo; }
#else
extern char __start_ai_data[], __stop_ai_data[];
static ai_inline bool in_data(void *a) {
 return (uintptr_t) a >= (uintptr_t) __start_ai_data
     && (uintptr_t) a <  (uintptr_t) __stop_ai_data; }
static ai_inline enum q ai_typ(union u *o) {
 static const enum q slot_kind[ai_data_n] = { KTuple, KBig, KString, KSym, KTwo };
 uintptr_t base = (uintptr_t) __start_ai_data,
           unit = ((uintptr_t) __stop_ai_data - base) / ai_data_n;
 return slot_kind[((uintptr_t) o->ap - base) / unit]; }
#endif
#endif
