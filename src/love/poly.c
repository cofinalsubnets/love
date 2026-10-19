// poly -- convex polygons cut by planes, as lore's brushes cut their faces (brush.l)
// a polygon is a list of points going round, each [x y z]; a plane [n d] holds the points p
// with dot n p <= d. a corner that comes through uncut is the same word it came in as.
//  (poly-keep ps pls)  ps kept inside each plane in turn, till it is under three corners
//  (poly-carve ps pls) ps in pieces, each plane through it cutting every piece it crosses
//  (poly-grid ps cell) ps cut at every multiple of cell, x then y then z
// a carve's or a grid's pieces are those three or more corners round and over 1e-8 in area,
// in the order brush.l laid them; () where an argument is not as it says
#include "love.h"
#if Bits == 64
double lm_sqrt(double);
#define pl_sqrt lm_sqrt
#else
float lm_sqrtf(float);
#define pl_sqrt lm_sqrtf
#endif

struct pv { flo_t p[3]; intptr_t src; };   // src the input corner it is, -1 a cut's
// pieces end to end: piece i's corners v[at[i]] to v[at[i + 1]]
struct bag { struct pv *v; uintptr_t nv, cv; uintptr_t *at; uintptr_t np, cp; int bad; };

static void *pl_grow(void *p, uintptr_t n, uintptr_t *cap, uintptr_t w, int *bad) {
 if (n <= *cap) return p;
 uintptr_t c = *cap ? *cap : 16;
 while (c < n) c *= 2;
 void *q = alloc(NULL, c * w);
 if (!q) return *bad = 1, p;
 if (p) memcpy(q, p, *cap * w), alloc(p, 0);
 return *cap = c, q; }
static void bag_ini(struct bag *b) { *b = (struct bag){0}; b->at = pl_grow(NULL, 1, &b->cp, sizeof *b->at, &b->bad); if (b->at) b->at[0] = 0; }
static void bag_fin(struct bag *b) { if (b->v) alloc(b->v, 0); if (b->at) alloc(b->at, 0); }
static void bag_put(struct bag *b, struct pv const *v) {
 b->v = pl_grow(b->v, b->nv + 1, &b->cv, sizeof *b->v, &b->bad);
 if (!b->bad) b->v[b->nv++] = *v; }
static void bag_end(struct bag *b) {   // the corners put since the last end, a piece
 b->at = pl_grow(b->at, b->np + 2, &b->cp, sizeof *b->at, &b->bad);
 if (!b->bad) b->at[++b->np] = b->nv; }
static void bag_drop(struct bag *b) { b->nv = b->at[b->np]; }   // ..or not
static void bag_reset(struct bag *b) { b->nv = b->np = 0; }
static uintptr_t bag_n(struct bag const *b, uintptr_t i) { return b->at[i + 1] - b->at[i]; }
static struct pv *bag_piece(struct bag const *b, uintptr_t i) { return b->v + b->at[i]; }
static void bag_copy(struct bag *b, struct pv const *ps, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) bag_put(b, ps + i);
 bag_end(b); }

// the arithmetic as brush.l's, step for step, so the corners come out the same
static flo_t pl_side(flo_t const pl[4], flo_t const p[3]) { return pl[0] * p[0] + pl[1] * p[1] + pl[2] * p[2] - pl[3]; }
static flo_t pl_area(struct pv const *ps, uintptr_t n) {
 flo_t s[3] = {0, 0, 0};
 flo_t const *a = ps[0].p;
 for (uintptr_t i = 1; i + 1 < n; i++) {
  flo_t const *b = ps[i].p, *c = ps[i + 1].p;
  flo_t u[3] = {b[0] - a[0], b[1] - a[1], b[2] - a[2]}, v[3] = {c[0] - a[0], c[1] - a[1], c[2] - a[2]};
  s[0] = s[0] + (u[1] * v[2] - u[2] * v[1]);
  s[1] = s[1] + (u[2] * v[0] - u[0] * v[2]);
  s[2] = s[2] + (u[0] * v[1] - u[1] * v[0]); }
 return pl_sqrt(s[0] * s[0] + s[1] * s[1] + s[2] * s[2]); }
