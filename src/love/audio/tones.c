// src/love/audio/tones.c -- voices as small graphs of operators, run over a run of frames and
// summed to stereo: harp's timbres, doom's FM instruments, the gamelan's chimes. love lays each
// voice's operators and decides their envelopes (src/apps/harp/ops.l); this runs the frames.
// (tones ops st n f0 rate) -> a float tray: n frames of left, n of right, then each operator's
//   last two outputs (for its feedback, handed back next time as st; any other st, () say, is
//   all at rest), then scratch. ops is a float
//   tray of rows of tn_row numbers, an operator a row, a modulator before what it moves:
//    0 at     the frame its voice starts           1 f      its frequency, Hz
//    2 slide  nepers a second it glides; phase f (e^kt - 1) / k
//    3 drop 4 kappa  a falling start: g (1 - e^-kappa t) cycles more
//    5 wave   0 sine 1 half 2 abs 3 quarter 4 tri 5 saw 6 square 7 noise
//    6 mod    the row whose output moves this one's phase, -1 none   7 depth  cycles a unit
//    8 fb     cycles the mean of its own last two outputs moves it
//    9 l 10 r how much of it reaches each side (a modulator 0)
//   11 vib 12 vrate  vibrato, a fraction of f at vrate Hz
//   13 trem 14 trate tremolo, dB down at trate Hz
//   15 16    spare                                       17 lvl  a factor over its envelope
//   18 nseg  then nseg segments of 5, t0 (seconds from at) kind a b c, the last begun ruling:
//      kind 0  10^(-(a + b tau) / 20)          kind 1  a + b tau, at least 0
//      kind 2  (1 - e^(-a tau)) 10^(-b tau / 20)
//      kind 3  (1 - e^(-a tau)) (c + (1 - c) 10^(-b tau / 20))
//      before the first segment, or 96 dB down, it is silent
//   an envelope or a glide is stepped a frame at a time by a constant factor, a sine a polynomial:
//   no libm call a frame. | () for a bad argument
#include "love.h"
#if Bits == 64
double lm_exp(double);
#define tn_exp lm_exp
#else
float lm_expf(float);
#define tn_exp lm_expf
#endif

enum { tn_row = 49, tn_segs = 6, tn_seg0 = 19 };
#define tn_ln10_20 ((flo_t) 0.11512925464970229)   // ln 10 / 20
#define tn_floor ((flo_t) 1.5848931924611134e-05)    // 96 dB down

static love_inline flo_t tn_fl(flo_t x) { flo_t f = (flo_t) (int64_t) x; return f > x ? f - 1 : f; }
// sine of x turns: folded to a quarter turn either side of 0, then its series to z^13
static love_inline flo_t tn_sin(flo_t x) {
 flo_t u = x - tn_fl(x);
 if (u > (flo_t) 0.5) u -= 1;
 if (u > (flo_t) 0.25) u = (flo_t) 0.5 - u;
 else if (u < (flo_t) -0.25) u = (flo_t) -0.5 - u;
 flo_t const z = u * (flo_t) 6.283185307179586, q = z * z;
 return z * (1 + q * ((flo_t) -1 / 6 + q * ((flo_t) 1 / 120 + q * ((flo_t) -1 / 5040 + q * ((flo_t) 1 / 362880
          + q * ((flo_t) -1 / 39916800 + q * ((flo_t) 1 / 6227020800.0)))))));
}
// harp's noise: the frame's number hashed, so a frame always draws the same sample
static flo_t tn_noise(int64_t ix) {
 uint64_t a = ((uint64_t) ix * 1103515245u + 12345u) & 0xffffffffu;
 uint64_t b = ((a ^ a >> 16) * 2246822507u) & 0xffffffffu;
 uint64_t c = ((b ^ b >> 13) * 3266489909u) & 0xffffffffu;
 return (flo_t) (c >> 16 & 65535) * (flo_t) 0.000030517578125 - 1; }
