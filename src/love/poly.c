// poly -- convex polygons cut by planes, as lore's brushes cut their faces (brush.l)
// a polygon is a list of points going round, each [x y z]; a plane [n d] holds the points p
// with dot n p <= d. a corner that comes through uncut is the same word it came in as.
//  (poly-keep ps pls)  ps kept inside each plane in turn, till it is under three corners
//  (poly-carve ps pls) ps in pieces, each plane through it cutting every piece it crosses
//  (poly-grid ps cell) ps cut at every multiple of cell, x then y then z
//  (poly-beside ..)    each face's neighbours, for brush.l's sides
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

// --- a scene's corners, and the fans its pieces make ---
// a set of corners in a string: its slot count, then the slots, each a corner's three
// numbers, empty where the first is pl_gone. corners a millimetre apart are one; a corner
// hashes by its bucket, 256 mm a side, so a bucket's corners lie between its hash and an
// empty slot
#define pl_gone ((flo_t) 1e30)
struct seen { uint8_t *s; uint64_t cap; };
static int64_t pl_mm(flo_t x) { return (int64_t) pl_floor(x * (flo_t) 1000.0 + (flo_t) 0.5); }
static int64_t pl_bk(flo_t x) { int64_t const k = pl_mm(x); return k >= 0 ? k / 256 : -((255 - k) / 256); }
static uint64_t pl_hash(int64_t const k[3]) {
 uint64_t h = (uint64_t) k[0] * 0x9e3779b97f4a7c15u;
 h = (h ^ (h >> 31)) + (uint64_t) k[1] * 0xc2b2ae3d27d4eb4fu;
 h = (h ^ (h >> 29)) + (uint64_t) k[2] * 0x165667b19e3779f9u;
 return h ^ (h >> 32); }
static void pl_bks(flo_t const p[3], int64_t b[3]) { for (int j = 0; j < 3; j++) b[j] = pl_bk(p[j]); }
static void pl_get(struct seen const *t, uint64_t i, flo_t p[3]) { memcpy(p, t->s + 8 + 3 * sizeof(flo_t) * i, 3 * sizeof(flo_t)); }
static void pl_add(struct seen *t, flo_t const p[3]) {
 int64_t b[3];
 pl_bks(p, b);
 for (uint64_t i = pl_hash(b) & (t->cap - 1);; i = (i + 1) & (t->cap - 1)) {
  flo_t e[3];
  pl_get(t, i, e);
  if (e[0] == pl_gone) { memcpy(t->s + 8 + 3 * sizeof(flo_t) * i, p, 3 * sizeof(flo_t)); return; }
  if (pl_mm(e[0]) == pl_mm(p[0]) && pl_mm(e[1]) == pl_mm(p[1]) && pl_mm(e[2]) == pl_mm(p[2])) return; } }
static bool pl_far(flo_t const p[3]) { for (int j = 0; j < 3; j++) if (!(p[j] > (flo_t) -1e9 && p[j] < (flo_t) 1e9)) return 1; return 0; }

// (poly-seen pss): every corner of every polygon in pss, for poly-fans
love_noinline static struct g *host_poly_seen(struct g *g) {
 uint64_t n = 0, cap = 8;
 for (word l = g->sp[0]; chainp(l); l = B(l))
  for (word q = A(l); chainp(q); q = B(q)) {
   flo_t p[3];
   if (!pl_num3(A(q), p) || pl_far(p)) return g->sp[0] = ZeroPoint, g;
   n++; }
 while (cap < 2 * n) cap *= 2;   // never full, so a probe ends
 uintptr_t const bytes = (uintptr_t) (8 + 3 * sizeof(flo_t) * cap), sw = str_width(bytes);
 if (!ok(g = have(g, sw))) return g;
 struct str *s = ini_str(bump(g, sw), bytes);
 struct seen t = {(uint8_t*) txt(s), cap};
 flo_t const none[3] = {pl_gone, 0, 0};
 memcpy(t.s, &cap, 8);
 for (uint64_t i = 0; i < cap; i++) memcpy(t.s + 8 + 3 * sizeof(flo_t) * i, none, sizeof none);
 for (word l = g->sp[0]; chainp(l); l = B(l))
  for (word q = A(l); chainp(q); q = B(q)) {
   flo_t p[3];
   pl_num3(A(q), p), pl_add(&t, p); }
 g->sp[0] = word(s);
 return g; }

