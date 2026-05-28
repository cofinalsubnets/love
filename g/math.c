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
enum arith_op { AOP_ADD, AOP_SUB, AOP_MUL, AOP_QUOT, AOP_REM };
struct arith_r { word v; g_flo_t d; bool isflo; bool isnil; };

static g_noinline struct arith_r do_arith(word a, word b, enum arith_op op) {
 struct arith_r r = { 0, 0, false, false };
 if (nump(a) && nump(b)) {
  intptr_t av = getnum(a), bv = getnum(b), t = 0;
  bool do_float = false;
  switch (op) {
   case AOP_ADD: do_float = __builtin_add_overflow(av, bv, &t); break;
   case AOP_SUB: do_float = __builtin_sub_overflow(av, bv, &t); break;
   case AOP_MUL: do_float = __builtin_mul_overflow(av, bv, &t); break;
   case AOP_QUOT:
    if (bv == 0) do_float = true;
    else if (av == INTPTR_MIN && bv == -1) do_float = true;
    else t = av / bv;
    break;
   case AOP_REM:
    if (bv == 0) do_float = true;
    else if (av == INTPTR_MIN && bv == -1) t = 0;
    else t = av % bv;
    break; }
  // Also require the result to fit the tagged-fixnum range (one bit lost).
  if (!do_float && (t < (INTPTR_MIN >> 1) || t > (INTPTR_MAX >> 1)))
   do_float = true;
  if (!do_float) { r.v = putnum(t); return r; } }
 // Float path: require both operands numeric.
 if (!(nump(a) || flop(a)) || !(nump(b) || flop(b))) {
  r.isnil = true; return r; }
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a);
 g_flo_t bd = nump(b) ? (g_flo_t) getnum(b) : flo_get(b);
 g_flo_t rd = 0;
 switch (op) {
  case AOP_ADD: rd = ad + bd; break;
  case AOP_SUB: rd = ad - bd; break;
  case AOP_MUL: rd = ad * bd; break;
  case AOP_QUOT: rd = ad / bd; break;         // ±inf or NaN on bd == 0
  case AOP_REM:  rd = g_fmod(ad, bd); break;  // NaN on bd == 0
 }
 r.isflo = true; r.d = rd;
 return r; }

#define ARITH_OP(nom, op_tag) g_vm(nom) {                                  \
 struct arith_r r = do_arith(Sp[0], Sp[1], op_tag);                        \
 if (r.isnil)  { Sp[1] = nil;  Sp += 1; Ip++; return Continue(); }         \
 if (!r.isflo) { Sp[1] = r.v;  Sp += 1; Ip++; return Continue(); }         \
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));              \
 Have(req);                                                                \
 struct g_vec *v = (struct g_vec*) Hp;                                     \
 Hp += req;                                                                \
 v->ap = g_vm_data;                                                        \
 v->typ = vec_q;                                                           \
 v->type = G_VT_FLO;                                                       \
 v->rank = 0;                                                              \
 flo_put(v->shape, r.d);                                               \
 Sp[1] = word(v);                                                          \
 Sp += 1; Ip++; return Continue(); }

ARITH_OP(g_vm_add,  AOP_ADD)
ARITH_OP(g_vm_sub,  AOP_SUB)
ARITH_OP(g_vm_mul,  AOP_MUL)
ARITH_OP(g_vm_quot, AOP_QUOT)
ARITH_OP(g_vm_rem,  AOP_REM)

// Mixed-numeric ordered comparison. Same nump-fast-path, else widen.
// Non-numeric operands return nil (matches existing degraded behavior
// on cross-type compares but well-defined).
#define CMP_OP(nom, c_op) g_vm(nom) {                                      \
 word a = Sp[0], b = Sp[1];                                                \
 word x;                                                                   \
 if (nump(a) && nump(b)) x = (a c_op b) ? putnum(-1) : nil;                \
 else if ((nump(a) || flop(a)) && (nump(b) || flop(b))) {                  \
  g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a);    \
  g_flo_t bd = nump(b) ? (g_flo_t) getnum(b) : flo_get(b);    \
  x = (ad c_op bd) ? putnum(-1) : nil;                                     \
 } else x = nil;                                                           \
 Sp[1] = x; Sp += 1; Ip++; return Continue(); }

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
#define MATH1_OP(nom, fn) g_vm(nom) {                                      \
 word a = Sp[0];                                                           \
 if (!nump(a) && !flop(a)) { Sp[0] = nil; Ip++; return Continue(); }       \
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a);     \
 g_flo_t rd = fn(ad);                                                      \
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));              \
 Have(req);                                                                \
 struct g_vec *v = (struct g_vec*) Hp;                                     \
 Hp += req;                                                                \
 v->ap = g_vm_data;                                                        \
 v->typ = vec_q;                                                           \
 v->type = G_VT_FLO;                                                       \
 v->rank = 0;                                                              \
 flo_put(v->shape, rd);                                                \
 Sp[0] = word(v);                                                          \
 Ip++; return Continue(); }

#define MATH2_OP(nom, fn) g_vm(nom) {                                      \
 word a = Sp[0], b = Sp[1];                                                \
 if ((!nump(a) && !flop(a)) || (!nump(b) && !flop(b)))                     \
  { Sp[1] = nil; Sp += 1; Ip++; return Continue(); }                       \
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a);     \
 g_flo_t bd = nump(b) ? (g_flo_t) getnum(b) : flo_get(b);     \
 g_flo_t rd = fn(ad, bd);                                                  \
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));              \
 Have(req);                                                                \
 struct g_vec *v = (struct g_vec*) Hp;                                     \
 Hp += req;                                                                \
 v->ap = g_vm_data;                                                        \
 v->typ = vec_q;                                                           \
 v->type = G_VT_FLO;                                                       \
 v->rank = 0;                                                              \
 flo_put(v->shape, rd);                                                \
 Sp[1] = word(v);                                                          \
 Sp += 1; Ip++; return Continue(); }

MATH1_OP(g_vm_sin,   g_sin)
MATH1_OP(g_vm_cos,   g_cos)
MATH1_OP(g_vm_tan,   g_tan)
MATH1_OP(g_vm_atan,  g_atan)
MATH1_OP(g_vm_sqrt,  g_sqrt)
MATH1_OP(g_vm_exp,   g_exp)
MATH1_OP(g_vm_log,   g_log)
MATH2_OP(g_vm_atan2, g_atan2)
MATH2_OP(g_vm_pow,   g_pow)

// Math hooks. Weak defaults trap so calls on a frontend without an
// override fail loudly (kernel/pico/esp until internal impls land).
// Host and pd override via libm.
#define WEAK_TRAP1(nom) __attribute__((weak)) g_flo_t nom(g_flo_t x) \
  { (void) x; __builtin_trap(); }
#define WEAK_TRAP2(nom) __attribute__((weak)) g_flo_t nom(g_flo_t x, g_flo_t y) \
  { (void) x; (void) y; __builtin_trap(); }
WEAK_TRAP1(g_sin)  WEAK_TRAP1(g_cos)  WEAK_TRAP1(g_tan)
WEAK_TRAP1(g_atan) WEAK_TRAP1(g_sqrt) WEAK_TRAP1(g_exp)
WEAK_TRAP1(g_log)
WEAK_TRAP2(g_atan2) WEAK_TRAP2(g_pow)

op11(g_vm_flop, flop(Sp[0]) ? putnum(-1) : nil)
