// src/love/picture/qoi.c
// (qoi-pixels s) -> the rgba of a qoi picture | why not: 1 not a qoi, 2 cut short, 5 past
// 2^24 pixels
// (qoi-encode w h rgba) -> a qoi of the w*h rgba image, its ops chosen as the reference
// encoder chooses them; 3 channels in the header where every alpha is 255 | ()
#include "love.h"
#include "bytes.h"
#include <stdint.h>
#include <string.h>

#define QOI_INDEX 0x00
#define QOI_DIFF  0x40
#define QOI_LUMA  0x80
#define QOI_RUN   0xc0
#define QOI_RGB   0xfe
#define QOI_RGBA  0xff

static unsigned qoi_hash(const uint8_t *p) { return (p[0] * 3u + p[1] * 5u + p[2] * 7u + p[3] * 11u) & 63; }

static int qoi_head(const uint8_t *s, uintptr_t n, uint32_t *w, uint32_t *h) {
 if (n < 14 || memcmp(s, "qoif", 4) || s[12] < 3 || s[12] > 4 || s[13] > 1) return 1;
 *w = ld32be(s + 4), *h = ld32be(s + 8);
 if (!*w || !*h) return 1;
 return (uint64_t) *w * *h > (1u << 24) ? 5 : 0; }

// the pixels from the ops at s[14..n) into out, k bytes; 0 or why not
static int qoi_ops(const uint8_t *s, uintptr_t n, uint8_t *out, uintptr_t k) {
 uint8_t ix[64][4], px[4] = { 0, 0, 0, 255 };
 uintptr_t p = 14, o = 0;
 unsigned run = 0;
 memset(ix, 0, sizeof ix);
 for (; o < k; o += 4) {
  if (run) run--;
  else {
   if (p >= n) return 2;
   unsigned b = s[p++];
   if (b == QOI_RGB || b == QOI_RGBA) {
    unsigned c = b == QOI_RGB ? 3 : 4;
    if (n - p < c) return 2;
    memcpy(px, s + p, c), p += c; }
   else switch (b & 0xc0) {
    case QOI_INDEX: memcpy(px, ix[b], 4); break;
    case QOI_DIFF:
     px[0] = (uint8_t) (px[0] + ((b >> 4) & 3) - 2);
     px[1] = (uint8_t) (px[1] + ((b >> 2) & 3) - 2);
     px[2] = (uint8_t) (px[2] + (b & 3) - 2); break;
    case QOI_LUMA: {
     if (p >= n) return 2;
     int dg = (int) (b & 63) - 32, c = s[p++];
     px[0] = (uint8_t) (px[0] + dg - 8 + (c >> 4));
     px[1] = (uint8_t) (px[1] + dg);
     px[2] = (uint8_t) (px[2] + dg - 8 + (c & 15)); break; }
    default: run = b & 63; }
   memcpy(ix[qoi_hash(px)], px, 4); }
  memcpy(out + o, px, 4); }
 return 0; }

love_noinline static struct g *host_qoid(struct g *g) {
 uint32_t w, h;
 if (!strp(g->sp[0])) return g->sp[0] = putcharm(1), g;
 int why = qoi_head((const uint8_t*) txt(g->sp[0]), len(g->sp[0]), &w, &h);
 if (why) return g->sp[0] = putcharm(why), g;
 uintptr_t k = (uintptr_t) w * h * 4;
 if (!ok(g = str0(g, k))) return g;               // pushes: out over s
 why = qoi_ops((const uint8_t*) txt(g->sp[1]), len(g->sp[1]), (uint8_t*) txt(g->sp[0]), k);
 if (why) return g->sp[1] = putcharm(why), g->sp += 1, g;
 g->sp[1] = g->sp[0], g->sp += 1;
 return g; }
static lvm(lvm_qoid) LvmCall(g, host_qoid)
LvDef("qoi-pixels", qoid, 1, "qoi");