struct pt { flo_t t, p[3]; };
struct fan { flo_t n[3], U[4], V[4]; struct seen seen; struct pt *ts; uintptr_t cts; };
static flo_t pl_dot4(flo_t const a[4], flo_t const p[3]) { return a[0] * p[0] + a[1] * p[1] + a[2] * p[2] + a[3]; }
// q onto ts, in order along a b, where it lies on the edge and clear of its ends
static void pl_near(struct fan *f, struct pv const *a, flo_t const d[3], flo_t dd, flo_t len, flo_t const q[3], uintptr_t *nt, int *bad) {
 flo_t const w[3] = {q[0] - a->p[0], q[1] - a->p[1], q[2] - a->p[2]}, t = (w[0] * d[0] + w[1] * d[1] + w[2] * d[2]) / dd,
             r[3] = {w[0] - t * d[0], w[1] - t * d[1], w[2] - t * d[2]};
 if (!(t * len > (flo_t) 1e-4 && ((flo_t) 1.0 - t) * len > (flo_t) 1e-4) || r[0] * r[0] + r[1] * r[1] + r[2] * r[2] > (flo_t) 1e-10) return;
 f->ts = pl_grow(f->ts, *nt + 1, &f->cts, sizeof *f->ts, bad);
 if (*bad) return;
 uintptr_t j = (*nt)++;
 for (; j && f->ts[j - 1].t > t; j--) f->ts[j] = f->ts[j - 1];
 f->ts[j] = (struct pt){t, {q[0], q[1], q[2]}}; }
// the corners some piece has on edge a b, onto e in order along it, each where it is
static void pl_on(struct fan *f, struct pv const *a, struct pv const *b, struct bag *e) {
 flo_t const d[3] = {b->p[0] - a->p[0], b->p[1] - a->p[1], b->p[2] - a->p[2]}, dd = d[0] * d[0] + d[1] * d[1] + d[2] * d[2];
 if (dd < (flo_t) 1e-12) return;
 flo_t const len = pl_sqrt(dd);
 int64_t lo[3], hi[3];
 uint64_t boxes = 1;
 for (int k = 0; k < 3; k++) {
  flo_t const l = a->p[k] < b->p[k] ? a->p[k] : b->p[k], h = a->p[k] < b->p[k] ? b->p[k] : a->p[k];
  lo[k] = pl_bk(l - (flo_t) 1e-3), hi[k] = pl_bk(h + (flo_t) 1e-3), boxes *= (uint64_t) (hi[k] - lo[k] + 1); }
 uintptr_t nt = 0;
 int bad = 0;
 if (boxes > f->seen.cap)   // a long slant: every slot is fewer
  for (uint64_t i = 0; i < f->seen.cap && !bad; i++) {
   flo_t q[3];
   pl_get(&f->seen, i, q);
   if (q[0] != pl_gone) pl_near(f, a, d, dd, len, q, &nt, &bad); }
 else
  for (int64_t x = lo[0]; x <= hi[0]; x++) for (int64_t y = lo[1]; y <= hi[1]; y++) for (int64_t z = lo[2]; z <= hi[2] && !bad; z++) {
   int64_t const k[3] = {x, y, z};
   for (uint64_t i = pl_hash(k) & (f->seen.cap - 1);; i = (i + 1) & (f->seen.cap - 1)) {
    flo_t q[3];
    int64_t c[3];
    pl_get(&f->seen, i, q);
    if (q[0] == pl_gone) break;
    pl_bks(q, c);
    if (c[0] == x && c[1] == y && c[2] == z) pl_near(f, a, d, dd, len, q, &nt, &bad); } }
 if (bad) { e->bad = 1; return; }
 for (uintptr_t i = 0, kept = 0; i < nt; i++) {
  bool near = 0;
  for (uintptr_t j = 0; j < kept; j++) near |= (f->ts[j].t - f->ts[i].t < 0 ? f->ts[i].t - f->ts[j].t : f->ts[j].t - f->ts[i].t) * len < (flo_t) 1e-4;
  if (near) continue;
  f->ts[kept++] = f->ts[i];
  struct pv x = {{f->ts[i].p[0], f->ts[i].p[1], f->ts[i].p[2]}, -1};
  bag_put(e, &x); } }