static bool pl_ok(struct pv const *ps, uintptr_t n) { return n >= 3 && pl_area(ps, n) > (flo_t) 1e-8; }
static bool pl_crosses(struct pv const *ps, uintptr_t n, flo_t const pl[4]) {
 bool hi = 0, lo = 0;
 for (uintptr_t i = 0; i < n; i++) {
  flo_t const s = pl_side(pl, ps[i].p);
  hi |= s > (flo_t) 1e-5, lo |= s < (flo_t) -1e-5; }
 return hi && lo; }
// ps's part inside the plane onto in, and beyond it onto out, each one piece; either NULL
static void pl_split(struct pv const *ps, uintptr_t n, flo_t const pl[4], struct bag *in, struct bag *out) {
 flo_t const eps = (flo_t) 1e-6;
 for (uintptr_t i = 0; i < n; i++) {
  struct pv const *a = ps + i, *b = ps + (i + 1) % n;
  flo_t const sa = pl_side(pl, a->p), sb = pl_side(pl, b->p);
  if (in && sa <= eps) bag_put(in, a);
  if (out && sa >= (flo_t) 0.0 - eps) bag_put(out, a);
  if ((sa < (flo_t) 0.0 - eps && sb > eps) || (sa > eps && sb < (flo_t) 0.0 - eps)) {
   flo_t const t = sa / (sa - sb);
   struct pv x = {{a->p[0] + t * (b->p[0] - a->p[0]), a->p[1] + t * (b->p[1] - a->p[1]), a->p[2] + t * (b->p[2] - a->p[2])}, -1};
   if (in) bag_put(in, &x);
   if (out) bag_put(out, &x); } } }

static bool pl_num3(word l, flo_t o[3]) {
 for (int k = 0; k < 3; k++, l = B(l)) {
  if (!chainp(l) || !isnum(A(l))) return 0;
  o[k] = toflo(A(l)); }
 return 1; }
// a polygon's corners into a piece of b
static bool pl_read(word l, struct bag *b) {
 for (intptr_t i = 0; chainp(l); l = B(l), i++) {
  struct pv v = {{0, 0, 0}, i};
  if (!pl_num3(A(l), v.p)) return 0;
  bag_put(b, &v); }
 return bag_end(b), 1; }
// planes into n0 n1 n2 d rows
static flo_t *pl_planes(word l, uintptr_t *n, int *bad) {
 uintptr_t m = llen(l), cap = 0;
 flo_t *p = pl_grow(NULL, 4 * m + 4, &cap, sizeof *p, bad);
 if (*bad) return NULL;
 for (uintptr_t i = 0; i < m; i++, l = B(l)) {
  word const q = A(l);
  if (!chainp(q) || !chainp(B(q)) || !isnum(A(B(q))) || !pl_num3(A(q), p + 4 * i)) return alloc(p, 0), *bad = 1, NULL;
  p[4 * i + 3] = toflo(A(B(q))); }
 return *n = m, p; }

// b's pieces as lists, the uncut corners taken from the polygon at sp[0]; one piece bare
static struct g *pl_emit(struct g *g, struct bag *b, bool one) {
 uintptr_t nw = one ? 0 : b->np * chain_req, nin = 0;
 for (uintptr_t i = 0; i < b->nv; i++) nw += chain_req + (b->v[i].src < 0 ? 3 * (chain_req + gem_req) : 0);
 if (!ok(g = have(g, nw))) return g;
 for (word l = g->sp[0]; chainp(l); l = B(l)) nin++;
 uintptr_t cap = 0;
 word *in = pl_grow(NULL, nin + 1, &cap, sizeof *in, &b->bad);
 if (b->bad) return g->sp[0] = ZeroPoint, g;
 nin = 0;
 for (word l = g->sp[0]; chainp(l); l = B(l)) in[nin++] = A(l);
 word r = ZeroPoint;
 for (uintptr_t i = b->np; i--; ) {
  word ps = ZeroPoint;
  for (uintptr_t j = bag_n(b, i); j--; ) {
   struct pv const *v = bag_piece(b, i) + j;
   word p;
   if (v->src >= 0) p = in[v->src];
   else {
    p = ZeroPoint;
    for (int k = 3; k--; ) {
     word const x = mk_gem(&g->hp, v->p[k]);
     p = word(ini_chain(bump(g, chain_req), (intptr_t) x, (intptr_t) p)); } }
   ps = word(ini_chain(bump(g, chain_req), (intptr_t) p, (intptr_t) ps)); }
  r = one ? ps : word(ini_chain(bump(g, chain_req), (intptr_t) ps, (intptr_t) r)); }
 alloc(in, 0);
 g->sp[0] = r;
 return g; }

