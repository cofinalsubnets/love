// arr.c -- generic-op lane, rng, eq, obin. one translation unit of the runtime;
// the shared layouts and the cross-TU seam are src/love/love.h.
#include "love.h"
// the math floor is ours on every frontend (src/apps/moon/lib/moonlibc/math/lm.c); the 32-bit
// lane computes in binary64 and narrows.
#if Bits == 64
double lm_sin(double), lm_cos(double), lm_atan2(double, double),
       lm_sqrt(double), lm_exp(double), lm_log(double), lm_pow(double, double);
#define love_sin   lm_sin
#define love_cos   lm_cos
#define love_atan2 lm_atan2
#define love_sqrt  lm_sqrt
#define love_exp   lm_exp
#define love_log   lm_log
#define love_pow   lm_pow
#else
float lm_sinf(float), lm_cosf(float), lm_atan2f(float, float), lm_sqrtf(float),
      lm_expf(float), lm_logf(float), lm_powf(float, float);
#define love_sin   lm_sinf
#define love_cos   lm_cosf
#define love_atan2 lm_atan2f
#define love_sqrt  lm_sqrtf
#define love_exp   lm_expf
#define love_log   lm_logf
#define love_pow   lm_powf
#endif
static love_inline flo_t love_tan(flo_t x) { return love_sin(x) / love_cos(x); }
static love_inline flo_t love_atan(flo_t x) { return love_atan2(x, (flo_t) 1); }
#define avm_div(op, c_op) lvm(lvm_##op) { \
 word a = Sp[0], b = Sp[1]; \
 if (charmp(a) && charmp(b)) { \
  intptr_t av = getcharm(a), bv = getcharm(b); \
  if (bv != 0 && !(av == INTPTR_MIN && bv == -1)) { \
   intptr_t t = av c_op bv; \
   if (t >= mincharm && t <= maxcharm) \
    love_musttail return Push(putcharm(t)); } } \
 avm_unit(a, b); \
 love_musttail return Ap(lvm_##op##n, g); }
#define bit_slow(n, c_op, vop) lvm(lvm_##n##_slow) {          \
 word a = Sp[0], b = Sp[1], _res;                                     \
 if (!intp(a) || !intp(b)) love_musttail return Push(ZeroPoint);        \
 if (bigp(a) || bigp(b)) { Pack(g); g = big_bitop(g, vop);         \
  if (!ok(g)) love_musttail return Ap(_lvm_ghelp, g);                \
  love_musttail return Resume(); }                                      \
 Have(box_req);                                                       \
 emit_int(_res, toint(a) c_op toint(b));                                    \
 love_musttail return Push(_res); }
#define mvm1(n) lvm(lvm_##n) { g->b = (word) (uintptr_t) (love_##n); love_musttail return Ap(lvm_math1, g); }
#define m1(_) _(sin) _(cos) _(tan) _(atan)   // the real-only unaries; sqrt/exp/log widen to complex and have their own aps
// RNG: a rank-1 i64 tray of length 4 (xoshiro256++), payload moved by memcpy -- tray_get/
// put_int would truncate the limbs on 32-bit ports. fixed 8-byte limbs reproduce a seed.
#define rng_state_len 4
#define rng_payload_bytes (rng_state_len * 8)
#define rng_tray_bytes (sizeof(struct tray) + sizeof(uintptr_t) + rng_payload_bytes)
#define rng_tray_req (b2w(rng_tray_bytes))
// whichever element kind is 8 bytes wide, so love_tray_bytes sees the full payload
#define rng_vt (Bytes == 4 ? love_C : love_Z)
static love_inline flo_t twin_mod(word x) {   // |z|
 flo_t re = twin_re(x), im = twin_im(x);
 return love_sqrt(re * re + im * im); }
// this file's own, forward-declared so order within it does not matter.
static int eqv_at(struct g *g, word a, word b, word *base, word *top);
// the bit_slow trio takes its linkage here: the macro body carries no storage class.
static lvm_t lvm_band_slow, lvm_bor_slow, lvm_bxor_slow, lvm_mul_cart, lvm_mul_rep;
// ============================================================================
// generic-op lane aps, the dispatch matrices, then the `+`/`*` dispatchers
// ============================================================================

// `*` repeat lane: a sequence times a scalar count n is n copies joined ("repeated
// +"). the count law (the associativity arc): a count acts by |count| when it is an
// exact integer -- magnitude is the one multiplicative hom that survives the sign
// crossing ((-1)*(-2) re-enters the positives) -- and any inexact count (gem, twin,
// tray) answers the absorbing () (those classes are closed under *, so the refusal
// composes: (x * 2.5) * 2 and x * (2.5 * 2 = 5.0) both land ()).
static lvm(lvm_mul_rep) {
 word a = Sp[0], b = Sp[1];
 bool aseq = strp(a) || chainp(a);                   // a string / list repeats
 word seq = aseq ? a : b, cnt = aseq ? b : a;
 if ((!strp(seq) && !chainp(seq)) || (!charmp(cnt) && !bigp(cnt)))
  love_musttail return Push(ZeroPoint);             // seq not a sequence, or count not exact
 uintptr_t n;
 if (charmp(cnt)) {
   intptr_t v = getcharm(cnt);
   n = (uintptr_t) (v < 0 ? -v : v); }
 else n = (uintptr_t) maxcharm;                      // |big|: past addressable, refused below
 // the apcap rule (prel.l) for the repeat lane: a count no heap could ever hold is
 // refused here rather than asked for. it cannot be refused downstream -- Have() is
 // pointer arithmetic, so Hp + n wraps at 2^61 words and reads as room, and an oom
 // raised inside gen_major reaches no help. () is this lane's answer to every count
 // it cannot use, so an impossible one lands there too
 if (n > ((uintptr_t) 1 << 40)) love_musttail return Push(ZeroPoint);
 if (chainp(seq)) {                                   // list -> n copies of the spine
  if (!n) love_musttail return Push(ZeroPoint);   // 0 copies -> the empty list () (zero-ontology)
  uintptr_t m = llen(seq), total = mulsat(m, n);
  if (total > words_max / Width(struct chain)) love_musttail return Push(ZeroPoint);
  Have(total * Width(struct chain));
  seq = chainp(Sp[0]) ? Sp[0] : Sp[1];                // re-read post-GC
  struct chain *base = two(Hp), *w = base;
  Hp += total * Width(struct chain);
  for (uintptr_t i = 0; i < n; i++)
   for (word l = seq; chainp(l); l = B(l), w++) ini_chain(w, A(l), word(w + 1));
  (w - 1)->b = ZeroPoint;                            // list terminator () (zero-ontology)
  love_musttail return Push(word(base)); }
 // string -> repeat the bytes
 struct str *src = str(seq);
 uintptr_t sl = src->len, total = mulsat(sl, n);
 if (!total) love_musttail return Push(EmptyString);   // 0 copies: ""
 if (total > words_max) love_musttail return Push(ZeroPoint);   // no heap holds it
 uintptr_t req = str_width(total);
 Have(req);
 src = str(strp(Sp[0]) ? Sp[0] : Sp[1]);             // re-read post-GC
 struct str *z = ini_str(str(Hp), total);
 Hp += req;
 for (uintptr_t i = 0; i < n; i++) memcpy(txt(z) + i * sl, txt(src), sl);
 *++Sp = word(z);
 Ip++; love_musttail return Continue(); }

// `*` cartesian lane: chain * chain -> the ordered cartesian product (tally is
// the homomorphism; the outer loop ranges the left operand so right-
// distributivity holds on the nose). 3*pairs chains total, one Have.
static lvm(lvm_mul_cart) {
 word a = Sp[0], b = Sp[1];
 if (!chainp(a) || !chainp(b)) love_musttail return Push(ZeroPoint);   // chain*chain only
 uintptr_t m = llen(a), n = llen(b), pairs = mulsat(m, n);
 if (!pairs) love_musttail return Push(ZeroPoint);             // empty operand annihilates
 if (pairs > words_max / (3 * Width(struct chain))) love_musttail return Push(ZeroPoint);
 Have(3 * pairs * Width(struct chain));
 a = Sp[0], b = Sp[1];                                               // re-read post-GC
 struct chain *spine = (struct chain*) Hp, *pc = spine + pairs;
 Hp += 3 * pairs * Width(struct chain);
 uintptr_t idx = 0;
 for (word la = a; chainp(la); la = B(la)) {
  word av = A(la);
  for (word lb = b; chainp(lb); lb = B(lb), idx++) {
   struct chain *p0 = pc + 2 * idx, *p1 = p0 + 1;
   ini_chain(p1, A(lb), ZeroPoint);                                  // (bj)
   ini_chain(p0, av, word(p1));                                      // (ai bj)
   ini_chain(spine + idx, word(p0), idx + 1 < pairs ? word(spine + idx + 1) : ZeroPoint); } }
 love_musttail return Push(word(spine)); }

// --- apply lane (the data-value `(g x)` aps) ---
// an applied data value's sentinel tail-jumps straight to its handler -- no table.
// the sequences index and juxtapose -- text by byte, a chain by element, a named point by
// its spelling -- numbers are church numerals. () is the default action: nothing is there
// to answer with, which is what an anonymous point, an opaque handle, an out-of-range
// index and a non-index operand all have in common.

