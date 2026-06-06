#ifndef _g_i_h
#define _g_i_h
#include "g.h"

#if UINTPTR_MAX == UINT64_MAX
#define WBITS 64
typedef double g_flo_t;
#define G_VT_FLO g_vt_f64
#define G_VT_INT g_vt_i64
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
#define WBITS 32
typedef float g_flo_t;
#define G_VT_FLO g_vt_f32
#define G_VT_INT g_vt_i32
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

#define WBYTES (WBITS>>3)
_Static_assert(WBYTES == sizeof(uintptr_t), "word size sanity check");

#define G_WAIT_FDS_MAX 8
#include <stdarg.h>
_Static_assert(sizeof(union u) == sizeof(intptr_t), "cell size equals word size");
_Static_assert(-1 >> 1 == -1, "sign extended shift");
// nilp: structural test for the nil word (the only false scalar). Distinct from
// g_false below (the language falsy predicate, which also counts an all-zero vec);
// the gwen `nilp` bif maps to g_false, not this macro.
#define nilp(_) (word(_)==nil)
#define A(o) two(o)->a
#define B(o) two(o)->b
#define AB(o) A(B(o))
#define AA(o) A(A(o))
#define BA(o) B(A(o))
#define BB(o) B(B(o))
#define len(_) (((struct g_str*)(_))->len)
#define txt(_) (((struct g_str*)(_))->bytes)
#define avail(f) ((uintptr_t)(f->sp-f->hp))
#define nom(_) sym(_)
#define ptr(_) ((word*)(_))
#define num(_) ((word)(_))
#define word(_) num(_)
#define datp(_) in_data_vt(cell(_)->ap)
#define avec(f, y, ...) (MM(f,&(y)),(__VA_ARGS__),UM(f))
#define MM(f,r) ((g_core_of(f)->root=&((struct g_r){(word*)(r),g_core_of(f)->root})))
#define UM(f) (g_core_of(f)->root=g_core_of(f)->root->n)


#if UINTPTR_MAX > 0xffffffffu
#define mix ((uintptr_t) 0x9e3779b97f4a7c15) // round(2^64 / phi)
#else
#define mix ((uintptr_t) 0x9e3779b9) // round(2^32 / phi)
#endif

#define oddp(_) ((uintptr_t)(_)&1)
#define evenp(_) !oddp(_)
#define typ(_) g_typ(cell(_))
#define cell(_) ((union u*)(_))

#define Have1() if (Sp == Hp) return Ap(g_vm_gc, f, 1)
#define Have(n) if (Sp < Hp + n) return Ap(g_vm_gc, f, n)
#if g_tco
#define g_status_yield g_status_ok
#else
#define g_status_yield g_status_eof
#endif
#define g_pop1(f) (*(f)->sp++)
#define str_type_width (Width(struct g_str))
#define op(nom, n, x) g_vm(nom) { intptr_t _ = (x); *(Sp += n-1) = _; Ip++; return Continue(); }
#define op1(nom, i, x) g_vm(nom) { Sp[0] = (x); Ip += i; return Continue(); }
#define op11(nom, x) op1(nom, 1, x)

#define nil g_nil
#define pop1 g_pop1
#define getnum g_getnum
#define putnum g_putnum

struct g_pair { g_vm_t *ap; intptr_t a, b; };
enum q { two_q, vec_q, sym_q, tbl_q, text_q, big_q, };
#define G_DATA_VT_N 6
typedef g_word num, word;
// Signedness is a property of operators, not data (see the wide-int box
// plan), so only signed integer widths + the two float widths exist here.
enum g_vec_type {
 g_vt_i8, g_vt_i16, g_vt_i32, g_vt_i64,
 g_vt_f32, g_vt_f64,
 // Step 7 -- complex: a rank-0 vec carrying two g_flo_t (re, im). Sits past the
 // real element types; arr/arrl reject ty > f64, so it can never be an array
 // element in v1 -- complex only ever appears as a rank-0 scalar (cplxp), never
 // in the rank>=1 array lanes. The `>= g_vt_f32` float-domain tests therefore
 // never see it except via the explicit cplx branches (g_all_zero, the printer).
 g_vt_cplx, };
