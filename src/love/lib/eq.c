// src/love/lib/eq.c -- the player's bus: a biquad cascade and a spectrum, over s16le pcm.
// numbers cross in Q40, int64 little-endian (love lays them with pinv): love works out the
// coefficients, window and twiddles, so nothing here needs libm.
// (biquads pcm ch co st) -> (out . st): pcm interleaved s16le of ch (1 or 2) channels through
//   co = [g0 g1] then [b0 b1 b2 a1 a2] a band (a0 divided out), each channel scaled by its g
//   after the bands, rounded and saturated. st is the filters' memory, answered fresh each
//   run and carried by the caller; any other length starts them at rest. | 'badarg
// (spectrum pcm ch tw edges) -> the power of each band, int64s | 'badarg. the last n frames
//   of pcm (zeros ahead of a short one), mixed to mono, through tw = n window values then
//   n/2 cosines and n/2 sines (n a power of two); edges = u16 fft bins e0 e1 .., band i
//   the most power in bins [ei, ei+1), or bin ei alone when that range is empty.
#include "love.h"
#include <stdint.h>
#include <string.h>

#define Q40 1099511627776.0

static int64_t eq_i64(const uint8_t *p) {
 uint64_t v = 0;
 for (int k = 7; k >= 0; k--) v = v << 8 | p[k];
 return (int64_t) v; }
static double eq_q(const uint8_t *p, uintptr_t i) { return (double) eq_i64(p + 8 * i) / Q40; }
static int eq_s16(const uint8_t *p, uintptr_t i) { return (int16_t) (uint16_t) (p[2 * i] | p[2 * i + 1] << 8); }

static struct g *host_biquads(struct g *g) {
 word w = g->sp[1];
 if (!(strp(g->sp[0]) || caskp(g->sp[0])) || !oddp(w) || !strp(g->sp[2]) || !strp(g->sp[3]))
  return g->sp[3] = badarg(g), g->sp += 3, g;
 intptr_t ch = getcharm(w);
 uintptr_t nco = len(g->sp[2]) / 8;
 if (ch < 1 || ch > 2 || nco < 2 || (nco - 2) % 5) return g->sp[3] = badarg(g), g->sp += 3, g;
 uintptr_t nb = (nco - 2) / 5, ns = len(bytes_of(g->sp[0])) / 2 / (uintptr_t) ch * (uintptr_t) ch,
           nst = nb * (uintptr_t) ch * 4 * sizeof(double), nout = ns * 2;
 if (!ok(g = have(g, str_width(nout) + str_width(nst) + Width(struct chain)))) return g;
 struct str *out = ini_str(bump(g, str_width(nout)), nout), *st = ini_str(bump(g, str_width(nst)), nst);
 const uint8_t *in = (const uint8_t*) bytes_of(g->sp[0])->bytes, *co = (const uint8_t*) txt(g->sp[2]);
 double *m = (double*) st->bytes;
 if (len(g->sp[3]) == nst) memcpy(m, txt(g->sp[3]), nst);
 else memset(m, 0, nst);
 uint8_t *o = (uint8_t*) out->bytes;
 for (uintptr_t i = 0; i < ns; i++) {
  uintptr_t c = i % (uintptr_t) ch;
  double x = eq_s16(in, i);
  for (uintptr_t b = 0; b < nb; b++) {
   double *z = m + 4 * (b * (uintptr_t) ch + c);   // x1 x2 y1 y2
   uintptr_t k = 2 + 5 * b;
   double y = eq_q(co, k) * x + eq_q(co, k + 1) * z[0] + eq_q(co, k + 2) * z[1]
            - eq_q(co, k + 3) * z[2] - eq_q(co, k + 4) * z[3];
   z[1] = z[0], z[0] = x, z[3] = z[2], z[2] = y, x = y; }
  x *= eq_q(co, c);
  long v = (long) (x < 0 ? x - 0.5 : x + 0.5);
  v = v > 32767 ? 32767 : v < -32768 ? -32768 : v;
  o[2 * i] = (uint8_t) v, o[2 * i + 1] = (uint8_t) ((unsigned long) v >> 8); }
 struct chain *r = ini_chain(bump(g, Width(struct chain)), (intptr_t) out, (intptr_t) st);
 return g->sp[3] = word(r), g->sp += 3, g; }

