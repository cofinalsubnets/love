// arr.c -- the generic-op lane, rng, eq, obin
#include "love.h"
// the math floor is ours on every frontend (moonlibc's math/lm.c)
#if Bits == 64
double lm_sin(double), lm_cos(double), lm_atan2(double, double), lm_asin(double), lm_acos(double),
       lm_sqrt(double), lm_exp(double), lm_log(double), lm_pow(double, double);
#define love_sin   lm_sin
#define love_cos   lm_cos
#define love_atan2 lm_atan2
#define love_asin  lm_asin
#define love_acos  lm_acos
#define love_sqrt  lm_sqrt
#define love_exp   lm_exp
#define love_log   lm_log
#define love_pow   lm_pow
#else
float lm_sinf(float), lm_cosf(float), lm_atan2f(float, float), lm_asinf(float), lm_acosf(float),
      lm_sqrtf(float), lm_expf(float), lm_logf(float), lm_powf(float, float);
#define love_sin   lm_sinf
#define love_cos   lm_cosf
#define love_atan2 lm_atan2f
#define love_asin  lm_asinf
#define love_acos  lm_acosf
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
  Unpack(g); love_musttail return Continue(); }                                      \
 Have(box_req);                                                       \
 emit_int(_res, toint(a) c_op toint(b));                                    \
 love_musttail return Push(_res); }
#define mvm1(n) lvm(lvm_##n) { g->b = (word) (uintptr_t) (love_##n); love_musttail return Ap(lvm_math1, g); }
#define m1(_) _(sin) _(cos) _(tan) _(atan) _(asin) _(acos)   // the real-only unaries
// rng state: a rank-1 tray of four 8-byte limbs, moved by memcpy (tray_put_int truncates on 32-bit)
#define rng_state_len 4
#define rng_payload_bytes (rng_state_len * 8)
#define rng_tray_bytes (sizeof(struct tray) + sizeof(uintptr_t) + rng_payload_bytes)
#define rng_tray_req (b2w(rng_tray_bytes))
// whichever element kind is 8 bytes wide, so love_tray_bytes sees the full payload
#define rng_vt (Bytes == 4 ? love_C : love_Z)
static love_inline flo_t twin_mod(word x) {   // |z|
 flo_t re = twin_re(x), im = twin_im(x);
 return love_sqrt(re * re + im * im); }
static int eqv_at(struct g *g, word a, word b, word *base, word *top);
static lvm_t lvm_band_slow, lvm_bor_slow, lvm_bxor_slow, lvm_mul_cart, lvm_mul_rep;

// `*` repeat lane: sequence * n is |n| copies joined; an inexact count answers (), which
// composes since those classes are closed under *
static lvm(lvm_mul_rep) {
 word a = Sp[0], b = Sp[1];
 bool aseq = strp(a) || chainp(a);
 word seq = aseq ? a : b, cnt = aseq ? b : a;
 if ((!strp(seq) && !chainp(seq)) || (!charmp(cnt) && !bigp(cnt)))
  love_musttail return Push(ZeroPoint);
 uintptr_t n;
 if (charmp(cnt)) {
   intptr_t v = getcharm(cnt);
   n = (uintptr_t) (v < 0 ? -v : v); }
 else n = (uintptr_t) maxcharm;                      // |big|: refused below
 // the apcap rule (prel.l): refused here, as Hp + n in Have() can wrap and read as room
 if (n > ((uintptr_t) 1 << 40)) love_musttail return Push(ZeroPoint);
 if (chainp(seq)) {
  if (!n) love_musttail return Push(ZeroPoint);
  uintptr_t m = llen(seq), total = mulsat(m, n);
  if (total > words_max / Width(struct chain)) love_musttail return Push(ZeroPoint);
  Have(total * Width(struct chain));
  seq = chainp(Sp[0]) ? Sp[0] : Sp[1];                // re-read post-GC
  struct chain *base = two(Hp), *w = base;
  Hp += total * Width(struct chain);
  for (uintptr_t i = 0; i < n; i++)
   for (word l = seq; chainp(l); l = B(l), w++) ini_chain(w, A(l), word(w + 1));
  (w - 1)->b = ZeroPoint;
  love_musttail return Push(word(base)); }
 struct str *src = str(seq);
 uintptr_t sl = src->len, total = mulsat(sl, n);
 if (!total) love_musttail return Push(EmptyString);
 if (total > words_max) love_musttail return Push(ZeroPoint);   // no heap holds it
 uintptr_t req = str_width(total);
 Have(req);
 src = str(strp(Sp[0]) ? Sp[0] : Sp[1]);             // re-read post-GC
 struct str *z = ini_str(str(Hp), total);
 Hp += req;
 for (uintptr_t i = 0; i < n; i++) memcpy(txt(z) + i * sl, txt(src), sl);
 *++Sp = word(z);
 Ip++; love_musttail return Continue(); }

