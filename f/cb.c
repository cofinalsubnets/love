#include "g.h"
#include "cb.h"

void cb_fill(struct cb *c, uint8_t _) {
  uint32_t cell = cb_cell(_, c->cur_fg, c->cur_bg, c->cur_font);
  for (uint32_t i = 0, j = c->rows * c->cols; i < j; i++)
    c->cb[i] = cell; }

void cb_clear(struct cb *c) { cb_fill(c, 0); }

void cb_cur(struct cb *c, uint32_t row, uint32_t col) {
  c->wpos = (row * c->cols + col) % (c->rows * c->cols); }

void cb_attr(struct cb *c, uint8_t fg, uint8_t bg, uint8_t font) {
  c->cur_fg = fg, c->cur_bg = bg, c->cur_font = font; }

static void cb_line_feed(struct cb *c) {
  uintptr_t rs = c->rows, cs = c->cols,
            p = 1 + c->wpos / cs;
  c->wpos = cs * (p == rs ? 0 : p); }

// erase from the cursor to the end of its row -- ANSI EL (CSI K).
static void cb_erase_eol(struct cb *c) {
  uint32_t cell = cb_cell(0, c->cur_fg, c->cur_bg, c->cur_font);
  for (uint16_t p = c->wpos, e = (p / c->cols + 1) * c->cols; p < e; p++)
    c->cb[p] = cell; }

// cb_putc interprets a small ANSI subset, enough for the line editor:
// ESC 7 / ESC 8 save and restore the cursor (DECSC/DECRC), CSI K erases
// to the end of the row, CSI <n> D moves the cursor left. anything else
// is stamped as a glyph with the current pen; \b and \n are handled too.
void cb_putc(struct cb *c, char i) {
  switch (c->esc) {
   case 1:                                  // after ESC
    c->esc = 0;
    if (i == '[') c->esc = 2, c->arg = 0;   // CSI: collect a parameter
    else if (i == '7') c->spos = c->wpos;   // DECSC: save the cursor
    else if (i == '8') c->wpos = c->spos;   // DECRC: restore the cursor
    return;
   case 2:                                  // within CSI ESC [ ...
    if (i >= '0' && i <= '9') { c->arg = c->arg * 10 + (i - '0'); return; }
    c->esc = 0;
    if (i == 'K') cb_erase_eol(c);           // EL: erase to end of row
    else if (i == 'D') {                     // CUB: move the cursor left
      uint16_t n = c->arg ? c->arg : 1;
      c->wpos = c->wpos > n ? c->wpos - n : 0; }
    return;
   default:
    if (i == 27) { c->esc = 1; return; }     // ESC: begin a sequence
    if (i == '\b') {
      if (c->wpos != c->rpos) c->wpos--;
      return; }
    if (i == '\n') return cb_line_feed(c);   // line feed: advance, stamp nothing
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
