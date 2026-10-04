// src/love/lib/flac.c
// (flac-frame s o bps ch) -> (pcm . next): the frame at s[o] decoded (rfc 9639), its samples
// interleaved little-endian in (bps + 7) / 8 bytes each, right-justified, and the offset just
// past it | why not: 1 no frame there, 2 cut short, 3 a kind it can't read, 4 a bad stream
// (a crc, a reserved code, a frame that disagrees with the stream's bps or ch).
// bps and ch are the streaminfo's. samples are held 64 bits wide: a 32-bit stream's side
// channel is 33.
// (flac-encode pcm ch bps rate fno level) -> frame number fno of the samples in pcm, laid out
// as flac-frame answers them, at level 0..8 | 3 when it cannot be (a bad shape, past 65535).
#include "love.h"
#include <stdint.h>
#include <string.h>

struct fb { const uint8_t *s; uintptr_t n, p; int k, bad; };   // the bytes, byte p, k bits of it read
struct fh { int bs, nch, assign, bps; };                        // block size, channels, their coupling, bits

static uint64_t fb_bits(struct fb *b, int w) {
 uint64_t v = 0;
 while (w > 0) {
  if (b->p >= b->n) { if (!b->bad) b->bad = 2; return 0; }
  int room = 8 - b->k, t = w < room ? w : room;
  v = v << t | (uint64_t) (b->s[b->p] >> (room - t) & ((1u << t) - 1));
  w -= t, b->k += t;
  if (b->k == 8) b->k = 0, b->p++; }
 return v; }

static int64_t fb_sbits(struct fb *b, int w) {
 if (!w) return 0;
 uint64_t v = fb_bits(b, w), m = (uint64_t) 1 << (w - 1);
 return (int64_t) (v ^ m) - (int64_t) m; }

// zeros up to a one, which is read too
static uint64_t fb_unary(struct fb *b) {
 uint64_t q = 0;
 for (;;) {
  if (b->p >= b->n) { if (!b->bad) b->bad = 2; return 0; }
  unsigned x = (unsigned) (b->s[b->p] << b->k) & 0xff;
  if (x) {
   int z = 0;
   while (!(x & 0x80)) x <<= 1, z++;
   q += (uint64_t) z, b->k += z + 1;
   if (b->k == 8) b->k = 0, b->p++;
   return q; }
  q += (uint64_t) (8 - b->k), b->k = 0, b->p++; } }

// floor(v / 2^s), without a right shift of a negative
static int64_t ff_floor(int64_t v, int s) {
 return v >= 0 ? v >> s : -(int64_t) (((uint64_t) -v + ((uint64_t) 1 << s) - 1) >> s); }

static unsigned ff_crc8(const uint8_t *p, uintptr_t n) {
 unsigned c = 0;
 for (uintptr_t i = 0; i < n; i++) {
  c ^= p[i];
  for (int j = 0; j < 8; j++) c = (c & 0x80 ? c << 1 ^ 0x07 : c << 1) & 0xff; }
 return c; }

static unsigned ff_crc16(const uint8_t *p, uintptr_t n) {
 unsigned c = 0;
 for (uintptr_t i = 0; i < n; i++) {
  c ^= (unsigned) p[i] << 8;
  for (int j = 0; j < 8; j++) c = (c & 0x8000 ? c << 1 ^ 0x8005 : c << 1) & 0xffff; }
 return c; }