// a piece with corners taken on its edges
static void pl_edged(struct fan *f, struct pv const *ps, uintptr_t n, struct bag *e) {
 for (uintptr_t i = 0; i < n; i++) bag_put(e, ps + i), pl_on(f, ps + i, ps + (i + 1) % n, e);
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

// (poly-fans pss n look seen): each piece of a face facing n, its edges taking on the seen
// corners that lie on them, as [mid [verts tris]] for
// poly-weave: fanned from its first corner, or from mid when its edges took corners on,
// turned to face n; look [tex U V], a corner's texels U and V dotted with [x y z 1]
love_noinline static struct g *host_poly_fans(struct g *g) {
 struct fan f = {0};
 struct bag a, e;
 bag_ini(&a), bag_ini(&e);
 word const lk = g->sp[2], sn = g->sp[3];
 uintptr_t nm = 0, cm = 0, words = 0;
 flo_t *mids = NULL;
 bool good = pl_num3(g->sp[1], f.n) && chainp(lk) && charmp(A(lk)) && chainp(B(lk)) && chainp(B(B(lk))) && strp(sn) && len(str(sn)) >= 8;
 for (int s = 0; good && s < 2; s++) {
  word q = A(s ? B(B(lk)) : B(lk));
  flo_t *r = s ? f.V : f.U;
  for (int k = 0; k < 4; k++, q = B(q)) good = good && chainp(q) && isnum(A(q)) && ((r[k] = toflo(A(q))), 1); }
 if (good) {
  f.seen.s = (uint8_t*) txt(str(sn)), memcpy(&f.seen.cap, f.seen.s, 8);
  good = f.seen.cap && !(f.seen.cap & (f.seen.cap - 1)) && f.seen.cap <= len(str(sn)) / (3 * sizeof(flo_t))
         && 8 + 3 * sizeof(flo_t) * f.seen.cap <= len(str(sn)); }
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
  words += 5 * chain_req + 3 * (chain_req + gem_req)   // the list's, [mid part], mid, [verts tris]
         + b2w(tray_bytes(love_R, 1, 11 * nv)) + b2w(tray_bytes(love_Z, 1, 4 * nt)); }
 good = good && !a.bad && !e.bad;
 if (good && ok(g = have(g, words))) {
  word r = ZeroPoint;
  intptr_t const tex = getcharm(A(g->sp[2]));
  for (uintptr_t i = nm; i--; ) {
   struct pv const *ps = bag_piece(&e, i);
   uintptr_t const ne = bag_n(&e, i), n0 = bag_n(&a, i), fan = ne != n0, nv = ne + fan, nt = fan ? ne : n0 - 2;
   flo_t const *m = mids + 3 * i;
   uintptr_t const vw = b2w(tray_bytes(love_R, 1, 11 * nv)), tw = b2w(tray_bytes(love_Z, 1, 4 * nt));
   struct tray *vt = ini_tray(bump(g, vw), love_R, 1), *tt = ini_tray(bump(g, tw), love_Z, 1);
   vt->shape[0] = 11 * nv, tt->shape[0] = 4 * nt;
   flo_t *v = tray_data(vt);
   intptr_t *t = tray_data(tt);
   if (fan)   // from the middle, round
    for (uintptr_t j = 0; j < ne; j++) {
     uintptr_t const b = (j + 1) % ne;
     bool const u = pl_turns(f.n, m, ps[b].p, ps[j].p);
     t[4 * j] = (intptr_t) ne, t[4 * j + 1] = (intptr_t) (u ? j : b), t[4 * j + 2] = (intptr_t) (u ? b : j), t[4 * j + 3] = tex; }
   else
    for (uintptr_t j = 0; j < nt; j++) {
     bool const u = pl_turns(f.n, ps[0].p, ps[j + 2].p, ps[j + 1].p);
     t[4 * j] = 0, t[4 * j + 1] = (intptr_t) (u ? j + 1 : j + 2), t[4 * j + 2] = (intptr_t) (u ? j + 2 : j + 1), t[4 * j + 3] = tex; }
   for (uintptr_t j = 0; j < nv; j++, v += 11) {
    flo_t const *p = j < ne ? ps[j].p : m;
    v[0] = p[0], v[1] = p[1], v[2] = p[2], v[3] = pl_dot4(f.U, p), v[4] = pl_dot4(f.V, p);
    v[5] = f.n[0], v[6] = f.n[1], v[7] = f.n[2], v[8] = v[9] = v[10] = (flo_t) 1.0; }
   word const mw[3] = {pl_gem(g, m[0]), pl_gem(g, m[1]), pl_gem(g, m[2])}, part[2] = {word(vt), word(tt)},
              it[2] = {pl_list(g, mw, 3), pl_list(g, part, 2)};
   r = word(ini_chain(bump(g, chain_req), (intptr_t) pl_list(g, it, 2), (intptr_t) r)); }
  g->sp[0] = r; }
 if (ok(g) && (!good || a.bad)) g->sp[0] = ZeroPoint;
 if (mids) alloc(mids, 0);
 if (f.ts) alloc(f.ts, 0);
 return bag_fin(&a), bag_fin(&e), g; }