#define G_VT_CPLX g_vt_cplx
// Elementwise binary opcodes for g_vm_vbin (kernel/arr.c). The five arith codes
// match the arith slow handlers; the five compare codes (>= VOP_LT) produce a
// 0/-1 bool array. VOP_EQ is `=` over arrays (whole-array eq is `(aall (= a b))`).
enum vop { VOP_ADD, VOP_SUB, VOP_MUL, VOP_QUOT, VOP_REM,
           VOP_LT, VOP_LE, VOP_GT, VOP_GE, VOP_EQ, };
void g_wait_fds(int const *fds, int n, uintptr_t ticks);
bool g_ready(int fd), g_strp(g_word);
struct g
 *g_please(struct g*, uintptr_t),
 *g_push(struct g*, uintptr_t, ...),
 *g_strof(struct g*, const char*),
 *gxl(struct g*),
 *gxr(struct g*),
 *g_tput(struct g*),
 *intern(struct g*),
 *g_reads(struct g*, struct g_io*),
 *g_read1(struct g*, struct g_io*),
 *str0(struct g*, uintptr_t);
struct g_atom *intern_checked(struct g*, struct g_str*);
g_vm(g_vm_gc, uintptr_t);
g_vm_t g_vm_kcall,
 g_vm_two, g_vm_vec, g_vm_sym, g_vm_tbl, g_vm_text, g_vm_big, // data self-quote sentinels, enum q order
 g_vm_putn, g_vm_info,    g_vm_clock,
 g_vm_nilp,  g_vm_putc, g_vm_gensym, g_vm_intern, g_vm_twop,
 g_vm_len, g_vm_get, g_vm_fputx, g_vm_buf, g_vm_bufnew, g_vm_bcopy,
 g_vm_nump,  g_vm_symp,   g_vm_strp,   g_vm_tblp, g_vm_band,   g_vm_bor,  g_vm_flo,  g_vm_flop,
 g_vm_sin, g_vm_cos, g_vm_tan, g_vm_atan, g_vm_atan2,
 g_vm_sqrt, g_vm_exp, g_vm_log, g_vm_pow,
 // Step 7 -- complex (kernel/cplx.c). g_vm_cplx_bin (declared apart, below) is
 // the arithmetic lane the scalar arith slow paths divert into.
 g_vm_cplx, g_vm_cplxp, g_vm_re, g_vm_im, g_vm_conj, g_vm_abs, g_vm_carg,
 g_vm_bxor,  g_vm_bsr,    g_vm_bsl,    g_vm_bnot, g_vm_ssub,
 g_vm_scat,   g_vm_cons,   g_vm_car,  g_vm_cdr,    g_vm_puts,
 g_vm_getc,  g_vm_string, g_vm_lt,     g_vm_le,   g_vm_eq,     g_vm_same, g_vm_gt,  g_vm_ge,
 g_vm_put, g_vm_tdel,   g_vm_tnew,   g_vm_tkeys,
 g_vm_unc, g_vm_poke2, g_vm_peek2,
 g_vm_seek,  g_vm_trim,   g_vm_thda,   g_vm_add,
 g_vm_sub,   g_vm_mul,    g_vm_quot,   g_vm_rem,  g_vm_arg,
 g_vm_quote, g_vm_freev,  g_vm_eval,   g_vm_cond, g_vm_jump,   g_vm_defglob,
 g_vm_ap,    g_vm_tap,    g_vm_apn,    g_vm_tapn, g_vm_ret,
 g_vm_callk, g_vm_yield_sw, g_vm_yield_bif, g_vm_task_exit, g_vm_spawn, g_vm_wait,
 g_vm_sleep, g_vm_donep, g_vm_kill, g_vm_key,
 g_vm_fgetc, g_vm_fungetc, g_vm_feof, g_vm_fputc, g_vm_fputs, g_vm_fflush,
 g_vm_fputn, g_vm_fread,
 // Step 5a -- typed multi-rank arrays (kernel/arr.c). g_vm_vbin is the shared
 // elementwise/broadcast engine the arith/compare slow lanes divert into.
 g_vm_arr, g_vm_arrl, g_vm_arank, g_vm_alen, g_vm_ashape, g_vm_atype,
 g_vm_asum, g_vm_aprod, g_vm_amax, g_vm_amin, g_vm_aall, g_vm_aany;
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
// data-kind recovery (datp/typ). Included here, after the self-quote sentinels
// above, because a frontend's override (e.g. wasm/inc/vt.h) resolves kinds
// by comparing an ap against g_vm_two..g_vm_text directly.
#include <vt.h>
uintptr_t hash(struct g*, word), g_vec_bytes(struct g_vec*);
word g_tget(struct g*, word, word, struct g_tab*);
char const *g_bif_name(intptr_t);
#define vec(_) ((struct g_vec*)(_))
#define str(_) ((struct g_str*)(_))
#define tbl(_) ((struct g_tab*)(_))
#define nump oddp
#define homp evenp
#define two(_) ((struct g_pair*)(_))
#define sym(_) ((struct g_atom*)(_))
static g_inline bool twop(word _) { return homp(_) && cell(_)->ap == g_vm_two; }
static g_inline bool tblp(word _) { return homp(_) && cell(_)->ap == g_vm_tbl; }
static g_inline bool symp(word _) { return homp(_) && cell(_)->ap == g_vm_sym; }
static g_inline bool vecp(word _) { return homp(_) && cell(_)->ap == g_vm_vec; }
static g_inline bool strp(word _) { return homp(_) && cell(_)->ap == g_vm_text; }
// Mutable flat byte string. NOT a data_vt kind: its head word is the
// self-quoting g_vm_buf (like g_vm_port_io for ports), so the GC walks a buf
// as a plain length-2 thread -- [g_vm_buf, backing g_str, terminator] -- and
// the generic thread scan forwards the embedded string pointer for free; no
// bespoke evac/copy rule, and the data-sentinel mechanism stays reserved for
// kinds that need one. The bytes live in an ordinary g_str we mutate in place
// (cf. the `to` output port). Earned by tools/elf2efi.g, which back-patches a
// PE image. Recognized by ap, like iop() for ports.
struct g_buf { g_vm_t *ap; struct g_str *str; };
static g_inline bool bufp(word _) { return homp(_) && cell(_)->ap == g_vm_buf; }
static g_inline struct g_str *buf_str(word x) { return ((struct g_buf*) x)->str; }
// the byte ops read from a string or a buf; both resolve to a g_str of bytes.
static g_inline struct g_str *bytes_of(word x) { return bufp(x) ? buf_str(x) : str(x); }
// Arbitrary-precision integer (Step 6). Own data-sentinel kind big_q: a flat,
// GC-trivial object (raw limbs, no embedded gwen pointers) the copying GC moves
// by memcpy. A generic thread scan can't hold inline limb words (a limb that's
// even-and-in-pool would be spuriously forwarded, one matching G_THD_TAG would
// truncate the object), so a flat bignum needs its own copy/evac rule -- like
// text_q strings -- which is exactly what the sentinel buys. slen = signed limb
// count (negative => negative value); |slen| 32-bit limbs little-endian
// (limb[0] least significant), top limb nonzero (normalized). Zero is never a
// bignum (it demotes to the fixnum nil), so slen is never 0 and the sign is
// unambiguous. Canonical demotion keeps the tiers disjoint: a value in fixnum
// range is a fixnum, one in intptr_t range a wide-int box, only wider values a
// bignum -- so nump/boxp/bigp are mutually exclusive and =/eqv stay well defined.
struct g_big { g_vm_t *ap; intptr_t slen; uint32_t limb[]; };
static g_inline bool bigp(word _) { return homp(_) && cell(_)->ap == g_vm_big; }
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
  return vecp(_) && vec(_)->rank == 0 && vec(_)->type == G_VT_FLO; }
