// raster -- triangles onto a frame of pixels as a ps1 drew them: vertex colours, nearest
// texels, a depth buffer, linear fog, the era's quirks on request
// (facets w h base mat verts tris texs opts) answers an [h w] tray of 0xrrggbb.
//  base   the ground: a tray of w*h colours, or one colour; or [ground cs ds], cs and ds a
//         smaller frame's colours and depths through the same mat, cw by ch, row by row:
//         each pixel the one over it, where that drew, else the ground
//  mat    16 numbers, row-major: clip = mat * [x y z 1], gl's clip box (-w <= x,y,z <= w)
//  verts  8 numbers a vertex: x y z  u v (texels)  r g b (1.0 the texel as it is)
//  tris   4 a triangle: three vertex indices and a texture's index, -1 none, -2 a glow
//         (added to what is behind, hiding nothing: drawn after what it lies over; on a bare
//         pixel kept as -1 less its colour, and added to what is drawn under it), -3 - t
//         glass of texture t (what is behind times its texel, its colour added, hiding nothing);
//         verts and tris may be lists of batches, pairwise
//  texs   a list of textures, each an [h w] tray of colours (one below 0 is a hole) or a
//         list of them, each level half the last
//  opts   fog r g b, fog near, fog far (view depth), flags: 1 affine, 2 snap, 4 dither, 8 cull,
//         16 depth (the answer the depth buffer, [h w] floats, 2 where nothing was drawn),
//         32 under (drawn only where the base is bare, below 0: a sky after the scene),
//         64 flat (the colours answered as one row of w*h, not [h w]);
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

enum { rz_affine = 1, rz_snap = 2, rz_dither = 4, rz_cull = 8, rz_depth = 16, rz_under = 32, rz_flat = 64, rz_lv = 8 * sizeof(word), rz_tn = 256,
       rz_na = 11,   // the riders: u v, r g b, the sun's r g b, and the place as the sun sees it
       rz_par = 32768, rz_band = 32, rz_pv = 9 };   // a frame big enough to share, in bands of rows
                       // rz_lv: a level halves, so a word's bits hold every chain
// a vertex in clip space and its riders; once projected x y are pixels and z ndc
struct rz_v { flo_t x, y, z, w, a[rz_na]; };
struct rz_tex { intptr_t const *px; intptr_t w, h, mw, mh; };   // m: a side less one, when a power of two
struct rz {
 intptr_t W, H, flags, stride, add, glass;
 flo_t const *m;
 flo_t lm[16], bias;     // the sun's view, when there is one, and its depth answer
 flo_t const *sm;
 intptr_t SW, SH;
 flo_t fog[5], tone;
 flo_t tl[rz_tn + 2];   // the tone at k c / 255 = i / 32, 0 to 8, eased between
 int32_t *out;           // the frame drawn four bytes a pixel, then laid into ans a word each
 float *depth;
 void *ans;
 flo_t *tz;             // each 8 by 8 tile's farthest depth, then whether it was drawn on since
 intptr_t TW, TH;
 flo_t *pv;              // the vertices once through m and lm, rz_pv a vertex: x y z w, the sun's x y z, bits, row
 intptr_t nth, ylo, yhi; // the bands the frame is in, and this one's rows
 word base, vs, ts, tx;  // the ground, the batches, the textures
 intptr_t const *cc;     // a smaller frame laid first, cw by ch, its colours and depths
 flo_t const *cd;
 intptr_t cw, ch;
 struct rz_tex lv[rz_lv];
 int nlv; };

static flo_t rz_floor(flo_t x) { flo_t t = love_trunc(x); return t > x ? t - 1 : t; }
static love_inline intptr_t rz_ifloor(flo_t x) { intptr_t const i = (intptr_t) x; return i - (x < (flo_t) i); }
static love_inline flo_t rz_num(struct tray *v, uintptr_t i) { return tray_get_flo(v, i); }

