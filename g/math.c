#include "i.h"

opf(g_vm_bsr, >>)
opf(g_vm_bsl, <<)

// Truncation toward zero. Magnitudes above 2^63 are already
// integer-valued in double precision, so we leave them alone instead of
// risking an int64 overflow on the round-trip. NaN passes through.
static g_inline g_flo_t g_trunc(g_flo_t x) {
 if (x != x) return x;
 g_flo_t m = x < 0 ? -x : x;
 if (m > (g_flo_t) 9.22e18) return x;
 return (g_flo_t)(int64_t) x; }

// Float remainder via truncated quotient. Matches libm's fmod() for
// the cases we care about. When b == 0, x/b is ±inf or NaN, ±inf*0 is
// NaN, so the result is NaN — same as libm.
static g_inline g_flo_t g_fmod(g_flo_t a, g_flo_t b) {
 return a - g_trunc(a / b) * b; }

// Generic arithmetic dispatcher. Both fixnums + no overflow → fixnum
// result; otherwise (mixed nump/flop, overflow, /0, both flop) → double
// result. Division/remainder by zero promote to IEEE values (±inf or
// NaN), not nil. Non-numeric operands return nil.
// g_noinline + by-value struct return keeps the &t overflow-out-param
// off the g_vm caller's frame, preserving TCO.
enum arith_op { aop_add, aop_sub, aop_mul, aop_quot, aop_rem };
struct arith_r { union { word v; g_flo_t d; }; bool isflo; };

static g_noinline struct arith_r do_arith(word a, word b, enum arith_op op) {
 struct arith_r r = { 0 };
 if (nump(a) && nump(b)) {
  intptr_t av = getnum(a), bv = getnum(b), t = 0;
  bool do_float = false;
  switch (op) {
   case aop_add: do_float = __builtin_add_overflow(av, bv, &t); break;
   case aop_sub: do_float = __builtin_sub_overflow(av, bv, &t); break;
   case aop_mul: do_float = __builtin_mul_overflow(av, bv, &t); break;
   case aop_quot:
    if (bv == 0 || (av == INTPTR_MIN && bv == -1)) do_float = true;
    else t = av / bv;
    break;
   case aop_rem:
    if (bv == 0 || (av == INTPTR_MIN && bv == -1)) do_float = true;
    else t = av % bv; }
  // Also require the result to fit the tagged-fixnum range (one bit lost).
  do_float = do_float || t < (INTPTR_MIN >> 1) || t > (INTPTR_MAX >> 1);
  if (!do_float) return r.v = putnum(t), r; }
 // Float path: require both operands numeric.
 if (!(nump(a) || flop(a)) || !(nump(b) || flop(b))) return r.v = nil, r;
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a),
         bd = nump(b) ? (g_flo_t) getnum(b) : flo_get(b);
 r.isflo = true;
 switch (op) {
  default: __builtin_trap();
  case aop_add: return r.d = ad + bd, r;
  case aop_sub: return r.d = ad - bd, r;
  case aop_mul: return r.d = ad * bd, r;
  case aop_quot: return r.d = ad / bd, r;    // ±inf or NaN on bd == 0
  case aop_rem:  return r.d = g_fmod(ad, bd), r; } }  // NaN on bd == 0

static g_noinline g_vm(g_vm_arith, enum arith_op op_tag) {
 struct arith_r r = do_arith(Sp[0], Sp[1], op_tag);
 if (!r.isflo) return *++Sp = r.v, Ip++, Continue();
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));
 Have(req);
 struct g_vec *v = (struct g_vec*) Hp;
 Hp += req;
 v->ap = g_vm_data;
 v->typ = vec_q;
 v->type = G_VT_FLO;
 v->rank = 0;
 flo_put(v->shape, r.d);
 Sp[1] = word(v);
 return Sp++, Ip++, Continue(); }

#define a2(_) _(add) _(sub) _(mul) _(quot) _(rem)
#define avm2(n) g_vm(g_vm_##n) { return Ap(g_vm_arith, f, aop_##n); }
a2(avm2)

