// src/love/lib/flac.c
// (flac-frame s o bps ch) -> (pcm . next): the frame at s[o] decoded (rfc 9639), its samples
// interleaved little-endian in (bps + 7) / 8 bytes each, right-justified, and the offset just
// past it | why not: 1 no frame there, 2 cut short, 3 a kind it can't read, 4 a bad stream
// (a crc, a reserved code, a frame that disagrees with the stream's bps or ch).
// bps and ch are the streaminfo's. samples are held 64 bits wide: a 32-bit stream's side
// channel is 33.
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

static union u const
  nif_flac_frame[] = {{lvm_cur}, {.x = putcharm(4)}, {lvm_flac_frame}, {lvm_ret0}};
LvNif("flac-frame", nif_flac_frame, NULL);
