// gc.c -- the generational collector: a minor evacuates the nursery into the survivors' block
// and the survivors before into the major block, a major copies all of it into a fresh block;
// the rem set lets a minor skip the tenured bulk
#include "love.h"
// one pass's state, on the driver's C stack: meaningless between collections
struct gcx {
 word const *p0, *t0;        // the from-space under trace
 word const *f2lo, *f2hi;    // a second from-space (0 = unused): a minor's survivors, a major's nursery
 word const *f3lo, *f3hi;    // a third: a major's survivors
 word *to_lo, *to_hi;        // where the tenured land: the tagp range [to_lo, to_hi)
 word *fwd;                  // the forwarding floor: word0 in [fwd, to_hi) = a copy made this pass
 word *cp;                   // the cheney scan cursor
 // a minor's survivors' block [s_lo, s_hi), filled to s_hp and scanned at s_cp; old says the
 // scan is in a tenured object and hit that it kept a survivor; ten that its young tenure with it
 word *s_lo, *s_hi, *s_hp, *s_cp;
 bool old, ten, hit, over; };
// a terminator is known by the live pool its head lands in, never the scan's range;
// mid-pass the to-space counts as a third pool
static love_inline bool tagl(struct g *g, struct gcx *X, word x) {
 if ((x & 3) != thread_tag) return false;
 word const *p = (word const*) (x & ~(word) 3);
 return (X->to_lo && p >= X->to_lo && p < X->to_hi) || (X->s_lo && p >= X->s_lo && p < X->s_hi)
     || in_live_pool(g, p); }

lvm(lvm_gc) {
 uintptr_t n = (uintptr_t) g->b;                // Have's ask, left in the scratch slot
 LvmResume(g, please, n) }

static love_noinline word gcp(struct g*, struct gcx*, word);

// the collector's bump: a pass promotes into the major pool, never the nursery it is emptying
static love_inline void *gbump(struct g *g, uintptr_t n) {
 void *x = g->major_hp; g->major_hp += n; return x; }
// ..or a copy's room: a nursery object found from the young goes to the survivors while they
// have it, all else tenures
static love_inline void *cbump(struct g *g, struct gcx *X, bool sv, uintptr_t n) {
 if (sv) {
  if (X->s_hp + n <= X->s_hi) { void *x = X->s_hp; X->s_hp += n; return x; }
  X->over = true; }
 return gbump(g, n); }

static void evac_thread(struct g *g, struct gcx *X) {
 for (X->cp += 1; !tagl(g, X, X->cp[-1]); X->cp[-1] = gcp(g, X, X->cp[-1]), X->cp++); }

static void evac_data(struct g *g, struct gcx *X) {
 switch (typ(X->cp)) {
  case DTray: {
   struct tray *v = tray(X->cp);
   uintptr_t n = tray_nelem(v);
   X->cp += b2w(love_tray_bytes(v));
   if (v->type == love_O)                          // numeric trays are GC leaves (flat payload)
    for (word *e = ptr(tray_data(v)); n--; e[n] = gcp(g, X, e[n]));
   return; }
  case DMint: X->cp += mint_req; return;
  case DNom: {
   struct nom *w = nom(X->cp);
   X->cp += nom_req;
   w->name = gcp(g, X, w->name);
   return; }
  case DChain: {
   struct chain *w = two(X->cp);
   X->cp += chain_req;
   w->a = gcp(g, X, w->a);
   w->b = gcp(g, X, w->b);
   return; }
  case DString: X->cp += str_width(str(X->cp)->len); return;
  case DBig: X->cp += b2w(big_bytes(big(X->cp))); return;
  case DGem: X->cp += gem_req; return;
  case DTwin: X->cp += twin_req; return; }
 __builtin_trap(); }                            // a hot outside enum d: the object is not what its ap says

// the write barrier: every old->young edge goes through gen_wb into the rem set, so a minor
// under a complete set is sound (gc.v barrier_sound); an overflow (rem_miss) forces a major
static bool young(struct g *g, word p) {
 return evenp(p) && ((ptr(p) >= (word*) g->end && ptr(p) < g->hp) || (ptr(p) >= g->sv_base && ptr(p) < g->sv_hp)); }

