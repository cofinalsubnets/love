#include "i.h"

#define opf(nom, op) g_vm(nom) {\
 word a = getnum(Sp[0]), b = getnum(Sp[1]);\
 *++Sp = putnum(a op b);\
 return Ip++, Continue(); }
opf(g_vm_bsl, <<) opf(g_vm_bsr, >>)

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

// Arithmetic is dispatched op-first: each operator is its own g_vm handler
// (g_vm_add ... g_vm_rem) carrying an inlined both-fixnum fast path, and
// tail-calls the shared slow handler arith_flo only when an operand isn't a
// fixnum, an integer op overflows, or a division degenerates. This keeps the
// common integer case free of the indirect re-dispatch + noinline struct
// return + runtime op-switch the old generic dispatcher imposed.
enum arith_op { aop_add, aop_sub, aop_mul, aop_quot, aop_rem };

// Slow path: at least one operand is non-fixnum, or the fixnum op overflowed
// the tagged range / hit a /0 or INT_MIN/-1 degenerate. Non-numeric operand →
// nil. Otherwise promote both to g_flo_t, compute, and box the f64 inline.
// g_vm (noinline) + reached only by tail call, so the per-op fast paths stay
// branch-light and TCO-clean (the &-escaping float box never touches them).
static g_vm(arith_flo, enum arith_op op) {
 word a = Sp[0], b = Sp[1];
 if (!(nump(a) || flop(a)) || !(nump(b) || flop(b)))
  return *++Sp = nil, Ip++, Continue();
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a),
         bd = nump(b) ? (g_flo_t) getnum(b) : flo_get(b), rd;
 switch (op) {
  default: __builtin_trap();
  case aop_add:  rd = ad + bd; break;
  case aop_sub:  rd = ad - bd; break;
  case aop_mul:  rd = ad * bd; break;
  case aop_quot: rd = ad / bd; break;          // ±inf or NaN on bd == 0
  case aop_rem:  rd = g_fmod(ad, bd); break; }  // NaN on bd == 0
 uintptr_t req = Width(struct g_vec) + Width(g_flo_t);
 Have(req);
 struct g_vec *v = ini_scalar((struct g_vec*) Hp, G_VT_FLO);
 Hp += req;
 flo_put(v->shape, rd);
 return *++Sp = word(v), Ip++, Continue(); }

// Both-fixnum fast path, inlined per operation. add/sub/mul use the compiler
// overflow builtins; the result must also fit the tagged-fixnum range (one bit
// lost to the tag). quot/rem guard /0 and the INT_MIN/-1 overflow, then
// range-check the quotient (-2^62 / -1 == 2^62 overflows the fixnum range).
// Anything that fails a guard tail-calls arith_flo.
#define AVM_OVF(n, builtin) g_vm(g_vm_##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (nump(a) && nump(b)) { intptr_t t; \
  if (!builtin((intptr_t) getnum(a), (intptr_t) getnum(b), &t) && \
      t >= (INTPTR_MIN >> 1) && t <= (INTPTR_MAX >> 1)) \
   return *++Sp = putnum(t), Ip++, Continue(); } \
 return Ap(arith_flo, f, aop_##n); }
AVM_OVF(add, __builtin_add_overflow)
AVM_OVF(sub, __builtin_sub_overflow)
AVM_OVF(mul, __builtin_mul_overflow)

#define AVM_DIV(n, c_op) g_vm(g_vm_##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (nump(a) && nump(b)) { \
  intptr_t av = getnum(a), bv = getnum(b); \
  if (bv != 0 && !(av == INTPTR_MIN && bv == -1)) { \
   intptr_t t = av c_op bv; \
   if (t >= (INTPTR_MIN >> 1) && t <= (INTPTR_MAX >> 1)) \
    return *++Sp = putnum(t), Ip++, Continue(); } } \
 return Ap(arith_flo, f, aop_##n); }
AVM_DIV(quot, /)
AVM_DIV(rem, %)

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

CMP_OP(g_vm_lt, <) CMP_OP(g_vm_le, <=) CMP_OP(g_vm_gt, >) CMP_OP(g_vm_ge, >=)

op(g_vm_bnot, 1, ~Sp[0] | 1)
op(g_vm_band, 2, (Sp[0] & Sp[1]) | 1)
op(g_vm_bor, 2, (Sp[0] | Sp[1]) | 1)
op(g_vm_bxor, 2, (Sp[0] ^ Sp[1]) | 1)
op(g_vm_nump, 1, oddp(Sp[0]) ? putnum(-1) : nil)
op11(g_vm_nilp, nilp(Sp[0]) ? putnum(-1) : nil)

// Unary math bif: nump/flop arg → double via vec_data, call fn, allocate
// rank-0 f64 inline. Non-numeric arg → nil. TCO-clean (no & escapes).
static g_vm(g_vm_math1, g_flo_t (*fn)(g_flo_t)) {
 word a = Sp[0];
 if (!nump(a) && !flop(a)) return Sp[0] = nil, Ip++, Continue();
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a), rd = fn(ad);
 uintptr_t req = Width(struct g_vec) + Width(g_flo_t);
 Have(req);
 struct g_vec *v = ini_scalar((struct g_vec*) Hp, G_VT_FLO);
 Hp += req;
 flo_put(v->shape, rd);
 return Sp[0] = word(v), Ip++, Continue(); }

static g_vm(g_vm_math2, g_flo_t (*fn)(g_flo_t, g_flo_t)) {
 word a = Sp[0], b = Sp[1];
 if ((!nump(a) && !flop(a)) || (!nump(b) && !flop(b))) return
  *++Sp = nil, Ip++, Continue();
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a),
         bd = nump(b) ? (g_flo_t) getnum(b) : flo_get(b),
         rd = fn(ad, bd);
 uintptr_t req = Width(struct g_vec) + Width(g_flo_t);
 Have(req);
 struct g_vec *v = ini_scalar((struct g_vec*) Hp, G_VT_FLO);
 Hp += req;
 flo_put(v->shape, rd);
 return *++Sp = word(v), Ip++, Continue(); }

#define mvm1(n) g_vm(g_vm_##n) { return Ap(g_vm_math1, f, g_##n); }
#define mvm2(n) g_vm(g_vm_##n) { return Ap(g_vm_math2, f, g_##n); }

// g_sin .. g_pow are macro aliases (g/g.h) for the C library math
// functions: libm on hosted builds, k/libc.c on the freestanding
// kernel. The op generators reference them through g_##n, which the
// preprocessor rescans into the real names after pasting.
#define m1(_) _(sin) _(cos) _(tan) _(atan) _(sqrt) _(exp) _(log)
#define m2(_) _(atan2) _(pow)
m1(mvm1) m2(mvm2)

op11(g_vm_flop, flop(Sp[0]) ? putnum(-1) : nil)
