// map.c -- map, codegen backend. one translation unit of the runtime;
// the shared layouts and the cross-TU seam are src/love/love.h.
#include "love.h"
// a tray key -> a row-major element offset: a fixnum on a rank-1 tray, else a shape-list of
// `rank` fixnums; -1 = wrong rank or out of bounds. by value: an &local costs the tail jump.
static ai_inline intptr_t tray_off(struct ai_tray *v, word k) {
 if (v->rank == 1 && charmp(k)) {
  intptr_t ix = getcharm(k);
  return ix >= 0 && ix < (intptr_t) v->shape[0] ? ix : -1; }
 if (!chainp(k)) return -1;
 uintptr_t a = 0, o = 0;
 for (word l = k;; l = B(l)) {
  if (!chainp(l)) return a == v->rank ? (intptr_t) o : -1;
  word ki = A(l);
  if (a >= v->rank || !charmp(ki)) return -1;
  intptr_t ix = getcharm(ki);
  if (ix < 0 || ix >= (intptr_t) v->shape[a]) return -1;
  o = o * v->shape[a] + (uintptr_t) ix, a++; } }
#define map_hint_max (1u << 24)        // the `(tablet n)` size hint saturates to this bounded green charm
// this file's own, forward-declared so order within it does not matter.
static ai_noinline struct ai *map_grow(struct ai *g);
static ai_noinline word ai_mapdel(struct ai *g, word m, word k, word dflt);
// ============================================================================
// map (lookup-lambda backed by an open-addressed thread; see tabp comment)
// ============================================================================
// backing is internal -- only ever reached from a header[1], never applied as a
// l value; its ap answers () like lvm_cask should it ever be applied (it won't).
lvm(lvm_map_data) { // FIXME this seems to just return const (). what is this for? can we delete?
 Ip = cell(*++Sp); *Sp = ZeroPoint; ai_musttail return Continue(); }

// the backing slot of k, or -- if absent -- the first empty slot on its probe
// chain. load is kept < 3/4 so an empty slot always terminates the sound.
uintptr_t map_probe(struct ai *g, word m, word k, bool *found) {
 uintptr_t mask = map_cap(m) - 1, i = hash(g, k) & mask;
 word *s = map_slots(m);
 for (;; i = (i + 1) & mask) {
  word sk = s[2 * i];
  if (sk == map_gap) return *found = false, i;
  if (eql(g, k, sk)) return *found = true, i; } }

word ai_mapget(struct ai *g, word dflt, word k, word m) {
 bool found; uintptr_t i = map_probe(g, m, k, &found);
 return found ? map_slots(m)[2 * i + 1] : dflt; }

// the layered global read: g->stack is a chain of books walked head-first. a
// per-layer miss needs its own sentinel -- a stored () must shadow, never fall
// through. the l twin is ev.l's gv; keep them in step.
word stacklook(struct ai *g, word dflt, word k) {
 static union u const miss[1];
 for (word c = g->stack; chainp(c); c = B(c)) {
  word v = ai_mapget(g, word(miss), k, A(c));
  if (v != word(miss)) return v; }
 return dflt; }

// the layered macro read: each layer's macro table rides its [zero] slot; miss
// answers 0, the no-macro convention
word stacklook_macro(struct ai *g, word k) {
 static union u const miss[1];
 for (word c = g->stack; chainp(c); c = B(c)) {
  word mt = ai_mapget(g, word(miss), zero, A(c));
  if (mt == word(miss)) continue;
  word v = ai_mapget(g, word(miss), k, mt);
  if (v != word(miss)) return v; }
 return 0; }

// fill an empty cap-slot backing at b (cap a power of two); caller reserves it.
union u *map_fill_back(union u *b, uintptr_t cap) {
 b[0].ap = lvm_map_data, b[1].x = putcharm(0), b[2].x = putcharm(cap);
 for (uintptr_t i = 0; i < cap; i++) b[3 + 2 * i].x = map_gap, b[4 + 2 * i].x = zero;
 return tagthread(b, 3 + 2 * cap); }

// double the backing of the map at sp[2], rehash, swap into header[1]; the
// header never moves, so aliased references stay valid
static ai_noinline struct ai *map_grow(struct ai *g) {
 uintptr_t ncap = 2 * map_cap(g->sp[2]);
 if (!ai_ok(g = ai_have(g, 4 + 2 * ncap))) return g;
 word m = g->sp[2];                                 // re-fetch header after GC
 union u *nb = map_fill_back((union u*) g->hp, ncap);
 g->hp += 4 + 2 * ncap;
 word *os = map_slots(m), *ns = &nb[3].x;
 uintptr_t ocap = map_cap(m), nlen = 0, nmask = ncap - 1;
 for (uintptr_t j = 0; j < ocap; j++) {
  word k = os[2 * j];
  if (k == map_gap) continue;
  uintptr_t i = hash(g, k) & nmask;
  while (ns[2 * i] != map_gap) i = (i + 1) & nmask;
  ns[2 * i] = k, ns[2 * i + 1] = os[2 * j + 1], nlen++; }
 nb[1].x = putcharm(nlen);
 cell(m)[1].x = (word) nb;                         // swap backing; header identity stable
 gen_wb(g, m, (word) nb);                          // barrier: old header now points at the fresh (young) backing
 return g; }