// string x charm -> byte by index or ()
// string x string -> concat
// string x name -> concat
lvm(data_string_apply) {
 bool pt = namep(word(Ip));                             // a point head can answer a point
 struct str *na = pt ? nom_str(g, word(Ip)) : str(word(Ip)),
               *nb = strp(Sp[0]) ? str(Sp[0]) : namep(Sp[0]) ? nom_str(g, Sp[0]) : NULL;
 if (nb) {
  bool mk = pt && namep(Sp[0]);                         // point + point -> the interned point
  uintptr_t m = na->len, n = nb->len, req = str_width(m + n);
  if (!(m + n)) {
   Ip = cell(*++Sp);
   *Sp = mk ? ZeroPoint : EmptyString;
   love_musttail return Continue(); }  // the empty spelling is the zero point; no empty string is ever allocated
  Have(req + (mk ? intern_reserve(g) : 0));
  na = pt ? nom_str(g, word(Ip)) : str(word(Ip));       // re-read: a GC in Have moved the roots
  struct str *z = seq_cat(g, Hp, word(na), Sp[0]);
  Hp += req;
  word v = word(z);
  if (mk) Pack(g), v = intern_checked(g, z), Unpack(g);
  Ip = cell(*++Sp);
  *Sp = v;
  love_musttail return Continue(); }
 word v = ZeroPoint;
 if (oddp(Sp[0])) {
  word k = getcharm(Sp[0]);
  if (k >= 0 && k < (word) na->len) v = putcharm((unsigned char) txt(na)[k]); }
 Ip = cell(*++Sp), *Sp = v;
 love_musttail return Continue(); }

// applying a point: a named point acts as its spelling, so it rides the text lane whole.
// an anonymous point -- a gensym, and () -- has no spelling to act as, so nothing is
// there to answer with: (). name? and mint? partition nom? and () is in neither.
// (p x): a point is its own constant -- a name or a mint answers itself, () stays ()
lvm(data_sym_apply) {
 word self = word(Ip);
 Ip = cell(*++Sp), *Sp = self;
 love_musttail return Continue(); }

// (n x): church-numeral application for the boxed tower -- the same
// [n, num-ap, x, ret] frame as lvm_numap
lvm(data_num_apply) {
 Have(2);
 word h = hot_hook(g->hot_numap);
 word n = word(Ip), x = Sp[0], ret = Sp[1], *dst = Sp - 2;
 dst[0] = n, dst[1] = h, dst[2] = x, dst[3] = ret;
 Sp = dst, Ip = cell(numap_drive);
 love_musttail return Continue(); }

// (l k): index the spine -- the kth element, out of range () and a negative is out of range.
// (l m): a chain operand juxtaposes -- the append, agreeing with (+ l m) on the nose
// (add_seq's list+list lane, spelled here). the text law, one lattice rung up: a chain
// indexes elements where text indexes bytes. every other operand answers ().
lvm(data_pair_apply) {
 if (chainp(Sp[0])) {
  uintptr_t n = llen(word(Ip));
  Have(n * Width(struct chain));
  struct chain *base = two(Hp), *w = base;
  Hp += n * Width(struct chain);
  for (word l = word(Ip); chainp(l); l = B(l), w++) ini_chain(w, A(l), word(w + 1));
  (w - 1)->b = Sp[0];                        // last cdr -> the operand (a chain is never empty)
  Ip = cell(*++Sp); *Sp = word(base); love_musttail return Continue(); }
 word v = ZeroPoint;
 if (oddp(Sp[0])) {
  word k = getcharm(Sp[0]), l = word(Ip);
  if (k >= 0) { while (k-- > 0 && chainp(l)) l = B(l);
                if (chainp(l)) v = A(l); } }
 Ip = cell(*++Sp); *Sp = v; love_musttail return Continue(); }

// === the two generic-op dispatch matrices (+ and *), indexed by kind =====
// lanes: *n numeric/broadcast (every star and tray kind routes identically), add_seq
// a list anywhere, add_string strings and symbols (a number arrives as the unit),
// mul_rep sequence * count, *l a lambda-or-map operand (church add / compose),
// lvm_0 undefined -> zero. precedence: lambda > tablet > chain > text > number.
// the tables are generated: one datum (mx.l) feeds this header and the rocq model
// mx.v, so theorem and code cannot drift. edit mx.l, not mx.h; make relays it.
#include "mx.h"

// any value -> the kind it dispatches as (enum q, love.h): fixnum -> KCharm,
// non-data heap pointer -> KTablet/KHot, else the rep's kind. a tray is the one rep
// that dispatches four ways, by element tier. exported so the apply sentinels share
// it; it sits under mx.h for kind_of_d, the rep -> kind crossing.
enum q kind(word x) {
 if (charmp(x)) return KCharm;
 if (!datp(x)) return tabp(x) ? KTablet : KHot;
 enum d r = typ(x);
 if (r == DTray) return (enum q) (KTrayZ + tray(x)->type);
 return kind_of_d[r]; }

// === the `+`/`*` dispatchers (fixnum fast path, then the matrix) ============
lvm(lvm_add) {
 word a = Sp[0], b = Sp[1]; intptr_t t;
 if (charmp(a) && charmp(b)
     && !__builtin_add_overflow((intptr_t) getcharm(a), (intptr_t) getcharm(b), &t)
     && t >= mincharm && t <= maxcharm)
  love_musttail return Push(putcharm(t));
 // a point -- (), a bare mint, a name -- is the identity on either side, and two points
 // join: the greater under love's order stands, () the bottom. a bounded semilattice, so
 // + is associative and commutative here (distinct points annihilating could not
 // associate). this must mirror lvm_bin_unit exactly -- it is that matrix lane's fast
 // path, nothing more.
 if (nomp(a)) love_musttail return Push(nomp(b) && love_mint_cmp(g, a, b) > 0 ? a : b);
 if (nomp(b)) love_musttail return Push(a);
 love_musttail return Ap(add_mx[kind(a)][kind(b)], g); }

lvm(lvm_mul) {
 word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) { intptr_t t;
  if (!__builtin_mul_overflow((intptr_t) getcharm(a), (intptr_t) getcharm(b), &t)
      && t >= mincharm && t <= maxcharm)
   love_musttail return Push(putcharm(t)); }
 // a point is absent, and * repeats: a sequence taken an absent number of times
 // is nothing, so it annihilates. the matrix says the same thing (lvm_0), so this
 // stays a fast path.
 if (nomp(a) || nomp(b)) love_musttail return Push(ZeroPoint);
 love_musttail return Ap(mul_mx[kind(a)][kind(b)], g); }

avm_div(fquot, /)                               // `//` fixnum fast path: truncating quotient
avm_div(rem, %)
// `/` fixnum fast path: stay exact only when b divides a; otherwise the slow lane
// promotes to a float box. the INT_MIN/-1 guard precedes the `%` (it would be UB).
lvm(lvm_quot) {
 word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) {
  intptr_t av = getcharm(a), bv = getcharm(b);
  if (bv != 0 && !(av == INTPTR_MIN && bv == -1) && av % bv == 0) {
   intptr_t t = av / bv;
   if (t >= mincharm && t <= maxcharm) love_musttail return Push(putcharm(t)); } }
 avm_unit(a, b);
 if (coinp(a) || coinp(b)) love_musttail return Ap(lvm_quot_coin, g);   // the die's div method, slot 8
 love_musttail return Ap(lvm_quotn, g); }

// the ordered comparisons (lvm_lt/le/gt/ge) and their total order are defined
// after vcmp_int/vcmp_flo (the per-op trichotomy helpers), near lvm_vbin.

// bitwise and/or/xor: the both-fixnum tag trick (two odds stay odd under & and |;
// ^ clears the tag, re-set it). integer-only: any other operand yields zero.
bit_slow(band, &, vop_band) bit_slow(bor, |, vop_bor) bit_slow(bxor, ^, vop_bxor)

lvm(lvm_band) { word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) love_musttail return Push((a & b) | 1);
 avm_unit(a, b);
 if (trayp(a) || trayp(b)) { g->b = (word) (vop_band); love_musttail return Ap(lvm_vbin, g); }
 love_musttail return Ap(lvm_band_slow, g); }

lvm(lvm_bor) { word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) love_musttail return Push((a | b) | 1);
 avm_unit(a, b);
 if (trayp(a) || trayp(b)) { g->b = (word) (vop_bor); love_musttail return Ap(lvm_vbin, g); }
 love_musttail return Ap(lvm_bor_slow, g); }

lvm(lvm_bxor) { word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) love_musttail return Push((a ^ b) | 1);
 avm_unit(a, b);
 if (trayp(a) || trayp(b)) { g->b = (word) (vop_bxor); love_musttail return Ap(lvm_vbin, g); }
 love_musttail return Ap(lvm_bxor_slow, g); }
// (bitwise complement is `(^ x -1)`; logical not is the `!` reader sigil / `zerop`.)

// >> : a floor shift. the fast path is two fixnums and a count the word can take;
// everything else -- a big either side, a negative count, a count past the width --
// goes to the lane that has the whole domain.
lvm(lvm_bsr) {
 word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) {
  intptr_t k = getcharm(b);
  if (k >= 0 && k < Bits)
   love_musttail return Push(putcharm(getcharm(a) >> k)); }
 avm_unit(a, b);
 if (trayp(a) || trayp(b)) {
  g->b = (word) (vop_bsr);
  love_musttail return Ap(lvm_vbin, g); }
 if (!intp(a) || !intp(b))
  love_musttail return Push(ZeroPoint);
 LvmResume(g, big_shift, vop_bsr) }

// << : x * 2^k, so it promotes rather than dropping the bits off the top. the word
// lane is taken only where shifting back gives x again -- that is the whole test for
// "nothing was lost", and it lets 0 and every small shift stay cheap.
lvm(lvm_bsl) { word a = Sp[0], b = Sp[1], _res;
 avm_unit(a, b);
 if (trayp(a) || trayp(b)) { g->b = (word) (vop_bsl); love_musttail return Ap(lvm_vbin, g); }
 if (!intp(a) || !intp(b)) love_musttail return Push(ZeroPoint);
 if (charmp(a) && charmp(b)) { intptr_t x = getcharm(a), k = getcharm(b);
  if (k >= 0 && k < Bits) { intptr_t r = (intptr_t) ((uintptr_t) x << k);
   if ((r >> k) == x) { Have(box_req); emit_int(_res, r); love_musttail return Push(_res); } } }
 LvmResume(g, big_shift, vop_bsl) }

