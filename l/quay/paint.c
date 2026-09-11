// paint -- a quay screen as pixels, and the only place the palette is spent.
// 32bpp targets; a 1-bit device (the playdate) draws its own.
#include "quay.h"
#include "xterm256.h"

// one CELL onto the paper at pixel (x,y). a cell that would fall off is dropped,
// so a caller cannot be made to write outside the target it named. a glyph pixel
// is a paper->scale square, which is the whole of "sharp": whole pixels, no
// resampling, and the same table serving a 640x400 screen and a dense one.
static void cb_px(struct cb_paper const *p, struct font const *f,
                  uint32_t cell, uintptr_t x, uintptr_t y) {
  uintptr_t const bpr = ((uintptr_t) f->w + 7) / 8, s = p->scale;
  if (x + f->w * s > p->w || y + f->h * s > p->h) return;
  uint8_t const g = cb_ch(cell), face = cb_face(cell);
  uint8_t const *bmp = f->glyphs + bpr * f->h * (g == '\n' ? 0 : g);
  uint8_t fgx = cb_fg(cell);
  if (face & cb_bold && fgx < 8) fgx = (uint8_t) (fgx + 8);   // bold as the bright half
  uint32_t fg = xterm256[fgx], bg = xterm256[cb_bg(cell)];
  if (face & cb_rev) { uint32_t t = fg; fg = bg, bg = t; }
  for (uint8_t r = 0; r < f->h; r++) {
    int const ul = (face & cb_under) && r == f->h - 1u;   // underline: the last scanline
    uint32_t o = bmp[r * bpr];
    if (bpr > 1) o = o << 8 | bmp[r * bpr + 1];
    for (uintptr_t d = 0; d < s; d++) {
      volatile uint32_t *px = p->px + (y + r * s + d) * p->pitch + x;
      for (uint8_t k = 0; k < f->w; k++) {
        uint32_t const v = ul || o >> (bpr * 8 - 1 - k) & 1 ? fg : bg;
        for (uintptr_t e = 0; e < s; e++) px[k * s + e] = v; } } } }

// one grid ROW of `c` onto the paper at (x0,y0) -- the origin is what lets a screen
// hold a RECTANGLE of the target rather than all of it. `cur` names the cell wearing
// the cursor (~0u for none), worn as the reverse face so a cell already reversed
// reads normally under it, which is the only way a block stays visible on one.
void cb_paint(struct cb_paper const *p, struct cb const *c, struct font const *f,
              uint16_t row, uintptr_t x0, uintptr_t y0, uint32_t cur) {
  if (row >= c->rows) return;
  for (uint16_t j = 0; j < c->cols; j++) {
    uint32_t const pos = (uint32_t) row * c->cols + j;
    uint32_t cell = c->cb[pos];
    if (pos == cur) cell ^= (uint32_t) cb_rev << 28;
    cb_px(p, f, cell, x0 + (uintptr_t) j * f->w * p->scale,
          y0 + (uintptr_t) row * f->h * p->scale); } }
