// lamp -- lore's lamps on a packed mesh's vertices (mesh.l's mesh-lamp), shared over the pool
// (lamp-light cols lamps): cols a packed mesh's columns, [x y z u v nx ny nz r g b] trays;
// lamps each [pts r c n s2 wrap box]: its points, reach, [r g b], () or the way it faces, its
// softness squared, its wrap, and () or the box it keeps to, [x0 z0 x1 z1] in plan or
// [x0 z0 x1 z1 y0 y1] between two heights too. answers the
// light they throw on each vertex as [r g b] trays, summed lamp by lamp in order, a lamp
// whose reach misses the mesh's box adding nothing, and the numbers [0.0 0.0 0.0] where none
// reaches it. (lamp-lights cols base lights): base [r g b], each a tray or a number, and to
// it each light's lamp-light in turn. () where an argument is not as it says
// (lamp-open X Y Z db): the daylight walk of world.l's daylit on the points X Y Z, db its
// brushes end to end, each [kind n lo hi ..n numbers], kind 1 air, 2 open, 4 land, 8 walked,
// the numbers its planes [nx ny nz d] or its land (dy_land). answers [o u past] trays.
// (lamp-near db lo hi): the brushes of db lamp-open asks about points in the box lo hi.
// (lamp-varies ps lift step gap db): 1 where the light the open lets in on face ps, its
// corners end to end, changes by more than step, else 0. () where an argument is not as it says
#include "love.h"
#if Bits == 64
double lm_sqrt(double);
#define lp_sqrt lm_sqrt
#else
float lm_sqrtf(float);
#define lp_sqrt lm_sqrtf
#endif

enum { lp_chunk = 1024 };   // vertices a share
struct lamp { flo_t const *ps; uintptr_t np; flo_t r, c[3], n[3], s2, wr, box[6]; bool fn, keep, keepy; };
// light j's lamps l[at[j]] to l[at[j + 1]]; the base a tray a colour, or where none bv
struct lit { flo_t const *col[6], *base[3]; flo_t *out[3], bv[3]; struct lamp const *l; uintptr_t const *at; uintptr_t nlt, nv; };

static bool lp_num(word x, flo_t *o) { return isnum(x) && ((*o = toflo(x)), 1); }
static bool lp_nums(word l, flo_t *o, int n) {
 for (int k = 0; k < n; k++, l = B(l)) if (!chainp(l) || !lp_num(A(l), o + k)) return 0;
 return 1; }
static flo_t lp_sat(flo_t v) { v = (flo_t) 0.0 < v ? v : (flo_t) 0.0; return (flo_t) 1.0 < v ? (flo_t) 1.0 : v; }

// the arithmetic as mesh.l's, step for step
static void lp_share(void *c, intptr_t s) {
 struct lit const *t = c;
 uintptr_t const i0 = (uintptr_t) s * lp_chunk, i1 = i0 + lp_chunk < t->nv ? i0 + lp_chunk : t->nv;
 for (uintptr_t i = i0; i < i1; i++) {
  flo_t const X = t->col[0][i], Y = t->col[1][i], Z = t->col[2][i], nx = t->col[3][i], ny = t->col[4][i], nz = t->col[5][i];
  flo_t o[3];
  for (int m = 0; m < 3; m++) o[m] = t->base[m] ? t->base[m][i] : t->bv[m];
  for (uintptr_t lt = 0; lt < t->nlt; lt++) {
   flo_t a[3] = {(flo_t) 0.0, (flo_t) 0.0, (flo_t) 0.0};
   for (uintptr_t j = t->at[lt]; j < t->at[lt + 1]; j++) {
    struct lamp const *l = t->l + j;
    flo_t k = X * (flo_t) 0.0;
    for (uintptr_t q = 0; q < l->np; q++) {
     flo_t const *p = l->ps + 3 * q,
                 lx = p[0] - X, ly = p[1] - Y, lz = p[2] - Z, d2 = lx * lx + ly * ly + lz * lz,
                 d = lp_sqrt(d2 + (flo_t) 1e-9),
                 lam = lp_sat(((nx * lx + ny * ly + nz * lz) / d + l->wr) / ((flo_t) 1.0 + l->wr)),
                 em = l->fn ? lp_sat((flo_t) 0.25 - (l->n[0] * lx + l->n[1] * ly + l->n[2] * lz) / d) : (flo_t) 1.0,
                 f = lp_sat((flo_t) 1.0 - (d2 / (l->r * l->r)) * (d2 / (l->r * l->r)));
     k = k + lam * em * (f * f) / (d2 + l->s2); }
    k = k / (flo_t) l->np;
    if (l->keep) k = k * (flo_t) ((l->box[0] < X) * (X < l->box[2]) * (l->box[1] < Z) * (Z < l->box[3])
                                  * (!l->keepy || (l->box[4] < Y && Y < l->box[5])));
    for (int m = 0; m < 3; m++) a[m] = a[m] + k * l->c[m]; }
   for (int m = 0; m < 3; m++) o[m] = o[m] + a[m]; }
  for (int m = 0; m < 3; m++) t->out[m][i] = o[m]; } }