// Mixed-numeric ordered comparison. Same nump-fast-path, else widen.
// Non-numeric operands return nil (matches existing degraded behavior
// on cross-type compares but well-defined).
#define CMP_OP(nom, c_op) g_vm(nom) {                                      \
 word a = Sp[0], b = Sp[1], x = nil;                                                \
 if (nump(a) && nump(b)) x = (a c_op b) ? putnum(-1) : nil;                \
 else if ((nump(a) || flop(a)) && (nump(b) || flop(b))) {                  \
  g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a),    \
          bd = nump(b) ? (g_flo_t) getnum(b) : flo_get(b);    \
  x = (ad c_op bd) ? putnum(-1) : nil; }                      \
 return *++Sp = x, Ip++, Continue(); }

CMP_OP(g_vm_lt, <)
CMP_OP(g_vm_le, <=)
CMP_OP(g_vm_gt, >)
CMP_OP(g_vm_ge, >=)

op(g_vm_bnot, 1, ~Sp[0] | 1)
op(g_vm_band, 2, (Sp[0] & Sp[1]) | 1)
op(g_vm_bor, 2, (Sp[0] | Sp[1]) | 1)
op(g_vm_bxor, 2, (Sp[0] ^ Sp[1]) | 1)
op(g_vm_nump, 1, oddp(Sp[0]) ? putnum(-1) : nil)
op11(g_vm_nilp, nilp(Sp[0]) ? putnum(-1) : nil)

// Unary math bif: nump/flop arg → double via vec_data, call fn, allocate
// rank-0 f64 inline. Non-numeric arg → nil. TCO-clean (no & escapes).
static g_noinline g_vm(g_vm_math1, g_flo_t (*fn)(g_flo_t)) {
 word a = Sp[0];
 if (!nump(a) && !flop(a)) return Sp[0] = nil, Ip++, Continue();
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a), rd = fn(ad);
 uintptr_t req = Width(struct g_vec) + Width(g_flo_t);
 Have(req);
 struct g_vec *v = (struct g_vec*) Hp;
 Hp += req;
 v->ap = g_vm_data;
 v->typ = vec_q;
 v->type = G_VT_FLO;
 v->rank = 0;
 flo_put(v->shape, rd);
 return Sp[0] = word(v), Ip++, Continue(); }

static g_noinline g_vm(g_vm_math2, g_flo_t (*fn)(g_flo_t, g_flo_t)) {
 word a = Sp[0], b = Sp[1];
 if ((!nump(a) && !flop(a)) || (!nump(b) && !flop(b))) return
  *++Sp = nil, Ip++, Continue();
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a),
         bd = nump(b) ? (g_flo_t) getnum(b) : flo_get(b),
         rd = fn(ad, bd);
 uintptr_t req = Width(struct g_vec) + Width(g_flo_t);
 Have(req);
 struct g_vec *v = (struct g_vec*) Hp;
 Hp += req;
 v->ap = g_vm_data;
 v->typ = vec_q;
 v->type = G_VT_FLO;
 v->rank = 0;
 flo_put(v->shape, rd);
 return *++Sp = word(v), Ip++, Continue(); }

#define mvm1(n) g_vm(g_vm_##n) { return Ap(g_vm_math1, f, g_##n); }
#define mvm2(n) g_vm(g_vm_##n) { return Ap(g_vm_math2, f, g_##n); }

#define WEAK_TRAP1(nom) __attribute__((weak)) g_flo_t g_##nom(g_flo_t x) \
  { (void) x; __builtin_trap(); }
#define WEAK_TRAP2(nom) __attribute__((weak)) g_flo_t g_##nom(g_flo_t x, g_flo_t y) \
  { (void) x; (void) y; __builtin_trap(); }
#define m1(_) _(sin) _(cos) _(tan) _(atan) _(sqrt) _(exp) _(log)
#define m2(_) _(atan2) _(pow)
m1(WEAK_TRAP1) m1(mvm1)
m2(WEAK_TRAP2) m2(mvm2)

op11(g_vm_flop, flop(Sp[0]) ? putnum(-1) : nil)
