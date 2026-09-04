// gc.c -- the generational collector. one translation unit of the runtime; the shared
// layouts and the cross-TU seam are src/love.h. a minor evacuates young into the major
// active half, a major compacts that half into the spare one and flips; the rem set and the
// write barriers below are what let a minor skip the tenured bulk.
#include "love.h"

lvm(lvm_gc) {
 uintptr_t n = (uintptr_t) g->b;                // Have's ask, left in the scratch slot
 Pack(g);
 if (!ai_ok(g = ai_please(g, n))) ai_musttail return Ap(_lvm_ghelp, g);
 ai_musttail return Resume(); }

static ai_noinline word gcp(struct ai*, struct ai_gcx*, word);

// the collector's bump. a pass promotes into the major pool, never the nursery it is
// emptying; gen_grow drives the same copy_* code with gc_gen clear and wants hp, which
// is the whole of what the flag selects. the mutator's bump (love.h) is the hp half
// alone -- gc_gen cannot be set under it, so it does not pay for the test.
static ai_inline void *gbump(struct ai *g, uintptr_t n) {
 if (g->gc_gen) { void *x = g->major_hp; g->major_hp += n; return x; }
 if (avail(g) < n) __builtin_trap();
 void *x = g->hp; g->hp += n; return x; }

static void evac_thread(struct ai *g, struct ai_gcx *X) {
 // tagl ends the thread regardless of scan space, so a young-pointing terminator is never gcp'd as a field
 for (X->cp += 1; !tagl(g, X, X->cp[-1]); X->cp[-1] = gcp(g, X, X->cp[-1]), X->cp++); }

static void evac_data(struct ai *g, struct ai_gcx *X) {
 switch (typ(X->cp)) {
  case DTray: {
   struct ai_tray *v = tray(X->cp);
   uintptr_t n = tray_nelem(v);
   X->cp += b2w(ai_tray_bytes(v));
   if (v->type == ai_O)                          // numeric trays are GC leaves (flat payload)
    for (word *e = ptr(tray_data(v)); n--; e[n] = gcp(g, X, e[n]));
   return; }
  case DMint: X->cp += mint_req; return;
  case DNom: {
   struct ai_nom *w = nom(X->cp);
   X->cp += nom_req;
   w->name = gcp(g, X, w->name);
   return; }
  case DChain: {
   struct ai_chain *w = two(X->cp);
   X->cp += chain_req;
   w->a = gcp(g, X, w->a);
   w->b = gcp(g, X, w->b);
   return; }
  case DString: X->cp += str_width(str(X->cp)->len); return;
  case DBig: X->cp += b2w(ai_big_bytes(big(X->cp))); return;
  case DGem: X->cp += gem_req; return;
  case DSun: X->cp += sun_req; return;
  case DTwin: X->cp += twin_req; return; }
 __builtin_trap(); }                            // a hot outside enum d: the object is not what its ap says

// ===== generational write barrier =====
// a minor scavenges only [minor, hp) and finds old->young edges through the rem
// set: every edge execution mints (a map pin, a store) goes through gen_wb, so a
// minor under a complete set is sound (test/proof/rocq/gc.v barrier_sound).
// the one escape is overflow (rem_miss): a dropped entry forces the next collection
// major, which traces from roots and needs no rem set.
// young?: the address is the generation (no age bits) -- in [end, hp).
static bool ai_young(struct ai *g, word p) {
 return evenp(p) && ptr(p) >= (word*) g->end && ptr(p) < g->hp; }

static bool gen_remembered(struct ai *g, word obj) {
 for (uintptr_t i = 0; i < g->rem_n; i++) if (g->rem[i] == obj) return true;
 return false; }