// (put k v map): mutate in place; grow (may GC) on a new key past the load
// factor, re-reading k/v from the stack afterwards. leaves the map at sp[2].
ai_noinline struct ai *ai_mapput(struct ai *g) {
 if (!ai_ok(g)) return g;
 bool found;
 uintptr_t i = map_probe(g, g->sp[2], g->sp[0], &found);
 if (found) {
  gen_wb(g, map_back(g->sp[2]), g->sp[1]);         // barrier: a young value into an old backing
  return map_slots(g->sp[2])[2 * i + 1] = g->sp[1], g->sp += 2, g; }
 if ((map_len(g->sp[2]) + 1) * 4 >= map_cap(g->sp[2]) * 3) {
  if (!ai_ok(g = map_grow(g))) return g;
  i = map_probe(g, g->sp[2], g->sp[0], &found); }   // re-probe larger backing
 word *s = map_slots(g->sp[2]);
 s[2 * i] = g->sp[0], s[2 * i + 1] = g->sp[1];
 gen_wb(g, map_back(g->sp[2]), g->sp[0]);          // barrier: a young key ...
 gen_wb(g, map_back(g->sp[2]), g->sp[1]);          // ... or young value into an old backing
 cell(map_back(g->sp[2]))[1].x = putcharm(map_len(g->sp[2]) + 1);
 return g->sp += 2, g; }

// ai_mapdel: delete k, backward-shift the probe chain so no tombstone is
// needed; v is the not-found result. no allocation. leaves the map at sp[2].
static ai_noinline word ai_mapdel(struct ai *g, word m, word k, word dflt) {
 bool found;
 uintptr_t i = map_probe(g, m, k, &found);
 if (!found) return dflt;
 word *s = map_slots(m);
 uintptr_t mask = map_cap(m) - 1;
 for (uintptr_t j = i;;) {
  j = (j + 1) & mask;
  if (s[2 * j] == map_gap) break;
  uintptr_t h = hash(g, s[2 * j]) & mask;            // ideal slot of the probed key
  bool gap = i <= j ? (h <= i || h > j) : (h <= i && h > j);   // h not in (i, j]
  if (gap) {
   s[2 * i] = s[2 * j], s[2 * i + 1] = s[2 * j + 1];
   gen_wb(g, map_back(m), s[2 * i]), gen_wb(g, map_back(m), s[2 * i + 1]);  // delete shifts a (maybe young) k/v within an old backing
   i = j; } }
 s[2 * i] = map_gap, s[2 * i + 1] = zero;
 cell(map_back(m))[1].x = putcharm(map_len(m) - 1);
 return m; }

// C-callable fresh empty map, pushed on sp[0]. same shape as lvm_tablet.
struct ai *map_new(struct ai *g) {
 uintptr_t cap = map_min_cap, nb = 4 + 2 * cap;
 if (!ai_ok(g = ai_have(g, nb + map_head))) return g;
 union u *b = map_fill_back(cell(g->hp), cap), *h = cell(g->hp + nb);
 h[0].ap = lvm_map_lookup, h[1].x = (word) b, h[2].x = putcharm(++g->next_serial), tagthread(h, 3);
 g->hp += nb + map_head;
 return ai_push(g, 1, (word) h); }

// (tablet n): a fresh empty map; n is a size hint (presized below the 0.75 load
// factor, so inserting n known keys never rehashes). n<=0 keeps the min capacity.
lvm(lvm_tablet) {
 intptr_t raw = charmp(Sp[0]) ? getcharm(Sp[0]) : 0;          // saturate to a bounded green charm first
 uintptr_t hint = raw <= 0 ? 0 : (uintptr_t) raw > map_hint_max ? map_hint_max : (uintptr_t) raw,
           cap = map_min_cap;
 while (cap * 3 <= hint * 4) cap *= 2;                        // grow to hold `hint` below the 0.75 load factor
 uintptr_t nb = 4 + 2 * cap;
 Have(nb + map_head);
 union u *b = map_fill_back(cell(Hp), cap),
         *h = cell(Hp + nb);
 h[0].ap = lvm_map_lookup, h[1].x = (word) b, h[2].x = putcharm(++g->next_serial), tagthread(h, 3);
 Sp[0] = (word) h;
 Hp += nb + map_head; ai_musttail return Next(1); }

