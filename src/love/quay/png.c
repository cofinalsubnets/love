// png -- a PNG laid into quay's store as pixels, for kitty's f=100. every colour type and
// depth (1..16), tRNS, and Adam7; alpha as the store keeps it, set at half or past.
// no allocation: the caller hands one region holding the file at its head and room behind
// it, and the pixels come back at the head. the zlib stream is packed in place, inflated
// behind where the pixels will end, then unfiltered and read out row by row -- a pixel
// never lands on a byte still to be read.
#include "quay.h"

intptr_t inflate_raw(unsigned char const*, uintptr_t, unsigned char*, uintptr_t);

static uint32_t qp_be32(uint8_t const *p) {
  return (uint32_t) p[0] << 24 | (uint32_t) p[1] << 16 | (uint32_t) p[2] << 8 | p[3]; }

static uint8_t qp_paeth(uint8_t a, uint8_t b, uint8_t c) {
  int const p = a + b - c, pa = p > a ? p - a : a - p, pb = p > b ? p - b : b - p,
            pc = p > c ? p - c : c - p;
  return pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }

// one pass's rows, filtered: each a filter byte and rb bytes, the previous row the one above
static int qp_unfilter(uint8_t *f, uint32_t rows, uint32_t rb, uint32_t bpp) {
  uint8_t *prev = 0;
  for (uint32_t y = 0; y < rows; y++) {
    uint8_t *row = f + (uintptr_t) y * (rb + 1u), t = row[0], *d = row + 1;
    if (t > 4) return -1;
    for (uint32_t i = 0; i < rb; i++) {
      uint8_t const a = i >= bpp ? d[i - bpp] : 0, b = prev ? prev[i] : 0,
                    c = prev && i >= bpp ? prev[i - bpp] : 0;
      d[i] = (uint8_t) (d[i] + (t == 1 ? a : t == 2 ? b : t == 3 ? (a + b) / 2 : t == 4 ? qp_paeth(a, b, c) : 0)); }
    prev = d; }
  return 0; }

// sample k (0-based across the row) of depth bits, as its raw value
static uint32_t qp_sample(uint8_t const *d, uint32_t k, uint32_t depth) {
  if (depth == 8) return d[k];
  if (depth == 16) return (uint32_t) d[2 * k] << 8 | d[2 * k + 1];
  uint32_t const bit = k * depth;
  return (uint32_t) d[bit >> 3] >> (8u - depth - (bit & 7u)) & ((1u << depth) - 1u); }

