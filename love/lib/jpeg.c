// love/lib/jpeg.c
// (jpeg-encode w h rgba q) -> a baseline jfif of the w*h rgba image at quality 1..100 | ()
// jpeg's own tables (itu t.81 annex k) scaled by quality as libjpeg scales them, 4:2:0
// chroma, alpha dropped. the stream is sized by a counting pass, then written.
// (jpeg-pixels s) -> the rgba of a baseline or progressive jpeg, grey or ycbcr (rgb by
// adobe's word), any sampling | why not: 1 not a jpeg, 2 cut short, 3 a kind it can't
// read (arithmetic, lossless, 12-bit, cmyk), 4 a bad table or scan, 5 past 2^24 pixels
#include "love.h"
#include <stdint.h>
#include <string.h>

static const uint8_t jp_zigzag[64] = {
  0,  1,  8, 16,  9,  2,  3, 10, 17, 24, 32, 25, 18, 11,  4,  5,
 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13,  6,  7, 14, 21, 28,
 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51,
 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63 };

static const uint8_t jp_std_q[2][64] = {
 { 16, 11, 10, 16, 24, 40, 51, 61,  12, 12, 14, 19, 26, 58, 60, 55,
   14, 13, 16, 24, 40, 57, 69, 56,  14, 17, 22, 29, 51, 87, 80, 62,
   18, 22, 37, 56, 68,109,103, 77,  24, 35, 55, 64, 81,104,113, 92,
   49, 64, 78, 87,103,121,120,101,  72, 92, 95, 98,112,100,103, 99 },
 { 17, 18, 24, 47, 99, 99, 99, 99,  18, 21, 26, 66, 99, 99, 99, 99,
   24, 26, 56, 99, 99, 99, 99, 99,  47, 66, 99, 99, 99, 99, 99, 99,
   99, 99, 99, 99, 99, 99, 99, 99,  99, 99, 99, 99, 99, 99, 99, 99,
   99, 99, 99, 99, 99, 99, 99, 99,  99, 99, 99, 99, 99, 99, 99, 99 } };

// the four huffman tables: code lengths 1..16, then the symbols in code order
static const uint8_t jp_dc_bits[2][16] = {
 { 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0 },
 { 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0 } };
static const uint8_t jp_dc_vals[12] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 };
static const uint8_t jp_ac_bits[2][16] = {
 { 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d },
 { 0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 0x77 } };
static const uint8_t jp_ac_vals[2][162] = {
 { 0x01,0x02,0x03,0x00,0x04,0x11,0x05,0x12,0x21,0x31,0x41,0x06,0x13,0x51,0x61,0x07,
   0x22,0x71,0x14,0x32,0x81,0x91,0xa1,0x08,0x23,0x42,0xb1,0xc1,0x15,0x52,0xd1,0xf0,
   0x24,0x33,0x62,0x72,0x82,0x09,0x0a,0x16,0x17,0x18,0x19,0x1a,0x25,0x26,0x27,0x28,
   0x29,0x2a,0x34,0x35,0x36,0x37,0x38,0x39,0x3a,0x43,0x44,0x45,0x46,0x47,0x48,0x49,
   0x4a,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5a,0x63,0x64,0x65,0x66,0x67,0x68,0x69,
   0x6a,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x83,0x84,0x85,0x86,0x87,0x88,0x89,
   0x8a,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,
   0xa8,0xa9,0xaa,0xb2,0xb3,0xb4,0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xc2,0xc3,0xc4,0xc5,
   0xc6,0xc7,0xc8,0xc9,0xca,0xd2,0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,0xd9,0xda,0xe1,0xe2,
   0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,0xf1,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,
   0xf9,0xfa },
 { 0x00,0x01,0x02,0x03,0x11,0x04,0x05,0x21,0x31,0x06,0x12,0x41,0x51,0x07,0x61,0x71,
   0x13,0x22,0x32,0x81,0x08,0x14,0x42,0x91,0xa1,0xb1,0xc1,0x09,0x23,0x33,0x52,0xf0,
   0x15,0x62,0x72,0xd1,0x0a,0x16,0x24,0x34,0xe1,0x25,0xf1,0x17,0x18,0x19,0x1a,0x26,
   0x27,0x28,0x29,0x2a,0x35,0x36,0x37,0x38,0x39,0x3a,0x43,0x44,0x45,0x46,0x47,0x48,
   0x49,0x4a,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5a,0x63,0x64,0x65,0x66,0x67,0x68,
   0x69,0x6a,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x82,0x83,0x84,0x85,0x86,0x87,
   0x88,0x89,0x8a,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0xa2,0xa3,0xa4,0xa5,
   0xa6,0xa7,0xa8,0xa9,0xaa,0xb2,0xb3,0xb4,0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xc2,0xc3,
   0xc4,0xc5,0xc6,0xc7,0xc8,0xc9,0xca,0xd2,0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,0xd9,0xda,
   0xe2,0xe3,0xe4,0xe5,0xe6,0xe7,0xe8,0xe9,0xea,0xf2,0xf3,0xf4,0xf5,0xf6,0xf7,0xf8,
   0xf9,0xfa } };

