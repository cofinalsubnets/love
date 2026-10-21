// swatch -- lore's textures painted from a recipe (swatch.l's swatch-plan), shared over the pool
// (swatch-pic w h plan): the picture w by h, mid grey at first, each layer painted in turn on
// each texel, x from the left and y down; then its levels as mesh-pic lays them, each half the
// last, a texel the mean of the four under it or a hole where two or more were: a list of
// [h w] trays of 0xrrggbb, -1 a hole. a layer [boxes kind nums seed paint paint]: drawn only
// inside every box [x0 y0 x1 y1] of boxes; kind 0-9 a shape of four nums (fill rows cols rect
// disc grid checker stripes dots patches), 10 a bevel [dx dy w] lit by the first paint and
// darkened by the second, 11 a polygon of its nums' corners. a paint [tag a b c d]: 0 a hole,
// 1 the colour a b c, 2 shade by a, 3 tint by a b c, 4 mix toward a b c by d, 5 noise of size
// a b, amount c, seed d. () where an argument is not as it says
#include "love.h"

enum { sw_band = 8, sw_side = 4096 };   // rows a share; the widest side
struct sw_paint { int tag; flo_t a[4]; };
struct sw_layer { flo_t const *box, *num; uintptr_t nbox, nnum; int kind; int64_t seed; struct sw_paint p, d; };
struct sw { struct sw_layer const *l; uintptr_t nl; intptr_t w, h; flo_t *c; uint8_t *hole; };

// the arithmetic as swatch.l's and view.l's, step for step
static int64_t sw_floor(flo_t x) { flo_t t = love_trunc(x); return (int64_t) (t > x ? t - 1 : t); }
static flo_t sw_fmod(flo_t a, flo_t m) { return a - m * (flo_t) sw_floor(a / m); }
static int64_t sw_mash(int64_t a) {
 uint64_t const m = 4294967295u, h = (((uint64_t) a & m) * 1103515245u) & m, h2 = ((h ^ (h >> 15)) * 1664525u) & m;
 return (int64_t) (h2 ^ (h2 >> 13)); }
static int64_t sw_throw(int64_t x, int64_t y, int64_t s) { return sw_mash(y * 374761393 + x * 668265263 + s * 2654435761 + 1) % 1024; }
static flo_t sw_vn(flo_t x, flo_t z, int64_t s) {
 int64_t const ix = sw_floor(x), iz = sw_floor(z);
 flo_t const ux = x - (flo_t) ix, uz = z - (flo_t) iz, ex = ux * ux * ((flo_t) 3.0 - (flo_t) 2.0 * ux), ez = uz * uz * ((flo_t) 3.0 - (flo_t) 2.0 * uz),
             p = (flo_t) sw_throw(ix, iz, s) / (flo_t) 1023.0, q = (flo_t) sw_throw(ix + 1, iz, s) / (flo_t) 1023.0,
             r = (flo_t) sw_throw(ix, iz + 1, s) / (flo_t) 1023.0, t = (flo_t) sw_throw(ix + 1, iz + 1, s) / (flo_t) 1023.0,
             lo = p + ex * (q - p), hi = r + ex * (t - r);
 return lo + ez * (hi - lo); }
static flo_t sw_sq(flo_t v) { return v * v; }

static bool sw_in(struct sw_layer const *l, flo_t x, flo_t y) {
 flo_t const *n = l->num;
 switch (l->kind) {
  case 0: return 1;
  case 1: return n[0] <= y && y < n[1];
  case 2: return n[0] <= x && x < n[1];
  case 3: return n[0] <= x && x < n[2] && n[1] <= y && y < n[3];
  case 4: return sw_sq(x + (flo_t) 0.5 - n[0]) + sw_sq(y + (flo_t) 0.5 - n[1]) < sw_sq(n[2]);
  case 5: return (n[0] > 0 && sw_fmod(x, n[0]) < n[2]) || (n[1] > 0 && sw_fmod(y, n[1]) < n[2]);
  case 6: return (sw_floor(x / n[0]) + sw_floor(y / n[1])) % 2 == 1;
  case 7: return sw_fmod(x + n[2] * y, n[0]) < n[1];
  case 8: return sw_sq(sw_fmod(x, n[0]) + (flo_t) 0.5 - (flo_t) 0.5 * n[0]) + sw_sq(sw_fmod(y, n[1]) + (flo_t) 0.5 - (flo_t) 0.5 * n[1]) < sw_sq(n[2]);
  case 9: return sw_vn(x / n[0], y / n[0], l->seed) > (flo_t) 1.0 - n[1];
  case 11: {   // a texel's middle crossed by the edges an odd number of times to its right
   flo_t const px = x + (flo_t) 0.5, py = y + (flo_t) 0.5;
   uintptr_t const m = l->nnum / 2;
   int a = 0;
   for (uintptr_t i = 0; i < m; i++) {
    uintptr_t const j = (i + 1) % m;
    flo_t const e0 = n[2 * i], e1 = n[2 * i + 1], e2 = n[2 * j], e3 = n[2 * j + 1];
    if ((e1 > py) != (e3 > py) && px < e0 + (e2 - e0) * (py - e1) / (e3 - e1)) a = 1 - a; }
   return a == 1; }
  default: return 0; } }