// the index: entry numbers probed from an object's hash, one at or past rem_n free. cleared with
// the set; a probe that runs long costs a duplicate, never a miss
static uint16_t *rem_ix(struct g *g) { return (uint16_t*)(g->rem + LvRemCap); }
static void rem_clear(struct g *g) {
 g->rem_n = 0;
 memset(rem_ix(g), 0xff, LvRemIx * sizeof(uint16_t)); }

static void gen_remember(struct g *g, word obj) {
 uint16_t *ix = rem_ix(g), *e = NULL;
 uintptr_t h = (uintptr_t)(((uint64_t) obj >> 3) * 0x9e3779b97f4a7c15ull >> (64 - LvRemIxBits));
 for (int k = 0; k < 16; k++, h = (h + 1) & (LvRemIx - 1)) {
  if (ix[h] >= g->rem_n) { e = ix + h; break; }
  if (g->rem[ix[h]] == obj) return; }
 if (g->rem_n < LvRemCap) { if (e) *e = (uint16_t) g->rem_n; g->rem[g->rem_n++] = obj; }
 else g->rem_miss++;                                           // full: the next collection is a major
 if (g->rem_n > g->rem_hi) g->rem_hi = g->rem_n; }

// an old src gains a young p: maps and reader spines are the only in-place mutations
void gen_wb(struct g *g, word src, word p) {
 if (evenp(src) && young(g, p) && !young(g, src)) gen_remember(g, src); }

static love_inline bool major_cell(struct g *g, word *c) {
 return ptr(c) >= g->major_base && ptr(c) < g->major_hp; }
// a young store into a tenured cell of a thread or scope, never a chain's field: the
// remembered walk needs a terminator to stop at. masks g
void gen_wb_cell(struct g *g, void *cl, word v) {
 g = core_of(g);
 if (young(g, v) && major_cell(g, cl)) gen_remember(g, (word) cl); }

// a remembered tenured object stays put; its young fields promote in place
static void gen_scan_inplace(struct g *g, struct gcx *X, word obj) {
 union u *p = cell(obj);
 if (!datp(obj))
  for (union u *q = p; !tagl(g, X, q->x); q++) q->x = gcp(g, X, q->x);
 else switch (typ(obj)) {
  case DChain: {
   struct chain *w = two(obj);
   w->a = gcp(g, X, w->a), w->b = gcp(g, X, w->b);
   break; }
  case DTray: {
   struct tray *v = tray(p);
   uintptr_t ne = tray_nelem(v);
   if (v->type == love_O)
    for (word *e = ptr(tray_data(v)); ne--; e[ne] = gcp(g, X, e[ne]));
   break; }
  case DNom: nom(p)->name = gcp(g, X, nom(p)->name); break;
  default: break; } }                              // the rest are pointer-free

// a word0 that is this pass's forward: into the tenured it made, or the survivors
static love_inline bool moved(struct gcx *X, word w) {
 return evenp(w) && ((X->fwd <= ptr(w) && ptr(w) < X->to_hi) || (X->s_lo && X->s_lo <= ptr(w) && ptr(w) < X->s_hi)); }

// after the drain: an unforwarded young target is dead and finalizes while the from-space
// still reads; a tenured one waits for a major
static void minor_run_finalizers(struct g *g, struct gcx *X) {
 struct fz **link = &g->fz;
 for (struct fz *fz = *link; fz; ) {
  struct fz *next = fz->next;
  word const *q = (word const*) fz->p;
  if ((q >= X->p0 && q < X->t0) || (X->f2lo && q >= X->f2lo && q < X->f2hi)) {
   word fwd = fz->p->x;
   if (!moved(X, fwd)) {
    fz->fn(g, fz->p), *link = fz = next;
    continue; }
   fz->p = cell(fwd); }
  if ((word*) fz >= (word*) g->end && (word*) fz < g->hp) {   // the node itself was young
   struct fz *nn = gbump(g, Width(struct fz));
   nn->p = fz->p, nn->fn = fz->fn, nn->next = next;
   *link = nn, link = &nn->next;
  } else link = &fz->next;
  fz = next; } }

