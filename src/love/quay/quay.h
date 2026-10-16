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
// cb only stores these; the renderer maps them to glyphs, pixels and faces
struct cb_cell { uint32_t g, fg, bg; };

#define cb_gw(cp, face) (((uint32_t) (cp) & 0x1fffffu) | (uint32_t) (uint8_t) (face) << 24)
#define cb_cp(g)    ((g) & 0x1fffffu)
#define cb_wide(g)  (((g) >> 21) & 3u)
#define cb_face(g)  ((uint8_t) ((g) >> 24))
enum { cb_lead = 1, cb_tail = 2 };  // the width field: a wide char's two halves
// a tile: the picture bit, a store slot (1..127), and the cell's column and row in the picture
#define cb_pic      ((uint32_t) 1 << 23)
#define cb_tile(slot, tx, ty) (cb_pic | (uint32_t) (slot) << 16 | (uint32_t) (tx) << 8 | (uint32_t) (ty))
#define cb_tslot(g) (((g) >> 16) & 127u)
#define cb_ttx(g)   (((g) >> 8) & 255u)
#define cb_tty(g)   ((g) & 255u)

// a grapheme cluster: a base and up to nine marks; slots are the header's cb_nclu, then cx after
// the twin. free while its base is 0; a pool full past reclaiming sets cfull, for a bigger one
enum { cb_nclu = 128, cb_clun = 10 };
enum { cb_clumax = 0x1fffff - 0x110000 + 1 };   // the slots a glyph word can name
#define cb_clu0 0x110000u
#define cb_xsize(cx) ((uintptr_t) (cx) * cb_clun * sizeof(uint32_t))

enum {              // face bits, the glyph word's top byte
  cb_bold = 1, cb_under = 2, cb_rev = 4, cb_dim = 8,
  cb_ital = 16, cb_strike = 32, cb_blink = 64, cb_hide = 128 };

// a colour's kind: the screen's default (def_fg/def_bg, so a recolour needs no rewrite),
// an xterm-256 index, or rgb24
enum { cb_def = 0, cb_idx = 1, cb_rgb = 2 };
#define cb_ink(kind, v) ((uint32_t) (kind) << 24 | ((uint32_t) (v) & 0xffffffu))
#define cb_kind(k)  (((k) >> 24) & 0x7fu)
#define cb_soft     ((uint32_t) 1 << 31)   // on a row's last cell's fg: the row wrapped into the next
#define cb_val(k)   ((k) & 0xffffffu)

enum {              // flag bits: the console's modes
  cb_show   = 1,    // cursor visible (DECTCEM ?25)
  cb_wrap   = 2,    // autowrap (DECAWM ?7)
  cb_lnm    = 4,    // LNM (20): \n implies \r
  cb_origin = 8,    // DECOM (?6): rows address relative to the scroll region
  cb_pend   = 16,   // wrap pending: a glyph landed on the last column
  cb_priv   = 32,   // parser transient: the CSI had a DEC '?'/'='/'<' marker
  cb_junk   = 64,   // parser transient: the CSI had intermediates we don't speak
  cb_gt     = 128,  // parser transient: the CSI had the '>' marker (secondary DA)
  cb_alt    = 256,  // the alternate screen (?1049 and kin): scrolls keep no history
  cb_mx10   = 512,  // mouse (?9): presses alone
  cb_mbtn   = 1024, // mouse (?1000): presses and releases
  cb_mdrag  = 2048, // mouse (?1002): and moves while a button is held
  cb_many   = 4096, // mouse (?1003): and every move
  cb_msgr   = 8192, // mouse reports as CSI < b ; x ; y M/m (?1006), else CSI M and three bytes
  cb_paste  = 16384, // bracketed paste (?2004): a seat wraps what it pastes in CSI 200~ .. 201~
  cb_gc     = 32768 };// grapheme clusters (?2027): VS16 gives an emoji style two cells
enum { cb_mice = cb_mx10 | cb_mbtn | cb_mdrag | cb_many };

enum { cb_outn = 64 };  // the reply queue's capacity (cb_reply's buffer size)
enum { cb_saymax = 40 };  // one reply's longest: kitty's, with a 10-digit id and its error
// the charsets: G0 and G1 each ascii or DEC special graphics, and SO's shift to G1
enum { cb_g0 = 1, cb_g1 = 2, cb_so = 4 };
enum { cb_pmax = 16 };  // CSI parameters kept: two rgb pens in one SGR are ten
enum { cb_mousen = 36 };  // a mouse report's longest: ESC [ < and three 10-digit fields, 2 ; and M