// a lamp row read, and whether any of its points comes within its reach of the box lo hi
static bool lp_read(word w, struct lamp *l, flo_t *pts, uintptr_t *np) {
 word const ps = A(w), r = A(B(w)), c = A(B(B(w))), n = A(B(B(B(w)))), s2 = A(B(B(B(B(w))))), wr = A(B(B(B(B(B(w)))))),
            bx = A(B(B(B(B(B(B(w)))))));
 l->ps = pts, l->np = 0;
 for (word q = ps; chainp(q); q = B(q), l->np++) if (!lp_nums(A(q), pts + 3 * l->np, 3)) return 0;
 *np = l->np;
 l->fn = chainp(n), l->keep = chainp(bx), l->keepy = l->keep && llen(bx) == 6;
 return l->np && lp_num(r, &l->r) && lp_nums(c, l->c, 3) && (!l->fn || lp_nums(n, l->n, 3)) && lp_num(s2, &l->s2) && lp_num(wr, &l->wr)
        && (!l->keep || lp_nums(bx, l->box, l->keepy ? 6 : 4)); }
static bool lp_row(word w) {
 int k = 0;
 for (; chainp(w) && k < 7; w = B(w)) k++;
 return k == 7; }
static bool lp_reaches(struct lamp const *l, flo_t const lo[3], flo_t const hi[3]) {
 for (uintptr_t q = 0; q < l->np; q++) {
  flo_t const *p = l->ps + 3 * q, a[3] = {lo[0] - p[0], lo[1] - p[1], lo[2] - p[2]}, b[3] = {p[0] - hi[0], p[1] - hi[1], p[2] - hi[2]};
  flo_t s = 0;
  for (int k = 0; k < 3; k++) {
   flo_t const m = a[k] < b[k] ? b[k] : a[k], e = (flo_t) 0.0 < m ? m : (flo_t) 0.0;
   s = k ? s + e * e : e * e; }
  if (s < l->r * l->r) return 1; }
 return 0; }

// the mesh's columns into t, and its box
static void lp_cols(word cl, struct lit *t, flo_t lo[3], flo_t hi[3]) {
 static int const want[6] = {0, 1, 2, 5, 6, 7};
 for (int k = 0, j = 0; k < 11; k++, cl = B(cl)) if (j < 6 && k == want[j]) t->col[j++] = tray_data(tray(A(cl)));
 for (int k = 0; k < 3; k++) lo[k] = hi[k] = t->nv ? t->col[k][0] : 0;
 for (uintptr_t i = 0; i < t->nv; i++)
  for (int k = 0; k < 3; k++) {
   flo_t const x = t->col[k][i];
   lo[k] = x < lo[k] ? x : lo[k], hi[k] = hi[k] < x ? x : hi[k]; } }
// the lamps of each light in ls (ls one light's, where one) that reach the box into t, their
// points into pts, at its lights' starts; 0 where one is not as it says
static bool lp_lamps(word ls, bool one, struct lit *t, struct lamp *l, uintptr_t *at, flo_t *pts, flo_t const lo[3], flo_t const hi[3]) {
 uintptr_t used = 0, n = 0, nlt = 0;
 t->l = l, t->at = at;
 for (; one ? !nlt : chainp(ls); ls = one ? ls : B(ls), nlt++) {
  at[nlt] = n;
  for (word q = one ? ls : A(ls); chainp(q); q = B(q)) {
   uintptr_t np = 0;
   if (!lp_read(A(q), l + n, pts + 3 * used, &np)) return 0;
   if (lp_reaches(l + n, lo, hi)) n++, used += np; } }
 at[nlt] = n, t->nlt = nlt;
 return 1; }

