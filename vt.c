#include "gwen.h"
#include <vt.h>

// Per-data-kind apply handler table, indexed by enum q. Each data sentinel
// (below) recovers its own kind via g_typ and tail-jumps through this table, so
// the kind's apply behavior lives in a slot rather than the sentinel body. Every
// slot starts as self-quote (a data value applied to itself returns itself, as
// before); individual kinds can later install a custom apply handler here.
static g_vm(data_self_quote) {
 word x = word(Ip);
 return Ip = cell(*++Sp), *Sp = x, Continue(); }

// (t x): applying a hash looks x up as a key, nil if absent -- i.e. the value
// is itself the lookup fn, so (t x) == (get 0 x t). g_hget doesn't allocate, so
// no GC dance; the frame unwinds exactly as self-quote (drop arg, jump to the
// return address held in Sp[1], leave the result on top).
static g_vm(data_hash_apply) {
 word v = g_hget(f, nil, Sp[0], hsh(Ip));
 return Ip = cell(*++Sp), *Sp = v, Continue(); }

// (s k): applying a string indexes it -- k is a byte offset and the result is
// the unsigned byte 0..255 there, nil (0) if k is non-numeric or out of range,
// i.e. (s k) == (get 0 k s). No allocation, so the frame unwinds like self-quote.
static g_vm(data_text_apply) {
 word k = Sp[0], v = nil, n;
 if (oddp(k) && (n = g_getnum(k)) >= 0 && n < (word) len(Ip))
  v = g_putnum((unsigned char) txt(Ip)[n]);
 return Ip = cell(*++Sp), *Sp = v, Continue(); }

// ((a . b) f) == (f a b): a pair is its own Church eliminator (cons = \a b f.f a b).
// We re-enter the apply protocol via a static driver thread: lay the stack as the
// two curried calls expect, then [ap ; swap+ap ; ret0] runs ((f a) b) and returns
// the result to the caller. pair_swap reorders [result, b] -> [b, result] so the
// second ap sees arg=b, fn=(f a). The driver lives in .data, so the return
// addresses it leaves on the stack fall outside the GC pool and are never forwarded
// (cf. spawn_body); currying/arity are handled by the reused g_vm_ap/g_vm_cur path.
static g_vm(pair_swap) {
 word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t;
 return Ap(g_vm_ap, f); }
static union u pair_drive[] = { {g_vm_ap}, {.ap = pair_swap}, {.ap = g_vm_ret0} };
static g_vm(data_pair_apply) {
 Have(2);
 word a = A(Ip), b = B(Ip), fn = Sp[0];     // re-read after the Have guard; no alloc past here
 Sp -= 2;                                    // grow the frame to [a, fn, b, ret]
 Sp[0] = a, Sp[1] = fn, Sp[2] = b;           // Sp[3] = ret (was Sp[1]) stays put
 return Ip = pair_drive, Continue(); }

g_vm_t *g_data_ap[G_DATA_VT_N] = {
 [two_q]  = data_pair_apply, [vec_q]  = data_self_quote, [sym_q] = data_self_quote,
 [hash_q]  = data_hash_apply,  [text_q] = data_text_apply, [big_q] = data_self_quote, };

#define data_vt(idx, name) \
 __attribute__((section("gwen_data_vt." #idx), used)) g_vm(name) { \
  return Ap(g_data_ap[g_typ(Ip)], f); }

#define go(_)\
  _(00, g_vm_two) _(01, g_vm_vec) _(02, g_vm_sym)\
  _(03, g_vm_hash) _(04, g_vm_text) _(05, g_vm_big)

go(data_vt)