// (poly-weave parts): parts each [verts tris], verts 11 numbers a vertex and tris 4 a
// triangle, its indices the part's own, joined as [n cols tris]: the vertex count, a tray a
// column, and the triangles' indices moved past the parts before
love_noinline static struct g *host_poly_weave(struct g *g) {
 uintptr_t nv = 0, nt = 0;
 for (word l = g->sp[0]; chainp(l); l = B(l)) {
  word const q = A(l);
  if (!chainp(q) || !chainp(B(q)) || !galaxyp(A(q)) || !galaxyp(A(B(q)))) return g->sp[0] = ZeroPoint, g;
  uintptr_t const a = tray_nelem(tray(A(q))), b = tray_nelem(tray(A(B(q))));
  if (a % 11 || b % 4) return g->sp[0] = ZeroPoint, g;
  nv += a / 11, nt += b; }
 uintptr_t const cw = b2w(tray_bytes(love_R, 1, nv)), tw = b2w(tray_bytes(love_Z, 1, nt));
 if (!ok(g = have(g, 11 * cw + tw + 14 * chain_req))) return g;
 struct tray *c[11], *t = ini_tray(bump(g, tw), love_Z, 1);
 word cs[11];
 for (int k = 0; k < 11; k++) c[k] = ini_tray(bump(g, cw), love_R, 1), c[k]->shape[0] = nv, cs[k] = word(c[k]);
 t->shape[0] = nt;
 intptr_t *td = tray_data(t);
 uintptr_t at = 0, i = 0;
 for (word l = g->sp[0]; chainp(l); l = B(l)) {
  struct tray *pv = tray(A(A(l))), *pt = tray(A(B(A(l))));
  uintptr_t const n = tray_nelem(pv) / 11, m = tray_nelem(pt);
  for (uintptr_t j = 0; j < n; j++)
   for (int k = 0; k < 11; k++) ((flo_t*) tray_data(c[k]))[at + j] = tray_get_flo(pv, 11 * j + (uintptr_t) k);
  for (uintptr_t j = 0; j < m; j++) td[i + j] = tray_get_int(pt, j) + (j % 4 < 3 ? (intptr_t) at : 0);
  at += n, i += m; }
 word const r[3] = {putcharm(nv), pl_list(g, cs, 11), word(t)};
 g->sp[0] = pl_list(g, r, 3);
 return g; }

