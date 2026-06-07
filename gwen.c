#include "gwen.h"

// ============================================================================
// kernel-internal declarations (private; merged from former i.h)
// ============================================================================

#if UINTPTR_MAX == UINT64_MAX
#define Bits 64
typedef double g_flo_t;
#define g_sin   sin
#define g_cos   cos
#define g_tan   tan
#define g_atan  atan
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
#define g_tan   tanf
#define g_atan  atanf
#define g_atan2 atan2f
#define g_sqrt  sqrtf
#define g_exp   expf
#define g_log   logf
#define g_pow   powf
#endif

#if __STDC_HOSTED__
#include <math.h>
#else
g_flo_t g_sin(g_flo_t), g_cos(g_flo_t), g_tan(g_flo_t), g_atan(g_flo_t),
        g_atan2(g_flo_t, g_flo_t), g_sqrt(g_flo_t), g_exp(g_flo_t),
        g_log(g_flo_t), g_pow(g_flo_t, g_flo_t);
#endif

#define Bytes (Bits>>3)
_Static_assert(Bytes == sizeof(uintptr_t), "word size sanity check");

#include <stdarg.h>
_Static_assert(sizeof(union u) == sizeof(intptr_t), "cell size equals word size");
_Static_assert(-1 >> 1 == -1, "sign extended shift");
// nilp: structural test for the nil word (the only false scalar). Distinct from
// g_false below (the language falsy predicate, which also counts an all-zero tuple);
// the gwen `nilp` bif maps to g_false, not this macro.
#define nilp(_) (word(_)==nil)
#define AB(o) A(B(o))
#define AA(o) A(A(o))
#define BA(o) B(A(o))
#define BB(o) B(B(o))
#define nom(_) sym(_)
#define ptr(_) ((word*)(_))
#define datp(_) in_data(cell(_)->ap)
#define avec(f, y, ...) (MM(f,&(y)),(__VA_ARGS__),UM(f))
#define MM(f,r) ((g_core_of(f)->root=&((struct g_r){(word*)(r),g_core_of(f)->root})))
#define UM(f) (g_core_of(f)->root=g_core_of(f)->root->n)


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
#define getnum g_getnum
#define putnum g_putnum

// One word per element: every integer width folds to Z (intptr_t), every float
// width to R (g_flo_t), and C is the rank-0 complex scalar (two g_flo_t). Ordered
// Z < R < C so `>= g_R` is the float-domain test and C is the widest *numeric* tier.
// arr/arrl reject ty == C, so C never appears as a rank>=1 array element -- complex
// only ever shows up as a rank-0 scalar (cplxp), handled by explicit cplx branches.
// O (object) is the odd tier out: its slots hold live gwen words (any value --
// fixnum, bignum, box, complex, string, pair...), so it is the ONE tuple type the
// copying GC must trace element-by-element (evac_tuple). It sits outside the numeric
// order; the typed fast lanes gate on `type <= g_C`, the arith lane on `type == g_O`
// (g_vm_obin), so O elements always route through the promoting scalar dispatch --
// that is what makes a bignum array add/multiply exactly instead of wrapping.
enum g_tuple_type { g_Z, g_R, g_C, g_O, };
// Elementwise binary opcodes for g_vm_vbin (kernel/arr.c). The five arith codes
// match the arith slow handlers; the five compare codes (>= VOP_LT) produce a
// 0/1 bool array. VOP_EQ is `=` over arrays (whole-array eq is `(aall (= a b))`).
enum vop { VOP_ADD, VOP_SUB, VOP_MUL, VOP_QUOT, VOP_REM,
           VOP_LT, VOP_LE, VOP_GT, VOP_GE, VOP_EQ, };
struct g_atom *intern_checked(struct g*, struct g_str*);
g_vm_t g_vm_kcall,
 g_vm_two, g_vm_tuple, g_vm_sym, g_vm_str, g_vm_big, // data sentinels (enum q order); apply dispatches through g_apply_mx
 g_vm_putn, g_vm_info,    g_vm_clock,
 g_vm_nilp,  g_vm_putc, g_vm_gensym, g_vm_intern, g_vm_twop,
 g_vm_len, g_vm_get, g_vm_fputx, g_vm_buf, g_vm_bufnew, g_vm_bcopy,
 g_vm_nump,  g_vm_symp,   g_vm_strp,   g_vm_hashp, g_vm_band,   g_vm_bor,  g_vm_flo,  g_vm_flop,
 g_vm_sin, g_vm_cos, g_vm_tan, g_vm_atan, g_vm_atan2,
 g_vm_sqrt, g_vm_exp, g_vm_log, g_vm_pow,
 // Step 7 -- complex (kernel/cplx.c). g_vm_cplx_bin (declared apart, below) is
 // the arithmetic lane the scalar arith slow paths divert into.
 g_vm_cplx, g_vm_cplxp, g_vm_re, g_vm_im, g_vm_conj, g_vm_abs, g_vm_carg,
 g_vm_bxor,  g_vm_bsr,    g_vm_bsl,    g_vm_bnot, g_vm_ssub,
 g_vm_scat,   g_vm_cons,   g_vm_car,  g_vm_cdr,    g_vm_puts,
 g_vm_getc,  g_vm_string, g_vm_lt,     g_vm_le,   g_vm_eq,     g_vm_same, g_vm_gt,  g_vm_ge,
 g_vm_put, g_vm_hashd,   g_vm_hnew,   g_vm_hashk,  g_vm_hashof,
 g_vm_unc, g_vm_poke2, g_vm_peek2,
 g_vm_seek,  g_vm_trim,   g_vm_lam,   g_vm_add,
 g_vm_sub,   g_vm_mul,    g_vm_quot,   g_vm_rem,  g_vm_arg,
 g_vm_quote, g_vm_freev,  g_vm_eval,   g_vm_cond, g_vm_jump,   g_vm_defglob,
 g_vm_ap,    g_vm_tap,    g_vm_apn,    g_vm_tapn, g_vm_ret,
 g_vm_argap, g_vm_quoteap, g_vm_argtap,
 g_vm_arg0, g_vm_arg1, g_vm_arg2, g_vm_arg3,
 g_vm_quo0, g_vm_quo1, g_vm_quo2, g_vm_quo3, g_vm_quom1, g_vm_quom2,
 g_vm_callk, g_vm_yield_sw, g_vm_yield_bif, g_vm_task_exit, g_vm_spawn, g_vm_wait,
 g_vm_sleep, g_vm_donep, g_vm_kill, g_vm_key,
 g_vm_fgetc, g_vm_fungetc, g_vm_feof, g_vm_fputc, g_vm_fputs, g_vm_fflush,
 g_vm_fputn, g_vm_fread,
 // Step 5a -- typed multi-rank arrays (kernel/arr.c). g_vm_vbin is the shared
 // elementwise/broadcast engine the arith/compare slow lanes divert into.
 g_vm_arr, g_vm_arrl, g_vm_arank, g_vm_alen, g_vm_ashape, g_vm_atype,
 g_vm_asum, g_vm_aprod, g_vm_amax, g_vm_amin, g_vm_aall, g_vm_aany,
 g_vm_tuplep, g_vm_bigp, g_vm_boxp, g_vm_arrp, g_vm_intf;
// Carry extra operands, so (like g_vm_gc) they are declared apart from the
// plain g_vm_t list, which fixes the 4-argument handler signature. g_vm_vbin
// is the elementwise/broadcast binary engine (vop selects the op); g_vm_vmap1
// applies a unary math fn elementwise to an array (e.g. (sin arr)); g_vm_vmap2
// is the binary analogue with broadcasting (e.g. (pow arr arr), (atan2 ...)).
g_vm(g_vm_vbin, int);
g_vm(g_vm_vmap1, g_flo_t (*)(g_flo_t));
g_vm(g_vm_vmap2, g_flo_t (*)(g_flo_t, g_flo_t));
// Complex arithmetic lane (kernel/cplx.c): the scalar arith slow paths divert
// here when either operand is complex; vop selects add/sub/mul/quot (rem -> nil).
g_vm(g_vm_cplx_bin, int);
// Object-array elementwise lane (g_O): the broadcast engine g_vm_vbin diverts
// here when an operand is a g_O array, so each element op runs the promoting
// scalar dispatch (exact bignum results) instead of the typed raw-C lanes.
g_vm(g_vm_obin, int);
// data-kind recovery (datp/typ). Included here, after the self-quote sentinels
// above, because a frontend's override (e.g. wasm/inc/data.h) resolves kinds
// by comparing an ap against g_vm_two..g_vm_str directly.
#include <data.h>
char const *g_bif_name(intptr_t);
#define tuple(_) ((struct g_tuple*)(_))
#define nump oddp
#define sym(_) ((struct g_atom*)(_))
static g_inline bool symp(word _) { return lamp(_) && cell(_)->ap == g_vm_sym; }
static g_inline bool tuplep(word _) { return lamp(_) && cell(_)->ap == g_vm_tuple; }
static g_inline bool strp(word _) { return lamp(_) && cell(_)->ap == g_vm_str; }
// Mutable flat byte string. NOT a data kind: its head word is the
// behaves-as-0 g_vm_buf (like g_vm_port_io for ports), so the GC walks a buf
// as a plain length-2 thread -- [g_vm_buf, backing g_str, terminator] -- and
// the generic thread scan forwards the embedded string pointer for free; no
// bespoke evac/copy rule, and the data-sentinel mechanism stays reserved for
// kinds that need one. The bytes live in an ordinary g_str we mutate in place
// (cf. the `to` output port). Earned by tools/elf2efi.g, which back-patches a
// PE image. Recognized by ap, like iop() for ports.
struct g_buf { g_vm_t *ap; struct g_str *str; };
static g_inline bool bufp(word _) { return lamp(_) && cell(_)->ap == g_vm_buf; }
// A map is a lookup-lambda with stable identity across growth, like the hash it
// replaces (whose struct stayed put while its bucket array reallocated). Two
// threads: a fixed 2-word HEADER [g_vm_map_lookup, backing, <tag>] that callers
// hold, and a BACKING [g_vm_map_data, putnum(len), putnum(cap), k0,v0, … , <tag>]
// it points at -- open-addressed, linear-probed, cap a power of two. Growth
// allocates a new backing and swaps header[1]; the header never moves, so an
// aliased reference (ev's scopes) sees later inserts. Both are plain threads:
// len/cap are fixnums and keys/vals gwen words, so evac_thd traces them with no
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
static g_inline uintptr_t map_len(word m) { return getnum(cell(map_back(m))[1].x); }
static g_inline uintptr_t map_cap(word m) { return getnum(cell(map_back(m))[2].x); }
word g_mapget(struct g*, word, word, word);
static struct g *g_mapput(struct g*), *map_new(struct g*);
static g_inline struct g_str *buf_str(word x) { return ((struct g_buf*) x)->str; }
// the byte ops read from a string or a buf; both resolve to a g_str of bytes.
static g_inline struct g_str *bytes_of(word x) { return bufp(x) ? buf_str(x) : str(x); }
// Arbitrary-precision integer (Step 6). Own data-sentinel kind K_BIG: a flat,
// GC-trivial object (raw limbs, no embedded gwen pointers) the copying GC moves
// by memcpy. A generic thread scan can't hold inline limb words (a limb that's
// even-and-in-pool would be spuriously forwarded, one matching G_THD_TAG would
// truncate the object), so a flat bignum needs its own copy/evac rule -- like
// K_STRING strings -- which is exactly what the sentinel buys. slen = signed limb
// count (negative => negative value); |slen| 32-bit limbs little-endian
// (limb[0] least significant), top limb nonzero (normalized). Zero is never a
// bignum (it demotes to the fixnum nil), so slen is never 0 and the sign is
// unambiguous. Canonical demotion keeps the tiers disjoint: a value in fixnum
// range is a fixnum, one in intptr_t range a wide-int box, only wider values a
// bignum -- so nump/boxp/bigp are mutually exclusive and =/eqv stay well defined.
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
struct g *g_big_dec(struct g*);             // sp[0] bignum -> decimal string
struct g *g_big_read_dec(struct g*);        // sp[0] [+-]?digits token -> canonical value

static g_inline bool flop(word _) {
  return tuplep(_) && tuple(_)->rank == 0 && tuple(_)->type == g_R; }
// Wide-integer box: a rank-0 g_Z scalar tuple. Arises only from
// transparent fixnum overflow (kernel/math.c); never holds a value that
// fits the fixnum tag (canonical demotion keeps box and fixnum ranges
// disjoint), so boxp and nump never both hold for the same number.
static g_inline bool boxp(word _) {
  return tuplep(_) && tuple(_)->rank == 0 && tuple(_)->type == g_Z; }
// A complex scalar: a rank-0 g_C tuple (two g_flo_t, re then im). Deliberately
// NOT folded into ISNUM -- the real-tower macros (TOFLO/TOINT) would misread its
// two-word payload, so the arith/eq paths handle complex via explicit cplxp
// branches placed before the real lanes (decision: complex > float > int/bignum).
static g_inline bool cplxp(word _) {
  return tuplep(_) && tuple(_)->rank == 0 && tuple(_)->type == g_C; }
// A rank>=1 typed array (vs a rank-0 scalar box, which flop/boxp catch). The
// elementwise arith/compare lanes divert to g_vm_vbin when either operand arrp.
static g_inline bool arrp(word _) { return tuplep(_) && tuple(_)->rank >= 1; }

// Max array rank (bounds the stack index/stride arrays in the broadcast loop).
#define G_VEC_MAXRANK 8
extern size_t const g_vt_[];                 // element byte size by g_tuple_type
// Element payload: laid out row-major just past the shape words.
static g_inline void *tuple_data(struct g_tuple *v) { return (void*) (v->shape + v->rank); }
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
// Read/write element i of a g_O array as a raw tagged gwen word (the GC traces
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
// Truthiness: a value is false iff it is "zero or empty" -- exactly (= 0 (len x)).
// nil/0, an all-zero number/array/complex, and the empty string/buf/table. Every
// present value (non-empty container, symbol incl. anonymous, function, port,
// bignum) is truthy. Kept in sync with g_vm_len's zero case.
static g_inline bool g_false(word x) {
  return nilp(x) || (tuplep(x) && g_all_zero(tuple(x)))
      || (strp(x) && len(x) == 0)                       // empty string
      || (bufp(x) && len(buf_str(x)) == 0)              // empty buf
      || (mapp(x) && map_len(x) == 0); }                // empty table

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
#define ISNUM(x) (nump(x) || flop(x) || boxp(x) || bigp(x))
// Integer value of a fixnum-or-box operand (callers must exclude floats AND
// bignums -- a bignum doesn't fit an intptr_t; integer lanes guard on !bigp).
#define TOINT(x) (nump(x) ? (intptr_t) getnum(x) : box_get(x))
// Double value of any numeric operand (a bignum widens via g_big_to_flo).
#define TOFLO(x) (nump(x) ? (g_flo_t) getnum(x) : flop(x) ? flo_get(x) : boxp(x) ? (g_flo_t) box_get(x) : g_big_to_flo(x))
// Heap words for one scalar box. The float box (g_flo_t) and the wide-int box
// (intptr_t) are both one pointer-width word, so one reservation fits.
#define BOX_REQ (Width(struct g_tuple) + Width(intptr_t))
// Heap words for one complex box: the (re, im) payload is two g_flo_t words.
#define CPLX_REQ (Width(struct g_tuple) + 2 * Width(g_flo_t))
// The tagged fixnum range: putnum spends one bit, so |value| <= 2^(Bits-2).
#define FIX_MIN (INTPTR_MIN >> 1)
#define FIX_MAX (INTPTR_MAX >> 1)
// Emit an integer result R into `_res`: demote to a fixnum when it fits the
// tag, else box it as a rank-0 g_Z scalar (bumping Hp). The caller must
// already hold Have(BOX_REQ). Takes no &local, so a handler that uses it keeps
// its trailing tail call.
#define EMIT_INT(R) do { intptr_t _r = (R); \
 if (_r >= FIX_MIN && _r <= FIX_MAX) _res = putnum(_r); \
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
g_vm_t g_vm_set_numap,   // installs f->numap (the gwen fixnum-as-function handler), see vm.c
       g_vm_set_scomb, g_vm_set_bcomb;   // install the `+`/`*` thread combinators (S / compose)

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
// `call`+`ret` where there must be a `jmp`; see tools/vmret.g). GCC proves
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
static g_inline void cplx_put(struct g_tuple *v, g_flo_t re, g_flo_t im) {
 v->shape[0] = ((g_flo_pun){ .d = re }).u;
 v->shape[1] = ((g_flo_pun){ .d = im }).u; }

// Boxed wide-int access. The payload is one pointer-width signed integer
// in shape[0]; unlike the float box it needs no bit reinterpretation --
// it is already an integer, only its signedness differs from the
// uintptr_t slot. Neither helper takes the address of a stack local, so a
// VM handler that inlines them keeps its trailing tail call (see the
// flo_get/flo_put note above and tools/vmret.g).
static g_inline intptr_t box_get(word x) { return (intptr_t) tuple(x)->shape[0]; }
static g_inline void box_put(void *p, intptr_t v) { *(uintptr_t*) p = (uintptr_t) v; }

// equality comparisons inline the fast identity check
g_noinline bool eqv(struct g*, word, word); // this is for checking equality of non-identical values
static g_inline bool eql(struct g *f, word a, word b) { return a == b || eqv(f, a, b); }

// Threads -- and every other variable-length heap object the GC copies by
// scanning (continuations, task nodes, env scopes, ports) -- end with a single
// tag word: the object's own head pointer with bit 1 set (G_THD_TAG), saving a
// word over a separate NULL marker + head. Small ints are odd and gwen heap
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
#define topof(f) ((word*)f+f->len)
static g_inline struct g_tag { union u *head; union u end[]; } *ttag(struct g*f, union u *k) {
 word *lo = ptr(f), *hi = topof(f);
 while (!tagp(k->x, lo, hi)) k++;
 return (struct g_tag*) k; }
static g_inline union u *tag_head(struct g_tag *t) {
 return cell(word(t->head) & ~(word) 3); }

static g_inline union u *clip(struct g *f, union u *k) {
 return tagthd(k, cell(ttag(f, k)) - k); }



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
// External linkage (declared in gwen.h with the EMPTY_STR/EMPTY_SYM macros) so the
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
static g_inline void *off_pool(struct g *f) {
 return f == f->pool ? (word*) f->pool + f->len : (word*) f->pool; }
static g_inline struct g *pushq(struct g*f) { return intern(g_strof(f, "\\")); }
static g_inline struct g *push0(struct g*f) { return g_push(f, 1, nil); }
static g_inline size_t llen(word l) {
 size_t n = 0;
 while (twop(l)) n++, l = B(l);
 return n; }
static g_inline struct g*g_pop(struct g*f, uintptr_t n) {
 return g_core_of(f)->sp += n, f; }

// ============================================================================
// macros (hoisted from all merged units; see section banners below)
// ============================================================================






#define MIN(p,q) ((p)<(q)?(p):(q))
#define MAX(p,q) ((p)>(q)?(p):(q))




#define LIMB_BITS 32
#define LIMB_BASE ((uint64_t) 1 << LIMB_BITS)

#define RED_EXTREME(nom, c_op, kind) g_vm(nom) { \
 word x = Sp[0]; \
 if (!tuplep(x)) return Ip++, Continue(); \
 if (tuple(x)->type == g_O) { \
  Pack(f); f = ored(f, kind); \
  if (!g_ok(f)) return gtrap(f); \
  return Unpack(f), Continue(); } \
 struct g_tuple *v = tuple(x); \
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i]; \
 if (!n) return Sp[0] = nil, Ip++, Continue(); \
 bool fdom = v->type >= g_R; word _res; \
 Have(BOX_REQ); v = tuple(Sp[0]); \
 if (fdom) { g_flo_t m = tuple_get_flo(v, 0); \
  for (uintptr_t i = 1; i < n; i++) {\
   g_flo_t e = tuple_get_flo(v, i);\
   if (e c_op m) m = e; } \
  EMIT_FLO(m); } \
 else { intptr_t m = tuple_get_int(v, 0); \
  for (uintptr_t i = 1; i < n; i++) {\
   intptr_t e = tuple_get_int(v, i);\
   if (e c_op m) m = e; } \
  EMIT_INT(m); } \
 return Sp[0] = _res, Ip++, Continue(); }

#define YIELD_INTERVAL 64
#define YieldCheck() \
  if (f->tasks->m != f->tasks && ++f->yield_ctr >= YIELD_INTERVAL) \
    return Ap(g_vm_yield_sw, f)
#define ARGN(nom, i) g_vm(nom) { Have1(); Sp[-1] = Sp[i]; Sp -= 1; Ip += 1; return Continue(); }
#define QUON(nom, v) g_vm(nom) { Have1(); Sp -= 1; Sp[0] = putnum(v); Ip += 1; return Continue(); }

#define Ana(n, ...) struct g *n(struct g *f, struct env **c, intptr_t x, ##__VA_ARGS__)
#define Cata(n, ...) struct g *n(struct g *f, struct env **c, ##__VA_ARGS__)
#define incl(e, n) ((e)->len += ((n)<<1))
#define Kp (f->ip)
#define C1(n, ...) static Cata(n) { return __VA_ARGS__, pull(f, c); }
#define forget() (g_core_of(f)->root=(mm),f)

#define fs0(f) (g_core_of(f)->sp[0])
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
#define S2(i) {{g_vm_cur},{.x=putnum(2)},{i}, {g_vm_ret0}}
#define S3(i) {{g_vm_cur},{.x=putnum(3)},{i}, {g_vm_ret0}}
#define S5(i) {{g_vm_cur},{.x=putnum(5)},{i}, {g_vm_ret0}}
#define bifs(_) \
 _(bif_clock, "clock", S1(g_vm_clock)) _(bif_addr, "vminfo", S1(g_vm_info))\
 _(bif_add, "+", S2(g_vm_add)) _(bif_sub, "-", S2(g_vm_sub)) _(bif_mul, "*", S2(g_vm_mul))\
 _(bif_quot, "/", S2(g_vm_quot)) _(bif_rem, "mod", S2(g_vm_rem)) \
 _(bif_lt, "<", S2(g_vm_lt))  _(bif_le, "<=", S2(g_vm_le)) _(bif_eq, "=", S2(g_vm_eq))\
 _(bif_ge, ">=", S2(g_vm_ge))  _(bif_gt, ">", S2(g_vm_gt)) \
 _(bif_same, "same", S2(g_vm_same)) \
 _(bif_bnot, "~", S1(g_vm_bnot)) _(bif_bsl, "<<", S2(g_vm_bsl)) _(bif_bsr, ">>", S2(g_vm_bsr))\
 _(bif_band, "&", S2(g_vm_band)) _(bif_bor, "|", S2(g_vm_bor)) _(bif_bxor, "^", S2(g_vm_bxor))\
 _(bif_cons, "X", S2(g_vm_cons)) _(bif_car, "A", S1(g_vm_car)) _(bif_cdr, "B", S1(g_vm_cdr)) \
 _(bif_cons2, "cons", S2(g_vm_cons)) _(bif_car2, "car", S1(g_vm_car)) _(bif_cdr2, "cdr", S1(g_vm_cdr)) \
 _(bif_ssub, "ssub", S3(g_vm_ssub)) _(bif_scat, "scat", S2(g_vm_scat)) \
 _(bif_fread, "fread", S2(g_vm_fread))\
 _(bif_string, "string", S1(g_vm_string))\
 _(bif_intern, "intern", S1(g_vm_intern)) _(bif_gensym, "gensym", S1(g_vm_gensym))\
 _(bif_lam, "lam", S1(g_vm_lam))\
 _(bif_peek, "peek", S2(g_vm_peek2)) _(bif_poke, "poke", S3(g_vm_poke2)) _(bif_trim, "trim", S1(g_vm_trim))\
 _(bif_seek, "seek", S2(g_vm_seek)) _(bif_len, "len", S1(g_vm_len)) _(bif_get, "get", S3(g_vm_get))\
 _(bif_put, "put", S3(g_vm_put)) _(bif_hnew, "hashn", S1(g_vm_hnew)) _(bif_hashk, "hashk", S1(g_vm_hashk))\
 _(bif_hash, "hash", S1(g_vm_hashof))\
 _(bif_bufnew, "bufnew", S1(g_vm_bufnew)) _(bif_bcopy, "bcopy", S5(g_vm_bcopy))\
 _(bif_hashd, "hashd", S3(g_vm_hashd)) _(bif_twop, "twop", S1(g_vm_twop)) _(bif_strp, "strp", S1(g_vm_strp))\
 _(bif_flo, "flo", S1(g_vm_flo)) _(bif_flop, "flop", S1(g_vm_flop))\
 _(bif_sin, "sin", S1(g_vm_sin)) _(bif_cos, "cos", S1(g_vm_cos)) _(bif_tan, "tan", S1(g_vm_tan)) _(bif_atan, "atan", S1(g_vm_atan))\
 _(bif_sqrt, "sqrt", S1(g_vm_sqrt)) _(bif_exp, "exp", S1(g_vm_exp)) _(bif_log, "log", S1(g_vm_log))\
 _(bif_atan2, "atan2", S2(g_vm_atan2)) _(bif_pow, "pow", S2(g_vm_pow))\
 _(bif_cplx, "C", S2(g_vm_cplx)) _(bif_cplxp, "cplxp", S1(g_vm_cplxp))\
 _(bif_re, "re", S1(g_vm_re)) _(bif_im, "im", S1(g_vm_im)) _(bif_conj, "conj", S1(g_vm_conj))\
 _(bif_abs, "abs", S1(g_vm_abs)) _(bif_arg, "arg", S1(g_vm_carg))\
 _(bif_arr, "arr", S2(g_vm_arr)) _(bif_arrl, "arrl", S3(g_vm_arrl))\
 _(bif_arank, "arank", S1(g_vm_arank))\
 _(bif_alen, "alen", S1(g_vm_alen)) _(bif_ashape, "ashape", S1(g_vm_ashape))\
 _(bif_atype, "atype", S1(g_vm_atype))\
 _(bif_asum, "asum", S1(g_vm_asum)) _(bif_aprod, "aprod", S1(g_vm_aprod))\
 _(bif_amax, "amax", S1(g_vm_amax)) _(bif_amin, "amin", S1(g_vm_amin))\
 _(bif_aall, "aall", S1(g_vm_aall)) _(bif_aany, "aany", S1(g_vm_aany))\
 _(bif_tuplep, "tuplep", S1(g_vm_tuplep)) _(bif_bigp, "bigp", S1(g_vm_bigp)) _(bif_boxp, "boxp", S1(g_vm_boxp))\
 _(bif_arrp, "arrp", S1(g_vm_arrp)) _(bif_intf, "int", S1(g_vm_intf))\
 _(bif_symp, "symp", S1(g_vm_symp)) _(bif_hashp, "hashp", S1(g_vm_hashp)) _(bif_nump, "nump", S1(g_vm_nump))\
 _(bif_nilp, "nilp", S1(g_vm_nilp)) _(bif_ev, "ev", S1(g_vm_eval))\
 _(bif_callk, "call_cc", S1(g_vm_callk)) _(bif_yield, "yield", S1(g_vm_yield_bif)) \
 _(bif_spawn, "spawn", S2(g_vm_spawn)) _(bif_wait, "wait", S1(g_vm_wait)) \
 _(bif_sleep, "sleep", S1(g_vm_sleep)) _(bif_donep, "done?", S1(g_vm_donep)) \
 _(bif_kill, "kill", S1(g_vm_kill)) \
 _(bif_key, "key?", S1(g_vm_key)) \
 _(bif_fputn, "fputn", S3(g_vm_fputn))\
 _(bif_fputx, "fputx", S2(g_vm_fputx))\
 _(bif_fgetc, "fgetc", S1(g_vm_fgetc)) _(bif_fungetc, "fungetc", S2(g_vm_fungetc)) _(bif_feof, "feof", S1(g_vm_feof))\
 _(bif_fputc, "fputc", S2(g_vm_fputc)) _(bif_fputs, "fputs", S2(g_vm_fputs))  _(bif_fflush, "fflush", S1(g_vm_fflush))\
 _(bif_rng_seed, "rng-seed", S1(g_vm_rng_seed)) _(bif_rng_get, "rng-get", S1(g_vm_rng_get)) _(bif_rng_set, "rng-set", S1(g_vm_rng_set))\
 _(bif_rand, "rand", S1(g_vm_rand)) _(bif_randf, "randf", S1(g_vm_randf))\
 _(bif_rand_next, "rand-next", S1(g_vm_rand_next)) _(bif_randf_next, "randf-next", S1(g_vm_randf_next))\
 _(bif_set_numap, "set-numap", S1(g_vm_set_numap))\
 _(bif_set_scomb, "set-scomb", S1(g_vm_set_scomb)) _(bif_set_bcomb, "set-bcomb", S1(g_vm_set_bcomb))