static void gen_remember(struct ai *g, word obj) {
 if (g->rem_n && g->rem[g->rem_n - 1] == obj) return;          // hot path: same map as last pin
 if (gen_remembered(g, obj)) return;                           // deduped: the set stays small (book + a few)
 if (g->rem_n < AiRemCap) g->rem[g->rem_n++] = obj;            // full: the miss forces a major (roots-only trace, no rem set), so a dropped entry can't orphan a young edge
 else g->rem_miss++;
 if (g->rem_n > g->rem_hi) g->rem_hi = g->rem_n; }

// an old `src` gains a young `p` -> remember src. maps and reader spines are the
// only in-place mutations, so this is the whole hot-path barrier.
void gen_wb(struct ai *g, word src, word p) {
 if (evenp(src) && ai_young(g, p) && !ai_young(g, src)) gen_remember(g, src); }

static ai_inline bool ai_major_cell(struct ai *g, word *c) {       // a tenured cell: inside the major pool
 return ptr(c) >= g->major_base && ptr(c) < g->major_hp; }
// the cell barrier (c0's emit, ev's poke): remember the smallest scannable unit around a
// young-into-tenured store. the cell sits in a tagged span -- a thread, a scope -- and
// never in a chain's field, which has no terminator for the remembered walk to stop at.
// there is no door for a cons: nothing patches one, so nothing needs to say it does.
// masks g.
void gen_wb_cell(struct ai *g, void *cl, word v) {
 g = ai_core_of(g);
 if (ai_young(g, v) && ai_major_cell(g, cl)) gen_remember(g, (word) cl); }

// gen_scan_inplace: a tenured object pointing into the young set stays put, but its
// young fields must promote -- gcp each outgoing pointer in place. evac_* without
// the relocation; a thread's terminator sits in the major to-space.
static void gen_scan_inplace(struct ai *g, struct ai_gcx *X, word obj) {
 union u *p = cell(obj);
 if (!datp(obj))
  for (union u *q = p; !tagl(g, X, q->x); q++) q->x = gcp(g, X, q->x); // read to the terminator
 else switch (typ(obj)) {
  case DChain: {
   struct ai_chain *w = two(obj);
   w->a = gcp(g, X, w->a), w->b = gcp(g, X, w->b);
   break; }
  case DTray: {
   struct ai_tray *v = tray(p);
   uintptr_t ne = tray_nelem(v);
   if (v->type == ai_O)
    for (word *e = ptr(tray_data(v)); ne--; e[ne] = gcp(g, X, e[ne]));
   break; }
  case DNom: nom(p)->name = gcp(g, X, nom(p)->name); break;
  default: break; } }                              // DMint/DString/DBig/DGem/DSun/DTwin: pointer-free leaves

// relocate finalizer nodes out of the dead minor into the major. a minor never
// runs a finalizer; that waits for a major's compact.
static void gen_fz_relocate(struct ai *g) {
 struct ai_fz **link = &g->fz;
 for (struct ai_fz *fz = *link; fz; ) {
  struct ai_fz *next = fz->next;
  if ((word*) fz >= (word*) g->end && (word*) fz < g->hp) {   // node was in the minor -> relocate
   struct ai_fz *nn = gbump(g, Width(struct ai_fz));
   nn->p = fz->p, nn->fn = fz->fn, nn->next = next;
   *link = nn, link = &nn->next;
  } else link = &fz->next;
  fz = next; } }