// `*` cartesian lane: chain * chain, the outer loop over the left so right-distributivity holds
static lvm(lvm_mul_cart) {
 word a = Sp[0], b = Sp[1];
 if (!chainp(a) || !chainp(b)) love_musttail return Push(ZeroPoint);
 uintptr_t m = llen(a), n = llen(b), pairs = mulsat(m, n);
 if (!pairs) love_musttail return Push(ZeroPoint);
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

// the apply lane: sequences and trays index, sequences juxtapose, numbers are church numerals,
// and anything with nothing to answer with answers ()

// string x charm -> byte by index or (); x string or name -> concat
lvm(data_string_apply) {
 bool pt = namep(word(Ip));
 struct str *na = pt ? nom_str(g, word(Ip)) : str(word(Ip)),
               *nb = strp(Sp[0]) ? str(Sp[0]) : namep(Sp[0]) ? nom_str(g, Sp[0]) : NULL;
 if (nb) {
  bool mk = pt && namep(Sp[0]);                         // point + point -> the interned point
  uintptr_t m = na->len, n = nb->len, req = str_width(m + n);
  if (!(m + n)) {
   Ip = cell(*++Sp);
   *Sp = mk ? ZeroPoint : EmptyString;
   love_musttail return Continue(); }  // no empty string is ever allocated
  Have(req + (mk ? intern_reserve(g) : 0));
  na = pt ? nom_str(g, word(Ip)) : str(word(Ip));       // re-read post-GC
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

// (p x): a point is its own constant
lvm(data_sym_apply) {
 word self = word(Ip);
 Ip = cell(*++Sp), *Sp = self;
 love_musttail return Continue(); }

// (n x): church numerals for the boxed tower, lvm_numap's frame
lvm(data_num_apply) {
 Have(2);
 word h = hot_hook(g->hook[hook_numap]);
 word n = word(Ip), x = Sp[0], ret = Sp[1], *dst = Sp - 2;
 dst[0] = n, dst[1] = h, dst[2] = x, dst[3] = ret;
 Sp = dst, Ip = cell(numap_drive);
 love_musttail return Continue(); }

// (l k): the kth element or (); (l m): the append, as (+ l m); else ()
lvm(data_pair_apply) {
 if (chainp(Sp[0])) {
  uintptr_t n = llen(word(Ip));
  Have(n * Width(struct chain));
  struct chain *base = two(Hp), *w = base;
  Hp += n * Width(struct chain);
  for (word l = word(Ip); chainp(l); l = B(l), w++) ini_chain(w, A(l), word(w + 1));
  (w - 1)->b = Sp[0];                        // a chain is never empty
  Ip = cell(*++Sp); *Sp = word(base); love_musttail return Continue(); }
 word v = ZeroPoint;
 if (oddp(Sp[0])) {
  word k = getcharm(Sp[0]), l = word(Ip);
  if (k >= 0) { while (k-- > 0 && chainp(l)) l = B(l);
                if (chainp(l)) v = A(l); } }
 Ip = cell(*++Sp); *Sp = v; love_musttail return Continue(); }

// the + and * dispatch matrices, generated from mx.l with the rocq model mx.v: edit mx.l, not mx.h
#include "mx.h"

// any value -> the kind it dispatches as; a tray dispatches by element tier
enum q kind(word x) {
 if (charmp(x)) return KCharm;
 if (!datp(x)) return tabp(x) ? KTablet : KHot;
 enum d r = typ(x);
 if (r == DTray) return (enum q) (KTrayZ + tray(x)->type);
 return kind_of_d[r]; }

lvm(lvm_add) {
 word a = Sp[0], b = Sp[1]; intptr_t t;
 if (charmp(a) && charmp(b)
     && !__builtin_add_overflow((intptr_t) getcharm(a), (intptr_t) getcharm(b), &t)
     && t >= mincharm && t <= maxcharm)
  love_musttail return Push(putcharm(t));
 // a point is the identity, two join to the greater: mirrors lvm_bin_unit exactly
 if (nomp(a)) love_musttail return Push(nomp(b) && love_mint_cmp(g, a, b) > 0 ? a : b);
 if (nomp(b)) love_musttail return Push(a);
 love_musttail return Ap(add_mx[kind(a)][kind(b)], g); }

lvm(lvm_mul) {
 word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) { intptr_t t;
  if (!__builtin_mul_overflow((intptr_t) getcharm(a), (intptr_t) getcharm(b), &t)
      && t >= mincharm && t <= maxcharm)
   love_musttail return Push(putcharm(t)); }
 // a point annihilates, as the matrix's lvm_0 does
 if (nomp(a) || nomp(b)) love_musttail return Push(ZeroPoint);
 love_musttail return Ap(mul_mx[kind(a)][kind(b)], g); }

avm_div(fquot, /)
avm_div(rem, %)
// `/` stays exact only when b divides a; the INT_MIN/-1 guard precedes the UB `%`
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

// bitwise and/or/xor: two odds stay odd under & and |, ^ clears the tag. integers only
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

// >> : a floor shift; a big, a negative count or one past the width takes the slow lane
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

// << : x * 2^k, promoting; the word lane only where shifting back gives x again
lvm(lvm_bsl) { word a = Sp[0], b = Sp[1], _res;
 avm_unit(a, b);
 if (trayp(a) || trayp(b)) { g->b = (word) (vop_bsl); love_musttail return Ap(lvm_vbin, g); }
 if (!intp(a) || !intp(b)) love_musttail return Push(ZeroPoint);
 if (charmp(a) && charmp(b)) { intptr_t x = getcharm(a), k = getcharm(b);
  if (k >= 0 && k < Bits) { intptr_t r = (intptr_t) ((uintptr_t) x << k);
   if ((r >> k) == x) { Have(box_req); emit_int(_res, r); love_musttail return Push(_res); } } }
 LvmResume(g, big_shift, vop_bsl) }

op(lvm_charmp, 1, oddp(Sp[0]) ? putcharm(1) : zero)
// (nil? x): ($ x <= 0), asked as ? and aall do (leaf_nilp)
lvm(lvm_nilp) {
 if (__builtin_expect(!leafp(Sp[0]), 0)) love_musttail return Ap(lvm_measure, g);
 Sp[0] = leaf_nilp(Sp[0]) ? putcharm(1) : zero; Ip += 1; love_musttail return Continue(); }

static lvm(lvm_math1) {
 flo1 fn = (flo1) (uintptr_t) g->b;
 word a = Sp[0];
 if (trayp(a)) {                               // a twin tray is undefined
  if (tray(a)->type == love_C) love_musttail return Answer(ZeroPoint);
  g->b = (word) (uintptr_t) (fn); love_musttail return Ap(lvm_vmap1, g); }
 if (!isnum(a)) love_musttail return Answer(ZeroPoint);
 flo_t ad = toflo(a), rd = fn(ad);
 Have(gem_req);
 Sp[0] = mk_gem(&Hp, rd); love_musttail return Next(1); }

static lvm(lvm_math2) {
 flo2 fn = (flo2) (uintptr_t) g->b;
 word a = Sp[0], b = Sp[1];
 if (trayp(a) || trayp(b)) {
  if ((trayp(a) && tray(a)->type == love_C) || (trayp(b) && tray(b)->type == love_C))
   love_musttail return Push(ZeroPoint);
  g->b = (word) (uintptr_t) (fn); love_musttail return Ap(lvm_vmap2, g); }
 if (!isnum(a) || !isnum(b)) love_musttail return Push(ZeroPoint);
 flo_t ad = toflo(a), bd = toflo(b), rd = fn(ad, bd);
 Have(gem_req);
 *++Sp = mk_gem(&Hp, rd); love_musttail return Next(1); }


m1(mvm1)
lvm(lvm_atan2) { g->b = (word) (uintptr_t) (love_atan2); love_musttail return Ap(lvm_math2, g); }

// (log x): a negative real or a complex widens to the principal value; a tray stays float
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

// rng: xoshiro256++ seeded by SplitMix64, not a CSPRNG. C holds no state: turn/turnf copy
// the state and answer (value . new-state)

static uint64_t rotl64(uint64_t x, int k) {
 return (x << k) | (x >> (64 - k)); }

// the scratch lives in these noinline helpers: a &s in an ap defeats the sibcall
static love_noinline uint64_t rng_step(void *payload) {
 uint64_t s[4];
 memcpy(s, payload, sizeof s);
 uint64_t const result = rotl64(s[0] + s[3], 23) + s[0], t = s[1] << 17;
 s[2] ^= s[0]; s[3] ^= s[1]; s[1] ^= s[2]; s[0] ^= s[3];
 s[2] ^= t; s[3] = rotl64(s[3], 45);
 memcpy(payload, s, sizeof s);
 return result; }

// SplitMix64; the all-zero state is xoshiro's fixed point
static love_noinline void rng_seed_into(void *payload, uint64_t seed) {
 uint64_t s[4], x = seed;
 for (int i = 0; i < rng_state_len; i++) {
  uint64_t z = (x += (uint64_t) 0x9e3779b97f4a7c15);
  z = (z ^ (z >> 30)) * (uint64_t) 0xbf58476d1ce4e5b9;
  z = (z ^ (z >> 27)) * (uint64_t) 0x94d049bb133111eb;
  s[i] = z ^ (z >> 31); }
 if (!(s[0] | s[1] | s[2] | s[3])) s[0] = 1;
 memcpy(payload, s, sizeof s); }

static flo_t u64_to_unit(uint64_t u) {
#if Bits >= 64
 return (flo_t) (u >> 11) * (flo_t) 0x1.0p-53;
#else
 return (flo_t) (uint32_t) (u >> 40) * (flo_t) 0x1.0p-24f;
#endif
}

// no &local, so an inlining caller keeps its tail call
static void rng_seed(struct tray *v, uint64_t seed) {
 ini_tray(v, rng_vt, 1);
 v->shape[0] = rng_state_len;
 rng_seed_into(tray_data(v), seed); }

static bool rng_state_p(word x) {
 return packp(x) && tray(x)->rank == 1 && tray(x)->type == rng_vt
        && tray(x)->shape[0] == rng_state_len; }

// caller holds Have(rng_tray_req)
static struct tray *rng_copy(word **hp, struct tray *src) {
 struct tray *v = (struct tray*) *hp;
 *hp += rng_tray_req;
 ini_tray(v, rng_vt, 1);
 v->shape[0] = rng_state_len;
 memcpy(tray_data(v), tray_data(src), rng_payload_bytes);
 return v; }

// out of line, so limb[] never forces a frame in lvm_turn (make vmret)
static love_noinline word rng_canon(struct g *g, uint64_t r) {
 love_limb limb[64 / limb_bits]; int nl = 0;
 for (int i = 0; (size_t) i * limb_bits < 64; i++) limb[i] = (love_limb) (r >> (i * limb_bits)), nl = i + 1;
 return big_canon(&g->hp, limb, nl, false); }

// (wheel n): a fresh state seeded from n, a non-fixnum from 0
lvm(lvm_wheel) {
 word n = Sp[0];
 uint64_t seed = charmp(n) ? (uint64_t) (intptr_t) getcharm(n) : 0;
 Have(rng_tray_req);
 struct tray *v = (struct tray*) Hp; Hp += rng_tray_req;
 rng_seed(v, seed);
 love_musttail return Answer(word(v)); }

// (turn st): (value . st'), value a fixed 62 bits so a seed answers alike on every target
#define rng_draw_mask (((uint64_t) 1 << 62) - 1)              // 62 bits = 64-bit maxcharm
#define rng_draw_req  (Width(struct big) + b2w((64 / limb_bits) * sizeof(love_limb)))
lvm(lvm_turn) {
 word st = Sp[0];
 if (!rng_state_p(st)) love_musttail return Answer(ZeroPoint);
 Have(rng_tray_req + rng_draw_req + Width(struct chain));
 st = Sp[0];
 struct tray *v = rng_copy(&Hp, tray(st));
 uint64_t r = rng_step(tray_data(v)) & rng_draw_mask;
 Pack(g);
 word val = rng_canon(g, r);
 Unpack(g);
 struct chain *p = (struct chain*) Hp; Hp += Width(struct chain);
 ini_chain(p, val, word(v));
 love_musttail return Answer(word(p)); }

// (turnf st): (float in [0,1) . st')
lvm(lvm_turnf) {
 word st = Sp[0], _res;
 if (!rng_state_p(st)) love_musttail return Answer(ZeroPoint);
 Have(rng_tray_req + box_req + Width(struct chain));
 st = Sp[0];
 struct tray *v = rng_copy(&Hp, tray(st));
 uint64_t r = rng_step(tray_data(v));
 flo_t u = u64_to_unit(r);
 emit_gem(_res, u);
 struct chain *p = (struct chain*) Hp; Hp += Width(struct chain);
 ini_chain(p, _res, word(v));
 love_musttail return Answer(word(p)); }

// eq. two functions are equal when their threads are: a pointer back into its own thread by
// its offset, other heap words pushed for the worklist. 1 so far, 0 unequal, -1 out of
// region; a yield word (a parked continuation) is unequal
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
  if ((x | y) & 1) return 0;
  bool sa = x >= ha && x <= ea, sb = y >= hb && y <= eb;
  // a native whose twin is this thread points back into it too
  if (!sa) { word m = fn_meaning(c, x); if (m >= ha && m <= ea) x = m, sa = 1; }
  if (!sb) { word m = fn_meaning(c, y); if (m >= hb && m <= eb) y = m, sb = 1; }
  if (sa || sb) {
   if (!sa || !sb || x - a != y - b) return 0;
   continue; }
  if (!in_heap(c, x) || !in_heap(c, y)) return 0;        // an op, a nif, an immortal
  if (hi - w < 2) return -1;
  *w++ = x, *w++ = y; }
 return *wp = w, 1; }

