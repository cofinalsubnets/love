// tumble -- the step of src/apps/lore/tumble.l in C, the same work in the same order, so the
// two answer alike to rounding: bodies against brushes and each other, the contacts solved by
// impulses, what is left sunk taken back, the awake moved and turned, the still a while asleep.
// (tumble-step B P O F) answers B a step on:
//  B  tb-nb numbers a body: shape (0 sphere, 1 box) m im ii3 p3 q4 v3 w3 e mu roll size3 idle still
//     (size a sphere's radius, else a box's half sides)
//  P  8 numbers a plane, n3 d, its brush's number and the brush's velocity u3, a brush's planes
//     together; a contact on a brush is taken against how it moves
//  O  gx gy gz dt
//  F  the faces' count, then each face: np ne n3 d c3 rad, np corners, ne edges [a3 t3 l o3]
// () when the trays are not so
#include "love.h"
#include <stdlib.h>

enum { tb_nb = 28, tb_iters = 30 };
#define tb_h (1.0 / 240.0)
#define tb_slop 0.002
#define tb_fixk 0.4
#define tb_bounce 0.6
#define tb_restv 0.05
#define tb_restt 0.5
#define tb_wakev 0.3

typedef flo_t v3[3];
struct tbody { flo_t shape, m, im, ii[3], p[3], q[4], v[3], w[3], e, mu, roll, s[3], idle, still, R[3][3]; };
struct tcon { struct tbody *a, *b; v3 n, ra, rb, t1, t2, u; flo_t d, kn, k1, k2, jn, j1, j2, mu, bias; };
struct tpt { v3 n, x; flo_t d; };
struct tset { struct tcon *c; uintptr_t n, cap; int bad; };

