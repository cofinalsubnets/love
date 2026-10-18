// tablet.c -- tablets (open-addressed maps), peep/pin over every collection, hashing,
// and the native-install seam
#include "love.h"
// a tray key -> a row-major offset, -1 for wrong rank or out of bounds. by value: an &local
// costs the tail jump
static love_inline intptr_t tray_off(struct tray *v, word k) {
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
#define map_hint_max (1u << 24)        // where (tablet n)'s hint saturates
static love_noinline struct g *map_grow(struct g *g);
static love_noinline word mapdel(struct g *g, word m, word k, word dflt);
// a backing's ap, reached only from a header, never applied: answers () if it ever is
lvm(lvm_map_data) { // FIXME this just returns const (); can we delete it?
 Ip = cell(*++Sp); *Sp = ZeroPoint; love_musttail return Continue(); }

// k's slot, or the first empty one on its chain: load < 3/4 keeps an empty slot to stop at.
// a walk that spent the gap answers not found with g->walk set
uintptr_t map_probe(struct g *g, word m, word k, bool *found) {
 uintptr_t mask = map_cap(m) - 1, i = hash(g, k) & mask;
 word *s = map_slots(m);
 for (;; i = (i + 1) & mask) {
  if (g->walk) return *found = false, 0;
  word sk = s[2 * i];
  if (sk == map_gap) return *found = false, i;
  if (eql(g, k, sk)) return *found = true, i; } }

word mapget(struct g *g, word dflt, word k, word m) {
 bool found; uintptr_t i = map_probe(g, m, k, &found);
 return found ? map_slots(m)[2 * i + 1] : dflt; }

// the layered global read, books head-first; a sentinel miss, as a stored () must shadow.
// ev.l's gv is the twin: keep them in step
word stacklook(struct g *g, word dflt, word k) {
 static union u const miss[1];
 for (word c = g->stack; chainp(c); c = B(c)) {
  word v = mapget(g, word(miss), k, A(c));
  if (v != word(miss)) return v; }
 return dflt; }

// each layer's macro table rides its [zero] slot; a miss answers 0
word stacklook_macro(struct g *g, word k) {
 static union u const miss[1];
 for (word c = g->stack; chainp(c); c = B(c)) {
  word mt = mapget(g, word(miss), zero, A(c));
  if (mt == word(miss)) continue;
  word v = mapget(g, word(miss), k, mt);
  if (v != word(miss)) return v; }
 return 0; }

// an empty backing of cap slots (a power of two) at b, reserved by the caller
union u *map_fill_back(union u *b, uintptr_t cap) {
 struct tablet_back *t = tablet_back(b);
 t->ap = lvm_map_data, t->len = putcharm(0), t->cap = putcharm(cap);
 for (uintptr_t i = 0; i < cap; i++) t->slot[2 * i] = map_gap, t->slot[2 * i + 1] = zero;
 return tagthread(b, map_back_words(cap) - 1); }

// double the backing of the map at sp[2]; the header never moves, so aliases hold
static love_noinline struct g *map_grow(struct g *g) {
 uintptr_t ncap = 2 * map_cap(g->sp[2]);
 if (!ok(g = have(g, map_back_words(ncap)))) return g;
 word m = g->sp[2];                                 // after GC
 union u *nb = map_fill_back((union u*) g->hp, ncap);
 g->hp += map_back_words(ncap);
 word *os = map_slots(m), *ns = tablet_back(nb)->slot;
 uintptr_t ocap = map_cap(m), nlen = 0, nmask = ncap - 1;
 for (uintptr_t j = 0; j < ocap; j++) {
  word k = os[2 * j];
  if (k == map_gap) continue;
  uintptr_t i = hash(g, k) & nmask;
  if (g->walk) return g;                          // a key's walk spent the gap: the old backing stands
  while (ns[2 * i] != map_gap) i = (i + 1) & nmask;
  ns[2 * i] = k, ns[2 * i + 1] = os[2 * j + 1], nlen++; }
 tablet_back(nb)->len = putcharm(nlen);
 tablet(m)->back = (word) nb;
 gen_wb(g, m, (word) nb);
 return g; }

// (put k v map) in place; a new key past the load grows (may GC). leaves the map at sp[2]
love_noinline struct g *mapput(struct g *g) {
 if (!ok(g)) return g;
 bool found;
 uintptr_t i;
 for (;; g = walk_room(g)) {                        // a walk spent the gap: the room, and the put again
  if (!ok(g)) return g;
  i = map_probe(g, g->sp[2], g->sp[0], &found);
  if (g->walk) continue;
  if (found) {
   gen_wb(g, map_back(g->sp[2]), g->sp[1]);
   return map_slots(g->sp[2])[2 * i + 1] = g->sp[1], g->sp += 2, g; }
  if ((map_len(g->sp[2]) + 1) * 4 < map_cap(g->sp[2]) * 3) break;
  if (!ok(g = map_grow(g))) return g;
  if (g->walk) continue;
  i = map_probe(g, g->sp[2], g->sp[0], &found);
  if (!g->walk) break; }
 word *s = map_slots(g->sp[2]);
 s[2 * i] = g->sp[0], s[2 * i + 1] = g->sp[1];
 gen_wb(g, map_back(g->sp[2]), g->sp[0]);
 gen_wb(g, map_back(g->sp[2]), g->sp[1]);
 map_len_set(g->sp[2], map_len(g->sp[2]) + 1);
 return g->sp += 2, g; }

// delete k by backward shift, no tombstones; dflt when absent. no allocation
static love_noinline word mapdel(struct g *g, word m, word k, word dflt) {
 bool found;
 uintptr_t i = map_probe(g, m, k, &found);
 if (!found) return dflt;
 word *s = map_slots(m);
 uintptr_t mask = map_cap(m) - 1;
 // every key the shift may hash, hashed before a slot is written: a walk that spends the
 // gap leaves the map as it was, for the op to run again
 for (uintptr_t j = (i + 1) & mask; s[2 * j] != map_gap; j = (j + 1) & mask)
  if (hash(g, s[2 * j]), g->walk) return dflt;
 for (uintptr_t j = i;;) {
  j = (j + 1) & mask;
  if (s[2 * j] == map_gap) break;
  uintptr_t h = hash(g, s[2 * j]) & mask;            // its ideal slot
  bool gap = i <= j ? (h <= i || h > j) : (h <= i && h > j);   // h not in (i, j]
  if (gap) {
   s[2 * i] = s[2 * j], s[2 * i + 1] = s[2 * j + 1];
   gen_wb(g, map_back(m), s[2 * i]), gen_wb(g, map_back(m), s[2 * i + 1]);
   i = j; } }
 s[2 * i] = map_gap, s[2 * i + 1] = zero;
 map_len_set(m, map_len(m) - 1);
 return m; }

// a fresh empty map onto sp[0], lvm_tablet's shape
struct g *map_new(struct g *g) {
 uintptr_t cap = map_min_cap, nb = map_back_words(cap);
 if (!ok(g = have(g, nb + map_head))) return g;
 union u *b = map_fill_back(cell(g->hp), cap);
 word h = ini_tablet(cell(g->hp + nb), (word) b, putcharm(++g->next_serial));
 g->hp += nb + map_head;
 return push(g, 1, h); }

// (tablet n): a fresh map presized so n keys never rehash
lvm(lvm_tablet) {
 intptr_t raw = charmp(Sp[0]) ? getcharm(Sp[0]) : 0;
 uintptr_t hint = raw <= 0 ? 0 : (uintptr_t) raw > map_hint_max ? map_hint_max : (uintptr_t) raw,
           cap = map_min_cap;
 while (cap * 3 <= hint * 4) cap *= 2;
 uintptr_t nb = map_back_words(cap);
 Have(nb + map_head);
 union u *b = map_fill_back(cell(Hp), cap);
 Sp[0] = ini_tablet(cell(Hp + nb), (word) b, putcharm(++g->next_serial));
 Hp += nb + map_head; love_musttail return Next(1); }

// (m k): lookup, () if absent
lvm(lvm_map_lookup) {
 Pack(g);                                            // packed: the probe's walks take the nursery's free room
 word v = mapget(g, ZeroPoint, Sp[0], (word) Ip);   // a miss is (), not 0
 WalkAgain();
 Ip = cell(*++Sp), *Sp = v;
 love_musttail return Continue(); }

op11(lvm_tabp, tabp(Sp[0]) ? putcharm(1) : zero)

// FIXME this predicate is confusing, let's try and remove it
// (lit? x): kind >= KTablet -- tablets, closures, nifs, casks, ports; never a coin
lvm(lvm_litp) {
 word x = Sp[0];
 bool lit = !coinp(x) && kind(x) >= KTablet;
 Sp[0] = lit ? putcharm(1) : zero;
 love_musttail return Next(1); }
// (hot? x): a cask or a port
op11(lvm_hotp, (caskp(Sp[0]) || iop(Sp[0])) ? putcharm(1) : zero)

lvm(lvm_dig) {
 Pack(g);                                            // packed: hash takes the nursery's free room
 uintptr_t h = hash(g, Sp[0]);
 WalkAgain();
 Sp[0] = putcharm(h);
 love_musttail return Next(1); }

// (peep tray idx d), idx an int tray: the gather, idx's shape in the tray's kind, a miss d. a
// complex or object tray, a float index or a non-number d answer d whole
static love_noinline void gather_fill(struct tray *r, struct tray *v, struct tray *ki, flo_t zf, intptr_t zi) {
 uintptr_t n = tray_nelem(r), m = tray_nelem(v);
 intptr_t *k = tray_data(ki);                          // ki is love_Z
 if (r->type == love_R) { flo_t *d = tray_data(r), *s = tray_data(v);
  for (uintptr_t i = 0; i < n; i++) { intptr_t j = k[i]; d[i] = j >= 0 && (uintptr_t) j < m ? s[j] : zf; } }
 else { intptr_t *d = tray_data(r), *s = tray_data(v);
  for (uintptr_t i = 0; i < n; i++) { intptr_t j = k[i]; d[i] = j >= 0 && (uintptr_t) j < m ? s[j] : zi; } } }
static lvm(lvm_gather) {
 word z = Sp[2];
 struct tray *v = tray(Sp[0]), *ki = tray(Sp[1]);
 if (v->type > love_R || ki->type >= love_R || !(charmp(z) || gemp(z))) love_musttail return Answerp(2, z);
 flo_t zf = charmp(z) ? (flo_t) getcharm(z) : gem_get(z);
 intptr_t zi = charmp(z) ? getcharm(z) : (intptr_t) zf;
 int type = v->type == love_R ? love_R : love_Z;
 uintptr_t rank = ki->rank, n = tray_nelem(ki), bytes = tray_bytes(type, rank, n);
 Have(b2w(bytes));
 v = tray(Sp[0]), ki = tray(Sp[1]);
 struct tray *r = (struct tray*) Hp;
 Hp += b2w(bytes);
 ini_tray(r, type, rank);
 for (uintptr_t i = 0; i < rank; i++) r->shape[i] = ki->shape[i];
 gather_fill(r, v, ki, zf, zi);
 love_musttail return Answerp(2, word(r)); }
// (pin tray idx vals): the scatter into a fresh copy, a later index winning, out of range
// skipped. vals a number or a numeric tray idx's length, else the tray unchanged
static lvm(lvm_scatter) {
 struct tray *v = tray(Sp[0]), *ki = tray(Sp[1]);
 word z = Sp[2];
 bool zt = trayp(z);
 if (v->type > love_R || ki->type >= love_R
     || !(zt ? tray(z)->type <= love_R && tray_nelem(tray(z)) == tray_nelem(ki) : (charmp(z) || gemp(z))))
  love_musttail return Answerp(2, Sp[0]);
 uintptr_t req = b2w(love_tray_bytes(v));
 Have(req);
 struct tray *r = (struct tray*) Hp; Hp += req;
 memcpy(r, tray(Sp[0]), love_tray_bytes(tray(Sp[0])));
 ki = tray(Sp[1]), z = Sp[2];
 uintptr_t n = tray_nelem(ki), m = tray_nelem(r);
 intptr_t *k = tray_data(ki);
 struct tray *zv = zt ? tray(z) : 0;
 flo_t zf = zt ? 0 : charmp(z) ? (flo_t) getcharm(z) : gem_get(z);
 intptr_t zi = zt ? 0 : charmp(z) ? getcharm(z) : (intptr_t) zf;
 bool zr = zt && zv->type == love_R;
 if (r->type == love_R) { flo_t *d = tray_data(r);
  for (uintptr_t i = 0; i < n; i++) { intptr_t j = k[i]; if (j >= 0 && (uintptr_t) j < m)
   d[j] = !zt ? zf : zr ? ((flo_t*) tray_data(zv))[i] : (flo_t) ((intptr_t*) tray_data(zv))[i]; } }
 else { intptr_t *d = tray_data(r);
  for (uintptr_t i = 0; i < n; i++) { intptr_t j = k[i]; if (j >= 0 && (uintptr_t) j < m)
   d[j] = !zt ? zi : zr ? (intptr_t) ((flo_t*) tray_data(zv))[i] : ((intptr_t*) tray_data(zv))[i]; } }
 love_musttail return Answerp(2, word(r)); }

lvm(lvm_peep) {                                // (peep coll key default)
 word x = Sp[0], k = Sp[1], z = Sp[2], n;
 if (caskp(x)) {
  struct str *s = cask(x)->str;
  if (charmp(k) && (n = getcharm(k)) >= 0 && n < (word) len(s))
   z = putcharm((unsigned char) txt(s)[n]); }
 else if (tabp(x)) {                            // packed: the probe's walks take the free room
  Pack(g), z = mapget(g, z, k, x);
  WalkAgain(); }
 else if (evenp(x) && datp(x)) switch (typ(x)) {
  default: break;
  case DGem:                                    // a scalar: a zero key derefs to itself
  case DBig:
  case DTwin:
   if (zerop(k)) z = x;
   break;
  case DTray: {
   struct tray *v = tray(x);
   if (trayp(k)) love_musttail return Ap(lvm_gather, g);
   intptr_t o = tray_off(v, k); uintptr_t off = (uintptr_t) o; bool ok = o >= 0;
   if (ok && v->type == love_O) z = tray_get_obj(v, off);
   else if (ok && v->type == love_C) {
    Have(twin_req); v = tray(Sp[0]);
    flo_t *fp = tray_data(v);
    z = mk_twin(&Hp, fp[2*off], fp[2*off+1]); }
   else if (ok) { word _res; Have(box_req); v = tray(Sp[0]);
    if (v->type >= love_R) emit_gem(_res, tray_get_flo(v, off));
    else emit_int(_res, tray_get_int(v, off));
    z = _res; }
   break; }
  case DString:
   // txt is signed: the cast keeps a high byte from sign-extending
   if (charmp(k) && (n = getcharm(k)) >= 0 && n < (word) len(x))
    z = putcharm((unsigned char) txt(x)[n]);
   break;
  case DChain:
   if (charmp(k) && (n = getcharm(k)) >= 0) {
    while (n-- && chainp(x = B(x)));
    if (chainp(x)) z = A(x); } }
 love_musttail return Answerp(2, z); }

// (pin coll key val): a map or cask in place; text, a chain or a tray answer a fresh one.
// out of range or wrong kind answers coll unchanged
lvm(lvm_pin) {
 word x = Sp[0], n;
 if (tabp(x)) {
  Sp[0] = Sp[1], Sp[1] = Sp[2], Sp[2] = x;       // mapput's (key val coll)
  LvmCall(g, mapput) }
 if (caskp(x)) {
  if (charmp(Sp[1]) && charmp(Sp[2]) && (n = getcharm(Sp[1])) >= 0 && n < (word) len(cask(x)->str))
   txt(cask(x)->str)[n] = (char) getcharm(Sp[2]);
  love_musttail return Answerp(2, x); }
 if (evenp(x) && datp(x)) switch (typ(x)) {
  default: break;
  case DString: {
   if (!charmp(Sp[1]) || !charmp(Sp[2])) break;
   if ((n = getcharm(Sp[1])) < 0 || n >= (word) len(x)) break;
   uintptr_t sz = len(x), req = str_width(sz);
   Have(req);
   struct str *s = ini_str(str(Hp), sz); Hp += req;
   memcpy(s->bytes, txt(Sp[0]), sz);             // re-read: the Have may move it
   s->bytes[n] = (char) getcharm(Sp[2]);
   love_musttail return Answerp(2, word(s)); }
  case DChain: {                                 // the prefix copied, the tail shared
   if (!charmp(Sp[1]) || (n = getcharm(Sp[1])) < 0 || n >= (word) llen(x)) break;
   Have((uintptr_t) (n + 1) * Width(struct chain));
   struct chain *w = (struct chain*) Hp, *base = w;
   Hp += (uintptr_t) (n + 1) * Width(struct chain);
   word l = Sp[0];
   for (word i = 0; i < n; i++, w++, l = B(l)) ini_chain(w, A(l), word(w + 1));
   ini_chain(w, Sp[2], B(l));                    // the pinned cell, then the old tail
   love_musttail return Answerp(2, word(base)); }
  case DTray: {
   if (trayp(Sp[1])) love_musttail return Ap(lvm_scatter, g);
   intptr_t o = tray_off(tray(x), Sp[1]);
   if (o < 0) break;
   uintptr_t req = b2w(love_tray_bytes(tray(x)));
   Have(req);
   struct tray *v = (struct tray*) Hp; Hp += req;
   memcpy(v, tray(Sp[0]), love_tray_bytes(tray(Sp[0])));
   if (!tray_put(v, (uintptr_t) o, Sp[2])) { Hp -= req; break; }   // a non-number into a numeric tray
   love_musttail return Answerp(2, word(v)); } }
 love_musttail return Answerp(2, x); }

// (pull coll key default): remove key from a map, answering its value or default
lvm(lvm_pull) {
 word coll = Sp[0], v = Sp[2];
 if (tabp(coll)) {
  Pack(g);                                     // packed: the probe's walks take the nursery's free room
  v = mapget(g, Sp[2], Sp[1], coll);
  WalkAgain();
  mapdel(g, coll, Sp[1], Sp[2]);
  WalkAgain(); }
 love_musttail return Answerp(2, v); }

lvm(lvm_keys) {
 intptr_t list = ZeroPoint;
 if (tabp(Sp[0])) {
  uintptr_t cap = map_cap(Sp[0]), n = map_len(Sp[0]);
  Have(n * Width(struct chain));
  struct chain *chains = (struct chain*) Hp;
  Hp += n * Width(struct chain);
  word *s = map_slots(Sp[0]);                    // after Have
  for (uintptr_t i = cap; i;)
   if (s[2 * --i] != map_gap)
    ini_chain(chains, s[2 * i], list), list = (intptr_t) chains, chains++; }
 Sp[0] = list;
 love_musttail return Next(1); }

// an out-of-pool word hashes by its image seat, so native keys order alike in every build;
// without one, by its offset from an anchor on its own side of .rodata
static const char hash_base[1] = {0};
static intptr_t oop_key(word x) {
 intptr_t s = image_seat(x);
 return s >= 0 ? s : (uintptr_t) x < (uintptr_t) hash_base ? (intptr_t) x - (intptr_t) hash_base
                                                         : (intptr_t) x - (intptr_t) __start_love_nifs; }
// hash_at (arr.c) is this walk continued on a live worklist; a leaf settles here, no scratch
uintptr_t hash(struct g *g, intptr_t x) {
 if (charmp(x)) return rot(x*mix);
 uintptr_t t; word src;
 if (!chainp(x) && hash_leaf(g, x, &t, &src) != 3) return t;
 word *top, *base = gap(g, &top);
 return hash_at(g, x, base, top); }

// a function hashes as fn_eq (arr.c) reads it, GC-stable: its thread's words, a self-pointer
// by offset, a partial its base and captures, a carrier its length, out of pool oop_key.
// d levels of heap words fold their leaf hash, deeper a 2; only a prefix is read
static uintptr_t fn_hash_d(struct g *g, word x, int d);
static uintptr_t fn_word(struct g *g, word v, int d) {
 uintptr_t t; word src;
 if (!d || (datp(v) && typ(v) == DChain)) return 2;
 if (!datp(v)) return fn_hash_d(g, v, d - 1);
 return hash_leaf(g, v, &t, &src), t; }

static uintptr_t fn_hash(struct g *g, word x) { return fn_hash_d(g, x, 1); }
static uintptr_t fn_hash_d(struct g *g, word x, int d) {
 x = fn_meaning(g, x);
 if (!in_heap(g, x)) return rot(oop_key(x) * mix);
 union u *k = cell(x);
 struct tag *tg = ttag(g, k);
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
              : in_heap(g, v) ? fn_word(g, v, d) : (uintptr_t) oop_key(v);
  h = (h ^ t) * mix; }
 return h; }