// (m k): map application is lookup, () if absent; unwinds like self-quote
lvm(lvm_map_lookup) {
 word v = ai_mapget(g, ZeroPoint, Sp[0], (word) Ip);   // a map miss answers () (the zero point), not the number 0
 Ip = cell(*++Sp), *Sp = v;
 ai_musttail return Continue(); }

op11(lvm_tabp, tabp(Sp[0]) ? putcharm(1) : zero)

// FIXME this predicate is confusing, let's try and remove it
// (lit? x): the upper segment of the lattice, ai_kind >= KTablet -- tablets and the
// tops above (closures, nifs, cask/port), never the fresh value-data below or a coin.
lvm(lvm_litp) {
 word x = Sp[0];
 bool lit = !coinp(x) && ai_kind(x) >= KTablet;                    // a coin is data
 Sp[0] = lit ? putcharm(1) : zero;
 ai_musttail return Next(1); }
// (hot? x): an opaque hot handle -- a cask or a port (a task is a fixnum id, not a handle)
op11(lvm_hotp, (caskp(Sp[0]) || iop(Sp[0])) ? putcharm(1) : zero)

// (hash x) -- the general hashing method exposed to l as a fixnum.
op11(lvm_dig, putcharm(hash(g, Sp[0])))

// (peep tray idx d) with idx an int tray: the gather. the answer takes idx's shape and the
// tray's kind, a miss the default; a complex or object tray, a float index or a default
// that is not a number answer the default whole, as a miss would
static ai_noinline void gather_fill(struct ai_tray *r, struct ai_tray *v, struct ai_tray *ki, ai_flo_t zf, intptr_t zi) {
 uintptr_t n = tray_nelem(r), m = tray_nelem(v);
 intptr_t *k = tray_data(ki);                          // ki is ai_Z, and r wears v's kind: asked once
 if (r->type == ai_R) { ai_flo_t *d = tray_data(r), *s = tray_data(v);
  for (uintptr_t i = 0; i < n; i++) { intptr_t j = k[i]; d[i] = j >= 0 && (uintptr_t) j < m ? s[j] : zf; } }
 else { intptr_t *d = tray_data(r), *s = tray_data(v);
  for (uintptr_t i = 0; i < n; i++) { intptr_t j = k[i]; d[i] = j >= 0 && (uintptr_t) j < m ? s[j] : zi; } } }
static lvm(lvm_gather) {
 word z = Sp[2];
 struct ai_tray *v = tray(Sp[0]), *ki = tray(Sp[1]);
 if (v->type > ai_R || ki->type >= ai_R || !(charmp(z) || gemp(z))) ai_musttail return Answerp(2, z);
 ai_flo_t zf = charmp(z) ? (ai_flo_t) getcharm(z) : gem_get(z);
 intptr_t zi = charmp(z) ? getcharm(z) : (intptr_t) zf;
 int type = v->type == ai_R ? ai_R : ai_Z;
 uintptr_t rank = ki->rank, n = tray_nelem(ki), bytes = tray_bytes(type, rank, n);
 Have(b2w(bytes));
 v = tray(Sp[0]), ki = tray(Sp[1]);             // re-read post-Have
 struct ai_tray *r = (struct ai_tray*) Hp;
 Hp += b2w(bytes);
 ini_tray(r, type, rank);
 for (uintptr_t i = 0; i < rank; i++) r->shape[i] = ki->shape[i];
 gather_fill(r, v, ki, zf, zi);
 ai_musttail return Answerp(2, word(r)); }
// (pin tray idx vals) with idx an int tray: the scatter, gather's mirror. a fresh copy of
// the tray with vals stored at idx in order, so a later index wins; vals a number or a
// numeric tray as long as idx, an index out of range skipped. a complex or object tray,
// a float index or vals of another length answer the tray unchanged
static lvm(lvm_scatter) {
 struct ai_tray *v = tray(Sp[0]), *ki = tray(Sp[1]);
 word z = Sp[2];
 bool zt = trayp(z);
 if (v->type > ai_R || ki->type >= ai_R
     || !(zt ? tray(z)->type <= ai_R && tray_nelem(tray(z)) == tray_nelem(ki) : (charmp(z) || gemp(z))))
  ai_musttail return Answerp(2, Sp[0]);
 uintptr_t req = b2w(ai_tray_bytes(v));
 Have(req);
 struct ai_tray *r = (struct ai_tray*) Hp; Hp += req;
 memcpy(r, tray(Sp[0]), ai_tray_bytes(tray(Sp[0])));   // re-read post-Have
 ki = tray(Sp[1]), z = Sp[2];
 uintptr_t n = tray_nelem(ki), m = tray_nelem(r);
 intptr_t *k = tray_data(ki);
 struct ai_tray *zv = zt ? tray(z) : 0;
 ai_flo_t zf = zt ? 0 : charmp(z) ? (ai_flo_t) getcharm(z) : gem_get(z);
 intptr_t zi = zt ? 0 : charmp(z) ? getcharm(z) : (intptr_t) zf;
 bool zr = zt && zv->type == ai_R;
 if (r->type == ai_R) { ai_flo_t *d = tray_data(r);
  for (uintptr_t i = 0; i < n; i++) { intptr_t j = k[i]; if (j >= 0 && (uintptr_t) j < m)
   d[j] = !zt ? zf : zr ? ((ai_flo_t*) tray_data(zv))[i] : (ai_flo_t) ((intptr_t*) tray_data(zv))[i]; } }
 else { intptr_t *d = tray_data(r);
  for (uintptr_t i = 0; i < n; i++) { intptr_t j = k[i]; if (j >= 0 && (uintptr_t) j < m)
   d[j] = !zt ? zi : zr ? (intptr_t) ((ai_flo_t*) tray_data(zv))[i] : ((intptr_t*) tray_data(zv))[i]; } }
 ai_musttail return Answerp(2, word(r)); }

