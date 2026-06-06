#include "i.h"

// Step 5a -- typed multi-rank arrays. An array is a g_vec with rank >= 1 (rank-0
// vecs are the scalar boxes: flop / boxp). Construction, indexing, accessors,
// reductions, and the elementwise/broadcast binary engine the arith/compare
// slow lanes divert into. GC is free: copy_vec / evac_vec already generalize
// over rank + type via g_vec_bytes (kernel/gc.c). See [[project-todo-math]] 5a.
// The per-element read/write + size helpers live in i.h (vec_get/put_*,
// g_vt_size in kernel/vec.c), shared with `get` (kernel/hash.c) and the printer.

// --- (arr type shape-list): zero-filled array ------------------------------
// `type` is a fixnum element-type code (i8..f64, named in the prelude); `shape`
// is a list of non-negative fixnum dimensions (empty -> a rank-0 scalar box).
// Bad type / negative dim / over-rank -> nil.
g_vm(g_vm_arr) {
 word t = Sp[0], shp = Sp[1];
 if (!nump(t)) return *++Sp = nil, Ip++, Continue();
 intptr_t ty = getnum(t);
 if (ty < 0 || ty > g_vt_f64) return *++Sp = nil, Ip++, Continue();
 uintptr_t rank = 0, nelem = 1;
 for (word l = shp; twop(l); l = B(l)) {
  word d = A(l);
  if (!nump(d) || getnum(d) < 0) return *++Sp = nil, Ip++, Continue();
  rank++, nelem *= (uintptr_t) getnum(d); }
 if (rank > G_VEC_MAXRANK) return *++Sp = nil, Ip++, Continue();
 uintptr_t bytes = sizeof(struct g_vec) + rank * sizeof(word) + nelem * g_vt_size[ty];
 Have(b2w(bytes));
 struct g_vec *v = (struct g_vec*) Hp;
 Hp += b2w(bytes);
 ini_vec(v, ty, rank);
 uintptr_t i = 0;                              // re-walk the (possibly moved) list
 for (word l = Sp[1]; twop(l); l = B(l)) v->shape[i++] = (uintptr_t) getnum(A(l));
 memset(vec_data(v), 0, nelem * g_vt_size[ty]);
 return *++Sp = word(v), Ip++, Continue(); }

// (arrl type shape-list vals-list): like arr, but fills row-major from
// vals-list (a non-numeric or missing entry stays 0; extras are ignored). Lets
// code build a specific array before array-literal syntax lands.
g_vm(g_vm_arrl) {
 word t = Sp[0], shp = Sp[1];                  // vals = Sp[2]
 if (!nump(t)) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 intptr_t ty = getnum(t);
 if (ty < 0 || ty > g_vt_f64) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 uintptr_t rank = 0, nelem = 1;
 for (word l = shp; twop(l); l = B(l)) {
  word d = A(l);
  if (!nump(d) || getnum(d) < 0) return Sp[2] = nil, Sp += 2, Ip++, Continue();
  rank++, nelem *= (uintptr_t) getnum(d); }
 if (rank > G_VEC_MAXRANK) return Sp[2] = nil, Sp += 2, Ip++, Continue();
 uintptr_t bytes = sizeof(struct g_vec) + rank * sizeof(word) + nelem * g_vt_size[ty];
 Have(b2w(bytes));
 struct g_vec *v = (struct g_vec*) Hp;
 Hp += b2w(bytes);
 ini_vec(v, ty, rank);
 uintptr_t i = 0;                              // re-walk the (possibly moved) lists
 for (word l = Sp[1]; twop(l); l = B(l)) v->shape[i++] = (uintptr_t) getnum(A(l));
 memset(vec_data(v), 0, nelem * g_vt_size[ty]);
 i = 0;
 for (word l = Sp[2]; twop(l) && i < nelem; l = B(l), i++) {
  word e = A(l);
  if (!ISNUM(e)) continue;
  if (ty >= g_vt_f32) vec_put_flo(v, i, TOFLO(e));
  else vec_put_int(v, i, nump(e) ? (intptr_t) getnum(e)
                       : flop(e) ? (intptr_t) flo_get(e) : box_get(e)); }
 return Sp[2] = word(v), Sp += 2, Ip++, Continue(); }