// the weak-table sweep + finalizer pass of a major's compact: symbols_rebuild /
// run_finalizers, but bumping into the major to-space and testing survival against X's
static word major_symbols_rebuild(struct ai *g, struct ai_gcx *X, word om) {
 if (!om) return 0;
 uintptr_t cap = map_cap(om), mask = cap - 1, n = 0;
 union u *b = map_fill_back(gbump(g, 4 + 2 * cap), cap), *hd = gbump(g, 3);
 hd[0].ap = lvm_map_lookup, hd[1].x = (word) b, tagthread(hd, 2);
 word *os = map_slots(om), *ns = &b[3].x;
 word const *lo = X->to_lo, *hi = X->to_hi;
 for (uintptr_t j = 0; j < cap; j++) {
  word k = os[2 * j];
  if (k == map_gap) continue;
  word e = os[2 * j + 1];
  word fwd = cell(e)->x;                        // the atom's first word: its forward, if it survived
  if (!(lamp(fwd) && lo <= ptr(fwd) && ptr(fwd) < hi)) continue;
  word nk = nom(fwd)->name;
  uintptr_t i = hash(g, nk) & mask;
  while (ns[2 * i] != map_gap) i = (i + 1) & mask;
  ns[2 * i] = nk, ns[2 * i + 1] = fwd, n++; }
 b[1].x = putcharm(n);
 return (word) hd; }

static void major_run_finalizers(struct ai *g, struct ai_gcx *X) {
 struct ai_fz *new_fz = NULL;
 for (struct ai_fz *fz = g->fz; fz; fz = fz->next) {
  word fwd = fz->p->x;
  if (lamp(fwd) && X->to_lo <= ptr(fwd) && ptr(fwd) < X->to_hi) {
   struct ai_fz *nn = gbump(g, Width(struct ai_fz));
   nn->p = cell(fwd), nn->fn = fz->fn, nn->next = new_fz, new_fz = nn;
  } else fz->fn(g, fz->p); }
 g->fz = new_fz; }

// AiGcStress's two numbers: an even poison, so a stale read faults at an address
// a backtrace can name; and how often a forced collection is a major (ai_please).
#define ai_gc_poison ((word) 0xd0d0d0d0d0d0d0d0ULL)
#define ai_gc_stress_major 32

// the minor: evacuate [end, hp) into the major active half, reset hp = end. the
// cheney scan starts at the append point, walking only fresh survivors; X.fwd
// tells a forward made this collection from a pointer to a pre-existing major object.
static void gen_minor(struct ai *g) {
 struct ai_gcx X = { .p0 = (word const*) g->end, .t0 = g->hp,    // minor from-range
                     .to_lo = g->major_base, .to_hi = g->major_base + g->major_len,
                     .fwd = g->major_hp, .cp = g->major_hp };
 g->gc_gen = true;
 g->ip = cell(gcp(g, &X, word(g->ip)));
 g->tasks = cell(gcp(g, &X, word(g->tasks)));
 if (g->parked) g->parked = cell(gcp(g, &X, word(g->parked)));   // the parked ring is its own root
 for (word i = 0; i < g->end - &g->v0; i++) (&g->v0)[i] = gcp(g, &X, (&g->v0)[i]);   // core vars
 for (word *s = g->sp; s < topof(g); s++) *s = gcp(g, &X, *s);                       // stack
 for (struct ai_r *r = g->root; r; r = r->n) *r->x = gcp(g, &X, *r->x);              // C roots
 // the weak intern map is its own field, not a root: promote its structure by hand
 // (entries stay weak -- a major drops dead atoms). young header: gcp it; tenured:
 // scan its possibly-young backing in place.
 if (g->symbols) { // FIXME when !g->symbols ?  early init?
  if (ai_young(g, g->symbols)) g->symbols = gcp(g, &X, g->symbols);
  else gen_scan_inplace(g, &X, g->symbols), gen_scan_inplace(g, &X, map_back(g->symbols)); }
 for (uintptr_t i = 0; i < g->rem_n; i++) gen_scan_inplace(g, &X, g->rem[i]);        // major->young edges
 for (struct ai_fz *fz = g->fz; fz; fz = fz->next) fz->p = cell(gcp(g, &X, word(fz->p)));
 while (X.cp < g->major_hp)
  if (datp(X.cp)) evac_data(g, &X);
  else evac_thread(g, &X);
#ifdef AiGcCheck
 // the fixpoint is a fixpoint (gc.v drain_second_pass_copies_nothing): re-drive the
 // whole scan; every gcp must be an identity. if major_hp moves, the first pass lost
 // a reachable object -- trap at the collection that lost it. (make test_gcheck)
 { word *hp1 = g->major_hp;
  X.cp = X.fwd;
  g->ip = cell(gcp(g, &X, word(g->ip)));
  g->tasks = cell(gcp(g, &X, word(g->tasks)));
  if (g->parked) g->parked = cell(gcp(g, &X, word(g->parked)));
  for (word i = 0; i < g->end - &g->v0; i++) (&g->v0)[i] = gcp(g, &X, (&g->v0)[i]);
  for (word *s = g->sp; s < topof(g); s++) *s = gcp(g, &X, *s);
  for (struct ai_r *r = g->root; r; r = r->n) *r->x = gcp(g, &X, *r->x);
  if (g->symbols) {
   if (ai_young(g, g->symbols)) g->symbols = gcp(g, &X, g->symbols);
   else gen_scan_inplace(g, &X, g->symbols), gen_scan_inplace(g, &X, map_back(g->symbols)); }
  for (uintptr_t i = 0; i < g->rem_n; i++) gen_scan_inplace(g, &X, g->rem[i]);
  for (struct ai_fz *fz = g->fz; fz; fz = fz->next) fz->p = cell(gcp(g, &X, word(fz->p)));
  while (X.cp < g->major_hp) (datp(X.cp) ? evac_data : evac_thread)(g, &X);
  if (g->major_hp != hp1) __builtin_trap(); }
#endif
 if (g->fz) gen_fz_relocate(g);
 g->hp = g->end;                                              // minor emptied
#ifdef AiGcStress
 // poison the vacated nursery, or the stress build is half a detector: a stale
 // local otherwise reads a forwarding pointer that still looks live. last thing
 // here -- gen_fz_relocate is the from-space's last reader.
 for (word *p = (word*) X.p0; p < (word*) X.t0; p++) *p = ai_gc_poison;
#endif
 g->gc_gen = false; }