lvm(lvm_peep) {                                // (peep coll key default): collection-first
 word x = Sp[0], k = Sp[1], z = Sp[2], n;
 if (caskp(x)) {                                 // mutable byte string: byte index
  struct ai_str *s = cask(x)->str;
  if (charmp(k) && (n = getcharm(k)) >= 0 && n < (word) len(s))
   z = putcharm((unsigned char) txt(s)[n]); }
 else if (tabp(x)) z = ai_mapget(g, z, k, x);     // map lookup (not a data sentinel)
 else if (evenp(x) && datp(x)) switch (typ(x)) {
  default: break;                               // a bare mint (DMint) is not indexable
  case DGem:                                    // a rank-0 scalar float: a zero key derefs to itself
  case DBig:                                    // ... same for a boxed integer
  case DTwin:                                   // ... and a complex scalar
   if (zerop(k)) z = x;
   break;
  case DTray: {
   // array index: a fixnum (rank-1) or a row-major shape-list (rank-N);
   // out-of-bounds or wrong rank falls through to the default
   struct ai_tray *v = tray(x);
   if (trayp(k)) ai_musttail return Ap(lvm_gather, g);   // a tray of indices gathers
   intptr_t o = tray_off(v, k); uintptr_t off = (uintptr_t) o; bool ok = o >= 0;
   if (ok && v->type == ai_O) z = tray_get_obj(v, off);   // object: the slot is the value
   else if (ok && v->type == ai_C) {                       // packed complex -> a (re,im) box
    Have(twin_req); v = tray(Sp[0]);                      // re-read coll (Sp[0]) post-Have
    ai_flo_t *fp = tray_data(v);
    z = mk_twin(&Hp, fp[2*off], fp[2*off+1]); }
   else if (ok) { word _res; Have(box_req); v = tray(Sp[0]);
    if (v->type >= ai_R) emit_gem(_res, tray_get_flo(v, off));
    else emit_int(_res, tray_get_int(v, off));
    z = _res; }
   break; }
  case DString:
   // byte as its unsigned value 0..255 (txt is signed char[]: cast, or a high byte sign-extends)
   if (charmp(k) && (n = getcharm(k)) >= 0 && n < (word) len(x))
    z = putcharm((unsigned char) txt(x)[n]);
   break;
  case DChain:
   if (charmp(k) && (n = getcharm(k)) >= 0) {
    while (n-- && chainp(x = B(x)));
    if (chainp(x)) z = A(x); } }
 ai_musttail return Answerp(2, z); }