// the frame header at b->p -> 0 | why, with h filled
static int ff_head(struct fb *b, int sbps, int sch, struct fh *h) {
 uintptr_t o = b->p;
 if (b->n - o < 2) return 2;
 if (b->s[o] != 0xff || (b->s[o + 1] & 0xfe) != 0xf8) return 1;
 b->p += 2;
 unsigned bsc = (unsigned) fb_bits(b, 4), rc = (unsigned) fb_bits(b, 4),
          ac = (unsigned) fb_bits(b, 4), sc = (unsigned) fb_bits(b, 3);
 if (fb_bits(b, 1) || !bsc || rc == 15 || ac > 10 || sc == 3) return b->bad ? b->bad : 4;
 uint64_t c = fb_bits(b, 8);                     // the coded frame or sample number: its length
 int more = 0;
 while (more < 8 && c & 0x80 >> more) more++;
 if (more == 1 || more == 8) return b->bad ? b->bad : 4;
 for (int i = 1; i < more; i++) if ((fb_bits(b, 8) & 0xc0) != 0x80) return b->bad ? b->bad : 4;
 h->bs = bsc == 1 ? 192 : bsc <= 5 ? 576 << (bsc - 2) : bsc == 6 ? (int) fb_bits(b, 8) + 1
       : bsc == 7 ? (int) fb_bits(b, 16) + 1 : 256 << (bsc - 8);
 if (rc == 12) fb_bits(b, 8); else if (rc == 13 || rc == 14) fb_bits(b, 16);
 if (b->bad) return b->bad;
 if (b->p >= b->n) return 2;
 if (ff_crc8(b->s + o, b->p - o) != b->s[b->p]) return 4;
 b->p++;
 static const int sizes[8] = { 0, 8, 12, 0, 16, 20, 24, 32 };
 h->bps = sc ? sizes[sc] : sbps;
 h->assign = (int) ac, h->nch = ac < 8 ? (int) ac + 1 : 2;
 return h->bps != sbps || h->nch != sch ? 4 : 0; }

static void ff_res(struct fb *b, int64_t *x, int bs, int order) {
 int m = (int) fb_bits(b, 2);
 if (m > 1) { b->bad = 4; return; }
 int pb = m ? 5 : 4, esc = m ? 31 : 15, po = (int) fb_bits(b, 4), parts = 1 << po;
 if (po && ((bs & (parts - 1)) || bs >> po < order)) { b->bad = 4; return; }
 int i = order;
 for (int p = 0; p < parts && !b->bad; p++) {
  int cnt = (bs >> po) - (p ? 0 : order), k = (int) fb_bits(b, pb);
  if (k == esc) {
   int rw = (int) fb_bits(b, 5);
   for (int j = 0; j < cnt && !b->bad; j++) x[i++] = fb_sbits(b, rw); }
  else for (int j = 0; j < cnt && !b->bad; j++) {
   uint64_t q = fb_unary(b);
   if (q >> 32) { b->bad = 4; return; }
   uint64_t u = q << k | fb_bits(b, k);
   x[i++] = (int64_t) (u >> 1) ^ -(int64_t) (u & 1); } } }

static void ff_sub(struct fb *b, int64_t *x, int bs, int w) {
 if (fb_bits(b, 1)) { b->bad = b->bad ? b->bad : 4; return; }
 int t = (int) fb_bits(b, 6), wasted = 0;
 if (fb_bits(b, 1)) wasted = (int) fb_unary(b) + 1;
 if (b->bad) return;
 if (wasted >= w) { b->bad = 4; return; }
 w -= wasted;
 if (t == 0) { int64_t v = fb_sbits(b, w); for (int i = 0; i < bs; i++) x[i] = v; }
 else if (t == 1) for (int i = 0; i < bs && !b->bad; i++) x[i] = fb_sbits(b, w);
 else if (t >= 8 && t <= 12) {
  int order = t - 8;
  if (order > bs) { b->bad = 4; return; }
  for (int i = 0; i < order; i++) x[i] = fb_sbits(b, w);
  ff_res(b, x, bs, order);
  if (b->bad) return;
  for (int i = order; i < bs; i++)
   x[i] += order == 1 ? x[i - 1] : order == 2 ? 2 * x[i - 1] - x[i - 2]
         : order == 3 ? 3 * x[i - 1] - 3 * x[i - 2] + x[i - 3]
         : order == 4 ? 4 * x[i - 1] - 6 * x[i - 2] + 4 * x[i - 3] - x[i - 4] : 0; }
 else if (t >= 32) {
  int order = t - 31;
  if (order > bs) { b->bad = 4; return; }
  for (int i = 0; i < order; i++) x[i] = fb_sbits(b, w);
  int prec = (int) fb_bits(b, 4) + 1, shift = (int) fb_sbits(b, 5);
  if (prec == 16 || shift < 0) { b->bad = b->bad ? b->bad : 4; return; }
  int64_t c[32];
  for (int j = 0; j < order; j++) c[j] = fb_sbits(b, prec);
  ff_res(b, x, bs, order);
  if (b->bad) return;
  for (int i = order; i < bs; i++) {
   int64_t s = 0;
   for (int j = 0; j < order; j++) s += c[j] * x[i - 1 - j];
   x[i] += ff_floor(s, shift); } }
 else { b->bad = 4; return; }
 if (wasted) for (int i = 0; i < bs; i++) x[i] *= (int64_t) 1 << wasted; }

