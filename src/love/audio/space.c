// src/love/audio/space.c -- an effects bus over a mixed stereo chunk: chorus, a ping-pong
// feedback delay, then a reverb (four allpass diffusers into eight feedback lines mixed by a
// householder matrix, each damped by a one-pole lowpass) whose tail may come back into it an
// octave up, a shimmer. love keeps the knobs; this runs frames.
// (space L R mem prm) -> (L' . R'), two float trays of #L | the bytes mem wants, a number,
//   when mem is not a cask that long (a fresh one, all zero, is a bus at rest) | () bad args.
//   mem carries the lines and every filter's memory from one chunk to the next. prm, a float tray:
//    0 rate
//    1 chorus send  2 wet  3 depth, seconds  4 rate, Hz
//    5 delay send   6 wet  7 time, seconds (under 2)  8 feedback  9 tone, 1 keeps every high
//   10 reverb send 11 wet 12 t60, seconds  13 size, the lines' length over the base (1/4 .. 3)
//   14 damp, 0 bright .. 1 dark  15 shimmer, how much of the tail returns an octave up (0 .. 1)
//   a send or wet moves to its new value across the chunk, so a toggle does not click; a send
//   gone to 0 leaves what its effect holds ringing out
// (sweep x st prm) -> (y . st'): a mono float tray through a state-variable filter whose cutoff
//   a slow lfo moves; st' (two floats) handed back as st next time, any other st at rest | ().
//   prm, a float tray: 0 rate  1 the frame x begins on  2 cutoff, Hz  3 depth, octaves either
//   side  4 lfo, Hz  5 its phase at frame 0, turns  6 q  7 0 lowpass, 1 bandpass (unity at its peak).
//   the lfo is read off the frame's own number and the coefficient laid every 32 frames between,
//   so a run cut into chunks anywhere answers the same
#include "love.h"
#if Bits == 64
double lm_exp(double);
#define sp_exp lm_exp
#else
float lm_expf(float);
#define sp_exp lm_expf
#endif

enum { sp_nprm = 16, sp_lines = 8, sp_aps = 4, sp_ramps = 7 };
// the lines' and diffusers' lengths in frames at 44100: mutually prime, so no echo lines up
static int const sp_fdn[sp_lines] = { 1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116 },
                 sp_ap[sp_aps] = { 210, 159, 562, 410 };
// which side each line reaches, and with what sign
static flo_t const sp_ls[sp_lines] = { 1, 0, -1, 0, 1, 0, -1, 0 }, sp_rs[sp_lines] = { 0, 1, 0, -1, 0, 1, 0, -1 };
// the knobs that ramp across a chunk, and how far each may go
static int const sp_ramp[sp_ramps] = { 1, 2, 5, 6, 10, 11, 15 };
static flo_t const sp_rhi[sp_ramps] = { 2, 2, 2, 2, 2, 2, 1 };
#define sp_tiny ((flo_t) 1e-20)   // added and taken away: a decaying state flushed before it is subnormal

struct sp_head { uint64_t w; flo_t lfo, shp, cur[sp_ramps], dlp[2], flp[sp_lines]; };

static uintptr_t sp_pow2(flo_t x) { uintptr_t n = 16; while ((flo_t) n < x) n <<= 1; return n; }
// every buffer's length, a power of two, and the whole in bytes
struct sp_caps { uintptr_t ch, dl, sh, fdn[sp_lines], ap[sp_aps], bytes; };
static void sp_caps(flo_t rate, struct sp_caps *c) {
 flo_t const k = rate / 44100;
 c->ch = sp_pow2(rate / 20), c->dl = sp_pow2(2 * rate + 2), c->sh = sp_pow2(rate / 20 + 4);
 uintptr_t n = 2 * c->ch + 2 * c->dl + 2 * c->sh;
 for (int i = 0; i < sp_lines; i++) n += c->fdn[i] = sp_pow2(sp_fdn[i] * 3 * k + 2);
 for (int i = 0; i < sp_aps; i++) n += c->ap[i] = sp_pow2(sp_ap[i] * k + 2);
 c->bytes = sizeof(struct sp_head) + n * sizeof(flo_t); }