love_noinline static struct g *host_poly_keep(struct g *g) {
 struct bag a, c;
 bag_ini(&a), bag_ini(&c);
 uintptr_t np = 0;
 flo_t *pl = pl_planes(g->sp[1], &np, &a.bad);
 if (!a.bad && pl_read(g->sp[0], &a))
  for (uintptr_t j = 0; j < np && bag_n(&a, 0) >= 3 && !a.bad && !c.bad; j++) {
   bag_reset(&c);
   pl_split(bag_piece(&a, 0), bag_n(&a, 0), pl + 4 * j, &c, NULL);
   bag_end(&c);
   struct bag t = a; a = c, c = t; }
 else a.bad = 1;
 g = a.bad || c.bad ? (g->sp[0] = ZeroPoint, g) : pl_emit(g, &a, 1);
 if (pl) alloc(pl, 0);
 return bag_fin(&a), bag_fin(&c), g; }

love_noinline static struct g *host_poly_carve(struct g *g) {
 struct bag a, c;
 bag_ini(&a), bag_ini(&c);
 uintptr_t np = 0;
 flo_t *pl = pl_planes(g->sp[1], &np, &a.bad);
 if (!a.bad && pl_read(g->sp[0], &a))
  for (uintptr_t j = 0; j < np && !a.bad && !c.bad; j++) {
   bag_reset(&c);
   for (uintptr_t i = 0; i < a.np; i++) {
    struct pv const *ps = bag_piece(&a, i);
    uintptr_t const n = bag_n(&a, i);
    if (!pl_crosses(ps, n, pl + 4 * j)) { bag_copy(&c, ps, n); continue; }
    for (int s = 0; s < 2; s++) {
     pl_split(ps, n, pl + 4 * j, s ? NULL : &c, s ? &c : NULL);
     if (pl_ok(c.v + c.at[c.np], c.nv - c.at[c.np])) bag_end(&c); else bag_drop(&c); } }
   struct bag t = a; a = c, c = t; }
 else a.bad = 1;
 g = a.bad || c.bad ? (g->sp[0] = ZeroPoint, g) : pl_emit(g, &a, 0);
 if (pl) alloc(pl, 0);
 return bag_fin(&a), bag_fin(&c), g; }

static flo_t pl_floor(flo_t x) { flo_t t = love_trunc(x); return t > x ? t - 1 : t; }
// one piece in strips across axis k onto c, last first as brush.l's slab laid them; s u r scratch
static void pl_slab(struct pv const *ps, uintptr_t n, int k, flo_t cell, struct bag *c, struct bag *s, struct bag *u, struct bag *r) {
 flo_t lo = (flo_t) 1e9, hi = (flo_t) -1e9;
 for (uintptr_t i = 0; i < n; i++) {
  flo_t const x = ps[i].p[k];
  lo = lo < x ? lo : x, hi = hi < x ? x : hi; }
 intptr_t m = (intptr_t) pl_floor((lo + (flo_t) 1e-5) / cell) + 1, m1 = (intptr_t) pl_floor((hi - (flo_t) 1e-5) / cell);
 bag_reset(r), bag_reset(s), bag_copy(s, ps, n);
 for (; !s->bad && !u->bad && !r->bad; m++) {
  if (m > m1 || cell * (flo_t) m >= hi - (flo_t) 1e-5) {
   if (pl_ok(bag_piece(s, 0), bag_n(s, 0))) bag_copy(r, bag_piece(s, 0), bag_n(s, 0));
   break; }
  flo_t const pl[4] = {(flo_t) (k == 0), (flo_t) (k == 1), (flo_t) (k == 2), cell * (flo_t) m};
  bag_reset(u);
  pl_split(bag_piece(s, 0), bag_n(s, 0), pl, r, u);
  bag_end(u);
  if (pl_ok(r->v + r->at[r->np], r->nv - r->at[r->np])) bag_end(r); else bag_drop(r);
  struct bag t = *s; *s = *u, *u = t; }
 for (uintptr_t i = r->np; i--; ) bag_copy(c, bag_piece(r, i), bag_n(r, i)); }

