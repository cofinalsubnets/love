// paint -- a quay screen as pixels, and the only place the palette is spent.
// 32bpp targets; a 1-bit device (the playdate) draws its own.
#include "quay.h"
#include "xterm256.h"

// a colour word as xrgb: a default follows the screen's, an index is the palette's.
// bold brightens the low eight, as a vt did.
static uint32_t cb_rgbof(struct cb const *c, uint32_t k, uint32_t d, int bright) {
  if (cb_kind(k) == cb_def) k = d;
  if (cb_kind(k) == cb_rgb) return cb_val(k);
  uint32_t v = cb_val(k) & 255u;
  return xterm256[bright && v < 8 ? v + 8 : v]; }

// halfway from a to b, per channel: dim's fg
static uint32_t cb_mid(uint32_t a, uint32_t b) {
  return (a >> 1 & 0x7f7f7f) + (b >> 1 & 0x7f7f7f); }

// one TILE onto the paper at pixel (x,y): its piece of the picture, a pixel a glyph pixel
// (so a scale square each), the cell's bg where the picture set nothing. a picture is laid
// in the screen's cell grain, so a face of another size paints the tile as bare ground
static void cb_tpx(struct cb_paper const *p, struct cb const *c, struct font const *f,
                   struct cb_cell const *cell, uintptr_t x, uintptr_t y) {
  uintptr_t const s = p->scale;
  if (x + f->w * s > p->w || y + f->h * s > p->h) return;
  uint32_t const bg = cb_rgbof(c, cell->bg, c->def_bg, 0);
  struct cb_img const *im = f->w == c->cw && f->h == c->ch ? cb_img(c, cb_tslot(cell->g)) : 0;
  uint32_t const *ipx = cb_ipx(c);
  for (uint8_t r = 0; r < f->h; r++) {
    uint32_t const Y = cb_tty(cell->g) * f->h + r;
    for (uintptr_t d = 0; d < s; d++) {
      volatile uint32_t *px = p->px + (y + r * s + d) * p->pitch + x;
      for (uint8_t k = 0; k < f->w; k++) {
        uint32_t const X = cb_ttx(cell->g) * f->w + k,
                       v = im && X < im->w && Y < im->h ? ipx[im->off + Y * im->w + X] : 0;
        uint32_t const o = v >> 24 ? v & 0xffffffu : bg;
        for (uintptr_t e = 0; e < s; e++) px[k * s + e] = o; } } } }

// cp's glyph in the chain: the built-in face's where the cp437 page has cp, else a loaded
// face's (qf, the 8x16 cell only). cb_row reads row r of it left-aligned in 32 bits, bit 31
// the leftmost pixel, and 0 for a glyph neither face has
struct cb_look { uint8_t const *bmp, *rows; };
static struct cb_look cb_look(struct font const *f, uint8_t const *qf, uint32_t cp) {
  uintptr_t const bpr = ((uintptr_t) f->w + 7) / 8;
  int const g = cb_437x(cp);
  return (struct cb_look) { g < 0 ? 0 : f->glyphs + bpr * f->h * (uint32_t) g,
                            g < 0 && qf && f->w == 8 && f->h == 16 ? cb_face_rows(qf, cp) : 0 }; }

static uint32_t cb_row(struct font const *f, struct cb_look l, uint8_t r) {
  uintptr_t const bpr = ((uintptr_t) f->w + 7) / 8;
  if (l.rows) return ((uint32_t) l.rows[2 * r] | (uint32_t) l.rows[2 * r + 1] << 8) << 16;
  if (l.bmp) return (uint32_t) l.bmp[r * bpr] << 24 | (bpr > 1 ? (uint32_t) l.bmp[r * bpr + 1] << 16 : 0u);
  return 0; }