// --- accessors -------------------------------------------------------------
// rank / element-type code as fixnums; nil for a non-vec. Both 0 for a scalar box.
op11(g_vm_arank, vecp(Sp[0]) ? putnum(vec(Sp[0])->rank) : nil)
op11(g_vm_atype, vecp(Sp[0]) ? putnum(vec(Sp[0])->type) : nil)

// total element count (1 for a scalar box), nil for a non-vec.
g_vm(g_vm_alen) {
 word x = Sp[0];
 if (!vecp(x)) return Sp[0] = nil, Ip++, Continue();
 uintptr_t n = 1;
 for (uintptr_t i = 0; i < vec(x)->rank; i++) n *= vec(x)->shape[i];
 return Sp[0] = putnum(n), Ip++, Continue(); }

// dimensions as a list (allocates rank cons cells), nil for a non-vec.
g_vm(g_vm_ashape) {
 word x = Sp[0];
 if (!vecp(x)) return Sp[0] = nil, Ip++, Continue();
 uintptr_t r = vec(x)->rank;
 Have(r * Width(struct g_pair));
 struct g_vec *v = vec(Sp[0]);                 // re-read post-Have
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
bool g_all_zero(struct g_vec *v) {
 // A complex scalar is falsy iff both components are 0 (so (cplx 0 0) and 0.0
 // agree). Read both parts -- the generic float-domain scan below would see only
 // the real part (cplx sorts past f64, so `>= g_vt_f32` treats it as float).
 if (v->type == G_VT_CPLX) return cplx_re(word(v)) == 0 && cplx_im(word(v)) == 0;
 uintptr_t n = 1;
 for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 bool fdom = v->type >= g_vt_f32;
 for (uintptr_t i = 0; i < n; i++)
  if (fdom ? vec_get_flo(v, i) != 0 : vec_get_int(v, i) != 0) return false;
 return true; }

// --- reductions: rank>=1 array -> rank-0 scalar; identity on a scalar -------
// The identity-on-scalar property makes `(aall (< a b))` rank-agnostic: the
// same expression works whether a/b are scalars or arrays.
g_vm(g_vm_asum) {
 word x = Sp[0];
 if (!vecp(x)) return Ip++, Continue();        // scalar: (asum 5) = 5
 struct g_vec *v = vec(x);
 uintptr_t n = 1;
 for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 bool fdom = v->type >= g_vt_f32; word _res;
 Have(BOX_REQ);
 v = vec(Sp[0]);
 if (fdom) {
  g_flo_t a = 0;
  for (uintptr_t i = 0; i < n; i++) a += vec_get_flo(v, i);
  EMIT_FLO(a); }
 else {
  intptr_t a = 0;
  for (uintptr_t i = 0; i < n; i++) a = (intptr_t) ((uintptr_t) a + (uintptr_t) vec_get_int(v, i));
  EMIT_INT(a); }
 return Sp[0] = _res, Ip++, Continue(); }

g_vm(g_vm_aprod) {
 word x = Sp[0];
 if (!vecp(x)) return Ip++, Continue();
 struct g_vec *v = vec(x);
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 bool fdom = v->type >= g_vt_f32; word _res;
 Have(BOX_REQ); v = vec(Sp[0]);
 if (fdom) {
  g_flo_t a = 1;
  for (uintptr_t i = 0; i < n; i++) a *= vec_get_flo(v, i);
  EMIT_FLO(a); }
 else { intptr_t a = 1;
  for (uintptr_t i = 0; i < n; i++) a = (intptr_t)((uintptr_t) a * (uintptr_t) vec_get_int(v, i));
  EMIT_INT(a); }
 return Sp[0] = _res, Ip++, Continue(); }

// max / min over a non-empty array; empty -> nil; scalar -> identity.
#define RED_EXTREME(nom, c_op) g_vm(nom) { \
 word x = Sp[0]; \
 if (!vecp(x)) return Ip++, Continue(); \
 struct g_vec *v = vec(x); \
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i]; \
 if (!n) return Sp[0] = nil, Ip++, Continue(); \
 bool fdom = v->type >= g_vt_f32; word _res; \
 Have(BOX_REQ); v = vec(Sp[0]); \
 if (fdom) { g_flo_t m = vec_get_flo(v, 0); \
  for (uintptr_t i = 1; i < n; i++) {\
   g_flo_t e = vec_get_flo(v, i);\
   if (e c_op m) m = e; } \
  EMIT_FLO(m); } \
 else { intptr_t m = vec_get_int(v, 0); \
  for (uintptr_t i = 1; i < n; i++) {\
   intptr_t e = vec_get_int(v, i);\
   if (e c_op m) m = e; } \
  EMIT_INT(m); } \
 return Sp[0] = _res, Ip++, Continue(); }