// (pin coll key val): a map or cask has a cell, so the write is in place and the same
// collection answers; text, a chain and a tray have none and answer a fresh one, a tray
// keyed by a tray of indices scattering into it (lvm_scatter). a rank-0
// scalar is the one kind peep reads and pin cannot write. out-of-range or wrong-kind is a
// silent no-op answering coll, the byte ops' misuse convention.
lvm(lvm_pin) {
 word x = Sp[0], n;                              // coll
 if (tabp(x)) {
  Sp[0] = Sp[1], Sp[1] = Sp[2], Sp[2] = x;       // ai_mapput wants (sp0,sp1,sp2)=(key,val,coll)
  LvmCall(g, ai_mapput) }
 if (caskp(x)) {
  if (charmp(Sp[1]) && charmp(Sp[2]) && (n = getcharm(Sp[1])) >= 0 && n < (word) len(cask(x)->str))
   txt(cask(x)->str)[n] = (char) getcharm(Sp[2]);    // index = key = Sp[1], val = Sp[2]
  ai_musttail return Answerp(2, x); }
 if (evenp(x) && datp(x)) switch (typ(x)) {
  default: break;                                // a mint, a scalar: nothing to pin into
  case DString: {                                // one byte replaced in a fresh text
   if (!charmp(Sp[1]) || !charmp(Sp[2])) break;
   if ((n = getcharm(Sp[1])) < 0 || n >= (word) len(x)) break;
   uintptr_t sz = len(x), req = str_width(sz);
   Have(req);
   struct ai_str *s = ini_str(str(Hp), sz); Hp += req;
   memcpy(s->bytes, txt(Sp[0]), sz);             // re-read coll: the Have may have moved it
   s->bytes[n] = (char) getcharm(Sp[2]);
   ai_musttail return Answerp(2, word(s)); }
  case DChain: {                                 // the prefix copied, the tail shared
   if (!charmp(Sp[1]) || (n = getcharm(Sp[1])) < 0 || n >= (word) llen(x)) break;
   Have((uintptr_t) (n + 1) * Width(struct ai_chain));
   struct ai_chain *w = (struct ai_chain*) Hp, *base = w;
   Hp += (uintptr_t) (n + 1) * Width(struct ai_chain);
   word l = Sp[0];                               // re-read coll post-Have
   for (word i = 0; i < n; i++, w++, l = B(l)) ini_chain(w, A(l), word(w + 1));
   ini_chain(w, Sp[2], B(l));                    // the pinned cell, then the old tail
   ai_musttail return Answerp(2, word(base)); }
  case DTray: {                                  // the whole payload copied, one slot stored
   if (trayp(Sp[1])) ai_musttail return Ap(lvm_scatter, g);   // a tray of indices scatters
   intptr_t o = tray_off(tray(x), Sp[1]);
   if (o < 0) break;
   uintptr_t req = b2w(ai_tray_bytes(tray(x)));
   Have(req);
   struct ai_tray *v = (struct ai_tray*) Hp; Hp += req;
   memcpy(v, tray(Sp[0]), ai_tray_bytes(tray(Sp[0])));   // re-read coll post-Have
   if (!tray_put(v, (uintptr_t) o, Sp[2])) { Hp -= req; break; }   // a non-number into a numeric tray
   ai_musttail return Answerp(2, word(v)); } }
 ai_musttail return Answerp(2, x); }

// (pull coll key default): remove key from a map, answering its value or default
// (symmetry with peep); a non-map coll yields default
lvm(lvm_pull) {
 word coll = Sp[0], v = Sp[2];                   // default
 if (tabp(coll)) {
  v = ai_mapget(g, Sp[2], Sp[1], coll);           // value, or default if absent
  ai_mapdel(g, coll, Sp[1], Sp[2]); }             // remove in place (no-op if absent)
 ai_musttail return Answerp(2, v); }

lvm(lvm_keys) {
 intptr_t list = ZeroPoint;                         // () terminator / empty-map result (zero-ontology)
 if (tabp(Sp[0])) {
  uintptr_t cap = map_cap(Sp[0]), n = map_len(Sp[0]);
  Have(n * Width(struct ai_chain));
  struct ai_chain *chains = (struct ai_chain*) Hp;
  Hp += n * Width(struct ai_chain);
  word *s = map_slots(Sp[0]);                    // re-read after Have (GC may move the map)
  for (uintptr_t i = cap; i;)
   if (s[2 * --i] != map_gap)
    ini_chain(chains, s[2 * i], list), list = (intptr_t) chains, chains++; }
 Sp[0] = list;
 ai_musttail return Next(1); }

// the anchor an out-of-pool ap hashes against: the offset survives a bake/wake where the
// raw address does not, so a nif-keyed table still finds its buckets at wake.
static const char hash_base[1] = {0};
// the walk-from-nothing entry; hash_at (src/love/arr.c) is the same walk continued above a live
// worklist. a charm settles here so the hot key never pays for the hand-off.
uintptr_t hash(struct ai *g, intptr_t x) {
 word *top; return charmp(x) ? rot(x*mix) : hash_at(g, x, ai_gap(g, &top)); }

// a leaf's own hash, nothing walked under it: -> 0 the answer is in *out; 1 hash the
// \-expr in *src, nothing filled; 2 bridge the closure in *src, falling back to *out when
// it will not residualize; 3 fold the cells of the object tray in *src over the header hash
// in *out. a chain never arrives -- hash_at spines it -- and a sourced lambda leaves by 1
// or 2, which is what keeps this side free of the source walk.
// a function hashes as `=` reads it (arr.c's fn_eq): its thread's words from the value to the
// terminator, a pointer back into its own thread by its offset, any other heap word by being
// one -- the worklist compares those, and a hash owes `=` only that what it joins hashes alike.
// a partial folds its base and its captures, a native is its twin, a carrier its length (it
// is equal to itself alone). out of the pool, an offset from hash_base. all GC-stable.
// d levels of those heap words fold their own leaf hash, the rest a 2: threads alike in
// shape but not in what they call part here, where the worklist would walk them deep.
// the length and a prefix are read, which bounds a probe on a big thread
static uintptr_t fn_hash_d(struct ai *g, word x, int d);
static uintptr_t fn_word(struct ai *g, word v, int d) {
 uintptr_t t; word src;
 if (!d || (datp(v) && typ(v) == DChain)) return 2;
 if (!datp(v)) return fn_hash_d(g, v, d - 1);
 return hash_leaf(g, v, &t, &src), t; }

