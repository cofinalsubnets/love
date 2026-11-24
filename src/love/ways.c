// ways -- what a line of sight reaches through lore's cells (world.l, cells-seen)
//  (ways-seen D V at) the chunks seen, a list in no order; () where an argument is not as it says
// D [X Y Z pb wb wt wo wi kb kc ko ki mx my mz mr]: the cells' points end to end, cell i's from
// pb[i]; its ways wb[i] to wb[i + 1], each to cell wt, -1 the sky, over the points wi[wo[w]..];
// its chunks kb[i] on, each chunk kc over the points ki[ko[k]..]; and each chunk's ball
// V the camera's rows 0 1 3, then a pixel's 8th across and down, the near plane, bent or not
// at the cells the eye is in
#include "love.h"

enum { wy_X, wy_Y, wy_Z, wy_pb, wy_wb, wy_wt, wy_wo, wy_wi, wy_kb, wy_kc, wy_ko, wy_ki, wy_mx, wy_my, wy_mz, wy_mr, wy_n };
struct box { flo_t v[4]; };
struct todo { intptr_t i; struct box r; };
struct wy {
 struct tray *d[wy_n];
 intptr_t n, np, nc;
 flo_t cam[12], mx, my, nr; bool bent;
 flo_t *q; char *in, *s;        // each point down the rows, whether its cell's are; the chunks seen
 struct box *b; unsigned char *nb;   // each cell's boxes, four at most, the sky's last
 struct todo *t; uintptr_t nt, ct; int bad; };

static void *wy_new(uintptr_t n, uintptr_t w, int *bad) {
 void *p = alloc(NULL, (n + 1) * w);
 if (p) memset(p, 0, (n + 1) * w); else *bad = 1;
 return p; }
static void wy_fin(struct wy *h) {
 void *p[] = { h->q, h->in, h->s, h->b, h->nb, h->t };
 for (uintptr_t i = 0; i < sizeof p / sizeof *p; i++) if (p[i]) alloc(p[i], 0); }
static intptr_t wy_int(struct wy const *h, int k, intptr_t i) { return tray_get_int(h->d[k], (uintptr_t) i); }
static flo_t wy_flo(struct wy const *h, int k, intptr_t i) { return tray_get_flo(h->d[k], (uintptr_t) i); }

// tray k's n + 1 offsets into m, rising from 0
static bool wy_offs(struct wy const *h, int k, intptr_t n, intptr_t m) {
 if ((intptr_t) tray_nelem(h->d[k]) != n + 1 || wy_int(h, k, 0)) return 0;
 for (intptr_t i = 0; i < n; i++) if (wy_int(h, k, i) > wy_int(h, k, i + 1)) return 0;
 return wy_int(h, k, n) == m; }
static bool wy_below(struct wy const *h, int k, intptr_t lo, intptr_t hi) {
 for (uintptr_t i = 0, n = tray_nelem(h->d[k]); i < n; i++) { intptr_t const v = wy_int(h, k, (intptr_t) i); if (v < lo || v >= hi) return 0; }
 return 1; }
static bool wy_ok(struct wy *h) {
 intptr_t m[wy_n];
 for (int k = 0; k < wy_n; k++) m[k] = (intptr_t) tray_nelem(h->d[k]);
 h->np = m[wy_X], h->n = m[wy_pb] - 1, h->nc = m[wy_mx];
 return h->n >= 0 && m[wy_Y] == h->np && m[wy_Z] == h->np && m[wy_my] == h->nc && m[wy_mz] == h->nc && m[wy_mr] == h->nc
  && wy_offs(h, wy_pb, h->n, h->np) && wy_offs(h, wy_wb, h->n, m[wy_wt]) && wy_offs(h, wy_kb, h->n, m[wy_kc])
  && wy_offs(h, wy_wo, m[wy_wt], m[wy_wi]) && wy_offs(h, wy_ko, m[wy_kc], m[wy_ki])
  && wy_below(h, wy_wt, -1, h->n) && wy_below(h, wy_kc, 0, h->nc) && wy_below(h, wy_wi, 0, h->np) && wy_below(h, wy_ki, 0, h->np); }

static void wy_cell(struct wy *h, intptr_t c) {   // c's points down the camera's rows, once
 if (h->in[c]) return;
 h->in[c] = 1;
 for (intptr_t i = wy_int(h, wy_pb, c), e = wy_int(h, wy_pb, c + 1); i < e; i++) {
  flo_t const x = wy_flo(h, wy_X, i), y = wy_flo(h, wy_Y, i), z = wy_flo(h, wy_Z, i);
  for (int k = 0; k < 3; k++) { flo_t const *r = h->cam + 4 * k; h->q[3 * i + k] = r[0] * x + r[1] * y + r[2] * z + r[3]; } } }