#define built_in_function(n, _, d) static union u const n[] = d;
#define insts(_) _(g_vm_unc) _(g_vm_freev) _(g_vm_ret) _(g_vm_ap) _(g_vm_tap) _(g_vm_apn) _(g_vm_tapn)\
  _(g_vm_jump) _(g_vm_cond) _(g_vm_arg) _(g_vm_quote) _(g_vm_defglob)\
  _(g_vm_argap) _(g_vm_quoteap) _(g_vm_argtap)\
  _(g_vm_arg0) _(g_vm_arg1) _(g_vm_arg2) _(g_vm_arg3)\
  _(g_vm_quo0) _(g_vm_quo1) _(g_vm_quo2) _(g_vm_quo3) _(g_vm_quom1) _(g_vm_quom2)
#define biff(b, n, _) {n, (intptr_t) b},
#define i_entry(i) {#i, (intptr_t) i},

// ============================================================================
// g
// ============================================================================
enum g_status g_fin(struct g *f) {
 enum g_status s = g_code_of(f);
 if ((f = g_core_of(f))) {
   for (struct g_fz *fz = f->fz; fz; fz->fn(fz->p), fz = fz->next); // run finalizers
   f->free(f, f->pool); }
 return s; }

struct g *g_defn(struct g*f, struct g_def const*defs, uintptr_t n) {
 for (f = g_push(f, 1, g_core_of(f)->dict); n--;
  f = g_mapput(intern(g_strof(g_push(f, 1, defs[n].x), defs[n].n))));
 g_core_of(f)->sp++;
 return f; }

bifs(built_in_function);

static g_vm(_g_vm_yield_c) { return Pack(f), f; }
static union u yield_c[] = { {_g_vm_yield_c} };

// Default continuation installed at f->k. A throw enters it with the thrown
// status encoded into f (see gtrap2 in i.h); it re-encodes that status and
// yields to C -- the same escape the old trap did. Swap f->k for a gwen thread
// to land throws in gwen instead.
static g_vm(_g_vm_throw_c) {
 enum g_status s = g_code_of(f);
 f = g_core_of(f);
 return Pack(f), encode(f, s); }
static union u throw_c[] = { {_g_vm_throw_c} };

static struct g_def const def1[] = { bifs(biff) insts(i_entry)};

// reverse-lookup a function value against the builtin table -> its source name,
// or NULL. Used by the printer to render bifs (e.g. `+`) by name.
char const *g_bif_name(intptr_t x) {
 for (uintptr_t i = 0; i < LEN(def1); i++) if (def1[i].x == x) return def1[i].n;
 return 0; }

static struct g *g_ini_0(struct g*f, uintptr_t len0, void *(*ma)(struct g*, size_t), void (*fr)(struct g*, void*)) {
 memset(f, 0, sizeof(struct g));
 f->len = len0, f->pool = (void*) f, f->malloc = ma, f->free = fr;
 f->hp = f->end, f->sp = (word*) f + len0, f->ip = yield_c, f->t0 = g_clock();
 f->k = throw_c;
 // dict + macro maps (lookup-lambdas) then the main task thread.
 if (g_ok(f = map_new(f)) && g_ok(f = map_new(f)) && g_ok(f = g_have(f, 6))) {
  union u *M = bump(f, 6);            // sp[0]=macro, sp[1]=dict (no GC since g_have)
  M[0].m = M;
  M[1].x = nil;   // sentinel; replaced on first yield
  M[2].x = nil;   // main pid
  M[3].x = nil;   // wake_at: nil means "always runnable"
  M[4].x = putnum(-1);  // wait_fd: -1 = not waiting on I/O (slot value -1, non-zero)
  f->tasks = tagthd(M, 5);
  // dict[nil] = macro (the macro table -- no separate field). Both are on the
  // stack; push the nil key so (sp2,sp1,sp0)=(dict,macro,nil) for g_mapput.
  f = g_push(f, 1, nil);
  f = g_mapput(f);                     // -> sp[0] = dict
  f->dict = f->sp[0];                  // henceforth GC-forwarded via the v0..end loop
  f = g_pop(f, 1);
  struct g_def def0[] = {
   {"globals", f->dict},
   {"in", (word) &g_stdin},
   {"out", (word) &g_stdout},
   {"err", (word) &g_stderr}, };
  f = g_defn(f, def0, LEN(def0));
  f = g_defn(f, def1, LEN(def1));
  // Eager-seed the global RNG stream so f->rng is always a valid state tuple (gl0
  // bootstrap included). The seed mixes the clock with the rotated pool address.
  if (g_ok(f = g_have(f, RNG_VEC_REQ))) {
   struct g_tuple *v = bump(f, RNG_VEC_REQ);
   g_rng_seed(v, (uint64_t) (g_clock() ^ rot((uintptr_t) f)));
   f->rng = word(v); } }
 return f; }

struct g *g_ini_m(void *(*ma)(struct g*, size_t), void (*fr)(struct g*, void*)) {
 uintptr_t const len0 = 1 << 10;
 struct g *f = ma(NULL, 2 * len0 * sizeof(word));
 return f == NULL ? encode(f, g_status_oom) : g_ini_0(f, len0, ma, fr); }

static void *g_no_malloc(struct g*f, uintptr_t n) { return NULL; }
static void g_no_free(struct g*f, void *p) { }
struct g *g_ini_s(void *mem, uintptr_t nbytes) {
 uintptr_t len0 = nbytes / (2 * sizeof(word));
 return len0 <= Width(struct g) ? encode(mem, g_status_oom) :
   g_ini_0(mem, len0, g_no_malloc, g_no_free); }

static void *g_libc_malloc(struct g*f, size_t n) { return malloc(n); }
static void g_libc_free(struct g*f, void *x) { free(x); }
struct g *g_ini(void) { return g_ini_m(g_libc_malloc, g_libc_free); }

// ============================================================================
// stack
// ============================================================================
static struct g *g_pushr(struct g *f, uintptr_t m, uintptr_t n, va_list xs) {
 if (n == m) return g_please(f, m);
 word x = va_arg(xs, word);
 MM(f, &x);
 f = g_pushr(f, m, n + 1, xs);
 UM(f);
 if (g_ok(f)) *--f->sp = x;
 return f; }

struct g *g_push(struct g *f, uintptr_t m, ...) {
 if (!g_ok(f)) return f;
 va_list xs;
 va_start(xs, m);
 uintptr_t n = 0;
 if (avail(f) < m) f = g_pushr(f, m, n, xs);
 else for (f->sp -= m; n < m; f->sp[n++] = va_arg(xs, word));
 va_end(xs);
 return f; }

struct g *gxl(struct g *f) {
 if (g_ok(f = g_have(f, Width(struct g_pair)))) {
  struct g_pair *p = bump(f, Width(struct g_pair));
  ini_two(p, f->sp[0], f->sp[1]);
  *++f->sp = (word) p; }
 return f; }

struct g *gxr(struct g *f) {
 if (g_ok(f = g_have(f, Width(struct g_pair)))) {
  struct g_pair *p = bump(f, Width(struct g_pair));
  ini_two(p, f->sp[1], f->sp[0]);
  *++f->sp = (word) p; }
 return f; }

// ============================================================================
// gc
// ============================================================================
g_vm(g_vm_gc, uintptr_t n) {
 Pack(f);
 if (!g_ok(f = g_please(f, n))) return gtrap(f);
 return Unpack(f), Continue(); }

static word gcp(struct g*, word, word const *, word const *);

static g_inline void evac_two(struct g*f, word const*const p0, word const*const t0) {
 struct g_pair *w = (struct g_pair*) f->cp;
 f->cp += Width(struct g_pair);
 w->a = gcp(f, w->a, p0, t0);
 w->b = gcp(f, w->b, p0, t0); }

static g_inline void evac_tuple(struct g*f, word const*const p0, word const*const t0) {
 struct g_tuple *v = tuple(f->cp);
 f->cp += b2w(g_tuple_bytes(v));
 if (v->type != g_O) return;                 // numeric vecs are GC leaves (flat payload)
 word *e = (word*) tuple_data(v);              // object tuple: forward each live element word
 uintptr_t n = 1;
 for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 while (n--) e[n] = gcp(f, e[n], p0, t0); }

static g_inline void evac_str(struct g*f, word const*const p0, word const*const t0) {
 f->cp += b2w(sizeof(struct g_str) + str(f->cp)->len); }

static g_inline void evac_big(struct g*f, word const*const p0, word const*const t0) {
 f->cp += b2w(g_big_bytes((struct g_big*) f->cp)); }

static g_inline void evac_sym(struct g*f, word const*const p0, word const*const t0) {
 word nom = word(sym(f->cp)->nom);            // l/r subtree slots exist only for interned
 f->cp += Width(struct g_atom) - (nom && strp(nom) ? 0 : 2); }   // (string nom); anon/uninterned skip them

static g_inline void evac_thd(struct g *g, word const *const p0, word const*const t0) {
  // terminator payloads point into the new pool (the copied object's home);
  // a stray 2-byte-aligned external content word is rejected by the range
  word const *lo = ptr(g), *hi = ptr(g) + g->len;
  for (g->cp += 1; !tagp(g->cp[-1], lo, hi); g->cp[-1] = gcp(g, g->cp[-1], p0, t0), g->cp++); }

static g_inline void evac_data(struct g *g, word const *const p0, word const*const t0) {
  switch (typ(g->cp)) {
   default: __builtin_trap();
   case K_TUPLE: return evac_tuple(g, p0, t0);
   case K_SYM: return evac_sym(g, p0, t0);
   case K_TWO: return evac_two(g, p0, t0);
   case K_STRING: return evac_str(g, p0, t0);
   case K_BIG: return evac_big(g, p0, t0); } }

static g_inline void run_finalizers(struct g*g) {
 struct g_fz *new_fz = NULL;
 for (struct g_fz *fz = g->fz; fz; fz = fz->next) {
  word fwd = fz->p->x;
  if (lamp(fwd) && ptr(g) <= ptr(fwd) && ptr(fwd) < ptr(g) + g->len) {
   struct g_fz *nn = bump(g, Width(struct g_fz));
   nn->p = cell(fwd), nn->fn = fz->fn, nn->next = new_fz, new_fz = nn;
  } else fz->fn(fz->p); }
 g->fz = new_fz; }

static g_noinline struct g *gcg(struct g*g, struct g *p1, uintptr_t len1, struct g *f) {
 memcpy(g, f, sizeof(struct g));
 g->pool = (void*) p1;
 g->len = len1;
 uintptr_t const len0 = f->len;
 word const *p0 = ptr(f),
            *t0 = ptr(f) + len0, // source top
            *sp0 = f->sp;
 word h = t0 - sp0; // stack height
 g->sp = ptr(g) + len1 - h;
 g->hp = g->cp = g->end;
 g->ip = cell(gcp(g, word(g->ip), p0, t0));
 g->tasks = cell(gcp(g, word(g->tasks), p0, t0));
 g->symbols = 0;
 for (word i = 0; i < g->end - &g->v0; i++) (&g->v0)[i] = gcp(g, (&g->v0)[i], p0, t0);               // core live variables
 g_numap = gcp(g, g_numap, p0, t0);                                                  // singleton fixnum-apply handler (vm.c)
 g_scomb = gcp(g, g_scomb, p0, t0), g_bcomb = gcp(g, g_bcomb, p0, t0);               // `+`/`*` thread combinators
 for (word n = 0; n < h; n++) g->sp[n] = gcp(g, sp0[n], p0, t0);                     // stack
 for (struct g_r *s = g->root; s; s = s->n) *s->x = gcp(g, *s->x, p0, t0); // C live variables
 while (g->cp < g->hp) (datp(g->cp) ? evac_data : evac_thd)(g, p0, t0);              // cheney algorithm
 run_finalizers(g);
 if (g->len > g->max_len) g->max_len = g->len;                                       // instrumentation: peak pool len
 { uintptr_t heap = g->hp - g->end; if (heap > g->max_heap) g->max_heap = heap; }    // peak live (compacted) heap
 return g; }


g_noinline struct g *g_please(struct g *f, uintptr_t req0) {
 uintptr_t const
  t0 = f->t0, // end of last gc period
  t1 = g_clock(), // end of current non-gc period
  len0 = f->len;
 // find alternate pool
 struct g *g = off_pool(f);
 f = gcg(g, f->pool, f->len, f);
 f->n_gc += 1; // instrumentation: count one gc cycle per please
 uintptr_t const
  v_lo = 4,
  v_hi = v_lo * v_lo,
  req = req0 + len0 - avail(f),
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
 else return f->t0 = t2, f; // else right size -> all done
 return // allocate a new pool with target size
  !(g = f->malloc(f, len1 * 2 * sizeof(word))) ? // if malloc fails but pool is big enough
   encode(f, req <= len0 ? g_status_ok : g_status_oom) : // we can still report success
  (g = gcg(g, g, len1, f),
   f->free(f, f->pool),
   g->t0 = g_clock(),
   g); }

static g_inline word copy_two(struct g*f, struct g_pair *src, word const *const p0, word const *const t0) {
 struct g_pair *dst = bump(f, Width(struct g_pair));
 ini_two(dst, src->a, src->b);
 src->ap = (g_vm_t*) dst;
 return word(dst); }