// the subframes into x (nch planes of bs), coupling undone, the footer checked -> 0 | why
static int ff_body(struct fb *b, struct fh *h, int64_t *x, uintptr_t o) {
 for (int c = 0; c < h->nch && !b->bad; c++) {
  int side = (h->assign == 8 && c == 1) || (h->assign == 9 && c == 0) || (h->assign == 10 && c == 1);
  ff_sub(b, x + (uintptr_t) c * (uintptr_t) h->bs, h->bs, h->bps + side); }
 if (b->bad) return b->bad;
 if (b->k) b->k = 0, b->p++;
 if (b->n - b->p < 2) return 2;
 if (ff_crc16(b->s + o, b->p - o) != (unsigned) (b->s[b->p] << 8 | b->s[b->p + 1])) return 4;
 b->p += 2;
 int64_t *l = x, *r = x + h->bs;
 for (int i = 0; i < h->bs; i++)
  if (h->assign == 8) r[i] = l[i] - r[i];
  else if (h->assign == 9) l[i] += r[i];
  else if (h->assign == 10) {
   int64_t mid = l[i] * 2 + (r[i] & 1), side = r[i];
   l[i] = ff_floor(mid + side, 1), r[i] = ff_floor(mid - side, 1); }
 return 0; }

// --- the encoder: one frame at a time, the shape a level asks for ---------------------
// a level is libFLAC's: the longest lpc, mid/side, the deepest rice partition (its blocksize is
// the caller's, as flac -b makes it). every candidate is costed exactly and the smallest written.
struct fe_lv { int lpc, ms, po; };
static const struct fe_lv fe_levels[9] = {
 {0, 0, 3}, {0, 1, 3}, {0, 1, 3}, {6, 0, 4}, {8, 1, 4}, {8, 1, 5}, {8, 1, 6}, {12, 1, 6}, {12, 1, 6} };

struct fw { uint8_t *p; uintptr_t n; int k; };                  // bytes out, k bits of the last used

static void fw_put(struct fw *w, uint64_t v, int n) {
 while (n > 0) {
  int room = 8 - w->k, t = n < room ? n : room;
  unsigned bits = (unsigned) (v >> (n - t)) & ((1u << t) - 1);
  if (!w->k) w->p[w->n] = 0;
  w->p[w->n] |= (uint8_t) (bits << (room - t));
  w->k += t, n -= t;
  if (w->k == 8) w->k = 0, w->n++; } }
static void fw_sput(struct fw *w, int64_t v, int n) { fw_put(w, (uint64_t) v & (n == 64 ? ~0ull : (1ull << n) - 1), n); }
static void fw_unary(struct fw *w, uint64_t q) { for (; q >= 32; q -= 32) fw_put(w, 0, 32); fw_put(w, 1, (int) q + 1); }
static void fw_align(struct fw *w) { if (w->k) w->k = 0, w->n++; }

// one subframe as it will be written: kind 0 constant, 1 verbatim, 2 fixed, 3 lpc
struct fe_sub { int kind, order, prec, shift, wasted, po, rice[64]; int32_t q[32]; uint64_t bits; };

static uint64_t fe_fold(int64_t r) { return r < 0 ? ((uint64_t) -(r + 1) << 1) | 1 : (uint64_t) r << 1; }

// the cheapest rice parameter for u[0..n) -> its bits; k back through *kp
static uint64_t fe_rice1(const uint64_t *u, uintptr_t n, int *kp) {
 uint64_t sum = 0;
 for (uintptr_t i = 0; i < n; i++) sum += u[i];
 int k0 = 0;
 if (n) for (uint64_t m = sum / n; m > 1 && k0 < 30; m >>= 1) k0++;
 uint64_t best = ~0ull;
 for (int k = k0 > 0 ? k0 - 1 : 0; k <= k0 + 1 && k <= 30; k++) {
  uint64_t c = (uint64_t) n * (uint64_t) (k + 1);
  for (uintptr_t i = 0; i < n; i++) c += u[i] >> k;
  if (c < best) best = c, *kp = k; }
 return best; }