// the encoding into o, or its length alone when o is null
static uintptr_t qoi_enc(const uint8_t *px, uint32_t w, uint32_t h, uint8_t *o) {
 uint8_t ix[64][4], prev[4] = { 0, 0, 0, 255 };
 uintptr_t n = (uintptr_t) w * h * 4, q = 14;
 unsigned run = 0, alpha = 0;
 memset(ix, 0, sizeof ix);
 for (uintptr_t i = 3; i < n; i += 4) alpha |= px[i] != 255;
 if (o) {
  memcpy(o, "qoif", 4);
  for (int j = 0; j < 4; j++) o[4 + j] = (uint8_t) (w >> (24 - 8 * j)), o[8 + j] = (uint8_t) (h >> (24 - 8 * j));
  o[12] = alpha ? 4 : 3, o[13] = 0; }
#define QOI_PUT(b) (o ? (void) (o[q] = (uint8_t) (b)) : (void) 0, q++)
 for (uintptr_t i = 0; i < n; i += 4) {
  const uint8_t *p = px + i;
  if (!memcmp(p, prev, 4)) {
   if (++run == 62 || i + 4 == n) QOI_PUT(QOI_RUN | (run - 1)), run = 0;
   continue; }
  if (run) QOI_PUT(QOI_RUN | (run - 1)), run = 0;
  unsigned k = qoi_hash(p);
  if (!memcmp(ix[k], p, 4)) QOI_PUT(QOI_INDEX | k);
  else {
   memcpy(ix[k], p, 4);
   if (p[3] == prev[3]) {
    int vr = (int8_t) (p[0] - prev[0]), vg = (int8_t) (p[1] - prev[1]), vb = (int8_t) (p[2] - prev[2]),
        gr = vr - vg, gb = vb - vg;
    if (vr > -3 && vr < 2 && vg > -3 && vg < 2 && vb > -3 && vb < 2)
     QOI_PUT(QOI_DIFF | (vr + 2) << 4 | (vg + 2) << 2 | (vb + 2));
    else if (gr > -9 && gr < 8 && vg > -33 && vg < 32 && gb > -9 && gb < 8)
     QOI_PUT(QOI_LUMA | (vg + 32)), QOI_PUT((gr + 8) << 4 | (gb + 8));
    else QOI_PUT(QOI_RGB), QOI_PUT(p[0]), QOI_PUT(p[1]), QOI_PUT(p[2]); }
   else QOI_PUT(QOI_RGBA), QOI_PUT(p[0]), QOI_PUT(p[1]), QOI_PUT(p[2]), QOI_PUT(p[3]); }
  memcpy(prev, p, 4); }
 for (int j = 0; j < 7; j++) QOI_PUT(0);
 QOI_PUT(1);
#undef QOI_PUT
 return q; }

love_noinline static struct g *host_qoie(struct g *g) {
 if (!oddp(g->sp[0]) || !oddp(g->sp[1]) || !strp(g->sp[2])) return g->sp[2] = ZeroPoint, g->sp += 2, g;
 intptr_t w = getcharm(g->sp[0]), h = getcharm(g->sp[1]);
 if (w < 1 || h < 1 || (uint64_t) w * (uint64_t) h > (1u << 24) || len(g->sp[2]) != (uint64_t) w * (uint64_t) h * 4)
  return g->sp[2] = ZeroPoint, g->sp += 2, g;
 uintptr_t k = qoi_enc((const uint8_t*) txt(g->sp[2]), (uint32_t) w, (uint32_t) h, NULL);
 if (!ok(g = str0(g, k))) return g;               // pushes: out over the three
 qoi_enc((const uint8_t*) txt(g->sp[3]), (uint32_t) w, (uint32_t) h, (uint8_t*) txt(g->sp[0]));
 g->sp[3] = g->sp[0], g->sp += 3;
 return g; }
static lvm(lvm_qoie) LvmCall(g, host_qoie)
LvDef("qoi-encode", qoie, 3, "qoi");
