// inle/png.c
// (png-unfilter s o rows n bpp) -> one pass's rows from offset o of s with their filters
// undone and filter bytes dropped, rows*n bytes | () for a bad filter or too few bytes
#include "love.h"
#include <stdint.h>

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

static int unfilter_args(struct ai *g) {
 for (int k = 1; k < 5; k++) if (!oddp(g->sp[k]) || getcharm(g->sp[k]) < 0) return 0;
 uintptr_t o = (uintptr_t) getcharm(g->sp[1]), rows = (uintptr_t) getcharm(g->sp[2]),
           n = (uintptr_t) getcharm(g->sp[3]), bpp = (uintptr_t) getcharm(g->sp[4]);
 return strp(g->sp[0]) && bpp >= 1 && bpp <= 8 && n < ((uintptr_t) 1 << 31)
     && rows < ((uintptr_t) 1 << 31) && o <= len(g->sp[0])
     && rows * (n + 1) <= len(g->sp[0]) - o; }

ai_noinline static struct ai *host_unfilter(struct ai *g) {
 if (!unfilter_args(g)) return g->sp[4] = ZeroPoint, g->sp += 4, g;
 uintptr_t rows = (uintptr_t) getcharm(g->sp[2]), n = (uintptr_t) getcharm(g->sp[3]);
 if (!ai_ok(g = str0(g, rows * n))) return g;       // pushes: out over the five args
 const uint8_t *in = (const uint8_t*) txt(g->sp[1]) + getcharm(g->sp[2]);
 uintptr_t bpp = (uintptr_t) getcharm(g->sp[5]);
 uint8_t *o = (uint8_t*) txt(g->sp[0]);
 for (uintptr_t y = 0; y < rows; y++, in += n + 1)
  if (!unfilter_row(o + y * n, y ? o + (y - 1) * n : 0, in + 1, n, bpp, in[0]))
   return g->sp[5] = ZeroPoint, g->sp += 5, g;
 g->sp[5] = g->sp[0], g->sp += 5;
 return g; }
static lvm(lvm_unfilter) LvmCall(g, host_unfilter)

static union u const
  nif_unfilter[] = {{lvm_cur}, {.x = putcharm(5)}, {lvm_unfilter}, {lvm_ret0}};
LvNif("png-unfilter", nif_unfilter, NULL);