// c[u][x] = C(u)/2 cos((2x+1)u pi/16), C(0) = 1/sqrt 2: the dct is c f c'
static const double jp_dct_c[8][8] = {
 {0.35355339059327373, 0.35355339059327373, 0.35355339059327373, 0.35355339059327373,
  0.35355339059327373, 0.35355339059327373, 0.35355339059327373, 0.35355339059327373},
 {0.49039264020161522, 0.41573480615127262, 0.27778511650980114, 0.097545161008064166,
  -0.097545161008064096, -0.27778511650980098, -0.41573480615127267, -0.49039264020161522},
 {0.46193976625564337, 0.19134171618254492, -0.19134171618254486, -0.46193976625564337,
  -0.46193976625564342, -0.19134171618254517, 0.191341716182545, 0.46193976625564326},
 {0.41573480615127262, -0.097545161008064096, -0.49039264020161522, -0.27778511650980109,
  0.27778511650980092, 0.49039264020161522, 0.097545161008064388, -0.41573480615127256},
 {0.35355339059327379, -0.35355339059327373, -0.35355339059327384, 0.35355339059327368,
  0.35355339059327384, -0.35355339059327334, -0.35355339059327356, 0.35355339059327329},
 {0.27778511650980114, -0.49039264020161522, 0.097545161008064152, 0.41573480615127273,
  -0.41573480615127256, -0.097545161008064013, 0.49039264020161533, -0.27778511650980076},
 {0.19134171618254492, -0.46193976625564342, 0.46193976625564326, -0.19134171618254495,
  -0.19134171618254528, 0.46193976625564337, -0.4619397662556432, 0.19134171618254478},
 {0.097545161008064166, -0.27778511650980109, 0.41573480615127273, -0.49039264020161533,
  0.49039264020161522, -0.41573480615127251, 0.27778511650980076, -0.097545161008064291} };

struct jp_huff { uint16_t code[256]; uint8_t size[256]; };

struct jp_enc {
 uint8_t *out;                   // null on the counting pass
 uintptr_t n;                    // bytes so far
 uint32_t acc; int bits;         // pending bits, msb first
 uint8_t q[2][64];               // natural order
 struct jp_huff dc[2], ac[2];
 int pred[3]; };

static void jp_put(struct jp_enc *e, int b) { if (e->out) e->out[e->n] = (uint8_t) b; e->n++; }
static void jp_put16(struct jp_enc *e, int v) { jp_put(e, v >> 8), jp_put(e, v & 255); }

// entropy-coded bytes: a 0xff is followed by a stuffed zero
static void jp_bits(struct jp_enc *e, uint32_t v, int n) {
 e->acc = (e->acc << n) | (v & ((1u << n) - 1)), e->bits += n;
 while (e->bits >= 8) {
  int b = (int) (e->acc >> (e->bits - 8)) & 255;
  jp_put(e, b); if (b == 255) jp_put(e, 0);
  e->bits -= 8; } }

static void jp_huff_build(struct jp_huff *h, const uint8_t *nbits, const uint8_t *vals) {
 int code = 0, k = 0;
 memset(h, 0, sizeof *h);
 for (int len = 1; len <= 16; len++, code <<= 1)
  for (int i = 0; i < nbits[len - 1]; i++, k++)
   h->code[vals[k]] = (uint16_t) code++, h->size[vals[k]] = (uint8_t) len; }

static int jp_nbits_of(int v) { int n = 0; if (v < 0) v = -v; while (v) n++, v >>= 1; return n; }

// a coefficient's n low bits, a negative one as v - 1
static void jp_coef(struct jp_enc *e, int v, int n) {
 jp_bits(e, (uint32_t) (v < 0 ? v - 1 : v), n); }