// the major: one cheney pass from the real roots over both from-spaces into the
// spare half -- reachability, never a linear sweep, which is why a rem-set overflow
// forces one. then rebuild the intern map, run finalizers, flip, reset the minor.
// req0 is the allocation that could not be served; *tight answers whether the pool got the
// size it asked for, which only ai_please can act on.
struct ai *gen_major(struct ai *g, uintptr_t req0, bool *tight) {
 struct ai_gcx X = { .p0 = g->major_base, .t0 = g->major_hp };   // from-range 1: major active
 // size the to-space for the worst case: all of major-active and all of the minor survive
 uintptr_t used = (uintptr_t)(g->major_hp - g->major_base), young = (uintptr_t)(g->hp - (word*) g->end),
           need = used + young,
 // grow/shrink by a whole step (= ai_major0): one step at a time prevents thrash, and
 // snapping down reclaims floated dead promotions. headroom is 25% or a whole nursery
 // plus the pending request, whichever is larger -- the second is ai_please's forcing
 // test verbatim, and a pool sized under it leaves that test true after the major it
 // just forced, so every later collection is a major too.
           slack = (uintptr_t) g->len + req0 + 16, head = need >> 2,
           step = g->major0, want = need + (head > slack ? head : slack) + 16,
           to_len = ((want + step - 1) / step) * step;
 if (to_len < step) to_len = step;
 uintptr_t free_len = to_len,                                   // the size asked for, before any clamp
           need_step = ((need + step - 1) / step) * step;       // the tight size: smallest step-multiple holding `need`
 if (need_step < step) need_step = step;
 // budget cap: keep the major pair within its share, but never below need_step (the
 // to-space must hold the worst-case promotion); too small falls through to the oom path
 if (g->budget) {
  uintptr_t cap = g->budget > 2 * (uintptr_t) g->len ? (g->budget - 2 * (uintptr_t) g->len) / 2 : 0;
  if (to_len > cap) to_len = cap > need_step ? (cap / step) * step : need_step; }
 word *spare = (g->major_base == g->major_pool) ? g->major_pool + g->major_len : g->major_pool,  // the same-size other half
      *to, *resized = 0;
 if (to_len != g->major_len) {                                 // a different-size pair: alloc it, free the old
  resized = g->alloc(g, NULL, 2 * to_len * sizeof(word));
  if (!resized && to_len > need_step)                          // the headroom alloc failed: retry at the tight size
   to_len = need_step, resized = (need_step == g->major_len) ? 0 : g->alloc(g, NULL, 2 * need_step * sizeof(word));
  if (resized) to = resized;
  else if (need <= g->major_len) to_len = g->major_len, to = spare;   // alloc failed, but the existing spare half holds the live set
  else return g->gc_gen = false, encode(g, ai_status_scare);         // true oom: compacting would overflow the spare -> clean scare, no corruption
 } else to = spare;
 g->gc_gen = true;
 if (tight) *tight = to_len < free_len;   // denied: the budget cap, or the bigger alloc failed
 g->major_hp = to, X.cp = to;
 X.to_lo = to, X.to_hi = to + to_len, X.fwd = to;           // fresh to-space: every copy is a forward
 X.f2lo = (word const*) g->end, X.f2hi = g->hp;             // from-range 2: the minor (promote young in the same pass)
 g->ip = cell(gcp(g, &X, word(g->ip)));
 g->tasks = cell(gcp(g, &X, word(g->tasks)));
 if (g->parked) g->parked = cell(gcp(g, &X, word(g->parked)));   // the parked ring is its own root
 for (word i = 0; i < g->end - &g->v0; i++) (&g->v0)[i] = gcp(g, &X, (&g->v0)[i]);
 for (word *s = g->sp; s < topof(g); s++) *s = gcp(g, &X, *s);
 for (struct ai_r *r = g->root; r; r = r->n) *r->x = gcp(g, &X, *r->x);
 word om = g->symbols; g->symbols = 0;                       // weak: rebuilt after the fixpoint
 while (X.cp < g->major_hp) (datp(X.cp) ? evac_data : evac_thread)(g, &X);
 g->symbols = major_symbols_rebuild(g, &X, om);
 major_run_finalizers(g, &X);
 if (resized) g->alloc(g, g->major_pool, 0), g->major_pool = resized, g->major_len = to_len;
 g->major_base = to;                                           // flip: active = the to-space
 g->hp = g->end;                                             // the minor's young was promoted: reset it
#ifdef AiGcStress
 // poison the promoted young, like the minor. the old major half does not: poisoning it
 // costs ten minutes on a 24-second lane, and a cheney copy already left a forwarding
 // pointer in word0 (the ap), which faults on dispatch.
 for (word *p = (word*) g->end; p < (word*) g->end + young; p++) *p = ai_gc_poison;
#endif
 // the rem set dies with the half it named: a major promotes every survivor, so there is
 // no old->young edge left to remember and every address in it points into a half about
 // to be reused. cleared here rather than in ai_please alone, because a major can be
 // called directly -- the image dump compacts before it serializes.
 g->rem_n = 0, g->rem_miss = 0;
 return g->gc_gen = false, g; }