static g_inline word copy_tuple(struct g*f, struct g_tuple *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = g_tuple_bytes(src);
 struct g_tuple *dst = bump(f, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

static g_inline word copy_str(struct g*f, struct g_str *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = sizeof(struct g_str) + src->len;
 struct g_str *dst = bump(f, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

// Bignums are flat (raw limbs, no embedded gwen pointers), so they copy by a
// single memcpy and evac by advancing past their bytes -- exactly like strings.
static g_inline word copy_big(struct g*f, struct g_big *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = g_big_bytes(src);
 struct g_big *dst = bump(f, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

static g_inline word copy_sym(struct g*f, struct g_atom *src, word const *const p0, word const*const t0) {
 struct g_atom *dst;
 if (!src->nom) dst = bump(f, Width(struct g_atom) - 2), ini_anon(dst, src->code);
 else {
  word nom = gcp(f, word(src->nom), p0, t0);   // relocate the nom (its sentinel now reads true)
  if (symp(nom))                               // named-uninterned: copy fresh, stay out of the tree
   dst = bump(f, Width(struct g_atom) - 2), ini_usym(dst, sym(nom), src->code);
  else                                         // interned (string nom): rebuild the tree by name
   dst = intern_checked(f, (struct g_str*) nom); }
 return word(src->ap = (g_vm_t*) dst); }

static g_inline word copy_data(struct g *f, union u *src, word const *const p0, word const *const t0) {
 switch (typ(src)) {
  default: __builtin_trap();
  case K_TWO: return copy_two(f, two(src), p0, t0);
  case K_TUPLE: return copy_tuple(f, tuple(src), p0, t0);
  case K_SYM: return copy_sym(f, sym(src), p0, t0);
  case K_STRING: return copy_str(f, str(src), p0, t0);
  case K_BIG: return copy_big(f, (struct g_big*) src, p0, t0); } }

static g_inline struct g_tag *ttag2(union u *k, word const *const lo, word const *const hi) {
 while (!tagp(k->x, lo, hi)) k++;
 return (struct g_tag*) k; }

static g_inline word copy_thread(struct g *f, union u *src, word const *const p0, word const *const t0) {
 // it's a thread, find the end to find the head
 struct g_tag *t = ttag2(src, p0, t0);
 union u *ini = tag_head(t), *d = bump(f, t->end - ini), *dst = d;
 // copy each content word to dest and leave a forwarding pointer behind,
 // stopping at the terminator; then rewrite it as the new tagged head
 for (union u *s = ini; !tagp(s->x, p0, t0); s->x = (word) d, d++, s++) d->x = s->x;
 return (word) (tagthd(dst, d - dst) + (src - ini)); }

static g_noinline intptr_t gcp(struct g *f, word x, word const *p0, word const *t0) {
 // if it's a number or it's outside managed memory then return it
 if (nump(x) || ptr(x) < p0 || ptr(x) >= t0) return x;
 union u *src = cell(x);
 x = src->x; // get its contents
 // if it contains a pointer to the new space then return the pointer
 return lamp(x) && ptr(f) <= ptr(x) && ptr(x) < ptr(f) + f->len ? x :
        in_data((void*) x) ? copy_data(f, src, p0, t0) :
                                copy_thread(f, src, p0, t0); }

// ============================================================================
// ev
// ============================================================================
static g_inline struct g *pushl(struct g*f) { return intern(g_strof(f, "\\")); }
static struct g *c0(struct g *f, g_vm_t *y);

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
static g_inline Cata(pull) { return g_ok(f) ? ((cata*) pop1(f))(f, c) : f; }

// generic instruction ana handlers
static g_inline struct g *c0_ix(struct g *f, struct env **c, g_vm_t *i, word x) {
 return incl(*c, 2), g_push(f, 3, c1_ix, i, x); }

static g_inline struct g *c0_i(struct g *f, struct env **c, g_vm_t *i) {
 return incl(*c, 1), g_push(f, 2, c1_i, i); }

static struct g *enscope(struct g *f, struct env *par, word args, word imps) {
 uintptr_t const n = Width(struct env) + Width(struct g_tag);
 f = g_push(f, 3, args, imps, par);
 if (g_ok(f = g_have(f, n))) {
  struct env *c = bump(f, n);
  c->stack = c->branches = c->exits = c->lams = c->len = c->sites = c->src = nil;
  c->args = f->sp[0], c->imps = f->sp[1], c->par = (struct env*) f->sp[2];
  *(f->sp += 2) = (word) tagthd((union u*)c, Width(struct env)); }
 return f; }

static word memq(struct g *f, word l, word k) {
 for (; twop(l); l = B(l)) if (eql(f, k, A(l))) return l;
 return 0; }

static word assq(struct g *f, word l, word k) {
 for (; twop(l); l = B(l)) if (eql(f, k, AA(l))) return A(l);
 return 0; }

static struct g *append(struct g *f) {
 uintptr_t i = 0;
 for (word l; g_ok(f) && twop(f->sp[0]); i++)
  l = B(f->sp[0]),
  f->sp[0] = A(f->sp[0]),
  f = g_push(f, 1, l);
 if (!g_ok(f)) return f;
 if (i == 0) return f->sp++, f;
 for (f->sp[0] = f->sp[i + 1]; i--; f = gxr(f));
 if (g_ok(f)) f->sp[1] = f->sp[0], f->sp++;
 return f; }

// don't inline this so callers can tail call optimize
static g_noinline struct g *c0(struct g *f, g_vm_t *y) {
 if (!g_ok(f = enscope(f, (struct env*) nil, nil, nil))) return f;
 struct env *c = (void*) ptr(pop1(f));
 word x = f->sp[0];
 f->sp[0] = (word) c1_yield;
 MM(f, &c); MM(f, &x);
 if (g_ok(f = analyze(f, &c, x)))
   f = c1(c0_ix(f, &c, y, word(f->ip)), &c);
 UM(f), UM(f);
 return f; }

static Cata(c1) {
 uintptr_t l = getnum((*c)->len);
 // a lambda carries its source \-expr: reserve one extra leading word for it so
 // it sits at value[-1] (the printer's discriminator) and rides inside the thread
 // span (head = src word) for free GC tracing. top-level/aux threads have no src.
 uintptr_t extra = nilp((*c)->src) ? 0 : 1;
 f = g_have(f, l + extra + Width(struct g_tag));
 if (g_ok(f)) {
  union u *k = bump(f, l + extra + Width(struct g_tag));
  memset(k, -1, (l + extra) * sizeof(word));
  Kp = tagthd(k, l + extra) + l + extra;
  if (g_ok(f = pull(f, c))) {           // pull emits l words (may GC); Kp now = entry
   // read src AFTER all allocation: g_have/pull can GC and relocate the env's src.
   if (extra) Kp[-1].x = (*c)->src,     // value[-1] = source \-expr
              clip(f, Kp - 1);          // tag head spans [src .. body]; value stays Kp
   else clip(f, Kp); } }
 return f; }

static Cata(c1_yield) { return f; }

static Cata(c1_cond_pop_exit) { return
 (*c)->exits = B((*c)->exits), // pops cond expression exit address off env stack exits
 pull(f, c); }

static Cata(c1_apn) {
 word arity = pop1(f);
 if (arity == putnum(1)) {
  if (Kp[0].ap == g_vm_ret) Kp[0].ap = g_vm_tap;
  else Kp -= 1, Kp[0].ap = g_vm_ap; }
 else {
  if (Kp[0].ap == g_vm_ret) Kp -= 1, Kp[0].ap = g_vm_tapn, Kp[1].x = arity;
  else Kp -= 2, Kp[0].ap = g_vm_apn, Kp[1].x = arity; }
 return pull(f, c); }


static Cata(c1_i) {
 g_vm_t *i = (void*) pop1(f);
 Kp -= 1;
 Kp[0].ap = i;
 return pull(f, c); }

static Cata(c1_ix) {
 g_vm_t *i = (void*) pop1(f);
 word x = pop1(f);
 Kp -= 2;
 Kp[0].ap = i;
 Kp[1].x = x;
 return pull(f, c); }

// Emit a recursive-function ref: bake `quote AB(y)` if the closure is final, else
// `quote nil` + stash the operand cell in the site for ana_d to backpatch.
static Cata(c1_recv) {
 word y = pop1(f), site = pop1(f);
 Kp -= 2;
 Kp[0].ap = g_vm_quote;
 if (nilp(site)) Kp[1].x = AB(y);
 else Kp[1].x = nil, B(site) = (word) &Kp[1];
 return pull(f, c); }

static Cata(c1_ar, g_vm_t *i, word ar) { return
 Kp -= 2,
 Kp[0].ap = i,
 Kp[1].x = putnum(ar),
 pull(f, c); }

static Cata(c1_cur) {
 struct env *e = (void*) pop1(f);
 uintptr_t ar = llen(e->args) + llen(e->imps);
 return ar == 1 ? pull(f, c) : c1_ar(f, c, g_vm_cur, ar); }

static Cata(c1_ret) {
 struct env *e = (struct env*) pop1(f);
 uintptr_t ar = llen(e->args) + llen(e->imps);
 return c1_ar(f, c, g_vm_ret, ar); }

C1(c1_cond_push_branch, f = gxl(g_push(f, 2, Kp, (*c)->branches)), (*c)->branches = g_ok(f) ? pop1(f) : nil)
C1(c1_cond_push_exit, f = gxl(g_push(f, 2, Kp, (*c)->exits)), (*c)->exits = g_ok(f) ? pop1(f) : nil)
C1(c1_cond_pop_branch, Kp -= 2, Kp[0].ap = g_vm_cond, Kp[1].x = A((*c)->branches), (*c)->branches = B((*c)->branches))

static Cata(c1_cond_exit) {
 union u *a = cell(A((*c)->exits));
 if (a->ap == g_vm_ret || a->ap == g_vm_tap)
  Kp = memcpy(Kp - 2, a, 2 * sizeof(*Kp));
 else if (a->ap == g_vm_tapn)
  Kp = memcpy(Kp - 3, a, 3 * sizeof(*Kp));
 else
  Kp -= 2, Kp[0].ap = g_vm_jump, Kp[1].x = (word) a;
 return pull(f, c); }

static g_vm(_g_vm_yieldk) { return
 Ip = Ip[1].m,
 Pack(f),
 encode(f, g_status_yield); }


static struct g *g_eval(struct g *f) {
 f = c0(f, _g_vm_yieldk);
#if g_tco
 if (g_ok(f)) f = f->ip->ap(f, f->ip, f->hp, f->sp);
#else
 while (g_ok(f)) f = f->ip->ap(f);
 if (g_code_of(f) == g_status_eof) f = g_core_of(f);
#endif
 return f; }

static word lidx(struct g*f, word x, word l) {
 word i = 0;
 for (; twop(l); i++, l = B(l)) if (eql(f, x, A(l))) return i;
 return -1; }

static Ana(ana_v) {
 word y;
 if (!g_ok(f)) return f;
 for (struct env *d = *c;; d = d->par) {
  if (nilp(d)) {
   if ((y = g_mapget(f, 0, x, f->dict))) return ana_q(f, c, y);
   // undefined global: resolved by g_vm_freev via the dict at run time.
   // Only record it as a captured free variable when this scope is nested
   // (cf. ev.g avb: `(? (get 0 'par c) (push 'imp x))`). At top level there
   // is no enclosing frame to capture from, so adding x to imps would make a
   // second reference resolve via memq(imps) to an uninitialized arg slot.
   // re-read x from the imps cons: the gxl/g_push above can GC and relocate
   // the symbol, leaving the local x dangling (cf. the same A((*c)->imps)
   // pattern in the capture path below). c0_ix then emits the live pointer.
   if (!nilp((*c)->par))
    f = gxl(g_push(f, 2, x, (*c)->imps)),
    x = g_ok(f) ? A((*c)->imps = pop1(f)) : nil;
   return c0_ix(f, c, g_vm_freev, x); }
  // lambda definition of local let form?
  if ((y = assq(f, d->lams, x))) {
   // recursive-fn ref: record a backpatch site on d (the lams-owning scope) when
   // the closure isn't built yet, then apply the captured imports.
   word site = nil;
   if (nilp(AB(y))) {
    MM(f, &d), MM(f, &y);
    f = gxl(g_push(f, 2, y, nil)); // site = (y . nil)
    if (g_ok(f)) {
     f = gxl(g_push(f, 2, f->sp[0], d->sites)); // (site . d->sites)
     if (g_ok(f)) d->sites = pop1(f), site = pop1(f); }
    UM(f), UM(f); }
   incl(*c, 2);
   if (g_ok(f = g_push(f, 3, c1_recv, y, site)))
    f = ana_ap(f, c, BB(f->sp[1]));
   return f; }
  // let binding in the *current* scope -> a direct stack slot.
  if (d == *c && memq(f, d->stack, x)) return
    c0_ix(f, c, g_vm_arg, putnum(lidx(f, x, d->stack)));
  // a let binding, closure var, or lambda arg -- possibly from an enclosing
  // scope. If enclosing, import it into this scope's free-variable (imps) list
  // so the offset c1_var emits is valid in *this* frame, not the defining one;
  // otherwise a captured let binding aliases whatever sits at the same offset
  // in the closure's frame (see the boot.g compiler's ava fix, commit 8e3acf0).
  if (memq(f, d->stack, x) || memq(f, d->imps, x) || memq(f, d->args, x)) {
   incl(*c, 2);
   if (d != *c) // found in an enclosing scope -> import (capture) it
    f = gxl(g_push(f, 2, x, (*c)->imps)),
    x = g_ok(f) ? A((*c)->imps = pop1(f)) : nil;
   return g_push(f, 3, c1_var, x, (*c)->stack); } } }


static Cata(c1_var) {
 word v = pop1(f), i = llen(pop1(f)); // stack inset
 for (word l = (*c)->imps; !nilp(l); l = B(l), i++)
  if (eql(f, v, A(l))) goto out;
 for (word l = (*c)->args; !nilp(l); l = B(l), i++)
  if (eql(f, v, A(l))) break;
out:
 return Kp -= 2,
        Kp[0].ap = g_vm_arg,
        Kp[1].x = putnum(i),
        pull(f, c); }

static g_noinline Ana(analyze) {
 if (symp(x)) return ana_v(f, c, x); // lookup symbol as variable
 if (!twop(x)) return ana_q(f, c, x); // non-pairs are self quoting
 word a = A(x), b = B(x);                        // it must be a pair
 if (!twop(b)) return analyze(f, c, a); // singleton list has value of element
 // if it is a special form then do that
 if (symp(a) && nom(a)->nom && len(nom(a)->nom) == 1)
  switch (*txt(nom(a)->nom)) {
   case '\\': return ana_l(f, c, b);
   case ':': return ana_d(f, c, b);
   case '?': return ana_c(f, c, b); }
 return ana_2(f, c, x, a, b); }


static struct g *c0_lambda(struct g *f, struct env **c, intptr_t imps, intptr_t exp) {
 union u *k, *ip;
 word ops = exp;             // the full operand list (params… body) for the stored src
 struct env *d = NULL;
 MM(f, &d); MM(f, &exp); MM(f, &ops);
 f = enscope(f, *c, exp, imps);

 if (g_ok(f)) {
  d = (struct env*) pop1(f);
  exp = d->args;
  int n = 0; // push exp args onto stack
  for (; twop(B(exp)); exp = B(exp), n++) f = g_push(f, 1, A(exp));
  for (f = push0(f); n--; f = gxr(f));
  exp = A(exp); }

 if (g_ok(f)) {
  d->args = f->sp[0];
  f->sp[0] = (word) c1_yield;
  incl(d, 4);
  f = g_push(f, 2, c1_cur, d);
  f = analyze(f, &d, exp);
  // stash the source \-expr for the printer (gzput_fn), built AFTER analyze so the
  // captured imports (d->imps) are known. ops is (params… body); prepend the
  // imports as leading params (the frame layout is [imps, args]) so a closure
  // prints as `(\ imps… params… body)` applied to its captures and round-trips.
  if (g_ok(f)) {
   word l = d->imps; int ni = 0;
   MM(f, &l);
   for (; twop(l); l = B(l), ni++) f = g_push(f, 1, A(l));  // push imp1..impN
   UM(f);
   f = g_push(f, 1, ops);                                   // tail = (params… body)
   while (ni-- > 0) f = gxr(f);                             // fold: imps ++ ops
   f = gxl(pushl(f));                                       // cons '\ onto the front
   if (g_ok(f)) d->src = pop1(f); }
  if (g_ok(f = g_push(f, 2, c1_ret, d)))
    ip = f->ip,
    avec(f, ip, f = c1(f, &d)); }

 if (g_ok(f)) k = f->ip, f->ip = ip, f = gxl(g_push(f, 2, k, d->imps));

 return UM(f), UM(f), UM(f), f; }

static Ana(c0_cond_exit) { return
 incl(*c, 3),
 g_push(analyze(f, c, x), 1, c1_cond_exit); }

static Ana(c0_cond_r) { return
 !twop(x) ? c0_cond_exit(f, c, nil) :
 !twop(B(x)) ? c0_cond_exit(f, c, A(x)) :
 (avec(f, x,
  incl(*c, 2),
  f = analyze(f, c, A(x)),
  f = g_push(f, 1, c1_cond_pop_branch),
  f = c0_cond_exit(f, c, AB(x)),
  f = g_push(f, 1, c1_cond_push_branch),
  f = c0_cond_r(f, c, BB(x))), f); }


static struct g *ana_ap_r2l(struct g *f, struct env **c, word x);
static struct g *ana_ap(struct g *f, struct env **c, intptr_t x) {
 if (!g_ok(f)) return f;
 bool imfp =
  f->sp[0] == (word) c1_ix &&
  f->sp[1] == (word) g_vm_quote &&
  lamp(f->sp[2]);
 intptr_t
  ca = llen(x),
  va =
   imfp && cell(f->sp[2])->ap == g_vm_cur ?
    getnum(cell(f->sp[2])[1].x) :
    1;
 bool b1p = ca == 1 && imfp && cell(f->sp[2])[1].ap == g_vm_ret0,
      anp = va == ca && ca > 1,
      bnp = anp && cell(f->sp[2])[3].ap == g_vm_ret0;

 if (b1p) { // inline an instruction
  g_vm_t *i = cell(f->sp[2])->ap;
  f->sp += 3;
  f = c0_i(analyze(f, c, A(x)), c, i);
  return f; }

 if (bnp) { // inline a curried instruction
  g_vm_t *i = cell(f->sp[2])[2].ap;
  f->sp += 3;
  f = c0_i(ana_ap_r2l(f, c, x), c, i); // r2l arg eval
  if (g_ok(f)) while (ca--) (*c)->stack = B((*c)->stack);
  return f; }

 if (g_ok(f = gxl(g_push(f, 3, nil, (*c)->stack, x)))) {
  (*c)->stack = pop1(f), x = pop1(f), MM(f, &x);
  if (anp) { // r2l 1 n-ary ap
   f = ana_ap_r2l(f, c, x),
   incl(*c, 2),
   f = g_push(f, 2, c1_apn, putnum(ca));
   if (g_ok(f)) while (ca--) (*c)->stack = B((*c)->stack); }
  else while (twop(x)) // l2r n 1-ary ap
   f = analyze(f, c, A(x)),
   incl(*c, 2),
   f = g_push(f, 2, c1_apn, putnum(1)),
   x = B(x);
  UM(f), (*c)->stack = B((*c)->stack); }

 return f; }


static struct g *ana_ap_r2l(struct g *f, struct env **c, word x) {
 if (twop(x)) {
  word y = A(x);
  avec(f, y, f = ana_ap_r2l(f, c, B(x)));
  f = analyze(f, c, y);
  f = gxl(g_push(f, 2, nil, (*c)->stack));
  if (g_ok(f)) (*c)->stack = pop1(f); }
 return f; }

static g_inline bool lambp(struct g *f, word x) {
 struct g_str *n;
 return twop(x) && symp(A(x)) && twop(B(x)) && twop(B(B(x))) &&
  (n = sym(A(x))->nom) && len(n) == 1 && txt(n)[0] == '\\'; }

static g_inline word rev(word l) {
 word m, n = nil;
 while (twop(l)) m = l, l = B(l), B(m) = n, n = m;
 return n; }

static word ldels(struct g *f, word lam, word l);

static g_inline Ana(ana_2, word a, word b) {
 if ((x = g_mapget(f, 0, a, g_mapget(f, nil, nil, g_core_of(f)->dict))))   // macro table = dict[nil]
  return f = g_eval(gxr(gxl(gxl(pushq(gxl(g_push(f, 4, b, nil, nil, x))))))),
         analyze(f, c, g_ok(f) ? pop1(f) : 0);
 return avec(f, b, f = analyze(f, c, a)),
        ana_ap(f, c, b); }

static g_inline Ana(ana_q) { return c0_ix(f, c, g_vm_quote, x); }
static g_inline Ana(ana_l) {
  if (!twop(B(x))) return ana_q(f, c, A(x)); // one operand, no params: quote
  return f = c0_lambda(f, c, nil, x),
         analyze(f, c, g_ok(f) ? pop1(f) : 0); }
static Ana(c0_cond_r);
static g_inline Ana(ana_c) {
 return !twop(B(x)) ? analyze(f, c, A(x)) :
    (f = g_push(f, 2, x, c1_cond_pop_exit),
     f = c0_cond_r(f, c, g_ok(f) ? pop1(f) : nil),
     g_push(f, 1, c1_cond_push_exit)); }
// this is the longest C function :(
// it handles the let special form in a way to support sequential and recursive binding.
static g_inline struct g *ana_d(struct g *f, struct env **b, word exp) {
 if (!twop(B(exp))) return analyze(f, b, A(exp));
 struct g_r *mm = g_core_of(f)->root;
 MM(f, &exp);
 // recursive-value boxing: c0 is the bootstrap compiler, so it delegates the
 // letrec*-value rewrite to the gwen `boxfix` prepass (prelude.g) -- evaluated
 // like a macro -- once that global exists (i.e. for everything after its own
 // definition partway through the prelude). It boxes a value binding whose init
 // closes over the name being defined into a heap cell. The runtime compiler
 // (ev.g) does the same natively in `l2x`. exp is rooted across the alloc.
 if (g_ok(f = intern(g_strof(f, "boxfix")))) {
  word bf = g_mapget(f, 0, pop1(f), f->dict);
  if (bf && lamp(bf)) {
   f = g_eval(gxr(gxl(gxl(pushq(gxl(g_push(f, 4, exp, nil, nil, bf)))))));
   if (g_ok(f)) exp = pop1(f); } }
 f = enscope(f, *b, (*b)->args, (*b)->imps);
 if (!g_ok(f)) return forget();
 struct env *q = (struct env*) pop1(f), **c = &q;
 // lots of variables :(
 word nom = nil, def = nil, lam = nil,
      v = nil, d = nil, e = nil, os = nil;
 MM(f, &nom), MM(f, &def), MM(f, &lam);
 MM(f, &d); MM(f, &e); MM(f, &v); MM(f, &q); MM(f, &os);

 // collect vars and defs into two lists.
 // While finding each bound lambda's closure (the c0_lambda below) we expose
 // the preceding bindings on the enclosing scope's stack, so a let-bound
 // lambda that refers to a sibling binding captures it as a free variable
 // instead of falling through to a same-named global (cf. ev.g l2/jj's
 // `_ (push 'stk (car n))`). The original stack is restored after the loop,
 // before any code is emitted, so the run-time frame layout is unchanged.
 os = (*b)->stack;
 while (twop(exp) && twop(B(exp))) {
  for (d = A(exp), e = AB(exp); twop(d); e = pop1(f), d = A(d)) {
   f = gxl(g_push(f, 2, e, nil));
   f = append(gxl(pushl(g_push(f, 1, B(d)))));
   if (!g_ok(f)) return forget(); }
  f = gxl(g_push(f, 2, d, nom));
  f = gxl(g_push(f, 2, e, def));
  if (!g_ok(f)) return forget();
  def = pop1(f), nom = pop1(f);
  // if it's a lambda compile it and record in lam list
  if (lambp(f, e)) {
   f = g_push(f, 2, d, lam);
   f = gxl(gxr(c0_lambda(f, c, nil, B(e))));
   if (!g_ok(f)) return forget();
   lam = pop1(f); }
  f = gxl(g_push(f, 2, d, (*b)->stack)); // expose this binding to later siblings
  (*b)->stack = g_ok(f) ? pop1(f) : nil;
  exp = BB(exp); }
 (*b)->stack = os; // restore: emission below rebuilds the real frame

 intptr_t ll = llen(nom);
 bool oddp = twop(exp),
      globp = !oddp && nilp((*b)->args); // we check this again later to make global bindings at top level
 if (!oddp) { // if there's no body then evaluate the name of the last definition
  f = gxl(g_push(f, 2, A(nom), nil));
  if (!g_ok(f)) return forget();
  exp = pop1(f); }

 // find closures
 // for each function f with closure C(f)
 // for each function g with closure C(g)
 // if f in C(g) then C(g) include C(f)
 word j, vars, var;
 do for (j = 0, d = lam; twop(d); d = B(d)) // for each bound function variable
  for (e = lam; twop(e); e = B(e)) if (d != e) // for each other bound function variable
   if (memq(f, BB(A(e)), AA(d))) // if you need this function
    for (v = BB(A(d)); twop(v); v = B(v)) // then you need its variables
     if (!memq(f, vars = BB(A(e)), var = A(v))) // only add if it's not already there
      j++,
      f = gxl(g_push(f, 2, var, vars)),
      BB(A(e)) = g_ok(f) ? pop1(f) : nil;
 while (j);

 // now delete defined functions from the closure variable lists
 // they will be bound lazily when the function runs
 for (e = lam; twop(e); BB(A(e)) = ldels(f, lam, BB(A(e))), e = B(e));

 (*c)->lams = lam;
 f = append(gxl(pushl(g_push(f, 2, nom, exp))));

 if (!g_ok(f)) return forget();
 exp = pop1(f);

 //
 // all the code emissions are below here (??)
 //

 // clear each function's provisional closure so a ref hit mid-rebuild defers to a
 // backpatch site rather than baking the stale closure; keep the import sets (BB).
 for (d = lam; twop(d); d = B(d)) AB(A(d)) = nil;

 for (e = nom, v = def; twop(e); e = B(e), v = B(v))
  if (lambp(f, A(v))) {
   d = assq(f, lam, A(e));
   f = c0_lambda(f, c, BB(d), BA(v));
   if (!g_ok(f)) return forget();
   A(v) = B(d) = pop1(f); }

 // closures final -> backpatch each recorded recursive-fn ref with its thread.
 for (d = (*c)->sites; twop(d); d = B(d)) cell(B(A(d)))->x = AB(A(A(d)));
 (*c)->sites = nil;

 nom = rev(nom); // put in literal order
 f = analyze(f, b, exp);
 f = gxl(g_push(f, 2, nil, e = (*b)->stack)); // push function stack rep
 (*b)->stack = g_ok(f) ? pop1(f) : nil;
 for (def = rev(def); twop(nom); nom = B(nom), def = B(def))
  f = analyze(f, b, A(def)),
  f = globp ? c0_ix(f, b, g_vm_defglob, A(nom)) : f,
  f = gxl(g_push(f, 2, A(nom), (*b)->stack)),
  (*b)->stack = g_ok(f) ? pop1(f) : nil;
 return
  (*b)->stack = e,
  incl(*b, 2),
  f = g_push(f, 2, c1_apn, putnum(ll)),
  forget(); }

static word ldels(struct g *f, word lam, word l) {
 if (!twop(l)) return nil;
 word m = ldels(f, lam, B(l));
 if (!assq(f, lam, A(l))) B(l) = m, m = l;
 return m; }

g_vm(g_vm_defglob) {
 Have(3);
 Sp -= 3;
 word k = Ip[1].x, v = Sp[3];
 return Sp[0] = k, Sp[1] = v, Sp[2] = f->dict, Pack(f),
  !g_ok(f = g_mapput(f)) ? gtrap(f) : (Unpack(f), Sp += 1, Ip += 2, Continue()); }

g_vm(g_vm_freev) { return
 Ip[0].ap = g_vm_quote,
 Ip[1].x = g_mapget(f, nil, Ip[1].x, f->dict),
 Continue(); }

g_vm(g_vm_eval) { return Ip++, Pack(f),
 !g_ok(f = c0(f, g_vm_jump)) ? gtrap(f) : (Unpack(f), Continue()); }

g_noinline struct g *g_evals_(struct g*f, char const*s) {
 static char const *t = "((:(e a b)(? b(e(ev'ev(A b))(B b))a)e)0)";
 struct ti i = {{g_vm_port_io, putnum(-1), putnum(EOF), putnum(false)}, t, 0};
 f = push0(pushq(push0(g_eval(g_reads(f, (void*) &i)))));
 i.t = s, i.i = 0, i.io.ungetc_buf = putnum(EOF), i.io.eof_seen = putnum(false);
 return g_pop(g_eval(gxr(gxl(gxr(gxl(g_reads(f, (void*) &i)))))), 1); }

// ============================================================================
// vm
// ============================================================================
// (set-numap fn): install the gwen handler for fixnum-as-function application.
// Called once from prelude.g; the value stays as the bif's result.
g_word g_numap;
g_vm(g_vm_set_numap) { g_numap = Sp[0]; return Ip++, Continue(); }

// Thread (function) combinators for `+` and `*`, installed from the prelude like
// num-ap. A thread operand takes precedence over every other type, so `+`/`*` of a
// function build a new function -- the README's Church arithmetic, so on Church
// numerals they agree with the numbers: `+` is Church add ((+ f g) a x = f a (g a x)),
// `*` is composition ((* f g) x = f (g x)) = Church mul (mul a b f = a (b f)). g_scomb
// holds the 4-arg add lambda, g_bcomb the 3-arg compose lambda; the C handlers reuse
// numap_drive to compute the partial (scomb f g) / (bcomb f g) -- itself the new
// function -- and leave it as the result, resuming at Ip+1.
g_word g_scomb, g_bcomb;
g_vm(g_vm_set_scomb) { g_scomb = Sp[0]; return Ip++, Continue(); }
g_vm(g_vm_set_bcomb) { g_bcomb = Sp[0]; return Ip++, Continue(); }

// Fixnum-as-function application. A fixnum operator n applied to x is dispatched
// to the gwen handler in g_numap as (num-ap n x): numeric x -> x**n, a function
// x -> x iterated n times (Church numerals). prelude.g installs num-ap before any
// fixnum apply can run (boot itself applies none), so there is no fallback path.
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
 return Ap(g_vm_ap, f); }
union u numap_drive[] = { {g_vm_ap}, {.ap = numap_swap}, {.ap = g_vm_ret0} };
// numap/numtap are tail-called (Ap) from the fused arg/quote handlers, which bump
// Ip by one word so its `ret = Ip+1` math lines up -- leaving Ip pointing at an
// operand, NOT a re-runnable instruction. So a plain Have() here is unsafe: g_vm_gc
// re-dispatches via Continue() -> cell(Ip)->ap, which would jump into that operand.
// Instead gc by hand and re-Ap ourselves (we read but don't mutate before this, so
// re-entry is idempotent); the dispatch never has to trust Ip.
#define NumapHave(self) if (Sp < Hp + 2) { \
 Pack(f); f = g_please(f, 2); if (!g_ok(f)) return gtrap(f); \
 return Unpack(f), Ap(self, f); }
static g_vm(g_vm_numap) {
 NumapHave(g_vm_numap);
 word n = Sp[1], x = Sp[0], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = n, dst[1] = g_numap, dst[2] = x, dst[3] = ret;
 return Sp = dst, Ip = numap_drive, Continue(); }
static g_vm(g_vm_numtap) {
 NumapHave(g_vm_numtap);
 word fs = getnum(Ip[1].x), n = Sp[1], x = Sp[0], *dst = &Sp[fs + 2] - 3, ret = Sp[fs + 2];
 dst[0] = n, dst[1] = g_numap, dst[2] = x, dst[3] = ret;
 return Sp = dst, Ip = numap_drive, Continue(); }

// `+`/`*` over a lambda operand: build the combinator partial (g_scomb/g_bcomb f g)
// and leave it as the result. Mirrors g_vm_numap's frame -- [f, comb, g, ret=Ip+1]
// run through numap_drive -- but the combinator (4-arg add / 3-arg compose) applied
// to 2 args yields a closure (the new function) instead of a value. Ip is at the +/*
// opcode (a re-runnable instruction), so a plain Have is safe; operands re-read after.
static g_vm(g_vm_addl) {
 Have(2);
 word fa = Sp[0], ga = Sp[1], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = fa, dst[1] = g_scomb, dst[2] = ga, dst[3] = ret;
 return Sp = dst, Ip = numap_drive, Continue(); }
static g_vm(g_vm_mull) {
 Have(2);
 word fa = Sp[0], ga = Sp[1], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = fa, dst[1] = g_bcomb, dst[2] = ga, dst[3] = ret;
 return Sp = dst, Ip = numap_drive, Continue(); }

// apply function to one argument
g_vm(g_vm_ap) {
 union u *k;
 if (oddp(Sp[1])) return Ap(g_vm_numap, f);
 k = cell(Sp[1]), Sp[1] = word(Ip + 1), Ip = k;
 YieldCheck();
 return Continue(); }

// tail call
g_vm(g_vm_tap) {
 if (oddp(Sp[1])) return Ap(g_vm_numtap, f);         // fixnum operator -> num-ap, deliver to caller
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getnum(Ip[1].x) + 1;
 Ip = cell(j), Sp[0] = x;
 YieldCheck();
 return Continue(); }

// apply to multiple arguments
g_vm(g_vm_apn) {
 size_t n = getnum(Ip[1].x);
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
 size_t n = getnum(Ip[1].x),
        r = getnum(Ip[2].x);
 Ip = cell(Sp[n]) + 2;
 word *o = Sp;
 for (Sp += r + 1; n--; Sp[n] = o[n]);
 YieldCheck();
 return Continue(); }

// return
g_vm(g_vm_ret) {
 word n = getnum(Ip[1].x) + 1;
 return Ip = cell(Sp[n]), Sp[n] = Sp[0], Sp += n, Continue(); }

g_vm(g_vm_ret0) { return
 Ip = cell(Sp[1]),
 Sp[1] = Sp[0],
 Sp += 1,
 Continue(); }


// kcall : x = Sp[0], k = Ip[1] -> Ip = k, Sp[0] = x
g_vm(g_vm_kcall) {
 word x = Sp[0];
 union u *stack = Ip + 2, *end = (union u*) ttag(f, stack);
 uintptr_t height = end - stack;
 Have(height);
 *(Sp = memmove(topof(f) - height, stack, height * sizeof(word))) = x;
 Ip = Ip[1].m;
 return Continue(); }

// callk : i = Sp[0], k = Ip + 1 -> Ip = i, Sp[0] = k
g_vm(g_vm_callk) {
 word f_val = Sp[0];                         // f, the call_cc arg
 if (oddp(f_val)) return Ip += 1, Continue();
 word height = topof(f) - Sp;
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
 return Ap(g_vm_ap, f); }

// g_vm_yield_sw_mono can't call g_wait_fds directly with a stack pointer
static g_noinline void g_wait_fd(int const fd, int n, uintptr_t ms) {
  g_wait_fds(&fd, n, ms); }

// monotask fast path
static g_vm(g_vm_yield_sw_mono) { uintptr_t my_wake = f->next_wake_at;
 int my_wait_fd = f->next_wait_fd;
 f->next_wake_at = 0;
 f->next_wait_fd = -1;
 f->yield_ctr = 0;
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
  if (n[1].m->ap != g_vm_task_exit && (uintptr_t) getnum(n[3].x) <= now) {
   int wf = (int) getnum(n[4].x);
   if (wf < 0 || g_ready(wf)) return n; }
 return NULL; }

static g_noinline union u *yield_sw_wait(struct g *f, uintptr_t my_wake, int my_wait_fd) {
 uintptr_t min_wake = my_wake;
 int fds[G_WAIT_FDS_MAX], nfds = 0;
 if (my_wait_fd >= 0) fds[nfds++] = my_wait_fd;
 for (union u *n = f->tasks->m; n != f->tasks; n = n->m)
  if (n[1].m->ap != g_vm_task_exit) {
   uintptr_t wa = (uintptr_t) getnum(n[3].x);
   if (wa && (!min_wake || wa < min_wake)) min_wake = wa;
   int wf = (int) getnum(n[4].x);
   if (wf >= 0 && nfds < G_WAIT_FDS_MAX) fds[nfds++] = wf; }
 if (!min_wake && !nfds) return NULL;
 uintptr_t now = g_clock();
 if (!min_wake) g_wait_fds(fds, nfds, 0);
 else if (min_wake > now) g_wait_fds(fds, nfds, min_wake - now);
 now = g_clock();
 if (my_wait_fd >= 0 && g_ready(my_wait_fd)) return NULL;
 return find_runnable(f->tasks, now); }

g_vm(g_vm_yield_sw) {
 if (f->tasks->m == f->tasks) return Ap(g_vm_yield_sw_mono, f);
 union u *next = find_runnable(f->tasks, g_clock());
 uintptr_t my_wake = f->next_wake_at;
 int my_wait_fd = f->next_wait_fd;
 if (!next) {
  next = yield_sw_wait(f, my_wake, my_wait_fd);
  if (!next) {
   f->next_wake_at = 0;
   f->next_wait_fd = -1;
   if (f->yield_ctr >= YIELD_INTERVAL) f->yield_ctr = 0;
   return Continue(); } }
 word my_height = topof(f) - Sp;
 union u *next_stack = next + 5,
       *end = (union u*) ttag(f, next_stack);
 uintptr_t restore_h = end - next_stack,
           need = my_height + restore_h + 6;
 if (Sp < Hp + need) {
  Pack(f);
  if (!g_ok(f = g_please(g_push(f, 1, next), need))) return gtrap(f);
  next = cell(pop1(f));
  Unpack(f);
  next_stack = next + 5; }   // recompute: next was forwarded by gc
 f->next_wake_at = 0;
 f->next_wait_fd = -1;
 union u *prev = next;
 while (prev->m != f->tasks) prev = prev->m;
 union u *N = (union u*) Hp;
 Hp += need - restore_h;
 N[0].m = f->tasks->m;
 N[1].m = Ip;
 N[2].x = f->tasks[2].x;
 N[3].x = putnum((intptr_t) my_wake);
 N[4].x = putnum(my_wait_fd);
 memcpy(N + 5, Sp, my_height * sizeof(word));
 prev->m = tagthd(N, 5 + my_height);
 f->yield_ctr = 0;
 f->tasks = next;
 Sp = memmove(topof(f) - restore_h, next_stack, restore_h * sizeof(word));
 Ip = next[1].m;
 return Continue(); }

g_vm(g_vm_yield_bif) { return Ip++, Ap(g_vm_yield_sw, f); }
g_vm(g_vm_task_exit) { return Ap(g_vm_yield_sw, f); }
static union u spawn_body[] = { {g_vm_ap}, {.ap = g_vm_task_exit} };
g_vm(g_vm_spawn) {
 Have(8);
 // New task node N: [next, saved_ip=spawn_body, pid, wake_at=0, wait_io=0, stack[0..1]=x,fn, tag]
 union u *N = (union u*) Hp;
 Hp += 8;
 word fn = Sp[0], x = Sp[1];
 uintptr_t pid = ++f->next_pid;
 N[0].m = f->tasks->m;
 N[1].m = (union u*) spawn_body;
 N[2].x = Sp[1] = putnum(pid);
 N[3].x = nil;         // wake_at: sentinel for "always runnable"
 N[4].x = putnum(-1);  // wait_fd: -1 = not waiting on I/O
 N[5].x = x;
 N[6].x = fn;
 f->tasks->m = tagthd(N, 7);
 return Sp++, Ip++, Continue(); }

g_vm(g_vm_wait) {
 word pid_arg = Sp[0], ret = nil;
 intptr_t target = getnum(pid_arg);
 for (union u *node = f->tasks->m; node != f->tasks; node = node->m) {
  if (getnum(node[2].x) != target) continue;
  if (node[1].m->ap == g_vm_task_exit) {
   // dormant: dormant task's stack is just [retval] at node[5]
   ret = node[5].x;
   union u *prev = node;
   while (prev->m != node) prev = prev->m;
   prev->m = node->m;
   break; }
   // still running: yield without advancing Ip (re-enter wait on resume)
  return Ap(g_vm_yield_sw, f); }
 return *Sp = ret, Ip++, Continue(); }

g_vm(g_vm_donep) {
 word pid_arg = Sp[0], result = putnum(1);
 intptr_t target = getnum(pid_arg);
 for (union u *node = f->tasks->m; node != f->tasks; node = node->m)
  if (getnum(node[2].x) == target) {
   if (node[1].m->ap != g_vm_task_exit) result = nil;
   break; }
 Sp[0] = result;
 Ip += 1;
 return Continue(); }

g_vm(g_vm_kill) {
 word pid_arg = Sp[0], result = nil;
 intptr_t target = getnum(pid_arg);
 union u *prev = f->tasks;
 for (union u *node = prev->m; node != f->tasks; prev = node, node = node->m)
  if (getnum(node[2].x) == target) {
   prev->m = node->m;
   result = putnum(1);
   break; }
 Sp[0] = result;
 Ip += 1;
 return Continue(); }

g_vm(g_vm_sleep) {
 word n = Sp[0];
 Sp[0] = nil;
 Ip += 1;
 if (!nump(n) || getnum(n) <= 0) return Continue();
 f->next_wake_at = (uintptr_t) g_clock() + getnum(n);
 return Ap(g_vm_yield_sw, f); }


g_vm(g_vm_jump) { return Ip = Ip[1].m, Continue(); }
// The only compiled truthiness branch (`?`, and the `&&`/`||` macros). Uses the
// language falsy predicate so an all-zero tuple (boxed 0.0, zero int box,
// all-zero array) takes the false arm, lifting "0 is the only false scalar".
g_vm(g_vm_cond) { return Ip = g_false(*Sp++) ? Ip[1].m : Ip + 2, Continue(); }
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
 size_t n = getnum(Ip[1].x);
 // FIXME this does not always need to be a runtime check
 if (n > 2) Hp += 2,
            j += 2,
            k[0].ap = g_vm_cur,
            k[1].x = putnum(n - 1);
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
  *Sp = putnum(1);
  return Continue(); }

// push a value from the stack
g_vm(g_vm_arg) {
 Have1();
 Sp[-1] = Sp[getnum(Ip[1].x)];
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
  Sp[-1] = Sp[getnum(Ip[1].x)], Sp -= 1, Ip += 1;   // push local under operator; resume now Ip+2
  return Ap(g_vm_numap, f); }
 Have1();
 Sp[-1] = Sp[getnum(Ip[1].x)];
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
  return Ap(g_vm_numap, f); }
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
  Sp[-1] = Sp[getnum(Ip[1].x)], Sp -= 1, Ip += 1;   // push local under operator; fs operand now Ip[1]
  return Ap(g_vm_numtap, f); }
 Have1();
 Sp[-1] = Sp[getnum(Ip[1].x)];
 Sp -= 1;
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getnum(Ip[2].x) + 1;
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
 clip(f, cell(Sp[0])), Ip++, Continue(); }