// a box's bytes past its first word: that word is the kind's op, an address the load moves
// and every box of the kind shares, so the hash is the payload's alone
static uintptr_t box_hash(word x, uintptr_t len) {
 uintptr_t h = mix;
 for (uint8_t const *bs = (uint8_t const*) x + sizeof(word), *e = (uint8_t const*) x + len; bs < e; h ^= *bs++, h *= mix);
 return h; }
int hash_leaf(struct g *g, word x, uintptr_t *out, word *src) {
 if (charmp(x)) return *out = rot(x*mix), 0;
 if (!datp(x)) return *out = fn_hash(g, x), 0;
 switch (typ(x)) {
   case DChain: break;                            // hash_at spines a chain: a bug here
   case DMint: return *out = sym(x)->serial, 0;
   case DNom: return *out = nom(x)->dig, 0;        // the spelling's: a serial keys order to intern history
   case DTray: {
    // an object tray's header only: answer 3 and hash_at folds the cells, as = reads through
    bool obj = objtrayp(x);
    *out = box_hash(x, obj ? (uintptr_t) ((uint8_t*) tray_data(tray(x)) - (uint8_t*) x) : love_tray_bytes(tray(x)));
    return obj ? (*src = x, 3) : 0; }
   case DBig: return *out = box_hash(x, big_bytes(big(x))), 0;
   case DGem: return *out = box_hash(x, gem_req * sizeof(word)), 0;    // the lean box: ap is GC-stable
   case DTwin: return *out = box_hash(x, twin_req * sizeof(word)), 0;
   case DString: {
    uintptr_t n = len(x), h = mix;
    char const *bs = txt(x);
    while (n--) h ^= (uint8_t) *bs++, h *= mix;
    return *out = h, 0; } }
 __builtin_trap(); }

