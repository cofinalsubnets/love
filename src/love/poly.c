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

static lvm(lvm_poly_keep) { LvmCallp(g, 1, host_poly_keep) }
static lvm(lvm_poly_carve) { LvmCallp(g, 1, host_poly_carve) }
static lvm(lvm_poly_grid) { LvmCallp(g, 1, host_poly_grid) }
LvDef("poly-keep", poly_keep, 2, NULL);
LvDef("poly-carve", poly_carve, 2, NULL);
LvDef("poly-grid", poly_grid, 2, NULL);