// --- the faces beside each face: those of the brushes near its brush, whose boxes meet its own ---
// a column of n numbers: a tray of them
static bool pl_col(word w, uintptr_t n) { return galaxyp(w) && tray_nelem(tray(w)) == n; }
static bool pl_cols3(word l, uintptr_t n) {
 for (int k = 0; k < 3; k++, l = B(l)) if (!chainp(l) || !pl_col(A(l), n)) return 0;
 return 1; }
static void pl_get3(word l, uintptr_t n, flo_t *o) {   // three columns into rows of three
 for (int k = 0; k < 3; k++, l = B(l))
  for (uintptr_t i = 0; i < n; i++) o[3 * i + (uintptr_t) k] = tray_get_flo(tray(A(l)), i); }

// (poly-beside fl fh fb ci bl bh): faces' boxes fl fh, each three trays, their brushes fb and
// numbers ci; the brushes' boxes bl bh. answers each face's list of the numbers of the faces
// of brushes within 0.02 of its brush's box, brush by brush and face by face in order, whose
// boxes come within 1e-3 of its own
struct side { flo_t *f, *b; intptr_t *br, *id, *by, *at, *sp, *r; uintptr_t nf, nb, nr, cr; int bad; };
static void sd_fin(struct side *s) {
 flo_t *fs[2] = {s->f, s->b};
 intptr_t *is[6] = {s->br, s->id, s->by, s->at, s->sp, s->r};
 for (int k = 0; k < 2; k++) if (fs[k]) alloc(fs[k], 0);
 for (int k = 0; k < 6; k++) if (is[k]) alloc(is[k], 0); }
static void *sd_new(uintptr_t n, uintptr_t w, int *bad) { uintptr_t c = 0; return pl_grow(NULL, n + 1, &c, w, bad); }
// the faces brush by brush, each brush's in order: by[at[c]] to by[at[c + 1]]
static void sd_group(struct side *s) {
 for (uintptr_t c = 0; c <= s->nb; c++) s->at[c] = 0;
 for (uintptr_t i = 0; i < s->nf; i++) s->at[s->br[i] + 1]++;
 for (uintptr_t c = 0; c < s->nb; c++) s->at[c + 1] += s->at[c];
 for (uintptr_t i = 0; i < s->nf; i++) s->by[s->at[s->br[i]]++] = (intptr_t) i;
 for (uintptr_t c = s->nb; c; c--) s->at[c] = s->at[c - 1];
 s->at[0] = 0; }
static bool sd_meet(flo_t const *lo, flo_t const *hi, uintptr_t i, uintptr_t j, flo_t e) {
 for (int k = 0; k < 3; k++) if (!(hi[3 * j + k] >= lo[3 * i + k] - e && lo[3 * j + k] - e <= hi[3 * i + k])) return 0;
 return 1; }
static void sd_run(struct side *s) {
 flo_t const *fl = s->f, *fh = s->f + 3 * s->nf, *bl = s->b, *bh = s->b + 3 * s->nb;
 for (uintptr_t i = 0; i < s->nf && !s->bad; i++) {
  uintptr_t const c0 = (uintptr_t) s->br[i];
  s->sp[2 * i] = (intptr_t) s->nr;
  for (uintptr_t c = 0; c < s->nb && !s->bad; c++) {
   if (!sd_meet(bl, bh, c0, c, (flo_t) 0.02)) continue;
   for (intptr_t q = s->at[c]; q < s->at[c + 1] && !s->bad; q++) {
    uintptr_t const j = (uintptr_t) s->by[q];
    if (!sd_meet(fl, fh, i, j, (flo_t) 1e-3)) continue;
    s->r = pl_grow(s->r, s->nr + 1, &s->cr, sizeof *s->r, &s->bad);
    if (!s->bad) s->r[s->nr++] = s->id[j]; } }
  s->sp[2 * i + 1] = (intptr_t) s->nr - s->sp[2 * i]; } }
