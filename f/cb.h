#ifndef _g_cb_h
#define _g_cb_h
#include <stdint.h>
#include <stdarg.h>

// console buffer. each cell is a packed 32-bit value:
//   bits  0..7   character code
//   bits  8..15  foreground colour index
//   bits 16..23  background colour index
//   bits 24..31  font index
// the colour and font bytes are plain indices -- cb only stores them;
// the renderer (fbdraw) maps colour indices to pixels and font indices
// to glyph sets. cb_putc stamps each cell with the current pen
// (cur_fg/cur_bg/cur_font), which cb_attr sets; a bare character
// therefore lands with all three indices 0.
#define cb_cell(ch, fg, bg, fn) ( (uint32_t)(uint8_t)(ch)        \
                                | (uint32_t)(uint8_t)(fg) <<  8  \
                                | (uint32_t)(uint8_t)(bg) << 16  \
                                | (uint32_t)(uint8_t)(fn) << 24 )
#define cb_ch(c)   ((uint8_t)(c))
#define cb_fg(c)   ((uint8_t)((c) >>  8))
#define cb_bg(c)   ((uint8_t)((c) >> 16))
#define cb_font(c) ((uint8_t)((c) >> 24))

struct cb {
  uint16_t rpos, wpos, spos, flag, arg;  // spos: saved cursor; arg: CSI param
  uint8_t rows, cols, cur_fg, cur_bg, cur_font, esc;  // esc: escape-parser state
  uint32_t cb[]; };

void
  cb_clear(struct cb*),
  cb_putc(struct cb*, char),
  cb_fill(struct cb*, uint8_t),
  cb_attr(struct cb*, uint8_t fg, uint8_t bg, uint8_t font),
  cb_cur(struct cb*, uint32_t row, uint32_t col);
int
  cb_getc(struct cb*),
  cb_ungetc(struct cb*, int),
  cb_eof(struct cb*);

struct font { uint8_t const *glyphs, w, h; };
extern uint8_t const cga_8x8[256][8], moderndos_8x16[256][16];
#endif