static love_inline bool sym_survived(word fwd, word const *lo, word const *hi) {
 return evenp(fwd) && lo <= ptr(fwd) && ptr(fwd) < hi; }   // an atom's first word: its forward, if it survived
// the weak intern map, rebuilt from the survivors into the to-space
static word major_symbols_rebuild(struct g *g, struct gcx *X, word om) {
 if (!om) return 0;
 uintptr_t ocap = map_cap(om), cap = map_min_cap, n = 0;
 word *os = map_slots(om);
 word const *lo = X->to_lo, *hi = X->to_hi;
 for (uintptr_t j = 0; j < ocap; j++)
  if (os[2 * j] != map_gap && sym_survived(cell(os[2 * j + 1])->x, lo, hi)) n++;
 // sized to the survivors, so an image's map is a function of the live set; +1 is intern_reserve's
 while ((n + 1) * 4 >= cap * 3) cap *= 2;
 uintptr_t mask = cap - 1;
 union u *b = map_fill_back(gbump(g, map_back_words(cap)), cap), *hd = gbump(g, map_head);
 ini_tablet(hd, (word) b, tablet(om)->serial);
 word *ns = tablet_back(b)->slot;
 n = 0;
 for (uintptr_t j = 0; j < ocap; j++) {
  word k = os[2 * j];
  if (k == map_gap) continue;
  word fwd = cell(os[2 * j + 1])->x;
  if (!sym_survived(fwd, lo, hi)) continue;
  word nk = nom(fwd)->name;
  uintptr_t i = nom(fwd)->dig & mask;   // the cached spelling hash: hash(g, nk) without the walk
  while (ns[2 * i] != map_gap) i = (i + 1) & mask;
  ns[2 * i] = nk, ns[2 * i + 1] = fwd, n++; }
 b[1].x = putcharm(n);
 return (word) hd; }

static void major_run_finalizers(struct g *g, struct gcx *X) {
 struct fz *new_fz = NULL;
 for (struct fz *fz = g->fz; fz; fz = fz->next) {
  word fwd = fz->p->x;
  if (evenp(fwd) && X->to_lo <= ptr(fwd) && ptr(fwd) < X->to_hi) {
   struct fz *nn = gbump(g, Width(struct fz));
   nn->p = cell(fwd), nn->fn = fz->fn, nn->next = new_fz, new_fz = nn;
  } else fz->fn(g, fz->p); }
 g->fz = new_fz; }

// LvGcStress: an even poison, so a stale read faults at a nameable address; every Nth collection a major
#define gc_poison ((word) 0xd0d0d0d0d0d0d0d0ULL)
#define gc_stress_major 32

// the minor's roots: the machine's own, and an intern map still young
static void minor_roots(struct g *g, struct gcx *X) {
 g->ip = cell(gcp(g, X, word(g->ip)));
 g->tasks = cell(gcp(g, X, word(g->tasks)));
 if (g->parked) g->parked = cell(gcp(g, X, word(g->parked)));   // the parked ring is its own root
 for (word i = 0; i < g->end - &g->v0; i++) (&g->v0)[i] = gcp(g, X, (&g->v0)[i]);   // core vars
 for (word *s = g->sp; s < topof(g); s++) *s = gcp(g, X, *s);                       // stack
 for (struct love_r *r = g->root; r; r = r->n) *r->x = gcp(g, X, *r->x);              // C roots
 // the intern map is weak, not a root: a young header promotes here, a tenured one is remembered
 if (g->symbols && young(g, g->symbols)) g->symbols = gcp(g, X, g->symbols); }

// the cheney drain over both to-spaces: the survivors' first, then the tenured, each of
// which a survivor's pointer leaves remembered, but past an overflow, which rescans them
static void drain(struct g *g, struct gcx *X) {
 for (;;) {
  if (X->s_cp < X->s_hp) {
   word *c = X->cp;
   X->cp = X->s_cp;
   (datp(X->cp) ? evac_data : evac_thread)(g, X);
   X->s_cp = X->cp, X->cp = c; }
  else if (X->cp < g->major_hp) {
   word *o = X->cp;
   X->old = X->ten = X->s_lo != NULL, X->hit = false;
   (datp(X->cp) ? evac_data : evac_thread)(g, X);
   X->old = X->ten = false;
   if (X->hit && !X->over) gen_remember(g, (word) o); }
  else return; } }