static love_inline flo_t sp_fl(flo_t x) { flo_t f = (flo_t) (int64_t) x; return f > x ? f - 1 : f; }
// sine of x turns, folded to a quarter turn and its series to z^9: a slow lfo needs no more
static love_inline flo_t sp_sin(flo_t x) {
 flo_t u = x - sp_fl(x);
 if (u > (flo_t) 0.5) u -= 1;
 if (u > (flo_t) 0.25) u = (flo_t) 0.5 - u;
 else if (u < (flo_t) -0.25) u = (flo_t) -0.5 - u;
 flo_t const z = u * (flo_t) 6.283185307179586, q = z * z;
 return z * (1 + q * ((flo_t) -1 / 6 + q * ((flo_t) 1 / 120 + q * ((flo_t) -1 / 5040 + q * ((flo_t) 1 / 362880))))); }
// a line read d frames back, between frames
static love_inline flo_t sp_tap(flo_t const *b, uintptr_t m, uint64_t w, flo_t d) {
 intptr_t const i = (intptr_t) d;
 flo_t const f = d - (flo_t) i, a = b[(w - (uint64_t) i) & m], c = b[(w - (uint64_t) i - 1) & m];
 return a + f * (c - a); }
static love_inline flo_t sp_clamp(flo_t x, flo_t lo, flo_t hi) { return x != x ? lo : x < lo ? lo : x > hi ? hi : x; }