// the native finalizer: the header duplicates the code address (dead = out of pool, live = a
// forward). not hosted is a bare board alone
#if __STDC_HOSTED__
static void nat_free(struct g *g, void *p) { code_free(g, (char*) ((union u*) p)[0].ap); }
#endif

// FIXME doesn't belong in this file
// (nif code interp arity): emitted bytes -> a native closure, [hdr code|cur (ar) interp lvm_ret n
// (extras)]: lvm_ret at one offset either way, so the body is layout-blind. a decline answers
// the interp twin. nifx adds extras at Ip+32. code in the arena, or a heap string on a board
lvm(lvm_nifx) {                               // Sp[0]=code Sp[1]=interp Sp[2]=arity [Sp[3]=extras]
 int xtra = Ip->ap == lvm_nifx, nsp = xtra ? 3 : 2;   // nif tail-jumps here with Ip at its own word
 word codebuf = Sp[0];
 intptr_t ar = oddp(Sp[2]) ? getcharm(Sp[2]) : 0;
 if (!(strp(codebuf) || caskp(codebuf)) || ar < 1) love_musttail return Answerp(nsp, Sp[1]);
 uintptr_t n = len(bytes_of(codebuf));
 if (n == 0) love_musttail return Answerp(nsp, Sp[1]);
#ifdef __wasm__                                // no executable pages
 love_musttail return Answerp(nsp, Sp[1]);
#endif
 char *code;
#if __STDC_HOSTED__
 // inle declines: its heap rides the NX hhdm window
 if (__love_osv < 0) love_musttail return Answerp(nsp, Sp[1]);
 Have(10 + Width(struct fz));              // 10 covers every cell (5..8 words) + tag + fz
 code = code_install(g, txt(bytes_of(Sp[0])), n);   // reloaded: Have may move it
 if (!code) love_musttail return Answerp(nsp, Sp[1]);
#else
 Have(str_width(n) + 10);                     // RAM is executable
 struct str *s = ini_str(str(Hp), n); Hp += str_width(n);
 memcpy(txt(s), txt(bytes_of(Sp[0])), n);
 __builtin___clear_cache(txt(s), txt(s) + n);
 code = txt(s);
#endif
 union u *k = (union u*) Hp;
 uintptr_t w;
 if (ar == 1) {
  k[0].ap = (lvm_t*) code;                    // header: the finalizer's dead test
  k[1].ap = (lvm_t*) code;
  k[2].x  = Sp[1];                            // interp
  k[3].ap = lvm_ret;
  k[4].x  = putcharm(0);
  w = 5;
 } else {
  k[0].ap = (lvm_t*) code;                    // header
  k[1].ap = lvm_cur;
  k[2].x  = putcharm(ar);
  k[3].ap = (lvm_t*) code;                    // lvm_cur resumes at Ip+2
  k[4].x  = Sp[1];                            // interp
  k[5].ap = lvm_ret;
  k[6].x  = putcharm(ar - 1);
  w = 7; }
 if (xtra) k[w++].x = Sp[3];                  // extras at Ip+32 from the body entry
 Hp += w + 1;
 tagthread(k, w);
#if __STDC_HOSTED__
 struct fz *z = (struct fz*) Hp; Hp += Width(struct fz);
 z->p = k, z->fn = nat_free, z->next = g->fz, g->fz = z;
#endif
 love_musttail return Answerp(nsp, word(k + 1)); }