// one 8x8 block of level-shifted samples, component comp
static void jp_block(struct jp_enc *e, const double *f, int comp) {
 double t[64], c[64]; int z[64], tab = comp > 0;
 for (int u = 0; u < 8; u++)
  for (int x = 0; x < 8; x++) {
   double s = 0; for (int y = 0; y < 8; y++) s += jp_dct_c[u][y] * f[y * 8 + x]; t[u * 8 + x] = s; }
 for (int u = 0; u < 8; u++)
  for (int v = 0; v < 8; v++) {
   double s = 0; for (int x = 0; x < 8; x++) s += t[u * 8 + x] * jp_dct_c[v][x];
   c[u * 8 + v] = s / e->q[tab][u * 8 + v]; }
 for (int k = 0; k < 64; k++) {
  double s = c[jp_zigzag[k]];
  z[k] = s < 0 ? -(int) (0.5 - s) : (int) (s + 0.5); }
 int d = z[0] - e->pred[comp], n = jp_nbits_of(d);
 e->pred[comp] = z[0];
 jp_bits(e, e->dc[tab].code[n], e->dc[tab].size[n]); if (n) jp_coef(e, d, n);
 int run = 0;
 for (int k = 1; k < 64; k++) {
  if (!z[k]) { run++; continue; }
  while (run > 15) jp_bits(e, e->ac[tab].code[0xf0], e->ac[tab].size[0xf0]), run -= 16;
  n = jp_nbits_of(z[k]);
  int s = run << 4 | n;
  jp_bits(e, e->ac[tab].code[s], e->ac[tab].size[s]); jp_coef(e, z[k], n);
  run = 0; }
 if (run) jp_bits(e, e->ac[tab].code[0], e->ac[tab].size[0]); }

static void jp_headers(struct jp_enc *e, int w, int h) {
 static const uint8_t jfif[16] = { 0xff,0xe0, 0,16, 'J','F','I','F',0, 1,1, 0, 0,1, 0,1 };
 jp_put16(e, 0xffd8);
 for (int i = 0; i < 16; i++) jp_put(e, jfif[i]);
 jp_put(e, 0), jp_put(e, 0);                                          // no thumbnail
 jp_put16(e, 0xffdb), jp_put16(e, 2 + 2 * 65);
 for (int t = 0; t < 2; t++) {
  jp_put(e, t); for (int k = 0; k < 64; k++) jp_put(e, e->q[t][jp_zigzag[k]]); }
 jp_put16(e, 0xffc0), jp_put16(e, 17), jp_put(e, 8), jp_put16(e, h), jp_put16(e, w), jp_put(e, 3);
 jp_put(e, 1), jp_put(e, 0x22), jp_put(e, 0);
 jp_put(e, 2), jp_put(e, 0x11), jp_put(e, 1);
 jp_put(e, 3), jp_put(e, 0x11), jp_put(e, 1);
 jp_put16(e, 0xffc4), jp_put16(e, 2 + 2 * (17 + 12) + (17 + 162) * 2);
 for (int t = 0; t < 2; t++) {
  jp_put(e, t); for (int i = 0; i < 16; i++) jp_put(e, jp_dc_bits[t][i]);
  for (int i = 0; i < 12; i++) jp_put(e, jp_dc_vals[i]);
  jp_put(e, 0x10 | t); for (int i = 0; i < 16; i++) jp_put(e, jp_ac_bits[t][i]);
  for (int i = 0; i < 162; i++) jp_put(e, jp_ac_vals[t][i]); }
 jp_put16(e, 0xffda), jp_put16(e, 12), jp_put(e, 3);
 jp_put(e, 1), jp_put(e, 0x00), jp_put(e, 2), jp_put(e, 0x11), jp_put(e, 3), jp_put(e, 0x11);
 jp_put(e, 0), jp_put(e, 63), jp_put(e, 0); }

// the whole stream into e (its out null to count); rows past the edge repeat the last
static void jp_encode(struct jp_enc *e, const uint8_t *px, int w, int h) {
 e->n = 0, e->acc = 0, e->bits = 0, e->pred[0] = e->pred[1] = e->pred[2] = 0;
 jp_headers(e, w, h);
 for (int my = 0; my < h; my += 16)
  for (int mx = 0; mx < w; mx += 16) {
   double y[256], cb[64], cr[64];
   for (int i = 0; i < 64; i++) cb[i] = cr[i] = 0;
   for (int j = 0; j < 16; j++)
    for (int i = 0; i < 16; i++) {
     int sx = mx + i < w ? mx + i : w - 1, sy = my + j < h ? my + j : h - 1;
     const uint8_t *p = px + 4 * ((uintptr_t) sy * (uintptr_t) w + (uintptr_t) sx);
     double r = p[0], g = p[1], b = p[2];
     y[j * 16 + i] = 0.299 * r + 0.587 * g + 0.114 * b - 128;
     cb[(j >> 1) * 8 + (i >> 1)] += (-0.168736 * r - 0.331264 * g + 0.5 * b) / 4;
     cr[(j >> 1) * 8 + (i >> 1)] += (0.5 * r - 0.418688 * g - 0.081312 * b) / 4; }
   for (int k = 0; k < 4; k++) {
    double f[64];
    for (int j = 0; j < 8; j++)
     for (int i = 0; i < 8; i++) f[j * 8 + i] = y[((k >> 1) * 8 + j) * 16 + (k & 1) * 8 + i];
    jp_block(e, f, 0); }
   jp_block(e, cb, 1), jp_block(e, cr, 2); }
 if (e->bits) jp_bits(e, 0x7f, 8 - e->bits);                       // pad with ones
 jp_put16(e, 0xffd9); }

