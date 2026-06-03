#include "i.h"

g_noinline bool eqv(struct g *f, word a, word b) {
 word *base = off_pool(f), *top = base + f->len, *w = base;
 for (;;) {
  if (a != b) {
   if (((a | b) & 1) || !datp(a) || !datp(b) || typ(a) != typ(b)) return false;
   switch (typ(a)) {
    default: return false;
    case two_q:
     if (top - w < 2) __builtin_trap();     // worklist overflow: a cycle
     *w++ = B(a), *w++ = B(b), a = A(a), b = A(b);
     continue;
    case vec_q: {
     size_t la = g_vec_bytes(vec(a)), lb = g_vec_bytes(vec(b));
     if (la != lb || memcmp(vec(a), vec(b), la)) return false;
     break; }
    case big_q: {
     struct g_big *x = (struct g_big*) a, *y = (struct g_big*) b;
     if (x->slen != y->slen) return false;
     size_t nb = (size_t) (x->slen < 0 ? -x->slen : x->slen) * sizeof(uint32_t);
     if (memcmp(x->limb, y->limb, nb)) return false;
     break; }
    case text_q:
     if (len(a) != len(b) || memcmp(txt(a), txt(b), len(a))) return false;
     break; } }
  if (w == base) return true;              // worklist drained: all equal
  b = *--w, a = *--w; } }

// (= a b) — value-equality with numeric promotion across the numeric tower
// (fixnum / boxed float / boxed wide int). With a float operand we compare as
// doubles (a box widens via box_get); otherwise eql handles it — two equal
// wide-int boxes match through eqv's vec arm (g_vec_bytes covers the type +
// payload), while a box and a fixnum never collide since boxes hold only
// out-of-fixnum-range values. Falls through to eql for non-numeric operands so
// symbol/pair/string identity is unchanged. Strictly looser than eqv, which
// still rejects mixed-type pairs (so table keys 3 and 3.0 stay distinct).
g_vm(g_vm_eq) {
 word a = Sp[0], b = Sp[1];
 // Over a rank>=1 array, `=` is elementwise -> a 0/-1 bool array (whole-array
 // equality is `(aall (= a b))`). Rank-0 boxes stay scalar (handled below).
 if (arrp(a) || arrp(b)) return Ap(g_vm_vbin, f, VOP_EQ);
 bool r;
 // A float operand compares as doubles across the whole numeric tower (fixnum /
 // float box / wide-int box / bignum all widen via TOFLO; a bignum loses
 // precision past 2^53, the documented float caveat). Otherwise eql: two equal
 // bignums match through eqv's big_q arm, and canonical demotion keeps a bignum
 // distinct from any fixnum/box of a different value.
 if (flop(a) || flop(b)) r = ISNUM(a) && ISNUM(b) && (TOFLO(a) == TOFLO(b));
 else r = eql(f, a, b);
 Sp[1] = r ? putnum(-1) : nil;
 return Sp++, Ip++, Continue(); }
