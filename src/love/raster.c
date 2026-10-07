// raster -- triangles onto a frame of pixels, the way a ps1 drew them: vertex colours, small
// textures sampled nearest, a depth buffer, linear fog, and the era's quirks on request.
// (facets w h base mat verts tris texs opts) answers an [h w] tray of 0xrrggbb.
//  base   the ground: a tray of w*h colours, or one colour
//  mat    16 numbers, row-major: clip = mat * [x y z 1], gl's clip box (-w <= x,y,z <= w)
//  verts  8 numbers a vertex: x y z  u v (texels)  r g b (1.0 the texel as it is)
//  tris   4 a triangle: three vertex indices and a texture's index, -1 for none, -2 for a
//         glow: its colour added to what is behind it, hidden by what is nearer, hiding
//         nothing (so drawn after what it lies over); verts
//         and tris may be lists of batches, pairwise, each batch's tris its own verts
//  texs   a list of textures, each an [h w] tray of colours (one below 0 is a hole) or a
//         list of them, each level half the last
//  opts   fog r g b, fog near, fog far (view depth), flags: 1 affine, 2 snap, 4 dither, 8 cull,
//         16 depth (the answer the depth buffer, [h w] floats, 2 where nothing was drawn);
//         and an exposure k, a colour c 0 to 255 shown as 255 (1 - e^(-k c / 255)), 0 none;
//         and a shadow's bias, in the sun's depth
//         or a list (opts sun depth): the verts then 11 a vertex, the r g b of the light
//         from everywhere but the sun and then the sun's, which a pixel takes as much of as
//         sun, 16 numbers, and depth, a depth answer through sun, say it sees past
#include "love.h"
#if Bits == 64
double lm_exp(double);
#define rz_exp lm_exp
#else
float lm_expf(float);
#define rz_exp lm_expf
#endif

enum { rz_affine = 1, rz_snap = 2, rz_dither = 4, rz_cull = 8, rz_depth = 16, rz_lv = 8, rz_tn = 256,
       rz_na = 11 };   // the riders: u v, r g b, the sun's r g b, and the place as the sun sees it
// a vertex in clip space with what rides on it; once projected x y are pixels and z ndc
struct rz_v { flo_t x, y, z, w, a[rz_na]; };
struct rz_tex { intptr_t const *px; intptr_t w, h; };
struct rz {
 intptr_t W, H, flags, stride, add;
 flo_t const *m;
 flo_t lm[16], bias;     // the sun's view, when there is one, and its depth answer
 flo_t const *sm;
 intptr_t SW, SH;
 flo_t fog[5], tone;
 flo_t tl[rz_tn + 2];   // the tone at k c / 255 = i / 32, 0 to 8, eased between
 intptr_t *out;
 flo_t *depth;
 struct rz_tex lv[rz_lv];
 int nlv; };

static flo_t rz_floor(flo_t x) { flo_t t = love_trunc(x); return t > x ? t - 1 : t; }
static flo_t rz_num(struct tray *v, uintptr_t i) { return tray_get_flo(v, i); }

// texture t of the list: its levels, each a rank-2 tray of colours; none if it is not one
static int rz_level(word e, struct rz_tex *lv) {
 if (!galaxyp(e) || tray(e)->rank != 2 || tray(e)->type != love_Z || !tray(e)->shape[0] || !tray(e)->shape[1]) return 0;
 *lv = (struct rz_tex) { tray_data(tray(e)), (intptr_t) tray(e)->shape[1], (intptr_t) tray(e)->shape[0] };
 return 1; }
static int rz_levels(word texs, intptr_t t, struct rz_tex *lv) {
 for (; t > 0 && chainp(texs); t--) texs = B(texs);
 if (t < 0 || !chainp(texs)) return 0;
 word l = A(texs);
 if (!chainp(l)) return rz_level(l, lv);
 int n = 0;
 for (; chainp(l) && n < rz_lv && rz_level(A(l), lv + n); l = B(l)) n++;
 return n; }

