#include "i.h"
g_vm(g_vm_tnew) {
 Have(Width(struct g_tab) + 1);
 struct g_tab *t = (struct g_tab*) Hp;
 struct g_kvs **tab = (struct g_kvs**) (t + 1);
 return
  Hp += Width(struct g_tab) + 1,
  tab[0] = 0,
  Sp[0] = word(ini_tab(t, 0, 1, tab)),
  Ip++,
  Continue(); }

op11(g_vm_tblp, tblp(Sp[0]) ? putnum(-1) : nil)

// relies on table capacity being a power of 2
static g_inline uintptr_t index_of_key(struct g *f, struct g_tab *t, intptr_t k) {
 return (t->cap - 1) & hash(f, k); }

word g_tget(struct g *f, word zero, word k, struct g_tab *t) {
 uintptr_t i = index_of_key(f, t, k);
 struct g_kvs *e = t->tab[i];
 while (e && !eql(f, k, e->key)) e = e->next;
 return e ? e->val : zero; }


g_noinline struct g *g_tput(struct g *f) {
 if (!g_ok(f)) return f;
 struct g_tab *t = (struct g_tab*) f->sp[2];
 word v = f->sp[1], k = f->sp[0];
 uintptr_t i = index_of_key(f, t, k);
 struct g_kvs *e = t->tab[i];
 while (e && !eql(f, k, e->key)) e = e->next;

 if (e) return e->val = v, f->sp += 2, f;

 if (!g_ok(f = g_have(f, Width(struct g_kvs) + 1))) return f;
 e = bump(f, Width(struct g_kvs));
 t = (struct g_tab*) f->sp[2];
 k = f->sp[0], v = f->sp[1];
 e->key = k, e->val = v, e->next = t->tab[i];
 t->tab[i] = e;
 intptr_t cap0 = t->cap, load = ++t->len / cap0;

 if (load < 2) return f->sp += 2, f;

 // grow the table
 intptr_t cap1 = 2 * cap0;
 struct g_kvs **tab0, **tab1;

 if (!g_ok(f = g_have(f, cap1 + 1))) return f;
 tab1 = bump(f, cap1);
 t = (struct g_tab*) f->sp[2];
 tab0 = t->tab;
 memset(tab1, 0, cap1 * sizeof(intptr_t));
 for (t->cap = cap1, t->tab = tab1; cap0--;)
  for (struct g_kvs *e, *es = tab0[cap0]; es;
   e = es,
   es = es->next,
   i = (cap1-1) & hash(f, e->key),
   e->next = tab1[i],
   tab1[i] = e);

 return f->sp += 2, f; }

static struct g_kvs *gtabdelr(struct g *f, struct g_tab *t, intptr_t k, intptr_t *v, struct g_kvs *e) {
 if (e) {
  if (eql(f, e->key, k)) return
   t->len--,
   *v = e->val,
   e->next;
  e->next = gtabdelr(f, t, k, v, e->next); }
 return e; }

static g_noinline intptr_t gtabdel(struct g *f, struct g_tab *t, intptr_t k, intptr_t v) {
 uintptr_t idx = index_of_key(f, t, k);
 t->tab[idx] = gtabdelr(f, t, k, &v, t->tab[idx]);
 if (t->cap > 1 && t->len / t->cap < 1) {
  intptr_t cap = t->cap;
  struct g_kvs *coll = 0, *x, *y; // collect all entries in one list
  for (intptr_t i = 0; i < cap; i++)
   for (x = t->tab[i], t->tab[i] = 0; x;)
    y = x, x = x->next, y->next = coll, coll = y;
  t->cap = cap >>= 1;
  for (intptr_t i; coll;)
   i = (cap - 1) & hash(f, coll->key),
   x = coll->next,
   coll->next = t->tab[i],
   t->tab[i] = coll,
   coll = x; }
 return v; }

