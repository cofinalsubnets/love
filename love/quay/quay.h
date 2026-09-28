#ifndef _g_cb_h
#define _g_cb_h
#include <stdint.h>
#include <stdarg.h>

// console buffer. each cell is three u32 words:
//   g   bits  0..20  codepoint (0 is the blank)
//       bits 21..22  width: 0 single, 1 a wide char's left half, 2 its right half
//       bit  23      picture: bits 0..22 name a tile, not a codepoint
//       bits 24..31  face bits (bold / underline / reverse / ..)
//   fg, bg           a colour: the top byte its kind, the low 24 bits its value
// cb only stores these -- the renderer maps a codepoint to a glyph (cb_437 for
// the built-in faces), a colour to pixels, and faces to whatever it can afford.
// cb_putc stamps each cell with the current pen (cur_fg, cur_bg, cur_face).
struct cb_cell { uint32_t g, fg, bg; };

#define cb_gw(cp, face) (((uint32_t) (cp) & 0x1fffffu) | (uint32_t) (uint8_t) (face) << 24)
#define cb_cp(g)    ((g) & 0x1fffffu)
#define cb_wide(g)  (((g) >> 21) & 3u)
#define cb_face(g)  ((uint8_t) ((g) >> 24))
enum { cb_lead = 1, cb_tail = 2 };  // the width field: a wide char's two halves

enum {              // face bits, the glyph word's top byte
  cb_bold = 1, cb_under = 2, cb_rev = 4, cb_dim = 8,
  cb_ital = 16, cb_strike = 32, cb_blink = 64, cb_hide = 128 };

// a colour's kind: the screen's default, an xterm-256 index, or rgb24. a default
// cell follows the screen's def_fg/def_bg, so a recolour moves it without a rewrite.
enum { cb_def = 0, cb_idx = 1, cb_rgb = 2 };
#define cb_ink(kind, v) ((uint32_t) (kind) << 24 | ((uint32_t) (v) & 0xffffffu))
#define cb_kind(k)  ((k) >> 24)
#define cb_val(k)   ((k) & 0xffffffu)

enum {              // flag bits: the console's modes
  cb_show   = 1,    // cursor visible (DECTCEM ?25) -- renderers read it
  cb_wrap   = 2,    // autowrap (DECAWM ?7)
  cb_lnm    = 4,    // LNM (20): \n implies \r -- the kernel console's discipline
  cb_origin = 8,    // DECOM (?6): rows address relative to the scroll region
  cb_pend   = 16,   // wrap pending: a glyph landed on the last column
  cb_priv   = 32,   // parser transient: the CSI had a DEC '?'/'='/'<' marker
  cb_junk   = 64,   // parser transient: the CSI had intermediates we don't speak
  cb_gt     = 128 };// parser transient: the CSI had the '>' marker (secondary DA)

enum { cb_outn = 64 };  // the reply queue's capacity (cb_reply's buffer size)

struct cb {
  uint32_t wpos, spos;        // the write cursor, and DECSC's saved one
  uint16_t rows, cols, flag, arg;  // arg: the CSI parameter being collected
  uint32_t cur_fg, cur_bg, def_fg, def_bg;  // the pen, and what a default colour means
  uint32_t sfg, sbg;  // the saved pen (DECSC), with sface
  uint8_t cur_face, sface, esc;  // esc: escape-parser state
  uint16_t pv[8]; uint8_t pn;  // pv/pn: collected CSI parameters
  uint16_t top, bot;  // the scroll region, inclusive rows
  uint8_t out[cb_outn], on;  // the reply queue (DSR/DA answers ride home here)
  uint32_t ucp; uint8_t un;  // utf-8 in flight: the codepoint, continuations to come
  uint8_t ob[6], ol;  // an OSC body's head: enough to recognize the colour asks
  uint32_t dmg[8];  // dirty rows, one bit each (row 255 stands for 255-and-past);
                    // every grid write marks, a renderer reads-and-clears --
                    // repainting only what moved is what keeps a wide window quick
  struct cb_cell cb[]; };

// the bytes a screen of rows x cols needs, header and cells
#define cb_size(rows, cols) \
  (sizeof(struct cb) + (uintptr_t) (rows) * (uintptr_t) (cols) * sizeof(struct cb_cell))

void
  cb_open(struct cb*, uint16_t rows, uint16_t cols),
  cb_clear(struct cb*),
  cb_putc(struct cb*, char),
  cb_stamp(struct cb*, uint8_t),
  cb_fill(struct cb*, uint32_t cp),
  cb_attr(struct cb*, uint32_t fg, uint32_t bg),
  cb_recolor(struct cb*, uint32_t fg, uint32_t bg),
  cb_cur(struct cb*, uint32_t row, uint32_t col);
int cb_reply(struct cb*, uint8_t*);  // drain the reply queue; buf holds cb_outn
uint32_t cb_unfold(uint8_t);       // a cp437 glyph byte's codepoint
uint8_t cb_437(uint32_t cp);       // the cp437 glyph that draws cp: 0xfe, the ■, for none
uint8_t cb_width(uint32_t cp);     // the columns cp takes: 0 1 or 2, 'text's wcwidth

struct font { uint8_t const *glyphs, w, h; };
extern uint8_t const cga_8x8[256][8], cleat_8x16[256][16];

// where a screen lands (paint.c): a 32bpp target. px is the pixel origin and
// pitch/w/h are all in PIXELS -- a screen paints at an ORIGIN inside it, so one
// target can carry several panes rather than exactly one screen.
// scale is how many of this target's pixels a GLYPH pixel gets, so a cell covers
// f->w*scale by f->h*scale. it is the screen's number and not the face's: a bitmap
// stays sharp on a dense display by growing whole pixels, where the alternative is
// resampling somebody else does. 1 is the bitmap as drawn; 0 paints nothing.
struct cb_paper { volatile uint32_t *px; uintptr_t pitch, w, h, scale; };
void cb_paint(struct cb_paper const*, struct cb const*, struct font const*,
              uint16_t row, uintptr_t x0, uintptr_t y0, uint32_t cur);
#endif