static void jp_setup(struct jp_enc *e, int quality) {
 int scale = quality < 50 ? 5000 / quality : 200 - 2 * quality;
 for (int t = 0; t < 2; t++) {
  for (int k = 0; k < 64; k++) {
   int v = (jp_std_q[t][k] * scale + 50) / 100;
   e->q[t][k] = (uint8_t) (v < 1 ? 1 : v > 255 ? 255 : v); }
  jp_huff_build(&e->dc[t], jp_dc_bits[t], jp_dc_vals);
  jp_huff_build(&e->ac[t], jp_ac_bits[t], jp_ac_vals[t]); } }

static int jpeg_args(struct ai *g) {
 for (int k = 0; k < 4; k++) if (k != 2 && !oddp(g->sp[k])) return 0;
 intptr_t w = getcharm(g->sp[0]), h = getcharm(g->sp[1]), q = getcharm(g->sp[3]);
 return w >= 1 && w <= 65535 && h >= 1 && h <= 65535 && q >= 1 && q <= 100
     && strp(g->sp[2]) && len(g->sp[2]) == (uintptr_t) w * (uintptr_t) h * 4; }

ai_noinline static struct ai *host_jpeg(struct ai *g) {
 if (!jpeg_args(g)) return g->sp[3] = ZeroPoint, g->sp += 3, g;
 int w = (int) getcharm(g->sp[0]), h = (int) getcharm(g->sp[1]);
 struct jp_enc e;
 jp_setup(&e, (int) getcharm(g->sp[3]));
 e.out = 0, jp_encode(&e, (const uint8_t*) txt(g->sp[2]), w, h);
 if (!ai_ok(g = str0(g, e.n))) return g;              // pushes: out over the four args
 e.out = (uint8_t*) txt(g->sp[0]), jp_encode(&e, (const uint8_t*) txt(g->sp[3]), w, h);
 g->sp[4] = g->sp[0], g->sp += 4;
 return g; }
static lvm(lvm_jpeg) LvmCall(g, host_jpeg)

static union u const
  nif_jpeg[] = {{lvm_cur}, {.x = putcharm(4)}, {lvm_jpeg}, {lvm_ret0}};
LvNif("jpeg-encode", nif_jpeg, NULL);

// ---- decoding ---------------------------------------------------------------------------
// coefficients land in a scratch string, 128 bytes a block, and each block's samples are
// then written over the front half of its own place; chroma is upsampled linearly.

struct jd_huff { uint16_t fast[512]; uint32_t first[17]; uint16_t count[17], off[17];
                 uint8_t vals[256]; int ok; };
struct jd_comp { int id, h, v, tq, td, ta, pred; uintptr_t bw, bh, cw, ch, off; };
struct jd {
 const uint8_t *s; uintptr_t n, pos;
 uint8_t *base;                  // the scratch, null until it is laid
 uint32_t acc; int bits, marker, bad;
 uint16_t q[4][64];              // natural order
 struct jd_huff dc[4], ac[4];
 struct jd_comp c[3];
 int nc, hmax, vmax, w, h, prog, frame, scans, ri, adobe, transform, eobrun;
 uintptr_t mcux, mcuy;
 int ns, sc[3], ss, se, ah, al; };

static int jd_be16(const uint8_t *p) { return p[0] << 8 | p[1]; }

// entropy bytes, msb first into acc; a marker (or the end) feeds zeros
static void jd_fill(struct jd *d) {
 while (d->bits <= 24) {
  int b = 0;
  if (!d->marker && d->pos < d->n) {
   b = d->s[d->pos];
   if (b != 0xff) d->pos++;
   else {
    int c = d->pos + 1 < d->n ? d->s[d->pos + 1] : 0xd9;
    if (c == 0) d->pos += 2;
    else if (c == 0xff) { d->pos++; continue; }
    else d->marker = 1, b = 0; } }
  d->acc |= (uint32_t) b << (24 - d->bits), d->bits += 8; } }

static int jd_get(struct jd *d, int n) {
 if (!n) return 0;
 jd_fill(d);
 int v = (int) (d->acc >> (32 - n));
 d->acc <<= n, d->bits -= n;
 return v; }

static int jd_extend(int v, int s) { return s && v < 1 << (s - 1) ? v - (1 << s) + 1 : v; }

static int jd_huff_build(struct jd_huff *h, const uint8_t *nbits, const uint8_t *vals, int total) {
 uint32_t code = 0; int k = 0;
 memset(h, 0, sizeof *h);
 for (int l = 1; l <= 16; l++, code <<= 1) {
  h->first[l] = code, h->count[l] = nbits[l - 1], h->off[l] = (uint16_t) k;
  for (int i = 0; i < nbits[l - 1]; i++, k++, code++) {
   if (code >= 1u << l) return 0;                  // more codes than the length holds
   if (l <= 9)
    for (uint32_t j = code << (9 - l), e = (code + 1) << (9 - l); j < e; j++)
     h->fast[j] = (uint16_t) (l << 8 | vals[k]); } }
 memcpy(h->vals, vals, (size_t) total);
 return h->ok = 1; }

