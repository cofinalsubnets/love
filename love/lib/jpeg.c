// love/lib/jpeg.c
// (jpeg-encode w h rgba q) -> a baseline jfif of the w*h rgba image at quality 1..100 | ()
// jpeg's own tables (itu t.81 annex k) scaled by quality as libjpeg scales them, 4:2:0
// chroma, alpha dropped. the stream is sized by a counting pass, then written.
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