love_noinline static struct g *host_poly_grid(struct g *g) {
 struct bag a, c, s, u, r;
 bag_ini(&a), bag_ini(&c), bag_ini(&s), bag_ini(&u), bag_ini(&r);
 word const cl = g->sp[1];
 if (isnum(cl) && pl_read(g->sp[0], &a)) {
  flo_t const cell = toflo(cl);
  for (int k = 0; k < 3; k++) {
   bag_reset(&c);
   for (uintptr_t i = 0; i < a.np; i++) pl_slab(bag_piece(&a, i), bag_n(&a, i), k, cell, &c, &s, &u, &r);
   struct bag t = a; a = c, c = t; } }
 else a.bad = 1;
 int const bad = a.bad | c.bad | s.bad | u.bad | r.bad;
 g = bad ? (g->sp[0] = ZeroPoint, g) : pl_emit(g, &a, 0);
 return bag_fin(&a), bag_fin(&c), bag_fin(&s), bag_fin(&u), bag_fin(&r), g; }

// --- a scene's corners, a millimetre a step, and the fans its pieces make ---
// a set of corners in a string: its slot count, its slot width (12 when every key fits 32
// bits, else 24), then the slots, each three keys, empty where the first is the least
static void pl_key(flo_t const p[3], int64_t k[3]) { for (int j = 0; j < 3; j++) k[j] = (int64_t) pl_floor(p[j] * (flo_t) 1000.0 + (flo_t) 0.5); }
static bool pl_narrow(int64_t const k[3]) { for (int j = 0; j < 3; j++) if (k[j] <= INT32_MIN || k[j] > INT32_MAX) return 0; return 1; }
static uint64_t pl_hash(int64_t const k[3]) {
 uint64_t h = (uint64_t) k[0] * 0x9e3779b97f4a7c15u;
 h = (h ^ (h >> 31)) + (uint64_t) k[1] * 0xc2b2ae3d27d4eb4fu;
 h = (h ^ (h >> 29)) + (uint64_t) k[2] * 0x165667b19e3779f9u;
 return h ^ (h >> 32); }
struct seen { uint8_t *s; uint64_t cap, w; };
static void pl_get(struct seen const *t, uint64_t i, int64_t e[3]) {
 uint8_t const *q = t->s + 16 + t->w * i;
 if (t->w == 24) { memcpy(e, q, 24); return; }
 int32_t n[3];
 memcpy(n, q, 12);
 for (int j = 0; j < 3; j++) e[j] = n[j]; }
static void pl_set(struct seen *t, uint64_t i, int64_t const k[3]) {
 uint8_t *q = t->s + 16 + t->w * i;
 if (t->w == 24) { memcpy(q, k, 24); return; }
 int32_t const n[3] = {(int32_t) k[0], (int32_t) k[1], (int32_t) k[2]};
 memcpy(q, n, 12); }
static int64_t pl_none(struct seen const *t) { return t->w == 24 ? INT64_MIN : INT32_MIN; }
// k's slot: where it is, or the empty one it would go in
static uint64_t pl_slot(struct seen const *t, int64_t const k[3]) {
 for (uint64_t i = pl_hash(k) & (t->cap - 1);; i = (i + 1) & (t->cap - 1)) {
  int64_t e[3];
  pl_get(t, i, e);
  if (e[0] == pl_none(t) || (e[0] == k[0] && e[1] == k[1] && e[2] == k[2])) return i; } }
static bool pl_seen(struct seen const *t, flo_t const p[3]) {
 int64_t k[3], e[3];
 pl_key(p, k);
 if (t->w == 12 && !pl_narrow(k)) return 0;
 pl_get(t, pl_slot(t, k), e);
 return e[0] != pl_none(t); }