// the ps1's ordered dither, offsets -4..3 before the drop to five bits a channel
static int const rz_bayer[16] = { -4, 0, -3, 1, 2, -2, 3, -1, -3, 1, -4, 0, 3, -1, 2, -2 };

static intptr_t rz_ch(flo_t c, int d) {
 intptr_t k = (intptr_t) (c + (flo_t) 0.5) + d;
 k = k < 0 ? 0 : k > 255 ? 255 : k;
 return d ? (k & 0xf8) | (k >> 5) : k; }

// how much of the sun a place reaches, as it sees it: four of its depths about the place,
// each passed or not, eased between; off its edge, all of it
static flo_t rz_lit(struct rz const *r, intptr_t i, intptr_t j, flo_t z) {
 return i < 0 || j < 0 || i >= r->SW || j >= r->SH || z <= r->sm[j * r->SW + i] ? 1 : 0; }
static flo_t rz_vis(struct rz const *r, flo_t lx, flo_t ly, flo_t lz) {
 flo_t const sx = (lx * (flo_t) 0.5 + (flo_t) 0.5) * (flo_t) r->SW - (flo_t) 0.5,
             sy = ((flo_t) 0.5 - ly * (flo_t) 0.5) * (flo_t) r->SH - (flo_t) 0.5,
             fi = rz_floor(sx), fj = rz_floor(sy), fx = sx - fi, fy = sy - fj, z = lz - r->bias;
 intptr_t const i = (intptr_t) fi, j = (intptr_t) fj;
 flo_t const t0 = rz_lit(r, i, j, z) + (rz_lit(r, i + 1, j, z) - rz_lit(r, i, j, z)) * fx,
             t1 = rz_lit(r, i, j + 1, z) + (rz_lit(r, i + 1, j + 1, z) - rz_lit(r, i, j + 1, z)) * fx;
 return t0 + (t1 - t0) * fy; }