RED_EXTREME(g_vm_amax, >)
RED_EXTREME(g_vm_amin, <)

// aall/aany: bool reductions. Scalar -> identity (so (aall -1) = -1, the linchpin
// of the rank-agnostic compare idiom). Over an array: aall = "no zero element",
// aany = "some nonzero element" -- the falsy rule lifted to a conjunction/
// disjunction. Empty array: aall true (vacuous), aany false.
g_vm(g_vm_aall) {
 word x = Sp[0];
 if (!vecp(x)) return Ip++, Continue();
 struct g_vec *v = vec(x);
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 bool fdom = v->type >= g_vt_f32;
 for (uintptr_t i = 0; i < n; i++)
  if (fdom ? vec_get_flo(v, i) == 0 : vec_get_int(v, i) == 0)
   return Sp[0] = nil, Ip++, Continue();
 return Sp[0] = putnum(-1), Ip++, Continue(); }

g_vm(g_vm_aany) {
 word x = Sp[0];
 if (!vecp(x)) return Ip++, Continue();
 struct g_vec *v = vec(x);
 uintptr_t n = 1; for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 bool fdom = v->type >= g_vt_f32;
 for (uintptr_t i = 0; i < n; i++)
  if (fdom ? vec_get_flo(v, i) != 0 : vec_get_int(v, i) != 0)
   return Sp[0] = putnum(-1), Ip++, Continue();
 return Sp[0] = nil, Ip++, Continue(); }

// --- elementwise unary math over an array (sin/cos/sqrt/... ) --------------
// Reached from g_vm_math1 when its operand arrp. Result is a float array
// (G_VT_FLO) with the operand's shape. The fill loop takes no &local, so the
// g_vm wrapper keeps its trailing tail call.
static g_noinline void vmap1_fill(struct g_vec *r, struct g_vec *a, g_flo_t (*fn)(g_flo_t)) {
 uintptr_t i, n = 1;
 for (i = 0; i < r->rank; i++) n *= r->shape[i];
 for (i = 0; i < n; i++) vec_put_flo(r, i, fn(vec_get_flo(a, i))); }

g_vm(g_vm_vmap1, g_flo_t (*fn)(g_flo_t)) {
 struct g_vec *a = vec(Sp[0]);
 uintptr_t rank = a->rank, n = 1;
 for (uintptr_t i = 0; i < rank; i++) n *= a->shape[i];
 uintptr_t bytes = sizeof(struct g_vec) + rank * sizeof(word) + n * g_vt_size[G_VT_FLO];
 Have(b2w(bytes));
 a = vec(Sp[0]);                               // re-read post-Have
 struct g_vec *r = (struct g_vec*) Hp;
 Hp += b2w(bytes);
 ini_vec(r, G_VT_FLO, rank);
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
static g_noinline void vbin_fill(struct g_vec *r, word a, word b, int op, bool fdom) {
 uintptr_t R = r->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= r->shape[i];
 bool aarr = arrp(a), barr = arrp(b);
 struct g_vec *va = aarr ? vec(a) : 0, *vb = barr ? vec(b) : 0;
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
   g_flo_t av = aarr ? vec_get_flo(va, oa) : sa, bv = barr ? vec_get_flo(vb, ob) : sb;
   if (cmp) vec_put_int(r, p, vcmp_flo(op, av, bv) ? -1 : 0);
   else vec_put_flo(r, p, vop_flo(op, av, bv)); }
  else {
   intptr_t av = aarr ? vec_get_int(va, oa) : ia, bv = barr ? vec_get_int(vb, ob) : ib;
   if (cmp) {                                    // bignum side (if any) sorts by sign: a-b ~ asign, or -bsign
    intptr_t t = (abig || bbig) ? vcmp_sign(op, abig ? asign : -bsign) : vcmp_int(op, av, bv);
    vec_put_int(r, p, t ? -1 : 0); }
   else vec_put_int(r, p, vop_int(op, av, bv)); }
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) {  // odometer
   if (++idx[j] < (intptr_t) r->shape[j]) break;
   idx[j] = 0; } } }