// Wide-integer box: a rank-0 G_VT_INT scalar vec. Arises only from
// transparent fixnum overflow (kernel/math.c); never holds a value that
// fits the fixnum tag (canonical demotion keeps box and fixnum ranges
// disjoint), so boxp and nump never both hold for the same number.
static g_inline bool boxp(word _) {
  return vecp(_) && vec(_)->rank == 0 && vec(_)->type == G_VT_INT; }
// A complex scalar: a rank-0 G_VT_CPLX vec (two g_flo_t, re then im). Deliberately
// NOT folded into ISNUM -- the real-tower macros (TOFLO/TOINT) would misread its
// two-word payload, so the arith/eq paths handle complex via explicit cplxp
// branches placed before the real lanes (decision: complex > float > int/bignum).
static g_inline bool cplxp(word _) {
  return vecp(_) && vec(_)->rank == 0 && vec(_)->type == G_VT_CPLX; }
static g_inline bool numericp(word _) { return nump(_) || vecp(_) || bigp(_); }
// A rank>=1 typed array (vs a rank-0 scalar box, which flop/boxp catch). The
// elementwise arith/compare lanes divert to g_vm_vbin when either operand arrp.
static g_inline bool arrp(word _) { return vecp(_) && vec(_)->rank >= 1; }