static love_inline flo_t tn_wave(int w, flo_t x, int64_t ix) {
 flo_t u, s;
 switch (w) {
  case 0: return tn_sin(x);
  case 1: s = tn_sin(x); return s > 0 ? s : 0;
  case 2: s = tn_sin(x); return s > 0 ? s : -s;
  case 3: s = tn_sin(x), u = x - tn_fl(x); return (s > 0 ? s : -s) * (u - (u >= (flo_t) 0.5 ? (flo_t) 0.5 : 0) < (flo_t) 0.25);
  case 4: u = x - tn_fl(x); return u < (flo_t) 0.5 ? 4 * u - 1 : 3 - 4 * u;
  case 5: u = x - tn_fl(x); return 2 * u - 1;
  case 6: u = x - tn_fl(x); return u < (flo_t) 0.5 ? 1 : -1;
  default: return tn_noise(ix); } }

// an envelope's state: which segment, and its stepping factors and values
struct tn_env { intptr_t seg, nseg; flo_t const *s; flo_t next, v, e, d, rv, re, rd; };
static void tn_enter(struct tn_env *E, flo_t t, flo_t dt) {
 while (E->seg + 1 < E->nseg && t >= E->s[5 * (E->seg + 1)]) E->seg++;
 E->next = E->seg + 1 < E->nseg ? E->s[5 * (E->seg + 1)] : (flo_t) 1e30;
 if (E->seg < 0) { E->v = E->e = E->d = 0, E->rv = 0, E->re = E->rd = 1; return; }
 flo_t const *p = E->s + 5 * E->seg, tau = t - p[0];
 int const k = (int) p[1];
 if (k == 0) E->v = tn_exp(-(p[2] + p[3] * tau) * tn_ln10_20), E->rv = tn_exp(-p[3] * dt * tn_ln10_20);
 else if (k == 1) E->v = p[2] + p[3] * tau, E->rv = p[3] * dt;
 else E->e = tn_exp(-p[2] * tau), E->re = tn_exp(-p[2] * dt),
      E->d = tn_exp(-p[3] * tau * tn_ln10_20), E->rd = tn_exp(-p[3] * dt * tn_ln10_20); }
static love_inline flo_t tn_amp(struct tn_env *E) {
 if (E->seg < 0) return 0;
 flo_t const *p = E->s + 5 * E->seg;
 int const k = (int) p[1];
 flo_t a = k == 0 || k == 1 ? E->v : k == 2 ? (1 - E->e) * E->d : (1 - E->e) * (p[4] + (1 - p[4]) * E->d);
 return a < tn_floor ? 0 : a; }
static love_inline void tn_step(struct tn_env *E) {
 if (E->seg < 0) return;
 int const k = (int) E->s[5 * E->seg + 1];
 if (k == 0) E->v *= E->rv;
 else if (k == 1) E->v += E->rv;
 else E->e *= E->re, E->d *= E->rd; }