// the value hash: chains spine with their cars on the worklist, leaves go to hash_leaf, and
// an object tray's cells fold like cars. spent, it answers 0 with the room it wanted in g->walk
uintptr_t hash_at(struct g *g, intptr_t x0, word *base, word *end) {
 word *sw = base, x = x0, src = 0;
 uintptr_t h = mix, t = 0;
 bool fold = chainp(x);
 for (;;) {
  while (chainp(x)) {
   if (sw == end) return walk_short(g, base, end, 1), 0;
   h = (h ^ mix) * mix;
   *sw++ = A(x), x = B(x); }
  if (hash_leaf(g, x, &t, &src) == 3) {                   // an object tray: the header already in t
   struct tray *v = tray(src);
   uintptr_t n = tray_nelem(v);
   if ((uintptr_t) (end - sw) < n) return walk_short(g, base, end, n), 0;
   for (uintptr_t i = n; i--;) *sw++ = tray_get_obj(v, i);
   fold = true; }
  if (!fold) return t;
  h = (h ^ t) * mix;
  if (sw == base) return h;
  x = *--sw; } }

// one step of the walk: settled, or which descent it takes
enum eqstep { eq_no, eq_yes, eq_chain, eq_coin, eq_fn, eq_tray };
static enum eqstep eqv_leaf(struct g *g, word a, word b) {
 if (a == b) return eq_yes;
 if (coinp(a) || coinp(b))
  return coinp(a) && coinp(b) && coin_kind(a) == coin_kind(b) ? eq_coin : eq_no;
 if (evenp(a) && evenp(b) && !datp(a) && !datp(b)) return eq_fn;
 // a number never equals a closure: bridging 0/1 to church lambdas breaks congruence
 if (((a | b) & 1) || !datp(a) || !datp(b) || typ(a) != typ(b)) return eq_no;
 switch (typ(a)) {
  default: return eq_no;
  case DChain: return eq_chain;
  case DTray: {
   // an object tray's cells decide, never a memcmp of its pointers
   if (objtrayp(a) || objtrayp(b)) {
    struct tray *va = tray(a), *vb = tray(b);
    if (!objtrayp(a) || !objtrayp(b) || va->rank != vb->rank) return eq_no;
    for (uintptr_t k = 0; k < va->rank; k++) if (va->shape[k] != vb->shape[k]) return eq_no;
    return eq_tray; }
   size_t la = love_tray_bytes(tray(a)), lb = love_tray_bytes(tray(b));
   return la == lb && !memcmp(tray(a), tray(b), la) ? eq_yes : eq_no; }
  case DGem: return gem_get(a) == gem_get(b) ? eq_yes : eq_no;
  case DTwin: return twin_re(a) == twin_re(b) && twin_im(a) == twin_im(b) ? eq_yes : eq_no;
  case DBig: { struct big *x = big(a), *y = big(b);
   size_t nb = (size_t) (x->slen < 0 ? -x->slen : x->slen) * sizeof(love_limb);
   return x->slen == y->slen && !memcmp(x->limb, y->limb, nb) ? eq_yes : eq_no; }
  case DString:
   return len(a) == len(b) && !memcmp(txt(a), txt(b), len(a)) ? eq_yes : eq_no; } }