// texture t of the list: its levels, each a rank-2 tray of colours; none if it is not one
static int rz_level(word e, struct rz_tex *lv) {
 if (!galaxyp(e) || tray(e)->rank != 2 || tray(e)->type != love_Z || !tray(e)->shape[0] || !tray(e)->shape[1]) return 0;
 intptr_t const w = (intptr_t) tray(e)->shape[1], h = (intptr_t) tray(e)->shape[0];
 *lv = (struct rz_tex) { tray_data(tray(e)), w, h, w & (w - 1) ? 0 : w - 1, h & (h - 1) ? 0 : h - 1 };
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

// how much sun a place gets: four sun depths about it, eased between; off the edge, all
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

// the first row from y on that is this worker's
static love_inline intptr_t rz_own(struct rz const *r, intptr_t y) {
 return y < r->ylo ? r->ylo : y < r->yhi ? y : r->H; }

// one screen triangle, edges exact in sixteenths so a shared edge's pixels fall to one side;
// riders over w unless affine
static void rz_tri(struct rz *r, struct rz_v const *p0, struct rz_v const *p1, struct rz_v const *p2,
                   struct rz_tex const *lv, int nlv) {
 struct rz_v const *P[3] = { p0, p1, p2 };
 int64_t X[3], Y[3];
 for (int i = 0; i < 3; i++)
  X[i] = (intptr_t) rz_floor(P[i]->x * 16 + (flo_t) 0.5), Y[i] = (intptr_t) rz_floor(P[i]->y * 16 + (flo_t) 0.5);   // in the guard band: a word
 int64_t A = (X[1] - X[0]) * (Y[2] - Y[0]) - (X[2] - X[0]) * (Y[1] - Y[0]);
 if (A == 0) return;
 if (A > 0 && (r->flags & rz_cull)) return;   // anticlockwise in gl's y-up faces the eye,
 if (A < 0) {                                  // and is clockwise on the screen's y-down
  struct rz_v const *t = P[1]; P[1] = P[2], P[2] = t;
  int64_t u = X[1]; X[1] = X[2], X[2] = u;
  u = Y[1], Y[1] = Y[2], Y[2] = u, A = -A; }
 p0 = P[0], p1 = P[1], p2 = P[2];
 // the pixels whose centres the box holds: none, and done before any plane
 int64_t xa = X[0], xb = X[0], ya = Y[0], yb = Y[0];
 for (int i = 1; i < 3; i++) {
  xa = X[i] < xa ? X[i] : xa, xb = X[i] > xb ? X[i] : xb;
  ya = Y[i] < ya ? Y[i] : ya, yb = Y[i] > yb ? Y[i] : yb; }
 int64_t bx0 = (xa + 7) >> 4, bx1 = (xb + 8) >> 4, by0 = (ya + 7) >> 4, by1 = (yb + 8) >> 4;
 bx0 = bx0 < 0 ? 0 : bx0, by0 = by0 < 0 ? 0 : by0;
 bx1 = bx1 > r->W ? r->W : bx1, by1 = by1 > r->H ? r->H : by1;
 if (bx0 >= bx1 || by0 >= by1 || rz_own(r, (intptr_t) by0) >= (intptr_t) by1) return;   // ..or none of them this worker's
 { // ..or behind all that is drawn on every tile it covers, as near as its nearest corner
  flo_t const zn = p0->z < p1->z ? (p0->z < p2->z ? p0->z : p2->z) : (p1->z < p2->z ? p1->z : p2->z);
  intptr_t const ty1 = ((intptr_t) by1 < r->yhi ? (intptr_t) by1 - 1 : r->yhi - 1) >> 3, tx0 = (intptr_t) bx0 >> 3, tx1 = (intptr_t) (bx1 - 1) >> 3;
  int seen = 0;
  for (intptr_t ty = rz_own(r, (intptr_t) by0) >> 3; ty <= ty1 && !seen; ty++)
   for (intptr_t tx = tx0; tx <= tx1 && !seen; tx++) seen = r->tz[ty * r->TW + tx] > zn;
  if (!seen) return; }
 flo_t const x0f = (flo_t) (intptr_t) X[0] / 16, y0f = (flo_t) (intptr_t) Y[0] / 16,
             dx1 = (flo_t) (intptr_t) (X[1] - X[0]) / 16, dy1 = (flo_t) (intptr_t) (Y[1] - Y[0]) / 16,
             dx2 = (flo_t) (intptr_t) (X[2] - X[0]) / 16, dy2 = (flo_t) (intptr_t) (Y[2] - Y[0]) / 16, Af = (flo_t) A / 256;
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
 int lit = 0, under = r->flags & rz_under;   // the sun's view is asked only where some of the sun falls
 for (int i = 0; i < 3; i++) lit |= P[i]->a[5] != 0 || P[i]->a[6] != 0 || P[i]->a[7] != 0;
 int const shade = lit && r->sm,
           // ..and a pixel steps only the planes it reads
           nk = shade ? 2 + rz_na : lit ? 10 : 7;
 for (intptr_t y = rz_own(r, y0); y < y1; y = rz_own(r, y + 1)) {
  // the row's run inside all three edges, found by exact division: the box outside is never walked
  intptr_t xs = x0, xe = x1;
  for (int i = 0; i < 3; i++) {
   int64_t const c = ec[i] + ey[i] * (int64_t) y;
   if (ex[i] > 0) { int64_t const m = c >= 0 ? 0 : (-c + ex[i] - 1) / ex[i]; xs = m > xs ? (intptr_t) m : xs; }
   else if (ex[i] < 0) { int64_t const m = c < 0 ? 0 : c / -ex[i] + 1; xe = m < xe ? (intptr_t) m : xe; }
   else if (c < 0) xe = xs; }
  if (xs >= xe) continue;
  flo_t const py = (flo_t) y + (flo_t) 0.5, px0 = (flo_t) xs + (flo_t) 0.5;
  flo_t a[2 + rz_na];
  for (int k = 0; k < 2 + rz_na; k++) a[k] = v0[k] + vx[k] * (px0 - x0f) + vy[k] * (py - y0f);
  int L = 0;   // the texture's level, asked again every eighth pixel, and its texels one of the first's
  flo_t us = 1;
  int32_t *o = r->out + y * r->W;
  float *dz = r->depth + y * r->W;
  flo_t *td = r->tz + r->TW * r->TH + (y >> 3) * r->TW;
  for (intptr_t x = xs; x < xe; x++) {
   float const z = (float) a[0];
   if (a[0] >= -1 && a[0] <= 1 && z < dz[x] && !(under && o[x] >= 0)) {   // inside all three edges: the run is exact
    if (r->flags & rz_depth) dz[x] = z, td[x >> 3] = 1;
    else {
    flo_t const w = 1 / a[1], s = persp ? w : 1,
                sun = shade ? rz_vis(r, a[10] * s, a[11] * s, a[12] * s) : 1;
    flo_t c[3] = { (a[4] + a[7] * sun) * s * 255, (a[5] + a[8] * sun) * s * 255, (a[6] + a[9] * sun) * s * 255 };
    int hole = 0;
    flo_t tint[3] = { 1, 1, 1 };
    if (nlv) {   // the level where a pixel's step crosses about a texel
     flo_t const u = a[2] * s, v = a[3] * s;
     if (nlv > 1 && !((x - xs) & 7)) {   // ..one level alone is that one
      L = 0;
      flo_t const ux = (vx[2] - (persp ? u * vx[1] : 0)) * s, vxx = (vx[3] - (persp ? v * vx[1] : 0)) * s,
                  uy = (vy[2] - (persp ? u * vy[1] : 0)) * s, vyy = (vy[3] - (persp ? v * vy[1] : 0)) * s;
      flo_t r2 = ux * ux + vxx * vxx, ry = uy * uy + vyy * vyy;
      r2 = ry > r2 ? ry : r2;
      while (r2 > 2 && L + 1 < nlv) r2 /= 4, L++;
      us = (flo_t) 1 / (flo_t) ((intptr_t) 1 << L); }
     struct rz_tex const *tx = lv + L;
     intptr_t iu = rz_ifloor(u * us), iv = rz_ifloor(v * us);
     if (tx->mw) iu &= tx->mw;   // wrapped, by a mask where a side is a power of two
     else if ((uintptr_t) iu >= (uintptr_t) tx->w) iu %= tx->w, iu += iu < 0 ? tx->w : 0;
     if (tx->mh) iv &= tx->mh;
     else if ((uintptr_t) iv >= (uintptr_t) tx->h) iv %= tx->h, iv += iv < 0 ? tx->h : 0;
     intptr_t const t = tx->px[iv * tx->w + iu];
     if (t < 0) hole = 1;
     else if (r->glass) tint[0] = (flo_t) (t >> 16 & 255) / 255, tint[1] = (flo_t) (t >> 8 & 255) / 255, tint[2] = (flo_t) (t & 255) / 255;
     else c[0] *= (flo_t) (t >> 16 & 255) / 255, c[1] *= (flo_t) (t >> 8 & 255) / 255, c[2] *= (flo_t) (t & 255) / 255; }
    if (!hole) {
     if (fs) {   // glass fades clear, what is behind it fogged already
      flo_t f = (w - fn) * fs;
      f = f < 0 ? 0 : f > 1 ? 1 : f;
      for (int k = 0; k < 3; k++)
       if (r->glass) c[k] -= c[k] * f, tint[k] += (1 - tint[k]) * f;
       else c[k] += (r->fog[k] - c[k]) * f; }
     if (r->tone > 0) for (int k = 0; k < 3; k++) {
      flo_t const x = r->tone * c[k] * (flo_t) (32.0 / 255);
      intptr_t const i = x <= 0 ? 0 : x >= rz_tn ? rz_tn : (intptr_t) x;
      flo_t const f = x <= 0 ? 0 : x - (flo_t) i;
      c[k] = r->tl[i] + (r->tl[i + 1] - r->tl[i]) * (f > 1 ? 1 : f); }
     int const d = r->flags & rz_dither ? rz_bayer[(y & 3) * 4 + (x & 3)] : 0;
     if (r->glass) {   // glass: what is there through its tint, its sheen on it; bare, left bare
      int32_t const q = o[x];
      if (q >= 0) o[x] = (int32_t) (rz_ch((flo_t) (q >> 16 & 255) * tint[0] + c[0], 0) << 16 | rz_ch((flo_t) (q >> 8 & 255) * tint[1] + c[1], 0) << 8
                                    | rz_ch((flo_t) (q & 255) * tint[2] + c[2], 0)); }
     else if (r->add) {   // a glow: onto what is there, the depth left as it was; bare, kept as -1 less it
      int32_t const q = o[x], g = q >= 0 ? q : -1 - q,
                    s = (int32_t) (rz_ch(c[0] + (flo_t) (g >> 16 & 255), 0) << 16 | rz_ch(c[1] + (flo_t) (g >> 8 & 255), 0) << 8
                                   | rz_ch(c[2] + (flo_t) (g & 255), 0));
      o[x] = q >= 0 ? s : -1 - s; }
     else {   // ..and drawn under, onto a glow kept there
      int32_t const g = under && o[x] < -1 ? -1 - o[x] : 0;
      o[x] = (int32_t) (rz_ch(c[0] + (flo_t) (g >> 16 & 255), d) << 16 | rz_ch(c[1] + (flo_t) (g >> 8 & 255), d) << 8
                        | rz_ch(c[2] + (flo_t) (g & 255), d)), dz[x] = z, td[x >> 3] = 1; } } } }
   for (int k = 0; k < 7; k++) a[k] += vx[k];
   if (nk > 7) for (int k = 7; k < 10; k++) a[k] += vx[k];
   if (nk > 10) for (int k = 10; k < 2 + rz_na; k++) a[k] += vx[k]; } } }

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

// cut planes, d = (x y z w) . p >= 0: near, and a guard band that keeps sixteenths in an int64
#define rz_guard 64
#define rz_side_max ((intptr_t) 1 << 20)   // a frame's side: the edge sums, near 2^21 side^2, stay in reach
static flo_t rz_side(struct rz_v const *v, int k) {
 switch (k) {
  case 0: return v->z + v->w;
  case 1: return rz_guard * v->w - v->x;
  case 2: return rz_guard * v->w + v->x;
  case 3: return rz_guard * v->w - v->y;
  default: return rz_guard * v->w + v->y; } }

// a batch's vertices through the view and the sun's, once each, into pv: outside planes as
// bits, 64 once inside every cut, then its screen row
static void rz_verts(struct rz const *r, struct tray *vt, intptr_t nv, flo_t *pv) {
 flo_t const *m = r->m, *l = r->lm;
 for (intptr_t i = 0; i < nv; i++) {
  uintptr_t const b = (uintptr_t) (i * r->stride);
  flo_t const X = rz_num(vt, b), Y = rz_num(vt, b + 1), Z = rz_num(vt, b + 2);
  flo_t *o = pv + rz_pv * i;
  flo_t const x = m[0] * X + m[1] * Y + m[2] * Z + m[3], y = m[4] * X + m[5] * Y + m[6] * Z + m[7],
              z = m[8] * X + m[9] * Y + m[10] * Z + m[11], w = m[12] * X + m[13] * Y + m[14] * Z + m[15];
  o[0] = x, o[1] = y, o[2] = z, o[3] = w;
  o[4] = l[0] * X + l[1] * Y + l[2] * Z + l[3];
  o[5] = l[4] * X + l[5] * Y + l[6] * Z + l[7];
  o[6] = l[8] * X + l[9] * Y + l[10] * Z + l[11];
  struct rz_v const v = { .x = x, .y = y, .z = z, .w = w };
  int in = w > 0;
  for (int k = 0; k < 5; k++) in &= rz_side(&v, k) >= 0;
  o[7] = (flo_t) ((x < -w) | (x > w) << 1 | (y < -w) << 2 | (y > w) << 3 | (z < -w) << 4 | (z > w) << 5 | in << 6);
  o[8] = in ? ((flo_t) 0.5 - y / w * (flo_t) 0.5) * (flo_t) r->H : 0; } }

// one triangle of the list: its vertices from rz_verts, cut at the planes, then a fan
static void rz_draw(struct rz *r, struct tray *vt, intptr_t const ix[3], struct rz_tex const *lv, int nlv) {
 flo_t const *P[3] = { r->pv + rz_pv * ix[0], r->pv + rz_pv * ix[1], r->pv + rz_pv * ix[2] };
 int const o0 = (int) P[0][7], o1 = (int) P[1][7], o2 = (int) P[2][7];
 if (o0 & o1 & o2 & 63) return;   // all outside one plane
 if (r->nth > 1 && o0 & o1 & o2 & 64) {   // ..or, uncut, on no row of this worker's, a row's slack either side
  flo_t lo = P[0][8], hi = P[0][8];
  for (int i = 1; i < 3; i++) lo = P[i][8] < lo ? P[i][8] : lo, hi = P[i][8] > hi ? P[i][8] : hi;
  intptr_t const y0 = lo > 1 ? (intptr_t) lo - 1 : 0;
  if ((flo_t) rz_own(r, y0) > hi + 1) return; }
 struct rz_v p[8], q[8];
 for (int i = 0; i < 3; i++) {
  uintptr_t const b = (uintptr_t) (ix[i] * r->stride);
  p[i].x = P[i][0], p[i].y = P[i][1], p[i].z = P[i][2], p[i].w = P[i][3];
  for (int k = 0; k < 8; k++) p[i].a[k] = k < r->stride - 3 ? rz_num(vt, b + 3 + (uintptr_t) k) : 0;
  p[i].a[8] = P[i][4], p[i].a[9] = P[i][5], p[i].a[10] = P[i][6]; }
 // a triangle inside every plane passes the cuts unchanged, so it skips them
 int n = 3, in = 1;
 for (int k = 0; k < 5 && in; k++)
  for (int i = 0; i < 3; i++) in &= rz_side(p + i, k) >= 0;
 for (int k = 0; k < 5 && n >= 3 && !in; k++) {
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

// a batch: verts and tris both trays, or lists of them pairwise
static int rz_ok(word v, word t, uintptr_t st) {
 return galaxyp(v) && galaxyp(t) && !(tray_nelem(tray(v)) % st) && !(tray_nelem(tray(t)) % 4); }
static int rz_batches(word v, word t, uintptr_t st) {
 if (rz_ok(v, t, st)) return 1;
 for (; chainp(v) && chainp(t); v = B(v), t = B(t)) if (!rz_ok(A(v), A(t), st)) return 0;
 return v == ZeroPoint && t == ZeroPoint; }

// the tiles of this worker's rows drawn on since last, each its farthest depth again
static void rz_tiles(struct rz *r) {
 flo_t *td = r->tz + r->TW * r->TH;
 for (intptr_t ty = rz_own(r, 0) >> 3; ty < r->TH && ty * 8 < r->yhi; ty++)
  for (intptr_t tx = 0; tx < r->TW; tx++) {
   if (!td[ty * r->TW + tx]) continue;
   td[ty * r->TW + tx] = 0;
   flo_t m = -2;
   intptr_t const x1 = tx * 8 + 8 < r->W ? tx * 8 + 8 : r->W, y1 = ty * 8 + 8 < r->H ? ty * 8 + 8 : r->H;
   for (intptr_t y = ty * 8; y < y1; y++)
    for (intptr_t x = tx * 8; x < x1; x++) m = r->depth[y * r->W + x] > m ? r->depth[y * r->W + x] : m;
   r->tz[ty * r->TW + tx] = m; } }

static void rz_batch(struct rz *r, struct tray *vt, struct tray *tt, word texs) {
 intptr_t const nv = (intptr_t) tray_nelem(vt) / r->stride;
 uintptr_t const nt = tray_nelem(tt) / 4;
 intptr_t ct = -1;   // the texture the last triangle used, its levels still in r->lv
 r->nlv = 0, r->add = 0, r->glass = 0;   // not the last batch's
 for (uintptr_t i = 0; i < nt; i++) {
  intptr_t const ix[3] = { tray_get_int(tt, 4 * i), tray_get_int(tt, 4 * i + 1), tray_get_int(tt, 4 * i + 2) },
                 t = tray_get_int(tt, 4 * i + 3);
  if (ix[0] < 0 || ix[1] < 0 || ix[2] < 0 || ix[0] >= nv || ix[1] >= nv || ix[2] >= nv) continue;
  if (t != ct) ct = t, r->glass = t <= -3, r->nlv = rz_levels(texs, r->glass ? -3 - t : t, r->lv), r->add = t == -2;
  rz_draw(r, vt, ix, r->lv, r->nlv);
  if ((i & 255) == 255) rz_tiles(r); }
 rz_tiles(r); }

// each batch's vertices put through, one after another in pv
static void rz_prep(struct rz const *r) {
 flo_t *pv = r->pv;
 if (galaxyp(r->vs)) rz_verts(r, tray(r->vs), (intptr_t) tray_nelem(tray(r->vs)) / r->stride, pv);
 else for (word v = r->vs; chainp(v); v = B(v)) {
  intptr_t const nv = (intptr_t) tray_nelem(tray(A(v))) / r->stride;
  rz_verts(r, tray(A(v)), nv, pv), pv += rz_pv * nv; } }

// a worker's share of the frame: its rows laid with the ground, then every batch drawn on them,
// then laid out a word a pixel. drawn under, a pixel not bare stands nearest of all, so a tile
// with none bare turns every triangle away before its rows are walked
static void rz_run(struct rz *r) {
 int const bt = galaxyp(r->base) && tray_nelem(tray(r->base)) >= (uintptr_t) (r->W * r->H), under = (r->flags & rz_under) != 0;
 intptr_t const bc = charmp(r->base) ? getcharm(r->base) : 0;
 for (intptr_t y = rz_own(r, 0); y < r->H; y = rz_own(r, y + 1))
  for (intptr_t i = y * r->W, e = i + r->W; i < e; i++) {
   r->out[i] = (int32_t) (bt ? tray_get_int(tray(r->base), (uintptr_t) i) : bc), r->depth[i] = 2;
   if (r->cc) {
    intptr_t const j = y * r->ch / r->H * r->cw + (i - y * r->W) * r->cw / r->W;
    if (r->cd[j] < 2) r->out[i] = (int32_t) r->cc[j], r->depth[i] = (float) r->cd[j]; }
   if (under && r->out[i] >= 0) r->depth[i] = -2; }
 int const laid = under || r->cc;   // ..the tiles' farthest asked of what was laid, else all far
 for (intptr_t ty = rz_own(r, 0) >> 3; ty < r->TH && ty * 8 < r->yhi; ty++)
  for (intptr_t tx = 0; tx < r->TW; tx++) r->tz[ty * r->TW + tx] = 2, r->tz[r->TW * r->TH + ty * r->TW + tx] = laid;
 if (laid) rz_tiles(r);
 flo_t *const pv = r->pv;
 if (galaxyp(r->vs)) rz_batch(r, tray(r->vs), tray(r->ts), r->tx);
 else for (word v = r->vs, t = r->ts; chainp(v); v = B(v), t = B(t))
  rz_batch(r, tray(A(v)), tray(A(t)), r->tx), r->pv += rz_pv * (intptr_t) tray_nelem(tray(A(v))) / r->stride;
 r->pv = pv;
 int const dp = (r->flags & rz_depth) != 0;
 for (intptr_t y = rz_own(r, 0); y < r->H; y = rz_own(r, y + 1))
  for (intptr_t i = y * r->W, e = i + r->W; i < e; i++)
   if (dp) ((flo_t*) r->ans)[i] = r->depth[i] < -1 ? 2 : (flo_t) r->depth[i];
   else ((intptr_t*) r->ans)[i] = r->out[i]; }

// a band of rows, drawn on its own copy of the frame's state
static void rz_bandrun(void *c, intptr_t i) {
 struct rz w = *(struct rz const*) c;
 w.ylo = i * rz_band, w.yhi = w.ylo + rz_band < w.H ? w.ylo + rz_band : w.H;
 rz_run(&w); }
// the frame shared out in bands over the pool, its vertices put through first: a band writes
// only its own rows and reads only what facets was given, nothing the heap could move while
// they run. a frame too small to pay, or a width of one, is drawn whole
static void rz_share(struct g *g, struct rz *r) {
 rz_prep(r);
 intptr_t const nb = (r->H + rz_band - 1) / rz_band;
 if (r->W * r->H < rz_par || par_width(g, nb) < 2) { r->nth = 1, r->ylo = 0, r->yhi = r->H, rz_run(r); return; }
 r->nth = nb;
 par_run(g, nb, rz_bandrun, r); }

love_noinline static struct g *host_raster(struct g *g) {
 word *a = g->sp;
 // (facets w h base mat verts tris texs opts)
 uintptr_t const st = chainp(a[7]) ? 11 : 8;
 if (!(a[0] & a[1] & 1) || !galaxyp(a[3]) || tray_nelem(tray(a[3])) < 16 || !rz_batches(a[4], a[5], st)) {
  a[0] = ZeroPoint; return g; }
 intptr_t const W = getcharm(a[0]), H = getcharm(a[1]);
 if (W < 1 || H < 1 || W > rz_side_max || H > rz_side_max) { a[0] = ZeroPoint; return g; }
 uintptr_t nv = 0;   // the vertices of all the batches
 if (galaxyp(a[4])) nv = tray_nelem(tray(a[4])) / st;
 else for (word v = a[4]; chainp(v); v = B(v)) nv += tray_nelem(tray(A(v))) / st;
 word const o0 = chainp(a[7]) ? A(a[7]) : a[7];
 intptr_t const fl = (intptr_t) rz_opt(o0, 5, 0);
 uintptr_t const fr1 = (fl & rz_flat) && !(fl & rz_depth) ? 1 : 2;   // the answer's rank
 uintptr_t const n = mulsat((uintptr_t) W, (uintptr_t) H),   // past every heap: have refuses it
                 fw = b2w(tray_bytes(fl & rz_depth ? love_R : love_Z, fr1, n)),
                 dw = b2w(tray_bytes(love_Z, 1, mulsat(n, 8) / sizeof(word))),   // a colour and a depth, four bytes each
                 pw = b2w(tray_bytes(love_R, 1, rz_pv * nv + 1));
 intptr_t const TW = (W + 7) / 8, TH = (H + 7) / 8;
 uintptr_t const tw = b2w(tray_bytes(love_R, 1, (uintptr_t) (2 * TW * TH)));
 if (!ok(g = have(g, fw + dw + pw + tw))) return g;
 a = g->sp;
 struct tray *fr = ini_tray(bump(g, fw), fl & rz_depth ? love_R : love_Z, fr1), *sc = ini_tray(bump(g, dw), love_Z, 1),
             *pt = ini_tray(bump(g, pw), love_R, 1), *tt = ini_tray(bump(g, tw), love_R, 1);
 pt->shape[0] = rz_pv * nv + 1, tt->shape[0] = (uintptr_t) (2 * TW * TH);
 sc->shape[0] = mulsat(n, 8) / sizeof(word);
 if (fr1 == 2) fr->shape[0] = (uintptr_t) H, fr->shape[1] = (uintptr_t) W;
 else fr->shape[0] = n;
 struct rz r = { .W = W, .H = H, .stride = (intptr_t) st, .out = tray_data(sc), .depth = (float*) tray_data(sc) + n, .ans = tray_data(fr), .pv = tray_data(pt),
                 .tz = tray_data(tt), .TW = TW, .TH = TH, .nth = 1, .yhi = H, .base = a[2], .vs = a[4], .ts = a[5], .tx = a[6] };
 // a smaller frame under it, and the ground under that
 word const b = a[2];
 if (chainp(b) && chainp(B(b)) && chainp(B(B(b)))) {
  word const cs = A(B(b)), ds = A(B(B(b)));
  r.base = A(b);
  if (galaxyp(cs) && galaxyp(ds) && tray(cs)->type == love_Z && tray(ds)->type == love_R && tray(ds)->rank == 2
      && tray_nelem(tray(cs)) == tray_nelem(tray(ds)) && tray(ds)->shape[1] <= (uintptr_t) W && tray(ds)->shape[0] <= (uintptr_t) H)
   r.cc = tray_data(tray(cs)), r.cd = tray_data(tray(ds)), r.cw = (intptr_t) tray(ds)->shape[1], r.ch = (intptr_t) tray(ds)->shape[0]; }
 // the opts, read after the allocation, which may move them
 word o = a[7], sv = ZeroPoint, sd = ZeroPoint;
 if (chainp(o)) {
  word const l = B(o);
  sv = chainp(l) ? A(l) : ZeroPoint, sd = chainp(l) && chainp(B(l)) ? A(B(l)) : ZeroPoint, o = A(o); }
 if (galaxyp(sv) && tray_nelem(tray(sv)) >= 16 && galaxyp(sd) && tray(sd)->rank == 2 && tray(sd)->type == love_R) {
  for (uintptr_t i = 0; i < 16; i++) r.lm[i] = tray_get_flo(tray(sv), i);
  r.sm = tray_data(tray(sd)), r.SH = (intptr_t) tray(sd)->shape[0], r.SW = (intptr_t) tray(sd)->shape[1]; }
 flo_t m[16];
 for (uintptr_t i = 0; i < 16; i++) m[i] = tray_get_flo(tray(a[3]), i);
 r.m = m;
 for (uintptr_t i = 0; i < 5; i++) r.fog[i] = rz_opt(o, i, 0);
 r.flags = (intptr_t) rz_opt(o, 5, 0), r.tone = rz_opt(o, 6, 0), r.bias = rz_opt(o, 7, 0);
 if (r.tone > 0) for (int i = 0; i < rz_tn + 2; i++)
  r.tl[i] = 255 * (1 - rz_exp(-(flo_t) (i < rz_tn ? i : rz_tn) / 32));
 rz_share(g, &r);
 a[0] = word(fr);
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

// (frame-paint f w s P W): a frame w pixels wide onto the cask P, W 32-bit xrgb pixels a
// row, each of the frame's an s by s square from the corner, clipped to P; answers P
static lvm(lvm_frame_paint) {
 word const f = Sp[0], P = Sp[3];
 if (galaxyp(f) && caskp(P) && (Sp[1] & Sp[2] & Sp[4] & 1)) {
  struct tray *t = tray(f);
  struct str *d = cask(P)->str;
  intptr_t const w = getcharm(Sp[1]), s = getcharm(Sp[2]), W = getcharm(Sp[4]);
  if (w > 0 && s > 0 && W > 0) {
   intptr_t const h = (intptr_t) tray_nelem(t) / w, H = (intptr_t) len(d) / 4 / W,
                  cw = w * s < W ? w * s : W, rows = h * s < H ? h * s : H;
   uint8_t *o = (uint8_t*) txt(d);
   for (intptr_t y = 0; y < rows; y++) {
    uint8_t *row = o + 4 * y * W;
    if (y % s) { memcpy(row, row - 4 * W, (size_t) (4 * cw)); continue; }   // a square's rows alike
    for (intptr_t i = y / s * w, x = 0; x < cw; i++) {
     uint32_t const c = (uint32_t) tray_get_int(t, (uintptr_t) i);
     for (intptr_t k = 0; k < s && x < cw; k++, x++)
      row[4 * x] = (uint8_t) c, row[4 * x + 1] = (uint8_t) (c >> 8), row[4 * x + 2] = (uint8_t) (c >> 16), row[4 * x + 3] = 0; } } } }
 love_musttail return Answerp(4, P); }

// (lace cols): columns laced into one float tray, row i the i-th of each (facets's verts); a
// column is a tray, or a number in every row; () when lengths differ or a column is neither
love_noinline static struct g *host_lace(struct g *g) {
 uintptr_t k = 0, n = 0;
 int seen = 0;
 for (word l = g->sp[0]; chainp(l); l = B(l), k++) {
  word const c = A(l);
  if (galaxyp(c)) {
   uintptr_t const m = tray_nelem(tray(c));
   if (seen && m != n) { g->sp[0] = ZeroPoint; return g; }
   n = m, seen = 1; }
  else if (!isnum(c)) { g->sp[0] = ZeroPoint; return g; } }
 uintptr_t const w = b2w(tray_bytes(love_R, 1, k * n));
 if (!ok(g = have(g, w))) return g;
 struct tray *o = ini_tray(bump(g, w), love_R, 1);
 o->shape[0] = k * n;
 flo_t *d = tray_data(o);
 uintptr_t j = 0;
 for (word l = g->sp[0]; chainp(l); l = B(l), j++) {   // re-walked: the bump may have moved it
  word const c = A(l);
  if (galaxyp(c)) for (uintptr_t i = 0; i < n; i++) d[i * k + j] = tray_get_flo(tray(c), i);
  else { flo_t const v = toflo(c); for (uintptr_t i = 0; i < n; i++) d[i * k + j] = v; } }
 g->sp[0] = word(o);
 return g; }
static lvm(lvm_lace) { LvmCall(g, host_lace) }

LvDef("facets", raster, 8, NULL);
LvDef("frame-bytes", frame_bytes, 3, NULL);
LvDef("frame-paint", frame_paint, 5, NULL);
LvDef("lace", lace, 1, NULL);