// resize the minor pool, decoupled from the major. called right after a collection,
// so the minor is empty: only the core + stack move; the major + intern map ride
// through untouched (() is ZeroPoint, so nothing points at the moving core).
struct ai *gen_grow(struct ai *g, uintptr_t len1) {
 struct ai *h = g->alloc(g, NULL, len1 * 2 * sizeof(word));
 if (!h) return encode(g, ai_status_scare);
 memcpy(h, g, sizeof(struct ai));
 h->len = len1;
 h->gc_gen = false;
 word const *sp0 = g->sp;
 struct ai_gcx X = { .p0 = ptr(g), .t0 = ptr(g) + g->len,      // the whole old pool is the from-space
                     .to_lo = ptr(h), .to_hi = ptr(h) + len1, .fwd = ptr(h), .cp = h->end };
 word sh = X.t0 - sp0;
 h->sp = ptr(h) + len1 - sh;
 h->hp = h->end;                             // core moves to h; no (word)g root to forward (() is the const ZeroPoint)
 h->ip = cell(gcp(h, &X, word(h->ip)));
 h->tasks = cell(gcp(h, &X, word(h->tasks)));
 if (h->parked) h->parked = cell(gcp(h, &X, word(h->parked)));
 // h->symbols + the major were memcpy'd and live outside [p0,t0): untouched, not rebuilt
 for (word i = 0; i < h->end - &h->v0; i++) (&h->v0)[i] = gcp(h, &X, (&h->v0)[i]);   // core vars
 for (word n = 0; n < sh; n++) h->sp[n] = gcp(h, &X, sp0[n]);                        // stack
 for (struct ai_r *s = h->root; s; s = s->n) *s->x = gcp(h, &X, *s->x);              // C roots
 while (X.cp < h->hp) (datp(X.cp) ? evac_data : evac_thread)(h, &X);                 // heap empty -> ~nothing
 h->n_resize += 1;
 if (h->len > h->max_len) h->max_len = h->len;
 g->alloc(g, g, 0);                          // free the old main pool
 return h; }