// the residual r[order..bs) folded into u, every partition order up to po costed -> the bits,
// with s's partition order and parameters set; ~0 when a residual will not fit 32 bits
static uint64_t fe_resid(const int64_t *r, uint64_t *u, int bs, int order, int maxpo, struct fe_sub *s) {
 for (int i = order; i < bs; i++) {
  if (r[i] > INT32_MAX || r[i] < INT32_MIN) return ~0ull;
  u[i] = fe_fold(r[i]); }
 uint64_t best = ~0ull;
 for (int po = 0; po <= maxpo; po++) {
  int parts = 1 << po;
  if (po && ((bs & (parts - 1)) || bs >> po <= order)) break;
  uint64_t c = 6; int big = 0, ks[64];
  for (int p = 0, i = order; p < parts; p++) {
   int cnt = (bs >> po) - (p ? 0 : order);
   c += fe_rice1(u + i, (uintptr_t) cnt, &ks[p]), i += cnt;
   if (ks[p] > 14) big = 1; }
  c += (uint64_t) parts * (big ? 5 : 4);
  if (c < best) { best = c, s->po = po; memcpy(s->rice, ks, sizeof(int) * (uintptr_t) parts); } }
 return best; }

static void fe_fixed(const int64_t *x, int64_t *r, int bs, int order) {
 for (int i = order; i < bs; i++)
  r[i] = x[i] - (order == 0 ? 0 : order == 1 ? x[i - 1] : order == 2 ? 2 * x[i - 1] - x[i - 2]
       : order == 3 ? 3 * x[i - 1] - 3 * x[i - 2] + x[i - 3]
       : 4 * x[i - 1] - 6 * x[i - 2] + 4 * x[i - 3] - x[i - 4]); }

static void fe_lpcres(const int64_t *x, int64_t *r, int bs, const int32_t *q, int order, int shift) {
 for (int i = order; i < bs; i++) {
  int64_t s = 0;
  for (int j = 0; j < order; j++) s += (int64_t) q[j] * x[i - 1 - j];
  r[i] = x[i] - ff_floor(s, shift); } }

// cos on [0, pi]: a series near 0, a step's rotation for the rest
static double fe_cos0(double t) {
 double t2 = t * t;
 return 1 - t2 / 2 * (1 - t2 / 12 * (1 - t2 / 30 * (1 - t2 / 56 * (1 - t2 / 90)))); }

// the tukey(0.5) window, libFLAC's default, into w: a raised cosine over np + 1 samples each end
static void fe_window(double *w, int bs) {
 int np = bs / 4 - 1;
 for (int i = 0; i < bs; i++) w[i] = 1.0;
 if (np < 1) return;
 double c1 = fe_cos0(3.14159265358979323846 / (double) np), cp = fe_cos0(-3.14159265358979323846 / (double) np), cc = 1.0;
 for (int n = 0; n <= np; n++) {                   // cc = cos(pi n / np), by the recurrence
  w[n] = 0.5 - 0.5 * cc, w[bs - np - 1 + n] = 0.5 + 0.5 * cc;
  double nx = 2 * c1 * cc - cp; cp = cc, cc = nx; } }

// quantised coefficients from lp, as libFLAC does -> 0 | 1 when they cannot be
static int fe_quant(const double *lp, int order, int prec, int32_t *q, int *shift) {
 double cmax = 0;
 for (int i = 0; i < order; i++) { double a = lp[i] < 0 ? -lp[i] : lp[i]; if (a > cmax) cmax = a; }
 if (cmax <= 0) return 1;
 int l = 0;                                        // floor(log2 cmax)
 while (cmax >= 2) cmax /= 2, l++;
 while (cmax < 1) cmax *= 2, l--;
 int sh = prec - 2 - l;
 if (sh > 15) sh = 15;
 if (sh < 0) return 1;
 int32_t qmax = (1 << (prec - 1)) - 1, qmin = -(1 << (prec - 1));
 double err = 0;
 for (int i = 0; i < order; i++) {
  err += lp[i] * (double) (1 << sh);
  double f = err + 0.5;
  int64_t v = (int64_t) f; if ((double) v > f) v--;   // floor
  v = v > qmax ? qmax : v < qmin ? qmin : v;
  q[i] = (int32_t) v, err -= (double) v; }
 *shift = sh;
 return 0; }