love_noinline static struct g *host_space(struct g *g) {
 word *a = g->sp;
 // (space L R mem prm)
 if (!galaxyp(a[0]) || !galaxyp(a[1]) || !galaxyp(a[3]) || tray(a[3])->type != love_R || tray_nelem(tray(a[3])) < sp_nprm
     || tray(a[0])->rank != 1 || tray(a[1])->rank != 1 || tray_nelem(tray(a[0])) != tray_nelem(tray(a[1]))) { a[0] = ZeroPoint; return g; }
 flo_t p[sp_nprm];
 for (int i = 0; i < sp_nprm; i++) p[i] = tray_get_flo(tray(a[3]), (uintptr_t) i);
 flo_t const rate = p[0];
 if (!(rate >= 1000 && rate <= 384000)) { a[0] = ZeroPoint; return g; }
 struct sp_caps c;
 sp_caps(rate, &c);
 uintptr_t nb = 0;
 if (!cask_bytes(a[2], &nb) || nb != c.bytes) { a[0] = putcharm((intptr_t) c.bytes); return g; }
 uintptr_t const n = tray_nelem(tray(a[0])), w1 = b2w(tray_bytes(love_R, 1, n));
 if (n > 1 << 22) { a[0] = ZeroPoint; return g; }
 if (!ok(g = have(g, 2 * w1 + Width(struct chain)))) return g;
 a = g->sp;
 struct tray *tl = ini_tray(bump(g, w1), love_R, 1), *tr = ini_tray(bump(g, w1), love_R, 1);
 tl->shape[0] = tr->shape[0] = n;
 flo_t *L = tray_data(tl), *R = tray_data(tr);
 for (uintptr_t i = 0; i < n; i++) L[i] = tray_get_flo(tray(a[0]), i), R[i] = tray_get_flo(tray(a[1]), i);
 // the memory, read after the allocation, which may move it
 struct sp_head *h = (struct sp_head*) cask_bytes(a[2], &nb);
 flo_t *chl = (flo_t*) (h + 1), *chr = chl + c.ch, *dll = chr + c.ch, *dlr = dll + c.dl, *shl = dlr + c.dl, *shr = shl + c.sh,
      *fdn[sp_lines], *ap[sp_aps];
 fdn[0] = shr + c.sh;
 for (int i = 1; i < sp_lines; i++) fdn[i] = fdn[i - 1] + c.fdn[i - 1];
 ap[0] = fdn[sp_lines - 1] + c.fdn[sp_lines - 1];
 for (int i = 1; i < sp_aps; i++) ap[i] = ap[i - 1] + c.ap[i - 1];

 flo_t const k = rate / 44100, cd = sp_clamp(p[3], 0, (flo_t) 0.012) * rate, cb = (flo_t) 0.015 * rate,
             cstep = sp_clamp(p[4], 0, 20) / rate, sw = rate / 20, sstep = 1 / sw,
             dd = sp_clamp(p[7], (flo_t) 0.001, 2) * rate, dfb = sp_clamp(p[8], 0, (flo_t) 0.95), dt = sp_clamp(p[9], (flo_t) 0.01, 1),
             t60 = sp_clamp(p[12], (flo_t) 0.1, 60), sz = sp_clamp(p[13], (flo_t) 0.25, 3), damp = sp_clamp(p[14], 0, (flo_t) 0.95);
 uint64_t len[sp_lines], apl[sp_aps];
 flo_t gain[sp_lines];
 for (int i = 0; i < sp_lines; i++)   // each line loses 60 dB in t60 seconds, whatever its length
  len[i] = (uint64_t) (sp_fdn[i] * sz * k), gain[i] = sp_exp((flo_t) -6.907755278982137 * (flo_t) len[i] / (rate * t60));
 for (int i = 0; i < sp_aps; i++) apl[i] = (uint64_t) (sp_ap[i] * k);
 // the shimmer gives back a share of what the lines lose a pass: at 1 a tail rings some four
 // times its t60, and a longer t60 stays as stable as a short one
 flo_t sg = 0;
 for (int i = 0; i < sp_lines; i++) sg += gain[i];
 sg = (flo_t) 4.5 * (1 - sg / sp_lines);
 uint64_t const dn = (uint64_t) dd;
 flo_t tgt[sp_ramps], inc[sp_ramps];
 for (int i = 0; i < sp_ramps; i++) tgt[i] = sp_clamp(p[sp_ramp[i]], 0, sp_rhi[i]), inc[i] = (tgt[i] - h->cur[i]) / (flo_t) n;
 uint64_t w = h->w;
 flo_t lfo = h->lfo, shp = h->shp;
 for (uintptr_t i = 0; i < n; i++, w++) {
  flo_t *v = h->cur;
  for (int j = 0; j < sp_ramps; j++) v[j] += inc[j];
  flo_t x = L[i], y = R[i];
  // chorus: each side moved toward itself read a moving 15 ms back, the right a quarter turn behind
  chl[w & (c.ch - 1)] = x, chr[w & (c.ch - 1)] = y;
  if (v[0] > 0 || v[1] > 0) {
   flo_t const ml = sp_tap(chl, c.ch - 1, w, cb + cd * sp_sin(lfo)), mr = sp_tap(chr, c.ch - 1, w, cb + cd * sp_sin(lfo + (flo_t) 0.25));
   x += (flo_t) 0.5 * v[1] * v[0] * (ml - x), y += (flo_t) 0.5 * v[1] * v[0] * (mr - y); }   // wettest is half each: no louder
  lfo += cstep;
  if (lfo >= 1) lfo -= 1;
  // the delay: each side's echo, toned, fed back into the other's line
  flo_t const el = dll[(w - dn) & (c.dl - 1)], er = dlr[(w - dn) & (c.dl - 1)];
  h->dlp[0] += dt * (el - h->dlp[0]) + sp_tiny - sp_tiny, h->dlp[1] += dt * (er - h->dlp[1]) + sp_tiny - sp_tiny;
  dll[w & (c.dl - 1)] = v[2] * x + dfb * h->dlp[1], dlr[w & (c.dl - 1)] = v[2] * y + dfb * h->dlp[0];
  x += v[3] * h->dlp[0], y += v[3] * h->dlp[1];
  // the shimmer: the tail read by two heads closing on the present at twice its speed, each
  // faded in and out over its sweep and half a sweep apart, so their sum is an octave up, smooth
  flo_t s = (flo_t) 0.5 * v[4] * (x + y);
  if (v[6] > 0) {
   flo_t const q = shp + (flo_t) 0.5 - (shp >= (flo_t) 0.5), wa = sp_sin(shp / 2), wb = sp_sin(q / 2);
   s += sg * v[6] * (wa * wa * sp_tap(shl, c.sh - 1, w, 1 + sw * (1 - shp)) + wb * wb * sp_tap(shl, c.sh - 1, w, 1 + sw * (1 - q))
                + wa * wa * sp_tap(shr, c.sh - 1, w, 1 + sw * (1 - shp)) + wb * wb * sp_tap(shr, c.sh - 1, w, 1 + sw * (1 - q))); }
  shp += sstep;
  if (shp >= 1) shp -= 1;
  // the reverb: the sum diffused, into every line
  for (int j = 0; j < sp_aps; j++) {
   uintptr_t const m = c.ap[j] - 1;
   flo_t const d = ap[j][(w - apl[j]) & m], o = d - (flo_t) 0.6 * s;
   ap[j][w & m] = s + (flo_t) 0.6 * o + sp_tiny - sp_tiny, s = o; }
  flo_t o[sp_lines], sum = 0, sl = 0, sr = 0;
  for (int j = 0; j < sp_lines; j++) {
   flo_t const d = fdn[j][(w - len[j]) & (c.fdn[j] - 1)];
   h->flp[j] = d + damp * (h->flp[j] - d) + sp_tiny - sp_tiny;
   o[j] = h->flp[j] * gain[j], sum += o[j];
   sl += sp_ls[j] * o[j], sr += sp_rs[j] * o[j]; }
  sum *= (flo_t) 2 / sp_lines;
  for (int j = 0; j < sp_lines; j++) fdn[j][w & (c.fdn[j] - 1)] = o[j] - sum + (j & 1 ? -s : s);
  shl[w & (c.sh - 1)] = (flo_t) 0.5 * sl, shr[w & (c.sh - 1)] = (flo_t) 0.5 * sr;
  L[i] = x + v[5] * (flo_t) 0.5 * sl, R[i] = y + v[5] * (flo_t) 0.5 * sr; }
 for (int j = 0; j < sp_ramps; j++) h->cur[j] = tgt[j];
 h->w = w, h->lfo = lfo, h->shp = shp;
 struct chain *r = ini_chain(bump(g, Width(struct chain)), (intptr_t) word(tl), (intptr_t) word(tr));
 a[0] = word(r);
 return g; }