// the minor: [end, hp) into the survivors' block sto, slen long, and the survivors before into
// the major block; X.fwd tells this pass's forwards from older major objects, and the tenured
// from scan up are walked again. answers whether the block ran out
static bool gen_minor(struct g *g, word *sto, uintptr_t slen, word *scan) {
 struct gcx X = { .p0 = (word const*) g->end, .t0 = g->hp,    // minor from-range
                  .f2lo = g->sv_base, .f2hi = g->sv_hp,      // the survivors before, tenuring
                  .to_lo = g->major_base, .to_hi = g->major_base + g->major_len,
                  .fwd = g->major_hp, .cp = scan,
                  .s_lo = sto, .s_hi = sto + slen, .s_hp = sto, .s_cp = sto };
 minor_roots(g, &X);
 // major->young edges: each remembered again only while it holds a survivor
 uintptr_t n0 = g->rem_n;
 rem_clear(g);
 for (uintptr_t i = 0; i < n0; i++) {
  word o = g->rem[i];
  X.old = true, X.hit = false;
  gen_scan_inplace(g, &X, o);
  if (X.hit) gen_remember(g, o); }
 X.old = false;
 drain(g, &X);
#ifdef LvGcCheck
 // a second drive copies nothing (gc.v drain_second_pass_copies_nothing), or the first lost an object
 { word *hp1 = g->major_hp, *sh1 = X.s_hp;
  uintptr_t rn = g->rem_n;
  X.cp = scan, X.s_cp = X.s_lo;
  minor_roots(g, &X);
  for (uintptr_t i = 0; i < rn; i++) gen_scan_inplace(g, &X, g->rem[i]);
  drain(g, &X);
  if (g->major_hp != hp1 || X.s_hp != sh1 || g->rem_n != rn) __builtin_trap(); }
#endif
 if (g->fz) minor_run_finalizers(g, &X);
 g->hp = g->end;
#ifdef LvGcStress
 // after the finalizers, the from-spaces' last reader
 for (word *p = (word*) X.p0; p < (word*) X.t0; p++) *p = gc_poison;
 for (word *p = (word*) X.f2lo; p < (word*) X.f2hi; p++) *p = gc_poison;
#endif
 // the block copied into holds the survivors now; the one emptied is the spare
 word *ob = g->sv_base;
 uintptr_t ol = g->sv_len;
 g->sv_base = sto, g->sv_len = slen, g->sv_hp = X.s_hp;
 g->sv2_base = ob, g->sv2_len = ol;
 return X.over; }

// the pool a major leaves for v survivors: f of them again plus a nursery's promotion n, in
// whole steps -- gcsize.v's target, whose bounds hold only while this is it
static uintptr_t gc_target(uintptr_t n, uintptr_t v, uintptr_t step) {
 uintptr_t const w = v + v * gc_fn / gc_fd + n + 16, t = (w + step - 1) / step * step;
 return t < step ? step : t; }
// the nursery's ceiling: q of the live set, at least its floor -- gcsize.v's ncap
static uintptr_t gc_ncap(struct g *g) {
 uintptr_t const c = g->major_live0 * gc_qn / gc_qd;
 return c < g->minor0 ? g->minor0 : c; }

// a block's share of the budget: a major holds two beside the nursery; 0 is no budget
static uintptr_t major_share(struct g *g) {
 return g->budget > (uintptr_t) g->len ? (g->budget - (uintptr_t) g->len) / 2 : 0; }
// the pool can grow no further: the major then comes a nursery early, so the worst case
// still fits. read off the pool alone, never the nursery this shrinks
static bool at_share(struct g *g) {
 return g->budget && 2 * ((uintptr_t) g->major_len + g->major0) + g->minor0 > g->budget; }