// the best subframe for x[0..bs) of w bits -> its bits, s set; r and u are scratch
static uint64_t fe_best(int64_t *x, int bs, int w, const struct fe_lv *lv, double *win,
                        int64_t *r, uint64_t *u, struct fe_sub *s) {
 int64_t all = 0;
 for (int i = 0; i < bs; i++) all |= x[i];
 int wasted = 0;
 if (all) while (!(all >> wasted & 1)) wasted++;
 s->wasted = 0;
 int same = 1;
 for (int i = 1; i < bs && same; i++) same = x[i] == x[0];
 if (same) return s->kind = 0, s->bits = 8 + (uint64_t) w;
 if (wasted) for (int i = 0; i < bs; i++) x[i] = ff_floor(x[i], wasted);
 int ww = w - wasted;
 uint64_t head = 8 + (wasted ? (uint64_t) wasted : 0);
 struct fe_sub t;
 s->kind = 1, s->bits = head + (uint64_t) bs * (uint64_t) ww;
 for (int order = 0; order <= 4 && order < bs; order++) {
  fe_fixed(x, r, bs, order);
  uint64_t c = fe_resid(r, u, bs, order, lv->po, &t);
  if (c == ~0ull) continue;
  c += head + (uint64_t) order * (uint64_t) ww;
  if (c < s->bits) t.kind = 2, t.order = order, t.bits = c, *s = t; }
 if (lv->lpc && bs > lv->lpc) {
  int maxo = lv->lpc;
  double ac[33], lp[32], tmp[32], e;
  for (int k = 0; k <= maxo; k++) {
   double a = 0;
   for (int i = k; i < bs; i++) a += ((double) x[i] * win[i]) * ((double) x[i - k] * win[i - k]);
   ac[k] = a; }
  int prec = ww <= 16 ? (bs <= 192 ? 7 : bs <= 384 ? 8 : bs <= 576 ? 9 : bs <= 1152 ? 10 : bs <= 2304 ? 11 : bs <= 4608 ? 12 : 13) : 15;
  if (prec > 15) prec = 15;
  ac[0] *= 1.0 + 1e-10;
  e = ac[0];
  for (int m = 0; m < maxo && e > 0; m++) {          // levinson-durbin, order m + 1 each pass
   double k = ac[m + 1];
   for (int j = 0; j < m; j++) k -= lp[j] * ac[m - j];
   k /= e;
   for (int j = 0; j < m; j++) tmp[j] = lp[j];
   lp[m] = k;
   for (int j = 0; j < m; j++) lp[j] = tmp[j] - k * tmp[m - 1 - j];
   e *= 1 - k * k;
   int order = m + 1;
   int32_t q[32]; int shift;
   if (fe_quant(lp, order, prec, q, &shift)) continue;
   fe_lpcres(x, r, bs, q, order, shift);
   uint64_t c = fe_resid(r, u, bs, order, lv->po, &t);
   if (c == ~0ull) continue;
   c += head + (uint64_t) order * (uint64_t) ww + 4 + 5 + (uint64_t) order * (uint64_t) prec;
   if (c < s->bits) {
    t.kind = 3, t.order = order, t.prec = prec, t.shift = shift, t.bits = c;
    memcpy(t.q, q, sizeof(int32_t) * (uintptr_t) order);
    *s = t; } } }
 s->wasted = wasted;
 return s->bits; }