op(lvm_charmp, 1, oddp(Sp[0]) ? putcharm(1) : zero)   // (charm? x): a fixnum -- a charm, the tagged odd word
// (nil? x): the falsy predicate, ($ x <= 0) -- every negative is nil, not just (). `?`,
// argcond and aall ask it the same way (leaf_nilp), so the feel pass can drop a zerop wrapper.
lvm(lvm_nilp) {
 if (__builtin_expect(!leafp(Sp[0]), 0)) love_musttail return Ap(lvm_measure, g);
 Sp[0] = leaf_nilp(Sp[0]) ? putcharm(1) : zero; Ip += 1; love_musttail return Continue(); }

// unary math nif: numeric arg → double, call fn, box the rank-0 f64 result.
// non-numeric arg → zero. TCO-clean (no & escapes).
static lvm(lvm_math1) {
 flo1 fn = (flo1) (uintptr_t) g->b;
 word a = Sp[0];
 if (trayp(a)) {                               // (sin a-tray) etc. -> gem tray; a twin tray is undefined
  if (tray(a)->type == love_C) love_musttail return Answer(ZeroPoint);
  g->b = (word) (uintptr_t) (fn); love_musttail return Ap(lvm_vmap1, g); }
 if (!isnum(a)) love_musttail return Answer(ZeroPoint);
 flo_t ad = toflo(a), rd = fn(ad);
 Have(gem_req);
 Sp[0] = mk_gem(&Hp, rd); love_musttail return Next(1); }

static lvm(lvm_math2) {
 flo2 fn = (flo2) (uintptr_t) g->b;
 word a = Sp[0], b = Sp[1];
 if (trayp(a) || trayp(b)) {                               // (pow arr ..) etc. -> float array
  if ((trayp(a) && tray(a)->type == love_C) || (trayp(b) && tray(b)->type == love_C))
   love_musttail return Push(ZeroPoint);                 // complex array undefined here
  g->b = (word) (uintptr_t) (fn); love_musttail return Ap(lvm_vmap2, g); }
 if (!isnum(a) || !isnum(b)) love_musttail return Push(ZeroPoint);
 flo_t ad = toflo(a), bd = toflo(b), rd = fn(ad, bd);
 Have(gem_req);
 *++Sp = mk_gem(&Hp, rd); love_musttail return Next(1); }


m1(mvm1)
lvm(lvm_atan2) { g->b = (word) (uintptr_t) (love_atan2); love_musttail return Ap(lvm_math2, g); }

// (log x): a positive real stays float; a negative real or complex widens to the
// complex principal value ~((log |z|) (arg z)) -- so (log -1) = (* i pi), euler in
// the exact direction. arrays stay elementwise float.
lvm(lvm_log) {
 word a = Sp[0];
 flo_t m, th;
 if (twinp(a)) m = love_log(twin_mod(a)), th = love_atan2(twin_im(a), twin_re(a));
 else if (isnum(a) && toflo(a) < 0) { flo_t ad = toflo(a);
  m = love_log(-ad), th = love_atan2(0, ad); }
 else { g->b = (word) (uintptr_t) (love_log); love_musttail return Ap(lvm_math1, g); }
 Have(twin_req);
 Sp[0] = mk_twin(&Hp, m, th); love_musttail return Next(1); }

op11(lvm_gemp, gemp(Sp[0]) ? putcharm(1) : zero)

// ============================================================================
// rng
// ============================================================================
// xoshiro256++ seeded by SplitMix64. C holds no RNG state and never draws: the
// primitives are wheel (fresh state) and the functional steps turn/turnf, which
// copy the state and answer (value . new-state) -- the input is never mutated.
// the global rand/randf stream is prel lisp over the same steps. not a CSPRNG.

static uint64_t rotl64(uint64_t x, int k) {
 return (x << k) | (x >> (64 - k)); }

// the uint64_t scratch lives in these love_noinline helpers, moved via memcpy:
// taking &s in a VM ap defeats the sibcall, and memcpy is alignment-safe.

// advance the 4-word state at `payload` and return one 64-bit draw
static love_noinline uint64_t rng_step(void *payload) {
 uint64_t s[4];
 memcpy(s, payload, sizeof s);
 uint64_t const result = rotl64(s[0] + s[3], 23) + s[0], t = s[1] << 17;
 s[2] ^= s[0]; s[3] ^= s[1]; s[1] ^= s[2]; s[0] ^= s[3];
 s[2] ^= t; s[3] = rotl64(s[3], 45);
 memcpy(payload, s, sizeof s);
 return result; }

// fill the state from a seed via SplitMix64; the all-zero state is xoshiro's
// fixed point, so substitute a nonzero word
static love_noinline void rng_seed_into(void *payload, uint64_t seed) {
 uint64_t s[4], x = seed;
 for (int i = 0; i < rng_state_len; i++) {
  uint64_t z = (x += (uint64_t) 0x9e3779b97f4a7c15);
  z = (z ^ (z >> 30)) * (uint64_t) 0xbf58476d1ce4e5b9;
  z = (z ^ (z >> 27)) * (uint64_t) 0x94d049bb133111eb;
  s[i] = z ^ (z >> 31); }
 if (!(s[0] | s[1] | s[2] | s[3])) s[0] = 1;
 memcpy(payload, s, sizeof s); }

// map a 64-bit draw to a float in [0,1): keep the high mantissa bits and scale.
static flo_t u64_to_unit(uint64_t u) {
#if Bits >= 64
 return (flo_t) (u >> 11) * (flo_t) 0x1.0p-53;
#else
 return (flo_t) (uint32_t) (u >> 40) * (flo_t) 0x1.0p-24f;
#endif
}

// shape v as a state tray and seed it; no &local, so an inlining caller keeps its tail call
static void rng_seed(struct tray *v, uint64_t seed) {
 ini_tray(v, rng_vt, 1);
 v->shape[0] = rng_state_len;
 rng_seed_into(tray_data(v), seed); }

// is x a well-formed state tray (rank-1 i64, length 4)?
static bool rng_state_p(word x) {
 return packp(x) && tray(x)->rank == 1 && tray(x)->type == rng_vt
        && tray(x)->shape[0] == rng_state_len; }

// a fresh state tray at Hp copying src's limbs; caller holds Have(rng_tray_req)
static struct tray *rng_copy(word **hp, struct tray *src) {
 struct tray *v = (struct tray*) *hp;
 *hp += rng_tray_req;
 ini_tray(v, rng_vt, 1);
 v->shape[0] = rng_state_len;
 memcpy(tray_data(v), tray_data(src), rng_payload_bytes);
 return v; }

// canonicalize a 62-bit draw to the smallest integer tier. out-of-line so the
// limb[] scratch never forces a frame in lvm_turn (make vmret); bump-only.
static love_noinline word rng_canon(struct g *g, uint64_t r) {
 love_limb limb[64 / limb_bits]; int nl = 0;               // split the 64-bit draw into native limbs (1 or 2)
 for (int i = 0; (size_t) i * limb_bits < 64; i++) limb[i] = (love_limb) (r >> (i * limb_bits)), nl = i + 1;
 return big_canon(&g->hp, limb, nl, false); }

// (wheel n): a fresh state tray deterministically seeded from fixnum n. A
// non-fixnum seeds from 0.
lvm(lvm_wheel) {
 word n = Sp[0];
 uint64_t seed = charmp(n) ? (uint64_t) (intptr_t) getcharm(n) : 0;
 Have(rng_tray_req);
 struct tray *v = (struct tray*) Hp; Hp += rng_tray_req;
 rng_seed(v, seed);
 love_musttail return Answer(word(v)); }

// (turn st): functional draw -> (value . st'), value a fixed 62 bits so a seed
// yields the identical integer on every target; st is copied, never mutated
#define rng_draw_mask (((uint64_t) 1 << 62) - 1)              // 62 bits = 64-bit maxcharm
#define rng_draw_req  (Width(struct big) + b2w((64 / limb_bits) * sizeof(love_limb)))  // worst case: the 62-bit draw split into native limbs
lvm(lvm_turn) {
 word st = Sp[0];
 if (!rng_state_p(st)) love_musttail return Answer(ZeroPoint);
 Have(rng_tray_req + rng_draw_req + Width(struct chain));
 st = Sp[0];                                 // re-read post-Have
 struct tray *v = rng_copy(&Hp, tray(st));
 uint64_t r = rng_step(tray_data(v)) & rng_draw_mask;
 Pack(g);
 word val = rng_canon(g, r);
 Unpack(g);
 struct chain *p = (struct chain*) Hp; Hp += Width(struct chain);
 ini_chain(p, val, word(v));
 love_musttail return Answer(word(p)); }

// (turnf st): functional draw -> (float . st'), float in [0,1).
lvm(lvm_turnf) {
 word st = Sp[0], _res;
 if (!rng_state_p(st)) love_musttail return Answer(ZeroPoint);
 Have(rng_tray_req + box_req + Width(struct chain));
 st = Sp[0];                                 // re-read post-Have
 struct tray *v = rng_copy(&Hp, tray(st));
 uint64_t r = rng_step(tray_data(v));
 flo_t u = u64_to_unit(r);
 emit_gem(_res, u);                                // box at Hp, into _res
 struct chain *p = (struct chain*) Hp; Hp += Width(struct chain);
 ini_chain(p, _res, word(v));
 love_musttail return Answer(word(p)); }