// the box the points of tray k from a to b span past r, a little over, onto o. those across the
// near plane also as far out as they cross it, each no further out there than over its depth
static bool wy_span(struct wy const *h, int k, intptr_t a, intptr_t b, struct box const *r, struct box *o) {
 if (a >= b) return 0;
 flo_t n = h->q[3 * wy_int(h, k, a) + 2], f = n;
 for (intptr_t i = a + 1; i < b; i++) { flo_t const w = h->q[3 * wy_int(h, k, i) + 2]; if (w < n) n = w; if (w > f) f = w; }
 flo_t lo[2] = {0, 0}, hi[2] = {0, 0};
 flo_t const nr = h->nr, d = n > nr ? n : nr;
 for (int j = 0; j < 2; j++) {
  for (intptr_t i = a; i < b; i++) {
   flo_t const *q = h->q + 3 * wy_int(h, k, i), v = q[j] / (q[2] > nr ? q[2] : nr);
   if (i == a || v < lo[j]) lo[j] = v;
   if (i == a || v > hi[j]) hi[j] = v; }
  if (n < nr) for (intptr_t i = a; i < b; i++) {
   flo_t const v = h->q[3 * wy_int(h, k, i) + j] / nr;
   if (v < lo[j]) lo[j] = v;
   if (v > hi[j]) hi[j] = v; } }
 flo_t const t = h->bent ? (flo_t) 0.04 / d : 0, p = h->mx > t ? h->mx : t, u = h->my > t ? h->my : t;
 flo_t const v[4] = { lo[0] - p, hi[0] + p, lo[1] - u, hi[1] + u };
 for (int j = 0; j < 4; j++) o->v[j] = j & 1 ? (v[j] < r->v[j] ? v[j] : r->v[j]) : (v[j] > r->v[j] ? v[j] : r->v[j]);
 return f >= nr && o->v[0] <= o->v[1] && o->v[2] <= o->v[3]; }

static bool wy_has(struct box const *a, struct box const *b) { return a->v[0] <= b->v[0] && b->v[1] <= a->v[1] && a->v[2] <= b->v[2] && b->v[3] <= a->v[3]; }
static bool wy_meets(struct box const *a, struct box const *b) { return a->v[0] <= b->v[1] && b->v[0] <= a->v[1] && a->v[2] <= b->v[3] && b->v[2] <= a->v[3]; }
static void wy_join(struct box *a, struct box const *b) {
 for (int j = 0; j < 4; j++) if (j & 1 ? b->v[j] > a->v[j] : b->v[j] < a->v[j]) a->v[j] = b->v[j]; }

// a box come to a cell: none if one there holds it, else joined with those it meets, and all
// as one past four; r what it came to
static bool wy_from(struct wy *h, intptr_t c, struct box *r) {
 struct box *o = h->b + 4 * c, l[5];
 int m = h->nb[c], n = 1;
 for (int i = 0; i < m; i++) if (wy_has(o + i, r)) return 0;
 l[0] = *r;
 for (int i = 0; i < m; i++) if (wy_meets(r, o + i)) wy_join(l, o + i); else l[n++] = o[i];
 if (n > 4) { for (int i = 1; i < n; i++) wy_join(l, l + i); n = 1; }
 memcpy(o, l, (uintptr_t) n * sizeof *l), h->nb[c] = (unsigned char) n;
 return *r = l[0], 1; }
static void wy_push(struct wy *h, intptr_t c, struct box const *r) {
 if (h->nt == h->ct) {
  uintptr_t const n = h->ct ? 2 * h->ct : 64;
  struct todo *t = alloc(NULL, n * sizeof *t);
  if (!t) { h->bad = 1; return; }
  if (h->t) memcpy(t, h->t, h->nt * sizeof *t), alloc(h->t, 0);
  h->t = t, h->ct = n; }
 h->t[h->nt++] = (struct todo) { c, *r }; }
static void wy_flip(struct wy *h, uintptr_t a) {   // those pushed since a, the first to go first
 for (uintptr_t i = a, j = h->nt; i + 1 < j; i++, j--) { struct todo const t = h->t[i]; h->t[i] = h->t[j - 1], h->t[j - 1] = t; } }

