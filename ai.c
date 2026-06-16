#include "ai.h"
// The build's version string (the version-control id), generated into out/lib/ai_version.h by
// the Makefile and surfaced in the runtime as the `ai-version` global (ai_ini_0).
// Optional include so a standalone/unwired compile still builds; falls back to "unknown".
#if defined(__has_include) && __has_include("ai_version.h")
#include "ai_version.h"
#endif
#ifndef AI_VERSION
#define AI_VERSION "unknown"
#endif

// ============================================================================
// kernel-internal declarations (private; merged from former i.h)
// ============================================================================

#if UINTPTR_MAX == UINT64_MAX
#define Bits 64
typedef double ai_flo_t;
#define ai_sin   sin
#define ai_cos   cos
#define ai_atan2 atan2
#define ai_sqrt  sqrt
#define ai_exp   exp
#define ai_log   log
#define ai_pow   pow
#elif UINTPTR_MAX == UINT32_MAX
#define Bits 32
typedef float ai_flo_t;
#define ai_sin   sinf
#define ai_cos   cosf
#define ai_atan2 atan2f
#define ai_sqrt  sqrtf
#define ai_exp   expf
#define ai_log   logf
#define ai_pow   powf
#endif

#if __STDC_HOSTED__
#include <math.h>
#else
ai_flo_t ai_sin(ai_flo_t), ai_cos(ai_flo_t),
        ai_atan2(ai_flo_t, ai_flo_t), ai_sqrt(ai_flo_t), ai_exp(ai_flo_t),
        ai_log(ai_flo_t), ai_pow(ai_flo_t, ai_flo_t);
#endif

#define Bytes (Bits>>3)
_Static_assert(Bytes == sizeof(uintptr_t), "word size sanity check");

#include <stdarg.h>
_Static_assert(sizeof(union u) == sizeof(intptr_t), "cell size equals word size");
_Static_assert(-1 >> 1 == -1, "sign extended shift");
// nilp: structural test for the nil word (the only false scalar). Distinct from
// ai_nilp below (the language falsy predicate, which also counts an all-zero vec);
// the l `nilp` nif maps to ai_nilp, not this macro.
#define nilp(_) (word(_)==nil)
#define AB(o) A(B(o))
#define AA(o) A(A(o))
#define BA(o) B(A(o))
#define BB(o) B(B(o))
#define ptr(_) ((word*)(_))
#define datp(_) in_data(cell(_)->ap)
#define avec(g, y, ...) (mm(g,&(y)),(__VA_ARGS__),um(g))
#define mm(g,r) ((ai_core_of(g)->root=&((struct ai_r){(word*)(r),ai_core_of(g)->root})))
#define um(g) (ai_core_of(g)->root=ai_core_of(g)->root->n)


#if UINTPTR_MAX > 0xffffffffu
#define mix ((uintptr_t) 0x9e3779b97f4a7c15) // round(2^64 / phi)
#else
#define mix ((uintptr_t) 0x9e3779b9) // round(2^32 / phi)
#endif

#define typ(_) ai_typ(cell(_))

#if ai_tco
#define ai_status_yield ai_status_ok
#else
#define ai_status_yield ai_status_eof
#endif
#define str_type_width (Width(struct ai_str))
#define op1(nom, i, x) lvm(nom) { Sp[0] = (x); Ip += i; return Continue(); }
#define op11(nom, x) op1(nom, 1, x)

#define pop1 ai_pop1

// One word per element: every integer width folds to Z (intptr_t), every float
// width to R (ai_flo_t), and C is the rank-0 complex scalar (two ai_flo_t). Ordered
// Z < R < C so `>= ai_R` is the float-domain test and C is the widest *numeric* tier.
// arr rejects ty == C, so C never appears as a rank>=1 array element -- complex
// only ever shows up as a rank-0 scalar (Cp), handled by explicit cplx branches.
// O (object) is the odd tier out: its slots hold live l words (any value --
// fixnum, bignum, box, complex, string, pair...), so it is the ONE vec type the
// copying GC must trace element-by-element (evac_vec). It sits outside the numeric
// order; the typed fast lanes gate on `type <= ai_C`, the arith lane on `type == ai_O`
// (lvm_obin), so O elements always route through the promoting scalar dispatch --
// that is what makes a bignum array add/multiply exactly instead of wrapping.
enum ai_vec_type { ai_Z, ai_R, ai_C, ai_O, };
// Elementwise dyadic opcodes for lvm_vbin (kernel/arr.c). The five arith codes
// match the arith slow aps; the five compare codes (>= vop_lt) produce a
// 0/1 bool array. vop_eq is `=` over arrays (whole-array eq is `(aall (= a b))`).
// vop_quot is `/` (true division: float when a element divides inexactly);
// vop_fquot is `//` (truncating integer division). Both stay in the arith group
// (< vop_lt) so `op >= vop_lt` still selects the compare codes.
enum vop { vop_add, vop_sub, vop_mul, vop_quot, vop_rem, vop_fquot,
           vop_lt, vop_le, vop_gt, vop_ge, vop_eq, };
struct ai_atom *intern_checked(struct ai*, struct ai_str*);
uintptr_t intern_reserve(struct ai*);
uintptr_t hash(struct ai*, intptr_t);
static ai_inline union u *map_fill_back(union u*, uintptr_t);
lvm_t lvm_kcall,
 lvm_two, lvm_vec, lvm_sym, lvm_str, lvm_big, // data sentinels (enum q order); apply dispatches through ai_apply_mx
 lvm_putn, lvm_gauge,    lvm_clock,
 lvm_nilp,  lvm_putc, lvm_mint, lvm_intern, lvm_twop,
 lvm_pin, lvm_peep, lvm_fputx, lvm_buf, lvm_bufnew, lvm_bcopy, lvm_call, lvm_call2, lvm_toast, lvm_toasted,
 lvm_fixp,  lvm_symp,   lvm_strp,   lvm_mapp, lvm_band,   lvm_bor,  lvm_real,  lvm_flop,
 lvm_sin, lvm_cos, lvm_log, lvm_pow,   // sqrt/exp/tan/atan/atan2 are derived (numeral/complex forms), not nifs
 // Step 7 -- complex (kernel/cplx.c). lvm_cplx_bin (declared apart, below) is
 // the arithmetic lane the scalar arith slow paths divert into.
 lvm_cplx, lvm_Cp, lvm_re, lvm_im, lvm_conj, lvm_abs, lvm_carg,
 lvm_bxor,  lvm_bsr,    lvm_bsl,    lvm_slice,
 lvm_cons,   lvm_car,  lvm_cdr,    lvm_puts,
 lvm_getc,  lvm_string, lvm_lt,     lvm_le,   lvm_eq,     lvm_same, lvm_gt,  lvm_ge,
 lvm_sort,  lvm_tally,
 lvm_put, lvm_pull, lvm_table,   lvm_keys,  lvm_dig,
 lvm_unc, lvm_poke, lvm_peek,
 lvm_seek,  lvm_trim,   lvm_spin,   lvm_add,
 lvm_sub,   lvm_mul,    lvm_quot,   lvm_fquot, lvm_rem,  lvm_arg,
 lvm_bmul_start, lvm_bmul,   // resumable (yieldable) bignum multiply
 lvm_quote, lvm_index,  lvm_eval,   lvm_cond, lvm_jump,   lvm_defglob,
 lvm_ap,    lvm_tap,    lvm_apn,    lvm_tapn, lvm_ret,
 lvm_argap, lvm_quoteap, lvm_argtap,
 lvm_arg0, lvm_arg1, lvm_arg2, lvm_arg3,
 lvm_quo0, lvm_quo1, lvm_quo2, lvm_quo3, lvm_quom1, lvm_quom2, lvm_zp,
 lvm_callk, lvm_scare, lvm_missing, lvm_yield_sw, lvm_yield_nif, lvm_task_exit, lvm_spawn, lvm_wait,
 lvm_sleep, lvm_donep, lvm_hush, lvm_key,
 lvm_fgetc, lvm_fungetc, lvm_feof, lvm_fputc, lvm_fputs, lvm_fflush,
 lvm_fputbn, lvm_read, lvm_dot,
 // Step 5a -- typed multi-rank arrays (kernel/arr.c). lvm_vbin is the shared
 // elementwise/broadcast engine the arith/compare slow lanes divert into.
 lvm_arr, lvm_iota, lvm_arank, lvm_alen, lvm_ashape, lvm_atype,
 lvm_asum, lvm_aprod, lvm_amax, lvm_amin, lvm_aall, lvm_inner, lvm_outer,
 lvm_packp, lvm_bigp, lvm_widep, lvm_arrp, lvm_intf, lvm_lamp, lvm_hotp,
 lvm_nat, lvm_natn,         // CODEGEN BACKEND: emitted bytes -> applicable native value (1-arg / multi-arg)
 lvm_absent, lvm_absent2;   // safe defaults for the frontend nifs (exit/open/..)
// Carry extra operands, so (like lvm_gc) they are declared apart from the
// plain lvm_t list, which fixes the 4-argument ap signature. lvm_vbin
// is the elementwise/broadcast dyadic engine (vop selects the op); lvm_vmap1
// applies a monadic math fn elementwise to an array (e.g. (sin arr)); lvm_vmap2
// is the dyadic analogue with broadcasting (e.g. (pow arr arr), (atan2 ...)).
lvm(lvm_vbin, int);
lvm(lvm_vmap1, ai_flo_t (*)(ai_flo_t));
lvm(lvm_vmap2, ai_flo_t (*)(ai_flo_t, ai_flo_t));
// Complex arithmetic lane (kernel/cplx.c): the scalar arith slow paths divert
// here when either operand is complex; vop selects add/sub/mul/quot (rem -> nil).
lvm(lvm_cplx_bin, int);
// Complex-array elementwise lane (ai_C): lvm_vbin diverts here when an operand is
// a packed (re,im) ai_C array (or a complex scalar paired with an array). Same
// numpy broadcast as vbin, complex domain; `=` -> mask, ordering/% -> nil.
lvm(lvm_cbin, int);
// Object-array elementwise lane (ai_O): the broadcast engine lvm_vbin diverts
// here when an operand is a ai_O array, so each element op runs the promoting
// scalar dispatch (exact bignum results) instead of the typed raw-C lanes.
lvm(lvm_obin, int);
// data-kind recovery (datp/typ). Included here, after the self-quote sentinels
// above, because a frontend's override (e.g. wasm/inc/data.h) resolves kinds
// by comparing an ap against lvm_two..lvm_str directly.
#include <data.h>
char const *ai_nif_name(intptr_t);
#define vec(_) ((struct ai_vec*)(_))
#define charmp oddp
#define sym(_) ((struct ai_atom*)(_))
static ai_inline bool symp(word _) { return lamp(_) && cell(_)->ap == lvm_sym; }
static ai_inline bool packp(word _) { return lamp(_) && cell(_)->ap == lvm_vec; }
static ai_inline bool strp(word _) { return lamp(_) && cell(_)->ap == lvm_str; }
// Mutable flat byte string. NOT a data kind: its head word is the
// behaves-as-0 lvm_buf (like lvm_port_io for ports), so the GC walks a buf
// as a plain length-2 text -- [lvm_buf, backing ai_str, terminator] -- and
// the generic text sound forwards the embedded string pointer for free; no
// bespoke evac/copy rule, and the data-sentinel mechanism stays reserved for
// kinds that need one. The bytes live in an ordinary ai_str we mutate in place
// (cf. the `to` output port). Earned by the build tools that back-patch a
// binary image in place. Recognized by ap, like iop() for ports.
struct ai_buf { lvm_t *ap; struct ai_str *str; };
static ai_inline bool bufp(word _) { return lamp(_) && cell(_)->ap == lvm_buf; }
// a TOAST: an opaque executable handle (toasted native code). A hot like a buf, but a
// DISTINCT ap so it is not bufp -- no peep/pin/blit/tally as data; only `call` runs it.
static ai_inline bool toastp(word _) { return lamp(_) && cell(_)->ap == lvm_toasted; }
// A map is a lookup-lambda with stable identity across growth, like the hash it
// replaces (whose struct stayed put while its bucket array reallocated). Two
// texts: a fixed 2-word HEADER [lvm_map_lookup, backing, <tag>] that callers
// hold, and a BACKING [lvm_map_data, putcharm(len), putcharm(cap), k0,v0, … , <tag>]
// it points at -- open-addressed, linear-probed, cap a power of two. Growth
// allocates a new backing and swaps header[1]; the header never moves, so an
// aliased reference (ev's scopes) sees later inserts. Both are plain texts:
// len/cap are fixnums and keys/vals l words, so evac_text traces them with no
// bespoke GC, like ai_buf. Empty slots hold map_gap, a unique word-aligned
// out-of-pool address gcp leaves untouched, never a legal key and never read as
// a terminator. (m k) looks k up (nil if absent) through lvm_map_lookup.
static lvm_t lvm_map_lookup, lvm_map_data;
static ai_inline bool mapp(word _) { return lamp(_) && cell(_)->ap == lvm_map_lookup; }
static const word ai_map_gap_cell = 0;
#define map_gap ((word) &ai_map_gap_cell)
#define map_min_cap 4
static ai_inline word map_back(word m) { return cell(m)[1].x; }
static ai_inline word *map_slots(word m) { return &cell(map_back(m))[3].x; }
static ai_inline uintptr_t map_len(word m) { return getcharm(cell(map_back(m))[1].x); }
static ai_inline uintptr_t map_cap(word m) { return getcharm(cell(map_back(m))[2].x); }
word ai_mapget(struct ai*, word, word, word);
static struct ai *ai_mapput(struct ai*), *map_new(struct ai*);
static ai_inline struct ai_str *buf_str(word x) { return ((struct ai_buf*) x)->str; }
// the byte ops read from a string or a buf; both resolve to a ai_str of bytes.
static ai_inline struct ai_str *bytes_of(word x) { return bufp(x) ? buf_str(x) : str(x); }
// Arbitrary-precision integer (Step 6). Own data-sentinel kind KBig: a flat,
// GC-trivial object (raw limbs, no embedded l pointers) the copying GC moves
// by memcpy. A generic text sound can't hold inline limb words (a limb that's
// even-and-in-pool would be spuriously forwarded, one matching ai_text_tag would
// truncate the object), so a flat bignum needs its own copy/evac rule -- like
// KString strings -- which is exactly what the sentinel buys. slen = signed limb
// count (negative => negative value); |slen| 32-bit limbs little-endian
// (limb[0] least significant), top limb nonzero (normalized). Zero is never a
// bignum (it demotes to the fixnum nil), so slen is never 0 and the sign is
// unambiguous. Canonical demotion keeps the tiers disjoint: a value in fixnum
// range is a fixnum, one in intptr_t range a wide-int box, only wider values a
// bignum -- so charmp/widep/bigp are mutually exclusive and =/eqv stay well defined.
struct ai_big { lvm_t *ap; intptr_t slen; uint32_t limb[]; };
static ai_inline bool bigp(word _) { return lamp(_) && cell(_)->ap == lvm_big; }
static ai_inline struct ai_big *ini_big(struct ai_big *b, intptr_t slen) {
 return b->ap = lvm_big, b->slen = slen, b; }
uintptr_t ai_big_bytes(struct ai_big*);
// Canonicalize a magnitude (limb[0..n), sign neg) into the smallest tier:
// fixnum, else wide-int box, else bignum; bumps *hp when it boxes/bignums. One
// sink shared by the reader and the arithmetic slow paths.
word ai_big_canon(ai_word **hp, uint32_t const *limb, int n, bool neg);
ai_flo_t ai_big_to_flo(word);                 // bignum -> double (used by toflo)
intptr_t ai_big_low(word);                   // bignum value mod 2^W (low machine word)
int ai_big_cmp(word, word);                  // -1/0/1 over two integer operands
struct ai *ai_big_binop(struct ai*, int vop);  // vop_add..vop_rem, packed; pops one operand
struct ai *ai_big_quot_true(struct ai*);       // `/` bignum lane: exact quotient when b | a, else a float box
struct ai *ai_big_dec(struct ai*);             // sp[0] bignum -> decimal string
struct ai *ai_big_read_dec(struct ai*);        // sp[0] [+-]?digits token -> canonical value

static ai_inline bool flop(word _) {
  return packp(_) && vec(_)->rank == 0 && vec(_)->type == ai_R; }
// Wide-integer box: a rank-0 ai_Z scalar vec. Arises only from
// transparent fixnum overflow (kernel/math.c); never holds a value that
// fits the fixnum tag (canonical demotion keeps box and fixnum ranges
// disjoint), so widep and charmp never both hold for the same number.
static ai_inline bool widep(word _) {
  return packp(_) && vec(_)->rank == 0 && vec(_)->type == ai_Z; }
// A complex scalar: a rank-0 ai_C vec (two ai_flo_t, re then im). Deliberately
// NOT folded into isnum -- the real-tower macros (toflo/toint) would misread its
// two-word payload, so the arith/eq paths handle complex via explicit Cp
// branches placed before the real lanes (decision: complex > float > int/bignum).
static ai_inline bool Cp(word _) {
  return packp(_) && vec(_)->rank == 0 && vec(_)->type == ai_C; }
// A rank>=1 typed array (vs a rank-0 scalar box, which flop/widep catch). The
// elementwise arith/compare lanes divert to lvm_vbin when either operand arrp.
static ai_inline bool arrp(word _) { return packp(_) && vec(_)->rank >= 1; }

// Max array rank (bounds the stack index/stride arrays in the broadcast loop).
#define maxrank 8
extern size_t const ai_vt_[];                 // element byte size by ai_vec_type
// Element payload: laid out row-major just past the shape words.
static ai_inline void *vec_data(struct ai_vec *v) { return (void*) (v->shape + v->rank); }
// Total element count = product of the dimensions (1 for a rank-0 scalar box).
static ai_inline uintptr_t vec_nelem(struct ai_vec *v) {
 uintptr_t n = 1;
 for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 return n; }
static ai_inline struct ai_vec *ini_vec(struct ai_vec *v, enum ai_vec_type t, uintptr_t rank) {
 return v->ap = lvm_vec, v->type = t, v->rank = rank, v; }
// Read element i of v as a double / as an integer (sign-extending the narrow
// integer types; truncating a float toward zero for the int reader). The int
// reader is only used on integer-typed arrays in practice.
static ai_inline ai_flo_t vec_get_flo(struct ai_vec *v, uintptr_t i) {
 void *p = vec_data(v);
 return v->type == ai_R ? ((ai_flo_t*) p)[i] : (ai_flo_t) ((intptr_t*) p)[i]; }
static ai_inline intptr_t vec_get_int(struct ai_vec *v, uintptr_t i) {
 void *p = vec_data(v);
 return v->type == ai_R ? (intptr_t) ((ai_flo_t*) p)[i] : ((intptr_t*) p)[i]; }
// Write element i of v, converting to v's element kind.
static ai_inline void vec_put_int(struct ai_vec *v, uintptr_t i, intptr_t x) {
 void *p = vec_data(v);
 if (v->type == ai_R) ((ai_flo_t*) p)[i] = (ai_flo_t) x; else ((intptr_t*) p)[i] = x; }
static ai_inline void vec_put_flo(struct ai_vec *v, uintptr_t i, ai_flo_t x) {
 void *p = vec_data(v);
 if (v->type == ai_R) ((ai_flo_t*) p)[i] = x; else ((intptr_t*) p)[i] = (intptr_t) x; }
// Read/write element i of a ai_O array as a raw tagged l word (the GC traces
// these; see evac_vec). No conversion -- the slot IS a value.
static ai_inline word vec_get_obj(struct ai_vec *v, uintptr_t i) {
 return ((word*) vec_data(v))[i]; }
static ai_inline void vec_put_obj(struct ai_vec *v, uintptr_t i, word x) {
 ((word*) vec_data(v))[i] = x; }

// Truthiness: x is false iff (= 0 ($ x)) -- the net's sign read in the total order.
// THE NET'S CODOMAIN IS COMPLEX (ai_net below): a complex scalar nets ITSELF, phase
// intact; every other scalar nets on the real line; aggregates SUM as complex
// numbers -- + is total there, so the net is additive EXACTLY, at every rank and
// phase. Truth and $ each observe the net through ONE retraction at the boundary:
// ai_nilp reads the lex sign (re, then im -- the flagged order choice, applied once,
// never per element), ai_pin the order-signed magnitude. The common kinds short-
// circuit with NO walk: nil (the 0 word), EmptyString, fixnum sign, table key count,
// bignum sign, symbol name; products, vecs, strings and bufs compute their net
// (content measures: an all-NUL text or zeroed buf is nothing, and a sum cannot
// short-circuit -- a later negative can cancel an early positive). Lockstep with
// ai_pin (lvm_pin): same zero conditions.
// a symbol's net, shared by ai_net ($) and ai_nilp (!): the SPELLING's charm
// sum (a symbol nets what its nom pair nets -- chars measure by content now).
// every MINT (the nameless fresh point: materially empty, a DISTINCT NOTHING)
// nets 0 -> falsy; so does an all-NUL spelling: a string of nothings is
// nothing, in or out of a symbol.
static ai_inline intptr_t pin_sym(struct ai *g, word x) {
  if (x == (word) ai_core_of(g)) return 0;  // () is the core: a nameless point, no spelling -> net 0 (its atom slots are live VM state, never read)
  struct ai_str *nm = ((struct ai_atom*) x)->nom;
  if (!nm) return 0;
  intptr_t t = 0;
  for (uintptr_t i = 0; i < nm->len; i++) t += (uint8_t) nm->bytes[i];
  return t; }
struct ai_zn { ai_flo_t re, im; };                     // the net: a complex value
static ai_inline struct ai_zn zn(ai_flo_t re, ai_flo_t im) {
  struct ai_zn z = {re, im}; return z; }
static ai_inline bool zn_nonpos(struct ai_zn z) {      // <= 0 in the total order
  return z.re < 0 || (z.re == 0 && z.im <= 0); }
static struct ai_zn ai_net(struct ai *, word);         // fwd: aggregates sum their elements
static ai_inline bool ai_nilp(struct ai *g, word x) {
  if (x == nil || x == EmptyString) return true;
  if (charmp(x)) return getcharm(x) < 0;                 // 0 is nil (caught above); negatives false
  if (mapp(x)) return map_len(x) == 0;
  if (bigp(x)) return ((struct ai_big*) x)->slen < 0; // a negative bignum is false
  if (symp(x)) return pin_sym(g, x) == 0;            // empty/anonymous symbol name (or the core) -> nil (pin lockstep)
  if (twop(x) || packp(x) || strp(x) || bufp(x))
    return zn_nonpos(ai_net(g, x));                   // content measures: net <= 0 in the order
  return false; }                                    // fn / port: present

// Truncation toward zero / float remainder. Pure, freestanding-safe (no libm):
// 1/0 lowers to an FPU divide that yields +-inf or NaN per IEEE, and inf*0=NaN
// propagates through ai_fmod's subtraction. Shared by the scalar arith slow
// paths (math.c) and the elementwise array lane (arr.c).
static ai_inline ai_flo_t ai_trunc(ai_flo_t x) {
 if (x != x) return x;
 ai_flo_t m = x < 0 ? -x : x;
 if (m > (ai_flo_t) 9.22e18) return x;
 return (ai_flo_t) (int64_t) x; }
static ai_inline ai_flo_t ai_fmod(ai_flo_t a, ai_flo_t b) {
 return a - ai_trunc(a / b) * b; }

// --- numeric tower helpers (shared by math.c, arr.c, hash.c) ----------------
// Numeric scalar = a fixnum, a boxed float (flop), or a boxed wide int (widep).
#define isnum(x) (charmp(x) || flop(x) || widep(x) || bigp(x))
// Integer value of a fixnum-or-box operand (callers must exclude floats AND
// bignums -- a bignum doesn't fit an intptr_t; integer lanes guard on !bigp).
#define toint(x) (charmp(x) ? (intptr_t) getcharm(x) : box_get(x))
// Double value of any numeric operand (a bignum widens via ai_big_to_flo).
#define toflo(x) (charmp(x) ? (ai_flo_t) getcharm(x) : flop(x) ? flo_get(x) : widep(x) ? (ai_flo_t) box_get(x) : ai_big_to_flo(x))
// Heap words for one scalar box. The float box (ai_flo_t) and the wide-int box
// (intptr_t) are both one pointer-width word, so one reservation fits.
#define box_req (Width(struct ai_vec) + Width(intptr_t))
// Heap words for one complex box: the (re, im) payload is two ai_flo_t words.
#define cplx_req (Width(struct ai_vec) + 2 * Width(ai_flo_t))
// The tagged fixnum range: putcharm spends one bit, so |value| <= 2^(Bits-2).
#define fix_min (INTPTR_MIN >> 1)
#define fix_max (INTPTR_MAX >> 1)
// Emit an integer result R into `_res`: demote to a fixnum when it fits the
// tag, else box it as a rank-0 ai_Z scalar (bumping Hp). The caller must
// already hold Have(box_req). Takes no &local, so a ap that uses it keeps
// its trailing tail call.
#define emit_int(R) do { intptr_t _r = (R); \
 if (_r >= fix_min && _r <= fix_max) _res = putcharm(_r); \
 else { struct ai_vec *_v = ini_scalar((struct ai_vec*) Hp, ai_Z); \
        Hp += box_req; box_put(_v->shape, _r); _res = word(_v); } } while (0)
// Emit a double result R into `_res` as a rank-0 ai_R box. Same Have(box_req)
// precondition and TCO discipline as emit_int.
#define emit_flo(R) do { struct ai_vec *_v = ini_scalar((struct ai_vec*) Hp, ai_R); \
 Hp += box_req; flo_put(_v->shape, (R)); _res = word(_v); } while (0)

// Step 8 -- RNG (kernel/rng.c). State is a rank-1 i64 vec of length 4 (256 bits,
// xoshiro256++). It rides the existing vec machinery (no data sentinel) but its
// payload is treated as raw bytes -- moved by memcpy, never via vec_get/put_int,
// which would truncate the 64-bit limbs to intptr_t on 32-bit ports. The fixed
// 8-byte limbs make a seed reproduce the same sequence on every target.
#define rng_state_len 4
#define rng_payload_bytes (rng_state_len * 8)
#define rng_vec_bytes (sizeof(struct ai_vec) + sizeof(uintptr_t) + rng_payload_bytes)
#define rng_vec_req (b2w(rng_vec_bytes))
// State element kind: pick whichever kind is 8 bytes wide so ai_vec_bytes (GC) sees
// the full 256-bit payload -- Z (one word) on 64-bit, C (two words) on 32-bit.
#define rng_vt (Bytes == 4 ? ai_C : ai_Z)
void ai_rng_seed(struct ai_vec*, uint64_t);   // shape an i64 state vec + seed it (SplitMix64)
lvm_t lvm_rng_seed, lvm_rand_next, lvm_randf_next;
int memcmp(void const*, void const*, size_t);
void *malloc(size_t), free(void*),
 *memcpy(void*restrict, void const*restrict, size_t),
 *memmove(void*restrict, void const*restrict, size_t),
 *memset(void*, int, size_t);
long strtol(char const*restrict, char**restrict, int);
size_t strlen(char const*);
double strtod(char const *restrict, char **restrict);

// Boxed scalar float access. The payload occupies one uintptr_t-wide
// shape[] slot (ai_flo_t is f64 on 64-bit ports, f32 on 32-bit -- always
// the width of uintptr_t). Pun through a union rather than
// memcpy(&local, ...): both are strict-aliasing clean, but the memcpy form
// takes the address of a stack local, which clang -Os treats as an escape
// and then refuses to sibling-call the trailing Continue() out of any VM
// ap that inlines this -- silently breaking threaded dispatch (a
// `call`+`ret` where there must be a `jmp`; see tools/vmret.l). GCC proves
// the local dead and TCOs either way; the union keeps the value in a
// register so clang does too.
_Static_assert(sizeof(ai_flo_t) == sizeof(uintptr_t), "float box assumes ai_flo_t is pointer-width");
typedef union { uintptr_t u; ai_flo_t d; } ai_flo_pun;
static ai_inline ai_flo_t flo_get(word x) {
 return ((ai_flo_pun){ .u = vec(x)->shape[0] }).d; }
static ai_inline void flo_put(void *p, ai_flo_t v) {
 // NaN collapses to 0.0: love's "undefined is nothing" convention (a type error
 // is nil) reaching the floats. This is the single real-float box-write, so 0/0
 // and every other indeterminate land on 0 -- the value NaN's own net ($ = 0)
 // already claimed. Restores the total order (NaN was its only incomparable
 // point) and the !x == (0 = $x) coherence (NaN alone netted 0 yet read truthy).
 // `inf` is untouched (it is comparable); complex NaN rides cplx_put, not here.
 if (v != v) v = 0;                              // v != v iff v is NaN
 *(uintptr_t*) p = ((ai_flo_pun){ .d = v }).u; }

// Boxed complex access: re in shape[0], im in shape[1] (rank-0, so vec_data ==
// shape). Same union-pun discipline as flo_get/flo_put so an inlining VM ap
// keeps its tail call. cplx_put writes both components of an already-shaped box.
static ai_inline ai_flo_t cplx_re(word x) {
 return ((ai_flo_pun){ .u = vec(x)->shape[0] }).d; }
static ai_inline ai_flo_t cplx_im(word x) {
 return ((ai_flo_pun){ .u = vec(x)->shape[1] }).d; }
// |z| of a boxed complex scalar: the L2 norm of (re, im).
static ai_inline ai_flo_t cplx_mod(word x) {
 ai_flo_t re = cplx_re(x), im = cplx_im(x);
 return ai_sqrt(re * re + im * im); }
// (the total-order non-positive test for a boxed complex lives on the net now:
// ai_net returns the value itself and zn_nonpos reads the lex sign -- once.)
static ai_inline void cplx_put(struct ai_vec *v, ai_flo_t re, ai_flo_t im) {
 v->shape[0] = ((ai_flo_pun){ .d = re }).u;
 v->shape[1] = ((ai_flo_pun){ .d = im }).u; }

// Boxed wide-int access. The payload is one pointer-width signed integer
// in shape[0]; unlike the float box it needs no bit reinterpretation --
// it is already an integer, only its signedness differs from the
// uintptr_t slot. Neither helper takes the address of a stack local, so a
// VM ap that inlines them keeps its trailing tail call (see the
// flo_get/flo_put note above and tools/vmret.l).
static ai_inline intptr_t box_get(word x) { return (intptr_t) vec(x)->shape[0]; }
static ai_inline void box_put(void *p, intptr_t v) { *(uintptr_t*) p = (uintptr_t) v; }

// equality comparisons inline the fast identity check
ai_noinline bool eqv(struct ai*, word, word); // this is for checking equality of non-identical values
static ai_inline bool eql(struct ai *g, word a, word b) { return a == b || eqv(g, a, b); }

// Threads -- and every other variable-length heap object the GC copies by
// sounding (continuations, task nodes, env scopes, ports) -- end with a single
// tag word: the object's own head pointer with bit 1 set (ai_text_tag), saving a
// word over a separate NULL marker + head. Small ints are odd and l heap
// pointers are word-aligned, so the only other word that can carry (x & 3) == 2
// is an embedded *external* pointer (host data/function) that happens to land
// on a 2-byte boundary. So the terminator test is not just the tag bits: the
// payload must also point back into [lo, hi), the pool the object lives in --
// which a stray external pointer never does.
#define ai_text_tag 2
static ai_inline bool tagp(word x, word const *lo, word const *hi) {
 word const *p = (word const*) (x & ~(word) 3);
 return (x & 3) == ai_text_tag && p >= lo && p < hi; }
static ai_inline union u *tagtext(union u *h, uintptr_t len) {
  return h[len].x = word(h) | ai_text_tag, h; }
#define topof(g) ((word*)g+g->len)
static ai_inline struct ai_tag { union u *head; union u end[]; } *ttag(struct ai*g, union u *k) {
 word *lo = ptr(g), *hi = topof(g);
 while (!tagp(k->x, lo, hi)) k++;
 return (struct ai_tag*) k; }
static ai_inline union u *tag_head(struct ai_tag *t) {
 return cell(word(t->head) & ~(word) 3); }

static ai_inline union u *clip(struct ai *g, union u *k) {
 return tagtext(k, cell(ttag(g, k)) - k); }



static ai_inline struct ai_atom *ini_missing(struct ai_atom *y, uintptr_t code) {
 return y->ap = lvm_sym, y->nom = 0, y->code = code, y; }

static ai_inline struct ai_atom *ini_sym(struct ai_atom *y, struct ai_str *nom, uintptr_t code) {
 return y->ap = lvm_sym, y->nom = nom, y->code = code, y; }

static ai_inline struct ai_str *ini_str(struct ai_str *s, uintptr_t len) {
 return s->ap = lvm_str, s->len = len, s; }

// The unique empty string and empty (anonymous) symbol. Both live in the data
// segment, so the Cheney forwarder leaves any pointer to them untouched (gcp's
// out-of-pool short-circuit, like ai_stdin/stdout/stderr) -- immortal, never copied
// or freed, so `const` is safe. Strings are immutable, so a single empty string
// suffices and we NEVER heap-allocate a zero-length one (str0/strin/the reader and
// the `+` string lane all hand back ai_str_empty). Predicates read `ap`, so it
// behaves as a normal string value; the FAM `bytes[]` is simply absent (len 0).
// External linkage (declared in ai.h with the EmptyString macro) so the
// frontends can return it too (e.g. host_run's empty-output capture). (the
// empty SYMBOL died in the one-nothing round: () reads as 0.)
const struct ai_str ai_str_empty = { .ap = lvm_str, .len = 0 };

static ai_inline struct ai_vec *ini_scalar(struct ai_vec *v, enum ai_vec_type t) {
 return v->ap = lvm_vec, v->type = t, v->rank = 0, v; }


static ai_inline uintptr_t rot(uintptr_t x) {
  int const s = sizeof(uintptr_t) * 4; // shift bits = word bits / 2 = sizeof(word) * 4
  return (x << s) | (x >> s); }

extern struct ai_port_vt const synth[];

struct ti { struct ai_io io; char const *t; word i; } ; // C string input
static ai_inline void *off_pool(struct ai *g) {
 return g == g->pool ? (word*) g->pool + g->len : (word*) g->pool; }
static ai_inline struct ai *pushq(struct ai*g) { return intern(ai_strof(g, "\\")); }
static ai_inline struct ai *push0(struct ai*g) { return ai_push(g, 1, nil); }
static ai_inline size_t llen(word l) {
 size_t n = 0;
 while (twop(l)) n++, l = B(l);
 return n; }
static ai_inline struct ai*ai_pop(struct ai*g, uintptr_t n) {
 return ai_core_of(g)->sp += n, g; }

// ============================================================================
// macros (hoisted from all merged units; see section banners below)
// ============================================================================






#define min(p,q) ((p)<(q)?(p):(q))
#define max(p,q) ((p)>(q)?(p):(q))




#define limb_bits 32
#define limb_base ((uint64_t) 1 << limb_bits)

#define yield_interval 64
#define YieldCheck() \
  if (g->tasks->m != g->tasks && ++g->yield_ctr >= yield_interval) \
    return Ap(lvm_yield_sw, g)
#define argn(nom, i) lvm(nom) { Have1(); Sp[-1] = Sp[i]; Sp -= 1; Ip += 1; return Continue(); }
#define quon(nom, v) lvm(nom) { Have1(); Sp -= 1; Sp[0] = putcharm(v); Ip += 1; return Continue(); }

#define Ana(n, ...) struct ai *n(struct ai *g, struct env **c, intptr_t x, ##__VA_ARGS__)
#define Cata(n, ...) struct ai *n(struct ai *g, struct env **c, ##__VA_ARGS__)
#define incl(e, n) ((e)->len += ((n)<<1))
#define Kp (g->ip)
#define cata1(n, ...) static Cata(n) { return __VA_ARGS__, pull(g, c); }
#define forget() (ai_core_of(g)->root=(mm0),g)

#define fs0(g) (ai_core_of(g)->sp[0])
#if UINTPTR_MAX > 0xffffffffu
#define dtoa_inf    1e308
#define dtoa_sci_hi 1e16
#define dtoa_sci_lo 1e-4
#else
#define dtoa_inf    __FLT_MAX__
#define dtoa_sci_hi 1e16f
#define dtoa_sci_lo 1e-4f
#endif

#define s1(i) {{i}, {lvm_ret0}}
#define s2(i) {{lvm_cur},{.x=putcharm(2)},{i}, {lvm_ret0}}
#define s3(i) {{lvm_cur},{.x=putcharm(3)},{i}, {lvm_ret0}}
#define s4(i) {{lvm_cur},{.x=putcharm(4)},{i}, {lvm_ret0}}
#define s5(i) {{lvm_cur},{.x=putcharm(5)},{i}, {lvm_ret0}}
// HARNESS (compile-gated, -DG_FAULT_TEST): __fault deliberately derefs null to
// raise a hardware fault inside eval -- the one in-eval fault a user can trigger to
// probe the ai_eval fault barrier (the raw fault nifs spin/peek/poke/seek are pulled
// from the image at birth, so nothing else reaches it). NEVER in a shipping or kernel
// build (the kernel has no signal recovery -- it would crash qemu).
#ifdef G_FAULT_TEST
lvm_t lvm_fault;
#define NIF_FAULT(_) _(nif_fault, "__fault", s1(lvm_fault))
#else
#define NIF_FAULT(_)
#endif
#define nifs(_) \
 _(nif_clock, "clock", s1(lvm_clock)) _(nif_gauge, "gauge", s1(lvm_gauge))\
 _(nif_add, "+", s2(lvm_add)) _(nif_sub, "-", s2(lvm_sub)) _(nif_mul, "*", s2(lvm_mul))\
 _(nif_quot, "/", s2(lvm_quot)) _(nif_fquot, "//", s2(lvm_fquot)) _(nif_rem, "%", s2(lvm_rem)) \
 _(nif_lt, "<", s2(lvm_lt))  _(nif_le, "<=", s2(lvm_le)) _(nif_eq, "=", s2(lvm_eq))\
 _(nif_ge, ">=", s2(lvm_ge))  _(nif_gt, ">", s2(lvm_gt)) \
 _(nif_same, "idp", s2(lvm_same)) \
 _(nif_bsl, "<<", s2(lvm_bsl)) _(nif_bsr, ">>", s2(lvm_bsr))\
 _(nif_band, "&", s2(lvm_band)) _(nif_bor, "|", s2(lvm_bor)) _(nif_bxor, "^", s2(lvm_bxor))\
 _(nif_cons, "cons", s2(lvm_cons)) _(nif_car, "cap", s1(lvm_car)) _(nif_cdr, "cup", s1(lvm_cdr))\
 _(nif_sort, "sort", s1(lvm_sort)) _(nif_tally, "tally", s1(lvm_tally)) \
 _(nif_slice, "slice", s3(lvm_slice)) \
 _(nif_read, "read", s2(lvm_read))\
 _(nif_string, "string", s1(lvm_string))\
 _(nif_intern, "intern", s1(lvm_intern)) _(nif_mint, "mint", s1(lvm_mint))\
 _(nif_spin, "spin", s1(lvm_spin))\
 _(nif_peek, "peek", s2(lvm_peek)) _(nif_poke, "poke", s3(lvm_poke)) _(nif_trim, "trim", s1(lvm_trim))\
 _(nif_seek, "seek", s2(lvm_seek)) _(nif_pin, "sat", s1(lvm_pin)) _(nif_peep, "peep", s3(lvm_peep))\
 _(nif_put, "pin", s3(lvm_put)) _(nif_pull, "pull", s3(lvm_pull))\
 _(nif_table, "tablet", s1(lvm_table)) _(nif_keys, "keys", s1(lvm_keys))\
 _(nif_dig, "dig", s1(lvm_dig))\
 _(nif_bufnew, "buf", s1(lvm_bufnew)) _(nif_bcopy, "blit", s5(lvm_bcopy))\
 _(nif_call, "call", s2(lvm_call)) _(nif_call2, "call2", s3(lvm_call2)) _(nif_toast, "toast", s1(lvm_toast))\
 _(nif_twop, "twop", s1(lvm_twop)) _(nif_strp, "strp", s1(lvm_strp))\
 _(nif_real, "real", s1(lvm_real)) _(nif_flop, "flop", s1(lvm_flop))\
 _(nif_sin, "sin", s1(lvm_sin)) _(nif_cos, "cos", s1(lvm_cos))\
 _(nif_log, "log", s1(lvm_log)) _(nif_pow, "pow", s2(lvm_pow))\
 _(nif_cplx, "wave", s2(lvm_cplx)) _(nif_Cp, "comp", s1(lvm_Cp))\
 _(nif_re, "re", s1(lvm_re)) _(nif_im, "im", s1(lvm_im)) _(nif_conj, "conj", s1(lvm_conj))\
 _(nif_abs, "abs", s1(lvm_abs)) _(nif_arg, "arg", s1(lvm_carg))\
 _(nif_arr, "arr", s3(lvm_arr))\
 _(nif_iota, "iota", s1(lvm_iota))\
 _(nif_nat, "nat", s3(lvm_nat)) _(nif_natn, "natn", s4(lvm_natn))\
 _(nif_arank, "arank", s1(lvm_arank))\
 _(nif_alen, "alen", s1(lvm_alen)) _(nif_ashape, "ashape", s1(lvm_ashape))\
 _(nif_atype, "atype", s1(lvm_atype))\
 _(nif_asum, "asum", s1(lvm_asum)) _(nif_aprod, "aprod", s1(lvm_aprod))\
 _(nif_amax, "amax", s1(lvm_amax)) _(nif_amin, "amin", s1(lvm_amin))\
 _(nif_aall, "aall", s1(lvm_aall)) _(nif_inner, "inner", s2(lvm_inner)) _(nif_outer, "outer", s2(lvm_outer))\
 _(nif_packp, "packp", s1(lvm_packp)) _(nif_bigp, "bigp", s1(lvm_bigp)) _(nif_widep, "widep", s1(lvm_widep))\
 _(nif_arrp, "arrp", s1(lvm_arrp)) _(nif_intf, "int", s1(lvm_intf))\
 _(nif_symp, "symp", s1(lvm_symp)) _(nif_mapp, "mapp", s1(lvm_mapp)) _(nif_fixp, "fixp", s1(lvm_fixp))\
 _(nif_lamp, "lamp", s1(lvm_lamp)) _(nif_hotp, "hotp", s1(lvm_hotp))\
 _(nif_nilp, "nilp", s1(lvm_nilp)) _(nif_ev, "ev", s1(lvm_eval))\
 _(nif_callk, "call-cc", s1(lvm_callk)) _(nif_scare, "scare", s2(lvm_scare))\
 _(nif_missing, "missing", s2(lvm_missing)) _(nif_yield, "yield", s1(lvm_yield_nif)) \
 _(nif_spawn, "spawn", s2(lvm_spawn)) _(nif_wait, "wait", s1(lvm_wait)) \
 _(nif_sleep, "sleep", s1(lvm_sleep)) _(nif_donep, "done?", s1(lvm_donep)) \
 _(nif_hush, "hush", s1(lvm_hush)) \
 _(nif_key, "key?", s1(lvm_key)) \
 _(nif_fputbn, "fputbn", s3(lvm_fputbn))\
 _(nif_fputx, "fputx", s2(lvm_fputx))\
 _(nif_fgetc, "fgetc", s1(lvm_fgetc)) _(nif_fungetc, "fungetc", s2(lvm_fungetc)) _(nif_feof, "feof", s1(lvm_feof))\
 _(nif_fputc, "fputc", s2(lvm_fputc)) _(nif_fputs, "fputs", s2(lvm_fputs))  _(nif_fflush, "fflush", s1(lvm_fflush))\
 _(nif_dot, "dot", s1(lvm_dot))\
 _(nif_rng_seed, "rng-seed", s1(lvm_rng_seed))\
 _(nif_rand_next, "rand-next", s1(lvm_rand_next)) _(nif_randf_next, "randf-next", s1(lvm_randf_next)) NIF_FAULT(_)
#define native_implemented_function(n, _, d) static union u const n[] = d;
#define insts(_) _(lvm_unc) _(lvm_index) _(lvm_ret) _(lvm_ap) _(lvm_tap) _(lvm_apn) _(lvm_tapn)\
  _(lvm_jump) _(lvm_cond) _(lvm_arg) _(lvm_quote) _(lvm_defglob)\
  _(lvm_argap) _(lvm_quoteap) _(lvm_argtap)\
  _(lvm_arg0) _(lvm_arg1) _(lvm_arg2) _(lvm_arg3)\
  _(lvm_quo0) _(lvm_quo1) _(lvm_quo2) _(lvm_quo3) _(lvm_quom1) _(lvm_quom2)\
  _(lvm_zp)
#define niff(b, n, _) {n, (intptr_t) b},
#define i_entry(i) {#i, (intptr_t) i},

// ============================================================================
// g
// ============================================================================
enum ai_status ai_fin(struct ai *g) {
 enum ai_status s = ai_code_of(g);
 if ((g = ai_core_of(g))) {
   for (struct ai_fz *fz = g->fz; fz; fz->fn(fz->p), fz = fz->next); // run finalizers
   g->alloc(g, g->pool, 0); }
 return s; }

struct ai *ai_defn(struct ai*g, struct ai_def const*defs, uintptr_t n) {
 for (g = ai_push(g, 1, ai_core_of(g)->book); n--;
  g = ai_mapput(intern(ai_strof(ai_push(g, 1, defs[n].x), defs[n].n))));
 ai_core_of(g)->sp++;
 return g; }

nifs(native_implemented_function);

static lvm(_lvm_yield_c) { return Pack(g), g; }
static union u const yield_c[] = { {_lvm_yield_c} };

// lvm_help: the default help ap, a first-class vm ap (declared in ai.h with
// ret0/cur/port_io). A raise enters it with the raised status encoded into g
// (see ghelp2 below). The MORE bit is read control flow, not a scare: the
// raise site left [resume port sentinel] on the stack (the read protocol), so
// deliver the port (more: incomplete) or the sentinel (eof) to the resume
// text and keep running. A scare re-encodes and yields to C. Define a global
// `help` function to land raises in l instead.
// the scare exit door: re-encode and yield to C. Lives OUTSIDE the lvm_*
// namespace (the underscore convention, like _lvm_yield_c above) because it
// is the one designed return -- the vmret gate's no-ret invariant sounds
// lvm_*, and lvm_help reaches here by tail call (a jmp under ai_tco).
static lvm(_lvm_help_scare, enum ai_status s) { return Pack(g), encode(g, s); }
lvm(lvm_help) {
 enum ai_status s = ai_code_of(g);
 g = ai_core_of(g);
 if (s & ai_status_more) {
  Ip = cell(Sp[0]);                                   // [resume port sentinel]
  Sp[2] = s == ai_status_more ? Sp[1] : Sp[2];         // more -> port, eof -> sentinel
  Sp += 2;
  return Continue(); }
 return Ap(_lvm_help_scare, g, s); }
static union u const raise_c[] = { {lvm_help} };

// ghelp2/ghelp are defined after numap_drive (the help call frame runs
// through its 3-arg twin); declared in ai.h.

static struct ai_def const def1[] = { nifs(niff) insts(i_entry)};

// --- frontend-nif defaults ---------------------------------------------------
// exit/open/close/run/getenv are FRONTEND nifs: each frontend overrides them via
// ai_defn (main.c POSIX, kmain.c qemu, the wasm host emscripten) -- the book is
// last-write-wins, and a frontend's ai_defn runs after ai_ini. The core installs
// safe no-op defaults here so the NAMES ALWAYS EXIST. A frontend that omits one
// then inherits a clean nil instead of a MISSING name -- whose capture-at-
// creation would raise (scare 'missing ..) at every define that merely mentions
// it, even in an unrun branch (the wasm host's missing `exit` did exactly that).
// The defaults need no OS, so they live in the freestanding core. open is the
// only 2-arg one (curried via lvm_cur like the real main.c nif).
lvm(lvm_absent)  { return Sp[0] = nil, Ip++, Continue(); }                 // 1-arg -> nil
lvm(lvm_absent2) { return Sp[1] = nil, Sp += 1, Ip++, Continue(); }        // 2-arg -> nil (open)
static union u const nif_absent[]      = {{lvm_absent}, {lvm_ret0}};
static union u const nif_absent_open[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_absent2}, {lvm_ret0}};
static struct ai_def const frontend_defaults[] = {
 {"exit", (word) nif_absent}, {"open", (word) nif_absent_open}, {"close", (word) nif_absent},
 {"run", (word) nif_absent},  {"getenv", (word) nif_absent} };

// reverse-lookup a function value against the builtin table -> its source name,
// or NULL. Used by the printer to render nifs (e.g. `+`) by name.
char const *ai_nif_name(intptr_t x) {
 for (uintptr_t i = 0; i < countof(def1); i++) if (def1[i].x == x) return def1[i].n;
 return 0; }

static struct ai *ai_ini_0(struct ai*g, uintptr_t len0, void *(*al)(struct ai*, void*, size_t)) {
 memset(g, 0, sizeof(struct ai));
 g->ap = lvm_sym;                      // () IS the core: its first word is an ap (a nameless point; no code/nom to read)
 g->len = len0, g->pool = (void*) g, g->alloc = al;
 g->scare_a = g->scare_b = nil;        // v0..end is GC-walked: raw 0 is not a value
 g->hp = g->end, g->sp = (word*) g + len0, g->ip = (union u*) yield_c, g->t0 = ai_clock();
 // book + macro maps (lookup-lambdas) then the main task text.
 if (ai_ok(g = map_new(g)) && ai_ok(g = map_new(g)) && ai_ok(g = ai_have(g, 6))) {
  union u *M = bump(g, 6);            // sp[0]=macro, sp[1]=book (no GC since ai_have)
  M[0].m = M;
  M[1].x = nil;   // sentinel; replaced on first yield
  M[2].x = nil;   // main pid
  M[3].x = nil;   // wake_at: nil means "always runnable"
  M[4].x = putcharm(-1);  // wait_fd: -1 = not waiting on I/O (slot value -1, non-zero)
  g->tasks = tagtext(M, 5);
  // book[nil] = macro (the macro table -- no separate field). Both are on the
  // stack; push the nil key so (sp2,sp1,sp0)=(book,macro,nil) for ai_mapput.
  g = ai_push(g, 1, nil);
  g = ai_mapput(g);                     // -> sp[0] = book
  g->book = g->sp[0];                  // henceforth GC-forwarded via the v0..end loop
  g = ai_pop(g, 1);
  // the WEAK intern map (string -> the canonical atom), created before the
  // first intern (the def tables just below). it lives OUTSIDE the traced
  // v0 region: gcg clones it untraced and sweeps it at the fixpoint.
  g = map_new(g);
  if (ai_ok(g)) g->symbols = ai_pop1(g);
  struct ai_def def0[] = {
   {"book", g->book},
   {"in", (word) &ai_stdin},
   {"out", (word) &ai_stdout},
   {"err", (word) &ai_stderr},
   // fix-max/fix-min: this build's fixnum bounds, exposed so width-specific
   // tests gate on the real boundary (it differs on 32- vs 64-bit ports).
   {"fix-max", putcharm((ai_word)((uintptr_t)-1 >> 2))},
   {"fix-min", putcharm(-(ai_word)((uintptr_t)-1 >> 2) - 1)}, };
  g = ai_defn(g, def0, countof(def0));
  g = ai_defn(g, def1, countof(def1));
  g = ai_defn(g, frontend_defaults, countof(frontend_defaults));   // overridable by the frontend
  // `ai-version`: the build's version-control id (ai_version.h), surfaced on init so the user
  // can read the running version. A non-fixnum global, harmlessly skipped by ev.l's pureset.
  if (ai_ok(g = ai_strof(g, AI_VERSION))) {
   struct ai_def vd[] = {{"ai-version", ai_pop1(g)}};
   g = ai_defn(g, vd, countof(vd)); }
  // the 'missing condition tag needs no pre-intern: it is the `missing` nif's
  // name, so installing that nif interns it and the book roots it; the raise
  // path reads it back alloc-free via sym_probe (lvm_index/lvm_missing).
  // the reader owns no operator tables: book['operators] (the ONE table,
  // symbol -> arity | (name . arity)) is seeded by the prel, and the
  // opfix source pass (prel.l, hooked by both compilers at c0 and wev)
  // factors sigil tokens against it at compile time. data reading is
  // purely structural.
 }
 return g; }

struct ai *ai_ini_m(void *(*al)(struct ai*, void*, size_t)) {
 uintptr_t const len0 = 1 << 10;
 struct ai *g = al(NULL, NULL, 2 * len0 * sizeof(word));
 return g == NULL ? encode(g, ai_status_scare) : ai_ini_0(g, len0, al); }

static void *ai_static_alloc(struct ai*g, void *p, size_t n) { (void) g, (void) p, (void) n; return NULL; }  // fixed arena: no malloc/free
struct ai *ai_ini_s(void *mem, uintptr_t nbytes) {
 uintptr_t len0 = nbytes / (2 * sizeof(word));
 return len0 <= Width(struct ai) ? encode(mem, ai_status_scare) :
   ai_ini_0(mem, len0, ai_static_alloc); }

static void *ai_libc_alloc(struct ai*g, void *p, size_t n) { (void) g; return n ? malloc(n) : (free(p), NULL); }
struct ai *ai_ini(void) { return ai_ini_m(ai_libc_alloc); }

// ============================================================================
// stack
// ============================================================================
static struct ai *ai_pushr(struct ai *g, uintptr_t m, uintptr_t n, va_list xs) {
 if (n == m) return ai_please(g, m);
 word x = va_arg(xs, word);
 mm(g, &x);
 g = ai_pushr(g, m, n + 1, xs);
 um(g);
 if (ai_ok(g)) *--g->sp = x;
 return g; }

struct ai *ai_push(struct ai *g, uintptr_t m, ...) {
 if (!ai_ok(g)) return g;
 va_list xs;
 va_start(xs, m);
 uintptr_t n = 0;
 if (avail(g) < m) g = ai_pushr(g, m, n, xs);
 else for (g->sp -= m; n < m; g->sp[n++] = va_arg(xs, word));
 va_end(xs);
 return g; }

struct ai *gxl(struct ai *g) {
 if (ai_ok(g = ai_have(g, Width(struct ai_pair)))) {
  struct ai_pair *p = bump(g, Width(struct ai_pair));
  ini_two(p, g->sp[0], g->sp[1]);
  *++g->sp = (word) p; }
 return g; }

struct ai *gxr(struct ai *g) {
 if (ai_ok(g = ai_have(g, Width(struct ai_pair)))) {
  struct ai_pair *p = bump(g, Width(struct ai_pair));
  ini_two(p, g->sp[1], g->sp[0]);
  *++g->sp = (word) p; }
 return g; }

// ============================================================================
// gc
// ============================================================================
lvm(lvm_gc, uintptr_t n) {
 Pack(g);
 if (!ai_ok(g = ai_please(g, n))) return ghelp(g);
 return Unpack(g), Continue(); }

static word gcp(struct ai*, word, word const *, word const *);

static ai_inline void evac_two(struct ai*g, word const*const p0, word const*const t0) {
 struct ai_pair *w = (struct ai_pair*) g->cp;
 g->cp += Width(struct ai_pair);
 w->a = gcp(g, w->a, p0, t0);
 w->b = gcp(g, w->b, p0, t0); }

static ai_inline void evac_vec(struct ai*g, word const*const p0, word const*const t0) {
 struct ai_vec *v = vec(g->cp);
 g->cp += b2w(ai_vec_bytes(v));
 if (v->type != ai_O) return;                 // numeric vecs are GC leaves (flat payload)
 word *e = (word*) vec_data(v);              // object vec: forward each live element word
 uintptr_t n = vec_nelem(v);
 while (n--) e[n] = gcp(g, e[n], p0, t0); }

static ai_inline void evac_str(struct ai*g, word const*const p0, word const*const t0) {
 g->cp += b2w(sizeof(struct ai_str) + str(g->cp)->len); }

static ai_inline void evac_big(struct ai*g, word const*const p0, word const*const t0) {
 g->cp += b2w(ai_big_bytes((struct ai_big*) g->cp)); }

static ai_inline void evac_sym(struct ai*g, word const*const p0, word const*const t0) {
 g->cp += Width(struct ai_atom); }              // uniform 3 words; copy_sym forwarded the nom

static ai_inline void evac_text(struct ai *g, word const *const p0, word const*const t0) {
  // terminator payloads point into the new pool (the copied object's home);
  // a stray 2-byte-aligned external content word is rejected by the range
  word const *lo = ptr(g), *hi = ptr(g) + g->len;
  for (g->cp += 1; !tagp(g->cp[-1], lo, hi); g->cp[-1] = gcp(g, g->cp[-1], p0, t0), g->cp++); }

static ai_inline void evac_data(struct ai *g, word const *const p0, word const*const t0) {
  switch (typ(g->cp)) {
   default: __builtin_trap();
   case KVec: return evac_vec(g, p0, t0);
   case KSym: return evac_sym(g, p0, t0);
   case KTwo: return evac_two(g, p0, t0);
   case KString: return evac_str(g, p0, t0);
   case KBig: return evac_big(g, p0, t0); } }

// THE WEAK INTERN TABLE. the cheney phase never traces it (the map alone
// keeps no atom alive); after the fixpoint, symbols_rebuild walks the OLD
// from-space table -- still ours to read -- and inserts only the entries
// whose atoms were forwarded into a fresh same-cap backing in to-space (the
// copied atom carries its forwarded name; survivors <= len < 3/4 cap, so
// everything fits with no growth). a dead atom's entry simply never crosses:
// dead spellings vanish, the same weak interning the rebuilt map gave for
// free. bump-bounded: from-space held a table of the same size.
static ai_noinline word symbols_rebuild(struct ai *h, struct ai *g) {
 word om = g->symbols;
 if (!om) return 0;
 uintptr_t cap = map_cap(om), mask = cap - 1, n = 0;
 union u *b = map_fill_back(bump(h, 4 + 2 * cap), cap), *hd = bump(h, 3);
 hd[0].ap = lvm_map_lookup, hd[1].x = (word) b, tagtext(hd, 2);
 word *os = map_slots(om), *ns = &b[3].x;
 word const *lo = ptr(h), *hi = ptr(h) + h->len;
 for (uintptr_t j = 0; j < cap; j++) {
  word k = os[2 * j];
  if (k == map_gap) continue;
  word fwd = cell(os[2 * j + 1])->x;            // the atom's first word: its forward, if it survived
  if (!(lamp(fwd) && lo <= ptr(fwd) && ptr(fwd) < hi)) continue;
  word nk = word(sym(fwd)->nom);                // the copied atom carries the forwarded name
  uintptr_t i = hash(h, nk) & mask;
  while (ns[2 * i] != map_gap) i = (i + 1) & mask;
  ns[2 * i] = nk, ns[2 * i + 1] = fwd, n++; }
 b[1].x = putcharm(n);
 return (word) hd; }

static ai_inline void run_finalizers(struct ai*g) {
 struct ai_fz *new_fz = NULL;
 for (struct ai_fz *fz = g->fz; fz; fz = fz->next) {
  word fwd = fz->p->x;
  if (lamp(fwd) && ptr(g) <= ptr(fwd) && ptr(fwd) < ptr(g) + g->len) {
   struct ai_fz *nn = bump(g, Width(struct ai_fz));
   nn->p = cell(fwd), nn->fn = fz->fn, nn->next = new_fz, new_fz = nn;
  } else fz->fn(fz->p); }
 g->fz = new_fz; }

static ai_noinline struct ai *gcg(struct ai*h, struct ai *p1, uintptr_t len1, struct ai *g) {
 memcpy(h, g, sizeof(struct ai));
 h->pool = (void*) p1;
 h->len = len1;
 uintptr_t const len0 = g->len;
 word const *p0 = ptr(g),
            *t0 = ptr(g) + len0, // source top
            *sp0 = g->sp;
 word sh = t0 - sp0; // stack height
 h->sp = ptr(h) + len1 - sh;
 // () IS the core, and it FLOPS with the dust: the old core sits at the from-space
 // base (p0), so leave a forwarding pointer in its first word -> the new core (h).
 // Every stored () then forwards through the normal gcp (h is in to-space), no
 // per-pointer check -- there is only ONE core, so the existing evacuation carries it.
 ((union u*) g)->ap = (lvm_t*) h;
 h->hp = h->cp = h->end;
 h->ip = cell(gcp(h, word(h->ip), p0, t0));
 h->tasks = cell(gcp(h, word(h->tasks), p0, t0));
 h->symbols = 0;                               // the WEAK intern map: rebuilt below, after the fixpoint
 for (word i = 0; i < h->end - &h->v0; i++) (&h->v0)[i] = gcp(h, (&h->v0)[i], p0, t0);               // core live variables (incl. the pre-interned *_sym book keys)
 for (word n = 0; n < sh; n++) h->sp[n] = gcp(h, sp0[n], p0, t0);                     // stack
 for (struct ai_r *s = h->root; s; s = s->n) *s->x = gcp(h, *s->x, p0, t0); // C live variables
 while (h->cp < h->hp) (datp(h->cp) ? evac_data : evac_text)(h, p0, t0);              // cheney algorithm
 // the weak intern table: rebuilt ONLY NOW, past the sound window, so the
 // cheney loop never traces it (an early copy would sit in [cp, hp) and get
 // walked -- resurrecting every atom). run_finalizers bumps after the
 // fixpoint the same way.
 h->symbols = symbols_rebuild(h, g);
 run_finalizers(h);
#ifdef AI_STAT
 if (h->len > h->max_len) h->max_len = h->len;                                       // instrumentation: peak pool len
 { uintptr_t heap = h->hp - h->end; if (heap > h->max_heap) h->max_heap = heap; }    // peak live (compacted) heap
#endif
 return h; }


ai_noinline struct ai *ai_please(struct ai *g, uintptr_t req0) {
 uintptr_t const
  t0 = g->t0, // end of last gc period
  t1 = ai_clock(), // end of current non-gc period
  len0 = g->len;
 // find alternate pool
 struct ai *h = off_pool(g);
 g = gcg(h, g->pool, g->len, g);
#ifdef AI_STAT
 g->n_gc += 1; // instrumentation: count one gc cycle per please
#endif
 uintptr_t const
  v_lo = 4,
  v_hi = v_lo * v_lo,
  used = len0 - avail(g),                        // live set after this compaction (heap + stack)
  // HEADROOM is mandatory, not just the immediate request. Each collection
  // rebuilds the weak intern table fresh in the free sliver between hp and sp
  // (symbols_rebuild). If the pool is sized to barely fit `req0 + used` it runs
  // at ~100% load: that sliver shrinks to a couple of words, and a live stack
  // root can come to alias the rebuilt backing -- the next collection then
  // forwards through that root and stamps a forwarding pointer over the
  // backing's cap field (garbage cap -> bump trap). Keeping >= 1/4 of the live
  // set free holds the table clear of the roots. (See test/jit two-file load:
  // 197 nifs fit, 198 tipped boot to the 2-word sliver and SIGILL'd.)
  req = req0 + used + (used >> 2),
  t2 = ai_clock();
 uintptr_t
  len1 = len0,
  v = t2 == t1 ? v_hi : (t2 - t0) / (t2 - t1);
 if (len1 < req || v < v_lo) // if too small
  do len1 <<= 1, v <<= 1; // then grow
  while (len1 < req || v < v_lo);
 else if (len1 > 2 * req && v > v_hi) // else if too big
  do len1 >>= 1, v >>= 1; // then shrink
  while (len1 > 2 * req && v > v_hi);
 else return g->t0 = t2, g; // else right size -> all done
 return // allocate a new pool with target size
  !(h = g->alloc(g, NULL, len1 * 2 * sizeof(word))) ? // if malloc fails but pool is big enough
   (g->scare_a = g->scare_b = nil, // oom is the bare scare: clear any stale stash
    encode(g, req <= len0 ? ai_status_ok : ai_status_scare)) : // we can still report success
  (h = gcg(h, h, len1, g),
   g->alloc(g, g->pool, 0),
   h->t0 = ai_clock(),
   h); }

static ai_inline word copy_two(struct ai*g, struct ai_pair *src, word const *const p0, word const *const t0) {
 struct ai_pair *dst = bump(g, Width(struct ai_pair));
 ini_two(dst, src->a, src->b);
 src->ap = (lvm_t*) dst;
 return word(dst); }

static ai_inline word copy_vec(struct ai*g, struct ai_vec *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = ai_vec_bytes(src);
 struct ai_vec *dst = bump(g, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

static ai_inline word copy_str(struct ai*g, struct ai_str *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = sizeof(struct ai_str) + src->len;
 struct ai_str *dst = bump(g, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

// Bignums are flat (raw limbs, no embedded l pointers), so they copy by a
// single memcpy and evac by advancing past their bytes -- exactly like strings.
static ai_inline word copy_big(struct ai*g, struct ai_big *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = ai_big_bytes(src);
 struct ai_big *dst = bump(g, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

// atoms copy like any object (the nom string forwards normally); interning
// maintenance moved WHOLLY to the post-fixpoint table sweep (symbols_sweep).
static ai_inline word copy_sym(struct ai*g, struct ai_atom *src, word const *const p0, word const*const t0) {
 struct ai_atom *dst = bump(g, Width(struct ai_atom));
 if (!src->nom) ini_missing(dst, src->code);      // a mint: the serial rides
 else ini_sym(dst, (struct ai_str*) gcp(g, word(src->nom), p0, t0), src->code);
 return word(src->ap = (lvm_t*) dst); }

static ai_inline word copy_data(struct ai *g, union u *src, word const *const p0, word const *const t0) {
 switch (typ(src)) {
  default: __builtin_trap();
  case KTwo: return copy_two(g, two(src), p0, t0);
  case KVec: return copy_vec(g, vec(src), p0, t0);
  case KSym: return copy_sym(g, sym(src), p0, t0);
  case KString: return copy_str(g, str(src), p0, t0);
  case KBig: return copy_big(g, (struct ai_big*) src, p0, t0); } }

static ai_inline struct ai_tag *ttag2(union u *k, word const *const lo, word const *const hi) {
 while (!tagp(k->x, lo, hi)) k++;
 return (struct ai_tag*) k; }

static ai_inline word copy_text(struct ai *g, union u *src, word const *const p0, word const *const t0) {
 // it's a text, find the end to find the head
 struct ai_tag *t = ttag2(src, p0, t0);
 union u *ini = tag_head(t), *d = bump(g, t->end - ini), *dst = d;
 // copy each content word to dest and leave a forwarding pointer behind,
 // stopping at the terminator; then rewrite it as the new tagged head
 for (union u *s = ini; !tagp(s->x, p0, t0); s->x = (word) d, d++, s++) d->x = s->x;
 return (word) (tagtext(dst, d - dst) + (src - ini)); }

static ai_noinline intptr_t gcp(struct ai *g, word x, word const *p0, word const *t0) {
 // if it's a number or it's outside managed memory then return it
 if (charmp(x) || ptr(x) < p0 || ptr(x) >= t0) return x;
 union u *src = cell(x);
 x = src->x; // get its contents
 // if it contains a pointer to the new space then return the pointer
 return lamp(x) && ptr(g) <= ptr(x) && ptr(x) < ptr(g) + g->len ? x :
        in_data((void*) x) ? copy_data(g, src, p0, t0) :
                                copy_text(g, src, p0, t0); }

// ============================================================================
// ev
// ============================================================================
static ai_inline struct ai *pushl(struct ai*g) { return intern(ai_strof(g, "\\")); }
static struct ai *c0(struct ai *g, lvm_t *y);
static struct ai *ai_eval(struct ai *g);
static struct ai_atom *sym_probe(struct ai *g, char const *nm, uintptr_t n);

// function state using this type
struct env {
 struct env *par; // enclosing scope
 word args, imps, // positional and closure variables
  stack, // computed arguments and let bindings on stack
  lams, // lambdas defined in a local let form
  len,  // text length accumulator
  branches, // stack for conditional alternate branch addresses
  exits,
  sites, // recursive-fn ref backpatch: list of (lams-entry . operand-cell)
  src,  // a lambda's source \-expr, stashed at the text head for printing (nil = none)
  end[]; }; // stach for conditional exit addresses

typedef Ana(ana);
typedef Cata(cata);
static ana analyze, ana_d, ana_c, ana_l, ana_q, ana_ap;
static Ana(ana_2, word, word);
static cata c1_i, c1_ix, c1_var, c1_yield, c1_ret, c1, c1_recv;
static ai_inline Cata(pull) { return ai_ok(g) ? ((cata*) pop1(g))(g, c) : g; }

// generic instruction ana aps
static ai_inline struct ai *c0_ix(struct ai *g, struct env **c, lvm_t *i, word x) {
 return incl(*c, 2), ai_push(g, 3, c1_ix, i, x); }

static ai_inline struct ai *c0_i(struct ai *g, struct env **c, lvm_t *i) {
 return incl(*c, 1), ai_push(g, 2, c1_i, i); }

static struct ai *enscope(struct ai *g, struct env *par, word args, word imps) {
 uintptr_t const n = Width(struct env) + Width(struct ai_tag);
 g = ai_push(g, 3, args, imps, par);
 if (ai_ok(g = ai_have(g, n))) {
  struct env *c = bump(g, n);
  c->stack = c->branches = c->exits = c->lams = c->len = c->sites = c->src = nil;
  c->args = g->sp[0], c->imps = g->sp[1], c->par = (struct env*) g->sp[2];
  *(g->sp += 2) = (word) tagtext((union u*)c, Width(struct env)); }
 return g; }

static word memq(struct ai *g, word l, word k) {
 for (; twop(l); l = B(l)) if (eql(g, k, A(l))) return l;
 return 0; }

static word assq(struct ai *g, word l, word k) {
 for (; twop(l); l = B(l)) if (eql(g, k, AA(l))) return A(l);
 return 0; }

static struct ai *append(struct ai *g) {
 uintptr_t i = 0;
 for (word l; ai_ok(g) && twop(g->sp[0]); i++)
  l = B(g->sp[0]),
  g->sp[0] = A(g->sp[0]),
  g = ai_push(g, 1, l);
 if (!ai_ok(g)) return g;
 if (i == 0) return g->sp++, g;
 for (g->sp[0] = g->sp[i + 1]; i--; g = gxr(g));
 if (ai_ok(g)) g->sp[1] = g->sp[0], g->sp++;
 return g; }

// don't inline this so callers can tail call optimize
static ai_noinline struct ai *c0(struct ai *g, lvm_t *y) {
 // the operator factor pass: c0 delegates the sigil surface -> core source
 // rewrite to the l `opfix` prepass (prel.l) -- evaluated like a macro,
 // once that global exists (i.e. for everything after its own definition
 // partway through the prel) -- so both compilers see factored forms.
 // A pair whose head is already a top (a non-data heap value -- C lamp is
 // just the heap test) is a constructed direct application ((f 'x) calls
 // built by this hook, boxfix's, or ana_2's -- never readable source):
 // skipped, which also terminates the recursion through ai_eval.
 { word x0 = g->sp[0];
   if (twop(x0) && (!lamp(A(x0)) || datp(A(x0)))) {
    struct ai_atom *os = sym_probe(ai_core_of(g), "opfix", 5);
    word of = os ? ai_mapget(ai_core_of(g), 0, word(os), ai_core_of(g)->book) : 0;
    if (of && lamp(of)) {
     g = ai_eval(gxr(gxl(gxl(pushq(gxl(ai_push(g, 4, x0, nil, nil, of)))))));
     if (!ai_ok(g)) return g;
     g->sp[1] = g->sp[0], g->sp += 1; } } }
 if (!ai_ok(g = enscope(g, (struct env*) nil, nil, nil))) return g;
 struct env *c = (void*) ptr(pop1(g));
 word x = g->sp[0];
 g->sp[0] = (word) c1_yield;
 mm(g, &c); mm(g, &x);
 if (ai_ok(g = analyze(g, &c, x)))
   g = c1(c0_ix(g, &c, y, word(g->ip)), &c);
 um(g), um(g);
 return g; }

static Cata(c1) {
 uintptr_t l = getcharm((*c)->len);
 // a lambda carries its source \-expr: reserve one extra leading word for it so
 // it sits at value[-1] (the printer's discriminator) and rides inside the text
 // span (head = src word) for free GC tracing. top-level/aux texts have no src.
 uintptr_t extra = nilp((*c)->src) ? 0 : 1;
 g = ai_have(g, l + extra + Width(struct ai_tag));
 if (ai_ok(g)) {
  union u *k = bump(g, l + extra + Width(struct ai_tag));
  memset(k, -1, (l + extra) * sizeof(word));
  Kp = tagtext(k, l + extra) + l + extra;
  if (ai_ok(g = pull(g, c))) {           // pull emits l words (may GC); Kp now = entry
   // read src AFTER all allocation: ai_have/pull can GC and relocate the env's src.
   if (extra) Kp[-1].x = (*c)->src,     // value[-1] = source \-expr
              clip(g, Kp - 1);          // tag head spans [src .. body]; value stays Kp
   else clip(g, Kp); } }
 return g; }

static Cata(c1_yield) { return g; }

static Cata(c1_cond_pop_exit) { return
 (*c)->exits = B((*c)->exits), // pops cond expression exit address off env stack exits
 pull(g, c); }

static Cata(c1_apn) {
 word arity = pop1(g);
 if (arity == putcharm(1)) {
  if (Kp[0].ap == lvm_ret) Kp[0].ap = lvm_tap;
  else Kp -= 1, Kp[0].ap = lvm_ap; }
 else {
  if (Kp[0].ap == lvm_ret) Kp -= 1, Kp[0].ap = lvm_tapn, Kp[1].x = arity;
  else Kp -= 2, Kp[0].ap = lvm_apn, Kp[1].x = arity; }
 return pull(g, c); }


static Cata(c1_i) {
 lvm_t *i = (void*) pop1(g);
 Kp -= 1;
 Kp[0].ap = i;
 return pull(g, c); }

static Cata(c1_ix) {
 lvm_t *i = (void*) pop1(g);
 word x = pop1(g);
 Kp -= 2;
 Kp[0].ap = i;
 Kp[1].x = x;
 return pull(g, c); }

// Emit a recursive-function ref: bake `quote AB(y)` if the closure is final, else
// `quote nil` + stash the operand cell in the site for ana_d to backpatch.
static Cata(c1_recv) {
 word y = pop1(g), site = pop1(g);
 Kp -= 2;
 Kp[0].ap = lvm_quote;
 if (nilp(site)) Kp[1].x = AB(y);
 else Kp[1].x = nil, B(site) = (word) &Kp[1];
 return pull(g, c); }

static Cata(c1_ar, lvm_t *i, word ar) { return
 Kp -= 2,
 Kp[0].ap = i,
 Kp[1].x = putcharm(ar),
 pull(g, c); }

static Cata(c1_cur) {
 struct env *e = (void*) pop1(g);
 uintptr_t ar = llen(e->args) + llen(e->imps);
 return ar == 1 ? pull(g, c) : c1_ar(g, c, lvm_cur, ar); }

static Cata(c1_ret) {
 struct env *e = (struct env*) pop1(g);
 uintptr_t ar = llen(e->args) + llen(e->imps);
 return c1_ar(g, c, lvm_ret, ar); }

cata1(c1_cond_push_branch, g = gxl(ai_push(g, 2, Kp, (*c)->branches)), (*c)->branches = ai_ok(g) ? pop1(g) : nil)
cata1(c1_cond_push_exit, g = gxl(ai_push(g, 2, Kp, (*c)->exits)), (*c)->exits = ai_ok(g) ? pop1(g) : nil)
cata1(c1_cond_pop_branch, Kp -= 2, Kp[0].ap = lvm_cond, Kp[1].x = A((*c)->branches), (*c)->branches = B((*c)->branches))

static Cata(c1_cond_exit) {
 union u *a = cell(A((*c)->exits));
 if (a->ap == lvm_ret || a->ap == lvm_tap)
  Kp = memcpy(Kp - 2, a, 2 * sizeof(*Kp));
 else if (a->ap == lvm_tapn)
  Kp = memcpy(Kp - 3, a, 3 * sizeof(*Kp));
 else
  Kp -= 2, Kp[0].ap = lvm_jump, Kp[1].x = (word) a;
 return pull(g, c); }

static lvm(_lvm_yieldk) { return
 Ip = Ip[1].m,
 Pack(g),
 encode(g, ai_status_yield); }


#if __STDC_HOSTED__
#include <signal.h>
#include <setjmp.h>
// THE FAULT BARRIER infra -- shared by ai_eval (below) and call (lvm_call). A hardware
// fault (SIGSEGV/SIGILL/SIGBUS/SIGFPE) inside an armed region siglongjmps to the
// innermost barrier and becomes a survivable love condition; outside any barrier the
// default handler runs, so a genuine crash stays a crash. Host-only: the kernel has no
// signal layer (its fault vectors are a separate hookup). ai_fault_jb is always the
// INNERMOST barrier (each entry saves/restores it), so a fault in a native (call) body
// recovers there (-> 0) while a fault in plain eval recovers at the ai_eval barrier.
static sigjmp_buf ai_fault_jb;
static volatile sig_atomic_t ai_fault_depth;   // nesting depth of active barriers (the handler gate)
static void ai_fault_sig(int s) {
 if (ai_fault_depth) siglongjmp(ai_fault_jb, s);
 signal(s, SIG_DFL), raise(s); }
static void ai_fault_arm(void) {
 static int armed; if (armed) return; armed = 1;
 struct sigaction sa; memset(&sa, 0, sizeof sa);
 sa.sa_handler = ai_fault_sig; sigemptyset(&sa.sa_mask); sa.sa_flags = SA_NODEFER;
 sigaction(SIGSEGV, &sa, 0); sigaction(SIGILL, &sa, 0);
 sigaction(SIGBUS, &sa, 0); sigaction(SIGFPE, &sa, 0); }
#if ai_tco
static volatile sig_atomic_t ai_eval_armed;          // an outermost ai_eval barrier is already up
static struct ai *ai_eval_fault_raise(struct ai *c, int sig);   // recovery, defined just after ai_raise
#endif
#endif

static struct ai *ai_eval(struct ai *g) {
 g = c0(g, _lvm_yieldk);
#if __STDC_HOSTED__ && ai_tco
 // The barrier wraps the VM RUN of the OUTERMOST eval: a fault anywhere below (a bad
 // native call, a null deref, an ill-formed op) unwinds here -- the task BURNT. If it has
 // a runnable peer (the repl evaluates each line in a spawned task while its poll loop
 // stays runnable), toss the burnt task -- unlink it from the ring -- and serve the
 // survivors: resume a peer under the same barrier. done? reads an absent pid as done, so
 // the poll then carries on, ^C and cooperative scheduling intact. With no runnable peer
 // (file mode, the lone task) the stack resets to the eval boundary and the fault
 // re-raises as a catchable (scare 'fault sig) through `help` -- transparent, up through
 // object-array ops, spin, and (ev ..). Nested evals run inside this one barrier
 // (ai_eval_armed); compilation (c0, above) is outside it.
 if (!ai_ok(g)) return g;
 if (ai_eval_armed) return g->ip->ap(g, g->ip, g->hp, g->sp);
 ai_fault_arm();
 struct ai *volatile vg = g; word *volatile esp = g->sp;   // entry g/sp, volatile across sigsetjmp
 sigjmp_buf prev; memcpy(&prev, &ai_fault_jb, sizeof prev);
 ai_eval_armed = 1, ai_fault_depth++;
 for (;;) {
  int fsig = sigsetjmp(ai_fault_jb, 1);
  struct ai *c = (struct ai *) vg;
  if (fsig == 0) {
   struct ai *r = c->ip->ap(c, c->ip, c->hp, c->sp);
   ai_fault_depth--, ai_eval_armed = 0, memcpy(&ai_fault_jb, &prev, sizeof prev);
   return r; }
  // BURNT (fsig = the signal). Find any LIVE peer to serve next -- not just an already-
  // runnable one (find_runnable's wake_at/wait_fd test is for normal scheduling; for
  // RECOVERY the goal is to survive, and a resumed peer re-checks its own wait/sleep
  // conditions, e.g. the repl task re-parks on stdin). The lone task -> no peer -> scare.
  union u *dead = c->tasks, *next = 0;
  for (union u *n = dead->m; n != dead; n = n->m)
   if (n[1].m->ap != lvm_task_exit) { next = n; break; }
  if (next) {                                              // serve the survivors
   union u *p = next; while (p->m != dead) p = p->m;
   p->m = dead->m;                                         // toss the burnt task: unlink from the ring
   union u *ns = next + 5, *end = (union u*) ttag(c, ns);
   uintptr_t rh = end - ns;
   c->tasks = next;
   c->sp = memmove(topof(c) - rh, ns, rh * sizeof(word));  // restore the peer's stack + ip, resume
   c->ip = next[1].m;
   continue; }
  ai_fault_depth--, ai_eval_armed = 0, memcpy(&ai_fault_jb, &prev, sizeof prev);
  c->sp = esp;                                             // lone task: reset + raise (scare 'fault sig)
  return ai_eval_fault_raise(c, fsig); }
#elif ai_tco
 if (ai_ok(g)) g = g->ip->ap(g, g->ip, g->hp, g->sp);
 return g;
#else
 while (ai_ok(g)) g = g->ip->ap(g);
 if (ai_code_of(g) == ai_status_eof) g = ai_core_of(g);
 return g;
#endif
}

static word lidx(struct ai*g, word x, word l) {
 word i = 0;
 for (; twop(l); i++, l = B(l)) if (eql(g, x, A(l))) return i;
 return -1; }

static Ana(ana_v) {
 word y;
 if (!ai_ok(g)) return g;
 for (struct env *d = *c;; d = d->par) {
  if (nilp(d)) {
   if ((y = ai_mapget(g, 0, x, g->book))) return ana_q(g, c, y);
   // undefined global: resolved by lvm_index via the book at run time.
   // Only record it as a captured free variable when this scope is nested
   // (cf. ev.l avb: `(? (get 0 'par c) (push 'imp x))`). At top level there
   // is no enclosing frame to capture from, so adding x to imps would make a
   // second reference resolve via memq(imps) to an uninitialized arg slot.
   // re-read x from the imps cons: the gxl/ai_push above can GC and relocate
   // the symbol, leaving the local x dangling (cf. the same A((*c)->imps)
   // pattern in the capture path below). c0_ix then emits the live pointer.
   if (!nilp((*c)->par))
    g = gxl(ai_push(g, 2, x, (*c)->imps)),
    x = ai_ok(g) ? A((*c)->imps = pop1(g)) : nil;
   return c0_ix(g, c, lvm_index, x); }
  // lambda definition of local let form?
  if ((y = assq(g, d->lams, x))) {
   // recursive-fn ref: record a backpatch site on d (the lams-owning scope) when
   // the closure isn't built yet, then apply the captured imports.
   word site = nil;
   if (nilp(AB(y))) {
    mm(g, &d), mm(g, &y);
    g = gxl(ai_push(g, 2, y, nil)); // site = (y . nil)
    if (ai_ok(g)) {
     g = gxl(ai_push(g, 2, g->sp[0], d->sites)); // (site . d->sites)
     if (ai_ok(g)) d->sites = pop1(g), site = pop1(g); }
    um(g), um(g); }
   incl(*c, 2);
   if (ai_ok(g = ai_push(g, 3, c1_recv, y, site)))
    g = ana_ap(g, c, BB(g->sp[1]));
   return g; }
  // let binding in the *current* scope -> a direct stack slot.
  if (d == *c && memq(g, d->stack, x)) return
    c0_ix(g, c, lvm_arg, putcharm(lidx(g, x, d->stack)));
  // a let binding, closure var, or lambda arg -- possibly from an enclosing
  // scope. If enclosing, import it into this scope's free-variable (imps) list
  // so the offset c1_var emits is valid in *this* frame, not the defining one;
  // otherwise a captured let binding aliases whatever sits at the same offset
  // in the closure's frame (see the boot.l compiler's ava fix, commit 8e3acf0).
  if (memq(g, d->stack, x) || memq(g, d->imps, x) || memq(g, d->args, x)) {
   incl(*c, 2);
   if (d != *c) // found in an enclosing scope -> import (capture) it
    g = gxl(ai_push(g, 2, x, (*c)->imps)),
    x = ai_ok(g) ? A((*c)->imps = pop1(g)) : nil;
   return ai_push(g, 3, c1_var, x, (*c)->stack); } } }


static Cata(c1_var) {
 word v = pop1(g), i = llen(pop1(g)); // stack inset
 for (word l = (*c)->imps; !nilp(l); l = B(l), i++)
  if (eql(g, v, A(l))) goto out;
 for (word l = (*c)->args; !nilp(l); l = B(l), i++)
  if (eql(g, v, A(l))) break;
out:
 return Kp -= 2,
        Kp[0].ap = lvm_arg,
        Kp[1].x = putcharm(i),
        pull(g, c); }

static ai_noinline Ana(analyze) {
 if (x == (word) ai_core_of(g)) return c0_i(g, c, lvm_zp); // () = the core: a runtime fetch (it flops; never bake/var-lookup it)
 if (symp(x)) return ana_v(g, c, x); // lookup symbol as variable
 if (!twop(x)) return ana_q(g, c, x); // non-pairs are self quoting
 word a = A(x), b = B(x);                        // it must be a pair
 if (!twop(b)) return analyze(g, c, a); // singleton list has value of element
 // if it is a special form then do that
 if (symp(a) && a != (word) ai_core_of(g) && sym(a)->nom && len(sym(a)->nom) == 1)  // the core heads no special form (its nom slot is live VM state)
  switch (*txt(sym(a)->nom)) {
   case '\\': return ana_l(g, c, b);
   case ':': return ana_d(g, c, b);
   case '?': return ana_c(g, c, b); }
 return ana_2(g, c, x, a, b); }


static struct ai *c0_lambda(struct ai *g, struct env **c, intptr_t imps, intptr_t exp) {
 union u *k, *ip;
 word ops = exp;             // the full operand list (params… body) for the stored src
 struct env *d = NULL;
 mm(g, &d); mm(g, &exp); mm(g, &ops);
 g = enscope(g, *c, exp, imps);

 if (ai_ok(g)) {
  d = (struct env*) pop1(g);
  exp = d->args;
  int n = 0; // push exp args onto stack
  for (; twop(B(exp)); exp = B(exp), n++) g = ai_push(g, 1, A(exp));
  for (g = push0(g); n--; g = gxr(g));
  exp = A(exp); }

 if (ai_ok(g)) {
  d->args = g->sp[0];
  g->sp[0] = (word) c1_yield;
  incl(d, 4);
  g = ai_push(g, 2, c1_cur, d);
  g = analyze(g, &d, exp);
  // stash the source \-expr for the printer (ioput_fn), built AFTER analyze so the
  // captured imports (d->imps) are known. ops is (params… body); prepend the
  // imports as leading params (the frame layout is [imps, args]) so a closure
  // prints as `(\ imps… params… body)` applied to its captures and round-trips.
  if (ai_ok(g)) {
   word l = d->imps; int ni = 0;
   mm(g, &l);
   for (; twop(l); l = B(l), ni++) g = ai_push(g, 1, A(l));  // push imp1..impN
   um(g);
   g = ai_push(g, 1, ops);                                   // tail = (params… body)
   while (ni-- > 0) g = gxr(g);                             // fold: imps ++ ops
   g = gxl(pushl(g));                                       // cons '\ onto the front
   if (ai_ok(g)) d->src = pop1(g); }
  if (ai_ok(g = ai_push(g, 2, c1_ret, d)))
    ip = g->ip,
    avec(g, ip, g = c1(g, &d)); }

 if (ai_ok(g)) k = g->ip, g->ip = ip, g = gxl(ai_push(g, 2, k, d->imps));

 return um(g), um(g), um(g), g; }

static Ana(c0_cond_exit) { return
 incl(*c, 3),
 ai_push(analyze(g, c, x), 1, c1_cond_exit); }

static Ana(c0_cond_r) { return
 !twop(x) ? c0_cond_exit(g, c, nil) :
 !twop(B(x)) ? c0_cond_exit(g, c, A(x)) :
 (avec(g, x,
  incl(*c, 2),
  g = analyze(g, c, A(x)),
  g = ai_push(g, 1, c1_cond_pop_branch),
  g = c0_cond_exit(g, c, AB(x)),
  g = ai_push(g, 1, c1_cond_push_branch),
  g = c0_cond_r(g, c, BB(x))), g); }


static struct ai *ana_ap_r2l(struct ai *g, struct env **c, word x);
static struct ai *ana_ap(struct ai *g, struct env **c, intptr_t x) {
 if (!ai_ok(g)) return g;
 bool imfp =
  g->sp[0] == (word) c1_ix &&
  g->sp[1] == (word) lvm_quote &&
  lamp(g->sp[2]);
 intptr_t
  ca = llen(x),
  va =
   imfp && cell(g->sp[2])->ap == lvm_cur ?
    getcharm(cell(g->sp[2])[1].x) :
    1;
 bool b1p = ca == 1 && imfp && cell(g->sp[2])[1].ap == lvm_ret0,
      anp = va == ca && ca > 1,
      bnp = anp && cell(g->sp[2])[3].ap == lvm_ret0;

 if (b1p) { // inline an instruction
  lvm_t *i = cell(g->sp[2])->ap;
  g->sp += 3;
  g = c0_i(analyze(g, c, A(x)), c, i);
  return g; }

 if (bnp) { // inline a curried instruction
  lvm_t *i = cell(g->sp[2])[2].ap;
  g->sp += 3;
  g = c0_i(ana_ap_r2l(g, c, x), c, i); // r2l arg eval
  if (ai_ok(g)) while (ca--) (*c)->stack = B((*c)->stack);
  return g; }

 if (ai_ok(g = gxl(ai_push(g, 3, nil, (*c)->stack, x)))) {
  (*c)->stack = pop1(g), x = pop1(g), mm(g, &x);
  if (anp) { // r2l 1 n-ary ap
   g = ana_ap_r2l(g, c, x),
   incl(*c, 2),
   g = ai_push(g, 2, c1_apn, putcharm(ca));
   if (ai_ok(g)) while (ca--) (*c)->stack = B((*c)->stack); }
  else while (twop(x)) // l2r n 1-ary ap
   g = analyze(g, c, A(x)),
   incl(*c, 2),
   g = ai_push(g, 2, c1_apn, putcharm(1)),
   x = B(x);
  um(g), (*c)->stack = B((*c)->stack); }

 return g; }


static struct ai *ana_ap_r2l(struct ai *g, struct env **c, word x) {
 if (twop(x)) {
  word y = A(x);
  avec(g, y, g = ana_ap_r2l(g, c, B(x)));
  g = analyze(g, c, y);
  g = gxl(ai_push(g, 2, nil, (*c)->stack));
  if (ai_ok(g)) (*c)->stack = pop1(g); }
 return g; }

static ai_inline bool lambp(struct ai *g, word x) {
 struct ai_str *n;
 return twop(x) && symp(A(x)) && A(x) != (word) ai_core_of(g) && twop(B(x)) && twop(B(B(x))) &&
  (n = sym(A(x))->nom) && len(n) == 1 && txt(n)[0] == '\\'; }

static ai_inline word rev(word l) {
 word m, n = nil;
 while (twop(l)) m = l, l = B(l), B(m) = n, n = m;
 return n; }

static word ldels(struct ai *g, word lam, word l);

static ai_inline Ana(ana_2, word a, word b) {
 if ((x = ai_mapget(g, 0, a, ai_mapget(g, nil, nil, ai_core_of(g)->book))))   // macro table = book[nil]
  return g = ai_eval(gxr(gxl(gxl(pushq(gxl(ai_push(g, 4, b, nil, nil, x))))))),
         analyze(g, c, ai_ok(g) ? pop1(g) : 0);
 return avec(g, b, g = analyze(g, c, a)),
        ana_ap(g, c, b); }

static ai_inline Ana(ana_q) { return c0_ix(g, c, lvm_quote, x); }
static ai_inline Ana(ana_l) {
  if (!twop(B(x))) return ana_q(g, c, A(x)); // one operand, no params: quote
  return g = c0_lambda(g, c, nil, x),
         analyze(g, c, ai_ok(g) ? pop1(g) : 0); }
static Ana(c0_cond_r);
static ai_inline Ana(ana_c) {
 return !twop(B(x)) ? analyze(g, c, A(x)) :
    (g = ai_push(g, 2, x, c1_cond_pop_exit),
     g = c0_cond_r(g, c, ai_ok(g) ? pop1(g) : nil),
     ai_push(g, 1, c1_cond_push_exit)); }
// this is the longest C function :(
// it handles the let special form in a way to support sequential and recursive binding.
static ai_inline struct ai *ana_d(struct ai *g, struct env **b, word exp) {
 if (!twop(B(exp))) return analyze(g, b, A(exp));
 struct ai_r *mm0 = ai_core_of(g)->root;
 mm(g, &exp);
 // recursive-value boxing: c0 is the bootstrap compiler, so it delegates the
 // letrec*-value rewrite to the l `boxfix` prepass (prel.l) -- evaluated
 // like a macro -- once that global exists (i.e. for everything after its own
 // definition partway through the prel). It indirects forward-referenced
 // bindings through nom-keyed cells -- one scope; see prel.l. The runtime compiler
 // (ev.l) runs the same pass in wev, so both lanes share one boxfix. exp is
 // rooted across the alloc.
 if (ai_ok(g = intern(ai_strof(g, "boxfix")))) {
  word bf = ai_mapget(g, 0, pop1(g), g->book);
  if (bf && lamp(bf)) {
   g = ai_eval(gxr(gxl(gxl(pushq(gxl(ai_push(g, 4, exp, nil, nil, bf)))))));
   if (ai_ok(g)) exp = pop1(g); } }
 g = enscope(g, *b, (*b)->args, (*b)->imps);
 if (!ai_ok(g)) return forget();
 struct env *q = (struct env*) pop1(g), **c = &q;
 // lots of variables :(
 word nom = nil, def = nil, lam = nil,
      v = nil, d = nil, e = nil, os = nil;
 mm(g, &nom), mm(g, &def), mm(g, &lam);
 mm(g, &d); mm(g, &e); mm(g, &v); mm(g, &q); mm(g, &os);

 // collect vars and defs into two lists.
 // While finding each bound lambda's closure (the c0_lambda below) we expose
 // the preceding bindings on the enclosing scope's stack, so a let-bound
 // lambda that refers to a sibling binding captures it as a free variable
 // instead of falling through to a same-named global (cf. ev.l l2/jj's
 // `_ (push 'stk (car n))`). The original stack is restored after the loop,
 // before any code is emitted, so the run-time frame layout is unchanged.
 os = (*b)->stack;
 while (twop(exp) && twop(B(exp))) {
  for (d = A(exp), e = AB(exp); twop(d); e = pop1(g), d = A(d)) {
   g = gxl(ai_push(g, 2, e, nil));
   g = append(gxl(pushl(ai_push(g, 1, B(d)))));
   if (!ai_ok(g)) return forget(); }
  g = gxl(ai_push(g, 2, d, nom));
  g = gxl(ai_push(g, 2, e, def));
  if (!ai_ok(g)) return forget();
  def = pop1(g), nom = pop1(g);
  // if it's a lambda compile it and record in lam list
  if (lambp(g, e)) {
   g = ai_push(g, 2, d, lam);
   g = gxl(gxr(c0_lambda(g, c, nil, B(e))));
   if (!ai_ok(g)) return forget();
   lam = pop1(g); }
  g = gxl(ai_push(g, 2, d, (*b)->stack)); // expose this binding to later siblings
  (*b)->stack = ai_ok(g) ? pop1(g) : nil;
  exp = BB(exp); }
 (*b)->stack = os; // restore: emission below rebuilds the real frame

 intptr_t l = llen(nom);
 bool oddp = twop(exp),
      globp = !oddp && nilp((*b)->args); // we check this again later to make global bindings at top level
 if (!oddp) { // if there's no body then evaluate the name of the last definition
  g = gxl(ai_push(g, 2, A(nom), nil));
  if (!ai_ok(g)) return forget();
  exp = pop1(g); }

 // find closures
 // for each function g with closure C(g)
 // for each function g with closure C(g)
 // if g in C(g) then C(g) include C(g)
 word j, vars, var;
 do for (j = 0, d = lam; twop(d); d = B(d)) // for each bound function variable
  for (e = lam; twop(e); e = B(e)) if (d != e) // for each other bound function variable
   if (memq(g, BB(A(e)), AA(d))) // if you need this function
    for (v = BB(A(d)); twop(v); v = B(v)) // then you need its variables
     if (!memq(g, vars = BB(A(e)), var = A(v))) // only add if it's not already there
      j++,
      g = gxl(ai_push(g, 2, var, vars)),
      BB(A(e)) = ai_ok(g) ? pop1(g) : nil;
 while (j);

 // now delete defined functions from the closure variable lists
 // they will be bound lazily when the function runs
 for (e = lam; twop(e); BB(A(e)) = ldels(g, lam, BB(A(e))), e = B(e));

 (*c)->lams = lam;
 g = append(gxl(pushl(ai_push(g, 2, nom, exp))));

 if (!ai_ok(g)) return forget();
 exp = pop1(g);

 //
 // all the code emissions are below here (??)
 //

 // clear each function's provisional closure so a ref hit mid-rebuild defers to a
 // backpatch site rather than baking the stale closure; keep the import sets (BB).
 for (d = lam; twop(d); d = B(d)) AB(A(d)) = nil;

 for (e = nom, v = def; twop(e); e = B(e), v = B(v))
  if (lambp(g, A(v))) {
   d = assq(g, lam, A(e));
   g = c0_lambda(g, c, BB(d), BA(v));
   if (!ai_ok(g)) return forget();
   A(v) = B(d) = pop1(g); }

 // closures final -> backpatch each recorded recursive-fn ref with its text.
 for (d = (*c)->sites; twop(d); d = B(d)) cell(B(A(d)))->x = AB(A(A(d)));
 (*c)->sites = nil;

 nom = rev(nom); // put in literal order
 g = analyze(g, b, exp);
 g = gxl(ai_push(g, 2, nil, e = (*b)->stack)); // push function stack rep
 (*b)->stack = ai_ok(g) ? pop1(g) : nil;
 for (def = rev(def); twop(nom); nom = B(nom), def = B(def))
  g = analyze(g, b, A(def)),
  g = globp ? c0_ix(g, b, lvm_defglob, A(nom)) : g,
  g = gxl(ai_push(g, 2, A(nom), (*b)->stack)),
  (*b)->stack = ai_ok(g) ? pop1(g) : nil;
 return
  (*b)->stack = e,
  incl(*b, 2),
  g = ai_push(g, 2, c1_apn, putcharm(l)),
  forget(); }

static word ldels(struct ai *g, word lam, word l) {
 if (!twop(l)) return nil;
 word m = ldels(g, lam, B(l));
 if (!assq(g, lam, A(l))) B(l) = m, m = l;
 return m; }

lvm(lvm_defglob) {
 Have(3);
 Sp -= 3;
 word k = Ip[1].x, v = Sp[3];
 return Sp[0] = k, Sp[1] = v, Sp[2] = g->book, Pack(g),
  !ai_ok(g = ai_mapput(g)) ? ghelp(g) : (Unpack(g), Sp += 1, Ip += 2, Continue()); }

// lvm_index (the late-bound global read) is defined below lvm_scare: its
// miss path is the missing condition and borrows the whole help apparatus.

lvm(lvm_eval) { return Ip++, Pack(g),
 !ai_ok(g = c0(g, lvm_jump)) ? ghelp(g) : (Unpack(g), Continue()); }

ai_noinline struct ai *ai_evals_(struct ai*g, char const*s) {
 static char const *t = "((:(e a b)(? b(e(ev 'ev(cap b))(cup b))a)e)0)";
 struct ti i = {{lvm_port_io, putcharm(-1), putcharm(EOF), putcharm(false)}, t, 0};
 g = push0(pushq(push0(ai_eval(ai_reads(g, (void*) &i)))));
 i.t = s, i.i = 0, i.io.ungetc_buf = putcharm(EOF), i.io.eof_seen = putcharm(false);
 return ai_pop(ai_eval(gxr(gxl(gxr(gxl(ai_reads(g, (void*) &i)))))), 1); }

// ============================================================================
// vm
// ============================================================================
// Probe the symbol map for a C-string name, materializing the lookup with a
// phantom ai_str on the C stack -- same content hash, same walk as
// intern_checked, but never interning or allocating. A miss means the name was
// never read, so no global by that name was ever defined.
uintptr_t hash(struct ai*, intptr_t);
static struct ai_atom *sym_probe(struct ai *g, char const *nm, uintptr_t n) {
 word m = g->symbols;
 if (!m) return 0;
 uintptr_t h = mix;                            // the KString content hash, over the C bytes
 for (uintptr_t j = 0; j < n; j++) h ^= (uint8_t) nm[j], h *= mix;
 uintptr_t mask = map_cap(m) - 1, i = h & mask;
 word *s = map_slots(m);
 for (;; i = (i + 1) & mask) {
  word k = s[2 * i];
  if (k == map_gap) return 0;
  if (len(k) == n && !memcmp(txt(k), nm, n)) return sym(s[2 * i + 1]); } }

// Resolve a C->lisp ap from book (where the prel pins it -- book is
// GC-traced and egg-baked, so it survives into the runtime image), materializing
// the key by name. Scare loud if undefined: a prel-ordering contract
// violation. Probe + mapget are reads, so no Have in the tail-jump callers.
static ai_inline ai_word resolve_hot(struct ai *g, char const *nm, uintptr_t n) {
 struct ai_atom *y = sym_probe(g, nm, n);
 ai_word cur = y ? ai_mapget(g, nil, word(y), g->book) : nil;
 if (!lamp(cur)) __builtin_trap();
 return cur; }

// Thread (function) combinators for `+` and `*`, pinned on book by the prel
// like num-ap. A text operand takes precedence over every other type, so
// `+`/`*` of a function build a new function -- the README's Church arithmetic,
// agreeing with numerals: `+` is Church add ((+ g g) a x = g a (g a x)), `*` is
// composition. add is the 4-arg add lambda, mul the 3-arg compose; the C
// aps reuse numap_drive to compute the partial (add g g) / (mul g g)
// -- itself the new function -- and leave it as the result, resuming at Ip+1.

// Fixnum-as-function application. A fixnum operator n applied to x is dispatched
// to the l ap at book['num-ap] as (num-ap n x): numeric x -> x**n, a
// function x -> x iterated n times (Church numerals).
//
// The driver mirrors the pair driver: with the stack laid out [n, num-ap, x, ret]
// it applies num-ap to n (a partial), swaps so that partial becomes the operator,
// applies it to x, and ret0s the result to ret. The five apply sites divert here as
// a tail jump (no extra args -> stays a sibcall, cf. vmret): lvm_numap is the
// non-tail form (frame below Sp, resume at Ip+1), lvm_numtap the tail form (frame
// in the popped region, deliver to the caller's ret at Sp[fs+2]). The fused arg/quote
// variants first push their argument under the operator and bump Ip by one word so
// the canonical [.. x n] layout and resume/frame-size operand line up, then divert.
static lvm(numap_swap) {
 word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t;
 return Ap(lvm_ap, g); }
union u const numap_drive[] = { {lvm_ap}, {.ap = numap_swap}, {.ap = lvm_ret0} };

// ============================================================================
// the lisp help calling convention
// ============================================================================
// With a global `help` function installed, a raise becomes the call
// (help s a b): s = the status word (prel readers scare?/more?/eof?),
// a/b = the condition data -- for the more bit the port and the read sentinel,
// for a scare nil nil (oom is bare; future scares define their shapes). The
// frame runs through help_drive (numap_drive's 3-arg twin) into a per-class
// epilogue: the more bit delivers the ap's result to the raise site's resume
// text (the read protocol -- the ap chooses what the reader's caller
// sees); a scare is observed, then takes the default escape to C.
static lvm(help_ret_more) {   // [result resume port sentinel ..] -> resume sees result
 Ip = cell(Sp[1]);
 Sp[3] = Sp[0];
 Sp += 3;
 return Continue(); }
static lvm(help_ret_scare) {  // result ignored: scares are not (yet) resumable
 return Pack(g), encode(g, ai_status_scare); }
static union u const help_more_k[] = { {help_ret_more} };
static union u const help_scare_k[] = { {help_ret_scare} };
static union u const help_drive[] =
 { {lvm_ap}, {.ap = numap_swap}, {.ap = numap_swap}, {.ap = lvm_ret0} };

// Raise status s with condition data a/b to the help continuation. With a
// global `help` function -- present the way everything is present: by its
// net -- and 5 words of stack headroom (the raise path never
// allocates), build the (help s a b) frame and run it; else the C default
// raise_c, which resumes the eof protocol raw. Pre-book raises (ai_ini_0)
// always take the default.
static struct ai *ai_raise(struct ai *c, enum ai_status s, word a, word b,
                         union u const *K) {
 if (s == ai_status_scare) c->scare_a = a, c->scare_b = b; // for the exit face
 if (c->book) {
  struct ai_atom *ts = sym_probe(c, "help", 4);
  word h = ts ? ai_mapget(c, nil, word(ts), c->book) : nil;
  if (!ai_nilp(c, h) && avail(c) >= 5) {
   word *sp = c->sp -= 5;          // [s h a b K | raise site data ..]
   sp[0] = putcharm(s), sp[1] = h;
   sp[2] = a, sp[3] = b;
   sp[4] = word(K);
   c->ip = (union u*) help_drive;
#if ai_tco
   return c->ip->ap(c, c->ip, c->hp, c->sp);
#else
   return c;                       // ok-g: the trampoline dispatches help_drive
#endif
  } }
 union u *t = (union u*) raise_c;
 c->ip = t;
#if ai_tco
 return t->ap(encode(c, s), t, c->hp, c->sp);
#else
 return t->ap(encode(c, s));
#endif
}
#if __STDC_HOSTED__ && ai_tco
// The ai_eval barrier's recovery (see ai_eval): a caught hardware fault `sig` becomes a
// scare delivered to `help`, like any other condition -- (scare 'fault sig). Unlike
// 'missing, 'fault is NOT rooted in struct ai: it is a COLD tag (raised only on a real
// fault, never during oom), so we re-create it on demand -- a clean fault, the only
// recoverable kind, has the heap room to name itself. The intern runs UNDER the barrier
// (re-armed here) so a heap too damaged to name the fault can't re-crash recovery: it
// falls back to the bare scare, and the signal number still shows. A fault mid-mutation
// or mid-GC is the residual unrecoverable corner.
static struct ai *ai_eval_fault_raise(struct ai *c, int sig) {
 volatile word tag = nil; struct ai *volatile vc = c;   // volatile: survive the recovery longjmp
 sigjmp_buf prev; memcpy(&prev, &ai_fault_jb, sizeof prev);
 ai_fault_depth++;
 if (sigsetjmp(ai_fault_jb, 1) == 0) {
  struct ai *h = ai_strof((struct ai *) vc, "fault");
  if (ai_ok(h)) { h = intern(h); if (ai_ok(h)) vc = ai_core_of(h), tag = ai_pop1((struct ai *) vc); } }
 ai_fault_depth--; memcpy(&ai_fault_jb, &prev, sizeof prev);
 return ai_raise((struct ai *) vc, ai_status_scare, tag, putcharm(sig), help_scare_k); }
#endif
struct ai *ghelp2(struct ai *g, enum ai_status s) {
 struct ai *c = ai_core_of(g);
 int rd = s & ai_status_more;       // the more bit: a read-end condition --
 return ai_raise(c, s,              // [resume port sentinel] sits on the stack
  rd ? c->sp[1] : nil, rd ? c->sp[2] : nil,
  rd ? help_more_k : help_scare_k); }
// Raise on an already-tagged g: re-raise its own status.
struct ai *ghelp(struct ai *g) { return ghelp2(ai_core_of(g), ai_code_of(g)); }
// (scare a b): the deliberate raise -- the user scares, the scare bit is set
// unconditionally and the global help hears (help 1 a b). Unlike a C scare
// (oom), the raise point here is a clean boundary, so the help's result is
// delivered back as (scare a b)'s value via the more continuation -- the
// resume is this nif's own ret. With no help installed the C default
// applies and the scare is terminal.
lvm(lvm_scare) {
 Have(6);                          // [resume] + ai_raise's 5 words (a, b are the
                                   // two args, already on the stack). Under-
                                   // provisioning here lets ai_raise's avail>=5
                                   // guard fail and SILENTLY drop the help call,
                                   // so a deliberate scare can miss its handler
                                   // on a tight heap (cf. lvm_index/lvm_missing,
                                   // which Have(8) for the same reason).
 word a = Sp[0], b = Sp[1];
 *--Sp = word(Ip + 1);             // [resume a b ..]: help_more_k's layout
 return Pack(g), ai_raise(g, ai_status_scare, a, b, help_more_k); }
// the missing miss sentinel: a private static address no book value can equal,
// so a name bound to nil stays distinct from no entry at all.
static union u const no_entry[1];
// THE NOTHING IS THE CORE: () = (word) ai_core_of(g), what a helpless missing read
// answers and what () reads as. The core's head is a nameless serial-0 mint (the one
// serial never drawn), nameless, $0, falsy, applying const-1 like every unit. absence
// is a POINT, not a quantity: a number would exponentiate under a numeral ((i love) =
// 0**i is honest nan), a unit absorbs -- which is what keeps (i love you) = 1. It FLOPS
// with the dust (gcg forwards old->new core) and prints () -- the face of absence.
// No named constant; the nothing is the core. DISTINCT from 0 (fixnum) and "" (string).
// A read of the LIVE book (the outermost cell) by name -- the missing-name law
// at the global scope, the twin of boxfix's local (missing cell 'nom). A hit
// pushes the current value; a miss is a MISSING name -- a nom not in the book,
// a call for help: with a global help installed the read raises (help 1 'missing
// nom) and the help's result is the value here; helpless it reads the zero point.
// The site NEVER self-patches (it stays a live read, so a define that lands later
// is seen, a rebind is honoured) and the name is NOT a frame import.
lvm(lvm_index) {
 Have1();                          // room for the push first (may GC; no live local held yet)
 word v = ai_mapget(g, word(no_entry), Ip[1].x, g->book);
 if (v != word(no_entry)) return
  *--Sp = v,                       // present: push the live value, no quote patch
  Ip += 2,
  Continue();
 Have(8);                          // [resume a b] + ai_raise's 5 words
 struct ai_atom *ts = sym_probe(g, "help", 4);
 word h = ts ? ai_mapget(g, nil, word(ts), g->book) : nil;
 if (ai_nilp(g, h)) return
  *--Sp = (word) ai_core_of(g),
  Ip += 2,
  Continue();
 word a = word(sym_probe(g, "missing", 7)), b = Ip[1].x;   // 'missing: the nif's name, rooted by the book
 Sp -= 3;
 Sp[0] = word(Ip + 2), Sp[1] = a, Sp[2] = b;   // help_more_k's layout
 return Pack(g), ai_raise(g, ai_status_scare, a, b, help_more_k); }
// (missing t k): the book read as a value -- lvm_index's law with the book as an
// argument (a tablet is a little book; the book is just the outermost one).
// k present in map t answers the value; a miss is the MISSING CONDITION: with a
// global help installed the read raises (help 1 'missing k) and the help's result
// is the value, helpless it reads the zero point. boxfix's letrec cells read this way --
// pre-fill is a miss, the binding-site nom the payload. distinct from peep,
// whose caller names what absence means.
lvm(lvm_missing) {
 word v = mapp(Sp[0]) ? ai_mapget(g, word(no_entry), Sp[1], Sp[0]) : word(no_entry);
 if (v != word(no_entry)) return
  Sp[1] = v,
  Sp++,
  Ip++,
  Continue();
 Have(8);                          // [resume a b] + ai_raise's 5 words
 struct ai_atom *ts = sym_probe(g, "help", 4);
 word h = ts ? ai_mapget(g, nil, word(ts), g->book) : nil;
 if (ai_nilp(g, h)) return
  Sp[1] = (word) ai_core_of(g),
  Sp++,
  Ip++,
  Continue();
 word a = word(sym_probe(g, "missing", 7));   // 'missing: the nif's name, rooted by the book
 Sp -= 1;                          // [resume a b]: b = the key, already in place at Sp[2]
 Sp[0] = word(Ip + 1), Sp[1] = a;
 return Pack(g), ai_raise(g, ai_status_scare, a, Sp[2], help_more_k); }
// numap/numtap are tail-called (Ap) from the fused arg/quote aps, which bump
// Ip by one word so its `ret = Ip+1` math lines up -- leaving Ip pointing at an
// operand, NOT a re-runnable instruction. So a plain Have() here is unsafe: lvm_gc
// re-dispatches via Continue() -> cell(Ip)->ap, which would jump into that operand.
// Instead gc by hand and re-Ap ourselves (we read but don't mutate before this, so
// re-entry is idempotent); the dispatch never has to trust Ip.
#define NumapHave(self) if (Sp < Hp + 2) { \
 Pack(g); g = ai_please(g, 2); if (!ai_ok(g)) return ghelp(g); \
 return Unpack(g), Ap(self, g); }
static lvm(lvm_numap) {
 NumapHave(lvm_numap);
 word h = resolve_hot(g, "num-ap", 6);
 word n = Sp[1], x = Sp[0], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = n, dst[1] = h, dst[2] = x, dst[3] = ret;
 return Sp = dst, Ip = (union u*) numap_drive, Continue(); }
static lvm(lvm_numtap) {
 NumapHave(lvm_numtap);
 word h = resolve_hot(g, "num-ap", 6);
 word fs = getcharm(Ip[1].x), n = Sp[1], x = Sp[0], *dst = &Sp[fs + 2] - 3, ret = Sp[fs + 2];
 dst[0] = n, dst[1] = h, dst[2] = x, dst[3] = ret;
 return Sp = dst, Ip = (union u*) numap_drive, Continue(); }

// `+`/`*` over a lambda operand: build the combinator partial (add/mul g g)
// and leave it as the result. Mirrors lvm_numap's frame -- [g, comb, g, ret=Ip+1]
// run through numap_drive -- but the combinator (4-arg add / 3-arg compose) applied
// to 2 args yields a closure (the new function) instead of a value. Ip is at the +/*
// opcode (a re-runnable instruction), so a plain Have is safe; operands re-read after.
static lvm(lvm_addh) {
 Have(2);
 word h = resolve_hot(g, "add", 3);
 word fa = Sp[0], ga = Sp[1], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = fa, dst[1] = h, dst[2] = ga, dst[3] = ret;
 return Sp = dst, Ip = (union u*) numap_drive, Continue(); }
static lvm(lvm_mulh) {
 Have(2);
 word h = resolve_hot(g, "mul", 3);
 word fa = Sp[0], ga = Sp[1], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = fa, dst[1] = h, dst[2] = ga, dst[3] = ret;
 return Sp = dst, Ip = (union u*) numap_drive, Continue(); }

// apply function to one argument
lvm(lvm_ap) {
 union u *k;
 if (oddp(Sp[1])) return Ap(lvm_numap, g);
 k = cell(Sp[1]), Sp[1] = word(Ip + 1), Ip = k;
 YieldCheck();
 return Continue(); }

// tail call
lvm(lvm_tap) {
 if (oddp(Sp[1])) return Ap(lvm_numtap, g);         // fixnum operator -> num-ap, deliver to caller
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getcharm(Ip[1].x) + 1;
 Ip = cell(j), Sp[0] = x;
 YieldCheck();
 return Continue(); }

// apply to multiple arguments
lvm(lvm_apn) {
 size_t n = getcharm(Ip[1].x);
 union u *r = Ip + 2; // return address
 // this instruction is only emitted when the callee is known to be a function
 // so putting a value off the stack into Ip is safe. the +2 is cause we leave
 // the currying instruction in there... should be skipped in compiler instead FIXME
 Ip = cell(Sp[n]) + 2;
 Sp[n] = word(r); // store return address
 YieldCheck();
 return Continue(); }

// tail call
lvm(lvm_tapn) {
 size_t n = getcharm(Ip[1].x),
        r = getcharm(Ip[2].x);
 Ip = cell(Sp[n]) + 2;
 word *o = Sp;
 for (Sp += r + 1; n--; Sp[n] = o[n]);
 YieldCheck();
 return Continue(); }

// return
lvm(lvm_ret) {
 word n = getcharm(Ip[1].x) + 1;
 return Ip = cell(Sp[n]), Sp[n] = Sp[0], Sp += n, Continue(); }

lvm(lvm_ret0) { return
 Ip = cell(Sp[1]),
 Sp[1] = Sp[0],
 Sp += 1,
 Continue(); }

// kcall : x = Sp[0], k = Ip[1] -> Ip = k, Sp[0] = x
lvm(lvm_kcall) {
 word x = Sp[0];
 union u *stack = Ip + 2, *end = (union u*) ttag(g, stack);
 uintptr_t height = end - stack;
 Have(height);
 *(Sp = memmove(topof(g) - height, stack, height * sizeof(word))) = x;
 Ip = Ip[1].m;
 return Continue(); }

// callk : i = Sp[0], k = Ip + 1 -> Ip = i, Sp[0] = k
lvm(lvm_callk) {
 word f_val = Sp[0];                         // g, the call_cc arg
 if (oddp(f_val)) return Ip += 1, Continue();
 word height = topof(g) - Sp;
 uintptr_t n = 2 + height;                   // lvm_kcall + (ip + 1) + stack = text_contents
 Have(n + Width(struct ai_tag) + 1);          // text_contents + text_tag + 1 stack = _mem_req
 union u *k = (union u*) Hp;
 Hp += n + Width(struct ai_tag);              // text_contents + text_tag = _heap_alloc
 k[0].ap = lvm_kcall;                       // 
 k[1].m  = Ip + 1;                           // resume at next instruction
 memcpy(k + 2, Sp, height * sizeof(word));
 Sp -= 1;
 Sp[0] = word(tagtext(k, n));
 Sp[1] = f_val;
 return Ap(lvm_ap, g); }

// lvm_yield_sw_mono can't call ai_wait_fds directly with a stack pointer
static ai_noinline void ai_wait_fd(int const fd, int n, uintptr_t ms) {
  ai_wait_fds(&fd, n, ms); }

// monotask fast path
static lvm(lvm_yield_sw_mono) { uintptr_t my_wake = g->next_wake_at;
 int my_wait_fd = g->next_wait_fd;
 g->next_wake_at = 0;
 g->next_wait_fd = -1;
 g->yield_ctr = 0;
 if (my_wake) for (uintptr_t now; my_wake > (now = ai_clock());)
  my_wait_fd >= 0 ? ai_wait_fd(my_wait_fd, 1, my_wake - now) : ai_sleep(my_wake - now);
 else if (my_wait_fd >= 0)
  while (!ai_ready(my_wait_fd)) ai_wait_fd(my_wait_fd, 1, 0);
 return Continue(); }

// First non-dormant peer in the ring whose wake_at <= now and whose
// wait_fd is either unset or actually ready. Without the wait_fd check
// a task parked on stdin would be scheduled immediately, busy-looping
// through yield_sw and filling the heap with stale task nodes.
static ai_inline union u *find_runnable(union u *head, uintptr_t now) {
 for (union u *n = head->m; n != head; n = n->m)
  if (n[1].m->ap != lvm_task_exit && (uintptr_t) getcharm(n[3].x) <= now) {
   int wf = (int) getcharm(n[4].x);
   if (wf < 0 || ai_ready(wf)) return n; }
 return NULL; }

static ai_noinline union u *yield_sw_wait(struct ai *g, uintptr_t my_wake, int my_wait_fd) {
 uintptr_t min_wake = my_wake;
 int fds[ai_wait_fds_max], nfds = 0;
 if (my_wait_fd >= 0) fds[nfds++] = my_wait_fd;
 for (union u *n = g->tasks->m; n != g->tasks; n = n->m)
  if (n[1].m->ap != lvm_task_exit) {
   uintptr_t wa = (uintptr_t) getcharm(n[3].x);
   if (wa && (!min_wake || wa < min_wake)) min_wake = wa;
   int wf = (int) getcharm(n[4].x);
   if (wf >= 0 && nfds < ai_wait_fds_max) fds[nfds++] = wf; }
 if (!min_wake && !nfds) return NULL;
 uintptr_t now = ai_clock();
 if (!min_wake) ai_wait_fds(fds, nfds, 0);
 else if (min_wake > now) ai_wait_fds(fds, nfds, min_wake - now);
 now = ai_clock();
 if (my_wait_fd >= 0 && ai_ready(my_wait_fd)) return NULL;
 return find_runnable(g->tasks, now); }

lvm(lvm_yield_sw) {
 if (g->tasks->m == g->tasks) return Ap(lvm_yield_sw_mono, g);
 union u *next = find_runnable(g->tasks, ai_clock());
 uintptr_t my_wake = g->next_wake_at;
 int my_wait_fd = g->next_wait_fd;
 if (!next) {
  next = yield_sw_wait(g, my_wake, my_wait_fd);
  if (!next) {
   g->next_wake_at = 0;
   g->next_wait_fd = -1;
   if (g->yield_ctr >= yield_interval) g->yield_ctr = 0;
   return Continue(); } }
 word my_height = topof(g) - Sp;
 union u *next_stack = next + 5,
       *end = (union u*) ttag(g, next_stack);
 uintptr_t restore_h = end - next_stack,
           need = my_height + restore_h + 6;
 if (Sp < Hp + need) {
  Pack(g);
  if (!ai_ok(g = ai_please(ai_push(g, 1, next), need))) return ghelp(g);
  next = cell(pop1(g));
  Unpack(g);
  next_stack = next + 5; }   // recompute: next was forwarded by gc
 g->next_wake_at = 0;
 g->next_wait_fd = -1;
 union u *prev = next;
 while (prev->m != g->tasks) prev = prev->m;
 union u *N = (union u*) Hp;
 Hp += need - restore_h;
 N[0].m = g->tasks->m;
 N[1].m = Ip;
 N[2].x = g->tasks[2].x;
 N[3].x = putcharm((intptr_t) my_wake);
 N[4].x = putcharm(my_wait_fd);
 memcpy(N + 5, Sp, my_height * sizeof(word));
 prev->m = tagtext(N, 5 + my_height);
 g->yield_ctr = 0;
 g->tasks = next;
 Sp = memmove(topof(g) - restore_h, next_stack, restore_h * sizeof(word));
 Ip = next[1].m;
 return Continue(); }

lvm(lvm_yield_nif) { return Ip++, Ap(lvm_yield_sw, g); }
lvm(lvm_task_exit) { return Ap(lvm_yield_sw, g); }
static union u const spawn_body[] = { {lvm_ap}, {.ap = lvm_task_exit} };
lvm(lvm_spawn) {
 Have(8);
 // New task node N: [next, saved_ip=spawn_body, pid, wake_at=0, wait_io=0, stack[0..1]=x,fn, tag]
 union u *N = (union u*) Hp;
 Hp += 8;
 word fn = Sp[0], x = Sp[1];
 uintptr_t pid = ++g->next_serial;   // a pid is a fresh identity: drawn from the mint stream
 N[0].m = g->tasks->m;
 N[1].m = (union u*) spawn_body;
 N[2].x = Sp[1] = putcharm(pid);
 N[3].x = nil;         // wake_at: sentinel for "always runnable"
 N[4].x = putcharm(-1);  // wait_fd: -1 = not waiting on I/O
 N[5].x = x;
 N[6].x = fn;
 g->tasks->m = tagtext(N, 7);
 return Sp++, Ip++, Continue(); }

lvm(lvm_wait) {
 word pid_arg = Sp[0], ret = nil;
 intptr_t target = getcharm(pid_arg);
 for (union u *node = g->tasks->m; node != g->tasks; node = node->m) {
  if (getcharm(node[2].x) != target) continue;
  if (node[1].m->ap == lvm_task_exit) {
   // dormant: dormant task's stack is just [retval] at node[5]
   ret = node[5].x;
   union u *prev = node;
   while (prev->m != node) prev = prev->m;
   prev->m = node->m;
   break; }
   // still running: yield without advancing Ip (re-enter wait on resume).
   // A task blocked in `wait` is polling a peer, NOT blocked on I/O or a timer,
   // so clear any stale next_wait_fd/next_wake_at (e.g. a serial-read fd left set
   // by the kernel's cooperative input) -- otherwise yield_sw saves this task as
   // parked on an unready fd and find_runnable never reschedules it (deadlock).
   g->next_wake_at = 0;
   g->next_wait_fd = -1;
  return Ap(lvm_yield_sw, g); }
 return *Sp = ret, Ip++, Continue(); }

lvm(lvm_donep) {
 word pid_arg = Sp[0], result = putcharm(1);
 intptr_t target = getcharm(pid_arg);
 for (union u *node = g->tasks->m; node != g->tasks; node = node->m)
  if (getcharm(node[2].x) == target) {
   if (node[1].m->ap != lvm_task_exit) result = nil;
   break; }
 Sp[0] = result;
 Ip += 1;
 return Continue(); }

lvm(lvm_hush) {
 word pid_arg = Sp[0], result = nil;
 intptr_t target = getcharm(pid_arg);
 union u *prev = g->tasks;
 for (union u *node = prev->m; node != g->tasks; prev = node, node = node->m)
  if (getcharm(node[2].x) == target) {
   prev->m = node->m;
   result = putcharm(1);
   break; }
 Sp[0] = result;
 Ip += 1;
 return Continue(); }

lvm(lvm_sleep) {
 word n = Sp[0];
 Sp[0] = nil;
 Ip += 1;
 if (!charmp(n) || getcharm(n) <= 0) return Continue();
 g->next_wake_at = (uintptr_t) ai_clock() + getcharm(n);
 return Ap(lvm_yield_sw, g); }


lvm(lvm_jump) { return Ip = Ip[1].m, Continue(); }
// The only compiled truthiness branch (`?`, and the `&&`/`||` macros). Uses the
// language falsy predicate so an all-zero vec (boxed 0.0, zero int box,
// all-zero array) takes the false arm, lifting "0 is the only false scalar".
lvm(lvm_cond) { return Ip = ai_nilp(g, *Sp++) ? Ip[1].m : Ip + 2, Continue(); }
lvm(lvm_unc) {
 Have1();
 *--Sp = Ip[1].x;
 Ip = Ip[2].m;
 return Continue(); }

lvm(lvm_cur) {
 size_t const S = 3 + Width(struct ai_tag);
 Have(S + 2);
 union u *k = (union u*) Hp, *j = k;
 Hp += S;
 size_t n = getcharm(Ip[1].x);
 // FIXME this does not always need to be a runtime check
 if (n > 2) Hp += 2,
            j += 2,
            k[0].ap = lvm_cur,
            k[1].x = putcharm(n - 1);
 return
  j[0].ap = lvm_unc,
  j[1].x = *Sp++,
  j[2].m = Ip + 2,
  Ip = cell(*Sp),
  Sp[0] = (word) tagtext(k, j + 3 - k),
  Continue(); }

// load instructions
//
lvm(lvm_quote) {
 Have1();
 Sp -= 1;
 Sp[0] = Ip[1].x;
 Ip += 2;
 return Continue(); }

// push () -- the core, the one true nothing. A RUNTIME FETCH (no operand): the core
// FLOPS with the dust, so () can never be baked as a quote constant (the egg's build
// core != the runtime core). analyze emits this for the core; the value is always the
// live core, forwarded by gcg when it moves.
lvm(lvm_zp) {
 Have1();
 Sp -= 1;
 Sp[0] = (word) ai_core_of(g);
 Ip += 1;
 return Continue(); }

// A port has no function meaning either: applying it behaves as 0 (yields 1), like
// a buf (byte-identical body, kept distinct by ai_noicf -- see lvm_buf).
lvm(lvm_port_io) {
  Ip = cell(*++Sp);
  *Sp = putcharm(1);
  return Continue(); }

// push a value from the stack
lvm(lvm_arg) {
 Have1();
 Sp[-1] = Sp[getcharm(Ip[1].x)];
 Sp -= 1;
 Ip += 2;
 return Continue(); }

// fused (lvm_arg <idx> ; lvm_ap): push local at <idx>, then apply. A 2-word op
// emitted by the compiler's `karg` when an arg ref is immediately followed by a
// non-tail ap (the dominant "call a function on a local" shape). Saves one
// dispatch + the standalone ap word vs. the unfused pair. The post-pattern
// resume address is Ip+2 (cf. lvm_ap's Ip+1, since the op is one word longer).
lvm(lvm_argap) {
 if (oddp(Sp[0])) {                                  // fixnum operator -> num-ap, resume at Ip+2
  Have1();
  Sp[-1] = Sp[getcharm(Ip[1].x)], Sp -= 1, Ip += 1;   // push local under operator; resume now Ip+2
  return Ap(lvm_numap, g); }
 Have1();
 Sp[-1] = Sp[getcharm(Ip[1].x)];
 Sp -= 1;
 union u *k = cell(Sp[1]); Sp[1] = word(Ip + 2), Ip = k;
 YieldCheck();
 return Continue(); }

// fused (lvm_quote <v> ; lvm_ap): push constant <v>, then apply. Emitted by
// kim when a quote is immediately followed by a non-tail ap (a call with a
// constant arg, e.g. (k 0)). Resume at Ip+2 (2-word op), cf. lvm_argap.
lvm(lvm_quoteap) {
 if (oddp(Sp[0])) {                                  // fixnum operator -> num-ap, resume at Ip+2
  Have1();
  Sp[-1] = Ip[1].x, Sp -= 1, Ip += 1;               // push const under operator; resume now Ip+2
  return Ap(lvm_numap, g); }
 Have1();
 Sp -= 1;
 Sp[0] = Ip[1].x;
 union u *k = cell(Sp[1]); Sp[1] = word(Ip + 2), Ip = k;
 YieldCheck();
 return Continue(); }

// fused (lvm_arg <idx> ; lvm_tap <fs>): push local <idx>, then tail-call,
// popping frame size <fs> at Ip[2] (tap's operand, kept in place by the fused
// emit). The single-arg tail-call shape, e.g. a tail (loop x) or cont (k v).
lvm(lvm_argtap) {
 if (oddp(Sp[0])) {                                  // fixnum operator -> num-ap, deliver to caller
  Have1();
  Sp[-1] = Sp[getcharm(Ip[1].x)], Sp -= 1, Ip += 1;   // push local under operator; fs operand now Ip[1]
  return Ap(lvm_numtap, g); }
 Have1();
 Sp[-1] = Sp[getcharm(Ip[1].x)];
 Sp -= 1;
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getcharm(Ip[2].x) + 1;
 Ip = cell(j), Sp[0] = x;
 YieldCheck();
 return Continue(); }

// operand-value-specialized arg/quote: 1-word ops with the index/constant baked
// into the ap (no Ip[1] operand fetch). Emitted by the compiler's spa/spq for
// the hottest indices {0..3} / constants {0,1,2,3,-1,-2}.
argn(lvm_arg0, 0) argn(lvm_arg1, 1) argn(lvm_arg2, 2) argn(lvm_arg3, 3)
quon(lvm_quo0, 0) quon(lvm_quo1, 1) quon(lvm_quo2, 2) quon(lvm_quo3, 3)
quon(lvm_quom1, -1) quon(lvm_quom2, -2)

lvm(lvm_trim) { return
 clip(g, cell(Sp[0])), Ip++, Continue(); }

lvm(lvm_seek) { return
 Sp[1] = word(cell(Sp[1]) + getcharm(Sp[0])),
 Sp++, Ip++, Continue(); }

lvm(lvm_peek) { return
 Sp[1] = (cell(Sp[1]) + getcharm(Sp[0]))->x,
 Sp++, Ip++, Continue(); }

lvm(lvm_poke) {
 union u *c = cell(Sp[2]) + getcharm(Sp[0]);
 return c->x = Sp[1], *(Sp += 2) = word(c), Ip++, Continue(); }

lvm(lvm_spin) {
 size_t n = getcharm(Sp[0]);
 Have(n + Width(struct ai_tag));
 union u *k = (union u*) Hp;
 Hp += n + Width(struct ai_tag);
 Sp[0] = word(memset(tagtext(k, n), -1, n * sizeof(word)));
 return Ip++, Continue(); }

// ceil a positive measure into a fixnum, saturating at fix_max. ceil (not floor)
// so the result is 0 *only* when m is exactly 0 -- $ then doubles as a zero test:
// (= 0 ($ x)) iff x is nothing. Never overflows putcharm's tag.
static ai_inline intptr_t len_sat(ai_flo_t m) {
  if (m >= (ai_flo_t) fix_max) return fix_max;
  intptr_t i = (intptr_t) m;                    // trunc toward 0 (m >= 0)
  return i + (m > (ai_flo_t) i ? 1 : 0); }       // bump for any fractional part -> ceil
// The NET: the COMPLEX-VALUED measure of any value (the net->C round: the spec's
// additivity law -- net(a + b) = net a + net b wherever + is total -- holds over
// complex operands only if the measure keeps phase, so the codomain is C and the
// order retraction happens ONCE, in the observers). A complex scalar nets ITSELF;
// every other scalar nets on the real line (a number its value, text/spellings
// their charm sums, a table its key count, a fn/port 1); a product or rank>=1
// array nets the SUM of its elements' nets -- a TRUE complex sum, recursive and
// UNCLAMPED, the SPINE only (a dotted tail is not an element) -- so a list of
// negatives nets negative, a product of nothings nets to nothing, and opposite
// phases annihilate by VECTOR cancellation, not by the order's tiebreak. The
// arrangement does not matter: a packed ai_C array and the o-list of the same
// values net the same sum, and net(asum v) = net(v) by construction.
//   ai_C  packed (re,im) float pairs at vec_data -> componentwise sum
//   ai_O  object words -> each element's own ai_net (recursive; depth bounded by nesting)
//   ai_Z/ai_R  the element values directly (vec_get_flo), imaginary part 0
static struct ai_zn ai_net(struct ai *g, word x) {
  if (charmp(x)) return zn((ai_flo_t) getcharm(x), 0);               // fixnum: its value
  if (bufp(x)) { struct ai_str *b = buf_str(x); ai_flo_t t = 0;   // hot chars: Σ charms, like a string
    for (uintptr_t i = 0; i < b->len; i++) t += (uint8_t) b->bytes[i];
    return zn(t, 0); }
  if (mapp(x)) return zn((ai_flo_t) map_len(x), 0);              // table: key count
  if (!datp(x)) return zn(1, 0);                                // opaque but present (fn / port): truthy
  switch (typ(x)) {
    default: return zn(1, 0);                                   // unknown present data kind -> truthy
    case KString: { ai_flo_t t = 0;                                 // a string is PACKED CHARS: Σ charms
      for (uintptr_t i = 0; i < len(x); i++) t += (uint8_t) txt(x)[i];
      return zn(t, 0); }                                           // (the count moved to tally)
    case KTwo: { struct ai_zn s = zn(0, 0); word p = x;           // product: sum the SPINE's nets --
      do { struct ai_zn e = ai_net(g, A(p));                       // complex sums, so negatives cancel,
           s.re += e.re, s.im += e.im;                           // phases cancel, and a product of
           p = B(p); } while (twop(p));                          // nothings nets to nothing
      return s; }
    case KBig: return zn(ai_big_to_flo(x), 0);                   // bignum: full magnitude, sign intact
    case KSym: return zn((ai_flo_t) pin_sym(g, x), 0);           // a symbol nets its SPELLING's charms
                                                                // (a mint: the distinct nothing)
    case KVec: { struct ai_vec *v = vec(x);                 // boxed scalar or rank-n array
      uintptr_t i, n = vec_nelem(v);
      if (!v->rank) {                                            // rank-0 scalar: its value
        if (v->type == ai_C) return zn(cplx_re(x), cplx_im(x));   // a complex nets ITSELF
        if (v->type == ai_R) return zn(flo_get(x), 0);
        return zn((ai_flo_t) box_get(x), 0); }                    // ai_Z wide-int box
      struct ai_zn s = zn(0, 0);                                  // rank>=1 array -> Σ elem
      if (v->type == ai_C) { ai_flo_t *d = vec_data(v);
        for (i = 0; i < n; i++) s.re += d[2*i], s.im += d[2*i+1];
        return s; }
      if (v->type == ai_O)
        for (i = 0; i < n; i++) { struct ai_zn e = ai_net(g, vec_get_obj(v, i));
          s.re += e.re, s.im += e.im; }
      else for (i = 0; i < n; i++) s.re += vec_get_flo(v, i);
      return s; } } }
// The $ operator: the net observed once -- max(0, ceil) of its ORDER-SIGNED
// MAGNITUDE (a real net is its own magnitude, exactly; a phaseful net takes
// |z|, signed by zn_nonpos) -- so (nilp x) == (= 0 ($ x)) at every kind and
// rank: a negative real, a non-positive complex, a list or array whose net
// sums <= 0 in the order all measure 0. Lockstep with ai_nilp.
static intptr_t ai_pin(struct ai *g, word x) {
  if (charmp(x)) { intptr_t n = getcharm(x); return n <= 0 ? 0 : n; }   // <= 0 -> 0 (0 is nil), exact
  struct ai_zn z = ai_net(g, x);
  if (zn_nonpos(z)) return 0;
  return len_sat(z.im == 0 ? z.re : ai_sqrt(z.re * z.re + z.im * z.im)); }
lvm(lvm_pin) { Sp[0] = putcharm(ai_pin(g, Sp[0])); Ip += 1; return Continue(); }

// ============================================================================
// io
// ============================================================================
// THE ATOMIC-EDGE CONTRACT (an io_* function owns the io buffer slot).
// A `to` string sink (struct to) GROWS its backing ai_str via str0 -> a GC, so
// EVERY zputc to a show-string sink is a relocation point. The contract for the
// whole io_* family: an io op that spans more than one zputc must PARK its heap
// operand (ai_push -> g->sp) and RE-READ it across each write -- never hold a raw
// pointer over an edge. Audited 2026-06-16, the family holds it without exception:
//   * structural printers park + re-read: ioput_str/_sym/_two/_map/_big/_arr
//     (e.g. ioput_two re-reads A/B(g->sp[0]) after every byte; ioput_map snapshots
//     k/v into a fresh list under the seen-list cycle guard).
//   * to_putc itself re-derives o = g->io (GC-traced) and copy-then-swaps the
//     grown buffer, so the swap is atomic across its own str0 GC.
//   * scalar decompositions (re/im, float) are read to C locals BEFORE any zputc
//     (ioput_vec_scalar_complex, ioput_carr_elem).
//   * pure C-data emitters hold no heap operand, so need no park: ioputcs/ioputn/
//     ioprintf (integer + char formats only -- no %s).
//   * lvm edges Pack/Unpack and re-read bytes each step (lvm_dot/_fputs/_fputc),
//     zflush at the close; a scare mid-print stops cleanly (ai_ok gates).
//   * the reader half is symmetric: ioread1op/ioparse keep the partial parse in
//     parked sp slots and re-read the growing buffer (grbufg/str0) after each GC.
// The lam_* lambda-canonicalization helpers are PURE (no io, no buffer): they
// cannot open an edge, and lam_canon reserves its cells up front (alloc-free
// rebuild), so even ioput_fn_body -> lam_canon keeps the surrounding op atomic.
static ai_inline bool iop(word x) { return lamp(x) && cell(x)->ap == lvm_port_io; }
static ai_inline struct ai_port_vt const *port_vt(word fd_tagged) {
 intptr_t fd = getcharm(fd_tagged);
 return fd >= 0 ? &ai_fd_port_vt : &synth[-(fd + 1)]; }
static ai_inline struct ai *zgetc(struct ai*g)          { return ai_ok(g) ? port_vt(g->io->fd)->getc(g) : g; }
static ai_inline struct ai *zungetc(struct ai*g, int c) { return ai_ok(g) ? port_vt(g->io->fd)->ungetc(g, c) : g; }
static ai_inline struct ai *zputc(struct ai*g, int c)   { return port_vt(g->io->fd)->putc(g, c); }
static ai_inline struct ai *zflush(struct ai*g)         { return port_vt(g->io->fd)->flush(g); }
static ai_inline struct ai *zeof(struct ai*g)           { return ai_ok(g) ? port_vt(g->io->fd)->eof(g) : g; }
struct ci { struct ai_io io; ai_word head; }; // charlist input
struct to { struct ai_io io; struct ai_str *buf; ai_word i; }; // lisp string output
static struct ai *ai_dtoa2(struct ai*, ai_flo_t);
static struct ai *gfputx(struct ai *g, struct ai_io *o, intptr_t x);

static struct ai *noop_getc(struct ai *g) {
 ai_core_of(g)->io->eof_seen = putcharm(true);
 return g->b = EOF, g; }
static struct ai *noop_ungetc(struct ai *g, int c) { (void) c; return g; }
static struct ai *noop_eof(struct ai *g) { return g->b = true, g; }
static struct ai *noop_putc(struct ai *g, int c) { (void) c; return g; }
static struct ai *noop_flush(struct ai *g) { return g; }

static struct ai *ti_eof(struct ai*g) {
 struct ti *i = (struct ti*) g->io;
 return g->b = (getcharm(i->io.ungetc_buf) == EOF) && getcharm(i->io.eof_seen), g; }

static struct ai *ti_getc(struct ai*g) {
 struct ti *i = (struct ti*) g->io;
 if (getcharm(i->io.ungetc_buf) != EOF) {
  int c = getcharm(i->io.ungetc_buf);
  i->io.ungetc_buf = putcharm(EOF);
  return g->b = c, g; }
 if (!i->t[i->i]) { i->io.eof_seen = putcharm(true); return g->b = EOF, g; }
 return g->b = i->t[i->i++], g; }

static struct ai *ti_ungetc(struct ai*g, int c) {
 struct ti *i = (struct ti*) g->io;
 i->io.ungetc_buf = putcharm(c);
 i->io.eof_seen = putcharm(false);
 return g->b = c, g; }

static struct ai *ci_getc(struct ai *g) {
 struct ci *i = (struct ci*) g->io;
 if (getcharm(i->io.ungetc_buf) != EOF) {
  int c = getcharm(i->io.ungetc_buf);
  i->io.ungetc_buf = putcharm(EOF);
  return g->b = c, g; }
 if (!twop(i->head)) { i->io.eof_seen = putcharm(true); return g->b = EOF, g; }
 int c = getcharm(A(i->head));
 i->head = B(i->head);
 return g->b = c, g; }

static struct ai *to_putc(struct ai *g, int c) {
 struct to *o = (struct to*) g->io;
 uintptr_t i = getcharm(o->i);
 if (i >= len(o->buf)) {
  uintptr_t new_cap = len(o->buf) * 2;
  g = str0(g, new_cap);
  if (!ai_ok(g)) return g;
  o = (struct to*) g->io;                 // GC may have moved it; g->out is GC-traced
  struct ai_str *nb = (struct ai_str*) g->sp[0];
  memcpy(txt(nb), txt(o->buf), i);
  o->buf = nb;
  g->sp++; }
 txt(o->buf)[i] = c;
 o->i = putcharm(i + 1);
 return g; }
static struct ai *to_flush(struct ai *g) { return g; }

struct ai_port_vt const synth[] = {
 /* fd = -1, ti: read-only string source */
 { ti_getc,   ti_ungetc,   ti_eof,   noop_putc, noop_flush },
 /* fd = -2, to: write-only vec sink   */
 { noop_getc, noop_ungetc, noop_eof, to_putc,   to_flush   },
 /* fd = -3, closed port (post-close)  */
 { noop_getc, noop_ungetc, noop_eof, noop_putc, noop_flush },
 /* fd = -4, ci: read-only charlist source -- ungetc/eof read only the ai_io
    fields, so ti_ungetc/ti_eof work unchanged here. */
 { ci_getc,   ti_ungetc,   ti_eof,   noop_putc, noop_flush }, };

// (fputc port byte) — write byte to port; return byte.
lvm(lvm_fputc) {
 if (iop(Sp[0])) {
  g->io = (struct ai_io*) Sp[0];
  Pack(g);
  if (!ai_ok(g = zputc(g, getcharm(g->sp[1])))) return ghelp(g);
  Unpack(g); }
 return Sp++, Ip++, Continue(); }

// (fflush port) — flush; return the port.
lvm(lvm_fflush) {
 if (iop(Sp[0])) {
  g->io = (struct ai_io*) Sp[0];
  Pack(g);
  if (!ai_ok(g = zflush(g))) return ghelp(g);
  Unpack(g); }
 return Ip++, Continue(); }

// (fputs port s) — write every byte of string-or-buf s through port; return
// the port. No-op when args are misused (non-port, or neither string nor
// buf). bytes_of resolves either to the ai_str holding the bytes, re-read each
// iteration so GC inside zputc (e.g., growing a sink buffer) can forward it
// safely (for a buf, GC may move both the wrapper and its backing string).
lvm(lvm_fputs) {
 if (iop(Sp[0]) && (strp(Sp[1]) || bufp(Sp[1]))) {
  g->io = (struct ai_io*) Sp[0];
  uintptr_t i = 0, l = len(bytes_of(Sp[1]));
  Pack(g);
  while (ai_ok(g) && i < l) g = zputc(g, txt(bytes_of(g->sp[1]))[i++]);
  if (!ai_ok(g = zflush(g))) return ghelp(g);
  Unpack(g); }
 return Sp++, Ip++, Continue(); }

lvm(lvm_fputx) {
 if (iop(Sp[0])) {
  Pack(g);
  if (!ai_ok(g = gfputx(g, (struct ai_io*) Sp[0], Sp[1]))) return ghelp(g);
  Unpack(g); }
 return Sp++, Ip++, Continue(); }

// (dot x) -> print x to `out` and return x. A string/buf is written verbatim
// (puts discipline -- raw bytes); any other value in external form (putx
// discipline -- the inspect form). The `.` reader sigil expands to (dot x). The
// string bytes are re-read from g->sp[0] each iteration (GC inside zputc may
// forward them); gfputx is self-GC-safe over its value arg, as in lvm_fputx.
lvm(lvm_dot) {
 word x = Sp[0];
 g->io = &ai_stdout;
 Pack(g);
 if (strp(x) || bufp(x)) {
  uintptr_t i = 0, l = len(bytes_of(x));
  while (ai_ok(g) && i < l) g = zputc(g, txt(bytes_of(g->sp[0]))[i++]);
  if (ai_ok(g)) g = zflush(g); }
 else g = gfputx(g, &ai_stdout, x);
 if (!ai_ok(g)) return ghelp(g);
 Unpack(g);
 return Ip++, Continue(); }

static struct ai*gfputbn(struct ai *g, intptr_t n, uint8_t b, struct ai_io *o);
lvm(lvm_fputbn) {
 if (iop(Sp[0])) {
   Pack(g);
   if (!ai_ok(g = gfputbn(g, getcharm(Sp[1]), getcharm(Sp[2]), (struct ai_io*) Sp[0]))) return ghelp(g);
   Unpack(g);
   Sp[2] = Sp[1]; }
 return Sp += 2, Ip++, Continue(); }

static struct ai*ioputc(struct ai*g, int c) {
  return port_vt(ai_core_of(g)->io->fd)->putc(g, c); }
static struct ai*ioputs(struct ai*g, char const *s) {
 while (*s) g = ioputc(g, *s++);
 return g; }

// the terminal scare face (declared in ai.h): an helpless scare's stashed
// condition data prints as ";; a b" -- the shell help's face -- to the err
// port; the bare scare (nil nil) is oom, which has no data: answer 0 and let
// the frontend report it raw. best-effort: a failure mid-print just stops.
int ai_scare_face_(struct ai *g) {
 struct ai *c = ai_core_of(g);
 if (!c || (nilp(c->scare_a) && nilp(c->scare_b))) return 0;
 c->io = &ai_stderr;
 struct ai *h = ioputs(c, ";; ");  // gfputx may GC and MOVE the core: re-derive
 if (ai_ok(h)) h = gfputx(h, &ai_stderr, ai_core_of(h)->scare_a);
 if (ai_ok(h)) h = ioputc(h, ' ');
 if (ai_ok(h)) h = gfputx(h, &ai_stderr, ai_core_of(h)->scare_b);
 if (ai_ok(h)) h = ioputc(h, '\n');
 if (ai_ok(h)) zflush(h);
 return 1; }

static struct ai*ioputn(struct ai *g, intptr_t n, uint8_t b) {
 uintptr_t
  m = n >= 0 || b != 10 ? (uintptr_t) n : (g = ioputc(g, '-'), -(uintptr_t) n),
  q = m / b,
  r = m % b;
 if (q) g = ioputn(g, q, b);
 return ioputc(g, ai_digits[r]); }

static ai_inline struct ai*gfputbn(struct ai *g, intptr_t n, uint8_t b, struct ai_io *o) {
 return g->io = o, ioputn(g, n, b); }

static struct ai*gvzprintf(struct ai*g, char const *fmt, va_list xs) {
 for (int c; (c = *fmt++);) {
  if (c != '%') g = ioputc(g, c);
  else pass: switch ((c = *fmt++)) {
   case 0: return g;
   case 'l': goto pass;
   case 'b': g = ioputn(g, va_arg(xs, uintptr_t), 2); continue;
   case 'n': g = ioputn(g, va_arg(xs, uintptr_t), 6); continue;
   case 'o': g = ioputn(g, va_arg(xs, uintptr_t), 8); continue;
   case 'd': g = ioputn(g, va_arg(xs, uintptr_t), 10); continue;
   case 'u': g = ioputn(g, va_arg(xs, uintptr_t), 12); continue;
   case 'x': g = ioputn(g, va_arg(xs, uintptr_t), 16); continue;
   case 'z': g = ioputn(g, va_arg(xs, uintptr_t), 36); continue;
   case '%': g = ioputc(g, '%'); continue;             // %% -> literal %
   default: g = ioputc(g, c); } }
 return g; }

static struct ai *ioprintf(struct ai *g, char const *fmt, ...) {
 va_list xs;
 va_start(xs, fmt);
 g = gvzprintf(g, fmt, xs);
 va_end(xs);
 return g; }

static struct ai *ioputx(struct ai *g, intptr_t x, uintptr_t off);
static struct ai *ioputcs(struct ai *g, char const *s);

// --- print cycle detection (tables only) --------------------------------------
// A "seen" list of the tables on the current print path lives in a single stack
// slot at the bottom of the print region (established by gfputx). It moves with
// the stack on GC, so callers locate it by its offset from the stack top (`off`),
// which GC preserves; the offset is threaded down the recursion as an ordinary
// integer (no struct-g state). A table is consed on as we descend into it and
// dropped as we ascend, so the list is exactly the ancestor path of tables. When
// printing finishes gfputx restores the original stack height, discarding it.
static word *seen_slot(struct ai *g, uintptr_t off) {
 return topof(ai_core_of(g)) - off; }
static bool seen_member(struct ai *g, uintptr_t off, word x) {
 for (word l = *seen_slot(g, off); twop(l); l = B(l)) if (A(l) == x) return true;
 return false; }
static struct ai *seen_push(struct ai *g, uintptr_t off, word x) {   // cons x onto seen
 if (!ai_ok(g = ai_push(g, 1, x))) return g;                         // protect x across GC
 if (!ai_ok(g = ai_have(g, Width(struct ai_pair)))) return ai_pop(g, 1);
 struct ai_pair *p = bump(g, Width(struct ai_pair));
 word *slot = seen_slot(g, off);                                   // re-read: GC may move it
 ini_two(p, g->sp[0], *slot);
 *slot = (word) p;
 return ai_pop(g, 1); }
static void seen_pop(struct ai *g, uintptr_t off) {                 // drop the newest entry
 word *slot = seen_slot(g, off);
 *slot = B(*slot); }

static ai_inline struct ai*ioput_two(struct ai*g, word _, uintptr_t off) {
 if (!ai_ok(g = ai_push(g, 1, _))) return g;
 struct ai_str *n;
 // a one-operand `\` pair (`(\ x)`) is quote -> print as 'x; ≥2 operands is a lambda.
 if (symp(A(g->sp[0])) && A(g->sp[0]) != (word) ai_core_of(g) && (n = sym(A(g->sp[0]))->nom) && len(n) == 1 && txt(n)[0] == '\\'
     && twop(B(g->sp[0])) && !twop(BB(g->sp[0]))) {
  g = ioputc(g, '\'');                          // GC here may relocate sp[0]; read AB after
  g = ioputx(g, AB(g->sp[0]), off); }
 else for (g = ioputc(g, '(');; g = ioputc(g, ' '), g->sp[0] = B(g->sp[0])) {
  g = ioputx(g, A(g->sp[0]), off);            // off threaded so nested tables are still tracked
  if (!twop(B(g->sp[0]))) { g = ioputc(g, ')'); break; } }
 return ai_pop(g, 1); }


// Print element i of the array parked at g->sp[0] as a bare number (float ->
// ai_dtoa, integer -> base 10). The element value is read before any ioputc, so
// a GC during printing (string-port growth) that relocates the array is safe;
// callers re-fetch vec(g->sp[0]) each call for the same reason.
static struct ai *ioput_vec_elem(struct ai *g, uintptr_t i) {
 struct ai_vec *v = vec(g->sp[0]);
 if (v->type >= ai_R)
  return ai_dtoa2(g, vec_get_flo(v, i));
 return ioputn(g, vec_get_int(v, i), 10); }

// Print element i of a packed ai_C array (at g->sp[0]) as ~(re im) -- the same
// read-back form as a complex scalar (the `~` reader macro splices into (wave …)).
// re/im are copied to C locals before any ioputc/ai_dtoa2 (which may grow a string
// port and relocate the array).
static struct ai *ioput_carr_elem(struct ai *g, uintptr_t i) {
 ai_flo_t *fp = vec_data(vec(g->sp[0]));
 ai_flo_t re = fp[2*i], im = fp[2*i+1];
 g = ioprintf(g, "~("); g = ai_dtoa2(g, re); g = ioputc(g, ' ');
 g = ai_dtoa2(g, im); return ioputc(g, ')'); }

// Print a rank>=1 array (g->sp[0]) as a constructor expression that reads back to
// the same array -- always a SURFACE form, never the typed `arr` call. A rank-1
// array uses the terse `@(a b …)` sugar (the `@` reader macro splices into
// `(vec a b …)`); rank>=2 uses `(array '(shape) elem …)`. Either way a-type
// re-infers the element type from the printed elements: bare numbers -> z/r,
// ~(re im) -> c, anything else -> o, with symbol/pair elements quoted so eval
// reconstructs them. (An o array of self-evaluating scalars re-reads at its
// natural tier -- the type is inferred, not pinned.) The array may move on a GC
// during printing, so shape/elements are re-fetched from g->sp[0] each step.
static ai_noinline struct ai *ioputx(struct ai *g, intptr_t x, uintptr_t off);

static struct ai *ioput_arr_elem(struct ai *g, uintptr_t i, uintptr_t type, uintptr_t off) {
 if (type == ai_C) return ioput_carr_elem(g, i);
 if (type != ai_O) return ioput_vec_elem(g, i);
 word e = vec_get_obj(vec(g->sp[0]), i);           // kind test only; re-fetched below
 if (symp(e) || twop(e)) g = ioputc(g, '\'');          // quote, so eval rebuilds the element
 return ioputx(g, vec_get_obj(vec(g->sp[0]), i), off); }

static struct ai *ioput_arr(struct ai *g, uintptr_t off) {
 struct ai_vec *v = vec(g->sp[0]);
 uintptr_t rank = v->rank, type = v->type, nelem = vec_nelem(v);
 if (rank == 1 && nelem) {                             // terse rank-1: @(…)
  g = ioputc(g, '@'); g = ioputc(g, '(');
  for (uintptr_t i = 0; ai_ok(g) && i < nelem; i++) {
   if (i) g = ioputc(g, ' ');
   g = ioput_arr_elem(g, i, type, off); }
  return ai_ok(g) ? ioputc(g, ')') : g; }
 // rank>=2 -- and the EMPTY rank-1, which has no @ spelling: (array '(0))
 // reads back to the empty array (a-type of no elements infers z, the same
 // re-inference loss every surface form accepts).
 g = ioprintf(g, "(array '(");                         // (array '(shape) elem …)
 for (uintptr_t i = 0; ai_ok(g) && i < rank; i++) {
  if (i) g = ioputc(g, ' ');
  g = ioputn(g, vec(g->sp[0])->shape[i], 10); }
 g = ioputc(g, ')');
 for (uintptr_t i = 0; ai_ok(g) && i < nelem; i++) {
  g = ioputc(g, ' '); g = ioput_arr_elem(g, i, type, off); }
 return ai_ok(g) ? ioputc(g, ')') : g; }

static ai_inline struct ai*ioput_vec_scalar_float(struct ai*g) {
 return ai_dtoa2(g, (ai_flo_t) flo_get(g->sp[0])); }

// complex -> ~(re im); round-trips by re-evaluation (the `~` reader macro splices
// into (wave re im), and wave is a nif). re/im are read into C locals up front so a
// GC during ai_dtoa2 can't strand the operand.
static ai_inline struct ai*ioput_vec_scalar_complex(struct ai*g) {
 ai_flo_t re = cplx_re(g->sp[0]), im = cplx_im(g->sp[0]);
 g = ioprintf(g, "~(");
 g = ai_dtoa2(g, re);
 g = ioputc(g, ' ');
 g = ai_dtoa2(g, im);
 return ioputc(g, ')'); }

static ai_inline struct ai*ioput_vec(struct ai*g, word _, uintptr_t off) {
 intptr_t rank = vec(_)->rank, type = vec(_)->type;
 if (!ai_ok(g = ai_push(g, 1, _))) return g;
 if (rank == 0 && type == ai_R) g = ioput_vec_scalar_float(g);
 else if (rank == 0 && type == ai_Z) g = ioputn(g, box_get(g->sp[0]), 10);
 else if (rank == 0 && type == ai_C) g = ioput_vec_scalar_complex(g);
 else if (rank >= 1) g = ioput_arr(g, off);
 return ai_pop(g, 1); }

static ai_inline struct ai*ioput_str(struct ai*g, word _) {
 uintptr_t slen = len(_);
 g = ioputc(ai_push(g, 1, _), '"');
 for (uintptr_t i = 0; ai_ok(g) && i < slen; i++) {
  char c = txt(g->sp[0])[i];
  if (c == '\\' || c == '"') g = ioputc(g, '\\');
  else if (c == '\n') g = ioputc(g, '\\'), c = 'n';
  else if (c == '\t') g = ioputc(g, '\\'), c = 't';
  else if (c == '\r') g = ioputc(g, '\\'), c = 'r';
  else if (c == '\0') g = ioputc(g, '\\'), c = '0';
  else if ((unsigned char) c < 32)
   g = ioputc(ioputc(ioputc(g, '\\'), 'x'), ai_digits[(c >> 4) & 0xf]),
   c = ai_digits[c & 0xf];
  g = ioputc(g, c); }
 return ai_pop(ioputc(g, '"'), 1); }

// A symbol's nom is its kind: 0 = a mint (the nameless fresh point), a string
// = interned. Interned syms print bare; a mint prints `(mint 0)` -- which
// re-reads to a FRESH point, the same round-trip the mutables make (a printed
// map is a fresh map): identity is the mint's whole product, so no spelling
// can carry it.
static ai_inline struct ai*ioput_sym(struct ai*g, word _) {
 if (_ == (word) ai_core_of(g)) return ioputcs(g, "()");  // the face of absence
 if (ai_ok(g = ai_push(g, 1, _))) {
  word nom = word(sym(g->sp[0])->nom);
  if (!nom) g = ioprintf(g, "(mint 0)");                    // a mint: fresh on re-read
  else {                                                    // interned: bare name
   g->sp[0] = nom;
   for (uintptr_t l = len(nom), i = 0; ai_ok(g) && i < l;)
     g = ioputc(g, txt(g->sp[0])[i++]); } }
 return ai_pop(g, 1); }


// Maps print as #(k v …), the empty map as (tablet 0); both round-trip.
// A map is mutable and can hold itself, so guard the recursion with the seen
// list. Snapshot k/v into a list first (printing may GC and move the map).
static ai_inline struct ai*ioput_map(struct ai*g, word x, uintptr_t off) {
 if (seen_member(g, off, x)) return ioputcs(g, "<cycle>");
 if (!ai_ok(g = seen_push(g, off, x))) return g;        // sp[0] = seen list head (= x)
 x = A(*seen_slot(g, off));                             // reload x: seen_push may have GC'd
 if (!ai_ok(g = ai_push(g, 1, x))) return seen_pop(g, off), g;   // sp[0] = map
 uintptr_t cap = map_cap(g->sp[0]), n = map_len(g->sp[0]);
 if (!ai_ok(g = ai_have(g, n * 2 * Width(struct ai_pair)))) return seen_pop(ai_pop(g, 1), off), g;
 word *s = map_slots(g->sp[0]);                         // re-fetch after possible GC
 struct ai_pair *p = bump(g, n * 2 * Width(struct ai_pair));
 word list = nil;
 for (uintptr_t i = cap; i;)
  if (s[2 * --i] != map_gap) {
   struct ai_pair *kv = p++;
   ini_two(kv, s[2 * i], s[2 * i + 1]);                 // (k . v)
   ini_two(p, (word) kv, list), list = (word) p++; }    // cons onto the snapshot
 fs0(g) = list;
 if (!twop(fs0(g))) g = ioputcs(g, "(tablet 0)");             // the empty map prints (tablet 0): "#()" reads as #0, the 0-box
 else {
  if (ai_ok(g = ioprintf(g, "#("))) for (bool sp = false;;) {
   if (sp) g = ioputc(g, ' ');
   sp = true;
   g = ioputx(g, AA(ai_core_of(g)->sp[0]), off);
   g = ioputc(g, ' '); g = ioputx(g, BA(ai_core_of(g)->sp[0]), off);
   ai_core_of(g)->sp[0] = B(ai_core_of(g)->sp[0]);
   if (!ai_ok(g) || !twop(g->sp[0])) break; }
  g = ai_ok(g) ? ioputc(g, ')') : g; }
 g = ai_pop(g, 1);
 return seen_pop(g, off), g; }

// A bignum prints in base 10 (with sign). ai_big_dec renders it to a fresh
// string (repeated divide-by-10 of a heap-local copy); we then emit the bytes,
// re-fetching sp[0] each step since ioputc may grow a string port and GC.
static ai_inline struct ai*ioput_big(struct ai*g, word x) {
 if (!ai_ok(g = ai_push(g, 1, x))) return g;
 g = ai_big_dec(g);
 for (uintptr_t i = 0, n = ai_ok(g) ? len(g->sp[0]) : 0; ai_ok(g) && i < n; i++)
  g = ioputc(g, txt(g->sp[0])[i]);
 return ai_pop(g, 1); }

// emit a C string literal byte-for-byte.
static struct ai *ioputcs(struct ai *g, char const *s) {
 for (; ai_ok(g) && *s; s++) g = ioputc(g, *s);
 return g; }

// --- partial-application introspection (mirrors kernel/vm.c lvm_cur/lvm_unc) ---
// A partial-app closure is a text whose head is lvm_unc (one more arg wanted)
// or [lvm_cur n][lvm_unc …] (more wanted). Each lvm_unc cell holds a captured
// arg at [1] and a link at [2] that points either to the next (older) closure's
// unc cell or, for the last one, two cells into the underlying function's body --
// so the base function value is terminal_link-2 and the captured args are the
// chain of [1] fields, newest first. The chain survives GC (interior pointers are
// relocated), so callers re-walk from the parked, possibly-moved closure.
static bool fn_partialp(union u *k) {
 return k[0].ap == lvm_unc || (k[0].ap == lvm_cur && k[2].ap == lvm_unc); }
static ai_inline union u *fn_unc0(union u *k) {
 return k[0].ap == lvm_cur ? k + 2 : k; }       // first unc cell
static union u *fn_base(union u *k, int *nargs) { // base value + captured-arg count
 union u *u = fn_unc0(k), *link;
 int n = 0;
 for (;;) { link = u[2].m; n++; if (link[0].ap != lvm_unc) break; u = link; }
 return *nargs = n, link - 2; }
static word fn_arg(union u *k, int i, int nargs) { // i-th arg in application order
 union u *u = fn_unc0(k);
 for (int w = nargs - 1 - i; w > 0; w--) u = u[2].m;
 return u[1].x; }

static struct ai *ioput_fn_body(struct ai *g, word x, uintptr_t off);

// the in-pool source \-expr stashed at value[-1] by a compiled lambda, or 0.
// Only an ala/k0s lambda reserves that leading cell, so its value pointer sits one past
// the allocation start. A k0 top-level wrap, a partial-app (lvm_cur/unc), a continuation,
// or an opaque handle puts its value AT the start -- no leading cell -- so reading value[-1]
// there reads the neighbouring object: uninitialised/foreign (flaky to valgrind, and garbage
// that looked like an in-pool pair would spuriously read back as a source). Probe the tag,
// which records the true start, instead of reading value[-1]: ttag sounds only defined text
// cells. value > start <=> a reserved leading cell exists. (fn_partialp is a cheap fast
// reject so the common curried-closure case skips the tag sound.)
static word fn_src(struct ai *c, union u *k, word x) {
 if (!(ptr(x) > ptr(c) && ptr(x) < ptr(c) + c->len) || fn_partialp(k)) return 0;
 if (k == tag_head(ttag(c, k))) return 0;       // value at allocation start: no leading src cell
 word s = k[-1].x;
 return lamp(s) && ptr(s) >= ptr(c) && ptr(s) < ptr(c) + c->len && twop(s) ? s : 0; }

// --- de Bruijn canonical printing of a lambda's source ---------------------
// A \-bound variable prints as $<level> where the level (de Bruijn LEVEL:
// outermost binder 0, counting inward, left-to-right within a \-group) is
// rendered in a-z shortlex ($a,$b,…,$z,$aa,…), so a-equivalent lambdas print
// identically -- (\ x x) and (\ y y) both -> (\ $a $a) -- and inspect agrees
// with = (same binder convention as salpha). Free/global/:-bound vars keep
// their names; quoted data (one-operand \) is shared verbatim, never renamed.
// lam_canon rebuilds the source with bound syms replaced: it pre-interns the
// d<lvl> names and pre-reserves the cell count, so the rebuild itself allocates
// nothing and cannot GC -- pointers into the parked source stay stable. The
// names are interned plain symbols (d0,d1,…) so the printed form round-trips.
struct lam_bv { word sym; uintptr_t lev; struct lam_bv *up; };  // a \-binder in scope
static ai_inline bool lam_head(struct ai *g, word a) {        // is a the symbol \ ?
 struct ai_str *nm;                                          // the core heads no \ (identity-guarded: its nom slot is live VM state)
 return symp(a) && a != (word) ai_core_of(g) && (nm = sym(a)->nom) && len(nm) == 1 && txt(nm)[0] == '\\'; }
static ai_inline bool lam_isp(struct ai *g, word x) {         // (\ b.. body): >=2 operands
 return twop(x) && lam_head(g, A(x)) && twop(B(x)) && twop(BB(x)); }
static ai_inline bool lam_quotep(struct ai *g, word x) {       // (\ datum): exactly 1 operand
 return twop(x) && lam_head(g, A(x)) && twop(B(x)) && !twop(BB(x)); }
static uintptr_t lam_cells(struct ai *g, word x) {             // pairs the rebuild will bump
 return !twop(x) || lam_quotep(g, x) ? 0 : 1 + lam_cells(g, A(x)) + lam_cells(g, B(x)); }
static uintptr_t lam_depth(struct ai *g, word x, uintptr_t d) {  // max binder level + 1 (= # d-syms)
 if (!twop(x) || lam_quotep(g, x)) return d;
 if (lam_isp(g, x)) {
  word o = B(x); uintptr_t nb = 0;
  while (twop(B(o))) nb++, o = B(o);                          // every operand but the last = a binder
  uintptr_t here = d + nb, body = lam_depth(g, A(o), here);
  return here > body ? here : body; }
 uintptr_t a = lam_depth(g, A(x), d), b = lam_depth(g, B(x), d);
 return a > b ? a : b; }
static word lam_build_ops(struct ai *g, word o, struct lam_bv *sc, uintptr_t d, uintptr_t D);
static word lam_build(struct ai *g, word x, struct lam_bv *sc, uintptr_t d, uintptr_t D) {
 if (!twop(x)) {                                              // atom: a bound sym -> d<lev>, else as-is
  if (symp(x)) for (struct lam_bv *p = sc; p; p = p->up) if (p->sym == x) return g->sp[D - 1 - p->lev];
  return x; }
 if (lam_quotep(g, x)) return x;                              // quoted data: share, do not descend
 word a, b;
 if (lam_isp(g, x)) a = A(x), b = lam_build_ops(g, B(x), sc, d, D);  // share \, rename the operand spine
 else a = lam_build(g, A(x), sc, d, D), b = lam_build(g, B(x), sc, d, D);
 struct ai_pair *p = bump(g, Width(struct ai_pair));
 return ini_two(p, a, b), (word) p; }
static word lam_build_ops(struct ai *g, word o, struct lam_bv *sc, uintptr_t d, uintptr_t D) {
 word car, rest;
 if (!twop(B(o))) car = lam_build(g, A(o), sc, d, D), rest = nil;  // last operand = the body
 else { struct lam_bv fr = { A(o), d, sc };                        // a binder, level d, in scope for the rest
        car = g->sp[D - 1 - d], rest = lam_build_ops(g, B(o), &fr, d + 1, D); }
 struct ai_pair *p = bump(g, Width(struct ai_pair));
 return ini_two(p, car, rest), (word) p; }
// sp[0] = a lambda's source \-expr; replace it with the de Bruijn-renamed copy.
static struct ai *lam_canon(struct ai *g) {
 word s = g->sp[0];
 if (!lam_isp(g, s)) return g;                               // not a lambda -> leave as-is
 uintptr_t P = lam_cells(g, s), D = lam_depth(g, s, 0);
 for (uintptr_t i = 0; i < D; i++) {                          // push d0,d1,… (de Bruijn level); src parked below
  char b[24], *e = b + sizeof b; uintptr_t n = i;            // interned d<lvl> -> reads back as the same sym
  *--e = 0;
  do { *--e = '0' + n % 10; } while (n /= 10);
  *--e = 'd';
  if (!ai_ok(g = intern(ai_strof(g, e)))) return g; }
 if (!ai_ok(g = ai_have(g, P * Width(struct ai_pair)))) return g;  // reserve cells: the last possible GC
 word r = lam_build(g, g->sp[D], 0, 0, D);                     // alloc-free, GC-free; g->sp stays put
 return g->sp[D] = r, g->sp += D, g; }

// Print a function value. Like vec/cplx/hash it's a `,`-prefixed value form (so it
// reads back via uq=identity): ,(base arg…) for a partial application / closure,
// ,name for a builtin, ,(\ …) for a compiled lambda (its stored source). An opaque
// text (continuation, top-level wrap) has no constructor form, so it prints as the
// opaque, re-parsable token ,thd@<addr>. The leading , is emitted once here; body w/o it.
static struct ai *ioput_fn(struct ai *g, word x, uintptr_t off) {
 union u *k = cell(x);
 bool reprp = fn_partialp(k) || ai_nif_name(x) || fn_src(ai_core_of(g), k, x);
 return reprp ? ioput_fn_body(g, x, off) : ioprintf(g, "\\%z", x); }

// Render a function as a bare constructor expression (NO leading ,). Detection
// order matters: a bare multi-arg lambda and a partial-app both have a lvm_cur
// head, and a nif's value[-1] is undefined static data. The partial-app base
// recurses here (not ioput_fn) so it doesn't get its own comma.
static struct ai *ioput_fn_body(struct ai *g, word x, uintptr_t off) {
 struct ai *c = ai_core_of(g);
 union u *k = cell(x);
 if (fn_partialp(k)) {                              // (base arg…)
  if (!ai_ok(g = ai_push(g, 1, x))) return g;         // park: GC relocates the closure
  int na; fn_base(cell(g->sp[0]), &na);
  g = ioputc(g, '(');
  { union u *bk = cell(g->sp[0]); int n2;           // base re-derived after each ioputc
    g = ioput_fn_body(g, (word) fn_base(bk, &n2), off); }
  for (int i = 0; ai_ok(g) && i < na; i++) {
   g = ioputc(g, ' ');                              // separate stmt: re-read arg after GC
   g = ioputx(g, fn_arg(cell(g->sp[0]), i, na), off); }
  return ai_pop(ai_ok(g) ? ioputc(g, ')') : g, 1); }
 char const *nm = ai_nif_name(x);                    // builtin -> name
 if (nm) return ioputcs(g, nm);
 word s = fn_src(c, k, x);                          // compiled lambda -> source \-expr
 if (!s) return ioprintf(g, "\\%z", x);
 if (!ai_ok(g = ai_push(g, 1, s))) return g;          // park source across lam_canon's allocs
 g = lam_canon(g);                                   // sp[0] := de Bruijn-renamed copy
 if (ai_ok(g)) g = ioputx(g, g->sp[0], off);
 return ai_ok(g) ? ai_pop(g, 1) : g; }

static ai_noinline struct ai *ioputx(struct ai *g, intptr_t x, uintptr_t off) {
 if (charmp(x)) return ioprintf(g, "%d", getcharm(x));
 if (!datp(x)) return mapp(x) ? ioput_map(g, x, off) : ioput_fn(g, x, off);
 // Maps are the only mutable/self-referential value, and ioput_map guards its
 // own recursion (the seen list); the data kinds below are acyclic.
 switch (typ(x)) {
   default: __builtin_trap();
   case KTwo:  return ioput_two(g, x, off);
   case KVec:  return ioput_vec(g, x, off);
   case KSym:  return ioput_sym(g, x);
   case KString: return ioput_str(g, x);
   case KBig:  return ioput_big(g, x); } }

// Establish a fresh seen-list slot at the bottom of the print region, print, then
// restore the original stack height (discarding the slot and the whole list).
static ai_inline struct ai *gfputx(struct ai *g, struct ai_io *o, intptr_t x) {
 struct ai *c = ai_core_of(g);
 c->io = o;
 uintptr_t base = topof(c) - c->sp;                 // original height (GC-invariant)
 if (!ai_ok(g = ai_push(g, 1, nil))) return g;        // the seen-list slot
 c = ai_core_of(g);
 g = ioputx(g, x, topof(c) - c->sp);                // offset of the slot from the top
 c = ai_core_of(g);
 return c->sp = topof(c) - base, g; }               // restore original stack height

// AI slop alert....
//

static struct ai* ai_dtoa2(struct ai*g, ai_flo_t v) {
 int const max_frac = sizeof(ai_flo_t) == 4 ? 7 : 15;
 if (v != v) return ioputs(g, "ieee-nan");
 if (v < 0) g = ioputc(g, '-'), v = -v;
 if (v > dtoa_inf) return ioputs(g, "ieee-inf");
 int exp = 0;
 bool sci = false;
 if (v != 0 && (v >= dtoa_sci_hi || v < dtoa_sci_lo)) {
  sci = true;
  while (v >= 10) v /= 10, exp++;
  while (v < 1)  v *= 10, exp--; }
 // integer part, lsb-first then reversed
 word ip = (word) v;
 ai_flo_t frac = v - (ai_flo_t) ip;
 char ib[24];
 int ib_n = 0;
 if (ip == 0) ib[ib_n++] = '0';
 while (ip) ib[ib_n++] = '0' + ip % 10, ip /= 10;
 while (ib_n > 0) g = ioputc(g, ib[--ib_n]);
 // fractional digits; in non-scientific mode always emit at least ".0"
 // so the result is visually distinguishable from a fixnum.
 bool emit_frac = frac > 0 || !sci;
 if (emit_frac) {
  char fb[16];
  int fb_n = 0;
  for (int i = 0; i < max_frac && frac > 0; i++) {
   frac *= 10;
   int d = (int) frac;
   if (d > 9) d = 9;
   fb[fb_n++] = '0' + d;
   frac -= d; }
  while (fb_n > 0 && fb[fb_n - 1] == '0') fb_n--;
  if (!sci && fb_n == 0) fb[fb_n++] = '0';      // force "X.0" for ints
  if (fb_n > 0) {
   g = ioputc(g, '.');
   for (int i = 0; i < fb_n; i++) g = ioputc(g, fb[i]); } }
 if (sci) {
  g = ioputc(g, 'e');
  if (exp < 0) g = ioputc(g, '-'), exp = -exp;
  char eb[8]; int eb_n = 0;
  if (exp == 0) eb[eb_n++] = '0';
  while (exp) eb[eb_n++] = '0' + exp % 10, exp /= 10;
  while (eb_n > 0) g = ioputc(g, eb[--eb_n]); }
 return g; }

// (feof port) — -1 if at end of stream, nil otherwise.
lvm(lvm_feof) {
 if (iop(Sp[0])) {
  g->io = (struct ai_io*) Sp[0];
  Pack(g);
  if (!ai_ok(g = zeof(g))) return ghelp(g);
  Unpack(g);
  Sp[0] = g->b ? putcharm(1) : nil; }
 return Ip++, Continue(); }

// (fgetc port) — like (getc _) but on an explicit port. Cooperative wait
// uses the port's own fd. A non-port reads as an already-empty stream: EOF
// (-1), not the echoed argument, so a (fgetc ...)-until-(-1) loop over a
// misused or absent port (e.g. `open` on a host with no filesystem) is
// bounded instead of spinning forever on a value that never equals -1.
lvm(lvm_fgetc) {
 if (iop(Sp[0])) {
  struct ai_io *i = (struct ai_io*) Sp[0];
  if (!ai_ready(getcharm(i->fd))) {
   g->next_wait_fd = getcharm(i->fd);
   return Ap(lvm_yield_sw, g); }
  Pack(g);
  g->io = i;
  if (!ai_ok(g = zgetc(g))) return ghelp(g);
  Unpack(g);
  Sp[0] = putcharm(g->b); }
 else Sp[0] = putcharm(EOF);
 return Ip++, Continue(); }

// (fungetc port byte) — push back one byte, return the byte.
lvm(lvm_fungetc) {
 if (iop(Sp[0])) {
  struct ai_io *i = (struct ai_io*) Sp[0];
  Pack(g);
  g->io = i;
  if (!ai_ok(g = zungetc(g, getcharm(g->sp[1])))) return ghelp(g);
  Unpack(g); }
 return Sp++, Ip++, Continue(); }

// Finalizer for heap stream ports: extract the fd and ask the frontend to
// close it. Runs inside GC (run_finalizers); fz->p still points at the
// from-space port so its fields are readable. Skip if fd < 0 — that means
// either the port was already closed explicitly (fd mutated to a synth
// sentinel) or the caller wrapped a non-OS fd.
static void io_close(void *p) {
 intptr_t fd = getcharm(((struct ai_io*)p)->fd);
 if (fd >= 0) ai_fd_close(fd); }

// Heap-allocate a stream port for the given OS fd. Pushes the port pointer
// on Sp[0] and registers io_close as its finalizer. The fd >= 0 path of
// the dispatcher routes through ai_fd_port_vt, so the host's read/write
// methods see this port like any other.
struct ai *ai_io_alloc(struct ai *g, int fd) {
 uintptr_t const n = Width(struct ai_io);
 if (ai_ok(g = ai_have(g, n + Width(struct ai_tag) + Width(struct ai_fz) + 1))) {
  union u *k = bump(g, n + Width(struct ai_tag));
  struct ai_io *io = (struct ai_io*) k;
  io->ap = lvm_port_io;
  io->fd = putcharm(fd);
  io->ungetc_buf = putcharm(EOF);
  io->eof_seen = putcharm(false);
  *--g->sp = (word) tagtext(k, n);            // stack slot reserved by the +1 in have()
  struct ai_fz *z = bump(g, Width(struct ai_fz));
  z->p = k, z->fn = io_close, z->next = g->fz, g->fz = z; }
 return g; }

static struct ai *grbufg(struct ai *g, uintptr_t len);

// A token is a plain decimal integer iff it is [+-]?[0-9]+ with no leading-zero
// prefix (so "0x.." hex and "0.." octal stay with strtol, and bare "0" parses
// as decimal). These read at full precision through ai_big_read_dec.
static ai_inline bool is_dec_int(char const *s, uintptr_t n) {
 uintptr_t i = (n && (s[0] == '-' || s[0] == '+')) ? 1 : 0;
 if (i >= n) return false;                       // a lone sign is a symbol
 if (s[i] == '0' && n - i > 1) return false;     // leading zero -> let strtol decide
 for (; i < n; i++) if (s[i] < '0' || s[i] > '9') return false;
 return true; }

static struct ai *ioparse(struct ai *g, bool multi);
static ai_inline struct ai *ioread1sym(struct ai*g, int c), *ioread1str(struct ai*g);
struct ai *ai_reads(struct ai *g, struct ai_io* i) { return ai_core_of(g)->io = i, ioparse(g, true); }
struct ai *ai_read1(struct ai*g, struct ai_io *i) { return ai_core_of(g)->io = i, ioparse(g, false); }

static struct ai *grbufg(struct ai *g, uintptr_t len) {
 if (ai_ok(g = str0(g, 2 * len)))
  memcpy(txt(g->sp[0]), txt(g->sp[1]), len),
  g->sp[1] = g->sp[0],
  g->sp++;
 return g; }

static ai_noinline double strtod_wrap(struct ai*g, word x) {
 struct ai_str *s = str(x);
 if (!strp(x) || !s->len) return NAN;
 char *e, *b = off_pool(g);
 memcpy(b, s->bytes, s->len);
 b[s->len] = 0;
 double r = strtod(b, &e);
 return e != b && *e == 0 ? (ai_flo_t) r : (ai_flo_t) NAN; }

// (flo s) — parse a l string as a decimal float. Returns a rank-0
// f64 box if the entire string parses, else nil. Used by the l-side
// reader in repl.l to match the C reader's strtol → strtod → intern
// cascade on float-shaped tokens.
lvm(lvm_real) {
 word x = Sp[0];
 double d = strtod_wrap(g, x);
 if (d != d) return Sp[0] = nil, Ip += 1, Continue();
 uintptr_t req = b2w(sizeof(struct ai_vec) + sizeof(ai_flo_t));
 Have(req);
 struct ai_vec *r = ini_scalar((struct ai_vec*) Hp, ai_R);
 Hp += req;
 flo_put(r->shape, (ai_flo_t) d);
 Sp[0] = word(r);
 return Ip++, Continue(); }

lvm(lvm_read) {
 Ip++;
 if (!iop(Sp[0])) return Sp++, Continue();
 struct ai_io *i = (struct ai_io*) Sp[0];
 uintptr_t depth = topof(g) - Sp;
 Pack(g);
 if (ai_ok(g = ai_read1(g, i))) g->sp[2] = g->sp[0], g->sp += 2;
 else {
  struct ai *c = ai_core_of(g); // reset stack on parse fail
  c->sp = (word*) c + c->len - depth;
  switch (ai_code_of(g)) {
   default: return ghelp(g);                          // scare: condition data per raise site
   case ai_status_more: case ai_status_eof:
    // The more bit routes control through the help continuation: push the read protocol's
    // resume text under [port sentinel] and raise -- the help function (or
    // raise_c's default) decides flow from the bits. Headroom for the push is
    // the parse ctx frame, which exists wherever more/eof can arise.
    *--c->sp = word(c->ip);
    return ghelp2(c, ai_code_of(g)); } }
 return Unpack(g), Continue(); }

// (string x): a charlist -> the string of those bytes; a named symbol -> its
// name string; a fixnum -> the one-byte string of its low byte. Identity on any
// other type (strings, anonymous syms, nil, ...).
lvm(lvm_string) {
 word x = Sp[0];
 if (x == nil) return Ip++, Continue();             // nil is the empty string (0)
 if (charmp(x)) {                                     // fixnum -> one-byte string
  uintptr_t req = str_type_width + b2w(1);
  Have(req);
  struct ai_str *s = (void*) Hp;
  Hp += req;
  ini_str(s, 1);
  txt(s)[0] = (char) getcharm(x);
  return Sp[0] = word(s), Ip++, Continue(); }
 if (symp(x)) {                                      // named symbol -> name string, else identity
  if (x == (word) ai_core_of(g)) return Ip++, Continue();  // the core: nameless, like a mint -> identity (its atom slots are never read)
  word y = x;
  while (symp(y) && sym(y)->nom && symp(word(sym(y)->nom))) y = word(sym(y)->nom);
  word nom = word(sym(y)->nom);
  if (nom && strp(nom)) Sp[0] = nom;
  return Ip++, Continue(); }
 if (twop(x)) {                                      // charlist -> string
  uintptr_t n = llen(x), req = str_type_width + b2w(n);
  Have(req);
  struct ai_str *s = (void*) Hp;
  Hp += req;
  ini_str(s, n);
  for (uintptr_t i = 0; n--; x = B(x)) txt(s)[i++] = (char) getcharm(A(x));
  return Sp[0] = word(s), Ip++, Continue(); }
 return Ip++, Continue(); }                          // any other type: identity

////
/// " the parser "
//
//
// get the next significant character from the stream. mm-protect the C
// `i` parameter across the multiple port_* calls — each push triggers a
// have() check that may GC and move heap ports.

// Comments: `;` runs to end of line; `#!` (shebang) runs to end of line; a bare
// `#` is significant (the len reader macro), as is any other non-whitespace char.
static struct ai* ai_z_getc(struct ai*g) {
 while (ai_ok(g = zgetc(g))) switch (g->b) {
  default: return g;
  case '\n': case '\r': continue;
  case 0: case ' ': case '\t': case '\f': continue;
  case '#':                                          // #! is a line comment; bare # is significant (the hash macro)
   if (!ai_ok(g = zgetc(g))) return g;
   if (g->b != '!') {                                // not a shebang: push back, return #
    if ((int) g->b != EOF && !ai_ok(g = zungetc(g, g->b))) return g;
    return g->b = '#', g; }
   while (ai_ok(g = zeof(g)) && !g->b && ai_ok(g = zgetc(g)) && g->b != '\n' && g->b != '\r');
   continue;
  case ';':                                          // line comment: run to end of line
   while (ai_ok(g = zeof(g)) && !g->b && ai_ok(g = zgetc(g)) && g->b != '\n' && g->b != '\r');
   continue; }
 return g; }

// --- one non-recursive STRUCTURAL reader for ai_read1 (multi=0) and ai_reads
// (multi=1) --- it knows tokens, parens, strings, and the value surface (the
// printer's read-back contract: ' ` , @ # ~), and nothing else: operator
// sigils read as plain symbols, factored at COMPILE time by the opfix pass
// (prel.l) -- so reading is environment-free and the same machinery
// serves data (read) and code (ev = opfix after read).
// `ctx` (kept at sp[0]) is an explicit stack of frames, top = car, so the nesting
// that used to recurse in C now lives on the l heap (and rides GC). A frame is
// either a *list accumulator* — a pair (head . tail) holding the elements read so
// far in source order, ((nil . nil) when empty), built in place by appending at
// `tail` so no reverse pass is needed — or a *reader-macro* — the wrap symbol \ qq
// uq uqs hash vec plex wave, recognised by symp. A finished datum is `delivered`
// to the top frame: appended to a list, or wrapped/spliced and re-delivered; with
// no frame left it is the result. Everything lives on the l stack so GC relocates
// it across the allocs that reading does.

static ai_inline struct ai *push_frame(struct ai *g) {     // push an empty (head . tail) accumulator
 return gxl(gxl(ai_push(g, 2, nil, nil))); }    // ctx' = ((nil . nil) . ctx)
static ai_inline struct ai *push_wrap(struct ai *g, char const *nom) {
 return gxl(intern(ai_strof(g, nom))); }        // ctx' = (wrapsym . ctx)
// the LEXER LAW, operator half. a token led by an operator (punctuation)
// char is a maximal run of operator chars -- a SIGIL, read as one plain
// symbol; the opfix compile pass (prel.l) factors it against
// book['operators] later, so the reader is purely structural. a run stops
// at name chars (alnum/_), whitespace, delimiters, and the value-surface
// chars (' ` , # @ ~) -- those break runs, though a NAME-led token may
// still contain @ ~ $ ! . and a trailing/internal ' (the prime: x', n'';
// a LEADING ' is quote, dispatched before the name sounder -- see ioread1sym).
static ai_inline bool op_break(int c) {
 return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
        c == '_' || c == ' ' || c == '\n' || c == '\t' || c == '\r' || c == '\f' ||
        c == ';' || c == '#' || c == '(' || c == ')' || c == '[' || c == ']' ||
        c == '{' || c == '}' || c == '"' || c == '\'' || c == '`' || c == ',' ||
        c == '@' || c == '~' || c == 0 || c == EOF || c >= 128; }
// read a maximal operator run starting with c -> the interned symbol. a
// trailing '-' immediately before a digit is the next number's sign, not
// part of the run: the run is shortened by one and '-' re-dispatched via
// *pending (the digit is ungot for ioread1sym), so `!-5` is ! then -5.
static ai_inline struct ai *ioread1sym(struct ai*g, int c);
static struct ai *ioread1op(struct ai *g, int c, int *pending) {
 uintptr_t n = 1, lim = sizeof(intptr_t);
 if (ai_ok(g = str0(g, sizeof(word))))
  for (txt((struct ai_str*) g->sp[0])[0] = c; ai_ok(g); g = grbufg(g, lim), lim *= 2)
   for (; n < lim; txt(g->sp[0])[n++] = c) {
    if (!ai_ok(g = zgetc(g))) return g;
    c = g->b;
    if (!op_break(c)) continue;
    if (!ai_ok(g = zungetc(g, c))) return g;
    struct ai_str *s = str(g->sp[0]);
    if (n > 1 && txt(s)[n - 1] == '-' && c >= '0' && c <= '9')
     n -= 1, *pending = '-';
    len(s) = n;
    return intern(g); }
 return g; }
// recognise the splicing reader-macro wraps -- `#` (interned `hash`) and `@`
// (interned `vec`) -- so a list operand splices into the constructor call
// instead of being wrapped: see the deliver loop in ioparse.
static ai_inline bool symeq(word x, char const *nm, uintptr_t n) {
 struct ai_str *s = symp(x) ? sym(x)->nom : 0;
 if (!s || !strp(word(s)) || s->len != n) return false;
 for (uintptr_t i = 0; i < n; i++) if (s->bytes[i] != nm[i]) return false;
 return true; }
static ai_inline bool hashsym(word x) { return symeq(x, "hash", 4); }
static ai_inline bool splicesym(word x) { return hashsym(x) || symeq(x, "tuple", 5) || symeq(x, "wave", 4) || symeq(x, "list", 4); }

static struct ai *ioparse(struct ai *g, bool multi) {
 // multi: ctx starts with one open accumulator (collects all top-level datums in
 // source order); read1: ctx starts empty (returns the first complete datum).
 g = multi ? gxl(gxl(ai_push(g, 3, nil, nil, nil))) : ai_push(g, 1, nil);
 int pending = 0;
 for (;;) {
  int c, c2 = EOF;
  if (pending) c = pending, pending = 0;               // a '-' shed from an operator run
  else {
   if (!ai_ok(g = ai_z_getc(g))) return g;
   c = g->b; }
  switch (c) {
   case '(': case '[': case '{': g = push_frame(g); continue;   // [ ] { } are () synonyms
   case '~':                                            // ~(re im)->(wave re im) [construct]; ~x->(conj x)
    if (!ai_ok(g = zgetc(g))) return g;                 // peek the char after ~: `(` -> splice into wave (build
    c2 = g->b;                                         // a complex / curry); anything else -> monadic lift/conj
    if (c2 != EOF) g = zungetc(g, c2);                 // (conj: real r -> ~(r 0); complex z -> conj z)
    g = push_wrap(g, c2 == '(' ? "wave" : "conj"); continue;
   case ',':                                            // unquote / unquote-splice
    if (!ai_ok(g = zgetc(g))) return g;
    if ((c2 = g->b) == '@') { g = push_wrap(g, "uqs"); continue; }
    if (c2 != EOF) g = zungetc(g, c2);
    g = push_wrap(g, "uq"); continue;
   // the value surface -- the printer's read-back contract, environment-free,
   // so it lives here in the structural reader (with ~ and , above), NOT in
   // the operator table: ' ` # @ each wrap the next datum.
   case '\'': g = push_wrap(g, "\\"); continue;        // quote: 'x = (\ x)
   case '`':                                            // ` quasiquote; `` (double) -> (list ...) the element-eval list ctor
    if (!ai_ok(g = zgetc(g))) return g;                 // peek: a second ` -> the list constructor (each element evaluated)
    c2 = g->b;
    if (c2 == '`') { g = push_wrap(g, "list"); continue; }   // ``(a b c) -> (list a b c); resolves nested-qq too
    if (c2 != EOF) g = zungetc(g, c2);
    g = push_wrap(g, "qq"); continue;
   case '#': g = push_wrap(g, "hash"); continue;       // (#! comments die in ai_z_getc)
   case '@': g = push_wrap(g, "tuple"); continue;
   case ')': case ']': case '}':
    if (nilp(g->sp[0])) return encode(ai_core_of(g), ai_status_eof);   // stray ) / read1
    if (symp(A(g->sp[0]))) return encode(ai_core_of(g), ai_status_more); // wrap wants its operand
    g = ai_push(g, 1, AA(g->sp[0]));                    // d = head of the closed frame
    if (ai_ok(g)) {
     if (nilp(g->sp[0])) g->sp[0] = (word) ai_core_of(g);         // empty () IS the zero point (not the number 0)
     g->sp[1] = B(g->sp[1]); }                          // pop the closed frame
    break;                                             // -> deliver d
   case EOF:
    if (nilp(g->sp[0])) return encode(ai_core_of(g), ai_status_eof);
    if (!(multi && nilp(B(g->sp[0])) && !symp(A(g->sp[0]))))
     return encode(ai_core_of(g), ai_status_more);       // unclosed list / pending wrap
    g = ai_push(g, 1, AA(g->sp[0]));                    // close the top accumulator -> its head
    if (ai_ok(g)) g->sp[1] = B(g->sp[1]);
    break;
   case '"': g = ioread1str(g); break;
   default: {                                          // operator run, else a symbol/number token
    bool opp = c != '-' && c != '+' && !op_break(c);
    if (!opp && (c == '-' || c == '+')) {              // +/- lead numbers and names (kebab), EXCEPT
     if (!ai_ok(g = zgetc(g))) return g;                // glued to a constructor datum -- +'(..),
     int cpm = g->b;                                   // -(f x), +@(..), +~(..), +"s", +#(..) --
     if (cpm != EOF && !ai_ok(g = zungetc(g, cpm))) return g;  // where they are monadic runs (net, neg)
     opp = cpm == '(' || cpm == '\'' || cpm == '"' ||
           cpm == '@' || cpm == '~' || cpm == '#'; }
    if (opp) {
     int lead = c;                                     // the run's first char: '\' never fuses (form space)
     g = ioread1op(g, c, &pending);                    // sigil: a plain symbol, factored by opfix later
     if (!ai_ok(g)) return g;
     if (lead == '\\') break;
     // the VALENCE LAW, reader half: a run GLUED to a following datum is
     // monadic -- the run itself becomes a wrap under a `mono` wrap, so the
     // next datum d delivers as (mono (run d)); opfix factors the run
     // against book['monadics] (glued is monadic, spaced is dyadic). a shed
     // '-' (pending) means a number follows: glued by definition. the
     // emission is a plain list, so data round-trips through show.
     int c3 = EOF;
     if (!pending) {
      if (!ai_ok(g = zgetc(g))) return g;
      c3 = g->b;
      if (c3 != EOF && !ai_ok(g = zungetc(g, c3))) return g; }
     // HEAD POSITION NEVER FUSES: a run right after an open delimiter is
     // the form's operator -- the section/escape law, and what keeps
     // minified source ((:(co ..) like (: (co ..)) legal. head = the top
     // frame's head is still nil; a pending wrap (quote etc) is a symbol on
     // the ctx, not a frame, and does not suppress fusion.
     word rctx = g->sp[1];
     bool headp = twop(rctx) && twop(A(rctx)) && nilp(A(A(rctx)));
     if (!headp &&
         (pending || !(c3 == ' ' || c3 == '\n' || c3 == '\t' || c3 == '\r' ||
                       c3 == '\f' || c3 == ';' || c3 == ')' || c3 == ']' ||
                       c3 == '}' || c3 == 0 || c3 == EOF))) {
      g = intern(ai_strof(g, "mono"));                  // [mono run ctx]
      if (!ai_ok(g)) return g;
      word w = g->sp[1]; g->sp[1] = g->sp[2], g->sp[2] = w;  // [mono ctx run]
      g = gxl(g);                                      // [(mono . ctx) run]
      if (!ai_ok(g)) return g;
      w = g->sp[0], g->sp[0] = g->sp[1], g->sp[1] = w; // [run (mono . ctx)]
      g = gxl(g);                                      // ctx' = (run mono . ctx)
      if (!ai_ok(g)) return g;
      continue; }                                      // the wraps take the next datum
     break; }
    g = ioread1sym(g, c);                              // name/number ('-'/'+' lead numbers, -> and \names etc.)
    if (!ai_ok(g)) return g;
    break; } }
  if (!ai_ok(g)) return g;
  // deliver the datum at sp[0] into the frame stack at sp[1]
  for (bool done = false; ai_ok(g) && !done; ) {
   if (nilp(g->sp[1])) {                               // no frame left: the result
    g->sp[1] = g->sp[0], g->sp++;
    return g; }
   if (symp(A(g->sp[1]))) {                            // reader-macro wrap, pop the wrap frame
    if (splicesym(A(g->sp[1])) &&
        (twop(g->sp[0]) ||
         (nilp(g->sp[0]) && !hashsym(A(g->sp[1]))))) { // @()/@0 splice empty; #()/#0 wrap (a box)
     g = gxl(ai_push(g, 1, A(g->sp[1])));               // #(k v …)/@(e …)/@() : splice -> (sym . d)
     if (ai_ok(g)) g->sp[1] = B(g->sp[1]); }
    else {                                             // 'x `x ,x  #x %atom/@atom -> (wrapsym d)
     g = gxr(ai_push(g, 1, nil));                       // (d . nil)
     g = gxl(ai_push(g, 1, ai_ok(g) ? A(g->sp[1]) : nil)); // (wrapsym . (d))
     if (ai_ok(g)) g->sp[1] = B(g->sp[1]); } }
   else {                                              // list: append d at the frame's tail
    g = gxr(ai_push(g, 1, nil));                        // newcons = (d . nil)
    if (ai_ok(g)) {
     word frame = A(g->sp[1]);                         // (head . tail)
     if (nilp(A(frame))) A(frame) = B(frame) = g->sp[0];  // first element: head = tail = newcons
     else B(B(frame)) = g->sp[0], B(frame) = g->sp[0];    // link onto tail, advance tail
     g->sp++; }                                        // pop newcons -> ctx
    done = true; } }
  if (!ai_ok(g)) return g; } }

static ai_inline struct ai *ioread1str(struct ai*g) {
 int c;
 size_t n = 0, lim = sizeof(word);
 for (g = str0(g, lim); ai_ok(g); g = grbufg(g, lim), lim *= 2)
  for (; n < lim; txt(g->sp[0])[n++] = c) {
   if (!ai_ok(g = zgetc(g))) return g;     // threaded; char in g->b
   else if ((c = g->b) == '"')                  // close quote; "" -> the empty
    return n ? (len(g->sp[0]) = n, g)            // (truthy) singleton, never allocated
             : (g->sp[0] = EmptyString, g);
   else if (c == EOF) return encode(g, ai_status_more);
   else if (c == '\\') {                               // escape: take next char
    if (!ai_ok(g = zgetc(g))) return g;
    else if ((c = g->b) == EOF) return encode(g, ai_status_more);
    else if (c == 'n') c = '\n';
    else if (c == 't') c = '\t';
    else if (c == 'r') c = '\r';
    else if (c == '0') c = '\0';
    else if (c == 'x') {                          // \xHH: two hex digits
     if (!ai_ok(g = zgetc(g))) return g;
     int h1 = g->b;
     if (h1 == EOF) return encode(g, ai_status_more);
     if (!ai_ok(g = zgetc(g))) return g;
     int h2 = g->b;
     if (h2 == EOF) return encode(g, ai_status_more);
     int v1 = h1 <= '9' ? h1 - '0' : (h1 | 0x20) - 'a' + 10;
     int v2 = h2 <= '9' ? h2 - '0' : (h2 | 0x20) - 'a' + 10;
     c = ((v1 & 0xf) << 4) | (v2 & 0xf); } } }
 return g; }



static ai_inline struct ai *ioread1sym(struct ai*g, int c) {
 uintptr_t n = 1, lim = sizeof(intptr_t);
 if (ai_ok(g = str0(g, sizeof(word))))
  for (txt((struct ai_str*) g->sp[0])[0] = c; ai_ok(g); g = grbufg(g, lim), lim *= 2)
   for (; n < lim; txt(g->sp[0])[n++] = c) {
    if (!ai_ok(g = zgetc(g))) return g;
    switch (c = g->b) {
     default: continue;
     case ' ': case '\n': case '\t': case '\r': case '\f': case ';': case '#':
     case '(': case ')': case '[': case ']': case '{': case '}':
     // note: '\'' is NOT here -- a name keeps a trailing/internal prime (x', n'',
     // the prover idiom). A LEADING ' is still quote: ioparse dispatches it as a
     // wrap before this sounder ever runs, so only a continuation ' reaches here.
     case '"': case '`': case ',': case 0 : case EOF:
      if (!ai_ok(g = zungetc(g, c))) return g;
      struct ai_str *s = str(g->sp[0]);
      txt(s)[len(s) = n] = 0; // zero terminate for strtol ; n < lim so this is safe
      // A plain decimal integer reads at full precision (fixnum / box / bignum);
      // hex/octal/float/symbol tokens keep the strtol -> strtod -> intern path.
      if (is_dec_int(txt(s), n)) return ai_big_read_dec(g);
      char *e;
      long j = strtol(txt(s), &e, 0);
      if (*e == 0) {
       if (j >= fix_min && j <= fix_max) return g->sp[0] = putcharm(j), g;
       if (ai_ok(g = ai_have(g, box_req))) {
        struct ai_vec *b = ini_scalar(bump(g, box_req), ai_Z);
        box_put(b->shape, j);
        g->sp[0] = word(b); }
       return g; }
      // the IEEE specials read by their own names; everything else strtod
      // would take by spelling (inf, infinity, nan) stays a symbol: a float
      // token leads with a digit (a sign or dot may front it).
      char *tx = txt(s);
      double d;
      if (n == 8 && !memcmp(tx, "ieee-inf", 8)) d = __builtin_inf();
      else if (n == 9 && !memcmp(tx, "-ieee-inf", 9)) d = -__builtin_inf();
      // no ieee-nan literal: NaN collapses to 0 (flo_put), so there is no NaN
      // value to name -- "ieee-nan" reads as an honest symbol, free for binding.
      else {
       char c0 = *tx == '+' || *tx == '-' ? tx[1] : *tx;
       if (!(c0 >= '0' && c0 <= '9') && c0 != '.') return intern(g);
       d = strtod(tx, &e);
       if (e == tx || *e != 0) return intern(g); }
      uintptr_t req = b2w(sizeof(struct ai_vec) + sizeof(ai_flo_t));
      if (ai_ok(g = ai_have(g, req))) {
       struct ai_vec *r = ini_scalar(bump(g, req), ai_R);
       flo_put(r->shape, d);
       g->sp[0] = word(r); }
      return g; } }
 return g; }

// ============================================================================
// sys
// ============================================================================
op11(lvm_clock, putcharm(ai_clock() - getcharm(Sp[0])))

lvm(lvm_gauge) {
 size_t const req = 7 * Width(struct ai_pair);
 Have(req);
 struct ai_pair *si = (struct ai_pair*) Hp;
 Hp += req;
 Sp[0] = word(si);
 ini_two(si + 0, putcharm(g), word(si + 1));
 ini_two(si + 1, putcharm(g->len), word(si + 2));
 ini_two(si + 2, putcharm(Hp - ptr(g)), word(si + 3));
 ini_two(si + 3, putcharm(ptr(g) + g->len - Sp), word(si + 4));
#ifdef AI_STAT
 ini_two(si + 4, putcharm(g->n_gc), word(si + 5));               // gc cycles
 ini_two(si + 5, putcharm(g->max_len), word(si + 6));            // peak pool len (words)
 ini_two(si + 6, putcharm(g->max_heap), nil);                    // peak live heap (words)
#else
 ini_two(si + 4, putcharm(0), word(si + 5));                     // gc instrumentation gated off (-DAI_STAT to keep it)
 ini_two(si + 5, putcharm(0), word(si + 6));
 ini_two(si + 6, putcharm(0), nil);
#endif
 Ip += 1;
 return Continue(); }

// Default fd-keyed waits. Frontends override; defaults are conservative
// (all fds always-ready; multi-source wait collapses to plain sleep) so
// frontends that don't multitask (lcat, pd) link without providing impls.
__attribute__((weak)) bool ai_ready(int fd) { (void) fd; return true; }
__attribute__((weak)) void ai_wait_fds(int const *fds, int n, uintptr_t ticks) {
  (void) fds; (void) n; ai_sleep(ticks); }

// Default fd close is a no-op. The host overrides with close(2); kernel
// and pd don't have real OS fds to release, so the no-op is correct.
__attribute__((weak)) void ai_fd_close(int fd) { (void) fd; }
// default sleep is busy wait
__attribute__((weak)) ai_noinline void ai_sleep(uintptr_t ticks) {
  for (ticks += ai_clock(); ai_clock() < ticks;); }

lvm(lvm_key) {
 Sp[0] = (getcharm(ai_stdin.ungetc_buf) != EOF || ai_ready(getcharm(ai_stdin.fd))) ? putcharm(1) : nil;
 Ip += 1;
 return Continue(); }

// ============================================================================
// map (lookup-lambda backed by an open-addressed text; see mapp comment)
// ============================================================================
// backing is internal -- only ever reached from a header[1], never applied as a
// l value; its ap behaves-as-1 like lvm_buf should it ever be (it won't).
static lvm(lvm_map_data) {
 return Ip = cell(*++Sp), *Sp = putcharm(1), Continue(); }

// the backing slot of k, or -- if absent -- the first empty slot on its probe
// chain. load is kept < 3/4 so an empty slot always terminates the sound.
static ai_inline uintptr_t map_probe(struct ai *g, word m, word k, bool *found) {
 uintptr_t mask = map_cap(m) - 1, i = hash(g, k) & mask;
 word *s = map_slots(m);
 for (;; i = (i + 1) & mask) {
  word sk = s[2 * i];
  if (sk == map_gap) return *found = false, i;
  if (eql(g, k, sk)) return *found = true, i; } }

word ai_mapget(struct ai *g, word zero, word k, word m) {
 bool found; uintptr_t i = map_probe(g, m, k, &found);
 return found ? map_slots(m)[2 * i + 1] : zero; }

// fill an empty cap-slot backing at b (cap a power of two); caller reserves it.
static ai_inline union u *map_fill_back(union u *b, uintptr_t cap) {
 b[0].ap = lvm_map_data, b[1].x = putcharm(0), b[2].x = putcharm(cap);
 for (uintptr_t i = 0; i < cap; i++) b[3 + 2 * i].x = map_gap, b[4 + 2 * i].x = nil;
 return tagtext(b, 3 + 2 * cap); }

// double the backing of the map at sp[2] and rehash into it, then swap it into
// header[1]; the header never moves, so aliased references stay valid. The
// rehash inserts distinct keys into a backing with room to spare, so it never
// allocates and the fresh backing can't move under it.
static ai_noinline struct ai *map_grow(struct ai *g) {
 uintptr_t ncap = 2 * map_cap(g->sp[2]);
 if (!ai_ok(g = ai_have(g, 4 + 2 * ncap))) return g;
 word m = g->sp[2];                                 // re-fetch header after GC
 union u *nb = map_fill_back((union u*) g->hp, ncap);
 g->hp += 4 + 2 * ncap;
 word *os = map_slots(m), *ns = &nb[3].x;
 uintptr_t ocap = map_cap(m), nlen = 0, nmask = ncap - 1;
 for (uintptr_t j = 0; j < ocap; j++) {
  word k = os[2 * j];
  if (k == map_gap) continue;
  uintptr_t i = hash(g, k) & nmask;
  while (ns[2 * i] != map_gap) i = (i + 1) & nmask;
  ns[2 * i] = k, ns[2 * i + 1] = os[2 * j + 1], nlen++; }
 nb[1].x = putcharm(nlen);
 return cell(m)[1].x = (word) nb, g; }            // swap backing; header identity stable

// (put k v map): mutate in place; grow (may GC) on a new key past the load
// factor, re-reading k/v from the stack afterwards. Leaves the map at sp[2].
static ai_noinline struct ai *ai_mapput(struct ai *g) {
 if (!ai_ok(g)) return g;
 bool found; uintptr_t i = map_probe(g, g->sp[2], g->sp[0], &found);
 if (found) return map_slots(g->sp[2])[2 * i + 1] = g->sp[1], g->sp += 2, g;
 if ((map_len(g->sp[2]) + 1) * 4 >= map_cap(g->sp[2]) * 3) {
  if (!ai_ok(g = map_grow(g))) return g;
  i = map_probe(g, g->sp[2], g->sp[0], &found); }   // re-probe larger backing
 word *s = map_slots(g->sp[2]);
 s[2 * i] = g->sp[0], s[2 * i + 1] = g->sp[1];
 cell(map_back(g->sp[2]))[1].x = putcharm(map_len(g->sp[2]) + 1);
 return g->sp += 2, g; }

// ai_mapdel: delete k, backward-shift the probe chain so no tombstone is
// needed; v is the not-found result. No allocation. Leaves the map at sp[2].
static ai_noinline word ai_mapdel(struct ai *g, word m, word k, word zero) {
 bool found; uintptr_t i = map_probe(g, m, k, &found);
 if (!found) return zero;
 word *s = map_slots(m); uintptr_t mask = map_cap(m) - 1;
 for (uintptr_t j = i;;) {
  j = (j + 1) & mask;
  if (s[2 * j] == map_gap) break;
  uintptr_t h = hash(g, s[2 * j]) & mask;            // ideal slot of the probed key
  bool gap = i <= j ? (h <= i || h > j) : (h <= i && h > j);   // h not in (i, j]
  if (gap) s[2 * i] = s[2 * j], s[2 * i + 1] = s[2 * j + 1], i = j; }
 s[2 * i] = map_gap, s[2 * i + 1] = nil;
 cell(map_back(m))[1].x = putcharm(map_len(m) - 1);
 return m; }

// C-callable fresh empty map, pushed on sp[0]. Same shape as lvm_table.
static struct ai *map_new(struct ai *g) {
 uintptr_t cap = map_min_cap, nb = 4 + 2 * cap;
 if (!ai_ok(g = ai_have(g, nb + 3))) return g;
 union u *b = map_fill_back((union u*) g->hp, cap), *h = (union u*) (g->hp + nb);
 h[0].ap = lvm_map_lookup, h[1].x = (word) b, tagtext(h, 2);
 g->hp += nb + 3;
 return ai_push(g, 1, (word) h); }

// (tablet _): a fresh empty map -- header [lvm_map_lookup, backing] + backing.
lvm(lvm_table) {
 uintptr_t cap = map_min_cap, nb = 4 + 2 * cap;
 Have(nb + 3);
 union u *b = map_fill_back((union u*) Hp, cap);
 union u *h = (union u*) (Hp + nb);
 h[0].ap = lvm_map_lookup, h[1].x = (word) b, tagtext(h, 2);
 Sp[0] = (word) h;
 return Hp += nb + 3, Ip++, Continue(); }

// (m k): map application is lookup, nil if absent (the map is its own lookup fn,
// so (m k) == (get 0 k m)). No alloc, unwinds like self-quote: drop the arg,
// jump to the return address at Sp[1], leave the result on top.
static lvm(lvm_map_lookup) {
 word v = ai_mapget(g, nil, Sp[0], (word) Ip);
 return Ip = cell(*++Sp), *Sp = v, Continue(); }

op11(lvm_mapp, mapp(Sp[0]) ? putcharm(1) : nil)
// (lamp x): is x lit -- wired to a hot, a heap pointer, not a fixnum? true for every
// present non-fixnum value -- pairs, symbols, strings, vecs, maps, texts.
op11(lvm_lamp, lamp(Sp[0]) ? putcharm(1) : nil)
// (hotp x): is x an opaque hot handle -- a buf or a port? (a task is referenced
// by a fixnum id, not a handle object.) a hot also answers lamp (it acts as
// a constant function); hotp is the refinement that names the zoo.
op11(lvm_hotp, (bufp(Sp[0]) || iop(Sp[0]) || toastp(Sp[0])) ? putcharm(1) : nil)

// (hash x) -- the general hashing method exposed to l as a fixnum.
op11(lvm_dig, putcharm(hash(g, Sp[0])))

lvm(lvm_peep) {                                // (peep coll key default): collection-first
 word x = Sp[0], k = Sp[1], z = Sp[2], n;
 if (bufp(x)) {                                  // mutable byte string: byte index
  struct ai_str *s = buf_str(x);
  if (charmp(k) && (n = getcharm(k)) >= 0 && n < (word) len(s))
   z = putcharm((unsigned char) txt(s)[n]); }
 else if (mapp(x)) z = ai_mapget(g, z, k, x);     // map lookup (not a data sentinel)
 else if (lamp(x) && datp(x)) switch (typ(x)) {
  default: break;                               // KSym is not indexable
  case KVec: {
   // Array index: a fixnum for a rank-1 array, or a shape-list (row-major) for
   // rank-N; an empty/nil key derefs a rank-0 scalar box. Out-of-bounds or a
   // wrong-rank key falls through to the default `z`. Integer elements keep
   // integer type (emit_int demotes-or-boxes); float elements box an f64.
   struct ai_vec *v = vec(x);
   uintptr_t R = v->rank, off = 0; bool ok = false;
   if (R == 0) ok = nilp(k);
   else if (R == 1 && charmp(k)) {
    intptr_t ix = getcharm(k);
    if (ix >= 0 && ix < (intptr_t) v->shape[0]) off = ix, ok = true; }
   else if (twop(k)) {
    uintptr_t a = 0; ok = true;
    for (word l = k;; l = B(l)) {
     if (!twop(l)) { ok = a == R; break; }
     word ki = A(l);
     if (a >= R || !charmp(ki)) { ok = false; break; }
     intptr_t ix = getcharm(ki);
     if (ix < 0 || ix >= (intptr_t) v->shape[a]) { ok = false; break; }
     off = off * v->shape[a] + ix, a++; } }
   if (ok && v->type == ai_O) z = vec_get_obj(v, off);   // object: the slot IS the value
   else if (ok && v->type == ai_C) {                       // packed complex -> a (re,im) box
    Have(cplx_req); v = vec(Sp[0]);                      // re-read coll (Sp[0]) post-Have
    ai_flo_t *fp = vec_data(v);
    struct ai_vec *bx = ini_scalar((struct ai_vec*) Hp, ai_C); Hp += cplx_req;
    cplx_put(bx, fp[2*off], fp[2*off+1]); z = word(bx); }
   else if (ok) { word _res; Have(box_req); v = vec(Sp[0]);
    if (v->type >= ai_R) emit_flo(vec_get_flo(v, off));
    else emit_int(vec_get_int(v, off));
    z = _res; }
   break; }
  case KString:
   // Byte as its unsigned value 0..255 -- bytes are data, signedness is the
   // operator's job. txt is signed char[], so cast to avoid sign-extending a
   // high byte (e.g. 0xff -> -1) when binary data is indexed.
   if (charmp(k) && (n = getcharm(k)) >= 0 && n < (word) len(x))
    z = putcharm((unsigned char) txt(x)[n]);
   break;
  case KTwo:
   if (charmp(k) && (n = getcharm(k)) >= 0) {
    while (n-- && twop(x = B(x)));
    if (twop(x)) z = A(x); } }
 return Sp[2] = z, Sp += 2, Ip += 1, Continue(); }

// (pin coll key val): collection-first map insert, or -- when coll is a buf --
// store the byte val at index key. Both leave coll on the stack as the result.
// A buf store needs no allocation, so no GC dance; out-of-range/non-numeric is a
// silent no-op, matching the misuse convention of the other byte ops.
lvm(lvm_put) {
 word x = Sp[0], n;                              // coll
 if (mapp(x)) {
  Sp[0] = Sp[1], Sp[1] = Sp[2], Sp[2] = x;       // ai_mapput wants (sp0,sp1,sp2)=(key,val,coll)
  Pack(g);
  if (!ai_ok(g = ai_mapput(g))) return ghelp(g);
  Unpack(g); }
 else {
  if (bufp(x) && charmp(Sp[1]) && (n = getcharm(Sp[1])) >= 0 && n < (word) len(buf_str(x)))
   txt(buf_str(x))[n] = (char) getcharm(Sp[2]);     // index = key = Sp[1], val = Sp[2]
  Sp[2] = x, Sp += 2; }                           // leave coll as the result
 return Ip += 1, Continue(); }

// (pull coll key default): remove key from a map, returning its value -- or
// default if absent (symmetry with peep) -- and mutating coll in place.
// ai_mapget reads the value, ai_mapdel removes it; neither allocates, so no GC
// dance. A non-map coll yields default (silent misuse).
lvm(lvm_pull) {
 word coll = Sp[0], v = Sp[2];                   // default
 if (mapp(coll)) {
  v = ai_mapget(g, Sp[2], Sp[1], coll);           // value, or default if absent
  ai_mapdel(g, coll, Sp[1], Sp[2]); }             // remove in place (no-op if absent)
 return Sp[2] = v, Sp += 2, Ip += 1, Continue(); }

lvm(lvm_keys) {
 intptr_t list = nil;
 if (mapp(Sp[0])) {
  uintptr_t cap = map_cap(Sp[0]), n = map_len(Sp[0]);
  Have(n * Width(struct ai_pair));
  struct ai_pair *pairs = (struct ai_pair*) Hp;
  Hp += n * Width(struct ai_pair);
  word *s = map_slots(Sp[0]);                    // re-read after Have (GC may move the map)
  for (uintptr_t i = cap; i;)
   if (s[2 * --i] != map_gap)
    ini_two(pairs, s[2 * i], list), list = (intptr_t) pairs, pairs++; }
 Sp[0] = list;
 Ip += 1;
 return Continue(); }

static ai_noinline uintptr_t hash_two(struct ai *g, word x) {
 word *base = off_pool(g), *top = base + g->len, *w = base;
 for (uintptr_t h = mix;; x = *--w) {
  while (twop(x)) {
   if (w == top) __builtin_trap();       // worklist overflow: a cycle
   h = (h ^ mix) * mix;                  // mark a pair node
   *w++ = A(x), x = B(x); }
  h = (h ^ hash(g, x)) * mix;          // x is a leaf: hash won't recur
  if (w == base) return h; } }

// general hashing method...
struct arib; static uintptr_t shash(struct ai *g, word x, struct arib *env);  // α-invariant source hash
uintptr_t hash(struct ai *g, intptr_t x) {
 if (charmp(x)) return rot(x*mix);
 if (!datp(x)) {
   // out-of-pool (static nif): stable distinct address. in-pool: a compiled lambda
   // parks its source \-expr one cell before the entry (the tag head points there) and
   // hashes it α-invariantly (so the order agrees with `=`'s α-equivalence); else by
   // length. All GC-stable (buckets survive copy).
   if ((word*) x < ptr(g) || (word*) x >= topof(g)) return rot(x * mix);
   union u *k = cell(x); struct ai_tag *tg = ttag(g, k);
   if (tag_head(tg) < k) return shash(g, k[-1].x, 0);
   uintptr_t r = mix;
   for (union u *y = k; y < (union u*) tg; y++) r ^= r * mix;
   return r; }
 switch (typ(x)) {
   default: __builtin_trap();
   case KTwo: return hash_two(g, x);
   case KSym: return sym(x)->code;
   case KVec: {
    uintptr_t len = ai_vec_bytes(vec(x)), h = mix;
    for (uint8_t const *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return h; }
   case KBig: {
    uintptr_t len = ai_big_bytes((struct ai_big*) x), h = mix;
    for (uint8_t const *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return h; }
   case KString: {
    uintptr_t n = len(x), h = mix;
    char const *bs = txt(x);
    while (n--) h ^= (uint8_t) *bs++, h *= mix;
    return h; } } }

// ============================================================================
// str
// ============================================================================
struct ai *str0(struct ai *g, uintptr_t len) {
 if (!len) { if (ai_ok(g = ai_have(g, 1))) *--g->sp = EmptyString; return g; } // never alloc empty
 uintptr_t req = str_type_width + b2w(len);
 if (ai_ok(g = ai_have(g, req + 1)))
  *--g->sp = word(ini_str(bump(g, req), len));
 return g; }

struct ai *ai_strof(struct ai *g, char const *cs) {
 uintptr_t len = strlen(cs);
 if (ai_ok(g = str0(g, len))) memcpy(txt(g->sp[0]), cs, len);
 return g; }

op11(lvm_strp, strp(Sp[0]) ? putcharm(1) : nil)
lvm(lvm_slice) {
 if (!strp(Sp[0])) Sp[2] = nil;
 else {
  struct ai_str *s = str(Sp[0]), *t;
  intptr_t i = oddp(Sp[1]) ? getcharm(Sp[1]) : 0,
           j = oddp(Sp[2]) ? getcharm(Sp[2]) : 0;
  i = max(i, 0), i = min(i, (word) len(s));
  j = max(j, i), j = min(j, (word) len(s));
  if (i == j) Sp[2] = nil;
  else {
   size_t req = str_type_width + b2w(j - i);
   Have(req);
   t = (struct ai_str*) Hp;
   Hp += req;
   ini_str(t, j - i);
   memcpy(txt(t), txt(s) + i, j - i);
   Sp[2] = (word) t; } }
 return Ip += 1, Sp += 2, Continue(); }


// A buf has no function meaning, so applying it behaves as 0 (yields 1, the const-1
// identity numeral) -- like every structureless value. Its address is still the
// kind tag: ai_noicf (on every lvm) keeps this byte-identical to lvm_port_io so
// bufp and iop never collide. NOT a data sentinel, so the GC copies a buf via the
// generic text path and the cheney sound forwards its backing-string pointer.
lvm(lvm_buf) {
 return Ip = cell(*++Sp), *Sp = putcharm(1), Continue(); }
// the toast ap (its type tag): applied, a toast is const-1 like any opaque hot -- it is
// meant to be (call ..)'d, not applied. Distinct from lvm_buf so toastp tells them apart.
lvm(lvm_toasted) {
 return Ip = cell(*++Sp), *Sp = putcharm(1), Continue(); }

// (buf n) — allocate a zeroed n-byte mutable buf. n<=0 / non-numeric -> the empty
// string singleton EmptyString, so NO empty buf object ever exists (an un-writable 0-byte
// buf IS ""); this lets ai_nilp drop its buf branch (every real buf has len>=1, truthy).
// Two heap objects under one Have (so no GC sees a half-built buf): the backing ai_str
// holding the bytes, and the length-2 wrapper text [lvm_buf, str, terminator].
lvm(lvm_bufnew) {
 intptr_t n = charmp(Sp[0]) ? getcharm(Sp[0]) : 0;
 if (n <= 0) return Sp[0] = EmptyString, Ip++, Continue();   // no empty buf: it is ""
 uintptr_t sreq = str_type_width + b2w(n),
           breq = Width(struct ai_buf) + Width(struct ai_tag);
 Have(sreq + breq);
 struct ai_str *s = ini_str((struct ai_str*) Hp, n);
 Hp += sreq;
 memset(txt(s), 0, n);
 union u *k = (union u*) Hp;
 Hp += breq;
 ((struct ai_buf*) k)->ap = lvm_buf;
 ((struct ai_buf*) k)->str = s;
 tagtext(k, Width(struct ai_buf));
 return Sp[0] = word(k), Ip++, Continue(); }

// (call b x) — the JIT trampoline: jump into the machine code stored in buf b,
// passing x as the sole argument (SysV AMD64: %rdi/%rax; AArch64: x0/x0), and
// wrap the returned machine word as a fixnum. The bytes in b are the caller's
// responsibility -- an ill-formed body is a hard crash, by design. AArch64 must
// __builtin___clear_cache(txt(s), txt(s)+len(s)) before the jump (I-cache not
// coherent with freshly-written D-cache); omitted for the x86_64 probe.
#ifdef G_FAULT_TEST   // harness: trigger a hardware fault inside eval (see nifs)
lvm(lvm_fault) { volatile char *p = 0; (void) *p; return Sp[0] = putcharm(0), Ip++, Continue(); }
#endif

// THE FAULT BARRIER (hosted). Running native (toasted) code is love's one
// un-survivable corner: an ill-formed body faults the CPU (SIGSEGV/SIGILL/...),
// below help. call_run wraps the native call in a sigsetjmp; a fault during it is
// caught and reported via *bad (the caller returns 0, the same value the non-buf
// guard gives), so a bad body is survivable like any other love error -- never a
// core dump. The handler only fires inside an active call (call_depth); a fault in
// love's OWN code still crashes for real. The native body never touches love state
// (the call contract), so recovery is clean -- no heap-consistency question here.
// (The broad version -- a barrier at ai_eval turning faults in object-array ops,
// spin, etc. into scares -- reuses this same handler; that's the next step.)
#if __STDC_HOSTED__
static ai_noinline ai_word call_run(void *fnp, ai_word x, ai_word y, int two, int *bad) {
 ai_fault_arm();                                          // shared barrier (defined before ai_eval)
 sigjmp_buf prev; memcpy(&prev, &ai_fault_jb, sizeof prev);   // save outer (nesting)
 ai_fault_depth++;
 if (sigsetjmp(ai_fault_jb, 1) == 0) {
  ai_word r = two ? ((ai_word (*)(ai_word, ai_word)) fnp)(x, y) : ((ai_word (*)(ai_word)) fnp)(x);
  ai_fault_depth--; *bad = 0; memcpy(&ai_fault_jb, &prev, sizeof prev); return r; }
 ai_fault_depth--; *bad = 1; memcpy(&ai_fault_jb, &prev, sizeof prev); return 0; }  // recovered from a fault
#else
static ai_word call_run(void *fnp, ai_word x, ai_word y, int two, int *bad) {  // freestanding: no signals (yet)
 *bad = 0; return two ? ((ai_word (*)(ai_word, ai_word)) fnp)(x, y) : ((ai_word (*)(ai_word)) fnp)(x); }
#endif

lvm(lvm_call) {
 word b = Sp[0], x = Sp[1];
 if (!toastp(b)) return *++Sp = putcharm(0), Ip++, Continue();   // only a toast is callable -> else nothing
 int bad; ai_word r = call_run(txt(buf_str(b)), x, 0, 0, &bad);   // fault -> bad -> 0 (survivable)
 return *++Sp = putcharm(bad ? 0 : r), Ip++, Continue(); }   // arity 2: pop one, result at the new top

// (call2 b x y) — like (call b x) but passes TWO arguments (SysV AMD64: x in
// %rdi, y in %rsi; AArch64: x0, x1) for native two-argument kernels. Same raw
// machine-word contract and fixnum-wrapped result as call, and the same fault
// barrier. Arity 3.
lvm(lvm_call2) {
 word b = Sp[0], x = Sp[1], y = Sp[2];
 if (!toastp(b)) return Sp[2] = putcharm(0), Sp += 2, Ip++, Continue();   // only a toast is callable
 int bad; ai_word r = call_run(txt(buf_str(b)), x, y, 1, &bad);
 return Sp[2] = putcharm(bad ? 0 : r), Sp += 2, Ip++, Continue(); }   // arity 3: collapse two, result at the new top

// THE HOST EXEC ARENA (hosted builds only). The Linux malloc heap is NX, so a
// buf of real code cannot be run directly -- the jump faults. `toast` copies the
// bytes into a W^X mapping instead: mmap RW, write, mprotect to R+X, and never
// write again (writable XOR executable, honored, so hardened systems that forbid
// RWX still run it). The mapping is page-rounded and holds a ai_str header [len,
// bytes..]; the resulting TOAST is a hot whose ->str lives outside the GC pool --
// gcp's out-of-pool short-circuit leaves the pointer untouched (like the immortal
// data-segment constants), and a finalizer munmaps it when the toast is collected
// (mirrors io_close). The freestanding kernel needs none of this: its HHDM is
// mapped executable, so a plain heap copy already runs (see ai/glaze/README.md), and
// `toast` there is just that copy. Either way the idiom is (call (toast bytes) x).
#if __STDC_HOSTED__
#include <sys/mman.h>
#include <unistd.h>
#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif
static ai_inline size_t ai_pagesize(void) {
 static size_t p; if (!p) { long q = sysconf(_SC_PAGESIZE); p = q > 0 ? (size_t) q : 4096; }
 return p; }
static ai_inline size_t code_maplen(size_t codelen) {
 size_t ps = ai_pagesize(), need = sizeof(struct ai_str) + codelen;
 return (need + ps - 1) & ~(ps - 1); }
// Finalizer (runs inside GC, fz->p is the from-space buf wrapper, still
// readable): recover the arena base from ->str and unmap it. ->str is an
// out-of-pool pointer the collector never rewrote, so it still names the map.
static void code_unmap(void *p) {
 struct ai_str *base = ((struct ai_buf*) p)->str;
 munmap(base, code_maplen(base->len)); }
#endif

// (toast src) — bake src's bytes into an opaque, executable TOAST (src a string or
// buf; non-byte or empty -> 0). On a hosted build the bytes go into the W^X code
// arena above; on the freestanding kernel a plain heap copy (the HHDM is already
// executable). A toast is a distinct opaque hot -- hotp but NOT a buf, so it can't
// be peep/pin/blit/tally'd as data; only (call ...) runs it, on either target. The
// bytes are the caller's responsibility: toast only places them where they can run,
// it does not check them.
lvm(lvm_toast) {
 word src = Sp[0];
 if (!(strp(src) || bufp(src))) return Sp[0] = putcharm(0), Ip++, Continue();
 struct ai_str *in = bytes_of(src);
 uintptr_t n = len(in);
 if (n == 0) return Sp[0] = putcharm(0), Ip++, Continue();   // nothing to toast -> nothing
#if __STDC_HOSTED__
 // The buf wrapper + finalizer node live in the heap; the ai_str backing lives
 // in the arena. Have() BEFORE the mmap so a GC retry (which re-runs the nif)
 // never leaks a mapping -- past Have no GC fires, so `in` stays valid below.
 Have(Width(struct ai_buf) + Width(struct ai_tag) + Width(struct ai_fz));
 size_t maplen = code_maplen(n);
 void *base = mmap(0, maplen, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
 if (base == MAP_FAILED) return Sp[0] = putcharm(0), Ip++, Continue();   // OOM -> nothing
 struct ai_str *s = ini_str((struct ai_str*) base, n);
 memcpy(txt(s), txt(bytes_of(Sp[0])), n);   // reload src: a GC in Have may have moved it
 if (mprotect(base, maplen, PROT_READ | PROT_EXEC))   // seal: writable -> executable
  return munmap(base, maplen), Sp[0] = putcharm(0), Ip++, Continue();
 union u *k = (union u*) Hp; Hp += Width(struct ai_buf) + Width(struct ai_tag);
 ((struct ai_buf*) k)->ap = lvm_toasted;   // opaque toast tag, not lvm_buf: not peep/pin-able
 ((struct ai_buf*) k)->str = s;
 tagtext(k, Width(struct ai_buf));
 struct ai_fz *z = (struct ai_fz*) Hp; Hp += Width(struct ai_fz);
 z->p = k, z->fn = code_unmap, z->next = g->fz, g->fz = z;
 return Sp[0] = word(k), Ip++, Continue();
#else
 // Freestanding: a heap buf copy (HHDM is RWX). Two objects under one Have, as
 // in lvm_bufnew, so no GC ever sees a half-built buf.
 uintptr_t sreq = str_type_width + b2w(n),
           breq = Width(struct ai_buf) + Width(struct ai_tag);
 Have(sreq + breq);
 struct ai_str *s = ini_str((struct ai_str*) Hp, n); Hp += sreq;
 memcpy(txt(s), txt(bytes_of(Sp[0])), n);   // reload src: a GC in Have may have moved it
 union u *k = (union u*) Hp; Hp += breq;
 ((struct ai_buf*) k)->ap = lvm_toasted;   // opaque toast tag, not lvm_buf
 ((struct ai_buf*) k)->str = s;
 tagtext(k, Width(struct ai_buf));
 return Sp[0] = word(k), Ip++, Continue();
#endif
}

// ============================================================================
// CODEGEN BACKEND brick 1 -- the native-install seam (provisional; -> `ev`)
// ============================================================================
// the W^X arena finalizer: recover the ai_str base from the code address (cell[0],
// the header) and munmap it. Fires only on death (run_finalizers' survival test
// reads z->p->x: the header is the out-of-pool code addr when dead, an in-pool
// forward when alive -- so a dead native closure is correctly reclaimed).
#if __STDC_HOSTED__
static void nat_unmap(void *p) {
 char *code = (char*) ((union u*) p)[0].ap;            // header == the W^X code address
 struct ai_str *base = (struct ai_str*) (code - sizeof(struct ai_str));   // code == s->bytes
 munmap(base, code_maplen(base->len)); }
#endif

// (nat codebuf interp src) installs codebuf's machine code and returns a TRANSPARENT
// applicable native closure. Cell: [code, src, code, interp, lvm_ret, putcharm(0)] with
// the VALUE pointing at the 3rd word (the second `code`), so:
//   value[0]  = code      -- lvm_ap dispatches straight into the emitted body
//   value[-1] = src       -- the source \-expr, where fn_src/the printer/salpha look,
//                            so the native closure is =/show-IDENTICAL to its source
//   value[1]  = interp    -- the deopt fallback (rsi+8): an overflow guard tail-applies
//                            it to the original arg (Sp[0]) -> native is never wrong
//   value[2]  = lvm_ret   -- the fast-path return (emitted: add rsi,16; Continue)
// cell[0] is a HEADER duplicate of the code addr at the allocation start: out-of-pool,
// so run_finalizers distinguishes a dead closure (header) from a live one (forward).
// The code follows the lvm ABI (g=rdi Ip=rsi Hp=rdx Sp=rcx). Applied by JUXTAPOSITION
// -- no run-verb; plumbing the compiler calls to emit native for a hot closure,
// transparently. Internal: the egg mops it like boxfix/wev.
lvm(lvm_nat) {
 word codebuf = Sp[0];                       // Sp[0]=code, Sp[1]=interp, Sp[2]=src
 if (!(strp(codebuf) || bufp(codebuf))) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 uintptr_t n = len(bytes_of(codebuf));
 if (n == 0) return Sp[2] = nil, Sp += 2, Ip++, Continue();
#if __STDC_HOSTED__
 Have(7 + Width(struct ai_fz));               // [code,src,code,interp,lvm_ret,putcharm(0)] + tag + finalizer
 size_t maplen = code_maplen(n);
 void *base = mmap(0, maplen, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
 if (base == MAP_FAILED) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 struct ai_str *s = ini_str((struct ai_str*) base, n);
 memcpy(txt(s), txt(bytes_of(Sp[0])), n);    // reload codebuf: a GC in Have may have moved it
 if (mprotect(base, maplen, PROT_READ | PROT_EXEC))
  return munmap(base, maplen), Sp[2] = nil, Sp += 2, Ip++, Continue();
#else
 Have(str_type_width + b2w(n) + 7);          // freestanding: HHDM is RWX, a heap copy runs
 struct ai_str *s = ini_str((struct ai_str*) Hp, n); Hp += str_type_width + b2w(n);
 memcpy(txt(s), txt(bytes_of(Sp[0])), n);
#endif
 union u *k = (union u*) Hp; Hp += 7;
 k[0].ap = (lvm_t*) txt(s);                  // header (== code, out-of-pool): finalizer dead-detect
 k[1].x  = Sp[2];                            // src   (reloaded): value[-1], for =/show
 k[2].ap = (lvm_t*) txt(s);                  // code  (value[0]): the emitted body
 k[3].x  = Sp[1];                            // interp(reloaded): value[1], deopt fallback
 k[4].ap = lvm_ret;                          // value[2]: fast-path return
 k[5].x  = putcharm(0);                        // ret n=1
 tagtext(k, 6);
#if __STDC_HOSTED__
 struct ai_fz *z = (struct ai_fz*) Hp; Hp += Width(struct ai_fz);
 z->p = k, z->fn = nat_unmap, z->next = g->fz, g->fz = z;
#endif
 return Sp[2] = word(k + 2), Sp += 2, Ip++, Continue(); }

// (natn code interp src arity) -- nat for arity>=2: the cell ENTRY is lvm_cur, so
// applying it reuses the interpreter's currying to saturation, then runs the native
// body at cell+2 (lvm_cur's Ip+2 resume) with args at Sp[0..arity-1] and retaddr at
// Sp[arity]. The body runs with rsi=&code, so interp@rsi+8 and lvm_ret@rsi+16 -- the
// SAME offsets as nat. value[-1]=src (=/show). DEOPT (emitter) jmps to interp's BODY
// (interp+2, past its own lvm_cur), where the saturated args already sit. lvm_ret
// pops n=arity via putcharm(arity-1).
lvm(lvm_natn) {
 word codebuf = Sp[0];
 intptr_t ar = oddp(Sp[3]) ? getcharm(Sp[3]) : 0;     // Sp[0]=code Sp[1]=interp Sp[2]=src Sp[3]=arity
 if (!(strp(codebuf) || bufp(codebuf)) || ar < 2) return Sp[3] = nil, Sp += 3, Ip++, Continue();
 uintptr_t n = len(bytes_of(codebuf));
 if (n == 0) return Sp[3] = nil, Sp += 3, Ip++, Continue();
#if __STDC_HOSTED__
 Have(9 + Width(struct ai_fz));               // [hdr,src,cur,putcharm(ar),code,interp,ret,putcharm(ar-1)] + tag + fz
 size_t maplen = code_maplen(n);
 void *base = mmap(0, maplen, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
 if (base == MAP_FAILED) return Sp[3] = nil, Sp += 3, Ip++, Continue();
 struct ai_str *s = ini_str((struct ai_str*) base, n);
 memcpy(txt(s), txt(bytes_of(Sp[0])), n);
 if (mprotect(base, maplen, PROT_READ | PROT_EXEC))
  return munmap(base, maplen), Sp[3] = nil, Sp += 3, Ip++, Continue();
#else
 Have(str_type_width + b2w(n) + 9);
 struct ai_str *s = ini_str((struct ai_str*) Hp, n); Hp += str_type_width + b2w(n);
 memcpy(txt(s), txt(bytes_of(Sp[0])), n);
#endif
 union u *k = (union u*) Hp; Hp += 9;
 k[0].ap = (lvm_t*) txt(s);                  // header (out-of-pool): finalizer dead-detect
 k[1].x  = Sp[2];                            // src (reloaded): value[-1]
 k[2].ap = lvm_cur;                          // value[0]: curry to saturation
 k[3].x  = putcharm(ar);
 k[4].ap = (lvm_t*) txt(s);                  // native body (lvm_cur resume Ip+2)
 k[5].x  = Sp[1];                            // interp (reloaded): deopt fallback
 k[6].ap = lvm_ret;
 k[7].x  = putcharm(ar - 1);                   // ret pops n=arity
 tagtext(k, 8);
#if __STDC_HOSTED__
 struct ai_fz *z = (struct ai_fz*) Hp; Hp += Width(struct ai_fz);
 z->p = k, z->fn = nat_unmap, z->next = g->fz, g->fz = z;
#endif
 return Sp[3] = word(k + 2), Sp += 3, Ip++, Continue(); }

// (bcopy dst doff src soff n) — copy n bytes from src[soff..] into buf dst at
// doff. src may be a string or buf; dst must be a buf. Ranges are clamped to
// both backing stores -- a safety net (the caller sizes dst to fit), so an
// out-of-range request copies less rather than trampling the heap. Returns
// dst. No allocation, so no GC dance and the trailing tail call is preserved.
lvm(lvm_bcopy) {
 word dst = Sp[0], src = Sp[2];
 if (bufp(dst) && (strp(src) || bufp(src))) {
  struct ai_str *d = buf_str(dst), *s = bytes_of(src);
  intptr_t doff = getcharm(Sp[1]), soff = getcharm(Sp[3]), n = getcharm(Sp[4]),
           dl = len(d), sl = len(s);
  if (n < 0) n = 0;
  if (doff < 0) doff = 0;
  if (soff < 0) soff = 0;
  if (doff + n > dl) n = dl - doff;
  if (soff + n > sl) n = sl - soff;
  if (n > 0) memmove(txt(d) + doff, txt(s) + soff, n); }
 return Sp[4] = dst, Sp += 4, Ip += 1, Continue(); }

// public predicate for frontends that need to check string args
bool ai_strp(ai_word x) { return strp(x); }

// ============================================================================
// sym
// ============================================================================
// (intern s) -> the interned symbol named by string s; identity on any other arg.
// The empty spelling names nothing: (intern "") is 0, never an atom -- one
// nothing (the empty symbol died with the one-nothing round).
lvm(lvm_intern) {
 if (strp(Sp[0])) {
  if (Sp[0] == EmptyString) return Sp[0] = nil, Ip += 1, Continue();
  struct ai_atom *y;
  Have(intern_reserve(g));
  Pack(g), y = intern_checked(g, (struct ai_str*) g->sp[0]), Unpack(g);
  Sp[0] = word(y); }
 return Ip += 1, Continue(); }

// (mint _) -> a fresh POINT, adjoined to the value space: nameless, materially
// empty ($mint = 0, applies const-1 like every unit), identity its only
// property -- the arg is ignored. `code` gets THE MINT SERIAL (monotonic,
// pre-incremented) -- the point's hash and its place
// in the total order: mints order by creation, GC-stable. a NOM is now the
// literal pair of a name string and a mint (prel sugar over this nif) --
// the named-uninterned atom species is gone, the McCarthy restoration's first
// half. mints still answer symp (a nameless atom), so they bind as gensyms.
lvm(lvm_mint) {
 Have(Width(struct ai_atom));
 struct ai_atom *y = (struct ai_atom*) Hp;
 Hp += Width(struct ai_atom);                   // atoms are uniform: ap, code, nom
 ini_missing(y, ++g->next_serial);
 return
  Sp[0] = word(y),
  Ip += 1,
  Continue(); }

struct ai *intern(struct ai*g) {
 if (ai_ok(g = ai_have(g, intern_reserve(g))))   // atom + (at the load factor) the doubled backing
  g->sp[0] = (word) intern_checked(g, (struct ai_str*) g->sp[0]);
 return g; }

// avail must be >= Width(struct ai_atom) when this is called.
// how much a fresh intern may bump: the atom, plus -- when the table sits at
// the load factor -- the doubled backing it rehashes into. callers reserve
// this BEFORE intern_checked so the insert below never allocates (and so the
// string never moves mid-insert).
uintptr_t intern_reserve(struct ai *g) {
 word m = g->symbols;
 uintptr_t extra = m && (map_len(m) + 1) * 4 >= map_cap(m) * 3 ? 4 + 4 * map_cap(m) : 0;
 return Width(struct ai_atom) + extra; }

// intern: probe the WEAK intern map by string content (string hash + content
// equality -- the same value-keyed probe every map uses); a miss mints the
// canonical atom (code = its name hash, the symbol's own hash) and inserts.
// avail must be >= intern_reserve(g) when this is called: bump-only in here.
ai_noinline struct ai_atom *intern_checked(struct ai *g, struct ai_str *b) {
 word m = g->symbols;
 bool found; uintptr_t i = map_probe(g, m, word(b), &found);
 if (found) return sym(map_slots(m)[2 * i + 1]);
 if ((map_len(m) + 1) * 4 >= map_cap(m) * 3) {           // at load: rehash into a doubled backing
  uintptr_t ncap = 2 * map_cap(m), nmask = ncap - 1;
  union u *nb = map_fill_back(bump(g, 4 + 2 * ncap), ncap);
  word *os = map_slots(m), *ns = &nb[3].x;
  uintptr_t ocap = map_cap(m), nlen = 0;
  for (uintptr_t j = 0; j < ocap; j++) {
   word k = os[2 * j];
   if (k == map_gap) continue;
   uintptr_t x = hash(g, k) & nmask;
   while (ns[2 * x] != map_gap) x = (x + 1) & nmask;
   ns[2 * x] = k, ns[2 * x + 1] = os[2 * j + 1], nlen++; }
  nb[1].x = putcharm(nlen);
  cell(m)[1].x = (word) nb;                              // swap backing; header identity stable
  i = map_probe(g, m, word(b), &found); }
 struct ai_atom *y = ini_sym(bump(g, Width(struct ai_atom)), b, rot(hash(g, word(b))));
 word *slots = map_slots(m);
 slots[2 * i] = word(b), slots[2 * i + 1] = word(y);
 cell(map_back(m))[1].x = putcharm(map_len(m) + 1);
 return y; }

op11(lvm_symp, symp(Sp[0]) ? putcharm(1) : nil)
op11(lvm_packp, packp(Sp[0]) ? putcharm(1) : nil)
op11(lvm_bigp, bigp(Sp[0]) ? putcharm(1) : nil)
op11(lvm_widep, widep(Sp[0]) ? putcharm(1) : nil)
op11(lvm_arrp, arrp(Sp[0]) ? putcharm(1) : nil)
// (int x): truncate a float scalar to a fixnum; other numbers pass through. Used by
// num-ap to get an integer composition count from a non-integer numeral operator.
op11(lvm_intf, flop(Sp[0]) ? putcharm((intptr_t) flo_get(Sp[0])) : Sp[0])

// ============================================================================
// pair
// ============================================================================
op11(lvm_car, twop(Sp[0]) ? A(Sp[0]) : Sp[0])
op11(lvm_cdr, twop(Sp[0]) ? B(Sp[0]) : nil)
op11(lvm_twop, twop(Sp[0]) ? putcharm(1) : nil)
lvm(lvm_cons) {
 Have(Width(struct ai_pair));
 struct ai_pair *w = (struct ai_pair*) Hp;
 Hp += Width(struct ai_pair);
 ini_two(w, Sp[0], Sp[1]);
 *++Sp = word(w);
 Ip++;
 return Continue(); }

#define avm_slow(op, vop, ovf, fexpr) static lvm(lvm_##op##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (arrp(a) || arrp(b)) return Ap(lvm_vbin, g, vop); \
 if (Cp(a) || Cp(b)) return Ap(lvm_cplx_bin, g, vop); \
 if (!isnum(a) || !isnum(b)) return *++Sp = nil, Ip++, Continue(); \
 if (flop(a) || flop(b)) { word _res; Have(box_req); \
  ai_flo_t ad = toflo(a), bd = toflo(b); \
  struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_R); \
  Hp += box_req; flo_put(v->shape, (fexpr)); _res = word(v); \
  return *++Sp = _res, Ip++, Continue(); } \
 if (!bigp(a) && !bigp(b)) { intptr_t av = toint(a), bv = toint(b), t; \
  if (!ovf(av, bv, &t)) { word _res; Have(box_req); emit_int(t); \
   return *++Sp = _res, Ip++, Continue(); } } \
 if ((vop) == vop_mul) return Ap(lvm_bmul_start, g); /* O(n^2): run yieldable */ \
 Pack(g); g = ai_big_binop(g, vop); \
 if (!ai_ok(g)) return ghelp(g); \
 return Unpack(g), Continue(); }
#define avm_slowdiv(op, vop, c_op, fexpr) static lvm(lvm_##op##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (arrp(a) || arrp(b)) return Ap(lvm_vbin, g, vop); \
 if (Cp(a) || Cp(b)) return Ap(lvm_cplx_bin, g, vop); \
 if (!isnum(a) || !isnum(b)) return *++Sp = nil, Ip++, Continue(); \
 if (flop(a) || flop(b) || b == nil) { word _res; Have(box_req); \
  ai_flo_t ad = toflo(a), bd = toflo(b); \
  struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_R); \
  Hp += box_req; flo_put(v->shape, (fexpr)); _res = word(v); \
  return *++Sp = _res, Ip++, Continue(); } \
 if (!bigp(a) && !bigp(b)) { intptr_t av = toint(a), bv = toint(b); \
  if (!(av == INTPTR_MIN && bv == -1)) { word _res; Have(box_req); emit_int(av c_op bv); \
   return *++Sp = _res, Ip++, Continue(); } } \
 Pack(g); g = ai_big_binop(g, vop); \
 if (!ai_ok(g)) return ghelp(g); \
 return Unpack(g), Continue(); }
#define avm_ovf(op, builtin) lvm(lvm_##op) { \
 word a = Sp[0], b = Sp[1]; \
 if (charmp(a) && charmp(b)) { intptr_t t; \
  if (!builtin((intptr_t) getcharm(a), (intptr_t) getcharm(b), &t) && \
      t >= fix_min && t <= fix_max) \
   return *++Sp = putcharm(t), Ip++, Continue(); } \
 return Ap(lvm_##op##n, g); }
#define avm_div(op, c_op) lvm(lvm_##op) { \
 word a = Sp[0], b = Sp[1]; \
 if (charmp(a) && charmp(b)) { \
  intptr_t av = getcharm(a), bv = getcharm(b); \
  if (bv != 0 && !(av == INTPTR_MIN && bv == -1)) { \
   intptr_t t = av c_op bv; \
   if (t >= fix_min && t <= fix_max) \
    return *++Sp = putcharm(t), Ip++, Continue(); } } \
 return Ap(lvm_##op##n, g); }
// the ordered comparisons (< <= > >=) and their total order over all values are
// defined after vcmp_int/vcmp_flo (the per-op helpers they reuse), by lvm_vbin.
#define bit_slow(n, c_op) static lvm(lvm_##n##_slow) {               \
 word a = Sp[0], b = Sp[1], _res;                                     \
 if (!(charmp(a) || widep(a)) || !(charmp(b) || widep(b)))                  \
  return *++Sp = nil, Ip++, Continue();                               \
 Have(box_req);                                                       \
 emit_int(toint(a) c_op toint(b));                                    \
 return *++Sp = _res, Ip++, Continue(); }
#define mvm1(n) lvm(lvm_##n) { return Ap(lvm_math1, g, ai_##n); }
#define m1(_) _(sin) _(cos)   // sqrt/exp/tan/atan derived; sin/cos/log are the kept transcendentals (log has its own ap)


avm_slow(add, vop_add, __builtin_add_overflow, ad + bd)
avm_slow(sub, vop_sub, __builtin_sub_overflow, ad - bd)
avm_slow(mul, vop_mul, __builtin_mul_overflow, ad * bd)

avm_slowdiv(fquot, vop_fquot, /, ai_trunc(ad / bd))  // `//` truncating: float operand floors toward zero
avm_slowdiv(rem, vop_rem, %, ai_fmod(ad, bd))    // NaN on bd == 0

// `/` true division: exact integer when b divides a, a float box otherwise (the
// truncating quotient is `//`, lvm_fquot above). Mirrors avm_slowdiv's lane order
// -- array / complex / non-num / float-or-÷0 -- then splits the integer lane on
// divisibility. The bignum lane defers to ai_big_quot_true (same exact-or-float test).
static lvm(lvm_quotn) {
 word a = Sp[0], b = Sp[1];
 if (arrp(a) || arrp(b)) return Ap(lvm_vbin, g, vop_quot);
 if (Cp(a) || Cp(b)) return Ap(lvm_cplx_bin, g, vop_quot);
 if (!isnum(a) || !isnum(b)) return *++Sp = nil, Ip++, Continue();
 if (flop(a) || flop(b) || b == nil) { word _res; Have(box_req);   // ±inf/NaN on ÷0
  ai_flo_t ad = toflo(a), bd = toflo(b);
  struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_R);
  Hp += box_req; flo_put(v->shape, ad / bd); _res = word(v);
  return *++Sp = _res, Ip++, Continue(); }
 if (!bigp(a) && !bigp(b)) { intptr_t av = toint(a), bv = toint(b);  // bv != 0 (b != nil)
  if (!(av == INTPTR_MIN && bv == -1)) {                            // INT_MIN/-1 is exact but overflows -> bignum lane
   if (av % bv == 0) { word _res; Have(box_req); emit_int(av / bv);
    return *++Sp = _res, Ip++, Continue(); }
   word _res; Have(box_req);                                        // inexact -> promote to float
   struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_R);
   Hp += box_req; flo_put(v->shape, (ai_flo_t) av / (ai_flo_t) bv); _res = word(v);
   return *++Sp = _res, Ip++, Continue(); } }
 Pack(g); g = ai_big_quot_true(g);
 if (!ai_ok(g)) return ghelp(g);
 return Unpack(g), Continue(); }

avm_ovf(sub, __builtin_sub_overflow)
// lvm_mul + its kind matrix live after the `+` string lane (they reuse add_name /
// stringrank for the symbol-repetition case), below.

// `+` is overloaded: still arithmetic add, but generic over strings and lists,
// where it is order-preserving concatenation -- a precedes b in the result, with a
// scalar lifted into the sequence on the side it appears (left -> front, right ->
// back). This is deliberately noncommutative (unlike numeric add): the written
// order survives, since concatenation is inherently ordered. (nil counts as the
// number 0 here, not the empty list.)
//   str + str   -> byte concat            list + list -> spine append
//   str + list  -> (cons str list)        list + str  -> (append list (list str))
//   num + str   -> byte at front          str + num   -> byte at back
//   num + list  -> (cons num list)        list + num  -> (append list (list num))
// RUNTIME FLAG: ai_add_lr selects order-preserving (left->front, right->back); set
// it false for the commutative reading (smaller operand always joins the front, so
// a+b == b+a like numeric add). A plain mutable global -> toggleable at runtime.
// FIXME we always want commutative reading so make this false then remove
static const bool ai_add_lr = true;
// THE BYTE LAW: text + number is one byte, STRICTLY -- the value must be an exact
// integer 0..255 (rep-blind, like `=`: 66.0 is 66; a wide box/bignum is never in
// range), anything else nil, like `-` on strings. Returns the byte or -1.
static ai_inline intptr_t seq_byte(word x) {
 if (charmp(x)) { intptr_t v = getcharm(x); return v < 0 || v > 255 ? -1 : v; }
 if (flop(x)) { ai_flo_t f = flo_get(x);
  if (!(f >= 0 && f <= 255)) return -1;                 // range first (nan fails); cast below is safe
  return f != (ai_flo_t) (intptr_t) f ? -1 : (intptr_t) f; }
 return -1; }
// LIST lane: at least one operand is a pair (the matrix only routes list-involved
// pairs here). list+list -> spine append; elt<->list -> the non-list operand joins
// as a scalar element (front if it is on the left, else appended at the tail).
static lvm(lvm_add_seq) {
 word a = Sp[0], b = Sp[1];
 if (twop(a) && twop(b)) {                       // list + list -> append a..b
  uintptr_t n = llen(a); Have(n * Width(struct ai_pair));
  a = Sp[0], b = Sp[1];
  struct ai_pair *base = (struct ai_pair*) Hp, *w = base;
  Hp += n * Width(struct ai_pair);
  for (word l = a; twop(l); l = B(l), w++) ini_two(w, A(l), word(w + 1));
  (w - 1)->b = b;                                // last cdr -> b
  return *++Sp = word(base), Ip++, Continue(); }
 if (twop(a) || twop(b)) {                        // elt <-> list
  bool front = !ai_add_lr || twop(b);              // element on the left -> front
  word lst = twop(a) ? a : b, elt = twop(a) ? b : a;
  if (front) { Sp[0] = elt, Sp[1] = lst; return Ap(lvm_cons, g); }  // (cons elt list)
  uintptr_t n = llen(lst) + 1; Have(n * Width(struct ai_pair));        // append elt at tail
  lst = twop(Sp[0]) ? Sp[0] : Sp[1], elt = twop(Sp[0]) ? Sp[1] : Sp[0];
  struct ai_pair *base = (struct ai_pair*) Hp, *w = base;
  Hp += n * Width(struct ai_pair);
  for (word l = lst; twop(l); l = B(l), w++) ini_two(w, A(l), word(w + 1));
  ini_two(w, elt, nil);                           // trailing (elt . nil)
  return *++Sp = word(base), Ip++, Continue(); }
 return *++Sp = nil, Ip++, Continue(); }          // unreachable: matrix gates on a list

// --- TEXT lane: strings + symbols, name-compatible -------------------------
// The string tower is STRING (rank 0) < UNINTERNED-SYM (1) < INTERNED-SYM (2). A
// symbol's bytes are its name (anonymous -> empty, like ""); a number contributes
// one byte (seq_byte) and sits at the top rank, so min() keeps its partner's type
// (a scalar lifts into whatever it joins). Mixing demotes to the lower rank:
// isym+usym -> usym, sym+str -> str, num+sym -> sym (lifted), num+str -> str. The
// concat is built as one string in operand order, then returned per the result
// rank: string as-is / nom'd to a fresh uninterned sym / interned. An empty
// result is the ai_str_empty singleton, or nil at symbol rank (the symbol
// lane is gated off by the dispatch matrix since the mint round anyway).
static ai_inline struct ai_str *add_name(struct ai *g, word x) {   // symbol -> name string, or 0 (a mint / the core)
 if (x == (word) ai_core_of(g)) return 0;               // () is the core: a nameless point (its atom slots are live VM state, never read)
 word nom = word(sym(x)->nom);
 return nom ? str(nom) : 0; }                           // interned: nom IS the name; a mint nets nom 0 -> nameless
static ai_inline int stringrank(struct ai *g, word x) {    // STR 0 / USYM 1 / ISYM|NUM 2
 if (strp(x)) return 0;
 if (x == (word) ai_core_of(g)) return 1;               // the core is a nameless point: an uninterned (fresh) symbol
 if (symp(x)) return word(sym(x)->nom) ? 2 : 1;
 return 2; }
static ai_inline uintptr_t stringlen(struct ai *g, word x) {  // bytes x contributes to a concat
 if (strp(x)) return len(x);
 if (symp(x)) { struct ai_str *n = add_name(g, x); return n ? n->len : 0; }
 return 1; }                                            // number -> one byte
static ai_inline char *add_emit(struct ai *g, char *w, word x) {  // append x's bytes; return advanced w
 if (strp(x)) return (void) memcpy(w, txt(x), len(x)), w + len(x);
 if (symp(x)) { struct ai_str *n = add_name(g, x);
  return n ? ((void) memcpy(w, txt(n), n->len), w + n->len) : w; }
 return *w = (char) seq_byte(x), w + 1; }               // number -> one byte (gated >= 0 by the byte law)
static lvm(lvm_add_string) {
 word a = Sp[0], b = Sp[1];
 if (arrp(a) || arrp(b)) return *++Sp = nil, Ip++, Continue(); // array <-> string: undefined
 if (!strp(a) && !symp(a) && seq_byte(a) < 0) return *++Sp = nil, Ip++, Continue();  // the byte law
 if (!strp(b) && !symp(b) && seq_byte(b) < 0) return *++Sp = nil, Ip++, Continue();
 int rank = min(stringrank(g, a), stringrank(g, b));
 uintptr_t n = stringlen(g, a) + stringlen(g, b);
 if (!n) return *++Sp = rank ? nil : EmptyString, Ip++, Continue();
 uintptr_t req = str_type_width + b2w(n);
 Have(req);
 a = Sp[0], b = Sp[1];                                  // re-read post-GC
 struct ai_str *z = ini_str((struct ai_str*) Hp, n); Hp += req;
 add_emit(g, add_emit(g, txt(z), a), b);                      // a's bytes then b's, in order
 *++Sp = word(z);
 return rank == 0 ? (Ip++, Continue())                  // string
      : rank == 1 ? Ap(lvm_mint, g)                  // uninterned symbol (fresh)
                  : Ap(lvm_intern, g); }               // interned symbol
static lvm(lvm_0) {                             // unsupported mix (array <-> string)
 return *++Sp = nil, Ip++, Continue(); }

// The fundamental value kind for generic-op dispatch (enum q in ai.h): a fixnum is
// the odd tag (KCharm), a non-data heap pointer is a text/function (KTop), else ai_typ
// gives the data kind. The refinement: a vec expands by element tier -- a rank>=1 vec
// (array) to KArrZ..KArrO and a rank-0 box (a scalar GEM: wide/float/complex) to
// KWide..KCplx -- so the gem tower and the array tower it mirrors both dispatch inline.
// ai_typ still gives KVec (the coarse sentinel) for both; only ai_kind splits them.
// Exported (not inline) so data.c's apply sentinels share it.
enum q ai_kind(word x) {
 if (charmp(x)) return KCharm;
 if (!datp(x)) return mapp(x) ? KMap : KTop;
 enum q k = typ(x);
 if (k != KVec) return k;
 return (enum q) ((vec(x)->rank ? KArrZ : KWide) + vec(x)->type); }

// ============================================================================
// generic-op lane aps, then all three dispatch matrices adjacent, then the
// `+`/`*` dispatchers. The numeric slow lanes (addn/muln…) come from the AVM_*
// macros above; the `+` string lanes (add_seq/add_string) and lvm_0 just above; the
// lambda combinators (lvm_addh/lvm_mulh) near num-ap. Defined here: the `*`
// repeat lane and the apply aps -- everything the matrices reference.
// ============================================================================

// `*` REPEAT lane: the multiplicative analog of `+`'s concat. `*` is "repeated
// `+`": a sequence (string / symbol / list) times a scalar count n is n copies
// joined, just as `(* 2 3)` is 2+2+2. The count is the OTHER operand, SATURATED
// to a green charm (($ c) -- the count law, shared with numeral-apply and array shapes:
// non-positive -> 0 -> the empty singleton, a float ceils, a complex counts by
// total-order-guarded modulus); an array (or any non-number) is not a count ->
// nil. A symbol stays at its own rank (no demotion): an interned name repeats
// to an interned symbol.
static lvm(lvm_mul_rep) {
 word a = Sp[0], b = Sp[1];
 bool aseq = strp(a) || symp(a) || twop(a);
 word seq = aseq ? a : b, cnt = aseq ? b : a;
 if (!isnum(cnt) && !Cp(cnt)) return *++Sp = nil, Ip++, Continue();   // array/non-number count
 uintptr_t n = (uintptr_t) ai_pin(g, cnt);
 if (twop(seq)) {                                  // list -> n copies of the spine
  if (!n) return *++Sp = nil, Ip++, Continue();
  uintptr_t m = llen(seq), total = m * n;
  Have(total * Width(struct ai_pair));
  seq = twop(Sp[0]) ? Sp[0] : Sp[1];               // re-read post-GC
  struct ai_pair *base = (struct ai_pair*) Hp, *w = base;
  Hp += total * Width(struct ai_pair);
  for (uintptr_t i = 0; i < n; i++)
   for (word l = seq; twop(l); l = B(l), w++) ini_two(w, A(l), word(w + 1));
  (w - 1)->b = nil;
  return *++Sp = word(base), Ip++, Continue(); }
 // string / symbol: repeat the byte content (a symbol's name; anonymous -> empty)
 int rank = strp(seq) ? 0 : stringrank(g, seq);         // 0 str / 1 usym / 2 isym
 struct ai_str *src = strp(seq) ? str(seq) : add_name(g, seq);
 uintptr_t sl = src ? src->len : 0, total = sl * n;
 if (!total) return *++Sp = rank ? nil : EmptyString, Ip++, Continue();
 uintptr_t req = str_type_width + b2w(total);
 Have(req);
 seq = (strp(Sp[0]) || symp(Sp[0])) ? Sp[0] : Sp[1];   // re-read post-GC
 src = strp(seq) ? str(seq) : add_name(g, seq);
 struct ai_str *z = ini_str((struct ai_str*) Hp, total); Hp += req;
 for (uintptr_t i = 0; i < n; i++) memcpy(txt(z) + i * sl, txt(src), sl);
 *++Sp = word(z);
 return rank == 0 ? (Ip++, Continue())             // string
      : rank == 1 ? Ap(lvm_mint, g)             // uninterned symbol
                  : Ap(lvm_intern, g); }          // interned symbol

// --- apply lane (the data-value `(g x)` aps; moved here from data.c) -----
// When a data value is applied, its sentinel (data.c, pinned in the ai_data
// section) tail-jumps through ai_apply_mx[ai_typ(Ip)][ai_kind(Sp[0])] -- the static
// kind of the applied value and the dynamic kind of the argument. Every data kind
// has a meaningful apply (pair = eliminator, string/symbol = byte index, numeric
// tower = Church numeral); opaque handles (ports, buffers) behave as 0 via their
// own lvm_* sentinel, not through here. Maps look up via lvm_map_lookup (a text
// ap, not a data sentinel), so they do not appear in this table.

// (s k): applying a string indexes it -- k a byte offset, result the unsigned byte
// 0..255 there, 1 if k is non-numeric or out of range (matches "" == 0: a numeric
// ("" k) is the Church numeral k**0 == 1). No alloc, unwinds like self-quote.
static lvm(data_string_apply) {
 word k = Sp[0], v = putcharm(1), n;
 if (oddp(k) && (n = getcharm(k)) >= 0 && n < (word) len(Ip))
  v = putcharm((unsigned char) txt(Ip)[n]);
 return Ip = cell(*++Sp), *Sp = v, Continue(); }

// (y k): applying a symbol indexes its underlying name string, so (y k) == (nom k).
// nom encodes the kind: a string is the name (interned), a symbol is the naming
// symbol of a named-uninterned sym (follow once to its string nom), 0 is an anonymous
// nom. With no underlying string we act like 0 (absent name == "" == 0 -> 1).
// applying a symbol: the name-index is RELEASED (the string semantics left the
// symbols with the mint round) -- a symbol is a point with a spelling attribute,
// and a point applies as every unit does: const-1, like 0, (), and the hots.
static lvm(data_sym_apply) {
 return Ip = cell(*++Sp), *Sp = putcharm(1), Continue(); }

// (n x): applying a number is Church-numeral application, like a fixnum (cf.
// lvm_numap). Fixnums reach num-ap via the odd-tag check in lvm_ap; the rest of the
// tower (floats, boxes, complex, arrays -- all lvm_vec -- and bignums) are heap
// pointers, so they arrive at their data sentinel. We lay the same [n, num-ap, x, ret]
// frame and run numap_drive, handing the boxed operator n to the l num-ap ap,
// which picks exponentiate / compose / self by operand+operator kind.
static lvm(data_num_apply) {
 Have(2);
 word h = resolve_hot(g, "num-ap", 6);
 word n = word(Ip), x = Sp[0], ret = Sp[1], *dst = Sp - 2;
 dst[0] = n, dst[1] = h, dst[2] = x, dst[3] = ret;
 return Sp = dst, Ip = (union u*) numap_drive, Continue(); }

// ((a . b) g) == (g a b): a pair is its own Church eliminator (cons = \a b g.g a b).
// Re-enter the apply protocol via a static driver text: lay the stack as the two
// curried calls expect, then [ap ; swap+ap ; ret0] runs ((g a) b). pair_swap reorders
// [result, b] -> [b, result] so the second ap sees arg=b, fn=(g a). The driver lives
// in .data, so the return addresses it leaves on the stack fall outside the GC pool.
static lvm(pair_swap) {
 word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t;
 return Ap(lvm_ap, g); }
static union u const pair_drive[] = { {lvm_ap}, {.ap = pair_swap}, {.ap = lvm_ret0} };
static lvm(data_pair_apply) {
 Have(2);
 word a = A(Ip), b = B(Ip), fn = Sp[0];     // re-read after the Have guard; no alloc past here
 Sp -= 2;                                    // grow the frame to [a, fn, b, ret]
 Sp[0] = a, Sp[1] = fn, Sp[2] = b;           // Sp[3] = ret (was Sp[1]) stays put
 return Ip = (union u*) pair_drive, Continue(); }

// === the three generic-op dispatch matrices, adjacent ======================
// All indexed by ai_kind (ai_apply_mx's row by ai_typ, the data-kind subrange). The kind
// order (ai.h) makes each lane a contiguous block: [KCharm..KArrO] arithmetic (the
// scalar GEM tower charm/wide/float/complex/big, the vec sentinel, then the parallel
// array tower arrZ/arrR/arrC/arrO), then [KString..KTwo] sequence, then KMap, then KTop.
// The rows below are NAMED-index (NUMK + the five) -- adding a kind can't shift a column.
// Lanes:
//   *n   = numeric tower & arrays (arithmetic / broadcast) -- the lane ap still
//          refines by ai_vec_type; every gem/array kind routes identically (NUMK).
//   add_seq = a list anywhere (other operand a scalar element / spine); pair wins
//   add_string = strings (+ a number as one byte -- the byte law; nils an array
//              operand internally). SYMBOLS left the string algebra with the mint
//              round: their string cells are lvm_0 (intern/string = the explicit bridge)
//   mul_rep  = sequence * scalar-count -> repetition
//   *l   = a LAMBDA-or-MAP operand (precedence: the KMap/KTop rows+cols) -- Church
//          add / compose; a map IS a lookup lambda for +/*, kept deliberately, so
//          its rung shares the lanes (the rung exists for the order)
//   lvm_0 = undefined (-> nil): sequence*sequence
// Precedence (high->low): lambda > map > pair > text > number(incl array).

// `+`: numbers add, lists/text concat, lambdas/maps Church-add. KMap/KTop rows+cols all addl.
// Named-index rows (NOT positional): one column value per OTHER-operand kind, so
// inserting a kind can't silently shift a column. NUMK fills the whole arithmetic
// lane -- every numeric kind (the scalar gems KCharm/KWide/KFlo/KCplx/KBig, the KVec
// sentinel, and the arrays KArrZ..KArrO) with one value v; the five non-numeric
// columns (string/sym/two/map/top) are named explicitly. Unnamed entries would be
// NULL (a crash), so every row names all 15 columns via NUMK + the five.
#define NUMK(v) [KCharm]=v,[KWide]=v,[KFlo]=v,[KCplx]=v,[KBig]=v,[KVec]=v,\
                [KArrZ]=v,[KArrR]=v,[KArrC]=v,[KArrO]=v
#define ADD_NUM { NUMK(lvm_addn),     [KString]=lvm_add_string, [KSym]=lvm_0,       [KTwo]=lvm_add_seq, [KMap]=lvm_addh, [KTop]=lvm_addh }
#define ADD_STR { NUMK(lvm_add_string),[KString]=lvm_add_string,[KSym]=lvm_0,       [KTwo]=lvm_add_seq, [KMap]=lvm_addh, [KTop]=lvm_addh }
#define ADD_SYM { NUMK(lvm_0),        [KString]=lvm_0,          [KSym]=lvm_0,       [KTwo]=lvm_add_seq, [KMap]=lvm_addh, [KTop]=lvm_addh }
#define ADD_TWO { NUMK(lvm_add_seq),  [KString]=lvm_add_seq,    [KSym]=lvm_add_seq, [KTwo]=lvm_add_seq, [KMap]=lvm_addh, [KTop]=lvm_addh }
#define ADD_H   { NUMK(lvm_addh),     [KString]=lvm_addh,       [KSym]=lvm_addh,    [KTwo]=lvm_addh,    [KMap]=lvm_addh, [KTop]=lvm_addh }
static lvm_t *const ai_add_mx[KN][KN] = {
 [KCharm]=ADD_NUM, [KWide]=ADD_NUM, [KFlo]=ADD_NUM, [KCplx]=ADD_NUM, [KBig]=ADD_NUM, [KVec]=ADD_NUM,
 [KArrZ]=ADD_NUM, [KArrR]=ADD_NUM, [KArrC]=ADD_NUM, [KArrO]=ADD_NUM,
 [KString]=ADD_STR, [KSym]=ADD_SYM, [KTwo]=ADD_TWO, [KMap]=ADD_H, [KTop]=ADD_H,
};
#undef ADD_NUM
#undef ADD_STR
#undef ADD_SYM
#undef ADD_TWO
#undef ADD_H
// `*`: the semiring product whose `+` is the lane above. numbers multiply, sequence
// * count repeats, lambdas/maps compose (Church mul). seq*seq -> nil (so the string
// and two rows agree: a number repeats, everything else nils, lambda/map composes).
#define MUL_NUM { NUMK(lvm_muln),    [KString]=lvm_mul_rep, [KSym]=lvm_0, [KTwo]=lvm_mul_rep, [KMap]=lvm_mulh, [KTop]=lvm_mulh }
#define MUL_REP { NUMK(lvm_mul_rep), [KString]=lvm_0,       [KSym]=lvm_0, [KTwo]=lvm_0,       [KMap]=lvm_mulh, [KTop]=lvm_mulh }
#define MUL_SYM { NUMK(lvm_0),       [KString]=lvm_0,       [KSym]=lvm_0, [KTwo]=lvm_0,       [KMap]=lvm_mulh, [KTop]=lvm_mulh }
#define MUL_H   { NUMK(lvm_mulh),    [KString]=lvm_mulh,    [KSym]=lvm_mulh,[KTwo]=lvm_mulh,  [KMap]=lvm_mulh, [KTop]=lvm_mulh }
static lvm_t *const ai_mul_mx[KN][KN] = {
 [KCharm]=MUL_NUM, [KWide]=MUL_NUM, [KFlo]=MUL_NUM, [KCplx]=MUL_NUM, [KBig]=MUL_NUM, [KVec]=MUL_NUM,
 [KArrZ]=MUL_NUM, [KArrR]=MUL_NUM, [KArrC]=MUL_NUM, [KArrO]=MUL_NUM,
 [KString]=MUL_REP, [KSym]=MUL_SYM, [KTwo]=MUL_REP, [KMap]=MUL_H, [KTop]=MUL_H,
};
#undef MUL_NUM
#undef MUL_REP
#undef MUL_SYM
#undef MUL_H
#undef NUMK
// apply: [applied data kind = ai_typ(Ip)][argument kind = ai_kind(arg)]. Rows are by
// ai_typ (the coarse data kind, so still KVec for any vec); the columns are ai_kind, so
// arow names the gem kinds too. Every row is arg-kind-uniform today (arow fills all
// columns); the 2-D shape is the hook for later argument-kind branching.
#define arow(h) { [KCharm]=h,[KWide]=h,[KFlo]=h,[KCplx]=h,[KBig]=h,[KVec]=h,[KArrZ]=h,[KArrR]=h,\
                  [KArrC]=h,[KArrO]=h,[KString]=h,[KSym]=h,[KTwo]=h,[KMap]=h,[KTop]=h }
lvm_t *ai_apply_mx[KN][KN] = {
 [KTwo]  = arow(data_pair_apply), [KVec]  = arow(data_num_apply),
 [KSym]  = arow(data_sym_apply),
 [KString] = arow(data_string_apply), [KBig]  = arow(data_num_apply), };
#undef arow

// === the `+`/`*` dispatchers (fixnum fast path, then the matrix) ============
lvm(lvm_add) {
 word a = Sp[0], b = Sp[1]; intptr_t t;
 if (charmp(a) && charmp(b)
     && !__builtin_add_overflow((intptr_t) getcharm(a), (intptr_t) getcharm(b), &t)
     && t >= fix_min && t <= fix_max)
  return *++Sp = putcharm(t), Ip++, Continue();
 return Ap(ai_add_mx[ai_kind(a)][ai_kind(b)], g); }
lvm(lvm_mul) {
 word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) { intptr_t t;
  if (!__builtin_mul_overflow((intptr_t) getcharm(a), (intptr_t) getcharm(b), &t)
      && t >= fix_min && t <= fix_max)
   return *++Sp = putcharm(t), Ip++, Continue(); }
 return Ap(ai_mul_mx[ai_kind(a)][ai_kind(b)], g); }

avm_div(fquot, /)                               // `//` fixnum fast path: truncating quotient
avm_div(rem, %)
// `/` fixnum fast path: stay exact only when b divides a; otherwise the slow lane
// promotes to a float box. The INT_MIN/-1 guard precedes the `%` (it would be UB).
lvm(lvm_quot) {
 word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) { intptr_t av = getcharm(a), bv = getcharm(b);
  if (bv != 0 && !(av == INTPTR_MIN && bv == -1) && av % bv == 0) {
   intptr_t t = av / bv;
   if (t >= fix_min && t <= fix_max) return *++Sp = putcharm(t), Ip++, Continue(); } }
 return Ap(lvm_quotn, g); }

// The ordered comparisons (lvm_lt/le/gt/ge) and their total order are defined
// after vcmp_int/vcmp_flo (the per-op trichotomy helpers), near lvm_vbin.

// Bitwise and/or/xor: fast both-fixnum tag trick (two odds stay odd under &
// and |; ^ clears the tag bit so we re-set it). A box operand routes to the
// slow ap, which works at full width and demotes-or-boxes; these are
// integer-only, so a float (or any non-integer) operand yields nil.
bit_slow(band, &) bit_slow(bor, |) bit_slow(bxor, ^)
lvm(lvm_band) { word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) return *++Sp = (a & b) | 1, Ip++, Continue();
 return Ap(lvm_band_slow, g); }
lvm(lvm_bor) { word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) return *++Sp = (a | b) | 1, Ip++, Continue();
 return Ap(lvm_bor_slow, g); }
lvm(lvm_bxor) { word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) return *++Sp = (a ^ b) | 1, Ip++, Continue();
 return Ap(lvm_bxor_slow, g); }
// (bitwise complement is `(^ x -1)`; logical not is the `!` reader sigil / `nilp`.)

// >> : arithmetic right shift. A fixnum value only shrinks, so it keeps a
// non-allocating fast path; a boxed value routes to the slow ap.
static lvm(lvm_bsr_slow) { word a = Sp[0], b = Sp[1], _res;
 if (!(charmp(a) || widep(a)) || !charmp(b)) return *++Sp = nil, Ip++, Continue();
 Have(box_req);
 emit_int(toint(a) >> getcharm(b));
 return *++Sp = _res, Ip++, Continue(); }
lvm(lvm_bsr) { word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b))
  return *++Sp = putcharm(getcharm(a) >> getcharm(b)), Ip++, Continue();
 return Ap(lvm_bsr_slow, g); }

// << : can overflow the tag, so it always runs through the box/demote path
// (emit_int still demotes small results — only genuinely wide values
// allocate). Shift done in uintptr_t for well-defined overflow.
lvm(lvm_bsl) { word a = Sp[0], b = Sp[1], _res;
 if (!(charmp(a) || widep(a)) || !charmp(b)) return *++Sp = nil, Ip++, Continue();
 Have(box_req);
 emit_int((intptr_t)((uintptr_t) toint(a) << getcharm(b)));
 return *++Sp = _res, Ip++, Continue(); }

op(lvm_fixp, 1, oddp(Sp[0]) ? putcharm(1) : nil)
// `nilp`/`not`: the falsy predicate -- the efficient generic form of (= 0 ($ x)),
// via ai_nilp, which reads the net's sign without the clamp (a sym/string/fn is truthy
// with no walk). The single truthiness oracle: `?` (lvm_cond), nilp, and aall all
// consult ai_nilp, so `(? (nilp e) a b)` == `(? e b a)` -- the wev pass drops such a
// nilp wrapper. Use `(= x 0)` for a literal scalar-zero test.
op11(lvm_nilp, ai_nilp(g, Sp[0]) ? putcharm(1) : nil)

// Unary math nif: numeric arg → double, call fn, box the rank-0 f64 result.
// Non-numeric arg → nil. TCO-clean (no & escapes).
static lvm(lvm_math1, ai_flo_t (*fn)(ai_flo_t)) {
 word a = Sp[0];
 if (arrp(a)) {                               // (sin arr) etc. -> float array; complex array undefined
  if (vec(a)->type == ai_C) return Sp[0] = nil, Ip++, Continue();
  return Ap(lvm_vmap1, g, fn); }
 if (!isnum(a)) return Sp[0] = nil, Ip++, Continue();
 ai_flo_t ad = toflo(a), rd = fn(ad);
 uintptr_t req = Width(struct ai_vec) + Width(ai_flo_t);
 Have(req);
 struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_R);
 Hp += req;
 flo_put(v->shape, rd);
 return Sp[0] = word(v), Ip++, Continue(); }

static lvm(lvm_math2, ai_flo_t (*fn)(ai_flo_t, ai_flo_t)) {
 word a = Sp[0], b = Sp[1];
 if (arrp(a) || arrp(b)) {                               // (pow arr ..) etc. -> float array
  if ((arrp(a) && vec(a)->type == ai_C) || (arrp(b) && vec(b)->type == ai_C))
   return *++Sp = nil, Ip++, Continue();                 // complex array undefined here
  return Ap(lvm_vmap2, g, fn); }
 if (!isnum(a) || !isnum(b)) return
  *++Sp = nil, Ip++, Continue();
 ai_flo_t ad = toflo(a), bd = toflo(b), rd = fn(ad, bd);
 uintptr_t req = Width(struct ai_vec) + Width(ai_flo_t);
 Have(req);
 struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_R);
 Hp += req;
 flo_put(v->shape, rd);
 return *++Sp = word(v), Ip++, Continue(); }


// ai_sin .. ai_pow are macro aliases (g/g.h) for the C library math
// functions: libm on hosted builds, k/libc.c on the freestanding
// kernel. The op generators reference them through ai_##n, which the
// preprocessor resounds into the real names after pasting.
m1(mvm1)

// (log x): natural log, climbing the tier lattice like everything else. A
// positive real stays float (math1); a negative real or a complex scalar
// widens to the complex principal value ~((log |z|) (arg z)) -- so euler's
// identity holds in the direction floats can state it exactly: (log -1) =
// (* i pi), since atan2(0,-1) is pi by IEEE fiat and i moves it with exact
// 0/1 products. Arrays stay elementwise float (negative elements -> nan).
lvm(lvm_log) {
 word a = Sp[0];
 ai_flo_t m, th;
 if (Cp(a)) m = ai_log(cplx_mod(a)), th = ai_atan2(cplx_im(a), cplx_re(a));
 else if (isnum(a) && toflo(a) < 0) { ai_flo_t ad = toflo(a);
  m = ai_log(-ad), th = ai_atan2(0, ad); }
 else return Ap(lvm_math1, g, ai_log);
 Have(cplx_req);
 struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_C);
 Hp += cplx_req;
 cplx_put(v, m, th);
 return Sp[0] = word(v), Ip++, Continue(); }

op11(lvm_flop, flop(Sp[0]) ? putcharm(1) : nil)

// ============================================================================
// vec
// ============================================================================
size_t const ai_T[] = {
 [ai_Z] = Bytes,
 [ai_R] = Bytes,
 [ai_C] = 2 * Bytes,      // complex scalar: (re, im)
 [ai_O] = Bytes, };       // object: one tagged l word per element

uintptr_t ai_vec_bytes(struct ai_vec *v) {
 return sizeof(struct ai_vec) + v->rank * sizeof(word) + ai_T[v->type] * vec_nelem(v); }

// ============================================================================
// rng
// ============================================================================
// Step 8 -- random numbers. xoshiro256++ (Blackman & Vigna, public domain)
// seeded by SplitMix64. State is a rank-1 i64 vec of length 4 (256 bits) that
// rides the existing vec machinery -- no data sentinel, no enum q / ai_data_n
// / gen_data / wasm-vt changes (cf. complex, Step 7). The payload is treated
// as raw bytes (memcpy), never via the typed vec_get/put accessors, so the
// 64-bit limbs survive on 32-bit ports and a given seed reproduces the same
// sequence on host/kernel/MCU/WASM/Playdate. C holds no RNG state and never
// draws: the only primitives are rng-seed (fresh state from a fixnum) and the
// functional steps rand-next/randf-next (copy the input state, step the copy,
// return (value . new-state) -- the input is never mutated). The global stream
// (rand/randf over book['rng-state]) is prel lisp. Not a CSPRNG.

static ai_inline uint64_t rotl64(uint64_t x, int k) {
 return (x << k) | (x >> (64 - k)); }

// All the uint64_t scratch (s[4]) lives in these ai_noinline helpers that move it
// via memcpy: taking &s in a VM ap would defeat the Continue() sibcall (see
// the flo_get note in i.h), and memcpy is alignment-safe (a 32-bit port's
// vec_data is only 4-byte aligned, so a raw uint64_t* deref could fault).

// Advance the 4-word state stored at `payload` and return one 64-bit draw.
static ai_noinline uint64_t rng_step(void *payload) {
 uint64_t s[4];
 memcpy(s, payload, sizeof s);
 uint64_t const result = rotl64(s[0] + s[3], 23) + s[0];
 uint64_t const t = s[1] << 17;
 s[2] ^= s[0]; s[3] ^= s[1]; s[1] ^= s[2]; s[0] ^= s[3];
 s[2] ^= t; s[3] = rotl64(s[3], 45);
 memcpy(payload, s, sizeof s);
 return result; }

// Fill the 4-word state at `payload` from a 64-bit seed via SplitMix64. The
// all-zero state is xoshiro's fixed point, so substitute a nonzero word if it
// ever arises (SplitMix64 makes that practically impossible, but be exact).
static ai_noinline void rng_seed_into(void *payload, uint64_t seed) {
 uint64_t s[4], x = seed;
 for (int i = 0; i < rng_state_len; i++) {
  uint64_t z = (x += (uint64_t) 0x9e3779b97f4a7c15);
  z = (z ^ (z >> 30)) * (uint64_t) 0xbf58476d1ce4e5b9;
  z = (z ^ (z >> 27)) * (uint64_t) 0x94d049bb133111eb;
  s[i] = z ^ (z >> 31); }
 if (!(s[0] | s[1] | s[2] | s[3])) s[0] = 1;
 memcpy(payload, s, sizeof s); }

// Map a 64-bit draw to a float in [0,1): keep the high mantissa bits and scale.
static ai_inline ai_flo_t u64_to_unit(uint64_t u) {
#if Bits >= 64
 return (ai_flo_t) (u >> 11) * (ai_flo_t) 0x1.0p-53;
#else
 return (ai_flo_t) (uint32_t) (u >> 40) * (ai_flo_t) 0x1.0p-24f;
#endif
}

// Shape v as an i64 state vec (rank 1, len 4) and seed it. ini_vec + a
// pointer write only, so an inlining caller keeps its tail call; the &s
// scratch stays inside rng_seed_into.
void ai_rng_seed(struct ai_vec *v, uint64_t seed) {
 ini_vec(v, rng_vt, 1);
 v->shape[0] = rng_state_len;
 rng_seed_into(vec_data(v), seed); }

// Is x a well-formed state vec (rank-1 i64, length 4)?
static ai_inline bool rng_state_p(word x) {
 return packp(x) && vec(x)->rank == 1 && vec(x)->type == rng_vt
        && vec(x)->shape[0] == rng_state_len; }

// Build a fresh state vec at Hp, copying the 4 limbs of `src` into it. Caller
// holds Have(rng_vec_req). Both pointers are heap pointers -> no &local escape.
static ai_inline struct ai_vec *rng_copy(ai_word **hp, struct ai_vec *src) {
 struct ai_vec *v = (struct ai_vec*) *hp;
 *hp += rng_vec_req;
 ini_vec(v, rng_vt, 1);
 v->shape[0] = rng_state_len;
 memcpy(vec_data(v), vec_data(src), rng_payload_bytes);
 return v; }

// Canonicalize a 62-bit draw to the smallest integer tier (a fixnum on a 64-bit
// word, a bignum on a 32-bit one). Out-of-line so its limb[] scratch and the
// ai_big_canon call don't force a frame in lvm_rand_next -- a frame there would
// turn the tail Continue() into a ret and trip `make vmret`. The caller has
// already Have'd rng_draw_req; ai_big_canon only bumps g->hp (no GC).
static ai_noinline word rng_canon(struct ai *g, uint64_t r) {
 uint32_t limb[2] = { (uint32_t) r, (uint32_t) (r >> 32) };
 return ai_big_canon(&g->hp, limb, 2, false); }

// (rng-seed n): a fresh state vec deterministically seeded from fixnum n. A
// non-fixnum seeds from 0.
lvm(lvm_rng_seed) {
 word n = Sp[0];
 uint64_t seed = charmp(n) ? (uint64_t) (intptr_t) getcharm(n) : 0;
 Have(rng_vec_req);
 struct ai_vec *v = (struct ai_vec*) Hp; Hp += rng_vec_req;
 ai_rng_seed(v, seed);
 return Sp[0] = word(v), Ip++, Continue(); }

// (rand-next st): functional draw -> (value . st'), value a non-negative
// integer of a fixed 62 bits -- the 64-bit host's fixnum width -- so a seed
// yields the IDENTICAL integer on every target (a fixnum on a 64-bit word, a
// bignum on a 32-bit one), not a word-width truncation. The draw is split into
// two 32-bit limbs and canonicalized; ai_big_canon picks the tier. st is copied
// (referentially transparent); st' is the stepped copy.
#define rng_draw_mask (((uint64_t) 1 << 62) - 1)              // 62 bits = 64-bit fix_max
#define rng_draw_req  (Width(struct ai_big) + b2w(2 * sizeof(uint32_t)))  // worst case: a 2-limb bignum
lvm(lvm_rand_next) {
 word st = Sp[0];
 if (!rng_state_p(st)) return Sp[0] = nil, Ip++, Continue();
 Have(rng_vec_req + rng_draw_req + Width(struct ai_pair));
 st = Sp[0];                                 // re-read post-Have
 struct ai_vec *v = rng_copy(&Hp, vec(st));
 uint64_t r = rng_step(vec_data(v)) & rng_draw_mask;
 Pack(g);
 word val = rng_canon(g, r);
 Unpack(g);
 struct ai_pair *p = (struct ai_pair*) Hp; Hp += Width(struct ai_pair);
 ini_two(p, val, word(v));
 return Sp[0] = word(p), Ip++, Continue(); }

// (randf-next st): functional draw -> (float . st'), float in [0,1).
lvm(lvm_randf_next) {
 word st = Sp[0], _res;
 if (!rng_state_p(st)) return Sp[0] = nil, Ip++, Continue();
 Have(rng_vec_req + box_req + Width(struct ai_pair));
 st = Sp[0];                                 // re-read post-Have
 struct ai_vec *v = rng_copy(&Hp, vec(st));
 uint64_t r = rng_step(vec_data(v));
 ai_flo_t u = u64_to_unit(r);
 emit_flo(u);                                // box at Hp, into _res
 struct ai_pair *p = (struct ai_pair*) Hp; Hp += Width(struct ai_pair);
 ini_two(p, _res, word(v));
 return Sp[0] = word(p), Ip++, Continue(); }

// ============================================================================
// eq
// ============================================================================
// α-equivalence of two stored lambda source \-exprs. Bound variables (a \ form's
// leading params -- imports + params, since a closure parks (\ imps… params… body))
// match by binder position, not name, so (\ x x) and (\ y y) compare equal; free
// variables match by symbol. `:` binders are not tracked (a sound, conservative
// incompleteness: a let-rebound name needs the same spelling); a one-operand \ is
// quote -- compared as data via eqv, never walked for binders.
struct arib { word la, lb; int na, nb; struct arib *up; };  // binder rib: (p…body) lists + param counts
static int arib_pos(word s, word l, int n) {                // index of s among the first n of l, else -1
 for (int i = 0; i < n && twop(l); i++, l = B(l)) if (A(l) == s) return i;
 return -1; }
static bool ai_isbs(struct ai *g, word h) {                  // h is the `\` symbol?
 struct ai_str *n; return symp(h) && h != (word) ai_core_of(g) && (n = sym(h)->nom) && n->len == 1 && n->bytes[0] == '\\'; }
static bool salpha(struct ai *g, word a, word b, struct arib *env) {
 if (symp(a) || symp(b)) {
  if (!symp(a) || !symp(b)) return false;
  for (struct arib *r = env; r; r = r->up) {
   int ia = arib_pos(a, r->la, r->na), ib = arib_pos(b, r->lb, r->nb);
   if (ia >= 0 || ib >= 0) return ia == ib; }               // bound at this rib: positions agree
  return a == b; }                                          // both free: same symbol
 if (!twop(a) || !twop(b)) return eqv(g, a, b);             // numbers / strings / atoms
 if (ai_isbs(g, A(a)) && ai_isbs(g, A(b))) {                        // both `\`-headed
  word pa = B(a), pb = B(b);
  if (!twop(B(pa)) || !twop(B(pb))) return eqv(g, a, b);    // one-operand \ = quote: data
  int na = 0, nb = 0;                                       // (\ p1..pn body): params = init, body = last
  word t = pa;
  for (; twop(B(t)); t = B(t)) na++;
  word ba = A(t);
  for (t = pb; twop(B(t)); t = B(t)) nb++;
  word bb = A(t);
  if (na != nb) return false;
  struct arib r = { pa, pb, na, nb, env };
  return salpha(g, ba, bb, &r); }
 return salpha(g, A(a), A(b), env) && salpha(g, B(a), B(b), env); }  // structural: app / ? / :
// α-invariant hash of a source \-expr, parallel to salpha: a bound variable hashes by its
// binder coordinate (rib depth, position), a free variable by its symbol code, so α-equal
// lambdas hash equal and the total order (cmp3, by repr hash) agrees with `=`.
static uintptr_t shash(struct ai *g, word x, struct arib *env) {
 if (symp(x)) {
  int d = 0;
  for (struct arib *r = env; r; r = r->up, d++) {
   int i = arib_pos(x, r->la, r->na);
   if (i >= 0) return rot((uintptr_t) (d * 131 + i + 1) * mix); }
  return sym(x)->code; }
 if (!twop(x)) return hash(g, x);
 if (ai_isbs(g, A(x))) {
  word p = B(x);
  if (!twop(B(p))) return hash(g, x);                       // one-operand \ = quote: data
  int n = 0;
  word t = p;
  for (; twop(B(t)); t = B(t)) n++;
  word body = A(t);
  struct arib r = { p, p, n, n, env };
  return (mix * (uintptr_t) (n + 7)) ^ (shash(g, body, &r) * mix); }
 return (mix ^ (shash(g, A(x), env) * mix)) ^ (shash(g, B(x), env) * mix); }
// The numeral<->lambda `=` bridges: 1 is the identity numeral ((1 z) = z) and
// 0 is const-1 ((0 z) = 1), so a one-binder lambda whose body is that binder
// equals 1, and one whose body is the literal 1 equals 0. All a-variants count;
// idp stays false (distinct objects). Closures / multi-binder never match.
static word lam_src1(struct ai *c, word v) {           // 1-binder lambda -> (binder body), else 0
 if (!lamp(v) || datp(v)) return 0;
 if (!(ptr(v) > ptr(c) && ptr(v) < ptr(c) + c->len)) return 0;  // in-pool only: k[-1]/k valid
 union u *k = cell(v);
 if (fn_partialp(k)) return 0;
 word s = fn_src(c, k, v);                            // s = (\ b.. body)
 if (!s || !lam_isp(c, s)) return 0;
 word ops = B(s);                                     // (binder body ..)
 return !twop(B(B(ops))) && symp(A(ops)) ? ops : 0; } // exactly one binder
static bool id_lam(struct ai *c, word v) {             // (\ x x): body IS the binder
 word ops = lam_src1(c, v);
 return ops && A(ops) == A(B(ops)); }
static bool k1_lam(struct ai *c, word v) {             // (\ _ 1): body is the literal 1
 word ops = lam_src1(c, v);
 return ops && A(B(ops)) == putcharm(1); }
ai_noinline bool eqv(struct ai *g, word a, word b) {
 word *base = off_pool(g), *top = base + g->len, *w = base;
 struct ai *c = ai_core_of(g);
 for (;;) {
  if (a != b) {
   // Function values: structural equality of compiled lambdas/closures. A no-capture
   // lambda parks its source \-expr (fn_src) -> compare those structurally. A closure
   // is a partial-application chain (fn_partialp) -> compare the base function and each
   // captured arg pairwise, so (\ y (+ x y))[x=1] != [x=2]. Bifs / source-less / maps /
   // ports / mixed fall through to identity (a==b already failed -> false).
   if (lamp(a) && lamp(b) && !datp(a) && !datp(b)) {
    union u *ka = cell(a), *kb = cell(b);
    if (fn_partialp(ka) && fn_partialp(kb)) {
     int na, nb; union u *ba = fn_base(ka, &na), *bb = fn_base(kb, &nb);
     if (na != nb) return false;
     if (top - w < 2 * (na + 1)) __builtin_trap();        // worklist overflow / cycle
     for (int i = 0; i < na; i++) *w++ = fn_arg(ka, i, na), *w++ = fn_arg(kb, i, nb);
     a = (word) ba, b = (word) bb; continue; }
    word sa = fn_src(c, ka, a), sb = fn_src(c, kb, b);
    if (sa && sb && !fn_partialp(ka) && !fn_partialp(kb)) {
     if (!salpha(g, sa, sb, 0)) return false;             // α-equivalence of source \-exprs
     a = b; continue; }                                   // equal -> drain worklist
    return false; }
   // The numerals 1 and 0 bridge to their lambdas extensionally: (\ x x), (\ _ 1).
   if ((a == putcharm(1) && id_lam(c, b)) || (b == putcharm(1) && id_lam(c, a))) { a = b; continue; }
   if ((a == putcharm(0) && k1_lam(c, b)) || (b == putcharm(0) && k1_lam(c, a))) { a = b; continue; }
   if (((a | b) & 1) || !datp(a) || !datp(b) || typ(a) != typ(b)) return false;
   switch (typ(a)) {
    default: return false;
    case KTwo:
     if (top - w < 2) __builtin_trap();     // worklist overflow: a cycle
     *w++ = B(a), *w++ = B(b), a = A(a), b = A(b);
     continue;
    case KVec: {
     size_t la = ai_vec_bytes(vec(a)), lb = ai_vec_bytes(vec(b));
     if (la != lb || memcmp(vec(a), vec(b), la)) return false;
     break; }
    case KBig: {
     struct ai_big *x = (struct ai_big*) a, *y = (struct ai_big*) b;
     if (x->slen != y->slen) return false;
     size_t nb = (size_t) (x->slen < 0 ? -x->slen : x->slen) * sizeof(uint32_t);
     if (memcmp(x->limb, y->limb, nb)) return false;
     break; }
    case KString:
     if (len(a) != len(b) || memcmp(txt(a), txt(b), len(a))) return false;
     break; } }
  if (w == base) return true;              // worklist drained: all equal
  b = *--w, a = *--w; } }

// (= a b) — value-equality with numeric promotion across the numeric tower
// (fixnum / boxed float / boxed wide int). With a float operand we compare as
// doubles (a box widens via box_get); otherwise eql handles it — two equal
// wide-int boxes match through eqv's vec arm (ai_vec_bytes covers the type +
// payload), while a box and a fixnum never collide since boxes hold only
// out-of-fixnum-range values. Falls through to eql for non-numeric operands so
// symbol/pair/string identity is unchanged. Strictly looser than eqv, which
// still rejects mixed-type pairs (so table keys 3 and 3.0 stay distinct).
lvm(lvm_eq) {
 word a = Sp[0], b = Sp[1];
 // Over a rank>=1 array, `=` is elementwise -> a 0/1 bool array (whole-array
 // equality is `(aall (= a b))`). Rank-0 boxes stay scalar (handled below).
 if (arrp(a) || arrp(b)) return Ap(lvm_vbin, g, vop_eq);
 // Complex equality: equal iff re and im match. A real operand reads as (r, 0),
 // so the cross-real case `(= (cplx 2 0) 2)` is true (numeric widening, like
 // `(= 2 2.0)`); a non-numeric operand makes it false. Done before the float
 // lane so a complex never reaches toflo (which would misread its two words).
 if (Cp(a) || Cp(b)) {
  bool r = (Cp(a) || isnum(a)) && (Cp(b) || isnum(b))
        && (Cp(a) ? cplx_re(a) : toflo(a)) == (Cp(b) ? cplx_re(b) : toflo(b))
        && (Cp(a) ? cplx_im(a) : 0) == (Cp(b) ? cplx_im(b) : 0);
  Sp[1] = r ? putcharm(1) : nil;
  return Sp++, Ip++, Continue(); }
 bool r;
 // A float operand compares as doubles across the whole numeric tower (fixnum /
 // float box / wide-int box / bignum all widen via toflo; a bignum loses
 // precision past 2^53, the documented float caveat). Otherwise eql: two equal
 // bignums match through eqv's KBig arm, and canonical demotion keeps a bignum
 // distinct from any fixnum/box of a different value.
 if (flop(a) || flop(b)) r = isnum(a) && isnum(b) && (toflo(a) == toflo(b));
 else r = eql(g, a, b);
 Sp[1] = r ? putcharm(1) : nil;
 return Sp++, Ip++, Continue(); }

// (same a b) — pointer/word identity, no structural recursion. Distinguishes
// two distinct objects that `=` would conflate (e.g. two equal pairs), so the
// compiler can find a unique marker by identity.
lvm(lvm_same) {
 Sp[1] = Sp[0] == Sp[1] ? putcharm(1) : nil;
 return Sp++, Ip++, Continue(); }

// ============================================================================
// big
// ============================================================================
// Step 6 -- arbitrary-precision integers (bignums). Closes the numeric tower
// fixnum -> wide-int box -> bignum. The representation is the KBig data
// sentinel `struct ai_big` (i.h): sign-magnitude, 32-bit base-2^32 limbs,
// little-endian, top limb nonzero, slen the signed limb count. Zero is never a
// bignum (it demotes to nil), so every bignum has |slen| >= 1 limbs.
//
// All multi-limb work lives in ai_noinline magnitude helpers operating on raw
// uint32_t arrays (no l pointers, no allocation), so the VM-facing entry
// points keep their tail calls and the GC never sees a half-built object. The
// arithmetic uses 32-bit limbs with a uint64_t accumulator on every target:
// limb products fit a uint64_t and Knuth divmod's 2-limb/1-limb step needs no
// __int128 (not guaranteed on freestanding 32-bit ports). Schoolbook mul +
// Knuth Algorithm D divmod -- Karatsuba/Toom are a later speed diff.


// |slen| of a heap bignum.
static ai_inline int big_nlimbs(word x) {
 intptr_t s = ((struct ai_big*) x)->slen;
 return (int) (s < 0 ? -s : s); }

uintptr_t ai_big_bytes(struct ai_big *b) {
 intptr_t n = b->slen < 0 ? -b->slen : b->slen;
 return sizeof(struct ai_big) + (uintptr_t) n * sizeof(uint32_t); }

// --- raw magnitude primitives (little-endian uint32_t limb arrays) ----------
// Callers pass normalized inputs (no leading zero limbs) and normalize outputs
// via ai_big_canon, which strips leading zeros itself.

static int mag_copy(uint32_t *dst, uint32_t const *src, int n) {
 for (int i = 0; i < n; i++) dst[i] = src[i];
 return n; }

// Compare magnitudes: -1 if a<b, 0 if equal, 1 if a>b.
static ai_noinline int mag_cmp(uint32_t const *a, int na, uint32_t const *b, int nb) {
 while (na > 0 && a[na-1] == 0) na--;
 while (nb > 0 && b[nb-1] == 0) nb--;
 if (na != nb) return na < nb ? -1 : 1;
 for (int i = na - 1; i >= 0; i--) if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
 return 0; }

// r = a + b. r distinct from a,b; capacity >= max(na,nb)+1. Returns limb count.
static ai_noinline int mag_add(uint32_t *r, uint32_t const *a, int na, uint32_t const *b, int nb) {
 if (na < nb) { uint32_t const *t = a; a = b; b = t; int u = na; na = nb; nb = u; }
 uint64_t c = 0; int i = 0;
 for (; i < nb; i++) { uint64_t s = (uint64_t) a[i] + b[i] + c; r[i] = (uint32_t) s; c = s >> 32; }
 for (; i < na; i++) { uint64_t s = (uint64_t) a[i] + c;        r[i] = (uint32_t) s; c = s >> 32; }
 if (c) r[i++] = (uint32_t) c;
 return i; }

// r = a - b, requires a >= b (magnitudes). r distinct from a,b. Returns na
// (caller normalizes away any high zero limbs the subtraction produced).
static ai_noinline int mag_sub(uint32_t *r, uint32_t const *a, int na, uint32_t const *b, int nb) {
 int64_t borrow = 0; int i = 0;
 for (; i < nb; i++) {
  int64_t d = (int64_t) a[i] - b[i] - borrow;
  if (d < 0) d += (int64_t) limb_base, borrow = 1; else borrow = 0;
  r[i] = (uint32_t) d; }
 for (; i < na; i++) {
  int64_t d = (int64_t) a[i] - borrow;
  if (d < 0) d += (int64_t) limb_base, borrow = 1; else borrow = 0;
  r[i] = (uint32_t) d; }
 return na; }

// r = a * b (schoolbook). r must be distinct from a,b; capacity >= na+nb. Used
// one-shot by ai_big_binop (the object-array elementwise lane); the scalar `*`
// path instead drives a chunked, yieldable copy of this loop in lvm_bmul.
static ai_noinline void mag_mul(uint32_t *r, uint32_t const *a, int na, uint32_t const *b, int nb) {
 for (int i = 0; i < na + nb; i++) r[i] = 0;
 for (int i = 0; i < na; i++) {
  uint64_t carry = 0, ai = a[i];
  for (int j = 0; j < nb; j++) {
   uint64_t s = ai * b[j] + r[i+j] + carry;
   r[i+j] = (uint32_t) s; carry = s >> 32; }
  r[i+nb] = (uint32_t) carry; } }

// a = a*mul + add, in place (mul,add < 2^32). a capacity must allow one carry
// limb at a[n]. Returns the new limb count. Used by the decimal reader.
static ai_noinline int mag_mul_add_small(uint32_t *a, int n, uint32_t mul, uint32_t add) {
 uint64_t c = add;
 for (int i = 0; i < n; i++) { uint64_t s = (uint64_t) a[i] * mul + c; a[i] = (uint32_t) s; c = s >> 32; }
 if (c) a[n++] = (uint32_t) c;
 return n; }

// a /= d in place (d != 0), returning the remainder. Used by the printer.
static ai_noinline uint32_t mag_divmod_small(uint32_t *a, int n, uint32_t d) {
 uint64_t rem = 0;
 for (int i = n - 1; i >= 0; i--) { uint64_t cur = (rem << 32) | a[i]; a[i] = (uint32_t) (cur / d); rem = cur % d; }
 return (uint32_t) rem; }

// Knuth Algorithm D long division (Hacker's Delight `divmnu`). Divides u (m
// limbs) by v (n limbs, v[n-1] != 0, m >= n): q gets the m-n+1 quotient limbs,
// r the n remainder limbs. un (scratch, >= m+1) and vn (scratch, >= n) hold the
// normalized dividend/divisor. q,r,un,vn all distinct from u,v.
static ai_noinline void mag_divmod(uint32_t *q, uint32_t *r,
  uint32_t const *u, int m, uint32_t const *v, int n, uint32_t *un, uint32_t *vn) {
 uint64_t const B = limb_base;
 if (n == 1) {                                  // single-limb divisor: simple
  uint64_t rem = 0;
  for (int j = m - 1; j >= 0; j--) { uint64_t cur = (rem << 32) | u[j]; q[j] = (uint32_t) (cur / v[0]); rem = cur % v[0]; }
  r[0] = (uint32_t) rem; return; }
 int s = __builtin_clz(v[n-1]);                 // normalize so v[n-1] has its top bit set
 for (int i = n - 1; i > 0; i--) vn[i] = (v[i] << s) | (s ? (uint64_t) v[i-1] >> (32 - s) : 0);
 vn[0] = v[0] << s;
 un[m] = s ? (uint64_t) u[m-1] >> (32 - s) : 0;
 for (int i = m - 1; i > 0; i--) un[i] = (u[i] << s) | (s ? (uint64_t) u[i-1] >> (32 - s) : 0);
 un[0] = u[0] << s;
 for (int j = m - n; j >= 0; j--) {
  uint64_t num = ((uint64_t) un[j+n] << 32) | un[j+n-1];
  uint64_t qhat = num / vn[n-1], rhat = num % vn[n-1];
  while (qhat >= B || qhat * vn[n-2] > ((rhat << 32) | un[j+n-2])) {
   qhat--; rhat += vn[n-1];
   if (rhat >= B) break; }
  int64_t borrow = 0;                           // multiply and subtract qhat*v
  for (int i = 0; i < n; i++) {
   uint64_t p = qhat * vn[i];
   int64_t sub = (int64_t) un[i+j] - borrow - (int64_t) (uint32_t) p;
   un[i+j] = (uint32_t) sub;
   borrow = (int64_t) (p >> 32) - (sub >> 32); }
  int64_t sub = (int64_t) un[j+n] - borrow;
  un[j+n] = (uint32_t) sub;
  q[j] = (uint32_t) qhat;
  if (sub < 0) {                                // qhat was one too big: add back
   q[j]--;
   uint64_t carry = 0;
   for (int i = 0; i < n; i++) { uint64_t t = (uint64_t) un[i+j] + vn[i] + carry; un[i+j] = (uint32_t) t; carry = t >> 32; }
   un[j+n] = (uint32_t) (un[j+n] + carry); } }
 for (int i = 0; i < n; i++) r[i] = s ? (un[i] >> s) | ((uint64_t) un[i+1] << (32 - s)) : un[i]; }

// --- operand loading + tier conversions -------------------------------------

// Load integer operand x (fixnum / wide-int box / bignum -- never a float) as a
// magnitude. A fixnum/box fills `scratch` (1-2 limbs) and points *out at it; a
// bignum points *out into its heap limbs (stable only while no GC runs). Sets
// *neg and returns the limb count (0 for the value zero).
static int load_int_mag(word x, uint32_t scratch[2], uint32_t const **out, bool *neg) {
 if (bigp(x)) { struct ai_big *b = (struct ai_big*) x; intptr_t s = b->slen;
  *neg = s < 0, *out = b->limb; return (int) (s < 0 ? -s : s); }
 intptr_t v = charmp(x) ? (intptr_t) getcharm(x) : box_get(x);
 *neg = v < 0;
 uintptr_t u = *neg ? (uintptr_t) 0 - (uintptr_t) v : (uintptr_t) v;
 scratch[0] = (uint32_t) u;
 int k;
#if Bits == 64
 scratch[1] = (uint32_t) (u >> 32);
 k = scratch[1] ? 2 : scratch[0] ? 1 : 0;
#else
 k = scratch[0] ? 1 : 0;
#endif
 *out = scratch;
 return k; }

ai_flo_t ai_big_to_flo(word x) {
 struct ai_big *b = (struct ai_big*) x;
 intptr_t sl = b->slen;
 bool neg = sl < 0;
 int n = (int) (neg ? -sl : sl);
 double r = 0;
 for (int i = n - 1; i >= 0; i--) r = r * 4294967296.0 + (double) b->limb[i];
 return (ai_flo_t) (neg ? -r : r); }

// The bignum's two's-complement value mod 2^W (its low machine word). Used when
// an integer-array elementwise op must broadcast a bignum scalar down to one
// machine-int element ("arrays win; demote the bignum by its low bits").
intptr_t ai_big_low(word x) {
 struct ai_big *b = (struct ai_big*) x;
 intptr_t sl = b->slen;
 bool neg = sl < 0;
 uintptr_t u = b->limb[0];
#if Bits == 64
 int n = (int) (neg ? -sl : sl);   // limb count only consulted for the 2nd limb
 if (n >= 2) u |= ((uintptr_t) b->limb[1] << 16) << 16;
#endif
 return (intptr_t) (neg ? (uintptr_t) 0 - u : u); }

int ai_big_cmp(word a, word b) {
 uint32_t sa[2], sb[2]; uint32_t const *la, *lb; bool na, nb;
 int nla = load_int_mag(a, sa, &la, &na), nlb = load_int_mag(b, sb, &lb, &nb);
 bool aneg = na && nla > 0, bneg = nb && nlb > 0;   // zero is non-negative
 if (aneg != bneg) return aneg ? -1 : 1;
 int c = mag_cmp(la, nla, lb, nlb);
 return aneg ? -c : c; }

// Demote a magnitude to the smallest tier. Strip leading zeros; a value in
// fixnum range -> a tagged fixnum; in intptr_t range -> a wide-int box; wider
// -> a fresh bignum. Bumps *hp for the box/bignum cases. The single sink that
// keeps the tiers disjoint, so eqv / table keys stay well defined.
word ai_big_canon(ai_word **hp, uint32_t const *limb, int n, bool neg) {
 while (n > 0 && limb[n-1] == 0) n--;
 if (n == 0) return nil;
 int const wlimbs = Bits / 32;                 // 2 on 64-bit, 1 on 32-bit ports
 if (n <= wlimbs) {
  uintptr_t u = limb[0];
  if (wlimbs == 2 && n == 2) u |= ((uintptr_t) limb[1] << 16) << 16;
  uintptr_t const fixmag = (uintptr_t) 1 << (Bits - 2);   // |fix_min|  = 2^(W-2)
  uintptr_t const boxmag = (uintptr_t) 1 << (Bits - 1);   // |INT_MIN|  = 2^(W-1)
  intptr_t val;
  if (!neg) {
   if (u <= fixmag - 1) return putcharm((intptr_t) u);       // fix_max = 2^(W-2)-1
   if (u > boxmag - 1) goto big;                            // > INTPTR_MAX -> bignum
   val = (intptr_t) u; }
  else {
   if (u <= fixmag) return putcharm((intptr_t) ((uintptr_t) 0 - u));   // incl fix_min
   if (u > boxmag) goto big;                                          // < INTPTR_MIN -> bignum
   val = (intptr_t) ((uintptr_t) 0 - u); }                            // incl INTPTR_MIN
  struct ai_vec *bx = ini_scalar((struct ai_vec*) *hp, ai_Z);
  *hp += box_req; box_put(bx->shape, val); return word(bx); }
big:;
 struct ai_big *b = ini_big((struct ai_big*) *hp, neg ? -n : n);
 for (int i = 0; i < n; i++) b->limb[i] = limb[i];
 *hp += b2w(sizeof(struct ai_big) + (size_t) n * sizeof(uint32_t));
 return word(b); }

// --- arithmetic (sign-magnitude over the loaded operands) -------------------

// r = a +/- b (subtract flips b's sign), result magnitude + sign.
static void big_addsub(uint32_t *r, int *rn, bool *rneg,
  uint32_t const *a, int na, bool nega, uint32_t const *b, int nb, bool negb, bool subtract) {
 bool sb = subtract ? !negb : negb;             // effective sign of the b operand
 if (nega == sb) { *rn = mag_add(r, a, na, b, nb); *rneg = nega; }
 else { int c = mag_cmp(a, na, b, nb);
  if (c == 0) { *rn = 0; *rneg = false; }
  else if (c > 0) { *rn = mag_sub(r, a, na, b, nb); *rneg = nega; }
  else { *rn = mag_sub(r, b, nb, a, na); *rneg = sb; } } }

static int big_mul_mag(uint32_t *r, uint32_t const *a, int na, uint32_t const *b, int nb) {
 mag_mul(r, a, na, b, nb);
 int n = na + nb; while (n > 0 && r[n-1] == 0) n--;
 return n; }

// Packed multi-precision lane for + - * / %, reached from the arith slow paths
// when either operand is a bignum or a fixnum/box op overflowed a machine word.
// Operands at g->sp[0..1] are integers (fixnum/box/bignum); a zero divisor is
// screened off by the caller. Computes a (vop) b, leaves the canonical result
// at g->sp[1], pops one operand, and advances g->ip -- so the caller is just
// Pack(g); g = ai_big_binop(g, vop); Unpack(g); Continue();  (cf. lvm_gc).
struct ai *ai_big_binop(struct ai *g, int vop) {
 word a = g->sp[0], b = g->sp[1];
 int na = bigp(a) ? big_nlimbs(a) : 2, nb = bigp(b) ? big_nlimbs(b) : 2;
 int bound = na + nb + 2;                        // result magnitude upper bound
 int work = 4 * (na + nb) + 16;                  // divmod scratch upper bound
 uintptr_t res_area = Width(struct ai_big) + b2w((size_t) bound * 4),
           ws_words = b2w((size_t) (bound + work) * 4);
 if (!ai_ok(g = ai_have(g, res_area + ws_words))) return g;
 a = g->sp[0], b = g->sp[1];                     // re-fetch (ai_have may have GC'd)
 uint32_t sa[2], sb[2]; uint32_t const *la, *lb; bool nega, negb;
 int nla = load_int_mag(a, sa, &la, &nega), nlb = load_int_mag(b, sb, &lb, &negb);
 uint32_t *rmag = (uint32_t*) (g->hp + res_area), *scr = rmag + bound;
 int rn = 0; bool rneg = false;
 switch (vop) {
  case vop_add: big_addsub(rmag, &rn, &rneg, la, nla, nega, lb, nlb, negb, false); break;
  case vop_sub: big_addsub(rmag, &rn, &rneg, la, nla, nega, lb, nlb, negb, true); break;
  case vop_mul: rn = big_mul_mag(rmag, la, nla, lb, nlb); rneg = nega != negb; break;
  default: {                                     // vop_quot / vop_rem (truncated)
   int c = mag_cmp(la, nla, lb, nlb);
   if (c < 0) {                                  // |a| < |b|: q = 0, r = a
    if (vop == vop_rem) rn = mag_copy(rmag, la, nla), rneg = nega; }
   else {
    uint32_t *q = scr, *rem = q + (nla - nlb + 1), *un = rem + nlb, *vn = un + (nla + 1);
    mag_divmod(q, rem, la, nla, lb, nlb, un, vn);
    if (vop != vop_rem) {                          // vop_quot / vop_fquot: truncated quotient
     int qn = nla - nlb + 1; while (qn > 0 && q[qn-1] == 0) qn--;
     rn = mag_copy(rmag, q, qn), rneg = nega != negb; }
    else {
     int rr = nlb; while (rr > 0 && rem[rr-1] == 0) rr--;
     rn = mag_copy(rmag, rem, rr), rneg = nega; } } } }
 g->sp[1] = ai_big_canon(&g->hp, rmag, rn, rneg);
 g->sp++;
 g->ip = (union u*) g->ip + 1;
 return g; }

// `/` over the bignum lane: like ai_big_binop's truncated quotient, but the result
// stays an exact integer ONLY when b divides a; a nonzero remainder promotes to a
// float box of a/b (the bignum analogue of the scalar `/` int promotion). Operands
// at g->sp[0..1] are integers; a zero divisor is screened off by the caller.
struct ai *ai_big_quot_true(struct ai *g) {
 word a = g->sp[0], b = g->sp[1];
 int na = bigp(a) ? big_nlimbs(a) : 2, nb = bigp(b) ? big_nlimbs(b) : 2;
 int bound = na + nb + 2, work = 4 * (na + nb) + 16;
 uintptr_t res_area = Width(struct ai_big) + b2w((size_t) bound * 4),
           ws_words = b2w((size_t) (bound + work) * 4);
 if (!ai_ok(g = ai_have(g, res_area + ws_words + box_req))) return g;
 a = g->sp[0], b = g->sp[1];                     // re-fetch (ai_have may have GC'd)
 uint32_t sa[2], sb[2]; uint32_t const *la, *lb; bool nega, negb;
 int nla = load_int_mag(a, sa, &la, &nega), nlb = load_int_mag(b, sb, &lb, &negb);
 uint32_t *rmag = (uint32_t*) (g->hp + res_area), *scr = rmag + bound;
 int rn = 0; bool rneg = false, exact;
 int c = mag_cmp(la, nla, lb, nlb);
 if (c < 0) exact = (nla == 0);                  // |a| < |b|: q = 0, exact iff a == 0
 else {
  uint32_t *q = scr, *rem = q + (nla - nlb + 1), *un = rem + nlb, *vn = un + (nla + 1);
  mag_divmod(q, rem, la, nla, lb, nlb, un, vn);
  int rr = nlb; while (rr > 0 && rem[rr-1] == 0) rr--;
  exact = (rr == 0);
  int qn = nla - nlb + 1; while (qn > 0 && q[qn-1] == 0) qn--;
  rn = mag_copy(rmag, q, qn), rneg = nega != negb; }
 if (exact) g->sp[1] = ai_big_canon(&g->hp, rmag, rn, rneg);
 else { struct ai_vec *v = ini_scalar((struct ai_vec*) g->hp, ai_R);  // a,b still valid: no GC since the re-fetch, and toflo is alloc-free
  g->hp += box_req; flo_put(v->shape, toflo(a) / toflo(b)); g->sp[1] = word(v); }
 g->sp++;
 g->ip = (union u*) g->ip + 1;
 return g; }

// --- resumable (yieldable) multiply -----------------------------------------
// Schoolbook multiply is O(na*nb) and, run as one C call, never yields -- so a
// peer task (the repl's Ctrl-C poller) can't interrupt a huge product. Instead
// we drive it as a self-looping VM instruction: the partial product lives in a
// buf (flat bytes, GC-relocates safely), and each dispatch folds ~bmul_chunk
// limb-mults of rows, then re-dispatches with a YieldCheck. The work state rides
// the l stack [i, r, ret_ip, a, b] -- a yield saves/restores it, so the
// product resumes exactly where it paused. Ip parks on bmul_loop while looping;
// on completion it jumps back to ret_ip (the instruction after `*`).
// Operands a,b are kept as heap bignums so the loop reads stable limb pointers
// directly: a tail-jumping ap must NOT take the address of a stack local
// (it blocks the sibcall), which rules out load_int_mag's scratch array. Setup
// (which may use scratch) is hoisted into a plain function, ai_bmul_setup.
#define bmul_chunk (1 << 14)
static union u const bmul_loop[1] = { { .ap = lvm_bmul } };

// Materialize integer x (fixnum/box/bignum) as a heap ai_big, bumping *hp for the
// fixnum/box case; a bignum is returned in place. Plain function: scratch is fine.
static union u *as_big(ai_word **hp, word x) {
 if (bigp(x)) return cell(x);
 intptr_t v = toint(x);
 bool neg = v < 0;
 uintptr_t u = neg ? (uintptr_t) 0 - (uintptr_t) v : (uintptr_t) v;
 uint32_t lo = (uint32_t) u, hi = (uint32_t) ((u >> 16) >> 16);   // hi=0 on 32-bit ports
 int n = hi ? 2 : lo ? 1 : 0;
 struct ai_big *b = ini_big((struct ai_big*) *hp, neg ? -n : n);
 if (n >= 1) b->limb[0] = lo;
 if (n >= 2) b->limb[1] = hi;
 *hp += b2w(sizeof(struct ai_big) + (size_t) n * 4);
 return cell((word) b); }

// g->sp[0]=a g->sp[1]=b (integers whose product overflows a word). Promote both
// to bignums, allocate the zeroed result buf, and lay out the work frame; on
// return g->ip is bmul_loop. One ai_have so no half-built state is ever seen.
static struct ai *ai_bmul_setup(struct ai *g) {
 word a = g->sp[0], b = g->sp[1];
 int na = bigp(a) ? big_nlimbs(a) : 2, nb = bigp(b) ? big_nlimbs(b) : 2;
 uintptr_t rbytes = (uintptr_t) (na + nb) * 4,
           sreq = str_type_width + b2w(rbytes),
           breq = Width(struct ai_buf) + Width(struct ai_tag),
           bigmax = Width(struct ai_big) + b2w(2 * 4);
 if (!ai_ok(g = ai_have(g, 2 * bigmax + sreq + breq + 3))) return g;
 a = g->sp[0], b = g->sp[1];                       // re-fetch (ai_have may have GC'd)
 union u *abig = as_big(&g->hp, a), *bbig = as_big(&g->hp, b), *ret = g->ip + 1;
 struct ai_str *s = ini_str((struct ai_str*) g->hp, rbytes);
 g->hp += sreq; memset(txt(s), 0, rbytes);
 union u *k = (union u*) g->hp; g->hp += breq;
 ((struct ai_buf*) k)->ap = lvm_buf, ((struct ai_buf*) k)->str = s, tagtext(k, Width(struct ai_buf));
 g->sp -= 3;                                       // [i, r, ret_ip, abig, bbig]
 g->sp[0] = putcharm(0), g->sp[1] = word(k), g->sp[2] = word(ret);
 g->sp[3] = word(abig), g->sp[4] = word(bbig);
 g->ip = (union u*) bmul_loop;
 return g; }

lvm(lvm_bmul_start) {
 Pack(g); g = ai_bmul_setup(g);
 if (!ai_ok(g)) return ghelp(g);
 return Unpack(g), Continue(); }

lvm(lvm_bmul) {
 int i = (int) getcharm(Sp[0]);
 struct ai_big *A = (struct ai_big*) Sp[3], *B = (struct ai_big*) Sp[4];
 intptr_t sla = A->slen, slb = B->slen;
 int na = sla < 0 ? -sla : sla, nb = slb < 0 ? -slb : slb;
 if (!na || !nb) {                                // a zero operand: product is 0
  word ret = Sp[2]; return Sp += 4, Sp[0] = nil, Ip = cell(ret), Continue(); }
 uint32_t *la = A->limb, *lb = B->limb, *rl = (uint32_t*) txt(buf_str(Sp[1]));
 int end = min(i + max(1, bmul_chunk / nb), na);
 for (; i < end; i++) {                           // schoolbook outer loop, one chunk of rows
  uint64_t carry = 0, ai = la[i];
  for (int j = 0; j < nb; j++) {
   uint64_t t = ai * lb[j] + rl[i+j] + carry;
   rl[i+j] = (uint32_t) t, carry = t >> 32; }
  rl[i+nb] = (uint32_t) carry; }
 Sp[0] = putcharm(i);                               // persist progress before any yield/GC
 if (i < na) { YieldCheck(); return Continue(); }
 bool neg = (sla < 0) != (slb < 0); word ret;     // done: canonicalize the product
 Have(Width(struct ai_big) + b2w((size_t) (na + nb) * 4));
 ret = Sp[2]; uint32_t *rmag = (uint32_t*) txt(buf_str(Sp[1]));   // re-fetch (Have may have GC'd)
 Pack(g);                                          // canon needs the synced g->hp (not &Hp: stack-local escapes block the sibcall)
 word res = ai_big_canon(&g->hp, rmag, na + nb, neg);
 Unpack(g);
 return Sp += 4, Sp[0] = res, Ip = cell(ret), Continue(); }

// --- reader / printer -------------------------------------------------------

// g->sp[0] is a [+-]?[0-9]+ token string; replace it with the canonical value
// (fixnum / box / bignum). Accumulates 9 decimal digits per mul-add pass.
struct ai *ai_big_read_dec(struct ai *g) {
 struct ai_str *tok = str(g->sp[0]);
 uintptr_t n = tok->len;
 char const *s = tok->bytes;
 bool neg = n && s[0] == '-';
 uintptr_t i = (n && (s[0] == '-' || s[0] == '+')) ? 1 : 0, ndig = n - i;
 int cap = (int) (ndig / 9) + 3;                 // upper-bound magnitude limbs
 uintptr_t res_area = Width(struct ai_big) + b2w((size_t) cap * 4);
 if (!ai_ok(g = ai_have(g, res_area + b2w((size_t) cap * 4)))) return g;
 tok = str(g->sp[0]), s = tok->bytes;            // re-fetch post-GC
 uint32_t *mag = (uint32_t*) (g->hp + res_area);
 int m = 0;
 while (i < n) {
  uint32_t chunk = 0, pw = 1; int k = 0;
  for (; i < n && k < 9; i++, k++) chunk = chunk * 10 + (uint32_t) (s[i] - '0'), pw *= 10;
  m = mag_mul_add_small(mag, m, pw, chunk); }
 g->sp[0] = ai_big_canon(&g->hp, mag, m, neg);
 return g; }

// g->sp[0] is a bignum; replace it with its base-10 string (with sign). Builds
// the digits into a fresh ai_str by repeated divide-by-10 of a heap-local copy
// of the magnitude; no allocation (hence no GC) once the single Have lands, so
// the work buffer and the string stay put through the loop.
struct ai *ai_big_dec(struct ai *g) {
 struct ai_big *a = (struct ai_big*) g->sp[0];
 intptr_t sl = a->slen;
 bool neg = sl < 0;
 int n = (int) (neg ? -sl : sl),
     cap = n * 10 + 2 + (neg ? 1 : 0);           // upper-bound bytes (1 limb ~ 9.633 digits)
 uintptr_t str_words = str_type_width + b2w((size_t) cap),
           scratch_words = b2w((size_t) n * 4);
 if (!ai_ok(g = ai_have(g, str_words + scratch_words))) return g;
 a = (struct ai_big*) g->sp[0];                   // re-fetch post-GC
 struct ai_str *st = (struct ai_str*) g->hp;
 uint32_t *work = (uint32_t*) (g->hp + str_words);
 for (int i = 0; i < n; i++) work[i] = a->limb[i];
 char *out = txt(st);                            // bytes area (offset only; st not yet inited)
 int m = n, pos = cap;
 while (m > 0) {
  uint32_t r = mag_divmod_small(work, m, 10);
  while (m > 0 && work[m-1] == 0) m--;
  out[--pos] = (char) ('0' + r); }
 if (pos == cap) out[--pos] = '0';               // (a bignum is never zero; defensive)
 if (neg) out[--pos] = '-';
 int dl = cap - pos;
 for (int i = 0; i < dl; i++) out[i] = out[pos + i];   // shift digits to the front
 ini_str(st, dl);
 g->hp += str_type_width + b2w((size_t) dl);
 g->sp[0] = word(st);
 return g; }

// --- (arr type shape-list vals): THE typed array constructor ----------------
// `type` is a fixnum element-type code (z/r/c/o, named in the prel); `shape`
// is a list of non-negative fixnum dimensions (empty -> a rank-0 scalar box);
// `vals` fills row-major from a list (a non-numeric or missing entry stays 0;
// extras are ignored), and 0 (or any non-list) means zero-filled. A `c` array
// packs two floats (re,im) per element; zero-fill is 0+0i. Bad type / negative
// dim / over-rank -> nil.
lvm(lvm_arr) {
 word t = Sp[0], shp = Sp[1];                  // vals = Sp[2]
 if (!charmp(t)) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 intptr_t ty = getcharm(t);
 if (ty < 0 || ty > ai_O) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 uintptr_t rank = 0, nelem = 1;
 for (word l = shp; twop(l); l = B(l)) {
  word d = A(l);
  if (!charmp(d) || getcharm(d) < 0) return Sp[2] = nil, Sp += 2, Ip++, Continue();
  rank++, nelem *= (uintptr_t) getcharm(d); }
 if (rank > maxrank || (ty == ai_O && rank == 0)) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 uintptr_t bytes = sizeof(struct ai_vec) + rank * sizeof(word) + nelem * ai_T[ty];
 Have(b2w(bytes));
 struct ai_vec *v = (struct ai_vec*) Hp;
 Hp += b2w(bytes);
 ini_vec(v, ty, rank);
 uintptr_t i = 0;                              // re-walk the (possibly moved) lists
 for (word l = Sp[1]; twop(l); l = B(l)) v->shape[i++] = (uintptr_t) getcharm(A(l));
 if (ty == ai_O) for (i = 0; i < nelem; i++) vec_put_obj(v, i, nil);
 else memset(vec_data(v), 0, nelem * ai_T[ty]);
 i = 0;                                        // no alloc below, so v/Sp[2] stay put
 for (word l = Sp[2]; twop(l) && i < nelem; l = B(l), i++) {
  word e = A(l);
  if (ty == ai_O) { vec_put_obj(v, i, e); continue; }   // store any value verbatim
  if (ty == ai_C) {                                        // pack (re,im): a real -> (r,0)
   ai_flo_t *fp = vec_data(v);
   if (Cp(e)) fp[2*i] = cplx_re(e), fp[2*i+1] = cplx_im(e);
   else if (isnum(e)) fp[2*i] = toflo(e), fp[2*i+1] = 0;
   continue; }
  if (!isnum(e)) continue;
  if (ty >= ai_R) vec_put_flo(v, i, toflo(e));
  else vec_put_int(v, i, charmp(e) ? (intptr_t) getcharm(e)
                       : flop(e) ? (intptr_t) flo_get(e) : box_get(e)); }
 return Sp[2] = word(v), Sp += 2, Ip++, Continue(); }

// (iota n) -- a z-array of the first n charms, 0..n-1, filled in C (no cons
// spine): the array twin of `jot`. n<0 or non-fixnum -> nil. This is the baked
// range constructor, so (asum (iota n)) reduces a range end to end in C.
lvm(lvm_iota) {
 word nx = Sp[0];
 if (!charmp(nx) || getcharm(nx) < 0) return Sp[0] = nil, Ip++, Continue();
 uintptr_t n = (uintptr_t) getcharm(nx);
 uintptr_t bytes = sizeof(struct ai_vec) + 1 * sizeof(word) + n * ai_T[ai_Z];
 Have(b2w(bytes));
 struct ai_vec *v = (struct ai_vec*) Hp;
 Hp += b2w(bytes);
 ini_vec(v, ai_Z, 1);
 v->shape[0] = n;
 for (uintptr_t i = 0; i < n; i++) vec_put_int(v, i, (intptr_t) i);
 return Sp[0] = word(v), Ip++, Continue(); }

// --- accessors -------------------------------------------------------------
// rank / element-type code as fixnums; nil for a non-vec. Both 0 for a scalar box.
op11(lvm_arank, packp(Sp[0]) ? putcharm(vec(Sp[0])->rank) : nil)
op11(lvm_atype, packp(Sp[0]) ? putcharm(vec(Sp[0])->type) : nil)

// total element count (1 for a scalar box), nil for a non-vec.
lvm(lvm_alen) {
 word x = Sp[0];
 if (!packp(x)) return Sp[0] = nil, Ip++, Continue();
 return Sp[0] = putcharm(vec_nelem(vec(x))), Ip++, Continue(); }

// dimensions as a list (allocates rank cons cells), nil for a non-vec.
lvm(lvm_ashape) {
 word x = Sp[0];
 if (!packp(x)) return Sp[0] = nil, Ip++, Continue();
 uintptr_t r = vec(x)->rank;
 Have(r * Width(struct ai_pair));
 struct ai_vec *v = vec(Sp[0]);                 // re-read post-Have
 struct ai_pair *p = (struct ai_pair*) Hp;
 Hp += r * Width(struct ai_pair);
 word list = nil;
 for (uintptr_t i = r; i--; )
  ini_two(p, putcharm(v->shape[i]), list), list = word(p), p++;
 return Sp[0] = list, Ip++, Continue(); }


// ai_O reductions (sum/prod/max/min) fold through the promoting scalar op, so an
// object array reduces *exactly*. Defined after the object lane (below); the
// numeric reductions divert here when their operand is a ai_O array.
static struct ai *ored(struct ai *g, int kind);   // kind: 0 sum, 1 prod, 2 max, 3 min

// --- reductions: rank>=1 array -> rank-0 scalar; identity on a scalar -------
// The identity-on-scalar property makes `(aall (< a b))` rank-agnostic: the
// same expression works whether a/b are scalars or arrays.
lvm(lvm_asum) {
 word x = Sp[0];
 if (!packp(x)) return Ip++, Continue();        // scalar: (asum 5) = 5
 if (vec(x)->type == ai_O) {
  Pack(g); g = ored(g, 0);
  if (!ai_ok(g)) return ghelp(g);
  return Unpack(g), Continue(); }
 if (vec(x)->type == ai_C) {                   // complex sum -> a complex box
  struct ai_vec *v = vec(x); uintptr_t n = vec_nelem(v);  // K=4 accumulators (see aprod)
  ai_flo_t *fp = vec_data(v);                   // read all parts before Have (no alloc here)
  ai_flo_t a0=0,b0=0, a1=0,b1=0, a2=0,b2=0, a3=0,b3=0; uintptr_t j = 0;
  for (; j + 4 <= n; j += 4) {
   a0 += fp[2*j];   b0 += fp[2*j+1]; a1 += fp[2*j+2]; b1 += fp[2*j+3];
   a2 += fp[2*j+4]; b2 += fp[2*j+5]; a3 += fp[2*j+6]; b3 += fp[2*j+7]; }
  for (; j < n; j++) a0 += fp[2*j], b0 += fp[2*j+1];
  ai_flo_t sr = (a0+a1)+(a2+a3), si = (b0+b1)+(b2+b3);
  Have(cplx_req);
  struct ai_vec *r = ini_scalar((struct ai_vec*) Hp, ai_C); Hp += cplx_req;
  cplx_put(r, sr, si);
  return Sp[0] = word(r), Ip++, Continue(); }
 struct ai_vec *v = vec(x);
 uintptr_t n = vec_nelem(v);
 bool fdom = v->type >= ai_R; word _res;
 Have(box_req);
 v = vec(Sp[0]);
 if (fdom) {                                    // K=4 accumulators (see aprod complex)
  ai_flo_t a0=0,a1=0,a2=0,a3=0; uintptr_t i = 0;
  for (; i + 4 <= n; i += 4) a0+=vec_get_flo(v,i), a1+=vec_get_flo(v,i+1), a2+=vec_get_flo(v,i+2), a3+=vec_get_flo(v,i+3);
  for (; i < n; i++) a0 += vec_get_flo(v, i);
  emit_flo((a0+a1)+(a2+a3)); }
 else {                                         // K=4 (modular, Z/2^64 is a commutative ring -> assoc+exact)
  uintptr_t a0=0,a1=0,a2=0,a3=0, i = 0;
  for (; i + 4 <= n; i += 4) a0+=(uintptr_t)vec_get_int(v,i), a1+=(uintptr_t)vec_get_int(v,i+1), a2+=(uintptr_t)vec_get_int(v,i+2), a3+=(uintptr_t)vec_get_int(v,i+3);
  for (; i < n; i++) a0 += (uintptr_t) vec_get_int(v, i);
  emit_int((intptr_t) ((a0+a1)+(a2+a3))); }
 return Sp[0] = _res, Ip++, Continue(); }

lvm(lvm_aprod) {
 word x = Sp[0];
 if (!packp(x)) return Ip++, Continue();
 if (vec(x)->type == ai_O) {
  Pack(g); g = ored(g, 1);
  if (!ai_ok(g)) return ghelp(g);
  return Unpack(g), Continue(); }
 if (vec(x)->type == ai_C) {                   // complex product -> a complex box
  // K=4 INDEPENDENT accumulators break the multiply latency chain (acc_n depends
  // on acc_n-1); reassociation is sound -- * is a commutative monoid, so the
  // product is grouping-invariant by definition (fp * differs only in last-bit
  // rounding per grouping). ~3x faster than the sequential chain; the compiler
  // schedules the four chains. Tail folds the <4 remainder into chain 0.
  struct ai_vec *v = vec(x); uintptr_t n = vec_nelem(v);
  ai_flo_t *fp = vec_data(v);
  ai_flo_t r0=1,i0=0, r1=1,i1=0, r2=1,i2=0, r3=1,i3=0, t; uintptr_t j = 0;
  for (; j + 4 <= n; j += 4) {
   t = r0*fp[2*j]  -i0*fp[2*j+1]; i0 = r0*fp[2*j+1]+i0*fp[2*j];   r0 = t;
   t = r1*fp[2*j+2]-i1*fp[2*j+3]; i1 = r1*fp[2*j+3]+i1*fp[2*j+2]; r1 = t;
   t = r2*fp[2*j+4]-i2*fp[2*j+5]; i2 = r2*fp[2*j+5]+i2*fp[2*j+4]; r2 = t;
   t = r3*fp[2*j+6]-i3*fp[2*j+7]; i3 = r3*fp[2*j+7]+i3*fp[2*j+6]; r3 = t; }
  for (; j < n; j++) { t = r0*fp[2*j]-i0*fp[2*j+1]; i0 = r0*fp[2*j+1]+i0*fp[2*j]; r0 = t; }
  ai_flo_t ra = r0*r1-i0*i1, ia = r0*i1+i0*r1, rb = r2*r3-i2*i3, ib = r2*i3+i2*r3;
  ai_flo_t pr = ra*rb-ia*ib, pi = ra*ib+ia*rb;
  Have(cplx_req);
  struct ai_vec *r = ini_scalar((struct ai_vec*) Hp, ai_C); Hp += cplx_req;
  cplx_put(r, pr, pi);
  return Sp[0] = word(r), Ip++, Continue(); }
 struct ai_vec *v = vec(x);
 uintptr_t n = vec_nelem(v);
 bool fdom = v->type >= ai_R; word _res;
 Have(box_req); v = vec(Sp[0]);
 if (fdom) {                                    // K=4 accumulators (see complex above)
  ai_flo_t a0=1,a1=1,a2=1,a3=1; uintptr_t i = 0;
  for (; i + 4 <= n; i += 4) a0*=vec_get_flo(v,i), a1*=vec_get_flo(v,i+1), a2*=vec_get_flo(v,i+2), a3*=vec_get_flo(v,i+3);
  for (; i < n; i++) a0 *= vec_get_flo(v, i);
  emit_flo((a0*a1)*(a2*a3)); }
 else {                                         // K=4 (modular product; imul is latency-bound, ~3x)
  uintptr_t a0=1,a1=1,a2=1,a3=1, i = 0;
  for (; i + 4 <= n; i += 4) a0*=(uintptr_t)vec_get_int(v,i), a1*=(uintptr_t)vec_get_int(v,i+1), a2*=(uintptr_t)vec_get_int(v,i+2), a3*=(uintptr_t)vec_get_int(v,i+3);
  for (; i < n; i++) a0 *= (uintptr_t) vec_get_int(v, i);
  emit_int((intptr_t) ((a0*a1)*(a2*a3))); }
 return Sp[0] = _res, Ip++, Continue(); }

// max / min over a non-empty array (kind 2 = max, 3 = min, matching ored);
// empty -> nil; scalar -> identity. The kind selects the comparison sense.
static lvm(lvm_aextreme, int kind) {
 word x = Sp[0];
 if (!packp(x)) return Ip++, Continue();
 if (vec(x)->type == ai_O) {
  Pack(g); g = ored(g, kind);
  if (!ai_ok(g)) return ghelp(g);
  return Unpack(g), Continue(); }
 if (vec(x)->type == ai_C) return Sp[0] = nil, Ip++, Continue();   // complex: unordered
 struct ai_vec *v = vec(x);
 uintptr_t n = vec_nelem(v);
 if (!n) return Sp[0] = nil, Ip++, Continue();
 bool fdom = v->type >= ai_R, ismax = kind == 2; word _res;
 Have(box_req); v = vec(Sp[0]);
 // K=4 INDEPENDENT running extremes break the m_n<-m_n-1 latency chain. max/min
 // are commutative+associative+idempotent, so this is EXACT (it just selects an
 // existing element -- no rounding, unlike sum/prod). Each chain seeds from v[0].
 if (fdom) { ai_flo_t m0 = vec_get_flo(v, 0), m1=m0, m2=m0, m3=m0, e; uintptr_t i = 1;
  for (; i + 4 <= n; i += 4) {
   e = vec_get_flo(v,i);   if (ismax?e>m0:e<m0) m0=e;
   e = vec_get_flo(v,i+1); if (ismax?e>m1:e<m1) m1=e;
   e = vec_get_flo(v,i+2); if (ismax?e>m2:e<m2) m2=e;
   e = vec_get_flo(v,i+3); if (ismax?e>m3:e<m3) m3=e; }
  for (; i < n; i++) { e = vec_get_flo(v,i); if (ismax?e>m0:e<m0) m0=e; }
  if (ismax?m1>m0:m1<m0) m0=m1;
  if (ismax?m2>m0:m2<m0) m0=m2;
  if (ismax?m3>m0:m3<m0) m0=m3;
  emit_flo(m0); }
 else { intptr_t m0 = vec_get_int(v, 0), m1=m0, m2=m0, m3=m0, e; uintptr_t i = 1;
  for (; i + 4 <= n; i += 4) {
   e = vec_get_int(v,i);   if (ismax?e>m0:e<m0) m0=e;
   e = vec_get_int(v,i+1); if (ismax?e>m1:e<m1) m1=e;
   e = vec_get_int(v,i+2); if (ismax?e>m2:e<m2) m2=e;
   e = vec_get_int(v,i+3); if (ismax?e>m3:e<m3) m3=e; }
  for (; i < n; i++) { e = vec_get_int(v,i); if (ismax?e>m0:e<m0) m0=e; }
  if (ismax?m1>m0:m1<m0) m0=m1;
  if (ismax?m2>m0:m2<m0) m0=m2;
  if (ismax?m3>m0:m3<m0) m0=m3;
  emit_int(m0); }
 return Sp[0] = _res, Ip++, Continue(); }
lvm(lvm_amax) { return Ap(lvm_aextreme, g, 2); }
lvm(lvm_amin) { return Ap(lvm_aextreme, g, 3); }

// aall: the bool conjunction reduction. Scalar -> identity (so (aall 1) = 1, the
// linchpin of the rank-agnostic compare idiom). Over an array: "no zero element"
// (the falsy rule lifted to a conjunction); empty array -> true (vacuous). The
// DISJUNCTION (was `aany`) is just `len`: an array is truthy iff some element is
// nonzero, i.e. (nilp x) == (= 0 (len x)) -- so `(len x)` replaces `(aany x)`.
lvm(lvm_aall) {
 word x = Sp[0];
 if (!packp(x)) return Ip++, Continue();
 struct ai_vec *v = vec(x);
 uintptr_t n = vec_nelem(v);
 if (v->type == ai_O) {                         // object: a falsy element fails the conjunction
  for (uintptr_t i = 0; i < n; i++)
   if (ai_nilp(g, vec_get_obj(v, i))) return Sp[0] = nil, Ip++, Continue();
  return Sp[0] = putcharm(1), Ip++, Continue(); }
 if (v->type == ai_C) {                         // complex: a 0+0i element fails the conjunction
  ai_flo_t *fp = vec_data(v);
  for (uintptr_t i = 0; i < n; i++)
   if (fp[2*i] == 0 && fp[2*i+1] == 0) return Sp[0] = nil, Ip++, Continue();
  return Sp[0] = putcharm(1), Ip++, Continue(); }
 // a short-circuit sound, NOT an accumulator chain -- already load-bound (the
 // compiler vectorizes it), so multi-accumulating buys nothing; left as is.
 bool fdom = v->type >= ai_R;
 for (uintptr_t i = 0; i < n; i++)
  if (fdom ? vec_get_flo(v, i) == 0 : vec_get_int(v, i) == 0)
   return Sp[0] = nil, Ip++, Continue();
 return Sp[0] = putcharm(1), Ip++, Continue(); }

// (outer a b) — OUTER PRODUCT with *: result[I,J] = a[I] * b[J], rank ra+rb,
// shape a.shape ++ b.shape. z⊗z -> z (wrapping), any r -> r. complex/object or
// rank > maxrank -> nil. a's cell is hoisted out of the inner (b) loop.
lvm(lvm_outer) {
 word a = Sp[0], b = Sp[1];
 if (!(arrp(a) && arrp(b))) return *++Sp = nil, Ip++, Continue();
 struct ai_vec *va = vec(a), *vb = vec(b);
 if (va->type > ai_R || vb->type > ai_R) return *++Sp = nil, Ip++, Continue();
 uintptr_t M = vec_nelem(va), N = vec_nelem(vb), n = M * N, rank = va->rank + vb->rank;
 if (rank > maxrank) return *++Sp = nil, Ip++, Continue();
 bool fdom = va->type == ai_R || vb->type == ai_R;
 enum ai_vec_type rt = fdom ? ai_R : ai_Z;
 uintptr_t bytes = sizeof(struct ai_vec) + rank * sizeof(word) + ai_T[rt] * n;
 Have(b2w(bytes));
 va = vec(Sp[0]), vb = vec(Sp[1]);          // re-read post-Have
 struct ai_vec *r = (struct ai_vec*) Hp; Hp += b2w(bytes);
 ini_vec(r, rt, rank);
 for (uintptr_t i = 0; i < va->rank; i++) r->shape[i] = va->shape[i];
 for (uintptr_t i = 0; i < vb->rank; i++) r->shape[va->rank + i] = vb->shape[i];
 if (fdom) { ai_flo_t *rp = vec_data(r);
  for (uintptr_t i = 0; i < M; i++) { ai_flo_t av = vec_get_flo(va, i);
   for (uintptr_t j = 0; j < N; j++) rp[i*N+j] = av * vec_get_flo(vb, j); } }
 else { intptr_t *rp = vec_data(r);
  for (uintptr_t i = 0; i < M; i++) { intptr_t av = vec_get_int(va, i);
   for (uintptr_t j = 0; j < N; j++) rp[i*N+j] = (intptr_t)((uintptr_t)av * (uintptr_t)vec_get_int(vb, j)); } }
 return *++Sp = word(r), Ip++, Continue(); }   // arity 2

// (inner a b) — INNER PRODUCT (+.×): contract a's LAST axis with b's FIRST axis.
// a is [..M.., K], b is [K, ..N..]; result [..M.., ..N..] with
// C[I,J] = sum_l a[I,l]*b[l,J]. 1D·1D = dot product -> a scalar number; 2D·2D =
// matrix multiply. z -> z (modular sum-of-products), any r -> r. axis mismatch /
// complex / object / rank > maxrank -> nil. ikj order streams b and c rows so the
// inner j loop vectorizes (the l contraction is the dependency, hoisted one out).
lvm(lvm_inner) {
 word a = Sp[0], b = Sp[1];
 if (!(arrp(a) && arrp(b))) return *++Sp = nil, Ip++, Continue();
 struct ai_vec *va = vec(a), *vb = vec(b);
 if (va->type > ai_R || vb->type > ai_R || va->rank < 1 || vb->rank < 1)
  return *++Sp = nil, Ip++, Continue();
 uintptr_t K = va->shape[va->rank - 1];
 if (K != vb->shape[0]) return *++Sp = nil, Ip++, Continue();   // contracted axes must agree
 uintptr_t M = 1, N = 1;
 for (uintptr_t i = 0; i + 1 < va->rank; i++) M *= va->shape[i];
 for (uintptr_t i = 1; i < vb->rank; i++) N *= vb->shape[i];
 uintptr_t rank = (va->rank - 1) + (vb->rank - 1), n = M * N;
 if (rank > maxrank) return *++Sp = nil, Ip++, Continue();
 bool fdom = va->type == ai_R || vb->type == ai_R, ar = va->type == ai_R, br = vb->type == ai_R;
 if (rank == 0) {                               // dot product -> scalar number
  word _res;
  if (fdom) { ai_flo_t *Ad = vec_data(va), *Bd = vec_data(vb);
   intptr_t *Ai = vec_data(va), *Bi = vec_data(vb); ai_flo_t acc = 0;
   for (uintptr_t l = 0; l < K; l++) acc += (ar ? Ad[l] : (ai_flo_t) Ai[l]) * (br ? Bd[l] : (ai_flo_t) Bi[l]);
   Have(box_req); emit_flo(acc); }
  else { intptr_t *A = vec_data(va), *B = vec_data(vb); uintptr_t acc = 0;
   for (uintptr_t l = 0; l < K; l++) acc += (uintptr_t) A[l] * (uintptr_t) B[l];
   Have(box_req); emit_int((intptr_t) acc); }
  return *++Sp = _res, Ip++, Continue(); }
 enum ai_vec_type rt = fdom ? ai_R : ai_Z;
 uintptr_t bytes = sizeof(struct ai_vec) + rank * sizeof(word) + ai_T[rt] * n;
 Have(b2w(bytes));
 va = vec(Sp[0]), vb = vec(Sp[1]);
 struct ai_vec *r = (struct ai_vec*) Hp; Hp += b2w(bytes);
 ini_vec(r, rt, rank);
 { uintptr_t s = 0;
   for (uintptr_t i = 0; i + 1 < va->rank; i++) r->shape[s++] = va->shape[i];
   for (uintptr_t i = 1; i < vb->rank; i++) r->shape[s++] = vb->shape[i]; }
 if (fdom) { ai_flo_t *C = vec_data(r);
  ai_flo_t *Ad = vec_data(va), *Bd = vec_data(vb);
  intptr_t *Ai = vec_data(va), *Bi = vec_data(vb);
  for (uintptr_t p = 0; p < n; p++) C[p] = 0;
  for (uintptr_t i = 0; i < M; i++)
   for (uintptr_t l = 0; l < K; l++) { ai_flo_t av = ar ? Ad[i*K+l] : (ai_flo_t) Ai[i*K+l];
    for (uintptr_t j = 0; j < N; j++) C[i*N+j] += av * (br ? Bd[l*N+j] : (ai_flo_t) Bi[l*N+j]); } }
 else { intptr_t *C = vec_data(r), *A = vec_data(va), *B = vec_data(vb);
  for (uintptr_t p = 0; p < n; p++) C[p] = 0;
  for (uintptr_t i = 0; i < M; i++)
   for (uintptr_t l = 0; l < K; l++) { intptr_t av = A[i*K+l];
    for (uintptr_t j = 0; j < N; j++) C[i*N+j] = (intptr_t)((uintptr_t)C[i*N+j] + (uintptr_t)av * (uintptr_t)B[l*N+j]); } }
 return *++Sp = word(r), Ip++, Continue(); }   // arity 2

// --- elementwise monadic math over an array (sin/cos/sqrt/... ) --------------
// Reached from lvm_math1 when its operand arrp. Result is a float array
// (ai_R) with the operand's shape. The fill loop takes no &local, so the
// lvm wrapper keeps its trailing tail call.
static ai_noinline void vmap1_fill(struct ai_vec *r, struct ai_vec *a, ai_flo_t (*fn)(ai_flo_t)) {
 uintptr_t n = vec_nelem(r);
 for (uintptr_t i = 0; i < n; i++) vec_put_flo(r, i, fn(vec_get_flo(a, i))); }

lvm(lvm_vmap1, ai_flo_t (*fn)(ai_flo_t)) {
 struct ai_vec *a = vec(Sp[0]);
 uintptr_t rank = a->rank, n = vec_nelem(a);
 uintptr_t bytes = sizeof(struct ai_vec) + rank * sizeof(word) + n * ai_T[ai_R];
 Have(b2w(bytes));
 a = vec(Sp[0]);                               // re-read post-Have
 struct ai_vec *r = (struct ai_vec*) Hp;
 Hp += b2w(bytes);
 ini_vec(r, ai_R, rank);
 for (uintptr_t i = 0; i < rank; i++) r->shape[i] = a->shape[i];
 vmap1_fill(r, a, fn);
 return Sp[0] = word(r), Ip++, Continue(); }

// --- elementwise dyadic engine (arith / compare / =) with broadcasting ------
// Per-element ops. Integer division guards /0 and INT_MIN/-1 -> 0 (the array
// convention; a scalar `/` promotes such cases to an IEEE inf/NaN instead, but
// one element can't change the whole result's domain).
static ai_flo_t vop_flo(int op, ai_flo_t a, ai_flo_t b) {
 switch (op) {
  case vop_sub: return a - b; case vop_mul: return a * b;
  case vop_quot: return a / b; case vop_fquot: return ai_trunc(a / b);
  case vop_rem: return ai_fmod(a, b);
  default: return a + b; } }                   // vop_add
static intptr_t vop_int(int op, intptr_t a, intptr_t b) {
 switch (op) {
  case vop_sub: return (intptr_t)((uintptr_t) a - (uintptr_t) b);
  case vop_mul: return (intptr_t)((uintptr_t) a * (uintptr_t) b);
  case vop_quot: case vop_fquot: return (b == 0 || (a == INTPTR_MIN && b == -1)) ? 0 : a / b;
  case vop_rem:  return (b == 0 || (a == INTPTR_MIN && b == -1)) ? 0 : a % b;
  default: return (intptr_t)((uintptr_t) a + (uintptr_t) b); } } // vop_add
static intptr_t vcmp_flo(int op, ai_flo_t a, ai_flo_t b) {
 switch (op) {
  case vop_lt: return a < b; case vop_le: return a <= b;
  case vop_gt: return a > b; case vop_ge: return a >= b;
  default: return a == b; } }                   // vop_eq
static intptr_t vcmp_int(int op, intptr_t a, intptr_t b) {
 switch (op) {
  case vop_lt: return a < b; case vop_le: return a <= b;
  case vop_gt: return a > b; case vop_ge: return a >= b;
  default: return a == b; } }                   // vop_eq

// === ordered comparison: a total order over lisp values ======================
// `< <= > >=` extend across EVERY kind, not just numbers. The CROSS-kind order is
// the enum q type lattice (ai.h) -- fixnum/number LOW, lambda HIGH, the very
// order the generic-op matrix diagonals encode: number < string < symbol < pair <
// map < lambda. (Arrays are the exception: an array operand compares ELEMENTWISE -> a
// 0/1 mask via lvm_vbin, never the scalar order.) WITHIN a kind:
//   numbers  by value across the tower; a real r is the complex (r, 0), so complex
//            sorts lexicographically by (re, im). IEEE-faithful: NaN is unordered,
//            so every ordering of it is false.
//   strings  lexicographic over bytes (a prefix sorts first)
//   symbols  the product order: name lex (anonymous == the empty name), then
//            interned-first, then the mint serial -- TOTAL (see sym_cmp)
//   pairs    lexicographic over (car, then cdr), recursively
//   maps     by representation hash, in their OWN band (pair < map < lambda)
//   lambdas  by representation hash (ports/bufs too) -- a GC-stable order
// ANTISYMMETRY: only `<` and `<=` are implemented; `>` and `>=` REVERSE the
// operands and reuse them (a > b == b < a), which is also the right NaN behaviour
// (swap, never negate). A total PREORDER: agrees with `=` (eqv) except where eqv
// is finer -- hash-colliding lambdas compare EQUAL in the order but are not `=`
// (symbols no longer: the mint serial made their order total).
// cross-kind rank = the enum q kind, every numeric kind folded to the arith lane
// (KCharm) so fix/box/big/float/complex order by VALUE, not representation. Arrays
// divert to lvm_vbin before this, so KArr* never appear. One source of truth:
// the enum q order itself.
static ai_inline int cmp_rank(word x) { return (isnum(x) || Cp(x)) ? KCharm : (int) ai_kind(x); }
static ai_inline intptr_t bytes_cmp(const char *pa, uintptr_t la, const char *pb, uintptr_t lb) {
 uintptr_t n = la < lb ? la : lb;
 int c = n ? memcmp(pa, pb, n) : 0;
 return c ? (c < 0 ? -1 : 1) : la < lb ? -1 : la > lb ? 1 : 0; }
// symbols: the PRODUCT ORDER -- name lex first (nameless -> "", so mints sit
// below every named symbol), then interned before fresh on a name tie, then
// the mint serial (`code`; creation order). same-name noms used to compare
// EQUAL here while not being `=` -- the order wasn't total; the serial closes
// trichotomy.
static ai_inline bool sym_interned(word x) {
 return sym(x)->nom && strp(word(sym(x)->nom)); }
static ai_inline intptr_t sym_cmp(struct ai *g, word a, word b) {
 if (a == b) return 0;
 word core = (word) ai_core_of(g);                       // () is the nameless serial-0 point: least among symbols
 if (a == core) return -1;                               // (a != b, so b is some other symbol above it)
 if (b == core) return 1;                                // -- guarded by identity, its atom slots are never read
 struct ai_str *na = add_name(g, a), *nb = add_name(g, b);
 intptr_t c = bytes_cmp(na ? txt(na) : "", na ? na->len : 0, nb ? txt(nb) : "", nb ? nb->len : 0);
 if (c) return c;
 bool ia = sym_interned(a), ib = sym_interned(b);
 if (ia != ib) return ia ? -1 : 1;
 uintptr_t ca = sym(a)->code, cb = sym(b)->code;
 return ca < cb ? -1 : ca > cb ? 1 : 0; }
// 3-way total-order comparator (-1/0/1); the recursive engine for the pair case.
// Floats collapse NaN to "equal" here (a structural total order can't carry IEEE
// unorderedness); the scalar lane below keeps NaN unordered at the top level. hash
// is alloc-free + GC-stable, so the lambda case is safe to call mid-comparison.
static intptr_t cmp3(struct ai *g, word a, word b) {
 int ra = cmp_rank(a), rb = cmp_rank(b);
 if (ra != rb) return ra < rb ? -1 : 1;                    // cross-kind: type lattice
 switch (ra) {
  case KCharm:                                               // number band, by value
   if (Cp(a) || Cp(b)) {                                   // complex: (re, im) lexicographic
    ai_flo_t ar = Cp(a) ? cplx_re(a) : toflo(a), br = Cp(b) ? cplx_re(b) : toflo(b);
    if (ar != br) return ar < br ? -1 : 1;
    ai_flo_t ai = Cp(a) ? cplx_im(a) : 0, bi = Cp(b) ? cplx_im(b) : 0;
    return ai < bi ? -1 : ai > bi ? 1 : 0; }
   if (flop(a) || flop(b)) { ai_flo_t av = toflo(a), bv = toflo(b); return av < bv ? -1 : av > bv ? 1 : 0; }
   return ai_big_cmp(a, b);                                 // exact fix/box/big tower
  case KString: return bytes_cmp(txt(a), len(a), txt(b), len(b));
  case KSym:    return sym_cmp(g, a, b);
  case KTwo: { intptr_t c = cmp3(g, A(a), A(b)); return c ? c : cmp3(g, B(a), B(b)); }  // car, then cdr
  default: { uintptr_t ha = hash(g, a), hb = hash(g, b);   // lambda/map/port/buf: by repr hash
             return ha < hb ? -1 : ha > hb ? 1 : 0; } } }

// (sort l): sort a list ascending by the total order (cmp3), STABLE. One
// reservation up front -- n result pairs (committed) plus 2n scratch words
// (left in the uncommitted gap, GC-invisible) -- then a bottom-up merge over
// the scratch lanes and a single spine fill. cmp3 is alloc-free and
// GC-stable, so nothing moves between the reservation and the fill. The
// prel's `sort` dispatches (<)/(>) here (descending = rev) and keeps the
// lisp merge sort for arbitrary predicates. A non-pair passes through; a
// 1-element list returns itself (identity preserved, like the lisp sort).
// (tally l): the spine length of a list -- the number of pairs, blind to the
// elements (unlike $, which counts only the sat ones: a product of nothings
// is nothing, but it still has a length). the compiler's frame arithmetic
// runs on tally; the egg pulls it at birth with the other internals.
// (tally x): THE COUNT -- the second canonical foldMap (every generator weighs
// 1) beside $'s net (every generator weighs itself). a string or buf counts
// its charms, a list its spine, an array its cells, a map its keys, a symbol
// its spelling; a scalar counts nothing. this is what "length" always was.
lvm(lvm_tally) {
 word l = Sp[0]; intptr_t n = 0;
 if (strp(l)) n = (intptr_t) len(l);
 else if (bufp(l)) n = (intptr_t) len(buf_str(l));
 else if (mapp(l)) n = (intptr_t) map_len(l);
 else if (arrp(l)) n = (intptr_t) vec_nelem(vec(l));
 else if (symp(l)) n = (l != (word) ai_core_of(g) && sym(l)->nom) ? (intptr_t) len(sym(l)->nom) : 0;  // the core: nameless -> 0 charms
 else while (twop(l)) n++, l = B(l);
 Sp[0] = putcharm(n);
 return Ip++, Continue(); }

lvm(lvm_sort) {
 word l = Sp[0];
 if (!twop(l) || !twop(B(l))) return Ip++, Continue();
 uintptr_t n = 0;
 for (word p = l; twop(p); p = B(p)) n++;
 uintptr_t req = n * Width(struct ai_pair) + 2 * n;
 Have(req);
 l = Sp[0];                                        // re-read post-GC
 struct ai_pair *spine = (struct ai_pair*) Hp;
 Hp += n * Width(struct ai_pair);                   // commit the spine only
 word *a = (word*) Hp, *b = a + n;                 // scratch: the uncommitted gap
 uintptr_t i = 0;
 for (word p = l; twop(p); p = B(p)) a[i++] = A(p);
 for (uintptr_t w = 1; w < n; w *= 2) {            // bottom-up stable merge
  for (uintptr_t lo = 0; lo < n; lo += 2 * w) {
   uintptr_t m = min(lo + w, n), hi = min(lo + 2 * w, n), x = lo, y = m, o = lo;
   while (x < m && y < hi) b[o++] = cmp3(g, a[y], a[x]) < 0 ? a[y++] : a[x++];
   while (x < m) b[o++] = a[x++];
   while (y < hi) b[o++] = a[y++]; }
  word *t = a; a = b; b = t; }
 for (i = 0; i < n; i++) ini_two(spine + i, a[i], word(spine + i + 1));
 spine[n - 1].b = nil;
 return Sp[0] = word(spine), Ip++, Continue(); }

// the `<` / `<=` lane (op is vop_lt or vop_le). An array operand -> elementwise
// mask (lvm_vbin); a top-level float/complex pair is IEEE-faithful (NaN ->
// unordered -> false), so e.g. (<= nan nan) is nil.
static lvm(lvm_cmp_ord, int op) {
 word a = Sp[0], b = Sp[1]; intptr_t r;
 if (arrp(a) || arrp(b)) return Ap(lvm_vbin, g, op);      // array -> elementwise
 int ra = cmp_rank(a), rb = cmp_rank(b);
 if (ra != rb) r = vcmp_int(op, ra, rb);                   // cross-kind: type lattice
 else if (ra != KCharm) r = vcmp_int(op, cmp3(g, a, b), 0);  // string / sym / pair / lambda
 else if (Cp(a) || Cp(b)) {                                // complex: lexicographic, per op
  ai_flo_t ar = Cp(a) ? cplx_re(a) : toflo(a), br = Cp(b) ? cplx_re(b) : toflo(b);
  r = ar != br ? vcmp_flo(op, ar, br)
              : vcmp_flo(op, Cp(a) ? cplx_im(a) : 0, Cp(b) ? cplx_im(b) : 0); }
 else if (flop(a) || flop(b)) r = vcmp_flo(op, toflo(a), toflo(b));
 else if (bigp(a) || bigp(b)) r = vcmp_int(op, ai_big_cmp(a, b), 0);
 else r = vcmp_int(op, toint(a), toint(b));
 return *++Sp = r ? putcharm(1) : nil, Ip++, Continue(); }
// `<` `<=` -- the implemented side: both-fixnum fast path (tagged order is
// monotonic), else the lane. `>` `>=` are the other side: reverse the operands and
// reuse `<` `<=` (a > b == b < a; a >= b == b <= a).
#define cmp_lt(nom, vop) lvm(nom) { \
 word a = Sp[0], b = Sp[1]; \
 if (__builtin_expect(charmp(a) && charmp(b), 1)) \
  return *++Sp = vcmp_int(vop, a, b) ? putcharm(1) : nil, Ip++, Continue(); \
 return Ap(lvm_cmp_ord, g, vop); }
cmp_lt(lvm_lt, vop_lt) cmp_lt(lvm_le, vop_le)
#undef cmp_lt
lvm(lvm_gt) { word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t; return Ap(lvm_lt, g); }  // a > b == b < a
lvm(lvm_ge) { word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t; return Ap(lvm_le, g); }  // a >= b == b <= a

// Comparison from a 3-way sign of (lhs - rhs). Used when one operand is a bignum
// scalar: a bignum is always out of machine-int range (|bignum| > INTPTR_MAX, by
// canonical demotion), so it orders against any int element by its sign alone --
// exactly, where the low-bits truncation used for arithmetic would not.
static intptr_t vcmp_sign(int op, int s) {
 switch (op) {
  case vop_lt: return s < 0; case vop_le: return s <= 0;
  case vop_gt: return s > 0; case vop_ge: return s >= 0;
  default: return s == 0; } }                   // vop_eq

// The broadcast dim of two conformant axis sizes: a size-1 axis takes the
// OTHER size -- INCLUDING 0, so an empty axis stays empty (a max here turns
// (0,1) into 1 and fills one element out of an empty operand: garbage).
static ai_inline uintptr_t bdim(uintptr_t da, uintptr_t db) {
 return da == 1 ? db : db == 1 ? da : da; }

// Fill the (already-shaped) result r with a `op` b, broadcasting. All the
// &-taking stack arrays (strides, odometer) live here so the lvm wrapper stays
// TCO-clean. No allocation inside, so operand pointers can't move under us.
static ai_noinline void vbin_fill(struct ai_vec *r, word a, word b, int op, bool fdom) {
 uintptr_t R = r->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= r->shape[i];
 bool aarr = arrp(a), barr = arrp(b);
 struct ai_vec *va = aarr ? vec(a) : 0, *vb = barr ? vec(b) : 0;
 // CONTIGUOUS MONOTYPE FAST PATH: no size-1 broadcasting (each operand is either a
 // scalar or a full-shape array of the compute domain's storage type), so oa==ob==p
 // -- the per-cell odometer, offset recompute, and accessor/op dispatch all vanish.
 // Raw pointers, the op hoisted out of the loop ONCE, a tight body the compiler
 // vectorizes. Mixed types, bignum scalars, or genuine broadcasting fall through to
 // the general odometer loop below (correct, just not accelerated). Results are
 // bit-identical: same reads (raw f64/i64), same op (matches vop_flo/int/cmp).
 { bool cmpf = op >= vop_lt;
   bool aok = !aarr || vec_nelem(va) == n, bok = !barr || vec_nelem(vb) == n;
   bool nobig = !((!aarr && bigp(a)) || (!barr && bigp(b)));
   if (aok && bok && nobig) {
    if (fdom && (!aarr || va->type == ai_R) && (!barr || vb->type == ai_R)) {
     ai_flo_t sa = aarr ? 0 : toflo(a), sb = barr ? 0 : toflo(b);
     ai_flo_t *ap = aarr ? (ai_flo_t*) vec_data(va) : 0, *bp = barr ? (ai_flo_t*) vec_data(vb) : 0;
     if (cmpf) { intptr_t *rp = (intptr_t*) vec_data(r);
      #define VBF(E) do { for (uintptr_t p = 0; p < n; p++) { ai_flo_t av = aarr?ap[p]:sa, bv = barr?bp[p]:sb; rp[p] = (E)?1:0; } } while (0)
      switch (op) { case vop_lt: VBF(av<bv); return; case vop_le: VBF(av<=bv); return;
        case vop_gt: VBF(av>bv); return; case vop_ge: VBF(av>=bv); return; case vop_eq: VBF(av==bv); return; }
      #undef VBF
     } else { ai_flo_t *rp = (ai_flo_t*) vec_data(r);
      #define VBF(E) do { for (uintptr_t p = 0; p < n; p++) { ai_flo_t av = aarr?ap[p]:sa, bv = barr?bp[p]:sb; rp[p] = (E); } } while (0)
      switch (op) { case vop_add: VBF(av+bv); return; case vop_sub: VBF(av-bv); return;
        case vop_mul: VBF(av*bv); return; case vop_quot: VBF(av/bv); return;
        case vop_fquot: VBF(ai_trunc(av/bv)); return; case vop_rem: VBF(ai_fmod(av,bv)); return; }
      #undef VBF
     }
    } else if (!fdom && (!aarr || va->type == ai_Z) && (!barr || vb->type == ai_Z)) {
     intptr_t sia = aarr ? 0 : (charmp(a) ? (intptr_t) getcharm(a) : box_get(a));
     intptr_t sib = barr ? 0 : (charmp(b) ? (intptr_t) getcharm(b) : box_get(b));
     intptr_t *ap = aarr ? (intptr_t*) vec_data(va) : 0, *bp = barr ? (intptr_t*) vec_data(vb) : 0;
     intptr_t *rp = (intptr_t*) vec_data(r);   // r is ai_Z for both int-arith and the mask
     if (cmpf) {
      #define VBF(E) do { for (uintptr_t p = 0; p < n; p++) { intptr_t av = aarr?ap[p]:sia, bv = barr?bp[p]:sib; rp[p] = (E)?1:0; } } while (0)
      switch (op) { case vop_lt: VBF(av<bv); return; case vop_le: VBF(av<=bv); return;
        case vop_gt: VBF(av>bv); return; case vop_ge: VBF(av>=bv); return; case vop_eq: VBF(av==bv); return; }
      #undef VBF
     } else {
      #define VBF(E) do { for (uintptr_t p = 0; p < n; p++) { intptr_t av = aarr?ap[p]:sia, bv = barr?bp[p]:sib; rp[p] = (E); } } while (0)
      switch (op) {
        case vop_add: VBF((intptr_t)((uintptr_t)av+(uintptr_t)bv)); return;
        case vop_sub: VBF((intptr_t)((uintptr_t)av-(uintptr_t)bv)); return;
        case vop_mul: VBF((intptr_t)((uintptr_t)av*(uintptr_t)bv)); return;
        case vop_quot: case vop_fquot: VBF((bv==0||(av==INTPTR_MIN&&bv==-1))?0:av/bv); return;
        case vop_rem: VBF((bv==0||(av==INTPTR_MIN&&bv==-1))?0:av%bv); return; }
      #undef VBF
     } } } }
 // ca[j]/cb[j]: the operand flat-offset contribution of result axis j (0 when
 // that axis is absent in the operand or is a size-1 broadcast axis).
 intptr_t ca[maxrank], cb[maxrank], idx[maxrank];
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1;
  for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + R - va->rank;
   ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1;
  for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank;
   cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 bool cmp = op >= vop_lt;
 // scalar values: the float domain widens a bignum full-magnitude (ai_big_to_flo
 // via toflo); the int domain has no room for a bignum, so arithmetic demotes it
 // by low bits (modular). A *comparison* against a bignum, though, is decided
 // exactly by the bignum's sign below -- never by these low bits.
 ai_flo_t sa = aarr ? 0 : toflo(a), sb = barr ? 0 : toflo(b);
 intptr_t ia = aarr ? 0 : charmp(a) ? getcharm(a) : bigp(a) ? ai_big_low(a) : box_get(a),
          ib = barr ? 0 : charmp(b) ? getcharm(b) : bigp(b) ? ai_big_low(b) : box_get(b);
 bool abig = !aarr && bigp(a), bbig = !barr && bigp(b);   // at most one (the other is an array)
 int asign = abig ? (((struct ai_big*) a)->slen < 0 ? -1 : 1) : 0;
 int bsign = bbig ? (((struct ai_big*) b)->slen < 0 ? -1 : 1) : 0;
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  if (fdom) {
   ai_flo_t av = aarr ? vec_get_flo(va, oa) : sa, bv = barr ? vec_get_flo(vb, ob) : sb;
   if (cmp) vec_put_int(r, p, vcmp_flo(op, av, bv) ? 1 : 0);
   else vec_put_flo(r, p, vop_flo(op, av, bv)); }
  else {
   intptr_t av = aarr ? vec_get_int(va, oa) : ia, bv = barr ? vec_get_int(vb, ob) : ib;
   if (cmp) {                                    // bignum side (if any) sorts by sign: a-b ~ asign, or -bsign
    intptr_t t = (abig || bbig) ? vcmp_sign(op, abig ? asign : -bsign) : vcmp_int(op, av, bv);
    vec_put_int(r, p, t ? 1 : 0); }
   else vec_put_int(r, p, vop_int(op, av, bv)); }
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) {  // odometer
   if (++idx[j] < (intptr_t) r->shape[j]) break;
   idx[j] = 0; } } }

// For `/` (vop_quot) over the integer domain: true if some broadcast element pair
// (av, bv) divides inexactly (bv == 0 or av % bv != 0), so the whole result must
// promote to f64. A bignum scalar forces the float lane (its low word can't decide
// divisibility). ai_noinline: its &-taken stride/odometer arrays stay off lvm_vbin's
// tail call. Called only after conformance is checked, so every offset is in range.
static ai_noinline bool vquot_needs_float(word a, word b) {
 bool aarr = arrp(a), barr = arrp(b);
 if ((!aarr && bigp(a)) || (!barr && bigp(b))) return true;
 struct ai_vec *va = aarr ? vec(a) : 0, *vb = barr ? vec(b) : 0;
 uintptr_t ra = aarr ? va->rank : 0, rb = barr ? vb->rank : 0, R = ra > rb ? ra : rb, n = 1;
 intptr_t ca[maxrank], cb[maxrank], idx[maxrank], shp[maxrank];
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? va->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vb->shape[rb - 1 - k] : 1;
  shp[R - 1 - k] = (intptr_t) bdim(da, db); n *= bdim(da, db); }
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1; for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + (intptr_t) R - (intptr_t) va->rank; ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1; for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank; cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 intptr_t ia = aarr ? 0 : toint(a), ib = barr ? 0 : toint(b);
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  intptr_t av = aarr ? vec_get_int(va, oa) : ia, bv = barr ? vec_get_int(vb, ob) : ib;
  if (bv == 0 || av % bv != 0) return true;
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) { if (++idx[j] < shp[j]) break; idx[j] = 0; } }
 return false; }

lvm(lvm_vbin, int op) {
 word a = Sp[0], b = Sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 // complex lane first: a packed ai_C array, or a complex scalar paired with an
 // array (a complex scalar isn't isnum, so it must divert before the gate below).
 // Mixing ai_C with a ai_O object array is unsupported (neither reads the other's
 // element encoding) -- the ai_O lane wins there.
 if (((aarr && vec(a)->type == ai_C) || (barr && vec(b)->type == ai_C) || Cp(a) || Cp(b))
     && !(aarr && vec(a)->type == ai_O) && !(barr && vec(b)->type == ai_O))
  return Ap(lvm_cbin, g, op);
 if (!(aarr || isnum(a)) || !(barr || isnum(b)))   // each operand: array or scalar
  return *++Sp = nil, Ip++, Continue();
 if ((aarr && vec(a)->type == ai_O) || (barr && vec(b)->type == ai_O))
  return Ap(lvm_obin, g, op);                     // object array -> promoting lane
 uintptr_t ra = aarr ? vec(a)->rank : 0, rb = barr ? vec(b)->rank : 0;
 uintptr_t R = ra > rb ? ra : rb;
 // compute-type = max element type; a scalar int contributes the lowest type
 // (i8) so it never widens an int array, a scalar float forces the float lane.
 int ta = aarr ? (int) vec(a)->type : flop(a) ? (int) ai_R : (int) ai_Z;
 int tb = barr ? (int) vec(b)->type : flop(b) ? (int) ai_R : (int) ai_Z;
 int ct = ta > tb ? ta : tb;
 bool fdom = ct >= ai_R, cmp = op >= vop_lt;
 // broadcast shape + conformance, right-aligned; scalar locals only (no array,
 // so the trailing tail call below survives).
 uintptr_t n = 1;
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) return *++Sp = nil, Ip++, Continue();
  n *= bdim(da, db); }
 // `/` over an all-integer broadcast promotes the whole result to f64 the moment
 // any element divides inexactly (matching the scalar `/`); `//` (vop_fquot) stays
 // integer. Sound only after conformance is known good (offsets are then in range).
 if (op == vop_quot && !fdom && !cmp && vquot_needs_float(a, b)) fdom = true, ct = ai_R;
 enum ai_vec_type rt = cmp ? ai_Z : (enum ai_vec_type) ct;   // compare -> 0/1 Z mask
 uintptr_t bytes = sizeof(struct ai_vec) + R * sizeof(word) + n * ai_T[rt];
 Have(b2w(bytes));
 a = Sp[0], b = Sp[1], aarr = arrp(a), barr = arrp(b);       // re-read post-Have
 struct ai_vec *r = (struct ai_vec*) Hp; Hp += b2w(bytes);
 ini_vec(r, rt, R);
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
  r->shape[R - 1 - k] = bdim(da, db); }
 vbin_fill(r, a, b, op, fdom);
 return *++Sp = word(r), Ip++, Continue(); }

// --- dyadic libm map with broadcasting (pow / atan2 over arrays) -------------
// The float-domain twin of lvm_vbin: same numpy broadcast, but the result is
// always a float array and each element is fn(av, bv) for an arbitrary libm
// dyadic fn. A scalar operand broadcasts, widening through toflo -- so a bignum
// scalar feeds in at full magnitude (ai_big_to_flo), same as the scalar `pow`.
// All the &-taking stack arrays live in this ai_noinline fill so the wrapper's
// trailing tail call survives.
static ai_noinline void vmap2_fill(struct ai_vec *r, word a, word b, ai_flo_t (*fn)(ai_flo_t, ai_flo_t)) {
 uintptr_t R = r->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= r->shape[i];
 bool aarr = arrp(a), barr = arrp(b);
 struct ai_vec *va = aarr ? vec(a) : 0, *vb = barr ? vec(b) : 0;
 intptr_t ca[maxrank], cb[maxrank], idx[maxrank];
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1;
  for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + (intptr_t) R - (intptr_t) va->rank;
   ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1;
  for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank;
   cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 ai_flo_t sa = aarr ? 0 : toflo(a), sb = barr ? 0 : toflo(b);
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  ai_flo_t av = aarr ? vec_get_flo(va, oa) : sa, bv = barr ? vec_get_flo(vb, ob) : sb;
  vec_put_flo(r, p, fn(av, bv));
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) {  // odometer
   if (++idx[j] < (intptr_t) r->shape[j]) break;
   idx[j] = 0; } } }

lvm(lvm_vmap2, ai_flo_t (*fn)(ai_flo_t, ai_flo_t)) {
 word a = Sp[0], b = Sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 if (!(aarr || isnum(a)) || !(barr || isnum(b)))   // each operand: array or scalar
  return *++Sp = nil, Ip++, Continue();
 uintptr_t ra = aarr ? vec(a)->rank : 0, rb = barr ? vec(b)->rank : 0;
 uintptr_t R = ra > rb ? ra : rb, n = 1;
 for (uintptr_t k = 0; k < R; k++) {               // broadcast shape, right-aligned
  uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) return *++Sp = nil, Ip++, Continue();
  n *= bdim(da, db); }
 uintptr_t bytes = sizeof(struct ai_vec) + R * sizeof(word) + n * ai_T[ai_R];
 Have(b2w(bytes));
 a = Sp[0], b = Sp[1], aarr = arrp(a), barr = arrp(b);       // re-read post-Have
 struct ai_vec *r = (struct ai_vec*) Hp; Hp += b2w(bytes);
 ini_vec(r, ai_R, R);
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
  r->shape[R - 1 - k] = bdim(da, db); }
 vmap2_fill(r, a, b, fn);
 return *++Sp = word(r), Ip++, Continue(); }

// ============================================================================
// obin -- object-array elementwise lane (ai_O)
// ============================================================================
// The typed lanes (vbin/vmap) read raw C ints/floats and never allocate, so a
// fixed-width int array *wraps* on overflow. The object lane instead routes every
// element through the scalar dispatch (obin_elem), which promotes fixnum->box->
// bignum and boxes floats -- so a ai_O array adds/multiplies *exactly*. Cost: the
// inner loop allocates, so it runs Pack'd (lvm_obin -> obin_run) and re-fetches
// every live pointer (result, operands) after each element, exactly like the
// other allocate-in-a-loop paths (cf. host_run, ai_big_binop).

// One element op: a (op) b for two scalar values, allocating via *fp (may GC --
// a/b are passed by value and rooted before the first allocation here). Returns
// the result value, or nil for a non-numeric / complex operand (deferred).
static word obin_elem(struct ai **fp, int op, word a, word b) {
 if (op >= vop_lt) {                            // comparison -> 1 / nil, no allocation
  if (!isnum(a) || !isnum(b)) return nil;       // Cp not in isnum -> unordered -> nil
  intptr_t t = (flop(a) || flop(b)) ? vcmp_flo(op, toflo(a), toflo(b))
             : (bigp(a) || bigp(b)) ? vcmp_int(op, ai_big_cmp(a, b), 0)
                                    : vcmp_int(op, toint(a), toint(b));
  return t ? putcharm(1) : nil; }
 if (!isnum(a) || !isnum(b)) return nil;
 struct ai *g = *fp;
 if (flop(a) || flop(b)) {                      // float domain -> ai_R box
  if (!ai_ok(g = ai_have(g, box_req))) return *fp = g, nil;
  *fp = g;
  struct ai_vec *v = ini_scalar((struct ai_vec*) g->hp, ai_R);
  g->hp += box_req; flo_put(v->shape, vop_flo(op, toflo(a), toflo(b)));
  return word(v); }
 if (!bigp(a) && !bigp(b)) {                    // machine-int fast path, overflow-checked
  intptr_t av = toint(a), bv = toint(b), t; bool of;
  switch (op) {
   case vop_quot: case vop_fquot:                         // object (ai_O) arrays truncate under both / and //
                  if (bv == 0) return putcharm(0);          // array convention: int /0 -> 0
                  of = (av == INTPTR_MIN && bv == -1); t = of ? 0 : av / bv; break;
   case vop_rem:  if (bv == 0) return putcharm(0);
                  of = (av == INTPTR_MIN && bv == -1); t = of ? 0 : av % bv; break;
   case vop_sub:  of = __builtin_sub_overflow(av, bv, &t); break;
   case vop_mul:  of = __builtin_mul_overflow(av, bv, &t); break;
   default:       of = __builtin_add_overflow(av, bv, &t); break; }   // vop_add
  if (!of) {                                    // demote-or-box the result
   if (t >= fix_min && t <= fix_max) return putcharm(t);
   if (!ai_ok(g = ai_have(g, box_req))) return *fp = g, nil;
   *fp = g;
   struct ai_vec *v = ini_scalar((struct ai_vec*) g->hp, ai_Z);
   g->hp += box_req; box_put(v->shape, t); return word(v); } }
 // bignum lane: ai_big_binop computes sp[0] (op) sp[1], leaves it at sp[1],
 // pops one, and advances ip -- so save/restore ip and pop the net result.
 if (!ai_ok(g = ai_push(g, 2, a, b))) return *fp = g, nil;
 union u *ip0 = g->ip;
 g = ai_big_binop(g, op);
 if (!ai_ok(g)) return *fp = g, nil;
 g->ip = ip0;
 word r = g->sp[0]; g->sp++;
 return *fp = g, r; }

// Widen the numeric array at g->sp[slot] to a ai_O copy in place (box each
// element), so the obin loop reads values uniformly. Allocates per element; the
// source (rooted at its slot) and the partially-built copy (parked on the stack)
// are re-fetched after every box.
static struct ai *arr_to_obj(struct ai *g, int slot) {
 struct ai_vec *src = vec(g->sp[slot]);
 uintptr_t R = src->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= src->shape[i];
 uintptr_t bytes = sizeof(struct ai_vec) + R * sizeof(word) + n * ai_T[ai_O];
 if (!ai_ok(g = ai_have(g, b2w(bytes)))) return g;
 src = vec(g->sp[slot]);
 struct ai_vec *dst = (struct ai_vec*) g->hp; g->hp += b2w(bytes);
 ini_vec(dst, ai_O, R);
 for (uintptr_t i = 0; i < R; i++) dst->shape[i] = src->shape[i];
 for (uintptr_t i = 0; i < n; i++) vec_put_obj(dst, i, nil);   // safe pre-fill (GC may see it)
 if (!ai_ok(g = ai_push(g, 1, word(dst)))) return g;             // sp[0]=dst, src now at slot+1
 for (uintptr_t i = 0; i < n; i++) {
  struct ai_vec *s = vec(g->sp[slot + 1]);
  word v;
  if (s->type >= ai_R) {                                        // float -> ai_R box
   ai_flo_t e = vec_get_flo(s, i);
   if (!ai_ok(g = ai_have(g, box_req))) return g;
   struct ai_vec *bx = ini_scalar((struct ai_vec*) g->hp, ai_R); g->hp += box_req;
   flo_put(bx->shape, e); v = word(bx); }
  else {                                                       // int -> fixnum or ai_Z box
   intptr_t e = vec_get_int(s, i);
   if (e >= fix_min && e <= fix_max) v = putcharm(e);
   else { if (!ai_ok(g = ai_have(g, box_req))) return g;
    struct ai_vec *bx = ini_scalar((struct ai_vec*) g->hp, ai_Z); g->hp += box_req;
    box_put(bx->shape, e); v = word(bx); } }
  vec_put_obj(vec(g->sp[0]), i, v); }                          // re-fetch dst post-box
 word d = g->sp[0]; g->sp++; g->sp[slot] = d;                  // install copy, drop the parked root
 return g; }

// Pack'd body of lvm_obin (operands at g->sp[0..1], >=1 is a ai_O array).
static struct ai *obin_run(struct ai *g, int op) {
 word a = g->sp[0], b = g->sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 if (aarr && vec(a)->type != ai_O) { if (!ai_ok(g = arr_to_obj(g, 0))) return g; }
 if (barr && vec(b)->type != ai_O) { if (!ai_ok(g = arr_to_obj(g, 1))) return g; }
 a = g->sp[0], b = g->sp[1], aarr = arrp(a), barr = arrp(b);
 uintptr_t ra = aarr ? vec(a)->rank : 0, rb = barr ? vec(b)->rank : 0;
 uintptr_t R = ra > rb ? ra : rb, n = 1, shp[maxrank];
 for (uintptr_t k = 0; k < R; k++) {                           // broadcast shape, right-aligned
  uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) {                        // non-conforming -> nil
   g->sp[1] = nil, g->sp++, g->ip = (union u*) g->ip + 1; return g; }
  shp[R - 1 - k] = bdim(da, db); n *= bdim(da, db); }
 uintptr_t bytes = sizeof(struct ai_vec) + R * sizeof(word) + n * ai_T[ai_O];
 if (!ai_ok(g = ai_have(g, b2w(bytes)))) return g;
 struct ai_vec *r = (struct ai_vec*) g->hp; g->hp += b2w(bytes);
 ini_vec(r, ai_O, R);
 for (uintptr_t k = 0; k < R; k++) r->shape[k] = shp[k];
 for (uintptr_t p = 0; p < n; p++) vec_put_obj(r, p, nil);     // nil-fill before any GC
 if (!ai_ok(g = ai_push(g, 1, word(r)))) return g;               // sp: [0]=r [1]=a [2]=b
 intptr_t ca[maxrank], cb[maxrank], idx[maxrank];
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1; struct ai_vec *va = vec(g->sp[1]);
  for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + (intptr_t) R - (intptr_t) va->rank;
   ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1; struct ai_vec *vb = vec(g->sp[2]);
  for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank;
   cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  word ae = aarr ? vec_get_obj(vec(g->sp[1]), oa) : g->sp[1];  // scalar operand re-read each step
  word be = barr ? vec_get_obj(vec(g->sp[2]), ob) : g->sp[2];
  word res = obin_elem(&g, op, ae, be);
  if (!ai_ok(g)) return g;
  vec_put_obj(vec(g->sp[0]), p, res);                          // re-fetch result post-alloc
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) {
   if (++idx[j] < (intptr_t) shp[j]) break;
   idx[j] = 0; } }
 word result = g->sp[0];                                       // collapse [r,a,b] -> r, advance ip
 g->sp += 2, g->sp[0] = result, g->ip = (union u*) g->ip + 1;
 return g; }

lvm(lvm_obin, int op) {
 Pack(g);
 g = obin_run(g, op);
 if (!ai_ok(g)) return ghelp(g);
 return Unpack(g), Continue(); }

// ai_O reduction body (kind: 0 sum, 1 prod, 2 max, 3 min). g->sp[0] is the array.
static struct ai *ored(struct ai *g, int kind) {
 struct ai_vec *v = vec(g->sp[0]);
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 if (kind >= 2) {                                              // max/min: pick an element, no alloc
  if (!n) { g->sp[0] = nil, g->ip = (union u*) g->ip + 1; return g; }
  word acc = vec_get_obj(vec(g->sp[0]), 0);
  int cop = kind == 2 ? vop_gt : vop_lt;
  for (uintptr_t i = 1; i < n; i++) {
   word e = vec_get_obj(vec(g->sp[0]), i);
   if (obin_elem(&g, cop, e, acc) == putcharm(1)) acc = e; }
  g->sp[0] = acc, g->ip = (union u*) g->ip + 1; return g; }
 word init = kind == 0 ? putcharm(0) : putcharm(1);               // sum/prod: fold with allocation
 int aop = kind == 0 ? vop_add : vop_mul;
 if (!ai_ok(g = ai_push(g, 1, init))) return g;                 // sp[0]=acc, sp[1]=array
 for (uintptr_t i = 0; i < n; i++) {
  word e = vec_get_obj(vec(g->sp[1]), i);
  word acc = obin_elem(&g, aop, g->sp[0], e);
  if (!ai_ok(g)) return g;
  g->sp[0] = acc; }
 word result = g->sp[0]; g->sp++, g->sp[0] = result;          // collapse acc into the array slot
 g->ip = (union u*) g->ip + 1;
 return g; }

// (re, im) of an operand for the complex lane / equality: a complex contributes
// its two parts; a real number contributes (value, 0). toflo widens a fixnum /
// float box / wide-int box / bignum -- a bignum narrows to double here, since
// complex is a floating domain (decision 5). Caller guarantees x is Cp or
// isnum. The &out params stay inside ai_noinline callers, off the VM tail call.
static ai_inline void cplx_parts(word x, ai_flo_t *re, ai_flo_t *im) {
 if (Cp(x)) *re = cplx_re(x), *im = cplx_im(x);
 else *re = toflo(x), *im = 0; }

// Fill the rank-0 complex box v with a `vop` b. All the &-taking lives in this
// ai_noinline helper so the lvm wrapper keeps its trailing tail call; no
// allocation inside, so the operand pointers can't move under us.
static ai_noinline void cplx_fill(struct ai_vec *v, word a, word b, int vop) {
 ai_flo_t ar, ai, br, bi, re, im;
 cplx_parts(a, &ar, &ai); cplx_parts(b, &br, &bi);
 switch (vop) {
  case vop_sub: re = ar - br; im = ai - bi; break;
  case vop_mul: re = ar * br - ai * bi; im = ar * bi + ai * br; break;
  case vop_quot: { ai_flo_t d = br * br + bi * bi;   // (ac+bd)/(c^2+d^2) + ...
   re = (ar * br + ai * bi) / d; im = (ai * br - ar * bi) / d; break; }
  default: re = ar + br; im = ai + bi; }            // vop_add
 cplx_put(v, re, im); }

// The complex arithmetic lane. Reached from the arith slow paths when either
// operand is complex. A real operand promotes to (r, 0); a non-numeric operand,
// or vop_rem (% is undefined on complex), yields nil. TCO-clean: the validation
// and box are in the body (no &local), the math is in cplx_fill.
lvm(lvm_cplx_bin, int vop) {
 word a = Sp[0], b = Sp[1];
 if (!(Cp(a) || isnum(a)) || !(Cp(b) || isnum(b)) || vop > vop_quot)
  return *++Sp = nil, Ip++, Continue();
 Have(cplx_req);
 a = Sp[0], b = Sp[1];                              // re-read post-Have
 struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_C);
 Hp += cplx_req;
 cplx_fill(v, a, b, vop);
 return *++Sp = word(v), Ip++, Continue(); }

// --- complex-array elementwise lane (ai_C) ----------------------------------
// The complex twin of lvm_vbin: packed (re,im) numpy broadcast. An array operand
// is a ai_C (packed) array or a real ai_Z/ai_R array (each element promotes to (v,0));
// a scalar operand is a complex box or any real number. + - * / use cplx_fill's
// formulas; `=` writes a ai_Z 0/1 mask (componentwise equal); ordering and % are
// undefined on complex (handled in the wrapper -> nil). The &-taking odometer/
// stride arrays live in this ai_noinline fill so the wrapper keeps its tail call.
static ai_inline void cbin_part(bool isarr, struct ai_vec *v, ai_flo_t sre, ai_flo_t sim,
                               uintptr_t o, ai_flo_t *re, ai_flo_t *im) {
 if (!isarr) { *re = sre; *im = sim; return; }
 if (v->type == ai_C) { ai_flo_t *fp = vec_data(v); *re = fp[2*o]; *im = fp[2*o+1]; }
 else { *re = vec_get_flo(v, o); *im = 0; } }

static ai_noinline void cbin_fill(struct ai_vec *r, word a, word b, int op, bool cmp) {
 uintptr_t R = r->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= r->shape[i];
 bool aarr = arrp(a), barr = arrp(b);
 struct ai_vec *va = aarr ? vec(a) : 0, *vb = barr ? vec(b) : 0;
 intptr_t ca[maxrank], cb[maxrank], idx[maxrank];
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1;
  for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + (intptr_t) R - (intptr_t) va->rank;
   ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1;
  for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank;
   cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 ai_flo_t sar = 0, sai = 0, sbr = 0, sbi = 0;
 if (!aarr) { if (Cp(a)) sar = cplx_re(a), sai = cplx_im(a); else sar = toflo(a); }
 if (!barr) { if (Cp(b)) sbr = cplx_re(b), sbi = cplx_im(b); else sbr = toflo(b); }
 ai_flo_t *rf = cmp ? 0 : vec_data(r);
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  ai_flo_t ar, ai, br, bi, re, im;
  cbin_part(aarr, va, sar, sai, oa, &ar, &ai);
  cbin_part(barr, vb, sbr, sbi, ob, &br, &bi);
  if (cmp) vec_put_int(r, p, (ar == br && ai == bi) ? 1 : 0);
  else {
   switch (op) {
    case vop_sub: re = ar - br; im = ai - bi; break;
    case vop_mul: re = ar * br - ai * bi; im = ar * bi + ai * br; break;
    case vop_quot: { ai_flo_t d = br * br + bi * bi;
     re = (ar * br + ai * bi) / d; im = (ai * br - ar * bi) / d; break; }
    default: re = ar + br; im = ai + bi; }            // vop_add
   rf[2*p] = re; rf[2*p+1] = im; }
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) {  // odometer
   if (++idx[j] < (intptr_t) r->shape[j]) break;
   idx[j] = 0; } } }

lvm(lvm_cbin, int op) {
 word a = Sp[0], b = Sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 // operand: array / complex scalar / real number. %, // and the orderings are
 // undefined on complex; only `=` survives among the comparisons (-> a mask).
 if (!(aarr || Cp(a) || isnum(a)) || !(barr || Cp(b) || isnum(b))
     || op == vop_rem || op == vop_fquot || (op >= vop_lt && op != vop_eq))
  return *++Sp = nil, Ip++, Continue();
 bool cmp = op == vop_eq;
 uintptr_t ra = aarr ? vec(a)->rank : 0, rb = barr ? vec(b)->rank : 0;
 uintptr_t R = ra > rb ? ra : rb, n = 1;
 for (uintptr_t k = 0; k < R; k++) {                  // broadcast shape + conformance, right-aligned
  uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) return *++Sp = nil, Ip++, Continue();
  n *= bdim(da, db); }
 enum ai_vec_type rt = cmp ? ai_Z : ai_C;              // compare -> i64 mask, else packed complex
 uintptr_t bytes = sizeof(struct ai_vec) + R * sizeof(word) + n * ai_T[rt];
 Have(b2w(bytes));
 a = Sp[0], b = Sp[1], aarr = arrp(a), barr = arrp(b);     // re-read post-Have
 struct ai_vec *r = (struct ai_vec*) Hp; Hp += b2w(bytes);
 ini_vec(r, rt, R);
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
  r->shape[R - 1 - k] = bdim(da, db); }
 cbin_fill(r, a, b, op, cmp);
 return *++Sp = word(r), Ip++, Continue(); }

// Fill complex box v with w ** z via the principal branch: w^z = exp(z * Log w),
// Log w = ln|w| + i*arg w. A real operand promotes to (r, 0) (cplx_parts). w == 0
// falls out as the IEEE limit (exp(-inf) -> 0 for Re z > 0), same domain stance as
// real pow. &-locals stay in this ai_noinline helper, off lvm_pow's tail call.
static ai_noinline void cplx_pow_fill(struct ai_vec *v, word wbase, word zexp) {
 ai_flo_t wr, wi, zr, zi;
 cplx_parts(wbase, &wr, &wi); cplx_parts(zexp, &zr, &zi);
 ai_flo_t lr = (ai_flo_t) 0.5 * ai_log(wr * wr + wi * wi),    // ln|w|
         li = ai_atan2(wi, wr);                             // arg w
 ai_flo_t pr = zr * lr - zi * li, pi = zr * li + zi * lr,   // z * Log w
         e = ai_exp(pr);
 cplx_put(v, e * ai_cos(pi), e * ai_sin(pi)); }

// sin/cos of pi*x for finite non-integer x (the caller's flo_fracp guarantee,
// so the int cast is safe). The angle is reduced BEFORE multiplying by pi, so
// it never rounds through the float pi and a half-integer x lands exactly on
// the axis: sinpi(1/2) = 1, cospi(1/2) = 0 -- what makes ((/ 1 2) -1) = i
// bit-exact (the inputs are exact; pi*x in floats is where the error lives).
static ai_flo_t ai_sinpi(ai_flo_t x) {
 intptr_t n = (intptr_t) x; ai_flo_t r = x - (ai_flo_t) n;
 if (r < 0) r += 1, n--;                              // x = n + r, r in (0,1)
 ai_flo_t s = r == (ai_flo_t) 0.5 ? 1
   : ai_sin((ai_flo_t) 3.141592653589793 * (r < (ai_flo_t) 0.5 ? r : 1 - r));
 return n & 1 ? -s : s; }
static ai_flo_t ai_cospi(ai_flo_t x) {
 intptr_t n = (intptr_t) x; ai_flo_t r = x - (ai_flo_t) n;
 if (r < 0) r += 1, n--;
 ai_flo_t c = r == (ai_flo_t) 0.5 ? 0
   : r < (ai_flo_t) 0.5 ? ai_cos((ai_flo_t) 3.141592653589793 * r)
   : -ai_cos((ai_flo_t) 3.141592653589793 * (1 - r));
 return n & 1 ? -c : c; }
// finite non-integer? everything at/past 2^mantissa is an integer; nan/inf out.
static ai_inline bool flo_fracp(ai_flo_t x) {
 ai_flo_t lim = (ai_flo_t) (1ull << (Bits == 64 ? 53 : 24));
 return x > -lim && x < lim && (ai_flo_t) (intptr_t) x != x; }

// (pow b e) = b ** e. Complex base or exponent -> the complex lane above; a finite
// negative real base to a non-integer power widens to its principal root
// |b|^e * (cospi(e), sinpi(e)) instead of nan -- pow climbs tiers like log, and
// ((/ 1 2) -1) = i exactly. An infinite/integer-power/array case keeps the IEEE
// real lanes (lvm_math2 -> real pow, or vmap2 elementwise over arrays).
lvm(lvm_pow) {
 word a = Sp[0], b = Sp[1];
 if (Cp(a) || Cp(b)) {
  if (!(Cp(a) || isnum(a)) || !(Cp(b) || isnum(b)))
   return *++Sp = nil, Ip++, Continue();
  Have(cplx_req);
  a = Sp[0], b = Sp[1];                              // re-read post-Have
  struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_C);
  Hp += cplx_req;
  cplx_pow_fill(v, a, b);
  return *++Sp = word(v), Ip++, Continue(); }
 if (isnum(a) && isnum(b)) {
  ai_flo_t ad = toflo(a), bd = toflo(b);
  if (ad < 0 && !__builtin_isinf(ad) && flo_fracp(bd)) {
   ai_flo_t m = ai_pow(-ad, bd), re = m * ai_cospi(bd), im = m * ai_sinpi(bd);
   Have(cplx_req);
   struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_C);
   Hp += cplx_req;
   cplx_put(v, re, im);
   return *++Sp = word(v), Ip++, Continue(); } }
 return Ap(lvm_math2, g, ai_pow); }

// (C re im): build a complex from two real numbers. Non-numeric arg -> nil.
// Fill packed ai_C array r with (re = a-element, im = b-element) under numpy
// broadcast; a, b are real (ai_Z/ai_R) arrays or real scalars. &-taking stride/
// odometer arrays live in this ai_noinline fill so lvm_cplx keeps its tail call.
static ai_noinline void cplx_build_fill(struct ai_vec *r, word a, word b) {
 uintptr_t R = r->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= r->shape[i];
 bool aarr = arrp(a), barr = arrp(b);
 struct ai_vec *va = aarr ? vec(a) : 0, *vb = barr ? vec(b) : 0;
 intptr_t ca[maxrank], cb[maxrank], idx[maxrank];
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1; for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + (intptr_t) R - (intptr_t) va->rank; ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1; for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank; cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 ai_flo_t sa = aarr ? 0 : toflo(a), sb = barr ? 0 : toflo(b);
 ai_flo_t *rf = vec_data(r);
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  rf[2*p]   = aarr ? vec_get_flo(va, oa) : sa;
  rf[2*p+1] = barr ? vec_get_flo(vb, ob) : sb;
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) { if (++idx[j] < (intptr_t) r->shape[j]) break; idx[j] = 0; } } }

// (C re im): build a complex from two reals. Scalars -> a rank-0 complex box;
// a real array operand (with the other broadcasting) -> a packed ai_C array, so
// (arg (C 1 x)) = atan and (arg (C x y)) = atan2 stay elementwise. A complex or
// object array operand, or a non-numeric scalar, -> nil.
lvm(lvm_cplx) {
 word a = Sp[0], b = Sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 if (aarr || barr) {
  if ((aarr && vec(a)->type >= ai_C) || (barr && vec(b)->type >= ai_C)
      || (!aarr && !isnum(a)) || (!barr && !isnum(b)))
   return *++Sp = nil, Ip++, Continue();
  uintptr_t ra = aarr ? vec(a)->rank : 0, rb = barr ? vec(b)->rank : 0;
  uintptr_t R = ra > rb ? ra : rb, n = 1;
  for (uintptr_t k = 0; k < R; k++) {
   uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
   uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
   if (da != db && da != 1 && db != 1) return *++Sp = nil, Ip++, Continue();
   n *= bdim(da, db); }
  uintptr_t bytes = sizeof(struct ai_vec) + R * sizeof(word) + n * ai_T[ai_C];
  Have(b2w(bytes));
  a = Sp[0], b = Sp[1], aarr = arrp(a), barr = arrp(b);     // re-read post-Have
  struct ai_vec *r = (struct ai_vec*) Hp; Hp += b2w(bytes);
  ini_vec(r, ai_C, R);
  for (uintptr_t k = 0; k < R; k++) {
   uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
   uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
   r->shape[R - 1 - k] = bdim(da, db); }
  cplx_build_fill(r, a, b);
  return *++Sp = word(r), Ip++, Continue(); }
 if (!isnum(a) || !isnum(b)) return *++Sp = nil, Ip++, Continue();
 ai_flo_t re = toflo(a), im = toflo(b);             // values extracted before alloc
 Have(cplx_req);
 struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_C);
 Hp += cplx_req;
 cplx_put(v, re, im);
 return *++Sp = word(v), Ip++, Continue(); }

// (Cp x): is x a complex scalar?
op11(lvm_Cp, Cp(Sp[0]) ? putcharm(1) : nil)

// (re z) / (im z): real / imaginary part as a rank-0 float box. On a real
// number, re is the number itself and im is 0; on a non-number, nil.
lvm(lvm_re) {
 word a = Sp[0], _res;
 if (Cp(a)) { ai_flo_t re = cplx_re(a); Have(box_req); emit_flo(re);
  return Sp[0] = _res, Ip++, Continue(); }
 if (isnum(a)) return Ip++, Continue();            // re of a real is itself
 return Sp[0] = nil, Ip++, Continue(); }

lvm(lvm_im) {
 word a = Sp[0], _res;
 if (Cp(a)) { ai_flo_t im = cplx_im(a); Have(box_req); emit_flo(im);
  return Sp[0] = _res, Ip++, Continue(); }
 if (isnum(a)) return Sp[0] = putcharm(0), Ip++, Continue();   // im of a real is 0
 return Sp[0] = nil, Ip++, Continue(); }

// (conj z): complex conjugate (re, -im). conj LIFTS: a real r becomes ~(r 0)
// (= r by value, the tower bridges), so conj is the monadic `~` -- it always
// lands in C. (It used to pass a real through; lifting makes conj == the old
// `wave`, so `~x` reads as (conj x) and the constructor takes the name `wave`.)
lvm(lvm_conj) {
 word a = Sp[0];
 if (Cp(a)) { ai_flo_t re = cplx_re(a), im = cplx_im(a);
  Have(cplx_req);
  struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_C); Hp += cplx_req;
  cplx_put(v, re, -im);
  return Sp[0] = word(v), Ip++, Continue(); }
 if (isnum(a)) { ai_flo_t re = toflo(a);            // lift a real to ~(r 0)
  Have(cplx_req);
  struct ai_vec *v = ini_scalar((struct ai_vec*) Hp, ai_C); Hp += cplx_req;
  cplx_put(v, re, 0);
  return Sp[0] = word(v), Ip++, Continue(); }
 return Sp[0] = nil, Ip++, Continue(); }

// (abs z): type-aware magnitude. Complex -> sqrt(re^2+im^2) (a float). Real ->
// |z| in its own tier: fixnum stays fixnum (or boxes if |fix_min| overflows the
// tag), float stays float, bignum stays bignum (just flips its sign). The lone
// wart is a wide-int box holding INTPTR_MIN, whose magnitude needs a bignum --
// rare enough to leave (it re-boxes INTPTR_MIN unchanged), same flavor as the
// arith INT_MIN/-1 edge.
lvm(lvm_abs) {
 word a = Sp[0], _res;
 if (Cp(a)) { ai_flo_t m = cplx_mod(a);
  Have(box_req); emit_flo(m); return Sp[0] = _res, Ip++, Continue(); }
 if (charmp(a)) { intptr_t n = getcharm(a);
  Have(box_req); emit_int(n < 0 ? (intptr_t) (0 - (uintptr_t) n) : n);
  return Sp[0] = _res, Ip++, Continue(); }
 if (flop(a)) { ai_flo_t v = flo_get(a); if (v < 0) v = -v;
  Have(box_req); emit_flo(v); return Sp[0] = _res, Ip++, Continue(); }
 if (widep(a)) { intptr_t n = box_get(a);
  Have(box_req); emit_int(n < 0 ? (intptr_t) (0 - (uintptr_t) n) : n);
  return Sp[0] = _res, Ip++, Continue(); }
 if (bigp(a)) {
  struct ai_big *x = (struct ai_big*) a;
  if (x->slen > 0) return Ip++, Continue();         // already non-negative
  uintptr_t bytes = ai_big_bytes(x); Have(b2w(bytes));
  x = (struct ai_big*) Sp[0];                         // re-read post-Have
  struct ai_big *y = (struct ai_big*) Hp; Hp += b2w(bytes);
  memcpy(y, x, bytes); y->slen = -x->slen;           // flip the sign
  return Sp[0] = word(y), Ip++, Continue(); }
 if (arrp(a)) {                                       // vector -> scalar: the Euclidean (L2) norm
  struct ai_vec *v = vec(a); uintptr_t i, n = vec_nelem(v);   // sqrt(sum of squares); abs of a
  ai_flo_t s = 0;                                      // complex elem is its 2-vector modulus; ai_C sums 2n floats
  if (v->type == ai_C) { ai_flo_t *fp = vec_data(v); for (i = 0; i < 2*n; i++) s += fp[i] * fp[i]; }
  else for (i = 0; i < n; i++) { ai_flo_t e = vec_get_flo(v, i); s += e * e; }
  Have(box_req); emit_flo(ai_sqrt(s)); return Sp[0] = _res, Ip++, Continue(); }
 if (mapp(a)) {                                       // table: its key count (so (int (abs t)) == (len t))
  Have(box_req); emit_int((intptr_t) map_len(a)); return Sp[0] = _res, Ip++, Continue(); }
 return Sp[0] = nil, Ip++, Continue(); }

// fill f64 array r with arg of each element of v (a ai_C packed or ai_Z/ai_R real
// array, same shape). &-free, but ai_noinline to keep lvm_carg's tail call clean.
static ai_noinline void carg_fill(struct ai_vec *r, struct ai_vec *v) {
 uintptr_t n = vec_nelem(v);
 ai_flo_t *rf = vec_data(r);
 if (v->type == ai_C) { ai_flo_t *fp = vec_data(v);
  for (uintptr_t p = 0; p < n; p++) rf[p] = ai_atan2(fp[2*p+1], fp[2*p]); }
 else for (uintptr_t p = 0; p < n; p++) rf[p] = ai_atan2(0, vec_get_flo(v, p)); }

// (arg z): phase angle atan2(im, re) as a float. On a real number this is 0 for
// non-negative and pi for negative; on a complex/real array, an f64 array of the
// per-element phase (so (arg (C 1 x)) = atan elementwise); on a non-number, nil.
lvm(lvm_carg) {
 word a = Sp[0], _res;
 if (Cp(a)) { ai_flo_t r = ai_atan2(cplx_im(a), cplx_re(a));
  Have(box_req); emit_flo(r); return Sp[0] = _res, Ip++, Continue(); }
 if (arrp(a)) {
  struct ai_vec *v = vec(a);
  if (v->type == ai_O) return Sp[0] = nil, Ip++, Continue();   // object array -> nil
  uintptr_t R = v->rank, n = 1; for (uintptr_t i = 0; i < R; i++) n *= v->shape[i];
  uintptr_t bytes = sizeof(struct ai_vec) + R * sizeof(word) + n * ai_T[ai_R];
  Have(b2w(bytes));
  v = vec(Sp[0]);                                           // re-read post-Have
  struct ai_vec *r = (struct ai_vec*) Hp; Hp += b2w(bytes);
  ini_vec(r, ai_R, R);
  for (uintptr_t i = 0; i < R; i++) r->shape[i] = v->shape[i];
  carg_fill(r, v);
  return Sp[0] = word(r), Ip++, Continue(); }
 if (isnum(a)) { ai_flo_t r = ai_atan2(0, toflo(a));
  Have(box_req); emit_flo(r); return Sp[0] = _res, Ip++, Continue(); }
 return Sp[0] = nil, Ip++, Continue(); }