// ============================================================================
// eq
// ============================================================================
// two functions are equal when their threads are. names never reach a thread -- a param is
// a stack slot and a constant a value -- so lambdas that differ in spelling alone compile to
// the same words: from the value to the terminator they agree, a pointer back into its own
// thread agrees by its offset from the value, and any other heap word is a value the
// worklist settles. 1 so far (its pairs pushed at *wp), 0 not equal, -1 the region is spent.
// a parked continuation is itself alone: a yield word ends the walk unequal
static int fn_eq(struct g *c, word a, word b, word **wp, word *hi) {
 union u *ka = cell(a), *kb = cell(b);
 struct tag *ta = ttag(c, ka), *tb = ttag(c, kb);
 word ha = (word) tag_head(ta), hb = (word) tag_head(tb), ea = (word) ta, eb = (word) tb;
 uintptr_t n = (uintptr_t) ((union u*) ta - ka);
 if ((uintptr_t) ((union u*) tb - kb) != n) return 0;
 word *w = *wp;
 for (uintptr_t i = 0; i < n; i++) {
  word x = ka[i].x, y = kb[i].x;
  if (x == y) {
   if (x == word(lvm_yield_sw) || x == word(lvm_yield_nif) || x == word(lvm_task_exit)
    || x == word(_lvm_yieldk)) return 0;
   continue; }
  if ((x | y) & 1) return 0;                             // a charm, or a charm against a pointer
  bool sa = x >= ha && x <= ea, sb = y >= hb && y <= eb;
  // a native whose twin is this thread is a pointer back into it too
  if (!sa) { word m = fn_meaning(c, x); if (m >= ha && m <= ea) x = m, sa = 1; }
  if (!sb) { word m = fn_meaning(c, y); if (m >= hb && m <= eb) y = m, sb = 1; }
  if (sa || sb) {                                        // back into its own thread: the same place?
   if (!sa || !sb || x - a != y - b) return 0;
   continue; }
  if (!in_heap(c, x) || !in_heap(c, y)) return 0;        // an op, a nif, an immortal: the one word or none
  if (hi - w < 2) return -1;
  *w++ = x, *w++ = y; }
 return *wp = w, 1; }

// the value hash, in the gap: a chain spines, its cars pending above the region's base under
// one running h, and every leaf goes to map.c's hash_leaf -- a function among them hashed by
// its thread there, which never recurs into a value -- and an object tray's cells fold like cars
uintptr_t hash_at(struct g *g, intptr_t x0, word *base) {
 word *end, *sw = base, x = x0, src = 0;
 gap(g, &end);
 uintptr_t h = mix, t = 0;
 bool fold = chainp(x);
 for (;;) {
  while (chainp(x)) {
   if (sw == end) __builtin_trap();                       // gap exhausted: a cycle
   h = (h ^ mix) * mix;                                   // mark a chain node
   *sw++ = A(x), x = B(x); }
  if (hash_leaf(g, x, &t, &src) == 3) {                   // an object tray: the header already in t
   struct tray *v = tray(src);
   uintptr_t n = tray_nelem(v);
   if ((uintptr_t) (end - sw) < n) __builtin_trap();
   for (uintptr_t i = n; i--;) *sw++ = tray_get_obj(v, i);
   fold = true; }
  if (!fold) return t;
  h = (h ^ t) * mix;
  if (sw == base) return h;
  x = *--sw; } }

// one non-descending step of the walk: eq_no and eq_yes settle it, and the four descents
// name the parts a walker has to take apart.
enum eqstep { eq_no, eq_yes, eq_chain, eq_coin, eq_fn, eq_tray };
static enum eqstep eqv_leaf(struct g *g, word a, word b) {
 if (a == b) return eq_yes;
 if (coinp(a) || coinp(b))                                 // a coin: same die, then the payloads
  return coinp(a) && coinp(b) && coin_kind(a) == coin_kind(b) ? eq_coin : eq_no;
 if (evenp(a) && evenp(b) && !datp(a) && !datp(b)) return eq_fn;
 // a number never equals a closure: bridging 0/1 to their church lambdas would
 // break congruence, the order, and tower transitivity
 if (((a | b) & 1) || !datp(a) || !datp(b) || typ(a) != typ(b)) return eq_no;
 switch (typ(a)) {
  default: return eq_no;
  case DChain: return eq_chain;
  case DTray: {
   // an object tray holds values, so its cells decide: the payload words are pointers
   // and two trays built apart never memcmp equal however equal their cells are
   if (objtrayp(a) || objtrayp(b)) {
    struct tray *va = tray(a), *vb = tray(b);
    if (!objtrayp(a) || !objtrayp(b) || va->rank != vb->rank) return eq_no;
    for (uintptr_t k = 0; k < va->rank; k++) if (va->shape[k] != vb->shape[k]) return eq_no;
    return eq_tray; }
   size_t la = love_tray_bytes(tray(a)), lb = love_tray_bytes(tray(b));
   return la == lb && !memcmp(tray(a), tray(b), la) ? eq_yes : eq_no; }
  case DGem: return gem_get(a) == gem_get(b) ? eq_yes : eq_no;   // the float payload (parallels = / cmp)
  case DTwin: return twin_re(a) == twin_re(b) && twin_im(a) == twin_im(b) ? eq_yes : eq_no;
  case DBig: { struct big *x = big(a), *y = big(b);
   size_t nb = (size_t) (x->slen < 0 ? -x->slen : x->slen) * sizeof(love_limb);
   return x->slen == y->slen && !memcmp(x->limb, y->limb, nb) ? eq_yes : eq_no; }
  case DString:
   return len(a) == len(b) && !memcmp(txt(a), txt(b), len(a)) ? eq_yes : eq_no; } }

// the pairs still to compare come up from base, over a table of the function pairs already
// taken as equal: threads reach each other (a letrec's siblings, a closure through its own
// captures), so a pair met again holds rather than walks forever. the walk never calls back
// in, so this is the only frame of it the C stack ever holds.
static int eqv_at(struct g *g, word a, word b, word *base, word *top) {
 uintptr_t nseen = (uintptr_t) (top - base) / 8, ns = 0;
 if (nseen > 1024) nseen = 1024;
 word *seen = base, *hi = top, *w = base + 2 * nseen;
 struct g *c = core_of(g);
 for (;;) {
  switch (eqv_leaf(g, a, b)) {
   case eq_no: return 0;
   case eq_yes: break;
   case eq_coin: a = coin_load(a), b = coin_load(b); continue;
   case eq_chain:
    if (hi - w < 2) return -1;             // the region is spent: the caller widens it
    *w++ = B(a), *w++ = B(b), a = A(a), b = A(b);
    continue;
   case eq_tray: {                         // an object tray: shape settled above, cells onto the worklist
    struct tray *va = tray(a), *vb = tray(b);
    uintptr_t n = tray_nelem(va);
    if ((uintptr_t) (hi - w) < 2 * n) return -1;
    for (uintptr_t i = 0; i < n; i++) *w++ = tray_get_obj(va, i), *w++ = tray_get_obj(vb, i);
    break; }
   // function values: a partial is its base and its captures, pairwise; any other is its
   // thread (fn_eq). a carrier -- a tablet, a cask, a port -- is itself alone
   case eq_fn: {
    a = fn_meaning(c, a), b = fn_meaning(c, b);
    if (a == b) break;
    if (!in_heap(c, a) || !in_heap(c, b)) return 0;
    union u *ka = cell(a), *kb = cell(b);
    if (fn_carrier(ka) || fn_carrier(kb)) return 0;
    bool pa = fn_partialp(ka), pb = fn_partialp(kb);
    if (pa || pb) {
     int na, nb;
     if (!pa || !pb) return 0;
     union u *ba = fn_base(ka, &na), *bb = fn_base(kb, &nb);
     if (na != nb) return 0;
     if (hi - w < 2 * (na + 1)) return -1;                // the region is spent
     for (int i = 0; i < na; i++) *w++ = fn_arg(ka, i, na), *w++ = fn_arg(kb, i, nb);
     a = (word) ba, b = (word) bb; continue; }
    for (word *s = seen; s < seen + 2 * ns; s += 2)
     if (s[0] == a && s[1] == b) goto held;               // already taken as equal: it holds
    if (ns == nseen) return -1;
    seen[2 * ns] = a, seen[2 * ns + 1] = b, ns++;
    { int r = fn_eq(c, a, b, &w, hi); if (r <= 0) return r; }
   held:
    break; } }
  if (w == base + 2 * nseen) return 1;      // drained: all equal
  b = *--w, a = *--w; } }

// the gap is the region for a walk with nowhere to put a wider one: a map probe and a
// comparator both answer mid-reservation, where nothing may allocate.
love_noinline bool eqv(struct g *g, word a, word b) {
 word *top, *base = gap(g, &top);
 int r = eqv_at(g, a, b, base, top);
 if (r < 0) __builtin_trap();
 return r > 0; }

// whole-array `=`: a boolean like every other kind (shapes match, every cell
// equal), not the elementwise mask -- `<` and `>` are the mask makers. cells
// compare across tiers (a z-tray equals a gem-tray of the same values); object
// cells go through eqv; an object tray never equals a numeric one.
static love_noinline int tray_eq(struct g *g, word a, word b, word *base, word *top) {
 if (!trayp(a) || !trayp(b)) return 0;                // an array is never a scalar
 struct tray *va = tray(a), *vb = tray(b);
 if (va->rank != vb->rank) return 0;
 for (uintptr_t k = 0; k < va->rank; k++)
  if (va->shape[k] != vb->shape[k]) return 0;       // same shape, not merely conformant
 uintptr_t n = tray_nelem(va);
 bool oa = va->type == love_O, ob = vb->type == love_O;
 if (oa || ob) {
  if (oa != ob) return 0;
  for (uintptr_t i = 0; i < n; i++) {
   int r = eqv_at(g, tray_get_obj(va, i), tray_get_obj(vb, i), base, top);
   if (r <= 0) return r; }
  return 1; }
 if (va->type == love_C || vb->type == love_C) {        // (re,im) per cell; a real reads as (r,0)
  flo_t const *pa = tray_data(va), *pb = tray_data(vb);
  for (uintptr_t i = 0; i < n; i++) {
   flo_t are = va->type == love_C ? pa[2*i] : tray_get_flo(va, i),
            aim = va->type == love_C ? pa[2*i+1] : 0,
            bre = vb->type == love_C ? pb[2*i] : tray_get_flo(vb, i),
            bim = vb->type == love_C ? pb[2*i+1] : 0;
   if (!same_flo(are, bre) || !same_flo(aim, bim)) return 0; }
  return 1; }
 if (va->type == love_Z && vb->type == love_Z) {        // exact: no double round-trip
  for (uintptr_t i = 0; i < n; i++)
   if (tray_get_int(va, i) != tray_get_int(vb, i)) return 0;
  return 1; }
 for (uintptr_t i = 0; i < n; i++)                  // a float on either side: as doubles
  if (!same_flo(tray_get_flo(va, i), tray_get_flo(vb, i))) return 0;
 return 1; }

