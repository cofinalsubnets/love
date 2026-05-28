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
    case text_q:
     if (len(a) != len(b) || memcmp(txt(a), txt(b), len(a))) return false;
     break; } }
  if (w == base) return true;              // worklist drained: all equal
  b = *--w, a = *--w; } }

// (= a b) — value-equality with numeric promotion across nump/flop.
// Falls through to eql for non-numeric operands so symbol/pair/string
// identity is unchanged. Note: this is strictly looser than eqv, which
// still rejects mixed-type pairs (so table keys 3 and 3.0 stay distinct).
g_vm(g_vm_eq) {
 word a = Sp[0], b = Sp[1];
 bool eq;
 if (nump(a) && nump(b)) eq = a == b;
 else if ((nump(a) || flop(a)) && (nump(b) || flop(b))) {
  g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a);
  g_flo_t bd = nump(b) ? (g_flo_t) getnum(b) : flo_get(b);
  eq = ad == bd;
 } else eq = eql(f, a, b);
 Sp[1] = eq ? putnum(-1) : nil;
 Sp += 1; Ip++; return Continue(); }