// the major: one pass from the roots over the three from-spaces into a fresh block. req0 is
// the allocation that could not be served; *tight says the pool got less than it asked for
struct g *gen_major(struct g *g, uintptr_t req0, bool *tight) {
 struct gcx X = { .p0 = g->major_base, .t0 = g->major_hp };
 uintptr_t used = (uintptr_t)(g->major_hp - g->major_base), young = (uintptr_t)(g->hp - (word*) g->end),
           svu = (uintptr_t)(g->sv_hp - g->sv_base),
           need = used + young + svu,
 // the to-space (gcsize.v's lone block): the worst case and a promotion past it, or the
 // last survivors' target where that is more
           step = g->major0, nr = (uintptr_t) g->len + req0,
           hold = need + nr + 16, prior = gc_target(nr, g->major_live0, step),
           to_len = ((hold > prior ? hold : prior) + step - 1) / step * step;
 uintptr_t free_len = to_len,
           need_step = ((need + step - 1) / step) * step;       // the tight size
 if (need_step < step) need_step = step;
 // within its share of the budget, but never below the tight size
 if (g->budget) {
  uintptr_t cap = major_share(g);
  if (to_len > cap) {
   to_len = cap > need_step ? (cap / step) * step : need_step;
   // a pool that holds the worst case keeps its size
   if (need <= g->major_len && to_len < g->major_len) to_len = g->major_len; } }
 // short of that block, the tight sizes, then a scare
 word *to = alloc(NULL, to_len * sizeof(word));
 if (!to && to_len > need_step) to_len = need_step, to = alloc(NULL, need_step * sizeof(word));
 if (!to && need < to_len) to_len = need, to = alloc(NULL, need * sizeof(word));
 if (!to) return encode(g, status_scare);
 if (tight) *tight = to_len < free_len;
 g->major_hp = to, X.cp = to;
 X.to_lo = to, X.to_hi = to + to_len, X.fwd = to;
 X.f2lo = (word const*) g->end, X.f2hi = g->hp;             // the nursery promotes in the same pass
 X.f3lo = g->sv_base, X.f3hi = g->sv_hp;                    // ..and the survivors
 g->ip = cell(gcp(g, &X, word(g->ip)));
 g->tasks = cell(gcp(g, &X, word(g->tasks)));
 if (g->parked) g->parked = cell(gcp(g, &X, word(g->parked)));   // the parked ring is its own root
 for (word i = 0; i < g->end - &g->v0; i++) (&g->v0)[i] = gcp(g, &X, (&g->v0)[i]);
 for (word *s = g->sp; s < topof(g); s++) *s = gcp(g, &X, *s);
 for (struct love_r *r = g->root; r; r = r->n) *r->x = gcp(g, &X, *r->x);
 word om = g->symbols; g->symbols = 0;                       // weak: rebuilt after the fixpoint
 while (X.cp < g->major_hp) (datp(X.cp) ? evac_data : evac_thread)(g, &X);
 g->symbols = major_symbols_rebuild(g, &X, om);
 major_run_finalizers(g, &X);
 image_drop(X.p0);                                         // a lazy image in the from-space wakes whole
 // the pool from what survived, never past its block; no block is held between majors
 uintptr_t nl = gc_target(nr, (uintptr_t) (g->major_hp - to), step);
 if (nl > to_len) {
  nl = to_len;
  if (tight) *tight = true; }
 alloc(g->major_base, 0);
 g->major_len = nl;
 g->major_base = to;
 g->hp = g->end;
#ifdef LvGcStress
 // the old block needs none: each copy left a forward in word0, which faults on dispatch
 for (word *p = (word*) g->end; p < (word*) g->end + young; p++) *p = gc_poison;
 for (word *p = g->sv_base; p < g->sv_hp; p++) *p = gc_poison;
#endif
 g->sv_hp = g->sv_base;
 // the rem set dies with its block; cleared here too, as the image dump calls a major directly
 rem_clear(g), g->rem_miss = 0;
 // a live set past the whole budget scares, the heap intact
 if (g->budget && (uintptr_t) (g->major_hp - to) > g->budget) return encode(g, status_scare);
 return g; }