static struct g *host_spectrum(struct g *g) {
 if (!(strp(g->sp[0]) || caskp(g->sp[0])) || !oddp(g->sp[1]) || !strp(g->sp[2]) || !strp(g->sp[3]))
  return g->sp[3] = badarg(g), g->sp += 3, g;
 intptr_t ch = getcharm(g->sp[1]);
 uintptr_t n = len(g->sp[2]) / 16, ne = len(g->sp[3]) / 2;
 if (ch < 1 || ch > 2 || n < 2 || (n & (n - 1)) || n > 65536 || ne < 2) return g->sp[3] = badarg(g), g->sp += 3, g;
 uintptr_t nw = 2 * n * sizeof(double), nout = (ne - 1) * 8;
 if (!ok(g = have(g, str_width(nw) + str_width(nout)))) return g;
 struct str *work = ini_str(bump(g, str_width(nw)), nw), *out = ini_str(bump(g, str_width(nout)), nout);
 const uint8_t *in = (const uint8_t*) bytes_of(g->sp[0])->bytes, *tw = (const uint8_t*) txt(g->sp[2]),
               *ed = (const uint8_t*) txt(g->sp[3]);
 uintptr_t nf = len(bytes_of(g->sp[0])) / 2 / (uintptr_t) ch, skip = nf > n ? nf - n : 0, pad = nf < n ? n - nf : 0;
 double *re = (double*) work->bytes, *im = re + n;
 for (uintptr_t i = 0; i < n; i++) {
  double s = 0;
  if (i >= pad) {
   uintptr_t f = skip + i - pad;
   s = ch == 2 ? (eq_s16(in, 2 * f) + eq_s16(in, 2 * f + 1)) / 2.0 : eq_s16(in, f); }
  re[i] = s * eq_q(tw, i), im[i] = 0; }
 for (uintptr_t i = 1, j = 0; i < n; i++) {        // bit-reversed order
  uintptr_t b = n >> 1;
  for (; j & b; b >>= 1) j ^= b;
  j ^= b;
  if (i < j) { double t = re[i]; re[i] = re[j], re[j] = t; } }
 for (uintptr_t h = 1; h < n; h <<= 1)              // butterflies, twiddle e^(-2 pi i k / n)
  for (uintptr_t a = 0; a < n; a += 2 * h)
   for (uintptr_t k = 0; k < h; k++) {
    uintptr_t t = k * (n / (2 * h));
    double c = eq_q(tw, n + t), s = eq_q(tw, n + n / 2 + t),
           xr = re[a + k + h] * c + im[a + k + h] * s, xi = im[a + k + h] * c - re[a + k + h] * s;
    re[a + k + h] = re[a + k] - xr, im[a + k + h] = im[a + k] - xi;
    re[a + k] += xr, im[a + k] += xi; }
 uint8_t *o = (uint8_t*) out->bytes;
 for (uintptr_t b = 0; b + 1 < ne; b++) {
  uintptr_t lo = (uintptr_t) (ed[2 * b] | ed[2 * b + 1] << 8), hi = (uintptr_t) (ed[2 * b + 2] | ed[2 * b + 3] << 8);
  if (lo >= n / 2) lo = n / 2 - 1;
  if (hi <= lo) hi = lo + 1;
  if (hi > n / 2) hi = n / 2;
  double p = 0;
  for (uintptr_t k = lo; k < hi; k++) { double q = re[k] * re[k] + im[k] * im[k]; if (q > p) p = q; }
  uint64_t v = p >= 4.6e18 ? (uint64_t) 4600000000000000000ull : (uint64_t) p;
  for (int k = 0; k < 8; k++) o[8 * b + k] = (uint8_t) (v >> (8 * k)); }
 return g->sp[3] = word(out), g->sp += 3, g; }

static lvm(lvm_biquads) LvmCall(g, host_biquads)
static lvm(lvm_spectrum) LvmCall(g, host_spectrum)
static union u const
  nif_biquads[] = {{lvm_cur}, {.x = putcharm(4)}, {lvm_biquads}, {lvm_ret0}},
  nif_spectrum[] = {{lvm_cur}, {.x = putcharm(4)}, {lvm_spectrum}, {lvm_ret0}};
LvNif("biquads", nif_biquads, "dsp");
LvNif("spectrum", nif_spectrum, "dsp");