// (= a b): value-equality with numeric promotion across the tower; falls through
// to eql for non-numeric operands. strictly looser than eqv, which still rejects
// mixed-type chains (table keys 3 and 3.0 stay distinct).
// the whole of `=` as a question, so lvm_eq and lvm_elem cannot drift: a charm or a nom
// is settled by identity, and a tray, a complex, a numeric coin and a float each read by
// value before the structural fall-through. eql alone is NOT `=` -- it answers 0 for
// (= (/// 1 1) 1), which the coin band below reads as equal.
// 1 equal, 0 unequal, -1 the region ran out: eql's shape over the caller's region, since
// the walk under it is what runs out
static int eql_at(struct g *g, word a, word b, word *base, word *top) {
 return a == b ? 1 : (a & b & 1) || (nomp(a) && nomp(b)) ? 0 : eqv_at(g, a, b, base, top); }
static int eq_value(struct g *g, word a, word b, word *base, word *top) {
 if ((charmp(a) && charmp(b)) || nomp(a) || nomp(b)) return a == b;
 if (trayp(a) || trayp(b)) return tray_eq(g, a, b, base, top);
 if (twinp(a) || twinp(b))
  return (twinp(a) || isnum(a)) && (twinp(b) || isnum(b))
      && (twinp(a) ? twin_re(a) : toflo(a)) == (twinp(b) ? twin_re(b) : toflo(b))
      && (twinp(a) ? twin_im(a) : 0) == (twinp(b) ? twin_im(b) : 0);
 if (coinp(a) || coinp(b))
  return numband(g, a) && numband(g, b) ? love_cmp3(g, a, b) == 0 : eql_at(g, a, b, base, top);
 if (gemp(a) || gemp(b)) return isnum(a) && isnum(b) && (toflo(a) == toflo(b));
 return eql_at(g, a, b, base, top); }

// the gap the walk starts in, usable only because nothing allocates while it is being read
static word *eq_gap(struct g *g, word **top) { return gap(g, top); }

// a scratch array of n words for a walk the gap could not hold. it is read by nothing
// else and the walk allocates nothing, so the raw words in it stay put; () when the heap
// will not grow, which the caller hands back as the scare any reservation raises.
static word *eq_scratch(struct g **gp, uintptr_t n) {
 struct g *g = *gp;
 uintptr_t words = b2w(tray_bytes(love_Z, 1, n));
 if (!ok(g = have(g, words))) return *gp = g, (word*) 0;
 struct tray *v = (struct tray*) g->hp; g->hp += words;
 ini_tray(v, love_Z, 1), v->shape[0] = n;
 return *gp = g, tray_data(v); }

// the deep lane of `=`: the gap is bounded by the major's spare half and the values
// walked are not, so a shape past it gets a region of its own, doubling from twice the
// gap until the walk fits. the pair is re-read each round -- a reservation may move it.
// nothing fits a pair no region can hold, and the doubling ends where every reservation
// does, at a heap that will not grow. the 64 is what makes that true of the doubling
// too: from a zero-word gap it would double forever without asking for anything.
static struct g *eq_wide(struct g *g) {
 for (uintptr_t n = 2 * (uintptr_t) g->major_len + 64;; n *= 2) {
  word *base = eq_scratch(&g, n);
  if (!base) return g;
  int r = eq_value(g, g->sp[0], g->sp[1], base, base + n);
  if (r >= 0) return g->sp[1] = r ? putcharm(1) : zero, g->sp += 1, g; } }

// ..and of `elem`: the scan has no side effects, so a widened region simply re-runs it
static struct g *elem_wide(struct g *g) {
 for (uintptr_t n = 2 * (uintptr_t) g->major_len + 64;; n *= 2) {
  word *base = eq_scratch(&g, n);
  if (!base) return g;
  int r = 0;
  for (word l = g->sp[1]; chainp(l) && !nomp(l); l = B(l))
   if ((r = eq_value(g, g->sp[0], A(l), base, base + n))) break;
  if (r >= 0) return g->sp[1] = r > 0 ? putcharm(1) : zero, g->sp += 1, g; } }

lvm(lvm_eq) {
 word a = Sp[0], b = Sp[1];
 // the common case: identity settles two charms, and a point against anything
 // (a point equals only itself). both skip the dispatch below and fuse a
 // following `?` directly (then -> Ip+3, else -> Ip[2].m).
 if (__builtin_expect((charmp(a) && charmp(b)) || nomp(a) || nomp(b), 1)) {
  bool r = a == b;
  if (Ip[1].ap == lvm_cond) { Sp += 2; Ip = r ? Ip + 3 : Ip[2].m; love_musttail return Continue(); }
  love_musttail return Answerp(1, r ? putcharm(1) : zero); }
 // a tray: elementwise with broadcast, a mask; the whole question is (aall (= a b))
 if (trayp(a) || trayp(b)) { g->b = (word) vop_eq; love_musttail return Ap(lvm_vbin, g); }
 // a coin whose kind spells '=: the method's ((f a) b) under numap_drive, either side, like +
 // (two coins of distinct kinds are unequal by payload). the structural walk below, which a
 // map probe and sort share, reads the payload regardless
 if (coinp(a) || coinp(b)) {
  word f = coinp(a) && coinp(b) && coin_kind(a) != coin_kind(b) ? ZeroPoint
         : kind_get(g, coin_kind(coinp(a) ? a : b), KnEq);
  if (f != ZeroPoint) {
   Have(2);
   a = Sp[0], b = Sp[1], f = kind_get(g, coin_kind(coinp(a) ? a : b), KnEq);
   word *dst = Sp - 2;
   dst[0] = a, dst[1] = f, dst[2] = b, dst[3] = word(Ip + 1);
   Sp = dst; Ip = (union u*) numap_drive; love_musttail return Continue(); } }
 word *top, *base = eq_gap(g, &top);
 int r = eq_value(g, a, b, base, top);
 if (r < 0) LvmCall(g, eq_wide)                            // too deep for the gap: walk again, wider
 Sp[1] = r ? putcharm(1) : zero;
 love_musttail return Nextp(1, 1); }

// (== a b): pointer/word identity, no structural recursion
lvm(lvm_same) {
 Sp[1] = Sp[0] == Sp[1] ? putcharm(1) : zero;
 love_musttail return Nextp(1, 1); }

// (elem x l): x equal to some element of the sequence l -- a chain by link, a text by
// byte, which is the lattice the index lane already spells (a chain indexes elements
// where a text indexes bytes). eqv scratches above the pool and never collects, so l is
// safe to hold across a compare.
// a text's elements are CHARMS, so a 1-byte text is not one of them: (elem "b" "abc")
// is 0, as `=` across kinds is, and the charm is the spelling that finds it.
// a nom and a charm are each their own equality -- eql settles both by identity and
// never reaches eqv -- so ask that ONCE rather than per link: the common
// (elem nm '(a b c)) then walks at one pointer compare a link, which is assq's speed.
lvm(lvm_elem) { word x = Sp[0], l = Sp[1];
 if (!chainp(l) && strp(l)) {                            // the chain path pays one test it already makes
  if (!oddp(x)) love_musttail return Push(zero);          // only a charm can be a byte
  word c = getcharm(x);
  if (c >= 0 && c < 256) {
   struct str *s = str(l);
   for (uintptr_t i = 0; i < s->len; i++)
    if ((unsigned char) txt(s)[i] == (unsigned char) c) love_musttail return Push(putcharm(1)); }
  love_musttail return Push(zero); }
 if (nomp(x)) {
  for (; chainp(l) && !nomp(l); l = B(l))
   if (A(l) == x) love_musttail return Push(putcharm(1));
  love_musttail return Push(zero); }
 word *top, *base = eq_gap(g, &top);
 for (; chainp(l) && !nomp(l); l = B(l)) {
  int r = eq_value(g, x, A(l), base, top);
  if (r < 0) LvmCall(g, elem_wide)                         // too deep for the gap: scan again, wider
  if (r) love_musttail return Push(putcharm(1)); }
 love_musttail return Push(zero); }

// (eleq x l): elem under `==` rather than `=` -- identity, so a pointer compare a link
// and never a call. the two part company exactly where == and = do: a ratio coin, a
// float, a tray, and any two chains built apart.
lvm(lvm_eleq) { word x = Sp[0], l = Sp[1];
 for (; chainp(l) && !nomp(l); l = B(l))
  if (A(l) == x) love_musttail return Push(putcharm(1));
 love_musttail return Push(zero); }

// ============================================================================
// obin -- object-array elementwise lane (love_O)
// ============================================================================
// the typed lanes wrap on overflow; the object lane routes every element through
// the promoting scalar dispatch, so a love_O array adds/multiplies exactly. the
// inner loop allocates, so it runs Pack'd and re-fetches every live pointer.