// cols, then lights as lists of lamps (one, held, for lamp-light); base numbers or trays
static struct g *lp_light(struct g *g, word cl, uintptr_t ib, uintptr_t il, bool one) {
 uintptr_t nv = 0, nl = 0, npt = 0, nlt = 0;
 word c = cl;
 for (int k = 0; k < 11; k++, c = B(c)) {
  if (!chainp(c) || !galaxyp(A(c)) || tray(A(c))->type != love_R) return g->sp[0] = ZeroPoint, g;
  uintptr_t const m = tray_nelem(tray(A(c)));
  if (k && m != nv) return g->sp[0] = ZeroPoint, g;
  nv = m; }
 word b = ib ? g->sp[ib] : ZeroPoint;
 for (int m = 0; ib && m < 3; m++, b = B(b))
  if (!chainp(b) || !(isnum(A(b)) || (galaxyp(A(b)) && tray(A(b))->type == love_R && tray_nelem(tray(A(b))) == nv))) return g->sp[0] = ZeroPoint, g;
 for (word ls = g->sp[il]; one ? !nlt : chainp(ls); ls = one ? ls : B(ls), nlt++)
  for (word q = one ? ls : A(ls); chainp(q); q = B(q), nl++) {
   if (!lp_row(A(q))) return g->sp[0] = ZeroPoint, g;
   npt += llen(A(A(q))); }
 struct lamp *ls = alloc(NULL, (nl + 1) * sizeof *ls);
 uintptr_t *at = alloc(NULL, (nlt + 1) * sizeof *at);
 flo_t *pts = alloc(NULL, (3 * npt + 1) * sizeof *pts);
 struct lit t = {.nv = nv};
 flo_t lo[3], hi[3];
 bool good = ls && at && pts;
 if (good) lp_cols(g->sp[0], &t, lo, hi), good = lp_lamps(g->sp[il], one, &t, ls, at, pts, lo, hi);
 bool const bare = one && t.at && t.l && good && !t.at[t.nlt];   // none reaching: the numbers, a sum of none
 uintptr_t const w = b2w(tray_bytes(love_R, 1, nv)), ask = bare ? 3 * (gem_req + chain_req) : 3 * w + 3 * chain_req;
 if (good && ok(g = have(g, ask))) {
  word r[3];
  if (!bare) {
   lp_cols(g->sp[0], &t, lo, hi);   // re-read: the ask may have moved them
   lp_lamps(g->sp[il], one, &t, ls, at, pts, lo, hi);
   word bb = ib ? g->sp[ib] : ZeroPoint;
   for (int m = 0; m < 3; m++) {
    word const x = ib ? A(bb) : ZeroPoint;
    t.base[m] = ib && galaxyp(x) ? tray_data(tray(x)) : NULL, t.bv[m] = ib && isnum(x) ? toflo(x) : (flo_t) 0.0;
    if (ib) bb = B(bb); }
   struct tray *o[3];
   for (int m = 0; m < 3; m++) o[m] = ini_tray(bump(g, w), love_R, 1), o[m]->shape[0] = nv, t.out[m] = tray_data(o[m]), r[m] = word(o[m]);
   par_run(g, (intptr_t) ((nv + lp_chunk - 1) / lp_chunk), lp_share, &t); }
  else for (int m = 0; m < 3; m++) r[m] = mk_gem(&g->hp, (flo_t) 0.0);
  word l = ZeroPoint;
  for (int m = 3; m--; ) l = word(ini_chain(bump(g, chain_req), (intptr_t) r[m], (intptr_t) l));
  g->sp[0] = l; }
 else if (ok(g)) g->sp[0] = ZeroPoint;
 if (ls) alloc(ls, 0);
 if (at) alloc(at, 0);
 if (pts) alloc(pts, 0);
 return g; }