g_vm(g_vm_seek) { return
 Sp[1] = word(cell(Sp[1]) + getnum(Sp[0])),
 Sp++, Ip++, Continue(); }

g_vm(g_vm_peek2) { return
 Sp[1] = (cell(Sp[1]) + getnum(Sp[0]))->x,
 Sp++, Ip++, Continue(); }

g_vm(g_vm_poke2) {
 union u *c = cell(Sp[2]) + getnum(Sp[0]);
 return c->x = Sp[1], *(Sp += 2) = word(c), Ip++, Continue(); }

g_vm(g_vm_lam) {
 size_t n = getnum(Sp[0]);
 Have(n + Width(struct g_tag));
 union u *k = (union u*) Hp;
 Hp += n + Width(struct g_tag);
 Sp[0] = word(memset(tagthd(k, n), -1, n * sizeof(word)));
 return Ip++, Continue(); }

// (len x): a total size/magnitude. Containers -> element count (string/buf bytes,
// list pairs, table keys, rank-n array shape-product). Numbers -> floored |x|
// (fixnum/box/float/complex), so it agrees with (int (abs x)); a bignum saturates
// to the nearest representable fixnum (sign-preserving). Symbol -> its name length
// (anonymous gensym -> 0). Everything else (code, ports) -> 0.
// ceil a non-negative magnitude into a fixnum, saturating at FIX_MAX. ceil (not
// floor) so the result is 0 *only* when m is exactly 0 -- len then doubles as a
// zero test: (= 0 (len x)) iff x is zero/empty. Never overflows putnum's tag.
static g_inline intptr_t len_sat(g_flo_t m) {
  if (m >= (g_flo_t) FIX_MAX) return FIX_MAX;
  intptr_t i = (intptr_t) m;                    // trunc toward 0 (m >= 0)
  return i + (m > (g_flo_t) i ? 1 : 0); }       // bump for any fractional part -> ceil
g_vm(g_vm_len) {
  word x = Sp[0];
  intptr_t l = 0;
  if (nump(x)) { intptr_t n = getnum(x); l = n == FIX_MIN ? FIX_MAX : n < 0 ? -n : n; }  // fixnum: |x|
  else if (bufp(x)) l = len(buf_str(x));                         // mutable byte string
  else if (mapp(x)) l = map_len(x);                              // table: key count
  else if (datp(x)) switch (typ(x)) {
    default: l = 1; break;                                      // unknown present data kind -> truthy
    case K_STRING: l = len(x); break;                             // string: byte count
    case K_TWO: { word p = x; do l++, p = B(p); while (twop(p)); } break;  // list: pair count
    case K_BIG: l = FIX_MAX; break;                             // |bignum| > FIX_MAX: saturate
    case K_SYM: {                                              // symbol: name length, floored at 1
      struct g_atom *s = sym(x);                               // (a symbol is always a present identity)
      intptr_t nl = !s->nom ? 0                                // anonymous gensym
        : strp(word(s->nom)) ? (intptr_t) len(s->nom)          // interned: its name string
        : ((struct g_atom*) s->nom)->nom ? (intptr_t) len(((struct g_atom*) s->nom)->nom) : 0;  // uninterned
      l = nl ? nl : 1;
      break; }
    case K_TUPLE: {                                               // boxed scalar or rank-n array
      struct g_tuple *v = tuple(x);                                 // all -> ceil(|x|), saturated, never negative
      if (v->rank) { uintptr_t i = 0, n = 1;                    // array: its L2 norm
        while (i < v->rank) n *= v->shape[i++];
        g_flo_t s = 0;
        for (i = 0; i < n; i++) { g_flo_t e = tuple_get_flo(v, i); s += e * e; }
        l = len_sat(g_sqrt(s)); }
      else if (v->type == g_C) {                                // complex: |z|
        g_flo_t re = cplx_re(x), im = cplx_im(x); l = len_sat(g_sqrt(re * re + im * im)); }
      else if (v->type == g_R) { g_flo_t f = flo_get(x); l = len_sat(f < 0 ? -f : f); }  // float box
      else l = FIX_MAX;                                         // g_Z int box: |x| always exceeds FIX_MAX
      break; } }
  else l = 1;                                                  // opaque but present (fn / port): truthy, len 1
  Sp[0] = putnum(l);
  Ip += 1;
  return Continue(); }

// ============================================================================
// io
// ============================================================================
static g_inline bool iop(word x) { return lamp(x) && cell(x)->ap == g_vm_port_io; }
static g_inline struct g_port_vt const *port_vt(word fd_tagged) {
 intptr_t fd = getnum(fd_tagged);
 return fd >= 0 ? &g_fd_port_vt : &synth[-(fd + 1)]; }
static g_inline struct g *zgetc(struct g*f)          { return g_ok(f) ? port_vt(f->io->fd)->getc(f) : f; }
static g_inline struct g *zungetc(struct g*f, int c) { return g_ok(f) ? port_vt(f->io->fd)->ungetc(f, c) : f; }
static g_inline struct g *zputc(struct g*f, int c)   { return port_vt(f->io->fd)->putc(f, c); }
static g_inline struct g *zflush(struct g*f)         { return port_vt(f->io->fd)->flush(f); }
static g_inline struct g *zeof(struct g*f)           { return g_ok(f) ? port_vt(f->io->fd)->eof(f) : f; }
struct ci { struct g_io io; g_word head; }; // charlist input
struct to { struct g_io io; struct g_str *buf; g_word i; }; // lisp string output
static struct g *g_dtoa2(struct g*, g_flo_t);
static struct g *gfputx(struct g *f, struct g_io *o, intptr_t x);

static struct g *noop_getc(struct g *f) {
 g_core_of(f)->io->eof_seen = putnum(true);
 return f->b = EOF, f; }
static struct g *noop_ungetc(struct g *f, int c) { (void) c; return f; }
static struct g *noop_eof(struct g *f) { return f->b = true, f; }
static struct g *noop_putc(struct g *f, int c) { (void) c; return f; }
static struct g *noop_flush(struct g *f) { return f; }

static struct g *ti_eof(struct g*f) {
 struct ti *i = (struct ti*) f->io;
 return f->b = (getnum(i->io.ungetc_buf) == EOF) && getnum(i->io.eof_seen), f; }

static struct g *ti_getc(struct g*f) {
 struct ti *i = (struct ti*) f->io;
 if (getnum(i->io.ungetc_buf) != EOF) {
  int c = getnum(i->io.ungetc_buf);
  i->io.ungetc_buf = putnum(EOF);
  return f->b = c, f; }
 if (!i->t[i->i]) { i->io.eof_seen = putnum(true); return f->b = EOF, f; }
 return f->b = i->t[i->i++], f; }

static struct g *ti_ungetc(struct g*f, int c) {
 struct ti *i = (struct ti*) f->io;
 i->io.ungetc_buf = putnum(c);
 i->io.eof_seen = putnum(false);
 return f->b = c, f; }

static struct g *ci_getc(struct g *f) {
 struct ci *i = (struct ci*) f->io;
 if (getnum(i->io.ungetc_buf) != EOF) {
  int c = getnum(i->io.ungetc_buf);
  i->io.ungetc_buf = putnum(EOF);
  return f->b = c, f; }
 if (!twop(i->head)) { i->io.eof_seen = putnum(true); return f->b = EOF, f; }
 int c = getnum(A(i->head));
 i->head = B(i->head);
 return f->b = c, f; }

static struct g *to_putc(struct g *f, int c) {
 struct to *o = (struct to*) f->io;
 uintptr_t i = getnum(o->i);
 if (i >= len(o->buf)) {
  uintptr_t new_cap = len(o->buf) * 2;
  f = str0(f, new_cap);
  if (!g_ok(f)) return f;
  o = (struct to*) f->io;                 // GC may have moved it; f->out is GC-traced
  struct g_str *nb = (struct g_str*) f->sp[0];
  memcpy(txt(nb), txt(o->buf), i);
  o->buf = nb;
  f->sp++; }
 txt(o->buf)[i] = c;
 o->i = putnum(i + 1);
 return f; }
static struct g *to_flush(struct g *f) { return f; }

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
  f->io = (struct g_io*) Sp[0];
  Pack(f);
  if (!g_ok(f = zputc(f, getnum(f->sp[1])))) return gtrap(f);
  Unpack(f); }
 return Sp++, Ip++, Continue(); }

// (fflush port) — flush; return the port.
g_vm(g_vm_fflush) {
 if (iop(Sp[0])) {
  f->io = (struct g_io*) Sp[0];
  Pack(f);
  if (!g_ok(f = zflush(f))) return gtrap(f);
  Unpack(f); }
 return Ip++, Continue(); }

// (fputs port s) — write every byte of string-or-buf s through port; return
// the port. No-op when args are misused (non-port, or neither string nor
// buf). bytes_of resolves either to the g_str holding the bytes, re-read each
// iteration so GC inside zputc (e.g., growing a sink buffer) can forward it
// safely (for a buf, GC may move both the wrapper and its backing string).
g_vm(g_vm_fputs) {
 if (iop(Sp[0]) && (strp(Sp[1]) || bufp(Sp[1]))) {
  f->io = (struct g_io*) Sp[0];
  uintptr_t i = 0, l = len(bytes_of(Sp[1]));
  Pack(f);
  while (g_ok(f) && i < l) f = zputc(f, txt(bytes_of(f->sp[1]))[i++]);
  if (!g_ok(f = zflush(f))) return gtrap(f);
  Unpack(f); }
 return Sp++, Ip++, Continue(); }

g_vm(g_vm_fputx) {
 if (iop(Sp[0])) {
  Pack(f);
  if (!g_ok(f = gfputx(f, (struct g_io*) Sp[0], Sp[1]))) return gtrap(f);
  Unpack(f); }
 return Sp++, Ip++, Continue(); }

static struct g*gfputn(struct g *f, intptr_t n, uint8_t b, struct g_io *o);
g_vm(g_vm_fputn) {
 if (iop(Sp[0])) {
   Pack(f);
   if (!g_ok(f = gfputn(f, getnum(Sp[1]), getnum(Sp[2]), (struct g_io*) Sp[0]))) return gtrap(f);
   Unpack(f);
   Sp[2] = Sp[1]; }
 return Sp += 2, Ip++, Continue(); }

static struct g*gzputc(struct g*f, int c) {
  return port_vt(g_core_of(f)->io->fd)->putc(f, c); }
static struct g*gzputs(struct g*f, char const *s) {
 while (*s) f = gzputc(f, *s++);
 return f; }

static struct g*gzputn(struct g *f, intptr_t n, uint8_t b) {
 uintptr_t
  m = n >= 0 || b != 10 ? (uintptr_t) n : (f = gzputc(f, '-'), -(uintptr_t) n),
  q = m / b,
  r = m % b;
 if (q) f = gzputn(f, q, b);
 return gzputc(f, g_digits[r]); }

static g_inline struct g*gfputn(struct g *f, intptr_t n, uint8_t b, struct g_io *o) {
 return f->io = o, gzputn(f, n, b); }

static struct g*gvzprintf(struct g*f, char const *fmt, va_list xs) {
 for (int c; (c = *fmt++);) {
  if (c != '%') f = gzputc(f, c);
  else pass: switch ((c = *fmt++)) {
   case 0: return f;
   case 'l': goto pass;
   case 'b': f = gzputn(f, va_arg(xs, uintptr_t), 2); continue;
   case 'n': f = gzputn(f, va_arg(xs, uintptr_t), 6); continue;
   case 'o': f = gzputn(f, va_arg(xs, uintptr_t), 8); continue;
   case 'd': f = gzputn(f, va_arg(xs, uintptr_t), 10); continue;
   case 'u': f = gzputn(f, va_arg(xs, uintptr_t), 12); continue;
   case 'x': f = gzputn(f, va_arg(xs, uintptr_t), 16); continue;
   case 'z': f = gzputn(f, va_arg(xs, uintptr_t), 36); continue;
   case '%': f = gzputc(f, '%'); continue;             // %% -> literal %
   default: f = gzputc(f, c); } }
 return f; }

static struct g *gzprintf(struct g *f, char const *fmt, ...) {
 va_list xs;
 va_start(xs, fmt);
 f = gvzprintf(f, fmt, xs);
 va_end(xs);
 return f; }

static struct g *gzputx(struct g *f, intptr_t x, uintptr_t off);
static struct g *gzputcs(struct g *f, char const *s);

// --- print cycle detection (tables only) --------------------------------------
// A "seen" list of the tables on the current print path lives in a single stack
// slot at the bottom of the print region (established by gfputx). It moves with
// the stack on GC, so callers locate it by its offset from the stack top (`off`),
// which GC preserves; the offset is threaded down the recursion as an ordinary
// integer (no struct-g state). A table is consed on as we descend into it and
// dropped as we ascend, so the list is exactly the ancestor path of tables. When
// printing finishes gfputx restores the original stack height, discarding it.
static word *seen_slot(struct g *f, uintptr_t off) {
 return topof(g_core_of(f)) - off; }
static bool seen_member(struct g *f, uintptr_t off, word x) {
 for (word l = *seen_slot(f, off); twop(l); l = B(l)) if (A(l) == x) return true;
 return false; }
static struct g *seen_push(struct g *f, uintptr_t off, word x) {   // cons x onto seen
 if (!g_ok(f = g_push(f, 1, x))) return f;                         // protect x across GC
 if (!g_ok(f = g_have(f, Width(struct g_pair)))) return g_pop(f, 1);
 struct g_pair *p = bump(f, Width(struct g_pair));
 word *slot = seen_slot(f, off);                                   // re-read: GC may move it
 ini_two(p, f->sp[0], *slot);
 *slot = (word) p;
 return g_pop(f, 1); }
static void seen_pop(struct g *f, uintptr_t off) {                 // drop the newest entry
 word *slot = seen_slot(f, off);
 *slot = B(*slot); }

static g_inline struct g*gzput_two(struct g*f, word _, uintptr_t off) {
 if (!g_ok(f = g_push(f, 1, _))) return f;
 struct g_str *n;
 // a one-operand `\` pair (`(\ x)`) is quote -> print as 'x; ≥2 operands is a lambda.
 if (symp(A(f->sp[0])) && (n = sym(A(f->sp[0]))->nom) && len(n) == 1 && txt(n)[0] == '\\'
     && twop(B(f->sp[0])) && !twop(BB(f->sp[0])))
  f = gzputx(gzputc(f, '\''), AB(f->sp[0]), off);
 else for (f = gzputc(f, '(');; f = gzputc(f, ' '), f->sp[0] = B(f->sp[0])) {
  f = gzputx(f, A(f->sp[0]), off);            // off threaded so nested tables are still tracked
  if (!twop(B(f->sp[0]))) { f = gzputc(f, ')'); break; } }
 return g_pop(f, 1); }


// Print element i of the array parked at f->sp[0] as a bare number (float ->
// g_dtoa, integer -> base 10). The element value is read before any gzputc, so
// a GC during printing (string-port growth) that relocates the array is safe;
// callers re-fetch tuple(f->sp[0]) each call for the same reason.
static struct g *gzput_tuple_elem(struct g *f, uintptr_t i) {
 struct g_tuple *v = tuple(f->sp[0]);
 if (v->type >= g_R)
  return g_dtoa2(f, tuple_get_flo(v, i));
 return gzputn(f, tuple_get_int(v, i), 10); }

// element-kind code -> a prelude symbol bound to it, so the printed `arrl` form
// round-trips: Z prints as the `i64` alias, R as `f64`. `c` only labels the
// 32-bit RNG state tuple (never a constructible array -- arrl rejects ty > R).
static char const *const g_vt_names[] = {
 [g_Z] = "i64", [g_R] = "f64", [g_C] = "c", [g_O] = "o" };

// Print a rank>=1 array (f->sp[0]) as a constructor expression that reads back to
// the same array. A rank-1 i64/f64 array uses the terse `@(a b …)` sugar (the `@`
// reader macro splices into `(tuple a b …)`, which infers i64/f64 from its args);
// anything else (rank>=2, or an object array whose elements are arbitrary, quoted
// values) uses `(arrl <type> '(shape) '(vals))`, a bare constructor call that pins
// the exact element type and shape. The array may move on a GC during printing, so
// shape/elements are re-fetched from f->sp[0] each step.
static g_noinline struct g *gzputx(struct g *f, intptr_t x, uintptr_t off);

static struct g *gzput_arr(struct g *f, uintptr_t off) {
 struct g_tuple *v = tuple(f->sp[0]);
 uintptr_t rank = v->rank, type = v->type, nelem = 1;
 for (uintptr_t i = 0; i < rank; i++) nelem *= v->shape[i];
 if (rank == 1 && (type == g_Z || type == g_R)) {     // terse rank-1 numeric: @(a b …)
  if (nelem == 0) return gzputcs(f, "@0");            // empty array prints @0 (reads back via @0/@())
  f = gzputc(f, '@'); f = gzputc(f, '(');
  for (uintptr_t i = 0; g_ok(f) && i < nelem; i++) {
   if (i) f = gzputc(f, ' ');
   f = gzput_tuple_elem(f, i); }
  return g_ok(f) ? gzputc(f, ')') : f; }
 f = gzprintf(f, "(arrl ");                            // explicit: (arrl type '(shape) '(vals))
 for (char const *s = g_vt_names[type]; g_ok(f) && *s; s++) f = gzputc(f, *s);
 f = gzprintf(f, " '(");
 for (uintptr_t i = 0; g_ok(f) && i < rank; i++) {
  if (i) f = gzputc(f, ' ');
  f = gzputn(f, tuple(f->sp[0])->shape[i], 10); }
 f = gzprintf(f, ") '(");
 for (uintptr_t i = 0; g_ok(f) && i < nelem; i++) {    // object elements via the general
  if (i) f = gzputc(f, ' ');                           // printer; numeric via gzput_tuple_elem
  f = type == g_O ? gzputx(f, tuple_get_obj(tuple(f->sp[0]), i), off) : gzput_tuple_elem(f, i); }
 return g_ok(f) ? gzprintf(f, "))") : f; }

static g_inline struct g*gzput_tuple_scalar_float(struct g*f) {
 return g_dtoa2(f, (g_flo_t) flo_get(f->sp[0])); }

// complex -> (C re im); round-trips by re-evaluation (C is a bif). re/im are
// read into C locals up front so a GC during g_dtoa2 can't strand the operand.
static g_inline struct g*gzput_tuple_scalar_complex(struct g*f) {
 g_flo_t re = cplx_re(f->sp[0]), im = cplx_im(f->sp[0]);
 f = gzprintf(f, "(C ");
 f = g_dtoa2(f, re);
 f = gzputc(f, ' ');
 f = g_dtoa2(f, im);
 return gzputc(f, ')'); }

static g_inline struct g*gzput_tuple(struct g*f, word _, uintptr_t off) {
 intptr_t rank = tuple(_)->rank, type = tuple(_)->type;
 if (!g_ok(f = g_push(f, 1, _))) return f;
 if (rank == 0 && type == g_R) f = gzput_tuple_scalar_float(f);
 else if (rank == 0 && type == g_Z) f = gzputn(f, box_get(f->sp[0]), 10);
 else if (rank == 0 && type == g_C) f = gzput_tuple_scalar_complex(f);
 else if (rank >= 1) f = gzput_arr(f, off);
 else f = gzprintf(f, ",tuple@%z:%d.%d", tuple(f->sp[0]), type, rank);
 return g_pop(f, 1); }

static g_inline struct g*gzput_str(struct g*f, word _) {
 uintptr_t slen = len(_);
 f = gzputc(g_push(f, 1, _), '"');
 for (uintptr_t i = 0; g_ok(f) && i < slen; i++) {
  char c = txt(f->sp[0])[i];
  if (c == '\\' || c == '"') f = gzputc(f, '\\');
  else if (c == '\n') f = gzputc(f, '\\'), c = 'n';
  else if (c == '\t') f = gzputc(f, '\\'), c = 't';
  else if (c == '\r') f = gzputc(f, '\\'), c = 'r';
  else if (c == '\0') f = gzputc(f, '\\'), c = '0';
  else if ((unsigned char) c < 32)
   f = gzputc(gzputc(gzputc(f, '\\'), 'x'), g_digits[(c >> 4) & 0xf]),
   c = g_digits[c & 0xf];
  f = gzputc(f, c); }
 return g_pop(gzputc(f, '"'), 1); }

// A symbol's nom encodes its kind: 0 = anonymous gensym, a string = interned, a
// symbol = named-uninterned (the naming symbol, whose own nom is the name string).
// Interned syms print bare; gensyms get the `$` sigil (the `$` reader macro wraps
// its operand with gensym): a named-uninterned gensym as `$<name>` (re-reads to a
// fresh gensym of the same name), an anonymous one as `$<addr>` (unique, doesn't
// round-trip to identity -- the addr just makes the printout distinguishable).
static g_inline struct g*gzput_sym(struct g*f, word _) {
 if (g_ok(f = g_push(f, 1, _))) {
  word nom = word(sym(f->sp[0])->nom);
  if (!nom) f = gzprintf(f, "$%z", f->sp[0]);              // anonymous gensym -> $<addr>
  else if (strp(nom)) {                                     // interned: bare name
   f->sp[0] = nom;
   for (uintptr_t l = len(nom), i = 0; g_ok(f) && i < l;)
     f = gzputc(f, txt(f->sp[0])[i++]);
  } else {                                                  // named-uninterned -> $<name>
   word name = word(sym(nom)->nom);
   if (!name || !strp(name)) f = gzprintf(f, "$%z", f->sp[0]); // named after a nameless sym: fall back
   else {
    f = gzputc(f, '$');
    f->sp[0] = name;
    for (uintptr_t l = len(name), i = 0; g_ok(f) && i < l;)
        f = gzputc(f, txt(f->sp[0])[i++]); } } }
 return g_pop(f, 1); }