// resize the nursery pool. it is empty and nothing points into the core or the stack,
// so both move by copy and every value stays put
struct g *gen_grow(struct g *g, uintptr_t len1) {
 if (g->hp != g->end) __builtin_trap();
 if (len1 > words_max || (g->budget && len1 > g->budget)) return encode(g, status_scare);   // the stack rides this pool
 struct g *h = alloc(NULL, len1 * sizeof(word));
 if (!h) return encode(g, status_scare);
 uintptr_t sh = (uintptr_t) (ptr(g) + g->len - g->sp);
 memcpy(h, g, sizeof(struct g));
 h->len = len1, h->hp = h->end, h->sp = ptr(h) + len1 - sh;
 memcpy(h->sp, g->sp, sh * sizeof(word));
 h->n_resize += 1;
 if (h->len > h->max_len) h->max_len = h->len;
 alloc(g, 0);
 love_system = h;                              // the one place a state changes address
 return h; }

// the survivors' room: none at the budget's edge, where the pools keep gcsize.v's bounds;
// else what the last minors wanted, up to the nursery: no minor keeps more
static uintptr_t sv_size(struct g *g) {
 if (at_share(g)) return 0;
 uintptr_t w = g->sv_want ? g->sv_want : g->minor0, top = (uintptr_t) g->len;
 return w < top ? w : top; }

// the collector, asked for req0 words: a minor unless the rem set missed or the major lacks
// headroom. the ask rides g while it works, so an oom can say it
static struct g *please_(struct g *g, uintptr_t req0);
love_noinline struct g *please(struct g *g, uintptr_t req0) {
 g->ask = req0;
 g = please_(g, req0);
 if (ok(g)) g->ask = 0;
 return g; }