// Max array rank (bounds the stack index/stride arrays in the broadcast loop).
#define G_VEC_MAXRANK 8
extern size_t const g_vt_size[];                 // element byte size by g_vec_type
// Element payload: laid out row-major just past the shape words.
static g_inline void *vec_data(struct g_vec *v) { return (void*) (v->shape + v->rank); }
static g_inline struct g_vec *ini_vec(struct g_vec *v, enum g_vec_type t, uintptr_t rank) {
 return v->ap = g_vm_vec, v->type = t, v->rank = rank, v; }
// Read element i of v as a double / as an integer (sign-extending the narrow
// integer types; truncating a float toward zero for the int reader). The int
// reader is only used on integer-typed arrays in practice.
static g_inline g_flo_t vec_get_flo(struct g_vec *v, uintptr_t i) {
 void *p = vec_data(v);
 switch (v->type) {
  case g_vt_i8:  return (g_flo_t) ((int8_t*) p)[i];
  case g_vt_i16: return (g_flo_t) ((int16_t*) p)[i];
  case g_vt_i32: return (g_flo_t) ((int32_t*) p)[i];
  case g_vt_i64: return (g_flo_t) ((int64_t*) p)[i];
  case g_vt_f32: return (g_flo_t) ((float*) p)[i];
  default:       return (g_flo_t) ((double*) p)[i]; } }
static g_inline intptr_t vec_get_int(struct g_vec *v, uintptr_t i) {
 void *p = vec_data(v);
 switch (v->type) {
  case g_vt_i8:  return (intptr_t) ((int8_t*) p)[i];
  case g_vt_i16: return (intptr_t) ((int16_t*) p)[i];
  case g_vt_i32: return (intptr_t) ((int32_t*) p)[i];
  case g_vt_i64: return (intptr_t) ((int64_t*) p)[i];
  case g_vt_f32: return (intptr_t) ((float*) p)[i];
  default:       return (intptr_t) ((double*) p)[i]; } }
// Write element i of v, narrowing to v's element type.
static g_inline void vec_put_int(struct g_vec *v, uintptr_t i, intptr_t x) {
 void *p = vec_data(v);
 switch (v->type) {
  case g_vt_i8:  ((int8_t*) p)[i]  = (int8_t) x; break;
  case g_vt_i16: ((int16_t*) p)[i] = (int16_t) x; break;
  case g_vt_i32: ((int32_t*) p)[i] = (int32_t) x; break;
  case g_vt_i64: ((int64_t*) p)[i] = (int64_t) x; break;
  case g_vt_f32: ((float*) p)[i]   = (float) x; break;
  default:       ((double*) p)[i]  = (double) x; break; } }