// one element op, allocating via *fp; zero for a non-numeric/complex operand
static word obin_elem(struct g **fp, int op, word a, word b) {
 if (op == vop_eq) {                            // a cell against a cell: the whole `=`, structural
  word *top, *base = eq_gap(*fp, &top);
  return eq_value(*fp, a, b, base, top) > 0 ? putcharm(1) : zero; }
 if (op >= vop_lt) {                            // comparison -> 1 / zero, no allocation
  if (!isnum(a) || !isnum(b)) return zero;       // twinp not in isnum -> unordered -> zero
  intptr_t t = (gemp(a) || gemp(b)) ? vcmp_flo(op, toflo(a), toflo(b))
             : (bigp(a) || bigp(b)) ? vcmp_int(op, big_cmp(a, b), 0)
                                    : vcmp_int(op, toint(a), toint(b));
  return t ? putcharm(1) : zero; }
 if (!isnum(a) || !isnum(b)) return zero;
 struct g *g = *fp;
 if (gemp(a) || gemp(b)) {                      // float domain -> float box
  flo_t r = vop_flo(op, toflo(a), toflo(b));  // both operands read first: a/b are raw words
  if (!ok(g = have(g, gem_req))) return *fp = g, zero;   // and a float box is a heap object, so
  *fp = g;                                                    // toflo after the have reads a moved one
  return mk_gem(&g->hp, r); }
 if (!bigp(a) && !bigp(b)) {                    // machine-int fast path, overflow-checked
  intptr_t av = toint(a), bv = toint(b), t; bool of;
  switch (op) {
   case vop_quot: case vop_fquot:                         // object (love_O) arrays truncate under both / and //
                  if (bv == 0) return putcharm(0);          // array convention: int /0 -> 0
                  of = (av == INTPTR_MIN && bv == -1); t = of ? 0 : av / bv; break;
   case vop_rem:  if (bv == 0) return a;                     // a % 0 = a: no modulus, a whole
                  of = (av == INTPTR_MIN && bv == -1); t = of ? 0 : av % bv; break;
   case vop_sub:  of = __builtin_sub_overflow(av, bv, &t); break;
   case vop_mul:  of = __builtin_mul_overflow(av, bv, &t); break;
   case vop_max:  of = false; t = av > bv ? av : bv; break;
   case vop_min:  of = false; t = av < bv ? av : bv; break;
   default:       of = __builtin_add_overflow(av, bv, &t); break; }   // vop_add
  if (!of) {                                    // demote-or-box the result
   if (t >= mincharm && t <= maxcharm) return putcharm(t);
   if (!ok(g = have(g, wbig_req))) return *fp = g, zero;
   *fp = g;
   return mk_wbig(&g->hp, t); } }
 if (op == vop_max || op == vop_min) {          // an extreme is one of its operands: no arithmetic
  intptr_t c = big_cmp(a, b);
  return (op == vop_max ? c >= 0 : c <= 0) ? a : b; }
 // bignum lane: big_binop computes sp[0] (op) sp[1], leaves it at sp[1],
 // pops one, and advances ip -- so save/restore ip and pop the net result.
 if (!ok(g = push(g, 2, a, b))) return *fp = g, zero;
 union u *ip0 = g->ip;
 avec(g, ip0, g = big_binop(g, op));
 if (!ok(g)) return *fp = g, zero;
 g->ip = ip0;
 word r = g->sp[0]; g->sp++;
 return *fp = g, r; }

// widen the numeric array at g->sp[slot] to a love_O copy (box each element);
// allocates per element, everything re-fetched after every box
static struct g *tray_to_obj(struct g *g, int slot) {
 struct tray *src = tray(g->sp[slot]);
 uintptr_t R = src->rank, n = tray_nelem(src);
 uintptr_t bytes = tray_bytes(love_O, R, n);
 if (!ok(g = have(g, b2w(bytes)))) return g;
 src = tray(g->sp[slot]);
 struct tray *dst = (struct tray*) g->hp; g->hp += b2w(bytes);
 ini_tray(dst, love_O, R);
 for (uintptr_t i = 0; i < R; i++) dst->shape[i] = src->shape[i];
 for (uintptr_t i = 0; i < n; i++) tray_put_obj(dst, i, zero);   // safe pre-fill (GC may see it)
 if (!ok(g = push(g, 1, word(dst)))) return g;             // sp[0]=dst, src now at slot+1
 for (uintptr_t i = 0; i < n; i++) {
  struct tray *s = tray(g->sp[slot + 1]);
  word v;
  if (s->type >= love_R) {                                        // float -> float box
   flo_t e = tray_get_flo(s, i);
   if (!ok(g = have(g, gem_req))) return g;
   v = mk_gem(&g->hp, e); }
  else {                                                       // int -> fixnum or boxed
   intptr_t e = tray_get_int(s, i);
   if (e >= mincharm && e <= maxcharm) v = putcharm(e);
   else { if (!ok(g = have(g, wbig_req))) return g;
    v = mk_wbig(&g->hp, e); } }
  tray_put_obj(tray(g->sp[0]), i, v);                            // re-fetch dst post-box
  gen_wb(g, g->sp[0], v); }                                    // ... and barrier it: see obin_run
 word d = g->sp[0]; g->sp++; g->sp[slot] = d;                  // install copy, drop the parked root
 return g; }

// Pack'd body of lvm_obin (operands at g->sp[0..1], >=1 is a love_O array).
static struct g *obin_run(struct g *g, int op) {
 word a = g->sp[0], b = g->sp[1];
 bool atray = trayp(a), btray = trayp(b);
 if (atray && tray(a)->type != love_O) { if (!ok(g = tray_to_obj(g, 0))) return g; }
 if (btray && tray(b)->type != love_O) { if (!ok(g = tray_to_obj(g, 1))) return g; }
 a = g->sp[0], b = g->sp[1], atray = trayp(a), btray = trayp(b);
 uintptr_t R, n = bshape(a, b, &R), shp[maxrank];
 if (n == (uintptr_t) -1) {                                    // non-conforming -> zero
  g->sp[1] = zero, g->sp++, g->ip = (union u*) g->ip + 1; return g; }
 bshape_put(shp, R, a, b);
 uintptr_t bytes = tray_bytes(love_O, R, n);
 if (!ok(g = have(g, b2w(bytes)))) return g;
 struct tray *r = (struct tray*) g->hp; g->hp += b2w(bytes);
 ini_tray(r, love_O, R);
 for (uintptr_t k = 0; k < R; k++) r->shape[k] = shp[k];
 for (uintptr_t p = 0; p < n; p++) tray_put_obj(r, p, zero);     // zero-fill before any GC
 if (!ok(g = push(g, 1, word(r)))) return g;               // sp: [0]=r [1]=a [2]=b
 struct bcast w; bc_open(&w, atray ? tray(g->sp[1]) : 0, btray ? tray(g->sp[2]) : 0, R, shp);
 for (uintptr_t p = 0; p < n; p++, bc_step(&w)) {
  intptr_t oa = w.oa, ob = w.ob;
  word ae = atray ? tray_get_obj(tray(g->sp[1]), oa) : g->sp[1],  // scalar operand re-read each step
       be = btray ? tray_get_obj(tray(g->sp[2]), ob) : g->sp[2],
       res = obin_elem(&g, op, ae, be);
  if (!ok(g)) return g;
  tray_put_obj(tray(g->sp[0]), p, res);                          // re-fetch result post-alloc
  // and barrier it: a minor mid-loop promotes the result array while its
  // elements stay young -- an edge the rem set must carry, or the next minor
  // frees an element still in the array
  gen_wb(g, g->sp[0], res); }
 g->sp[2] = g->sp[0], g->sp += 2, g->ip += 1;
 return g; }

lvm(lvm_obin) {
 int op = (int) g->b;
 LvmResume(g, obin_run, op) }

// love_O reduction body (kind: 0 sum, 1 prod, 2 max, 3 min). g->sp[0] is the array.
struct g *ored(struct g *g, int kind) {
 struct tray *v = tray(g->sp[0]);
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 if (kind >= 2) {                                              // max/min: pick an element, no alloc
  if (!n) { g->sp[0] = zero, g->ip = (union u*) g->ip + 1; return g; }
  word acc = tray_get_obj(tray(g->sp[0]), 0);
  int cop = kind == 2 ? vop_gt : vop_lt;
  for (uintptr_t i = 1; i < n; i++) {
   word e = tray_get_obj(tray(g->sp[0]), i);
   if (obin_elem(&g, cop, e, acc) == putcharm(1)) acc = e; }
  g->sp[0] = acc, g->ip = (union u*) g->ip + 1; return g; }
 word init = kind == 0 ? putcharm(0) : putcharm(1);               // sum/prod: fold with allocation
 int aop = kind == 0 ? vop_add : vop_mul;
 if (!ok(g = push(g, 1, init))) return g;                 // sp[0]=acc, sp[1]=array
 for (uintptr_t i = 0; i < n; i++) {
  word e = tray_get_obj(tray(g->sp[1]), i);
  word acc = obin_elem(&g, aop, g->sp[0], e);
  if (!ok(g)) return g;
  g->sp[0] = acc; }
 word result = g->sp[0]; g->sp++, g->sp[0] = result;          // collapse acc into the array slot
 g->ip = (union u*) g->ip + 1;
 return g; }

// (re, im) of an operand: a complex its parts, a real (value, 0); caller
// guarantees twinp or isnum
static void twin_parts(word x, flo_t *re, flo_t *im) {
 if (twinp(x)) *re = twin_re(x), *im = twin_im(x);
 else *re = toflo(x), *im = 0; }

// (ar,ai) `vop` (br,bi) in components: the one set of complex formulas, shared
// by the scalar lane (twin_fill) and the packed array lane (cbin_fill).
static void twin_op(int vop, flo_t ar, flo_t ai, flo_t br, flo_t bi,
                             flo_t *re, flo_t *im) {
 switch (vop) {
  case vop_sub: *re = ar - br; *im = ai - bi; break;
  case vop_mul: *re = ar * br - ai * bi; *im = ar * bi + ai * br; break;
  case vop_quot: { flo_t d = br * br + bi * bi;   // (ac+bd)/(c^2+d^2) + ...
   *re = (ar * br + ai * bi) / d; *im = (ai * br - ar * bi) / d; break; }
  case vop_max: case vop_min: {                       // the (re, im) order the comparisons keep
   int c = ar < br ? -1 : ar > br ? 1 : ai < bi ? -1 : ai > bi ? 1 : 0;
   bool pa = vop == vop_max ? c >= 0 : c <= 0;
   *re = pa ? ar : br; *im = pa ? ai : bi; break; }
  default: *re = ar + br; *im = ai + bi; } }          // vop_add

// fill the complex box with a `vop` b; the &-taking lives here (the wrapper's tail call)
static love_noinline void twin_fill(struct twin *v, word a, word b, int vop) {
 flo_t ar, ai, br, bi, re, im;
 twin_parts(a, &ar, &ai); twin_parts(b, &br, &bi);
 twin_op(vop, ar, ai, br, bi, &re, &im);
 twin_set(v, re, im); }