static struct g *please_(struct g *g, uintptr_t req0) {
 if (req0 > words_max) return encode(g, status_scare);   // before any sum can wrap
 uintptr_t seen_young = (uintptr_t)(g->hp - g->end),
           major_free = (uintptr_t)((g->major_base + g->major_len) - g->major_hp);
 // a major on a rem-set miss, or when the major lacks room for a worst-case promotion --
 // at the budget a nursery early, or the pool ratchets past it
 bool early = at_share(g);
 uintptr_t svu = (uintptr_t)(g->sv_hp - g->sv_base);         // a minor tenures every survivor
 bool major = g->rem_miss
   || major_free < (early ? 2 : 1) * (uintptr_t) g->len + svu + req0 + 16;
#ifdef LvGcStress
 // a minor never moves the tenured, so every Nth collection is a major
 major = major || g->n_gc % gc_stress_major == 0;
#endif
 word *before = g->major_hp;
 bool tight = false;
 if (major) {
  if (!ok(g = gen_major(g, req0, &tight))) return g;
  g->n_gc += 1;
  g->major_live0 = (uintptr_t)(g->major_hp - g->major_base);
#ifdef LvGcCheck
  // a pool that got its ask no longer forces a major, or the collector latches into majors
  if (!tight && (uintptr_t)((g->major_base + g->major_len) - g->major_hp) < (uintptr_t) g->len + req0 + 16)
   __builtin_trap();
  // the pool is at most its survivors' target, the one gcsize.v's bounds are proved for
  if (g->major_len > gc_target((uintptr_t) g->len + req0, g->major_live0, g->major0))
   __builtin_trap();
#endif
 } else {
  // the survivors' block for this minor: the spare, made again when its size is not wanted
  uintptr_t want = sv_size(g), sl = g->sv2_len;
  word *sto = g->sv2_base;
  if (sl != want) {
   if (sto) alloc(sto, 0);
   sto = want ? alloc(NULL, want * sizeof(word)) : NULL, sl = sto ? want : 0;
   g->sv2_base = NULL, g->sv2_len = 0; }
  bool over = gen_minor(g, sto, sl, before);
  // a block that ran out tenures whole, its overflow rescanned for the edges back into it
  if (over) gen_minor(g, NULL, 0, before), g->rem_miss = 0;
  uintptr_t su = (uintptr_t)(g->sv_hp - g->sv_base);
  // grown when it ran out, halved after eight minors mostly empty, never under the floor
  if (over) g->sv_want = 2 * (sl ? sl : g->minor0), g->sv_idle = 0;
  else if (sl > g->minor0 && 8 * su < sl) {
   if (++g->sv_idle >= 8) g->sv_want = sl / 2, g->sv_idle = 0; }
  else g->sv_idle = 0;
  g->n_gc += 1, g->n_minor += 1; }
 uintptr_t copied = major ? (uintptr_t)(g->major_hp - g->major_base)
                          : (uintptr_t)(g->major_hp - before) + (uintptr_t)(g->sv_hp - g->sv_base);
 g->n_seen += seen_young;
 g->n_evac += copied;
 if (major) { if (copied > g->major_hi) g->major_hi = copied; }
 else if (copied > g->minor_hi) g->minor_hi = copied;
 uintptr_t e = (uintptr_t)(g->major_hp - g->major_base);
 if (e > g->max_heap) g->max_heap = e;
 // the nursery grows on copy overhead (copied / allocated, no clock) over a window; only
 // the budget shrinks it, by appel's rule
 uintptr_t const ratio = g->ratio;
#ifdef LvGcStress
 // no setpoint on a forced schedule: the hard floor, the budget's cap, and a 4x-hysteresis
 // shrink, or a parked nursery forces a major every collection
 { uintptr_t used0 = g->len - avail(g), req = req0 + used0 + (used0 >> 2),
             want = req < g->minor0 ? g->minor0 : req;
   if (req > (uintptr_t) g->len) return gen_grow(g, req);
   if (g->budget) {
    uintptr_t lv = 2 * g->major_live0, room = g->budget > lv ? (g->budget - lv) / 4 : 0;
    if (room < want) room = want;
    if ((uintptr_t) g->len > room) return gen_grow(g, room); }
   if ((uintptr_t) g->len > 4 * want) return gen_grow(g, want);
   return g; }
#endif
 // only a minor sizes the nursery: grown on a major it outgrows the room that major made
 uintptr_t used = g->len - avail(g), req = req0 + used + (used >> 2), len1 = g->len, arena = len1;
 // grow on two consecutive windows over the setpoint (lean counts them); never shrink for
 // low overhead, which oscillates on phased work
 if (!major) {
  g->win_alloc += seen_young, g->win_copied += copied;
  if (g->win_copied * ratio > g->win_alloc) {                  // overhead over 1/ratio
   if ((g->lean = g->lean > 0 ? g->lean + 1 : 1) >= 2) {
    uintptr_t wa = g->win_alloc | 1;                           // | 1: progress
    while (g->win_copied * ratio > wa) arena <<= 1, wa <<= 1;
    g->lean = 0, g->win_alloc = g->win_copied = 0; }
  } else if (g->win_alloc > 8 * len1) g->win_alloc = g->win_copied = 0, g->lean = 0; }
 if (g->budget) {
  // appel's cap, leaving the major room for a worst-case promotion: /8 at the budget,
  // where the room past live holds two nurseries
  uintptr_t lv = 2 * g->major_live0, room = g->budget > lv ? (g->budget - lv) / (at_share(g) ? 8 : 4) : 0;
  if (arena > room) arena = room; }
 // the pool was denied room for this nursery's promotion, so the nursery gives; the floors still win
 if (tight) {
  uintptr_t fr = (uintptr_t)((g->major_base + g->major_len) - g->major_hp),
            fit = fr > req0 + 16 ? (fr - req0 - 16) / (at_share(g) ? 2 : 1) : 0;
  if (arena > fit) arena = fit; }
 // gcsize.v's minor rule: up to q of the live set, while the pool holds its promotion
 if (arena > len1) {
  uintptr_t const c = gc_ncap(g), fr = (uintptr_t) ((g->major_base + g->major_len) - g->major_hp),
                  fit = fr > req0 + 16 ? fr - req0 - 16 : 0, top = c < fit ? c : fit;
  arena = top > len1 ? top : len1; }
 if (arena < g->minor0) arena = g->minor0;
 if (arena < req) arena = req;                                 // the pending allocation fits
#ifdef LvGcCheck
 // past its ceiling only to hold the request: gcsize.v's bounds assume it
 if (arena > len1 && arena > gc_ncap(g) && arena > req) __builtin_trap();
#endif
 if (arena == len1) return g;
 struct g *h = gen_grow(g, arena);
 return ok(h) || len1 < req ? h : g; }                      // denied: keep a pool that still holds the request