g_vm(g_vm_get) {
 word z = Sp[0], k = Sp[1], x = Sp[2], n;
 if (bufp(x)) {                                  // mutable byte string: byte index
  struct g_str *s = buf_str(x);
  if (nump(k) && (n = getnum(k)) >= 0 && n < (word) len(s))
   z = putnum((unsigned char) txt(s)[n]); }
 else if (homp(x) && datp(x)) switch (typ(x)) {
  default: break;                               // sym_q is not indexable
  case vec_q: {
   // Array index: a fixnum for a rank-1 array, or a shape-list (row-major) for
   // rank-N; an empty/nil key derefs a rank-0 scalar box. Out-of-bounds or a
   // wrong-rank key falls through to the default `z`. Integer elements keep
   // integer type (EMIT_INT demotes-or-boxes); float elements box an f64.
   struct g_vec *v = vec(x);
   uintptr_t R = v->rank, off = 0; bool ok = false;
   if (R == 0) ok = nilp(k);
   else if (R == 1 && nump(k)) {
    intptr_t ix = getnum(k);
    if (ix >= 0 && ix < (intptr_t) v->shape[0]) off = ix, ok = true; }
   else if (twop(k)) {
    uintptr_t a = 0; ok = true;
    for (word l = k;; l = B(l)) {
     if (!twop(l)) { ok = a == R; break; }
     word ki = A(l);
     if (a >= R || !nump(ki)) { ok = false; break; }
     intptr_t ix = getnum(ki);
     if (ix < 0 || ix >= (intptr_t) v->shape[a]) { ok = false; break; }
     off = off * v->shape[a] + ix, a++; } }
   if (ok) { word _res; Have(BOX_REQ); v = vec(Sp[2]);
    if (v->type >= g_vt_f32) EMIT_FLO(vec_get_flo(v, off));
    else EMIT_INT(vec_get_int(v, off));
    z = _res; }
   break; }
  case tbl_q: z = g_tget(f, z, k, tbl(x)); break;
  case text_q:
   // Byte as its unsigned value 0..255 -- bytes are data, signedness is the
   // operator's job. txt is signed char[], so cast to avoid sign-extending a
   // high byte (e.g. 0xff -> -1) when binary data is indexed.
   if (nump(k) && (n = getnum(k)) >= 0 && n < (word) len(x))
    z = putnum((unsigned char) txt(x)[n]);
   break;
  case two_q:
   if (nump(k) && (n = getnum(k)) >= 0) {
    while (n-- && twop(x = B(x)));
    if (twop(x)) z = A(x); } }
 return Sp[2] = z, Sp += 2, Ip += 1, Continue(); }

// (put key val coll): table insert, or -- when coll is a buf -- store the
// byte val at index key. Both leave coll on the stack as the result. A buf
// store needs no allocation, so no GC dance; out-of-range/non-numeric is a
// silent no-op, matching the misuse convention of the other byte ops.
g_vm(g_vm_put) {
 word x = Sp[2], n;
 if (tblp(x)) {
  Pack(f);
  if (!g_ok(f = g_tput(f))) return gtrap(f);
  Unpack(f); }
 else {
  if (bufp(x) && nump(Sp[0]) && (n = getnum(Sp[0])) >= 0 && n < (word) len(buf_str(x)))
   txt(buf_str(x))[n] = (char) getnum(Sp[1]);
  Sp += 2; }
 return Ip += 1, Continue(); }

g_vm(g_vm_tdel) {
 if (tblp(Sp[1])) Sp[2] = gtabdel(f, (struct g_tab*) Sp[1], Sp[2], Sp[0]);
 return Sp += 2, Ip += 1, Continue(); }

g_vm(g_vm_tkeys) {
 intptr_t list = nil;
 if (tblp(Sp[0])) {
  struct g_tab *t = (struct g_tab*) Sp[0];
  intptr_t len = t->len;
  Have(len * Width(struct g_pair));
  struct g_pair *pairs = (struct g_pair*) Hp;
  Hp += len * Width(struct g_pair);
  for (uintptr_t i = t->cap; i;)
   for (struct g_kvs *e = t->tab[--i]; e; e = e->next)
    ini_two(pairs, e->key, list),
    list = (intptr_t) pairs, pairs++; }
 Sp[0] = list;
 Ip += 1;
 return Continue(); }

static g_noinline uintptr_t hash_two(struct g *f, word x) {
 word *base = off_pool(f), *top = base + f->len, *w = base;
 for (uintptr_t h = mix;; x = *--w) {
  while (twop(x)) {
   if (w == top) __builtin_trap();       // worklist overflow: a cycle
   h = (h ^ mix) * mix;                  // mark a pair node
   *w++ = A(x), x = B(x); }
  h = (h ^ hash(f, x)) * mix;          // x is a leaf: hash won't recur
  if (w == base) return h; } }

// general hashing method...
uintptr_t hash(struct g *f, intptr_t x) {
 if (nump(x)) return rot(x*mix);
 if (!datp(x)) {
   // it's a thread; hash by length. Threads live in the pool and end in a
   // G_THD_TAG word, so walk to that terminator rather than to a 0 word: the
   // length is GC-stable, and we never read past the object into un-written
   // pool space (the 0-walk did, depending on heap layout). Bounded by the
   // pool so a stray non-pool thread value can't run away.
   uintptr_t r = mix;
   word const *lo = ptr(f), *hi = ptr(f) + f->len;
   for (word const *y = (word const*) x; y >= lo && y < hi && !tagp(*y, lo, hi); y++)
     r ^= r * mix;
   return r; }
 switch (typ(x)) {
   default: __builtin_trap();
   case two_q: return hash_two(f, x);
   case sym_q: return sym(x)->code;
   case tbl_q: return mix;
   case vec_q: {
    uintptr_t len = g_vec_bytes(vec(x)), h = mix;
    for (uint8_t const *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return h; }
   case big_q: {
    uintptr_t len = g_big_bytes((struct g_big*) x), h = mix;
    for (uint8_t const *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return h; }
   case text_q: {
    uintptr_t n = len(x), h = mix;
    char const *bs = txt(x);
    while (n--) h ^= (uint8_t) *bs++, h *= mix;
    return h; } } }