g_vm(g_vm_vbin, int op) {
 word a = Sp[0], b = Sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 if (!(aarr || ISNUM(a)) || !(barr || ISNUM(b)))   // each operand: array or scalar
  return *++Sp = nil, Ip++, Continue();
 uintptr_t ra = aarr ? vec(a)->rank : 0, rb = barr ? vec(b)->rank : 0;
 uintptr_t R = ra > rb ? ra : rb;
 // compute-type = max element type; a scalar int contributes the lowest type
 // (i8) so it never widens an int array, a scalar float forces the float lane.
 int ta = aarr ? (int) vec(a)->type : flop(a) ? (int) G_VT_FLO : (int) g_vt_i8;
 int tb = barr ? (int) vec(b)->type : flop(b) ? (int) G_VT_FLO : (int) g_vt_i8;
 int ct = ta > tb ? ta : tb;
 bool fdom = ct >= g_vt_f32, cmp = op >= VOP_LT;
 enum g_vec_type rt = cmp ? g_vt_i8 : (enum g_vec_type) ct;   // compare -> 0/-1 i8
 // broadcast shape + conformance, right-aligned; scalar locals only (no array,
 // so the trailing tail call below survives).
 uintptr_t n = 1;
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) return *++Sp = nil, Ip++, Continue();
  n *= da > db ? da : db; }
 uintptr_t bytes = sizeof(struct g_vec) + R * sizeof(word) + n * g_vt_size[rt];
 Have(b2w(bytes));
 a = Sp[0], b = Sp[1], aarr = arrp(a), barr = arrp(b);       // re-read post-Have
 struct g_vec *r = (struct g_vec*) Hp; Hp += b2w(bytes);
 ini_vec(r, rt, R);
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
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
static g_noinline void vmap2_fill(struct g_vec *r, word a, word b, g_flo_t (*fn)(g_flo_t, g_flo_t)) {
 uintptr_t R = r->rank, n = 1;
 for (uintptr_t i = 0; i < R; i++) n *= r->shape[i];
 bool aarr = arrp(a), barr = arrp(b);
 struct g_vec *va = aarr ? vec(a) : 0, *vb = barr ? vec(b) : 0;
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
  g_flo_t av = aarr ? vec_get_flo(va, oa) : sa, bv = barr ? vec_get_flo(vb, ob) : sb;
  vec_put_flo(r, p, fn(av, bv));
  for (intptr_t j = (intptr_t) R - 1; j >= 0; j--) {  // odometer
   if (++idx[j] < (intptr_t) r->shape[j]) break;
   idx[j] = 0; } } }

g_vm(g_vm_vmap2, g_flo_t (*fn)(g_flo_t, g_flo_t)) {
 word a = Sp[0], b = Sp[1];
 bool aarr = arrp(a), barr = arrp(b);
 if (!(aarr || ISNUM(a)) || !(barr || ISNUM(b)))   // each operand: array or scalar
  return *++Sp = nil, Ip++, Continue();
 uintptr_t ra = aarr ? vec(a)->rank : 0, rb = barr ? vec(b)->rank : 0;
 uintptr_t R = ra > rb ? ra : rb, n = 1;
 for (uintptr_t k = 0; k < R; k++) {               // broadcast shape, right-aligned
  uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) return *++Sp = nil, Ip++, Continue();
  n *= da > db ? da : db; }
 uintptr_t bytes = sizeof(struct g_vec) + R * sizeof(word) + n * g_vt_size[G_VT_FLO];
 Have(b2w(bytes));
 a = Sp[0], b = Sp[1], aarr = arrp(a), barr = arrp(b);       // re-read post-Have
 struct g_vec *r = (struct g_vec*) Hp; Hp += b2w(bytes);
 ini_vec(r, G_VT_FLO, R);
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (aarr && k < ra) ? vec(a)->shape[ra - 1 - k] : 1;
  uintptr_t db = (barr && k < rb) ? vec(b)->shape[rb - 1 - k] : 1;
  r->shape[R - 1 - k] = da > db ? da : db; }
 vmap2_fill(r, a, b, fn);
 return *++Sp = word(r), Ip++, Continue(); }