// Maps print as %(k v …), round-tripping through the %( reader, like hashes.
// A map is mutable and can hold itself, so guard the recursion with the seen
// list. Snapshot k/v into a list first (printing may GC and move the map).
static g_inline struct g*gzput_map(struct g*f, word x, uintptr_t off) {
 if (seen_member(f, off, x)) return gzputcs(f, "<cycle>");
 if (!g_ok(f = seen_push(f, off, x))) return f;        // sp[0] = seen list head (= x)
 x = A(*seen_slot(f, off));                             // reload x: seen_push may have GC'd
 if (!g_ok(f = g_push(f, 1, x))) return seen_pop(f, off), f;   // sp[0] = map
 uintptr_t cap = map_cap(f->sp[0]), n = map_len(f->sp[0]);
 if (!g_ok(f = g_have(f, n * 2 * Width(struct g_pair)))) return seen_pop(g_pop(f, 1), off), f;
 word *s = map_slots(f->sp[0]);                         // re-fetch after possible GC
 struct g_pair *p = bump(f, n * 2 * Width(struct g_pair));
 word list = nil;
 for (uintptr_t i = cap; i;)
  if (s[2 * --i] != MAP_GAP) {
   struct g_pair *kv = p++;
   ini_two(kv, s[2 * i], s[2 * i + 1]);                 // (k . v)
   ini_two(p, (word) kv, list), list = (word) p++; }    // cons onto the snapshot
 fs0(f) = list;
 if (!twop(fs0(f))) f = gzputcs(f, "%0");              // empty map prints %0 (reads back via %0/%())
 else {
  if (g_ok(f = gzprintf(f, "%%("))) for (bool sp = false;;) {
   if (sp) f = gzputc(f, ' ');
   sp = true;
   f = gzputx(f, AA(g_core_of(f)->sp[0]), off);
   f = gzputc(f, ' '); f = gzputx(f, BA(g_core_of(f)->sp[0]), off);
   g_core_of(f)->sp[0] = B(g_core_of(f)->sp[0]);
   if (!g_ok(f) || !twop(f->sp[0])) break; }
  f = g_ok(f) ? gzputc(f, ')') : f; }
 f = g_pop(f, 1);
 return seen_pop(f, off), f; }

// A bignum prints in base 10 (with sign). g_big_dec renders it to a fresh
// string (repeated divide-by-10 of a heap-local copy); we then emit the bytes,
// re-fetching sp[0] each step since gzputc may grow a string port and GC.
static g_inline struct g*gzput_big(struct g*f, word x) {
 if (!g_ok(f = g_push(f, 1, x))) return f;
 f = g_big_dec(f);
 for (uintptr_t i = 0, n = g_ok(f) ? len(f->sp[0]) : 0; g_ok(f) && i < n; i++)
  f = gzputc(f, txt(f->sp[0])[i]);
 return g_pop(f, 1); }

// emit a C string literal byte-for-byte.
static struct g *gzputcs(struct g *f, char const *s) {
 for (; g_ok(f) && *s; s++) f = gzputc(f, *s);
 return f; }

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

static struct g *gzput_fn_body(struct g *f, word x, uintptr_t off);

// the in-pool source \-expr stashed at value[-1] by a compiled lambda, or 0.
static word fn_src(struct g *c, union u *k, word x) {
 word s = k[-1].x;
 return ptr(x) > ptr(c) && ptr(x) < ptr(c) + c->len
     && lamp(s) && ptr(s) >= ptr(c) && ptr(s) < ptr(c) + c->len && twop(s) ? s : 0; }

// Print a function value. Like tuple/cplx/hash it's a `,`-prefixed value form (so it
// reads back via uq=identity): ,(base arg…) for a partial application / closure,
// ,name for a builtin, ,(\ …) for a compiled lambda (its stored source). An opaque
// thread (continuation, top-level wrap) has no constructor form, so it prints as the
// opaque, re-parsable token ,thd@<addr>. The leading , is emitted once here; body w/o it.
static struct g *gzput_fn(struct g *f, word x, uintptr_t off) {
 union u *k = cell(x);
 bool reprp = fn_partialp(k) || g_bif_name(x) || fn_src(g_core_of(f), k, x);
 return reprp ? gzput_fn_body(f, x, off) : gzprintf(f, "\\%z", x); }

// Render a function as a bare constructor expression (NO leading ,). Detection
// order matters: a bare multi-arg lambda and a partial-app both have a g_vm_cur
// head, and a bif's value[-1] is undefined static data. The partial-app base
// recurses here (not gzput_fn) so it doesn't get its own comma.
static struct g *gzput_fn_body(struct g *f, word x, uintptr_t off) {
 struct g *c = g_core_of(f);
 union u *k = cell(x);
 if (fn_partialp(k)) {                              // (base arg…)
  if (!g_ok(f = g_push(f, 1, x))) return f;         // park: GC relocates the closure
  int na; fn_base(cell(f->sp[0]), &na);
  f = gzputc(f, '(');
  { union u *bk = cell(f->sp[0]); int n2;           // base re-derived after each gzputc
    f = gzput_fn_body(f, (word) fn_base(bk, &n2), off); }
  for (int i = 0; g_ok(f) && i < na; i++) {
   f = gzputc(f, ' ');                              // separate stmt: re-read arg after GC
   f = gzputx(f, fn_arg(cell(f->sp[0]), i, na), off); }
  return g_pop(g_ok(f) ? gzputc(f, ')') : f, 1); }
 char const *nm = g_bif_name(x);                    // builtin -> name
 if (nm) return gzputcs(f, nm);
 word s = fn_src(c, k, x);                          // compiled lambda -> source \-expr
 return s ? gzputx(f, s, off) : gzprintf(f, "\\%z", x); }

static g_noinline struct g *gzputx(struct g *f, intptr_t x, uintptr_t off) {
 if (nump(x)) return gzprintf(f, "%d", getnum(x));
 if (!datp(x)) return mapp(x) ? gzput_map(f, x, off) : gzput_fn(f, x, off);
 // Maps are the only mutable/self-referential value, and gzput_map guards its
 // own recursion (the seen list); the data kinds below are acyclic.
 switch (typ(x)) {
   default: __builtin_trap();
   case K_TWO:  return gzput_two(f, x, off);
   case K_TUPLE:  return gzput_tuple(f, x, off);
   case K_SYM:  return gzput_sym(f, x);
   case K_STRING: return gzput_str(f, x);
   case K_BIG:  return gzput_big(f, x); } }

// Establish a fresh seen-list slot at the bottom of the print region, print, then
// restore the original stack height (discarding the slot and the whole list).
static g_inline struct g *gfputx(struct g *f, struct g_io *o, intptr_t x) {
 struct g *c = g_core_of(f);
 c->io = o;
 uintptr_t base = topof(c) - c->sp;                 // original height (GC-invariant)
 if (!g_ok(f = g_push(f, 1, nil))) return f;        // the seen-list slot
 c = g_core_of(f);
 f = gzputx(f, x, topof(c) - c->sp);                // offset of the slot from the top
 c = g_core_of(f);
 return c->sp = topof(c) - base, f; }               // restore original stack height

// AI slop alert....
//

static struct g* g_dtoa2(struct g*f, g_flo_t v) {
 int const max_frac = sizeof(g_flo_t) == 4 ? 7 : 15;
 if (v != v) return gzputs(f, "nan");
 if (v < 0) f = gzputc(f, '-'), v = -v;
 if (v > DTOA_INF) return gzputs(f, "inf");
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
 while (ib_n > 0) f = gzputc(f, ib[--ib_n]);
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
   f = gzputc(f, '.');
   for (int i = 0; i < fb_n; i++) f = gzputc(f, fb[i]); } }
 if (sci) {
  f = gzputc(f, 'e');
  if (exp < 0) f = gzputc(f, '-'), exp = -exp;
  char eb[8]; int eb_n = 0;
  if (exp == 0) eb[eb_n++] = '0';
  while (exp) eb[eb_n++] = '0' + exp % 10, exp /= 10;
  while (eb_n > 0) f = gzputc(f, eb[--eb_n]); }
 return f; }

// (feof port) — -1 if at end of stream, nil otherwise.
g_vm(g_vm_feof) {
 if (iop(Sp[0])) {
  f->io = (struct g_io*) Sp[0];
  Pack(f);
  if (!g_ok(f = zeof(f))) return gtrap(f);
  Unpack(f);
  Sp[0] = f->b ? putnum(1) : nil; }
 return Ip++, Continue(); }

// (fgetc port) — like (getc _) but on an explicit port. Cooperative wait
// uses the port's own fd.
g_vm(g_vm_fgetc) {
 if (iop(Sp[0])) {
  struct g_io *i = (struct g_io*) Sp[0];
  if (!g_ready(getnum(i->fd))) {
   f->next_wait_fd = getnum(i->fd);
   return Ap(g_vm_yield_sw, f); }
  Pack(f);
  f->io = i;
  if (!g_ok(f = zgetc(f))) return gtrap(f);
  Unpack(f);
  Sp[0] = putnum(f->b); }
 return Ip++, Continue(); }

// (fungetc port byte) — push back one byte, return the byte.
g_vm(g_vm_fungetc) {
 if (iop(Sp[0])) {
  struct g_io *i = (struct g_io*) Sp[0];
  Pack(f);
  f->io = i;
  if (!g_ok(f = zungetc(f, getnum(f->sp[1])))) return gtrap(f);
  Unpack(f); }
 return Sp++, Ip++, Continue(); }

// Finalizer for heap stream ports: extract the fd and ask the frontend to
// close it. Runs inside GC (run_finalizers); fz->p still points at the
// from-space port so its fields are readable. Skip if fd < 0 — that means
// either the port was already closed explicitly (fd mutated to a synth
// sentinel) or the caller wrapped a non-OS fd.
static void io_close(void *p) {
 intptr_t fd = getnum(((struct g_io*)p)->fd);
 if (fd >= 0) g_fd_close(fd); }

// Heap-allocate a stream port for the given OS fd. Pushes the port pointer
// on Sp[0] and registers io_close as its finalizer. The fd >= 0 path of
// the dispatcher routes through g_fd_port_vt, so the host's read/write
// methods see this port like any other.
struct g *g_io_alloc(struct g *f, int fd) {
 uintptr_t const n = Width(struct g_io);
 if (g_ok(f = g_have(f, n + Width(struct g_tag) + Width(struct g_fz) + 1))) {
  union u *k = bump(f, n + Width(struct g_tag));
  struct g_io *io = (struct g_io*) k;
  io->ap = g_vm_port_io;
  io->fd = putnum(fd);
  io->ungetc_buf = putnum(EOF);
  io->eof_seen = putnum(false);
  *--f->sp = (word) tagthd(k, n);            // stack slot reserved by the +1 in have()
  struct g_fz *z = bump(f, Width(struct g_fz));
  z->p = k, z->fn = io_close, z->next = f->fz, f->fz = z; }
 return f; }

static struct g *grbufg(struct g *f, uintptr_t len);

// A token is a plain decimal integer iff it is [+-]?[0-9]+ with no leading-zero
// prefix (so "0x.." hex and "0.." octal stay with strtol, and bare "0" parses
// as decimal). These read at full precision through g_big_read_dec.
static g_inline bool is_dec_int(char const *s, uintptr_t n) {
 uintptr_t i = (n && (s[0] == '-' || s[0] == '+')) ? 1 : 0;
 if (i >= n) return false;                       // a lone sign is a symbol
 if (s[i] == '0' && n - i > 1) return false;     // leading zero -> let strtol decide
 for (; i < n; i++) if (s[i] < '0' || s[i] > '9') return false;
 return true; }

static struct g *gz_parse(struct g *f, bool multi);
static g_inline struct g *gzread1sym(struct g*f, int c), *gzread1str(struct g*f);
struct g *g_reads(struct g *f, struct g_io* i) { return g_core_of(f)->io = i, gz_parse(f, true); }
struct g *g_read1(struct g*f, struct g_io *i) { return g_core_of(f)->io = i, gz_parse(f, false); }

static struct g *grbufg(struct g *f, uintptr_t len) {
 if (g_ok(f = str0(f, 2 * len)))
  memcpy(txt(f->sp[0]), txt(f->sp[1]), len),
  f->sp[1] = f->sp[0],
  f->sp++;
 return f; }

static g_noinline double strtod_wrap(struct g*f, word x) {
 struct g_str *s = str(x);
 if (!strp(x) || !s->len) return NAN;
 char *e, *b = off_pool(f);
 memcpy(b, s->bytes, s->len);
 b[s->len] = 0;
 double r = strtod(b, &e);
 return e != b && *e == 0 ? (g_flo_t) r : (g_flo_t) NAN; }

// (flo s) — parse a gwen string as a decimal float. Returns a rank-0
// f64 box if the entire string parses, else nil. Used by the gwen-side
// reader in repl.g to match the C reader's strtol → strtod → intern
// cascade on float-shaped tokens.
g_vm(g_vm_flo) {
 word x = Sp[0];
 double d = strtod_wrap(f, x);
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
 uintptr_t depth = topof(f) - Sp;
 Pack(f);
 if (g_ok(f = g_read1(f, i))) f->sp[2] = f->sp[0], f->sp += 2;
 else {
  struct g *c = g_core_of(f); // reset stack on parse fail
  c->sp = (word*) c + c->len - depth;
  switch (g_code_of(f)) {
   default: return gtrap(f);
   case g_status_more: c->sp[1] = c->sp[0];
   case g_status_eof: f = c, f->sp++; } }
 return Unpack(f), Continue(); }