love_noinline static struct g *host_poly_beside(struct g *g) {
 word const fb = g->sp[2], ci = g->sp[3], bl = g->sp[4];
 struct side s = {0};
 s.nf = galaxyp(fb) ? tray_nelem(tray(fb)) : 0, s.nb = chainp(bl) && galaxyp(A(bl)) ? tray_nelem(tray(A(bl))) : 0;
 if (!pl_cols3(g->sp[0], s.nf) || !pl_cols3(g->sp[1], s.nf) || !pl_col(ci, s.nf) || !pl_cols3(bl, s.nb) || !pl_cols3(g->sp[5], s.nb))
  return g->sp[0] = ZeroPoint, g;
 s.f = sd_new(6 * s.nf, sizeof *s.f, &s.bad), s.b = sd_new(6 * s.nb, sizeof *s.b, &s.bad);
 s.br = sd_new(s.nf, sizeof *s.br, &s.bad), s.id = sd_new(s.nf, sizeof *s.id, &s.bad), s.by = sd_new(s.nf, sizeof *s.by, &s.bad);
 s.at = sd_new(s.nb + 1, sizeof *s.at, &s.bad), s.sp = sd_new(2 * s.nf, sizeof *s.sp, &s.bad);
 if (!s.bad) {
  pl_get3(g->sp[0], s.nf, s.f), pl_get3(g->sp[1], s.nf, s.f + 3 * s.nf), pl_get3(bl, s.nb, s.b), pl_get3(g->sp[5], s.nb, s.b + 3 * s.nb);
  for (uintptr_t i = 0; i < s.nf; i++) {
   s.br[i] = tray_get_int(tray(fb), i), s.id[i] = tray_get_int(tray(ci), i);
   s.bad |= s.br[i] < 0 || (uintptr_t) s.br[i] >= s.nb; } }
 if (!s.bad) sd_group(&s), sd_run(&s);
 if (!s.bad && ok(g = have(g, (s.nf + s.nr) * chain_req))) {
  word l = ZeroPoint;
  for (uintptr_t i = s.nf; i--; ) {
   word m = ZeroPoint;
   for (intptr_t q = s.sp[2 * i] + s.sp[2 * i + 1]; q-- > s.sp[2 * i]; ) m = word(ini_chain(bump(g, chain_req), (intptr_t) putcharm(s.r[q]), (intptr_t) m));
   l = word(ini_chain(bump(g, chain_req), (intptr_t) m, (intptr_t) l)); }
  g->sp[0] = l; }
 else if (ok(g)) g->sp[0] = ZeroPoint;
 return sd_fin(&s), g; }

static lvm(lvm_poly_keep) { LvmCallp(g, 1, host_poly_keep) }
static lvm(lvm_poly_carve) { LvmCallp(g, 1, host_poly_carve) }
static lvm(lvm_poly_grid) { LvmCallp(g, 1, host_poly_grid) }
static lvm(lvm_poly_seen) { LvmCall(g, host_poly_seen) }
static lvm(lvm_poly_fans) { LvmCallp(g, 3, host_poly_fans) }
static lvm(lvm_poly_weave) { LvmCall(g, host_poly_weave) }
static lvm(lvm_poly_beside) { LvmCallp(g, 5, host_poly_beside) }
LvDef("poly-keep", poly_keep, 2, "lore");
LvDef("poly-carve", poly_carve, 2, "lore");
LvDef("poly-grid", poly_grid, 2, "lore");
LvDef("poly-seen", poly_seen, 1, "lore");
LvDef("poly-fans", poly_fans, 4, "lore");
LvDef("poly-weave", poly_weave, 1, "lore");
LvDef("poly-beside", poly_beside, 6, "lore");