// the region holds the function pairs taken as equal at its base (nseen slots), so a pair met
// again holds rather than walks forever, and the worklist over them; either spent, it answers
// -1 with the room it wanted in g->walk. the walk never recurs: this is its only C frame
static int eqv_at(struct g *g, word a, word b, word *base, word *top) {
 uintptr_t nseen = base ? (uintptr_t) (top - base) / 8 : 0, ns = 0;
 word *hi = top, *w = base ? base + 2 * nseen : 0;
 int r = 0;
 struct g *c = core_of(g);
#define eqv_short(k) { walk_short(g, base, hi, (k)); r = -1; goto out; }
#define eqv_room(k) if ((uintptr_t) (hi - w) < (k)) eqv_short(k)
 for (;;) {
  switch (eqv_leaf(g, a, b)) {
   case eq_no: goto out;
   case eq_yes: break;
   case eq_coin: a = coin_load(a), b = coin_load(b); continue;
   case eq_chain:
    eqv_room(2);
    *w++ = B(a), *w++ = B(b), a = A(a), b = A(b);
    continue;
   case eq_tray: {                         // shape settled above
    struct tray *va = tray(a), *vb = tray(b);
    uintptr_t n = tray_nelem(va);
    eqv_room(2 * n);
    for (uintptr_t i = 0; i < n; i++) *w++ = tray_get_obj(va, i), *w++ = tray_get_obj(vb, i);
    break; }
   // a partial is its base and captures pairwise, another function its thread; a carrier
   // (tablet, cask, port) is itself alone
   case eq_fn: {
    a = fn_meaning(c, a), b = fn_meaning(c, b);
    if (a == b) break;
    if (!in_heap(c, a) || !in_heap(c, b)) goto out;
    union u *ka = cell(a), *kb = cell(b);
    if (fn_carrier(ka) || fn_carrier(kb)) goto out;
    bool pa = fn_partialp(ka), pb = fn_partialp(kb);
    if (pa || pb) {
     int na, nb;
     if (!pa || !pb) goto out;
     union u *ba = fn_base(ka, &na), *bb = fn_base(kb, &nb);
     if (na != nb) goto out;
     eqv_room((uintptr_t) 2 * (na + 1));
     for (int i = 0; i < na; i++) *w++ = fn_arg(ka, i, na), *w++ = fn_arg(kb, i, nb);
     a = (word) ba, b = (word) bb; continue; }
    for (word *s = base; s && s < base + 2 * ns; s += 2)
     if (s[0] == a && s[1] == b) goto held;
    if (ns == nseen) eqv_short(2)
    base[2 * ns] = a, base[2 * ns + 1] = b, ns++;
    { int f = fn_eq(c, a, b, &w, hi);
      if (f < 0) eqv_short(64)
      if (f == 0) goto out; }
   held:
    break; } }
  if (w == (base ? base + 2 * nseen : 0)) { r = 1; goto out; }   // drained
  b = *--w, a = *--w; }
#undef eqv_room
#undef eqv_short
 out:
 return r; }

// for a map probe and a comparator, mid-reservation: nothing may allocate on the heap, so the
// walk takes the gap, and spent answers 0 with g->walk set, for its op to run again
love_noinline bool eqv(struct g *g, word a, word b) {
 enum eqstep s = eqv_leaf(g, a, b);
 if (s == eq_yes || s == eq_no) return s == eq_yes;
 word *top, *base = gap(g, &top);
 return eqv_at(g, a, b, base, top) > 0; }