static void sw_paint(struct sw_paint const *p, flo_t c[3], uint8_t *hole, flo_t x, flo_t y) {
 if (p->tag == 0) { *hole = 1; return; }
 if (p->tag == 1) { c[0] = p->a[0], c[1] = p->a[1], c[2] = p->a[2], *hole = 0; return; }
 if (*hole) return;
 if (p->tag == 2) for (int k = 0; k < 3; k++) c[k] = p->a[0] * c[k];
 else if (p->tag == 3) for (int k = 0; k < 3; k++) c[k] = c[k] * p->a[k];
 else if (p->tag == 4) for (int k = 0; k < 3; k++) c[k] = c[k] + p->a[3] * (p->a[k] - c[k]);
 else if (p->tag == 5) {
  flo_t const m = (flo_t) 1.0 - p->a[2] + p->a[2] * sw_vn(x / p->a[0], y / p->a[1], (int64_t) p->a[3]);
  for (int k = 0; k < 3; k++) c[k] = m * c[k]; } }

// a band of rows of the picture
static void sw_rows(void *ctx, intptr_t b) {
 struct sw const *s = ctx;
 for (intptr_t y = b * sw_band; y < s->h && y < (b + 1) * sw_band; y++)
  for (intptr_t x = 0; x < s->w; x++) {
   flo_t const fx = (flo_t) x, fy = (flo_t) y;
   flo_t *c = s->c + 3 * (y * s->w + x);
   uint8_t *hole = s->hole + y * s->w + x;
   c[0] = c[1] = c[2] = (flo_t) 0.5, *hole = 0;
   for (uintptr_t i = 0; i < s->nl; i++) {
    struct sw_layer const *l = s->l + i;
    bool on = 1;
    for (uintptr_t k = 0; on && k < l->nbox; k++) {
     flo_t const *r = l->box + 4 * k;
     on = r[0] <= fx && fx < r[2] && r[1] <= fy && fy < r[3]; }
    if (!on) continue;
    if (l->kind == 10) {
     flo_t const dx = l->num[0], dy = l->num[1], w = l->num[2], u = sw_fmod(fx, dx), v = sw_fmod(fy, dy);
     if (u >= dx - w || v >= dy - w) sw_paint(&l->d, c, hole, fx, fy);
     else if (u < w || v < w) sw_paint(&l->p, c, hole, fx, fy); }
    else if (sw_in(l, fx, fy)) sw_paint(&l->p, c, hole, fx, fy); } } }

static bool sw_nums(word l, flo_t *o, uintptr_t n) {
 for (uintptr_t k = 0; k < n; k++, l = B(l)) {
  if (!chainp(l) || !isnum(A(l))) return 0;
  o[k] = toflo(A(l)); }
 return 1; }
static bool sw_paint_of(word q, struct sw_paint *p) {
 if (!chainp(q) || !charmp(A(q))) return 0;
 p->tag = (int) getcharm(A(q));
 return p->tag >= 0 && p->tag <= 5 && sw_nums(B(q), p->a, 4) && (p->tag != 5 || (p->a[0] != 0 && p->a[1] != 0)); }
// the plan's layers into l, their numbers into f; 0 where one is not as it says
static bool sw_read(word pl, struct sw_layer *l, flo_t *f) {
 uintptr_t i = 0, used = 0;
 for (; chainp(pl); pl = B(pl), i++) {
  word q = A(pl), part[6];
  for (int k = 0; k < 6; k++, q = B(q)) { if (!chainp(q)) return 0; part[k] = A(q); }
  struct sw_layer *y = l + i;
  y->nbox = llen(part[0]) / 4, y->nnum = llen(part[2]);
  if (llen(part[0]) % 4 || !charmp(part[1]) || !charmp(part[3])) return 0;
  y->box = f + used, used += 4 * y->nbox;
  y->num = f + used, used += y->nnum;
  y->kind = (int) getcharm(part[1]), y->seed = getcharm(part[3]);
  if (!sw_nums(part[0], (flo_t*) y->box, 4 * y->nbox) || !sw_nums(part[2], (flo_t*) y->num, y->nnum) || !sw_paint_of(part[4], &y->p)) return 0;
  if (y->kind < 0 || y->kind > 11 || (y->kind == 10 ? y->nnum != 3 || !sw_paint_of(part[5], &y->d) : y->kind == 11 ? y->nnum < 6 || y->nnum % 2 : y->nnum != 4)) return 0; }
 return 1; }

