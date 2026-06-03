#include "i.h"

// The numeric-tower helpers (ISNUM / TOINT / TOFLO / BOX_REQ / FIX_MIN / FIX_MAX
// / EMIT_INT / EMIT_FLO) and g_trunc / g_fmod now live in i.h, shared with the
// elementwise array lane (core/arr.c) and the array element read in get
// (core/tbl.c). They are unchanged; only their home moved.

// Arithmetic is dispatched op-first: each operator is its own g_vm handler
// (g_vm_add ... g_vm_rem) carrying an inlined both-fixnum fast path, and
// tail-calls its own dedicated slow handler (g_vm_add_slow ...) only when an
// operand isn't a fixnum or the fixnum op overflows / divides degenerately.
// This keeps the common integer case free of the indirect re-dispatch the old
// generic dispatcher imposed, and the slow path statically specialized.
//
// Slow path, one handler per operator. Non-numeric operand → nil. Otherwise:
// either operand a float → promote both to g_flo_t and box the f64 result;
// else both are integers (fixnum or wide-int box) → compute in intptr_t
// (through uintptr_t, so an i64 overflow wraps with defined behavior) and
// demote-or-box via EMIT_INT. g_vm (noinline) + reached only by tail call, so
// the per-op fast paths stay branch-light and TCO-clean.
#define AVM_SLOW(n, vop, iexpr, fexpr) static g_vm(g_vm_##n##_slow) { \
 word a = Sp[0], b = Sp[1], _res; \
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, f, vop); \
 if (!ISNUM(a) || !ISNUM(b)) return *++Sp = nil, Ip++, Continue(); \
 Have(BOX_REQ); \
 if (flop(a) || flop(b)) { \
  g_flo_t ad = TOFLO(a), bd = TOFLO(b); \
  struct g_vec *v = ini_scalar((struct g_vec*) Hp, G_VT_FLO); \
  Hp += BOX_REQ; flo_put(v->shape, (fexpr)); _res = word(v); } \
 else { intptr_t av = TOINT(a), bv = TOINT(b); EMIT_INT(iexpr); } \
 return *++Sp = _res, Ip++, Continue(); }
AVM_SLOW(add, VOP_ADD, (intptr_t)((uintptr_t) av + (uintptr_t) bv), ad + bd)
AVM_SLOW(sub, VOP_SUB, (intptr_t)((uintptr_t) av - (uintptr_t) bv), ad - bd)
AVM_SLOW(mul, VOP_MUL, (intptr_t)((uintptr_t) av * (uintptr_t) bv), ad * bd)

// Division slow path: like AVM_SLOW, but the integer lane bails to the float
// lane on the two degenerate cases (÷0 → ±inf/NaN; INT_MIN÷-1 would overflow),
// matching the both-fixnum fast path's guard.
#define AVM_SLOWDIV(n, vop, c_op, fexpr) static g_vm(g_vm_##n##_slow) { \
 word a = Sp[0], b = Sp[1], _res; \
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, f, vop); \
 if (!ISNUM(a) || !ISNUM(b)) return *++Sp = nil, Ip++, Continue(); \
 Have(BOX_REQ); \
 bool use_flo = flop(a) || flop(b); \
 intptr_t av = 0, bv = 0; \
 if (!use_flo) { av = TOINT(a), bv = TOINT(b); \
  use_flo = bv == 0 || (av == INTPTR_MIN && bv == -1); } \
 if (use_flo) { \
  g_flo_t ad = TOFLO(a), bd = TOFLO(b); \
  struct g_vec *v = ini_scalar((struct g_vec*) Hp, G_VT_FLO); \
  Hp += BOX_REQ; flo_put(v->shape, (fexpr)); _res = word(v); } \
 else EMIT_INT(av c_op bv); \
 return *++Sp = _res, Ip++, Continue(); }
AVM_SLOWDIV(quot, VOP_QUOT, /, ad / bd)         // ±inf or NaN on bd == 0
AVM_SLOWDIV(rem, VOP_REM, %, g_fmod(ad, bd))    // NaN on bd == 0