static void fe_write(struct fw *o, const int64_t *x, int bs, int w, struct fe_sub *s, int64_t *r) {
 fw_put(o, 0, 1);
 int type = s->kind == 0 ? 0 : s->kind == 1 ? 1 : s->kind == 2 ? 8 + s->order : 31 + s->order;
 fw_put(o, (uint64_t) type, 6);
 if (s->wasted) fw_put(o, 1, 1), fw_unary(o, (uint64_t) s->wasted - 1); else fw_put(o, 0, 1);
 int ww = w - s->wasted;
 if (s->kind == 0) { fw_sput(o, x[0], w); return; }
 if (s->kind == 1) { for (int i = 0; i < bs; i++) fw_sput(o, x[i], ww); return; }
 for (int i = 0; i < s->order; i++) fw_sput(o, x[i], ww);
 if (s->kind == 2) fe_fixed(x, r, bs, s->order);
 else {
  fw_put(o, (uint64_t) s->prec - 1, 4), fw_sput(o, s->shift, 5);
  for (int j = 0; j < s->order; j++) fw_sput(o, s->q[j], s->prec);
  fe_lpcres(x, r, bs, s->q, s->order, s->shift); }
 int big = 0, parts = 1 << s->po;
 for (int p = 0; p < parts; p++) if (s->rice[p] > 14) big = 1;
 fw_put(o, (uint64_t) big, 2), fw_put(o, (uint64_t) s->po, 4);
 for (int p = 0, i = s->order; p < parts; p++) {
  int cnt = (bs >> s->po) - (p ? 0 : s->order), k = s->rice[p];
  fw_put(o, (uint64_t) k, big ? 5 : 4);
  for (int j = 0; j < cnt; j++, i++) {
   uint64_t u = fe_fold(r[i]);
   fw_unary(o, u >> k);
   if (k) fw_put(o, u & ((1ull << k) - 1), k); } } }

static void fe_utf8(struct fw *o, uint64_t v) {
 if (v < 0x80) { fw_put(o, v, 8); return; }
 int n = v < 0x800 ? 2 : v < 0x10000 ? 3 : v < 0x200000 ? 4 : v < 0x4000000 ? 5 : v < 0x80000000ull ? 6 : 7;
 fw_put(o, (uint64_t) (0xff00 >> n & 0xff) | (v >> (6 * (n - 1))), 8);
 for (int i = n - 2; i >= 0; i--) fw_put(o, 0x80 | (v >> (6 * i) & 0x3f), 8); }

// the scratch an encode wants, in 8-byte words: the planes, then a copy, a residual, the
// folded residual and the window, bs each; and the most a frame can take, in bytes
static uintptr_t fe_scratch(int bs, int nch) { return (uintptr_t) bs * (uintptr_t) ((nch > 2 ? nch : 4) + 4); }
static uintptr_t fe_bound(int bs, int nch, int bps) {
 return 32 + (uintptr_t) nch * (8 + ((uintptr_t) bs * (uintptr_t) (bps + 1) + 7) / 8); }

