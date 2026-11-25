// air -- lore's sky from the air it crosses (sky.l): the light scattered toward the eye, laid
// in tables the way hillaire's are, and the cloud map read down many rays at once
// an air [rr rg rb rh  ms mx mh  or og ob oy oh  g alb]: rayleigh's scattering a km and its
// height, the dust's scattering, its extinction and height, what the ozone takes, its middle
// and half its depth, how far forward dust throws light, and the ground's share given back
// (air-lay air): the tables an air has whatever the sun, the light left by a path to the top
// and then the light scattered over and over, one tray
// (air-sky air lay w h sy): the sky's colour by the sun's height sy, [h w 3] its rows by the
// root of the ray's height, its columns by the sine of half its turn from the sun
// (air-sun lay sy): the share of the sun's light left at the eye, [r g b], one each, the horizon's below it
// (air-look sky [w h sx sz t] [dx dy dz]): that table down rays, [r g b]; t as high below, and no
// lower than a fifth, so the two halves meet with no crease
// (cloud-thick map [x0 .. x5 f] u v [W0 W1 W2]): the thickness sky.l's thick-w answers
// () where an argument is not as it says
#include "love.h"

enum { air_n = 14, ai_tw = 96, ai_th = 32, ai_mw = 24, ai_mh = 12, ai_side = 1024,
       ai_t = 3 * ai_tw * ai_th, ai_lay = ai_t + 3 * ai_mw * ai_mh, ai_band = 2048 };
#define ai_f(x) ((flo_t) (x))
#define ai_pi ai_f(3.14159265358979323846)
#define ai_rg ai_f(6360.0)
#define ai_rt ai_f(6460.0)
#define ai_eye ai_f(0.3)
static flo_t ai_sat(flo_t x) { return x < 0 ? 0 : x > 1 ? 1 : x; }
static flo_t ai_root(flo_t x) { return x > 0 ? love_sqrt(x) : 0; }
static flo_t ai_abs(flo_t x) { return x < 0 ? -x : x; }

// a table of colours at x y of its texels, between them
static void ai_bil(flo_t const *t, intptr_t w, intptr_t h, flo_t x, flo_t y, flo_t *o) {
 x = ai_sat(x / ai_f(w - 1)) * ai_f(w - 1), y = ai_sat(y / ai_f(h - 1)) * ai_f(h - 1);
 intptr_t i = (intptr_t) x, j = (intptr_t) y;
 if (i > w - 2) i = w - 2;
 if (j > h - 2) j = h - 2;
 flo_t const u = x - ai_f(i), v = y - ai_f(j), *a = t + 3 * (j * w + i), *b = a + 3 * w;
 for (int c = 0; c < 3; c++) {
  flo_t const p = a[c] + u * (a[c + 3] - a[c]), q = b[c] + u * (b[c + 3] - b[c]);
  o[c] = p + v * (q - p); } }

// how far from r out along mu the top is, and the ground, under 0 for a miss
static flo_t ai_top(flo_t r, flo_t mu) { return -r * mu + ai_root(r * r * (mu * mu - 1) + ai_rt * ai_rt); }
static flo_t ai_low(flo_t r, flo_t mu) {
 flo_t const d = r * r * (mu * mu - 1) + ai_rg * ai_rg;
 return mu < 0 && d >= 0 ? -r * mu - love_sqrt(d) : ai_f(-1); }

// at a height: what rayleigh and the dust scatter, and all that is lost
static void ai_med(flo_t const *a, flo_t y, flo_t *ray, flo_t *mie, flo_t *ext) {
 y = y < 0 ? 0 : y;
 flo_t const dr = love_exp(-y / a[3]), dm = love_exp(-y / a[6]), doz = ai_sat(1 - ai_abs(y - a[10]) / a[11]);
 *mie = a[4] * dm;
 for (int c = 0; c < 3; c++) ray[c] = a[c] * dr, ext[c] = ray[c] + a[5] * dm + a[7 + c] * doz; }

static flo_t const ai_hh = ai_f(1132.2543883774531);   // the root of the top's square less the ground's
static void ai_thru(flo_t const *t, flo_t r, flo_t mu, flo_t *o) {
 flo_t const rho = ai_root(r * r - ai_rg * ai_rg), lo = ai_rt - r, d = ai_top(r, mu);
 ai_bil(t, ai_tw, ai_th, (d - lo) / (rho + ai_hh - lo) * ai_f(ai_tw - 1), rho / ai_hh * ai_f(ai_th - 1), o); }