// arith builtins take an explicit stack address but
// empirically this is compiled away on both GCC and
// clang so TCO is preserved.
#define AVM_OVF(n, builtin) g_vm(g_vm_##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (nump(a) && nump(b)) { intptr_t t; \
  if (!builtin((intptr_t) getnum(a), (intptr_t) getnum(b), &t) && \
      t >= FIX_MIN && t <= FIX_MAX) \
   return *++Sp = putnum(t), Ip++, Continue(); } \
 return Ap(g_vm_##n##_slow, f); }
AVM_OVF(add, __builtin_add_overflow)
AVM_OVF(sub, __builtin_sub_overflow)
AVM_OVF(mul, __builtin_mul_overflow)

#define AVM_DIV(n, c_op) g_vm(g_vm_##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (nump(a) && nump(b)) { \
  intptr_t av = getnum(a), bv = getnum(b); \
  if (bv != 0 && !(av == INTPTR_MIN && bv == -1)) { \
   intptr_t t = av c_op bv; \
   if (t >= FIX_MIN && t <= FIX_MAX) \
    return *++Sp = putnum(t), Ip++, Continue(); } } \
 return Ap(g_vm_##n##_slow, f); }
AVM_DIV(quot, /)
AVM_DIV(rem, %)

// Mixed-numeric ordered comparison, split like the arith handlers so the
// both-fixnum case is a compact, contiguous fast path: load/test/compare/
// store/jmp in source order. The slow handler widens to the integer lane
// (signed compare, valid across boxes) or the float lane (either operand a
// flop). Non-numeric operands return nil.
#define CMP_SLOW(nom, vop, c_op) static g_vm(nom##_slow) {                   \
 word a = Sp[0], b = Sp[1], x = nil;                                   \
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, f, vop);                 \
 if (ISNUM(a) && ISNUM(b))                                             \
  x = ((flop(a) || flop(b)) ? (TOFLO(a) c_op TOFLO(b))                 \
                            : (TOINT(a) c_op TOINT(b))) ? putnum(-1) : nil; \
 return *++Sp = x, Ip++, Continue(); }
#define CMP_OP(nom, vop, c_op) CMP_SLOW(nom, vop, c_op) g_vm(nom) {    \
 word a = Sp[0], b = Sp[1];                                           \
 if (__builtin_expect(nump(a) && nump(b), 1))                         \
  return *++Sp = (a c_op b) ? putnum(-1) : nil, Ip++, Continue();     \
 return Ap(nom##_slow, f); }

CMP_OP(g_vm_lt, VOP_LT, <) CMP_OP(g_vm_le, VOP_LE, <=)
CMP_OP(g_vm_gt, VOP_GT, >) CMP_OP(g_vm_ge, VOP_GE, >=)

// Bitwise and/or/xor: fast both-fixnum tag trick (two odds stay odd under &
// and |; ^ clears the tag bit so we re-set it). A box operand routes to the
// slow handler, which works at full width and demotes-or-boxes; these are
// integer-only, so a float (or any non-integer) operand yields nil.
#define BIT_SLOW(n, c_op) static g_vm(g_vm_##n##_slow) {               \
 word a = Sp[0], b = Sp[1], _res;                                     \
 if (!(nump(a) || boxp(a)) || !(nump(b) || boxp(b)))                  \
  return *++Sp = nil, Ip++, Continue();                               \
 Have(BOX_REQ);                                                       \
 EMIT_INT(TOINT(a) c_op TOINT(b));                                    \
 return *++Sp = _res, Ip++, Continue(); }
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

op(g_vm_nump, 1, oddp(Sp[0]) ? putnum(-1) : nil)
// `nilp`/`not`: the language falsy predicate (nil/0 OR an all-zero vec --
// boxed 0.0, zero int box, all-zero array). Use `(= x 0)` for a literal
// scalar-zero test; `(aall (= x 0))` over an array.
op11(g_vm_nilp, g_falsy(Sp[0]) ? putnum(-1) : nil)

// Unary math bif: numeric arg → double, call fn, box the rank-0 f64 result.
// Non-numeric arg → nil. TCO-clean (no & escapes).
static g_vm(g_vm_math1, g_flo_t (*fn)(g_flo_t)) {
 word a = Sp[0];
 if (arrp(a)) return Ap(g_vm_vmap1, f, fn);   // (sin arr) etc. -> float array
 if (!ISNUM(a)) return Sp[0] = nil, Ip++, Continue();
 g_flo_t ad = TOFLO(a), rd = fn(ad);
 uintptr_t req = Width(struct g_vec) + Width(g_flo_t);
 Have(req);
 struct g_vec *v = ini_scalar((struct g_vec*) Hp, G_VT_FLO);
 Hp += req;
 flo_put(v->shape, rd);
 return Sp[0] = word(v), Ip++, Continue(); }

static g_vm(g_vm_math2, g_flo_t (*fn)(g_flo_t, g_flo_t)) {
 word a = Sp[0], b = Sp[1];
 if (!ISNUM(a) || !ISNUM(b)) return
  *++Sp = nil, Ip++, Continue();
 g_flo_t ad = TOFLO(a), bd = TOFLO(b), rd = fn(ad, bd);
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