// (poly-seen pss): every corner of every polygon in pss, for poly-fans
love_noinline static struct g *host_poly_seen(struct g *g) {
 uint64_t n = 0, cap = 8, w = 12;
 for (word l = g->sp[0]; chainp(l); l = B(l))
  for (word q = A(l); chainp(q); q = B(q)) {
   flo_t p[3];
   int64_t k[3];
   if (!pl_num3(A(q), p)) return g->sp[0] = ZeroPoint, g;
   pl_key(p, k), n++;
   if (!pl_narrow(k)) w = 24; }
 while (cap <= n) cap *= 2;   // never full, so a probe ends
 uintptr_t const bytes = (uintptr_t) (16 + w * cap), sw = str_width(bytes);
 if (!ok(g = have(g, sw))) return g;
 struct str *s = ini_str(bump(g, sw), bytes);
 struct seen t = {(uint8_t*) txt(s), cap, w};
 int64_t const none[3] = {pl_none(&t), 0, 0};
 memcpy(t.s, &cap, 8), memcpy(t.s + 8, &w, 8);
 for (uint64_t i = 0; i < cap; i++) pl_set(&t, i, none);
 for (word l = g->sp[0]; chainp(l); l = B(l))
  for (word q = A(l); chainp(q); q = B(q)) {
   flo_t p[3];
   int64_t k[3];
   pl_num3(A(q), p), pl_key(p, k);
   pl_set(&t, pl_slot(&t, k), k); }
 g->sp[0] = word(s);
 return g; }

struct fan { flo_t n[3], U[4], V[4], fine; struct seen seen; flo_t *ts; uintptr_t cts; };
static flo_t pl_dot4(flo_t const a[4], flo_t const p[3]) { return a[0] * p[0] + a[1] * p[1] + a[2] * p[2] + a[3]; }
// the corners where edge a b crosses a line of the fine grid and some piece has a corner,
// onto e in order along it
static void pl_on(struct fan *f, struct pv const *a, struct pv const *b, struct bag *e) {
 flo_t const d[3] = {b->p[0] - a->p[0], b->p[1] - a->p[1], b->p[2] - a->p[2]};
 uintptr_t nt = 0;
 for (int k = 0; k < 3; k++) {
  flo_t const lo = a->p[k] < b->p[k] ? a->p[k] : b->p[k], hi = a->p[k] < b->p[k] ? b->p[k] : a->p[k];
  if (hi - lo < (flo_t) 1e-6) continue;
  intptr_t const m0 = (intptr_t) pl_floor(lo / f->fine) + 1, m1 = (intptr_t) pl_floor((hi - (flo_t) 1e-6) / f->fine);
  for (intptr_t m = m0; m <= m1; m++) {
   flo_t const t = (f->fine * (flo_t) m - a->p[k]) / d[k];
   if (!((flo_t) 1e-6 < t && t < (flo_t) 1.0 - (flo_t) 1e-6)) continue;
   flo_t const x[3] = {a->p[0] + t * d[0], a->p[1] + t * d[1], a->p[2] + t * d[2]};
   if (!pl_seen(&f->seen, x)) continue;
   int bad = 0;
   f->ts = pl_grow(f->ts, nt + 1, &f->cts, sizeof *f->ts, &bad);
   if (bad) { e->bad = 1; return; }
   uintptr_t j = nt++;   // in order as it goes in
   for (; j && f->ts[j - 1] > t; j--) f->ts[j] = f->ts[j - 1];
   f->ts[j] = t; } }
 for (uintptr_t i = 0, kept = 0; i < nt; i++) {
  flo_t const t = f->ts[i];
  bool near = 0;
  for (uintptr_t j = 0; j < kept; j++) near |= (f->ts[j] - t < 0 ? t - f->ts[j] : f->ts[j] - t) < (flo_t) 1e-6;
  if (near) continue;
  f->ts[kept++] = t;
  struct pv x = {{a->p[0] + t * d[0], a->p[1] + t * d[1], a->p[2] + t * d[2]}, -1};
  bag_put(e, &x); } }
// a piece with corners taken on its edges, once it is over a cell across
static void pl_edged(struct fan *f, struct pv const *ps, uintptr_t n, struct bag *e) {
 flo_t lo[3] = {(flo_t) 1e9, (flo_t) 1e9, (flo_t) 1e9}, hi[3] = {(flo_t) -1e9, (flo_t) -1e9, (flo_t) -1e9};
 for (uintptr_t i = 0; i < n; i++)
  for (int k = 0; k < 3; k++) {
   flo_t const x = ps[i].p[k];
   lo[k] = lo[k] < x ? lo[k] : x, hi[k] = hi[k] < x ? x : hi[k]; }
 bool big = 0;
 for (int k = 0; k < 3; k++) big |= hi[k] - lo[k] > f->fine + (flo_t) 1e-6;
 for (uintptr_t i = 0; i < n; i++) {
  bag_put(e, ps + i);
  if (big) pl_on(f, ps + i, ps + (i + 1) % n, e); }
 bag_end(e); }