// whole-tray equality, a boolean: same shape, cells equal across numeric tiers; an object
// tray never equals a numeric one
static love_noinline int tray_eq(struct g *g, word a, word b, word *base, word *top) {
 if (!trayp(a) || !trayp(b)) return 0;
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

// the whole of `=`, shared by lvm_eq and lvm_elem: numbers promote across the tower, then
// eql -- looser than eqv, where keys 3 and 3.0 stay apart. eql alone is not `=`: it answers 0
// for (= (/// 1 1) 1). -1 the region ran out
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

lvm(lvm_eq) {
 word a = Sp[0], b = Sp[1];
 // identity settles two charms or a point, fusing a following `?`
 if (__builtin_expect((charmp(a) && charmp(b)) || nomp(a) || nomp(b), 1)) {
  bool r = a == b;
  if (Ip[1].ap == lvm_cond) { Sp += 2; Ip = r ? Ip + 3 : Ip[2].m; love_musttail return Continue(); }
  love_musttail return Answerp(1, r ? putcharm(1) : zero); }
 // a tray: elementwise, a mask
 if (trayp(a) || trayp(b)) { g->b = (word) vop_eq; love_musttail return Ap(lvm_vbin, g); }
 // a coin whose kind spells '=: its method, either side; distinct kinds are unequal
 if (coinp(a) || coinp(b)) {
  word f = coinp(a) && coinp(b) && coin_kind(a) != coin_kind(b) ? ZeroPoint
         : kind_get(g, coin_kind(coinp(a) ? a : b), KnEq);
  if (f != ZeroPoint) {
   Have(2);
   a = Sp[0], b = Sp[1], f = kind_get(g, coin_kind(coinp(a) ? a : b), KnEq);
   word *dst = Sp - 2;
   dst[0] = a, dst[1] = f, dst[2] = b, dst[3] = word(Ip + 1);
   Sp = dst; Ip = (union u*) numap_drive; love_musttail return Continue(); } }
 Pack(g);                                                 // the gap is true only packed
 word *top, *base = gap(g, &top);
 int r = eq_value(g, a, b, base, top);
 WalkAgain();
 if (r < 0) love_musttail return Ap(_lvm_ghelp, g);
 Sp[1] = r ? putcharm(1) : zero;
 love_musttail return Nextp(1, 1); }

// (== a b): word identity
lvm(lvm_same) {
 Sp[1] = Sp[0] == Sp[1] ? putcharm(1) : zero;
 love_musttail return Nextp(1, 1); }

// (elem x l): x `=` some element of a chain, or byte of a text -- a charm, never a 1-byte text.
// the walk never collects, so l is safe across a compare. a nom is settled once, by identity
lvm(lvm_elem) { word x = Sp[0], l = Sp[1];
 if (!chainp(l) && strp(l)) {
  if (!oddp(x)) love_musttail return Push(zero);
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
 Pack(g);                                                 // the gap is true only packed
 word *top, *base = gap(g, &top);
 for (; chainp(l) && !nomp(l); l = B(l)) {
  int r = eq_value(g, x, A(l), base, top);
  WalkAgain();
  if (r < 0) love_musttail return Ap(_lvm_ghelp, g);
  if (r) love_musttail return Push(putcharm(1)); }
 love_musttail return Push(zero); }

// (eleq x l): elem under `==`
lvm(lvm_eleq) { word x = Sp[0], l = Sp[1];
 for (; chainp(l) && !nomp(l); l = B(l))
  if (A(l) == x) love_musttail return Push(putcharm(1));
 love_musttail return Push(zero); }

// obin, the object-tray elementwise lane: every cell through the promoting scalar ops, so it
// is exact where the typed lanes wrap. it allocates, so it runs packed and re-fetches

// one element op, allocating via *fp; zero for a non-numeric or complex operand
static word obin_elem(struct g **fp, int op, word a, word b) {
 if (op == vop_eq) {
  word *top, *base = gap(*fp, &top);
  int r = eq_value(*fp, a, b, base, top);
  if (r < 0 && !(*fp)->walk) return *fp = encode(*fp, status_scare), zero;
  return r > 0 ? putcharm(1) : zero; }                         // spent: obin_run takes the room
 if (op >= vop_lt) {
  if (!isnum(a) || !isnum(b)) return zero;       // a twin is unordered
  intptr_t t = (gemp(a) || gemp(b)) ? vcmp_flo(op, toflo(a), toflo(b))
             : (bigp(a) || bigp(b)) ? vcmp_int(op, big_cmp(a, b), 0)
                                    : vcmp_int(op, toint(a), toint(b));
  return t ? putcharm(1) : zero; }
 if (!isnum(a) || !isnum(b)) return zero;
 struct g *g = *fp;
 if (gemp(a) || gemp(b) || (op == vop_fquot && b == putcharm(0))) {   // a float, or `// 0` as the scalar answers
  flo_t r = vop_flo(op, toflo(a), toflo(b));  // read before the have, which moves a float box
  if (!ok(g = have(g, gem_req))) return *fp = g, zero;
  *fp = g;
  return mk_gem(&g->hp, r); }
 if (!bigp(a) && !bigp(b)) {
  intptr_t av = toint(a), bv = toint(b), t; bool of;
  switch (op) {
   case vop_fquot:                                        // `/` is the hook's (lvm_obin)
                  of = (av == INTPTR_MIN && bv == -1); t = of ? 0 : av / bv; break;
   case vop_rem:  if (bv == 0) return a;                     // a % 0 = a
                  of = (av == INTPTR_MIN && bv == -1); t = of ? 0 : av % bv; break;
   case vop_sub:  of = __builtin_sub_overflow(av, bv, &t); break;
   case vop_mul:  of = __builtin_mul_overflow(av, bv, &t); break;
   case vop_max:  of = false; t = av > bv ? av : bv; break;
   case vop_min:  of = false; t = av < bv ? av : bv; break;
   default:       of = __builtin_add_overflow(av, bv, &t); break; }   // vop_add
  if (!of) {
   if (t >= mincharm && t <= maxcharm) return putcharm(t);
   if (!ok(g = have(g, wbig_req))) return *fp = g, zero;
   *fp = g;
   return mk_wbig(&g->hp, t); } }
 if (op == vop_rem && b == putcharm(0)) return a;   // a big divides by no limbs
 if (op == vop_max || op == vop_min) {
  intptr_t c = big_cmp(a, b);
  return (op == vop_max ? c >= 0 : c <= 0) ? a : b; }
 // big_binop pops one and advances ip: restore ip, pop the result
 if (!ok(g = push(g, 2, a, b))) return *fp = g, zero;
 union u *ip0 = g->ip;
 avec(g, ip0, g = big_binop(g, op));
 if (!ok(g)) return *fp = g, zero;
 g->ip = ip0;
 word r = g->sp[0]; g->sp++;
 return *fp = g, r; }

// widen the numeric tray at g->sp[slot] to a love_O copy, re-fetching after every box
static struct g *tray_to_obj(struct g *g, int slot) {
 struct tray *src = tray(g->sp[slot]);
 uintptr_t R = src->rank, n = tray_nelem(src);
 uintptr_t bytes = tray_bytes(love_O, R, n);
 if (!ok(g = have(g, b2w(bytes)))) return g;
 src = tray(g->sp[slot]);
 struct tray *dst = (struct tray*) g->hp; g->hp += b2w(bytes);
 ini_tray(dst, love_O, R);
 for (uintptr_t i = 0; i < R; i++) dst->shape[i] = src->shape[i];
 for (uintptr_t i = 0; i < n; i++) tray_put_obj(dst, i, zero);   // the gc may see it
 if (!ok(g = push(g, 1, word(dst)))) return g;             // sp[0]=dst, src now at slot+1
 for (uintptr_t i = 0; i < n; i++) {
  struct tray *s = tray(g->sp[slot + 1]);
  word v;
  if (s->type >= love_R) {
   flo_t e = tray_get_flo(s, i);
   if (!ok(g = have(g, gem_req))) return g;
   v = mk_gem(&g->hp, e); }
  else {
   intptr_t e = tray_get_int(s, i);
   if (e >= mincharm && e <= maxcharm) v = putcharm(e);
   else { if (!ok(g = have(g, wbig_req))) return g;
    v = mk_wbig(&g->hp, e); } }
  tray_put_obj(tray(g->sp[0]), i, v);
  gen_wb(g, g->sp[0], v); }                                    // see obin_run
 word d = g->sp[0]; g->sp++; g->sp[slot] = d;
 return g; }

// lvm_obin's packed body: at least one operand a love_O tray
static struct g *obin_run(struct g *g, int op) {
 word a = g->sp[0], b = g->sp[1];
 bool atray = trayp(a), btray = trayp(b);
 if (atray && tray(a)->type != love_O) { if (!ok(g = tray_to_obj(g, 0))) return g; }
 if (btray && tray(g->sp[1])->type != love_O) { if (!ok(g = tray_to_obj(g, 1))) return g; }   // b may have moved
 a = g->sp[0], b = g->sp[1], atray = trayp(a), btray = trayp(b);
 uintptr_t R, n = bshape(a, b, &R), shp[maxrank];
 if (n == (uintptr_t) -1) {                                    // non-conforming
  g->sp[1] = zero, g->sp++, g->ip = (union u*) g->ip + 1; return g; }
 bshape_put(shp, R, a, b);
 uintptr_t bytes = tray_bytes(love_O, R, n);
 if (!ok(g = have(g, b2w(bytes)))) return g;
 struct tray *r = (struct tray*) g->hp; g->hp += b2w(bytes);
 ini_tray(r, love_O, R);
 for (uintptr_t k = 0; k < R; k++) r->shape[k] = shp[k];
 for (uintptr_t p = 0; p < n; p++) tray_put_obj(r, p, zero);     // before any gc
 if (!ok(g = push(g, 1, word(r)))) return g;               // sp: [0]=r [1]=a [2]=b
 struct bcast w; bc_open(&w, atray ? tray(g->sp[1]) : 0, btray ? tray(g->sp[2]) : 0, R, shp);
 for (uintptr_t p = 0; p < n; p++, bc_step(&w)) {
  intptr_t oa = w.oa, ob = w.ob;
  word res;
  for (;;) {                                                     // a walk spent: the room, and the cell again
   word ae = atray ? tray_get_obj(tray(g->sp[1]), oa) : g->sp[1],  // scalar operand re-read each step
        be = btray ? tray_get_obj(tray(g->sp[2]), ob) : g->sp[2];
   res = obin_elem(&g, op, ae, be);
   if (!ok(g)) return g;
   if (!g->walk) break;
   if (!ok(g = walk_room(g))) return g; }
  tray_put_obj(tray(g->sp[0]), p, res);
  gen_wb(g, g->sp[0], res); }                                  // a minor mid-loop may tenure r
 g->sp[2] = g->sp[0], g->sp += 2, g->ip += 1;
 return g; }

// the C lane takes plain numbers; anything else, and `/`, goes whole to hook_obin
static bool obj_plain(word x) {
 if (!trayp(x)) return isnum(x);                     // a coin or a twin against the tray
 if (tray(x)->type != love_O) return true;
 struct tray *v = tray(x);
 for (uintptr_t i = 0, n = tray_nelem(v); i < n; i++) if (!isnum(tray_get_obj(v, i))) return false;
 return true; }

// hook_obin's frame [k hook as bs sh ret]: the cells as C broadcasts them in two lists, the
// shape in a third. the caller checked they conform
static struct g *obin_frame(struct g *g, int op) {
 if (!ok(g = push(g, 4, zero, zero, zero, zero))) return g;   // operands now at sp[4], sp[5]
 if (trayp(g->sp[4]) && tray(g->sp[4])->type != love_O && !ok(g = tray_to_obj(g, 4))) return g;
 if (trayp(g->sp[5]) && tray(g->sp[5])->type != love_O && !ok(g = tray_to_obj(g, 5))) return g;
 uintptr_t R, n = bshape(g->sp[4], g->sp[5], &R), shp[maxrank];
 if (!ok(g = have(g, (2 * n + R) * chain_req))) return g;
 word a = g->sp[4], b = g->sp[5];
 bool atray = trayp(a), btray = trayp(b);
 bshape_put(shp, R, a, b);
 struct chain *as = (struct chain*) g->hp, *bs = as + n, *sh = bs + n;
 g->hp += (2 * n + R) * chain_req;
 struct bcast w; bc_open(&w, atray ? tray(a) : 0, btray ? tray(b) : 0, R, shp);
 for (uintptr_t p = 0; p < n; p++, bc_step(&w)) {
  ini_chain(as + p, atray ? tray_get_obj(tray(a), w.oa) : a, p + 1 < n ? word(as + p + 1) : ZeroPoint);
  ini_chain(bs + p, btray ? tray_get_obj(tray(b), w.ob) : b, p + 1 < n ? word(bs + p + 1) : ZeroPoint); }
 for (uintptr_t k = 0; k < R; k++) ini_chain(sh + k, putcharm(shp[k]), k + 1 < R ? word(sh + k + 1) : ZeroPoint);
 g->sp[0] = putcharm(op), g->sp[1] = hot_hook(g->hook[hook_obin]);
 g->sp[2] = n ? word(as) : ZeroPoint, g->sp[3] = n ? word(bs) : ZeroPoint;
 g->sp[4] = R ? word(sh) : ZeroPoint, g->sp[5] = word(g->ip + 1);
 return g; }

lvm(lvm_obin) {
 int op = (int) g->b;
 if (op == vop_eq || (op != vop_quot && obj_plain(Sp[0]) && obj_plain(Sp[1]))) LvmResume(g, obin_run, op)
 uintptr_t R;
 if (bshape(Sp[0], Sp[1], &R) == (uintptr_t) -1) { Sp[1] = zero; love_musttail return Nextp(1, 1); }   // as obin_run
 LvmPack(g, obin_frame, op);
 Unpack(g);
 Ip = (union u*) obin_drive;
 love_musttail return Continue(); }

// love_O reduction (kind: 0 sum, 1 prod, 2 max, 3 min) of g->sp[0]
struct g *ored(struct g *g, int kind) {
 struct tray *v = tray(g->sp[0]);
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 if (kind >= 2) {                                              // no alloc
  if (!n) { g->sp[0] = zero, g->ip = (union u*) g->ip + 1; return g; }
  word acc = tray_get_obj(tray(g->sp[0]), 0);
  int cop = kind == 2 ? vop_gt : vop_lt;
  for (uintptr_t i = 1; i < n; i++) {
   word e = tray_get_obj(tray(g->sp[0]), i);
   if (obin_elem(&g, cop, e, acc) == putcharm(1)) acc = e; }
  g->sp[0] = acc, g->ip = (union u*) g->ip + 1; return g; }
 word init = kind == 0 ? putcharm(0) : putcharm(1);
 int aop = kind == 0 ? vop_add : vop_mul;
 if (!ok(g = push(g, 1, init))) return g;                 // sp[0]=acc, sp[1]=array
 for (uintptr_t i = 0; i < n; i++) {
  word e = tray_get_obj(tray(g->sp[1]), i);
  word acc = obin_elem(&g, aop, g->sp[0], e);
  if (!ok(g)) return g;
  g->sp[0] = acc; }
 word result = g->sp[0]; g->sp++, g->sp[0] = result;
 g->ip = (union u*) g->ip + 1;
 return g; }

// caller guarantees twinp or isnum
static void twin_parts(word x, flo_t *re, flo_t *im) {
 if (twinp(x)) *re = twin_re(x), *im = twin_im(x);
 else *re = toflo(x), *im = 0; }

// the one set of complex formulas, for twin_fill and cbin_fill
static void twin_op(int vop, flo_t ar, flo_t ai, flo_t br, flo_t bi,
                             flo_t *re, flo_t *im) {
 switch (vop) {
  case vop_sub: *re = ar - br; *im = ai - bi; break;
  case vop_mul: *re = ar * br - ai * bi; *im = ar * bi + ai * br; break;
  case vop_quot: { flo_t d = br * br + bi * bi;
   *re = (ar * br + ai * bi) / d; *im = (ai * br - ar * bi) / d; break; }
  case vop_max: case vop_min: {                       // the (re, im) order the comparisons keep
   int c = ar < br ? -1 : ar > br ? 1 : ai < bi ? -1 : ai > bi ? 1 : 0;
   bool pa = vop == vop_max ? c >= 0 : c <= 0;
   *re = pa ? ar : br; *im = pa ? ai : bi; break; }
  default: *re = ar + br; *im = ai + bi; } }          // vop_add

// the &-taking lives here, for the wrapper's tail call
static love_noinline void twin_fill(struct twin *v, word a, word b, int vop) {
 flo_t ar, ai, br, bi, re, im;
 twin_parts(a, &ar, &ai); twin_parts(b, &br, &bi);
 twin_op(vop, ar, ai, br, bi, &re, &im);
 twin_set(v, re, im); }

// the complex lane: a real promotes to (r, 0); % is undefined
lvm(lvm_twin_bin) {
 int vop = (int) g->b;
 word a = Sp[0], b = Sp[1];
 if (!(twinp(a) || isnum(a)) || !(twinp(b) || isnum(b)) || vop > vop_quot)
  love_musttail return Push(ZeroPoint);
 Have(twin_req);
 struct twin *v = (struct twin*) Hp; v->ap = lvm_twinbox; Hp += twin_req;
 twin_fill(v, a, b, vop);
 love_musttail return Push(word(v)); }

// lvm_vbin's complex twin (love_C), a real element promoting to (v, 0)
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
  if (cmp) {                                   // (re,im) lexicographic, as cmp3's complex arm
   int t;
   if (op == vop_eq) t = same_flo(ar, br) && same_flo(ai, bi);
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
 // % and // are undefined on complex; the orderings hold
 if (!(atray || twinp(a) || isnum(a)) || !(btray || twinp(b) || isnum(b))
     || op == vop_rem || op == vop_fquot)
  love_musttail return Push(op == vop_eq ? zero : ZeroPoint);   // `=` is boolean
 bool cmp = op >= vop_lt;
 uintptr_t R, n = bshape(a, b, &R);
 if (n == (uintptr_t) -1) love_musttail return Push(op == vop_eq ? zero : ZeroPoint);
 enum tray_type rt = cmp ? love_Z : love_C;              // a compare answers a mask
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

// sin/cos of pi*x, reduced before multiplying so ((/ 1 2) -1) = i bit-exact
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
// finite non-integer? at or past 2^mantissa everything is an integer
static bool flo_fracp(flo_t x) {
 flo_t lim = (flo_t) (1ull << (Bits == 64 ? 53 : 24));
 return x > -lim && x < lim && (flo_t) (intptr_t) x != x; }

// (power b e): a complex operand, or a finite negative base to a non-integer power, widens
// to the principal root instead of nan; the rest stays IEEE
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

// (sqrt x): a complex or a negative real widens to the principal root, as (** x 1/2)
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

// (exp x): a complex operand as (** e x)
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

// (twin re im): real tray operands build a love_C tray; a complex or object tray answers ()
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
  a = Sp[0], b = Sp[1];
  struct tray *r = ini_tray((struct tray*) Hp, love_C, R);
  Hp += b2w(bytes);
  bshape_put(r->shape, R, a, b);
  twin_build_fill(r, a, b);
  love_musttail return Push(word(r)); }
 if (!isnum(a) || !isnum(b)) love_musttail return Push(ZeroPoint);
 flo_t re = toflo(a), im = toflo(b);             // before the alloc
 Have(twin_req);
 *++Sp = mk_twin(&Hp, re, im); love_musttail return Next(1); }

op11(lvm_twinp, twinp(Sp[0]) ? putcharm(1) : zero)

// component off (0 re, 1 im) of each cell; off < 0 is im of a real tray, all zeros
static love_noinline void cpart_fill(struct tray *r, struct tray *v, int off) {
 uintptr_t n = tray_nelem(r);
 if (off < 0) {
  intptr_t *zp = tray_data(r);
  for (uintptr_t p = 0; p < n; p++) zp[p] = 0;
  return; }
 flo_t *rf = tray_data(r), *fp = tray_data(v);
 for (uintptr_t p = 0; p < n; p++) rf[p] = fp[2*p + off]; }

static lvm(lvm_cpart) {
 int off = (int) g->b;
 struct tray *v = tray(Sp[0]);
 enum tray_type rt = off < 0 ? love_Z : love_R;
 uintptr_t R = v->rank, n = tray_nelem(v),
           bytes = tray_bytes(rt, R, n);
 Have(b2w(bytes));
 v = tray(Sp[0]);
 struct tray *r = ini_tray((struct tray*) Hp, rt, R); Hp += b2w(bytes);
 for (uintptr_t i = 0; i < R; i++) r->shape[i] = v->shape[i];
 cpart_fill(r, v, off);
 love_musttail return Answer(word(r)); }

// (re z) / (im z), elementwise over a tray; an object tray or non-number answers ()
lvm(lvm_re) {
 word a = Sp[0], _res;
 if (twinp(a)) {
  flo_t re = twin_re(a);
  Have(box_req);
  emit_gem(_res, re);
  love_musttail return Answer(_res); }
 if (trayp(a)) {
  enum tray_type t = tray(a)->type;
  if (t == love_O) love_musttail return Answer(ZeroPoint);
  if (t != love_C) love_musttail return Next(1);
  g->b = (word) (0); love_musttail return Ap(lvm_cpart, g); }
 if (isnum(a)) love_musttail return Next(1);
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
  g->b = (word) (t == love_C ? 1 : -1); love_musttail return Ap(lvm_cpart, g); }
 if (isnum(a)) love_musttail return Answer(putcharm(0));
 love_musttail return Answer(ZeroPoint); }