// ..the sun's light there, none past the ground
static void ai_sun(flo_t const *t, flo_t r, flo_t mu, flo_t *o) {
 if (ai_low(r, mu) > 0) o[0] = o[1] = o[2] = 0;
 else ai_thru(t, r, mu, o); }
static void ai_ms(flo_t const *m, flo_t r, flo_t mu, flo_t *o) {
 ai_bil(m, ai_mw, ai_mh, (mu * ai_f(0.5) + ai_f(0.5)) * ai_f(ai_mw - 1), (r - ai_rg) / (ai_rt - ai_rg) * ai_f(ai_mh - 1), o); }

// a row of the first table
struct ai { flo_t const *a, *lay; flo_t *o; intptr_t w, h; flo_t sy; };
static void ai_trow(void *x, intptr_t j) {
 struct ai const *s = x;
 flo_t const rho = ai_hh * ai_f(j) / ai_f(ai_th - 1), r = love_sqrt(rho * rho + ai_rg * ai_rg), lo = ai_rt - r;
 for (intptr_t i = 0; i < ai_tw; i++) {
  flo_t const d = lo + (rho + ai_hh - lo) * ai_f(i) / ai_f(ai_tw - 1);
  flo_t mu = d <= 0 ? 1 : (ai_hh * ai_hh - rho * rho - d * d) / (2 * r * d), od[3] = {0, 0, 0};
  mu = mu < -1 ? -1 : mu > 1 ? 1 : mu;
  for (int k = 0; k < 24; k++) {
   flo_t const t = d * (ai_f(k) + ai_f(0.5)) / 24, y = love_sqrt(r * r + t * t + 2 * r * t * mu) - ai_rg;
   flo_t ray[3], mie, ext[3];
   ai_med(s->a, y, ray, &mie, ext);
   for (int c = 0; c < 3; c++) od[c] += ext[c] * d / 24; }
  for (int c = 0; c < 3; c++) s->o[3 * (j * ai_tw + i) + c] = love_exp(-od[c]); } }

// the light down a ray from r, its way's height mu, the sun's ms, the cosine between nu: n
// steps. with m the light scattered again added and each scattering by its phase, else every
// way alike, what it would scatter under light all round in f, the ground's light in too
static void ai_ray(flo_t const *a, flo_t const *t, flo_t const *m, flo_t r, flo_t mu, flo_t ms, flo_t nu, int n, flo_t *L, flo_t *f) {
 flo_t const lo = ai_low(r, mu), end = lo > 0 ? lo : ai_top(r, mu), iso = 1 / (4 * ai_pi), g = a[12],
             pr = 3 / (16 * ai_pi) * (1 + nu * nu), b = 1 + g * g - 2 * g * nu,
             pm = 3 / (8 * ai_pi) * (1 - g * g) * (1 + nu * nu) / ((2 + g * g) * b * love_sqrt(b));
 flo_t T[3] = {1, 1, 1}, at = 0;
 for (int c = 0; c < 3; c++) L[c] = f[c] = 0;
 for (int k = 0; k < n; k++) {
  flo_t const q = ai_f(k + 1) / ai_f(n), to = end * q * q, dt = to - at, x = at + dt / 2,
              rr = love_sqrt(r * r + x * x + 2 * r * x * mu), mm = (r * ms + x * nu) / rr;
  flo_t ray[3], mie, ext[3], su[3], ps[3] = {0, 0, 0};
  ai_med(a, rr - ai_rg, ray, &mie, ext), ai_sun(t, rr, mm, su);
  if (m) ai_ms(m, rr, mm, ps);
  for (int c = 0; c < 3; c++) {
   flo_t const sc = ray[c] + mie, st = love_exp(-ext[c] * dt), in = (1 - st) / ext[c],
               e = m ? su[c] * (ray[c] * pr + mie * pm) + sc * ps[c] : su[c] * sc * iso;
   L[c] += T[c] * e * in, f[c] += T[c] * sc * in, T[c] *= st; }
  at = to; }
 if (!m && lo > 0) {
  flo_t const gm = (r * ms + lo * nu) / ai_rg;
  flo_t su[3];
  if (gm > 0) {
   ai_thru(t, ai_rg, gm, su);
   for (int c = 0; c < 3; c++) L[c] += T[c] * su[c] * gm * a[13] / ai_pi; } } }