// the complex arithmetic lane: a real operand promotes to (r, 0); non-numeric,
// or % (undefined on complex), yields zero
lvm(lvm_twin_bin) {
 int vop = (int) g->b;
 word a = Sp[0], b = Sp[1];
 if (!(twinp(a) || isnum(a)) || !(twinp(b) || isnum(b)) || vop > vop_quot)
  love_musttail return Push(ZeroPoint);
 Have(twin_req);
 struct twin *v = (struct twin*) Hp; v->ap = lvm_twinbox; Hp += twin_req;
 twin_fill(v, a, b, vop);
 love_musttail return Push(word(v)); }

// --- complex-array elementwise lane (love_C): lvm_vbin's complex twin -- packed
// (re,im) broadcast, a real element promoting to (v, 0)
static void cbin_part(bool istray, struct tray *v, flo_t sre, flo_t sim,
                               uintptr_t o, flo_t *re, flo_t *im) {
 if (!istray) { *re = sre; *im = sim; return; }
 if (v->type == love_C) { flo_t *fp = tray_data(v); *re = fp[2*o]; *im = fp[2*o+1]; }
 else { *re = tray_get_flo(v, o); *im = 0; } }

static love_noinline void cbin_fill(struct tray *r, word a, word b, int op, bool cmp) {
 uintptr_t R = r->rank, n = tray_nelem(r);
 bool atray = trayp(a), btray = trayp(b);
 struct tray *va = atray ? tray(a) : 0, *vb = btray ? tray(b) : 0;
 struct bcast w; bc_open(&w, va, vb, R, r->shape);
 flo_t sar = 0, sai = 0, sbr = 0, sbi = 0;
 if (!atray) { if (twinp(a)) sar = twin_re(a), sai = twin_im(a); else sar = toflo(a); }
 if (!btray) { if (twinp(b)) sbr = twin_re(b), sbi = twin_im(b); else sbr = toflo(b); }
 flo_t *rf = cmp ? 0 : tray_data(r);
 for (uintptr_t p = 0; p < n; p++, bc_step(&w)) {
  intptr_t oa = w.oa, ob = w.ob;
  flo_t ar, ai, br, bi, re, im;
  cbin_part(atray, va, sar, sai, oa, &ar, &ai);
  cbin_part(btray, vb, sbr, sbi, ob, &br, &bi);
  if (cmp) {                                   // (re,im) lexicographic -- the same order
   int t;                                      // cmp3's complex arm gives a scalar pair
   if (op == vop_eq) t = same_flo(ar, br) && same_flo(ai, bi);   // ..and a NaN is () here too
   else {
    int c = ar < br ? -1 : ar > br ? 1 : ai < bi ? -1 : ai > bi ? 1 : 0;
    t = op == vop_lt ? c < 0 : op == vop_le ? c <= 0
      : op == vop_gt ? c > 0 : c >= 0; }        // vop_ge
   tray_put_int(r, p, t ? 1 : 0); }
  else {
   twin_op(op, ar, ai, br, bi, &re, &im);
   rf[2*p] = re; rf[2*p+1] = im; } } }

lvm(lvm_cbin) {
 int op = (int) g->b;
 word a = Sp[0], b = Sp[1];
 bool atray = trayp(a), btray = trayp(b);
 // % and // stay undefined on complex, but the orderings hold ((re,im)
 // lexicographic): a tray follows its scalar
 if (!(atray || twinp(a) || isnum(a)) || !(btray || twinp(b) || isnum(b))
     || op == vop_rem || op == vop_fquot)
  love_musttail return Push(op == vop_eq ? zero : ZeroPoint);   // `=` is boolean: undefined face -> 0, not ()
 bool cmp = op >= vop_lt;
 uintptr_t R, n = bshape(a, b, &R);
 if (n == (uintptr_t) -1) love_musttail return Push(op == vop_eq ? zero : ZeroPoint);   // non-conformant `=` -> 0
 enum tray_type rt = cmp ? love_Z : love_C;              // compare -> i64 mask, else packed complex
 uintptr_t bytes = tray_bytes(rt, R, n);
 Have(b2w(bytes));
 a = Sp[0], b = Sp[1];                                 // re-read post-Have
 struct tray *r = ini_tray((struct tray*) Hp, rt, R); Hp += b2w(bytes);
 bshape_put(r->shape, R, a, b);
 cbin_fill(r, a, b, op, cmp);
 love_musttail return Push(word(r)); }

// w ** z via the principal branch: exp(z * Log w); w == 0 falls out as the IEEE limit
static love_noinline void twin_pow_fill(struct twin *v, word wbase, word zexp) {
 flo_t wr, wi, zr, zi;
 twin_parts(wbase, &wr, &wi); twin_parts(zexp, &zr, &zi);
 flo_t lr = (flo_t) 0.5 * love_log(wr * wr + wi * wi),    // ln|w|
          li = love_atan2(wi, wr),                             // arg w
          pr = zr * lr - zi * li, pi = zr * li + zi * lr,   // z * Log w
          e = love_exp(pr);
 twin_set(v, e * love_cos(pi), e * love_sin(pi)); }

// sin/cos of pi*x, the angle reduced before multiplying by pi so a half-integer
// lands exactly on the axis -- what makes ((/ 1 2) -1) = i bit-exact
static flo_t love_sinpi(flo_t x) {
 intptr_t n = (intptr_t) x; flo_t r = x - (flo_t) n;
 if (r < 0) r += 1, n--;                              // x = n + r, r in (0,1)
 flo_t s = r == (flo_t) 0.5 ? 1
   : love_sin((flo_t) 3.141592653589793 * (r < (flo_t) 0.5 ? r : 1 - r));
 return n & 1 ? -s : s; }
static flo_t love_cospi(flo_t x) {
 intptr_t n = (intptr_t) x; flo_t r = x - (flo_t) n;
 if (r < 0) r += 1, n--;
 flo_t c = r == (flo_t) 0.5 ? 0
   : r < (flo_t) 0.5 ? love_cos((flo_t) 3.141592653589793 * r)
   : -love_cos((flo_t) 3.141592653589793 * (1 - r));
 return n & 1 ? -c : c; }
// finite non-integer? everything at/past 2^mantissa is an integer; nan/inf out.
static bool flo_fracp(flo_t x) {
 flo_t lim = (flo_t) (1ull << (Bits == 64 ? 53 : 24));
 return x > -lim && x < lim && (flo_t) (intptr_t) x != x; }

// (power b e): complex operands take the complex lane; a finite negative real
// base to a non-integer power widens to its principal root instead of nan (pow
// climbs tiers like log). everything else keeps the IEEE real lanes.
lvm(lvm_pow) {
 word a = Sp[0], b = Sp[1];
 if (twinp(a) || twinp(b)) {
  if (!(twinp(a) || isnum(a)) || !(twinp(b) || isnum(b)))
   love_musttail return Push(ZeroPoint);
  Have(twin_req);
  struct twin *v = (struct twin*) Hp;
  Hp += twin_req;
  v->ap = lvm_twinbox;
  twin_pow_fill(v, a, b);
  love_musttail return Push(word(v)); }
 if (isnum(a) && isnum(b)) {
  flo_t ad = toflo(a), bd = toflo(b);
  if (ad < 0 && !__builtin_isinf(ad) && flo_fracp(bd)) {
   flo_t m = love_pow(-ad, bd), re = m * love_cospi(bd), im = m * love_sinpi(bd);
   Have(twin_req);
   *++Sp = mk_twin(&Hp, re, im); love_musttail return Next(1); } }
 g->b = (word) (uintptr_t) (love_pow); love_musttail return Ap(lvm_math2, g); }

// (sqrt x): a complex operand or a negative real widens to the principal root,
// as (** x 1/2) does; a non-negative real stays in the float lane.
lvm(lvm_sqrt) {
 word a = Sp[0];
 if (twinp(a)) {
  Have(twin_req + gem_req);
  word half = mk_gem(&Hp, (flo_t) 0.5);
  struct twin *v = (struct twin*) Hp;
  Hp += twin_req;
  v->ap = lvm_twinbox;
  twin_pow_fill(v, a, half);
  love_musttail return Answer(word(v)); }
 if (isnum(a) && toflo(a) < 0) {
  flo_t m = love_sqrt(-toflo(a));
  Have(twin_req);
  love_musttail return Answer(mk_twin(&Hp, 0, m)); }
 g->b = (word) (uintptr_t) (love_sqrt); love_musttail return Ap(lvm_math1, g); }

// (exp x): a complex operand takes the complex power lane, as (** e x) does.
lvm(lvm_exp) {
 word a = Sp[0];
 if (twinp(a)) {
  Have(twin_req + gem_req);
  word e = mk_gem(&Hp, (flo_t) 2.718281828459045);
  struct twin *v = (struct twin*) Hp;
  Hp += twin_req;
  v->ap = lvm_twinbox;
  twin_pow_fill(v, e, a);
  love_musttail return Answer(word(v)); }
 g->b = (word) (uintptr_t) (love_exp); love_musttail return Ap(lvm_math1, g); }

// fill a packed love_C array with (re = a-element, im = b-element) under broadcast
static love_noinline void twin_build_fill(struct tray *r, word a, word b) {
 uintptr_t R = r->rank, n = tray_nelem(r);
 bool atray = trayp(a), btray = trayp(b);
 struct tray *va = atray ? tray(a) : 0, *vb = btray ? tray(b) : 0;
 struct bcast w; bc_open(&w, va, vb, R, r->shape);
 flo_t sa = atray ? 0 : toflo(a), sb = btray ? 0 : toflo(b),
          *rf = tray_data(r);
 for (uintptr_t p = 0; p < n; p++, bc_step(&w)) {
  intptr_t oa = w.oa, ob = w.ob;
  rf[2*p]   = atray ? tray_get_flo(va, oa) : sa;
  rf[2*p+1] = btray ? tray_get_flo(vb, ob) : sb; } }