// (string x): a charlist -> the string of those bytes; a named symbol -> its
// name string; a fixnum -> the one-byte string of its low byte. Identity on any
// other type (strings, anonymous syms, nil, ...).
g_vm(g_vm_string) {
 word x = Sp[0];
 if (x == nil) return Ip++, Continue();             // nil is the empty string (0)
 if (nump(x)) {                                     // fixnum -> one-byte string
  uintptr_t req = str_type_width + b2w(1);
  Have(req);
  struct g_str *s = (void*) Hp;
  Hp += req;
  ini_str(s, 1);
  txt(s)[0] = (char) getnum(x);
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
  for (uintptr_t i = 0; n--; x = B(x)) txt(s)[i++] = (char) getnum(A(x));
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
static struct g* g_z_getc(struct g*f) {
 while (g_ok(f = zgetc(f))) switch (f->b) {
  default: return f;
  case '\n': case '\r': continue;
  case 0: case ' ': case '\t': case '\f': continue;
  case '#':                                          // #! is a line comment; bare # is significant (len macro)
   if (!g_ok(f = zgetc(f))) return f;
   if (f->b != '!') {                                // not a shebang: push back, return #
    if ((int) f->b != EOF && !g_ok(f = zungetc(f, f->b))) return f;
    return f->b = '#', f; }
   while (g_ok(f = zeof(f)) && !f->b && g_ok(f = zgetc(f)) && f->b != '\n' && f->b != '\r');
   continue;
  case ';':                                          // line comment: run to end of line
   while (g_ok(f = zeof(f)) && !f->b && g_ok(f = zgetc(f)) && f->b != '\n' && f->b != '\r');
   continue; }
 return f; }

// --- one non-recursive reader for both g_read1 (multi=0) and g_reads (multi=1) ---
// `ctx` (kept at sp[0]) is an explicit stack of frames, top = car, so the nesting
// that used to recurse in C now lives on the gwen heap (and rides GC). A frame is
// either a *list accumulator* — a pair (head . tail) holding the elements read so
// far in source order, ((nil . nil) when empty), built in place by appending at
// `tail` so no reverse pass is needed — or a *reader-macro* — the wrap symbol \ qq
// uq uqs, recognised by symp. A finished datum is `delivered` to the top frame:
// appended to a list, or wrapped and re-delivered; with no frame left it is the
// result. Everything lives on the gwen stack so GC relocates it across the allocs
// that reading does.

static g_inline struct g *push_frame(struct g *f) {     // push an empty (head . tail) accumulator
 return gxl(gxl(g_push(f, 2, nil, nil))); }    // ctx' = ((nil . nil) . ctx)
static g_inline struct g *push_wrap(struct g *f, char const *nom) {
 return gxl(intern(g_strof(f, nom))); }        // ctx' = (wrapsym . ctx)
// recognise the splicing reader-macro wraps -- `%` (interned `hasht`) and `@`
// (interned `tuple`) -- so a list operand splices into the constructor call
// instead of being wrapped: see the deliver loop in gz_parse.
static g_inline bool symeq(word x, char const *nm, uintptr_t n) {
 struct g_str *s = symp(x) ? sym(x)->nom : 0;
 if (!s || !strp(word(s)) || s->len != n) return false;
 for (uintptr_t i = 0; i < n; i++) if (s->bytes[i] != nm[i]) return false;
 return true; }
static g_inline bool hashsym(word x) { return symeq(x, "hasht", 5); }
static g_inline bool splicesym(word x) { return hashsym(x) || symeq(x, "tuple", 5); }

static struct g *gz_parse(struct g *f, bool multi) {
 // multi: ctx starts with one open accumulator (collects all top-level datums in
 // source order); read1: ctx starts empty (returns the first complete datum).
 f = multi ? gxl(gxl(g_push(f, 3, nil, nil, nil))) : g_push(f, 1, nil);
 for (;;) {
  if (!g_ok(f = g_z_getc(f))) return f;
  int c = f->b, c2 = EOF;
  switch (c) {
   case '(':  f = push_frame(f); continue;
   case '\'': f = push_wrap(f, "\\"); continue;
   case '`':  f = push_wrap(f, "qq"); continue;
   case '%':  f = push_wrap(f, "hasht"); continue;     // %(k v …)->(hasht k v …), %x->(hasht x)
   case '#':  f = push_wrap(f, "len"); continue;       // #x->(len x): wrap operand in len
   case '@':  f = push_wrap(f, "tuple"); continue;       // @(e …)->(tuple e …) [array], @()->(tuple)
   case '$':  f = push_wrap(f, "gsym"); continue;      // $x->(gsym x)->(gensym 'x): a fresh gensym
   case ',':                                            // unquote / unquote-splice
    if (!g_ok(f = zgetc(f))) return f;
    if ((c2 = f->b) == '@') { f = push_wrap(f, "uqs"); continue; }
    if (c2 != EOF) f = zungetc(f, c2);
    f = push_wrap(f, "uq"); continue;
   case ')':
    if (nilp(f->sp[0])) return encode(g_core_of(f), g_status_eof);   // stray ) / read1
    if (symp(A(f->sp[0]))) return encode(g_core_of(f), g_status_more); // wrap wants an operand
    f = g_push(f, 1, AA(f->sp[0]));                    // d = head of the closed frame
    if (g_ok(f)) f->sp[1] = B(f->sp[1]);               // pop the closed frame
    break;                                             // -> deliver d
   case EOF:
    if (nilp(f->sp[0])) return encode(g_core_of(f), g_status_eof);
    if (!(multi && nilp(B(f->sp[0])) && !symp(A(f->sp[0]))))
     return encode(g_core_of(f), g_status_more);       // unclosed list / pending wrap
    f = g_push(f, 1, AA(f->sp[0]));                    // close the top accumulator -> its head
    if (g_ok(f)) f->sp[1] = B(f->sp[1]);
    break;
   case '"': f = gzread1str(f); break;
   default:  f = gzread1sym(f, c); break; }
  if (!g_ok(f)) return f;
  // deliver the datum at sp[0] into the frame stack at sp[1]
  for (bool done = false; g_ok(f) && !done; ) {
   if (nilp(f->sp[1])) {                               // no frame left: the result
    f->sp[1] = f->sp[0], f->sp++;
    return f; }
   if (symp(A(f->sp[1]))) {                            // reader-macro wrap, pop the wrap frame
    if (hashsym(A(f->sp[1])) && nilp(f->sp[0])) {      // %() -> (hashn 0): a fresh empty hash
     f = gxr(g_push(f, 1, nil));                       // d (=nil=0) -> (0 . nil) = (0)
     f = gxl(intern(g_strof(f, "hashn")));             // (hashn . (0)) = (hashn 0)
     if (g_ok(f)) f->sp[1] = B(f->sp[1]); }            // pop wrap
    else if (splicesym(A(f->sp[1])) && (twop(f->sp[0]) || nilp(f->sp[0]))) {
     f = gxl(g_push(f, 1, A(f->sp[1])));               // %(k v …)/@(e …)/@() : splice -> (sym . d)
     if (g_ok(f)) f->sp[1] = B(f->sp[1]); }
    else {                                             // 'x `x ,x  #x %atom/@atom -> (wrapsym d)
     f = gxr(g_push(f, 1, nil));                       // (d . nil)
     f = gxl(g_push(f, 1, g_ok(f) ? A(f->sp[1]) : nil)); // (wrapsym . (d))
     if (g_ok(f)) f->sp[1] = B(f->sp[1]); } }
   else {                                              // list: append d at the frame's tail
    f = gxr(g_push(f, 1, nil));                        // newcons = (d . nil)
    if (g_ok(f)) {
     word frame = A(f->sp[1]);                         // (head . tail)
     if (nilp(A(frame))) A(frame) = B(frame) = f->sp[0];  // first element: head = tail = newcons
     else B(B(frame)) = f->sp[0], B(frame) = f->sp[0];    // link onto tail, advance tail
     f->sp++; }                                        // pop newcons -> ctx
    done = true; } }
  if (!g_ok(f)) return f; } }

static g_inline struct g *gzread1str(struct g*f) {
 int c;
 size_t n = 0, lim = sizeof(word);
 for (f = str0(f, lim); g_ok(f); f = grbufg(f, lim), lim *= 2)
  for (; n < lim; txt(f->sp[0])[n++] = c) {
   if (!g_ok(f = zgetc(f))) return f;     // threaded; char in f->b
   else if ((c = f->b) == '"')                  // close quote; "" -> the empty
    return n ? (len(f->sp[0]) = n, f)            // (truthy) singleton, never allocated
             : (f->sp[0] = EMPTY_STR, f);
   else if (c == EOF) return encode(f, g_status_more);
   else if (c == '\\') {                               // escape: take next char
    if (!g_ok(f = zgetc(f))) return f;
    else if ((c = f->b) == EOF) return encode(f, g_status_more);
    else if (c == 'n') c = '\n';
    else if (c == 't') c = '\t';
    else if (c == 'r') c = '\r';
    else if (c == '0') c = '\0';
    else if (c == 'x') {                          // \xHH: two hex digits
     if (!g_ok(f = zgetc(f))) return f;
     int h1 = f->b;
     if (h1 == EOF) return encode(f, g_status_more);
     if (!g_ok(f = zgetc(f))) return f;
     int h2 = f->b;
     if (h2 == EOF) return encode(f, g_status_more);
     int v1 = h1 <= '9' ? h1 - '0' : (h1 | 0x20) - 'a' + 10;
     int v2 = h2 <= '9' ? h2 - '0' : (h2 | 0x20) - 'a' + 10;
     c = ((v1 & 0xf) << 4) | (v2 & 0xf); } } }
 return f; }



static g_inline struct g *gzread1sym(struct g*f, int c) {
 uintptr_t n = 1, lim = sizeof(intptr_t);
 if (g_ok(f = str0(f, sizeof(word))))
  for (txt((struct g_str*) f->sp[0])[0] = c; g_ok(f); f = grbufg(f, lim), lim *= 2)
   for (; n < lim; txt(f->sp[0])[n++] = c) {
    if (!g_ok(f = zgetc(f))) return f;
    switch (c = f->b) {
     default: continue;
     case ' ': case '\n': case '\t': case '\r': case '\f': case ';': case '#':
     case '(': case ')': case '"': case '\'': case '`': case ',': case 0 : case EOF:
      if (!g_ok(f = zungetc(f, c))) return f;
      struct g_str *s = str(f->sp[0]);
      txt(s)[len(s) = n] = 0; // zero terminate for strtol ; n < lim so this is safe
      // A plain decimal integer reads at full precision (fixnum / box / bignum);
      // hex/octal/float/symbol tokens keep the strtol -> strtod -> intern path.
      if (is_dec_int(txt(s), n)) return g_big_read_dec(f);
      char *e;
      long j = strtol(txt(s), &e, 0);
      if (*e == 0) {
       if (j >= FIX_MIN && j <= FIX_MAX) return f->sp[0] = putnum(j), f;
       if (g_ok(f = g_have(f, BOX_REQ))) {
        struct g_tuple *b = ini_scalar(bump(f, BOX_REQ), g_Z);
        box_put(b->shape, j);
        f->sp[0] = word(b); }
       return f; }
      double d = strtod(txt(s), &e);
      if (e == txt(s) || *e != 0) return intern(f);
      uintptr_t req = b2w(sizeof(struct g_tuple) + sizeof(g_flo_t));
      if (g_ok(f = g_have(f, req))) {
       struct g_tuple *r = ini_scalar(bump(f, req), g_R);
       flo_put(r->shape, d);
       f->sp[0] = word(r); }
      return f; } }
 return f; }

// ============================================================================
// sys
// ============================================================================
op11(g_vm_clock, putnum(g_clock() - getnum(Sp[0])))

g_vm(g_vm_info) {
 size_t const req = 7 * Width(struct g_pair);
 Have(req);
 struct g_pair *si = (struct g_pair*) Hp;
 Hp += req;
 Sp[0] = word(si);
 ini_two(si + 0, putnum(f), word(si + 1));
 ini_two(si + 1, putnum(f->len), word(si + 2));
 ini_two(si + 2, putnum(Hp - ptr(f)), word(si + 3));
 ini_two(si + 3, putnum(ptr(f) + f->len - Sp), word(si + 4));
 ini_two(si + 4, putnum(f->n_gc), word(si + 5));               // gc cycles
 ini_two(si + 5, putnum(f->max_len), word(si + 6));            // peak pool len (words)
 ini_two(si + 6, putnum(f->max_heap), nil);                    // peak live heap (words)
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
 Sp[0] = (getnum(g_stdin.ungetc_buf) != EOF || g_ready(getnum(g_stdin.fd))) ? putnum(1) : nil;
 Ip += 1;
 return Continue(); }

// ============================================================================
// map (lookup-lambda backed by an open-addressed thread; see mapp comment)
// ============================================================================
// backing is internal -- only ever reached from a header[1], never applied as a
// gwen value; its ap behaves-as-1 like g_vm_buf should it ever be (it won't).
static g_vm(g_vm_map_data) {
 return Ip = cell(*++Sp), *Sp = putnum(1), Continue(); }

// the backing slot of k, or -- if absent -- the first empty slot on its probe
// chain. load is kept < 3/4 so an empty slot always terminates the scan.
static g_inline uintptr_t map_probe(struct g *f, word m, word k, bool *found) {
 uintptr_t mask = map_cap(m) - 1, i = hash(f, k) & mask;
 word *s = map_slots(m);
 for (;; i = (i + 1) & mask) {
  word sk = s[2 * i];
  if (sk == MAP_GAP) return *found = false, i;
  if (eql(f, k, sk)) return *found = true, i; } }

word g_mapget(struct g *f, word zero, word k, word m) {
 bool found; uintptr_t i = map_probe(f, m, k, &found);
 return found ? map_slots(m)[2 * i + 1] : zero; }

// fill an empty cap-slot backing at b (cap a power of two); caller reserves it.
static g_inline union u *map_fill_back(union u *b, uintptr_t cap) {
 b[0].ap = g_vm_map_data, b[1].x = putnum(0), b[2].x = putnum(cap);
 for (uintptr_t i = 0; i < cap; i++) b[3 + 2 * i].x = MAP_GAP, b[4 + 2 * i].x = nil;
 return tagthd(b, 3 + 2 * cap); }

// double the backing of the map at sp[2] and rehash into it, then swap it into
// header[1]; the header never moves, so aliased references stay valid. The
// rehash inserts distinct keys into a backing with room to spare, so it never
// allocates and the fresh backing can't move under it.
static g_noinline struct g *map_grow(struct g *f) {
 uintptr_t ncap = 2 * map_cap(f->sp[2]);
 if (!g_ok(f = g_have(f, 4 + 2 * ncap))) return f;
 word m = f->sp[2];                                 // re-fetch header after GC
 union u *nb = map_fill_back((union u*) f->hp, ncap);
 f->hp += 4 + 2 * ncap;
 word *os = map_slots(m), *ns = &nb[3].x;
 uintptr_t ocap = map_cap(m), nlen = 0, nmask = ncap - 1;
 for (uintptr_t j = 0; j < ocap; j++) {
  word k = os[2 * j];
  if (k == MAP_GAP) continue;
  uintptr_t i = hash(f, k) & nmask;
  while (ns[2 * i] != MAP_GAP) i = (i + 1) & nmask;
  ns[2 * i] = k, ns[2 * i + 1] = os[2 * j + 1], nlen++; }
 nb[1].x = putnum(nlen);
 return cell(m)[1].x = (word) nb, f; }            // swap backing; header identity stable

// (put k v map): mutate in place; grow (may GC) on a new key past the load
// factor, re-reading k/v from the stack afterwards. Leaves the map at sp[2].
static g_noinline struct g *g_mapput(struct g *f) {
 if (!g_ok(f)) return f;
 bool found; uintptr_t i = map_probe(f, f->sp[2], f->sp[0], &found);
 if (found) return map_slots(f->sp[2])[2 * i + 1] = f->sp[1], f->sp += 2, f;
 if ((map_len(f->sp[2]) + 1) * 4 >= map_cap(f->sp[2]) * 3) {
  if (!g_ok(f = map_grow(f))) return f;
  i = map_probe(f, f->sp[2], f->sp[0], &found); }   // re-probe larger backing
 word *s = map_slots(f->sp[2]);
 s[2 * i] = f->sp[0], s[2 * i + 1] = f->sp[1];
 cell(map_back(f->sp[2]))[1].x = putnum(map_len(f->sp[2]) + 1);
 return f->sp += 2, f; }

// (hashd k v map): delete k, backward-shift the probe chain so no tombstone is
// needed; v is the not-found result. No allocation. Leaves the map at sp[2].
static g_noinline word g_mapdel(struct g *f, word m, word k, word zero) {
 bool found; uintptr_t i = map_probe(f, m, k, &found);
 if (!found) return zero;
 word *s = map_slots(m); uintptr_t mask = map_cap(m) - 1;
 for (uintptr_t j = i;;) {
  j = (j + 1) & mask;
  if (s[2 * j] == MAP_GAP) break;
  uintptr_t h = hash(f, s[2 * j]) & mask;            // ideal slot of the probed key
  bool gap = i <= j ? (h <= i || h > j) : (h <= i && h > j);   // h not in (i, j]
  if (gap) s[2 * i] = s[2 * j], s[2 * i + 1] = s[2 * j + 1], i = j; }
 s[2 * i] = MAP_GAP, s[2 * i + 1] = nil;
 cell(map_back(m))[1].x = putnum(map_len(m) - 1);
 return m; }

// C-callable fresh empty map, pushed on sp[0]. Same shape as g_vm_hnew.
static struct g *map_new(struct g *f) {
 uintptr_t cap = MAP_MIN_CAP, nb = 4 + 2 * cap;
 if (!g_ok(f = g_have(f, nb + 3))) return f;
 union u *b = map_fill_back((union u*) f->hp, cap), *h = (union u*) (f->hp + nb);
 h[0].ap = g_vm_map_lookup, h[1].x = (word) b, tagthd(h, 2);
 f->hp += nb + 3;
 return g_push(f, 1, (word) h); }

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
 word v = g_mapget(f, nil, Sp[0], (word) Ip);
 return Ip = cell(*++Sp), *Sp = v, Continue(); }

op11(g_vm_hashp, mapp(Sp[0]) ? putnum(1) : nil)

// (hash x) -- the general hashing method exposed to gwen as a fixnum.
op11(g_vm_hashof, putnum(hash(f, Sp[0])))

g_vm(g_vm_get) {
 word z = Sp[0], k = Sp[1], x = Sp[2], n;
 if (bufp(x)) {                                  // mutable byte string: byte index
  struct g_str *s = buf_str(x);
  if (nump(k) && (n = getnum(k)) >= 0 && n < (word) len(s))
   z = putnum((unsigned char) txt(s)[n]); }
 else if (mapp(x)) z = g_mapget(f, z, k, x);     // map lookup (not a data sentinel)
 else if (lamp(x) && datp(x)) switch (typ(x)) {
  default: break;                               // K_SYM is not indexable
  case K_TUPLE: {
   // Array index: a fixnum for a rank-1 array, or a shape-list (row-major) for
   // rank-N; an empty/nil key derefs a rank-0 scalar box. Out-of-bounds or a
   // wrong-rank key falls through to the default `z`. Integer elements keep
   // integer type (EMIT_INT demotes-or-boxes); float elements box an f64.
   struct g_tuple *v = tuple(x);
   uintptr_t R = v->rank, off = 0; bool ok = false;
   if (R == 0) ok = nilp(k);
   else if (R == 1 && nump(k)) {
    intptr_t ix = getnum(k);
    if (ix >= 0 && ix < (intptr_t) v->shape[0]) off = ix, ok = true; }
   else if (twop(k)) {
    uintptr_t a = 0; ok = true;
    for (word l = k;; l = B(l)) {
     if (!twop(l)) { ok = a == R; break; }
     word ki = A(l);
     if (a >= R || !nump(ki)) { ok = false; break; }
     intptr_t ix = getnum(ki);
     if (ix < 0 || ix >= (intptr_t) v->shape[a]) { ok = false; break; }
     off = off * v->shape[a] + ix, a++; } }
   if (ok && v->type == g_O) z = tuple_get_obj(v, off);   // object: the slot IS the value
   else if (ok) { word _res; Have(BOX_REQ); v = tuple(Sp[2]);
    if (v->type >= g_R) EMIT_FLO(tuple_get_flo(v, off));
    else EMIT_INT(tuple_get_int(v, off));
    z = _res; }
   break; }
  case K_STRING:
   // Byte as its unsigned value 0..255 -- bytes are data, signedness is the
   // operator's job. txt is signed char[], so cast to avoid sign-extending a
   // high byte (e.g. 0xff -> -1) when binary data is indexed.
   if (nump(k) && (n = getnum(k)) >= 0 && n < (word) len(x))
    z = putnum((unsigned char) txt(x)[n]);
   break;
  case K_TWO:
   if (nump(k) && (n = getnum(k)) >= 0) {
    while (n-- && twop(x = B(x)));
    if (twop(x)) z = A(x); } }
 return Sp[2] = z, Sp += 2, Ip += 1, Continue(); }

// (put key val coll): map insert, or -- when coll is a buf -- store the
// byte val at index key. Both leave coll on the stack as the result. A buf
// store needs no allocation, so no GC dance; out-of-range/non-numeric is a
// silent no-op, matching the misuse convention of the other byte ops.
g_vm(g_vm_put) {
 word x = Sp[2], n;
 if (mapp(x)) {
  Pack(f);
  if (!g_ok(f = g_mapput(f))) return gtrap(f);
  Unpack(f); }
 else {
  if (bufp(x) && nump(Sp[0]) && (n = getnum(Sp[0])) >= 0 && n < (word) len(buf_str(x)))
   txt(buf_str(x))[n] = (char) getnum(Sp[1]);
  Sp += 2; }
 return Ip += 1, Continue(); }

g_vm(g_vm_hashd) {
 if (mapp(Sp[1])) Sp[2] = g_mapdel(f, Sp[1], Sp[2], Sp[0]);
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

static g_noinline uintptr_t hash_two(struct g *f, word x) {
 word *base = off_pool(f), *top = base + f->len, *w = base;
 for (uintptr_t h = mix;; x = *--w) {
  while (twop(x)) {
   if (w == top) __builtin_trap();       // worklist overflow: a cycle
   h = (h ^ mix) * mix;                  // mark a pair node
   *w++ = A(x), x = B(x); }
  h = (h ^ hash(f, x)) * mix;          // x is a leaf: hash won't recur
  if (w == base) return h; } }

// general hashing method...
uintptr_t hash(struct g *f, intptr_t x) {
 if (nump(x)) return rot(x*mix);
 if (!datp(x)) {
   // out-of-pool (static bif): stable distinct address. in-pool: a compiled lambda
   // parks its source \-expr one cell before the entry (the tag head points there),
   // a better key than length; else by length. All GC-stable (buckets survive copy).
   if ((word*) x < ptr(f) || (word*) x >= topof(f)) return rot(x * mix);
   union u *k = cell(x); struct g_tag *tg = ttag(f, k);
   if (tag_head(tg) < k) return hash(f, k[-1].x);
   uintptr_t r = mix;
   for (union u *y = k; y < (union u*) tg; y++) r ^= r * mix;
   return r; }
 switch (typ(x)) {
   default: __builtin_trap();
   case K_TWO: return hash_two(f, x);
   case K_SYM: return sym(x)->code;
   case K_TUPLE: {
    uintptr_t len = g_tuple_bytes(tuple(x)), h = mix;
    for (uint8_t const *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return h; }
   case K_BIG: {
    uintptr_t len = g_big_bytes((struct g_big*) x), h = mix;
    for (uint8_t const *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return h; }
   case K_STRING: {
    uintptr_t n = len(x), h = mix;
    char const *bs = txt(x);
    while (n--) h ^= (uint8_t) *bs++, h *= mix;
    return h; } } }

// ============================================================================
// str
// ============================================================================
struct g *str0(struct g *f, uintptr_t len) {
 if (!len) { if (g_ok(f = g_have(f, 1))) *--f->sp = EMPTY_STR; return f; } // never alloc empty
 uintptr_t req = str_type_width + b2w(len);
 if (g_ok(f = g_have(f, req + 1)))
  *--f->sp = word(ini_str(bump(f, req), len));
 return f; }

struct g *g_strof(struct g *f, char const *cs) {
 uintptr_t len = strlen(cs);
 if (g_ok(f = str0(f, len))) memcpy(txt(f->sp[0]), cs, len);
 return f; }

op11(g_vm_strp, strp(Sp[0]) ? putnum(1) : nil)
g_vm(g_vm_ssub) {
 if (!strp(Sp[0])) Sp[2] = nil;
 else {
  struct g_str *s = str(Sp[0]), *t;
  intptr_t i = oddp(Sp[1]) ? getnum(Sp[1]) : 0,
           j = oddp(Sp[2]) ? getnum(Sp[2]) : 0;
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
 else if (!(len(str(a)) + len(str(b)))) *++Sp = EMPTY_STR;   // both empty -> singleton
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
 return Ip = cell(*++Sp), *Sp = putnum(1), Continue(); }

// (bufnew n) — allocate a zeroed n-byte mutable buf (n<0 / non-numeric -> 0).
// Two heap objects under one Have (so no GC sees a half-built buf): the
// backing g_str holding the bytes, and the length-2 wrapper thread
// [g_vm_buf, str, terminator] that gives it its identity.
g_vm(g_vm_bufnew) {
 intptr_t n = nump(Sp[0]) ? getnum(Sp[0]) : 0;
 if (n < 0) n = 0;
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
  intptr_t doff = getnum(Sp[1]), soff = getnum(Sp[3]), n = getnum(Sp[4]),
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
  if (!len(str(Sp[0]))) return Sp[0] = EMPTY_SYM, Ip += 1, Continue();
  struct g_atom *y;
  Have(Width(struct g_atom));
  Pack(f), y = intern_checked(f, (struct g_str*) f->sp[0]), Unpack(f);
  Sp[0] = word(y); }
 return Ip += 1, Continue(); }

// (gensym name) -> a fresh *uninterned* symbol named after `name`: a string (the
// symbol it would intern to) or a symbol (used directly). The new symbol stores
// that naming SYMBOL as its nom, which marks it uninterned (interned syms have a
// string nom; see ini_usym). Any other arg yields an anonymous gensym (nom 0).
g_vm(g_vm_gensym) {
 if (strp(Sp[0]) && !len(str(Sp[0]))) return Sp[0] = EMPTY_SYM, Ip += 1, Continue(); // ""->the empty sym
 Have(2 * Width(struct g_atom));               // room for the wrapper + a fresh intern
 struct g_atom *nom;
 if (strp(Sp[0]))                              // (sym "x"): intern "x" -> the symbol it names
   Pack(f), nom = intern_checked(f, (struct g_str*) f->sp[0]), Unpack(f);
 else nom = symp(Sp[0]) ? sym(Sp[0]) : 0;      // symbol arg used as-is; else anonymous
 struct g_atom *y = (struct g_atom*) Hp;
 Hp += Width(struct g_atom) - 2;               // uninterned/anonymous: no l/r subtree slots
 nom ? ini_usym(y, nom, g_clock()) : ini_anon(y, g_clock());
 return
  Sp[0] = word(y),
  Ip += 1,
  Continue(); }

struct g *intern(struct g*f) {
 if (g_ok(f = g_have(f, Width(struct g_atom))))
  f->sp[0] = (word) intern_checked(f, (struct g_str*) f->sp[0]);
 return f; }

// avail must be >= Width(struct g_atom) when this is called.
g_noinline struct g_atom *intern_checked(struct g *v, struct g_str *b) {
 uintptr_t h = rot(hash(v, word(b)));
 for (struct g_atom **y = &v->symbols, *z;;) {
  if (!(z = *y)) return *y = ini_sym(bump(v, Width(struct g_atom)), b, h);
  struct g_str *a = z->nom;
  intptr_t i = z->code < h ? -1 : z->code > h ? 1 : 0;
  if (i == 0) i = len(a) - len(b);
  if (i == 0) i = memcmp(txt(a), txt(b), len(b));
  if (i == 0) return z;
  y = i < 0 ? &z->l : &z->r; } }

op11(g_vm_symp, symp(Sp[0]) ? putnum(1) : nil)
op11(g_vm_tuplep, tuplep(Sp[0]) ? putnum(1) : nil)
op11(g_vm_bigp, bigp(Sp[0]) ? putnum(1) : nil)
op11(g_vm_boxp, boxp(Sp[0]) ? putnum(1) : nil)
op11(g_vm_arrp, arrp(Sp[0]) ? putnum(1) : nil)
// (int x): truncate a float scalar to a fixnum; other numbers pass through. Used by
// num-ap to get an integer composition count from a non-integer numeral operator.
op11(g_vm_intf, flop(Sp[0]) ? putnum((intptr_t) flo_get(Sp[0])) : Sp[0])

// ============================================================================
// pair
// ============================================================================
op11(g_vm_car, twop(Sp[0]) ? A(Sp[0]) : Sp[0])
op11(g_vm_cdr, twop(Sp[0]) ? B(Sp[0]) : nil)
op11(g_vm_twop, twop(Sp[0]) ? putnum(1) : nil)
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
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, f, vop); \
 if (cplxp(a) || cplxp(b)) return Ap(g_vm_cplx_bin, f, vop); \
 if (!ISNUM(a) || !ISNUM(b)) return *++Sp = nil, Ip++, Continue(); \
 if (flop(a) || flop(b)) { word _res; Have(BOX_REQ); \
  g_flo_t ad = TOFLO(a), bd = TOFLO(b); \
  struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_R); \
  Hp += BOX_REQ; flo_put(v->shape, (fexpr)); _res = word(v); \
  return *++Sp = _res, Ip++, Continue(); } \
 if (!bigp(a) && !bigp(b)) { intptr_t av = TOINT(a), bv = TOINT(b), t; \
  if (!ovf(av, bv, &t)) { word _res; Have(BOX_REQ); EMIT_INT(t); \
   return *++Sp = _res, Ip++, Continue(); } } \
 Pack(f); f = g_big_binop(f, vop); \
 if (!g_ok(f)) return gtrap(f); \
 return Unpack(f), Continue(); }
#define AVM_SLOWDIV(op, vop, c_op, fexpr) static g_vm(g_vm_##op##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, f, vop); \
 if (cplxp(a) || cplxp(b)) return Ap(g_vm_cplx_bin, f, vop); \
 if (!ISNUM(a) || !ISNUM(b)) return *++Sp = nil, Ip++, Continue(); \
 if (flop(a) || flop(b) || b == nil) { word _res; Have(BOX_REQ); \
  g_flo_t ad = TOFLO(a), bd = TOFLO(b); \
  struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_R); \
  Hp += BOX_REQ; flo_put(v->shape, (fexpr)); _res = word(v); \
  return *++Sp = _res, Ip++, Continue(); } \
 if (!bigp(a) && !bigp(b)) { intptr_t av = TOINT(a), bv = TOINT(b); \
  if (!(av == INTPTR_MIN && bv == -1)) { word _res; Have(BOX_REQ); EMIT_INT(av c_op bv); \
   return *++Sp = _res, Ip++, Continue(); } } \
 Pack(f); f = g_big_binop(f, vop); \
 if (!g_ok(f)) return gtrap(f); \
 return Unpack(f), Continue(); }
#define AVM_OVF(op, builtin) g_vm(g_vm_##op) { \
 word a = Sp[0], b = Sp[1]; \
 if (nump(a) && nump(b)) { intptr_t t; \
  if (!builtin((intptr_t) getnum(a), (intptr_t) getnum(b), &t) && \
      t >= FIX_MIN && t <= FIX_MAX) \
   return *++Sp = putnum(t), Ip++, Continue(); } \
 return Ap(g_vm_##op##n, f); }
#define AVM_DIV(op, c_op) g_vm(g_vm_##op) { \
 word a = Sp[0], b = Sp[1]; \
 if (nump(a) && nump(b)) { \
  intptr_t av = getnum(a), bv = getnum(b); \
  if (bv != 0 && !(av == INTPTR_MIN && bv == -1)) { \
   intptr_t t = av c_op bv; \
   if (t >= FIX_MIN && t <= FIX_MAX) \
    return *++Sp = putnum(t), Ip++, Continue(); } } \
 return Ap(g_vm_##op##n, f); }
#define CMP_SLOW(nom, vop, c_op) static g_vm(nom##_slow) {                   \
 word a = Sp[0], b = Sp[1], x = nil;                                   \
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, f, vop);                 \
 if (ISNUM(a) && ISNUM(b))                                             \
  x = ((flop(a) || flop(b)) ? (TOFLO(a) c_op TOFLO(b))                 \
     : (bigp(a) || bigp(b)) ? (g_big_cmp(a, b) c_op 0)                 \
                            : (TOINT(a) c_op TOINT(b))) ? putnum(1) : nil; \
 return *++Sp = x, Ip++, Continue(); }
#define CMP_OP(nom, vop, c_op) CMP_SLOW(nom, vop, c_op) g_vm(nom) {    \
 word a = Sp[0], b = Sp[1];                                           \
 if (__builtin_expect(nump(a) && nump(b), 1))                         \
  return *++Sp = (a c_op b) ? putnum(1) : nil, Ip++, Continue();     \
 return Ap(nom##_slow, f); }
#define BIT_SLOW(n, c_op) static g_vm(g_vm_##n##_slow) {               \
 word a = Sp[0], b = Sp[1], _res;                                     \
 if (!(nump(a) || boxp(a)) || !(nump(b) || boxp(b)))                  \
  return *++Sp = nil, Ip++, Continue();                               \
 Have(BOX_REQ);                                                       \
 EMIT_INT(TOINT(a) c_op TOINT(b));                                    \
 return *++Sp = _res, Ip++, Continue(); }
#define mvm1(n) g_vm(g_vm_##n) { return Ap(g_vm_math1, f, g_##n); }
#define mvm2(n) g_vm(g_vm_##n) { return Ap(g_vm_math2, f, g_##n); }
#define m1(_) _(sin) _(cos) _(tan) _(atan) _(sqrt) _(exp) _(log)
#define m2(_) _(atan2)   // pow is hand-written (g_vm_pow, cplx section): it adds a complex lane


AVM_SLOW(add, VOP_ADD, __builtin_add_overflow, ad + bd)
AVM_SLOW(sub, VOP_SUB, __builtin_sub_overflow, ad - bd)
AVM_SLOW(mul, VOP_MUL, __builtin_mul_overflow, ad * bd)

AVM_SLOWDIV(quot, VOP_QUOT, /, ad / bd)         // ±inf or NaN on bd == 0
AVM_SLOWDIV(rem, VOP_REM, %, g_fmod(ad, bd))    // NaN on bd == 0

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
static bool g_add_lr = true;
// coerce a numeric to a string byte: floor(|x|) mod 256, where |x| of a complex
// is its modulus (matching abs's L2 vector->scalar coercion, see g_vm_abs).
static g_inline unsigned char seq_byte(word x) {
 g_flo_t v = cplxp(x)
  ? g_sqrt(cplx_re(x) * cplx_re(x) + cplx_im(x) * cplx_im(x)) : TOFLO(x);
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
  if (front) { Sp[0] = elt, Sp[1] = lst; return Ap(g_vm_cons, f); }  // (cons elt list)
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
// rank: string as-is / gensym'd to a fresh uninterned sym / interned. An empty
// result is the g_str_empty / g_sym_empty singleton (the additive identity).
static g_inline struct g_str *add_name(word x) {        // symbol -> name string, or 0 (anon)
 word nom = word(sym(x)->nom);
 if (!nom) return 0;
 if (strp(nom)) return str(nom);                        // interned: nom IS the name
 nom = word(sym(nom)->nom);                             // named-uninterned: naming sym's nom
 return nom && strp(nom) ? str(nom) : 0; }
static g_inline int stringrank(word x) {                  // STR 0 / USYM 1 / ISYM|NUM 2
 if (strp(x)) return 0;
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
 if (!n) return *++Sp = rank ? EMPTY_SYM : EMPTY_STR, Ip++, Continue();
 uintptr_t req = str_type_width + b2w(n);
 Have(req);
 a = Sp[0], b = Sp[1];                                  // re-read post-GC
 struct g_str *z = ini_str((struct g_str*) Hp, n); Hp += req;
 add_emit(add_emit(txt(z), a), b);                      // a's bytes then b's, in order
 *++Sp = word(z);
 return rank == 0 ? (Ip++, Continue())                  // string
      : rank == 1 ? Ap(g_vm_gensym, f)                  // uninterned symbol (fresh)
                  : Ap(g_vm_intern, f); }               // interned symbol
static g_vm(g_vm_0) {                             // unsupported mix (array <-> text)
 return *++Sp = nil, Ip++, Continue(); }

// The fundamental value kind for generic-op dispatch (enum q in gwen.h): a fixnum is
// the odd tag (K_FIX), a non-data heap pointer is a thread/function (K_LAM), else g_typ
// recovers the data kind directly (K_TUPLE..K_SYM -- it already folds in the +K_TUPLE
// slot shift). No subtype classification here; that is the handler's job. Exported (not
// inline) so data.c's apply sentinels share it.
enum q g_kind(word x) {
 return nump(x) ? K_FIX : !datp(x) ? K_LAM : typ(x); }

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
 if (!ISNUM(cnt) && !cplxp(cnt)) return *++Sp = nil, Ip++, Continue();   // array/non-number count
 g_flo_t cv = cplxp(cnt)
  ? g_sqrt(cplx_re(cnt) * cplx_re(cnt) + cplx_im(cnt) * cplx_im(cnt)) : TOFLO(cnt);
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
 if (!total) return *++Sp = rank ? EMPTY_SYM : EMPTY_STR, Ip++, Continue();
 uintptr_t req = str_type_width + b2w(total);
 Have(req);
 seq = (strp(Sp[0]) || symp(Sp[0])) ? Sp[0] : Sp[1];   // re-read post-GC
 src = strp(seq) ? str(seq) : add_name(seq);
 struct g_str *z = ini_str((struct g_str*) Hp, total); Hp += req;
 for (uintptr_t i = 0; i < n; i++) memcpy(txt(z) + i * sl, txt(src), sl);
 *++Sp = word(z);
 return rank == 0 ? (Ip++, Continue())             // string
      : rank == 1 ? Ap(g_vm_gensym, f)             // uninterned symbol
                  : Ap(g_vm_intern, f); }          // interned symbol

// --- apply lane (the data-value `(f x)` handlers; moved here from data.c) -----
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
 word k = Sp[0], v = putnum(1), n;
 if (oddp(k) && (n = getnum(k)) >= 0 && n < (word) len(Ip))
  v = putnum((unsigned char) txt(Ip)[n]);
 return Ip = cell(*++Sp), *Sp = v, Continue(); }

// (y k): applying a symbol indexes its underlying name string, so (y k) == (nom k).
// nom encodes the kind: a string is the name (interned), a symbol is the naming
// symbol of a named-uninterned sym (follow once to its string nom), 0 is an anonymous
// gensym. With no underlying string we act like 0 (absent name == "" == 0 -> 1).
static g_vm(data_sym_apply) {
 word nom = word(((struct g_atom*) Ip)->nom);
 if (nom && cell(nom)->ap == g_vm_sym)              // named-uninterned: follow to the naming symbol
  nom = word(((struct g_atom*) nom)->nom);
 if (nom && cell(nom)->ap == g_vm_str)             // interned/named: index the underlying name string
  return Ip = cell(nom), Ap(data_string_apply, f);
 return Ip = cell(*++Sp), *Sp = putnum(1), Continue(); }  // anonymous: no name -> act like 0