lvm(lvm_nif) { love_musttail return Ap(lvm_nifx, g); }   // the same build, no extras word

// a deferred native: nifx's shape, built before its compile sees every sibling; until patched
// (or for good on a decline) its code forwards to interp. the native rides last, keeping its code alive
//   ar 1: [hdr code interp lvm_ret 0 E N]    ar>1: [hdr cur ar code interp lvm_ret ar-1 E N]
lvm(lvm_deferfwd) {                           // entered at the code slot, as a native is
 union u *e = cell(Ip[1].x);
 Ip = Ip[-2].ap == lvm_cur && oddp(Ip[-1].x) ? e + 2 : e;
 love_musttail return Continue(); }
// (defercell interp arity): interp a function of that arity, else ()
static lvm(lvm_defercell) {
 word f = Sp[0];
 intptr_t ar = oddp(Sp[1]) ? getcharm(Sp[1]) : 0;
 if (ar < 1 || oddp(f) || datp(f)                                         // deferfwd enters f past its curry
     || (ar > 1 && (cell(f)->ap != lvm_cur || cell(f)[1].x != putcharm(ar))))
  love_musttail return Answerp(1, ZeroPoint);
 Have(10);
 union u *k = (union u*) Hp;
 uintptr_t w = 0;
 k[w++].ap = lvm_deferfwd;
 if (ar > 1) k[w++].ap = lvm_cur, k[w++].x = putcharm(ar);
 k[w++].ap = lvm_deferfwd, k[w++].x = Sp[0], k[w++].ap = lvm_ret, k[w++].x = putcharm(ar - 1);
 k[w++].x = putcharm(0), k[w++].x = putcharm(0);
 Hp += w + 1;
 tagthread(k, w);
 love_musttail return Answerp(1, word(k + 1)); }