static lvm(lvm_space) { LvmCallp(g, 3, host_space) }

enum { sw_nprm = 8 };
// the filter's g = tan(pi c / rate) at frame f
static flo_t sw_g(flo_t const *p, int64_t f) {
 flo_t const l = p[5] + p[4] * (flo_t) f / p[0], c = sp_clamp(p[2] * sp_exp((flo_t) 0.6931471805599453 * p[3] * sp_sin(l)), 10, (flo_t) 0.45 * p[0]),
             t = c / (2 * p[0]);
 return sp_sin(t) / sp_sin(t + (flo_t) 0.25); }

love_noinline static struct g *host_sweep(struct g *g) {
 word *a = g->sp;
 // (sweep x st prm)
 if (!galaxyp(a[0]) || tray(a[0])->rank != 1 || !galaxyp(a[2]) || tray(a[2])->type != love_R || tray_nelem(tray(a[2])) < sw_nprm) { a[0] = ZeroPoint; return g; }
 flo_t p[sw_nprm];
 for (int i = 0; i < sw_nprm; i++) p[i] = tray_get_flo(tray(a[2]), (uintptr_t) i);
 uintptr_t const n = tray_nelem(tray(a[0])), w1 = b2w(tray_bytes(love_R, 1, n)), w2 = b2w(tray_bytes(love_R, 1, 2));
 if (!(p[0] >= 1000 && p[0] <= 384000) || !(p[6] > (flo_t) 0.05) || n > 1 << 22) { a[0] = ZeroPoint; return g; }
 if (!ok(g = have(g, w1 + w2 + Width(struct chain)))) return g;
 a = g->sp;
 struct tray *ty = ini_tray(bump(g, w1), love_R, 1), *ts = ini_tray(bump(g, w2), love_R, 1);
 ty->shape[0] = n, ts->shape[0] = 2;
 flo_t *y = tray_data(ty), *z = tray_data(ts);
 int const carried = galaxyp(a[1]) && tray_nelem(tray(a[1])) == 2;
 z[0] = carried ? tray_get_flo(tray(a[1]), 0) : 0, z[1] = carried ? tray_get_flo(tray(a[1]), 1) : 0;
 flo_t const k = 1 / p[6];
 int const band = p[7] > (flo_t) 0.5;
 int64_t const f0 = (int64_t) p[1];
 int64_t b = -1;
 flo_t g0 = 0, g1 = 0;
 for (uintptr_t i = 0; i < n; i++) {
  int64_t const f = f0 + (int64_t) i, fb = f >= 0 ? f >> 5 : -((-f + 31) >> 5);
  if (fb != b) b = fb, g0 = sw_g(p, b * 32), g1 = sw_g(p, b * 32 + 32);
  flo_t const gg = g0 + (g1 - g0) * (flo_t) (f - b * 32) / 32,
              a1 = 1 / (1 + gg * (gg + k)), a2 = gg * a1, a3 = gg * a2,
              v3 = tray_get_flo(tray(a[0]), i) - z[1], v1 = a1 * z[0] + a2 * v3, v2 = z[1] + a2 * z[0] + a3 * v3;
  z[0] = 2 * v1 - z[0] + sp_tiny - sp_tiny, z[1] = 2 * v2 - z[1] + sp_tiny - sp_tiny;
  y[i] = band ? k * v1 : v2; }
 struct chain *r = ini_chain(bump(g, Width(struct chain)), (intptr_t) word(ty), (intptr_t) word(ts));
 a[0] = word(r);
 return g; }
static lvm(lvm_sweep) { LvmCallp(g, 2, host_sweep) }

LvDef("space", space, 4, "dsp");
LvDef("sweep", sweep, 3, "dsp");