static intptr_t sw_q(flo_t v) {   // a channel 0 to 255
 v = (flo_t) 0.0 < v ? v : (flo_t) 0.0, v = (flo_t) 1.0 < v ? (flo_t) 1.0 : v;
 return (intptr_t) love_trunc(v * (flo_t) 255.0 + (flo_t) 0.5); }
static void sw_lay(struct tray *t, flo_t const *c, uint8_t const *hole, uintptr_t n) {
 intptr_t *o = tray_data(t);
 for (uintptr_t i = 0; i < n; i++) o[i] = hole[i] ? -1 : (sw_q(c[3 * i]) << 16) | (sw_q(c[3 * i + 1]) << 8) | sw_q(c[3 * i + 2]); }

love_noinline static struct g *host_swatch_pic(struct g *g) {
 if (!charmp(g->sp[0]) || !charmp(g->sp[1])) return g->sp[0] = ZeroPoint, g;
 intptr_t const w = getcharm(g->sp[0]), h = getcharm(g->sp[1]);
 if (w < 1 || h < 1 || w > sw_side || h > sw_side) return g->sp[0] = ZeroPoint, g;
 uintptr_t nl = 0, nf = 0;
 for (word pl = g->sp[2]; chainp(pl); pl = B(pl), nl++) {
  word q = A(pl);
  if (!chainp(q) || !chainp(B(q)) || !chainp(B(B(q)))) return g->sp[0] = ZeroPoint, g;
  nf += llen(A(q)) + llen(A(B(B(q)))); }
 // the levels' trays and the list of them
 uintptr_t words = 0, nlev = 0;
 for (intptr_t m = w, n = h; ; m /= 2, n /= 2) {
  words += b2w(tray_bytes(love_Z, 2, (uintptr_t) (m * n))) + chain_req, nlev++;
  if (m < 2 || n < 2) break; }
 struct sw_layer *ls = alloc(NULL, (nl + 1) * sizeof *ls);
 flo_t *f = alloc(NULL, (nf + 1) * sizeof *f), *c = alloc(NULL, 3 * (uintptr_t) (w * h) * sizeof *c);
 uint8_t *hole = alloc(NULL, (uintptr_t) (w * h));
 bool good = ls && f && c && hole;
 if (good && ok(g = have(g, words))) {
  if (sw_read(g->sp[2], ls, f)) {
   struct sw s = {ls, nl, w, h, c, hole};
   par_run(g, (h + sw_band - 1) / sw_band, sw_rows, &s);
   struct tray *lv[64];
   intptr_t m = w, n = h;
   for (uintptr_t k = 0; k < nlev; k++, m /= 2, n /= 2) {
    lv[k] = ini_tray(bump(g, b2w(tray_bytes(love_Z, 2, (uintptr_t) (m * n)))), love_Z, 2);
    lv[k]->shape[0] = (uintptr_t) n, lv[k]->shape[1] = (uintptr_t) m;
    sw_lay(lv[k], c, hole, (uintptr_t) (m * n));
    if (k + 1 == nlev) break;
    // the next level down, in place: its texel i reads only texels at or past i
    intptr_t const a = m / 2, b = n / 2;
    for (intptr_t i = 0; i < a * b; i++) {
     intptr_t const x = 2 * (i % a), y = 2 * (i / a), at[4] = {y * m + x, y * m + x + 1, (y + 1) * m + x, (y + 1) * m + x + 1};
     flo_t s3[3] = {(flo_t) 0.0, (flo_t) 0.0, (flo_t) 0.0};
     int q = 0;
     for (int j = 0; j < 4; j++) if (!hole[at[j]]) { q++; for (int k3 = 0; k3 < 3; k3++) s3[k3] = s3[k3] + c[3 * at[j] + k3]; }
     hole[i] = q < 3;
     flo_t const r = (flo_t) 1.0 / (flo_t) q;
     for (int k3 = 0; k3 < 3; k3++) c[3 * i + k3] = q < 3 ? (flo_t) 0.0 : r * s3[k3]; } }
   word l = ZeroPoint;
   for (uintptr_t k = nlev; k--; ) l = word(ini_chain(bump(g, chain_req), (intptr_t) word(lv[k]), (intptr_t) l));
   g->sp[0] = l; }
  else g->sp[0] = ZeroPoint; }
 else if (ok(g)) g->sp[0] = ZeroPoint;
 if (ls) alloc(ls, 0);
 if (f) alloc(f, 0);
 if (c) alloc(c, 0);
 if (hole) alloc(hole, 0);
 return g; }
static lvm(lvm_swatch_pic) { LvmCallp(g, 2, host_swatch_pic) }
LvDef("swatch-pic", swatch_pic, 3, NULL);