LvDef("defercell", defercell, 2, "guts");
// (deferpatch cell native): a native of nif's shape and the cell's arity patches it, anything
// else leaves it forwarding. the cell, or () for one not deferred or already patched
static lvm(lvm_deferpatch) {
 word x = Sp[0], n = Sp[1];
 union u *v = evenp(x) && !datp(x) ? cell(x) : NULL,
         *c = v && v->ap == lvm_cur && oddp(v[1].x) ? v + 2 : v;
 if (!c || c->ap != lvm_deferfwd || v[-1].ap != lvm_deferfwd)
  love_musttail return Answerp(1, ZeroPoint);
 if (evenp(n) && n != c[1].x && !datp(n)) {
  union u *m = cell(n), *mc = m->ap == lvm_cur && oddp(m[1].x) ? m + 2 : m;
  if (mc[2].ap == lvm_ret && m[-1].ap == mc->ap && (mc == m ? v == c : v != c && m[1].x == v[1].x)) {
   c->ap = v[-1].ap = mc->ap;
   if ((mc[4].x & 3) != thread_tag) c[4].x = mc[4].x, gen_wb_cell(g, &c[4], mc[4].x);
   c[5].x = n, gen_wb_cell(g, &c[5], n); } }
 love_musttail return Answerp(1, Sp[0]); }
