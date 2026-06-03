#include "i.h"

// Step 7 -- complex arithmetic. A complex number is a rank-0 g_vec of element
// type G_VT_CPLX holding two g_flo_t (re, im) -- the exact parallel of the float
// box (G_VT_FLO), so it rides the existing vec allocation and copying GC for
// free (g_vec_bytes already generalizes over type via g_vt_size). Complex is the
// widest numeric tier (complex > float > int/bignum): the scalar arith slow
// paths (core/math.c) divert here via g_vm_cplx_bin when either operand is
// complex. It is sticky -- never demotes to a real, even when im is 0 -- and
// unordered (< <= > >= on a complex operand return nil, handled for free since
// cplxp is not in ISNUM). `=` IS defined (core/eq.c), bridging to reals.
// See [[project-todo-math]] step 7.

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
static g_noinline void cplx_fill(struct g_vec *v, word a, word b, int vop) {
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
 struct g_vec *v = ini_scalar((struct g_vec*) Hp, G_VT_CPLX);
 Hp += CPLX_REQ;
 cplx_fill(v, a, b, vop);
 return *++Sp = word(v), Ip++, Continue(); }

// (cplx re im): build a complex from two real numbers. Non-numeric arg -> nil.
g_vm(g_vm_cplx) {
 word a = Sp[0], b = Sp[1];
 if (!ISNUM(a) || !ISNUM(b)) return *++Sp = nil, Ip++, Continue();
 g_flo_t re = TOFLO(a), im = TOFLO(b);             // values extracted before alloc
 Have(CPLX_REQ);
 struct g_vec *v = ini_scalar((struct g_vec*) Hp, G_VT_CPLX);
 Hp += CPLX_REQ;
 cplx_put(v, re, im);
 return *++Sp = word(v), Ip++, Continue(); }

// (cplxp x): is x a complex scalar?
op11(g_vm_cplxp, cplxp(Sp[0]) ? putnum(-1) : nil)

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
  struct g_vec *v = ini_scalar((struct g_vec*) Hp, G_VT_CPLX); Hp += CPLX_REQ;
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