// a frame of bs samples, nch interleaved little-endian signed of (bps + 7) / 8 bytes from pcm,
// at frame number fno -> its bytes in out
static uintptr_t fe_frame(const uint8_t *pcm, int bs, int nch, int bps, int rate, uint64_t fno,
                          int level, int64_t *scr, uint8_t *out) {
 const struct fe_lv *lv = &fe_levels[level < 0 ? 0 : level > 8 ? 8 : level];
 int wb = (bps + 7) / 8, planes = nch > 2 ? nch : 4;
 int64_t *x = scr, *cp = scr + (uintptr_t) planes * (uintptr_t) bs, *r = cp + bs;
 uint64_t *u = (uint64_t*) (r + bs);
 double *win = (double*) (u + bs);
 for (int c = 0; c < nch; c++)
  for (int i = 0; i < bs; i++) {
   const uint8_t *p = pcm + ((uintptr_t) i * (uintptr_t) nch + (uintptr_t) c) * (uintptr_t) wb;
   uint64_t v = 0;
   for (int k = 0; k < wb; k++) v |= (uint64_t) p[k] << (8 * k);
   uint64_t m = (uint64_t) 1 << (8 * wb - 1);
   x[(uintptr_t) c * (uintptr_t) bs + (uintptr_t) i] = (int64_t) (v ^ m) - (int64_t) m; }
 fe_window(win, bs);
 // each plane's best subframe, costed on a copy (a plane loses its wasted bits as it is costed)
 struct fe_sub sub[8];
 int ms = nch == 2 && lv->ms, np = ms ? 4 : nch;
 if (ms) {
  int64_t *l = x, *rr = x + bs, *sd = x + 2 * (uintptr_t) bs, *md = x + 3 * (uintptr_t) bs;
  for (int i = 0; i < bs; i++) sd[i] = l[i] - rr[i], md[i] = ff_floor(l[i] + rr[i], 1); }
 for (int k = 0; k < np; k++) {
  memcpy(cp, x + (uintptr_t) k * (uintptr_t) bs, sizeof(int64_t) * (uintptr_t) bs);
  fe_best(cp, bs, bps + (ms && k == 2), lv, win, r, u, &sub[k]); }
 int assign = nch - 1, pl[2] = { 0, 1 };
 if (ms) {
  uint64_t lr = sub[0].bits + sub[1].bits, ls = sub[0].bits + sub[2].bits,
           rs = sub[2].bits + sub[1].bits, mss = sub[3].bits + sub[2].bits, m = lr;
  assign = 1;
  if (ls < m) m = ls, assign = 8, pl[0] = 0, pl[1] = 2;
  if (rs < m) m = rs, assign = 9, pl[0] = 2, pl[1] = 1;
  if (mss < m) m = mss, assign = 10, pl[0] = 3, pl[1] = 2; }
 struct fw o = { out, 0, 0 };
 fw_put(&o, 0xfff8, 16);
 int bsc = bs == 192 ? 1 : bs == 576 ? 2 : bs == 1152 ? 3 : bs == 2304 ? 4 : bs == 4608 ? 5
         : bs == 256 ? 8 : bs == 512 ? 9 : bs == 1024 ? 10 : bs == 2048 ? 11 : bs == 4096 ? 12
         : bs == 8192 ? 13 : bs == 16384 ? 14 : bs == 32768 ? 15 : bs <= 256 ? 6 : 7;
 static const int rates[12] = { 0, 88200, 176400, 192000, 8000, 16000, 22050, 24000, 32000, 44100, 48000, 96000 };
 int rc = 0;
 for (int i = 1; i < 12; i++) if (rates[i] == rate) rc = i;
 if (!rc) rc = rate % 1000 == 0 && rate / 1000 < 256 ? 12 : rate < 65536 ? 13 : rate % 10 == 0 && rate / 10 < 65536 ? 14 : 0;
 int sc = bps == 8 ? 1 : bps == 12 ? 2 : bps == 16 ? 4 : bps == 20 ? 5 : bps == 24 ? 6 : bps == 32 ? 7 : 0;
 fw_put(&o, (uint64_t) bsc, 4), fw_put(&o, (uint64_t) rc, 4);
 fw_put(&o, (uint64_t) assign, 4), fw_put(&o, (uint64_t) sc, 3), fw_put(&o, 0, 1);
 fe_utf8(&o, fno);
 if (bsc == 6) fw_put(&o, (uint64_t) bs - 1, 8); else if (bsc == 7) fw_put(&o, (uint64_t) bs - 1, 16);
 if (rc == 12) fw_put(&o, (uint64_t) rate / 1000, 8);
 else if (rc == 13) fw_put(&o, (uint64_t) rate, 16);
 else if (rc == 14) fw_put(&o, (uint64_t) rate / 10, 16);
 fw_put(&o, ff_crc8(out, o.n), 8);
 for (int c = 0; c < nch; c++) {
  int plane = nch == 2 ? pl[c] : c, side = ms && plane == 2;
  int64_t *ch = x + (uintptr_t) plane * (uintptr_t) bs;
  struct fe_sub *sb = &sub[plane];
  if (sb->kind && sb->wasted) for (int i = 0; i < bs; i++) ch[i] = ff_floor(ch[i], sb->wasted);
  fe_write(&o, ch, bs, bps + side, sb, r); }
 fw_align(&o);
 unsigned crc = ff_crc16(out, o.n);
 fw_put(&o, crc, 16);
 return o.n; }