// one screen triangle. edges in sixteenths of a pixel, exact, so a shared edge's pixels fall
// to one side of it only; the planes of z, 1/w and the riders (over w unless affine)
static void rz_tri(struct rz *r, struct rz_v const *p0, struct rz_v const *p1, struct rz_v const *p2,
                   struct rz_tex const *lv, int nlv) {
 struct rz_v const *P[3] = { p0, p1, p2 };
 int64_t X[3], Y[3];
 for (int i = 0; i < 3; i++)
  X[i] = (int64_t) rz_floor(P[i]->x * 16 + (flo_t) 0.5), Y[i] = (int64_t) rz_floor(P[i]->y * 16 + (flo_t) 0.5);
 int64_t A = (X[1] - X[0]) * (Y[2] - Y[0]) - (X[2] - X[0]) * (Y[1] - Y[0]);
 if (A == 0) return;
 if (A > 0 && (r->flags & rz_cull)) return;   // anticlockwise in gl's y-up faces the eye,
 if (A < 0) {                                  // and is clockwise on the screen's y-down
  struct rz_v const *t = P[1]; P[1] = P[2], P[2] = t;
  int64_t u = X[1]; X[1] = X[2], X[2] = u;
  u = Y[1], Y[1] = Y[2], Y[2] = u, A = -A; }
 p0 = P[0], p1 = P[1], p2 = P[2];
 flo_t const x0f = (flo_t) X[0] / 16, y0f = (flo_t) Y[0] / 16,
             dx1 = (flo_t) (X[1] - X[0]) / 16, dy1 = (flo_t) (Y[1] - Y[0]) / 16,
             dx2 = (flo_t) (X[2] - X[0]) / 16, dy2 = (flo_t) (Y[2] - Y[0]) / 16, Af = (flo_t) A / 256;
 int const persp = !(r->flags & rz_affine);
 // the attribute planes: value at p0, step a pixel right, step a row down
 flo_t v0[2 + rz_na], vx[2 + rz_na], vy[2 + rz_na], e1[2 + rz_na], e2[2 + rz_na];
 v0[0] = p0->z, e1[0] = p1->z, e2[0] = p2->z;
 v0[1] = 1 / p0->w, e1[1] = 1 / p1->w, e2[1] = 1 / p2->w;
 for (int k = 0; k < rz_na; k++) {
  v0[2 + k] = p0->a[k] * (persp ? v0[1] : 1);
  e1[2 + k] = p1->a[k] * (persp ? e1[1] : 1);
  e2[2 + k] = p2->a[k] * (persp ? e2[1] : 1); }
 for (int k = 0; k < 2 + rz_na; k++) {
  flo_t const d1 = e1[k] - v0[k], d2 = e2[k] - v0[k];
  vx[k] = (d1 * dy2 - d2 * dy1) / Af, vy[k] = (d2 * dx1 - d1 * dx2) / Af; }
 int64_t xa = X[0], xb = X[0], ya = Y[0], yb = Y[0];
 for (int i = 1; i < 3; i++) {
  xa = X[i] < xa ? X[i] : xa, xb = X[i] > xb ? X[i] : xb;
  ya = Y[i] < ya ? Y[i] : ya, yb = Y[i] > yb ? Y[i] : yb; }
 // the pixels whose centres the box holds
 int64_t bx0 = (xa + 7) >> 4, bx1 = (xb + 8) >> 4, by0 = (ya + 7) >> 4, by1 = (yb + 8) >> 4;
 bx0 = bx0 < 0 ? 0 : bx0, by0 = by0 < 0 ? 0 : by0;
 bx1 = bx1 > r->W ? r->W : bx1, by1 = by1 > r->H ? r->H : by1;
 if (bx0 >= bx1 || by0 >= by1) return;
 intptr_t const x0 = (intptr_t) bx0, x1 = (intptr_t) bx1, y0 = (intptr_t) by0, y1 = (intptr_t) by1;
 // edge i runs P[i] to P[i+1] and is above 0 on the inside; a top or a left edge owns the
 // pixels on it, the rest lose them by the bias of one
 int64_t ex[3], ey[3], ec[3];
 for (int i = 0; i < 3; i++) {
  int const j = (i + 1) % 3;
  int64_t const dx = X[j] - X[i], dy = Y[j] - Y[i];
  ex[i] = -dy * 16, ey[i] = dx * 16;
  ec[i] = dx * (8 - Y[i]) - dy * (8 - X[i]) - (dy < 0 || (dy == 0 && dx > 0) ? 0 : 1); }
 flo_t const fn = r->fog[3], ff = r->fog[4], fs = ff > fn ? 1 / (ff - fn) : 0;
 for (intptr_t y = y0; y < y1; y++) {
  flo_t const py = (flo_t) y + (flo_t) 0.5, px0 = (flo_t) x0 + (flo_t) 0.5;
  int64_t e[3];
  flo_t a[2 + rz_na];
  for (int i = 0; i < 3; i++) e[i] = ec[i] + ey[i] * (int64_t) y + ex[i] * (int64_t) x0;
  for (int k = 0; k < 2 + rz_na; k++) a[k] = v0[k] + vx[k] * (px0 - x0f) + vy[k] * (py - y0f);
  intptr_t *o = r->out + y * r->W;
  flo_t *dz = r->depth + y * r->W;
  for (intptr_t x = x0; x < x1; x++) {
   if ((e[0] | e[1] | e[2]) >= 0 && a[0] >= -1 && a[0] <= 1 && a[0] < dz[x]) {
    if (r->flags & rz_depth) dz[x] = a[0];
    else {
    flo_t const w = 1 / a[1], s = persp ? w : 1,
                sun = r->sm ? rz_vis(r, a[10] * s, a[11] * s, a[12] * s) : 1;
    flo_t c[3] = { (a[4] + a[7] * sun) * s * 255, (a[5] + a[8] * sun) * s * 255, (a[6] + a[9] * sun) * s * 255 };
    int hole = 0;
    if (nlv) {   // the level where a pixel's step crosses about a texel
     flo_t const u = a[2] * s, v = a[3] * s;
     flo_t const ux = (vx[2] - (persp ? u * vx[1] : 0)) * s, vxx = (vx[3] - (persp ? v * vx[1] : 0)) * s,
                 uy = (vy[2] - (persp ? u * vy[1] : 0)) * s, vyy = (vy[3] - (persp ? v * vy[1] : 0)) * s;
     flo_t r2 = ux * ux + vxx * vxx, ry = uy * uy + vyy * vyy;
     r2 = ry > r2 ? ry : r2;
     int L = 0;
     while (r2 > 2 && L + 1 < nlv) r2 /= 4, L++;
     struct rz_tex const *tx = lv + L;
     flo_t const us = (flo_t) 1 / (flo_t) ((intptr_t) 1 << L);
     intptr_t iu = (intptr_t) rz_floor(u * us) % tx->w, iv = (intptr_t) rz_floor(v * us) % tx->h;
     iu += iu < 0 ? tx->w : 0, iv += iv < 0 ? tx->h : 0;
     intptr_t const t = tx->px[iv * tx->w + iu];
     if (t < 0) hole = 1;
     else c[0] *= (flo_t) (t >> 16 & 255) / 255, c[1] *= (flo_t) (t >> 8 & 255) / 255, c[2] *= (flo_t) (t & 255) / 255; }
    if (!hole) {
     if (fs) {
      flo_t f = (w - fn) * fs;
      f = f < 0 ? 0 : f > 1 ? 1 : f;
      for (int k = 0; k < 3; k++) c[k] += (r->fog[k] - c[k]) * f; }
     if (r->tone > 0) for (int k = 0; k < 3; k++) {
      flo_t const x = r->tone * c[k] * (flo_t) (32.0 / 255);
      intptr_t const i = x <= 0 ? 0 : x >= rz_tn ? rz_tn : (intptr_t) x;
      flo_t const f = x <= 0 ? 0 : x - (flo_t) i;
      c[k] = r->tl[i] + (r->tl[i + 1] - r->tl[i]) * (f > 1 ? 1 : f); }
     int const d = r->flags & rz_dither ? rz_bayer[(y & 3) * 4 + (x & 3)] : 0;
     if (r->add) {   // a glow: onto what is there, the depth left as it was; bare, left bare
      intptr_t const q = o[x];
      if (q >= 0) o[x] = rz_ch(c[0] + (flo_t) (q >> 16 & 255), 0) << 16 | rz_ch(c[1] + (flo_t) (q >> 8 & 255), 0) << 8
                         | rz_ch(c[2] + (flo_t) (q & 255), 0); }
     else o[x] = rz_ch(c[0], d) << 16 | rz_ch(c[1], d) << 8 | rz_ch(c[2], d), dz[x] = a[0]; } } }
   for (int i = 0; i < 3; i++) e[i] += ex[i];
   for (int k = 0; k < 2 + rz_na; k++) a[k] += vx[k]; } } }