static g_inline void vec_put_flo(struct g_vec *v, uintptr_t i, g_flo_t x) {
 void *p = vec_data(v);
 switch (v->type) {
  case g_vt_i8:  ((int8_t*) p)[i]  = (int8_t) (intptr_t) x; break;
  case g_vt_i16: ((int16_t*) p)[i] = (int16_t) (intptr_t) x; break;
  case g_vt_i32: ((int32_t*) p)[i] = (int32_t) (intptr_t) x; break;
  case g_vt_i64: ((int64_t*) p)[i] = (int64_t) (intptr_t) x; break;
  case g_vt_f32: ((float*) p)[i]   = (float) x; break;
  default:       ((double*) p)[i]  = (double) x; break; } }

// Language falsy predicate: nil/0, or an all-zero vec (boxed 0.0, zero box/array;
// empty vec vacuously). Hot path short-circuits on nilp; only a vec scans g_all_zero.
bool g_all_zero(struct g_vec*);
static g_inline bool g_false(word x) { return nilp(x) || (vecp(x) && g_all_zero(vec(x))); }

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

// --- numeric tower helpers (shared by math.c, arr.c, tbl.c) ----------------
// Numeric scalar = a fixnum, a boxed float (flop), or a boxed wide int (boxp).
#define ISNUM(x) (nump(x) || flop(x) || boxp(x) || bigp(x))
// Integer value of a fixnum-or-box operand (callers must exclude floats AND
// bignums -- a bignum doesn't fit an intptr_t; integer lanes guard on !bigp).
#define TOINT(x) (nump(x) ? (intptr_t) getnum(x) : box_get(x))
// Double value of any numeric operand (a bignum widens via g_big_to_flo).
#define TOFLO(x) (nump(x) ? (g_flo_t) getnum(x) : flop(x) ? flo_get(x) : boxp(x) ? (g_flo_t) box_get(x) : g_big_to_flo(x))
// Heap words for one scalar box. The float box (g_flo_t) and the wide-int box
// (intptr_t) are both one pointer-width word, so one reservation fits.
#define BOX_REQ (Width(struct g_vec) + Width(intptr_t))
// Heap words for one complex box: the (re, im) payload is two g_flo_t words.
#define CPLX_REQ (Width(struct g_vec) + 2 * Width(g_flo_t))
// The tagged fixnum range: putnum spends one bit, so |value| <= 2^(WBITS-2).
#define FIX_MIN (INTPTR_MIN >> 1)
#define FIX_MAX (INTPTR_MAX >> 1)
// Emit an integer result R into `_res`: demote to a fixnum when it fits the
// tag, else box it as a rank-0 G_VT_INT scalar (bumping Hp). The caller must
// already hold Have(BOX_REQ). Takes no &local, so a handler that uses it keeps
// its trailing tail call.
#define EMIT_INT(R) do { intptr_t _r = (R); \
 if (_r >= FIX_MIN && _r <= FIX_MAX) _res = putnum(_r); \
 else { struct g_vec *_v = ini_scalar((struct g_vec*) Hp, G_VT_INT); \
        Hp += BOX_REQ; box_put(_v->shape, _r); _res = word(_v); } } while (0)
// Emit a double result R into `_res` as a rank-0 G_VT_FLO box. Same Have(BOX_REQ)
// precondition and TCO discipline as EMIT_INT.
#define EMIT_FLO(R) do { struct g_vec *_v = ini_scalar((struct g_vec*) Hp, G_VT_FLO); \
 Hp += BOX_REQ; flo_put(_v->shape, (R)); _res = word(_v); } while (0)

// Step 8 -- RNG (kernel/rng.c). State is a rank-1 i64 vec of length 4 (256 bits,
// xoshiro256++). It rides the existing vec machinery (no data sentinel) but its
// payload is treated as raw bytes -- moved by memcpy, never via vec_get/put_int,
// which would truncate the 64-bit limbs to intptr_t on 32-bit ports. The fixed
// 8-byte limbs make a seed reproduce the same sequence on every target.
#define RNG_STATE_LEN 4
#define RNG_PAYLOAD_BYTES (RNG_STATE_LEN * 8)
#define RNG_VEC_BYTES (sizeof(struct g_vec) + sizeof(uintptr_t) + RNG_PAYLOAD_BYTES)
#define RNG_VEC_REQ (b2w(RNG_VEC_BYTES))
void g_rng_seed(struct g_vec*, uint64_t);   // shape an i64 state vec + seed it (SplitMix64)
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
// `call`+`ret` where there must be a `jmp`; see tools/vmret.g). GCC proves
// the local dead and TCOs either way; the union keeps the value in a
// register so clang does too.
_Static_assert(sizeof(g_flo_t) == sizeof(uintptr_t), "float box assumes g_flo_t is pointer-width");
typedef union { uintptr_t u; g_flo_t d; } g_flo_pun;
static g_inline g_flo_t flo_get(word x) {
 return ((g_flo_pun){ .u = vec(x)->shape[0] }).d; }