LvDef("deferpatch", deferpatch, 2, "guts");
// a first-call native: a deferred cell whose code slot is lvm_firstcall and whose N holds the
// thunk that compiles it. its first call makes it forward first, so a call while the compile
// runs is the twin's, then hands the cell to the thunk (callout_drive), whose deferpatch lays
// the native in; the landing enters the cell again as it was entered
static lvm(lvm_firstcall_land) {                    // [ans ip]
 Ip = cell(Sp[1]); Sp += 2; love_musttail return Continue(); }
static union u const firstcall_land[] = {{.ap = lvm_firstcall_land}};
lvm(lvm_firstcall) {
 Have(4);
 union u *v = Ip[-2].ap == lvm_cur && oddp(Ip[-1].x) ? Ip - 2 : Ip;
 word t = Ip[5].x, *dst = Sp - 4;
 Ip->ap = v[-1].ap = lvm_deferfwd, Ip[5].x = putcharm(0);
 dst[0] = word(v), dst[1] = t, dst[2] = word(firstcall_land), dst[3] = word(Ip);
 Sp = dst; Ip = (union u*) callout_drive; love_musttail return Continue(); }
// (firstcell interp arity thunk): defercell's cell, compiled by (thunk cell) at its first call
static lvm(lvm_firstcell) {
 word f = Sp[0];
 intptr_t ar = oddp(Sp[1]) ? getcharm(Sp[1]) : 0;
 if (ar < 1 || oddp(f) || datp(f)
     || (ar > 1 && (cell(f)->ap != lvm_cur || cell(f)[1].x != putcharm(ar))))
  love_musttail return Answerp(2, ZeroPoint);
 Have(10);
 union u *k = (union u*) Hp;
 uintptr_t w = 0;
 k[w++].ap = lvm_firstcall;
 if (ar > 1) k[w++].ap = lvm_cur, k[w++].x = putcharm(ar);
 k[w++].ap = lvm_firstcall, k[w++].x = Sp[0], k[w++].ap = lvm_ret, k[w++].x = putcharm(ar - 1);
 k[w++].x = putcharm(0), k[w++].x = Sp[2];
 Hp += w + 1;
 tagthread(k, w);
 love_musttail return Answerp(2, word(k + 1)); }