// ..a row of the second, its series summed
static void ai_mrow(void *x, intptr_t j) {
 struct ai const *s = x;
 flo_t const r = ai_rg + (ai_rt - ai_rg) * (ai_f(j) + ai_f(0.01)) / ai_f(ai_mh);
 for (intptr_t i = 0; i < ai_mw; i++) {
  flo_t const ms = 2 * ai_f(i) / ai_f(ai_mw - 1) - 1, sn = ai_root(1 - ms * ms);
  flo_t L[3] = {0, 0, 0}, F[3] = {0, 0, 0};
  for (int p = 0; p < 4; p++)
   for (int q = 0; q < 8; q++) {
    flo_t const mu = 2 * (ai_f(p) + ai_f(0.5)) / 4 - 1, ph = 2 * ai_pi * (ai_f(q) + ai_f(0.5)) / 8;
    flo_t l[3], f[3];
    ai_ray(s->a, s->lay, NULL, r, mu, ms, mu * ms + ai_root(1 - mu * mu) * sn * love_cos(ph), 16, l, f);
    for (int c = 0; c < 3; c++) L[c] += l[c] / 32, F[c] += f[c] / 32; }
  for (int c = 0; c < 3; c++) s->o[3 * (j * ai_mw + i) + c] = L[c] / (1 - F[c]); } }

// ..and of the sky
static void ai_srow(void *x, intptr_t j) {
 struct ai const *s = x;
 flo_t const v = ai_f(j) / ai_f(s->h - 1), mu = v * v, ch = ai_root(1 - mu * mu), sh = ai_root(1 - s->sy * s->sy);
 for (intptr_t i = 0; i < s->w; i++) {
  flo_t const u = ai_f(i) / ai_f(s->w - 1);
  flo_t f[3];
  ai_ray(s->a, s->lay, s->lay + ai_t, ai_rg + ai_eye, mu, s->sy, mu * s->sy + ch * sh * (1 - 2 * u * u), 32,
         s->o + 3 * (j * s->w + i), f); } }

static bool ai_nums(word l, flo_t *o, uintptr_t n) {
 for (uintptr_t k = 0; k < n; k++, l = B(l)) {
  if (!chainp(l) || !isnum(A(l))) return 0;
  o[k] = toflo(A(l)); }
 return 1; }
static bool ai_air(word l, flo_t *o) {
 return ai_nums(l, o, air_n) && o[3] > 0 && o[5] > 0 && o[6] > 0 && o[11] > 0 && o[0] > 0 && o[1] > 0 && o[2] > 0; }
static bool ai_tray(word x) { return galaxyp(x) && tray(x)->type == love_R; }

love_noinline static struct g *host_air_lay(struct g *g) {
 flo_t a[air_n];
 if (!ai_air(g->sp[0], a)) return g->sp[0] = ZeroPoint, g;
 uintptr_t const w = b2w(tray_bytes(love_R, 1, ai_lay));
 if (!ok(g = have(g, w))) return g;
 struct tray *o = ini_tray(bump(g, w), love_R, 1);
 o->shape[0] = ai_lay;
 flo_t *t = tray_data(o);
 struct ai s = {a, t, t, 0, 0, 0};
 par_run(ai_th, ai_trow, &s);
 s.o = t + ai_t;
 par_run(ai_mh, ai_mrow, &s);
 return g->sp[0] = word(o), g; }
static lvm(lvm_air_lay) { LvmCallp(g, 0, host_air_lay) }
LvDef("air-lay", air_lay, 1, "lore");

love_noinline static struct g *host_air_sky(struct g *g) {
 flo_t a[air_n];
 if (!ai_air(g->sp[0], a) || !ai_tray(g->sp[1]) || tray_nelem(tray(g->sp[1])) != ai_lay
     || !charmp(g->sp[2]) || !charmp(g->sp[3]) || !isnum(g->sp[4])) return g->sp[0] = ZeroPoint, g;
 intptr_t const w = getcharm(g->sp[2]), h = getcharm(g->sp[3]);
 if (w < 2 || h < 2 || w > ai_side || h > ai_side) return g->sp[0] = ZeroPoint, g;
 flo_t const sy = toflo(g->sp[4]);
 uintptr_t const n = b2w(tray_bytes(love_R, 1, (uintptr_t) (3 * w * h)));
 if (!ok(g = have(g, n))) return g;
 struct tray *o = ini_tray(bump(g, n), love_R, 1);
 o->shape[0] = (uintptr_t) (3 * w * h);
 struct ai s = {a, tray_data(tray(g->sp[1])), tray_data(o), w, h, sy < -1 ? -1 : sy > 1 ? 1 : sy};
 par_run(h, ai_srow, &s);
 return g->sp[0] = word(o), g; }