// one CELL onto the paper at pixel (x,y), wide when it is a wide char's lead -- two cells'
// width, the tail beside it painted here too. the base draws through the chain, the ■ where
// it has nothing; a cluster's marks lie over it, centred on a wide one, and a mark the chain
// lacks draws nothing. a cell that would fall off is dropped, so a caller cannot be made to
// write outside the target it named. a glyph pixel is a paper->scale square, which is the
// whole of "sharp": whole pixels, no resampling, and the same table serving a 640x400 screen
// and a dense one.
static void cb_px(struct cb_paper const *p, struct cb const *c, struct font const *f,
                  uint8_t const *qf, struct cb_cell const *cell, uintptr_t x, uintptr_t y) {
  uintptr_t const bpr = ((uintptr_t) f->w + 7) / 8, s = p->scale;
  int const wide = cb_wide(cell->g) == cb_lead;
  uintptr_t const pw = wide ? 2u * f->w : f->w;   // pixels across
  if (x + pw * s > p->w || y + f->h * s > p->h) return;
  struct cb_look l[cb_clun] = { cb_look(f, qf, cb_base(c, cell->g)) };
  if (!l[0].bmp && !l[0].rows) l[0].bmp = f->glyphs + bpr * f->h * 0xfeu;
  uint32_t const *v = cb_clu(c, cell->g), n = v ? cb_clun : 1u;
  for (uint32_t k = 1; k < n; k++) l[k] = cb_look(f, qf, v[k]);
  uint8_t const face = cb_face(cell->g);
  uint32_t fg = cb_rgbof(c, cell->fg, c->def_fg, face & cb_bold),
           bg = cb_rgbof(c, cell->bg, c->def_bg, 0);
  if (face & cb_rev) { uint32_t t = fg; fg = bg, bg = t; }
  if (face & cb_dim) fg = cb_mid(fg, bg);
  if (face & cb_hide) fg = bg;
  for (uint8_t r = 0; r < f->h; r++) {
    int const ul = ((face & cb_under) && r == f->h - 1u)    // underline: the last scanline
                || ((face & cb_strike) && r == f->h / 2u);  // strike: the middle one
    uint32_t o = cb_row(f, l[0], r);
    for (uint32_t k = 1; k < n; k++) o |= cb_row(f, l[k], r) >> (wide ? f->w / 2u : 0u);
    if ((face & cb_ital) && r < f->h / 2u) o >>= 1;        // italic: the top half leans right
    for (uintptr_t d = 0; d < s; d++) {
      volatile uint32_t *px = p->px + (y + r * s + d) * p->pitch + x;
      for (uintptr_t k = 0; k < pw; k++) {
        uint32_t const v = ul || (o >> (31 - k) & 1) ? fg : bg;
        for (uintptr_t e = 0; e < s; e++) px[k * s + e] = v; } } } }

// one grid ROW of `c` onto the paper at (x0,y0) -- the origin is what lets a screen
// hold a RECTANGLE of the target rather than all of it. `cur` names the cell wearing
// the cursor (~0u for none), worn as the reverse face so a cell already reversed
// reads normally under it, which is the only way a block stays visible on one. a tail
// is its lead's to paint, and the cursor on one is worn by the lead.
void cb_paint(struct cb_paper const *p, struct cb const *c, struct font const *f,
              uint8_t const *qf, uint16_t row, uintptr_t x0, uintptr_t y0, uint32_t cur) {
  if (row >= c->rows) return;
  for (uint16_t j = 0; j < c->cols; j++) {
    uint32_t const pos = (uint32_t) row * c->cols + j;
    struct cb_cell cell = c->cb[pos];
    int const lead = cb_wide(cell.g) == cb_lead && j + 1u < c->cols
                     && cb_wide(c->cb[pos + 1].g) == cb_tail;
    if (j && cb_wide(cell.g) == cb_tail && cb_wide(c->cb[pos - 1].g) == cb_lead) continue;
    if (!lead) cell.g &= ~((uint32_t) 3 << 21);             // a lone half paints single
    uintptr_t const px0 = x0 + (uintptr_t) j * f->w * p->scale, py0 = y0 + (uintptr_t) row * f->h * p->scale;
    if (cell.g & cb_pic) { cb_tpx(p, c, f, &cell, px0, py0); continue; }
    if (pos == cur || (lead && pos + 1 == cur)) cell.g ^= (uint32_t) cb_rev << 24;
    cb_px(p, c, f, qf, &cell, x0 + (uintptr_t) j * f->w * p->scale,
          y0 + (uintptr_t) row * f->h * p->scale); } }