static void pl_mid(struct pv const *ps, uintptr_t n, flo_t m[3]) {
 flo_t s[3] = {(flo_t) 0.0, (flo_t) 0.0, (flo_t) 0.0};
 for (uintptr_t i = 0; i < n; i++) for (int k = 0; k < 3; k++) s[k] = s[k] + ps[i].p[k];
 flo_t const r = (flo_t) 1.0 / (flo_t) n;
 for (int k = 0; k < 3; k++) m[k] = r * s[k]; }
// whether the triangle a b c (b - a, c - a crossed) turns to n
static bool pl_turns(flo_t const n[3], flo_t const a[3], flo_t const b[3], flo_t const c[3]) {
 flo_t const u[3] = {b[0] - a[0], b[1] - a[1], b[2] - a[2]}, v[3] = {c[0] - a[0], c[1] - a[1], c[2] - a[2]},
             x[3] = {u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]};
 return x[0] * n[0] + x[1] * n[1] + x[2] * n[2] > 0; }

static word pl_list(struct g *g, word const *w, uintptr_t n) {
 word l = ZeroPoint;
 while (n--) l = word(ini_chain(bump(g, chain_req), (intptr_t) w[n], (intptr_t) l));
 return l; }
static word pl_gem(struct g *g, flo_t v) { return mk_gem(&g->hp, v); }