LvDef("firstcell", firstcell, 3, "guts");

// (pour dst doff src soff n): n bytes into cask dst, clamped to both; answers dst
lvm(lvm_bcopy) {
 word dst = Sp[0], src = Sp[2];
 if (caskp(dst) && (strp(src) || caskp(src))) {
  struct str *d = cask(dst)->str, *s = bytes_of(src);
  intptr_t doff = getcharm(Sp[1]), soff = getcharm(Sp[3]), n = getcharm(Sp[4]),
           dl = len(d), sl = len(s);
  if (n < 0) n = 0;
  if (doff < 0) doff = 0;
  if (soff < 0) soff = 0;
  if (doff + n > dl) n = dl - doff;
  if (soff + n > sl) n = sl - soff;
  if (n > 0) memmove(txt(d) + doff, txt(s) + soff, n); }
 love_musttail return Answerp(4, dst); }

// (xlat s tbl dst): s through a 512-byte table into cask dst, the count written: tbl[c] c's
// image, tbl[256 + c] its mode, 0 drop, 1 write, 2 squeeze. () on bad shapes; dst holds #s
lvm(lvm_xlat) {
 word s = Sp[0], t = Sp[1], d = Sp[2];
 if (!(strp(s) || caskp(s)) || !(strp(t) || caskp(t)) || !caskp(d))
  love_musttail return Answerp(2, ZeroPoint);
 struct str *ss = bytes_of(s), *ts = bytes_of(t), *ds = cask(d)->str;
 uintptr_t n = len(ss);
 if (len(ts) < 512 || len(ds) < n) love_musttail return Answerp(2, ZeroPoint);
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
 love_musttail return Answerp(2, putcharm((intptr_t) k)); }