static int jd_decode(struct jd *d, const struct jd_huff *h) {
 jd_fill(d);
 uint32_t v = d->acc >> 16;
 int f = h->fast[v >> 7];
 if (f) { d->acc <<= f >> 8, d->bits -= f >> 8; return f & 255; }
 for (int l = 10; l <= 16; l++) {
  uint32_t c = v >> (16 - l);
  if (c - h->first[l] < h->count[l]) {
   d->acc <<= l, d->bits -= l;
   return h->vals[h->off[l] + c - h->first[l]]; } }
 return -1; }

static int16_t *jd_coef(struct jd *d, struct jd_comp *c, uintptr_t bx, uintptr_t by) {
 return (int16_t*) (d->base + c->off) + 64 * (by * c->bw + bx); }

// one block of one scan; a bad code sets d->bad and the scan stops
static void jd_block(struct jd *d, struct jd_comp *c, int16_t *b) {
 const struct jd_huff *dc = &d->dc[c->td], *ac = &d->ac[c->ta];
 if (!d->prog) {
  int t = jd_decode(d, dc);
  if (t < 0 || t > 11) { d->bad = 1; return; }
  c->pred += jd_extend(jd_get(d, t), t), b[0] = (int16_t) c->pred;
  for (int k = 1; k < 64;) {
   int rs = jd_decode(d, ac), r = rs >> 4, s = rs & 15;
   if (rs < 0) { d->bad = 1; return; }
   if (!s) { if (r != 15) break; k += 16; continue; }
   if ((k += r) > 63) { d->bad = 1; return; }
   b[jp_zigzag[k++]] = (int16_t) jd_extend(jd_get(d, s), s); }
  return; }
 if (!d->ss) {                                   // dc, first or refined
  if (d->ah) { if (jd_get(d, 1)) b[0] = (int16_t) (b[0] | 1 << d->al); return; }
  int t = jd_decode(d, dc);
  if (t < 0 || t > 11) { d->bad = 1; return; }
  c->pred += jd_extend(jd_get(d, t), t), b[0] = (int16_t) (c->pred * (1 << d->al));
  return; }
 if (!d->ah) {                                   // ac, first
  if (d->eobrun) { d->eobrun--; return; }
  for (int k = d->ss; k <= d->se;) {
   int rs = jd_decode(d, ac), r = rs >> 4, s = rs & 15;
   if (rs < 0) { d->bad = 1; return; }
   if (!s) {
    if (r < 15) { d->eobrun = (1 << r) - 1 + jd_get(d, r); return; }
    k += 16; continue; }
   if ((k += r) > 63) { d->bad = 1; return; }
   b[jp_zigzag[k++]] = (int16_t) (jd_extend(jd_get(d, s), s) * (1 << d->al)); }
  return; }
 int bit = 1 << d->al, k = d->ss;               // ac, refined
 if (d->eobrun) {
  d->eobrun--;
  for (; k <= d->se; k++) {
   int16_t *p = &b[jp_zigzag[k]];
   if (*p && jd_get(d, 1) && !(*p & bit)) *p = (int16_t) (*p + (*p > 0 ? bit : -bit)); }
  return; }
 while (k <= d->se) {
  int rs = jd_decode(d, ac), r = rs >> 4, s = rs & 15;
  if (rs < 0) { d->bad = 1; return; }
  if (!s) {
   if (r < 15) d->eobrun = (1 << r) - 1 + jd_get(d, r), r = 64; }
  else s = jd_get(d, 1) ? bit : -bit;
  for (; k <= d->se; k++) {
   int16_t *p = &b[jp_zigzag[k]];
   if (*p) { if (jd_get(d, 1) && !(*p & bit)) *p = (int16_t) (*p + (*p > 0 ? bit : -bit)); }
   else if (!r) { *p = (int16_t) s; k++; break; }
   else r--; } } }

// past the RSTn a restart interval ends on; a marker that isn't one stays for the caller
static void jd_restart(struct jd *d) {
 d->acc = 0, d->bits = 0, d->marker = 0, d->eobrun = 0;
 for (int i = 0; i < d->nc; i++) d->c[i].pred = 0;
 while (d->pos + 1 < d->n) {
  int a = d->s[d->pos], m = d->s[d->pos + 1];
  if (a == 0xff && m >= 0xd0 && m <= 0xd7) { d->pos += 2; return; }
  if (a == 0xff && m && m != 0xff) return;
  d->pos++; } }