static lvm(lvm_cconj) {
 struct tray *v = tray(Sp[0]);
 uintptr_t R = v->rank, n = tray_nelem(v),
           bytes = tray_bytes(love_C, R, n);
 Have(b2w(bytes));
 v = tray(Sp[0]);
 struct tray *r = ini_tray((struct tray*) Hp, love_C, R); Hp += b2w(bytes);
 for (uintptr_t i = 0; i < R; i++) r->shape[i] = v->shape[i];
 flo_t *rf = tray_data(r), *fp = tray_data(v);
 for (uintptr_t p = 0; p < n; p++) rf[2*p] = fp[2*p], rf[2*p + 1] = -fp[2*p + 1];
 love_musttail return Answer(word(r)); }

// (conj z): lifts, a real scalar to ~(r 0) (the monadic `~`); a real tray is its own conjugate
lvm(lvm_conj) {
 word a = Sp[0];
 if (twinp(a)) {
  flo_t re = twin_re(a), im = twin_im(a);
  Have(twin_req);
  Sp[0] = mk_twin(&Hp, re, -im);
  love_musttail return Next(1); }
 if (trayp(a)) {
  enum tray_type t = tray(a)->type;
  if (t == love_O) love_musttail return Answer(ZeroPoint);
  if (t != love_C) love_musttail return Next(1);
  love_musttail return Ap(lvm_cconj, g); }
 if (isnum(a)) {
  flo_t re = toflo(a);
  Have(twin_req);
  Sp[0] = mk_twin(&Hp, re, 0);
  love_musttail return Next(1); }
 love_musttail return Answer(ZeroPoint); }