love_noinline static struct g *host_lamp_light(struct g *g) { return lp_light(g, g->sp[0], 0, 1, 1); }
love_noinline static struct g *host_lamp_lights(struct g *g) { return lp_light(g, g->sp[0], 1, 2, 0); }
// a brush of the db: its kind, box, and its n numbers, planes or a land; v0 the first walked
struct dbr { flo_t const *lo, *hi, *pl; uintptr_t n, np, nt; int kind; bool any; };
struct day { flo_t const *x[3]; flo_t *out[3]; struct dbr const *b; uintptr_t nb, v0, nv; bool tall; };
static flo_t dy_floor(flo_t x) { flo_t t = love_trunc(x); return t > x ? t - 1 : t; }
// a land's numbers: low, cell width g, its first cell x0 z0, nx by nz cells, each cell's start
// among the triangles' numbers, those, then the triangles, nine numbers each
static bool dy_land(struct dbr *b) {
 flo_t const *v = b->pl;
 if (b->n < 7 || v[4] < 0 || v[5] < 0 || !(v[1] > 0)) return 0;
 uintptr_t const nc = (uintptr_t) v[4] * (uintptr_t) v[5];
 if (6 + nc + 1 > b->n || v[6 + nc] < 0 || 6 + nc + 1 + (uintptr_t) v[6 + nc] > b->n) return 0;
 uintptr_t const at = 6 + nc + 1 + (uintptr_t) v[6 + nc];
 return (b->n - at) % 9 == 0 && ((b->nt = (b->n - at) / 9), 1); }
// the land's height at x z, as brush.l's land-at: the first of its cell's triangles holding it
static bool dy_land_y(struct dbr const *b, flo_t x, flo_t z, flo_t *h) {
 flo_t const *v = b->pl, g = v[1];
 intptr_t const nx = (intptr_t) v[4], nz = (intptr_t) v[5], i = (intptr_t) dy_floor(x / g) - (intptr_t) v[2], j = (intptr_t) dy_floor(z / g) - (intptr_t) v[3];
 if (i < 0 || j < 0 || i >= nx || j >= nz) return 0;
 flo_t const *of = v + 6, *ix = of + nx * nz + 1, *ts = ix + (uintptr_t) of[nx * nz];
 uintptr_t const c = (uintptr_t) (i * nz + j), q0 = (uintptr_t) of[c], q1 = (uintptr_t) of[c + 1];
 for (uintptr_t q = q0; q < q1 && q1 <= (uintptr_t) of[nx * nz]; q++) {
  uintptr_t const k = (uintptr_t) ix[q];
  if (k >= b->nt) continue;
  flo_t const *a = ts + 9 * k, *bb = a + 3, *cc = a + 6,
              d = (bb[2] - cc[2]) * (a[0] - cc[0]) + (cc[0] - bb[0]) * (a[2] - cc[2]);
  if ((d < 0 ? -d : d) < (flo_t) 1e-12) continue;
  flo_t const u = ((bb[2] - cc[2]) * (x - cc[0]) + (cc[0] - bb[0]) * (z - cc[2])) / d,
              w = ((cc[2] - a[2]) * (x - cc[0]) + (a[0] - cc[0]) * (z - cc[2])) / d, r = (flo_t) 1.0 - u - w;
  if (u >= (flo_t) -1e-9 && w >= (flo_t) -1e-9 && r >= (flo_t) -1e-9) return *h = u * a[1] + w * bb[1] + r * cc[1], 1; }
 return 0; }
static bool dy_box(struct dbr const *b, flo_t const p[3], flo_t e, flo_t top) {
 for (int k = 0; k < 3; k++) if (!(b->lo[k] - e < p[k] && p[k] < b->hi[k] + e + (k == 1 ? top : (flo_t) 0.0))) return 0;
 return 1; }
static bool dy_bbox(struct dbr const *b, flo_t const p[3]) {
 flo_t const e = (flo_t) 1e-6;
 for (int k = 0; k < 3; k++) if (!(b->lo[k] - e <= p[k] && p[k] <= b->hi[k] + e)) return 0;
 return 1; }
static bool dy_planes(struct dbr const *b, flo_t const p[3]) {
 for (uintptr_t q = 0; q < b->np; q++) {
  flo_t const *n = b->pl + 4 * q;
  if (!(p[0] * n[0] + p[1] * n[1] + p[2] * n[2] <= n[3] + (flo_t) 1e-6)) return 0; }
 return 1; }