static uintptr_t fn_hash(struct ai *g, word x) { return fn_hash_d(g, x, 1); }
static uintptr_t fn_hash_d(struct ai *g, word x, int d) {
 x = fn_meaning(g, x);
 if (!in_heap(g, x)) return rot(((intptr_t) x - (intptr_t) hash_base) * mix);
 union u *k = cell(x);
 struct ai_tag *tg = ttag(g, k);
 uintptr_t h = mix;
 if (fn_carrier(k)) {
  for (union u *y = k; y < (union u*) tg; y++) h ^= h * mix;
  return h; }
 if (fn_partialp(k)) {
  int n;
  union u *b = fn_base(k, &n);
  h = (fn_hash_d(g, (word) b, d) ^ (uintptr_t) n) * mix;
  for (int i = 0; i < n; i++) { word v = fn_arg(k, i, n); h = (h ^ (uintptr_t) (charmp(v) ? v : 2)) * mix; }
  return h; }
 word hd = (word) tag_head(tg), e = (word) tg;
 union u *z = (union u*) tg;
 h = (h ^ (uintptr_t) (z - k)) * mix;
 if (z - k > (d ? 32 : 8)) z = k + (d ? 32 : 8);
 for (union u *y = k; y < z; y++) {
  word v = y->x;
  if (!(v & 1) && !(v >= hd && v <= e)) { word m = fn_meaning(g, v); if (m >= hd && m <= e) v = m; }
  uintptr_t t = (v & 1) ? (uintptr_t) v
              : v >= hd && v <= e ? (uintptr_t) (v - x)
              : in_heap(g, v) ? fn_word(g, v, d) : (uintptr_t) (v - (intptr_t) hash_base);
  h = (h ^ t) * mix; }
 return h; }

