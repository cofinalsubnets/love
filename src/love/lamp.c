// lamp -- lore's lamps on a packed mesh's vertices (mesh.l's mesh-lamp), shared over the pool
// (lamp-light cols lamps): cols a packed mesh's columns, [x y z u v nx ny nz r g b] trays;
// lamps each [pts r c n s2 wrap box]: its points, reach, [r g b], () or the way it faces, its
// softness squared, its wrap, and () or the box it keeps to, [x0 z0 x1 z1] in plan or
// [x0 z0 x1 z1 y0 y1] between two heights too. answers the
// light they throw on each vertex as [r g b] trays, summed lamp by lamp in order, a lamp
// whose reach misses the mesh's box adding nothing, and the numbers [0.0 0.0 0.0] where none
// reaches it. (lamp-lights cols base lights): base [r g b], each a tray or a number, and to
// it each light's lamp-light in turn. () where an argument is not as it says
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
     flo_t const *p = l->ps + 3 * q;
     flo_t const lx = p[0] - X, ly = p[1] - Y, lz = p[2] - Z, d2 = lx * lx + ly * ly + lz * lz,
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
static lvm(lvm_lamp_light) { LvmCallp(g, 1, host_lamp_light) }
static lvm(lvm_lamp_lights) { LvmCallp(g, 2, host_lamp_lights) }
LvDef("lamp-light", lamp_light, 2, NULL);
LvDef("lamp-lights", lamp_lights, 3, NULL);