// clip space to pixels; snapped to whole ones on request
static void rz_project(struct rz const *r, struct rz_v *v) {
 flo_t const q = 1 / v->w;
 v->x = (v->x * q * (flo_t) 0.5 + (flo_t) 0.5) * (flo_t) r->W;
 v->y = ((flo_t) 0.5 - v->y * q * (flo_t) 0.5) * (flo_t) r->H;
 v->z = v->z * q;
 if (r->flags & rz_snap) v->x = rz_floor(v->x + (flo_t) 0.5), v->y = rz_floor(v->y + (flo_t) 0.5); }

static struct rz_v rz_lerp(struct rz_v const *a, struct rz_v const *b, flo_t t) {
 struct rz_v o;
 o.x = a->x + (b->x - a->x) * t, o.y = a->y + (b->y - a->y) * t;
 o.z = a->z + (b->z - a->z) * t, o.w = a->w + (b->w - a->w) * t;
 for (int k = 0; k < rz_na; k++) o.a[k] = a->a[k] + (b->a[k] - a->a[k]) * t;
 return o; }

// the planes a triangle is cut at, as d = (x y z w) . p >= 0: the near one, and a guard
// band far past the screen's edges, which keeps a pixel's sixteenths within an int64's reach
#define rz_guard 64
static flo_t rz_side(struct rz_v const *v, int k) {
 switch (k) {
  case 0: return v->z + v->w;
  case 1: return rz_guard * v->w - v->x;
  case 2: return rz_guard * v->w + v->x;
  case 3: return rz_guard * v->w - v->y;
  default: return rz_guard * v->w + v->y; } }