static lvm(lvm_air_sky) { LvmCallp(g, 4, host_air_sky) }
LvDef("air-sky", air_sky, 5, "lore");

// n rays a share
struct al { flo_t const *t, *x[3], *p, *m; flo_t *o[3]; uintptr_t n; intptr_t w, h; flo_t wv[3]; flo_t const *wt[3]; };
static void ai_look(void *x, intptr_t b) {
 struct al const *s = x;
 flo_t const sx = s->p[2], sz = s->p[3], sl = ai_root(sx * sx + sz * sz);
 for (uintptr_t i = (uintptr_t) b * ai_band; i < s->n && i < (uintptr_t) (b + 1) * ai_band; i++) {
  flo_t const dx = s->x[0][i], dz = s->x[2][i], y = s->x[1][i], dy = s->p[4] > 0 ? love_sqrt(y * y + ai_f(0.04)) : y,
              q = ai_root(dx * dx + dz * dz) * sl, c = q > ai_f(1e-9) ? (dx * sx + dz * sz) / q : 1;
  flo_t k[3];
  ai_bil(s->t, s->w, s->h, ai_root((1 - c) / 2) * ai_f(s->w - 1), ai_root(dy) * ai_f(s->h - 1), k);
  for (int j = 0; j < 3; j++) s->o[j][i] = k[j]; } }

// an answer of n trays of m, newest first into o
static word ai_list(struct g *g, uintptr_t n, uintptr_t m, flo_t **o) {
 word r[3], l = ZeroPoint;
 for (uintptr_t k = 0; k < n; k++) {
  struct tray *t = ini_tray(bump(g, b2w(tray_bytes(love_R, 1, m))), love_R, 1);
  t->shape[0] = m, o[k] = tray_data(t), r[k] = word(t); }
 if (n == 1) return r[0];
 for (uintptr_t k = n; k--; ) l = word(ini_chain(bump(g, chain_req), (intptr_t) r[k], (intptr_t) l));
 return l; }
love_noinline static struct g *host_air_sun(struct g *g) {
 if (!ai_tray(g->sp[0]) || tray_nelem(tray(g->sp[0])) != ai_lay || !isnum(g->sp[1])) return g->sp[0] = ZeroPoint, g;
 flo_t const sy = toflo(g->sp[1]);
 flo_t c[3], *o[3];
 ai_thru(tray_data(tray(g->sp[0])), ai_rg + ai_eye, sy < -1 ? -1 : sy > 1 ? 1 : sy, c);
 if (!ok(g = have(g, 3 * (b2w(tray_bytes(love_R, 1, 1)) + chain_req)))) return g;
 word const l = ai_list(g, 3, 1, o);
 for (int k = 0; k < 3; k++) o[k][0] = c[k];
 return g->sp[0] = l, g; }
static lvm(lvm_air_sun) { LvmCallp(g, 1, host_air_sun) }
LvDef("air-sun", air_sun, 2, "lore");

static bool ai_three(word l, uintptr_t *n, flo_t const **x) {
 for (int k = 0; k < 3; k++, l = B(l)) {
  if (!chainp(l) || !ai_tray(A(l)) || (k && tray_nelem(tray(A(l))) != *n)) return 0;
  *n = tray_nelem(tray(A(l))), x[k] = tray_data(tray(A(l))); }
 return 1; }

love_noinline static struct g *host_air_look(struct g *g) {
 struct al s;
 flo_t p[5];
 if (!ai_tray(g->sp[0]) || !ai_nums(g->sp[1], p, 5) || !ai_three(g->sp[2], &s.n, s.x)
     || !(p[0] >= 2 && p[0] <= ai_side && p[1] >= 2 && p[1] <= ai_side)
     || tray_nelem(tray(g->sp[0])) != (uintptr_t) (3 * (intptr_t) p[0] * (intptr_t) p[1])) return g->sp[0] = ZeroPoint, g;
 if (!ok(g = have(g, 3 * (b2w(tray_bytes(love_R, 1, s.n)) + chain_req)))) return g;
 ai_three(g->sp[2], &s.n, s.x);   // re-read: the ask may have moved them
 s.t = tray_data(tray(g->sp[0])), s.p = p, s.w = (intptr_t) p[0], s.h = (intptr_t) p[1];
 word const l = ai_list(g, 3, s.n, s.o);
 par_run((intptr_t) ((s.n + ai_band - 1) / ai_band), ai_look, &s);
 return g->sp[0] = l, g; }