// a collection asked for, not needed: the resize window is set aside, so it never steers the nursery
struct g *force(struct g *g, bool major) {
 uintptr_t wa = g->win_alloc, wc = g->win_copied;
 int8_t ln = g->lean;
 g->win_alloc = g->win_copied = 0, g->lean = 0;
 if (major) g->rem_miss = 1;
 if (!ok(g = please(g, 0))) return g;
 g->win_alloc = wa, g->win_copied = wc, g->lean = ln;
 return g; }

static love_inline word copy_data(struct g *g, struct gcx *X, union u *src, bool sv) {
 switch (typ(src)) {
  case DChain: {
   struct chain *s = two(src), *d = cbump(g, X, sv, chain_req);
   ini_chain(d, s->a, s->b);
   return word(s->ap = (void*) d); }
  case DTray: {
   struct tray *s = tray(src), *d;
   uintptr_t bytes = love_tray_bytes(s);
   d = cbump(g, X, sv, b2w(bytes));
   return word(s->ap = memcpy(d, s, bytes)); }
  case DMint: {
   struct mint *s = sym(src), *d = cbump(g, X, sv, mint_req);
   ini_missing(d, s->serial);
   return word(s->ap = (void*) d); }
  case DNom: {
   struct nom *s = nom(src), *d = cbump(g, X, sv, nom_req);
   ini_nom(d, s->name, s->dig);
   return word(s->ap = (void*) d); }
  case DString: {
   struct str *s = str(src), *d;
   uintptr_t w = str_width(s->len);
   d = cbump(g, X, sv, w);
   return word(s->ap = memcpy(d, s, w * sizeof(word))); }   // the zeroed tail rides
  case DBig: {
   struct big *s = big(src), *d;
   uintptr_t bytes = big_bytes(s);
   d = cbump(g, X, sv, b2w(bytes));
   return word(s->ap = memcpy(d, s, bytes)); }
  case DGem: {
   struct gem *s = gem(src), *d = cbump(g, X, sv, gem_req);
   return word(s->ap = memcpy(d, s, sizeof(struct gem))); }
  case DTwin: {
   struct twin *s = twin(src), *d = cbump(g, X, sv, twin_req);
   return word(s->ap = memcpy(d, s, sizeof(struct twin))); } }
 __builtin_trap(); }

static love_inline struct tag *ttag2(struct g *g, struct gcx *X, union u *k) {
 while (!tagl(g, X, k->x)) k++;
 return (struct tag*) k; }

static love_inline word copy_thread(struct g *g, struct gcx *X, union u *src, bool sv) {
 struct tag *t = ttag2(g, X, src);
 union u *ini = tag_head(t), *d = cbump(g, X, sv, t->end - ini), *dst = d;
 // each word copied leaves a forward; the terminator becomes the new head
 for (union u *s = ini; !tagl(g, X, s->x); s->x = (word) d, d++, s++) d->x = s->x;
 return (word) (tagthread(dst, d - dst) + (src - ini)); }

// what a tenured object's field comes to: a survivor's address leaves it to be remembered
static love_inline word seen(struct gcx *X, word r) {
 if (X->old && evenp(r) && ptr(r) >= X->s_lo && ptr(r) < X->s_hp) X->hit = true;
 return r; }

static love_noinline intptr_t gcp(struct g *g, struct gcx *X, word x) {
 if (charmp(x)) return x;
 bool nur = ptr(x) >= X->p0 && ptr(x) < X->t0;
 if (!nur && !(X->f2lo && ptr(x) >= X->f2lo && ptr(x) < X->f2hi)
          && !(X->f3lo && ptr(x) >= X->f3lo && ptr(x) < X->f3hi)) return seen(X, x);
 union u *src = cell(x);
 word w = src->x;
 if (moved(X, w)) return seen(X, w);
 // a minor's nursery object survives once, but one a tenure reaches; the rest tenure
 bool sv = X->s_lo && nur && !X->ten;
 return seen(X, in_data((void*) w) ? copy_data(g, X, src, sv) : copy_thread(g, X, src, sv)); }