// (n x): applying a number is Church-numeral application, like a fixnum (cf.
// g_vm_numap). Fixnums reach num-ap via the odd-tag check in g_vm_ap; the rest of the
// tower (floats, boxes, complex, arrays -- all g_vm_tuple -- and bignums) are heap
// pointers, so they arrive at their data sentinel. We lay the same [n, num-ap, x, ret]
// frame and run numap_drive, handing the boxed operator n to the gwen num-ap handler,
// which picks exponentiate / compose / self by operand+operator kind.
static g_vm(data_num_apply) {
 Have(2);
 word n = word(Ip), x = Sp[0], ret = Sp[1], *dst = Sp - 2;
 dst[0] = n, dst[1] = g_numap, dst[2] = x, dst[3] = ret;
 return Sp = dst, Ip = numap_drive, Continue(); }

// ((a . b) f) == (f a b): a pair is its own Church eliminator (cons = \a b f.f a b).
// Re-enter the apply protocol via a static driver thread: lay the stack as the two
// curried calls expect, then [ap ; swap+ap ; ret0] runs ((f a) b). pair_swap reorders
// [result, b] -> [b, result] so the second ap sees arg=b, fn=(f a). The driver lives
// in .data, so the return addresses it leaves on the stack fall outside the GC pool.
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

// === the three generic-op dispatch matrices, adjacent ======================
// All indexed by g_kind (g_apply_mx's row by g_typ, the data-kind subrange). Lanes:
//   *n   = numeric tower & arrays (arithmetic / broadcast)
//   add_seq = a list anywhere (other operand a scalar element / spine)
//   add_string = strings & symbols name-compatibly (+ a number as one byte; demotes
//              isym>usym>str and nils an array operand internally)
//   mul_rep  = sequence * scalar-count -> repetition
//   *l   = a LAMBDA operand (precedence: the K_LAM row+col) -- Church add / compose
//   g_vm_0 = undefined (-> nil): function<->text, sequence*sequence
// K_TUPLE covers boxes/complex (numbers) AND arrays; the lane handler refines. Maps
// are lambdas (K_LAM) -- the *l lanes -- so they have no row/col of their own.

// `+`: numbers add, lists/text concat, lambdas Church-add. K_LAM row+col all addl.
static g_vm_t *const g_add_mx[K_N][K_N] = {
//            FIX            TUPLE          BIG            TWO            STRING         SYM            LAM
 [K_FIX]  = { g_vm_addn,     g_vm_addn,     g_vm_addn,     g_vm_add_seq,  g_vm_add_string, g_vm_add_string, g_vm_addl },
 [K_TUPLE]  = { g_vm_addn,     g_vm_addn,     g_vm_addn,     g_vm_add_seq,  g_vm_add_string, g_vm_add_string, g_vm_addl },
 [K_BIG]  = { g_vm_addn,     g_vm_addn,     g_vm_addn,     g_vm_add_seq,  g_vm_add_string, g_vm_add_string, g_vm_addl },
 [K_TWO]  = { g_vm_add_seq,  g_vm_add_seq,  g_vm_add_seq,  g_vm_add_seq,  g_vm_add_seq,  g_vm_add_seq,  g_vm_addl },
 [K_STRING] = { g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_seq,  g_vm_add_string, g_vm_add_string, g_vm_addl },
 [K_SYM]  = { g_vm_add_string, g_vm_add_string, g_vm_add_string, g_vm_add_seq,  g_vm_add_string, g_vm_add_string, g_vm_addl },
 [K_LAM]  = { g_vm_addl,     g_vm_addl,     g_vm_addl,     g_vm_addl,     g_vm_addl,     g_vm_addl,     g_vm_addl },
};
// `*`: the semiring product whose `+` is the lane above. numbers multiply, sequence
// * count repeats, lambdas compose (Church mul). seq*seq -> nil.
static g_vm_t *const g_mul_mx[K_N][K_N] = {
//            FIX            TUPLE          BIG            TWO            STRING         SYM            LAM
 [K_FIX]  = { g_vm_muln,     g_vm_muln,     g_vm_muln,     g_vm_mul_rep,  g_vm_mul_rep,  g_vm_mul_rep,  g_vm_mull },
 [K_TUPLE]  = { g_vm_muln,     g_vm_muln,     g_vm_muln,     g_vm_mul_rep,  g_vm_mul_rep,  g_vm_mul_rep,  g_vm_mull },
 [K_BIG]  = { g_vm_muln,     g_vm_muln,     g_vm_muln,     g_vm_mul_rep,  g_vm_mul_rep,  g_vm_mul_rep,  g_vm_mull },
 [K_TWO]  = { g_vm_mul_rep,  g_vm_mul_rep,  g_vm_mul_rep,  g_vm_0,        g_vm_0,        g_vm_0,        g_vm_mull },
 [K_STRING] = { g_vm_mul_rep,  g_vm_mul_rep,  g_vm_mul_rep,  g_vm_0,        g_vm_0,        g_vm_0,        g_vm_mull },
 [K_SYM]  = { g_vm_mul_rep,  g_vm_mul_rep,  g_vm_mul_rep,  g_vm_0,        g_vm_0,        g_vm_0,        g_vm_mull },
 [K_LAM]  = { g_vm_mull,     g_vm_mull,     g_vm_mull,     g_vm_mull,     g_vm_mull,     g_vm_mull,     g_vm_mull },
};
// apply: [applied data kind = g_typ(Ip)][argument kind = g_kind(arg)]. Every row is
// arg-kind-uniform today (AROW fills all columns); the 2-D shape is the hook for
// later argument-kind branching (e.g. a number applied to a function vs a number).
#define AROW(h) { [K_FIX]=h,[K_LAM]=h,[K_TWO]=h,[K_TUPLE]=h,[K_SYM]=h,[K_STRING]=h,[K_BIG]=h }
g_vm_t *g_apply_mx[K_N][K_N] = {
 [K_TWO]  = AROW(data_pair_apply), [K_TUPLE]  = AROW(data_num_apply),
 [K_SYM]  = AROW(data_sym_apply),
 [K_STRING] = AROW(data_string_apply), [K_BIG]  = AROW(data_num_apply), };
#undef AROW

// === the `+`/`*` dispatchers (fixnum fast path, then the matrix) ============
g_vm(g_vm_add) {
 word a = Sp[0], b = Sp[1]; intptr_t t;
 if (nump(a) && nump(b)
     && !__builtin_add_overflow((intptr_t) getnum(a), (intptr_t) getnum(b), &t)
     && t >= FIX_MIN && t <= FIX_MAX)
  return *++Sp = putnum(t), Ip++, Continue();
 return Ap(g_add_mx[g_kind(a)][g_kind(b)], f); }
g_vm(g_vm_mul) {
 word a = Sp[0], b = Sp[1];
 if (nump(a) && nump(b)) { intptr_t t;
  if (!__builtin_mul_overflow((intptr_t) getnum(a), (intptr_t) getnum(b), &t)
      && t >= FIX_MIN && t <= FIX_MAX)
   return *++Sp = putnum(t), Ip++, Continue(); }
 return Ap(g_mul_mx[g_kind(a)][g_kind(b)], f); }

AVM_DIV(quot, /)
AVM_DIV(rem, %)

// Mixed-numeric ordered comparison, split like the arith handlers so the
// both-fixnum case is a compact, contiguous fast path: load/test/compare/
// store/jmp in source order. The slow handler widens to the integer lane
// (signed compare, valid across boxes) or the float lane (either operand a
// flop). Non-numeric operands return nil.

CMP_OP(g_vm_lt, VOP_LT, <) CMP_OP(g_vm_le, VOP_LE, <=)
CMP_OP(g_vm_gt, VOP_GT, >) CMP_OP(g_vm_ge, VOP_GE, >=)

// Bitwise and/or/xor: fast both-fixnum tag trick (two odds stay odd under &
// and |; ^ clears the tag bit so we re-set it). A box operand routes to the
// slow handler, which works at full width and demotes-or-boxes; these are
// integer-only, so a float (or any non-integer) operand yields nil.
BIT_SLOW(band, &) BIT_SLOW(bor, |) BIT_SLOW(bxor, ^)
g_vm(g_vm_band) { word a = Sp[0], b = Sp[1];
 if (nump(a) && nump(b)) return *++Sp = (a & b) | 1, Ip++, Continue();
 return Ap(g_vm_band_slow, f); }
g_vm(g_vm_bor) { word a = Sp[0], b = Sp[1];
 if (nump(a) && nump(b)) return *++Sp = (a | b) | 1, Ip++, Continue();
 return Ap(g_vm_bor_slow, f); }
g_vm(g_vm_bxor) { word a = Sp[0], b = Sp[1];
 if (nump(a) && nump(b)) return *++Sp = (a ^ b) | 1, Ip++, Continue();
 return Ap(g_vm_bxor_slow, f); }

// ~ : fixnum complement keeps the tag (no allocation); a boxed value is
// complemented full-width and demoted-or-boxed; a non-integer yields nil.
g_vm(g_vm_bnot) { word a = Sp[0], _res;
 if (nump(a)) return Sp[0] = ~a | 1, Ip++, Continue();
 if (!boxp(a)) return Sp[0] = nil, Ip++, Continue();
 Have(BOX_REQ);
 EMIT_INT(~box_get(a));
 return Sp[0] = _res, Ip++, Continue(); }

// >> : arithmetic right shift. A fixnum value only shrinks, so it keeps a
// non-allocating fast path; a boxed value routes to the slow handler.
static g_vm(g_vm_bsr_slow) { word a = Sp[0], b = Sp[1], _res;
 if (!(nump(a) || boxp(a)) || !nump(b)) return *++Sp = nil, Ip++, Continue();
 Have(BOX_REQ);
 EMIT_INT(TOINT(a) >> getnum(b));
 return *++Sp = _res, Ip++, Continue(); }
g_vm(g_vm_bsr) { word a = Sp[0], b = Sp[1];
 if (nump(a) && nump(b))
  return *++Sp = putnum(getnum(a) >> getnum(b)), Ip++, Continue();
 return Ap(g_vm_bsr_slow, f); }

// << : can overflow the tag, so it always runs through the box/demote path
// (EMIT_INT still demotes small results — only genuinely wide values
// allocate). Shift done in uintptr_t for well-defined overflow.
g_vm(g_vm_bsl) { word a = Sp[0], b = Sp[1], _res;
 if (!(nump(a) || boxp(a)) || !nump(b)) return *++Sp = nil, Ip++, Continue();
 Have(BOX_REQ);
 EMIT_INT((intptr_t)((uintptr_t) TOINT(a) << getnum(b)));
 return *++Sp = _res, Ip++, Continue(); }

op(g_vm_nump, 1, oddp(Sp[0]) ? putnum(1) : nil)
// `nilp`/`not`: the language falsy predicate (nil/0 OR an all-zero tuple --
// boxed 0.0, zero int box, all-zero array). Use `(= x 0)` for a literal
// scalar-zero test; `(aall (= x 0))` over an array.
op11(g_vm_nilp, g_false(Sp[0]) ? putnum(1) : nil)

// Unary math bif: numeric arg → double, call fn, box the rank-0 f64 result.
// Non-numeric arg → nil. TCO-clean (no & escapes).
static g_vm(g_vm_math1, g_flo_t (*fn)(g_flo_t)) {
 word a = Sp[0];
 if (arrp(a)) return Ap(g_vm_vmap1, f, fn);   // (sin arr) etc. -> float array
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
 if (arrp(a) || arrp(b)) return Ap(g_vm_vmap2, f, fn);   // (pow arr ..) etc. -> float array
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
m1(mvm1) m2(mvm2)

op11(g_vm_flop, flop(Sp[0]) ? putnum(1) : nil)

// ============================================================================
// tuple
// ============================================================================
size_t const g_T[] = {
 [g_Z] = Bytes,
 [g_R] = Bytes,
 [g_C] = 2 * Bytes,      // complex scalar: (re, im)
 [g_O] = Bytes, };       // object: one tagged gwen word per element

uintptr_t g_tuple_bytes(struct g_tuple *v) {
 uintptr_t len = g_T[v->type],
           rank = v->rank,
           *shape = v->shape;
 while (rank--) len *= *shape++;
 return sizeof(struct g_tuple) + v->rank * sizeof(word) + len; }

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
// representation: a global stream in f->rng (mutated in place by rand/randf) and
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
 return tuplep(x) && tuple(x)->rank == 1 && tuple(x)->type == RNG_VT
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
 uint64_t seed = nump(n) ? (uint64_t) (intptr_t) getnum(n) : 0;
 Have(RNG_VEC_REQ);
 struct g_tuple *v = (struct g_tuple*) Hp; Hp += RNG_VEC_REQ;
 g_rng_seed(v, seed);
 return Sp[0] = word(v), Ip++, Continue(); }

// (rng-get _): a snapshot copy of the global state tuple (never aliases it).
g_vm(g_vm_rng_get) {
 Have(RNG_VEC_REQ);
 struct g_tuple *src = tuple(f->rng);            // re-read post-Have (GC may move it)
 struct g_tuple *v = rng_copy(&Hp, src);
 return Sp[0] = word(v), Ip++, Continue(); }

// (rng-set v): install v's 4 limbs into the global state (copies, never aliases),
// returning v; nil if v isn't a valid state tuple.
g_vm(g_vm_rng_set) {
 word v = Sp[0];
 if (!rng_state_p(v)) return Sp[0] = nil, Ip++, Continue();
 memcpy(tuple_data(tuple(f->rng)), tuple_data(tuple(v)), RNG_PAYLOAD_BYTES);
 return Ip++, Continue(); }            // Sp[0] (== v) is the result

// (rand n): global draw, fixnum in [0,n); n <= 0 (incl. nil) -> a full-width
// non-negative fixnum. No allocation (the result is always a fixnum), so no Have
// and no GC concern from mutating f->rng in place.
g_vm(g_vm_rand) {
 word n = Sp[0];
 uint64_t r = rng_step(tuple_data(tuple(f->rng)));
 intptr_t out = nump(n) && getnum(n) > 0
   ? (intptr_t) (r % (uint64_t) getnum(n))
   : (intptr_t) (r & (uint64_t) FIX_MAX);
 return Sp[0] = putnum(out), Ip++, Continue(); }

// (randf _): global draw, float in [0,1). Have() runs before stepping so a
// GC-triggered handler restart doesn't double-advance the state.
g_vm(g_vm_randf) {
 word _res;
 Have(BOX_REQ);
 uint64_t r = rng_step(tuple_data(tuple(f->rng)));
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
 ini_two(p, putnum((intptr_t) (r & (uint64_t) FIX_MAX)), word(v));
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
g_noinline bool eqv(struct g *f, word a, word b) {
 word *base = off_pool(f), *top = base + f->len, *w = base;
 for (;;) {
  if (a != b) {
   if (((a | b) & 1) || !datp(a) || !datp(b) || typ(a) != typ(b)) return false;
   switch (typ(a)) {
    default: return false;
    case K_TWO:
     if (top - w < 2) __builtin_trap();     // worklist overflow: a cycle
     *w++ = B(a), *w++ = B(b), a = A(a), b = A(b);
     continue;
    case K_TUPLE: {
     size_t la = g_tuple_bytes(tuple(a)), lb = g_tuple_bytes(tuple(b));
     if (la != lb || memcmp(tuple(a), tuple(b), la)) return false;
     break; }
    case K_BIG: {
     struct g_big *x = (struct g_big*) a, *y = (struct g_big*) b;
     if (x->slen != y->slen) return false;
     size_t nb = (size_t) (x->slen < 0 ? -x->slen : x->slen) * sizeof(uint32_t);
     if (memcmp(x->limb, y->limb, nb)) return false;
     break; }
    case K_STRING:
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
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, f, VOP_EQ);
 // Complex equality: equal iff re and im match. A real operand reads as (r, 0),
 // so the cross-real case `(= (cplx 2 0) 2)` is true (numeric widening, like
 // `(= 2 2.0)`); a non-numeric operand makes it false. Done before the float
 // lane so a complex never reaches TOFLO (which would misread its two words).
 if (cplxp(a) || cplxp(b)) {
  bool r = (cplxp(a) || ISNUM(a)) && (cplxp(b) || ISNUM(b))
        && (cplxp(a) ? cplx_re(a) : TOFLO(a)) == (cplxp(b) ? cplx_re(b) : TOFLO(b))
        && (cplxp(a) ? cplx_im(a) : 0) == (cplxp(b) ? cplx_im(b) : 0);
  Sp[1] = r ? putnum(1) : nil;
  return Sp++, Ip++, Continue(); }
 bool r;
 // A float operand compares as doubles across the whole numeric tower (fixnum /
 // float box / wide-int box / bignum all widen via TOFLO; a bignum loses
 // precision past 2^53, the documented float caveat). Otherwise eql: two equal
 // bignums match through eqv's K_BIG arm, and canonical demotion keeps a bignum
 // distinct from any fixnum/box of a different value.
 if (flop(a) || flop(b)) r = ISNUM(a) && ISNUM(b) && (TOFLO(a) == TOFLO(b));
 else r = eql(f, a, b);
 Sp[1] = r ? putnum(1) : nil;
 return Sp++, Ip++, Continue(); }

// (same a b) — pointer/word identity, no structural recursion. Distinguishes
// two distinct objects that `=` would conflate (e.g. two equal pairs), so the
// compiler can find a unique marker by identity.
g_vm(g_vm_same) {
 Sp[1] = Sp[0] == Sp[1] ? putnum(1) : nil;
 return Sp++, Ip++, Continue(); }

// ============================================================================
// big
// ============================================================================
// Step 6 -- arbitrary-precision integers (bignums). Closes the numeric tower
// fixnum -> wide-int box -> bignum. The representation is the K_BIG data
// sentinel `struct g_big` (i.h): sign-magnitude, 32-bit base-2^32 limbs,
// little-endian, top limb nonzero, slen the signed limb count. Zero is never a
// bignum (it demotes to nil), so every bignum has |slen| >= 1 limbs.
//
// All multi-limb work lives in g_noinline magnitude helpers operating on raw
// uint32_t arrays (no gwen pointers, no allocation), so the VM-facing entry
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

// r = a * b (schoolbook). r must be distinct from a,b; capacity >= na+nb.
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
 intptr_t v = nump(x) ? (intptr_t) getnum(x) : box_get(x);
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
   if (u <= fixmag - 1) return putnum((intptr_t) u);       // FIX_MAX = 2^(W-2)-1
   if (u > boxmag - 1) goto big;                            // > INTPTR_MAX -> bignum
   val = (intptr_t) u; }
  else {
   if (u <= fixmag) return putnum((intptr_t) ((uintptr_t) 0 - u));   // incl FIX_MIN
   if (u > boxmag) goto big;                                          // < INTPTR_MIN -> bignum
   val = (intptr_t) ((uintptr_t) 0 - u); }                            // incl INTPTR_MIN
  struct g_tuple *bx = ini_scalar((struct g_tuple*) *hp, g_Z);
  *hp += BOX_REQ; box_put(bx->shape, val); return word(bx); }
big:
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
// Operands at f->sp[0..1] are integers (fixnum/box/bignum); a zero divisor is
// screened off by the caller. Computes a (vop) b, leaves the canonical result
// at f->sp[1], pops one operand, and advances f->ip -- so the caller is just
// Pack(f); f = g_big_binop(f, vop); Unpack(f); Continue();  (cf. g_vm_gc).
struct g *g_big_binop(struct g *f, int vop) {
 word a = f->sp[0], b = f->sp[1];
 int na = bigp(a) ? big_nlimbs(a) : 2, nb = bigp(b) ? big_nlimbs(b) : 2;
 int bound = na + nb + 2;                        // result magnitude upper bound
 int work = 4 * (na + nb) + 16;                  // divmod scratch upper bound
 uintptr_t res_area = Width(struct g_big) + b2w((size_t) bound * 4),
           ws_words = b2w((size_t) (bound + work) * 4);
 if (!g_ok(f = g_have(f, res_area + ws_words))) return f;
 a = f->sp[0], b = f->sp[1];                     // re-fetch (g_have may have GC'd)
 uint32_t sa[2], sb[2]; uint32_t const *la, *lb; bool nega, negb;
 int nla = load_int_mag(a, sa, &la, &nega), nlb = load_int_mag(b, sb, &lb, &negb);
 uint32_t *rmag = (uint32_t*) (f->hp + res_area), *scr = rmag + bound;
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
    if (vop == VOP_QUOT) {
     int qn = nla - nlb + 1; while (qn > 0 && q[qn-1] == 0) qn--;
     rn = mag_copy(rmag, q, qn), rneg = nega != negb; }
    else {
     int rr = nlb; while (rr > 0 && rem[rr-1] == 0) rr--;
     rn = mag_copy(rmag, rem, rr), rneg = nega; } } } }
 f->sp[1] = g_big_canon(&f->hp, rmag, rn, rneg);
 f->sp++;
 f->ip = (union u*) f->ip + 1;
 return f; }

// --- reader / printer -------------------------------------------------------

// f->sp[0] is a [+-]?[0-9]+ token string; replace it with the canonical value
// (fixnum / box / bignum). Accumulates 9 decimal digits per mul-add pass.
struct g *g_big_read_dec(struct g *f) {
 struct g_str *tok = str(f->sp[0]);
 uintptr_t n = tok->len;
 char const *s = tok->bytes;
 bool neg = n && s[0] == '-';
 uintptr_t i = (n && (s[0] == '-' || s[0] == '+')) ? 1 : 0, ndig = n - i;
 int cap = (int) (ndig / 9) + 3;                 // upper-bound magnitude limbs
 uintptr_t res_area = Width(struct g_big) + b2w((size_t) cap * 4);
 if (!g_ok(f = g_have(f, res_area + b2w((size_t) cap * 4)))) return f;
 tok = str(f->sp[0]), s = tok->bytes;            // re-fetch post-GC
 uint32_t *mag = (uint32_t*) (f->hp + res_area);
 int m = 0;
 while (i < n) {
  uint32_t chunk = 0, pw = 1; int k = 0;
  for (; i < n && k < 9; i++, k++) chunk = chunk * 10 + (uint32_t) (s[i] - '0'), pw *= 10;
  m = mag_mul_add_small(mag, m, pw, chunk); }
 f->sp[0] = g_big_canon(&f->hp, mag, m, neg);
 return f; }

// f->sp[0] is a bignum; replace it with its base-10 string (with sign). Builds
// the digits into a fresh g_str by repeated divide-by-10 of a heap-local copy
// of the magnitude; no allocation (hence no GC) once the single Have lands, so
// the work buffer and the string stay put through the loop.
struct g *g_big_dec(struct g *f) {
 struct g_big *a = (struct g_big*) f->sp[0];
 intptr_t sl = a->slen;
 bool neg = sl < 0;
 int n = (int) (neg ? -sl : sl),
     cap = n * 10 + 2 + (neg ? 1 : 0);           // upper-bound bytes (1 limb ~ 9.633 digits)
 uintptr_t str_words = str_type_width + b2w((size_t) cap),
           scratch_words = b2w((size_t) n * 4);
 if (!g_ok(f = g_have(f, str_words + scratch_words))) return f;
 a = (struct g_big*) f->sp[0];                   // re-fetch post-GC
 struct g_str *st = (struct g_str*) f->hp;
 uint32_t *work = (uint32_t*) (f->hp + str_words);
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
 f->hp += str_type_width + b2w((size_t) dl);
 f->sp[0] = word(st);
 return f; }

// --- (arr type shape-list): zero-filled array ------------------------------
// `type` is a fixnum element-type code (i8..f64, named in the prelude); `shape`
// is a list of non-negative fixnum dimensions (empty -> a rank-0 scalar box).
// Bad type / negative dim / over-rank -> nil.
g_vm(g_vm_arr) {
 word t = Sp[0], shp = Sp[1];
 if (!nump(t)) return *++Sp = nil, Ip++, Continue();
 intptr_t ty = getnum(t);
 if (ty < 0 || ty > g_O || ty == g_C) return *++Sp = nil, Ip++, Continue();
 uintptr_t rank = 0, nelem = 1;
 for (word l = shp; twop(l); l = B(l)) {
  word d = A(l);
  if (!nump(d) || getnum(d) < 0) return *++Sp = nil, Ip++, Continue();
  rank++, nelem *= (uintptr_t) getnum(d); }
 if (rank > G_VEC_MAXRANK || (ty == g_O && rank == 0)) return *++Sp = nil, Ip++, Continue();
 uintptr_t bytes = sizeof(struct g_tuple) + rank * sizeof(word) + nelem * g_T[ty];
 Have(b2w(bytes));
 struct g_tuple *v = (struct g_tuple*) Hp;
 Hp += b2w(bytes);
 ini_tuple(v, ty, rank);
 uintptr_t i = 0;                              // re-walk the (possibly moved) list
 for (word l = Sp[1]; twop(l); l = B(l)) v->shape[i++] = (uintptr_t) getnum(A(l));
 if (ty == g_O) for (i = 0; i < nelem; i++) tuple_put_obj(v, i, nil);   // object zero = nil, NOT raw 0
 else memset(tuple_data(v), 0, nelem * g_T[ty]);
 return *++Sp = word(v), Ip++, Continue(); }

// (arrl type shape-list vals-list): like arr, but fills row-major from
// vals-list (a non-numeric or missing entry stays 0; extras are ignored). Lets
// code build a specific array before array-literal syntax lands.
g_vm(g_vm_arrl) {
 word t = Sp[0], shp = Sp[1];                  // vals = Sp[2]
 if (!nump(t)) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 intptr_t ty = getnum(t);
 if (ty < 0 || ty > g_O || ty == g_C) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 uintptr_t rank = 0, nelem = 1;
 for (word l = shp; twop(l); l = B(l)) {
  word d = A(l);
  if (!nump(d) || getnum(d) < 0) return Sp[2] = nil, Sp += 2, Ip++, Continue();
  rank++, nelem *= (uintptr_t) getnum(d); }
 if (rank > G_VEC_MAXRANK || (ty == g_O && rank == 0)) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 uintptr_t bytes = sizeof(struct g_tuple) + rank * sizeof(word) + nelem * g_T[ty];
 Have(b2w(bytes));
 struct g_tuple *v = (struct g_tuple*) Hp;
 Hp += b2w(bytes);
 ini_tuple(v, ty, rank);
 uintptr_t i = 0;                              // re-walk the (possibly moved) lists
 for (word l = Sp[1]; twop(l); l = B(l)) v->shape[i++] = (uintptr_t) getnum(A(l));
 if (ty == g_O) for (i = 0; i < nelem; i++) tuple_put_obj(v, i, nil);
 else memset(tuple_data(v), 0, nelem * g_T[ty]);
 i = 0;                                        // no alloc below, so v/Sp[2] stay put
 for (word l = Sp[2]; twop(l) && i < nelem; l = B(l), i++) {
  word e = A(l);
  if (ty == g_O) { tuple_put_obj(v, i, e); continue; }   // store any value verbatim
  if (!ISNUM(e)) continue;
  if (ty >= g_R) tuple_put_flo(v, i, TOFLO(e));
  else tuple_put_int(v, i, nump(e) ? (intptr_t) getnum(e)
                       : flop(e) ? (intptr_t) flo_get(e) : box_get(e)); }
 return Sp[2] = word(v), Sp += 2, Ip++, Continue(); }