static void jd_scan(struct jd *d) {
 struct jd_comp *one = &d->c[d->sc[0]];
 uintptr_t mx = d->ns == 1 ? (one->cw + 7) / 8 : d->mcux,
           my = d->ns == 1 ? (one->ch + 7) / 8 : d->mcuy, todo = (uintptr_t) d->ri;
 d->acc = 0, d->bits = 0, d->marker = 0, d->eobrun = 0;
 for (int i = 0; i < d->nc; i++) d->c[i].pred = 0;
 for (uintptr_t y = 0; y < my && !d->bad; y++)
  for (uintptr_t x = 0; x < mx && !d->bad; x++) {
   if (d->ri && !todo) jd_restart(d), todo = (uintptr_t) d->ri;
   if (d->ns == 1) jd_block(d, one, jd_coef(d, one, x, y));
   else
    for (int i = 0; i < d->ns; i++) {
     struct jd_comp *c = &d->c[d->sc[i]];
     for (int v = 0; v < c->v; v++)
      for (int h = 0; h < c->h; h++)
       jd_block(d, c, jd_coef(d, c, x * (uintptr_t) c->h + (uintptr_t) h,
                                    y * (uintptr_t) c->v + (uintptr_t) v)); }
   todo--; }
 d->bad = 0;                                     // what decoded is kept
 while (d->pos + 1 < d->n) {                     // on to the next marker
  int a = d->s[d->pos], m = d->s[d->pos + 1];
  if (a == 0xff && m && m != 0xff && (m < 0xd0 || m > 0xd7)) break;
  d->pos++; } }

static int jd_sof(struct jd *d, const uint8_t *p, int n, int m) {
 if (m != 0xc0 && m != 0xc1 && m != 0xc2) return 3;
 if (n < 6 || p[0] != 8) return 3;
 d->h = jd_be16(p + 1), d->w = jd_be16(p + 3), d->nc = p[5], d->prog = m == 0xc2;
 if (!d->h || !d->w || (d->nc != 1 && d->nc != 3)) return 3;
 if (n < 6 + 3 * d->nc) return 4;
 if ((uintptr_t) d->w * (uintptr_t) d->h > (uintptr_t) 1 << 24) return 5;
 d->hmax = d->vmax = 1;
 for (int i = 0; i < d->nc; i++) {
  struct jd_comp *c = &d->c[i];
  c->id = p[6 + 3 * i], c->h = p[7 + 3 * i] >> 4, c->v = p[7 + 3 * i] & 15, c->tq = p[8 + 3 * i] & 3;
  if (c->h < 1 || c->h > 4 || c->v < 1 || c->v > 4) return 4;
  if (c->h > d->hmax) d->hmax = c->h;
  if (c->v > d->vmax) d->vmax = c->v; }
 if (d->nc == 1) d->c[0].h = d->c[0].v = d->hmax = d->vmax = 1;
 d->mcux = ((uintptr_t) d->w + 8 * (uintptr_t) d->hmax - 1) / (8 * (uintptr_t) d->hmax);
 d->mcuy = ((uintptr_t) d->h + 8 * (uintptr_t) d->vmax - 1) / (8 * (uintptr_t) d->vmax);
 uintptr_t off = 0;
 for (int i = 0; i < d->nc; i++) {
  struct jd_comp *c = &d->c[i];
  c->bw = d->mcux * (uintptr_t) c->h, c->bh = d->mcuy * (uintptr_t) c->v;
  c->cw = ((uintptr_t) d->w * (uintptr_t) c->h + (uintptr_t) d->hmax - 1) / (uintptr_t) d->hmax;
  c->ch = ((uintptr_t) d->h * (uintptr_t) c->v + (uintptr_t) d->vmax - 1) / (uintptr_t) d->vmax;
  c->off = off, off += c->bw * c->bh * 128; }
 d->frame = 1;
 return 0; }

static int jd_sos(struct jd *d, const uint8_t *p, int n) {
 if (!d->frame || n < 1) return 4;
 d->ns = p[0];
 if (d->ns < 1 || d->ns > d->nc || n < 4 + 2 * d->ns) return 4;
 for (int i = 0; i < d->ns; i++) {
  int j = 0;
  while (j < d->nc && d->c[j].id != p[1 + 2 * i]) j++;
  if (j == d->nc) return 4;
  d->sc[i] = j, d->c[j].td = p[2 + 2 * i] >> 4 & 3, d->c[j].ta = p[2 + 2 * i] & 3; }
 const uint8_t *t = p + 1 + 2 * d->ns;
 d->ss = t[0], d->se = t[1], d->ah = t[2] >> 4, d->al = t[2] & 15;
 if (d->prog) {
  if (d->ss > d->se || d->se > 63 || d->al > 13 || (d->ss && d->ns != 1) || (!d->ss && d->se))
   return 4; }
 else d->ss = 0, d->se = 63, d->ah = d->al = 0;
 for (int i = 0; i < d->ns; i++) {
  struct jd_comp *c = &d->c[d->sc[i]];
  if ((!d->ss && !d->ah && !d->dc[c->td].ok) || (d->se && !d->ac[c->ta].ok)) return 4; }
 return 0; }