// one operator over the n frames from f0 into y, onto L R
static void tn_op(flo_t const *o, flo_t const *mod, flo_t *y, flo_t *L, flo_t *R, intptr_t n, int64_t f0,
                  flo_t rate, flo_t *y1, flo_t *y2) {
 flo_t const dt = 1 / rate, f = o[1], k = o[2], g = o[3], ka = o[4], dep = o[7], fb = o[8] / 2,
             gl = o[9], gr = o[10], vib = o[11], vr = o[12], trem = o[13], tr = o[14], lvl = o[17];
 int const w = (int) o[5];
 intptr_t ns = (intptr_t) o[18];
 if (ns > tn_segs) ns = tn_segs;
 flo_t a1 = *y1, a2 = *y2;
 intptr_t i = 0;
 int64_t const at = (int64_t) o[0];
 for (; i < n && f0 + i < at; i++) y[i] = 0;   // not begun
 if (i < n) {
  flo_t t = (flo_t) (f0 + i - at) * dt;
  struct tn_env E = { .seg = -1, .nseg = ns, .s = o + tn_seg0 };
  tn_enter(&E, t, dt);
  flo_t ek = k != 0 ? tn_exp(k * t) : 0, rk = k != 0 ? tn_exp(k * dt) : 1,
        ed = g != 0 ? tn_exp(-ka * t) : 0, rd = g != 0 ? tn_exp(-ka * dt) : 1;
  flo_t const vamp = vib != 0 && vr != 0 ? f * vib / (vr * (flo_t) 6.283185307179586) : 0;
  for (; i < n; i++, t += dt) {
   if (t >= E.next) tn_enter(&E, t, dt);
   flo_t a = tn_amp(&E) * lvl;
   if (trem != 0) a *= tn_exp(-trem * ((flo_t) 0.5 - (flo_t) 0.5 * tn_sin(tr * t + (flo_t) 0.25)) * tn_ln10_20);
   flo_t x = k != 0 ? f * (ek - 1) / k : f * t;
   if (g != 0) x += g * (1 - ed);
   if (vamp != 0) x += vamp * (1 - tn_sin(vr * t + (flo_t) 0.25));
   if (mod) x += dep * mod[i];
   if (fb != 0) x += fb * (a1 + a2);
   flo_t const v = a == 0 ? 0 : a * tn_wave(w, x, f0 + i);
   y[i] = v, a2 = a1, a1 = v;
   if (gl != 0) L[i] += v * gl;
   if (gr != 0) R[i] += v * gr;
   tn_step(&E), ek *= rk, ed *= rd; } }
 *y1 = a1, *y2 = a2; }

love_noinline static struct g *host_tones(struct g *g) {
 word *a = g->sp;
 // (tones ops st n f0 rate)
 if (!galaxyp(a[0]) || tray(a[0])->type != love_R || !(a[2] & 1) || !isnum(a[3]) || !isnum(a[4])) { a[0] = ZeroPoint; return g; }
 intptr_t const n = getcharm(a[2]);
 uintptr_t const no = tray_nelem(tray(a[0])) / tn_row;
 if (n < 0 || n > 1 << 22 || no > 4096 || tray_nelem(tray(a[0])) % tn_row) { a[0] = ZeroPoint; return g; }
 uintptr_t const len = 2 * (uintptr_t) n + 2 * no + no * (uintptr_t) n, w = b2w(tray_bytes(love_R, 1, len));
 if (!ok(g = have(g, w))) return g;
 a = g->sp;
 struct tray *out = ini_tray(bump(g, w), love_R, 1);
 out->shape[0] = len;
 flo_t *d = tray_data(out), *L = d, *R = d + n, *st = d + 2 * n, *sc = st + 2 * no;
 for (uintptr_t i = 0; i < 2 * (uintptr_t) n; i++) d[i] = 0;
 flo_t const *ops = tray_data(tray(a[0])), rate = toflo(a[4]);
 int64_t const f0 = (int64_t) toflo(a[3]);
 if (rate <= 0) { a[0] = ZeroPoint; return g; }
 // the outputs carried in, read after the allocation, which may move them
 word const s0 = a[1];
 int const carried = galaxyp(s0) && tray(s0)->type == love_R && tray_nelem(tray(s0)) == 2 * no;
 for (uintptr_t j = 0; j < 2 * no; j++) st[j] = carried ? tray_get_flo(tray(s0), j) : 0;
 for (uintptr_t j = 0; j < no; j++) {
  flo_t const *o = ops + j * tn_row;
  intptr_t const m = (intptr_t) o[6];
  tn_op(o, m >= 0 && (uintptr_t) m < j ? sc + (uintptr_t) m * (uintptr_t) n : 0, sc + j * (uintptr_t) n, L, R, n, f0, rate,
        st + 2 * j, st + 2 * j + 1); }
 a[0] = word(out);
 return g; }
static lvm(lvm_tones) { LvmCallp(g, 4, host_tones) }

LvDef("tones", tones, 5, "dsp");