// past the sky, a chunk kept where its ball is inside the four planes through the eye and r's edges
static void wy_balls(struct wy *h, struct box const *r) {
 flo_t p[4][4];
 flo_t const *r0 = h->cam, *r1 = h->cam + 4, *r3 = h->cam + 8;
 for (int j = 0; j < 4; j++)
  p[0][j] = r0[j] - r->v[0] * r3[j], p[1][j] = r->v[1] * r3[j] - r0[j],
  p[2][j] = r1[j] - r->v[2] * r3[j], p[3][j] = r->v[3] * r3[j] - r1[j];
 for (int k = 0; k < 4; k++) {
  flo_t const s = 1 / love_sqrt(p[k][0] * p[k][0] + p[k][1] * p[k][1] + p[k][2] * p[k][2]);
  for (int j = 0; j < 4; j++) p[k][j] = s * p[k][j]; }
 for (intptr_t c = 0; c < h->nc; c++) {
  flo_t const x = wy_flo(h, wy_mx, c), y = wy_flo(h, wy_my, c), z = wy_flo(h, wy_mz, c), d = -wy_flo(h, wy_mr, c);
  int k = 0;
  while (k < 4 && p[k][0] * x + p[k][1] * y + p[k][2] * z + p[k][3] >= d) k++;
  if (k == 4) h->s[c] = 1; } }

static void wy_run(struct wy *h, struct tray *at) {
 for (uintptr_t i = 0, n = tray_nelem(at); i < n && !h->bad; i++) {
  intptr_t const c = tray_get_int(at, i);
  struct box r = {{ -1, 1, -1, 1 }};
  if (c < 0 || c >= h->n) { h->bad = 1; return; }
  if (wy_from(h, c, &r)) wy_push(h, c, &r); }
 wy_flip(h, 0);
 while (h->nt && !h->bad) {
  struct todo const e = h->t[--h->nt];
  uintptr_t const was = h->nt;
  wy_cell(h, e.i);
  for (intptr_t w = wy_int(h, wy_wb, e.i), z = wy_int(h, wy_wb, e.i + 1); w < z; w++) {
   struct box o;
   intptr_t const to = wy_int(h, wy_wt, w);
   if (wy_span(h, wy_wi, wy_int(h, wy_wo, w), wy_int(h, wy_wo, w + 1), &e.r, &o) && wy_from(h, to < 0 ? h->n : to, &o) && to >= 0)
    wy_push(h, to, &o); }
  wy_flip(h, was); }
 for (int i = 0; i < h->nb[h->n]; i++) wy_balls(h, h->b + 4 * h->n + i);
 for (intptr_t c = 0; c < h->n; c++) {
  if (!h->nb[c]) continue;
  wy_cell(h, c);
  for (intptr_t k = wy_int(h, wy_kb, c), z = wy_int(h, wy_kb, c + 1); k < z; k++) {
   intptr_t const t = wy_int(h, wy_kc, k);
   struct box o;
   for (int i = 0; i < h->nb[c] && !h->s[t]; i++)
    h->s[t] = wy_span(h, wy_ki, wy_int(h, wy_ko, k), wy_int(h, wy_ko, k + 1), h->b + 4 * c + i, &o); } } }

love_noinline static struct g *host_ways_seen(struct g *g) {
 struct wy h = {0};
 word l = g->sp[0];
 word const V = g->sp[1], at = g->sp[2];
 int k = 0;
 for (; k < wy_n && chainp(l) && galaxyp(A(l)); k++, l = B(l)) h.d[k] = tray(A(l));
 if (k < wy_n || !galaxyp(V) || tray_nelem(tray(V)) != 16 || !galaxyp(at) || !wy_ok(&h)) return g->sp[0] = ZeroPoint, g;
 for (int i = 0; i < 12; i++) h.cam[i] = tray_get_flo(tray(V), (uintptr_t) i);
 h.mx = tray_get_flo(tray(V), 12), h.my = tray_get_flo(tray(V), 13), h.nr = tray_get_flo(tray(V), 14), h.bent = tray_get_flo(tray(V), 15) != 0;
 h.q = wy_new(3 * (uintptr_t) h.np, sizeof *h.q, &h.bad), h.in = wy_new((uintptr_t) h.n, 1, &h.bad), h.s = wy_new((uintptr_t) h.nc, 1, &h.bad);
 h.b = wy_new(4 * ((uintptr_t) h.n + 1), sizeof *h.b, &h.bad), h.nb = wy_new((uintptr_t) h.n + 1, 1, &h.bad);
 if (!h.bad) wy_run(&h, tray(at));
 uintptr_t m = 0;
 if (!h.bad) for (intptr_t c = 0; c < h.nc; c++) m += (uintptr_t) h.s[c];
 word r = ZeroPoint;
 if (!h.bad && ok(g = have(g, m * chain_req)))
  for (intptr_t c = h.nc; c--; ) if (h.s[c]) r = word(ini_chain(bump(g, chain_req), (intptr_t) putcharm(c), (intptr_t) r));
 if (ok(g)) g->sp[0] = r;
 return wy_fin(&h), g; }
static lvm(lvm_ways_seen) { LvmCallp(g, 2, host_ways_seen) }
LvDef("ways-seen", ways_seen, 3, "lore");