// one triangle of the list: to clip space, cut at the planes, then a fan
static void rz_draw(struct rz *r, struct tray *vt, intptr_t const ix[3], struct rz_tex const *lv, int nlv) {
 struct rz_v p[8], q[8];
 int out[6] = { 0 };
 for (int i = 0; i < 3; i++) {
  flo_t const *m = r->m;
  uintptr_t const b = (uintptr_t) (ix[i] * r->stride);
  flo_t const X = rz_num(vt, b), Y = rz_num(vt, b + 1), Z = rz_num(vt, b + 2), *l = r->lm;
  p[i].x = m[0] * X + m[1] * Y + m[2] * Z + m[3];
  p[i].y = m[4] * X + m[5] * Y + m[6] * Z + m[7];
  p[i].z = m[8] * X + m[9] * Y + m[10] * Z + m[11];
  p[i].w = m[12] * X + m[13] * Y + m[14] * Z + m[15];
  for (int k = 0; k < 8; k++) p[i].a[k] = k < r->stride - 3 ? rz_num(vt, b + 3 + (uintptr_t) k) : 0;
  p[i].a[8] = l[0] * X + l[1] * Y + l[2] * Z + l[3];
  p[i].a[9] = l[4] * X + l[5] * Y + l[6] * Z + l[7];
  p[i].a[10] = l[8] * X + l[9] * Y + l[10] * Z + l[11];
  out[0] += p[i].x < -p[i].w, out[1] += p[i].x > p[i].w, out[2] += p[i].y < -p[i].w;
  out[3] += p[i].y > p[i].w, out[4] += p[i].z < -p[i].w, out[5] += p[i].z > p[i].w; }
 for (int k = 0; k < 6; k++) if (out[k] == 3) return;
 int n = 3;
 for (int k = 0; k < 5 && n >= 3; k++) {
  int m = 0;
  for (int i = 0; i < n; i++) {
   struct rz_v const *a = p + i, *b = p + (i + 1) % n;
   flo_t const da = rz_side(a, k), db = rz_side(b, k);
   if (da >= 0) q[m++] = *a;
   if ((da >= 0) != (db >= 0)) q[m++] = rz_lerp(a, b, da / (da - db)); }
  for (int i = 0; i < m; i++) p[i] = q[i];
  n = m; }
 if (n < 3) return;
 for (int i = 0; i < n; i++) {
  if (p[i].w <= 0) return;
  rz_project(r, p + i); }
 for (int i = 1; i + 1 < n; i++) rz_tri(r, p, p + i, p + i + 1, lv, nlv); }

static flo_t rz_opt(word o, uintptr_t i, flo_t d) {
 return galaxyp(o) && i < tray_nelem(tray(o)) ? tray_get_flo(tray(o), i) : d; }

// a batch: verts and tris both trays, or both lists of them pairwise, each list's tris
// counting from its own verts
static int rz_ok(word v, word t, uintptr_t st) {
 return galaxyp(v) && galaxyp(t) && !(tray_nelem(tray(v)) % st) && !(tray_nelem(tray(t)) % 4); }
static int rz_batches(word v, word t, uintptr_t st) {
 if (rz_ok(v, t, st)) return 1;
 for (; chainp(v) && chainp(t); v = B(v), t = B(t)) if (!rz_ok(A(v), A(t), st)) return 0;
 return v == ZeroPoint && t == ZeroPoint; }