static flo_t tb_dot3(v3 const a, v3 const b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
static void tb_cross3(v3 o, v3 const a, v3 const b) {
 flo_t const x = a[1] * b[2] - a[2] * b[1], y = a[2] * b[0] - a[0] * b[2], z = a[0] * b[1] - a[1] * b[0];
 o[0] = x, o[1] = y, o[2] = z; }
static flo_t tb_mag(flo_t x) { return x > -x ? x : -x; }
static flo_t tb_fmax2(flo_t a, flo_t b) { return a > b ? a : b; }
static flo_t tb_fmin2(flo_t a, flo_t b) { return a < b ? a : b; }
static flo_t tb_len3(v3 const a) { return love_sqrt(tb_dot3(a, a)); }
// ..a unit square to d, as vec.l's side
static void tb_side3(v3 o, v3 const d) {
 v3 const k = { tb_mag(d[1]) < 0.95 ? 0.0 : 1.0, tb_mag(d[1]) < 0.95 ? 1.0 : 0.0, 0.0 };
 tb_cross3(o, d, k);
 flo_t const l = 1.0 / love_sqrt(tb_fmax2(1e-12, tb_dot3(o, o)));
 o[0] *= l, o[1] *= l, o[2] *= l; }
static void tb_rot(struct tbody *b) {
 flo_t const w = b->q[0], x = b->q[1], y = b->q[2], z = b->q[3];
 b->R[0][0] = 1.0 - 2.0 * (y * y + z * z), b->R[0][1] = 2.0 * (x * y - w * z), b->R[0][2] = 2.0 * (x * z + w * y);
 b->R[1][0] = 2.0 * (x * y + w * z), b->R[1][1] = 1.0 - 2.0 * (x * x + z * z), b->R[1][2] = 2.0 * (y * z - w * x);
 b->R[2][0] = 2.0 * (x * z - w * y), b->R[2][1] = 2.0 * (y * z + w * x), b->R[2][2] = 1.0 - 2.0 * (x * x + y * y); }
static void tb_mv(v3 o, flo_t const R[3][3], v3 const v) {
 flo_t const x = tb_dot3(R[0], v), y = tb_dot3(R[1], v), z = tb_dot3(R[2], v); o[0] = x, o[1] = y, o[2] = z; }
static void tb_mtv(v3 o, flo_t const R[3][3], v3 const v) {
 for (int k = 0; k < 3; k++) o[k] = v[0] * R[0][k] + v[1] * R[1][k] + v[2] * R[2][k]; }
static void tb_col(v3 o, flo_t const R[3][3], int k) { o[0] = R[0][k], o[1] = R[1][k], o[2] = R[2][k]; }
// ..the inverse inertia in the world applied to v
static void tb_iw(v3 o, struct tbody const *b, v3 const v) {
 v3 t; tb_mtv(t, b->R, v);
 t[0] *= b->ii[0], t[1] *= b->ii[1], t[2] *= b->ii[2];
 tb_mv(o, b->R, t); }
static void tb_vel(v3 o, struct tbody const *b, v3 const r) { v3 c; tb_cross3(c, b->w, r); for (int k = 0; k < 3; k++) o[k] = b->v[k] + c[k]; }
static void tb_rel(v3 o, struct tcon const *c) {
 tb_vel(o, c->a, c->ra);
 if (c->b) { v3 u; tb_vel(u, c->b, c->rb); for (int k = 0; k < 3; k++) o[k] -= u[k]; }
 else for (int k = 0; k < 3; k++) o[k] -= c->u[k]; }
static flo_t tb_eff1(struct tbody const *o, v3 const r, v3 const u) {
 v3 a, b, c; tb_cross3(a, r, u), tb_iw(b, o, a), tb_cross3(c, b, r);
 return o->im + tb_dot3(u, c); }
static flo_t tb_reach(struct tbody const *b) { return b->shape == 0 ? b->s[0] : tb_len3(b->s); }
static flo_t tb_size(struct tbody const *b) { return b->shape == 0 ? b->s[0] : tb_fmax2(b->s[0], tb_fmax2(b->s[1], b->s[2])); }

// ..u the velocity of the brush a stands on, 0 for one standing still
static void tb_addu(struct tset *S, struct tbody *a, struct tbody *b, v3 const n, v3 const x, flo_t d, flo_t const *u) {
 if (S->n == S->cap) {
  uintptr_t const m = S->cap ? 2 * S->cap : 64;
  struct tcon *c = realloc(S->c, m * sizeof *c);
  if (!c) { S->bad = 1; return; }
  S->c = c, S->cap = m; }
 struct tcon *c = S->c + S->n++;
 c->a = a, c->b = b, c->d = d, c->jn = c->j1 = c->j2 = 0;
 for (int k = 0; k < 3; k++) c->n[k] = n[k], c->ra[k] = x[k] - a->p[k], c->rb[k] = b ? x[k] - b->p[k] : 0, c->u[k] = u ? u[k] : 0.0;
 tb_side3(c->t1, n), tb_cross3(c->t2, n, c->t1);
 c->kn = tb_eff1(a, c->ra, n) + (b ? tb_eff1(b, c->rb, n) : 0);
 c->k1 = tb_eff1(a, c->ra, c->t1) + (b ? tb_eff1(b, c->rb, c->t1) : 0);
 c->k2 = tb_eff1(a, c->ra, c->t2) + (b ? tb_eff1(b, c->rb, c->t2) : 0);
 v3 rv; tb_rel(rv, c);
 flo_t const vn = tb_dot3(rv, n), e = b ? tb_fmax2(a->e, b->e) : a->e;
 c->mu = b ? love_sqrt(a->mu * b->mu) : a->mu;
 c->bias = vn < 0.0 - tb_bounce ? 0.0 - e * vn : 0.0; }
static void tb_add(struct tset *S, struct tbody *a, struct tbody *b, v3 const n, v3 const x, flo_t d) { tb_addu(S, a, b, n, x, d, 0); }

// ..the plane of the brush at planes P[0..n) a point stands furthest out of
static flo_t tb_most(flo_t const *P, uintptr_t n, uintptr_t st, v3 const x, v3 on) {
 flo_t s = -1e9; on[0] = 0, on[1] = 1, on[2] = 0;
 for (uintptr_t i = 0; i < n; i++) {
  flo_t const *p = P + i * st, t = tb_dot3(p, x) - p[3];
  if (t > s) s = t, on[0] = p[0], on[1] = p[1], on[2] = p[2]; }
 return s; }
static void tb_corners(v3 o[8], struct tbody const *b) {
 for (int i = 0; i < 8; i++) {
  v3 const s = { (i & 1 ? 1.0 : -1.0) * b->s[0], (i & 2 ? 1.0 : -1.0) * b->s[1], (i & 4 ? 1.0 : -1.0) * b->s[2] };
  v3 t; tb_mv(t, b->R, s);
  for (int k = 0; k < 3; k++) o[i][k] = b->p[k] + t[k]; } }
// ..a box's six faces as planes, 4 numbers each
static void tb_faces(flo_t F[24], struct tbody const *b) {
 for (int k = 0; k < 3; k++) {
  v3 u; tb_col(u, b->R, k);
  flo_t const o = tb_dot3(u, b->p);
  flo_t *f = F + 8 * k;
  f[0] = u[0], f[1] = u[1], f[2] = u[2], f[3] = o + b->s[k];
  f[4] = -u[0], f[5] = -u[1], f[6] = -u[2], f[7] = b->s[k] - o; } }

static void tb_brush(struct tset *S, struct tbody *b, flo_t const *P, uintptr_t n) {
 v3 on;
 if (b->shape == 0) {
  flo_t const s = tb_most(P, n, 8, b->p, on);
  if (s < b->s[0]) {
   v3 x; for (int k = 0; k < 3; k++) x[k] = b->p[k] - b->s[0] * on[k];
   tb_addu(S, b, 0, on, x, b->s[0] - s, P + 5); }
  return; }
 v3 cs[8]; tb_corners(cs, b);
 for (int i = 0; i < 8; i++) {
  flo_t const s = tb_most(P, n, 8, cs[i], on);
  if (s < 0.0) tb_addu(S, b, 0, on, cs[i], 0.0 - s, P + 5); } }

// --- two bodies, as points with n out of b into a ---
static int tb_sph_sph(struct tpt *o, struct tbody const *a, struct tbody const *b) {
 v3 u; for (int k = 0; k < 3; k++) u[k] = a->p[k] - b->p[k];
 flo_t const l = tb_len3(u), d = a->s[0] + b->s[0] - l;
 if (!(d > 0.0 && l > 1e-9)) return 0;
 for (int k = 0; k < 3; k++) o->n[k] = u[k] * (1.0 / l), o->x[k] = b->p[k] + b->s[0] * o->n[k];
 o->d = d;
 return 1; }
static int tb_sph_box(struct tpt *o, struct tbody const *a, struct tbody const *b) {
 v3 u, c, q; for (int k = 0; k < 3; k++) u[k] = a->p[k] - b->p[k];
 tb_mtv(c, b->R, u);
 flo_t const r = a->s[0];
 for (int k = 0; k < 3; k++) q[k] = tb_fmax2(0.0 - b->s[k], tb_fmin2(b->s[k], c[k])), u[k] = c[k] - q[k];
 flo_t const l = tb_len3(u);
 if (l > 1e-9) {
  if (!(l < r)) return 0;
  v3 t; for (int k = 0; k < 3; k++) t[k] = (1.0 / l) * u[k];
  tb_mv(o->n, b->R, t), tb_mv(t, b->R, q);
  for (int k = 0; k < 3; k++) o->x[k] = b->p[k] + t[k];
  o->d = r - l;
  return 1; }
 flo_t F[24];
 tb_faces(F, b);
 flo_t const s = tb_most(F, 6, 4, a->p, o->n);
 for (int k = 0; k < 3; k++) o->x[k] = a->p[k];
 o->d = r - s;
 return 1; }
static flo_t tb_span(struct tbody const *b, v3 const L) {
 flo_t s = 0; v3 u;
 for (int k = 0; k < 3; k++) tb_col(u, b->R, k), s += b->s[k] * tb_mag(tb_dot3(u, L));
 return s; }
static int tb_inside(struct tbody const *b, v3 const x, flo_t e, int skip) {
 v3 u, c; for (int k = 0; k < 3; k++) u[k] = x[k] - b->p[k];
 for (int k = 0; k < 3; k++) { if (k == skip) continue; tb_col(c, b->R, k); if (!(tb_mag(tb_dot3(c, u)) <= b->s[k] + e)) return 0; }
 return 1; }
// ..of fifteen axes the one two boxes overlap least along, then the face's or the edges' points
static int tb_box_box(struct tpt *o, struct tbody const *a, struct tbody const *b) {
 v3 d; for (int k = 0; k < 3; k++) d[k] = a->p[k] - b->p[k];
 v3 A[3], B[3]; for (int k = 0; k < 3; k++) tb_col(A[k], a->R, k), tb_col(B[k], b->R, k);
 int bk = -1, bi = 0, bj = 0; flo_t bo = 0, bw = 1; v3 bn = { 0, 0, 0 };
 for (int x = 0; x < 15; x++) {
  v3 L; int kind, i = 0, j = 0;
  if (x < 3) kind = 0, i = x, L[0] = A[x][0], L[1] = A[x][1], L[2] = A[x][2];
  else if (x < 6) kind = 1, i = x - 3, L[0] = B[i][0], L[1] = B[i][1], L[2] = B[i][2];
  else {
   kind = 2, i = (x - 6) / 3, j = (x - 6) % 3;
   tb_cross3(L, A[i], B[j]);
   flo_t const l = tb_len3(L);
   if (l < 1e-5) continue;
   for (int k = 0; k < 3; k++) L[k] *= 1.0 / l; }
  flo_t const s = tb_dot3(d, L), ov = tb_span(a, L) + tb_span(b, L) - tb_mag(s), w = kind == 2 ? 1.05 : 1.0;
  if (ov < 0.0) return 0;
  if (bk < 0 || w * ov + 0.001 * (w - 1.0) < bw * bo) {
   bk = kind, bi = i, bj = j, bo = ov, bw = w;
   for (int k = 0; k < 3; k++) bn[k] = s < 0.0 ? -L[k] : L[k]; } }
 flo_t const tol = 0.005;
 int m = 0;
 v3 ca[8], cb[8]; tb_corners(ca, a), tb_corners(cb, b);
 if (bk == 1 || bk == 0) {
  // ..a face of b (or of a, turned about): the other's corners through it within its edges,
  // then its own corners inside the other
  struct tbody const *f = bk == 1 ? b : a, *g = bk == 1 ? a : b;
  v3 *gc = bk == 1 ? ca : cb, *fc = bk == 1 ? cb : ca;
  v3 nn; for (int k = 0; k < 3; k++) nn[k] = bk == 1 ? bn[k] : -bn[k];
  flo_t const P = tb_dot3(nn, f->p) + f->s[bi];
  for (int i = 0; i < 8; i++) {
   flo_t const e = P - tb_dot3(nn, gc[i]);
   if (e > 0.0 && tb_inside(f, gc[i], tol, bi)) {
    for (int k = 0; k < 3; k++) o[m].n[k] = bn[k], o[m].x[k] = gc[i][k];
    o[m++].d = e; } }
  for (int i = 0; i < 8; i++)
   if (tb_dot3(nn, fc[i]) > P - tol && tb_inside(g, fc[i], tol, -1)) {
    for (int k = 0; k < 3; k++) o[m].n[k] = bn[k], o[m].x[k] = fc[i][k];
    o[m++].d = bo; }
  return m; }
 // ..edge bi of a nearest b, edge bj of b nearest a, the middle of their nearest points
 v3 pa, pb;
 for (int k = 0; k < 3; k++) pa[k] = a->p[k], pb[k] = b->p[k];
 for (int k = 0; k < 3; k++) {
  if (k != bi) { flo_t const s = (0.0 - tb_dot3(A[k], bn) < 0.0 ? -1.0 : 1.0) * a->s[k]; for (int z = 0; z < 3; z++) pa[z] += s * A[k][z]; }
  if (k != bj) { flo_t const s = (tb_dot3(B[k], bn) < 0.0 ? -1.0 : 1.0) * b->s[k]; for (int z = 0; z < 3; z++) pb[z] += s * B[k][z]; } }
 v3 r; for (int k = 0; k < 3; k++) r[k] = pa[k] - pb[k];
 flo_t const e = tb_dot3(A[bi], B[bj]), dn = 1.0 - e * e,
             sa = tb_fmax2(0.0 - a->s[bi], tb_fmin2(a->s[bi], dn < 1e-9 ? 0.0 : (e * tb_dot3(B[bj], r) - tb_dot3(A[bi], r)) / dn)),
             tb = tb_fmax2(0.0 - b->s[bj], tb_fmin2(b->s[bj], e * sa + tb_dot3(B[bj], r)));
 for (int k = 0; k < 3; k++) o[0].n[k] = bn[k], o[0].x[k] = 0.5 * ((pa[k] + sa * A[bi][k]) + (pb[k] + tb * B[bj][k]));
 o[0].d = bo;
 return 1; }
// --- the world's faces: convex polygons, solid behind, pushing a body only out of it.
// a face as love lays it: np ne n d c rad, then np corners, then ne edges [a t l o] ---
struct tface { uintptr_t np, ne; flo_t const *n, *c, *ps, *es; flo_t d, rad; };
static int tb_inface(struct tface const *F, v3 const x, flo_t e) {
 for (uintptr_t i = 0; i < F->ne; i++) {
  flo_t const *q = F->es + 10 * i;
  v3 u; for (int k = 0; k < 3; k++) u[k] = x[k] - q[k];
  if (!(tb_dot3(q + 7, u) <= e)) return 0; }
 return 1; }
static void tb_segnear(v3 o, flo_t const *q, v3 const x) {
 v3 u; for (int k = 0; k < 3; k++) u[k] = x[k] - q[k];
 flo_t const s = tb_fmax2(0.0, tb_fmin2(q[6], tb_dot3(u, q + 3)));
 for (int k = 0; k < 3; k++) o[k] = q[k] + s * q[3 + k]; }
static void tb_sph_face(struct tset *S, struct tbody *b, struct tface const *F) {
 flo_t const r = b->s[0], s = tb_dot3(F->n, b->p) - F->d;
 if (s > r || s < 0.0) return;
 v3 p0, q, u; for (int k = 0; k < 3; k++) p0[k] = b->p[k] - s * F->n[k];
 if (tb_inface(F, p0, 0.0)) for (int k = 0; k < 3; k++) q[k] = p0[k];
 else {
  for (int k = 0; k < 3; k++) q[k] = F->ps[k];
  for (uintptr_t i = 0; i < F->ne; i++) {
   v3 y, a, c; tb_segnear(y, F->es + 10 * i, b->p);
   for (int k = 0; k < 3; k++) a[k] = b->p[k] - y[k], c[k] = b->p[k] - q[k];
   if (tb_len3(a) < tb_len3(c)) for (int k = 0; k < 3; k++) q[k] = y[k]; } }
 for (int k = 0; k < 3; k++) u[k] = b->p[k] - q[k];
 flo_t const l = tb_len3(u);
 if (!(l < r)) return;
 v3 n; for (int k = 0; k < 3; k++) n[k] = l > 1e-9 ? (1.0 / l) * u[k] : F->n[k];
 tb_add(S, b, 0, n, q, r - l); }
static void tb_box_face(struct tset *S, struct tbody *b, struct tface const *F) {
 v3 A[3]; for (int k = 0; k < 3; k++) tb_col(A[k], b->R, k);
 flo_t const sn = tb_span(b, F->n), s = tb_dot3(F->n, b->p) - F->d;
 if (s < 0.0 - 0.5 * sn || s > sn) return;
 v3 dc; for (int k = 0; k < 3; k++) dc[k] = b->p[k] - F->c[k];
 int bk = -1, bi = 0, bj = 0; flo_t bo = 0, bw = 1; v3 bL = { 0, 0, 0 };
 uintptr_t const nx = 4 + 3 * F->ne;
 for (uintptr_t x = 0; x < nx; x++) {
  v3 L; int kind, i = 0, j = 0;
  if (x == 0) kind = 0, L[0] = F->n[0], L[1] = F->n[1], L[2] = F->n[2];
  else if (x < 4) kind = 1, i = (int) x - 1, L[0] = A[i][0], L[1] = A[i][1], L[2] = A[i][2];
  else {
   kind = 2, i = (int) ((x - 4) / F->ne), j = (int) ((x - 4) % F->ne);
   tb_cross3(L, A[i], F->es + 10 * j + 3);
   flo_t const l = tb_len3(L);
   if (l < 1e-5) continue;
   for (int k = 0; k < 3; k++) L[k] = (1.0 / l) * L[k]; }
  if (kind && tb_dot3(L, dc) < 0.0) for (int k = 0; k < 3; k++) L[k] = -1.0 * L[k];
  flo_t m = -1e300;
  for (uintptr_t v = 0; v < F->np; v++) m = tb_fmax2(m, tb_dot3(L, F->ps + 3 * v));
  flo_t const ov = m - (tb_dot3(L, b->p) - tb_span(b, L)), w = kind == 2 ? 1.05 : 1.0;
  if (ov < 0.0) return;
  if (bk < 0 || w * ov + 0.001 * (w - 1.0) < bw * bo) {
   bk = kind, bi = i, bj = j, bo = ov, bw = w;
   for (int k = 0; k < 3; k++) bL[k] = L[k]; } }
 if (!(tb_dot3(bL, F->n) > 0.0)) return;
 flo_t const tol = 0.005;
 if (bk == 0) {
  v3 cs[8]; tb_corners(cs, b);
  for (int i = 0; i < 8; i++) {
   flo_t const e = F->d - tb_dot3(F->n, cs[i]);
   if (e > 0.0 && tb_inface(F, cs[i], tol)) tb_add(S, b, 0, F->n, cs[i], e); } }
 if (bk <= 1) {
  for (uintptr_t v = 0; v < F->np; v++)
   if (tb_inside(b, F->ps + 3 * v, tol, -1)) tb_add(S, b, 0, bk == 0 ? F->n : bL, F->ps + 3 * v, bo);
  return; }
 // ..edge bi of the box nearest the face, edge bj of the face, the middle of their nearest points
 flo_t const *e = F->es + 10 * bj, hb = 0.5 * e[6];
 v3 ca, cb, r;
 for (int k = 0; k < 3; k++) ca[k] = b->p[k], cb[k] = e[k] + hb * e[3 + k];
 for (int k = 0; k < 3; k++) if (k != bi) { flo_t const g = (0.0 - tb_dot3(A[k], bL) < 0.0 ? -1.0 : 1.0) * b->s[k]; for (int z = 0; z < 3; z++) ca[z] += g * A[k][z]; }
 for (int k = 0; k < 3; k++) r[k] = ca[k] - cb[k];
 flo_t const g = tb_dot3(A[bi], e + 3), dn = 1.0 - g * g,
             sa = tb_fmax2(0.0 - b->s[bi], tb_fmin2(b->s[bi], dn < 1e-9 ? 0.0 : (g * tb_dot3(e + 3, r) - tb_dot3(A[bi], r)) / dn)),
             tb = tb_fmax2(0.0 - hb, tb_fmin2(hb, g * sa + tb_dot3(e + 3, r)));
 v3 x; for (int k = 0; k < 3; k++) x[k] = 0.5 * ((ca[k] + sa * A[bi][k]) + (cb[k] + tb * e[3 + k]));
 tb_add(S, b, 0, bL, x, bo); }
static void tb_facehits(struct tset *S, struct tbody *b, struct tface const *Fs, uintptr_t nf) {
 flo_t const r = tb_reach(b);
 for (uintptr_t i = 0; i < nf; i++) {
  struct tface const *F = Fs + i;
  v3 u; for (int k = 0; k < 3; k++) u[k] = b->p[k] - F->c[k];
  flo_t const m = r + F->rad;
  if (tb_dot3(u, u) > m * m) continue;
  if (b->shape == 0) tb_sph_face(S, b, F); else tb_box_face(S, b, F); } }
static int tb_touching(struct tpt *o, struct tbody const *a, struct tbody const *b) {
 if (a->shape == 0 && b->shape == 0) return tb_sph_sph(o, a, b);
 if (a->shape == 0) return tb_sph_box(o, a, b);
 if (b->shape == 0) {
  int const n = tb_sph_box(o, b, a);
  for (int i = 0; i < n; i++) for (int k = 0; k < 3; k++) o[i].n[k] = -o[i].n[k];
  return n; }
 return tb_box_box(o, a, b); }
static void tb_wake(struct tbody *b) { b->still = 0, b->idle = 0; }
static flo_t tb_moving(struct tbody const *b) { return tb_len3(b->v) + tb_len3(b->w) * tb_reach(b); }
// ..the pairs near enough, found by a grid of cells twice the widest reach: each body's reach
// cube marks the cells it covers in a hash, and each body i in turn meets the j > i that share
// a cell with it, in order, as a sweep of every pair would
struct tgrid { uint64_t *hk; intptr_t *hh, *nx, *ent; uintptr_t *ej, *mark, *nb; intptr_t (*lo)[3], (*hi)[3];
               uintptr_t hc, cx, ce, cb, n; };
#define tb_lim 262144
static intptr_t tb_cell(flo_t x, flo_t c) {
 flo_t f = x / c;
 if (!(f > -tb_lim)) f = -tb_lim;
 if (!(f < tb_lim)) f = tb_lim;
 intptr_t i = (intptr_t) f;
 return (flo_t) i > f ? i - 1 : i; }
static uint64_t tb_key(intptr_t x, intptr_t y, intptr_t z) {
 return (uint64_t) (x + tb_lim) << 40 | (uint64_t) (y + tb_lim) << 20 | (uint64_t) (z + tb_lim); }
static uintptr_t tb_slot(struct tgrid const *G, uint64_t k) {
 uint64_t h = k * 0x9e3779b97f4a7c15u;
 uintptr_t i = (uintptr_t) (h >> 32) & (G->hc - 1);
 while (G->hh[i] >= 0 && G->hk[i] != k) i = (i + 1) & (G->hc - 1);
 return i; }
static int tb_grow(void **p, uintptr_t *cap, uintptr_t need, uintptr_t size) {
 if (need <= *cap) return 1;
 uintptr_t c = *cap ? *cap : 64;
 while (c < need) c *= 2;
 void *q = realloc(*p, c * size);
 if (!q) return 0;
 *p = q, *cap = c;
 return 1; }
static void tb_gfree(struct tgrid *G) {
 free(G->hk), free(G->hh), free(G->nx), free(G->ent), free(G->ej), free(G->mark), free(G->nb), free(G->lo), free(G->hi); }
static int tb_ginit(struct tgrid *G, uintptr_t n) {
 G->n = n;
 uintptr_t const m = n ? n : 1;
 G->mark = malloc(m * sizeof *G->mark), G->lo = malloc(m * sizeof *G->lo), G->hi = malloc(m * sizeof *G->hi);
 return G->mark && G->lo && G->hi; }
// ..the cells, filled once a substep: hh a cell's first entry, nx the next, ent the body
static int tb_fill(struct tgrid *G, struct tbody const *bs) {
 uintptr_t const n = G->n;
 flo_t c = 0.0;
 for (uintptr_t i = 0; i < n; i++) c = tb_fmax2(c, tb_reach(bs + i));
 c = c > 0.0 ? 2.0 * c : 1.0;
 uintptr_t ne = 0;
 for (uintptr_t i = 0; i < n; i++) {
  flo_t const r = tb_reach(bs + i);
  for (int k = 0; k < 3; k++) G->lo[i][k] = tb_cell(bs[i].p[k] - r, c), G->hi[i][k] = tb_cell(bs[i].p[k] + r, c);
  ne += (uintptr_t) ((G->hi[i][0] - G->lo[i][0] + 1) * (G->hi[i][1] - G->lo[i][1] + 1) * (G->hi[i][2] - G->lo[i][2] + 1)); }
 uintptr_t hc = 16;
 while (hc < 2 * ne) hc *= 2;
 if (hc != G->hc) {
  free(G->hk), free(G->hh);
  G->hk = malloc(hc * sizeof *G->hk), G->hh = malloc(hc * sizeof *G->hh), G->hc = hc;
  if (!G->hk || !G->hh) return G->hc = 0, 0; }
 for (uintptr_t i = 0; i < hc; i++) G->hh[i] = -1;
 if (!tb_grow((void **) &G->nx, &G->cx, ne, sizeof *G->nx) || !tb_grow((void **) &G->ent, &G->ce, ne, sizeof *G->ent)) return 0;
 uintptr_t e = 0;
 for (uintptr_t i = 0; i < n; i++)
  for (intptr_t x = G->lo[i][0]; x <= G->hi[i][0]; x++)
   for (intptr_t y = G->lo[i][1]; y <= G->hi[i][1]; y++)
    for (intptr_t z = G->lo[i][2]; z <= G->hi[i][2]; z++) {
     uint64_t const k = tb_key(x, y, z);
     uintptr_t const s = tb_slot(G, k);
     if (G->hh[s] < 0) G->hk[s] = k, G->nx[e] = -1;
     else G->nx[e] = G->hh[s];
     G->ent[e] = (intptr_t) i, G->hh[s] = (intptr_t) e++; }
 for (uintptr_t i = 0; i < n; i++) G->mark[i] = (uintptr_t) -1;
 return 1; }
// ..the j > i sharing a cell with i, rising, into nb; their number
static uintptr_t tb_near(struct tgrid *G, uintptr_t i) {
 uintptr_t m = 0;
 for (intptr_t x = G->lo[i][0]; x <= G->hi[i][0]; x++)
  for (intptr_t y = G->lo[i][1]; y <= G->hi[i][1]; y++)
   for (intptr_t z = G->lo[i][2]; z <= G->hi[i][2]; z++)
    for (intptr_t e = G->hh[tb_slot(G, tb_key(x, y, z))]; e >= 0; e = G->nx[e]) {
     uintptr_t const j = (uintptr_t) G->ent[e];
     if (j <= i || G->mark[j] == i) continue;
     G->mark[j] = i;
     if (!tb_grow((void **) &G->nb, &G->cb, m + 1, sizeof *G->nb)) return (uintptr_t) -1;
     uintptr_t t = m++;
     for (; t > 0 && G->nb[t - 1] > j; t--) G->nb[t] = G->nb[t - 1];
     G->nb[t] = j; }
 return m; }
static void tb_pairs(struct tset *S, struct tgrid *G, struct tbody *bs, uintptr_t n) {
 struct tpt ts[16];
 if (!tb_fill(G, bs)) { S->bad = 1; return; }
 for (uintptr_t i = 0; i < n; i++) {
  uintptr_t const m = tb_near(G, i);
  if (m == (uintptr_t) -1) { S->bad = 1; return; }
  for (uintptr_t q = 0; q < m; q++) {
   struct tbody *a = bs + i, *b = bs + G->nb[q];
   if (a->still == 1 && b->still == 1) continue;
   v3 u; for (int k = 0; k < 3; k++) u[k] = a->p[k] - b->p[k];
   flo_t const r = tb_reach(a) + tb_reach(b);
   if (tb_dot3(u, u) > r * r) continue;
   int const mt = tb_touching(ts, a, b);
   if (!mt) continue;
   if (a->still == 1 && tb_moving(b) > tb_wakev) { tb_wake(a); continue; }
   if (b->still == 1 && tb_moving(a) > tb_wakev) { tb_wake(b); continue; }
   for (int t = 0; t < mt; t++) {
    if (a->still == 1) { v3 nn = { -ts[t].n[0], -ts[t].n[1], -ts[t].n[2] }; tb_add(S, b, 0, nn, ts[t].x, ts[t].d); }
    else if (b->still == 1) tb_add(S, a, 0, ts[t].n, ts[t].x, ts[t].d);
    else tb_add(S, a, b, ts[t].n, ts[t].x, ts[t].d); } } } }

// --- the solve ---
static void tb_push1(struct tbody *b, v3 const r, v3 const J) {
 v3 c, t; tb_cross3(c, r, J), tb_iw(t, b, c);
 for (int k = 0; k < 3; k++) b->v[k] += b->im * J[k], b->w[k] += t[k]; }
static void tb_push2(struct tcon *c, v3 const J) {
 tb_push1(c->a, c->ra, J);
 if (c->b) { v3 m = { -J[0], -J[1], -J[2] }; tb_push1(c->b, c->rb, m); } }
static void tb_solve1(struct tcon *c) {
 v3 v; tb_rel(v, c);
 flo_t const jn = tb_fmax2(0.0, c->jn + (c->bias - tb_dot3(v, c->n)) / c->kn), dn = jn - c->jn;
 c->jn = jn;
 v3 J; for (int k = 0; k < 3; k++) J[k] = dn * c->n[k];
 tb_push2(c, J);
 flo_t const lim = c->mu * jn;
 for (int f = 0; f < 2; f++) {
  flo_t *t = f ? c->t2 : c->t1, ka = f ? c->k2 : c->k1, *ja = f ? &c->j2 : &c->j1;
  tb_rel(v, c);
  flo_t const j = tb_fmax2(0.0 - lim, tb_fmin2(lim, *ja - tb_dot3(v, t) / ka)), dj = j - *ja;
  *ja = j;
  for (int k = 0; k < 3; k++) J[k] = dj * t[k];
  tb_push2(c, J); } }
static void tb_unsink(struct tset *S, struct tbody const *bs, uintptr_t const *cn) {
 for (uintptr_t i = 0; i < S->n; i++) {
  struct tcon *c = S->c + i;
  if (!(c->d > tb_slop)) continue;
  struct tbody *a = c->a, *b = c->b;
  flo_t const m = b ? b->im : 0.0, s = tb_fixk * (c->d - tb_slop) / (a->im + m), fa = s * a->im / (flo_t) cn[a - bs];
  for (int k = 0; k < 3; k++) a->p[k] += fa * c->n[k];
  if (b) { flo_t const fb = 0.0 - s * m / (flo_t) cn[b - bs]; for (int k = 0; k < 3; k++) b->p[k] += fb * c->n[k]; } } }

// --- a substep of h ---
static int tb_sub(struct tbody *bs, uintptr_t n, flo_t const *P, uintptr_t np, struct tface const *Fs, uintptr_t nf, v3 const g, flo_t h, struct tset *S, struct tgrid *G, char *awake, uintptr_t *cn) {
 S->n = 0;
 for (uintptr_t i = 0; i < n; i++) tb_rot(bs + i), awake[i] = bs[i].still != 1;
 for (uintptr_t i = 0; i < n; i++) if (awake[i]) for (int k = 0; k < 3; k++) bs[i].v[k] += h * g[k];
 for (uintptr_t i = 0; i < n; i++) if (awake[i]) {
  for (uintptr_t a = 0, z; a < np; a = z) {
   for (z = a + 1; z < np && P[8 * z + 4] == P[8 * a + 4]; z++);
   tb_brush(S, bs + i, P + 8 * a, z - a); }
  tb_facehits(S, bs + i, Fs, nf); }
 tb_pairs(S, G, bs, n);
 if (S->bad) return 0;
 // ..each body's contacts, counted once: the share of a sinking it takes back, and touching at all
 for (uintptr_t i = 0; i < n; i++) cn[i] = 0;
 for (uintptr_t i = 0; i < S->n; i++) { cn[S->c[i].a - bs]++; if (S->c[i].b && S->c[i].b != S->c[i].a) cn[S->c[i].b - bs]++; }
 for (int it = 0; it < tb_iters; it++) for (uintptr_t i = 0; i < S->n; i++) tb_solve1(S->c + i);
 tb_unsink(S, bs, cn);
 for (uintptr_t i = 0; i < n; i++) {
  if (!awake[i]) continue;
  struct tbody *b = bs + i;
  int const touch = cn[i] > 0;
  if (touch && b->roll > 0.0) { flo_t const f = tb_fmax2(0.0, 1.0 - b->roll * 9.81 * h / b->s[0]); for (int k = 0; k < 3; k++) b->w[k] *= f; }
  for (int k = 0; k < 3; k++) b->p[k] += h * b->v[k];
  flo_t const w0 = 0.0, w1 = b->w[0], w2 = b->w[1], w3 = b->w[2], *q = b->q,
              d[4] = { w0 * q[0] - w1 * q[1] - w2 * q[2] - w3 * q[3], w0 * q[1] + w1 * q[0] + w2 * q[3] - w3 * q[2],
                       w0 * q[2] - w1 * q[3] + w2 * q[0] + w3 * q[1], w0 * q[3] + w1 * q[2] - w2 * q[1] + w3 * q[0] };
  flo_t q2[4];
  for (int k = 0; k < 4; k++) q2[k] = q[k] + 0.5 * h * d[k];
  flo_t const l = love_sqrt(q2[0] * q2[0] + q2[1] * q2[1] + q2[2] * q2[2] + q2[3] * q2[3]);
  for (int k = 0; k < 4; k++) b->q[k] = q2[k] / l;
  flo_t const s = tb_fmax2(tb_len3(b->v), tb_len3(b->w) * tb_size(b));
  if (touch && s < tb_restv) {
   flo_t const t = b->idle + h;
   if (t > tb_restt) { b->still = 1, b->idle = t; for (int k = 0; k < 3; k++) b->v[k] = b->w[k] = 0.0; }
   else b->idle = t; }
  else b->idle = 0.0; }
 return 1; }

static void tb_load(struct tbody *b, flo_t const *r) {
 b->shape = r[0], b->m = r[1], b->im = r[2];
 for (int k = 0; k < 3; k++) b->ii[k] = r[3 + k], b->p[k] = r[6 + k], b->v[k] = r[13 + k], b->w[k] = r[16 + k], b->s[k] = r[22 + k];
 for (int k = 0; k < 4; k++) b->q[k] = r[9 + k];
 b->e = r[19], b->mu = r[20], b->roll = r[21], b->idle = r[25], b->still = r[26]; }
static void tb_keep(flo_t *r, struct tbody const *b) {
 for (int k = 0; k < 3; k++) r[6 + k] = b->p[k], r[13 + k] = b->v[k], r[16 + k] = b->w[k];
 for (int k = 0; k < 4; k++) r[9 + k] = b->q[k];
 r[25] = b->idle, r[26] = b->still; }

static lvm(lvm_tumble_step) {
 word const B = Sp[0], P = Sp[1], O = Sp[2], Fw = Sp[3];
 if (!galaxyp(B) || !galaxyp(P) || !galaxyp(O) || !galaxyp(Fw) || tray_nelem(tray(O)) < 4 || tray_nelem(tray(B)) % tb_nb
     || tray_nelem(tray(P)) % 8 || tray_nelem(tray(Fw)) < 1)
  love_musttail return Answerp(3, ZeroPoint);
 uintptr_t const nb = tray_nelem(tray(B)), n = nb / tb_nb, np = tray_nelem(tray(P)) / 8,
                 w = b2w(tray_bytes(love_R, 1, nb));
 Have(w);
 struct tray *o = ini_tray((struct tray*) Hp, love_R, 1); Hp += w;
 o->shape[0] = nb;
 flo_t *d = tray_data(o);
 for (uintptr_t i = 0; i < nb; i++) d[i] = tray_get_flo(tray(Sp[0]), i);
 struct tbody *bs = malloc((n ? n : 1) * sizeof *bs);
 flo_t *pl = malloc((np ? np : 1) * 8 * sizeof *pl);
 char *aw = malloc(n ? n : 1);
 uintptr_t *cn = malloc((n ? n : 1) * sizeof *cn);
 uintptr_t const nfl = tray_nelem(tray(Sp[3]));
 flo_t *fl = malloc(nfl * sizeof *fl);
 struct tface *Fs = 0;
 uintptr_t nf = 0;
 struct tset S = { 0 };
 struct tgrid G = { 0 };
 int good = bs && pl && aw && cn && fl && tb_ginit(&G, n);
 if (good) {
  // ..the faces: their count, then each laid as tb_face reads it
  for (uintptr_t i = 0; i < nfl; i++) fl[i] = tray_get_flo(tray(Sp[3]), i);
  nf = fl[0] > 0.0 ? (uintptr_t) fl[0] : 0;
  Fs = malloc((nf ? nf : 1) * sizeof *Fs);
  good = Fs != 0;
  for (uintptr_t i = 0, at = 1; good && i < nf; i++) {
   struct tface *F = Fs + i;
   if (at + 10 > nfl) { good = 0; break; }
   F->np = (uintptr_t) fl[at], F->ne = (uintptr_t) fl[at + 1], F->n = fl + at + 2, F->d = fl[at + 5], F->c = fl + at + 6, F->rad = fl[at + 9];
   F->ps = fl + at + 10, F->es = F->ps + 3 * F->np;
   at += 10 + 3 * F->np + 10 * F->ne;
   if (at > nfl || F->np < 1) good = 0; } }
 if (good) {
  for (uintptr_t i = 0; i < np * 8; i++) pl[i] = tray_get_flo(tray(Sp[1]), i);
  struct tray *const to = tray(Sp[2]);
  v3 const g = { tray_get_flo(to, 0), tray_get_flo(to, 1), tray_get_flo(to, 2) };
  flo_t const dt = tray_get_flo(to, 3);
  intptr_t steps = (intptr_t) (dt / tb_h + 0.999);
  if (steps < 1) steps = 1;
  for (uintptr_t i = 0; i < n; i++) tb_load(bs + i, d + i * tb_nb);
  for (intptr_t s = 0; s < steps && good; s++) good = tb_sub(bs, n, pl, np, Fs, nf, g, dt / (flo_t) steps, &S, &G, aw, cn);
  for (uintptr_t i = 0; i < n; i++) tb_keep(d + i * tb_nb, bs + i); }
 tb_gfree(&G), free(S.c), free(Fs), free(fl), free(cn), free(aw), free(pl), free(bs);
 love_musttail return Answerp(3, good ? word(o) : ZeroPoint); }

LvDef("tumble-step", tumble_step, 4, "lore");
