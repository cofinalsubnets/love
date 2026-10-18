// png.c -- (png-unfilter s o rows n bpp) -> one pass's rows from offset o of s unfiltered,
// rows*n bytes | () for a bad filter or too few bytes
// (png-lay canvas cw frame fw x y op) -> the canvas with an apng frame's rgba laid at x y:
// op 0 overwrites the box, 1 lays it over | ()
#include "love.h"
#include <stdint.h>
#include <string.h>

static int paeth(int a, int b, int c) {
 int p = a + b - c, pa = p > a ? p - a : a - p, pb = p > b ? p - b : b - p,
     pc = p > c ? p - c : c - p;
 return pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }

// row y of out from its filtered bytes in; the row above is out's, zero for the first
static int unfilter_row(uint8_t *o, const uint8_t *up, const uint8_t *in, uintptr_t n,
                        uintptr_t bpp, int f) {
 for (uintptr_t i = 0; i < n; i++) {
  int a = i < bpp ? 0 : o[i - bpp], b = up ? up[i] : 0, c = up && i >= bpp ? up[i - bpp] : 0;
  switch (f) {
   case 0: o[i] = in[i]; break;
   case 1: o[i] = (uint8_t) (in[i] + a); break;
   case 2: o[i] = (uint8_t) (in[i] + b); break;
   case 3: o[i] = (uint8_t) (in[i] + ((a + b) >> 1)); break;
   case 4: o[i] = (uint8_t) (in[i] + paeth(a, b, c)); break;
   default: return 0; } }
 return 1; }

static int unfilter_args(struct g *g) {
 for (int k = 1; k < 5; k++) if (!oddp(g->sp[k]) || getcharm(g->sp[k]) < 0) return 0;
 uintptr_t o = (uintptr_t) getcharm(g->sp[1]), rows = (uintptr_t) getcharm(g->sp[2]),
           n = (uintptr_t) getcharm(g->sp[3]), bpp = (uintptr_t) getcharm(g->sp[4]);
 return strp(g->sp[0]) && bpp >= 1 && bpp <= 8 && n < ((uintptr_t) 1 << 31)
     && rows < ((uintptr_t) 1 << 31) && o <= len(g->sp[0])
     && (uint64_t) rows * (n + 1) <= len(g->sp[0]) - o; }

love_noinline static struct g *host_unfilter(struct g *g) {
 if (!unfilter_args(g)) return g->sp[4] = ZeroPoint, g->sp += 4, g;
 uintptr_t rows = (uintptr_t) getcharm(g->sp[2]), n = (uintptr_t) getcharm(g->sp[3]);
 if (!ok(g = str0(g, rows * n))) return g;       // pushes: out over the five args
 const uint8_t *in = (const uint8_t*) txt(g->sp[1]) + getcharm(g->sp[2]);
 uintptr_t bpp = (uintptr_t) getcharm(g->sp[5]);
 uint8_t *o = (uint8_t*) txt(g->sp[0]);
 for (uintptr_t y = 0; y < rows; y++, in += n + 1)
  if (!unfilter_row(o + y * n, y ? o + (y - 1) * n : 0, in + 1, n, bpp, in[0]))
   return g->sp[5] = ZeroPoint, g->sp += 5, g;
 g->sp[5] = g->sp[0], g->sp += 5;
 return g; }
static lvm(lvm_unfilter) LvmCall(g, host_unfilter)

LvDef("png-unfilter", unfilter, 5, "png");

// apng's over: s's alpha weighs it against d's, the sum the new alpha
static void png_over(uint8_t *d, const uint8_t *s) {
 unsigned sa = s[3], da = d[3];
 if (sa == 255 || !da) { memcpy(d, s, 4); return; }
 if (!sa) return;
 unsigned u = sa * 255, v = (255 - sa) * da, al = u + v;
 for (int k = 0; k < 3; k++) d[k] = (uint8_t) ((s[k] * u + d[k] * v) / al);
 d[3] = (uint8_t) (al / 255); }

love_noinline static struct g *host_pnglay(struct g *g) {
 for (int k = 0; k < 7; k++)
  if ((k == 0 || k == 2 ? !strp(g->sp[k]) : !oddp(g->sp[k]) || getcharm(g->sp[k]) < 0))
   return g->sp[6] = ZeroPoint, g->sp += 6, g;
 uintptr_t cw = (uintptr_t) getcharm(g->sp[1]), fw = (uintptr_t) getcharm(g->sp[3]),
           x = (uintptr_t) getcharm(g->sp[4]), y = (uintptr_t) getcharm(g->sp[5]),
           k = len(g->sp[0]), fn = len(g->sp[2]);
 int op = (int) getcharm(g->sp[6]);
 if (!cw || !fw || cw > 1 << 24 || fw > 1 << 24 || k % (4 * cw) || fn % (4 * fw)) return g->sp[6] = ZeroPoint, g->sp += 6, g;
 uintptr_t ch = k / (4 * cw), fh = fn / (4 * fw);
 if (x > cw || fw > cw - x || y > ch || fh > ch - y) return g->sp[6] = ZeroPoint, g->sp += 6, g;
 if (!ok(g = str0(g, k))) return g;               // pushes: the new canvas over the seven
 uint8_t *o = (uint8_t*) txt(g->sp[0]);
 const uint8_t *f = (const uint8_t*) txt(g->sp[3]);
 memcpy(o, txt(g->sp[1]), k);
 for (uintptr_t r = 0; r < fh; r++) {
  uint8_t *d = o + ((y + r) * cw + x) * 4;
  const uint8_t *c = f + r * fw * 4;
  if (op != 1) memcpy(d, c, fw * 4);
  else for (uintptr_t i = 0; i < fw; i++) png_over(d + 4 * i, c + 4 * i); }
 g->sp[7] = g->sp[0], g->sp += 7;
 return g; }
static lvm(lvm_pnglay) LvmCall(g, host_pnglay)
LvDef("png-lay", pnglay, 7, "png");