// (poly-fans pss n look seen fine): see the head
love_noinline static struct g *host_poly_fans(struct g *g) {
 struct fan f = {0};
 struct bag a, e;
 bag_ini(&a), bag_ini(&e);
 word const lk = g->sp[2], sn = g->sp[3];
 uintptr_t nm = 0, cm = 0, words = gem_req;
 flo_t *mids = NULL;
 bool good = pl_num3(g->sp[1], f.n) && chainp(lk) && chainp(B(lk)) && chainp(B(B(lk))) && strp(sn) && len(str(sn)) >= 16 && isnum(g->sp[4]);
 for (int s = 0; good && s < 2; s++) {
  word q = A(s ? B(B(lk)) : B(lk));
  flo_t *r = s ? f.V : f.U;
  for (int k = 0; k < 4; k++, q = B(q)) good = good && chainp(q) && isnum(A(q)) && ((r[k] = toflo(A(q))), 1); }
 if (good) {
  f.fine = toflo(g->sp[4]), f.seen.s = (uint8_t*) txt(str(sn)), memcpy(&f.seen.cap, f.seen.s, 8), memcpy(&f.seen.w, f.seen.s + 8, 8);
  good = (f.seen.w == 12 || f.seen.w == 24) && f.seen.cap && !(f.seen.cap & (f.seen.cap - 1)) && f.seen.cap <= len(str(sn)) / f.seen.w
         && 16 + f.seen.w * f.seen.cap <= len(str(sn)); }
 intptr_t src = 0;
 for (word l = g->sp[0]; good && chainp(l); l = B(l)) {
  uintptr_t const at = a.nv;
  for (word q = A(l); chainp(q); q = B(q), src++) {
   struct pv v = {{0, 0, 0}, src};
   if (!(good = pl_num3(A(q), v.p))) break;
   bag_put(&a, &v); }
  bag_end(&a);
  uintptr_t const n = a.nv - at;
  if (!good || n < 3) { good = 0; break; }
  mids = pl_grow(mids, 3 * (nm + 1), &cm, sizeof *mids, &a.bad);
  if (a.bad) break;
  pl_mid(a.v + at, n, mids + 3 * nm++);
  pl_edged(&f, a.v + at, n, &e);
  uintptr_t const ne = bag_n(&e, e.np - 1), nv = ne + (ne != n), nt = ne != n ? ne : n - 2;
  words += 5 * chain_req + 3 * (chain_req + gem_req)   // the list's, [mid mesh], mid, [vs ts]
         + nv * (12 * chain_req + 2 * gem_req) + nt * 5 * chain_req;
  for (uintptr_t i = 0; i < ne; i++) words += bag_piece(&e, e.np - 1)[i].src < 0 ? 3 * gem_req : 0; }
 good = good && !a.bad && !e.bad;
 if (good && ok(g = have(g, words))) {
  uintptr_t cin = 0;
  word *in = pl_grow(NULL, (uintptr_t) src + 1, &cin, sizeof *in, &a.bad);
  if (!a.bad) {
   uintptr_t k = 0;
   for (word l = g->sp[0]; chainp(l); l = B(l)) for (word q = A(l); chainp(q); q = B(q)) in[k++] = A(q);
   word nw[3], one = pl_gem(g, (flo_t) 1.0), r = ZeroPoint;
   for (int j = 0; j < 3; j++) nw[j] = A(j ? (j > 1 ? B(B(g->sp[1])) : B(g->sp[1])) : g->sp[1]);
   word const tex = A(g->sp[2]);
   for (uintptr_t i = nm; i--; ) {
    struct pv const *ps = bag_piece(&e, i);
    uintptr_t const ne = bag_n(&e, i), n0 = bag_n(&a, i), fan = ne != n0, nv = ne + fan;
    flo_t const *m = mids + 3 * i;
    word mw[3] = {pl_gem(g, m[0]), pl_gem(g, m[1]), pl_gem(g, m[2])};
    word ts = ZeroPoint, vs = ZeroPoint;
    if (fan)   // from the middle, round
     for (uintptr_t j = ne; j--; ) {
      uintptr_t const b = (j + 1) % ne;
      bool const t = pl_turns(f.n, m, ps[b].p, ps[j].p);
      word const tri[4] = {putcharm(ne), putcharm(t ? j : b), putcharm(t ? b : j), tex};
      ts = word(ini_chain(bump(g, chain_req), (intptr_t) pl_list(g, tri, 4), (intptr_t) ts)); }
    else
     for (uintptr_t j = n0 - 2; j--; ) {
      bool const t = pl_turns(f.n, ps[0].p, ps[j + 2].p, ps[j + 1].p);
      word const tri[4] = {putcharm(0), putcharm(t ? j + 1 : j + 2), putcharm(t ? j + 2 : j + 1), tex};
      ts = word(ini_chain(bump(g, chain_req), (intptr_t) pl_list(g, tri, 4), (intptr_t) ts)); }
    for (uintptr_t j = nv; j--; ) {
     flo_t const *p = j < ne ? ps[j].p : m;
     word x[3];
     if (j == ne) memcpy(x, mw, sizeof x);
     else if (ps[j].src >= 0) {
      word const c = in[ps[j].src];
      x[0] = A(c), x[1] = A(B(c)), x[2] = A(B(B(c))); }
     else for (int k = 0; k < 3; k++) x[k] = pl_gem(g, p[k]);
     word const vx[11] = {x[0], x[1], x[2], pl_gem(g, pl_dot4(f.U, p)), pl_gem(g, pl_dot4(f.V, p)), nw[0], nw[1], nw[2], one, one, one};
     vs = word(ini_chain(bump(g, chain_req), (intptr_t) pl_list(g, vx, 11), (intptr_t) vs)); }
    word const mesh[2] = {vs, ts}, it[2] = {pl_list(g, mw, 3), pl_list(g, mesh, 2)};
    r = word(ini_chain(bump(g, chain_req), (intptr_t) pl_list(g, it, 2), (intptr_t) r)); }
   g->sp[0] = r; }
  if (in) alloc(in, 0); }
 if (ok(g) && (!good || a.bad)) g->sp[0] = ZeroPoint;
 if (mids) alloc(mids, 0);
 if (f.ts) alloc(f.ts, 0);
 return bag_fin(&a), bag_fin(&e), g; }

static lvm(lvm_poly_keep) { LvmCallp(g, 1, host_poly_keep) }
static lvm(lvm_poly_carve) { LvmCallp(g, 1, host_poly_carve) }
static lvm(lvm_poly_grid) { LvmCallp(g, 1, host_poly_grid) }
static lvm(lvm_poly_seen) { LvmCall(g, host_poly_seen) }
static lvm(lvm_poly_fans) { LvmCallp(g, 4, host_poly_fans) }
LvDef("poly-keep", poly_keep, 2, NULL);
LvDef("poly-carve", poly_carve, 2, NULL);
LvDef("poly-grid", poly_grid, 2, NULL);
LvDef("poly-seen", poly_seen, 1, NULL);
LvDef("poly-fans", poly_fans, 5, NULL);