// the GC entry: a minor unless the rem set overflowed or the major lacks headroom --
// then a major. afterwards size the minor by appel's rule against the budget.
ai_noinline struct ai *ai_please(struct ai *g, uintptr_t req0) {
 uintptr_t seen_young = (uintptr_t)(g->hp - g->end),
           major_free = (uintptr_t)((g->major_base + g->major_len) - g->major_hp);
 g->since_major += seen_young;                                  // young allocated (∝ scanned) since the last major
 // a major: forced by rem-set overflow, by the major lacking room for a worst-case
 // promotion, or by the amortization rule -- live set + 4 minor-pools allocated since
 // the last one -- so floating dead tenured objects sweep and the pool can shrink.
 bool major = g->rem_miss
   || major_free < (uintptr_t) g->len + req0 + 16
   || g->since_major > g->major_live0 + 4 * (uintptr_t) g->len;
#ifdef AiGcStress
 // a minor is not enough: stress-collecting tenures everything almost at once,
 // and a minor never moves the tenured -- the detector answered green on its own
 // control. every-collection-major cost a 458 s boot, so a major rides every Nth
 // collection instead: deterministic, off g->n_gc. coverage is the stated trade.
 major = major || g->n_gc % ai_gc_stress_major == 0;
#endif
 word *before = g->major_hp;
 bool tight = false;
 if (major) {
  if (!ai_ok(g = gen_major(g, req0, &tight))) return g;     // a true oom mid-major (compacting would overflow the spare): propagate the scare
  g->n_gc += 1;
  g->since_major = 0, g->major_live0 = (uintptr_t)(g->major_hp - g->major_base);   // reset the amortization window
#ifdef AiGcCheck
  // the forcing test above must read false after the major it forced, unless the sizer was
  // denied the room -- there thrash beats dying. still true on a pool that got what it asked
  // for is the two disagreeing over one number, and the collector has latched into permanent
  // majors: correct, quadratic, and no gate can see it. (make test_gcheck)
  if (!tight && (uintptr_t)((g->major_base + g->major_len) - g->major_hp) < (uintptr_t) g->len + req0 + 16)
   __builtin_trap();
#endif
 } else gen_minor(g), g->n_gc += 1, g->n_minor += 1;
 uintptr_t copied = major ? (uintptr_t)(g->major_hp - g->major_base) : (uintptr_t)(g->major_hp - before);
 g->n_seen += seen_young;
 g->n_evac += copied;
 if (major) { if (copied > g->major_hi) g->major_hi = copied; }
 else if (copied > g->minor_hi) g->minor_hi = copied;
 g->rem_n = 0, g->rem_miss = 0;
 uintptr_t e = (uintptr_t)(g->major_hp - g->major_base);
 if (e > g->max_heap) g->max_heap = e;
 // minor resize, deterministic (words copied / words allocated -- no wall clock, so
 // the schedule is reproducible): keep the copy overhead inside a band, accumulated
 // over a sliding window; ai_budget caps the footprint by appel's rule.
 uintptr_t const ratio = g->ratio;              // target band: grow above 1/ratio overhead, shrink below 1/(4*ratio)
#ifdef AiGcStress
 // the band is meaningless on a forced schedule (`allocated` ~0 doubles the nursery
 // every collection), but the hard floor stays: it guarantees the pending allocation
 // fits. it must also come back down -- a nursery parked at its high-water stands above
 // the major's spare, and `major_free < g->len` then forces a major every collection,
 // generational in name only. shrink on 4x hysteresis, so a resize is not per-pass.
 { uintptr_t used0 = g->len - avail(g), req = req0 + used0 + (used0 >> 2),
             want = req < g->minor0 ? g->minor0 : req;
   if (req > (uintptr_t) g->len) return gen_grow(g, req);        // the floor still wins
   if ((uintptr_t) g->len > 4 * want) return gen_grow(g, want);
   return g; }
#endif
 g->win_alloc += seen_young, g->win_copied += copied;
 uintptr_t used = g->len - avail(g), req = req0 + used + (used >> 2), len1 = g->len, arena = len1;
 // resize stickiness: act only on two consecutive same-way windows (lean tracks the
 // streak; in-band ends it). a resize is the costliest single act -- fresh pool, full
 // copy, every page refaulted -- so a spike self-corrects and only a real ramp confirms
 // next collection. first-verdict-with-reset taxes ramps ~4%, and excluding majors from
 // the window costs +70% wall.
 if (g->win_copied * ratio > g->win_alloc) {                   // overhead > 1/ratio: nursery too small
  if ((g->lean = g->lean > 0 ? g->lean + 1 : 1) >= 2) {        // confirmed: grow
   uintptr_t wa = g->win_alloc | 1;                            // grow until the projected overhead lands in band (| 1: guarantee progress)
   while (g->win_copied * ratio > wa) arena <<= 1, wa <<= 1;    // (doubling the pool ~doubles alloc-between-GCs)
   g->lean = 0, g->win_alloc = g->win_copied = 0; }
 } else if (g->win_copied * (ratio * 4) < g->win_alloc) {       // overhead < 1/(4*ratio): oversized
  if ((g->lean = g->lean < 0 ? g->lean - 1 : -1) <= -2)
   arena = len1 >> 1, g->lean = 0, g->win_alloc = g->win_copied = 0;   // shrink one step (gentle -- multi-step collapses on a lucky GC)
 } else if (g->win_alloc > 8 * len1) g->win_alloc = g->win_copied = 0, g->lean = 0;   // in band: cap the window; the streak dies
 if (g->budget) {
  // appel cap, reserving room for the major that must hold the worst-case promotion
  // (live + this whole nursery): the nursery gets ~(budget - 2*live)/4
  uintptr_t lv = 2 * g->major_live0, room = g->budget > lv ? (g->budget - lv) / 4 : 0;
  if (arena > room) arena = room; }
 // the pool was denied room for a worst-case promotion of this nursery, so the nursery is
 // what gives. the floors below still win: under real pressure thrash beats failing the
 // request that asked for the collection.
 if (tight) {
  uintptr_t fr = (uintptr_t)((g->major_base + g->major_len) - g->major_hp),
            fit = fr > req0 + 16 ? fr - req0 - 16 : 0;
  if (arena > fit) arena = fit; }
 if (arena < g->minor0) arena = g->minor0;                     // floor
 if (arena < req) arena = req;                                 // hard floor: hold the pending allocation
 return arena == len1 ? g : gen_grow(g, arena); }

