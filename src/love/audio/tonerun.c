// src/love/audio/tonerun.c -- tones.h's operators run: an envelope or a glide stepped by a
// constant factor, a sine by its series, the noise the frame's number hashed
#include "tones.h"

typedef tn_flo flo_t;
#define love_inline inline __attribute__((always_inline))
#if UINTPTR_MAX == UINT64_MAX
#define Bits 64
double lm_exp(double);
#define tn_exp lm_exp
enum { tn_lfo = 0 };
#else
#define Bits 32
float lm_expf(float);
#define tn_exp lm_expf
enum { tn_lfo = 15 };   // vibrato and tremolo taken each 16 frames and held
#endif
#define tn_ln10_20 ((flo_t) 0.11512925464970229)   // ln 10 / 20
#define tn_floor ((flo_t) 1.5848931924611134e-05)    // 96 dB down

static love_inline flo_t tn_fl(flo_t x) { flo_t f = (flo_t) (intptr_t) x; return f > x ? f - 1 : f; }
// sine of x turns: folded to a quarter turn either side of 0, then its series to z^13
static love_inline flo_t tn_sin(flo_t x) {
 flo_t u = x - tn_fl(x);
 if (u > (flo_t) 0.5) u -= 1;
 if (u > (flo_t) 0.25) u = (flo_t) 0.5 - u;
 else if (u < -(flo_t) 0.25) u = -(flo_t) 0.5 - u;
 flo_t const z = u * (flo_t) 6.283185307179586, q = z * z;
#if Bits == 64
 return z * (1 + q * (-(flo_t) 0.16666666666666666 + q * ((flo_t) 0.008333333333333333 + q * (-(flo_t) 0.0001984126984126984
          + q * ((flo_t) 2.7557319223985893e-06 + q * (-(flo_t) 2.505210838544172e-08 + q * (flo_t) 1.6059043836821613e-10))))));
#else
 return z * ((flo_t) 0.9999966158999021 + q * (-(flo_t) 0.166648283792627 + q * ((flo_t) 0.008306325205790568 + q * -(flo_t) 0.00018363653481551223)));
#endif
}
// harp's noise: the frame's number hashed, so a frame always draws the same sample
static flo_t tn_noise(int64_t ix) {
 uint64_t a = ((uint64_t) ix * 1103515245u + 12345u) & 0xffffffffu;
 uint64_t b = ((a ^ a >> 16) * 2246822507u) & 0xffffffffu;
 uint64_t c = ((b ^ b >> 13) * 3266489909u) & 0xffffffffu;
 return (flo_t) (int) (c >> 16 & 65535) * (flo_t) 0.000030517578125 - 1; }
static love_inline flo_t tn_wave(int w, flo_t x, int64_t ix, flo_t duty) {
 flo_t u, s;
 switch (w) {
  case 0: return tn_sin(x);
  case 1: s = tn_sin(x); return s > 0 ? s : 0;
  case 2: s = tn_sin(x); return s > 0 ? s : -s;
  case 3: s = tn_sin(x), u = x - tn_fl(x); return (s > 0 ? s : -s) * (u - (u >= (flo_t) 0.5 ? (flo_t) 0.5 : 0) < (flo_t) 0.25);
  case 4: u = x - tn_fl(x); return u < (flo_t) 0.5 ? 4 * u - 1 : 3 - 4 * u;
  case 5: u = x - tn_fl(x); return 2 * u - 1;
  case 6: u = x - tn_fl(x); return u < duty ? 1 : -1;
  case 8: u = x - tn_fl(x); return u < duty ? 1 : 0;
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
static void tn_op(flo_t const *o, flo_t const *mod, flo_t const *am, flo_t *y, flo_t *L, flo_t *R, intptr_t n,
                  int64_t f0, flo_t rate, flo_t *y1, flo_t *y2) {
 flo_t const dt = 1 / rate, f = o[1], k = o[2], g = o[3], ka = o[4], dep = o[7], fb = o[8] / 2,
             gl = o[9], gr = o[10], vib = o[11], vr = o[12], trem = o[13], tr = o[14], duty = o[16], lvl = o[17];
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
  flo_t tg = 1, vx = 0;
  for (; i < n; i++, t += dt) {
   if (t >= E.next) tn_enter(&E, t, dt);
   if (!(i & tn_lfo)) {
    if (trem != 0) tg = tn_exp(-trem * ((flo_t) 0.5 - (flo_t) 0.5 * tn_sin(tr * t + (flo_t) 0.25)) * tn_ln10_20);
    if (vamp != 0) vx = vamp * (1 - tn_sin(vr * t + (flo_t) 0.25)); }
   flo_t a = tn_amp(&E) * lvl * tg;
   if (am) a *= am[i];
   flo_t x = k != 0 ? f * (ek - 1) / k : f * t;
   if (g != 0) x += g * (1 - ed);
   x += vx;
   if (mod) x += dep * mod[i];
   if (fb != 0) x += fb * (a1 + a2);
   flo_t const v = a == 0 ? 0 : a * tn_wave(w, x, f0 + i, duty);
   y[i] = v, a2 = a1, a1 = v;
   if (gl != 0) L[i] += v * gl;
   if (gr != 0) R[i] += v * gr;
   tn_step(&E), ek *= rk, ed *= rd; } }
 *y1 = a1, *y2 = a2; }

void tones_run(flo_t const *ops, uintptr_t no, flo_t *st, intptr_t n, int64_t f0, flo_t rate,
               flo_t *L, flo_t *R, flo_t *sc) {
 for (uintptr_t j = 0; j < no; j++) {
  flo_t const *o = ops + j * tn_row;
  intptr_t const m = (intptr_t) o[6], q = (intptr_t) o[15];
  tn_op(o, m >= 0 && (uintptr_t) m < j ? sc + (uintptr_t) m * (uintptr_t) n : 0,
        q >= 0 && (uintptr_t) q < j ? sc + (uintptr_t) q * (uintptr_t) n : 0, sc + j * (uintptr_t) n, L, R, n, f0, rate,
        st + 2 * j, st + 2 * j + 1); } }