static int jd_dqt(struct jd *d, const uint8_t *p, int n) {
 while (n > 0) {
  int wide = p[0] >> 4, t = p[0] & 3, need = 1 + 64 * (wide ? 2 : 1);
  if (wide > 1 || n < need) return 4;
  for (int k = 0; k < 64; k++)
   d->q[t][jp_zigzag[k]] = (uint16_t) (wide ? jd_be16(p + 1 + 2 * k) : p[1 + k]);
  p += need, n -= need; }
 return 0; }

static int jd_dht(struct jd *d, const uint8_t *p, int n) {
 while (n > 0) {
  if (n < 17 || p[0] >> 4 > 1) return 4;
  int total = 0;
  for (int i = 0; i < 16; i++) total += p[1 + i];
  if (total > 256 || n < 17 + total) return 4;
  struct jd_huff *h = p[0] >> 4 ? &d->ac[p[0] & 3] : &d->dc[p[0] & 3];
  if (!jd_huff_build(h, p + 1, p + 17, total)) return 4;
  p += 17 + total, n -= 17 + total; }
 return 0; }

// the markers from the top: up to the frame header when head, else through every scan
static int jd_walk(struct jd *d, int head) {
 d->frame = 0, d->scans = 0, d->ri = 0, d->adobe = 0, d->pos = 2;
 if (d->n < 4 || d->s[0] != 0xff || d->s[1] != 0xd8) return 1;
 for (;;) {
  while (d->pos < d->n && d->s[d->pos] != 0xff) d->pos++;
  while (d->pos < d->n && d->s[d->pos] == 0xff) d->pos++;
  if (d->pos >= d->n) return d->scans ? 0 : 2;
  int m = d->s[d->pos++];
  if (m == 0xd9) return d->scans ? 0 : 2;
  if (m == 0x01 || (m >= 0xd0 && m <= 0xd7)) continue;
  if (d->pos + 2 > d->n) return d->scans ? 0 : 2;
  int len = jd_be16(d->s + d->pos);
  if (len < 2 || d->pos + (uintptr_t) len > d->n) return d->scans ? 0 : 2;
  const uint8_t *p = d->s + d->pos + 2; int n = len - 2, why = 0;
  d->pos += (uintptr_t) len;
  if (m >= 0xc0 && m <= 0xcf && m != 0xc4 && m != 0xc8 && m != 0xcc) {
   if (d->frame) return 4;
   if ((why = jd_sof(d, p, n, m)) || head) return why; }
  else if (m == 0xc4) why = jd_dht(d, p, n);
  else if (m == 0xdb) why = jd_dqt(d, p, n);
  else if (m == 0xdd) d->ri = n >= 2 ? jd_be16(p) : 0;
  else if (m == 0xee) { if (n >= 12 && !memcmp(p, "Adobe", 5)) d->adobe = 1, d->transform = p[11]; }
  else if (m == 0xdc) return 3;
  else if (m == 0xda) {
   if (head) return 4;
   if ((why = jd_sos(d, p, n))) return why;
   jd_scan(d), d->scans++; }
  if (why) return why; } }

// dequantised, inverted, level-shifted, clamped: each block's samples over its own front
static void jd_idct(struct jd *d) {
 for (int i = 0; i < d->nc; i++) {
  struct jd_comp *c = &d->c[i];
  const uint16_t *q = d->q[c->tq];
  uint8_t *o = d->base + c->off;
  for (uintptr_t k = 0; k < c->bw * c->bh; k++) {
   int16_t z[64]; double t[64]; int flat = 1;
   memcpy(z, o + 128 * k, sizeof z);
   for (int j = 1; j < 64 && flat; j++) flat = !z[j];
   if (flat) {
    double v = z[0] * q[0] / 8.0 + 128.5;
    memset(o + 64 * k, (uint8_t) (v < 0 ? 0 : v > 255 ? 255 : v), 64); continue; }
   for (int u = 0; u < 8; u++)
    for (int x = 0; x < 8; x++) {
     double s = 0;
     for (int v = 0; v < 8; v++) s += z[u * 8 + v] * q[u * 8 + v] * jp_dct_c[v][x];
     t[u * 8 + x] = s; }
   for (int y = 0; y < 8; y++)
    for (int x = 0; x < 8; x++) {
     double s = 128.5;
     for (int u = 0; u < 8; u++) s += jp_dct_c[u][y] * t[u * 8 + x];
     o[64 * k + y * 8 + x] = (uint8_t) (s < 0 ? 0 : s > 255 ? 255 : s); } } } }