struct cb {
  uint32_t wpos, spos;        // the write cursor, and DECSC's saved one
  uint16_t rows, cols, flag, arg;  // arg: the CSI parameter being collected
  uint32_t cur_fg, cur_bg, def_fg, def_bg;  // the pen, and what a default colour means
  uint32_t sfg, sbg;  // the saved pen (DECSC), with sface
  uint8_t cur_face, sface, esc, gset;  // esc: escape-parser state; gset: the charsets (cb_g0 cb_g1 cb_so)
  uint16_t pv[cb_pmax]; uint8_t pn, ci;  // pv/pn: collected CSI parameters, ci its intermediate
  // SGR in flight: the pen; ps 1 after 38/48, 2 an index to come, 3..5 its r g b; pw 38 or 48
  uint32_t pfg, pbg, pacc; uint8_t pface, ps, pw;
  uint16_t top, bot;  // the scroll region, inclusive rows
  uint8_t out[cb_outn], on, sgset;  // the reply queue (DSR/DA answers ride home here); DECSC's charsets
  uint8_t rd, cfull;  // rd: someone drains the queue (cb_reply), so a feed waits on it (cb_full)
  uint32_t ucp; uint8_t un;  // utf-8 in flight: the codepoint, continuations to come
  uint8_t ob[6], ol;  // an OSC body's head: enough to recognize the colour asks
  uint32_t dmg[8];  // dirty rows, a bit each (255 is 255-and-past): writes mark, a renderer clears
  uint8_t cw, ch;   // a cell in pixels: the store's grain, and what CSI 16 t answers
  uint8_t sm, sp2;  // sixel: the parameter command in flight ('#' '!' '"'), P2
  uint16_t sslot;   // sixel: the slot being decoded, 0 for none
  uint32_t sn, stop;  // the store's bytes past the cells (0: no pictures), its bump top
  uint32_t sx, sy, sw, sh, sreg, srep;  // sixel: the pen, the extent, the register, the repeat
  // kitty: keys, the key and value being read, base64 and pixel in flight, and a chunked
  // image's open transfer (slot, pixels laid)
  uint32_t ks, kv, ki, kc, kr, kval, kacc, kpx, kpix, kslot;
  uint8_t ka, kf, km, kq, kcur, kd, kt, ko, kkey, kvc, kn, kbyte, kpad, kopen;
  uint32_t clu[cb_nclu][cb_clun];  // the clusters, their unused words 0
  uint32_t cx;                     // the pool's slots past these, after the twin
  // history: a ring of hl lines after the store, hn held, the oldest at hh; view, how far a
  // reader looks back. twin: room after it, where the main grid waits out the alternate screen
  uint32_t hl, hh, hn, view, twin;
  int32_t sel0, sel1;  // the selection: cells [sel0, sel1) as glass counts them, none when equal
  uint32_t pgen;       // the last picture's gen
  struct cb_cell cb[]; };

// the store, after the cells: 128 slots (0 unused), 256 sixel registers, then xrgb pixels, top
// byte 0xff where set. id: kitty's, 0 none. gen: new per picture, kept across a regrid, so a
// reader tells one it already sent. dw x dh: what its tiles span, 0 its own size
struct cb_img { uint32_t off, w, h, live, id, gen, dw, dh; };
enum { cb_nimg = 128, cb_shead = cb_nimg * sizeof(struct cb_img) + 256 * 4 };
// the bytes a screen of rows x cols needs, header, cells and a store of sn bytes
#define cb_size(rows, cols, sn) \
  (sizeof(struct cb) + (uintptr_t) (rows) * (uintptr_t) (cols) * sizeof(struct cb_cell) + (uintptr_t) (sn))
// the bytes a history of hl lines takes, after the store, and a twin grid's after that
#define cb_hsize(hl, cols) ((uintptr_t) (hl) * (uintptr_t) (cols) * sizeof(struct cb_cell))
#define cb_tsize(rows, cols) ((uintptr_t) (rows) * (uintptr_t) (cols) * sizeof(struct cb_cell))
// a store a screenful of pictures deep, at 8x16 cells
#define cb_sdefault(rows, cols) ((uint32_t) cb_shead + (uint32_t) (rows) * (uint32_t) (cols) * 512u)

void
  cb_open(struct cb*, uint16_t rows, uint16_t cols, uint32_t sn),
  cb_store(struct cb*, uint32_t sn),   // lay an empty store of sn bytes after the cells
  cb_hist(struct cb*, uint32_t hl),    // lay an empty history of hl lines after the store
  cb_twin(struct cb*, uint32_t on),    // lay (1) or take away (0) the twin grid after the history
  cb_xclu(struct cb*, uint32_t cx),    // grow the slots after the twin to cx, the new ones empty
  // old into a fresh rows x cols screen, with an sn store, hl history, a twin when tw, old's cx
  cb_regrid(struct cb*, struct cb const *old, uint16_t rows, uint16_t cols, uint32_t sn, uint32_t hl,
            uint32_t tw),
  cb_peer(struct cb*, uint32_t n),     // look n lines back into the history, 0 the live grid
  cb_clear(struct cb*),
  cb_putc(struct cb*, char),
  cb_stamp(struct cb*, uint8_t),
  cb_fill(struct cb*, uint32_t cp),
  cb_attr(struct cb*, uint32_t fg, uint32_t bg),
  cb_recolor(struct cb*, uint32_t fg, uint32_t bg),
  cb_cur(struct cb*, uint32_t row, uint32_t col);
