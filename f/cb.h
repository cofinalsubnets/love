#ifndef _g_cb_h
#define _g_cb_h
#include <stdint.h>
#include <stdarg.h>
struct cb {
  uint16_t rpos, wpos, flag;
  uint8_t rows, cols, cb[]; };
void
  cb_clear(struct cb*),
  cb_putc(struct cb*, char),
  cb_fill(struct cb*, uint8_t),
  cb_cur(struct cb*, uint32_t row, uint32_t col);
int
  cb_getc(struct cb*),
  cb_ungetc(struct cb*, int),
  cb_eof(struct cb*);

struct font { uint8_t *glyphs, w, h; };
extern uint8_t cga_8x8[256][8];
#endif
