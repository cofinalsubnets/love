// src/love/lib/gif.c
// (gif-frame s o canvas trans) -> canvas with the image whose descriptor is at s[o] laid on
// it, its trans index (-1 none) left see-through | why not: 1 not a gif, 2 not an image
// there, 3 a bad canvas. (gif-clear s o canvas) -> canvas with that image's box cleared.
// the canvas is the screen's w*h rgba; an image is clipped to it, lzw read as far as it goes.
#include "love.h"
#include "bytes.h"
#include <stdint.h>
#include <string.h>

struct gf {
 const uint8_t *s; uintptr_t n, o;          // the gif, the image descriptor's offset
 int sw, sh, fx, fy, fw, fh, inter, ncol;   // screen, image box, interlaced, palette size
 uintptr_t pal, data; };                    // palette's offset in s, first byte past it (the code size)

static int gf_open(struct gf *g, const uint8_t *s, uintptr_t n, intptr_t o) {
 g->s = s, g->n = n;
 if (n < 13 || memcmp(s, "GIF8", 4)) return 1;
 g->sw = ld16le(s + 6), g->sh = ld16le(s + 8);
 if (!g->sw || !g->sh || (uintptr_t) g->sw * (uintptr_t) g->sh > (uintptr_t) 1 << 24) return 1;
 if (o < 13 || (uintptr_t) o + 10 > n || s[o] != 0x2c) return 2;
 const uint8_t *d = s + o;
 g->o = (uintptr_t) o, g->fx = ld16le(d + 1), g->fy = ld16le(d + 3);
 g->fw = ld16le(d + 5), g->fh = ld16le(d + 7), g->inter = d[9] >> 6 & 1;
 g->data = g->o + 10, g->pal = 0, g->ncol = 0;
 if (d[9] & 0x80) {
  g->ncol = 2 << (d[9] & 7), g->pal = g->data, g->data += 3 * (uintptr_t) g->ncol; }
 else if (s[10] & 0x80) g->ncol = 2 << (s[10] & 7), g->pal = 13;
 if (g->pal + 3 * (uintptr_t) g->ncol > n) g->ncol = 0;
 return g->data < n ? 0 : 2; }

// the image's codes, lsb first across its sub-blocks, each index handed to put
struct gf_bits { const uint8_t *s; uintptr_t n, p; int left; uint32_t acc; int bits; };

static int gf_code(struct gf_bits *b, int size) {
 while (b->bits < size) {
  if (!b->left) {
   if (b->p >= b->n || !b->s[b->p]) return -1;
   b->left = b->s[b->p++]; }
  if (b->p >= b->n) return -1;
  b->acc |= (uint32_t) b->s[b->p++] << b->bits, b->bits += 8, b->left--; }
 int c = (int) (b->acc & ((1u << size) - 1));
 b->acc >>= size, b->bits -= size;
 return c; }

static void gf_paint(struct gf *g, uint8_t *cv, int trans) {
 static const int start[4] = { 0, 4, 2, 1 }, step[4] = { 8, 8, 4, 2 };
 uint16_t prefix[4096]; uint8_t suffix[4096], first[4096], stack[4096];
 int mcs = g->s[g->data];
 if (mcs < 1 || mcs > 11 || !g->fw || !g->fh) return;
 struct gf_bits b = { g->s, g->n, g->data + 1, 0, 0, 0 };
 int clear = 1 << mcs, size = mcs + 1, next = clear + 2, prev = -1, x = 0, y = 0, pass = 0;
 for (int i = 0; i < clear; i++) prefix[i] = 0xffff, suffix[i] = first[i] = (uint8_t) i;
 while (y < g->fh) {
  int c = gf_code(&b, size), k = 0;
  if (c < 0 || c == clear + 1) return;
  if (c == clear) { size = mcs + 1, next = clear + 2, prev = -1; continue; }
  if (prev < 0) { if (c >= clear) return; }
  else if (c > next) return;
  else if (next < 4096) {                      // prev's string and c's first, c's own when c is new
   prefix[next] = (uint16_t) prev, first[next] = first[prev];
   suffix[next] = c < next ? first[c] : first[prev];
   if (++next == 1 << size && size < 12) size++; }
  else if (c == next) return;
  for (int t = c;; t = prefix[t]) { stack[k++] = suffix[t]; if (t < clear) break; }
  prev = c;
  while (k-- && y < g->fh) {                   // the string comes off the stack in order
   int ix = stack[k], px = g->fx + x, py = g->fy + y;
   if (ix != trans && px < g->sw && py < g->sh) {
    uint8_t *o = cv + 4 * ((uintptr_t) py * (uintptr_t) g->sw + (uintptr_t) px);
    if (ix < g->ncol) {
     const uint8_t *c = g->s + g->pal + 3 * (uintptr_t) ix;
     o[0] = c[0], o[1] = c[1], o[2] = c[2]; }
    else o[0] = o[1] = o[2] = 0;
    o[3] = 255; }
   if (++x == g->fw) {
    x = 0;
    if (!g->inter) y++;
    else {
     y += step[pass];
     while (y >= g->fh && pass < 3) y = start[++pass]; } } } } }

static void gf_clear(struct gf *g, uint8_t *cv) {
 for (int y = g->fy; y < g->fy + g->fh && y < g->sh; y++)
  for (int x = g->fx; x < g->fx + g->fw && x < g->sw; x++)
   memset(cv + 4 * ((uintptr_t) y * (uintptr_t) g->sw + (uintptr_t) x), 0, 4); }

// both nifs: s o canvas [trans] on the stack, the answer over them
static struct g *gf_host(struct g *g, int nargs, int clear) {
 struct gf f;
 int why = !strp(g->sp[0]) ? 1 : !oddp(g->sp[1]) ? 2
         : gf_open(&f, (const uint8_t*) txt(g->sp[0]), len(g->sp[0]), getcharm(g->sp[1]));
 if (!why && (!strp(g->sp[2]) || len(g->sp[2]) != 4 * (uintptr_t) f.sw * (uintptr_t) f.sh))
  why = 3;
 if (!why && nargs == 4 && !oddp(g->sp[3])) why = 3;
 if (why) return g->sp[nargs - 1] = putcharm(why), g->sp += nargs - 1, g;
 int trans = nargs == 4 ? (int) getcharm(g->sp[3]) : -1;
 if (!ok(g = str0(g, len(g->sp[2])))) return g;   // pushes: the new canvas
 f.s = (const uint8_t*) txt(g->sp[1]);
 uint8_t *cv = (uint8_t*) txt(g->sp[0]);
 memcpy(cv, txt(g->sp[3]), len(g->sp[3]));
 if (clear) gf_clear(&f, cv); else gf_paint(&f, cv, trans);
 g->sp[nargs] = g->sp[0], g->sp += nargs;
 return g; }

love_noinline static struct g *host_gif_frame(struct g *g) { return gf_host(g, 4, 0); }
love_noinline static struct g *host_gif_clear(struct g *g) { return gf_host(g, 3, 1); }
static lvm(lvm_gif_frame) LvmCall(g, host_gif_frame)
static lvm(lvm_gif_clear) LvmCall(g, host_gif_clear)

LvDef("gif-frame", gif_frame, 4, "gif");
LvDef("gif-clear", gif_clear, 3, "gif");