// (twin re im): scalars -> a complex box; a real array operand -> a packed love_C
// array (so arg stays elementwise); complex/object array or non-numeric -> zero
lvm(lvm_twin) {
 word a = Sp[0], b = Sp[1];
 bool atray = trayp(a), btray = trayp(b);
 if (atray || btray) {
  if ((atray && tray(a)->type >= love_C) || (btray && tray(b)->type >= love_C)
      || (!atray && !isnum(a)) || (!btray && !isnum(b)))
   love_musttail return Push(ZeroPoint);
  uintptr_t R, n = bshape(a, b, &R);
  if (n == (uintptr_t) -1) love_musttail return Push(ZeroPoint);
  uintptr_t bytes = tray_bytes(love_C, R, n);
  Have(b2w(bytes));
  a = Sp[0], b = Sp[1];                                     // re-read post-Have
  struct tray *r = ini_tray((struct tray*) Hp, love_C, R);
  Hp += b2w(bytes);
  bshape_put(r->shape, R, a, b);
  twin_build_fill(r, a, b);
  love_musttail return Push(word(r)); }
 if (!isnum(a) || !isnum(b)) love_musttail return Push(ZeroPoint);
 flo_t re = toflo(a), im = toflo(b);             // values extracted before alloc
 Have(twin_req);
 *++Sp = mk_twin(&Hp, re, im); love_musttail return Next(1); }

// (twinp x): is x a complex scalar?
op11(lvm_twinp, twinp(Sp[0]) ? putcharm(1) : zero)

// fill r with component `off` (0 = re, 1 = im) of each element; off < 0 is the
// (im realarr) lane -- all zeros
static love_noinline void cpart_fill(struct tray *r, struct tray *v, int off) {
 uintptr_t n = tray_nelem(r);
 if (off < 0) {
  intptr_t *zp = tray_data(r);
  for (uintptr_t p = 0; p < n; p++) zp[p] = 0;
  return; }
 flo_t *rf = tray_data(r), *fp = tray_data(v);
 for (uintptr_t p = 0; p < n; p++) rf[p] = fp[2*p + off]; }

// the array lane of re/im: result carries the operand's shape
static lvm(lvm_cpart) {
 int off = (int) g->b;
 struct tray *v = tray(Sp[0]);
 enum tray_type rt = off < 0 ? love_Z : love_R;
 uintptr_t R = v->rank, n = tray_nelem(v),
           bytes = tray_bytes(rt, R, n);
 Have(b2w(bytes));
 v = tray(Sp[0]);                                           // re-read post-Have
 struct tray *r = ini_tray((struct tray*) Hp, rt, R); Hp += b2w(bytes);
 for (uintptr_t i = 0; i < R; i++) r->shape[i] = v->shape[i];
 cpart_fill(r, v, off);
 love_musttail return Answer(word(r)); }

// (re z) / (im z): the parts, elementwise over an array (a real array is its own
// real part; im of one is fresh zeros); object array or non-number -> zero
lvm(lvm_re) {
 word a = Sp[0], _res;
 if (twinp(a)) {
  flo_t re = twin_re(a);
  Have(box_req);
  emit_gem(_res, re);
  love_musttail return Answer(_res); }
 if (trayp(a)) {
  enum tray_type t = tray(a)->type;
  if (t == love_O) love_musttail return Answer(ZeroPoint);   // a tray is not a number
  if (t != love_C) love_musttail return Next(1);          // a real array is its own real part
  g->b = (word) (0); love_musttail return Ap(lvm_cpart, g); }
 if (isnum(a)) love_musttail return Next(1);            // re of a real is itself
 love_musttail return Answer(ZeroPoint); }

lvm(lvm_im) {
 word a = Sp[0], _res;
 if (twinp(a)) {
  flo_t im = twin_im(a);
  Have(box_req);
  emit_gem(_res, im);
  love_musttail return Answer(_res); }
 if (trayp(a)) {
  enum tray_type t = tray(a)->type;
  if (t == love_O) love_musttail return Answer(ZeroPoint);
  g->b = (word) (t == love_C ? 1 : -1); love_musttail return Ap(lvm_cpart, g); }   // real array -> zeros of its shape
 if (isnum(a)) love_musttail return Answer(putcharm(0));   // im of a real is 0
 love_musttail return Answer(ZeroPoint); }

// the array lane of conj: the operand's shape, each cell's imaginary negated
static lvm(lvm_cconj) {
 struct tray *v = tray(Sp[0]);
 uintptr_t R = v->rank, n = tray_nelem(v),
           bytes = tray_bytes(love_C, R, n);
 Have(b2w(bytes));
 v = tray(Sp[0]);                                           // re-read post-Have
 struct tray *r = ini_tray((struct tray*) Hp, love_C, R); Hp += b2w(bytes);
 for (uintptr_t i = 0; i < R; i++) r->shape[i] = v->shape[i];
 flo_t *rf = tray_data(r), *fp = tray_data(v);
 for (uintptr_t p = 0; p < n; p++) rf[2*p] = fp[2*p], rf[2*p + 1] = -fp[2*p + 1];
 love_musttail return Answer(word(r)); }

// (conj z): complex conjugate, elementwise over an array. conj lifts -- a real r
// becomes ~(r 0), so a scalar always lands in C (the monadic `~`); a real array is
// its own conjugate. object array or non-number -> zero.
lvm(lvm_conj) {
 word a = Sp[0];
 if (twinp(a)) {
  flo_t re = twin_re(a), im = twin_im(a);
  Have(twin_req);
  Sp[0] = mk_twin(&Hp, re, -im);
  love_musttail return Next(1); }
 if (trayp(a)) {
  enum tray_type t = tray(a)->type;
  if (t == love_O) love_musttail return Answer(ZeroPoint);   // a tray is not a number
  if (t != love_C) love_musttail return Next(1);             // a real array is its own conjugate
  love_musttail return Ap(lvm_cconj, g); }
 if (isnum(a)) {
  flo_t re = toflo(a);            // lift a real to ~(r 0)
  Have(twin_req);
  Sp[0] = mk_twin(&Hp, re, 0);
  love_musttail return Next(1); }
 love_musttail return Answer(ZeroPoint); }

// (abs z): magnitude in its own tier; a boxed integer copies with its sign word flipped.
lvm(lvm_abs) {
 word a = Sp[0], _res;
 if (charmp(a)) {
  intptr_t n = getcharm(a);
  Have(box_req);
  emit_int(_res, n < 0 ? (intptr_t) (0 - (uintptr_t) n) : n);
  love_musttail return Answer(_res); }
 if (twinp(a)) {
  flo_t m = twin_mod(a);
  Have(box_req);
  emit_gem(_res, m);
  love_musttail return Answer(_res); }
 if (gemp(a)) {
  flo_t v = gem_get(a); if (v < 0) v = -v;
  Have(box_req);
  emit_gem(_res, v);
  love_musttail return Answer(_res); }
 if (bigp(a)) {
  struct big *x = big(a);
  if (x->slen > 0) love_musttail return Next(1);         // already non-negative
  uintptr_t bytes = big_bytes(x); Have(b2w(bytes));
  x = big(Sp[0]);                         // re-read post-Have
  struct big *y = big(Hp);
  Hp += b2w(bytes);
  memcpy(y, x, bytes); y->slen = -x->slen;           // flip the sign
  love_musttail return Answer(word(y)); }
 if (trayp(a)) {                                       // vector -> scalar: the Euclidean (L2) norm
  struct tray *v = tray(a); uintptr_t i, n = tray_nelem(v);   // sqrt(sum of squares); abs of a
  flo_t s = 0;                                      // complex elem is its 2-vector modulus; love_C sums 2n floats
  if (v->type == love_C) { flo_t *fp = tray_data(v); for (i = 0; i < 2*n; i++) s += fp[i] * fp[i]; }
  else for (i = 0; i < n; i++) { flo_t e = tray_get_flo(v, i); s += e * e; }
  Have(box_req);
  emit_gem(_res, love_sqrt(s));
  love_musttail return Answer(_res); }
 if (tabp(a)) {                                       // table: its key count (so (int (abs t)) == (len t))
  Have(box_req);
  emit_int(_res, (intptr_t) map_len(a));
  love_musttail return Answer(_res); }
 love_musttail return Answer(ZeroPoint); }

// fill f64 array r with arg of each element of v
static love_noinline void carg_fill(struct tray *r, struct tray *v) {
 uintptr_t n = tray_nelem(v);
 flo_t *rf = tray_data(r);
 if (v->type == love_C) { flo_t *fp = tray_data(v);
  for (uintptr_t p = 0; p < n; p++) rf[p] = love_atan2(fp[2*p+1], fp[2*p]); }
 else for (uintptr_t p = 0; p < n; p++) rf[p] = love_atan2(0, tray_get_flo(v, p)); }

// (arg z): phase angle atan2(im, re); elementwise over an array, () on a non-number
lvm(lvm_carg) {
 word a = Sp[0], _res;
 if (twinp(a)) {
  flo_t r = love_atan2(twin_im(a), twin_re(a));
  Have(box_req);
  emit_gem(_res, r);
  love_musttail return Answer(_res); }
 if (trayp(a)) {
  struct tray *v = tray(a);
  if (v->type == love_O) love_musttail return Answer(ZeroPoint);   // object array -> zero
  uintptr_t R = v->rank, n = tray_nelem(v);
  uintptr_t bytes = tray_bytes(love_R, R, n);
  Have(b2w(bytes));
  v = tray(Sp[0]);                                           // re-read post-Have
  struct tray *r = ini_tray((struct tray*) Hp, love_R, R); Hp += b2w(bytes);
  for (uintptr_t i = 0; i < R; i++) r->shape[i] = v->shape[i];
  carg_fill(r, v);
  love_musttail return Answer(word(r)); }
 if (isnum(a)) {                    // 0 for a positive real, pi for a negative one
  flo_t r = love_atan2(0, toflo(a));
  Have(box_req);
  emit_gem(_res, r);
  love_musttail return Answer(_res); }
 love_musttail return Answer(ZeroPoint); }