// open air puts a point out, a solid buries it, a room carved where it is buried brings it in,
// but one standing up out of the land is open, as it was before the land
static void dy_point(struct day const *t, flo_t const p[3], flo_t w[3]) {
 flo_t o = 0, u = 0, past = 1, G = (flo_t) -1e9, h;
 for (uintptr_t j = t->v0; t->tall && j < t->nb; j++)
  if (t->b[j].kind & 4 && dy_land_y(t->b + j, p[0], p[2], &h)) G = G < h ? h : G;
 for (uintptr_t j = 0; j < t->nb; j++) {
  struct dbr const *b = t->b + j;
  if (!(b->kind & 4) && dy_box(b, p, 0, (flo_t) 0.1)) past = 0;
  if (j < t->v0) continue;
  if (b->kind & 2) { if (dy_box(b, p, (flo_t) 0.001, (flo_t) 0.1)) o = 1, u = 0; }
  else if (b->kind & 4 ? p[1] <= b->pl[0] || (dy_land_y(b, p[0], p[2], &h) && p[1] <= h) : b->any && dy_planes(b, p)) {
   if (b->kind & 1) o = u && !(t->tall && b->hi[1] > G) ? 0 : o, u = 0;
   else u = 1; } }
 w[0] = o, w[1] = u, w[2] = past; }
static void dy_share(void *c, intptr_t s) {
 struct day const *t = c;
 uintptr_t const i0 = (uintptr_t) s * lp_chunk, i1 = i0 + lp_chunk < t->nv ? i0 + lp_chunk : t->nv;
 for (uintptr_t i = i0; i < i1; i++) {
  flo_t const p[3] = {t->x[0][i], t->x[1][i], t->x[2][i]};
  flo_t w[3];
  dy_point(t, p, w);
  for (int m = 0; m < 3; m++) t->out[m][i] = w[m]; } }
// the next brush of db v from at, 0 where it is not as it says
static bool dy_next(flo_t const *v, uintptr_t n, uintptr_t *at, struct dbr *b) {
 if (*at + 8 > n || v[*at + 1] < 0) return 0;
 *b = (struct dbr) {.kind = (int) v[*at], .n = (uintptr_t) v[*at + 1], .lo = v + *at + 2, .hi = v + *at + 5, .pl = v + *at + 8};
 if (*at + 8 + b->n > n || (b->kind & 4 ? !dy_land(b) : b->n % 4)) return 0;
 b->np = b->kind & 4 ? 0 : b->n / 4, *at += 8 + b->n;
 return 1; }
static bool dy_meets(struct dbr const *b, flo_t const lo[3], flo_t const hi[3]) {
 bool meet = 1;
 for (int k = 0; k < 3; k++) meet = meet && b->hi[k] >= lo[k] - (flo_t) 0.2 - (flo_t) 1e-3 && b->lo[k] - (flo_t) 1e-3 <= hi[k] + (flo_t) 0.2;
 return meet; }
// the brushes meeting the points' box, in order, each with whether any point is in its own
// box; walked from the first open one, or the first marked walked (8)
static bool dy_read(word db, struct day *t, struct dbr *bs, uintptr_t nmax) {
 struct tray *d = tray(db);
 flo_t const *v = tray_data(d);
 uintptr_t const n = tray_nelem(d);
 flo_t lo[3], hi[3];
 for (int k = 0; k < 3; k++) lo[k] = hi[k] = t->nv ? t->x[k][0] : 0;
 for (uintptr_t i = 0; i < t->nv; i++)
  for (int k = 0; k < 3; k++) {
   flo_t const x = t->x[k][i];
   lo[k] = x < lo[k] ? x : lo[k], hi[k] = hi[k] < x ? x : hi[k]; }
 t->b = bs, t->nb = 0, t->v0 = (uintptr_t) -1, t->tall = 0;
 for (uintptr_t at = 0, j = 0; at < n; j++) {
  struct dbr b;
  if (j >= nmax || !dy_next(v, n, &at, &b)) return 0;
  if (b.kind & 10 && t->v0 == (uintptr_t) -1) t->v0 = t->nb;
  if (!dy_meets(&b, lo, hi)) continue;
  for (uintptr_t i = 0; i < t->nv && !b.any && !(b.kind & 4); i++) {
   flo_t const p[3] = {t->x[0][i], t->x[1][i], t->x[2][i]};
   b.any = dy_bbox(&b, p); }
  bs[t->nb++] = b; }
 if (t->v0 == (uintptr_t) -1) t->v0 = t->nb;
 // ..a room standing up out of a land walked with it
 for (uintptr_t j = t->v0; j < t->nb; j++)
  for (uintptr_t l = t->v0; l < t->nb && !t->tall; l++)
   t->tall = (bs[j].kind & 5) == 1 && bs[l].kind & 4 && bs[j].hi[1] > bs[l].pl[0];
 return 1; }