// (abs z): magnitude in its own tier
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
  if (x->slen > 0) love_musttail return Next(1);
  uintptr_t bytes = big_bytes(x); Have(b2w(bytes));
  x = big(Sp[0]);
  struct big *y = big(Hp);
  Hp += b2w(bytes);
  memcpy(y, x, bytes); y->slen = -x->slen;
  love_musttail return Answer(word(y)); }
 if (trayp(a)) {                                       // the L2 norm; love_C sums 2n floats
  struct tray *v = tray(a); uintptr_t i, n = tray_nelem(v);
  flo_t s = 0;
  if (v->type == love_C) { flo_t *fp = tray_data(v); for (i = 0; i < 2*n; i++) s += fp[i] * fp[i]; }
  else for (i = 0; i < n; i++) { flo_t e = tray_get_flo(v, i); s += e * e; }
  Have(box_req);
  emit_gem(_res, love_sqrt(s));
  love_musttail return Answer(_res); }
 if (tabp(a)) {                                       // a tablet: its key count
  Have(box_req);
  emit_int(_res, (intptr_t) map_len(a));
  love_musttail return Answer(_res); }
 love_musttail return Answer(ZeroPoint); }

static love_noinline void carg_fill(struct tray *r, struct tray *v) {
 uintptr_t n = tray_nelem(v);
 flo_t *rf = tray_data(r);
 if (v->type == love_C) { flo_t *fp = tray_data(v);
  for (uintptr_t p = 0; p < n; p++) rf[p] = love_atan2(fp[2*p+1], fp[2*p]); }
 else for (uintptr_t p = 0; p < n; p++) rf[p] = love_atan2(0, tray_get_flo(v, p)); }

// (arg z): atan2(im, re), elementwise over a tray
lvm(lvm_carg) {
 word a = Sp[0], _res;
 if (twinp(a)) {
  flo_t r = love_atan2(twin_im(a), twin_re(a));
  Have(box_req);
  emit_gem(_res, r);
  love_musttail return Answer(_res); }
 if (trayp(a)) {
  struct tray *v = tray(a);
  if (v->type == love_O) love_musttail return Answer(ZeroPoint);
  uintptr_t R = v->rank, n = tray_nelem(v);
  uintptr_t bytes = tray_bytes(love_R, R, n);
  Have(b2w(bytes));
  v = tray(Sp[0]);
  struct tray *r = ini_tray((struct tray*) Hp, love_R, R); Hp += b2w(bytes);
  for (uintptr_t i = 0; i < R; i++) r->shape[i] = v->shape[i];
  carg_fill(r, v);
  love_musttail return Answer(word(r)); }
 if (isnum(a)) {
  flo_t r = love_atan2(0, toflo(a));
  Have(box_req);
  emit_gem(_res, r);
  love_musttail return Answer(_res); }
 love_musttail return Answer(ZeroPoint); }