love_noinline static struct g *host_flac_frame(struct g *g) {
 if (!strp(g->sp[0]) || !oddp(g->sp[1]) || !oddp(g->sp[2]) || !oddp(g->sp[3]))
  return g->sp[3] = putcharm(3), g->sp += 3, g;
 intptr_t o = getcharm(g->sp[1]), sbps = getcharm(g->sp[2]), sch = getcharm(g->sp[3]);
 if (o < 0 || sbps < 4 || sbps > 32 || sch < 1 || sch > 8) return g->sp[3] = putcharm(3), g->sp += 3, g;
 struct fb b = { (const uint8_t*) txt(g->sp[0]), len(g->sp[0]), (uintptr_t) o, 0, 0 };
 struct fh h;
 if ((uintptr_t) o > b.n) return g->sp[3] = putcharm(2), g->sp += 3, g;
 int why = ff_head(&b, (int) sbps, (int) sch, &h);
 if (why) return g->sp[3] = putcharm(why), g->sp += 3, g;
 uintptr_t ns = (uintptr_t) h.bs * (uintptr_t) h.nch, w = ((uintptr_t) h.bps + 7) / 8;
 if (!ok(g = str0(g, ns * sizeof(int64_t)))) return g;   // pushes: the planes over s o bps ch
 int64_t *x = (int64_t*) txt(g->sp[0]);
 b.s = (const uint8_t*) txt(g->sp[1]);
 if ((why = ff_body(&b, &h, x, (uintptr_t) o))) return g->sp[4] = putcharm(why), g->sp += 4, g;
 uintptr_t on = ns * w;
 if (!ok(g = have(g, str_width(on) + Width(struct chain)))) return g;
 struct str *out = ini_str(bump(g, str_width(on)), on);
 x = (int64_t*) txt(g->sp[0]);                  // re-read: have may move it
 uint8_t *p = (uint8_t*) out->bytes;
 for (uintptr_t i = 0; i < (uintptr_t) h.bs; i++)
  for (uintptr_t c = 0; c < (uintptr_t) h.nch; c++) {
   uint64_t v = (uint64_t) x[c * (uintptr_t) h.bs + i];
   for (uintptr_t k = 0; k < w; k++) *p++ = (uint8_t) (v >> (8 * k)); }
 struct chain *r = ini_chain(bump(g, Width(struct chain)), (intptr_t) out, putcharm((intptr_t) b.p));
 return g->sp[4] = word(r), g->sp += 4, g; }
static lvm(lvm_flac_frame) LvmCall(g, host_flac_frame)


love_noinline static struct g *host_flac_encode(struct g *g) {
 for (int i = 1; i < 6; i++) if (!oddp(g->sp[i])) return g->sp[5] = putcharm(3), g->sp += 5, g;
 intptr_t ch = getcharm(g->sp[1]), bps = getcharm(g->sp[2]), rate = getcharm(g->sp[3]),
          fno = getcharm(g->sp[4]), level = getcharm(g->sp[5]);
 uintptr_t n = strp(g->sp[0]) ? len(g->sp[0]) : 0, fs = (uintptr_t) ch * (((uintptr_t) bps + 7) / 8);
 if (!strp(g->sp[0]) || ch < 1 || ch > 8 || bps < 4 || bps > 32 || rate < 1 || rate >= 1 << 20
     || fno < 0 || level < 0 || level > 8 || !n || n % fs || n / fs > 65535)
  return g->sp[5] = putcharm(3), g->sp += 5, g;
 int bs = (int) (n / fs);
 if (!ok(g = str0(g, fe_scratch(bs, (int) ch) * sizeof(int64_t)))) return g;   // pushes: the scratch
 uintptr_t cap = fe_bound(bs, (int) ch, (int) bps);
 if (!ok(g = str0(g, cap))) return g;                                          // and the frame
 uintptr_t m = fe_frame((const uint8_t*) txt(g->sp[2]), bs, (int) ch, (int) bps, (int) rate,
                        (uint64_t) fno, (int) level, (int64_t*) txt(g->sp[1]), (uint8_t*) txt(g->sp[0]));
 if (!ok(g = str0(g, m))) return g;                                            // the frame, sized
 memcpy(txt(g->sp[0]), txt(g->sp[1]), m);
 return g->sp[8] = g->sp[0], g->sp += 8, g; }
static lvm(lvm_flac_encode) LvmCall(g, host_flac_encode)
static union u const
  nif_flac_frame[] = {{lvm_cur}, {.x = putcharm(4)}, {lvm_flac_frame}, {lvm_ret0}},
  nif_flac_encode[] = {{lvm_cur}, {.x = putcharm(6)}, {lvm_flac_encode}, {lvm_ret0}};
LvNif("flac-frame", nif_flac_frame, NULL);
LvNif("flac-encode", nif_flac_encode, NULL);