int cb_reply(struct cb*, uint8_t*);  // drain the reply queue; buf holds cb_outn
int cb_full(struct cb const*);       // a drained queue without room for one more reply
uintptr_t cb_laid(struct cb const*); // the bytes the screen spans, its last cluster slot's end
// a pointer event -> the report the program asked for, its length or 0. b: 0 1 2, 64 65 wheel,
// 3 none held, + 4 shift 8 meta 16 ctrl; how 0 press, 1 release, 2 move
uint32_t cb_mouse(struct cb const*, uint8_t *buf, uint32_t b, uint32_t row, uint32_t col, uint32_t how);
// n bytes of paste as sent (buf 0 counts): newlines as returns, no controls but tab, bracketed
// when the program asked
uintptr_t cb_pasted(struct cb const*, uint8_t *buf, uint8_t const *s, uintptr_t n);
// ..streamed: byte b after prev as sent, or -1 for none
int cb_paste1(uint8_t prev, uint8_t b);
#define cb_popen "\033[200~"
#define cb_pshut "\033[201~"
// cell i: the grid's, or the history's at a negative i (-cols the newest line's first); 0 past
struct cb_cell const *cb_at(struct cb const*, intptr_t i);
// select cells a..b by cell (0), word (1) or line (2); another unit clears, as does a write
// to a selected row or the history leaving
void cb_select(struct cb*, intptr_t a, intptr_t b, uint32_t unit);
// cells [a, b) as utf-8 (buf 0 counts): trailing blanks gone, a newline where a row did not wrap
uintptr_t cb_copied(struct cb const*, uint8_t *buf, intptr_t a, intptr_t b);
struct cb_img const *cb_img(struct cb const*, uint32_t slot);   // a live picture, or 0
uint32_t const *cb_ipx(struct cb const*);                       // the store's pixels
uint32_t cb_iw(struct cb_img const*), cb_ih(struct cb_img const*);   // the size its tiles span
// picture im's pixel at X,Y of what its tiles span, nearest; 0 past it
uint32_t cb_ipick(struct cb const*, struct cb_img const *im, uint32_t X, uint32_t Y);
// a PNG of n bytes at the head of a cap-byte region -> 0 and w x h pixels there, or -1
int cb_png(uint8_t *buf, uintptr_t n, uintptr_t cap, uint32_t *w, uint32_t *h);
uint32_t const *cb_clu(struct cb const*, uint32_t g);   // the cluster g names, or 0
uint32_t cb_base(struct cb const*, uint32_t g);          // g's codepoint, a cluster's base
// grid row r as a reader sees it: a history line while the view looks back, else the grid's
struct cb_cell const *cb_seen(struct cb const*, uint32_t r);
// history line k, 0 the oldest, or 0 past what is held
struct cb_cell const *cb_hline(struct cb const*, uint32_t k);
uint32_t cb_unfold(uint8_t);       // a cp437 glyph byte's codepoint
uint8_t cb_437(uint32_t cp);       // the cp437 glyph that draws cp: 0xfe, the ■, for none
uint8_t cb_width(uint32_t cp);     // the columns cp takes: 0 1 or 2, 'text's wcwidth
int cb_437x(uint32_t cp);          // cb_437, but -1 where the page has no glyph

// a loaded font as font.l lays it: "qf1\0", w h (8 16), npages, nglyphs, a u16 page per 256
// code points, the pages (glyph + 1, 0 none), 16 u16le rows a glyph, leftmost pixel high.
// cb_font_ok vets every index once, so cb_font_rows trusts them
enum { cb_qf_dir = 4352, cb_qf_head = 12 };
int cb_font_ok(uint8_t const *b, uintptr_t n);
uint8_t const *cb_font_rows(uint8_t const *b, uint32_t cp);   // 32 bytes, or 0

struct font { uint8_t const *glyphs, w, h; };
extern uint8_t const cga_8x8[256][8], cleat_8x16[256][16];

// a 32bpp target (paint.c), pitch w h in pixels; a screen paints at an origin inside it.
// scale: target pixels per glyph pixel, the screen's not the font's; 0 paints nothing
struct cb_paper { volatile uint32_t *px; uintptr_t pitch, w, h, scale; };
// qf: a font cb_font_ok passed, or 0 -- the chain is the built-in font, then qf, then the ■
void cb_paint(struct cb_paper const*, struct cb const*, struct font const*,
              uint8_t const *qf, uint16_t row, uintptr_t x0, uintptr_t y0, uint32_t cur);
#endif