static lvm(lvm_air_look) { LvmCallp(g, 2, host_air_look) }
LvDef("air-look", air_look, 3, "lore");

// the map at x z of its texels, wrapping; its side n
static flo_t ai_map(flo_t const *m, intptr_t n, flo_t x, flo_t z) {
 flo_t const fx = love_floor(x), fz = love_floor(z), u = x - fx, v = z - fz;
 int64_t const i = flo_i64(fx), j = flo_i64(fz);
 intptr_t const x0 = (intptr_t) ((i % n + n) % n), x1 = (x0 + 1) % n, z0 = (intptr_t) ((j % n + n) % n) * n, z1 = (z0 + n) % (n * n);
 flo_t const a = m[z0 + x0], b = m[z1 + x0], lo = a + u * (m[z0 + x1] - a), hi = b + u * (m[z1 + x1] - b);
 return lo + v * (hi - lo); }
static void ai_thick(void *x, intptr_t b) {
 struct al const *s = x;
 flo_t const *p = s->p, f = p[6], h = ai_f(0.5);
 for (uintptr_t i = (uintptr_t) b * ai_band; i < s->n && i < (uintptr_t) (b + 1) * ai_band; i++) {
  flo_t const u = s->x[0][i], v = s->x[1][i],
   q = ai_map(s->m, s->w, (u + p[0]) * 16, (v + p[1]) * 16), r = ai_map(s->m, s->w, (u + p[2]) * 37 + ai_f(11.3), (v + p[3]) * 37 - ai_f(5.1)),
   w = ai_map(s->m, s->w, (u + p[4]) * 3 + 40, (v + p[5]) * 3 + 17);
  flo_t W[3];
  for (int k = 0; k < 3; k++) W[k] = s->wt[k] ? s->wt[k][i] : s->wv[k];
  s->o[0][i] = (1 - f) * (h + W[0] * (q - h)) + f * (h + W[1] * (r - h)) + ai_f(0.18) * W[2] * (w - h); } }
static bool ai_args(struct g *g, struct al *s) {
 if (!ai_tray(g->sp[0]) || !ai_tray(g->sp[2]) || !ai_tray(g->sp[3])) return 0;
 s->n = tray_nelem(tray(g->sp[2]));
 if (tray_nelem(tray(g->sp[3])) != s->n) return 0;
 s->m = tray_data(tray(g->sp[0])), s->x[0] = tray_data(tray(g->sp[2])), s->x[1] = tray_data(tray(g->sp[3]));
 word l = g->sp[4];
 for (int k = 0; k < 3; k++, l = B(l)) {
  if (!chainp(l)) return 0;
  word const q = A(l);
  s->wt[k] = NULL, s->wv[k] = 0;
  if (isnum(q)) s->wv[k] = toflo(q);
  else if (ai_tray(q) && tray_nelem(tray(q)) == s->n) s->wt[k] = tray_data(tray(q));
  else return 0; }
 return 1; }
love_noinline static struct g *host_cloud_thick(struct g *g) {
 struct al s;
 flo_t p[7];
 if (!ai_nums(g->sp[1], p, 7) || !ai_args(g, &s)) return g->sp[0] = ZeroPoint, g;
 uintptr_t const nm = tray_nelem(tray(g->sp[0]));
 for (s.w = 1; (uintptr_t) (s.w * s.w) < nm && s.w < 4096; s.w++);
 if ((uintptr_t) (s.w * s.w) != nm) return g->sp[0] = ZeroPoint, g;
 if (!ok(g = have(g, b2w(tray_bytes(love_R, 1, s.n))))) return g;
 ai_args(g, &s), s.p = p;   // re-read: the ask may have moved them
 word const l = ai_list(g, 1, s.n, s.o);
 par_run((intptr_t) ((s.n + ai_band - 1) / ai_band), ai_thick, &s);
 return g->sp[0] = l, g; }
static lvm(lvm_cloud_thick) { LvmCallp(g, 4, host_cloud_thick) }
LvDef("cloud-thick", cloud_thick, 5, "lore");
