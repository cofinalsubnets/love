#include "ll.h"
// The build's version string (the git hash), generated into out/lib/ll_version.h by
// the Makefile and surfaced in the runtime as the `version-number` global (g_ini_0).
// Optional include so a standalone/unwired compile still builds; falls back to "unknown".
#if defined(__has_include) && __has_include("ll_version.h")
#include "ll_version.h"
#endif
#ifndef LL_VERSION
#define LL_VERSION "unknown"
#endif

// ============================================================================
// kernel-internal declarations (private; merged from former i.h)
// ============================================================================

#if UINTPTR_MAX == UINT64_MAX
#define Bits 64
typedef double g_flo_t;
#define g_sin   sin
#define g_cos   cos
#define g_atan2 atan2
#define g_sqrt  sqrt
#define g_exp   exp
#define g_log   log
#define g_pow   pow
#elif UINTPTR_MAX == UINT32_MAX
#define Bits 32
typedef float g_flo_t;
#define g_sin   sinf
#define g_cos   cosf
#define g_atan2 atan2f
#define g_sqrt  sqrtf
#define g_exp   expf
#define g_log   logf
#define g_pow   powf
#endif

#if __STDC_HOSTED__
#include <math.h>
#else
g_flo_t g_sin(g_flo_t), g_cos(g_flo_t),
        g_atan2(g_flo_t, g_flo_t), g_sqrt(g_flo_t), g_exp(g_flo_t),
        g_log(g_flo_t), g_pow(g_flo_t, g_flo_t);
#endif

#define Bytes (Bits>>3)
_Static_assert(Bytes == sizeof(uintptr_t), "word size sanity check");

#include <stdarg.h>
_Static_assert(sizeof(union u) == sizeof(intptr_t), "cell size equals word size");
_Static_assert(-1 >> 1 == -1, "sign extended shift");
// nilp: structural test for the nil word (the only false scalar). Distinct from
// g_nilp below (the language falsy predicate, which also counts an all-zero tuple);
// the ll `nilp` nif maps to g_nilp, not this macro.
#define nilp(_) (word(_)==nil)
#define AB(o) A(B(o))
#define AA(o) A(A(o))
#define BA(o) B(A(o))
#define BB(o) B(B(o))
#define ptr(_) ((word*)(_))
#define datp(_) in_data(cell(_)->ap)
#define avec(g, y, ...) (MM(g,&(y)),(__VA_ARGS__),UM(g))
#define MM(g,r) ((g_core_of(g)->root=&((struct g_r){(word*)(r),g_core_of(g)->root})))
#define UM(g) (g_core_of(g)->root=g_core_of(g)->root->n)


#if UINTPTR_MAX > 0xffffffffu
#define mix ((uintptr_t) 0x9e3779b97f4a7c15) // round(2^64 / phi)
#else
#define mix ((uintptr_t) 0x9e3779b9) // round(2^32 / phi)
#endif

#define typ(_) g_typ(cell(_))

#if g_tco
#define g_status_yield g_status_ok
#else
#define g_status_yield g_status_eof
#endif
#define str_type_width (Width(struct g_str))
#define op1(nom, i, x) g_vm(nom) { Sp[0] = (x); Ip += i; return Continue(); }
#define op11(nom, x) op1(nom, 1, x)

#define pop1 g_pop1

// One word per element: every integer width folds to Z (intptr_t), every float
// width to R (g_flo_t), and C is the rank-0 complex scalar (two g_flo_t). Ordered
// Z < R < C so `>= g_R` is the float-domain test and C is the widest *numeric* tier.
// arr/arrl reject ty == C, so C never appears as a rank>=1 array element -- complex
// only ever shows up as a rank-0 scalar (Cp), handled by explicit cplx branches.
// O (object) is the odd tier out: its slots hold live ll words (any value --
// fixnum, bignum, box, complex, string, pair...), so it is the ONE tuple type the
// copying GC must trace element-by-element (evac_tuple). It sits outside the numeric
// order; the typed fast lanes gate on `type <= g_C`, the arith lane on `type == g_O`
// (g_vm_obin), so O elements always route through the promoting scalar dispatch --
// that is what makes a bignum array add/multiply exactly instead of wrapping.
enum g_tuple_type { g_Z, g_R, g_C, g_O, };
// Elementwise dyadic opcodes for g_vm_vbin (kernel/arr.c). The five arith codes
// match the arith slow handlers; the five compare codes (>= VOP_LT) produce a
// 0/1 bool array. VOP_EQ is `=` over arrays (whole-array eq is `(aall (= a b))`).
// VOP_QUOT is `/` (true division: float when a element divides inexactly);
// VOP_FQUOT is `//` (truncating integer division). Both stay in the arith group
// (< VOP_LT) so `op >= VOP_LT` still selects the compare codes.
enum vop { VOP_ADD, VOP_SUB, VOP_MUL, VOP_QUOT, VOP_REM, VOP_FQUOT,
           VOP_LT, VOP_LE, VOP_GT, VOP_GE, VOP_EQ, };
struct g_atom *intern_checked(struct g*, struct g_str*);
g_vm_t g_vm_kcall,
 g_vm_two, g_vm_tuple, g_vm_sym, g_vm_str, g_vm_big, // data sentinels (enum q order); apply dispatches through g_apply_mx
 g_vm_putn, g_vm_info,    g_vm_clock,
 g_vm_nilp,  g_vm_putc, g_vm_nom, g_vm_intern, g_vm_twop,
 g_vm_pin, g_vm_get, g_vm_fputx, g_vm_buf, g_vm_bufnew, g_vm_bcopy,
 g_vm_fixp,  g_vm_symp,   g_vm_strp,   g_vm_mapp, g_vm_band,   g_vm_bor,  g_vm_flo,  g_vm_flop,
 g_vm_sin, g_vm_cos, g_vm_log, g_vm_pow,   // sqrt/exp/tan/atan/atan2 are derived (numeral/complex forms), not nifs
 // Step 7 -- complex (kernel/cplx.c). g_vm_cplx_bin (declared apart, below) is
 // the arithmetic lane the scalar arith slow paths divert into.
 g_vm_cplx, g_vm_Cp, g_vm_re, g_vm_im, g_vm_conj, g_vm_abs, g_vm_carg,
 g_vm_bxor,  g_vm_bsr,    g_vm_bsl,    g_vm_ssub,
 g_vm_scat,   g_vm_cons,   g_vm_car,  g_vm_cdr,    g_vm_puts,
 g_vm_getc,  g_vm_string, g_vm_lt,     g_vm_le,   g_vm_eq,     g_vm_same, g_vm_gt,  g_vm_ge,
 g_vm_put, g_vm_pull, g_vm_hashd,   g_vm_hnew,   g_vm_hashk,  g_vm_hashof,
 g_vm_unc, g_vm_poke2, g_vm_peek2,
 g_vm_seek,  g_vm_trim,   g_vm_lam,   g_vm_add,
 g_vm_sub,   g_vm_mul,    g_vm_quot,   g_vm_fquot, g_vm_rem,  g_vm_arg,
 g_vm_bmul_start, g_vm_bmul,   // resumable (yieldable) bignum multiply
 g_vm_quote, g_vm_freev,  g_vm_eval,   g_vm_cond, g_vm_jump,   g_vm_defglob,
 g_vm_ap,    g_vm_tap,    g_vm_apn,    g_vm_tapn, g_vm_ret,
 g_vm_argap, g_vm_quoteap, g_vm_argtap,
 g_vm_arg0, g_vm_arg1, g_vm_arg2, g_vm_arg3,
 g_vm_quo0, g_vm_quo1, g_vm_quo2, g_vm_quo3, g_vm_quom1, g_vm_quom2,
 g_vm_callk, g_vm_yield_sw, g_vm_yield_nif, g_vm_task_exit, g_vm_spawn, g_vm_wait,
 g_vm_sleep, g_vm_donep, g_vm_kill, g_vm_key,
 g_vm_fgetc, g_vm_fungetc, g_vm_feof, g_vm_fputc, g_vm_fputs, g_vm_fflush,
 g_vm_fputn, g_vm_fread, g_vm_dot,
 // Step 5a -- typed multi-rank arrays (kernel/arr.c). g_vm_vbin is the shared
 // elementwise/broadcast engine the arith/compare slow lanes divert into.
 g_vm_arr, g_vm_arrl, g_vm_arank, g_vm_alen, g_vm_ashape, g_vm_atype,
 g_vm_asum, g_vm_aprod, g_vm_amax, g_vm_amin, g_vm_aall,
 g_vm_tupp, g_vm_bigp, g_vm_boxp, g_vm_arrp, g_vm_intf, g_vm_lamp;
// Carry extra operands, so (like g_vm_gc) they are declared apart from the
// plain g_vm_t list, which fixes the 4-argument handler signature. g_vm_vbin
// is the elementwise/broadcast dyadic engine (vop selects the op); g_vm_vmap1
// applies a monadic math fn elementwise to an array (e.g. (sin arr)); g_vm_vmap2
// is the dyadic analogue with broadcasting (e.g. (pow arr arr), (atan2 ...)).
g_vm(g_vm_vbin, int);
g_vm(g_vm_vmap1, g_flo_t (*)(g_flo_t));
g_vm(g_vm_vmap2, g_flo_t (*)(g_flo_t, g_flo_t));
// Complex arithmetic lane (kernel/cplx.c): the scalar arith slow paths divert
// here when either operand is complex; vop selects add/sub/mul/quot (rem -> nil).
g_vm(g_vm_cplx_bin, int);
// Complex-array elementwise lane (g_C): g_vm_vbin diverts here when an operand is
// a packed (re,im) g_C array (or a complex scalar paired with an array). Same
// numpy broadcast as vbin, complex domain; `=` -> mask, ordering/% -> nil.
g_vm(g_vm_cbin, int);
// Object-array elementwise lane (g_O): the broadcast engine g_vm_vbin diverts
// here when an operand is a g_O array, so each element op runs the promoting
// scalar dispatch (exact bignum results) instead of the typed raw-C lanes.
g_vm(g_vm_obin, int);
// data-kind recovery (datp/typ). Included here, after the self-quote sentinels
// above, because a frontend's override (e.g. wasm/inc/data.h) resolves kinds
// by comparing an ap against g_vm_two..g_vm_str directly.
#include <data.h>
char const *g_nif_name(intptr_t);
#define tuple(_) ((struct g_tuple*)(_))
#define fixp oddp
#define sym(_) ((struct g_atom*)(_))
static g_inline bool symp(word _) { return lamp(_) && cell(_)->ap == g_vm_sym; }
static g_inline bool tupp(word _) { return lamp(_) && cell(_)->ap == g_vm_tuple; }
static g_inline bool strp(word _) { return lamp(_) && cell(_)->ap == g_vm_str; }
// Mutable flat byte string. NOT a data kind: its head word is the
// behaves-as-0 g_vm_buf (like g_vm_port_io for ports), so the GC walks a buf
// as a plain length-2 thread -- [g_vm_buf, backing g_str, terminator] -- and
// the generic thread scan forwards the embedded string pointer for free; no
// bespoke evac/copy rule, and the data-sentinel mechanism stays reserved for
// kinds that need one. The bytes live in an ordinary g_str we mutate in place
// (cf. the `to` output port). Earned by the build tools that back-patch a
// binary image in place. Recognized by ap, like iop() for ports.
struct g_buf { g_vm_t *ap; struct g_str *str; };
static g_inline bool bufp(word _) { return lamp(_) && cell(_)->ap == g_vm_buf; }
// A map is a lookup-lambda with stable identity across growth, like the hash it
// replaces (whose struct stayed put while its bucket array reallocated). Two
// threads: a fixed 2-word HEADER [g_vm_map_lookup, backing, <tag>] that callers
// hold, and a BACKING [g_vm_map_data, putfix(len), putfix(cap), k0,v0, … , <tag>]
// it points at -- open-addressed, linear-probed, cap a power of two. Growth
// allocates a new backing and swaps header[1]; the header never moves, so an
// aliased reference (ev's scopes) sees later inserts. Both are plain threads:
// len/cap are fixnums and keys/vals ll words, so evac_thd traces them with no
// bespoke GC, like g_buf. Empty slots hold MAP_GAP, a unique word-aligned
// out-of-pool address gcp leaves untouched, never a legal key and never read as
// a terminator. (m k) looks k up (nil if absent) through g_vm_map_lookup.
static g_vm_t g_vm_map_lookup, g_vm_map_data;
static g_inline bool mapp(word _) { return lamp(_) && cell(_)->ap == g_vm_map_lookup; }
static const word g_map_gap_cell = 0;
#define MAP_GAP ((word) &g_map_gap_cell)
#define MAP_MIN_CAP 4
static g_inline word map_back(word m) { return cell(m)[1].x; }
static g_inline word *map_slots(word m) { return &cell(map_back(m))[3].x; }
static g_inline uintptr_t map_len(word m) { return getfix(cell(map_back(m))[1].x); }
static g_inline uintptr_t map_cap(word m) { return getfix(cell(map_back(m))[2].x); }
word g_mapget(struct g*, word, word, word);
static struct g *g_mapput(struct g*), *map_new(struct g*);
static g_inline struct g_str *buf_str(word x) { return ((struct g_buf*) x)->str; }
// the byte ops read from a string or a buf; both resolve to a g_str of bytes.
static g_inline struct g_str *bytes_of(word x) { return bufp(x) ? buf_str(x) : str(x); }
// Arbitrary-precision integer (Step 6). Own data-sentinel kind KBig: a flat,
// GC-trivial object (raw limbs, no embedded ll pointers) the copying GC moves
// by memcpy. A generic thread scan can't hold inline limb words (a limb that's
// even-and-in-pool would be spuriously forwarded, one matching G_THD_TAG would
// truncate the object), so a flat bignum needs its own copy/evac rule -- like
// KString strings -- which is exactly what the sentinel buys. slen = signed limb
// count (negative => negative value); |slen| 32-bit limbs little-endian
// (limb[0] least significant), top limb nonzero (normalized). Zero is never a
// bignum (it demotes to the fixnum nil), so slen is never 0 and the sign is
// unambiguous. Canonical demotion keeps the tiers disjoint: a value in fixnum
// range is a fixnum, one in intptr_t range a wide-int box, only wider values a
// bignum -- so fixp/boxp/bigp are mutually exclusive and =/eqv stay well defined.
struct g_big { g_vm_t *ap; intptr_t slen; uint32_t limb[]; };
static g_inline bool bigp(word _) { return lamp(_) && cell(_)->ap == g_vm_big; }
static g_inline struct g_big *ini_big(struct g_big *b, intptr_t slen) {
 return b->ap = g_vm_big, b->slen = slen, b; }
uintptr_t g_big_bytes(struct g_big*);
// Canonicalize a magnitude (limb[0..n), sign neg) into the smallest tier:
// fixnum, else wide-int box, else bignum; bumps *hp when it boxes/bignums. One
// sink shared by the reader and the arithmetic slow paths.
word g_big_canon(g_word **hp, uint32_t const *limb, int n, bool neg);
g_flo_t g_big_to_flo(word);                 // bignum -> double (used by TOFLO)
intptr_t g_big_low(word);                   // bignum value mod 2^W (low machine word)
int g_big_cmp(word, word);                  // -1/0/1 over two integer operands
struct g *g_big_binop(struct g*, int vop);  // VOP_ADD..VOP_REM, packed; pops one operand
struct g *g_big_quot_true(struct g*);       // `/` bignum lane: exact quotient when b | a, else a float box
struct g *g_big_dec(struct g*);             // sp[0] bignum -> decimal string
struct g *g_big_read_dec(struct g*);        // sp[0] [+-]?digits token -> canonical value

static g_inline bool flop(word _) {
  return tupp(_) && tuple(_)->rank == 0 && tuple(_)->type == g_R; }
// Wide-integer box: a rank-0 g_Z scalar tuple. Arises only from
// transparent fixnum overflow (kernel/math.c); never holds a value that
// fits the fixnum tag (canonical demotion keeps box and fixnum ranges
// disjoint), so boxp and fixp never both hold for the same number.
static g_inline bool boxp(word _) {
  return tupp(_) && tuple(_)->rank == 0 && tuple(_)->type == g_Z; }
// A complex scalar: a rank-0 g_C tuple (two g_flo_t, re then im). Deliberately
// NOT folded into ISNUM -- the real-tower macros (TOFLO/TOINT) would misread its
// two-word payload, so the arith/eq paths handle complex via explicit Cp
// branches placed before the real lanes (decision: complex > float > int/bignum).
static g_inline bool Cp(word _) {
  return tupp(_) && tuple(_)->rank == 0 && tuple(_)->type == g_C; }
// A rank>=1 typed array (vs a rank-0 scalar box, which flop/boxp catch). The
// elementwise arith/compare lanes divert to g_vm_vbin when either operand arrp.
static g_inline bool arrp(word _) { return tupp(_) && tuple(_)->rank >= 1; }

// Max array rank (bounds the stack index/stride arrays in the broadcast loop).
#define G_VEC_MAXRANK 8
extern size_t const g_vt_[];                 // element byte size by g_tuple_type
// Element payload: laid out row-major just past the shape words.
static g_inline void *tuple_data(struct g_tuple *v) { return (void*) (v->shape + v->rank); }
// Total element count = product of the dimensions (1 for a rank-0 scalar box).
static g_inline uintptr_t tuple_nelem(struct g_tuple *v) {
 uintptr_t n = 1;
 for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 return n; }
static g_inline struct g_tuple *ini_tuple(struct g_tuple *v, enum g_tuple_type t, uintptr_t rank) {
 return v->ap = g_vm_tuple, v->type = t, v->rank = rank, v; }
// Read element i of v as a double / as an integer (sign-extending the narrow
// integer types; truncating a float toward zero for the int reader). The int
// reader is only used on integer-typed arrays in practice.
static g_inline g_flo_t tuple_get_flo(struct g_tuple *v, uintptr_t i) {
 void *p = tuple_data(v);
 return v->type == g_R ? ((g_flo_t*) p)[i] : (g_flo_t) ((intptr_t*) p)[i]; }
static g_inline intptr_t tuple_get_int(struct g_tuple *v, uintptr_t i) {
 void *p = tuple_data(v);
 return v->type == g_R ? (intptr_t) ((g_flo_t*) p)[i] : ((intptr_t*) p)[i]; }
// Write element i of v, converting to v's element kind.
static g_inline void tuple_put_int(struct g_tuple *v, uintptr_t i, intptr_t x) {
 void *p = tuple_data(v);
 if (v->type == g_R) ((g_flo_t*) p)[i] = (g_flo_t) x; else ((intptr_t*) p)[i] = x; }
static g_inline void tuple_put_flo(struct g_tuple *v, uintptr_t i, g_flo_t x) {
 void *p = tuple_data(v);
 if (v->type == g_R) ((g_flo_t*) p)[i] = x; else ((intptr_t*) p)[i] = (intptr_t) x; }
// Read/write element i of a g_O array as a raw tagged ll word (the GC traces
// these; see evac_tuple). No conversion -- the slot IS a value.
static g_inline word tuple_get_obj(struct g_tuple *v, uintptr_t i) {
 return ((word*) tuple_data(v))[i]; }
static g_inline void tuple_put_obj(struct g_tuple *v, uintptr_t i, word x) {
 ((word*) tuple_data(v))[i] = x; }

// Language falsy predicate: a value is falsy iff its magnitude (L2 norm) is zero.
// For a scalar that is just "== 0": nil/0, a boxed 0.0, a zero wide-int box. For a
// tuple it is the Euclidean norm being zero -- which, since a sum of squares is zero
// iff every term is, g_all_zero tests EXACTLY by scanning for a non-zero element
// (a boxed 0.0/array, an empty tuple vacuously; a complex via both components; an
// object array recursively per element). We scan rather than literally call abs()
// because this is the hot `?`/g_vm_cond path: the scan short-circuits on the first
// truthy element and is exact, whereas sqrt(Σx²) is slower and overflows to inf on
// a large array -- reporting a non-zero array as falsy. Same predicate, no float risk.
bool g_all_zero(struct g_tuple*);
// Truthiness: x is false iff (= 0 (len x)) -- i.e. NEGATIVE-OR-ZERO is false, POSITIVE
// is true. For an ordered scalar (fixnum/float/wide-int box/bignum/complex) that means
// <= 0 by the total order (complex: re first, then im). Containers are false iff empty;
// an array (rank>=1) is false iff its L2 norm is zero (all elements zero MAGNITUDE, so a
// negative element keeps it true -- arrays have no single sign). Each is a cheap test with
// NO magnitude walk: the empty singletons (nil = the 0 word; EmptyString), an empty table,
// a negative fixnum/bignum, or a tuple via g_all_zero (rank-0 scalar <=0, else norm-zero
// scan that short-circuits). Pair, symbol, non-empty string/table/array, buf, fn, port are
// truthy without traversal. Lockstep with g_pin (g_vm_pin): same zero-conditions.
// a symbol's # (pin) value, shared by g_mag (#) and g_nilp (!). THE empty symbol
// (EMPTY_SYM, prints as ()) has no name -> 0 -> falsy. Every other present symbol
// (interned, named-uninterned, anonymous nom) floors to >=1 -> truthy.
static g_inline intptr_t pin_sym(word x) {
  if (x == EMPTY_SYM) return 0;                        // the empty symbol: falsy (prints as ())
  struct g_atom *s = (struct g_atom*) x;
  intptr_t nl = !s->nom ? 0
    : strp(word(s->nom)) ? (intptr_t) len(s->nom)
    : ((struct g_atom*) s->nom)->nom ? (intptr_t) len(((struct g_atom*) s->nom)->nom) : 0;
  return nl ? nl : 1; }                                // present symbol -> truthy
static g_inline bool g_nilp(word x) {
  if (x == nil || x == EmptyString) return true;
  if (fixp(x)) return getfix(x) < 0;                 // 0 is nil (caught above); negatives false
  if (mapp(x)) return map_len(x) == 0;
  if (bigp(x)) return ((struct g_big*) x)->slen < 0; // a negative bignum is false
  if (symp(x)) return pin_sym(x) == 0;               // empty/anonymous symbol name -> nil (pin lockstep)
  return tupp(x) && g_all_zero(tuple(x)); }          // boxed scalar <=0 / array norm 0

// Truncation toward zero / float remainder. Pure, freestanding-safe (no libm):
// 1/0 lowers to an FPU divide that yields +-inf or NaN per IEEE, and inf*0=NaN
// propagates through g_fmod's subtraction. Shared by the scalar arith slow
// paths (math.c) and the elementwise array lane (arr.c).
static g_inline g_flo_t g_trunc(g_flo_t x) {
 if (x != x) return x;
 g_flo_t m = x < 0 ? -x : x;
 if (m > (g_flo_t) 9.22e18) return x;
 return (g_flo_t) (int64_t) x; }
static g_inline g_flo_t g_fmod(g_flo_t a, g_flo_t b) {
 return a - g_trunc(a / b) * b; }

// --- numeric tower helpers (shared by math.c, arr.c, hash.c) ----------------
// Numeric scalar = a fixnum, a boxed float (flop), or a boxed wide int (boxp).
#define ISNUM(x) (fixp(x) || flop(x) || boxp(x) || bigp(x))
// Integer value of a fixnum-or-box operand (callers must exclude floats AND
// bignums -- a bignum doesn't fit an intptr_t; integer lanes guard on !bigp).
#define TOINT(x) (fixp(x) ? (intptr_t) getfix(x) : box_get(x))
// Double value of any numeric operand (a bignum widens via g_big_to_flo).
#define TOFLO(x) (fixp(x) ? (g_flo_t) getfix(x) : flop(x) ? flo_get(x) : boxp(x) ? (g_flo_t) box_get(x) : g_big_to_flo(x))
// Heap words for one scalar box. The float box (g_flo_t) and the wide-int box
// (intptr_t) are both one pointer-width word, so one reservation fits.
#define BOX_REQ (Width(struct g_tuple) + Width(intptr_t))
// Heap words for one complex box: the (re, im) payload is two g_flo_t words.
#define CPLX_REQ (Width(struct g_tuple) + 2 * Width(g_flo_t))
// The tagged fixnum range: putfix spends one bit, so |value| <= 2^(Bits-2).
#define FIX_MIN (INTPTR_MIN >> 1)
#define FIX_MAX (INTPTR_MAX >> 1)
// Emit an integer result R into `_res`: demote to a fixnum when it fits the
// tag, else box it as a rank-0 g_Z scalar (bumping Hp). The caller must
// already hold Have(BOX_REQ). Takes no &local, so a handler that uses it keeps
// its trailing tail call.
#define EMIT_INT(R) do { intptr_t _r = (R); \
 if (_r >= FIX_MIN && _r <= FIX_MAX) _res = putfix(_r); \
 else { struct g_tuple *_v = ini_scalar((struct g_tuple*) Hp, g_Z); \
        Hp += BOX_REQ; box_put(_v->shape, _r); _res = word(_v); } } while (0)
// Emit a double result R into `_res` as a rank-0 g_R box. Same Have(BOX_REQ)
// precondition and TCO discipline as EMIT_INT.
#define EMIT_FLO(R) do { struct g_tuple *_v = ini_scalar((struct g_tuple*) Hp, g_R); \
 Hp += BOX_REQ; flo_put(_v->shape, (R)); _res = word(_v); } while (0)

// Step 8 -- RNG (kernel/rng.c). State is a rank-1 i64 tuple of length 4 (256 bits,
// xoshiro256++). It rides the existing tuple machinery (no data sentinel) but its
// payload is treated as raw bytes -- moved by memcpy, never via tuple_get/put_int,
// which would truncate the 64-bit limbs to intptr_t on 32-bit ports. The fixed
// 8-byte limbs make a seed reproduce the same sequence on every target.
#define RNG_STATE_LEN 4
#define RNG_PAYLOAD_BYTES (RNG_STATE_LEN * 8)
#define RNG_VEC_BYTES (sizeof(struct g_tuple) + sizeof(uintptr_t) + RNG_PAYLOAD_BYTES)
#define RNG_VEC_REQ (b2w(RNG_VEC_BYTES))
// State element kind: pick whichever kind is 8 bytes wide so g_tuple_bytes (GC) sees
// the full 256-bit payload -- Z (one word) on 64-bit, C (two words) on 32-bit.
#define RNG_VT (Bytes == 4 ? g_C : g_Z)
void g_rng_seed(struct g_tuple*, uint64_t);   // shape an i64 state tuple + seed it (SplitMix64)
g_vm_t g_vm_rng_seed, g_vm_rng_get, g_vm_rng_set,
       g_vm_rand, g_vm_randf, g_vm_rand_next, g_vm_randf_next;
int memcmp(void const*, void const*, size_t);
void *malloc(size_t), free(void*),
 *memcpy(void*restrict, void const*restrict, size_t),
 *memmove(void*restrict, void const*restrict, size_t),
 *memset(void*, int, size_t);
long strtol(char const*restrict, char**restrict, int);
size_t strlen(char const*);
double strtod(char const *restrict, char **restrict);

// Boxed scalar float access. The payload occupies one uintptr_t-wide
// shape[] slot (g_flo_t is f64 on 64-bit ports, f32 on 32-bit -- always
// the width of uintptr_t). Pun through a union rather than
// memcpy(&local, ...): both are strict-aliasing clean, but the memcpy form
// takes the address of a stack local, which clang -Os treats as an escape
// and then refuses to sibling-call the trailing Continue() out of any VM
// handler that inlines this -- silently breaking threaded dispatch (a
// `call`+`ret` where there must be a `jmp`; see tools/vmret.l). GCC proves
// the local dead and TCOs either way; the union keeps the value in a
// register so clang does too.
_Static_assert(sizeof(g_flo_t) == sizeof(uintptr_t), "float box assumes g_flo_t is pointer-width");
typedef union { uintptr_t u; g_flo_t d; } g_flo_pun;
static g_inline g_flo_t flo_get(word x) {
 return ((g_flo_pun){ .u = tuple(x)->shape[0] }).d; }
static g_inline void flo_put(void *p, g_flo_t v) {
 *(uintptr_t*) p = ((g_flo_pun){ .d = v }).u; }

// Boxed complex access: re in shape[0], im in shape[1] (rank-0, so tuple_data ==
// shape). Same union-pun discipline as flo_get/flo_put so an inlining VM handler
// keeps its tail call. cplx_put writes both components of an already-shaped box.
static g_inline g_flo_t cplx_re(word x) {
 return ((g_flo_pun){ .u = tuple(x)->shape[0] }).d; }
static g_inline g_flo_t cplx_im(word x) {
 return ((g_flo_pun){ .u = tuple(x)->shape[1] }).d; }
// |z| of a boxed complex scalar: the L2 norm of (re, im).
static g_inline g_flo_t cplx_mod(word x) {
 g_flo_t re = cplx_re(x), im = cplx_im(x);
 return g_sqrt(re * re + im * im); }
// Total-order non-positive test for a complex scalar (re first, then im): the
// falsiness oracle for `~(re im)` -- false iff it sorts <= 0+0i (re < 0, or re == 0
// and im <= 0). Lockstep with g_nilp/g_pin: negative-or-zero is FALSE, positive TRUE.
static g_inline bool cplx_nonpos(word x) {
 g_flo_t re = cplx_re(x); return re < 0 || (re == 0 && cplx_im(x) <= 0); }
static g_inline void cplx_put(struct g_tuple *v, g_flo_t re, g_flo_t im) {
 v->shape[0] = ((g_flo_pun){ .d = re }).u;
 v->shape[1] = ((g_flo_pun){ .d = im }).u; }

// Boxed wide-int access. The payload is one pointer-width signed integer
// in shape[0]; unlike the float box it needs no bit reinterpretation --
// it is already an integer, only its signedness differs from the
// uintptr_t slot. Neither helper takes the address of a stack local, so a
// VM handler that inlines them keeps its trailing tail call (see the
// flo_get/flo_put note above and tools/vmret.l).
static g_inline intptr_t box_get(word x) { return (intptr_t) tuple(x)->shape[0]; }
static g_inline void box_put(void *p, intptr_t v) { *(uintptr_t*) p = (uintptr_t) v; }

// equality comparisons inline the fast identity check
g_noinline bool eqv(struct g*, word, word); // this is for checking equality of non-identical values
static g_inline bool eql(struct g *g, word a, word b) { return a == b || eqv(g, a, b); }

// Threads -- and every other variable-length heap object the GC copies by
// scanning (continuations, task nodes, env scopes, ports) -- end with a single
// tag word: the object's own head pointer with bit 1 set (G_THD_TAG), saving a
// word over a separate NULL marker + head. Small ints are odd and ll heap
// pointers are word-aligned, so the only other word that can carry (x & 3) == 2
// is an embedded *external* pointer (host data/function) that happens to land
// on a 2-byte boundary. So the terminator test is not just the tag bits: the
// payload must also point back into [lo, hi), the pool the object lives in --
// which a stray external pointer never does.
#define G_THD_TAG 2
static g_inline bool tagp(word x, word const *lo, word const *hi) {
 word const *p = (word const*) (x & ~(word) 3);
 return (x & 3) == G_THD_TAG && p >= lo && p < hi; }
static g_inline union u *tagthd(union u *h, uintptr_t len) {
  return h[len].x = word(h) | G_THD_TAG, h; }
#define topof(g) ((word*)g+g->len)
static g_inline struct g_tag { union u *head; union u end[]; } *ttag(struct g*g, union u *k) {
 word *lo = ptr(g), *hi = topof(g);
 while (!tagp(k->x, lo, hi)) k++;
 return (struct g_tag*) k; }
static g_inline union u *tag_head(struct g_tag *t) {
 return cell(word(t->head) & ~(word) 3); }

static g_inline union u *clip(struct g *g, union u *k) {
 return tagthd(k, cell(ttag(g, k)) - k); }



static g_inline struct g_atom *ini_anon(struct g_atom *y, uintptr_t code) {
 return y->ap = g_vm_sym, y->nom = 0, y->code = code, y; }

static g_inline struct g_atom *ini_sym(struct g_atom *y, struct g_str *nom, uintptr_t code) {
 return y->ap = g_vm_sym, y->nom = nom, y->code = code, y->l = y->r = 0, y; }

// named but *uninterned* symbol: nom holds the interned SYMBOL it is named after
// (not a string). That both tags it as uninterned -- the printer renders it
// ,<name>@<addr> and the GC keeps it out of the to-space symbol tree -- and lets
// it skip the l/r subtree slots only interned syms (string nom) carry, exactly
// like an anonymous sym (nom 0). So it is also a Width-2 allocation.
static g_inline struct g_atom *ini_usym(struct g_atom *y, struct g_atom *nom, uintptr_t code) {
 return y->ap = g_vm_sym, y->nom = (struct g_str*) nom, y->code = code, y; }

static g_inline struct g_str *ini_str(struct g_str *s, uintptr_t len) {
 return s->ap = g_vm_str, s->len = len, s; }

// The unique empty string and empty (anonymous) symbol. Both live in the data
// segment, so the Cheney forwarder leaves any pointer to them untouched (gcp's
// out-of-pool short-circuit, like g_stdin/stdout/stderr) -- immortal, never copied
// or freed, so `const` is safe. Strings are immutable, so a single empty string
// suffices and we NEVER heap-allocate a zero-length one (str0/scat/strin/reader and
// the `+` text lane all hand back g_str_empty). g_sym_empty is the additive identity
// for `+` on symbols (empty name -> contributes no bytes) and the canonical value of
// any empty-named symbol concat. Predicates read `ap`, so these behave as a normal
// text/sym value; the FAM `bytes[]` is simply absent (len 0).
// External linkage (declared in ll.h with the EmptyString/EMPTY_SYM macros) so the
// frontends can return them too (e.g. host_run's empty-output capture).
const struct g_str g_str_empty = { .ap = g_vm_str, .len = 0 };
const struct g_atom g_sym_empty = { .ap = g_vm_sym, .code = 0, .nom = 0, .l = 0, .r = 0 };

static g_inline struct g_tuple *ini_scalar(struct g_tuple *v, enum g_tuple_type t) {
 return v->ap = g_vm_tuple, v->type = t, v->rank = 0, v; }


static g_inline uintptr_t rot(uintptr_t x) {
  int const s = sizeof(uintptr_t) * 4; // shift bits = word bits / 2 = sizeof(word) * 4
  return (x << s) | (x >> s); }

extern struct g_port_vt const synth[];

struct ti { struct g_io io; char const *t; word i; } ; // C string input
static g_inline void *off_pool(struct g *g) {
 return g == g->pool ? (word*) g->pool + g->len : (word*) g->pool; }
static g_inline struct g *pushq(struct g*g) { return intern(g_strof(g, "\\")); }
static g_inline struct g *push0(struct g*g) { return g_push(g, 1, nil); }
static g_inline size_t llen(word l) {
 size_t n = 0;
 while (twop(l)) n++, l = B(l);
 return n; }
static g_inline struct g*g_pop(struct g*g, uintptr_t n) {
 return g_core_of(g)->sp += n, g; }

// ============================================================================
// macros (hoisted from all merged units; see section banners below)
// ============================================================================






#define MIN(p,q) ((p)<(q)?(p):(q))
#define MAX(p,q) ((p)>(q)?(p):(q))




#define LIMB_BITS 32
#define LIMB_BASE ((uint64_t) 1 << LIMB_BITS)

#define YIELD_INTERVAL 64
#define YieldCheck() \
  if (g->tasks->m != g->tasks && ++g->yield_ctr >= YIELD_INTERVAL) \
    return Ap(g_vm_yield_sw, g)
#define ARGN(nom, i) g_vm(nom) { Have1(); Sp[-1] = Sp[i]; Sp -= 1; Ip += 1; return Continue(); }
#define QUON(nom, v) g_vm(nom) { Have1(); Sp -= 1; Sp[0] = putfix(v); Ip += 1; return Continue(); }

#define Ana(n, ...) struct g *n(struct g *g, struct env **c, intptr_t x, ##__VA_ARGS__)
#define Cata(n, ...) struct g *n(struct g *g, struct env **c, ##__VA_ARGS__)
#define incl(e, n) ((e)->len += ((n)<<1))
#define Kp (g->ip)
#define C1(n, ...) static Cata(n) { return __VA_ARGS__, pull(g, c); }
#define forget() (g_core_of(g)->root=(mm),g)

#define fs0(g) (g_core_of(g)->sp[0])
#if UINTPTR_MAX > 0xffffffffu
#define DTOA_INF    1e308
#define DTOA_SCI_HI 1e16
#define DTOA_SCI_LO 1e-4
#else
#define DTOA_INF    __FLT_MAX__
#define DTOA_SCI_HI 1e16f
#define DTOA_SCI_LO 1e-4f
#endif

#define S1(i) {{i}, {g_vm_ret0}}
#define S2(i) {{g_vm_cur},{.x=putfix(2)},{i}, {g_vm_ret0}}
#define S3(i) {{g_vm_cur},{.x=putfix(3)},{i}, {g_vm_ret0}}
#define S5(i) {{g_vm_cur},{.x=putfix(5)},{i}, {g_vm_ret0}}
#define nifs(_) \
 _(nif_clock, "clock", S1(g_vm_clock)) _(nif_addr, "vminfo", S1(g_vm_info))\
 _(nif_add, "+", S2(g_vm_add)) _(nif_sub, "-", S2(g_vm_sub)) _(nif_mul, "*", S2(g_vm_mul))\
 _(nif_quot, "/", S2(g_vm_quot)) _(nif_fquot, "//", S2(g_vm_fquot)) _(nif_rem, "mod", S2(g_vm_rem)) \
 _(nif_lt, "<", S2(g_vm_lt))  _(nif_le, "<=", S2(g_vm_le)) _(nif_eq, "=", S2(g_vm_eq))\
 _(nif_ge, ">=", S2(g_vm_ge))  _(nif_gt, ">", S2(g_vm_gt)) \
 _(nif_same, "idp", S2(g_vm_same)) \
 _(nif_bsl, "<<", S2(g_vm_bsl)) _(nif_bsr, ">>", S2(g_vm_bsr))\
 _(nif_band, "&", S2(g_vm_band)) _(nif_bor, "|", S2(g_vm_bor)) _(nif_bxor, "^", S2(g_vm_bxor))\
 _(nif_cons, "X", S2(g_vm_cons)) _(nif_car, "A", S1(g_vm_car)) _(nif_cdr, "B", S1(g_vm_cdr)) \
 _(nif_ssub, "ssub", S3(g_vm_ssub)) _(nif_scat, "scat", S2(g_vm_scat)) \
 _(nif_fread, "fread", S2(g_vm_fread))\
 _(nif_string, "string", S1(g_vm_string))\
 _(nif_intern, "intern", S1(g_vm_intern)) _(nif_nom, "nom", S1(g_vm_nom))\
 _(nif_lam, "lam", S1(g_vm_lam))\
 _(nif_peek, "peekl", S2(g_vm_peek2)) _(nif_poke, "pinl", S3(g_vm_poke2)) _(nif_trim, "trim", S1(g_vm_trim))\
 _(nif_seek, "seekl", S2(g_vm_seek)) _(nif_pin, "hash", S1(g_vm_pin)) _(nif_get, "peek", S3(g_vm_get))\
 _(nif_put, "pin", S3(g_vm_put)) _(nif_pull, "pull", S3(g_vm_pull)) _(nif_hnew, "mapn", S1(g_vm_hnew)) _(nif_hashk, "mapk", S1(g_vm_hashk))\
 _(nif_hash, "digest", S1(g_vm_hashof))\
 _(nif_bufnew, "bufnew", S1(g_vm_bufnew)) _(nif_bcopy, "bcopy", S5(g_vm_bcopy))\
 _(nif_hashd, "mapd", S3(g_vm_hashd)) _(nif_twop, "twop", S1(g_vm_twop)) _(nif_strp, "strp", S1(g_vm_strp))\
 _(nif_flo, "flo", S1(g_vm_flo)) _(nif_flop, "flop", S1(g_vm_flop))\
 _(nif_sin, "sin", S1(g_vm_sin)) _(nif_cos, "cos", S1(g_vm_cos))\
 _(nif_log, "log", S1(g_vm_log)) _(nif_pow, "pow", S2(g_vm_pow))\
 _(nif_cplx, "com", S2(g_vm_cplx)) _(nif_Cp, "comp", S1(g_vm_Cp))\
 _(nif_re, "re", S1(g_vm_re)) _(nif_im, "im", S1(g_vm_im)) _(nif_conj, "conj", S1(g_vm_conj))\
 _(nif_abs, "abs", S1(g_vm_abs)) _(nif_arg, "arg", S1(g_vm_carg))\
 _(nif_arr, "arr", S2(g_vm_arr)) _(nif_arrl, "arrl", S3(g_vm_arrl))\
 _(nif_arank, "arank", S1(g_vm_arank))\
 _(nif_alen, "alen", S1(g_vm_alen)) _(nif_ashape, "ashape", S1(g_vm_ashape))\
 _(nif_atype, "atype", S1(g_vm_atype))\
 _(nif_asum, "asum", S1(g_vm_asum)) _(nif_aprod, "aprod", S1(g_vm_aprod))\
 _(nif_amax, "amax", S1(g_vm_amax)) _(nif_amin, "amin", S1(g_vm_amin))\
 _(nif_aall, "aall", S1(g_vm_aall))\
 _(nif_tupp, "tupp", S1(g_vm_tupp)) _(nif_bigp, "bigp", S1(g_vm_bigp)) _(nif_boxp, "boxp", S1(g_vm_boxp))\
 _(nif_arrp, "arrp", S1(g_vm_arrp)) _(nif_intf, "int", S1(g_vm_intf))\
 _(nif_symp, "symp", S1(g_vm_symp)) _(nif_mapp, "mapp", S1(g_vm_mapp)) _(nif_fixp, "fixp", S1(g_vm_fixp))\
 _(nif_lamp, "lamp", S1(g_vm_lamp))\
 _(nif_nilp, "nilp", S1(g_vm_nilp)) _(nif_ev, "ev", S1(g_vm_eval))\
 _(nif_callk, "call-cc", S1(g_vm_callk)) _(nif_yield, "yield", S1(g_vm_yield_nif)) \
 _(nif_spawn, "spawn", S2(g_vm_spawn)) _(nif_wait, "wait", S1(g_vm_wait)) \
 _(nif_sleep, "sleep", S1(g_vm_sleep)) _(nif_donep, "done?", S1(g_vm_donep)) \
 _(nif_kill, "kill", S1(g_vm_kill)) \
 _(nif_key, "key?", S1(g_vm_key)) \
 _(nif_fputn, "fputn", S3(g_vm_fputn))\
 _(nif_fputx, "fputx", S2(g_vm_fputx))\
 _(nif_fgetc, "fgetc", S1(g_vm_fgetc)) _(nif_fungetc, "fungetc", S2(g_vm_fungetc)) _(nif_feof, "feof", S1(g_vm_feof))\
 _(nif_fputc, "fputc", S2(g_vm_fputc)) _(nif_fputs, "fputs", S2(g_vm_fputs))  _(nif_fflush, "fflush", S1(g_vm_fflush))\
 _(nif_dot, "dot", S1(g_vm_dot))\
 _(nif_rng_seed, "rng-seed", S1(g_vm_rng_seed)) _(nif_rng_get, "rng-get", S1(g_vm_rng_get)) _(nif_rng_set, "rng-set", S1(g_vm_rng_set))\
 _(nif_rand, "rand", S1(g_vm_rand)) _(nif_randf, "randf", S1(g_vm_randf))\
 _(nif_rand_next, "rand-next", S1(g_vm_rand_next)) _(nif_randf_next, "randf-next", S1(g_vm_randf_next))
#define native_implemented_function(n, _, d) static union u const n[] = d;
#define insts(_) _(g_vm_unc) _(g_vm_freev) _(g_vm_ret) _(g_vm_ap) _(g_vm_tap) _(g_vm_apn) _(g_vm_tapn)\
  _(g_vm_jump) _(g_vm_cond) _(g_vm_arg) _(g_vm_quote) _(g_vm_defglob)\
  _(g_vm_argap) _(g_vm_quoteap) _(g_vm_argtap)\
  _(g_vm_arg0) _(g_vm_arg1) _(g_vm_arg2) _(g_vm_arg3)\
  _(g_vm_quo0) _(g_vm_quo1) _(g_vm_quo2) _(g_vm_quo3) _(g_vm_quom1) _(g_vm_quom2)
#define niff(b, n, _) {n, (intptr_t) b},
#define i_entry(i) {#i, (intptr_t) i},

// ============================================================================
// g
// ============================================================================
enum g_status g_fin(struct g *g) {
 enum g_status s = g_code_of(g);
 if ((g = g_core_of(g))) {
   for (struct g_fz *fz = g->fz; fz; fz->fn(fz->p), fz = fz->next); // run finalizers
   g->free(g, g->pool); }
 return s; }

struct g *g_defn(struct g*g, struct g_def const*defs, uintptr_t n) {
 for (g = g_push(g, 1, g_core_of(g)->dict); n--;
  g = g_mapput(intern(g_strof(g_push(g, 1, defs[n].x), defs[n].n))));
 g_core_of(g)->sp++;
 return g; }

nifs(native_implemented_function);

static g_vm(_g_vm_yield_c) { return Pack(g), g; }
static union u const yield_c[] = { {_g_vm_yield_c} };

// Default trap continuation. A throw enters it with the thrown status encoded
// into g (see gtrap2 below). The MORE bit is read control flow, not a scare:
// the thrower left [resume port sentinel] on the stack (the fread protocol),
// so deliver the port (more: incomplete) or the sentinel (eof) to the resume
// thread and keep running. A scare re-encodes and yields to C -- the same
// escape the old trap did. Define a global `trap` function to land throws in
// ll instead.
static g_vm(_g_vm_throw_c) {
 enum g_status s = g_code_of(g);
 g = g_core_of(g);
 if (s & g_status_more) {
  Ip = cell(Sp[0]);                                   // [resume port sentinel]
  Sp[2] = s == g_status_more ? Sp[1] : Sp[2];         // more -> port, eof -> sentinel
  Sp += 2;
  return Continue(); }
 return Pack(g), encode(g, s); }
static union u const throw_c[] = { {_g_vm_throw_c} };

// gtrap2/gtrap are defined after numap_drive (the trap call frame runs
// through its 3-arg twin); declared in ll.h.

static struct g_def const def1[] = { nifs(niff) insts(i_entry)};

// reverse-lookup a function value against the builtin table -> its source name,
// or NULL. Used by the printer to render nifs (e.g. `+`) by name.
char const *g_nif_name(intptr_t x) {
 for (uintptr_t i = 0; i < LEN(def1); i++) if (def1[i].x == x) return def1[i].n;
 return 0; }

static struct g *g_ini_0(struct g*g, uintptr_t len0, void *(*ma)(struct g*, size_t), void (*fr)(struct g*, void*)) {
 memset(g, 0, sizeof(struct g));
 g->len = len0, g->pool = (void*) g, g->malloc = ma, g->free = fr;
 g->hp = g->end, g->sp = (word*) g + len0, g->ip = (union u*) yield_c, g->t0 = g_clock();
 // dict + macro maps (lookup-lambdas) then the main task thread.
 if (g_ok(g = map_new(g)) && g_ok(g = map_new(g)) && g_ok(g = g_have(g, 6))) {
  union u *M = bump(g, 6);            // sp[0]=macro, sp[1]=dict (no GC since g_have)
  M[0].m = M;
  M[1].x = nil;   // sentinel; replaced on first yield
  M[2].x = nil;   // main pid
  M[3].x = nil;   // wake_at: nil means "always runnable"
  M[4].x = putfix(-1);  // wait_fd: -1 = not waiting on I/O (slot value -1, non-zero)
  g->tasks = tagthd(M, 5);
  // dict[nil] = macro (the macro table -- no separate field). Both are on the
  // stack; push the nil key so (sp2,sp1,sp0)=(dict,macro,nil) for g_mapput.
  g = g_push(g, 1, nil);
  g = g_mapput(g);                     // -> sp[0] = dict
  g->dict = g->sp[0];                  // henceforth GC-forwarded via the v0..end loop
  g = g_pop(g, 1);
  struct g_def def0[] = {
   {"dict", g->dict},
   {"in", (word) &g_stdin},
   {"out", (word) &g_stdout},
   {"err", (word) &g_stderr}, };
  g = g_defn(g, def0, LEN(def0));
  g = g_defn(g, def1, LEN(def1));
  // () (the empty symbol) is self-evaluating: dict[()] = ().
  g = g_push(g, 3, EMPTY_SYM, EMPTY_SYM, g->dict);
  g = g_mapput(g);
  g = g_pop(g, 1);
  // `version-number`: the build's git hash (ll_version.h), surfaced on init so the user
  // can read the running version. A non-fixnum global, harmlessly skipped by ev.l's pureset.
  if (g_ok(g = g_strof(g, LL_VERSION))) {
   struct g_def vd[] = {{"version-number", g_pop1(g)}};
   g = g_defn(g, vd, LEN(vd)); }
  // Pre-intern the dict keys for the C->lisp hooks so resolve_handler/gtrap2
  // can look them up without allocating. Idempotent with the prelude's bindings.
  if (g_ok(g = intern(g_strof(g, "num-ap")))) g->numap_sym = pop1(g);
  if (g_ok(g = intern(g_strof(g, "scomb"))))  g->scomb_sym = pop1(g);
  if (g_ok(g = intern(g_strof(g, "bcomb"))))  g->bcomb_sym = pop1(g);
  if (g_ok(g = intern(g_strof(g, "trap"))))   g->trap_sym = pop1(g);
  if (g_ok(g = intern(g_strof(g, "operators")))) g->operators_sym = pop1(g);
  // dict['operators]: the reader's operator table, char -> name | (name . arity).
  // Seeded with the 8 builtin sigil operators at arity 1; `~` and `,` stay
  // hardcoded digraphs. Lisp extends it with a plain pin (arity 1..7).
  { struct { char c; char const *n; } const ops[] = {
     {'\'', "\\"}, {'`', "qq"}, {'%', "map"}, {'#', "hash"},
     {'@', "tuple"}, {'$', "gsym"}, {'!', "nilp"}, {'.', "dot"} };
   g = map_new(g);                                  // sp[0] = the table
   for (uintptr_t i = 0; i < LEN(ops); i++) {
    g = intern(g_strof(g, ops[i].n));               // sp[0]=name sp[1]=table
    g = g_push(g, 1, putfix(ops[i].c));             // (key val map) for g_mapput
    g = g_mapput(g); }                              // -> sp[0]=table
   g = intern(g_strof(g, "operators"));             // sp[0]=key sp[1]=table
   g = g_push(g, 1, nil);
   if (g_ok(g)) {                                   // permute to (key val map)=(operators table dict)
    g->sp[0] = g->sp[1], g->sp[1] = g->sp[2], g->sp[2] = g->dict;
    g = g_pop(g_mapput(g), 1); } }
  // Eager-seed the global RNG stream so g->rng is always a valid state tuple (ll0
  // bootstrap included). The seed mixes the clock with the rotated pool address.
  if (g_ok(g = g_have(g, RNG_VEC_REQ))) {
   struct g_tuple *v = bump(g, RNG_VEC_REQ);
   g_rng_seed(v, (uint64_t) (g_clock() ^ rot((uintptr_t) g)));
   g->rng = word(v); } }
 return g; }

struct g *g_ini_m(void *(*ma)(struct g*, size_t), void (*fr)(struct g*, void*)) {
 uintptr_t const len0 = 1 << 10;
 struct g *g = ma(NULL, 2 * len0 * sizeof(word));
 return g == NULL ? encode(g, g_status_scare) : g_ini_0(g, len0, ma, fr); }

static void *g_no_malloc(struct g*g, uintptr_t n) { return NULL; }
static void g_no_free(struct g*g, void *p) { }
struct g *g_ini_s(void *mem, uintptr_t nbytes) {
 uintptr_t len0 = nbytes / (2 * sizeof(word));
 return len0 <= Width(struct g) ? encode(mem, g_status_scare) :
   g_ini_0(mem, len0, g_no_malloc, g_no_free); }

static void *g_libc_malloc(struct g*g, size_t n) { return malloc(n); }
static void g_libc_free(struct g*g, void *x) { free(x); }
struct g *g_ini(void) { return g_ini_m(g_libc_malloc, g_libc_free); }

// ============================================================================
// stack
// ============================================================================
static struct g *g_pushr(struct g *g, uintptr_t m, uintptr_t n, va_list xs) {
 if (n == m) return g_please(g, m);
 word x = va_arg(xs, word);
 MM(g, &x);
 g = g_pushr(g, m, n + 1, xs);
 UM(g);
 if (g_ok(g)) *--g->sp = x;
 return g; }

struct g *g_push(struct g *g, uintptr_t m, ...) {
 if (!g_ok(g)) return g;
 va_list xs;
 va_start(xs, m);
 uintptr_t n = 0;
 if (avail(g) < m) g = g_pushr(g, m, n, xs);
 else for (g->sp -= m; n < m; g->sp[n++] = va_arg(xs, word));
 va_end(xs);
 return g; }

struct g *gxl(struct g *g) {
 if (g_ok(g = g_have(g, Width(struct g_pair)))) {
  struct g_pair *p = bump(g, Width(struct g_pair));
  ini_two(p, g->sp[0], g->sp[1]);
  *++g->sp = (word) p; }
 return g; }

struct g *gxr(struct g *g) {
 if (g_ok(g = g_have(g, Width(struct g_pair)))) {
  struct g_pair *p = bump(g, Width(struct g_pair));
  ini_two(p, g->sp[1], g->sp[0]);
  *++g->sp = (word) p; }
 return g; }

// ============================================================================
// gc
// ============================================================================
g_vm(g_vm_gc, uintptr_t n) {
 Pack(g);
 if (!g_ok(g = g_please(g, n))) return gtrap(g);
 return Unpack(g), Continue(); }

static word gcp(struct g*, word, word const *, word const *);

static g_inline void evac_two(struct g*g, word const*const p0, word const*const t0) {
 struct g_pair *w = (struct g_pair*) g->cp;
 g->cp += Width(struct g_pair);
 w->a = gcp(g, w->a, p0, t0);
 w->b = gcp(g, w->b, p0, t0); }

static g_inline void evac_tuple(struct g*g, word const*const p0, word const*const t0) {
 struct g_tuple *v = tuple(g->cp);
 g->cp += b2w(g_tuple_bytes(v));
 if (v->type != g_O) return;                 // numeric vecs are GC leaves (flat payload)
 word *e = (word*) tuple_data(v);              // object tuple: forward each live element word
 uintptr_t n = tuple_nelem(v);
 while (n--) e[n] = gcp(g, e[n], p0, t0); }

static g_inline void evac_str(struct g*g, word const*const p0, word const*const t0) {
 g->cp += b2w(sizeof(struct g_str) + str(g->cp)->len); }

static g_inline void evac_big(struct g*g, word const*const p0, word const*const t0) {
 g->cp += b2w(g_big_bytes((struct g_big*) g->cp)); }

static g_inline void evac_sym(struct g*g, word const*const p0, word const*const t0) {
 word nom = word(sym(g->cp)->nom);            // l/r subtree slots exist only for interned
 g->cp += Width(struct g_atom) - (nom && strp(nom) ? 0 : 2); }   // (string nom); anon/uninterned skip them

static g_inline void evac_thd(struct g *g, word const *const p0, word const*const t0) {
  // terminator payloads point into the new pool (the copied object's home);
  // a stray 2-byte-aligned external content word is rejected by the range
  word const *lo = ptr(g), *hi = ptr(g) + g->len;
  for (g->cp += 1; !tagp(g->cp[-1], lo, hi); g->cp[-1] = gcp(g, g->cp[-1], p0, t0), g->cp++); }

static g_inline void evac_data(struct g *g, word const *const p0, word const*const t0) {
  switch (typ(g->cp)) {
   default: __builtin_trap();
   case KTuple: return evac_tuple(g, p0, t0);
   case KSym: return evac_sym(g, p0, t0);
   case KTwo: return evac_two(g, p0, t0);
   case KString: return evac_str(g, p0, t0);
   case KBig: return evac_big(g, p0, t0); } }

static g_inline void run_finalizers(struct g*g) {
 struct g_fz *new_fz = NULL;
 for (struct g_fz *fz = g->fz; fz; fz = fz->next) {
  word fwd = fz->p->x;
  if (lamp(fwd) && ptr(g) <= ptr(fwd) && ptr(fwd) < ptr(g) + g->len) {
   struct g_fz *nn = bump(g, Width(struct g_fz));
   nn->p = cell(fwd), nn->fn = fz->fn, nn->next = new_fz, new_fz = nn;
  } else fz->fn(fz->p); }
 g->fz = new_fz; }

static g_noinline struct g *gcg(struct g*h, struct g *p1, uintptr_t len1, struct g *g) {
 memcpy(h, g, sizeof(struct g));
 h->pool = (void*) p1;
 h->len = len1;
 uintptr_t const len0 = g->len;
 word const *p0 = ptr(g),
            *t0 = ptr(g) + len0, // source top
            *sp0 = g->sp;
 word sh = t0 - sp0; // stack height
 h->sp = ptr(h) + len1 - sh;
 h->hp = h->cp = h->end;
 h->ip = cell(gcp(h, word(h->ip), p0, t0));
 h->tasks = cell(gcp(h, word(h->tasks), p0, t0));
 h->symbols = 0;
 for (word i = 0; i < h->end - &h->v0; i++) (&h->v0)[i] = gcp(h, (&h->v0)[i], p0, t0);               // core live variables (incl. the pre-interned *_sym dict keys)
 for (word n = 0; n < sh; n++) h->sp[n] = gcp(h, sp0[n], p0, t0);                     // stack
 for (struct g_r *s = h->root; s; s = s->n) *s->x = gcp(h, *s->x, p0, t0); // C live variables
 while (h->cp < h->hp) (datp(h->cp) ? evac_data : evac_thd)(h, p0, t0);              // cheney algorithm
 run_finalizers(h);
 if (h->len > h->max_len) h->max_len = h->len;                                       // instrumentation: peak pool len
 { uintptr_t heap = h->hp - h->end; if (heap > h->max_heap) h->max_heap = heap; }    // peak live (compacted) heap
 return h; }


g_noinline struct g *g_please(struct g *g, uintptr_t req0) {
 uintptr_t const
  t0 = g->t0, // end of last gc period
  t1 = g_clock(), // end of current non-gc period
  len0 = g->len;
 // find alternate pool
 struct g *h = off_pool(g);
 g = gcg(h, g->pool, g->len, g);
 g->n_gc += 1; // instrumentation: count one gc cycle per please
 uintptr_t const
  v_lo = 4,
  v_hi = v_lo * v_lo,
  req = req0 + len0 - avail(g),
  t2 = g_clock();
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
  !(h = g->malloc(g, len1 * 2 * sizeof(word))) ? // if malloc fails but pool is big enough
   encode(g, req <= len0 ? g_status_ok : g_status_scare) : // we can still report success
  (h = gcg(h, h, len1, g),
   g->free(g, g->pool),
   h->t0 = g_clock(),
   h); }

static g_inline word copy_two(struct g*g, struct g_pair *src, word const *const p0, word const *const t0) {
 struct g_pair *dst = bump(g, Width(struct g_pair));
 ini_two(dst, src->a, src->b);
 src->ap = (g_vm_t*) dst;
 return word(dst); }

static g_inline word copy_tuple(struct g*g, struct g_tuple *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = g_tuple_bytes(src);
 struct g_tuple *dst = bump(g, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

static g_inline word copy_str(struct g*g, struct g_str *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = sizeof(struct g_str) + src->len;
 struct g_str *dst = bump(g, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

// Bignums are flat (raw limbs, no embedded ll pointers), so they copy by a
// single memcpy and evac by advancing past their bytes -- exactly like strings.
static g_inline word copy_big(struct g*g, struct g_big *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = g_big_bytes(src);
 struct g_big *dst = bump(g, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

static g_inline word copy_sym(struct g*g, struct g_atom *src, word const *const p0, word const*const t0) {
 struct g_atom *dst;
 if (!src->nom) dst = bump(g, Width(struct g_atom) - 2), ini_anon(dst, src->code);
 else {
  word nom = gcp(g, word(src->nom), p0, t0);   // relocate the nom (its sentinel now reads true)
  if (symp(nom))                               // named-uninterned: copy fresh, stay out of the tree
   dst = bump(g, Width(struct g_atom) - 2), ini_usym(dst, sym(nom), src->code);
  else                                         // interned (string nom): rebuild the tree by name
   dst = intern_checked(g, (struct g_str*) nom); }
 return word(src->ap = (g_vm_t*) dst); }

static g_inline word copy_data(struct g *g, union u *src, word const *const p0, word const *const t0) {
 switch (typ(src)) {
  default: __builtin_trap();
  case KTwo: return copy_two(g, two(src), p0, t0);
  case KTuple: return copy_tuple(g, tuple(src), p0, t0);
  case KSym: return copy_sym(g, sym(src), p0, t0);
  case KString: return copy_str(g, str(src), p0, t0);
  case KBig: return copy_big(g, (struct g_big*) src, p0, t0); } }

static g_inline struct g_tag *ttag2(union u *k, word const *const lo, word const *const hi) {
 while (!tagp(k->x, lo, hi)) k++;
 return (struct g_tag*) k; }

static g_inline word copy_thread(struct g *g, union u *src, word const *const p0, word const *const t0) {
 // it's a thread, find the end to find the head
 struct g_tag *t = ttag2(src, p0, t0);
 union u *ini = tag_head(t), *d = bump(g, t->end - ini), *dst = d;
 // copy each content word to dest and leave a forwarding pointer behind,
 // stopping at the terminator; then rewrite it as the new tagged head
 for (union u *s = ini; !tagp(s->x, p0, t0); s->x = (word) d, d++, s++) d->x = s->x;
 return (word) (tagthd(dst, d - dst) + (src - ini)); }

static g_noinline intptr_t gcp(struct g *g, word x, word const *p0, word const *t0) {
 // if it's a number or it's outside managed memory then return it
 if (fixp(x) || ptr(x) < p0 || ptr(x) >= t0) return x;
 union u *src = cell(x);
 x = src->x; // get its contents
 // if it contains a pointer to the new space then return the pointer
 return lamp(x) && ptr(g) <= ptr(x) && ptr(x) < ptr(g) + g->len ? x :
        in_data((void*) x) ? copy_data(g, src, p0, t0) :
                                copy_thread(g, src, p0, t0); }

// ============================================================================
// ev
// ============================================================================
static g_inline struct g *pushl(struct g*g) { return intern(g_strof(g, "\\")); }
static struct g *c0(struct g *g, g_vm_t *y);

// function state using this type
struct env {
 struct env *par; // enclosing scope
 word args, imps, // positional and closure variables
  stack, // computed arguments and let bindings on stack
  lams, // lambdas defined in a local let form
  len,  // thread length accumulator
  branches, // stack for conditional alternate branch addresses
  exits,
  sites, // recursive-fn ref backpatch: list of (lams-entry . operand-cell)
  src,  // a lambda's source \-expr, stashed at the thread head for printing (nil = none)
  end[]; }; // stach for conditional exit addresses

typedef Ana(ana);
typedef Cata(cata);
static ana analyze, ana_d, ana_c, ana_l, ana_q, ana_ap;
static Ana(ana_2, word, word);
static cata c1_i, c1_ix, c1_var, c1_yield, c1_ret, c1, c1_recv;
static g_inline Cata(pull) { return g_ok(g) ? ((cata*) pop1(g))(g, c) : g; }

// generic instruction ana handlers
static g_inline struct g *c0_ix(struct g *g, struct env **c, g_vm_t *i, word x) {
 return incl(*c, 2), g_push(g, 3, c1_ix, i, x); }

static g_inline struct g *c0_i(struct g *g, struct env **c, g_vm_t *i) {
 return incl(*c, 1), g_push(g, 2, c1_i, i); }

static struct g *enscope(struct g *g, struct env *par, word args, word imps) {
 uintptr_t const n = Width(struct env) + Width(struct g_tag);
 g = g_push(g, 3, args, imps, par);
 if (g_ok(g = g_have(g, n))) {
  struct env *c = bump(g, n);
  c->stack = c->branches = c->exits = c->lams = c->len = c->sites = c->src = nil;
  c->args = g->sp[0], c->imps = g->sp[1], c->par = (struct env*) g->sp[2];
  *(g->sp += 2) = (word) tagthd((union u*)c, Width(struct env)); }
 return g; }

static word memq(struct g *g, word l, word k) {
 for (; twop(l); l = B(l)) if (eql(g, k, A(l))) return l;
 return 0; }

static word assq(struct g *g, word l, word k) {
 for (; twop(l); l = B(l)) if (eql(g, k, AA(l))) return A(l);
 return 0; }

static struct g *append(struct g *g) {
 uintptr_t i = 0;
 for (word l; g_ok(g) && twop(g->sp[0]); i++)
  l = B(g->sp[0]),
  g->sp[0] = A(g->sp[0]),
  g = g_push(g, 1, l);
 if (!g_ok(g)) return g;
 if (i == 0) return g->sp++, g;
 for (g->sp[0] = g->sp[i + 1]; i--; g = gxr(g));
 if (g_ok(g)) g->sp[1] = g->sp[0], g->sp++;
 return g; }

// don't inline this so callers can tail call optimize
static g_noinline struct g *c0(struct g *g, g_vm_t *y) {
 if (!g_ok(g = enscope(g, (struct env*) nil, nil, nil))) return g;
 struct env *c = (void*) ptr(pop1(g));
 word x = g->sp[0];
 g->sp[0] = (word) c1_yield;
 MM(g, &c); MM(g, &x);
 if (g_ok(g = analyze(g, &c, x)))
   g = c1(c0_ix(g, &c, y, word(g->ip)), &c);
 UM(g), UM(g);
 return g; }

static Cata(c1) {
 uintptr_t l = getfix((*c)->len);
 // a lambda carries its source \-expr: reserve one extra leading word for it so
 // it sits at value[-1] (the printer's discriminator) and rides inside the thread
 // span (head = src word) for free GC tracing. top-level/aux threads have no src.
 uintptr_t extra = nilp((*c)->src) ? 0 : 1;
 g = g_have(g, l + extra + Width(struct g_tag));
 if (g_ok(g)) {
  union u *k = bump(g, l + extra + Width(struct g_tag));
  memset(k, -1, (l + extra) * sizeof(word));
  Kp = tagthd(k, l + extra) + l + extra;
  if (g_ok(g = pull(g, c))) {           // pull emits l words (may GC); Kp now = entry
   // read src AFTER all allocation: g_have/pull can GC and relocate the env's src.
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
 if (arity == putfix(1)) {
  if (Kp[0].ap == g_vm_ret) Kp[0].ap = g_vm_tap;
  else Kp -= 1, Kp[0].ap = g_vm_ap; }
 else {
  if (Kp[0].ap == g_vm_ret) Kp -= 1, Kp[0].ap = g_vm_tapn, Kp[1].x = arity;
  else Kp -= 2, Kp[0].ap = g_vm_apn, Kp[1].x = arity; }
 return pull(g, c); }


static Cata(c1_i) {
 g_vm_t *i = (void*) pop1(g);
 Kp -= 1;
 Kp[0].ap = i;
 return pull(g, c); }

static Cata(c1_ix) {
 g_vm_t *i = (void*) pop1(g);
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
 Kp[0].ap = g_vm_quote;
 if (nilp(site)) Kp[1].x = AB(y);
 else Kp[1].x = nil, B(site) = (word) &Kp[1];
 return pull(g, c); }

static Cata(c1_ar, g_vm_t *i, word ar) { return
 Kp -= 2,
 Kp[0].ap = i,
 Kp[1].x = putfix(ar),
 pull(g, c); }

static Cata(c1_cur) {
 struct env *e = (void*) pop1(g);
 uintptr_t ar = llen(e->args) + llen(e->imps);
 return ar == 1 ? pull(g, c) : c1_ar(g, c, g_vm_cur, ar); }

static Cata(c1_ret) {
 struct env *e = (struct env*) pop1(g);
 uintptr_t ar = llen(e->args) + llen(e->imps);
 return c1_ar(g, c, g_vm_ret, ar); }

C1(c1_cond_push_branch, g = gxl(g_push(g, 2, Kp, (*c)->branches)), (*c)->branches = g_ok(g) ? pop1(g) : nil)
C1(c1_cond_push_exit, g = gxl(g_push(g, 2, Kp, (*c)->exits)), (*c)->exits = g_ok(g) ? pop1(g) : nil)
C1(c1_cond_pop_branch, Kp -= 2, Kp[0].ap = g_vm_cond, Kp[1].x = A((*c)->branches), (*c)->branches = B((*c)->branches))

static Cata(c1_cond_exit) {
 union u *a = cell(A((*c)->exits));
 if (a->ap == g_vm_ret || a->ap == g_vm_tap)
  Kp = memcpy(Kp - 2, a, 2 * sizeof(*Kp));
 else if (a->ap == g_vm_tapn)
  Kp = memcpy(Kp - 3, a, 3 * sizeof(*Kp));
 else
  Kp -= 2, Kp[0].ap = g_vm_jump, Kp[1].x = (word) a;
 return pull(g, c); }

static g_vm(_g_vm_yieldk) { return
 Ip = Ip[1].m,
 Pack(g),
 encode(g, g_status_yield); }


static struct g *g_eval(struct g *g) {
 g = c0(g, _g_vm_yieldk);
#if g_tco
 if (g_ok(g)) g = g->ip->ap(g, g->ip, g->hp, g->sp);
#else
 while (g_ok(g)) g = g->ip->ap(g);
 if (g_code_of(g) == g_status_eof) g = g_core_of(g);
#endif
 return g; }

static word lidx(struct g*g, word x, word l) {
 word i = 0;
 for (; twop(l); i++, l = B(l)) if (eql(g, x, A(l))) return i;
 return -1; }

static Ana(ana_v) {
 word y;
 if (!g_ok(g)) return g;
 for (struct env *d = *c;; d = d->par) {
  if (nilp(d)) {
   if ((y = g_mapget(g, 0, x, g->dict))) return ana_q(g, c, y);
   // undefined global: resolved by g_vm_freev via the dict at run time.
   // Only record it as a captured free variable when this scope is nested
   // (cf. ev.l avb: `(? (get 0 'par c) (push 'imp x))`). At top level there
   // is no enclosing frame to capture from, so adding x to imps would make a
   // second reference resolve via memq(imps) to an uninitialized arg slot.
   // re-read x from the imps cons: the gxl/g_push above can GC and relocate
   // the symbol, leaving the local x dangling (cf. the same A((*c)->imps)
   // pattern in the capture path below). c0_ix then emits the live pointer.
   if (!nilp((*c)->par))
    g = gxl(g_push(g, 2, x, (*c)->imps)),
    x = g_ok(g) ? A((*c)->imps = pop1(g)) : nil;
   return c0_ix(g, c, g_vm_freev, x); }
  // lambda definition of local let form?
  if ((y = assq(g, d->lams, x))) {
   // recursive-fn ref: record a backpatch site on d (the lams-owning scope) when
   // the closure isn't built yet, then apply the captured imports.
   word site = nil;
   if (nilp(AB(y))) {
    MM(g, &d), MM(g, &y);
    g = gxl(g_push(g, 2, y, nil)); // site = (y . nil)
    if (g_ok(g)) {
     g = gxl(g_push(g, 2, g->sp[0], d->sites)); // (site . d->sites)
     if (g_ok(g)) d->sites = pop1(g), site = pop1(g); }
    UM(g), UM(g); }
   incl(*c, 2);
   if (g_ok(g = g_push(g, 3, c1_recv, y, site)))
    g = ana_ap(g, c, BB(g->sp[1]));
   return g; }
  // let binding in the *current* scope -> a direct stack slot.
  if (d == *c && memq(g, d->stack, x)) return
    c0_ix(g, c, g_vm_arg, putfix(lidx(g, x, d->stack)));
  // a let binding, closure var, or lambda arg -- possibly from an enclosing
  // scope. If enclosing, import it into this scope's free-variable (imps) list
  // so the offset c1_var emits is valid in *this* frame, not the defining one;
  // otherwise a captured let binding aliases whatever sits at the same offset
  // in the closure's frame (see the boot.l compiler's ava fix, commit 8e3acf0).
  if (memq(g, d->stack, x) || memq(g, d->imps, x) || memq(g, d->args, x)) {
   incl(*c, 2);
   if (d != *c) // found in an enclosing scope -> import (capture) it
    g = gxl(g_push(g, 2, x, (*c)->imps)),
    x = g_ok(g) ? A((*c)->imps = pop1(g)) : nil;
   return g_push(g, 3, c1_var, x, (*c)->stack); } } }


static Cata(c1_var) {
 word v = pop1(g), i = llen(pop1(g)); // stack inset
 for (word l = (*c)->imps; !nilp(l); l = B(l), i++)
  if (eql(g, v, A(l))) goto out;
 for (word l = (*c)->args; !nilp(l); l = B(l), i++)
  if (eql(g, v, A(l))) break;
out:
 return Kp -= 2,
        Kp[0].ap = g_vm_arg,
        Kp[1].x = putfix(i),
        pull(g, c); }

static g_noinline Ana(analyze) {
 if (symp(x)) return ana_v(g, c, x); // lookup symbol as variable
 if (!twop(x)) return ana_q(g, c, x); // non-pairs are self quoting
 word a = A(x), b = B(x);                        // it must be a pair
 if (!twop(b)) return analyze(g, c, a); // singleton list has value of element
 // if it is a special form then do that
 if (symp(a) && sym(a)->nom && len(sym(a)->nom) == 1)
  switch (*txt(sym(a)->nom)) {
   case '\\': return ana_l(g, c, b);
   case ':': return ana_d(g, c, b);
   case '?': return ana_c(g, c, b); }
 return ana_2(g, c, x, a, b); }


static struct g *c0_lambda(struct g *g, struct env **c, intptr_t imps, intptr_t exp) {
 union u *k, *ip;
 word ops = exp;             // the full operand list (params… body) for the stored src
 struct env *d = NULL;
 MM(g, &d); MM(g, &exp); MM(g, &ops);
 g = enscope(g, *c, exp, imps);

 if (g_ok(g)) {
  d = (struct env*) pop1(g);
  exp = d->args;
  int n = 0; // push exp args onto stack
  for (; twop(B(exp)); exp = B(exp), n++) g = g_push(g, 1, A(exp));
  for (g = push0(g); n--; g = gxr(g));
  exp = A(exp); }

 if (g_ok(g)) {
  d->args = g->sp[0];
  g->sp[0] = (word) c1_yield;
  incl(d, 4);
  g = g_push(g, 2, c1_cur, d);
  g = analyze(g, &d, exp);
  // stash the source \-expr for the printer (gzput_fn), built AFTER analyze so the
  // captured imports (d->imps) are known. ops is (params… body); prepend the
  // imports as leading params (the frame layout is [imps, args]) so a closure
  // prints as `(\ imps… params… body)` applied to its captures and round-trips.
  if (g_ok(g)) {
   word l = d->imps; int ni = 0;
   MM(g, &l);
   for (; twop(l); l = B(l), ni++) g = g_push(g, 1, A(l));  // push imp1..impN
   UM(g);
   g = g_push(g, 1, ops);                                   // tail = (params… body)
   while (ni-- > 0) g = gxr(g);                             // fold: imps ++ ops
   g = gxl(pushl(g));                                       // cons '\ onto the front
   if (g_ok(g)) d->src = pop1(g); }
  if (g_ok(g = g_push(g, 2, c1_ret, d)))
    ip = g->ip,
    avec(g, ip, g = c1(g, &d)); }

 if (g_ok(g)) k = g->ip, g->ip = ip, g = gxl(g_push(g, 2, k, d->imps));

 return UM(g), UM(g), UM(g), g; }

static Ana(c0_cond_exit) { return
 incl(*c, 3),
 g_push(analyze(g, c, x), 1, c1_cond_exit); }

static Ana(c0_cond_r) { return
 !twop(x) ? c0_cond_exit(g, c, nil) :
 !twop(B(x)) ? c0_cond_exit(g, c, A(x)) :
 (avec(g, x,
  incl(*c, 2),
  g = analyze(g, c, A(x)),
  g = g_push(g, 1, c1_cond_pop_branch),
  g = c0_cond_exit(g, c, AB(x)),
  g = g_push(g, 1, c1_cond_push_branch),
  g = c0_cond_r(g, c, BB(x))), g); }


static struct g *ana_ap_r2l(struct g *g, struct env **c, word x);
static struct g *ana_ap(struct g *g, struct env **c, intptr_t x) {
 if (!g_ok(g)) return g;
 bool imfp =
  g->sp[0] == (word) c1_ix &&
  g->sp[1] == (word) g_vm_quote &&
  lamp(g->sp[2]);
 intptr_t
  ca = llen(x),
  va =
   imfp && cell(g->sp[2])->ap == g_vm_cur ?
    getfix(cell(g->sp[2])[1].x) :
    1;
 bool b1p = ca == 1 && imfp && cell(g->sp[2])[1].ap == g_vm_ret0,
      anp = va == ca && ca > 1,
      bnp = anp && cell(g->sp[2])[3].ap == g_vm_ret0;

 if (b1p) { // inline an instruction
  g_vm_t *i = cell(g->sp[2])->ap;
  g->sp += 3;
  g = c0_i(analyze(g, c, A(x)), c, i);
  return g; }

 if (bnp) { // inline a curried instruction
  g_vm_t *i = cell(g->sp[2])[2].ap;
  g->sp += 3;
  g = c0_i(ana_ap_r2l(g, c, x), c, i); // r2l arg eval
  if (g_ok(g)) while (ca--) (*c)->stack = B((*c)->stack);
  return g; }

 if (g_ok(g = gxl(g_push(g, 3, nil, (*c)->stack, x)))) {
  (*c)->stack = pop1(g), x = pop1(g), MM(g, &x);
  if (anp) { // r2l 1 n-ary ap
   g = ana_ap_r2l(g, c, x),
   incl(*c, 2),
   g = g_push(g, 2, c1_apn, putfix(ca));
   if (g_ok(g)) while (ca--) (*c)->stack = B((*c)->stack); }
  else while (twop(x)) // l2r n 1-ary ap
   g = analyze(g, c, A(x)),
   incl(*c, 2),
   g = g_push(g, 2, c1_apn, putfix(1)),
   x = B(x);
  UM(g), (*c)->stack = B((*c)->stack); }

 return g; }


static struct g *ana_ap_r2l(struct g *g, struct env **c, word x) {
 if (twop(x)) {
  word y = A(x);
  avec(g, y, g = ana_ap_r2l(g, c, B(x)));
  g = analyze(g, c, y);
  g = gxl(g_push(g, 2, nil, (*c)->stack));
  if (g_ok(g)) (*c)->stack = pop1(g); }
 return g; }

static g_inline bool lambp(struct g *g, word x) {
 struct g_str *n;
 return twop(x) && symp(A(x)) && twop(B(x)) && twop(B(B(x))) &&
  (n = sym(A(x))->nom) && len(n) == 1 && txt(n)[0] == '\\'; }

static g_inline word rev(word l) {
 word m, n = nil;
 while (twop(l)) m = l, l = B(l), B(m) = n, n = m;
 return n; }

static word ldels(struct g *g, word lam, word l);

static g_inline Ana(ana_2, word a, word b) {
 if ((x = g_mapget(g, 0, a, g_mapget(g, nil, nil, g_core_of(g)->dict))))   // macro table = dict[nil]
  return g = g_eval(gxr(gxl(gxl(pushq(gxl(g_push(g, 4, b, nil, nil, x))))))),
         analyze(g, c, g_ok(g) ? pop1(g) : 0);
 return avec(g, b, g = analyze(g, c, a)),
        ana_ap(g, c, b); }

static g_inline Ana(ana_q) { return c0_ix(g, c, g_vm_quote, x); }
static g_inline Ana(ana_l) {
  if (!twop(B(x))) return ana_q(g, c, A(x)); // one operand, no params: quote
  return g = c0_lambda(g, c, nil, x),
         analyze(g, c, g_ok(g) ? pop1(g) : 0); }
static Ana(c0_cond_r);
static g_inline Ana(ana_c) {
 return !twop(B(x)) ? analyze(g, c, A(x)) :
    (g = g_push(g, 2, x, c1_cond_pop_exit),
     g = c0_cond_r(g, c, g_ok(g) ? pop1(g) : nil),
     g_push(g, 1, c1_cond_push_exit)); }
// this is the longest C function :(
// it handles the let special form in a way to support sequential and recursive binding.
static g_inline struct g *ana_d(struct g *g, struct env **b, word exp) {
 if (!twop(B(exp))) return analyze(g, b, A(exp));
 struct g_r *mm = g_core_of(g)->root;
 MM(g, &exp);
 // recursive-value boxing: c0 is the bootstrap compiler, so it delegates the
 // letrec*-value rewrite to the ll `boxfix` prepass (prelude.l) -- evaluated
 // like a macro -- once that global exists (i.e. for everything after its own
 // definition partway through the prelude). It boxes a value binding whose init
 // closes over the name being defined into a heap cell. The runtime compiler
 // (ev.l) does the same natively in `l2x`. exp is rooted across the alloc.
 if (g_ok(g = intern(g_strof(g, "boxfix")))) {
  word bf = g_mapget(g, 0, pop1(g), g->dict);
  if (bf && lamp(bf)) {
   g = g_eval(gxr(gxl(gxl(pushq(gxl(g_push(g, 4, exp, nil, nil, bf)))))));
   if (g_ok(g)) exp = pop1(g); } }
 g = enscope(g, *b, (*b)->args, (*b)->imps);
 if (!g_ok(g)) return forget();
 struct env *q = (struct env*) pop1(g), **c = &q;
 // lots of variables :(
 word nom = nil, def = nil, lam = nil,
      v = nil, d = nil, e = nil, os = nil;
 MM(g, &nom), MM(g, &def), MM(g, &lam);
 MM(g, &d); MM(g, &e); MM(g, &v); MM(g, &q); MM(g, &os);

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
   g = gxl(g_push(g, 2, e, nil));
   g = append(gxl(pushl(g_push(g, 1, B(d)))));
   if (!g_ok(g)) return forget(); }
  g = gxl(g_push(g, 2, d, nom));
  g = gxl(g_push(g, 2, e, def));
  if (!g_ok(g)) return forget();
  def = pop1(g), nom = pop1(g);
  // if it's a lambda compile it and record in lam list
  if (lambp(g, e)) {
   g = g_push(g, 2, d, lam);
   g = gxl(gxr(c0_lambda(g, c, nil, B(e))));
   if (!g_ok(g)) return forget();
   lam = pop1(g); }
  g = gxl(g_push(g, 2, d, (*b)->stack)); // expose this binding to later siblings
  (*b)->stack = g_ok(g) ? pop1(g) : nil;
  exp = BB(exp); }
 (*b)->stack = os; // restore: emission below rebuilds the real frame

 intptr_t ll = llen(nom);
 bool oddp = twop(exp),
      globp = !oddp && nilp((*b)->args); // we check this again later to make global bindings at top level
 if (!oddp) { // if there's no body then evaluate the name of the last definition
  g = gxl(g_push(g, 2, A(nom), nil));
  if (!g_ok(g)) return forget();
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
      g = gxl(g_push(g, 2, var, vars)),
      BB(A(e)) = g_ok(g) ? pop1(g) : nil;
 while (j);

 // now delete defined functions from the closure variable lists
 // they will be bound lazily when the function runs
 for (e = lam; twop(e); BB(A(e)) = ldels(g, lam, BB(A(e))), e = B(e));

 (*c)->lams = lam;
 g = append(gxl(pushl(g_push(g, 2, nom, exp))));

 if (!g_ok(g)) return forget();
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
   if (!g_ok(g)) return forget();
   A(v) = B(d) = pop1(g); }

 // closures final -> backpatch each recorded recursive-fn ref with its thread.
 for (d = (*c)->sites; twop(d); d = B(d)) cell(B(A(d)))->x = AB(A(A(d)));
 (*c)->sites = nil;

 nom = rev(nom); // put in literal order
 g = analyze(g, b, exp);
 g = gxl(g_push(g, 2, nil, e = (*b)->stack)); // push function stack rep
 (*b)->stack = g_ok(g) ? pop1(g) : nil;
 for (def = rev(def); twop(nom); nom = B(nom), def = B(def))
  g = analyze(g, b, A(def)),
  g = globp ? c0_ix(g, b, g_vm_defglob, A(nom)) : g,
  g = gxl(g_push(g, 2, A(nom), (*b)->stack)),
  (*b)->stack = g_ok(g) ? pop1(g) : nil;
 return
  (*b)->stack = e,
  incl(*b, 2),
  g = g_push(g, 2, c1_apn, putfix(ll)),
  forget(); }

static word ldels(struct g *g, word lam, word l) {
 if (!twop(l)) return nil;
 word m = ldels(g, lam, B(l));
 if (!assq(g, lam, A(l))) B(l) = m, m = l;
 return m; }

g_vm(g_vm_defglob) {
 Have(3);
 Sp -= 3;
 word k = Ip[1].x, v = Sp[3];
 return Sp[0] = k, Sp[1] = v, Sp[2] = g->dict, Pack(g),
  !g_ok(g = g_mapput(g)) ? gtrap(g) : (Unpack(g), Sp += 1, Ip += 2, Continue()); }

g_vm(g_vm_freev) { return
 Ip[0].ap = g_vm_quote,
 Ip[1].x = g_mapget(g, nil, Ip[1].x, g->dict),
 Continue(); }

g_vm(g_vm_eval) { return Ip++, Pack(g),
 !g_ok(g = c0(g, g_vm_jump)) ? gtrap(g) : (Unpack(g), Continue()); }

g_noinline struct g *g_evals_(struct g*g, char const*s) {
 static char const *t = "((:(e a b)(? b(e(ev'ev(A b))(B b))a)e)0)";
 struct ti i = {{g_vm_port_io, putfix(-1), putfix(EOF), putfix(false)}, t, 0};
 g = push0(pushq(push0(g_eval(g_reads(g, (void*) &i)))));
 i.t = s, i.i = 0, i.io.ungetc_buf = putfix(EOF), i.io.eof_seen = putfix(false);
 return g_pop(g_eval(gxr(gxl(gxr(gxl(g_reads(g, (void*) &i)))))), 1); }

// ============================================================================
// vm
// ============================================================================
// Resolve a C->lisp handler from dict (where the prelude pins it -- dict is
// GC-traced and egg-baked, so it survives into the runtime image). Trap loud if
// undefined: a prelude-ordering contract violation. g_mapget is a read, so no
// Have is needed in the tail-jump callers.
static g_inline g_word resolve_handler(struct g *g, g_word nom) {
 g_word cur = g_mapget(g, nil, nom, g->dict);
 if (!lamp(cur)) __builtin_trap();
 return cur; }

// Thread (function) combinators for `+` and `*`, pinned on dict by the prelude
// like num-ap. A thread operand takes precedence over every other type, so
// `+`/`*` of a function build a new function -- the README's Church arithmetic,
// agreeing with numerals: `+` is Church add ((+ g g) a x = g a (g a x)), `*` is
// composition. scomb is the 4-arg add lambda, bcomb the 3-arg compose; the C
// handlers reuse numap_drive to compute the partial (scomb g g) / (bcomb g g)
// -- itself the new function -- and leave it as the result, resuming at Ip+1.

// Fixnum-as-function application. A fixnum operator n applied to x is dispatched
// to the ll handler at dict['num-ap] as (num-ap n x): numeric x -> x**n, a
// function x -> x iterated n times (Church numerals).
//
// The driver mirrors the pair driver: with the stack laid out [n, num-ap, x, ret]
// it applies num-ap to n (a partial), swaps so that partial becomes the operator,
// applies it to x, and ret0s the result to ret. The five apply sites divert here as
// a tail jump (no extra args -> stays a sibcall, cf. vmret): g_vm_numap is the
// non-tail form (frame below Sp, resume at Ip+1), g_vm_numtap the tail form (frame
// in the popped region, deliver to the caller's ret at Sp[fs+2]). The fused arg/quote
// variants first push their argument under the operator and bump Ip by one word so
// the canonical [.. x n] layout and resume/frame-size operand line up, then divert.
static g_vm(numap_swap) {
 word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t;
 return Ap(g_vm_ap, g); }
union u const numap_drive[] = { {g_vm_ap}, {.ap = numap_swap}, {.ap = g_vm_ret0} };

// ============================================================================
// the lisp trap calling convention
// ============================================================================
// With a global `trap` function installed, a throw becomes the call
// (trap s a b): s = the status word (prelude readers scare?/more?/eof?),
// a/b = the condition data -- for the more bit the port and the read sentinel,
// for a scare nil nil (oom is bare; future scares define their shapes). The
// frame runs through trap_drive (numap_drive's 3-arg twin) into a per-class
// epilogue: the more bit delivers the handler's result to the thrower's resume
// thread (the fread protocol -- the handler chooses what the reader's caller
// sees); a scare is observed, then takes the default escape to C.
static g_vm(trap_ret_more) {   // [result resume port sentinel ..] -> resume sees result
 Ip = cell(Sp[1]);
 Sp[3] = Sp[0];
 Sp += 3;
 return Continue(); }
static g_vm(trap_ret_scare) {  // result ignored: scares are not (yet) resumable
 return Pack(g), encode(g, g_status_scare); }
static union u const trap_more_k[] = { {trap_ret_more} };
static union u const trap_scare_k[] = { {trap_ret_scare} };
static union u const trap_drive[] =
 { {g_vm_ap}, {.ap = numap_swap}, {.ap = numap_swap}, {.ap = g_vm_ret0} };

// Throw status s to the trap continuation. With a global `trap` function and 5
// words of stack headroom (the throw path never allocates), build the
// (trap s a b) frame and run it; else the C default throw_c, which resumes the
// eof protocol raw. Pre-dict throws (g_ini_0) always take the default.
struct g *gtrap2(struct g *g, enum g_status s) {
 struct g *c = g_core_of(g);
 if (c->dict && c->trap_sym) {
  word h = g_mapget(c, nil, c->trap_sym, c->dict);
  if (lamp(h) && avail(c) >= 5) {
   int rd = s & g_status_more;     // the more bit: a read-end condition
   word *sp = c->sp -= 5;          // [s h a b K | thrower data ..]
   sp[0] = putfix(s), sp[1] = h;
   sp[2] = rd ? sp[6] : nil;       // read data: [resume port sentinel] under the frame
   sp[3] = rd ? sp[7] : nil;
   sp[4] = word(rd ? trap_more_k : trap_scare_k);
   c->ip = (union u*) trap_drive;
#if g_tco
   return c->ip->ap(c, c->ip, c->hp, c->sp);
#else
   return c;                       // ok-g: the trampoline dispatches trap_drive
#endif
  } }
 union u *t = (union u*) throw_c;
 c->ip = t;
#if g_tco
 return t->ap(encode(c, s), t, c->hp, c->sp);
#else
 return t->ap(encode(c, s));
#endif
}
// Throw on an already-tagged g: re-throw its own status.
struct g *gtrap(struct g *g) { return gtrap2(g_core_of(g), g_code_of(g)); }
// numap/numtap are tail-called (Ap) from the fused arg/quote handlers, which bump
// Ip by one word so its `ret = Ip+1` math lines up -- leaving Ip pointing at an
// operand, NOT a re-runnable instruction. So a plain Have() here is unsafe: g_vm_gc
// re-dispatches via Continue() -> cell(Ip)->ap, which would jump into that operand.
// Instead gc by hand and re-Ap ourselves (we read but don't mutate before this, so
// re-entry is idempotent); the dispatch never has to trust Ip.
#define NumapHave(self) if (Sp < Hp + 2) { \
 Pack(g); g = g_please(g, 2); if (!g_ok(g)) return gtrap(g); \
 return Unpack(g), Ap(self, g); }
static g_vm(g_vm_numap) {
 NumapHave(g_vm_numap);
 word h = resolve_handler(g, g->numap_sym);
 word n = Sp[1], x = Sp[0], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = n, dst[1] = h, dst[2] = x, dst[3] = ret;
 return Sp = dst, Ip = (union u*) numap_drive, Continue(); }
static g_vm(g_vm_numtap) {
 NumapHave(g_vm_numtap);
 word h = resolve_handler(g, g->numap_sym);
 word fs = getfix(Ip[1].x), n = Sp[1], x = Sp[0], *dst = &Sp[fs + 2] - 3, ret = Sp[fs + 2];
 dst[0] = n, dst[1] = h, dst[2] = x, dst[3] = ret;
 return Sp = dst, Ip = (union u*) numap_drive, Continue(); }

// `+`/`*` over a lambda operand: build the combinator partial (scomb/bcomb g g)
// and leave it as the result. Mirrors g_vm_numap's frame -- [g, comb, g, ret=Ip+1]
// run through numap_drive -- but the combinator (4-arg add / 3-arg compose) applied
// to 2 args yields a closure (the new function) instead of a value. Ip is at the +/*
// opcode (a re-runnable instruction), so a plain Have is safe; operands re-read after.
static g_vm(g_vm_addl) {
 Have(2);
 word h = resolve_handler(g, g->scomb_sym);
 word fa = Sp[0], ga = Sp[1], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = fa, dst[1] = h, dst[2] = ga, dst[3] = ret;
 return Sp = dst, Ip = (union u*) numap_drive, Continue(); }
static g_vm(g_vm_mull) {
 Have(2);
 word h = resolve_handler(g, g->bcomb_sym);
 word fa = Sp[0], ga = Sp[1], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = fa, dst[1] = h, dst[2] = ga, dst[3] = ret;
 return Sp = dst, Ip = (union u*) numap_drive, Continue(); }

// apply function to one argument
g_vm(g_vm_ap) {
 union u *k;
 if (oddp(Sp[1])) return Ap(g_vm_numap, g);
 k = cell(Sp[1]), Sp[1] = word(Ip + 1), Ip = k;
 YieldCheck();
 return Continue(); }

// tail call
g_vm(g_vm_tap) {
 if (oddp(Sp[1])) return Ap(g_vm_numtap, g);         // fixnum operator -> num-ap, deliver to caller
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getfix(Ip[1].x) + 1;
 Ip = cell(j), Sp[0] = x;
 YieldCheck();
 return Continue(); }

// apply to multiple arguments
g_vm(g_vm_apn) {
 size_t n = getfix(Ip[1].x);
 union u *r = Ip + 2; // return address
 // this instruction is only emitted when the callee is known to be a function
 // so putting a value off the stack into Ip is safe. the +2 is cause we leave
 // the currying instruction in there... should be skipped in compiler instead FIXME
 Ip = cell(Sp[n]) + 2;
 Sp[n] = word(r); // store return address
 YieldCheck();
 return Continue(); }

// tail call
g_vm(g_vm_tapn) {
 size_t n = getfix(Ip[1].x),
        r = getfix(Ip[2].x);
 Ip = cell(Sp[n]) + 2;
 word *o = Sp;
 for (Sp += r + 1; n--; Sp[n] = o[n]);
 YieldCheck();
 return Continue(); }

// return
g_vm(g_vm_ret) {
 word n = getfix(Ip[1].x) + 1;
 return Ip = cell(Sp[n]), Sp[n] = Sp[0], Sp += n, Continue(); }

g_vm(g_vm_ret0) { return
 Ip = cell(Sp[1]),
 Sp[1] = Sp[0],
 Sp += 1,
 Continue(); }

// kcall : x = Sp[0], k = Ip[1] -> Ip = k, Sp[0] = x
g_vm(g_vm_kcall) {
 word x = Sp[0];
 union u *stack = Ip + 2, *end = (union u*) ttag(g, stack);
 uintptr_t height = end - stack;
 Have(height);
 *(Sp = memmove(topof(g) - height, stack, height * sizeof(word))) = x;
 Ip = Ip[1].m;
 return Continue(); }

// callk : i = Sp[0], k = Ip + 1 -> Ip = i, Sp[0] = k
g_vm(g_vm_callk) {
 word f_val = Sp[0];                         // g, the call_cc arg
 if (oddp(f_val)) return Ip += 1, Continue();
 word height = topof(g) - Sp;
 uintptr_t n = 2 + height;                   // g_vm_kcall + (ip + 1) + stack = thread_contents
 Have(n + Width(struct g_tag) + 1);          // thread_contents + thread_tag + 1 stack = _mem_req
 union u *k = (union u*) Hp;
 Hp += n + Width(struct g_tag);              // thread_contents + thread_tag = _heap_alloc
 k[0].ap = g_vm_kcall;                       // 
 k[1].m  = Ip + 1;                           // resume at next instruction
 memcpy(k + 2, Sp, height * sizeof(word));
 Sp -= 1;
 Sp[0] = word(tagthd(k, n));
 Sp[1] = f_val;
 return Ap(g_vm_ap, g); }

// g_vm_yield_sw_mono can't call g_wait_fds directly with a stack pointer
static g_noinline void g_wait_fd(int const fd, int n, uintptr_t ms) {
  g_wait_fds(&fd, n, ms); }

// monotask fast path
static g_vm(g_vm_yield_sw_mono) { uintptr_t my_wake = g->next_wake_at;
 int my_wait_fd = g->next_wait_fd;
 g->next_wake_at = 0;
 g->next_wait_fd = -1;
 g->yield_ctr = 0;
 if (my_wake) for (uintptr_t now; my_wake > (now = g_clock());)
  my_wait_fd >= 0 ? g_wait_fd(my_wait_fd, 1, my_wake - now) : g_sleep(my_wake - now);
 else if (my_wait_fd >= 0)
  while (!g_ready(my_wait_fd)) g_wait_fd(my_wait_fd, 1, 0);
 return Continue(); }

// First non-dormant peer in the ring whose wake_at <= now and whose
// wait_fd is either unset or actually ready. Without the wait_fd check
// a task parked on stdin would be scheduled immediately, busy-looping
// through yield_sw and filling the heap with stale task nodes.
static g_inline union u *find_runnable(union u *head, uintptr_t now) {
 for (union u *n = head->m; n != head; n = n->m)
  if (n[1].m->ap != g_vm_task_exit && (uintptr_t) getfix(n[3].x) <= now) {
   int wf = (int) getfix(n[4].x);
   if (wf < 0 || g_ready(wf)) return n; }
 return NULL; }

static g_noinline union u *yield_sw_wait(struct g *g, uintptr_t my_wake, int my_wait_fd) {
 uintptr_t min_wake = my_wake;
 int fds[G_WAIT_FDS_MAX], nfds = 0;
 if (my_wait_fd >= 0) fds[nfds++] = my_wait_fd;
 for (union u *n = g->tasks->m; n != g->tasks; n = n->m)
  if (n[1].m->ap != g_vm_task_exit) {
   uintptr_t wa = (uintptr_t) getfix(n[3].x);
   if (wa && (!min_wake || wa < min_wake)) min_wake = wa;
   int wf = (int) getfix(n[4].x);
   if (wf >= 0 && nfds < G_WAIT_FDS_MAX) fds[nfds++] = wf; }
 if (!min_wake && !nfds) return NULL;
 uintptr_t now = g_clock();
 if (!min_wake) g_wait_fds(fds, nfds, 0);
 else if (min_wake > now) g_wait_fds(fds, nfds, min_wake - now);
 now = g_clock();
 if (my_wait_fd >= 0 && g_ready(my_wait_fd)) return NULL;
 return find_runnable(g->tasks, now); }

g_vm(g_vm_yield_sw) {
 if (g->tasks->m == g->tasks) return Ap(g_vm_yield_sw_mono, g);
 union u *next = find_runnable(g->tasks, g_clock());
 uintptr_t my_wake = g->next_wake_at;
 int my_wait_fd = g->next_wait_fd;
 if (!next) {
  next = yield_sw_wait(g, my_wake, my_wait_fd);
  if (!next) {
   g->next_wake_at = 0;
   g->next_wait_fd = -1;
   if (g->yield_ctr >= YIELD_INTERVAL) g->yield_ctr = 0;
   return Continue(); } }
 word my_height = topof(g) - Sp;
 union u *next_stack = next + 5,
       *end = (union u*) ttag(g, next_stack);
 uintptr_t restore_h = end - next_stack,
           need = my_height + restore_h + 6;
 if (Sp < Hp + need) {
  Pack(g);
  if (!g_ok(g = g_please(g_push(g, 1, next), need))) return gtrap(g);
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
 N[3].x = putfix((intptr_t) my_wake);
 N[4].x = putfix(my_wait_fd);
 memcpy(N + 5, Sp, my_height * sizeof(word));
 prev->m = tagthd(N, 5 + my_height);
 g->yield_ctr = 0;
 g->tasks = next;
 Sp = memmove(topof(g) - restore_h, next_stack, restore_h * sizeof(word));
 Ip = next[1].m;
 return Continue(); }

g_vm(g_vm_yield_nif) { return Ip++, Ap(g_vm_yield_sw, g); }
g_vm(g_vm_task_exit) { return Ap(g_vm_yield_sw, g); }
static union u const spawn_body[] = { {g_vm_ap}, {.ap = g_vm_task_exit} };
g_vm(g_vm_spawn) {
 Have(8);
 // New task node N: [next, saved_ip=spawn_body, pid, wake_at=0, wait_io=0, stack[0..1]=x,fn, tag]
 union u *N = (union u*) Hp;
 Hp += 8;
 word fn = Sp[0], x = Sp[1];
 uintptr_t pid = ++g->next_pid;
 N[0].m = g->tasks->m;
 N[1].m = (union u*) spawn_body;
 N[2].x = Sp[1] = putfix(pid);
 N[3].x = nil;         // wake_at: sentinel for "always runnable"
 N[4].x = putfix(-1);  // wait_fd: -1 = not waiting on I/O
 N[5].x = x;
 N[6].x = fn;
 g->tasks->m = tagthd(N, 7);
 return Sp++, Ip++, Continue(); }

g_vm(g_vm_wait) {
 word pid_arg = Sp[0], ret = nil;
 intptr_t target = getfix(pid_arg);
 for (union u *node = g->tasks->m; node != g->tasks; node = node->m) {
  if (getfix(node[2].x) != target) continue;
  if (node[1].m->ap == g_vm_task_exit) {
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
  return Ap(g_vm_yield_sw, g); }
 return *Sp = ret, Ip++, Continue(); }

g_vm(g_vm_donep) {
 word pid_arg = Sp[0], result = putfix(1);
 intptr_t target = getfix(pid_arg);
 for (union u *node = g->tasks->m; node != g->tasks; node = node->m)
  if (getfix(node[2].x) == target) {
   if (node[1].m->ap != g_vm_task_exit) result = nil;
   break; }
 Sp[0] = result;
 Ip += 1;
 return Continue(); }

g_vm(g_vm_kill) {
 word pid_arg = Sp[0], result = nil;
 intptr_t target = getfix(pid_arg);
 union u *prev = g->tasks;
 for (union u *node = prev->m; node != g->tasks; prev = node, node = node->m)
  if (getfix(node[2].x) == target) {
   prev->m = node->m;
   result = putfix(1);
   break; }
 Sp[0] = result;
 Ip += 1;
 return Continue(); }

g_vm(g_vm_sleep) {
 word n = Sp[0];
 Sp[0] = nil;
 Ip += 1;
 if (!fixp(n) || getfix(n) <= 0) return Continue();
 g->next_wake_at = (uintptr_t) g_clock() + getfix(n);
 return Ap(g_vm_yield_sw, g); }


g_vm(g_vm_jump) { return Ip = Ip[1].m, Continue(); }
// The only compiled truthiness branch (`?`, and the `&&`/`||` macros). Uses the
// language falsy predicate so an all-zero tuple (boxed 0.0, zero int box,
// all-zero array) takes the false arm, lifting "0 is the only false scalar".
g_vm(g_vm_cond) { return Ip = g_nilp(*Sp++) ? Ip[1].m : Ip + 2, Continue(); }
g_vm(g_vm_unc) {
 Have1();
 *--Sp = Ip[1].x;
 Ip = Ip[2].m;
 return Continue(); }

g_vm(g_vm_cur) {
 size_t const S = 3 + Width(struct g_tag);
 Have(S + 2);
 union u *k = (union u*) Hp, *j = k;
 Hp += S;
 size_t n = getfix(Ip[1].x);
 // FIXME this does not always need to be a runtime check
 if (n > 2) Hp += 2,
            j += 2,
            k[0].ap = g_vm_cur,
            k[1].x = putfix(n - 1);
 return
  j[0].ap = g_vm_unc,
  j[1].x = *Sp++,
  j[2].m = Ip + 2,
  Ip = cell(*Sp),
  Sp[0] = (word) tagthd(k, j + 3 - k),
  Continue(); }

// load instructions
//
g_vm(g_vm_quote) {
 Have1();
 Sp -= 1;
 Sp[0] = Ip[1].x;
 Ip += 2;
 return Continue(); }

// A port has no function meaning either: applying it behaves as 0 (yields 1), like
// a buf (byte-identical body, kept distinct by g_noicf -- see g_vm_buf).
g_vm(g_vm_port_io) {
  Ip = cell(*++Sp);
  *Sp = putfix(1);
  return Continue(); }

// push a value from the stack
g_vm(g_vm_arg) {
 Have1();
 Sp[-1] = Sp[getfix(Ip[1].x)];
 Sp -= 1;
 Ip += 2;
 return Continue(); }

// fused (g_vm_arg <idx> ; g_vm_ap): push local at <idx>, then apply. A 2-word op
// emitted by the compiler's `karg` when an arg ref is immediately followed by a
// non-tail ap (the dominant "call a function on a local" shape). Saves one
// dispatch + the standalone ap word vs. the unfused pair. The post-pattern
// resume address is Ip+2 (cf. g_vm_ap's Ip+1, since the op is one word longer).
g_vm(g_vm_argap) {
 if (oddp(Sp[0])) {                                  // fixnum operator -> num-ap, resume at Ip+2
  Have1();
  Sp[-1] = Sp[getfix(Ip[1].x)], Sp -= 1, Ip += 1;   // push local under operator; resume now Ip+2
  return Ap(g_vm_numap, g); }
 Have1();
 Sp[-1] = Sp[getfix(Ip[1].x)];
 Sp -= 1;
 union u *k = cell(Sp[1]); Sp[1] = word(Ip + 2), Ip = k;
 YieldCheck();
 return Continue(); }

// fused (g_vm_quote <v> ; g_vm_ap): push constant <v>, then apply. Emitted by
// kim when a quote is immediately followed by a non-tail ap (a call with a
// constant arg, e.g. (k 0)). Resume at Ip+2 (2-word op), cf. g_vm_argap.
g_vm(g_vm_quoteap) {
 if (oddp(Sp[0])) {                                  // fixnum operator -> num-ap, resume at Ip+2
  Have1();
  Sp[-1] = Ip[1].x, Sp -= 1, Ip += 1;               // push const under operator; resume now Ip+2
  return Ap(g_vm_numap, g); }
 Have1();
 Sp -= 1;
 Sp[0] = Ip[1].x;
 union u *k = cell(Sp[1]); Sp[1] = word(Ip + 2), Ip = k;
 YieldCheck();
 return Continue(); }

// fused (g_vm_arg <idx> ; g_vm_tap <fs>): push local <idx>, then tail-call,
// popping frame size <fs> at Ip[2] (tap's operand, kept in place by the fused
// emit). The single-arg tail-call shape, e.g. a tail (loop x) or cont (k v).
g_vm(g_vm_argtap) {
 if (oddp(Sp[0])) {                                  // fixnum operator -> num-ap, deliver to caller
  Have1();
  Sp[-1] = Sp[getfix(Ip[1].x)], Sp -= 1, Ip += 1;   // push local under operator; fs operand now Ip[1]
  return Ap(g_vm_numtap, g); }
 Have1();
 Sp[-1] = Sp[getfix(Ip[1].x)];
 Sp -= 1;
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getfix(Ip[2].x) + 1;
 Ip = cell(j), Sp[0] = x;
 YieldCheck();
 return Continue(); }

// operand-value-specialized arg/quote: 1-word ops with the index/constant baked
// into the handler (no Ip[1] operand fetch). Emitted by the compiler's spa/spq for
// the hottest indices {0..3} / constants {0,1,2,3,-1,-2}.
ARGN(g_vm_arg0, 0) ARGN(g_vm_arg1, 1) ARGN(g_vm_arg2, 2) ARGN(g_vm_arg3, 3)
QUON(g_vm_quo0, 0) QUON(g_vm_quo1, 1) QUON(g_vm_quo2, 2) QUON(g_vm_quo3, 3)
QUON(g_vm_quom1, -1) QUON(g_vm_quom2, -2)

g_vm(g_vm_trim) { return
 clip(g, cell(Sp[0])), Ip++, Continue(); }

g_vm(g_vm_seek) { return
 Sp[1] = word(cell(Sp[1]) + getfix(Sp[0])),
 Sp++, Ip++, Continue(); }

g_vm(g_vm_peek2) { return
 Sp[1] = (cell(Sp[1]) + getfix(Sp[0]))->x,
 Sp++, Ip++, Continue(); }

g_vm(g_vm_poke2) {
 union u *c = cell(Sp[2]) + getfix(Sp[0]);
 return c->x = Sp[1], *(Sp += 2) = word(c), Ip++, Continue(); }

g_vm(g_vm_lam) {
 size_t n = getfix(Sp[0]);
 Have(n + Width(struct g_tag));
 union u *k = (union u*) Hp;
 Hp += n + Width(struct g_tag);
 Sp[0] = word(memset(tagthd(k, n), -1, n * sizeof(word)));
 return Ip++, Continue(); }

// (len x): a total size/magnitude. Containers -> element count (string/buf bytes,
// list pairs, table keys, rank-n array shape-product). Numbers -> floored |x|
// (fixnum/box/float/complex), so it agrees with (int (abs x)); a bignum saturates
// to the nearest representable fixnum (sign-preserving). Symbol -> its name length
// (anonymous nom -> 0). Everything else (code, ports) -> 0.
// ceil a non-negative magnitude into a fixnum, saturating at FIX_MAX. ceil (not
// floor) so the result is 0 *only* when m is exactly 0 -- len then doubles as a
// zero test: (= 0 (len x)) iff x is zero/empty. Never overflows putfix's tag.
static g_inline intptr_t len_sat(g_flo_t m) {
  if (m >= (g_flo_t) FIX_MAX) return FIX_MAX;
  intptr_t i = (intptr_t) m;                    // trunc toward 0 (m >= 0)
  return i + (m > (g_flo_t) i ? 1 : 0); }       // bump for any fractional part -> ceil
// Magnitude: the SIGN-INDEPENDENT size of any value as a non-negative fixnum. A rank>=1
// array is ceil of its L2 norm; the three element families contribute their own magnitudes:
//   g_C  packed (re,im) float pairs at tuple_data -> sum all 2n floats squared
//   g_O  object words -> each element's own g_mag (recursive; depth bounded by nesting)
//   g_Z/g_R  the element values directly (tuple_get_flo)
// g_pin uses this for arrays/containers (no sign) and for g_O element norms, so a negative
// array element keeps the array truthy (matching g_all_zero's per-family magnitude scan).
static intptr_t g_mag(word x) {
  if (fixp(x)) { intptr_t n = getfix(x); return n == FIX_MIN ? FIX_MAX : n < 0 ? -n : n; }  // fixnum |x|
  if (bufp(x)) return len(buf_str(x));                          // mutable byte string
  if (mapp(x)) return map_len(x);                               // table: key count
  if (!datp(x)) return 1;                                       // opaque but present (fn / port): truthy
  switch (typ(x)) {
    default: return 1;                                          // unknown present data kind -> truthy
    case KString: return len(x);                                 // string: byte count
    case KTwo: { intptr_t l = 0; word p = x; do l++, p = B(p); while (twop(p)); return l; }  // list
    case KBig: return FIX_MAX;                                  // |bignum| > FIX_MAX: saturate
    case KSym: return pin_sym(x);                                // symbol: name length (0 if anonymous/empty)
    case KTuple: { struct g_tuple *v = tuple(x);                 // boxed scalar or rank-n array
      uintptr_t i, n = tuple_nelem(v);
      if (!v->rank) {                                            // rank-0 scalar magnitude
        if (v->type == g_C) return len_sat(cplx_mod(x));
        if (v->type == g_R) { g_flo_t r = flo_get(x); return len_sat(r < 0 ? -r : r); }
        return FIX_MAX; }                                        // g_Z int box: magnitude exceeds fixnum range
      g_flo_t s = 0;                                             // rank>=1 array -> ceil(sqrt(Σ |elem|²))
      if (v->type == g_C) { g_flo_t *re = tuple_data(v); for (i = 0; i < 2 * n; i++) s += re[i] * re[i]; }
      else if (v->type == g_O) for (i = 0; i < n; i++) { g_flo_t e = (g_flo_t) g_mag(tuple_get_obj(v, i)); s += e*e; }
      else for (i = 0; i < n; i++) { g_flo_t e = tuple_get_flo(v, i); s += e*e; }
      return len_sat(g_sqrt(s)); } } }
// The # operator: a SATURATING NON-NEGATIVE size, with negative-or-zero scalars clamped to 0
// so (nilp x) == (= 0 (len x)) and a negative real / non-positive complex is FALSE. An ordered
// scalar (fix/float/wide-int box/bignum/complex) clamps by the TOTAL ORDER (complex: re then
// im); arrays and containers have no single sign and pass straight to g_mag. Lockstep w/ g_nilp.
static intptr_t g_pin(word x) {
  if (fixp(x)) { intptr_t n = getfix(x); return n <= 0 ? 0 : n; }   // <= 0 -> 0 (0 is nil)
  if (bigp(x)) return ((struct g_big*) x)->slen < 0 ? 0 : FIX_MAX;  // negative bignum -> 0
  if (tupp(x) && !tuple(x)->rank) {                                 // boxed scalar: total-order <= 0 -> 0
    struct g_tuple *v = tuple(x);
    if (v->type == g_R) { g_flo_t r = flo_get(x); return r <= 0 ? 0 : len_sat(r); }
    if (v->type == g_C) return cplx_nonpos(x) ? 0 : len_sat(cplx_mod(x));
    return box_get(x) < 0 ? 0 : FIX_MAX; }                          // g_Z wide-int box
  return g_mag(x); }                                                // arrays / strings / lists / syms / maps / bufs / fns
g_vm(g_vm_pin) { Sp[0] = putfix(g_pin(Sp[0])); Ip += 1; return Continue(); }

// ============================================================================
// io
// ============================================================================
static g_inline bool iop(word x) { return lamp(x) && cell(x)->ap == g_vm_port_io; }
static g_inline struct g_port_vt const *port_vt(word fd_tagged) {
 intptr_t fd = getfix(fd_tagged);
 return fd >= 0 ? &g_fd_port_vt : &synth[-(fd + 1)]; }
static g_inline struct g *zgetc(struct g*g)          { return g_ok(g) ? port_vt(g->io->fd)->getc(g) : g; }
static g_inline struct g *zungetc(struct g*g, int c) { return g_ok(g) ? port_vt(g->io->fd)->ungetc(g, c) : g; }
static g_inline struct g *zputc(struct g*g, int c)   { return port_vt(g->io->fd)->putc(g, c); }
static g_inline struct g *zflush(struct g*g)         { return port_vt(g->io->fd)->flush(g); }
static g_inline struct g *zeof(struct g*g)           { return g_ok(g) ? port_vt(g->io->fd)->eof(g) : g; }
struct ci { struct g_io io; g_word head; }; // charlist input
struct to { struct g_io io; struct g_str *buf; g_word i; }; // lisp string output
static struct g *g_dtoa2(struct g*, g_flo_t);
static struct g *gfputx(struct g *g, struct g_io *o, intptr_t x);

static struct g *noop_getc(struct g *g) {
 g_core_of(g)->io->eof_seen = putfix(true);
 return g->b = EOF, g; }
static struct g *noop_ungetc(struct g *g, int c) { (void) c; return g; }
static struct g *noop_eof(struct g *g) { return g->b = true, g; }
static struct g *noop_putc(struct g *g, int c) { (void) c; return g; }
static struct g *noop_flush(struct g *g) { return g; }

static struct g *ti_eof(struct g*g) {
 struct ti *i = (struct ti*) g->io;
 return g->b = (getfix(i->io.ungetc_buf) == EOF) && getfix(i->io.eof_seen), g; }

static struct g *ti_getc(struct g*g) {
 struct ti *i = (struct ti*) g->io;
 if (getfix(i->io.ungetc_buf) != EOF) {
  int c = getfix(i->io.ungetc_buf);
  i->io.ungetc_buf = putfix(EOF);
  return g->b = c, g; }
 if (!i->t[i->i]) { i->io.eof_seen = putfix(true); return g->b = EOF, g; }
 return g->b = i->t[i->i++], g; }

static struct g *ti_ungetc(struct g*g, int c) {
 struct ti *i = (struct ti*) g->io;
 i->io.ungetc_buf = putfix(c);
 i->io.eof_seen = putfix(false);
 return g->b = c, g; }

static struct g *ci_getc(struct g *g) {
 struct ci *i = (struct ci*) g->io;
 if (getfix(i->io.ungetc_buf) != EOF) {
  int c = getfix(i->io.ungetc_buf);
  i->io.ungetc_buf = putfix(EOF);
  return g->b = c, g; }
 if (!twop(i->head)) { i->io.eof_seen = putfix(true); return g->b = EOF, g; }
 int c = getfix(A(i->head));
 i->head = B(i->head);
 return g->b = c, g; }

static struct g *to_putc(struct g *g, int c) {
 struct to *o = (struct to*) g->io;
 uintptr_t i = getfix(o->i);
 if (i >= len(o->buf)) {
  uintptr_t new_cap = len(o->buf) * 2;
  g = str0(g, new_cap);
  if (!g_ok(g)) return g;
  o = (struct to*) g->io;                 // GC may have moved it; g->out is GC-traced
  struct g_str *nb = (struct g_str*) g->sp[0];
  memcpy(txt(nb), txt(o->buf), i);
  o->buf = nb;
  g->sp++; }
 txt(o->buf)[i] = c;
 o->i = putfix(i + 1);
 return g; }
static struct g *to_flush(struct g *g) { return g; }

struct g_port_vt const synth[] = {
 /* fd = -1, ti: read-only string source */
 { ti_getc,   ti_ungetc,   ti_eof,   noop_putc, noop_flush },
 /* fd = -2, to: write-only tuple sink   */
 { noop_getc, noop_ungetc, noop_eof, to_putc,   to_flush   },
 /* fd = -3, closed port (post-close)  */
 { noop_getc, noop_ungetc, noop_eof, noop_putc, noop_flush },
 /* fd = -4, ci: read-only charlist source -- ungetc/eof read only the g_io
    fields, so ti_ungetc/ti_eof work unchanged here. */
 { ci_getc,   ti_ungetc,   ti_eof,   noop_putc, noop_flush }, };

// (fputc port byte) — write byte to port; return byte.
g_vm(g_vm_fputc) {
 if (iop(Sp[0])) {
  g->io = (struct g_io*) Sp[0];
  Pack(g);
  if (!g_ok(g = zputc(g, getfix(g->sp[1])))) return gtrap(g);
  Unpack(g); }
 return Sp++, Ip++, Continue(); }

// (fflush port) — flush; return the port.
g_vm(g_vm_fflush) {
 if (iop(Sp[0])) {
  g->io = (struct g_io*) Sp[0];
  Pack(g);
  if (!g_ok(g = zflush(g))) return gtrap(g);
  Unpack(g); }
 return Ip++, Continue(); }

// (fputs port s) — write every byte of string-or-buf s through port; return
// the port. No-op when args are misused (non-port, or neither string nor
// buf). bytes_of resolves either to the g_str holding the bytes, re-read each
// iteration so GC inside zputc (e.g., growing a sink buffer) can forward it
// safely (for a buf, GC may move both the wrapper and its backing string).
g_vm(g_vm_fputs) {
 if (iop(Sp[0]) && (strp(Sp[1]) || bufp(Sp[1]))) {
  g->io = (struct g_io*) Sp[0];
  uintptr_t i = 0, l = len(bytes_of(Sp[1]));
  Pack(g);
  while (g_ok(g) && i < l) g = zputc(g, txt(bytes_of(g->sp[1]))[i++]);
  if (!g_ok(g = zflush(g))) return gtrap(g);
  Unpack(g); }
 return Sp++, Ip++, Continue(); }

g_vm(g_vm_fputx) {
 if (iop(Sp[0])) {
  Pack(g);
  if (!g_ok(g = gfputx(g, (struct g_io*) Sp[0], Sp[1]))) return gtrap(g);
  Unpack(g); }
 return Sp++, Ip++, Continue(); }

// (dot x) -> print x to `out` and return x. A string/buf is written verbatim
// (puts discipline -- raw bytes); any other value in external form (putx
// discipline -- the inspect form). The `.` reader sigil expands to (dot x). The
// string bytes are re-read from g->sp[0] each iteration (GC inside zputc may
// forward them); gfputx is self-GC-safe over its value arg, as in g_vm_fputx.
g_vm(g_vm_dot) {
 word x = Sp[0];
 g->io = &g_stdout;
 Pack(g);
 if (strp(x) || bufp(x)) {
  uintptr_t i = 0, l = len(bytes_of(x));
  while (g_ok(g) && i < l) g = zputc(g, txt(bytes_of(g->sp[0]))[i++]);
  if (g_ok(g)) g = zflush(g); }
 else g = gfputx(g, &g_stdout, x);
 if (!g_ok(g)) return gtrap(g);
 Unpack(g);
 return Ip++, Continue(); }

static struct g*gfputn(struct g *g, intptr_t n, uint8_t b, struct g_io *o);
g_vm(g_vm_fputn) {
 if (iop(Sp[0])) {
   Pack(g);
   if (!g_ok(g = gfputn(g, getfix(Sp[1]), getfix(Sp[2]), (struct g_io*) Sp[0]))) return gtrap(g);
   Unpack(g);
   Sp[2] = Sp[1]; }
 return Sp += 2, Ip++, Continue(); }

static struct g*gzputc(struct g*g, int c) {
  return port_vt(g_core_of(g)->io->fd)->putc(g, c); }
static struct g*gzputs(struct g*g, char const *s) {
 while (*s) g = gzputc(g, *s++);
 return g; }

static struct g*gzputn(struct g *g, intptr_t n, uint8_t b) {
 uintptr_t
  m = n >= 0 || b != 10 ? (uintptr_t) n : (g = gzputc(g, '-'), -(uintptr_t) n),
  q = m / b,
  r = m % b;
 if (q) g = gzputn(g, q, b);
 return gzputc(g, g_digits[r]); }

static g_inline struct g*gfputn(struct g *g, intptr_t n, uint8_t b, struct g_io *o) {
 return g->io = o, gzputn(g, n, b); }

static struct g*gvzprintf(struct g*g, char const *fmt, va_list xs) {
 for (int c; (c = *fmt++);) {
  if (c != '%') g = gzputc(g, c);
  else pass: switch ((c = *fmt++)) {
   case 0: return g;
   case 'l': goto pass;
   case 'b': g = gzputn(g, va_arg(xs, uintptr_t), 2); continue;
   case 'n': g = gzputn(g, va_arg(xs, uintptr_t), 6); continue;
   case 'o': g = gzputn(g, va_arg(xs, uintptr_t), 8); continue;
   case 'd': g = gzputn(g, va_arg(xs, uintptr_t), 10); continue;
   case 'u': g = gzputn(g, va_arg(xs, uintptr_t), 12); continue;
   case 'x': g = gzputn(g, va_arg(xs, uintptr_t), 16); continue;
   case 'z': g = gzputn(g, va_arg(xs, uintptr_t), 36); continue;
   case '%': g = gzputc(g, '%'); continue;             // %% -> literal %
   default: g = gzputc(g, c); } }
 return g; }

static struct g *gzprintf(struct g *g, char const *fmt, ...) {
 va_list xs;
 va_start(xs, fmt);
 g = gvzprintf(g, fmt, xs);
 va_end(xs);
 return g; }

static struct g *gzputx(struct g *g, intptr_t x, uintptr_t off);
static struct g *gzputcs(struct g *g, char const *s);

// --- print cycle detection (tables only) --------------------------------------
// A "seen" list of the tables on the current print path lives in a single stack
// slot at the bottom of the print region (established by gfputx). It moves with
// the stack on GC, so callers locate it by its offset from the stack top (`off`),
// which GC preserves; the offset is threaded down the recursion as an ordinary
// integer (no struct-g state). A table is consed on as we descend into it and
// dropped as we ascend, so the list is exactly the ancestor path of tables. When
// printing finishes gfputx restores the original stack height, discarding it.
static word *seen_slot(struct g *g, uintptr_t off) {
 return topof(g_core_of(g)) - off; }
static bool seen_member(struct g *g, uintptr_t off, word x) {
 for (word l = *seen_slot(g, off); twop(l); l = B(l)) if (A(l) == x) return true;
 return false; }
static struct g *seen_push(struct g *g, uintptr_t off, word x) {   // cons x onto seen
 if (!g_ok(g = g_push(g, 1, x))) return g;                         // protect x across GC
 if (!g_ok(g = g_have(g, Width(struct g_pair)))) return g_pop(g, 1);
 struct g_pair *p = bump(g, Width(struct g_pair));
 word *slot = seen_slot(g, off);                                   // re-read: GC may move it
 ini_two(p, g->sp[0], *slot);
 *slot = (word) p;
 return g_pop(g, 1); }
static void seen_pop(struct g *g, uintptr_t off) {                 // drop the newest entry
 word *slot = seen_slot(g, off);
 *slot = B(*slot); }

static g_inline struct g*gzput_two(struct g*g, word _, uintptr_t off) {
 if (!g_ok(g = g_push(g, 1, _))) return g;
 struct g_str *n;
 // a one-operand `\` pair (`(\ x)`) is quote -> print as 'x; ≥2 operands is a lambda.
 if (symp(A(g->sp[0])) && (n = sym(A(g->sp[0]))->nom) && len(n) == 1 && txt(n)[0] == '\\'
     && twop(B(g->sp[0])) && !twop(BB(g->sp[0]))) {
  g = gzputc(g, '\'');                          // GC here may relocate sp[0]; read AB after
  g = gzputx(g, AB(g->sp[0]), off); }
 else for (g = gzputc(g, '(');; g = gzputc(g, ' '), g->sp[0] = B(g->sp[0])) {
  g = gzputx(g, A(g->sp[0]), off);            // off threaded so nested tables are still tracked
  if (!twop(B(g->sp[0]))) { g = gzputc(g, ')'); break; } }
 return g_pop(g, 1); }


// Print element i of the array parked at g->sp[0] as a bare number (float ->
// g_dtoa, integer -> base 10). The element value is read before any gzputc, so
// a GC during printing (string-port growth) that relocates the array is safe;
// callers re-fetch tuple(g->sp[0]) each call for the same reason.
static struct g *gzput_tuple_elem(struct g *g, uintptr_t i) {
 struct g_tuple *v = tuple(g->sp[0]);
 if (v->type >= g_R)
  return g_dtoa2(g, tuple_get_flo(v, i));
 return gzputn(g, tuple_get_int(v, i), 10); }

// Print element i of a packed g_C array (at g->sp[0]) as ~(re im) -- the same
// read-back form as a complex scalar (the `~` reader macro splices into (com …)).
// re/im are copied to C locals before any gzputc/g_dtoa2 (which may grow a string
// port and relocate the array).
static struct g *gzput_carr_elem(struct g *g, uintptr_t i) {
 g_flo_t *fp = tuple_data(tuple(g->sp[0]));
 g_flo_t re = fp[2*i], im = fp[2*i+1];
 g = gzprintf(g, "~("); g = g_dtoa2(g, re); g = gzputc(g, ' ');
 g = g_dtoa2(g, im); return gzputc(g, ')'); }

// element-kind code -> a prelude symbol bound to it, so the printed `arrl` form
// round-trips: Z prints as the `i64` alias, R as `f64`. `c` only labels the
// 32-bit RNG state tuple (never a constructible array -- arrl rejects ty > R).
static char const *const g_vt_names[] = {
 [g_Z] = "i64", [g_R] = "f64", [g_C] = "c", [g_O] = "o" };

// Print a rank>=1 array (g->sp[0]) as a constructor expression that reads back to
// the same array. A rank-1 i64/f64 array uses the terse `@(a b …)` sugar (the `@`
// reader macro splices into `(tuple a b …)`, which infers i64/f64 from its args);
// anything else (rank>=2, or an object array whose elements are arbitrary, quoted
// values) uses `(arrl <type> '(shape) '(vals))`, a bare constructor call that pins
// the exact element type and shape. The array may move on a GC during printing, so
// shape/elements are re-fetched from g->sp[0] each step.
static g_noinline struct g *gzputx(struct g *g, intptr_t x, uintptr_t off);

static struct g *gzput_arr(struct g *g, uintptr_t off) {
 struct g_tuple *v = tuple(g->sp[0]);
 uintptr_t rank = v->rank, type = v->type, nelem = tuple_nelem(v);
 if (rank == 1 && nelem == 0 && (type == g_Z || type == g_R))
  return gzputcs(g, "@0");                             // empty numeric -> @0 (reads back via @0/@())
 if (rank == 1 && nelem > 0 && (type == g_Z || type == g_R || type == g_C)) {  // terse rank-1: @(…)
  g = gzputc(g, '@'); g = gzputc(g, '(');              // a complex elem prints as ~(re im)
  for (uintptr_t i = 0; g_ok(g) && i < nelem; i++) {
   if (i) g = gzputc(g, ' ');
   g = type == g_C ? gzput_carr_elem(g, i) : gzput_tuple_elem(g, i); }
  return g_ok(g) ? gzputc(g, ')') : g; }
 if (type == g_C) {                                    // rank>=2 / empty complex: (array '(shape) ~(…)…)
  g = gzprintf(g, "(array '(");                        // array's trailing args are evaluated -> a-type
  for (uintptr_t i = 0; g_ok(g) && i < rank; i++) {    // infers c, so the ~(…) elems pack back exactly
   if (i) g = gzputc(g, ' ');
   g = gzputn(g, tuple(g->sp[0])->shape[i], 10); }
  g = gzputc(g, ')');
  for (uintptr_t i = 0; g_ok(g) && i < nelem; i++) {
   g = gzputc(g, ' '); g = gzput_carr_elem(g, i); }
  return g_ok(g) ? gzputc(g, ')') : g; }
 g = gzprintf(g, "(arrl ");                            // explicit: (arrl type '(shape) '(vals))
 for (char const *s = g_vt_names[type]; g_ok(g) && *s; s++) g = gzputc(g, *s);
 g = gzprintf(g, " '(");
 for (uintptr_t i = 0; g_ok(g) && i < rank; i++) {
  if (i) g = gzputc(g, ' ');
  g = gzputn(g, tuple(g->sp[0])->shape[i], 10); }
 g = gzprintf(g, ") '(");
 for (uintptr_t i = 0; g_ok(g) && i < nelem; i++) {    // object elements via the general
  if (i) g = gzputc(g, ' ');                           // printer; numeric via gzput_tuple_elem
  g = type == g_O ? gzputx(g, tuple_get_obj(tuple(g->sp[0]), i), off) : gzput_tuple_elem(g, i); }
 return g_ok(g) ? gzprintf(g, "))") : g; }

static g_inline struct g*gzput_tuple_scalar_float(struct g*g) {
 return g_dtoa2(g, (g_flo_t) flo_get(g->sp[0])); }

// complex -> ~(re im); round-trips by re-evaluation (the `~` reader macro splices
// into (com re im), and com is a nif). re/im are read into C locals up front so a
// GC during g_dtoa2 can't strand the operand.
static g_inline struct g*gzput_tuple_scalar_complex(struct g*g) {
 g_flo_t re = cplx_re(g->sp[0]), im = cplx_im(g->sp[0]);
 g = gzprintf(g, "~(");
 g = g_dtoa2(g, re);
 g = gzputc(g, ' ');
 g = g_dtoa2(g, im);
 return gzputc(g, ')'); }

static g_inline struct g*gzput_tuple(struct g*g, word _, uintptr_t off) {
 intptr_t rank = tuple(_)->rank, type = tuple(_)->type;
 if (!g_ok(g = g_push(g, 1, _))) return g;
 if (rank == 0 && type == g_R) g = gzput_tuple_scalar_float(g);
 else if (rank == 0 && type == g_Z) g = gzputn(g, box_get(g->sp[0]), 10);
 else if (rank == 0 && type == g_C) g = gzput_tuple_scalar_complex(g);
 else if (rank >= 1) g = gzput_arr(g, off);
 else g = gzprintf(g, ",tuple@%z:%d.%d", tuple(g->sp[0]), type, rank);
 return g_pop(g, 1); }

static g_inline struct g*gzput_str(struct g*g, word _) {
 uintptr_t slen = len(_);
 g = gzputc(g_push(g, 1, _), '"');
 for (uintptr_t i = 0; g_ok(g) && i < slen; i++) {
  char c = txt(g->sp[0])[i];
  if (c == '\\' || c == '"') g = gzputc(g, '\\');
  else if (c == '\n') g = gzputc(g, '\\'), c = 'n';
  else if (c == '\t') g = gzputc(g, '\\'), c = 't';
  else if (c == '\r') g = gzputc(g, '\\'), c = 'r';
  else if (c == '\0') g = gzputc(g, '\\'), c = '0';
  else if ((unsigned char) c < 32)
   g = gzputc(gzputc(gzputc(g, '\\'), 'x'), g_digits[(c >> 4) & 0xf]),
   c = g_digits[c & 0xf];
  g = gzputc(g, c); }
 return g_pop(gzputc(g, '"'), 1); }

// A symbol's nom encodes its kind: 0 = anonymous nom, a string = interned, a
// symbol = named-uninterned (the naming symbol, whose own nom is the name string).
// Interned syms print bare; the empty symbol as `()` (round-trips); gensyms get
// the `$` sigil (the `$` reader macro wraps its operand with nom): a
// named-uninterned nom as `$<name>` (re-reads to a fresh nom of the same name),
// an anonymous one as `$<addr>` (unique, doesn't round-trip to identity -- the
// addr just makes the printout distinguishable).
static g_inline struct g*gzput_sym(struct g*g, word _) {
 if (_ == EMPTY_SYM) return gzprintf(g, "()");
 if (g_ok(g = g_push(g, 1, _))) {
  word nom = word(sym(g->sp[0])->nom);
  if (!nom) g = gzprintf(g, "$%z", g->sp[0]);              // anonymous nom -> $<addr>
  else if (strp(nom)) {                                     // interned: bare name
   g->sp[0] = nom;
   for (uintptr_t l = len(nom), i = 0; g_ok(g) && i < l;)
     g = gzputc(g, txt(g->sp[0])[i++]);
  } else {                                                  // named-uninterned -> $<name>
   word name = word(sym(nom)->nom);
   if (!name || !strp(name)) g = gzprintf(g, "$%z", g->sp[0]); // named after a nameless sym: fall back
   else {
    g = gzputc(g, '$');
    g->sp[0] = name;
    for (uintptr_t l = len(name), i = 0; g_ok(g) && i < l;)
        g = gzputc(g, txt(g->sp[0])[i++]); } } }
 return g_pop(g, 1); }


// Maps print as %(k v …), round-tripping through the %( reader, like hashes.
// A map is mutable and can hold itself, so guard the recursion with the seen
// list. Snapshot k/v into a list first (printing may GC and move the map).
static g_inline struct g*gzput_map(struct g*g, word x, uintptr_t off) {
 if (seen_member(g, off, x)) return gzputcs(g, "<cycle>");
 if (!g_ok(g = seen_push(g, off, x))) return g;        // sp[0] = seen list head (= x)
 x = A(*seen_slot(g, off));                             // reload x: seen_push may have GC'd
 if (!g_ok(g = g_push(g, 1, x))) return seen_pop(g, off), g;   // sp[0] = map
 uintptr_t cap = map_cap(g->sp[0]), n = map_len(g->sp[0]);
 if (!g_ok(g = g_have(g, n * 2 * Width(struct g_pair)))) return seen_pop(g_pop(g, 1), off), g;
 word *s = map_slots(g->sp[0]);                         // re-fetch after possible GC
 struct g_pair *p = bump(g, n * 2 * Width(struct g_pair));
 word list = nil;
 for (uintptr_t i = cap; i;)
  if (s[2 * --i] != MAP_GAP) {
   struct g_pair *kv = p++;
   ini_two(kv, s[2 * i], s[2 * i + 1]);                 // (k . v)
   ini_two(p, (word) kv, list), list = (word) p++; }    // cons onto the snapshot
 fs0(g) = list;
 if (!twop(fs0(g))) g = gzputcs(g, "%0");              // empty map prints %0 (reads back via %0/%())
 else {
  if (g_ok(g = gzprintf(g, "%%("))) for (bool sp = false;;) {
   if (sp) g = gzputc(g, ' ');
   sp = true;
   g = gzputx(g, AA(g_core_of(g)->sp[0]), off);
   g = gzputc(g, ' '); g = gzputx(g, BA(g_core_of(g)->sp[0]), off);
   g_core_of(g)->sp[0] = B(g_core_of(g)->sp[0]);
   if (!g_ok(g) || !twop(g->sp[0])) break; }
  g = g_ok(g) ? gzputc(g, ')') : g; }
 g = g_pop(g, 1);
 return seen_pop(g, off), g; }

// A bignum prints in base 10 (with sign). g_big_dec renders it to a fresh
// string (repeated divide-by-10 of a heap-local copy); we then emit the bytes,
// re-fetching sp[0] each step since gzputc may grow a string port and GC.
static g_inline struct g*gzput_big(struct g*g, word x) {
 if (!g_ok(g = g_push(g, 1, x))) return g;
 g = g_big_dec(g);
 for (uintptr_t i = 0, n = g_ok(g) ? len(g->sp[0]) : 0; g_ok(g) && i < n; i++)
  g = gzputc(g, txt(g->sp[0])[i]);
 return g_pop(g, 1); }

// emit a C string literal byte-for-byte.
static struct g *gzputcs(struct g *g, char const *s) {
 for (; g_ok(g) && *s; s++) g = gzputc(g, *s);
 return g; }

// --- partial-application introspection (mirrors kernel/vm.c g_vm_cur/g_vm_unc) ---
// A partial-app closure is a thread whose head is g_vm_unc (one more arg wanted)
// or [g_vm_cur n][g_vm_unc …] (more wanted). Each g_vm_unc cell holds a captured
// arg at [1] and a link at [2] that points either to the next (older) closure's
// unc cell or, for the last one, two cells into the underlying function's body --
// so the base function value is terminal_link-2 and the captured args are the
// chain of [1] fields, newest first. The chain survives GC (interior pointers are
// relocated), so callers re-walk from the parked, possibly-moved closure.
static bool fn_partialp(union u *k) {
 return k[0].ap == g_vm_unc || (k[0].ap == g_vm_cur && k[2].ap == g_vm_unc); }
static g_inline union u *fn_unc0(union u *k) {
 return k[0].ap == g_vm_cur ? k + 2 : k; }       // first unc cell
static union u *fn_base(union u *k, int *nargs) { // base value + captured-arg count
 union u *u = fn_unc0(k), *link;
 int n = 0;
 for (;;) { link = u[2].m; n++; if (link[0].ap != g_vm_unc) break; u = link; }
 return *nargs = n, link - 2; }
static word fn_arg(union u *k, int i, int nargs) { // i-th arg in application order
 union u *u = fn_unc0(k);
 for (int w = nargs - 1 - i; w > 0; w--) u = u[2].m;
 return u[1].x; }

static struct g *gzput_fn_body(struct g *g, word x, uintptr_t off);

// the in-pool source \-expr stashed at value[-1] by a compiled lambda, or 0.
// Only an ala/k0s lambda reserves that leading cell, so its value pointer sits one past
// the allocation start. A k0 top-level wrap, a partial-app (g_vm_cur/unc), a continuation,
// or an opaque handle puts its value AT the start -- no leading cell -- so reading value[-1]
// there reads the neighbouring object: uninitialised/foreign (flaky to valgrind, and garbage
// that looked like an in-pool pair would spuriously read back as a source). Probe the tag,
// which records the true start, instead of reading value[-1]: ttag scans only defined thread
// cells. value > start <=> a reserved leading cell exists. (fn_partialp is a cheap fast
// reject so the common curried-closure case skips the tag scan.)
static word fn_src(struct g *c, union u *k, word x) {
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
// gz_canon rebuilds the source with bound syms replaced: it pre-interns the
// d<lvl> names and pre-reserves the cell count, so the rebuild itself allocates
// nothing and cannot GC -- pointers into the parked source stay stable. The
// names are interned plain symbols (d0,d1,…) so the printed form round-trips.
struct gz_bv { word sym; uintptr_t lev; struct gz_bv *up; };  // a \-binder in scope
static g_inline bool gz_lamhead(word a) {                     // is a the symbol \ ?
 struct g_str *nm;
 return symp(a) && (nm = sym(a)->nom) && strp(word(nm)) && len(nm) == 1 && txt(nm)[0] == '\\'; }
static g_inline bool gz_islam(word x) {                       // (\ b.. body): >=2 operands
 return twop(x) && gz_lamhead(A(x)) && twop(B(x)) && twop(BB(x)); }
static g_inline bool gz_isquote(word x) {                     // (\ datum): exactly 1 operand
 return twop(x) && gz_lamhead(A(x)) && twop(B(x)) && !twop(BB(x)); }
static uintptr_t gz_cells(word x) {                           // pairs the rebuild will bump
 return !twop(x) || gz_isquote(x) ? 0 : 1 + gz_cells(A(x)) + gz_cells(B(x)); }
static uintptr_t gz_depth(word x, uintptr_t d) {              // max binder level + 1 (= # d-syms)
 if (!twop(x) || gz_isquote(x)) return d;
 if (gz_islam(x)) {
  word o = B(x); uintptr_t nb = 0;
  while (twop(B(o))) nb++, o = B(o);                          // every operand but the last = a binder
  uintptr_t here = d + nb, body = gz_depth(A(o), here);
  return here > body ? here : body; }
 uintptr_t a = gz_depth(A(x), d), b = gz_depth(B(x), d);
 return a > b ? a : b; }
static word gz_build_ops(struct g *g, word o, struct gz_bv *sc, uintptr_t d, uintptr_t D);
static word gz_build(struct g *g, word x, struct gz_bv *sc, uintptr_t d, uintptr_t D) {
 if (!twop(x)) {                                              // atom: a bound sym -> d<lev>, else as-is
  if (symp(x)) for (struct gz_bv *p = sc; p; p = p->up) if (p->sym == x) return g->sp[D - 1 - p->lev];
  return x; }
 if (gz_isquote(x)) return x;                                 // quoted data: share, do not descend
 word a, b;
 if (gz_islam(x)) a = A(x), b = gz_build_ops(g, B(x), sc, d, D);  // share \, rename the operand spine
 else a = gz_build(g, A(x), sc, d, D), b = gz_build(g, B(x), sc, d, D);
 struct g_pair *p = bump(g, Width(struct g_pair));
 return ini_two(p, a, b), (word) p; }
static word gz_build_ops(struct g *g, word o, struct gz_bv *sc, uintptr_t d, uintptr_t D) {
 word car, rest;
 if (!twop(B(o))) car = gz_build(g, A(o), sc, d, D), rest = nil;  // last operand = the body
 else { struct gz_bv fr = { A(o), d, sc };                        // a binder, level d, in scope for the rest
        car = g->sp[D - 1 - d], rest = gz_build_ops(g, B(o), &fr, d + 1, D); }
 struct g_pair *p = bump(g, Width(struct g_pair));
 return ini_two(p, car, rest), (word) p; }
// sp[0] = a lambda's source \-expr; replace it with the de Bruijn-renamed copy.
static struct g *gz_canon(struct g *g) {
 word s = g->sp[0];
 if (!gz_islam(s)) return g;                                  // not a lambda -> leave as-is
 uintptr_t P = gz_cells(s), D = gz_depth(s, 0);
 for (uintptr_t i = 0; i < D; i++) {                          // push d0,d1,… (de Bruijn level); src parked below
  char b[24], *e = b + sizeof b; uintptr_t n = i;            // interned d<lvl> -> reads back as the same sym
  *--e = 0;
  do { *--e = '0' + n % 10; } while (n /= 10);
  *--e = 'd';
  if (!g_ok(g = intern(g_strof(g, e)))) return g; }
 if (!g_ok(g = g_have(g, P * Width(struct g_pair)))) return g;  // reserve cells: the last possible GC
 word r = gz_build(g, g->sp[D], 0, 0, D);                     // alloc-free, GC-free; g->sp stays put
 return g->sp[D] = r, g->sp += D, g; }

// Print a function value. Like tuple/cplx/hash it's a `,`-prefixed value form (so it
// reads back via uq=identity): ,(base arg…) for a partial application / closure,
// ,name for a builtin, ,(\ …) for a compiled lambda (its stored source). An opaque
// thread (continuation, top-level wrap) has no constructor form, so it prints as the
// opaque, re-parsable token ,thd@<addr>. The leading , is emitted once here; body w/o it.
static struct g *gzput_fn(struct g *g, word x, uintptr_t off) {
 union u *k = cell(x);
 bool reprp = fn_partialp(k) || g_nif_name(x) || fn_src(g_core_of(g), k, x);
 return reprp ? gzput_fn_body(g, x, off) : gzprintf(g, "\\%z", x); }

// Render a function as a bare constructor expression (NO leading ,). Detection
// order matters: a bare multi-arg lambda and a partial-app both have a g_vm_cur
// head, and a nif's value[-1] is undefined static data. The partial-app base
// recurses here (not gzput_fn) so it doesn't get its own comma.
static struct g *gzput_fn_body(struct g *g, word x, uintptr_t off) {
 struct g *c = g_core_of(g);
 union u *k = cell(x);
 if (fn_partialp(k)) {                              // (base arg…)
  if (!g_ok(g = g_push(g, 1, x))) return g;         // park: GC relocates the closure
  int na; fn_base(cell(g->sp[0]), &na);
  g = gzputc(g, '(');
  { union u *bk = cell(g->sp[0]); int n2;           // base re-derived after each gzputc
    g = gzput_fn_body(g, (word) fn_base(bk, &n2), off); }
  for (int i = 0; g_ok(g) && i < na; i++) {
   g = gzputc(g, ' ');                              // separate stmt: re-read arg after GC
   g = gzputx(g, fn_arg(cell(g->sp[0]), i, na), off); }
  return g_pop(g_ok(g) ? gzputc(g, ')') : g, 1); }
 char const *nm = g_nif_name(x);                    // builtin -> name
 if (nm) return gzputcs(g, nm);
 word s = fn_src(c, k, x);                          // compiled lambda -> source \-expr
 if (!s) return gzprintf(g, "\\%z", x);
 if (!g_ok(g = g_push(g, 1, s))) return g;          // park source across gz_canon's allocs
 g = gz_canon(g);                                   // sp[0] := de Bruijn-renamed copy
 if (g_ok(g)) g = gzputx(g, g->sp[0], off);
 return g_ok(g) ? g_pop(g, 1) : g; }

static g_noinline struct g *gzputx(struct g *g, intptr_t x, uintptr_t off) {
 if (fixp(x)) return gzprintf(g, "%d", getfix(x));
 if (!datp(x)) return mapp(x) ? gzput_map(g, x, off) : gzput_fn(g, x, off);
 // Maps are the only mutable/self-referential value, and gzput_map guards its
 // own recursion (the seen list); the data kinds below are acyclic.
 switch (typ(x)) {
   default: __builtin_trap();
   case KTwo:  return gzput_two(g, x, off);
   case KTuple:  return gzput_tuple(g, x, off);
   case KSym:  return gzput_sym(g, x);
   case KString: return gzput_str(g, x);
   case KBig:  return gzput_big(g, x); } }

// Establish a fresh seen-list slot at the bottom of the print region, print, then
// restore the original stack height (discarding the slot and the whole list).
static g_inline struct g *gfputx(struct g *g, struct g_io *o, intptr_t x) {
 struct g *c = g_core_of(g);
 c->io = o;
 uintptr_t base = topof(c) - c->sp;                 // original height (GC-invariant)
 if (!g_ok(g = g_push(g, 1, nil))) return g;        // the seen-list slot
 c = g_core_of(g);
 g = gzputx(g, x, topof(c) - c->sp);                // offset of the slot from the top
 c = g_core_of(g);
 return c->sp = topof(c) - base, g; }               // restore original stack height

// AI slop alert....
//

static struct g* g_dtoa2(struct g*g, g_flo_t v) {
 int const max_frac = sizeof(g_flo_t) == 4 ? 7 : 15;
 if (v != v) return gzputs(g, "nan");
 if (v < 0) g = gzputc(g, '-'), v = -v;
 if (v > DTOA_INF) return gzputs(g, "inf");
 int exp = 0;
 bool sci = false;
 if (v != 0 && (v >= DTOA_SCI_HI || v < DTOA_SCI_LO)) {
  sci = true;
  while (v >= 10) v /= 10, exp++;
  while (v < 1)  v *= 10, exp--; }
 // integer part, lsb-first then reversed
 word ip = (word) v;
 g_flo_t frac = v - (g_flo_t) ip;
 char ib[24];
 int ib_n = 0;
 if (ip == 0) ib[ib_n++] = '0';
 while (ip) ib[ib_n++] = '0' + ip % 10, ip /= 10;
 while (ib_n > 0) g = gzputc(g, ib[--ib_n]);
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
   g = gzputc(g, '.');
   for (int i = 0; i < fb_n; i++) g = gzputc(g, fb[i]); } }
 if (sci) {
  g = gzputc(g, 'e');
  if (exp < 0) g = gzputc(g, '-'), exp = -exp;
  char eb[8]; int eb_n = 0;
  if (exp == 0) eb[eb_n++] = '0';
  while (exp) eb[eb_n++] = '0' + exp % 10, exp /= 10;
  while (eb_n > 0) g = gzputc(g, eb[--eb_n]); }
 return g; }

// (feof port) — -1 if at end of stream, nil otherwise.
g_vm(g_vm_feof) {
 if (iop(Sp[0])) {
  g->io = (struct g_io*) Sp[0];
  Pack(g);
  if (!g_ok(g = zeof(g))) return gtrap(g);
  Unpack(g);
  Sp[0] = g->b ? putfix(1) : nil; }
 return Ip++, Continue(); }

// (fgetc port) — like (getc _) but on an explicit port. Cooperative wait
// uses the port's own fd.
g_vm(g_vm_fgetc) {
 if (iop(Sp[0])) {
  struct g_io *i = (struct g_io*) Sp[0];
  if (!g_ready(getfix(i->fd))) {
   g->next_wait_fd = getfix(i->fd);
   return Ap(g_vm_yield_sw, g); }
  Pack(g);
  g->io = i;
  if (!g_ok(g = zgetc(g))) return gtrap(g);
  Unpack(g);
  Sp[0] = putfix(g->b); }
 return Ip++, Continue(); }

// (fungetc port byte) — push back one byte, return the byte.
g_vm(g_vm_fungetc) {
 if (iop(Sp[0])) {
  struct g_io *i = (struct g_io*) Sp[0];
  Pack(g);
  g->io = i;
  if (!g_ok(g = zungetc(g, getfix(g->sp[1])))) return gtrap(g);
  Unpack(g); }
 return Sp++, Ip++, Continue(); }

// Finalizer for heap stream ports: extract the fd and ask the frontend to
// close it. Runs inside GC (run_finalizers); fz->p still points at the
// from-space port so its fields are readable. Skip if fd < 0 — that means
// either the port was already closed explicitly (fd mutated to a synth
// sentinel) or the caller wrapped a non-OS fd.
static void io_close(void *p) {
 intptr_t fd = getfix(((struct g_io*)p)->fd);
 if (fd >= 0) g_fd_close(fd); }

// Heap-allocate a stream port for the given OS fd. Pushes the port pointer
// on Sp[0] and registers io_close as its finalizer. The fd >= 0 path of
// the dispatcher routes through g_fd_port_vt, so the host's read/write
// methods see this port like any other.
struct g *g_io_alloc(struct g *g, int fd) {
 uintptr_t const n = Width(struct g_io);
 if (g_ok(g = g_have(g, n + Width(struct g_tag) + Width(struct g_fz) + 1))) {
  union u *k = bump(g, n + Width(struct g_tag));
  struct g_io *io = (struct g_io*) k;
  io->ap = g_vm_port_io;
  io->fd = putfix(fd);
  io->ungetc_buf = putfix(EOF);
  io->eof_seen = putfix(false);
  *--g->sp = (word) tagthd(k, n);            // stack slot reserved by the +1 in have()
  struct g_fz *z = bump(g, Width(struct g_fz));
  z->p = k, z->fn = io_close, z->next = g->fz, g->fz = z; }
 return g; }

static struct g *grbufg(struct g *g, uintptr_t len);

// A token is a plain decimal integer iff it is [+-]?[0-9]+ with no leading-zero
// prefix (so "0x.." hex and "0.." octal stay with strtol, and bare "0" parses
// as decimal). These read at full precision through g_big_read_dec.
static g_inline bool is_dec_int(char const *s, uintptr_t n) {
 uintptr_t i = (n && (s[0] == '-' || s[0] == '+')) ? 1 : 0;
 if (i >= n) return false;                       // a lone sign is a symbol
 if (s[i] == '0' && n - i > 1) return false;     // leading zero -> let strtol decide
 for (; i < n; i++) if (s[i] < '0' || s[i] > '9') return false;
 return true; }

static struct g *gz_parse(struct g *g, bool multi);
static g_inline struct g *gzread1sym(struct g*g, int c), *gzread1str(struct g*g);
struct g *g_reads(struct g *g, struct g_io* i) { return g_core_of(g)->io = i, gz_parse(g, true); }
struct g *g_read1(struct g*g, struct g_io *i) { return g_core_of(g)->io = i, gz_parse(g, false); }

static struct g *grbufg(struct g *g, uintptr_t len) {
 if (g_ok(g = str0(g, 2 * len)))
  memcpy(txt(g->sp[0]), txt(g->sp[1]), len),
  g->sp[1] = g->sp[0],
  g->sp++;
 return g; }

static g_noinline double strtod_wrap(struct g*g, word x) {
 struct g_str *s = str(x);
 if (!strp(x) || !s->len) return NAN;
 char *e, *b = off_pool(g);
 memcpy(b, s->bytes, s->len);
 b[s->len] = 0;
 double r = strtod(b, &e);
 return e != b && *e == 0 ? (g_flo_t) r : (g_flo_t) NAN; }

// (flo s) — parse a ll string as a decimal float. Returns a rank-0
// f64 box if the entire string parses, else nil. Used by the ll-side
// reader in repl.l to match the C reader's strtol → strtod → intern
// cascade on float-shaped tokens.
g_vm(g_vm_flo) {
 word x = Sp[0];
 double d = strtod_wrap(g, x);
 if (d != d) return Sp[0] = nil, Ip += 1, Continue();
 uintptr_t req = b2w(sizeof(struct g_tuple) + sizeof(g_flo_t));
 Have(req);
 struct g_tuple *r = ini_scalar((struct g_tuple*) Hp, g_R);
 Hp += req;
 flo_put(r->shape, (g_flo_t) d);
 Sp[0] = word(r);
 return Ip++, Continue(); }

g_vm(g_vm_fread) {
 Ip++;
 if (!iop(Sp[0])) return Sp++, Continue();
 struct g_io *i = (struct g_io*) Sp[0];
 uintptr_t depth = topof(g) - Sp;
 Pack(g);
 if (g_ok(g = g_read1(g, i))) g->sp[2] = g->sp[0], g->sp += 2;
 else {
  struct g *c = g_core_of(g); // reset stack on parse fail
  c->sp = (word*) c + c->len - depth;
  switch (g_code_of(g)) {
   default: return gtrap(g);                          // scare: condition data per thrower
   case g_status_more: case g_status_eof:
    // The more bit routes control through the trap continuation: push fread's
    // resume thread under [port sentinel] and throw -- the trap function (or
    // throw_c's default) decides flow from the bits. Headroom for the push is
    // the parse ctx frame, which exists wherever more/eof can arise.
    *--c->sp = word(c->ip);
    return gtrap2(c, g_code_of(g)); } }
 return Unpack(g), Continue(); }

// (string x): a charlist -> the string of those bytes; a named symbol -> its
// name string; a fixnum -> the one-byte string of its low byte. Identity on any
// other type (strings, anonymous syms, nil, ...).
g_vm(g_vm_string) {
 word x = Sp[0];
 if (x == nil) return Ip++, Continue();             // nil is the empty string (0)
 if (fixp(x)) {                                     // fixnum -> one-byte string
  uintptr_t req = str_type_width + b2w(1);
  Have(req);
  struct g_str *s = (void*) Hp;
  Hp += req;
  ini_str(s, 1);
  txt(s)[0] = (char) getfix(x);
  return Sp[0] = word(s), Ip++, Continue(); }
 if (symp(x)) {                                      // named symbol -> name string, else identity
  word y = x;
  while (symp(y) && sym(y)->nom && symp(word(sym(y)->nom))) y = word(sym(y)->nom);
  word nom = word(sym(y)->nom);
  if (nom && strp(nom)) Sp[0] = nom;
  return Ip++, Continue(); }
 if (twop(x)) {                                      // charlist -> string
  uintptr_t n = llen(x), req = str_type_width + b2w(n);
  Have(req);
  struct g_str *s = (void*) Hp;
  Hp += req;
  ini_str(s, n);
  for (uintptr_t i = 0; n--; x = B(x)) txt(s)[i++] = (char) getfix(A(x));
  return Sp[0] = word(s), Ip++, Continue(); }
 return Ip++, Continue(); }                          // any other type: identity

////
/// " the parser "
//
//
// get the next significant character from the stream. MM-protect the C
// `i` parameter across the multiple port_* calls — each push triggers a
// have() check that may GC and move heap ports.

// Comments: `;` runs to end of line; `#!` (shebang) runs to end of line; a bare
// `#` is significant (the len reader macro), as is any other non-whitespace char.
static struct g* g_z_getc(struct g*g) {
 while (g_ok(g = zgetc(g))) switch (g->b) {
  default: return g;
  case '\n': case '\r': continue;
  case 0: case ' ': case '\t': case '\f': continue;
  case '#':                                          // #! is a line comment; bare # is significant (len macro)
   if (!g_ok(g = zgetc(g))) return g;
   if (g->b != '!') {                                // not a shebang: push back, return #
    if ((int) g->b != EOF && !g_ok(g = zungetc(g, g->b))) return g;
    return g->b = '#', g; }
   while (g_ok(g = zeof(g)) && !g->b && g_ok(g = zgetc(g)) && g->b != '\n' && g->b != '\r');
   continue;
  case ';':                                          // line comment: run to end of line
   while (g_ok(g = zeof(g)) && !g->b && g_ok(g = zgetc(g)) && g->b != '\n' && g->b != '\r');
   continue; }
 return g; }

// --- one non-recursive reader for both g_read1 (multi=0) and g_reads (multi=1) ---
// `ctx` (kept at sp[0]) is an explicit stack of frames, top = car, so the nesting
// that used to recurse in C now lives on the ll heap (and rides GC). A frame is
// either a *list accumulator* — a pair (head . tail) holding the elements read so
// far in source order, ((nil . nil) when empty), built in place by appending at
// `tail` so no reverse pass is needed — or a *reader-macro* — the wrap symbol \ qq
// uq uqs, recognised by symp. A finished datum is `delivered` to the top frame:
// appended to a list, or wrapped and re-delivered; with no frame left it is the
// result. Everything lives on the ll stack so GC relocates it across the allocs
// that reading does.

static g_inline struct g *push_frame(struct g *g) {     // push an empty (head . tail) accumulator
 return gxl(gxl(g_push(g, 2, nil, nil))); }    // ctx' = ((nil . nil) . ctx)
static g_inline struct g *push_wrap(struct g *g, char const *nom) {
 return gxl(intern(g_strof(g, nom))); }        // ctx' = (wrapsym . ctx)
// N-ary operator wrap: frame = (count . (head . tail)), the accumulator seeded
// with the operator name so completion delivers (name d1 .. dN) directly.
static struct g *push_wrapn(struct g *g, word name, int n) {
 g = g_push(g, 1, name);
 g = gxr(g_push(g, 1, nil));                       // s = (name . nil)
 g = gxl(g_push(g, 1, g_ok(g) ? g->sp[0] : nil));  // (s . s): head = tail = s
 g = gxl(g_push(g, 1, putfix(n)));                 // (n . (s . s))
 return gxl(g); }                                  // ctx' = (frame . ctx)
// a pending wrap (vs a list accumulator): an arity-1 wrapsym, or an N-ary frame
// whose car is a positive count (a list frame's car is nil or a pair).
static g_inline bool wrap_framep(word f) {
 return symp(f) || (twop(f) && fixp(A(f)) && !nilp(A(f))); }
// recognise the splicing reader-macro wraps -- `%` (interned `hasht`) and `@`
// (interned `tuple`) -- so a list operand splices into the constructor call
// instead of being wrapped: see the deliver loop in gz_parse.
static g_inline bool symeq(word x, char const *nm, uintptr_t n) {
 struct g_str *s = symp(x) ? sym(x)->nom : 0;
 if (!s || !strp(word(s)) || s->len != n) return false;
 for (uintptr_t i = 0; i < n; i++) if (s->bytes[i] != nm[i]) return false;
 return true; }
static g_inline bool hashsym(word x) { return symeq(x, "map", 3); }
static g_inline bool splicesym(word x) { return hashsym(x) || symeq(x, "tuple", 5) || symeq(x, "com", 3); }

static struct g *gz_parse(struct g *g, bool multi) {
 // multi: ctx starts with one open accumulator (collects all top-level datums in
 // source order); read1: ctx starts empty (returns the first complete datum).
 g = multi ? gxl(gxl(g_push(g, 3, nil, nil, nil))) : g_push(g, 1, nil);
 for (;;) {
  if (!g_ok(g = g_z_getc(g))) return g;
  int c = g->b, c2 = EOF;
  switch (c) {
   case '(': case '[': case '{': g = push_frame(g); continue;   // [ ] { } are () synonyms
   case '~':                                            // ~(re im)->(com re im) [construct]; ~x->(clift x)
    if (!g_ok(g = zgetc(g))) return g;                 // peek the char after ~: `(` -> splice into com (build
    c2 = g->b;                                         // a complex / curry); anything else -> monadic lift/conj
    if (c2 != EOF) g = zungetc(g, c2);                 // (clift: real r -> ~(r 0); complex z -> conj z)
    g = push_wrap(g, c2 == '(' ? "com" : "clift"); continue;
   case ',':                                            // unquote / unquote-splice
    if (!g_ok(g = zgetc(g))) return g;
    if ((c2 = g->b) == '@') { g = push_wrap(g, "uqs"); continue; }
    if (c2 != EOF) g = zungetc(g, c2);
    g = push_wrap(g, "uq"); continue;
   case ')': case ']': case '}':
    if (nilp(g->sp[0])) return encode(g_core_of(g), g_status_eof);   // stray ) / read1
    if (wrap_framep(A(g->sp[0]))) return encode(g_core_of(g), g_status_more); // wrap wants operands
    g = g_push(g, 1, AA(g->sp[0]));                    // d = head of the closed frame
    if (g_ok(g)) {
     if (nilp(g->sp[0])) g->sp[0] = EMPTY_SYM;         // () -- the empty symbol, not 0
     g->sp[1] = B(g->sp[1]); }                         // pop the closed frame
    break;                                             // -> deliver d
   case EOF:
    if (nilp(g->sp[0])) return encode(g_core_of(g), g_status_eof);
    if (!(multi && nilp(B(g->sp[0])) && !wrap_framep(A(g->sp[0]))))
     return encode(g_core_of(g), g_status_more);       // unclosed list / pending wrap
    g = g_push(g, 1, AA(g->sp[0]));                    // close the top accumulator -> its head
    if (g_ok(g)) g->sp[1] = B(g->sp[1]);
    break;
   case '"': g = gzread1str(g); break;
   default: {                                          // operator table, else a symbol/number token
    struct g *cg = g_core_of(g);
    word t = cg->operators_sym ? g_mapget(cg, nil, cg->operators_sym, cg->dict) : nil;
    word v = mapp(t) ? g_mapget(cg, nil, putfix(c), t) : nil;
    if (symp(v) && v != EMPTY_SYM) { g = gxl(g_push(g, 1, v)); continue; }   // name -> arity-1 wrap
    if (twop(v) && symp(A(v)) && A(v) != EMPTY_SYM && fixp(B(v))) {          // (name . arity)
     intptr_t n = getfix(B(v));
     if (n == 1) { g = gxl(g_push(g, 1, A(v))); continue; }
     if (n >= 2 && n <= 7) { g = push_wrapn(g, A(v), (int) n); continue; } } // junk arity: not an op
    g = gzread1sym(g, c); break; } }
  if (!g_ok(g)) return g;
  // deliver the datum at sp[0] into the frame stack at sp[1]
  for (bool done = false; g_ok(g) && !done; ) {
   if (nilp(g->sp[1])) {                               // no frame left: the result
    g->sp[1] = g->sp[0], g->sp++;
    return g; }
   if (symp(A(g->sp[1]))) {                            // reader-macro wrap, pop the wrap frame
    if (hashsym(A(g->sp[1])) && (nilp(g->sp[0]) || g->sp[0] == EMPTY_SYM)) { // %() -> (mapn 0)
     g->sp[0] = nil;                                   // d -> (0 . nil) = (0)
     g = gxr(g_push(g, 1, nil));
     g = gxl(intern(g_strof(g, "mapn")));              // (mapn . (0)) = (mapn 0)
     if (g_ok(g)) g->sp[1] = B(g->sp[1]); }            // pop wrap
    else if (splicesym(A(g->sp[1])) &&
             (twop(g->sp[0]) || nilp(g->sp[0]) || g->sp[0] == EMPTY_SYM)) {
     if (g->sp[0] == EMPTY_SYM) g->sp[0] = nil;        // @() -> (tuple), ~() -> (com)
     g = gxl(g_push(g, 1, A(g->sp[1])));               // %(k v …)/@(e …)/@() : splice -> (sym . d)
     if (g_ok(g)) g->sp[1] = B(g->sp[1]); }
    else {                                             // 'x `x ,x  #x %atom/@atom -> (wrapsym d)
     g = gxr(g_push(g, 1, nil));                       // (d . nil)
     g = gxl(g_push(g, 1, g_ok(g) ? A(g->sp[1]) : nil)); // (wrapsym . (d))
     if (g_ok(g)) g->sp[1] = B(g->sp[1]); } }
   else if (twop(A(g->sp[1])) && fixp(AA(g->sp[1])) && !nilp(AA(g->sp[1]))) { // N-ary wrap: collect d
    g = gxr(g_push(g, 1, nil));                        // newcons = (d . nil)
    if (g_ok(g)) {
     word f = A(g->sp[1]), acc = B(f);                 // f = (count . (head . tail))
     B(B(acc)) = g->sp[0], B(acc) = g->sp[0];          // append at the tail (head pre-seeded)
     if (A(f) == putfix(1)) {                          // last operand -> (name d1 .. dN)
      g->sp[0] = A(acc);                               // the result replaces newcons
      g->sp[1] = B(g->sp[1]); }                        // pop the wrap; keep delivering
     else { A(f) = putfix(getfix(A(f)) - 1), g->sp++; done = true; } } }
   else {                                              // list: append d at the frame's tail
    g = gxr(g_push(g, 1, nil));                        // newcons = (d . nil)
    if (g_ok(g)) {
     word frame = A(g->sp[1]);                         // (head . tail)
     if (nilp(A(frame))) A(frame) = B(frame) = g->sp[0];  // first element: head = tail = newcons
     else B(B(frame)) = g->sp[0], B(frame) = g->sp[0];    // link onto tail, advance tail
     g->sp++; }                                        // pop newcons -> ctx
    done = true; } }
  if (!g_ok(g)) return g; } }

static g_inline struct g *gzread1str(struct g*g) {
 int c;
 size_t n = 0, lim = sizeof(word);
 for (g = str0(g, lim); g_ok(g); g = grbufg(g, lim), lim *= 2)
  for (; n < lim; txt(g->sp[0])[n++] = c) {
   if (!g_ok(g = zgetc(g))) return g;     // threaded; char in g->b
   else if ((c = g->b) == '"')                  // close quote; "" -> the empty
    return n ? (len(g->sp[0]) = n, g)            // (truthy) singleton, never allocated
             : (g->sp[0] = EmptyString, g);
   else if (c == EOF) return encode(g, g_status_more);
   else if (c == '\\') {                               // escape: take next char
    if (!g_ok(g = zgetc(g))) return g;
    else if ((c = g->b) == EOF) return encode(g, g_status_more);
    else if (c == 'n') c = '\n';
    else if (c == 't') c = '\t';
    else if (c == 'r') c = '\r';
    else if (c == '0') c = '\0';
    else if (c == 'x') {                          // \xHH: two hex digits
     if (!g_ok(g = zgetc(g))) return g;
     int h1 = g->b;
     if (h1 == EOF) return encode(g, g_status_more);
     if (!g_ok(g = zgetc(g))) return g;
     int h2 = g->b;
     if (h2 == EOF) return encode(g, g_status_more);
     int v1 = h1 <= '9' ? h1 - '0' : (h1 | 0x20) - 'a' + 10;
     int v2 = h2 <= '9' ? h2 - '0' : (h2 | 0x20) - 'a' + 10;
     c = ((v1 & 0xf) << 4) | (v2 & 0xf); } } }
 return g; }



static g_inline struct g *gzread1sym(struct g*g, int c) {
 uintptr_t n = 1, lim = sizeof(intptr_t);
 if (g_ok(g = str0(g, sizeof(word))))
  for (txt((struct g_str*) g->sp[0])[0] = c; g_ok(g); g = grbufg(g, lim), lim *= 2)
   for (; n < lim; txt(g->sp[0])[n++] = c) {
    if (!g_ok(g = zgetc(g))) return g;
    switch (c = g->b) {
     default: continue;
     case ' ': case '\n': case '\t': case '\r': case '\f': case ';': case '#':
     case '(': case ')': case '[': case ']': case '{': case '}':
     case '"': case '\'': case '`': case ',': case 0 : case EOF:
      if (!g_ok(g = zungetc(g, c))) return g;
      struct g_str *s = str(g->sp[0]);
      txt(s)[len(s) = n] = 0; // zero terminate for strtol ; n < lim so this is safe
      // A plain decimal integer reads at full precision (fixnum / box / bignum);
      // hex/octal/float/symbol tokens keep the strtol -> strtod -> intern path.
      if (is_dec_int(txt(s), n)) return g_big_read_dec(g);
      char *e;
      long j = strtol(txt(s), &e, 0);
      if (*e == 0) {
       if (j >= FIX_MIN && j <= FIX_MAX) return g->sp[0] = putfix(j), g;
       if (g_ok(g = g_have(g, BOX_REQ))) {
        struct g_tuple *b = ini_scalar(bump(g, BOX_REQ), g_Z);
        box_put(b->shape, j);
        g->sp[0] = word(b); }
       return g; }
      double d = strtod(txt(s), &e);
      if (e == txt(s) || *e != 0) return intern(g);
      uintptr_t req = b2w(sizeof(struct g_tuple) + sizeof(g_flo_t));
      if (g_ok(g = g_have(g, req))) {
       struct g_tuple *r = ini_scalar(bump(g, req), g_R);
       flo_put(r->shape, d);
       g->sp[0] = word(r); }
      return g; } }
 return g; }

// ============================================================================
// sys
// ============================================================================
op11(g_vm_clock, putfix(g_clock() - getfix(Sp[0])))

g_vm(g_vm_info) {
 size_t const req = 7 * Width(struct g_pair);
 Have(req);
 struct g_pair *si = (struct g_pair*) Hp;
 Hp += req;
 Sp[0] = word(si);
 ini_two(si + 0, putfix(g), word(si + 1));
 ini_two(si + 1, putfix(g->len), word(si + 2));
 ini_two(si + 2, putfix(Hp - ptr(g)), word(si + 3));
 ini_two(si + 3, putfix(ptr(g) + g->len - Sp), word(si + 4));
 ini_two(si + 4, putfix(g->n_gc), word(si + 5));               // gc cycles
 ini_two(si + 5, putfix(g->max_len), word(si + 6));            // peak pool len (words)
 ini_two(si + 6, putfix(g->max_heap), nil);                    // peak live heap (words)
 Ip += 1;
 return Continue(); }

// Default fd-keyed waits. Frontends override; defaults are conservative
// (all fds always-ready; multi-source wait collapses to plain sleep) so
// frontends that don't multitask (lcat, pd) link without providing impls.
__attribute__((weak)) bool g_ready(int fd) { (void) fd; return true; }
__attribute__((weak)) void g_wait_fds(int const *fds, int n, uintptr_t ticks) {
  (void) fds; (void) n; g_sleep(ticks); }

// Default fd close is a no-op. The host overrides with close(2); kernel
// and pd don't have real OS fds to release, so the no-op is correct.
__attribute__((weak)) void g_fd_close(int fd) { (void) fd; }
// default sleep is busy wait
__attribute__((weak)) g_noinline void g_sleep(uintptr_t ticks) {
  for (ticks += g_clock(); g_clock() < ticks;); }

g_vm(g_vm_key) {
 Sp[0] = (getfix(g_stdin.ungetc_buf) != EOF || g_ready(getfix(g_stdin.fd))) ? putfix(1) : nil;
 Ip += 1;
 return Continue(); }

// ============================================================================
// map (lookup-lambda backed by an open-addressed thread; see mapp comment)
// ============================================================================
// backing is internal -- only ever reached from a header[1], never applied as a
// ll value; its ap behaves-as-1 like g_vm_buf should it ever be (it won't).
static g_vm(g_vm_map_data) {
 return Ip = cell(*++Sp), *Sp = putfix(1), Continue(); }

// the backing slot of k, or -- if absent -- the first empty slot on its probe
// chain. load is kept < 3/4 so an empty slot always terminates the scan.
static g_inline uintptr_t map_probe(struct g *g, word m, word k, bool *found) {
 uintptr_t mask = map_cap(m) - 1, i = hash(g, k) & mask;
 word *s = map_slots(m);
 for (;; i = (i + 1) & mask) {
  word sk = s[2 * i];
  if (sk == MAP_GAP) return *found = false, i;
  if (eql(g, k, sk)) return *found = true, i; } }

word g_mapget(struct g *g, word zero, word k, word m) {
 bool found; uintptr_t i = map_probe(g, m, k, &found);
 return found ? map_slots(m)[2 * i + 1] : zero; }

// fill an empty cap-slot backing at b (cap a power of two); caller reserves it.
static g_inline union u *map_fill_back(union u *b, uintptr_t cap) {
 b[0].ap = g_vm_map_data, b[1].x = putfix(0), b[2].x = putfix(cap);
 for (uintptr_t i = 0; i < cap; i++) b[3 + 2 * i].x = MAP_GAP, b[4 + 2 * i].x = nil;
 return tagthd(b, 3 + 2 * cap); }

// double the backing of the map at sp[2] and rehash into it, then swap it into
// header[1]; the header never moves, so aliased references stay valid. The
// rehash inserts distinct keys into a backing with room to spare, so it never
// allocates and the fresh backing can't move under it.
static g_noinline struct g *map_grow(struct g *g) {
 uintptr_t ncap = 2 * map_cap(g->sp[2]);
 if (!g_ok(g = g_have(g, 4 + 2 * ncap))) return g;
 word m = g->sp[2];                                 // re-fetch header after GC
 union u *nb = map_fill_back((union u*) g->hp, ncap);
 g->hp += 4 + 2 * ncap;
 word *os = map_slots(m), *ns = &nb[3].x;
 uintptr_t ocap = map_cap(m), nlen = 0, nmask = ncap - 1;
 for (uintptr_t j = 0; j < ocap; j++) {
  word k = os[2 * j];
  if (k == MAP_GAP) continue;
  uintptr_t i = hash(g, k) & nmask;
  while (ns[2 * i] != MAP_GAP) i = (i + 1) & nmask;
  ns[2 * i] = k, ns[2 * i + 1] = os[2 * j + 1], nlen++; }
 nb[1].x = putfix(nlen);
 return cell(m)[1].x = (word) nb, g; }            // swap backing; header identity stable

// (put k v map): mutate in place; grow (may GC) on a new key past the load
// factor, re-reading k/v from the stack afterwards. Leaves the map at sp[2].
static g_noinline struct g *g_mapput(struct g *g) {
 if (!g_ok(g)) return g;
 bool found; uintptr_t i = map_probe(g, g->sp[2], g->sp[0], &found);
 if (found) return map_slots(g->sp[2])[2 * i + 1] = g->sp[1], g->sp += 2, g;
 if ((map_len(g->sp[2]) + 1) * 4 >= map_cap(g->sp[2]) * 3) {
  if (!g_ok(g = map_grow(g))) return g;
  i = map_probe(g, g->sp[2], g->sp[0], &found); }   // re-probe larger backing
 word *s = map_slots(g->sp[2]);
 s[2 * i] = g->sp[0], s[2 * i + 1] = g->sp[1];
 cell(map_back(g->sp[2]))[1].x = putfix(map_len(g->sp[2]) + 1);
 return g->sp += 2, g; }

// (hashd k v map): delete k, backward-shift the probe chain so no tombstone is
// needed; v is the not-found result. No allocation. Leaves the map at sp[2].
static g_noinline word g_mapdel(struct g *g, word m, word k, word zero) {
 bool found; uintptr_t i = map_probe(g, m, k, &found);
 if (!found) return zero;
 word *s = map_slots(m); uintptr_t mask = map_cap(m) - 1;
 for (uintptr_t j = i;;) {
  j = (j + 1) & mask;
  if (s[2 * j] == MAP_GAP) break;
  uintptr_t h = hash(g, s[2 * j]) & mask;            // ideal slot of the probed key
  bool gap = i <= j ? (h <= i || h > j) : (h <= i && h > j);   // h not in (i, j]
  if (gap) s[2 * i] = s[2 * j], s[2 * i + 1] = s[2 * j + 1], i = j; }
 s[2 * i] = MAP_GAP, s[2 * i + 1] = nil;
 cell(map_back(m))[1].x = putfix(map_len(m) - 1);
 return m; }

// C-callable fresh empty map, pushed on sp[0]. Same shape as g_vm_hnew.
static struct g *map_new(struct g *g) {
 uintptr_t cap = MAP_MIN_CAP, nb = 4 + 2 * cap;
 if (!g_ok(g = g_have(g, nb + 3))) return g;
 union u *b = map_fill_back((union u*) g->hp, cap), *h = (union u*) (g->hp + nb);
 h[0].ap = g_vm_map_lookup, h[1].x = (word) b, tagthd(h, 2);
 g->hp += nb + 3;
 return g_push(g, 1, (word) h); }

// (hashn _): a fresh empty map -- header [g_vm_map_lookup, backing] + backing.
g_vm(g_vm_hnew) {
 uintptr_t cap = MAP_MIN_CAP, nb = 4 + 2 * cap;
 Have(nb + 3);
 union u *b = map_fill_back((union u*) Hp, cap);
 union u *h = (union u*) (Hp + nb);
 h[0].ap = g_vm_map_lookup, h[1].x = (word) b, tagthd(h, 2);
 Sp[0] = (word) h;
 return Hp += nb + 3, Ip++, Continue(); }

// (m k): map application is lookup, nil if absent (the map is its own lookup fn,
// so (m k) == (get 0 k m)). No alloc, unwinds like self-quote: drop the arg,
// jump to the return address at Sp[1], leave the result on top.
static g_vm(g_vm_map_lookup) {
 word v = g_mapget(g, nil, Sp[0], (word) Ip);
 return Ip = cell(*++Sp), *Sp = v, Continue(); }

op11(g_vm_mapp, mapp(Sp[0]) ? putfix(1) : nil)
// (lamp x): is x a heap object (a pointer), i.e. not a fixnum? true for every
// present non-fixnum value -- pairs, symbols, strings, tuples, maps, threads.
op11(g_vm_lamp, lamp(Sp[0]) ? putfix(1) : nil)

// (hash x) -- the general hashing method exposed to ll as a fixnum.
op11(g_vm_hashof, putfix(hash(g, Sp[0])))

g_vm(g_vm_get) {                                // (peek coll key default): collection-first
 word x = Sp[0], k = Sp[1], z = Sp[2], n;
 if (bufp(x)) {                                  // mutable byte string: byte index
  struct g_str *s = buf_str(x);
  if (fixp(k) && (n = getfix(k)) >= 0 && n < (word) len(s))
   z = putfix((unsigned char) txt(s)[n]); }
 else if (mapp(x)) z = g_mapget(g, z, k, x);     // map lookup (not a data sentinel)
 else if (lamp(x) && datp(x)) switch (typ(x)) {
  default: break;                               // KSym is not indexable
  case KTuple: {
   // Array index: a fixnum for a rank-1 array, or a shape-list (row-major) for
   // rank-N; an empty/nil key derefs a rank-0 scalar box. Out-of-bounds or a
   // wrong-rank key falls through to the default `z`. Integer elements keep
   // integer type (EMIT_INT demotes-or-boxes); float elements box an f64.
   struct g_tuple *v = tuple(x);
   uintptr_t R = v->rank, off = 0; bool ok = false;
   if (R == 0) ok = nilp(k);
   else if (R == 1 && fixp(k)) {
    intptr_t ix = getfix(k);
    if (ix >= 0 && ix < (intptr_t) v->shape[0]) off = ix, ok = true; }
   else if (twop(k)) {
    uintptr_t a = 0; ok = true;
    for (word l = k;; l = B(l)) {
     if (!twop(l)) { ok = a == R; break; }
     word ki = A(l);
     if (a >= R || !fixp(ki)) { ok = false; break; }
     intptr_t ix = getfix(ki);
     if (ix < 0 || ix >= (intptr_t) v->shape[a]) { ok = false; break; }
     off = off * v->shape[a] + ix, a++; } }
   if (ok && v->type == g_O) z = tuple_get_obj(v, off);   // object: the slot IS the value
   else if (ok && v->type == g_C) {                       // packed complex -> a (re,im) box
    Have(CPLX_REQ); v = tuple(Sp[0]);                      // re-read coll (Sp[0]) post-Have
    g_flo_t *fp = tuple_data(v);
    struct g_tuple *bx = ini_scalar((struct g_tuple*) Hp, g_C); Hp += CPLX_REQ;
    cplx_put(bx, fp[2*off], fp[2*off+1]); z = word(bx); }
   else if (ok) { word _res; Have(BOX_REQ); v = tuple(Sp[0]);
    if (v->type >= g_R) EMIT_FLO(tuple_get_flo(v, off));
    else EMIT_INT(tuple_get_int(v, off));
    z = _res; }
   break; }
  case KString:
   // Byte as its unsigned value 0..255 -- bytes are data, signedness is the
   // operator's job. txt is signed char[], so cast to avoid sign-extending a
   // high byte (e.g. 0xff -> -1) when binary data is indexed.
   if (fixp(k) && (n = getfix(k)) >= 0 && n < (word) len(x))
    z = putfix((unsigned char) txt(x)[n]);
   break;
  case KTwo:
   if (fixp(k) && (n = getfix(k)) >= 0) {
    while (n-- && twop(x = B(x)));
    if (twop(x)) z = A(x); } }
 return Sp[2] = z, Sp += 2, Ip += 1, Continue(); }

// (pin coll key val): collection-first map insert, or -- when coll is a buf --
// store the byte val at index key. Both leave coll on the stack as the result.
// A buf store needs no allocation, so no GC dance; out-of-range/non-numeric is a
// silent no-op, matching the misuse convention of the other byte ops.
g_vm(g_vm_put) {
 word x = Sp[0], n;                              // coll
 if (mapp(x)) {
  Sp[0] = Sp[1], Sp[1] = Sp[2], Sp[2] = x;       // g_mapput wants (sp0,sp1,sp2)=(key,val,coll)
  Pack(g);
  if (!g_ok(g = g_mapput(g))) return gtrap(g);
  Unpack(g); }
 else {
  if (bufp(x) && fixp(Sp[1]) && (n = getfix(Sp[1])) >= 0 && n < (word) len(buf_str(x)))
   txt(buf_str(x))[n] = (char) getfix(Sp[2]);     // index = key = Sp[1], val = Sp[2]
  Sp[2] = x, Sp += 2; }                           // leave coll as the result
 return Ip += 1, Continue(); }

// (pull coll key default): remove key from a map, returning its value -- or
// default if absent (symmetry with peek) -- and mutating coll in place.
// g_mapget reads the value, g_mapdel removes it; neither allocates, so no GC
// dance. A non-map coll yields default (silent misuse).
g_vm(g_vm_pull) {
 word coll = Sp[0], v = Sp[2];                   // default
 if (mapp(coll)) {
  v = g_mapget(g, Sp[2], Sp[1], coll);           // value, or default if absent
  g_mapdel(g, coll, Sp[1], Sp[2]); }             // remove in place (no-op if absent)
 return Sp[2] = v, Sp += 2, Ip += 1, Continue(); }

g_vm(g_vm_hashd) {
 if (mapp(Sp[1])) Sp[2] = g_mapdel(g, Sp[1], Sp[2], Sp[0]);
 return Sp += 2, Ip += 1, Continue(); }

g_vm(g_vm_hashk) {
 intptr_t list = nil;
 if (mapp(Sp[0])) {
  uintptr_t cap = map_cap(Sp[0]), n = map_len(Sp[0]);
  Have(n * Width(struct g_pair));
  struct g_pair *pairs = (struct g_pair*) Hp;
  Hp += n * Width(struct g_pair);
  word *s = map_slots(Sp[0]);                    // re-read after Have (GC may move the map)
  for (uintptr_t i = cap; i;)
   if (s[2 * --i] != MAP_GAP)
    ini_two(pairs, s[2 * i], list), list = (intptr_t) pairs, pairs++; }
 Sp[0] = list;
 Ip += 1;
 return Continue(); }

static g_noinline uintptr_t hash_two(struct g *g, word x) {
 word *base = off_pool(g), *top = base + g->len, *w = base;
 for (uintptr_t h = mix;; x = *--w) {
  while (twop(x)) {
   if (w == top) __builtin_trap();       // worklist overflow: a cycle
   h = (h ^ mix) * mix;                  // mark a pair node
   *w++ = A(x), x = B(x); }
  h = (h ^ hash(g, x)) * mix;          // x is a leaf: hash won't recur
  if (w == base) return h; } }

// general hashing method...
struct arib; static uintptr_t shash(struct g *g, word x, struct arib *env);  // α-invariant source hash
uintptr_t hash(struct g *g, intptr_t x) {
 if (fixp(x)) return rot(x*mix);
 if (!datp(x)) {
   // out-of-pool (static nif): stable distinct address. in-pool: a compiled lambda
   // parks its source \-expr one cell before the entry (the tag head points there) and
   // hashes it α-invariantly (so the order agrees with `=`'s α-equivalence); else by
   // length. All GC-stable (buckets survive copy).
   if ((word*) x < ptr(g) || (word*) x >= topof(g)) return rot(x * mix);
   union u *k = cell(x); struct g_tag *tg = ttag(g, k);
   if (tag_head(tg) < k) return shash(g, k[-1].x, 0);
   uintptr_t r = mix;
   for (union u *y = k; y < (union u*) tg; y++) r ^= r * mix;
   return r; }
 switch (typ(x)) {
   default: __builtin_trap();
   case KTwo: return hash_two(g, x);
   case KSym: return sym(x)->code;
   case KTuple: {
    uintptr_t len = g_tuple_bytes(tuple(x)), h = mix;
    for (uint8_t const *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return h; }
   case KBig: {
    uintptr_t len = g_big_bytes((struct g_big*) x), h = mix;
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
struct g *str0(struct g *g, uintptr_t len) {
 if (!len) { if (g_ok(g = g_have(g, 1))) *--g->sp = EmptyString; return g; } // never alloc empty
 uintptr_t req = str_type_width + b2w(len);
 if (g_ok(g = g_have(g, req + 1)))
  *--g->sp = word(ini_str(bump(g, req), len));
 return g; }

struct g *g_strof(struct g *g, char const *cs) {
 uintptr_t len = strlen(cs);
 if (g_ok(g = str0(g, len))) memcpy(txt(g->sp[0]), cs, len);
 return g; }

op11(g_vm_strp, strp(Sp[0]) ? putfix(1) : nil)
g_vm(g_vm_ssub) {
 if (!strp(Sp[0])) Sp[2] = nil;
 else {
  struct g_str *s = str(Sp[0]), *t;
  intptr_t i = oddp(Sp[1]) ? getfix(Sp[1]) : 0,
           j = oddp(Sp[2]) ? getfix(Sp[2]) : 0;
  i = MAX(i, 0), i = MIN(i, (word) len(s));
  j = MAX(j, i), j = MIN(j, (word) len(s));
  if (i == j) Sp[2] = nil;
  else {
   size_t req = str_type_width + b2w(j - i);
   Have(req);
   t = (struct g_str*) Hp;
   Hp += req;
   ini_str(t, j - i);
   memcpy(txt(t), txt(s) + i, j - i);
   Sp[2] = (word) t; } }
 return Ip += 1, Sp += 2, Continue(); }

g_vm(g_vm_scat) {
 intptr_t a = Sp[0], b = Sp[1];
 if (!strp(a)) Sp += 1;
 else if (!strp(b)) Sp[1] = a, Sp += 1;
 else if (a == EmptyString && b == EmptyString) *++Sp = EmptyString;  // both empty -> singleton
 else {
  struct g_str *x = str(a), *y = str(b), *z;
  uintptr_t
   len = len(x) + len(y),
   req = str_type_width + b2w(len);
  Have(req);
  x = str(Sp[0]), y = str(Sp[1]);               // re-read post-Have
  z = (struct g_str*) Hp;
  Hp += req;
  ini_str(z, len);
  memcpy(txt(z), txt(x), len(x));
  memcpy(txt(z) + len(x), txt(y), len(y));
  *++Sp = word(z); }
 return Ip++, Continue(); }

// A buf has no function meaning, so applying it behaves as 0 (yields 1, the const-1
// identity numeral) -- like every structureless value. Its address is still the
// kind tag: g_noicf (on every g_vm) keeps this byte-identical to g_vm_port_io so
// bufp and iop never collide. NOT a data sentinel, so the GC copies a buf via the
// generic thread path and the cheney scan forwards its backing-string pointer.
g_vm(g_vm_buf) {
 return Ip = cell(*++Sp), *Sp = putfix(1), Continue(); }

// (bufnew n) — allocate a zeroed n-byte mutable buf. n<=0 / non-numeric -> the empty
// string singleton EmptyString, so NO empty buf object ever exists (an un-writable 0-byte
// buf IS ""); this lets g_nilp drop its buf branch (every real buf has len>=1, truthy).
// Two heap objects under one Have (so no GC sees a half-built buf): the backing g_str
// holding the bytes, and the length-2 wrapper thread [g_vm_buf, str, terminator].
g_vm(g_vm_bufnew) {
 intptr_t n = fixp(Sp[0]) ? getfix(Sp[0]) : 0;
 if (n <= 0) return Sp[0] = EmptyString, Ip++, Continue();   // no empty buf: it is ""
 uintptr_t sreq = str_type_width + b2w(n),
           breq = Width(struct g_buf) + Width(struct g_tag);
 Have(sreq + breq);
 struct g_str *s = ini_str((struct g_str*) Hp, n);
 Hp += sreq;
 memset(txt(s), 0, n);
 union u *k = (union u*) Hp;
 Hp += breq;
 ((struct g_buf*) k)->ap = g_vm_buf;
 ((struct g_buf*) k)->str = s;
 tagthd(k, Width(struct g_buf));
 return Sp[0] = word(k), Ip++, Continue(); }

// (bcopy dst doff src soff n) — copy n bytes from src[soff..] into buf dst at
// doff. src may be a string or buf; dst must be a buf. Ranges are clamped to
// both backing stores -- a safety net (the caller sizes dst to fit), so an
// out-of-range request copies less rather than trampling the heap. Returns
// dst. No allocation, so no GC dance and the trailing tail call is preserved.
g_vm(g_vm_bcopy) {
 word dst = Sp[0], src = Sp[2];
 if (bufp(dst) && (strp(src) || bufp(src))) {
  struct g_str *d = buf_str(dst), *s = bytes_of(src);
  intptr_t doff = getfix(Sp[1]), soff = getfix(Sp[3]), n = getfix(Sp[4]),
           dl = len(d), sl = len(s);
  if (n < 0) n = 0;
  if (doff < 0) doff = 0;
  if (soff < 0) soff = 0;
  if (doff + n > dl) n = dl - doff;
  if (soff + n > sl) n = sl - soff;
  if (n > 0) memmove(txt(d) + doff, txt(s) + soff, n); }
 return Sp[4] = dst, Sp += 4, Ip += 1, Continue(); }

// public predicate for frontends that need to check string args
bool g_strp(g_word x) { return strp(x); }

// ============================================================================
// sym
// ============================================================================
// (intern s) -> the interned symbol named by string s; identity on any other arg.
// The empty name maps to the one canonical empty symbol (g_sym_empty), so it is
// never interned into the tree and stays unique.
g_vm(g_vm_intern) {
 if (strp(Sp[0])) {
  if (Sp[0] == EmptyString) return Sp[0] = EMPTY_SYM, Ip += 1, Continue();
  struct g_atom *y;
  Have(Width(struct g_atom));
  Pack(g), y = intern_checked(g, (struct g_str*) g->sp[0]), Unpack(g);
  Sp[0] = word(y); }
 return Ip += 1, Continue(); }

// (nom name) -> a fresh *uninterned* symbol named after `name`: a string (the
// symbol it would intern to) or a symbol (used directly). The new symbol stores
// that naming SYMBOL as its nom, which marks it uninterned (interned syms have a
// string nom; see ini_usym). Any other arg yields an anonymous nom (nom 0).
g_vm(g_vm_nom) {
 if (Sp[0] == EmptyString) return Sp[0] = EMPTY_SYM, Ip += 1, Continue(); // ""->the empty sym
 Have(2 * Width(struct g_atom));               // room for the wrapper + a fresh intern
 struct g_atom *nom;
 if (strp(Sp[0]))                              // (sym "x"): intern "x" -> the symbol it names
   Pack(g), nom = intern_checked(g, (struct g_str*) g->sp[0]), Unpack(g);
 else nom = symp(Sp[0]) ? sym(Sp[0]) : 0;      // symbol arg used as-is; else anonymous
 struct g_atom *y = (struct g_atom*) Hp;
 Hp += Width(struct g_atom) - 2;               // uninterned/anonymous: no l/r subtree slots
 nom ? ini_usym(y, nom, g_clock()) : ini_anon(y, g_clock());
 return
  Sp[0] = word(y),
  Ip += 1,
  Continue(); }

struct g *intern(struct g*g) {
 if (g_ok(g = g_have(g, Width(struct g_atom))))
  g->sp[0] = (word) intern_checked(g, (struct g_str*) g->sp[0]);
 return g; }

// avail must be >= Width(struct g_atom) when this is called.
g_noinline struct g_atom *intern_checked(struct g *g, struct g_str *b) {
 uintptr_t h = rot(hash(g, word(b)));
 for (struct g_atom **y = &g->symbols, *z;;) {
  if (!(z = *y)) return *y = ini_sym(bump(g, Width(struct g_atom)), b, h);
  struct g_str *a = z->nom;
  intptr_t i = z->code < h ? -1 : z->code > h ? 1 : 0;
  if (i == 0) i = len(a) - len(b);
  if (i == 0) i = memcmp(txt(a), txt(b), len(b));
  if (i == 0) return z;
  y = i < 0 ? &z->l : &z->r; } }

op11(g_vm_symp, symp(Sp[0]) ? putfix(1) : nil)
op11(g_vm_tupp, tupp(Sp[0]) ? putfix(1) : nil)
op11(g_vm_bigp, bigp(Sp[0]) ? putfix(1) : nil)
op11(g_vm_boxp, boxp(Sp[0]) ? putfix(1) : nil)
op11(g_vm_arrp, arrp(Sp[0]) ? putfix(1) : nil)
// (int x): truncate a float scalar to a fixnum; other numbers pass through. Used by
// num-ap to get an integer composition count from a non-integer numeral operator.
op11(g_vm_intf, flop(Sp[0]) ? putfix((intptr_t) flo_get(Sp[0])) : Sp[0])

// ============================================================================
// pair
// ============================================================================
op11(g_vm_car, twop(Sp[0]) ? A(Sp[0]) : Sp[0])
op11(g_vm_cdr, twop(Sp[0]) ? B(Sp[0]) : nil)
op11(g_vm_twop, twop(Sp[0]) ? putfix(1) : nil)
g_vm(g_vm_cons) {
 Have(Width(struct g_pair));
 struct g_pair *w = (struct g_pair*) Hp;
 Hp += Width(struct g_pair);
 ini_two(w, Sp[0], Sp[1]);
 *++Sp = word(w);
 Ip++;
 return Continue(); }

#define AVM_SLOW(op, vop, ovf, fexpr) static g_vm(g_vm_##op##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, g, vop); \
 if (Cp(a) || Cp(b)) return Ap(g_vm_cplx_bin, g, vop); \
 if (!ISNUM(a) || !ISNUM(b)) return *++Sp = nil, Ip++, Continue(); \
 if (flop(a) || flop(b)) { word _res; Have(BOX_REQ); \
  g_flo_t ad = TOFLO(a), bd = TOFLO(b); \
  struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_R); \
  Hp += BOX_REQ; flo_put(v->shape, (fexpr)); _res = word(v); \
  return *++Sp = _res, Ip++, Continue(); } \
 if (!bigp(a) && !bigp(b)) { intptr_t av = TOINT(a), bv = TOINT(b), t; \
  if (!ovf(av, bv, &t)) { word _res; Have(BOX_REQ); EMIT_INT(t); \
   return *++Sp = _res, Ip++, Continue(); } } \
 if ((vop) == VOP_MUL) return Ap(g_vm_bmul_start, g); /* O(n^2): run yieldable */ \
 Pack(g); g = g_big_binop(g, vop); \
 if (!g_ok(g)) return gtrap(g); \
 return Unpack(g), Continue(); }
#define AVM_SLOWDIV(op, vop, c_op, fexpr) static g_vm(g_vm_##op##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, g, vop); \
 if (Cp(a) || Cp(b)) return Ap(g_vm_cplx_bin, g, vop); \
 if (!ISNUM(a) || !ISNUM(b)) return *++Sp = nil, Ip++, Continue(); \
 if (flop(a) || flop(b) || b == nil) { word _res; Have(BOX_REQ); \
  g_flo_t ad = TOFLO(a), bd = TOFLO(b); \
  struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_R); \
  Hp += BOX_REQ; flo_put(v->shape, (fexpr)); _res = word(v); \
  return *++Sp = _res, Ip++, Continue(); } \
 if (!bigp(a) && !bigp(b)) { intptr_t av = TOINT(a), bv = TOINT(b); \
  if (!(av == INTPTR_MIN && bv == -1)) { word _res; Have(BOX_REQ); EMIT_INT(av c_op bv); \
   return *++Sp = _res, Ip++, Continue(); } } \
 Pack(g); g = g_big_binop(g, vop); \
 if (!g_ok(g)) return gtrap(g); \
 return Unpack(g), Continue(); }
#define AVM_OVF(op, builtin) g_vm(g_vm_##op) { \
 word a = Sp[0], b = Sp[1]; \
 if (fixp(a) && fixp(b)) { intptr_t t; \
  if (!builtin((intptr_t) getfix(a), (intptr_t) getfix(b), &t) && \
      t >= FIX_MIN && t <= FIX_MAX) \
   return *++Sp = putfix(t), Ip++, Continue(); } \
 return Ap(g_vm_##op##n, g); }
#define AVM_DIV(op, c_op) g_vm(g_vm_##op) { \
 word a = Sp[0], b = Sp[1]; \
 if (fixp(a) && fixp(b)) { \
  intptr_t av = getfix(a), bv = getfix(b); \
  if (bv != 0 && !(av == INTPTR_MIN && bv == -1)) { \
   intptr_t t = av c_op bv; \
   if (t >= FIX_MIN && t <= FIX_MAX) \
    return *++Sp = putfix(t), Ip++, Continue(); } } \
 return Ap(g_vm_##op##n, g); }
// the ordered comparisons (< <= > >=) and their total order over all values are
// defined after vcmp_int/vcmp_flo (the per-op helpers they reuse), by g_vm_vbin.
#define BIT_SLOW(n, c_op) static g_vm(g_vm_##n##_slow) {               \
 word a = Sp[0], b = Sp[1], _res;                                     \
 if (!(fixp(a) || boxp(a)) || !(fixp(b) || boxp(b)))                  \
  return *++Sp = nil, Ip++, Continue();                               \
 Have(BOX_REQ);                                                       \
 EMIT_INT(TOINT(a) c_op TOINT(b));                                    \
 return *++Sp = _res, Ip++, Continue(); }
#define mvm1(n) g_vm(g_vm_##n) { return Ap(g_vm_math1, g, g_##n); }
#define m1(_) _(sin) _(cos) _(log)   // sqrt/exp/tan/atan derived; sin/cos/log are the kept transcendentals


AVM_SLOW(add, VOP_ADD, __builtin_add_overflow, ad + bd)
AVM_SLOW(sub, VOP_SUB, __builtin_sub_overflow, ad - bd)
AVM_SLOW(mul, VOP_MUL, __builtin_mul_overflow, ad * bd)

AVM_SLOWDIV(fquot, VOP_FQUOT, /, g_trunc(ad / bd))  // `//` truncating: float operand floors toward zero
AVM_SLOWDIV(rem, VOP_REM, %, g_fmod(ad, bd))    // NaN on bd == 0

// `/` true division: exact integer when b divides a, a float box otherwise (the
// truncating quotient is `//`, g_vm_fquot above). Mirrors AVM_SLOWDIV's lane order
// -- array / complex / non-num / float-or-÷0 -- then splits the integer lane on
// divisibility. The bignum lane defers to g_big_quot_true (same exact-or-float test).
static g_vm(g_vm_quotn) {
 word a = Sp[0], b = Sp[1];
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, g, VOP_QUOT);
 if (Cp(a) || Cp(b)) return Ap(g_vm_cplx_bin, g, VOP_QUOT);
 if (!ISNUM(a) || !ISNUM(b)) return *++Sp = nil, Ip++, Continue();
 if (flop(a) || flop(b) || b == nil) { word _res; Have(BOX_REQ);   // ±inf/NaN on ÷0
  g_flo_t ad = TOFLO(a), bd = TOFLO(b);
  struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_R);
  Hp += BOX_REQ; flo_put(v->shape, ad / bd); _res = word(v);
  return *++Sp = _res, Ip++, Continue(); }
 if (!bigp(a) && !bigp(b)) { intptr_t av = TOINT(a), bv = TOINT(b);  // bv != 0 (b != nil)
  if (!(av == INTPTR_MIN && bv == -1)) {                            // INT_MIN/-1 is exact but overflows -> bignum lane
   if (av % bv == 0) { word _res; Have(BOX_REQ); EMIT_INT(av / bv);
    return *++Sp = _res, Ip++, Continue(); }
   word _res; Have(BOX_REQ);                                        // inexact -> promote to float
   struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_R);
   Hp += BOX_REQ; flo_put(v->shape, (g_flo_t) av / (g_flo_t) bv); _res = word(v);
   return *++Sp = _res, Ip++, Continue(); } }
 Pack(g); g = g_big_quot_true(g);
 if (!g_ok(g)) return gtrap(g);
 return Unpack(g), Continue(); }

AVM_OVF(sub, __builtin_sub_overflow)
// g_vm_mul + its kind matrix live after the `+` text lane (they reuse add_name /
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
// RUNTIME FLAG: g_add_lr selects order-preserving (left->front, right->back); set
// it false for the commutative reading (smaller operand always joins the front, so
// a+b == b+a like numeric add). A plain mutable global -> toggleable at runtime.
static const bool g_add_lr = true;
// coerce a numeric to a string byte: floor(|x|) mod 256, where |x| of a complex
// is its modulus (matching abs's L2 vector->scalar coercion, see g_vm_abs).
static g_inline unsigned char seq_byte(word x) {
 g_flo_t v = Cp(x) ? cplx_mod(x) : TOFLO(x);
 if (v < 0) v = -v;
 return (unsigned char) (uintptr_t) g_trunc(v); }
// LIST lane: at least one operand is a pair (the matrix only routes list-involved
// pairs here). list+list -> spine append; elt<->list -> the non-list operand joins
// as a scalar element (front if it is on the left, else appended at the tail).
static g_vm(g_vm_add_seq) {
 word a = Sp[0], b = Sp[1];
 if (twop(a) && twop(b)) {                       // list + list -> append a..b
  uintptr_t n = llen(a); Have(n * Width(struct g_pair));
  a = Sp[0], b = Sp[1];
  struct g_pair *base = (struct g_pair*) Hp, *w = base;
  Hp += n * Width(struct g_pair);
  for (word l = a; twop(l); l = B(l), w++) ini_two(w, A(l), word(w + 1));
  (w - 1)->b = b;                                // last cdr -> b
  return *++Sp = word(base), Ip++, Continue(); }
 if (twop(a) || twop(b)) {                        // elt <-> list
  bool front = !g_add_lr || twop(b);              // element on the left -> front
  word lst = twop(a) ? a : b, elt = twop(a) ? b : a;
  if (front) { Sp[0] = elt, Sp[1] = lst; return Ap(g_vm_cons, g); }  // (cons elt list)
  uintptr_t n = llen(lst) + 1; Have(n * Width(struct g_pair));        // append elt at tail
  lst = twop(Sp[0]) ? Sp[0] : Sp[1], elt = twop(Sp[0]) ? Sp[1] : Sp[0];
  struct g_pair *base = (struct g_pair*) Hp, *w = base;
  Hp += n * Width(struct g_pair);
  for (word l = lst; twop(l); l = B(l), w++) ini_two(w, A(l), word(w + 1));
  ini_two(w, elt, nil);                           // trailing (elt . nil)
  return *++Sp = word(base), Ip++, Continue(); }
 return *++Sp = nil, Ip++, Continue(); }          // unreachable: matrix gates on a list

// --- TEXT lane: strings + symbols, name-compatible -------------------------
// The text tower is STRING (rank 0) < UNINTERNED-SYM (1) < INTERNED-SYM (2). A
// symbol's bytes are its name (anonymous -> empty, like ""); a number contributes
// one byte (seq_byte) and sits at the top rank, so min() keeps its partner's type
// (a scalar lifts into whatever it joins). Mixing demotes to the lower rank:
// isym+usym -> usym, sym+str -> str, num+sym -> sym (lifted), num+str -> str. The
// concat is built as one string in operand order, then returned per the result
// rank: string as-is / nom'd to a fresh uninterned sym / interned. An empty
// result is the g_str_empty / g_sym_empty singleton (the additive identity).
static g_inline struct g_str *add_name(word x) {        // symbol -> name string, or 0 (anon)
 word nom = word(sym(x)->nom);
 if (!nom) return 0;
 if (strp(nom)) return str(nom);                        // interned: nom IS the name
 nom = word(sym(nom)->nom);                             // named-uninterned: naming sym's nom
 return nom && strp(nom) ? str(nom) : 0; }
static g_inline int stringrank(word x) {                  // STR 0 / USYM 1 / ISYM|NUM 2
 if (strp(x)) return 0;
 if (x == EMPTY_SYM) return 2;                           // canonical (intern ""): the + identity
 if (symp(x)) { word n = word(sym(x)->nom); return n && strp(n) ? 2 : 1; }
 return 2; }
static g_inline uintptr_t stringlen(word x) {             // bytes x contributes to a concat
 if (strp(x)) return len(x);
 if (symp(x)) { struct g_str *n = add_name(x); return n ? n->len : 0; }
 return 1; }                                            // number -> one byte
static g_inline char *add_emit(char *w, word x) {       // append x's bytes; return advanced w
 if (strp(x)) return (void) memcpy(w, txt(x), len(x)), w + len(x);
 if (symp(x)) { struct g_str *n = add_name(x);
  return n ? ((void) memcpy(w, txt(n), n->len), w + n->len) : w; }
 return *w = (char) seq_byte(x), w + 1; }               // number -> one byte
static g_vm(g_vm_add_string) {
 word a = Sp[0], b = Sp[1];
 if (arrp(a) || arrp(b)) return *++Sp = nil, Ip++, Continue(); // array <-> text: undefined
 int rank = MIN(stringrank(a), stringrank(b));
 uintptr_t n = stringlen(a) + stringlen(b);
 if (!n) return *++Sp = rank ? EMPTY_SYM : EmptyString, Ip++, Continue();
 uintptr_t req = str_type_width + b2w(n);
 Have(req);
 a = Sp[0], b = Sp[1];                                  // re-read post-GC
 struct g_str *z = ini_str((struct g_str*) Hp, n); Hp += req;
 add_emit(add_emit(txt(z), a), b);                      // a's bytes then b's, in order
 *++Sp = word(z);
 return rank == 0 ? (Ip++, Continue())                  // string
      : rank == 1 ? Ap(g_vm_nom, g)                  // uninterned symbol (fresh)
                  : Ap(g_vm_intern, g); }               // interned symbol
static g_vm(g_vm_0) {                             // unsupported mix (array <-> text)
 return *++Sp = nil, Ip++, Continue(); }

// The fundamental value kind for generic-op dispatch (enum q in ll.h): a fixnum is
// the odd tag (KFix), a non-data heap pointer is a thread/function (KLam), else g_typ
// gives the data kind. The one refinement: a rank>=1 tuple (array) expands by element
// tier to KArrZ..KArrO so the array tower dispatches inline with the scalar tower it
// mirrors; rank-0 boxes (float/complex/wide-int) stay KTuple. Exported (not inline) so
// data.c's apply sentinels share it.
enum q g_kind(word x) {
 if (fixp(x)) return KFix;
 if (!datp(x)) return KLam;
 enum q k = typ(x);
 return k == KTuple && tuple(x)->rank ? (enum q) (KArrZ + tuple(x)->type) : k; }

// ============================================================================
// generic-op lane handlers, then all three dispatch matrices adjacent, then the
// `+`/`*` dispatchers. The numeric slow lanes (addn/muln…) come from the AVM_*
// macros above; the `+` text lanes (add_seq/add_string) and g_vm_0 just above; the
// lambda combinators (g_vm_addl/g_vm_mull) near num-ap. Defined here: the `*`
// repeat lane and the apply handlers -- everything the matrices reference.
// ============================================================================

// `*` REPEAT lane: the multiplicative analog of `+`'s concat. `*` is "repeated
// `+`": a sequence (string / symbol / list) times a scalar count n is n copies
// joined, just as `(* 2 3)` is 2+2+2. The count is the OTHER operand, L2-norm-
// coerced to a non-negative int (int(abs c) -- a float/complex count works, matching
// array shapes); an array (or any non-number) is not a count -> nil. n == 0 -> the
// empty singleton. A symbol stays at its own rank (no demotion): an interned name
// repeats to an interned symbol.
static g_vm(g_vm_mul_rep) {
 word a = Sp[0], b = Sp[1];
 bool aseq = strp(a) || symp(a) || twop(a);
 word seq = aseq ? a : b, cnt = aseq ? b : a;
 if (!ISNUM(cnt) && !Cp(cnt)) return *++Sp = nil, Ip++, Continue();   // array/non-number count
 g_flo_t cv = Cp(cnt) ? cplx_mod(cnt) : TOFLO(cnt);
 if (cv < 0) cv = -cv;
 uintptr_t n = (uintptr_t) g_trunc(cv);
 if (twop(seq)) {                                  // list -> n copies of the spine
  if (!n) return *++Sp = nil, Ip++, Continue();
  uintptr_t m = llen(seq), total = m * n;
  Have(total * Width(struct g_pair));
  seq = twop(Sp[0]) ? Sp[0] : Sp[1];               // re-read post-GC
  struct g_pair *base = (struct g_pair*) Hp, *w = base;
  Hp += total * Width(struct g_pair);
  for (uintptr_t i = 0; i < n; i++)
   for (word l = seq; twop(l); l = B(l), w++) ini_two(w, A(l), word(w + 1));
  (w - 1)->b = nil;
  return *++Sp = word(base), Ip++, Continue(); }
 // string / symbol: repeat the byte content (a symbol's name; anonymous -> empty)
 int rank = strp(seq) ? 0 : stringrank(seq);         // 0 str / 1 usym / 2 isym
 struct g_str *src = strp(seq) ? str(seq) : add_name(seq);
 uintptr_t sl = src ? src->len : 0, total = sl * n;
 if (!total) return *++Sp = rank ? EMPTY_SYM : EmptyString, Ip++, Continue();
 uintptr_t req = str_type_width + b2w(total);
 Have(req);
 seq = (strp(Sp[0]) || symp(Sp[0])) ? Sp[0] : Sp[1];   // re-read post-GC
 src = strp(seq) ? str(seq) : add_name(seq);
 struct g_str *z = ini_str((struct g_str*) Hp, total); Hp += req;
 for (uintptr_t i = 0; i < n; i++) memcpy(txt(z) + i * sl, txt(src), sl);
 *++Sp = word(z);
 return rank == 0 ? (Ip++, Continue())             // string
      : rank == 1 ? Ap(g_vm_nom, g)             // uninterned symbol
                  : Ap(g_vm_intern, g); }          // interned symbol

// --- apply lane (the data-value `(g x)` handlers; moved here from data.c) -----
// When a data value is applied, its sentinel (data.c, pinned in the gwen_data
// section) tail-jumps through g_apply_mx[g_typ(Ip)][g_kind(Sp[0])] -- the static
// kind of the applied value and the dynamic kind of the argument. Every data kind
// has a meaningful apply (pair = eliminator, string/symbol = byte index, numeric
// tower = Church numeral); opaque handles (ports, buffers) behave as 0 via their
// own g_vm_* sentinel, not through here. Maps look up via g_vm_map_lookup (a thread
// ap, not a data sentinel), so they do not appear in this table.

// (s k): applying a string indexes it -- k a byte offset, result the unsigned byte
// 0..255 there, 1 if k is non-numeric or out of range (matches "" == 0: a numeric
// ("" k) is the Church numeral k**0 == 1). No alloc, unwinds like self-quote.
static g_vm(data_string_apply) {
 word k = Sp[0], v = putfix(1), n;
 if (oddp(k) && (n = getfix(k)) >= 0 && n < (word) len(Ip))
  v = putfix((unsigned char) txt(Ip)[n]);
 return Ip = cell(*++Sp), *Sp = v, Continue(); }

// (y k): applying a symbol indexes its underlying name string, so (y k) == (nom k).
// nom encodes the kind: a string is the name (interned), a symbol is the naming
// symbol of a named-uninterned sym (follow once to its string nom), 0 is an anonymous
// nom. With no underlying string we act like 0 (absent name == "" == 0 -> 1).
static g_vm(data_sym_apply) {
 word nom = word(((struct g_atom*) Ip)->nom);
 if (nom && cell(nom)->ap == g_vm_sym)              // named-uninterned: follow to the naming symbol
  nom = word(((struct g_atom*) nom)->nom);
 if (nom && cell(nom)->ap == g_vm_str)             // interned/named: index the underlying name string
  return Ip = cell(nom), Ap(data_string_apply, g);
 return Ip = cell(*++Sp), *Sp = putfix(1), Continue(); }  // anonymous: no name -> act like 0

// (n x): applying a number is Church-numeral application, like a fixnum (cf.
// g_vm_numap). Fixnums reach num-ap via the odd-tag check in g_vm_ap; the rest of the
// tower (floats, boxes, complex, arrays -- all g_vm_tuple -- and bignums) are heap
// pointers, so they arrive at their data sentinel. We lay the same [n, num-ap, x, ret]
// frame and run numap_drive, handing the boxed operator n to the ll num-ap handler,
// which picks exponentiate / compose / self by operand+operator kind.
static g_vm(data_num_apply) {
 Have(2);
 word h = resolve_handler(g, g->numap_sym);
 word n = word(Ip), x = Sp[0], ret = Sp[1], *dst = Sp - 2;
 dst[0] = n, dst[1] = h, dst[2] = x, dst[3] = ret;
 return Sp = dst, Ip = (union u*) numap_drive, Continue(); }

// ((a . b) g) == (g a b): a pair is its own Church eliminator (cons = \a b g.g a b).
// Re-enter the apply protocol via a static driver thread: lay the stack as the two
// curried calls expect, then [ap ; swap+ap ; ret0] runs ((g a) b). pair_swap reorders
// [result, b] -> [b, result] so the second ap sees arg=b, fn=(g a). The driver lives
// in .data, so the return addresses it leaves on the stack fall outside the GC pool.
static g_vm(pair_swap) {
 word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t;
 return Ap(g_vm_ap, g); }
static union u const pair_drive[] = { {g_vm_ap}, {.ap = pair_swap}, {.ap = g_vm_ret0} };
static g_vm(data_pair_apply) {
 Have(2);
 word a = A(Ip), b = B(Ip), fn = Sp[0];     // re-read after the Have guard; no alloc past here
 Sp -= 2;                                    // grow the frame to [a, fn, b, ret]
 Sp[0] = a, Sp[1] = fn, Sp[2] = b;           // Sp[3] = ret (was Sp[1]) stays put
 return Ip = (union u*) pair_drive, Continue(); }

// === the three generic-op dispatch matrices, adjacent ======================
// All indexed by g_kind (g_apply_mx's row by g_typ, the data-kind subrange). The kind
// order (ll.h) makes each lane a contiguous block: [KFix..KArrO] arithmetic (the
// scalar tower fix/tuple/big then the parallel array tower arrZ/arrR/arrC/arrO), then
// [KString..KTwo] sequence, then KLam. Lanes:
//   *n   = numeric tower & arrays (arithmetic / broadcast) -- the lane handler still
//          refines by g_tuple_type; the seven arithmetic kinds route identically today.
//   add_seq = a list anywhere (other operand a scalar element / spine); pair wins
//   add_string = strings & symbols name-compatibly (+ a number as one byte; demotes
//              isym>usym>str and nils an array operand internally)
//   mul_rep  = sequence * scalar-count -> repetition
//   *l   = a LAMBDA operand (precedence: the KLam row+col) -- Church add / compose
//   g_vm_0 = undefined (-> nil): sequence*sequence
// Precedence (high->low): lambda > pair > text > number(incl array). Maps are lambdas
// (KLam) -- the *l lanes -- so they have no row/col of their own.
// cols (enum order): fix tuple big arrZ arrR arrC arrO | string sym | two | lam

// `+`: numbers add, lists/text concat, lambdas Church-add. KLam row+col all addl.
static g_vm_t *const g_add_mx[KN][KN] = {
 [KFix]    = { g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_add_string, g_vm_add_string, g_vm_add_seq, g_vm_addl },
 [KTuple]  = { g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_add_string, g_vm_add_string, g_vm_add_seq, g_vm_addl },
 [KBig]    = { g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_add_string, g_vm_add_string, g_vm_add_seq, g_vm_addl },
 [KArrZ]   = { g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_add_string, g_vm_add_string, g_vm_add_seq, g_vm_addl },
 [KArrR]   = { g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_add_string, g_vm_add_string, g_vm_add_seq, g_vm_addl },
 [KArrC]   = { g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_add_string, g_vm_add_string, g_vm_add_seq, g_vm_addl },
 [KArrO]   = { g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_addn, g_vm_add_string, g_vm_add_string, g_vm_add_seq, g_vm_addl },
 [KString] = { g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_seq, g_vm_addl },
 [KSym]    = { g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_seq, g_vm_addl },
 [KTwo]    = { g_vm_add_seq, g_vm_add_seq, g_vm_add_seq, g_vm_add_seq, g_vm_add_seq, g_vm_add_seq, g_vm_add_seq, g_vm_add_seq, g_vm_add_seq, g_vm_add_seq, g_vm_addl },
 [KLam]    = { g_vm_addl, g_vm_addl, g_vm_addl, g_vm_addl, g_vm_addl, g_vm_addl, g_vm_addl, g_vm_addl, g_vm_addl, g_vm_addl, g_vm_addl },
};
// `*`: the semiring product whose `+` is the lane above. numbers multiply, sequence
// * count repeats, lambdas compose (Church mul). seq*seq -> nil.
static g_vm_t *const g_mul_mx[KN][KN] = {
 [KFix]    = { g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mull },
 [KTuple]  = { g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mull },
 [KBig]    = { g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mull },
 [KArrZ]   = { g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mull },
 [KArrR]   = { g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mull },
 [KArrC]   = { g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mull },
 [KArrO]   = { g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_muln, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mull },
 [KString] = { g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_0, g_vm_0, g_vm_0, g_vm_mull },
 [KSym]    = { g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_0, g_vm_0, g_vm_0, g_vm_mull },
 [KTwo]    = { g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_mul_rep, g_vm_0, g_vm_0, g_vm_0, g_vm_mull },
 [KLam]    = { g_vm_mull, g_vm_mull, g_vm_mull, g_vm_mull, g_vm_mull, g_vm_mull, g_vm_mull, g_vm_mull, g_vm_mull, g_vm_mull, g_vm_mull },
};
// apply: [applied data kind = g_typ(Ip)][argument kind = g_kind(arg)]. Every row is
// arg-kind-uniform today (AROW fills all columns); the 2-D shape is the hook for
// later argument-kind branching (e.g. a number applied to a function vs a number).
#define AROW(h) { [KFix]=h,[KLam]=h,[KTwo]=h,[KTuple]=h,[KSym]=h,[KString]=h,[KBig]=h,\
                  [KArrZ]=h,[KArrR]=h,[KArrC]=h,[KArrO]=h }
g_vm_t *g_apply_mx[KN][KN] = {
 [KTwo]  = AROW(data_pair_apply), [KTuple]  = AROW(data_num_apply),
 [KSym]  = AROW(data_sym_apply),
 [KString] = AROW(data_string_apply), [KBig]  = AROW(data_num_apply), };
#undef AROW

// === the `+`/`*` dispatchers (fixnum fast path, then the matrix) ============
g_vm(g_vm_add) {
 word a = Sp[0], b = Sp[1]; intptr_t t;
 if (fixp(a) && fixp(b)
     && !__builtin_add_overflow((intptr_t) getfix(a), (intptr_t) getfix(b), &t)
     && t >= FIX_MIN && t <= FIX_MAX)
  return *++Sp = putfix(t), Ip++, Continue();
 return Ap(g_add_mx[g_kind(a)][g_kind(b)], g); }
g_vm(g_vm_mul) {
 word a = Sp[0], b = Sp[1];
 if (fixp(a) && fixp(b)) { intptr_t t;
  if (!__builtin_mul_overflow((intptr_t) getfix(a), (intptr_t) getfix(b), &t)
      && t >= FIX_MIN && t <= FIX_MAX)
   return *++Sp = putfix(t), Ip++, Continue(); }
 return Ap(g_mul_mx[g_kind(a)][g_kind(b)], g); }

AVM_DIV(fquot, /)                               // `//` fixnum fast path: truncating quotient
AVM_DIV(rem, %)
// `/` fixnum fast path: stay exact only when b divides a; otherwise the slow lane
// promotes to a float box. The INT_MIN/-1 guard precedes the `%` (it would be UB).
g_vm(g_vm_quot) {
 word a = Sp[0], b = Sp[1];
 if (fixp(a) && fixp(b)) { intptr_t av = getfix(a), bv = getfix(b);
  if (bv != 0 && !(av == INTPTR_MIN && bv == -1) && av % bv == 0) {
   intptr_t t = av / bv;
   if (t >= FIX_MIN && t <= FIX_MAX) return *++Sp = putfix(t), Ip++, Continue(); } }
 return Ap(g_vm_quotn, g); }

// The ordered comparisons (g_vm_lt/le/gt/ge) and their total order are defined
// after vcmp_int/vcmp_flo (the per-op trichotomy helpers), near g_vm_vbin.

// Bitwise and/or/xor: fast both-fixnum tag trick (two odds stay odd under &
// and |; ^ clears the tag bit so we re-set it). A box operand routes to the
// slow handler, which works at full width and demotes-or-boxes; these are
// integer-only, so a float (or any non-integer) operand yields nil.
BIT_SLOW(band, &) BIT_SLOW(bor, |) BIT_SLOW(bxor, ^)
g_vm(g_vm_band) { word a = Sp[0], b = Sp[1];
 if (fixp(a) && fixp(b)) return *++Sp = (a & b) | 1, Ip++, Continue();
 return Ap(g_vm_band_slow, g); }
g_vm(g_vm_bor) { word a = Sp[0], b = Sp[1];
 if (fixp(a) && fixp(b)) return *++Sp = (a | b) | 1, Ip++, Continue();
 return Ap(g_vm_bor_slow, g); }
g_vm(g_vm_bxor) { word a = Sp[0], b = Sp[1];
 if (fixp(a) && fixp(b)) return *++Sp = (a ^ b) | 1, Ip++, Continue();
 return Ap(g_vm_bxor_slow, g); }
// (bitwise complement is `(^ x -1)`; logical not is the `!` reader sigil / `nilp`.)

// >> : arithmetic right shift. A fixnum value only shrinks, so it keeps a
// non-allocating fast path; a boxed value routes to the slow handler.
static g_vm(g_vm_bsr_slow) { word a = Sp[0], b = Sp[1], _res;
 if (!(fixp(a) || boxp(a)) || !fixp(b)) return *++Sp = nil, Ip++, Continue();
 Have(BOX_REQ);
 EMIT_INT(TOINT(a) >> getfix(b));
 return *++Sp = _res, Ip++, Continue(); }
g_vm(g_vm_bsr) { word a = Sp[0], b = Sp[1];
 if (fixp(a) && fixp(b))
  return *++Sp = putfix(getfix(a) >> getfix(b)), Ip++, Continue();
 return Ap(g_vm_bsr_slow, g); }

// << : can overflow the tag, so it always runs through the box/demote path
// (EMIT_INT still demotes small results — only genuinely wide values
// allocate). Shift done in uintptr_t for well-defined overflow.
g_vm(g_vm_bsl) { word a = Sp[0], b = Sp[1], _res;
 if (!(fixp(a) || boxp(a)) || !fixp(b)) return *++Sp = nil, Ip++, Continue();
 Have(BOX_REQ);
 EMIT_INT((intptr_t)((uintptr_t) TOINT(a) << getfix(b)));
 return *++Sp = _res, Ip++, Continue(); }

op(g_vm_fixp, 1, oddp(Sp[0]) ? putfix(1) : nil)
// `nilp`/`not`: the falsy predicate -- the efficient generic form of (= 0 (len x)),
// via g_nilp, which short-circuits and never materializes len (a pair/sym/fn is truthy
// with no walk). The single truthiness oracle: `?` (g_vm_cond), nilp, and aall all
// consult g_nilp, so `(? (nilp e) a b)` == `(? e b a)` -- the wev pass drops such a
// nilp wrapper. Use `(= x 0)` for a literal scalar-zero test.
op11(g_vm_nilp, g_nilp(Sp[0]) ? putfix(1) : nil)

// Unary math nif: numeric arg → double, call fn, box the rank-0 f64 result.
// Non-numeric arg → nil. TCO-clean (no & escapes).
static g_vm(g_vm_math1, g_flo_t (*fn)(g_flo_t)) {
 word a = Sp[0];
 if (arrp(a)) {                               // (sin arr) etc. -> float array; complex array undefined
  if (tuple(a)->type == g_C) return Sp[0] = nil, Ip++, Continue();
  return Ap(g_vm_vmap1, g, fn); }
 if (!ISNUM(a)) return Sp[0] = nil, Ip++, Continue();
 g_flo_t ad = TOFLO(a), rd = fn(ad);
 uintptr_t req = Width(struct g_tuple) + Width(g_flo_t);
 Have(req);
 struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_R);
 Hp += req;
 flo_put(v->shape, rd);
 return Sp[0] = word(v), Ip++, Continue(); }

static g_vm(g_vm_math2, g_flo_t (*fn)(g_flo_t, g_flo_t)) {
 word a = Sp[0], b = Sp[1];
 if (arrp(a) || arrp(b)) {                               // (pow arr ..) etc. -> float array
  if ((arrp(a) && tuple(a)->type == g_C) || (arrp(b) && tuple(b)->type == g_C))
   return *++Sp = nil, Ip++, Continue();                 // complex array undefined here
  return Ap(g_vm_vmap2, g, fn); }
 if (!ISNUM(a) || !ISNUM(b)) return
  *++Sp = nil, Ip++, Continue();
 g_flo_t ad = TOFLO(a), bd = TOFLO(b), rd = fn(ad, bd);
 uintptr_t req = Width(struct g_tuple) + Width(g_flo_t);
 Have(req);
 struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_R);
 Hp += req;
 flo_put(v->shape, rd);
 return *++Sp = word(v), Ip++, Continue(); }


// g_sin .. g_pow are macro aliases (g/g.h) for the C library math
// functions: libm on hosted builds, k/libc.c on the freestanding
// kernel. The op generators reference them through g_##n, which the
// preprocessor rescans into the real names after pasting.
m1(mvm1)

op11(g_vm_flop, flop(Sp[0]) ? putfix(1) : nil)

// ============================================================================
// tuple
// ============================================================================
size_t const g_T[] = {
 [g_Z] = Bytes,
 [g_R] = Bytes,
 [g_C] = 2 * Bytes,      // complex scalar: (re, im)
 [g_O] = Bytes, };       // object: one tagged ll word per element

uintptr_t g_tuple_bytes(struct g_tuple *v) {
 return sizeof(struct g_tuple) + v->rank * sizeof(word) + g_T[v->type] * tuple_nelem(v); }

// ============================================================================
// rng
// ============================================================================
// Step 8 -- random numbers. xoshiro256++ (Blackman & Vigna, public domain)
// seeded by SplitMix64. State is a rank-1 i64 tuple of length 4 (256 bits) that
// rides the existing tuple machinery -- no data sentinel, no enum q / G_DATA_N
// / gen_data / wasm-vt changes (cf. complex, Step 7). The payload is treated
// as raw bytes (memcpy), never via the typed tuple_get/put accessors, so the
// 64-bit limbs survive on 32-bit ports and a given seed reproduces the same
// sequence on host/kernel/MCU/WASM/Playdate. Two stream flavors share the one
// representation: a global stream in g->rng (mutated in place by rand/randf) and
// a functional stream threaded explicitly (rand-next/randf-next copy the input
// state, step the copy, return (value . new-state) -- the input is never
// mutated). Not a CSPRNG. See [[project-todo-math]] step 8.

static g_inline uint64_t rotl64(uint64_t x, int k) {
 return (x << k) | (x >> (64 - k)); }

// All the uint64_t scratch (s[4]) lives in these g_noinline helpers that move it
// via memcpy: taking &s in a VM handler would defeat the Continue() sibcall (see
// the flo_get note in i.h), and memcpy is alignment-safe (a 32-bit port's
// tuple_data is only 4-byte aligned, so a raw uint64_t* deref could fault).

// Advance the 4-word state stored at `payload` and return one 64-bit draw.
static g_noinline uint64_t rng_step(void *payload) {
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
static g_noinline void rng_seed_into(void *payload, uint64_t seed) {
 uint64_t s[4], x = seed;
 for (int i = 0; i < RNG_STATE_LEN; i++) {
  uint64_t z = (x += (uint64_t) 0x9e3779b97f4a7c15);
  z = (z ^ (z >> 30)) * (uint64_t) 0xbf58476d1ce4e5b9;
  z = (z ^ (z >> 27)) * (uint64_t) 0x94d049bb133111eb;
  s[i] = z ^ (z >> 31); }
 if (!(s[0] | s[1] | s[2] | s[3])) s[0] = 1;
 memcpy(payload, s, sizeof s); }

// Map a 64-bit draw to a float in [0,1): keep the high mantissa bits and scale.
static g_inline g_flo_t u64_to_unit(uint64_t u) {
#if Bits >= 64
 return (g_flo_t) (u >> 11) * (g_flo_t) 0x1.0p-53;
#else
 return (g_flo_t) (uint32_t) (u >> 40) * (g_flo_t) 0x1.0p-24f;
#endif
}

// Shape v as an i64 state tuple (rank 1, len 4) and seed it. Exposed for the eager
// seed in g_ini_0. ini_tuple + a pointer write only, so an inlining caller keeps
// its tail call; the &s scratch stays inside rng_seed_into.
void g_rng_seed(struct g_tuple *v, uint64_t seed) {
 ini_tuple(v, RNG_VT, 1);
 v->shape[0] = RNG_STATE_LEN;
 rng_seed_into(tuple_data(v), seed); }

// Is x a well-formed state tuple (rank-1 i64, length 4)?
static g_inline bool rng_state_p(word x) {
 return tupp(x) && tuple(x)->rank == 1 && tuple(x)->type == RNG_VT
        && tuple(x)->shape[0] == RNG_STATE_LEN; }

// Build a fresh state tuple at Hp, copying the 4 limbs of `src` into it. Caller
// holds Have(RNG_VEC_REQ). Both pointers are heap pointers -> no &local escape.
static g_inline struct g_tuple *rng_copy(g_word **hp, struct g_tuple *src) {
 struct g_tuple *v = (struct g_tuple*) *hp;
 *hp += RNG_VEC_REQ;
 ini_tuple(v, RNG_VT, 1);
 v->shape[0] = RNG_STATE_LEN;
 memcpy(tuple_data(v), tuple_data(src), RNG_PAYLOAD_BYTES);
 return v; }

// (rng-seed n): a fresh state tuple deterministically seeded from fixnum n. A
// non-fixnum seeds from 0.
g_vm(g_vm_rng_seed) {
 word n = Sp[0];
 uint64_t seed = fixp(n) ? (uint64_t) (intptr_t) getfix(n) : 0;
 Have(RNG_VEC_REQ);
 struct g_tuple *v = (struct g_tuple*) Hp; Hp += RNG_VEC_REQ;
 g_rng_seed(v, seed);
 return Sp[0] = word(v), Ip++, Continue(); }

// (rng-get _): a snapshot copy of the global state tuple (never aliases it).
g_vm(g_vm_rng_get) {
 Have(RNG_VEC_REQ);
 struct g_tuple *src = tuple(g->rng);            // re-read post-Have (GC may move it)
 struct g_tuple *v = rng_copy(&Hp, src);
 return Sp[0] = word(v), Ip++, Continue(); }

// (rng-set v): install v's 4 limbs into the global state (copies, never aliases),
// returning v; nil if v isn't a valid state tuple.
g_vm(g_vm_rng_set) {
 word v = Sp[0];
 if (!rng_state_p(v)) return Sp[0] = nil, Ip++, Continue();
 memcpy(tuple_data(tuple(g->rng)), tuple_data(tuple(v)), RNG_PAYLOAD_BYTES);
 return Ip++, Continue(); }            // Sp[0] (== v) is the result

// (rand n): global draw, fixnum in [0,n); n <= 0 (incl. nil) -> a full-width
// non-negative fixnum. No allocation (the result is always a fixnum), so no Have
// and no GC concern from mutating g->rng in place.
g_vm(g_vm_rand) {
 word n = Sp[0];
 uint64_t r = rng_step(tuple_data(tuple(g->rng)));
 intptr_t out = fixp(n) && getfix(n) > 0
   ? (intptr_t) (r % (uint64_t) getfix(n))
   : (intptr_t) (r & (uint64_t) FIX_MAX);
 return Sp[0] = putfix(out), Ip++, Continue(); }

// (randf _): global draw, float in [0,1). Have() runs before stepping so a
// GC-triggered handler restart doesn't double-advance the state.
g_vm(g_vm_randf) {
 word _res;
 Have(BOX_REQ);
 uint64_t r = rng_step(tuple_data(tuple(g->rng)));
 g_flo_t u = u64_to_unit(r);
 EMIT_FLO(u);
 return Sp[0] = _res, Ip++, Continue(); }

// (rand-next st): functional draw -> (value . st'), value a full-width
// non-negative fixnum. st is copied (referentially transparent); st' is the
// stepped copy.
g_vm(g_vm_rand_next) {
 word st = Sp[0];
 if (!rng_state_p(st)) return Sp[0] = nil, Ip++, Continue();
 Have(RNG_VEC_REQ + Width(struct g_pair));
 st = Sp[0];                                 // re-read post-Have
 struct g_tuple *v = rng_copy(&Hp, tuple(st));
 uint64_t r = rng_step(tuple_data(v));
 struct g_pair *p = (struct g_pair*) Hp; Hp += Width(struct g_pair);
 ini_two(p, putfix((intptr_t) (r & (uint64_t) FIX_MAX)), word(v));
 return Sp[0] = word(p), Ip++, Continue(); }

// (randf-next st): functional draw -> (float . st'), float in [0,1).
g_vm(g_vm_randf_next) {
 word st = Sp[0], _res;
 if (!rng_state_p(st)) return Sp[0] = nil, Ip++, Continue();
 Have(RNG_VEC_REQ + BOX_REQ + Width(struct g_pair));
 st = Sp[0];                                 // re-read post-Have
 struct g_tuple *v = rng_copy(&Hp, tuple(st));
 uint64_t r = rng_step(tuple_data(v));
 g_flo_t u = u64_to_unit(r);
 EMIT_FLO(u);                                // box at Hp, into _res
 struct g_pair *p = (struct g_pair*) Hp; Hp += Width(struct g_pair);
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
static bool g_isbs(word h) {                                // h is the `\` symbol?
 struct g_str *n; return symp(h) && (n = sym(h)->nom) && n->len == 1 && n->bytes[0] == '\\'; }
static bool salpha(struct g *g, word a, word b, struct arib *env) {
 if (symp(a) || symp(b)) {
  if (!symp(a) || !symp(b)) return false;
  for (struct arib *r = env; r; r = r->up) {
   int ia = arib_pos(a, r->la, r->na), ib = arib_pos(b, r->lb, r->nb);
   if (ia >= 0 || ib >= 0) return ia == ib; }               // bound at this rib: positions agree
  return a == b; }                                          // both free: same symbol
 if (!twop(a) || !twop(b)) return eqv(g, a, b);             // numbers / strings / atoms
 if (g_isbs(A(a)) && g_isbs(A(b))) {                        // both `\`-headed
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
static uintptr_t shash(struct g *g, word x, struct arib *env) {
 if (symp(x)) {
  int d = 0;
  for (struct arib *r = env; r; r = r->up, d++) {
   int i = arib_pos(x, r->la, r->na);
   if (i >= 0) return rot((uintptr_t) (d * 131 + i + 1) * mix); }
  return sym(x)->code; }
 if (!twop(x)) return hash(g, x);
 if (g_isbs(A(x))) {
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
static word lam_src1(struct g *c, word v) {           // 1-binder lambda -> (binder body), else 0
 if (!lamp(v) || datp(v)) return 0;
 if (!(ptr(v) > ptr(c) && ptr(v) < ptr(c) + c->len)) return 0;  // in-pool only: k[-1]/k valid
 union u *k = cell(v);
 if (fn_partialp(k)) return 0;
 word s = fn_src(c, k, v);                            // s = (\ b.. body)
 if (!s || !gz_islam(s)) return 0;
 word ops = B(s);                                     // (binder body ..)
 return !twop(B(B(ops))) && symp(A(ops)) ? ops : 0; } // exactly one binder
static bool id_lam(struct g *c, word v) {             // (\ x x): body IS the binder
 word ops = lam_src1(c, v);
 return ops && A(ops) == A(B(ops)); }
static bool k1_lam(struct g *c, word v) {             // (\ _ 1): body is the literal 1
 word ops = lam_src1(c, v);
 return ops && A(B(ops)) == putfix(1); }
g_noinline bool eqv(struct g *g, word a, word b) {
 word *base = off_pool(g), *top = base + g->len, *w = base;
 struct g *c = g_core_of(g);
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
   if ((a == putfix(1) && id_lam(c, b)) || (b == putfix(1) && id_lam(c, a))) { a = b; continue; }
   if ((a == putfix(0) && k1_lam(c, b)) || (b == putfix(0) && k1_lam(c, a))) { a = b; continue; }
   if (((a | b) & 1) || !datp(a) || !datp(b) || typ(a) != typ(b)) return false;
   switch (typ(a)) {
    default: return false;
    case KTwo:
     if (top - w < 2) __builtin_trap();     // worklist overflow: a cycle
     *w++ = B(a), *w++ = B(b), a = A(a), b = A(b);
     continue;
    case KTuple: {
     size_t la = g_tuple_bytes(tuple(a)), lb = g_tuple_bytes(tuple(b));
     if (la != lb || memcmp(tuple(a), tuple(b), la)) return false;
     break; }
    case KBig: {
     struct g_big *x = (struct g_big*) a, *y = (struct g_big*) b;
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
// wide-int boxes match through eqv's tuple arm (g_tuple_bytes covers the type +
// payload), while a box and a fixnum never collide since boxes hold only
// out-of-fixnum-range values. Falls through to eql for non-numeric operands so
// symbol/pair/string identity is unchanged. Strictly looser than eqv, which
// still rejects mixed-type pairs (so table keys 3 and 3.0 stay distinct).
g_vm(g_vm_eq) {
 word a = Sp[0], b = Sp[1];
 // Over a rank>=1 array, `=` is elementwise -> a 0/1 bool array (whole-array
 // equality is `(aall (= a b))`). Rank-0 boxes stay scalar (handled below).
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, g, VOP_EQ);
 // Complex equality: equal iff re and im match. A real operand reads as (r, 0),
 // so the cross-real case `(= (cplx 2 0) 2)` is true (numeric widening, like
 // `(= 2 2.0)`); a non-numeric operand makes it false. Done before the float
 // lane so a complex never reaches TOFLO (which would misread its two words).
 if (Cp(a) || Cp(b)) {
  bool r = (Cp(a) || ISNUM(a)) && (Cp(b) || ISNUM(b))
        && (Cp(a) ? cplx_re(a) : TOFLO(a)) == (Cp(b) ? cplx_re(b) : TOFLO(b))
        && (Cp(a) ? cplx_im(a) : 0) == (Cp(b) ? cplx_im(b) : 0);
  Sp[1] = r ? putfix(1) : nil;
  return Sp++, Ip++, Continue(); }
 bool r;
 // A float operand compares as doubles across the whole numeric tower (fixnum /
 // float box / wide-int box / bignum all widen via TOFLO; a bignum loses
 // precision past 2^53, the documented float caveat). Otherwise eql: two equal
 // bignums match through eqv's KBig arm, and canonical demotion keeps a bignum
 // distinct from any fixnum/box of a different value.
 if (flop(a) || flop(b)) r = ISNUM(a) && ISNUM(b) && (TOFLO(a) == TOFLO(b));
 else r = eql(g, a, b);
 Sp[1] = r ? putfix(1) : nil;
 return Sp++, Ip++, Continue(); }

// (same a b) — pointer/word identity, no structural recursion. Distinguishes
// two distinct objects that `=` would conflate (e.g. two equal pairs), so the
// compiler can find a unique marker by identity.
g_vm(g_vm_same) {
 Sp[1] = Sp[0] == Sp[1] ? putfix(1) : nil;
 return Sp++, Ip++, Continue(); }

// ============================================================================
// big
// ============================================================================
// Step 6 -- arbitrary-precision integers (bignums). Closes the numeric tower
// fixnum -> wide-int box -> bignum. The representation is the KBig data
// sentinel `struct g_big` (i.h): sign-magnitude, 32-bit base-2^32 limbs,
// little-endian, top limb nonzero, slen the signed limb count. Zero is never a
// bignum (it demotes to nil), so every bignum has |slen| >= 1 limbs.
//
// All multi-limb work lives in g_noinline magnitude helpers operating on raw
// uint32_t arrays (no ll pointers, no allocation), so the VM-facing entry
// points keep their tail calls and the GC never sees a half-built object. The
// arithmetic uses 32-bit limbs with a uint64_t accumulator on every target:
// limb products fit a uint64_t and Knuth divmod's 2-limb/1-limb step needs no
// __int128 (not guaranteed on freestanding 32-bit ports). Schoolbook mul +
// Knuth Algorithm D divmod -- Karatsuba/Toom are a later speed diff.


// |slen| of a heap bignum.
static g_inline int big_nlimbs(word x) {
 intptr_t s = ((struct g_big*) x)->slen;
 return (int) (s < 0 ? -s : s); }

uintptr_t g_big_bytes(struct g_big *b) {
 intptr_t n = b->slen < 0 ? -b->slen : b->slen;
 return sizeof(struct g_big) + (uintptr_t) n * sizeof(uint32_t); }

// --- raw magnitude primitives (little-endian uint32_t limb arrays) ----------
// Callers pass normalized inputs (no leading zero limbs) and normalize outputs
// via g_big_canon, which strips leading zeros itself.

static int mag_copy(uint32_t *dst, uint32_t const *src, int n) {
 for (int i = 0; i < n; i++) dst[i] = src[i];
 return n; }

// Compare magnitudes: -1 if a<b, 0 if equal, 1 if a>b.
static g_noinline int mag_cmp(uint32_t const *a, int na, uint32_t const *b, int nb) {
 while (na > 0 && a[na-1] == 0) na--;
 while (nb > 0 && b[nb-1] == 0) nb--;
 if (na != nb) return na < nb ? -1 : 1;
 for (int i = na - 1; i >= 0; i--) if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
 return 0; }

// r = a + b. r distinct from a,b; capacity >= max(na,nb)+1. Returns limb count.
static g_noinline int mag_add(uint32_t *r, uint32_t const *a, int na, uint32_t const *b, int nb) {
 if (na < nb) { uint32_t const *t = a; a = b; b = t; int u = na; na = nb; nb = u; }
 uint64_t c = 0; int i = 0;
 for (; i < nb; i++) { uint64_t s = (uint64_t) a[i] + b[i] + c; r[i] = (uint32_t) s; c = s >> 32; }
 for (; i < na; i++) { uint64_t s = (uint64_t) a[i] + c;        r[i] = (uint32_t) s; c = s >> 32; }
 if (c) r[i++] = (uint32_t) c;
 return i; }

// r = a - b, requires a >= b (magnitudes). r distinct from a,b. Returns na
// (caller normalizes away any high zero limbs the subtraction produced).
static g_noinline int mag_sub(uint32_t *r, uint32_t const *a, int na, uint32_t const *b, int nb) {
 int64_t borrow = 0; int i = 0;
 for (; i < nb; i++) {
  int64_t d = (int64_t) a[i] - b[i] - borrow;
  if (d < 0) d += (int64_t) LIMB_BASE, borrow = 1; else borrow = 0;
  r[i] = (uint32_t) d; }
 for (; i < na; i++) {
  int64_t d = (int64_t) a[i] - borrow;
  if (d < 0) d += (int64_t) LIMB_BASE, borrow = 1; else borrow = 0;
  r[i] = (uint32_t) d; }
 return na; }

// r = a * b (schoolbook). r must be distinct from a,b; capacity >= na+nb. Used
// one-shot by g_big_binop (the object-array elementwise lane); the scalar `*`
// path instead drives a chunked, yieldable copy of this loop in g_vm_bmul.
static g_noinline void mag_mul(uint32_t *r, uint32_t const *a, int na, uint32_t const *b, int nb) {
 for (int i = 0; i < na + nb; i++) r[i] = 0;
 for (int i = 0; i < na; i++) {
  uint64_t carry = 0, ai = a[i];
  for (int j = 0; j < nb; j++) {
   uint64_t s = ai * b[j] + r[i+j] + carry;
   r[i+j] = (uint32_t) s; carry = s >> 32; }
  r[i+nb] = (uint32_t) carry; } }

// a = a*mul + add, in place (mul,add < 2^32). a capacity must allow one carry
// limb at a[n]. Returns the new limb count. Used by the decimal reader.
static g_noinline int mag_mul_add_small(uint32_t *a, int n, uint32_t mul, uint32_t add) {
 uint64_t c = add;
 for (int i = 0; i < n; i++) { uint64_t s = (uint64_t) a[i] * mul + c; a[i] = (uint32_t) s; c = s >> 32; }
 if (c) a[n++] = (uint32_t) c;
 return n; }

// a /= d in place (d != 0), returning the remainder. Used by the printer.
static g_noinline uint32_t mag_divmod_small(uint32_t *a, int n, uint32_t d) {
 uint64_t rem = 0;
 for (int i = n - 1; i >= 0; i--) { uint64_t cur = (rem << 32) | a[i]; a[i] = (uint32_t) (cur / d); rem = cur % d; }
 return (uint32_t) rem; }

// Knuth Algorithm D long division (Hacker's Delight `divmnu`). Divides u (m
// limbs) by v (n limbs, v[n-1] != 0, m >= n): q gets the m-n+1 quotient limbs,
// r the n remainder limbs. un (scratch, >= m+1) and vn (scratch, >= n) hold the
// normalized dividend/divisor. q,r,un,vn all distinct from u,v.
static g_noinline void mag_divmod(uint32_t *q, uint32_t *r,
  uint32_t const *u, int m, uint32_t const *v, int n, uint32_t *un, uint32_t *vn) {
 uint64_t const B = LIMB_BASE;
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
 if (bigp(x)) { struct g_big *b = (struct g_big*) x; intptr_t s = b->slen;
  *neg = s < 0, *out = b->limb; return (int) (s < 0 ? -s : s); }
 intptr_t v = fixp(x) ? (intptr_t) getfix(x) : box_get(x);
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

g_flo_t g_big_to_flo(word x) {
 struct g_big *b = (struct g_big*) x;
 intptr_t sl = b->slen;
 bool neg = sl < 0;
 int n = (int) (neg ? -sl : sl);
 double r = 0;
 for (int i = n - 1; i >= 0; i--) r = r * 4294967296.0 + (double) b->limb[i];
 return (g_flo_t) (neg ? -r : r); }

// The bignum's two's-complement value mod 2^W (its low machine word). Used when
// an integer-array elementwise op must broadcast a bignum scalar down to one
// machine-int element ("arrays win; demote the bignum by its low bits").
intptr_t g_big_low(word x) {
 struct g_big *b = (struct g_big*) x;
 intptr_t sl = b->slen;
 bool neg = sl < 0;
 uintptr_t u = b->limb[0];
#if Bits == 64
 int n = (int) (neg ? -sl : sl);   // limb count only consulted for the 2nd limb
 if (n >= 2) u |= ((uintptr_t) b->limb[1] << 16) << 16;
#endif
 return (intptr_t) (neg ? (uintptr_t) 0 - u : u); }

int g_big_cmp(word a, word b) {
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
word g_big_canon(g_word **hp, uint32_t const *limb, int n, bool neg) {
 while (n > 0 && limb[n-1] == 0) n--;
 if (n == 0) return nil;
 int const wlimbs = Bits / 32;                 // 2 on 64-bit, 1 on 32-bit ports
 if (n <= wlimbs) {
  uintptr_t u = limb[0];
  if (wlimbs == 2 && n == 2) u |= ((uintptr_t) limb[1] << 16) << 16;
  uintptr_t const fixmag = (uintptr_t) 1 << (Bits - 2);   // |FIX_MIN|  = 2^(W-2)
  uintptr_t const boxmag = (uintptr_t) 1 << (Bits - 1);   // |INT_MIN|  = 2^(W-1)
  intptr_t val;
  if (!neg) {
   if (u <= fixmag - 1) return putfix((intptr_t) u);       // FIX_MAX = 2^(W-2)-1
   if (u > boxmag - 1) goto big;                            // > INTPTR_MAX -> bignum
   val = (intptr_t) u; }
  else {
   if (u <= fixmag) return putfix((intptr_t) ((uintptr_t) 0 - u));   // incl FIX_MIN
   if (u > boxmag) goto big;                                          // < INTPTR_MIN -> bignum
   val = (intptr_t) ((uintptr_t) 0 - u); }                            // incl INTPTR_MIN
  struct g_tuple *bx = ini_scalar((struct g_tuple*) *hp, g_Z);
  *hp += BOX_REQ; box_put(bx->shape, val); return word(bx); }
big:;
 struct g_big *b = ini_big((struct g_big*) *hp, neg ? -n : n);
 for (int i = 0; i < n; i++) b->limb[i] = limb[i];
 *hp += b2w(sizeof(struct g_big) + (size_t) n * sizeof(uint32_t));
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
// Pack(g); g = g_big_binop(g, vop); Unpack(g); Continue();  (cf. g_vm_gc).
struct g *g_big_binop(struct g *g, int vop) {
 word a = g->sp[0], b = g->sp[1];
 int na = bigp(a) ? big_nlimbs(a) : 2, nb = bigp(b) ? big_nlimbs(b) : 2;
 int bound = na + nb + 2;                        // result magnitude upper bound
 int work = 4 * (na + nb) + 16;                  // divmod scratch upper bound
 uintptr_t res_area = Width(struct g_big) + b2w((size_t) bound * 4),
           ws_words = b2w((size_t) (bound + work) * 4);
 if (!g_ok(g = g_have(g, res_area + ws_words))) return g;
 a = g->sp[0], b = g->sp[1];                     // re-fetch (g_have may have GC'd)
 uint32_t sa[2], sb[2]; uint32_t const *la, *lb; bool nega, negb;
 int nla = load_int_mag(a, sa, &la, &nega), nlb = load_int_mag(b, sb, &lb, &negb);
 uint32_t *rmag = (uint32_t*) (g->hp + res_area), *scr = rmag + bound;
 int rn = 0; bool rneg = false;
 switch (vop) {
  case VOP_ADD: big_addsub(rmag, &rn, &rneg, la, nla, nega, lb, nlb, negb, false); break;
  case VOP_SUB: big_addsub(rmag, &rn, &rneg, la, nla, nega, lb, nlb, negb, true); break;
  case VOP_MUL: rn = big_mul_mag(rmag, la, nla, lb, nlb); rneg = nega != negb; break;
  default: {                                     // VOP_QUOT / VOP_REM (truncated)
   int c = mag_cmp(la, nla, lb, nlb);
   if (c < 0) {                                  // |a| < |b|: q = 0, r = a
    if (vop == VOP_REM) rn = mag_copy(rmag, la, nla), rneg = nega; }
   else {
    uint32_t *q = scr, *rem = q + (nla - nlb + 1), *un = rem + nlb, *vn = un + (nla + 1);
    mag_divmod(q, rem, la, nla, lb, nlb, un, vn);
    if (vop != VOP_REM) {                          // VOP_QUOT / VOP_FQUOT: truncated quotient
     int qn = nla - nlb + 1; while (qn > 0 && q[qn-1] == 0) qn--;
     rn = mag_copy(rmag, q, qn), rneg = nega != negb; }
    else {
     int rr = nlb; while (rr > 0 && rem[rr-1] == 0) rr--;
     rn = mag_copy(rmag, rem, rr), rneg = nega; } } } }
 g->sp[1] = g_big_canon(&g->hp, rmag, rn, rneg);
 g->sp++;
 g->ip = (union u*) g->ip + 1;
 return g; }

// `/` over the bignum lane: like g_big_binop's truncated quotient, but the result
// stays an exact integer ONLY when b divides a; a nonzero remainder promotes to a
// float box of a/b (the bignum analogue of the scalar `/` int promotion). Operands
// at g->sp[0..1] are integers; a zero divisor is screened off by the caller.
struct g *g_big_quot_true(struct g *g) {
 word a = g->sp[0], b = g->sp[1];
 g_flo_t fa = TOFLO(a), fb = TOFLO(b);          // captured before any allocation
 int na = bigp(a) ? big_nlimbs(a) : 2, nb = bigp(b) ? big_nlimbs(b) : 2;
 int bound = na + nb + 2, work = 4 * (na + nb) + 16;
 uintptr_t res_area = Width(struct g_big) + b2w((size_t) bound * 4),
           ws_words = b2w((size_t) (bound + work) * 4);
 if (!g_ok(g = g_have(g, res_area + ws_words + BOX_REQ))) return g;
 a = g->sp[0], b = g->sp[1];                     // re-fetch (g_have may have GC'd)
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
 if (exact) g->sp[1] = g_big_canon(&g->hp, rmag, rn, rneg);
 else { struct g_tuple *v = ini_scalar((struct g_tuple*) g->hp, g_R);
  g->hp += BOX_REQ; flo_put(v->shape, fa / fb); g->sp[1] = word(v); }
 g->sp++;
 g->ip = (union u*) g->ip + 1;
 return g; }

// --- resumable (yieldable) multiply -----------------------------------------
// Schoolbook multiply is O(na*nb) and, run as one C call, never yields -- so a
// peer task (the repl's Ctrl-C poller) can't interrupt a huge product. Instead
// we drive it as a self-looping VM instruction: the partial product lives in a
// buf (flat bytes, GC-relocates safely), and each dispatch folds ~BMUL_CHUNK
// limb-mults of rows, then re-dispatches with a YieldCheck. The work state rides
// the ll stack [i, r, ret_ip, a, b] -- a yield saves/restores it, so the
// product resumes exactly where it paused. Ip parks on bmul_loop while looping;
// on completion it jumps back to ret_ip (the instruction after `*`).
// Operands a,b are kept as heap bignums so the loop reads stable limb pointers
// directly: a tail-jumping handler must NOT take the address of a stack local
// (it blocks the sibcall), which rules out load_int_mag's scratch array. Setup
// (which may use scratch) is hoisted into a plain function, g_bmul_setup.
#define BMUL_CHUNK (1 << 14)
static union u const bmul_loop[1] = { { .ap = g_vm_bmul } };

// Materialize integer x (fixnum/box/bignum) as a heap g_big, bumping *hp for the
// fixnum/box case; a bignum is returned in place. Plain function: scratch is fine.
static union u *as_big(g_word **hp, word x) {
 if (bigp(x)) return cell(x);
 intptr_t v = TOINT(x);
 bool neg = v < 0;
 uintptr_t u = neg ? (uintptr_t) 0 - (uintptr_t) v : (uintptr_t) v;
 uint32_t lo = (uint32_t) u, hi = (uint32_t) ((u >> 16) >> 16);   // hi=0 on 32-bit ports
 int n = hi ? 2 : lo ? 1 : 0;
 struct g_big *b = ini_big((struct g_big*) *hp, neg ? -n : n);
 if (n >= 1) b->limb[0] = lo;
 if (n >= 2) b->limb[1] = hi;
 *hp += b2w(sizeof(struct g_big) + (size_t) n * 4);
 return cell((word) b); }

// g->sp[0]=a g->sp[1]=b (integers whose product overflows a word). Promote both
// to bignums, allocate the zeroed result buf, and lay out the work frame; on
// return g->ip is bmul_loop. One g_have so no half-built state is ever seen.
static struct g *g_bmul_setup(struct g *g) {
 word a = g->sp[0], b = g->sp[1];
 int na = bigp(a) ? big_nlimbs(a) : 2, nb = bigp(b) ? big_nlimbs(b) : 2;
 uintptr_t rbytes = (uintptr_t) (na + nb) * 4,
           sreq = str_type_width + b2w(rbytes),
           breq = Width(struct g_buf) + Width(struct g_tag),
           bigmax = Width(struct g_big) + b2w(2 * 4);
 if (!g_ok(g = g_have(g, 2 * bigmax + sreq + breq + 3))) return g;
 a = g->sp[0], b = g->sp[1];                       // re-fetch (g_have may have GC'd)
 union u *abig = as_big(&g->hp, a), *bbig = as_big(&g->hp, b), *ret = g->ip + 1;
 struct g_str *s = ini_str((struct g_str*) g->hp, rbytes);
 g->hp += sreq; memset(txt(s), 0, rbytes);
 union u *k = (union u*) g->hp; g->hp += breq;
 ((struct g_buf*) k)->ap = g_vm_buf, ((struct g_buf*) k)->str = s, tagthd(k, Width(struct g_buf));
 g->sp -= 3;                                       // [i, r, ret_ip, abig, bbig]
 g->sp[0] = putfix(0), g->sp[1] = word(k), g->sp[2] = word(ret);
 g->sp[3] = word(abig), g->sp[4] = word(bbig);
 g->ip = (union u*) bmul_loop;
 return g; }

g_vm(g_vm_bmul_start) {
 Pack(g); g = g_bmul_setup(g);
 if (!g_ok(g)) return gtrap(g);
 return Unpack(g), Continue(); }

g_vm(g_vm_bmul) {
 int i = (int) getfix(Sp[0]);
 struct g_big *A = (struct g_big*) Sp[3], *B = (struct g_big*) Sp[4];
 intptr_t sla = A->slen, slb = B->slen;
 int na = sla < 0 ? -sla : sla, nb = slb < 0 ? -slb : slb;
 if (!na || !nb) {                                // a zero operand: product is 0
  word ret = Sp[2]; return Sp += 4, Sp[0] = nil, Ip = cell(ret), Continue(); }
 uint32_t *la = A->limb, *lb = B->limb, *rl = (uint32_t*) txt(buf_str(Sp[1]));
 int end = MIN(i + MAX(1, BMUL_CHUNK / nb), na);
 for (; i < end; i++) {                           // schoolbook outer loop, one chunk of rows
  uint64_t carry = 0, ai = la[i];
  for (int j = 0; j < nb; j++) {
   uint64_t t = ai * lb[j] + rl[i+j] + carry;
   rl[i+j] = (uint32_t) t, carry = t >> 32; }
  rl[i+nb] = (uint32_t) carry; }
 Sp[0] = putfix(i);                               // persist progress before any yield/GC
 if (i < na) { YieldCheck(); return Continue(); }
 bool neg = (sla < 0) != (slb < 0); word ret;     // done: canonicalize the product
 Have(Width(struct g_big) + b2w((size_t) (na + nb) * 4));
 ret = Sp[2]; uint32_t *rmag = (uint32_t*) txt(buf_str(Sp[1]));   // re-fetch (Have may have GC'd)
 Pack(g);                                          // canon needs the synced g->hp (not &Hp: stack-local escapes block the sibcall)
 word res = g_big_canon(&g->hp, rmag, na + nb, neg);
 Unpack(g);
 return Sp += 4, Sp[0] = res, Ip = cell(ret), Continue(); }

// --- reader / printer -------------------------------------------------------

// g->sp[0] is a [+-]?[0-9]+ token string; replace it with the canonical value
// (fixnum / box / bignum). Accumulates 9 decimal digits per mul-add pass.
struct g *g_big_read_dec(struct g *g) {
 struct g_str *tok = str(g->sp[0]);
 uintptr_t n = tok->len;
 char const *s = tok->bytes;
 bool neg = n && s[0] == '-';
 uintptr_t i = (n && (s[0] == '-' || s[0] == '+')) ? 1 : 0, ndig = n - i;
 int cap = (int) (ndig / 9) + 3;                 // upper-bound magnitude limbs
 uintptr_t res_area = Width(struct g_big) + b2w((size_t) cap * 4);
 if (!g_ok(g = g_have(g, res_area + b2w((size_t) cap * 4)))) return g;
 tok = str(g->sp[0]), s = tok->bytes;            // re-fetch post-GC
 uint32_t *mag = (uint32_t*) (g->hp + res_area);
 int m = 0;
 while (i < n) {
  uint32_t chunk = 0, pw = 1; int k = 0;
  for (; i < n && k < 9; i++, k++) chunk = chunk * 10 + (uint32_t) (s[i] - '0'), pw *= 10;
  m = mag_mul_add_small(mag, m, pw, chunk); }
 g->sp[0] = g_big_canon(&g->hp, mag, m, neg);
 return g; }

// g->sp[0] is a bignum; replace it with its base-10 string (with sign). Builds
// the digits into a fresh g_str by repeated divide-by-10 of a heap-local copy
// of the magnitude; no allocation (hence no GC) once the single Have lands, so
// the work buffer and the string stay put through the loop.
struct g *g_big_dec(struct g *g) {
 struct g_big *a = (struct g_big*) g->sp[0];
 intptr_t sl = a->slen;
 bool neg = sl < 0;
 int n = (int) (neg ? -sl : sl),
     cap = n * 10 + 2 + (neg ? 1 : 0);           // upper-bound bytes (1 limb ~ 9.633 digits)
 uintptr_t str_words = str_type_width + b2w((size_t) cap),
           scratch_words = b2w((size_t) n * 4);
 if (!g_ok(g = g_have(g, str_words + scratch_words))) return g;
 a = (struct g_big*) g->sp[0];                   // re-fetch post-GC
 struct g_str *st = (struct g_str*) g->hp;
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

// --- (arr type shape-list): zero-filled array ------------------------------
// `type` is a fixnum element-type code (i64/f64/c/o, named in the prelude); `shape`
// is a list of non-negative fixnum dimensions (empty -> a rank-0 scalar box). A
// `c` array packs two floats (re,im) per element; zero-fill is 0+0i. Bad type /
// negative dim / over-rank -> nil.
g_vm(g_vm_arr) {
 word t = Sp[0], shp = Sp[1];
 if (!fixp(t)) return *++Sp = nil, Ip++, Continue();
 intptr_t ty = getfix(t);
 if (ty < 0 || ty > g_O) return *++Sp = nil, Ip++, Continue();
 uintptr_t rank = 0, nelem = 1;
 for (word l = shp; twop(l); l = B(l)) {
  word d = A(l);
  if (!fixp(d) || getfix(d) < 0) return *++Sp = nil, Ip++, Continue();
  rank++, nelem *= (uintptr_t) getfix(d); }
 if (rank > G_VEC_MAXRANK || (ty == g_O && rank == 0)) return *++Sp = nil, Ip++, Continue();
 uintptr_t bytes = sizeof(struct g_tuple) + rank * sizeof(word) + nelem * g_T[ty];
 Have(b2w(bytes));
 struct g_tuple *v = (struct g_tuple*) Hp;
 Hp += b2w(bytes);
 ini_tuple(v, ty, rank);
 uintptr_t i = 0;                              // re-walk the (possibly moved) list
 for (word l = Sp[1]; twop(l); l = B(l)) v->shape[i++] = (uintptr_t) getfix(A(l));
 if (ty == g_O) for (i = 0; i < nelem; i++) tuple_put_obj(v, i, nil);   // object zero = nil, NOT raw 0
 else memset(tuple_data(v), 0, nelem * g_T[ty]);
 return *++Sp = word(v), Ip++, Continue(); }

// (arrl type shape-list vals-list): like arr, but fills row-major from
// vals-list (a non-numeric or missing entry stays 0; extras are ignored). Lets
// code build a specific array before array-literal syntax lands.
g_vm(g_vm_arrl) {
 word t = Sp[0], shp = Sp[1];                  // vals = Sp[2]
 if (!fixp(t)) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 intptr_t ty = getfix(t);
 if (ty < 0 || ty > g_O) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 uintptr_t rank = 0, nelem = 1;
 for (word l = shp; twop(l); l = B(l)) {
  word d = A(l);
  if (!fixp(d) || getfix(d) < 0) return Sp[2] = nil, Sp += 2, Ip++, Continue();
  rank++, nelem *= (uintptr_t) getfix(d); }
 if (rank > G_VEC_MAXRANK || (ty == g_O && rank == 0)) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 uintptr_t bytes = sizeof(struct g_tuple) + rank * sizeof(word) + nelem * g_T[ty];
 Have(b2w(bytes));
 struct g_tuple *v = (struct g_tuple*) Hp;
 Hp += b2w(bytes);
 ini_tuple(v, ty, rank);
 uintptr_t i = 0;                              // re-walk the (possibly moved) lists
 for (word l = Sp[1]; twop(l); l = B(l)) v->shape[i++] = (uintptr_t) getfix(A(l));
 if (ty == g_O) for (i = 0; i < nelem; i++) tuple_put_obj(v, i, nil);
 else memset(tuple_data(v), 0, nelem * g_T[ty]);
 i = 0;                                        // no alloc below, so v/Sp[2] stay put
 for (word l = Sp[2]; twop(l) && i < nelem; l = B(l), i++) {
  word e = A(l);
  if (ty == g_O) { tuple_put_obj(v, i, e); continue; }   // store any value verbatim
  if (ty == g_C) {                                        // pack (re,im): a real -> (r,0)
   g_flo_t *fp = tuple_data(v);
   if (Cp(e)) fp[2*i] = cplx_re(e), fp[2*i+1] = cplx_im(e);
   else if (ISNUM(e)) fp[2*i] = TOFLO(e), fp[2*i+1] = 0;
   continue; }
  if (!ISNUM(e)) continue;
  if (ty >= g_R) tuple_put_flo(v, i, TOFLO(e));
  else tuple_put_int(v, i, fixp(e) ? (intptr_t) getfix(e)
                       : flop(e) ? (intptr_t) flo_get(e) : box_get(e)); }
 return Sp[2] = word(v), Sp += 2, Ip++, Continue(); }

// --- accessors -------------------------------------------------------------
// rank / element-type code as fixnums; nil for a non-tuple. Both 0 for a scalar box.
op11(g_vm_arank, tupp(Sp[0]) ? putfix(tuple(Sp[0])->rank) : nil)
op11(g_vm_atype, tupp(Sp[0]) ? putfix(tuple(Sp[0])->type) : nil)

// total element count (1 for a scalar box), nil for a non-tuple.
g_vm(g_vm_alen) {
 word x = Sp[0];
 if (!tupp(x)) return Sp[0] = nil, Ip++, Continue();
 return Sp[0] = putfix(tuple_nelem(tuple(x))), Ip++, Continue(); }

// dimensions as a list (allocates rank cons cells), nil for a non-tuple.
g_vm(g_vm_ashape) {
 word x = Sp[0];
 if (!tupp(x)) return Sp[0] = nil, Ip++, Continue();
 uintptr_t r = tuple(x)->rank;
 Have(r * Width(struct g_pair));
 struct g_tuple *v = tuple(Sp[0]);                 // re-read post-Have
 struct g_pair *p = (struct g_pair*) Hp;
 Hp += r * Width(struct g_pair);
 word list = nil;
 for (uintptr_t i = r; i--; )
  ini_two(p, putfix(v->shape[i]), list), list = word(p), p++;
 return Sp[0] = list, Ip++, Continue(); }

// --- falsiness -------------------------------------------------------------
// Tuple falsiness, in lockstep with g_pin. A rank-0 boxed scalar (float/wide-int/complex)
// is FALSE iff it sorts <= 0 by the total order (complex: re first, then im) -- so a negative
// real box and a non-positive complex are false. A rank>=1 array is false iff its L2 norm is
// zero, i.e. every element has zero MAGNITUDE (sign squares away, so a negative element keeps
// the array truthy -- an array has no single sign). Drives g_nilp -> g_vm_cond and nilp/not.
bool g_all_zero(struct g_tuple *v) {
 uintptr_t n = tuple_nelem(v);
 if (!v->rank) {                                // rank-0 boxed scalar: false iff <= 0 (total order)
  word x = word(v);
  if (v->type == g_C) return cplx_nonpos(x);    // re < 0, or re == 0 && im <= 0
  if (v->type == g_R) return flo_get(x) <= 0;   // boxed float <= 0
  return box_get(x) < 0; }                        // g_Z wide-int box (never exactly 0)
 if (v->type == g_C) {                          // packed complex array: every (re,im) float 0
  g_flo_t *re = tuple_data(v);                    // 2n packed (re,im) floats
  for (uintptr_t i = 0; i < 2 * n; i++) if (re[i] != 0) return false;
  return true; }
 if (v->type == g_O) {                          // object array: false iff every element zero-magnitude
  for (uintptr_t i = 0; i < n; i++) if (g_mag(tuple_get_obj(v, i)) != 0) return false;
  return true; }
 bool fdom = v->type >= g_R;
 for (uintptr_t i = 0; i < n; i++)
  if (fdom ? tuple_get_flo(v, i) != 0 : tuple_get_int(v, i) != 0) return false;
 return true; }

// g_O reductions (sum/prod/max/min) fold through the promoting scalar op, so an
// object array reduces *exactly*. Defined after the object lane (below); the
// numeric reductions divert here when their operand is a g_O array.
static struct g *ored(struct g *g, int kind);   // kind: 0 sum, 1 prod, 2 max, 3 min

// --- reductions: rank>=1 array -> rank-0 scalar; identity on a scalar -------
// The identity-on-scalar property makes `(aall (< a b))` rank-agnostic: the
// same expression works whether a/b are scalars or arrays.
g_vm(g_vm_asum) {
 word x = Sp[0];
 if (!tupp(x)) return Ip++, Continue();        // scalar: (asum 5) = 5
 if (tuple(x)->type == g_O) {
  Pack(g); g = ored(g, 0);
  if (!g_ok(g)) return gtrap(g);
  return Unpack(g), Continue(); }
 if (tuple(x)->type == g_C) {                   // complex sum -> a complex box
  struct g_tuple *v = tuple(x); uintptr_t n = tuple_nelem(v);
  g_flo_t *fp = tuple_data(v), sr = 0, si = 0;  // read all parts before Have (no alloc here)
  for (uintptr_t i = 0; i < n; i++) sr += fp[2*i], si += fp[2*i+1];
  Have(CPLX_REQ);
  struct g_tuple *r = ini_scalar((struct g_tuple*) Hp, g_C); Hp += CPLX_REQ;
  cplx_put(r, sr, si);
  return Sp[0] = word(r), Ip++, Continue(); }
 struct g_tuple *v = tuple(x);
 uintptr_t n = tuple_nelem(v);
 bool fdom = v->type >= g_R; word _res;
 Have(BOX_REQ);
 v = tuple(Sp[0]);
 if (fdom) {
  g_flo_t a = 0;
  for (uintptr_t i = 0; i < n; i++) a += tuple_get_flo(v, i);
  EMIT_FLO(a); }
 else {
  intptr_t a = 0;
  for (uintptr_t i = 0; i < n; i++) a = (intptr_t) ((uintptr_t) a + (uintptr_t) tuple_get_int(v, i));
  EMIT_INT(a); }
 return Sp[0] = _res, Ip++, Continue(); }

g_vm(g_vm_aprod) {
 word x = Sp[0];
 if (!tupp(x)) return Ip++, Continue();
 if (tuple(x)->type == g_O) {
  Pack(g); g = ored(g, 1);
  if (!g_ok(g)) return gtrap(g);
  return Unpack(g), Continue(); }
 if (tuple(x)->type == g_C) {                   // complex product -> a complex box
  struct g_tuple *v = tuple(x); uintptr_t n = tuple_nelem(v);
  g_flo_t *fp = tuple_data(v), pr = 1, pi = 0;
  for (uintptr_t i = 0; i < n; i++) {
   g_flo_t ar = pr, ai = pi, br = fp[2*i], bi = fp[2*i+1];
   pr = ar*br - ai*bi; pi = ar*bi + ai*br; }
  Have(CPLX_REQ);
  struct g_tuple *r = ini_scalar((struct g_tuple*) Hp, g_C); Hp += CPLX_REQ;
  cplx_put(r, pr, pi);
  return Sp[0] = word(r), Ip++, Continue(); }
 struct g_tuple *v = tuple(x);
 uintptr_t n = tuple_nelem(v);
 bool fdom = v->type >= g_R; word _res;
 Have(BOX_REQ); v = tuple(Sp[0]);
 if (fdom) {
  g_flo_t a = 1;
  for (uintptr_t i = 0; i < n; i++) a *= tuple_get_flo(v, i);
  EMIT_FLO(a); }
 else { intptr_t a = 1;
  for (uintptr_t i = 0; i < n; i++) a = (intptr_t)((uintptr_t) a * (uintptr_t) tuple_get_int(v, i));
  EMIT_INT(a); }
 return Sp[0] = _res, Ip++, Continue(); }

// max / min over a non-empty array (kind 2 = max, 3 = min, matching ored);
// empty -> nil; scalar -> identity. The kind selects the comparison sense.
static g_vm(g_vm_aextreme, int kind) {
 word x = Sp[0];
 if (!tupp(x)) return Ip++, Continue();
 if (tuple(x)->type == g_O) {
  Pack(g); g = ored(g, kind);
  if (!g_ok(g)) return gtrap(g);
  return Unpack(g), Continue(); }
 if (tuple(x)->type == g_C) return Sp[0] = nil, Ip++, Continue();   // complex: unordered
 struct g_tuple *v = tuple(x);
 uintptr_t n = tuple_nelem(v);
 if (!n) return Sp[0] = nil, Ip++, Continue();
 bool fdom = v->type >= g_R, ismax = kind == 2; word _res;
 Have(BOX_REQ); v = tuple(Sp[0]);
 if (fdom) { g_flo_t m = tuple_get_flo(v, 0);
  for (uintptr_t i = 1; i < n; i++) { g_flo_t e = tuple_get_flo(v, i); if (ismax ? e > m : e < m) m = e; }
  EMIT_FLO(m); }
 else { intptr_t m = tuple_get_int(v, 0);
  for (uintptr_t i = 1; i < n; i++) { intptr_t e = tuple_get_int(v, i); if (ismax ? e > m : e < m) m = e; }
  EMIT_INT(m); }
 return Sp[0] = _res, Ip++, Continue(); }
g_vm(g_vm_amax) { return Ap(g_vm_aextreme, g, 2); }
g_vm(g_vm_amin) { return Ap(g_vm_aextreme, g, 3); }

// aall: the bool conjunction reduction. Scalar -> identity (so (aall 1) = 1, the
// linchpin of the rank-agnostic compare idiom). Over an array: "no zero element"
// (the falsy rule lifted to a conjunction); empty array -> true (vacuous). The
// DISJUNCTION (was `aany`) is just `len`: an array is truthy iff some element is
// nonzero, i.e. (nilp x) == (= 0 (len x)) -- so `(len x)` replaces `(aany x)`.
g_vm(g_vm_aall) {
 word x = Sp[0];
 if (!tupp(x)) return Ip++, Continue();
 struct g_tuple *v = tuple(x);
 uintptr_t n = tuple_nelem(v);
 if (v->type == g_O) {                         // object: a falsy element fails the conjunction
  for (uintptr_t i = 0; i < n; i++)
   if (g_nilp(tuple_get_obj(v, i))) return Sp[0] = nil, Ip++, Continue();
  return Sp[0] = putfix(1), Ip++, Continue(); }
 if (v->type == g_C) {                         // complex: a 0+0i element fails the conjunction
  g_flo_t *fp = tuple_data(v);
  for (uintptr_t i = 0; i < n; i++)
   if (fp[2*i] == 0 && fp[2*i+1] == 0) return Sp[0] = nil, Ip++, Continue();
  return Sp[0] = putfix(1), Ip++, Continue(); }
 bool fdom = v->type >= g_R;
 for (uintptr_t i = 0; i < n; i++)
  if (fdom ? tuple_get_flo(v, i) == 0 : tuple_get_int(v, i) == 0)
   return Sp[0] = nil, Ip++, Continue();
 return Sp[0] = putfix(1), Ip++, Continue(); }

// --- elementwise monadic math over an array (sin/cos/sqrt/... ) --------------
// Reached from g_vm_math1 when its operand arrp. Result is a float array
// (g_R) with the operand's shape. The fill loop takes no &local, so the
// g_vm wrapper keeps its trailing tail call.
static g_noinline void vmap1_fill(struct g_tuple *r, struct g_tuple *a, g_flo_t (*fn)(g_flo_t)) {
 uintptr_t n = tuple_nelem(r);
 for (uintptr_t i = 0; i < n; i++) tuple_put_flo(r, i, fn(tuple_get_flo(a, i))); }

g_vm(g_vm_vmap1, g_flo_t (*fn)(g_flo_t)) {
 struct g_tuple *a = tuple(Sp[0]);
 uintptr_t rank = a->rank, n = tuple_nelem(a);
 uintptr_t bytes = sizeof(struct g_tuple) + rank * sizeof(word) + n * g_T[g_R];
 Have(b2w(bytes));
 a = tuple(Sp[0]);                               // re-read post-Have
 struct g_tuple *r = (struct g_tuple*) Hp;
 Hp += b2w(bytes);
 ini_tuple(r, g_R, rank);
 for (uintptr_t i = 0; i < rank; i++) r->shape[i] = a->shape[i];
 vmap1_fill(r, a, fn);
 return Sp[0] = word(r), Ip++, Continue(); }

// --- elementwise dyadic engine (arith / compare / =) with broadcasting ------
// Per-element ops. Integer division guards /0 and INT_MIN/-1 -> 0 (the array
// convention; a scalar `/` promotes such cases to an IEEE inf/NaN instead, but
// one element can't change the whole result's domain).
static g_flo_t vop_flo(int op, g_flo_t a, g_flo_t b) {
 switch (op) {
  case VOP_SUB: return a - b; case VOP_MUL: return a * b;
  case VOP_QUOT: return a / b; case VOP_FQUOT: return g_trunc(a / b);
  case VOP_REM: return g_fmod(a, b);
  default: return a + b; } }                   // VOP_ADD
static intptr_t vop_int(int op, intptr_t a, intptr_t b) {
 switch (op) {
  case VOP_SUB: return (intptr_t)((uintptr_t) a - (uintptr_t) b);
  case VOP_MUL: return (intptr_t)((uintptr_t) a * (uintptr_t) b);
  case VOP_QUOT: case VOP_FQUOT: return (b == 0 || (a == INTPTR_MIN && b == -1)) ? 0 : a / b;
  case VOP_REM:  return (b == 0 || (a == INTPTR_MIN && b == -1)) ? 0 : a % b;
  default: return (intptr_t)((uintptr_t) a + (uintptr_t) b); } } // VOP_ADD
static intptr_t vcmp_flo(int op, g_flo_t a, g_flo_t b) {
 switch (op) {
  case VOP_LT: return a < b; case VOP_LE: return a <= b;
  case VOP_GT: return a > b; case VOP_GE: return a >= b;
  default: return a == b; } }                   // VOP_EQ
static intptr_t vcmp_int(int op, intptr_t a, intptr_t b) {
 switch (op) {
  case VOP_LT: return a < b; case VOP_LE: return a <= b;
  case VOP_GT: return a > b; case VOP_GE: return a >= b;
  default: return a == b; } }                   // VOP_EQ

// === ordered comparison: a total order over lisp values ======================
// `< <= > >=` extend across EVERY kind, not just numbers. The CROSS-kind order is
// the enum q type lattice (ll.h) -- fixnum/number LOW, lambda HIGH, the very
// order the generic-op matrix diagonals encode: number < string < symbol < pair <
// lambda. (Arrays are the exception: an array operand compares ELEMENTWISE -> a
// 0/1 mask via g_vm_vbin, never the scalar order.) WITHIN a kind:
//   numbers  by value across the tower; a real r is the complex (r, 0), so complex
//            sorts lexicographically by (re, im). IEEE-faithful: NaN is unordered,
//            so every ordering of it is false.
//   strings  lexicographic over bytes (a prefix sorts first)
//   symbols  lexicographic over the name (anonymous == the empty name)
//   pairs    lexicographic over (car, then cdr), recursively
//   lambdas  by representation hash (maps/ports/bufs too) -- a GC-stable order
// ANTISYMMETRY: only `<` and `<=` are implemented; `>` and `>=` REVERSE the
// operands and reuse them (a > b == b < a), which is also the right NaN behaviour
// (swap, never negate). A total PREORDER: agrees with `=` (eqv) except where eqv
// is finer -- distinct same-name uninterned symbols, or hash-colliding lambdas,
// compare EQUAL in the order but are not `=`.
// cross-kind rank = the enum q kind, every numeric kind folded to the arith lane
// (KFix) so fix/box/big/float/complex order by VALUE, not representation. Arrays
// divert to g_vm_vbin before this, so KArr* never appear. One source of truth:
// the enum q order itself.
static g_inline int cmp_rank(word x) { return (ISNUM(x) || Cp(x)) ? KFix : (int) g_kind(x); }
static g_inline intptr_t bytes_cmp(const char *pa, uintptr_t la, const char *pb, uintptr_t lb) {
 uintptr_t n = la < lb ? la : lb;
 int c = n ? memcmp(pa, pb, n) : 0;
 return c ? (c < 0 ? -1 : 1) : la < lb ? -1 : la > lb ? 1 : 0; }
static g_inline intptr_t sym_cmp(word a, word b) {          // by name (anon -> "")
 struct g_str *na = add_name(a), *nb = add_name(b);
 return bytes_cmp(na ? txt(na) : "", na ? na->len : 0, nb ? txt(nb) : "", nb ? nb->len : 0); }
// 3-way total-order comparator (-1/0/1); the recursive engine for the pair case.
// Floats collapse NaN to "equal" here (a structural total order can't carry IEEE
// unorderedness); the scalar lane below keeps NaN unordered at the top level. hash
// is alloc-free + GC-stable, so the lambda case is safe to call mid-comparison.
static intptr_t cmp3(struct g *g, word a, word b) {
 int ra = cmp_rank(a), rb = cmp_rank(b);
 if (ra != rb) return ra < rb ? -1 : 1;                    // cross-kind: type lattice
 switch (ra) {
  case KFix:                                               // number band, by value
   if (Cp(a) || Cp(b)) {                                   // complex: (re, im) lexicographic
    g_flo_t ar = Cp(a) ? cplx_re(a) : TOFLO(a), br = Cp(b) ? cplx_re(b) : TOFLO(b);
    if (ar != br) return ar < br ? -1 : 1;
    g_flo_t ai = Cp(a) ? cplx_im(a) : 0, bi = Cp(b) ? cplx_im(b) : 0;
    return ai < bi ? -1 : ai > bi ? 1 : 0; }
   if (flop(a) || flop(b)) { g_flo_t av = TOFLO(a), bv = TOFLO(b); return av < bv ? -1 : av > bv ? 1 : 0; }
   return g_big_cmp(a, b);                                 // exact fix/box/big tower
  case KString: return bytes_cmp(txt(a), len(a), txt(b), len(b));
  case KSym:    return sym_cmp(a, b);
  case KTwo: { intptr_t c = cmp3(g, A(a), A(b)); return c ? c : cmp3(g, B(a), B(b)); }  // car, then cdr
  default: { uintptr_t ha = hash(g, a), hb = hash(g, b);   // lambda/map/port/buf: by repr hash
             return ha < hb ? -1 : ha > hb ? 1 : 0; } } }
// the `<` / `<=` lane (op is VOP_LT or VOP_LE). An array operand -> elementwise
// mask (g_vm_vbin); a top-level float/complex pair is IEEE-faithful (NaN ->
// unordered -> false), so e.g. (<= nan nan) is nil.
static g_vm(g_vm_cmp_ord, int op) {
 word a = Sp[0], b = Sp[1]; intptr_t r;
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, g, op);      // array -> elementwise
 int ra = cmp_rank(a), rb = cmp_rank(b);
 if (ra != rb) r = vcmp_int(op, ra, rb);                   // cross-kind: type lattice
 else if (ra != KFix) r = vcmp_int(op, cmp3(g, a, b), 0);  // string / sym / pair / lambda
 else if (Cp(a) || Cp(b)) {                                // complex: lexicographic, per op
  g_flo_t ar = Cp(a) ? cplx_re(a) : TOFLO(a), br = Cp(b) ? cplx_re(b) : TOFLO(b);
  r = ar != br ? vcmp_flo(op, ar, br)
              : vcmp_flo(op, Cp(a) ? cplx_im(a) : 0, Cp(b) ? cplx_im(b) : 0); }
 else if (flop(a) || flop(b)) r = vcmp_flo(op, TOFLO(a), TOFLO(b));
 else if (bigp(a) || bigp(b)) r = vcmp_int(op, g_big_cmp(a, b), 0);
 else r = vcmp_int(op, TOINT(a), TOINT(b));
 return *++Sp = r ? putfix(1) : nil, Ip++, Continue(); }
// `<` `<=` -- the implemented side: both-fixnum fast path (tagged order is
// monotonic), else the lane. `>` `>=` are the other side: reverse the operands and
// reuse `<` `<=` (a > b == b < a; a >= b == b <= a).
#define CMP_LT(nom, vop) g_vm(nom) { \
 word a = Sp[0], b = Sp[1]; \
 if (__builtin_expect(fixp(a) && fixp(b), 1)) \
  return *++Sp = vcmp_int(vop, a, b) ? putfix(1) : nil, Ip++, Continue(); \
 return Ap(g_vm_cmp_ord, g, vop); }
CMP_LT(g_vm_lt, VOP_LT) CMP_LT(g_vm_le, VOP_LE)
#undef CMP_LT
g_vm(g_vm_gt) { word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t; return Ap(g_vm_lt, g); }  // a > b == b < a
g_vm(g_vm_ge) { word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t; return Ap(g_vm_le, g); }  // a >= b == b <= a

// Comparison from a 3-way sign of (lhs - rhs). Used when one operand is a bignum
// scalar: a bignum is always out of machine-int range (|bignum| > INTPTR_MAX, by
// canonical demotion), so it orders against any int element by its sign alone --
// exactly, where the low-bits truncation used for arithmetic would not.
static intptr_t vcmp_sign(int op, int s) {
 switch (op) {
  case VOP_LT: return s < 0; case VOP_LE: return s <= 0;
  case VOP_GT: return s > 0; case VOP_GE: return s >= 0;
  default: return s == 0; } }                   // VOP_EQ

// Fill the (already-shaped) result r with a `op` b, broadcasting. All the
// &-taking stack arrays (strides, odometer) live here so the g_vm wrapper stays
// TCO-clean. No allocation inside, so operand pointers can't move under us.
static g_noinline void vbin_fill(struct g_tuple *r, word a, word b, int op, bool fdom) {
 uintptr_t R = r->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= r->shape[i];
 bool aarr = arrp(a), barr = arrp(b);
 struct g_tuple *va = aarr ? tuple(a) : 0, *vb = barr ? tuple(b) : 0;
 // ca[j]/cb[j]: the operand flat-offset contribution of result axis j (0 when
 // that axis is absent in the operand or is a size-1 broadcast axis).
 intptr_t ca[G_VEC_MAXRANK], cb[G_VEC_MAXRANK], idx[G_VEC_MAXRANK];
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1;
  for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + R - va->rank;
   ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1;
  for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank;
   cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 bool cmp = op >= VOP_LT;
 // scalar values: the float domain widens a bignum full-magnitude (g_big_to_flo
 // via TOFLO); the int domain has no room for a bignum, so arithmetic demotes it
 // by low bits (modular). A *comparison* against a bignum, though, is decided
 // exactly by the bignum's sign below -- never by these low bits.
 g_flo_t sa = aarr ? 0 : TOFLO(a), sb = barr ? 0 : TOFLO(b);
 intptr_t ia = aarr ? 0 : fixp(a) ? getfix(a) : bigp(a) ? g_big_low(a) : box_get(a),
          ib = barr ? 0 : fixp(b) ? getfix(b) : bigp(b) ? g_big_low(b) : box_get(b);
 bool abig = !aarr && bigp(a), bbig = !barr && bigp(b);   // at most one (the other is an array)
 int asign = abig ? (((struct g_big*) a)->slen < 0 ? -1 : 1) : 0;
 int bsign = bbig ? (((struct g_big*) b)->slen < 0 ? -1 : 1) : 0;
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  if (fdom) {
   g_flo_t av = aarr ? tuple_get_flo(va, oa) : sa, bv = barr ? tuple_get_flo(vb, ob) : sb;
   if (cmp) tuple_put_int(r, p, vcmp_flo(op, av, bv) ? 1 : 0);
   else tuple_put_flo(r, p, vop_flo(op, av, bv)); }
  else {
   intptr_t av = aarr ? tuple_get_int(va, oa) : ia, bv = barr ? tuple_get_int(vb, ob) : ib;
   if (cmp) {                                    // bignum side (if any) sorts by sign: a-b ~ asign, or -bsign
    intptr_t t = (abig || bbig) ? vcmp_sign(op, abig ? asign : -bsign) : vcmp_int(op, av, bv);
    tuple_put_int(r, p, t ? 1 : 0); }
   else tuple_put_int(r, p, vop_int(op, av, bv)); }
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) {  // odometer
   if (++idx[j] < (intptr_t) r->shape[j]) break;
   idx[j] = 0; } } }

// For `/` (VOP_QUOT) over the integer domain: true if some broadcast element pair
// (av, bv) divides inexactly (bv == 0 or av % bv != 0), so the whole result must
// promote to f64. A bignum scalar forces the float lane (its low word can't decide
// divisibility). g_noinline: its &-taken stride/odometer arrays stay off g_vm_vbin's
// tail call. Called only after conformance is checked, so every offset is in range.
static g_noinline bool vquot_needs_float(word a, word b) {
 bool aarr = arrp(a), barr = arrp(b);
 if ((!aarr && bigp(a)) || (!barr && bigp(b))) return true;
 struct g_tuple *va = aarr ? tuple(a) : 0, *vb = barr ? tuple(b) : 0;
 uintptr_t ra = aarr ? va->rank : 0, rb = barr ? vb->rank : 0, R = ra > rb ? ra : rb, n = 1;
 intptr_t ca[G_VEC_MAXRANK], cb[G_VEC_MAXRANK], idx[G_VEC_MAXRANK], shp[G_VEC_MAXRANK];
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? va->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vb->shape[rb - 1 - k] : 1;
  shp[R - 1 - k] = (intptr_t) (da > db ? da : db); n *= da > db ? da : db; }
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1; for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + (intptr_t) R - (intptr_t) va->rank; ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1; for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank; cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 intptr_t ia = aarr ? 0 : TOINT(a), ib = barr ? 0 : TOINT(b);
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  intptr_t av = aarr ? tuple_get_int(va, oa) : ia, bv = barr ? tuple_get_int(vb, ob) : ib;
  if (bv == 0 || av % bv != 0) return true;
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) { if (++idx[j] < shp[j]) break; idx[j] = 0; } }
 return false; }

g_vm(g_vm_vbin, int op) {
 word a = Sp[0], b = Sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 // complex lane first: a packed g_C array, or a complex scalar paired with an
 // array (a complex scalar isn't ISNUM, so it must divert before the gate below).
 // Mixing g_C with a g_O object array is unsupported (neither reads the other's
 // element encoding) -- the g_O lane wins there.
 if (((aarr && tuple(a)->type == g_C) || (barr && tuple(b)->type == g_C) || Cp(a) || Cp(b))
     && !(aarr && tuple(a)->type == g_O) && !(barr && tuple(b)->type == g_O))
  return Ap(g_vm_cbin, g, op);
 if (!(aarr || ISNUM(a)) || !(barr || ISNUM(b)))   // each operand: array or scalar
  return *++Sp = nil, Ip++, Continue();
 if ((aarr && tuple(a)->type == g_O) || (barr && tuple(b)->type == g_O))
  return Ap(g_vm_obin, g, op);                     // object array -> promoting lane
 uintptr_t ra = aarr ? tuple(a)->rank : 0, rb = barr ? tuple(b)->rank : 0;
 uintptr_t R = ra > rb ? ra : rb;
 // compute-type = max element type; a scalar int contributes the lowest type
 // (i8) so it never widens an int array, a scalar float forces the float lane.
 int ta = aarr ? (int) tuple(a)->type : flop(a) ? (int) g_R : (int) g_Z;
 int tb = barr ? (int) tuple(b)->type : flop(b) ? (int) g_R : (int) g_Z;
 int ct = ta > tb ? ta : tb;
 bool fdom = ct >= g_R, cmp = op >= VOP_LT;
 // broadcast shape + conformance, right-aligned; scalar locals only (no array,
 // so the trailing tail call below survives).
 uintptr_t n = 1;
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? tuple(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? tuple(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) return *++Sp = nil, Ip++, Continue();
  n *= da > db ? da : db; }
 // `/` over an all-integer broadcast promotes the whole result to f64 the moment
 // any element divides inexactly (matching the scalar `/`); `//` (VOP_FQUOT) stays
 // integer. Scan only after conformance is known good (offsets are then in range).
 if (op == VOP_QUOT && !fdom && !cmp && vquot_needs_float(a, b)) fdom = true, ct = g_R;
 enum g_tuple_type rt = cmp ? g_Z : (enum g_tuple_type) ct;   // compare -> 0/1 Z mask
 uintptr_t bytes = sizeof(struct g_tuple) + R * sizeof(word) + n * g_T[rt];
 Have(b2w(bytes));
 a = Sp[0], b = Sp[1], aarr = arrp(a), barr = arrp(b);       // re-read post-Have
 struct g_tuple *r = (struct g_tuple*) Hp; Hp += b2w(bytes);
 ini_tuple(r, rt, R);
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? tuple(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? tuple(b)->shape[rb - 1 - k] : 1;
  r->shape[R - 1 - k] = da > db ? da : db; }
 vbin_fill(r, a, b, op, fdom);
 return *++Sp = word(r), Ip++, Continue(); }

// --- dyadic libm map with broadcasting (pow / atan2 over arrays) -------------
// The float-domain twin of g_vm_vbin: same numpy broadcast, but the result is
// always a float array and each element is fn(av, bv) for an arbitrary libm
// dyadic fn. A scalar operand broadcasts, widening through TOFLO -- so a bignum
// scalar feeds in at full magnitude (g_big_to_flo), same as the scalar `pow`.
// All the &-taking stack arrays live in this g_noinline fill so the wrapper's
// trailing tail call survives.
static g_noinline void vmap2_fill(struct g_tuple *r, word a, word b, g_flo_t (*fn)(g_flo_t, g_flo_t)) {
 uintptr_t R = r->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= r->shape[i];
 bool aarr = arrp(a), barr = arrp(b);
 struct g_tuple *va = aarr ? tuple(a) : 0, *vb = barr ? tuple(b) : 0;
 intptr_t ca[G_VEC_MAXRANK], cb[G_VEC_MAXRANK], idx[G_VEC_MAXRANK];
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1;
  for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + (intptr_t) R - (intptr_t) va->rank;
   ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1;
  for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank;
   cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 g_flo_t sa = aarr ? 0 : TOFLO(a), sb = barr ? 0 : TOFLO(b);
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  g_flo_t av = aarr ? tuple_get_flo(va, oa) : sa, bv = barr ? tuple_get_flo(vb, ob) : sb;
  tuple_put_flo(r, p, fn(av, bv));
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) {  // odometer
   if (++idx[j] < (intptr_t) r->shape[j]) break;
   idx[j] = 0; } } }

g_vm(g_vm_vmap2, g_flo_t (*fn)(g_flo_t, g_flo_t)) {
 word a = Sp[0], b = Sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 if (!(aarr || ISNUM(a)) || !(barr || ISNUM(b)))   // each operand: array or scalar
  return *++Sp = nil, Ip++, Continue();
 uintptr_t ra = aarr ? tuple(a)->rank : 0, rb = barr ? tuple(b)->rank : 0;
 uintptr_t R = ra > rb ? ra : rb, n = 1;
 for (uintptr_t k = 0; k < R; k++) {               // broadcast shape, right-aligned
  uintptr_t da = (aarr && k < ra) ? tuple(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? tuple(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) return *++Sp = nil, Ip++, Continue();
  n *= da > db ? da : db; }
 uintptr_t bytes = sizeof(struct g_tuple) + R * sizeof(word) + n * g_T[g_R];
 Have(b2w(bytes));
 a = Sp[0], b = Sp[1], aarr = arrp(a), barr = arrp(b);       // re-read post-Have
 struct g_tuple *r = (struct g_tuple*) Hp; Hp += b2w(bytes);
 ini_tuple(r, g_R, R);
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? tuple(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? tuple(b)->shape[rb - 1 - k] : 1;
  r->shape[R - 1 - k] = da > db ? da : db; }
 vmap2_fill(r, a, b, fn);
 return *++Sp = word(r), Ip++, Continue(); }

// ============================================================================
// obin -- object-array elementwise lane (g_O)
// ============================================================================
// The typed lanes (vbin/vmap) read raw C ints/floats and never allocate, so a
// fixed-width int array *wraps* on overflow. The object lane instead routes every
// element through the scalar dispatch (obin_elem), which promotes fixnum->box->
// bignum and boxes floats -- so a g_O array adds/multiplies *exactly*. Cost: the
// inner loop allocates, so it runs Pack'd (g_vm_obin -> obin_run) and re-fetches
// every live pointer (result, operands) after each element, exactly like the
// other allocate-in-a-loop paths (cf. host_run, g_big_binop).

// One element op: a (op) b for two scalar values, allocating via *fp (may GC --
// a/b are passed by value and rooted before the first allocation here). Returns
// the result value, or nil for a non-numeric / complex operand (deferred).
static word obin_elem(struct g **fp, int op, word a, word b) {
 if (op >= VOP_LT) {                            // comparison -> 1 / nil, no allocation
  if (!ISNUM(a) || !ISNUM(b)) return nil;       // Cp not in ISNUM -> unordered -> nil
  intptr_t t = (flop(a) || flop(b)) ? vcmp_flo(op, TOFLO(a), TOFLO(b))
             : (bigp(a) || bigp(b)) ? vcmp_int(op, g_big_cmp(a, b), 0)
                                    : vcmp_int(op, TOINT(a), TOINT(b));
  return t ? putfix(1) : nil; }
 if (!ISNUM(a) || !ISNUM(b)) return nil;
 struct g *g = *fp;
 if (flop(a) || flop(b)) {                      // float domain -> g_R box
  if (!g_ok(g = g_have(g, BOX_REQ))) return *fp = g, nil;
  *fp = g;
  struct g_tuple *v = ini_scalar((struct g_tuple*) g->hp, g_R);
  g->hp += BOX_REQ; flo_put(v->shape, vop_flo(op, TOFLO(a), TOFLO(b)));
  return word(v); }
 if (!bigp(a) && !bigp(b)) {                    // machine-int fast path, overflow-checked
  intptr_t av = TOINT(a), bv = TOINT(b), t; bool of;
  switch (op) {
   case VOP_QUOT: case VOP_FQUOT:                         // object (g_O) arrays truncate under both / and //
                  if (bv == 0) return putfix(0);          // array convention: int /0 -> 0
                  of = (av == INTPTR_MIN && bv == -1); t = of ? 0 : av / bv; break;
   case VOP_REM:  if (bv == 0) return putfix(0);
                  of = (av == INTPTR_MIN && bv == -1); t = of ? 0 : av % bv; break;
   case VOP_SUB:  of = __builtin_sub_overflow(av, bv, &t); break;
   case VOP_MUL:  of = __builtin_mul_overflow(av, bv, &t); break;
   default:       of = __builtin_add_overflow(av, bv, &t); break; }   // VOP_ADD
  if (!of) {                                    // demote-or-box the result
   if (t >= FIX_MIN && t <= FIX_MAX) return putfix(t);
   if (!g_ok(g = g_have(g, BOX_REQ))) return *fp = g, nil;
   *fp = g;
   struct g_tuple *v = ini_scalar((struct g_tuple*) g->hp, g_Z);
   g->hp += BOX_REQ; box_put(v->shape, t); return word(v); } }
 // bignum lane: g_big_binop computes sp[0] (op) sp[1], leaves it at sp[1],
 // pops one, and advances ip -- so save/restore ip and pop the net result.
 if (!g_ok(g = g_push(g, 2, a, b))) return *fp = g, nil;
 union u *ip0 = g->ip;
 g = g_big_binop(g, op);
 if (!g_ok(g)) return *fp = g, nil;
 g->ip = ip0;
 word r = g->sp[0]; g->sp++;
 return *fp = g, r; }

// Widen the numeric array at g->sp[slot] to a g_O copy in place (box each
// element), so the obin loop reads values uniformly. Allocates per element; the
// source (rooted at its slot) and the partially-built copy (parked on the stack)
// are re-fetched after every box.
static struct g *arr_to_obj(struct g *g, int slot) {
 struct g_tuple *src = tuple(g->sp[slot]);
 uintptr_t R = src->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= src->shape[i];
 uintptr_t bytes = sizeof(struct g_tuple) + R * sizeof(word) + n * g_T[g_O];
 if (!g_ok(g = g_have(g, b2w(bytes)))) return g;
 src = tuple(g->sp[slot]);
 struct g_tuple *dst = (struct g_tuple*) g->hp; g->hp += b2w(bytes);
 ini_tuple(dst, g_O, R);
 for (uintptr_t i = 0; i < R; i++) dst->shape[i] = src->shape[i];
 for (uintptr_t i = 0; i < n; i++) tuple_put_obj(dst, i, nil);   // safe pre-fill (GC may see it)
 if (!g_ok(g = g_push(g, 1, word(dst)))) return g;             // sp[0]=dst, src now at slot+1
 for (uintptr_t i = 0; i < n; i++) {
  struct g_tuple *s = tuple(g->sp[slot + 1]);
  word v;
  if (s->type >= g_R) {                                        // float -> g_R box
   g_flo_t e = tuple_get_flo(s, i);
   if (!g_ok(g = g_have(g, BOX_REQ))) return g;
   struct g_tuple *bx = ini_scalar((struct g_tuple*) g->hp, g_R); g->hp += BOX_REQ;
   flo_put(bx->shape, e); v = word(bx); }
  else {                                                       // int -> fixnum or g_Z box
   intptr_t e = tuple_get_int(s, i);
   if (e >= FIX_MIN && e <= FIX_MAX) v = putfix(e);
   else { if (!g_ok(g = g_have(g, BOX_REQ))) return g;
    struct g_tuple *bx = ini_scalar((struct g_tuple*) g->hp, g_Z); g->hp += BOX_REQ;
    box_put(bx->shape, e); v = word(bx); } }
  tuple_put_obj(tuple(g->sp[0]), i, v); }                          // re-fetch dst post-box
 word d = g->sp[0]; g->sp++; g->sp[slot] = d;                  // install copy, drop the parked root
 return g; }

// Pack'd body of g_vm_obin (operands at g->sp[0..1], >=1 is a g_O array).
static struct g *obin_run(struct g *g, int op) {
 word a = g->sp[0], b = g->sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 if (aarr && tuple(a)->type != g_O) { if (!g_ok(g = arr_to_obj(g, 0))) return g; }
 if (barr && tuple(b)->type != g_O) { if (!g_ok(g = arr_to_obj(g, 1))) return g; }
 a = g->sp[0], b = g->sp[1], aarr = arrp(a), barr = arrp(b);
 uintptr_t ra = aarr ? tuple(a)->rank : 0, rb = barr ? tuple(b)->rank : 0;
 uintptr_t R = ra > rb ? ra : rb, n = 1, shp[G_VEC_MAXRANK];
 for (uintptr_t k = 0; k < R; k++) {                           // broadcast shape, right-aligned
  uintptr_t da = (aarr && k < ra) ? tuple(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? tuple(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) {                        // non-conforming -> nil
   g->sp[1] = nil, g->sp++, g->ip = (union u*) g->ip + 1; return g; }
  shp[R - 1 - k] = da > db ? da : db; n *= da > db ? da : db; }
 uintptr_t bytes = sizeof(struct g_tuple) + R * sizeof(word) + n * g_T[g_O];
 if (!g_ok(g = g_have(g, b2w(bytes)))) return g;
 struct g_tuple *r = (struct g_tuple*) g->hp; g->hp += b2w(bytes);
 ini_tuple(r, g_O, R);
 for (uintptr_t k = 0; k < R; k++) r->shape[k] = shp[k];
 for (uintptr_t p = 0; p < n; p++) tuple_put_obj(r, p, nil);     // nil-fill before any GC
 if (!g_ok(g = g_push(g, 1, word(r)))) return g;               // sp: [0]=r [1]=a [2]=b
 intptr_t ca[G_VEC_MAXRANK], cb[G_VEC_MAXRANK], idx[G_VEC_MAXRANK];
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1; struct g_tuple *va = tuple(g->sp[1]);
  for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + (intptr_t) R - (intptr_t) va->rank;
   ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1; struct g_tuple *vb = tuple(g->sp[2]);
  for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank;
   cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  word ae = aarr ? tuple_get_obj(tuple(g->sp[1]), oa) : g->sp[1];  // scalar operand re-read each step
  word be = barr ? tuple_get_obj(tuple(g->sp[2]), ob) : g->sp[2];
  word res = obin_elem(&g, op, ae, be);
  if (!g_ok(g)) return g;
  tuple_put_obj(tuple(g->sp[0]), p, res);                          // re-fetch result post-alloc
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) {
   if (++idx[j] < (intptr_t) shp[j]) break;
   idx[j] = 0; } }
 word result = g->sp[0];                                       // collapse [r,a,b] -> r, advance ip
 g->sp += 2, g->sp[0] = result, g->ip = (union u*) g->ip + 1;
 return g; }

g_vm(g_vm_obin, int op) {
 Pack(g);
 g = obin_run(g, op);
 if (!g_ok(g)) return gtrap(g);
 return Unpack(g), Continue(); }

// g_O reduction body (kind: 0 sum, 1 prod, 2 max, 3 min). g->sp[0] is the array.
static struct g *ored(struct g *g, int kind) {
 struct g_tuple *v = tuple(g->sp[0]);
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 if (kind >= 2) {                                              // max/min: pick an element, no alloc
  if (!n) { g->sp[0] = nil, g->ip = (union u*) g->ip + 1; return g; }
  word acc = tuple_get_obj(tuple(g->sp[0]), 0);
  int cop = kind == 2 ? VOP_GT : VOP_LT;
  for (uintptr_t i = 1; i < n; i++) {
   word e = tuple_get_obj(tuple(g->sp[0]), i);
   if (obin_elem(&g, cop, e, acc) == putfix(1)) acc = e; }
  g->sp[0] = acc, g->ip = (union u*) g->ip + 1; return g; }
 word init = kind == 0 ? putfix(0) : putfix(1);               // sum/prod: fold with allocation
 int aop = kind == 0 ? VOP_ADD : VOP_MUL;
 if (!g_ok(g = g_push(g, 1, init))) return g;                 // sp[0]=acc, sp[1]=array
 for (uintptr_t i = 0; i < n; i++) {
  word e = tuple_get_obj(tuple(g->sp[1]), i);
  word acc = obin_elem(&g, aop, g->sp[0], e);
  if (!g_ok(g)) return g;
  g->sp[0] = acc; }
 word result = g->sp[0]; g->sp++, g->sp[0] = result;          // collapse acc into the array slot
 g->ip = (union u*) g->ip + 1;
 return g; }

// (re, im) of an operand for the complex lane / equality: a complex contributes
// its two parts; a real number contributes (value, 0). TOFLO widens a fixnum /
// float box / wide-int box / bignum -- a bignum narrows to double here, since
// complex is a floating domain (decision 5). Caller guarantees x is Cp or
// ISNUM. The &out params stay inside g_noinline callers, off the VM tail call.
static g_inline void cplx_parts(word x, g_flo_t *re, g_flo_t *im) {
 if (Cp(x)) *re = cplx_re(x), *im = cplx_im(x);
 else *re = TOFLO(x), *im = 0; }

// Fill the rank-0 complex box v with a `vop` b. All the &-taking lives in this
// g_noinline helper so the g_vm wrapper keeps its trailing tail call; no
// allocation inside, so the operand pointers can't move under us.
static g_noinline void cplx_fill(struct g_tuple *v, word a, word b, int vop) {
 g_flo_t ar, ai, br, bi, re, im;
 cplx_parts(a, &ar, &ai); cplx_parts(b, &br, &bi);
 switch (vop) {
  case VOP_SUB: re = ar - br; im = ai - bi; break;
  case VOP_MUL: re = ar * br - ai * bi; im = ar * bi + ai * br; break;
  case VOP_QUOT: { g_flo_t d = br * br + bi * bi;   // (ac+bd)/(c^2+d^2) + ...
   re = (ar * br + ai * bi) / d; im = (ai * br - ar * bi) / d; break; }
  default: re = ar + br; im = ai + bi; }            // VOP_ADD
 cplx_put(v, re, im); }

// The complex arithmetic lane. Reached from the arith slow paths when either
// operand is complex. A real operand promotes to (r, 0); a non-numeric operand,
// or VOP_REM (% is undefined on complex), yields nil. TCO-clean: the validation
// and box are in the body (no &local), the math is in cplx_fill.
g_vm(g_vm_cplx_bin, int vop) {
 word a = Sp[0], b = Sp[1];
 if (!(Cp(a) || ISNUM(a)) || !(Cp(b) || ISNUM(b)) || vop > VOP_QUOT)
  return *++Sp = nil, Ip++, Continue();
 Have(CPLX_REQ);
 a = Sp[0], b = Sp[1];                              // re-read post-Have
 struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_C);
 Hp += CPLX_REQ;
 cplx_fill(v, a, b, vop);
 return *++Sp = word(v), Ip++, Continue(); }

// --- complex-array elementwise lane (g_C) ----------------------------------
// The complex twin of g_vm_vbin: packed (re,im) numpy broadcast. An array operand
// is a g_C (packed) array or a real g_Z/g_R array (each element promotes to (v,0));
// a scalar operand is a complex box or any real number. + - * / use cplx_fill's
// formulas; `=` writes a g_Z 0/1 mask (componentwise equal); ordering and % are
// undefined on complex (handled in the wrapper -> nil). The &-taking odometer/
// stride arrays live in this g_noinline fill so the wrapper keeps its tail call.
static g_inline void cbin_part(bool isarr, struct g_tuple *v, g_flo_t sre, g_flo_t sim,
                               uintptr_t o, g_flo_t *re, g_flo_t *im) {
 if (!isarr) { *re = sre; *im = sim; return; }
 if (v->type == g_C) { g_flo_t *fp = tuple_data(v); *re = fp[2*o]; *im = fp[2*o+1]; }
 else { *re = tuple_get_flo(v, o); *im = 0; } }

static g_noinline void cbin_fill(struct g_tuple *r, word a, word b, int op, bool cmp) {
 uintptr_t R = r->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= r->shape[i];
 bool aarr = arrp(a), barr = arrp(b);
 struct g_tuple *va = aarr ? tuple(a) : 0, *vb = barr ? tuple(b) : 0;
 intptr_t ca[G_VEC_MAXRANK], cb[G_VEC_MAXRANK], idx[G_VEC_MAXRANK];
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1;
  for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + (intptr_t) R - (intptr_t) va->rank;
   ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1;
  for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank;
   cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 g_flo_t sar = 0, sai = 0, sbr = 0, sbi = 0;
 if (!aarr) { if (Cp(a)) sar = cplx_re(a), sai = cplx_im(a); else sar = TOFLO(a); }
 if (!barr) { if (Cp(b)) sbr = cplx_re(b), sbi = cplx_im(b); else sbr = TOFLO(b); }
 g_flo_t *rf = cmp ? 0 : tuple_data(r);
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  g_flo_t ar, ai, br, bi, re, im;
  cbin_part(aarr, va, sar, sai, oa, &ar, &ai);
  cbin_part(barr, vb, sbr, sbi, ob, &br, &bi);
  if (cmp) tuple_put_int(r, p, (ar == br && ai == bi) ? 1 : 0);
  else {
   switch (op) {
    case VOP_SUB: re = ar - br; im = ai - bi; break;
    case VOP_MUL: re = ar * br - ai * bi; im = ar * bi + ai * br; break;
    case VOP_QUOT: { g_flo_t d = br * br + bi * bi;
     re = (ar * br + ai * bi) / d; im = (ai * br - ar * bi) / d; break; }
    default: re = ar + br; im = ai + bi; }            // VOP_ADD
   rf[2*p] = re; rf[2*p+1] = im; }
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) {  // odometer
   if (++idx[j] < (intptr_t) r->shape[j]) break;
   idx[j] = 0; } } }

g_vm(g_vm_cbin, int op) {
 word a = Sp[0], b = Sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 // operand: array / complex scalar / real number. %, // and the orderings are
 // undefined on complex; only `=` survives among the comparisons (-> a mask).
 if (!(aarr || Cp(a) || ISNUM(a)) || !(barr || Cp(b) || ISNUM(b))
     || op == VOP_REM || op == VOP_FQUOT || (op >= VOP_LT && op != VOP_EQ))
  return *++Sp = nil, Ip++, Continue();
 bool cmp = op == VOP_EQ;
 uintptr_t ra = aarr ? tuple(a)->rank : 0, rb = barr ? tuple(b)->rank : 0;
 uintptr_t R = ra > rb ? ra : rb, n = 1;
 for (uintptr_t k = 0; k < R; k++) {                  // broadcast shape + conformance, right-aligned
  uintptr_t da = (aarr && k < ra) ? tuple(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? tuple(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) return *++Sp = nil, Ip++, Continue();
  n *= da > db ? da : db; }
 enum g_tuple_type rt = cmp ? g_Z : g_C;              // compare -> i64 mask, else packed complex
 uintptr_t bytes = sizeof(struct g_tuple) + R * sizeof(word) + n * g_T[rt];
 Have(b2w(bytes));
 a = Sp[0], b = Sp[1], aarr = arrp(a), barr = arrp(b);     // re-read post-Have
 struct g_tuple *r = (struct g_tuple*) Hp; Hp += b2w(bytes);
 ini_tuple(r, rt, R);
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? tuple(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? tuple(b)->shape[rb - 1 - k] : 1;
  r->shape[R - 1 - k] = da > db ? da : db; }
 cbin_fill(r, a, b, op, cmp);
 return *++Sp = word(r), Ip++, Continue(); }

// Fill complex box v with w ** z via the principal branch: w^z = exp(z * Log w),
// Log w = ln|w| + i*arg w. A real operand promotes to (r, 0) (cplx_parts). w == 0
// falls out as the IEEE limit (exp(-inf) -> 0 for Re z > 0), same domain stance as
// real pow. &-locals stay in this g_noinline helper, off g_vm_pow's tail call.
static g_noinline void cplx_pow_fill(struct g_tuple *v, word wbase, word zexp) {
 g_flo_t wr, wi, zr, zi;
 cplx_parts(wbase, &wr, &wi); cplx_parts(zexp, &zr, &zi);
 g_flo_t lr = (g_flo_t) 0.5 * g_log(wr * wr + wi * wi),    // ln|w|
         li = g_atan2(wi, wr);                             // arg w
 g_flo_t pr = zr * lr - zi * li, pi = zr * li + zi * lr,   // z * Log w
         e = g_exp(pr);
 cplx_put(v, e * g_cos(pi), e * g_sin(pi)); }

// (pow b e) = b ** e. Complex base or exponent -> the complex lane above; otherwise
// the real/array lanes (g_vm_math2 -> real pow, or vmap2 elementwise over arrays).
g_vm(g_vm_pow) {
 word a = Sp[0], b = Sp[1];
 if (Cp(a) || Cp(b)) {
  if (!(Cp(a) || ISNUM(a)) || !(Cp(b) || ISNUM(b)))
   return *++Sp = nil, Ip++, Continue();
  Have(CPLX_REQ);
  a = Sp[0], b = Sp[1];                              // re-read post-Have
  struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_C);
  Hp += CPLX_REQ;
  cplx_pow_fill(v, a, b);
  return *++Sp = word(v), Ip++, Continue(); }
 return Ap(g_vm_math2, g, g_pow); }

// (C re im): build a complex from two real numbers. Non-numeric arg -> nil.
// Fill packed g_C array r with (re = a-element, im = b-element) under numpy
// broadcast; a, b are real (g_Z/g_R) arrays or real scalars. &-taking stride/
// odometer arrays live in this g_noinline fill so g_vm_cplx keeps its tail call.
static g_noinline void cplx_build_fill(struct g_tuple *r, word a, word b) {
 uintptr_t R = r->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= r->shape[i];
 bool aarr = arrp(a), barr = arrp(b);
 struct g_tuple *va = aarr ? tuple(a) : 0, *vb = barr ? tuple(b) : 0;
 intptr_t ca[G_VEC_MAXRANK], cb[G_VEC_MAXRANK], idx[G_VEC_MAXRANK];
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1; for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + (intptr_t) R - (intptr_t) va->rank; ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1; for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank; cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 g_flo_t sa = aarr ? 0 : TOFLO(a), sb = barr ? 0 : TOFLO(b);
 g_flo_t *rf = tuple_data(r);
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  rf[2*p]   = aarr ? tuple_get_flo(va, oa) : sa;
  rf[2*p+1] = barr ? tuple_get_flo(vb, ob) : sb;
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) { if (++idx[j] < (intptr_t) r->shape[j]) break; idx[j] = 0; } } }

// (C re im): build a complex from two reals. Scalars -> a rank-0 complex box;
// a real array operand (with the other broadcasting) -> a packed g_C array, so
// (arg (C 1 x)) = atan and (arg (C x y)) = atan2 stay elementwise. A complex or
// object array operand, or a non-numeric scalar, -> nil.
g_vm(g_vm_cplx) {
 word a = Sp[0], b = Sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 if (aarr || barr) {
  if ((aarr && tuple(a)->type >= g_C) || (barr && tuple(b)->type >= g_C)
      || (!aarr && !ISNUM(a)) || (!barr && !ISNUM(b)))
   return *++Sp = nil, Ip++, Continue();
  uintptr_t ra = aarr ? tuple(a)->rank : 0, rb = barr ? tuple(b)->rank : 0;
  uintptr_t R = ra > rb ? ra : rb, n = 1;
  for (uintptr_t k = 0; k < R; k++) {
   uintptr_t da = (aarr && k < ra) ? tuple(a)->shape[ra - 1 - k] : 1;
   uintptr_t db = (barr && k < rb) ? tuple(b)->shape[rb - 1 - k] : 1;
   if (da != db && da != 1 && db != 1) return *++Sp = nil, Ip++, Continue();
   n *= da > db ? da : db; }
  uintptr_t bytes = sizeof(struct g_tuple) + R * sizeof(word) + n * g_T[g_C];
  Have(b2w(bytes));
  a = Sp[0], b = Sp[1], aarr = arrp(a), barr = arrp(b);     // re-read post-Have
  struct g_tuple *r = (struct g_tuple*) Hp; Hp += b2w(bytes);
  ini_tuple(r, g_C, R);
  for (uintptr_t k = 0; k < R; k++) {
   uintptr_t da = (aarr && k < ra) ? tuple(a)->shape[ra - 1 - k] : 1;
   uintptr_t db = (barr && k < rb) ? tuple(b)->shape[rb - 1 - k] : 1;
   r->shape[R - 1 - k] = da > db ? da : db; }
  cplx_build_fill(r, a, b);
  return *++Sp = word(r), Ip++, Continue(); }
 if (!ISNUM(a) || !ISNUM(b)) return *++Sp = nil, Ip++, Continue();
 g_flo_t re = TOFLO(a), im = TOFLO(b);             // values extracted before alloc
 Have(CPLX_REQ);
 struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_C);
 Hp += CPLX_REQ;
 cplx_put(v, re, im);
 return *++Sp = word(v), Ip++, Continue(); }

// (Cp x): is x a complex scalar?
op11(g_vm_Cp, Cp(Sp[0]) ? putfix(1) : nil)

// (re z) / (im z): real / imaginary part as a rank-0 float box. On a real
// number, re is the number itself and im is 0; on a non-number, nil.
g_vm(g_vm_re) {
 word a = Sp[0], _res;
 if (Cp(a)) { g_flo_t re = cplx_re(a); Have(BOX_REQ); EMIT_FLO(re);
  return Sp[0] = _res, Ip++, Continue(); }
 if (ISNUM(a)) return Ip++, Continue();            // re of a real is itself
 return Sp[0] = nil, Ip++, Continue(); }

g_vm(g_vm_im) {
 word a = Sp[0], _res;
 if (Cp(a)) { g_flo_t im = cplx_im(a); Have(BOX_REQ); EMIT_FLO(im);
  return Sp[0] = _res, Ip++, Continue(); }
 if (ISNUM(a)) return Sp[0] = putfix(0), Ip++, Continue();   // im of a real is 0
 return Sp[0] = nil, Ip++, Continue(); }

// (conj z): complex conjugate (re, -im). On a real number, the number itself.
g_vm(g_vm_conj) {
 word a = Sp[0];
 if (Cp(a)) { g_flo_t re = cplx_re(a), im = cplx_im(a);
  Have(CPLX_REQ);
  struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_C); Hp += CPLX_REQ;
  cplx_put(v, re, -im);
  return Sp[0] = word(v), Ip++, Continue(); }
 if (ISNUM(a)) return Ip++, Continue();
 return Sp[0] = nil, Ip++, Continue(); }

// (abs z): type-aware magnitude. Complex -> sqrt(re^2+im^2) (a float). Real ->
// |z| in its own tier: fixnum stays fixnum (or boxes if |FIX_MIN| overflows the
// tag), float stays float, bignum stays bignum (just flips its sign). The lone
// wart is a wide-int box holding INTPTR_MIN, whose magnitude needs a bignum --
// rare enough to leave (it re-boxes INTPTR_MIN unchanged), same flavor as the
// arith INT_MIN/-1 edge.
g_vm(g_vm_abs) {
 word a = Sp[0], _res;
 if (Cp(a)) { g_flo_t m = cplx_mod(a);
  Have(BOX_REQ); EMIT_FLO(m); return Sp[0] = _res, Ip++, Continue(); }
 if (fixp(a)) { intptr_t n = getfix(a);
  Have(BOX_REQ); EMIT_INT(n < 0 ? (intptr_t) (0 - (uintptr_t) n) : n);
  return Sp[0] = _res, Ip++, Continue(); }
 if (flop(a)) { g_flo_t v = flo_get(a); if (v < 0) v = -v;
  Have(BOX_REQ); EMIT_FLO(v); return Sp[0] = _res, Ip++, Continue(); }
 if (boxp(a)) { intptr_t n = box_get(a);
  Have(BOX_REQ); EMIT_INT(n < 0 ? (intptr_t) (0 - (uintptr_t) n) : n);
  return Sp[0] = _res, Ip++, Continue(); }
 if (bigp(a)) {
  struct g_big *x = (struct g_big*) a;
  if (x->slen > 0) return Ip++, Continue();         // already non-negative
  uintptr_t bytes = g_big_bytes(x); Have(b2w(bytes));
  x = (struct g_big*) Sp[0];                         // re-read post-Have
  struct g_big *y = (struct g_big*) Hp; Hp += b2w(bytes);
  memcpy(y, x, bytes); y->slen = -x->slen;           // flip the sign
  return Sp[0] = word(y), Ip++, Continue(); }
 if (arrp(a)) {                                       // vector -> scalar: the Euclidean (L2) norm
  struct g_tuple *v = tuple(a); uintptr_t i, n = tuple_nelem(v);   // sqrt(sum of squares); abs of a
  g_flo_t s = 0;                                      // complex elem is its 2-vector modulus; g_C sums 2n floats
  if (v->type == g_C) { g_flo_t *fp = tuple_data(v); for (i = 0; i < 2*n; i++) s += fp[i] * fp[i]; }
  else for (i = 0; i < n; i++) { g_flo_t e = tuple_get_flo(v, i); s += e * e; }
  Have(BOX_REQ); EMIT_FLO(g_sqrt(s)); return Sp[0] = _res, Ip++, Continue(); }
 if (mapp(a)) {                                       // table: its key count (so (int (abs t)) == (len t))
  Have(BOX_REQ); EMIT_INT((intptr_t) map_len(a)); return Sp[0] = _res, Ip++, Continue(); }
 return Sp[0] = nil, Ip++, Continue(); }

// fill f64 array r with arg of each element of v (a g_C packed or g_Z/g_R real
// array, same shape). &-free, but g_noinline to keep g_vm_carg's tail call clean.
static g_noinline void carg_fill(struct g_tuple *r, struct g_tuple *v) {
 uintptr_t n = tuple_nelem(v);
 g_flo_t *rf = tuple_data(r);
 if (v->type == g_C) { g_flo_t *fp = tuple_data(v);
  for (uintptr_t p = 0; p < n; p++) rf[p] = g_atan2(fp[2*p+1], fp[2*p]); }
 else for (uintptr_t p = 0; p < n; p++) rf[p] = g_atan2(0, tuple_get_flo(v, p)); }

// (arg z): phase angle atan2(im, re) as a float. On a real number this is 0 for
// non-negative and pi for negative; on a complex/real array, an f64 array of the
// per-element phase (so (arg (C 1 x)) = atan elementwise); on a non-number, nil.
g_vm(g_vm_carg) {
 word a = Sp[0], _res;
 if (Cp(a)) { g_flo_t r = g_atan2(cplx_im(a), cplx_re(a));
  Have(BOX_REQ); EMIT_FLO(r); return Sp[0] = _res, Ip++, Continue(); }
 if (arrp(a)) {
  struct g_tuple *v = tuple(a);
  if (v->type == g_O) return Sp[0] = nil, Ip++, Continue();   // object array -> nil
  uintptr_t R = v->rank, n = 1; for (uintptr_t i = 0; i < R; i++) n *= v->shape[i];
  uintptr_t bytes = sizeof(struct g_tuple) + R * sizeof(word) + n * g_T[g_R];
  Have(b2w(bytes));
  v = tuple(Sp[0]);                                           // re-read post-Have
  struct g_tuple *r = (struct g_tuple*) Hp; Hp += b2w(bytes);
  ini_tuple(r, g_R, R);
  for (uintptr_t i = 0; i < R; i++) r->shape[i] = v->shape[i];
  carg_fill(r, v);
  return Sp[0] = word(r), Ip++, Continue(); }
 if (ISNUM(a)) { g_flo_t r = g_atan2(0, TOFLO(a));
  Have(BOX_REQ); EMIT_FLO(r); return Sp[0] = _res, Ip++, Continue(); }
 return Sp[0] = nil, Ip++, Continue(); }
