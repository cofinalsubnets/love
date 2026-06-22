#include "ai.h"
#include "cb.h"

void cb_fill(struct cb *c, uint8_t _) {
  uint32_t cell = cb_cell(_, c->cur_fg, c->cur_bg, c->cur_font);
  for (uint32_t i = 0, j = c->rows * c->cols; i < j; i++)
    c->cb[i] = cell; }

void cb_clear(struct cb *c) { cb_fill(c, 0); }

void cb_cur(struct cb *c, uint32_t row, uint32_t col) {
  c->wpos = (row * c->cols + col) % (c->rows * c->cols); }

void cb_attr(struct cb *c, uint8_t fg, uint8_t bg, uint8_t font) {
  c->cur_fg = c->def_fg = fg, c->cur_bg = c->def_bg = bg, c->cur_font = font; }

// advance to the start of the next row; if already on the bottom row
// scroll the buffer up by one row and leave the cursor at the start
// of the (now blank) bottom row. the l line editor relies on this:
// when the multi-line buffer reaches the last row, the terminal must
// scroll so its relative cursor-up moves still find the right rows.
static void cb_line_feed(struct cb *c) {
  uintptr_t rs = c->rows, cs = c->cols;
  if (c->wpos / cs == rs - 1u) {
    for (uintptr_t i = 0, j = (rs - 1) * cs; i < j; i++) c->cb[i] = c->cb[i + cs];
    uint32_t cell = cb_cell(0, c->cur_fg, c->cur_bg, c->cur_font);
    for (uintptr_t i = (rs - 1) * cs, j = rs * cs; i < j; i++) c->cb[i] = cell;
    c->wpos = (rs - 1) * cs; }
  else c->wpos = (c->wpos / cs + 1) * cs; }

// erase from the cursor to the end of its row -- ANSI EL (CSI K).
static void cb_erase_eol(struct cb *c) {
  uint32_t cell = cb_cell(0, c->cur_fg, c->cur_bg, c->cur_font);
  for (uint16_t p = c->wpos, e = (p / c->cols + 1) * c->cols; p < e; p++)
    c->cb[p] = cell; }

// erase from the cursor to the end of the screen -- ANSI ED (CSI J,
// arg 0). the l line editor calls this each render before redrawing.
static void cb_erase_eos(struct cb *c) {
  uint32_t cell = cb_cell(0, c->cur_fg, c->cur_bg, c->cur_font);
  for (uint32_t p = c->wpos, e = (uint32_t) c->rows * c->cols; p < e; p++)
    c->cb[p] = cell; }

// cb_putc interprets a small ANSI subset, enough for the line editor:
// \r returns to column 0 of the current row; \b moves left; \n line-
// feeds (and scrolls if needed). ESC 7 / ESC 8 save and restore the
// cursor (DECSC/DECRC). within CSI: K erases to end of row, J erases
// to end of screen, <n>A/<n>C/<n>D move the cursor up/right/left
// (default 1), and m sets the pen colour -- SGR 0 resets to the pen
// cb_attr last set, 38;5;N / 48;5;N pick a 256-colour fg/bg, 39/49 the
// defaults. anything else is stamped as a glyph with the current pen.
void cb_putc(struct cb *c, char i) {
  switch (c->esc) {
   case 1:                                  // after ESC
    c->esc = 0;
    if (i == '[') c->esc = 2, c->arg = 0, c->pn = 0;   // CSI: collect parameters
    else if (i == '7') c->spos = c->wpos;   // DECSC: save the cursor
    else if (i == '8') c->wpos = c->spos;   // DECRC: restore the cursor
    return;
   case 2: {                                // within CSI ESC [ ...
    if (i >= '0' && i <= '9') { c->arg = c->arg * 10 + (i - '0'); return; }
    if (i == ';') {                          // parameter separator: stash, keep going
      if (c->pn < 4) c->pv[c->pn++] = (uint8_t) c->arg;
      c->arg = 0;
      return; }
    if (c->pn < 4) c->pv[c->pn++] = (uint8_t) c->arg;   // the final parameter
    c->esc = 0;
    uint16_t n = c->pv[0] ? c->pv[0] : 1, cs = c->cols;
    if (i == 'K') cb_erase_eol(c);           // EL: erase to end of row
    else if (i == 'J') cb_erase_eos(c);      // ED: erase to end of screen
    else if (i == 'D')                       // CUB: cursor left
      c->wpos = c->wpos > n ? c->wpos - n : 0;
    else if (i == 'C') {                     // CUF: cursor right (clamp to row)
      uint16_t end = (c->wpos / cs + 1) * cs - 1;
      c->wpos = c->wpos + n > end ? end : c->wpos + n; }
    else if (i == 'A') {                     // CUU: cursor up (clamp to row 0)
      uint16_t up = n * cs;
      c->wpos = c->wpos >= up ? c->wpos - up : c->wpos % cs; }
    else if (i == 'm')                       // SGR: set the pen colour (256-colour + reset)
      for (uint8_t k = 0; k < c->pn; k++) {
        uint8_t p = c->pv[k];
        if (p == 0) c->cur_fg = c->def_fg, c->cur_bg = c->def_bg;        // reset to the default pen
        else if (p == 39) c->cur_fg = c->def_fg;                         // default foreground
        else if (p == 49) c->cur_bg = c->def_bg;                         // default background
        else if (p == 38 && k + 2 < c->pn && c->pv[k + 1] == 5)          // 38;5;N -- 256-colour fg
          c->cur_fg = c->pv[k + 2], k += 2;
        else if (p == 48 && k + 2 < c->pn && c->pv[k + 1] == 5)          // 48;5;N -- 256-colour bg
          c->cur_bg = c->pv[k + 2], k += 2; }
    return; }
   default:
    if (i == 27) { c->esc = 1; return; }     // ESC: begin a sequence
    if (i == '\r') { c->wpos -= c->wpos % c->cols; return; }
    if (i == '\b') {
      if (c->wpos != c->rpos) c->wpos--;
      return; }
    if (i == '\n') return cb_line_feed(c);   // line feed (scrolls at bottom)
    c->cb[c->wpos] = cb_cell(i, c->cur_fg, c->cur_bg, c->cur_font);
    if (++c->wpos == c->cols * c->rows) c->wpos = 0; } }

int cb_ungetc(struct cb *c, int i) {
  uint16_t r = c->rpos;
  r = r > 0 ? r - 1 : c->cols * c->rows - 1;
  if (r == c->wpos) return -1;
  c->rpos = r;
  // rewind one cell and replace its char, keeping the cell's colour/font
  c->cb[r] = (c->cb[r] & ~(uint32_t) 0xff) | (uint8_t) i;
  return i; }

int cb_eof(struct cb *c) {
  return c->rpos == c->wpos; }

int cb_getc(struct cb *c) {
  if (c->rpos == c->wpos) return -1;
  int i = cb_ch(c->cb[c->rpos]);
  if (++c->rpos == c->cols * c->rows) c->rpos = 0;
  return i; }