int hash_leaf(struct ai *g, word x, uintptr_t *out, word *src) {
 if (charmp(x)) return *out = rot(x*mix), 0;
 if (!datp(x)) return *out = fn_hash(g, x), 0;
 switch (typ(x)) {
   case DChain: break;                            // hash_at spines a chain; one reaching here is a bug
   case DMint: return *out = sym(x)->serial, 0;
   case DNom: return *out = nom(x)->dig, 0;        // the cached spelling hash -- a serial would key
                                                   // bucket order to intern history (a reproducible-
                                                   // build leak); same-spelled noms collide, `=` separates
   case DTray: {
    // an object tray's payload words are pointers, so only the header hashes here and
    // hash_at folds the cells: two trays built apart hold one set of values behind two
    // sets of pointers, and `=` reads through to the values
    bool obj = objtrayp(x);
    uintptr_t len = obj ? (uintptr_t) ((uint8_t*) tray_data(tray(x)) - (uint8_t*) x)
                        : ai_tray_bytes(tray(x)), h = mix;
    for (uint8_t const *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return *out = h, obj ? (*src = x, 3) : 0; }
   case DBig: {
    uintptr_t len = ai_big_bytes(big(x)), h = mix;
    for (uint8_t const *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return *out = h, 0; }
   case DGem: {                                 // hash the lean box (ap is GC-stable, payload is the value)
    uintptr_t len = gem_req * sizeof(word), h = mix;
    for (uint8_t const *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return *out = h, 0; }
   case DTwin: {                                // same: hash the lean (ap, re, im) box bytes
    uintptr_t len = twin_req * sizeof(word), h = mix;
    for (uint8_t const *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return *out = h, 0; }
   case DString: {
    uintptr_t n = len(x), h = mix;
    char const *bs = txt(x);
    while (n--) h ^= (uint8_t) *bs++, h *= mix;
    return *out = h, 0; } }
 __builtin_trap(); }

// ============================================================================
// codegen backend brick 1 -- the native-install seam (provisional; -> `ev`)
// ============================================================================
// the native finalizer: the cell's header duplicates its code address (dead = the
// out-of-pool addr, live = a forward), and the arena takes the blob back
// hosted here reads "not a bare board": mooncc predefines 1 and only src/inle/ passes 0.
// wasm is hosted too and declines below, on __wasm__.
#if __STDC_HOSTED__
static void nat_free(struct ai *g, void *p) { code_free(g, (char*) ((union u*) p)[0].ap); }
#endif

// FIXME doesn't belong in this file
// (nif code interp arity): emitted bytes -> a transparent applicable native closure
// (the lvm ABI: g=rdi Ip=rsi Hp=rdx Sp=rcx). the cell is [header code|cur (arity)
// interp lvm_ret n (extras)] -- arity 1 enters the body directly, arity>=2 curries to
// saturation through lvm_cur, and lvm_ret sits at the same offset in both so the emitted
// body is layout-blind. value[1] is the interp twin, so a decline (bad args, no code
// pages, inle) simply answers it and every caller falls back to bytecode. cell[0]
// duplicates the code addr for run_finalizers' dead/live test; internal, the egg mops it.
// nifx adds an extras word (value[3]+8 = Ip+32) for refs a native needs beyond the twin.
// code is the arena's (hosted) or a heap string's (freestanding, where RAM runs as it is)
lvm(lvm_nifx) {                               // Sp[0]=code Sp[1]=interp Sp[2]=arity [Sp[3]=extras]
 int xtra = Ip->ap == lvm_nifx, nsp = xtra ? 3 : 2;   // entered at its own word (nif's tail-jumps here with Ip at nif's)
 word codebuf = Sp[0];
 intptr_t ar = oddp(Sp[2]) ? getcharm(Sp[2]) : 0;
 if (!(strp(codebuf) || caskp(codebuf)) || ar < 1) ai_musttail return Answerp(nsp, Sp[1]);
 uintptr_t n = len(bytes_of(codebuf));
 if (n == 0) ai_musttail return Answerp(nsp, Sp[1]);
#ifdef __wasm__                                // wasm has no executable code pages: a jump to a data address traps.
 ai_musttail return Answerp(nsp, Sp[1]);  //  decline unconditionally -> the interp twin runs
#endif
 char *code;
#if __STDC_HOSTED__
 // inle declines: its heap rides the NX hhdm window and would move under the collector
 // besides, so the interp twin runs. a metal door would want low-window pages, which keep X.
 if (__ai_osv < 0) ai_musttail return Answerp(nsp, Sp[1]);
 Have(10 + Width(struct ai_fz));              // 10 covers every cell (5..8 words) + tag + fz
 code = code_install(g, txt(bytes_of(Sp[0])), n);   // reload codebuf: a GC in Have may have moved it
 if (!code) ai_musttail return Answerp(nsp, Sp[1]);
#else
 Have(str_width(n) + 10);                     // freestanding: RAM is executable, a heap copy runs
 struct ai_str *s = ini_str(str(Hp), n); Hp += str_width(n);
 memcpy(txt(s), txt(bytes_of(Sp[0])), n);
 __builtin___clear_cache(txt(s), txt(s) + n);
 code = txt(s);
#endif
 union u *k = (union u*) Hp;
 uintptr_t w;
 if (ar == 1) {                               // direct-entry cell
  k[0].ap = (lvm_t*) code;                    // header (== code, out-of-pool): finalizer dead-detect
  k[1].ap = (lvm_t*) code;                    // code  (value[0]): the emitted body, the entry
  k[2].x  = Sp[1];                            // interp(value[1]): deopt fallback
  k[3].ap = lvm_ret;                          // value[2]: fast-path return
  k[4].x  = putcharm(0);                      // ret n=1
  w = 5;
 } else {                                     // lvm_cur cell
  k[0].ap = (lvm_t*) code;                    // header (out-of-pool): finalizer dead-detect
  k[1].ap = lvm_cur;                          // value[0]: curry to saturation
  k[2].x  = putcharm(ar);
  k[3].ap = (lvm_t*) code;                    // native body (lvm_cur resume Ip+2)
  k[4].x  = Sp[1];                            // interp: deopt fallback
  k[5].ap = lvm_ret;
  k[6].x  = putcharm(ar - 1);                 // ret pops n=arity
  w = 7; }
 if (xtra) k[w++].x = Sp[3];                  // extras at Ip+32 from the body entry, either arity
 Hp += w + 1;
 tagthread(k, w);
#if __STDC_HOSTED__
 struct ai_fz *z = (struct ai_fz*) Hp; Hp += Width(struct ai_fz);
 z->p = k, z->fn = nat_free, z->next = g->fz, g->fz = z;
#endif
 ai_musttail return Answerp(nsp, word(k + 1)); }
lvm(lvm_nif) { ai_musttail return Ap(lvm_nifx, g); }   // the same build, no extras word

// a deferred native: a cell of nifx's shape built before its compile can see every sibling,
// patched once it can. until then, and for good if that compile declines, its code slot
// forwards to the interp twin; a patch lays the native's code in the header and the code
// slot, its extras beside them and the native itself past those, which keeps the code alive
//   ar 1: [hdr code interp lvm_ret 0 E N]    ar>1: [hdr cur ar code interp lvm_ret ar-1 E N]
lvm(lvm_deferfwd) {                           // entered at the code slot, as a native is
 union u *e = cell(Ip[1].x);
 Ip = Ip[-2].ap == lvm_cur && oddp(Ip[-1].x) ? e + 2 : e;
 ai_musttail return Continue(); }
// (defercell interp arity)
static lvm(lvm_defercell) {
 intptr_t ar = oddp(Sp[1]) ? getcharm(Sp[1]) : 0;
 if (ar < 1) ai_musttail return Answerp(1, Sp[0]);
 Have(10);
 union u *k = (union u*) Hp;
 uintptr_t w = 0;
 k[w++].ap = lvm_deferfwd;
 if (ar > 1) k[w++].ap = lvm_cur, k[w++].x = putcharm(ar);
 k[w++].ap = lvm_deferfwd, k[w++].x = Sp[0], k[w++].ap = lvm_ret, k[w++].x = putcharm(ar - 1);
 k[w++].x = putcharm(0), k[w++].x = putcharm(0);
 Hp += w + 1;
 tagthread(k, w);
 ai_musttail return Answerp(1, word(k + 1)); }
static union u const nif_defercell[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_defercell}, {lvm_ret0}};
LvNif("defercell", nif_defercell, NULL);
// (deferpatch cell native): a native of nif's shape (its header its code) patches the cell; the
// interp twin back, or anything else, leaves it forwarding. answers the cell
static lvm(lvm_deferpatch) {
 union u *v = cell(Sp[0]), *c = v->ap == lvm_cur ? v + 2 : v;
 word n = Sp[1];
 if (c->ap == lvm_deferfwd && evenp(n) && n != c[1].x && !in_data(cell(n)->ap)) {
  union u *m = cell(n), *mc = m->ap == lvm_cur ? m + 2 : m;
  if (mc[2].ap == lvm_ret && m[-1].ap == mc->ap) {
   c->ap = v[-1].ap = mc->ap;
   if ((mc[4].x & 3) != ai_thread_tag) c[4].x = mc[4].x, gen_wb_cell(g, &c[4], mc[4].x);
   c[5].x = n, gen_wb_cell(g, &c[5], n); } }
 ai_musttail return Answerp(1, Sp[0]); }
static union u const nif_deferpatch[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_deferpatch}, {lvm_ret0}};
LvNif("deferpatch", nif_deferpatch, NULL);


// (pour dst doff src soff n): copy n bytes of string-or-cask src into cask dst,
// clamped to both backings (an out-of-range ask copies less, never tramples); answers dst
lvm(lvm_bcopy) {
 word dst = Sp[0], src = Sp[2];
 if (caskp(dst) && (strp(src) || caskp(src))) {
  struct ai_str *d = cask(dst)->str, *s = bytes_of(src);
  intptr_t doff = getcharm(Sp[1]), soff = getcharm(Sp[3]), n = getcharm(Sp[4]),
           dl = len(d), sl = len(s);
  if (n < 0) n = 0;
  if (doff < 0) doff = 0;
  if (soff < 0) soff = 0;
  if (doff + n > dl) n = dl - doff;
  if (soff + n > sl) n = sl - soff;
  if (n > 0) memmove(txt(d) + doff, txt(s) + soff, n); }
 ai_musttail return Answerp(4, dst); }

// (xlat s tbl dst): every byte of s through a 512-byte table into cask dst, answering
// the count written -- tbl[c] is c's image, tbl[256 + c] its mode: 0 dropped, 1
// written, 2 written unless it repeats the byte written last. tr's three faces in one
// loop, and any byte map's. () when the shapes are wrong; dst must hold #s.
lvm(lvm_xlat) {
 word s = Sp[0], t = Sp[1], d = Sp[2];
 if (!(strp(s) || caskp(s)) || !(strp(t) || caskp(t)) || !caskp(d))
  ai_musttail return Answerp(2, ZeroPoint);
 struct ai_str *ss = bytes_of(s), *ts = bytes_of(t), *ds = cask(d)->str;
 uintptr_t n = len(ss);
 if (len(ts) < 512 || len(ds) < n) ai_musttail return Answerp(2, ZeroPoint);
 unsigned char const *sp = (unsigned char const*) txt(ss), *tb = (unsigned char const*) txt(ts);
 unsigned char *dp = (unsigned char*) txt(ds);
 uintptr_t k = 0;
 int last = -1;
 for (uintptr_t i = 0; i < n; i++) {
  unsigned c = sp[i], m = tb[256 + c];
  if (!m) continue;
  unsigned v = tb[c];
  if (m == 2 && (int) v == last) continue;
  dp[k++] = (unsigned char) v, last = (int) v; }
 ai_musttail return Answerp(2, putcharm((intptr_t) k)); }