static bool dy_db(word x) { return galaxyp(x) && tray(x)->type == love_R; }
love_noinline static struct g *host_lamp_open(struct g *g) {
 uintptr_t nv = 0;
 for (int k = 0; k < 4; k++) {
  word const x = g->sp[k];
  if (!dy_db(x)) return g->sp[0] = ZeroPoint, g;
  if (k < 3 && k && tray_nelem(tray(x)) != nv) return g->sp[0] = ZeroPoint, g;
  if (!k) nv = tray_nelem(tray(x)); }
 uintptr_t const nmax = tray_nelem(tray(g->sp[3])) / 8 + 1, w = b2w(tray_bytes(love_R, 1, nv));
 struct dbr *bs = alloc(NULL, nmax * sizeof *bs);
 struct day t = {.nv = nv};
 for (int k = 0; k < 3; k++) t.x[k] = tray_data(tray(g->sp[k]));
 bool const good = bs && dy_read(g->sp[3], &t, bs, nmax);
 if (good && ok(g = have(g, 3 * w + 3 * chain_req))) {
  for (int k = 0; k < 3; k++) t.x[k] = tray_data(tray(g->sp[k]));
  dy_read(g->sp[3], &t, bs, nmax);   // re-read: the ask may have moved them
  word r[3];
  for (int m = 0; m < 3; m++) {
   struct tray *o = ini_tray(bump(g, w), love_R, 1);
   o->shape[0] = nv, t.out[m] = tray_data(o), r[m] = word(o); }
  par_run(g, (intptr_t) ((nv + lp_chunk - 1) / lp_chunk), dy_share, &t);
  word l = ZeroPoint;
  for (int m = 3; m--; ) l = word(ini_chain(bump(g, chain_req), (intptr_t) r[m], (intptr_t) l));
  g->sp[0] = l; }
 else if (ok(g)) g->sp[0] = ZeroPoint;
 if (bs) alloc(bs, 0);
 return g; }
// the brushes of db v meeting the box lo hi, laid into o where there is one, those from the
// first walked marked so; their length, or -1 where db is not as it says
static uintptr_t dy_near(flo_t const *v, uintptr_t n, flo_t const lo[3], flo_t const hi[3], flo_t *o) {
 uintptr_t m = 0;
 bool walk = 0;
 for (uintptr_t at = 0; at < n; ) {
  uintptr_t const a0 = at;
  struct dbr b;
  if (!dy_next(v, n, &at, &b)) return (uintptr_t) -1;
  walk = walk || b.kind & 10;
  if (!dy_meets(&b, lo, hi)) continue;
  if (o) {
   for (uintptr_t k = a0; k < at; k++) o[m + k - a0] = v[k];
   o[m] = (flo_t) (b.kind | (walk ? 8 : 0)); }
  m += at - a0; }
 return m; }
love_noinline static struct g *host_lamp_near(struct g *g) {
 flo_t lo[3], hi[3];
 if (!dy_db(g->sp[0]) || !lp_nums(g->sp[1], lo, 3) || !lp_nums(g->sp[2], hi, 3)) return g->sp[0] = ZeroPoint, g;
 uintptr_t const m = dy_near(tray_data(tray(g->sp[0])), tray_nelem(tray(g->sp[0])), lo, hi, NULL);
 if (m == (uintptr_t) -1) return g->sp[0] = ZeroPoint, g;
 uintptr_t const w = b2w(tray_bytes(love_R, 1, m));
 if (ok(g = have(g, w))) {
  struct tray *o = ini_tray(bump(g, w), love_R, 1);
  o->shape[0] = m;
  dy_near(tray_data(tray(g->sp[0])), tray_nelem(tray(g->sp[0])), lo, hi, tray_data(o));
  g->sp[0] = word(o); }
 return g; }