// the region at buf, cap bytes, holds a PNG of n bytes: answers 0 and w x h pixels at buf,
// or -1 for no PNG this reads (and the region, then, is scratch)
int cb_png(uint8_t *buf, uintptr_t n, uintptr_t cap, uint32_t *wp, uint32_t *hp) {
  static uint8_t const sig[8] = { 137, 80, 78, 71, 13, 10, 26, 10 };
  static uint8_t const ax[7] = { 0, 4, 0, 2, 0, 1, 0 }, ay[7] = { 0, 0, 4, 0, 2, 0, 1 },
                       dx[7] = { 8, 8, 4, 4, 2, 2, 1 }, dy[7] = { 8, 8, 8, 4, 4, 2, 2 };
  if (n < 8 || n > cap) return -1;
  for (int i = 0; i < 8; i++) if (buf[i] != sig[i]) return -1;
  uint32_t w = 0, h = 0, depth = 0, ctype = 0, lace = 0, np = 0, trn = 0;
  uint32_t pal[256], tg = 0x10000u, tr = 0x10000u, tgn = 0x10000u, tb = 0x10000u;
  uint8_t alpha[256];
  for (int i = 0; i < 256; i++) pal[i] = 0, alpha[i] = 255;
  uintptr_t at = 8, z = 0;
  int ended = 0;
  while (!ended) {
    if (at + 12 > n) return -1;
    uint32_t const len = qp_be32(buf + at);
    uint8_t const *ty = buf + at + 4, *d = buf + at + 8;
    if (len > n - at - 12) return -1;
    if (!w && (ty[0] != 'I' || ty[1] != 'H' || ty[2] != 'D' || ty[3] != 'R')) return -1;
    if (ty[0] == 'I' && ty[1] == 'H' && ty[2] == 'D' && ty[3] == 'R') {
      if (len != 13 || w) return -1;
      w = qp_be32(d), h = qp_be32(d + 4), depth = d[8], ctype = d[9], lace = d[12];
      if (!w || !h || w > 16384u || h > 16384u || d[10] || d[11] || lace > 1) return -1;
      int const ok = (ctype == 0 && (depth == 1 || depth == 2 || depth == 4 || depth == 8 || depth == 16))
                  || (ctype == 3 && (depth == 1 || depth == 2 || depth == 4 || depth == 8))
                  || ((ctype == 2 || ctype == 4 || ctype == 6) && (depth == 8 || depth == 16));
      if (!ok) return -1; }
    else if (ty[0] == 'P' && ty[1] == 'L' && ty[2] == 'T' && ty[3] == 'E') {
      if (len % 3 || len > 768) return -1;
      np = len / 3;
      for (uint32_t k = 0; k < np; k++)
        pal[k] = (uint32_t) d[3 * k] << 16 | (uint32_t) d[3 * k + 1] << 8 | d[3 * k + 2]; }
    else if (ty[0] == 't' && ty[1] == 'R' && ty[2] == 'N' && ty[3] == 'S') {
      trn = 1;
      if (ctype == 3) for (uint32_t k = 0; k < len && k < 256; k++) alpha[k] = d[k];
      else if (ctype == 0 && len >= 2) tg = (uint32_t) d[0] << 8 | d[1];
      else if (ctype == 2 && len >= 6)
        tr = (uint32_t) d[0] << 8 | d[1], tgn = (uint32_t) d[2] << 8 | d[3], tb = (uint32_t) d[4] << 8 | d[5]; }
    else if (ty[0] == 'I' && ty[1] == 'D' && ty[2] == 'A' && ty[3] == 'T') {
      for (uint32_t k = 0; k < len; k++) buf[z + k] = d[k];   // packed down: z never passes d
      z += len; }
    else if (ty[0] == 'I' && ty[1] == 'E' && ty[2] == 'N' && ty[3] == 'D') ended = 1;
    else if (!(ty[0] & 32)) return -1;                       // a critical chunk this does not know
    at += 12u + len; }
  if (ctype == 3 && !np) return -1;
  uint32_t const ch = ctype == 0 || ctype == 3 ? 1 : ctype == 4 ? 2 : ctype == 2 ? 3 : 4;
  uint32_t const bits = depth * ch, bpp = bits < 8 ? 1 : bits / 8;
  // the filtered size, pass by pass (one pass when not interlaced)
  uintptr_t fsz = 0;
  for (int p = lace ? 0 : 6; p < 7; p++) {
    uint32_t const pw = lace ? (w + dx[p] - 1u - ax[p]) / dx[p] : w,
                   ph = lace ? (h + dy[p] - 1u - ay[p]) / dy[p] : h;
    if (pw && ph) fsz += (uintptr_t) ph * (1u + ((uintptr_t) pw * bits + 7u) / 8u); }
  uintptr_t const px = (uintptr_t) w * h * 4u, f0 = ((z > px ? z : px) + 3u) & ~(uintptr_t) 3;
  if (z < 6 || f0 + fsz > cap) return -1;
  // zlib: deflate, no preset dictionary
  if ((buf[0] & 15) != 8 || ((uint32_t) buf[0] << 8 | buf[1]) % 31u || buf[1] & 32) return -1;
  if (inflate_raw(buf + 2, z - 2, buf + f0, fsz) != (intptr_t) fsz) return -1;
  uint32_t *out = (uint32_t*) buf;
  uint8_t *f = buf + f0;
  for (int p = lace ? 0 : 6; p < 7; p++) {
    uint32_t const pw = lace ? (w + dx[p] - 1u - ax[p]) / dx[p] : w,
                   ph = lace ? (h + dy[p] - 1u - ay[p]) / dy[p] : h,
                   x0 = lace ? ax[p] : 0, y0 = lace ? ay[p] : 0,
                   sx = lace ? dx[p] : 1, sy = lace ? dy[p] : 1;
    if (!pw || !ph) continue;
    uint32_t const rb = (uint32_t) (((uintptr_t) pw * bits + 7u) / 8u);
    if (qp_unfilter(f, ph, rb, bpp)) return -1;
    for (uint32_t y = 0; y < ph; y++) {
      uint8_t const *d = f + (uintptr_t) y * (rb + 1u) + 1;
      for (uint32_t x = 0; x < pw; x++) {
        uint32_t r, g, b, a = 255;
        if (ctype == 3) {
          uint32_t const i = qp_sample(d, x, depth);
          if (i >= np) return -1;
          r = pal[i] >> 16, g = pal[i] >> 8 & 255u, b = pal[i] & 255u, a = alpha[i]; }
        else {
          uint32_t v[4];
          for (uint32_t k = 0; k < ch; k++) v[k] = qp_sample(d, x * ch + k, depth);
          // a sample to 8 bits: the high byte of 16, a low depth stretched over 0..255
          uint32_t const top = depth == 16 ? 8u : 0u, max = (1u << depth) - 1u;
          #define QP8(s) (depth == 16 ? (s) >> top : depth == 8 ? (s) : (s) * 255u / max)
          if (ctype == 0 || ctype == 4) {
            r = g = b = QP8(v[0]);
            if (ctype == 4) a = QP8(v[1]);
            else if (trn && v[0] == tg) a = 0; }
          else {
            r = QP8(v[0]), g = QP8(v[1]), b = QP8(v[2]);
            if (ctype == 6) a = QP8(v[3]);
            else if (trn && v[0] == tr && v[1] == tgn && v[2] == tb) a = 0; }
          #undef QP8
          }
        out[(uintptr_t) (y0 + y * sy) * w + x0 + x * sx] = a >= 128 ? 0xff000000u | r << 16 | g << 8 | b : 0; } }
    f += (uintptr_t) ph * (rb + 1u); }
  *wp = w, *hp = h;
  return 0; }