static ai_inline word copy_data(struct ai *g, union u *src) {
 switch (typ(src)) {
  case DChain: {
   struct ai_chain *s = two(src), *d = gbump(g, chain_req);
   ini_chain(d, s->a, s->b);
   return word(s->ap = (void*) d); }
  case DTray: {
   struct ai_tray *s = tray(src), *d;
   uintptr_t bytes = ai_tray_bytes(s);
   d = gbump(g, b2w(bytes));
   return word(s->ap = memcpy(d, s, bytes)); }
  case DMint: {
   struct ai_mint *s = sym(src), *d = gbump(g, mint_req);
   ini_missing(d, s->code); // FIXME missing???
   return word(s->ap = (void*) d); }
  case DNom: {
   struct ai_nom *s = nom(src), *d = gbump(g, nom_req);
   ini_nom(d, s->name, s->code, s->dig);
   return word(s->ap = (void*) d); }
  case DString: {
   struct ai_str *s = str(src), *d;
   uintptr_t w = str_width(s->len);
   d = gbump(g, w);
   return word(s->ap = memcpy(d, s, w * sizeof(word))); }   // whole words: the zeroed tail rides
  case DBig: {
   struct ai_big *s = big(src), *d;
   uintptr_t bytes = ai_big_bytes(s);
   d = gbump(g, b2w(bytes));
   return word(s->ap = memcpy(d, s, bytes)); }
  case DGem: {
   struct ai_gem *s = gem(src), *d = gbump(g, gem_req);
   return word(s->ap = memcpy(d, s, sizeof(struct ai_gem))); }
  case DSun: {
   struct ai_sun *s = sun(src), *d = gbump(g, sun_req);
   return word(s->ap = memcpy(d, s, sizeof(struct ai_sun))); }
  case DTwin: {
   struct ai_twin *s = twin(src), *d = gbump(g, twin_req);
   return word(s->ap = memcpy(d, s, sizeof(struct ai_twin))); } }
 __builtin_trap(); }