// --- accessors -------------------------------------------------------------
// rank / element-type code as fixnums; nil for a non-tuple. Both 0 for a scalar box.
op11(g_vm_arank, tuplep(Sp[0]) ? putnum(tuple(Sp[0])->rank) : nil)
op11(g_vm_atype, tuplep(Sp[0]) ? putnum(tuple(Sp[0])->type) : nil)

// total element count (1 for a scalar box), nil for a non-tuple.
g_vm(g_vm_alen) {
 word x = Sp[0];
 if (!tuplep(x)) return Sp[0] = nil, Ip++, Continue();
 uintptr_t n = 1;
 for (uintptr_t i = 0; i < tuple(x)->rank; i++) n *= tuple(x)->shape[i];
 return Sp[0] = putnum(n), Ip++, Continue(); }

// dimensions as a list (allocates rank cons cells), nil for a non-tuple.
g_vm(g_vm_ashape) {
 word x = Sp[0];
 if (!tuplep(x)) return Sp[0] = nil, Ip++, Continue();
 uintptr_t r = tuple(x)->rank;
 Have(r * Width(struct g_pair));
 struct g_tuple *v = tuple(Sp[0]);                 // re-read post-Have
 struct g_pair *p = (struct g_pair*) Hp;
 Hp += r * Width(struct g_pair);
 word list = nil;
 for (uintptr_t i = r; i--; )
  ini_two(p, putnum(v->shape[i]), list), list = word(p), p++;
 return Sp[0] = list, Ip++, Continue(); }

// --- falsiness -------------------------------------------------------------
// True iff every element compares numerically == 0 (so -0.0 counts as zero, and
// an empty array is vacuously all-zero). Drives g_false (i.h) -> g_vm_cond and
// the `nilp`/`not` bif.
bool g_all_zero(struct g_tuple *v) {
 // A complex scalar is falsy iff both components are 0 (so (cplx 0 0) and 0.0
 // agree). Read both parts -- the generic float-domain scan below would see only
 // the real part (cplx sorts past f64, so `>= g_R` treats it as float).
 if (v->type == g_C) return cplx_re(word(v)) == 0 && cplx_im(word(v)) == 0;
 uintptr_t n = 1;
 for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 if (v->type == g_O) {                          // object array: falsy iff every element is falsy
  for (uintptr_t i = 0; i < n; i++) if (!g_false(tuple_get_obj(v, i))) return false;
  return true; }
 bool fdom = v->type >= g_R;
 for (uintptr_t i = 0; i < n; i++)
  if (fdom ? tuple_get_flo(v, i) != 0 : tuple_get_int(v, i) != 0) return false;
 return true; }

// g_O reductions (sum/prod/max/min) fold through the promoting scalar op, so an
// object array reduces *exactly*. Defined after the object lane (below); the
// numeric reductions divert here when their operand is a g_O array.
static struct g *ored(struct g *f, int kind);   // kind: 0 sum, 1 prod, 2 max, 3 min

// --- reductions: rank>=1 array -> rank-0 scalar; identity on a scalar -------
// The identity-on-scalar property makes `(aall (< a b))` rank-agnostic: the
// same expression works whether a/b are scalars or arrays.
g_vm(g_vm_asum) {
 word x = Sp[0];
 if (!tuplep(x)) return Ip++, Continue();        // scalar: (asum 5) = 5
 if (tuple(x)->type == g_O) {
  Pack(f); f = ored(f, 0);
  if (!g_ok(f)) return gtrap(f);
  return Unpack(f), Continue(); }
 struct g_tuple *v = tuple(x);
 uintptr_t n = 1;
 for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
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
 if (!tuplep(x)) return Ip++, Continue();
 if (tuple(x)->type == g_O) {
  Pack(f); f = ored(f, 1);
  if (!g_ok(f)) return gtrap(f);
  return Unpack(f), Continue(); }
 struct g_tuple *v = tuple(x);
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
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

// max / min over a non-empty array; empty -> nil; scalar -> identity.
RED_EXTREME(g_vm_amax, >, 2)
RED_EXTREME(g_vm_amin, <, 3)

// aall/aany: bool reductions. Scalar -> identity (so (aall 1) = 1, the linchpin
// of the rank-agnostic compare idiom). Over an array: aall = "no zero element",
// aany = "some nonzero element" -- the falsy rule lifted to a conjunction/
// disjunction. Empty array: aall true (vacuous), aany false.
g_vm(g_vm_aall) {
 word x = Sp[0];
 if (!tuplep(x)) return Ip++, Continue();
 struct g_tuple *v = tuple(x);
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 if (v->type == g_O) {                         // object: a falsy element fails the conjunction
  for (uintptr_t i = 0; i < n; i++)
   if (g_false(tuple_get_obj(v, i))) return Sp[0] = nil, Ip++, Continue();
  return Sp[0] = putnum(1), Ip++, Continue(); }
 bool fdom = v->type >= g_R;
 for (uintptr_t i = 0; i < n; i++)
  if (fdom ? tuple_get_flo(v, i) == 0 : tuple_get_int(v, i) == 0)
   return Sp[0] = nil, Ip++, Continue();
 return Sp[0] = putnum(1), Ip++, Continue(); }

g_vm(g_vm_aany) {
 word x = Sp[0];
 if (!tuplep(x)) return Ip++, Continue();
 struct g_tuple *v = tuple(x);
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 if (v->type == g_O) {                         // object: a truthy element satisfies the disjunction
  for (uintptr_t i = 0; i < n; i++)
   if (!g_false(tuple_get_obj(v, i))) return Sp[0] = putnum(1), Ip++, Continue();
  return Sp[0] = nil, Ip++, Continue(); }
 bool fdom = v->type >= g_R;
 for (uintptr_t i = 0; i < n; i++)
  if (fdom ? tuple_get_flo(v, i) != 0 : tuple_get_int(v, i) != 0)
   return Sp[0] = putnum(1), Ip++, Continue();
 return Sp[0] = nil, Ip++, Continue(); }

// --- elementwise unary math over an array (sin/cos/sqrt/... ) --------------
// Reached from g_vm_math1 when its operand arrp. Result is a float array
// (g_R) with the operand's shape. The fill loop takes no &local, so the
// g_vm wrapper keeps its trailing tail call.
static g_noinline void vmap1_fill(struct g_tuple *r, struct g_tuple *a, g_flo_t (*fn)(g_flo_t)) {
 uintptr_t i, n = 1;
 for (i = 0; i < r->rank; i++) n *= r->shape[i];
 for (i = 0; i < n; i++) tuple_put_flo(r, i, fn(tuple_get_flo(a, i))); }

g_vm(g_vm_vmap1, g_flo_t (*fn)(g_flo_t)) {
 struct g_tuple *a = tuple(Sp[0]);
 uintptr_t rank = a->rank, n = 1;
 for (uintptr_t i = 0; i < rank; i++) n *= a->shape[i];
 uintptr_t bytes = sizeof(struct g_tuple) + rank * sizeof(word) + n * g_T[g_R];
 Have(b2w(bytes));
 a = tuple(Sp[0]);                               // re-read post-Have
 struct g_tuple *r = (struct g_tuple*) Hp;
 Hp += b2w(bytes);
 ini_tuple(r, g_R, rank);
 for (uintptr_t i = 0; i < rank; i++) r->shape[i] = a->shape[i];
 vmap1_fill(r, a, fn);
 return Sp[0] = word(r), Ip++, Continue(); }

// --- elementwise binary engine (arith / compare / =) with broadcasting ------
// Per-element ops. Integer division guards /0 and INT_MIN/-1 -> 0 (the array
// convention; a scalar `/` promotes such cases to an IEEE inf/NaN instead, but
// one element can't change the whole result's domain).
static g_flo_t vop_flo(int op, g_flo_t a, g_flo_t b) {
 switch (op) {
  case VOP_SUB: return a - b; case VOP_MUL: return a * b;
  case VOP_QUOT: return a / b; case VOP_REM: return g_fmod(a, b);
  default: return a + b; } }                   // VOP_ADD
static intptr_t vop_int(int op, intptr_t a, intptr_t b) {
 switch (op) {
  case VOP_SUB: return (intptr_t)((uintptr_t) a - (uintptr_t) b);
  case VOP_MUL: return (intptr_t)((uintptr_t) a * (uintptr_t) b);
  case VOP_QUOT: return (b == 0 || (a == INTPTR_MIN && b == -1)) ? 0 : a / b;
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
 intptr_t ia = aarr ? 0 : nump(a) ? getnum(a) : bigp(a) ? g_big_low(a) : box_get(a),
          ib = barr ? 0 : nump(b) ? getnum(b) : bigp(b) ? g_big_low(b) : box_get(b);
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

g_vm(g_vm_vbin, int op) {
 word a = Sp[0], b = Sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 if (!(aarr || ISNUM(a)) || !(barr || ISNUM(b)))   // each operand: array or scalar
  return *++Sp = nil, Ip++, Continue();
 if ((aarr && tuple(a)->type == g_O) || (barr && tuple(b)->type == g_O))
  return Ap(g_vm_obin, f, op);                     // object array -> promoting lane
 uintptr_t ra = aarr ? tuple(a)->rank : 0, rb = barr ? tuple(b)->rank : 0;
 uintptr_t R = ra > rb ? ra : rb;
 // compute-type = max element type; a scalar int contributes the lowest type
 // (i8) so it never widens an int array, a scalar float forces the float lane.
 int ta = aarr ? (int) tuple(a)->type : flop(a) ? (int) g_R : (int) g_Z;
 int tb = barr ? (int) tuple(b)->type : flop(b) ? (int) g_R : (int) g_Z;
 int ct = ta > tb ? ta : tb;
 bool fdom = ct >= g_R, cmp = op >= VOP_LT;
 enum g_tuple_type rt = cmp ? g_Z : (enum g_tuple_type) ct;   // compare -> 0/1 Z mask
 // broadcast shape + conformance, right-aligned; scalar locals only (no array,
 // so the trailing tail call below survives).
 uintptr_t n = 1;
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? tuple(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? tuple(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) return *++Sp = nil, Ip++, Continue();
  n *= da > db ? da : db; }
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

// --- binary libm map with broadcasting (pow / atan2 over arrays) -------------
// The float-domain twin of g_vm_vbin: same numpy broadcast, but the result is
// always a float array and each element is fn(av, bv) for an arbitrary libm
// binary fn. A scalar operand broadcasts, widening through TOFLO -- so a bignum
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
  if (!ISNUM(a) || !ISNUM(b)) return nil;       // cplxp not in ISNUM -> unordered -> nil
  intptr_t t = (flop(a) || flop(b)) ? vcmp_flo(op, TOFLO(a), TOFLO(b))
             : (bigp(a) || bigp(b)) ? vcmp_int(op, g_big_cmp(a, b), 0)
                                    : vcmp_int(op, TOINT(a), TOINT(b));
  return t ? putnum(1) : nil; }
 if (!ISNUM(a) || !ISNUM(b)) return nil;
 struct g *f = *fp;
 if (flop(a) || flop(b)) {                      // float domain -> g_R box
  if (!g_ok(f = g_have(f, BOX_REQ))) return *fp = f, nil;
  *fp = f;
  struct g_tuple *v = ini_scalar((struct g_tuple*) f->hp, g_R);
  f->hp += BOX_REQ; flo_put(v->shape, vop_flo(op, TOFLO(a), TOFLO(b)));
  return word(v); }
 if (!bigp(a) && !bigp(b)) {                    // machine-int fast path, overflow-checked
  intptr_t av = TOINT(a), bv = TOINT(b), t; bool of;
  switch (op) {
   case VOP_QUOT: if (bv == 0) return putnum(0);          // array convention: int /0 -> 0
                  of = (av == INTPTR_MIN && bv == -1); t = of ? 0 : av / bv; break;
   case VOP_REM:  if (bv == 0) return putnum(0);
                  of = (av == INTPTR_MIN && bv == -1); t = of ? 0 : av % bv; break;
   case VOP_SUB:  of = __builtin_sub_overflow(av, bv, &t); break;
   case VOP_MUL:  of = __builtin_mul_overflow(av, bv, &t); break;
   default:       of = __builtin_add_overflow(av, bv, &t); break; }   // VOP_ADD
  if (!of) {                                    // demote-or-box the result
   if (t >= FIX_MIN && t <= FIX_MAX) return putnum(t);
   if (!g_ok(f = g_have(f, BOX_REQ))) return *fp = f, nil;
   *fp = f;
   struct g_tuple *v = ini_scalar((struct g_tuple*) f->hp, g_Z);
   f->hp += BOX_REQ; box_put(v->shape, t); return word(v); } }
 // bignum lane: g_big_binop computes sp[0] (op) sp[1], leaves it at sp[1],
 // pops one, and advances ip -- so save/restore ip and pop the net result.
 if (!g_ok(f = g_push(f, 2, a, b))) return *fp = f, nil;
 union u *ip0 = f->ip;
 f = g_big_binop(f, op);
 if (!g_ok(f)) return *fp = f, nil;
 f->ip = ip0;
 word r = f->sp[0]; f->sp++;
 return *fp = f, r; }

// Widen the numeric array at f->sp[slot] to a g_O copy in place (box each
// element), so the obin loop reads values uniformly. Allocates per element; the
// source (rooted at its slot) and the partially-built copy (parked on the stack)
// are re-fetched after every box.
static struct g *arr_to_obj(struct g *f, int slot) {
 struct g_tuple *src = tuple(f->sp[slot]);
 uintptr_t R = src->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= src->shape[i];
 uintptr_t bytes = sizeof(struct g_tuple) + R * sizeof(word) + n * g_T[g_O];
 if (!g_ok(f = g_have(f, b2w(bytes)))) return f;
 src = tuple(f->sp[slot]);
 struct g_tuple *dst = (struct g_tuple*) f->hp; f->hp += b2w(bytes);
 ini_tuple(dst, g_O, R);
 for (uintptr_t i = 0; i < R; i++) dst->shape[i] = src->shape[i];
 for (uintptr_t i = 0; i < n; i++) tuple_put_obj(dst, i, nil);   // safe pre-fill (GC may see it)
 if (!g_ok(f = g_push(f, 1, word(dst)))) return f;             // sp[0]=dst, src now at slot+1
 for (uintptr_t i = 0; i < n; i++) {
  struct g_tuple *s = tuple(f->sp[slot + 1]);
  word v;
  if (s->type >= g_R) {                                        // float -> g_R box
   g_flo_t e = tuple_get_flo(s, i);
   if (!g_ok(f = g_have(f, BOX_REQ))) return f;
   struct g_tuple *bx = ini_scalar((struct g_tuple*) f->hp, g_R); f->hp += BOX_REQ;
   flo_put(bx->shape, e); v = word(bx); }
  else {                                                       // int -> fixnum or g_Z box
   intptr_t e = tuple_get_int(s, i);
   if (e >= FIX_MIN && e <= FIX_MAX) v = putnum(e);
   else { if (!g_ok(f = g_have(f, BOX_REQ))) return f;
    struct g_tuple *bx = ini_scalar((struct g_tuple*) f->hp, g_Z); f->hp += BOX_REQ;
    box_put(bx->shape, e); v = word(bx); } }
  tuple_put_obj(tuple(f->sp[0]), i, v); }                          // re-fetch dst post-box
 word d = f->sp[0]; f->sp++; f->sp[slot] = d;                  // install copy, drop the parked root
 return f; }

// Pack'd body of g_vm_obin (operands at f->sp[0..1], >=1 is a g_O array).
static struct g *obin_run(struct g *f, int op) {
 word a = f->sp[0], b = f->sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 if (aarr && tuple(a)->type != g_O) { if (!g_ok(f = arr_to_obj(f, 0))) return f; }
 if (barr && tuple(b)->type != g_O) { if (!g_ok(f = arr_to_obj(f, 1))) return f; }
 a = f->sp[0], b = f->sp[1], aarr = arrp(a), barr = arrp(b);
 uintptr_t ra = aarr ? tuple(a)->rank : 0, rb = barr ? tuple(b)->rank : 0;
 uintptr_t R = ra > rb ? ra : rb, n = 1, shp[G_VEC_MAXRANK];
 for (uintptr_t k = 0; k < R; k++) {                           // broadcast shape, right-aligned
  uintptr_t da = (aarr && k < ra) ? tuple(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? tuple(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) {                        // non-conforming -> nil
   f->sp[1] = nil, f->sp++, f->ip = (union u*) f->ip + 1; return f; }
  shp[R - 1 - k] = da > db ? da : db; n *= da > db ? da : db; }
 uintptr_t bytes = sizeof(struct g_tuple) + R * sizeof(word) + n * g_T[g_O];
 if (!g_ok(f = g_have(f, b2w(bytes)))) return f;
 struct g_tuple *r = (struct g_tuple*) f->hp; f->hp += b2w(bytes);
 ini_tuple(r, g_O, R);
 for (uintptr_t k = 0; k < R; k++) r->shape[k] = shp[k];
 for (uintptr_t p = 0; p < n; p++) tuple_put_obj(r, p, nil);     // nil-fill before any GC
 if (!g_ok(f = g_push(f, 1, word(r)))) return f;               // sp: [0]=r [1]=a [2]=b
 intptr_t ca[G_VEC_MAXRANK], cb[G_VEC_MAXRANK], idx[G_VEC_MAXRANK];
 for (uintptr_t j = 0; j < R; j++) ca[j] = cb[j] = idx[j] = 0;
 if (aarr) { intptr_t s = 1; struct g_tuple *va = tuple(f->sp[1]);
  for (intptr_t oa = (intptr_t) va->rank - 1; oa >= 0; oa--) {
   intptr_t j = oa + (intptr_t) R - (intptr_t) va->rank;
   ca[j] = va->shape[oa] == 1 ? 0 : s; s *= (intptr_t) va->shape[oa]; } }
 if (barr) { intptr_t s = 1; struct g_tuple *vb = tuple(f->sp[2]);
  for (intptr_t ob = (intptr_t) vb->rank - 1; ob >= 0; ob--) {
   intptr_t j = ob + (intptr_t) R - (intptr_t) vb->rank;
   cb[j] = vb->shape[ob] == 1 ? 0 : s; s *= (intptr_t) vb->shape[ob]; } }
 for (uintptr_t p = 0; p < n; p++) {
  intptr_t oa = 0, ob = 0;
  for (uintptr_t j = 0; j < R; j++) oa += idx[j] * ca[j], ob += idx[j] * cb[j];
  word ae = aarr ? tuple_get_obj(tuple(f->sp[1]), oa) : f->sp[1];  // scalar operand re-read each step
  word be = barr ? tuple_get_obj(tuple(f->sp[2]), ob) : f->sp[2];
  word res = obin_elem(&f, op, ae, be);
  if (!g_ok(f)) return f;
  tuple_put_obj(tuple(f->sp[0]), p, res);                          // re-fetch result post-alloc
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) {
   if (++idx[j] < (intptr_t) shp[j]) break;
   idx[j] = 0; } }
 word result = f->sp[0];                                       // collapse [r,a,b] -> r, advance ip
 f->sp += 2, f->sp[0] = result, f->ip = (union u*) f->ip + 1;
 return f; }

g_vm(g_vm_obin, int op) {
 Pack(f);
 f = obin_run(f, op);
 if (!g_ok(f)) return gtrap(f);
 return Unpack(f), Continue(); }

// g_O reduction body (kind: 0 sum, 1 prod, 2 max, 3 min). f->sp[0] is the array.
static struct g *ored(struct g *f, int kind) {
 struct g_tuple *v = tuple(f->sp[0]);
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 if (kind >= 2) {                                              // max/min: pick an element, no alloc
  if (!n) { f->sp[0] = nil, f->ip = (union u*) f->ip + 1; return f; }
  word acc = tuple_get_obj(tuple(f->sp[0]), 0);
  int cop = kind == 2 ? VOP_GT : VOP_LT;
  for (uintptr_t i = 1; i < n; i++) {
   word e = tuple_get_obj(tuple(f->sp[0]), i);
   if (obin_elem(&f, cop, e, acc) == putnum(1)) acc = e; }
  f->sp[0] = acc, f->ip = (union u*) f->ip + 1; return f; }
 word init = kind == 0 ? putnum(0) : putnum(1);               // sum/prod: fold with allocation
 int aop = kind == 0 ? VOP_ADD : VOP_MUL;
 if (!g_ok(f = g_push(f, 1, init))) return f;                 // sp[0]=acc, sp[1]=array
 for (uintptr_t i = 0; i < n; i++) {
  word e = tuple_get_obj(tuple(f->sp[1]), i);
  word acc = obin_elem(&f, aop, f->sp[0], e);
  if (!g_ok(f)) return f;
  f->sp[0] = acc; }
 word result = f->sp[0]; f->sp++, f->sp[0] = result;          // collapse acc into the array slot
 f->ip = (union u*) f->ip + 1;
 return f; }

// (re, im) of an operand for the complex lane / equality: a complex contributes
// its two parts; a real number contributes (value, 0). TOFLO widens a fixnum /
// float box / wide-int box / bignum -- a bignum narrows to double here, since
// complex is a floating domain (decision 5). Caller guarantees x is cplxp or
// ISNUM. The &out params stay inside g_noinline callers, off the VM tail call.
static g_inline void cplx_parts(word x, g_flo_t *re, g_flo_t *im) {
 if (cplxp(x)) *re = cplx_re(x), *im = cplx_im(x);
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
 if (!(cplxp(a) || ISNUM(a)) || !(cplxp(b) || ISNUM(b)) || vop > VOP_QUOT)
  return *++Sp = nil, Ip++, Continue();
 Have(CPLX_REQ);
 a = Sp[0], b = Sp[1];                              // re-read post-Have
 struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_C);
 Hp += CPLX_REQ;
 cplx_fill(v, a, b, vop);
 return *++Sp = word(v), Ip++, Continue(); }

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
 if (cplxp(a) || cplxp(b)) {
  if (!(cplxp(a) || ISNUM(a)) || !(cplxp(b) || ISNUM(b)))
   return *++Sp = nil, Ip++, Continue();
  Have(CPLX_REQ);
  a = Sp[0], b = Sp[1];                              // re-read post-Have
  struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_C);
  Hp += CPLX_REQ;
  cplx_pow_fill(v, a, b);
  return *++Sp = word(v), Ip++, Continue(); }
 return Ap(g_vm_math2, f, g_pow); }

// (C re im): build a complex from two real numbers. Non-numeric arg -> nil.
g_vm(g_vm_cplx) {
 word a = Sp[0], b = Sp[1];
 if (!ISNUM(a) || !ISNUM(b)) return *++Sp = nil, Ip++, Continue();
 g_flo_t re = TOFLO(a), im = TOFLO(b);             // values extracted before alloc
 Have(CPLX_REQ);
 struct g_tuple *v = ini_scalar((struct g_tuple*) Hp, g_C);
 Hp += CPLX_REQ;
 cplx_put(v, re, im);
 return *++Sp = word(v), Ip++, Continue(); }

// (cplxp x): is x a complex scalar?
op11(g_vm_cplxp, cplxp(Sp[0]) ? putnum(1) : nil)

// (re z) / (im z): real / imaginary part as a rank-0 float box. On a real
// number, re is the number itself and im is 0; on a non-number, nil.
g_vm(g_vm_re) {
 word a = Sp[0], _res;
 if (cplxp(a)) { g_flo_t re = cplx_re(a); Have(BOX_REQ); EMIT_FLO(re);
  return Sp[0] = _res, Ip++, Continue(); }
 if (ISNUM(a)) return Ip++, Continue();            // re of a real is itself
 return Sp[0] = nil, Ip++, Continue(); }

g_vm(g_vm_im) {
 word a = Sp[0], _res;
 if (cplxp(a)) { g_flo_t im = cplx_im(a); Have(BOX_REQ); EMIT_FLO(im);
  return Sp[0] = _res, Ip++, Continue(); }
 if (ISNUM(a)) return Sp[0] = putnum(0), Ip++, Continue();   // im of a real is 0
 return Sp[0] = nil, Ip++, Continue(); }

// (conj z): complex conjugate (re, -im). On a real number, the number itself.
g_vm(g_vm_conj) {
 word a = Sp[0];
 if (cplxp(a)) { g_flo_t re = cplx_re(a), im = cplx_im(a);
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
 if (cplxp(a)) { g_flo_t re = cplx_re(a), im = cplx_im(a), m = g_sqrt(re * re + im * im);
  Have(BOX_REQ); EMIT_FLO(m); return Sp[0] = _res, Ip++, Continue(); }
 if (nump(a)) { intptr_t n = getnum(a);
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
  struct g_tuple *v = tuple(a); uintptr_t i, n = 1;       // sqrt(sum of squares) -- the same magnitude
  for (i = 0; i < v->rank; i++) n *= v->shape[i];     // abs gives a complex (its 2-vector modulus)
  g_flo_t s = 0; for (i = 0; i < n; i++) { g_flo_t e = tuple_get_flo(v, i); s += e * e; }
  Have(BOX_REQ); EMIT_FLO(g_sqrt(s)); return Sp[0] = _res, Ip++, Continue(); }
 if (mapp(a)) {                                       // table: its key count (so (int (abs t)) == (len t))
  Have(BOX_REQ); EMIT_INT((intptr_t) map_len(a)); return Sp[0] = _res, Ip++, Continue(); }
 return Sp[0] = nil, Ip++, Continue(); }

// (arg z): phase angle atan2(im, re) as a float. On a real number this is 0 for
// non-negative and pi for negative; on a non-number, nil.
g_vm(g_vm_carg) {
 word a = Sp[0], _res;
 if (cplxp(a)) { g_flo_t r = g_atan2(cplx_im(a), cplx_re(a));
  Have(BOX_REQ); EMIT_FLO(r); return Sp[0] = _res, Ip++, Continue(); }
 if (ISNUM(a)) { g_flo_t r = g_atan2(0, TOFLO(a));
  Have(BOX_REQ); EMIT_FLO(r); return Sp[0] = _res, Ip++, Continue(); }
 return Sp[0] = nil, Ip++, Continue(); }