static int jd_at(struct jd *d, struct jd_comp *c, uintptr_t x, uintptr_t y) {
 return d->base[c->off + 64 * ((y >> 3) * c->bw + (x >> 3)) + (y & 7) * 8 + (x & 7)]; }

// component c's sample under pixel (x, y), its grid centred on the full one
static int jd_sample(struct jd *d, struct jd_comp *c, uintptr_t x, uintptr_t y) {
 if (c->h == d->hmax && c->v == d->vmax) return jd_at(d, c, x, y);
 intptr_t dx = 2 * d->hmax, dy = 2 * d->vmax,
          px = (intptr_t) (2 * x + 1) * c->h - d->hmax, py = (intptr_t) (2 * y + 1) * c->v - d->vmax;
 if (px < 0) px = 0;
 if (py < 0) py = 0;
 uintptr_t x0 = (uintptr_t) (px / dx), y0 = (uintptr_t) (py / dy);
 int wx = (int) (px % dx * 256 / dx), wy = (int) (py % dy * 256 / dy);
 if (x0 > c->cw - 1) x0 = c->cw - 1;
 if (y0 > c->ch - 1) y0 = c->ch - 1;
 uintptr_t x1 = x0 + 1 < c->cw ? x0 + 1 : x0, y1 = y0 + 1 < c->ch ? y0 + 1 : y0;
 int a = jd_at(d, c, x0, y0) * (256 - wx) + jd_at(d, c, x1, y0) * wx,
     b = jd_at(d, c, x0, y1) * (256 - wx) + jd_at(d, c, x1, y1) * wx;
 return (a * (256 - wy) + b * wy + 32768) >> 16; }

static uint8_t jd_clamp(int v) { return (uint8_t) (v < 0 ? 0 : v > 255 ? 255 : v); }

static void jd_rgba(struct jd *d, uint8_t *o) {
 int rgb = d->nc == 3 && ((d->adobe && !d->transform)
                          || (d->c[0].id == 'R' && d->c[1].id == 'G' && d->c[2].id == 'B'));
 for (uintptr_t y = 0; y < (uintptr_t) d->h; y++)
  for (uintptr_t x = 0; x < (uintptr_t) d->w; x++, o += 4) {
   int l = jd_sample(d, &d->c[0], x, y);
   if (d->nc == 1) o[0] = o[1] = o[2] = (uint8_t) l;
   else {
    int b = jd_sample(d, &d->c[1], x, y), r = jd_sample(d, &d->c[2], x, y);
    if (rgb) o[0] = (uint8_t) l, o[1] = (uint8_t) b, o[2] = (uint8_t) r;
    else {
     b -= 128, r -= 128;                          // + 2^24 keeps the shifts on positives
     o[0] = jd_clamp(l + ((91881 * r + 32768 + (1 << 24)) >> 16) - 256);
     o[1] = jd_clamp(l + ((-22554 * b - 46802 * r + 32768 + (1 << 24)) >> 16) - 256);
     o[2] = jd_clamp(l + ((116130 * b + 32768 + (1 << 24)) >> 16) - 256); } }
   o[3] = 255; } }

static uintptr_t jd_scratch(struct jd *d) {
 struct jd_comp *c = &d->c[d->nc - 1];
 return c->off + c->bw * c->bh * 128; }

ai_noinline static struct ai *host_jpegd(struct ai *g) {
 struct jd d;
 if (!strp(g->sp[0])) return g->sp[0] = putcharm(1), g;
 memset(&d, 0, sizeof d), d.s = (const uint8_t*) txt(g->sp[0]), d.n = len(g->sp[0]);
 int why = jd_walk(&d, 1);
 if (why) return g->sp[0] = putcharm(why), g;
 uintptr_t need = jd_scratch(&d);
 if (!ai_ok(g = str0(g, need))) return g;           // pushes: the scratch over s
 d.s = (const uint8_t*) txt(g->sp[1]), d.base = (uint8_t*) txt(g->sp[0]);
 memset(d.base, 0, need);
 if ((why = jd_walk(&d, 0))) return g->sp[1] = putcharm(why), g->sp += 1, g;
 jd_idct(&d);
 if (!ai_ok(g = str0(g, (uintptr_t) d.w * (uintptr_t) d.h * 4))) return g;
 d.base = (uint8_t*) txt(g->sp[1]);
 jd_rgba(&d, (uint8_t*) txt(g->sp[0]));
 g->sp[2] = g->sp[0], g->sp += 2;
 return g; }
static lvm(lvm_jpegd) LvmCall(g, host_jpegd)

static union u const
  nif_jpegd[] = {{lvm_cur}, {.x = putcharm(1)}, {lvm_jpegd}, {lvm_ret0}};
LvNif("jpeg-pixels", nif_jpegd, NULL);