static ai_inline struct ai_tag *ttag2(struct ai *g, struct ai_gcx *X, union u *k) {
 while (!tagl(g, X, k->x)) k++;                              // tagl: terminator head in any live pool
 return (struct ai_tag*) k; }

static ai_inline word copy_thread(struct ai *g, struct ai_gcx *X, union u *src) {
 // it's a thread, find the end to find the head
 struct ai_tag *t = ttag2(g, X, src);
 union u *ini = tag_head(t), *d = gbump(g, t->end - ini), *dst = d;
 // copy each content word to dest and leave a forwarding pointer behind,
 // stopping at the terminator; then rewrite it as the new tagged head
 for (union u *s = ini; !tagl(g, X, s->x); s->x = (word) d, d++, s++) d->x = s->x;
 return (word) (tagthread(dst, d - dst) + (src - ini)); }

static ai_noinline intptr_t gcp(struct ai *g, struct ai_gcx *X, word x) {
 // a number stays; else x must sit in a from-space range this pass traces (a major traces two)
 if (charmp(x)) return x;
 if (!(ptr(x) >= X->p0 && ptr(x) < X->t0)
  && !(X->f2lo && ptr(x) >= X->f2lo && ptr(x) < X->f2hi)) return x;
 union u *src = cell(x);
 x = src->x; // get its contents
 // if it contains a pointer to the new space then return the pointer (already forwarded)
 word const *flo = X->fwd, *fhi = X->to_hi;   // forwarding window of this collection (major/spare/new pool)
 return lamp(x) && flo <= ptr(x) && ptr(x) < fhi ? x :
        in_data((void*) x) ? copy_data(g, src) :
                             copy_thread(g, X, src); }