static void rz_batch(struct rz *r, struct tray *vt, struct tray *tt, word texs) {
 intptr_t const nv = (intptr_t) tray_nelem(vt) / r->stride;
 uintptr_t const nt = tray_nelem(tt) / 4;
 intptr_t ct = -1;   // the texture the last triangle used, its levels still in r->lv
 for (uintptr_t i = 0; i < nt; i++) {
  intptr_t const ix[3] = { tray_get_int(tt, 4 * i), tray_get_int(tt, 4 * i + 1), tray_get_int(tt, 4 * i + 2) },
                 t = tray_get_int(tt, 4 * i + 3);
  if (ix[0] < 0 || ix[1] < 0 || ix[2] < 0 || ix[0] >= nv || ix[1] >= nv || ix[2] >= nv) continue;
  if (t != ct) ct = t, r->nlv = t < 0 ? 0 : rz_levels(texs, t, r->lv), r->add = t == -2;
  rz_draw(r, vt, ix, r->lv, r->nlv); } }

love_noinline static struct g *host_raster(struct g *g) {
 word *a = g->sp;
 // (facets w h base mat verts tris texs opts)
 uintptr_t const st = chainp(a[7]) ? 11 : 8;
 if (!(a[0] & a[1] & 1) || !galaxyp(a[3]) || tray_nelem(tray(a[3])) < 16 || !rz_batches(a[4], a[5], st)) {
  a[0] = ZeroPoint; return g; }
 intptr_t const W = getcharm(a[0]), H = getcharm(a[1]);
 if (W < 1 || H < 1 || W > 4096 || H > 4096) { a[0] = ZeroPoint; return g; }
 uintptr_t const n = (uintptr_t) (W * H),
                 fw = b2w(tray_bytes(love_Z, 2, n)), dw = b2w(tray_bytes(love_R, 2, n));
 if (!ok(g = have(g, fw + dw))) return g;
 a = g->sp;
 struct tray *fr = ini_tray(bump(g, fw), love_Z, 2), *dp = ini_tray(bump(g, dw), love_R, 2);
 fr->shape[0] = dp->shape[0] = (uintptr_t) H, fr->shape[1] = dp->shape[1] = (uintptr_t) W;
 struct rz r = { .W = W, .H = H, .stride = (intptr_t) st, .out = tray_data(fr), .depth = tray_data(dp) };
 // the opts, and the sun's view and depths where they come as a list; read after the
 // allocation, which may move them
 word o = a[7], sv = ZeroPoint, sd = ZeroPoint;
 if (chainp(o)) {
  word const l = B(o);
  sv = chainp(l) ? A(l) : ZeroPoint, sd = chainp(l) && chainp(B(l)) ? A(B(l)) : ZeroPoint, o = A(o); }
 if (galaxyp(sv) && tray_nelem(tray(sv)) >= 16 && galaxyp(sd) && tray(sd)->rank == 2 && tray(sd)->type == love_R) {
  for (uintptr_t i = 0; i < 16; i++) r.lm[i] = tray_get_flo(tray(sv), i);
  r.sm = tray_data(tray(sd)), r.SH = (intptr_t) tray(sd)->shape[0], r.SW = (intptr_t) tray(sd)->shape[1]; }
 word const base = a[2];
 int const bt = galaxyp(base) && tray_nelem(tray(base)) >= n;
 intptr_t const bc = charmp(base) ? getcharm(base) : 0;
 for (uintptr_t i = 0; i < n; i++) r.out[i] = bt ? tray_get_int(tray(base), i) : bc, r.depth[i] = 2;
 flo_t m[16];
 for (uintptr_t i = 0; i < 16; i++) m[i] = tray_get_flo(tray(a[3]), i);
 r.m = m;
 for (uintptr_t i = 0; i < 5; i++) r.fog[i] = rz_opt(o, i, 0);
 r.flags = (intptr_t) rz_opt(o, 5, 0), r.tone = rz_opt(o, 6, 0), r.bias = rz_opt(o, 7, 0);
 if (r.tone > 0) for (int i = 0; i < rz_tn + 2; i++)
  r.tl[i] = 255 * (1 - rz_exp(-(flo_t) (i < rz_tn ? i : rz_tn) / 32));
 if (galaxyp(a[4])) rz_batch(&r, tray(a[4]), tray(a[5]), a[6]);
 else for (word v = a[4], t = a[5]; chainp(v); v = B(v), t = B(t)) rz_batch(&r, tray(A(v)), tray(A(t)), a[6]);
 a[0] = r.flags & rz_depth ? word(dp) : word(fr);
 return g; }