// whether the light the open lets in on face ps changes by more than step, asked a lift out
// from it along its edges gap apart and at its middle: the open's share and half of how
// buried it is where the open is round it, as world.l's daylit weighs them
love_noinline static struct g *host_lamp_varies(struct g *g) {
 flo_t lift[3], step, gap;
 if (!dy_db(g->sp[0]) || !dy_db(g->sp[4]) || !lp_nums(g->sp[1], lift, 3) || !lp_num(g->sp[2], &step) || !lp_num(g->sp[3], &gap) || !(gap > 0)
     || tray_nelem(tray(g->sp[0])) % 3 || !tray_nelem(tray(g->sp[0]))) return g->sp[0] = ZeroPoint, g;
 flo_t const *ps = tray_data(tray(g->sp[0]));
 uintptr_t const nc = tray_nelem(tray(g->sp[0])) / 3, nmax = tray_nelem(tray(g->sp[4])) / 8 + 1;
 uintptr_t nv = 1;
 for (uintptr_t i = 0; i < nc; i++) {
  flo_t const *p = ps + 3 * i, *q = ps + 3 * ((i + 1) % nc), d[3] = {q[0] - p[0], q[1] - p[1], q[2] - p[2]};
  nv += (uintptr_t) (lp_sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]) / gap) + 1; }
 flo_t *x = alloc(NULL, 3 * nv * sizeof *x);
 struct dbr *bs = alloc(NULL, nmax * sizeof *bs);
 struct day t = {.nv = nv};
 bool good = x && bs;
 if (good) {
  flo_t m[3] = {0, 0, 0};
  for (uintptr_t i = 0; i < nc; i++) for (int k = 0; k < 3; k++) m[k] = m[k] + ps[3 * i + k];
  for (int k = 0; k < 3; k++) x[k * nv] = m[k] / (flo_t) nc + lift[k];
  for (uintptr_t i = 0, s = 1; i < nc; i++) {
   flo_t const *p = ps + 3 * i, *q = ps + 3 * ((i + 1) % nc), d[3] = {q[0] - p[0], q[1] - p[1], q[2] - p[2]};
   uintptr_t const n = (uintptr_t) (lp_sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]) / gap) + 1;
   for (uintptr_t j = 0; j < n; j++, s++) for (int k = 0; k < 3; k++) x[k * nv + s] = p[k] + d[k] * ((flo_t) j / (flo_t) n) + lift[k]; }
  for (int k = 0; k < 3; k++) t.x[k] = x + k * nv;
  good = dy_read(g->sp[4], &t, bs, nmax); }
 flo_t lo = 0, hi = 0;
 for (uintptr_t i = 0; good && i < nv; i++) {
  flo_t const p[3] = {t.x[0][i], t.x[1][i], t.x[2][i]};
  flo_t w[3];
  dy_point(&t, p, w);
  flo_t const s = w[0] * (1 - w[1]) + w[2], m = s < 1 ? s : 1, o = m + (flo_t) 0.5 * (w[0] * w[1] * (1 - m));
  lo = i && lo < o ? lo : o, hi = i && o < hi ? hi : o; }
 bool const on = good && hi - lo > step;
 if (x) alloc(x, 0);
 if (bs) alloc(bs, 0);
 return g->sp[0] = good ? putcharm(on) : ZeroPoint, g; }
static lvm(lvm_lamp_light) { LvmCallp(g, 1, host_lamp_light) }
static lvm(lvm_lamp_lights) { LvmCallp(g, 2, host_lamp_lights) }
LvDef("lamp-light", lamp_light, 2, "lore");
LvDef("lamp-lights", lamp_lights, 3, "lore");
static lvm(lvm_lamp_open) { LvmCallp(g, 3, host_lamp_open) }
LvDef("lamp-open", lamp_open, 4, "lore");
static lvm(lvm_lamp_near) { LvmCallp(g, 2, host_lamp_near) }
LvDef("lamp-near", lamp_near, 3, "lore");
static lvm(lvm_lamp_varies) { LvmCallp(g, 4, host_lamp_varies) }
LvDef("lamp-varies", lamp_varies, 5, "lore");