static g_inline void flo_put(void *p, g_flo_t v) {
 *(uintptr_t*) p = ((g_flo_pun){ .d = v }).u; }

// Boxed complex access: re in shape[0], im in shape[1] (rank-0, so vec_data ==
// shape). Same union-pun discipline as flo_get/flo_put so an inlining VM handler
// keeps its tail call. cplx_put writes both components of an already-shaped box.
static g_inline g_flo_t cplx_re(word x) {
 return ((g_flo_pun){ .u = vec(x)->shape[0] }).d; }
static g_inline g_flo_t cplx_im(word x) {
 return ((g_flo_pun){ .u = vec(x)->shape[1] }).d; }
static g_inline void cplx_put(struct g_vec *v, g_flo_t re, g_flo_t im) {
 v->shape[0] = ((g_flo_pun){ .d = re }).u;
 v->shape[1] = ((g_flo_pun){ .d = im }).u; }

// Boxed wide-int access. The payload is one pointer-width signed integer
// in shape[0]; unlike the float box it needs no bit reinterpretation --
// it is already an integer, only its signedness differs from the
// uintptr_t slot. Neither helper takes the address of a stack local, so a
// VM handler that inlines them keeps its trailing tail call (see the
// flo_get/flo_put note above and tools/vmret.g).
static g_inline intptr_t box_get(word x) { return (intptr_t) vec(x)->shape[0]; }
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

static g_inline struct g *encode(struct g*f, enum g_status s) { return
  (struct g*) ((uintptr_t) f | s); }

static g_inline void *bump(struct g *f, uintptr_t n) {
  if (avail(f) < n) __builtin_trap();
  void *x = f->hp; f->hp += n; return x; }

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
 return s->ap = g_vm_text, s->len = len, s; }

static g_inline struct g_vec *ini_scalar(struct g_vec *v, enum g_vec_type t) {
 return v->ap = g_vm_vec, v->type = t, v->rank = 0, v; }

static g_inline struct g_tab *ini_tab(struct g_tab *t, size_t len, size_t cap, struct g_kvs**tab) {
 return t->ap = g_vm_tbl, t->len = len, t->cap = cap, t->tab = tab, t; }

static g_inline struct g_pair *ini_two(struct g_pair *w, intptr_t a, intptr_t b) {
 return w->ap = g_vm_two, w->a = a, w->b = b, w; }

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
// Throw status s: transfer control to the continuation installed at f->k,
// carrying s encoded into the f handed to it. The default k (throw_c, set in
// g_ini_0) immediately yields that back to the C driver -- same escape the old
// trap did; installing a gwen thread at f->k would instead land throws in gwen.
static g_inline struct g *gtrap2(struct g*f, enum g_status s) {
 struct g *c = g_core_of(f);
 c->ip = c->k;                                  // resume at the continuation
#if g_tco
 return c->k->ap(encode(c, s), c->k, c->hp, c->sp);
#else
 return c->k->ap(encode(c, s));
#endif
}
// Throw on an already-tagged f: re-throw its own status to f->k.
static g_inline struct g *gtrap(struct g*f) { return gtrap2(g_core_of(f), g_code_of(f)); }
static g_inline struct g *g_have(struct g *f, uintptr_t n) {
 return !g_ok(f) || avail(f) >= n ? f : g_please(f, n); }
static g_inline struct g*g_pop(struct g*f, uintptr_t n) {
 return g_core_of(f)->sp += n, f; }
#endif