static lvm(lvm_raster) { LvmCallp(g, 7, host_raster) }

// (frame-bytes f kind s): a frame of colours as bytes, each pixel an s by s square --
// kind 0 r g b, 1 b g r x (an xrgb word, little-endian), 2 the r g b in base64
static uintptr_t rz_out(struct tray *f, intptr_t kind, intptr_t s, uint8_t *o) {
 static char const abc[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
 uintptr_t const H = f->rank == 2 ? f->shape[0] : 1, W = f->rank == 2 ? f->shape[1] : f->shape[0];
 uintptr_t const per = kind == 1 ? 4 : 3, raw = W * H * per * (uintptr_t) (s * s);
 if (!o) return kind == 2 ? (raw + 2) / 3 * 4 : raw;
 uint32_t acc = 0, got = 0;
 uintptr_t at = 0;
 for (uintptr_t y = 0; y < H * (uintptr_t) s; y++)
  for (uintptr_t x = 0; x < W * (uintptr_t) s; x++) {
   uint32_t const c = (uint32_t) tray_get_int(f, y / (uintptr_t) s * W + x / (uintptr_t) s);
   uint8_t const b[4] = { (uint8_t) (c >> 16), (uint8_t) (c >> 8), (uint8_t) c, 0 },
                 x4[4] = { (uint8_t) c, (uint8_t) (c >> 8), (uint8_t) (c >> 16), 0 };
   for (uintptr_t k = 0; k < per; k++) {
    uint8_t const v = kind == 1 ? x4[k] : b[k];
    if (kind != 2) { o[at++] = v; continue; }
    acc = acc << 8 | v;
    if (++got == 3) {
     o[at++] = (uint8_t) abc[acc >> 18 & 63], o[at++] = (uint8_t) abc[acc >> 12 & 63];
     o[at++] = (uint8_t) abc[acc >> 6 & 63], o[at++] = (uint8_t) abc[acc & 63], acc = got = 0; } } }
 if (got) {
  acc <<= 8 * (3 - got);
  o[at++] = (uint8_t) abc[acc >> 18 & 63], o[at++] = (uint8_t) abc[acc >> 12 & 63];
  o[at++] = got == 2 ? (uint8_t) abc[acc >> 6 & 63] : '=', o[at++] = '='; }
 return at; }

love_noinline static struct g *host_frame_bytes(struct g *g) {
 word *a = g->sp;
 if (!galaxyp(a[0]) || tray(a[0])->rank > 2 || !(a[1] & a[2] & 1)) { a[0] = ZeroPoint; return g; }
 intptr_t const kind = getcharm(a[1]), s = getcharm(a[2]);
 if (kind < 0 || kind > 2 || s < 1 || s > 16) { a[0] = ZeroPoint; return g; }
 uintptr_t const n = rz_out(tray(a[0]), kind, s, 0);
 if (!ok(g = have(g, str_width(n)))) return g;
 a = g->sp;
 struct str *o = ini_str(bump(g, str_width(n)), n);
 rz_out(tray(a[0]), kind, s, (uint8_t*) txt(o));
 a[0] = word(o);
 return g; }
static lvm(lvm_frame_bytes) { LvmCallp(g, 2, host_frame_bytes) }

static union u const nif_facets[] = {{lvm_cur}, {.x = putcharm(8)}, {lvm_raster}, {lvm_ret0}},
  nif_frame_bytes[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_frame_bytes}, {lvm_ret0}};
LvNif("facets", nif_facets, NULL);
LvNif("frame-bytes", nif_frame_bytes, NULL);
