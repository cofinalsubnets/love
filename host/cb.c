// host/cb.c -- quay's console-screen nifs: the terminal emulator's engine.
// port/quay's struct cb (the VT parser + cell grid, the same C the kernel
// console runs) hosted INSIDE a cask, so the ai side owns allocation and
// lifetime (the GC moves and reclaims the screen like any value) and the C
// side stays a pure byte machine re-derived from the cask on every call.
// Self-contained host nif file: auto-globbed + AI_NIF-registered, no
// ai.c / main.c edit; quay.c rides along by unity include (it is not
// otherwise linked into the host binary -- only the kernel ports carry it).
//
//   (screen b rows cols) -> b    open a cb over cask b (cb_open)
//                         | n    b not a cask: the byte count a (cask n) needs,
//                                so the ctor is (screen (cask (screen () r c)) r c)
//                         | ()   misuse: cask too small, or silly geometry
//   (scribe scr x)       -> scr  feed x through the VT parser: a byte charm,
//                                or every byte of a string/cask; () misuse
//   (glass scr i)        -> cell the packed 32-bit cell at index i, or ()
//                                (cb_ch/fg/bg/font/face live in the packing)
//   (gaze scr k)         -> n    a field by key: 0 cursor, 1 rows, 2 cols,
//                                3 flag, 4 top, 5 bot; () misuse
//   (reply scr)          -> (b ..) drain the reply queue (DSR/DA answers ride
//                                home to the pty master) as byte charms; () quiet
#include "ai.h"
#include <unistd.h>   // write (gush), read (swig)
#include <fcntl.h>    // O_NONBLOCK (swig)
#include <errno.h>
#include "../port/quay/quay.c"
#include "../port/quay/moderndos_8x16.c"   // the blit's glyphs (host links no font objects)

// Re-derive the struct cb from a cask arg, or 0 if it isn't one / doesn't
// hold a sane screen. The cask is OPEN DATA -- the ai side can pin any byte
// of it -- so every entry clamps the header fields the C loops trust: a
// scribbled screen may paint garbage, never read or write out of bounds.
static struct cb *scr_ok(ai_word x) {
  if (x & 1 || ((union u*) x)->ap != lvm_buf) return 0;
  struct ai_str *s = ((struct ai_buf*) x)->str;
  if (s->len < sizeof(struct cb)) return 0;
  struct cb *c = (struct cb*) s->bytes;
  uintptr_t n = (uintptr_t) c->rows * c->cols;
  if (!c->rows || !c->cols || sizeof(struct cb) + n * 4 > s->len) return 0;
  if (c->wpos >= n) c->wpos = 0;
  if (c->rpos >= n) c->rpos = 0;
  if (c->spos >= n) c->spos = 0;
  if (c->bot >= c->rows) c->bot = (uint16_t) (c->rows - 1u);
  if (c->top > c->bot) c->top = 0;
  if (c->esc > 8) c->esc = 0;
  if (c->pn > 8) c->pn = 8;
  if (c->on > cb_outn) c->on = 0;
  if (c->un > 3) c->un = 0;
  if (c->ol > 6) c->ol = 6;
  return c; }

// (screen b rows cols): open a screen over cask b. A non-cask b answers the
// byte count the cask needs -- the size protocol that keeps sizeof(struct cb)
// out of the surface. Geometry is capped well under the u32 cell indices.
static lvm(lvm_screen) {
  ai_word b = Sp[0];
  intptr_t r = (Sp[1] & 1) ? getcharm(Sp[1]) : 0,
           k = (Sp[2] & 1) ? getcharm(Sp[2]) : 0;
  ai_word out = ZeroPoint;
  if (r >= 1 && k >= 1 && r <= 65535 && k <= 65535
      && (uintptr_t) r * (uintptr_t) k <= (uintptr_t) 1 << 22) {
    uintptr_t need = sizeof(struct cb) + (uintptr_t) r * (uintptr_t) k * 4;
    if ((b & 1) || ((union u*) b)->ap != lvm_buf) out = putcharm(need);
    else {
      struct ai_str *s = ((struct ai_buf*) b)->str;
      if (s->len >= need) {
        cb_open((struct cb*) s->bytes, (uint16_t) r, (uint16_t) k);
        out = b; } } }
  Sp[2] = out;
  Sp += 2; Ip += 1; return Continue(); }

// (scribe scr x): the feed. A charm is one byte; a string or cask pours every
// byte through cb_putc (the hot path: one nif call per pty read). Returns the
// screen back so feeds chain. No allocation, so the pointer holds throughout.
static lvm(lvm_scribe) {
  struct cb *c = scr_ok(Sp[0]);
  ai_word x = Sp[1], out = ZeroPoint;
  if (c) {
    out = Sp[0];
    if (x & 1) cb_putc(c, (char) (getcharm(x) & 0xff));
    else if (ai_strp(x)) {
      struct ai_str *s = (struct ai_str*) x;
      for (uintptr_t i = 0; i < s->len; i++) cb_putc(c, s->bytes[i]); }
    else if (((union u*) x)->ap == lvm_buf) {
      struct ai_str *s = ((struct ai_buf*) x)->str;
      for (uintptr_t i = 0; i < s->len; i++) cb_putc(c, s->bytes[i]); }
    else out = ZeroPoint; }
  Sp[1] = out;
  Sp += 1; Ip += 1; return Continue(); }

// (glass scr i): look through to one packed cell.
static lvm(lvm_glass) {
  struct cb *c = scr_ok(Sp[0]);
  ai_word out = ZeroPoint;
  if (c && (Sp[1] & 1)) {
    uintptr_t i = (uintptr_t) getcharm(Sp[1]);
    if (i < (uintptr_t) c->rows * c->cols) out = putcharm(c->cb[i]); }
  Sp[1] = out;
  Sp += 1; Ip += 1; return Continue(); }

// (gaze scr k): one header field by key -- no allocation, so a render loop
// polls the cursor for free. 0 cursor, 1 rows, 2 cols, 3 flag, 4 top, 5 bot.
static lvm(lvm_gaze) {
  struct cb *c = scr_ok(Sp[0]);
  ai_word out = ZeroPoint;
  if (c && (Sp[1] & 1)) switch (getcharm(Sp[1])) {
   case 0: out = putcharm(c->wpos); break;
   case 1: out = putcharm(c->rows); break;
   case 2: out = putcharm(c->cols); break;
   case 3: out = putcharm(c->flag); break;
   case 4: out = putcharm(c->top);  break;
   case 5: out = putcharm(c->bot);  break;
   default: break; }
  Sp[1] = out;
  Sp += 1; Ip += 1; return Continue(); }

// the xterm-256 palette, laid once: 16 classics + the 6x6x6 cube + greys.
// same recipe as the kernel's fbdraw palette -- a cell means the same
// pixels on the framebuffer and in a window.
static uint32_t xpal[256];
static void xpal_ini(void) {
  static const uint32_t base[16] = {
    0x000000, 0x800000, 0x008000, 0x808000,
    0x000080, 0x800080, 0x008080, 0xc0c0c0,
    0x808080, 0xff0000, 0x00ff00, 0xffff00,
    0x0000ff, 0xff00ff, 0x00ffff, 0xffffff };
  static const uint8_t cube[6] = { 0, 95, 135, 175, 215, 255 };
  for (int i = 0; i < 16; i++) xpal[i] = base[i];
  for (int i = 0; i < 216; i++) {
    int r = i / 36, g_ = i / 6 % 6, b_ = i % 6;
    xpal[16 + i] = (uint32_t) cube[r] << 16 | (uint32_t) cube[g_] << 8 | cube[b_]; }
  for (int i = 0; i < 24; i++) {
    uint32_t v = 8 + 10u * i;
    xpal[232 + i] = v << 16 | v << 8 | v; } }

// the pixel core: one 8x16 cell into a 32bpp little-endian framebuffer,
// glyphs from moderndos, faces rendered like the kernel's fbdraw (bright
// bold, swapped reverse, underline on the last scanline). caller bounds.
static void cb_px1(uint8_t *base, intptr_t w, uint32_t cell, intptr_t x, intptr_t y) {
  uint8_t g_ = cb_ch(cell), face = cb_face(cell), fgx = cb_fg(cell);
  if (face & cb_bold && fgx < 8) fgx = (uint8_t) (fgx + 8);
  uint32_t fg = xpal[fgx], bg = xpal[cb_bg(cell)];
  if (face & cb_rev) { uint32_t t_ = fg; fg = bg, bg = t_; }
  uint8_t const *bmp = moderndos_8x16[g_];
  for (int r = 0; r < 16; r++) {
    int ul = face & cb_under && r == 15;
    uint8_t *row = base + ((uintptr_t) (y + r) * (uintptr_t) w + (uintptr_t) x) * 4;
    for (uint8_t o = bmp[r], k = 8; k--; o >>= 1) {
      uint32_t px = ul || o & 1 ? fg : bg;
      row[k * 4] = (uint8_t) px;
      row[k * 4 + 1] = (uint8_t) (px >> 8);
      row[k * 4 + 2] = (uint8_t) (px >> 16);
      row[k * 4 + 3] = 0; } } }

// (blit fb wpx cell x y): one cell, bounds-checked; misuse is nothing.
static lvm(lvm_blit) {
  ai_word fb = Sp[0], out = ZeroPoint;
  intptr_t w = (Sp[1] & 1) ? getcharm(Sp[1]) : -1,
           cl = (Sp[2] & 1) ? getcharm(Sp[2]) : -1,
           x = (Sp[3] & 1) ? getcharm(Sp[3]) : -1,
           y = (Sp[4] & 1) ? getcharm(Sp[4]) : -1;
  if (!(fb & 1) && ((union u*) fb)->ap == lvm_buf
      && w > 0 && cl >= 0 && x >= 0 && y >= 0 && x + 8 <= w) {
    struct ai_str *s = ((struct ai_buf*) fb)->str;
    if ((uintptr_t) (y + 16) * (uintptr_t) w * 4 <= s->len) {
      if (!xpal[255]) xpal_ini();
      cb_px1((uint8_t*) s->bytes, w, (uint32_t) cl, x, y);
      out = fb; } }
  Sp[4] = out;
  Sp += 4; Ip += 1; return Continue(); }

// (blitrow fb wpx scr row curpos): a whole grid row in one call -- the
// painter's hot lane (a keystroke repaints one row, a scroll a bandful,
// and the loop stays in C either way). curpos names the cursor's cell,
// worn in reverse; a non-charm curpos means no cursor on this row.
static lvm(lvm_blitrow) {
  ai_word fb = Sp[0], out = ZeroPoint;
  intptr_t w = (Sp[1] & 1) ? getcharm(Sp[1]) : -1,
           row = (Sp[3] & 1) ? getcharm(Sp[3]) : -1,
           cur = (Sp[4] & 1) ? getcharm(Sp[4]) : -1;
  struct cb *c = scr_ok(Sp[2]);
  if (c && !(fb & 1) && ((union u*) fb)->ap == lvm_buf
      && w > 0 && row >= 0 && row < (intptr_t) c->rows) {
    struct ai_str *s = ((struct ai_buf*) fb)->str;
    intptr_t cols = c->cols;
    if (cols * 8 > w) cols = w / 8;
    if ((uintptr_t) (row * 16 + 16) * (uintptr_t) w * 4 <= s->len) {
      if (!xpal[255]) xpal_ini();
      for (intptr_t q = 0; q < cols; q++) {
        uint32_t cell = c->cb[(uintptr_t) row * c->cols + (uintptr_t) q];
        if ((intptr_t) ((uintptr_t) row * c->cols + (uintptr_t) q) == cur)
          cell ^= (uint32_t) cb_rev << 28;
        cb_px1((uint8_t*) s->bytes, w, cell, q * 8, row * 16); }
      out = fb; } }
  Sp[4] = out;
  Sp += 4; Ip += 1; return Continue(); }

// (damage scr k): dirty-row bits for rows 32k..32k+31, read-and-cleared --
// the renderer's shopping list. bit 255 stands for row 255 and past.
static lvm(lvm_damage) {
  struct cb *c = scr_ok(Sp[0]);
  ai_word out = ZeroPoint;
  if (c && (Sp[1] & 1)) {
    intptr_t k = getcharm(Sp[1]);
    if (k >= 0 && k < 8) {
      out = putcharm(c->dmg[k]);
      c->dmg[k] = 0; } }
  Sp[1] = out;
  Sp += 1; Ip += 1; return Continue(); }

// (gush port bytes): the bulk lane `say` never had -- write(2) a whole
// string/cask straight at an fd port. say's zputc loop costs a SECOND per
// megabyte; a frame must not. the CALLER flushes the port first (gush goes
// past the buffer). () ok | errno charm | -1 for a portless port (a jug) --
// the caller falls back to say, so memory ports keep working.
static lvm(lvm_gush) {
  ai_word p = Sp[0], x = Sp[1], out = putcharm(-1);
  if (!(p & 1) && ((union u*) p)->ap == lvm_port_io
      && (ai_strp(x) || (!(x & 1) && ((union u*) x)->ap == lvm_buf))) {
    intptr_t fd = getcharm(((struct ai_io*) p)->fd);
    struct ai_str *s = ai_strp(x) ? (struct ai_str*) x : ((struct ai_buf*) x)->str;
    if (fd >= 0) {
      uintptr_t i = 0;
      out = ZeroPoint;
      while (i < s->len) {
        ssize_t k = write((int) fd, s->bytes + i, s->len - i);
        if (k < 0) {
          if (errno == EINTR) continue;
          out = putcharm(errno);
          break; }
        i += (uintptr_t) k; } } }
  Sp[1] = out;
  Sp += 1; Ip += 1; return Continue(); }

// (swig port b): gush's read twin -- drink whatever the fd has waiting into
// cask b, WITHOUT blocking (the caller parks on `get` for the first byte;
// swig drains the rest of the gulp). n bytes read; 0 = nothing waiting or
// eof (the next get tells those apart); a negative charm = -errno / misuse.
static lvm(lvm_swig) {
  ai_word p = Sp[0], x = Sp[1];
  ai_word out = putcharm(-1);
  if (!(p & 1) && ((union u*) p)->ap == lvm_port_io
      && !(x & 1) && ((union u*) x)->ap == lvm_buf) {
    intptr_t fd = getcharm(((struct ai_io*) p)->fd);
    struct ai_str *s = ((struct ai_buf*) x)->str;
    if (fd >= 0 && s->len) {
      int fl = fcntl((int) fd, F_GETFL);
      fcntl((int) fd, F_SETFL, fl | O_NONBLOCK);
      ssize_t k = read((int) fd, s->bytes, s->len);
      fcntl((int) fd, F_SETFL, fl);
      out = k > 0 ? putcharm(k)
          : k == 0 ? putcharm(0)
          : (errno == EAGAIN || errno == EWOULDBLOCK) ? putcharm(0)
          : putcharm(-errno); } }
  Sp[1] = out;
  Sp += 1; Ip += 1; return Continue(); }

// (unfold g): a cp437 glyph byte's unicode codepoint, 0 when it has none --
// the outward half of the utf-8 fold, for a painter re-emitting the grid
// to a utf-8 terminal (berth caches these per glyph).
static lvm(lvm_unfold) {
  intptr_t g_ = (Sp[0] & 1) ? getcharm(Sp[0]) : -1;
  Sp[0] = (g_ >= 0 && g_ < 256) ? putcharm(cb_unfold((uint8_t) g_)) : ZeroPoint;
  Ip += 1; return Continue(); }

// Workhorse for (reply scr), called with g Packed and the screen at sp[0].
// Drains the queue into a stack buffer FIRST (ai_have may move the cask),
// then builds the byte list tail-first. Returns a not-ok g only on OOM.
ai_noinline static struct ai *host_reply(struct ai *g) {
  struct cb *c = scr_ok(g->sp[0]);
  uint8_t buf[cb_outn];
  int n = c ? cb_reply(c, buf) : 0;
  if (!n) { g->sp[0] = ZeroPoint; return g; }
  if (!ai_ok(g = ai_have(g, (uintptr_t) n * Width(struct ai_chain)))) return g;
  ai_word tail = ZeroPoint;
  for (int i = n; i-- > 0;) {
    struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                   putcharm(buf[i]), tail);
    tail = word(w); }
  g->sp[0] = tail;
  return g; }

// (reply scr): what the terminal wants to say back (DSR position reports, DA).
// The host app forwards these bytes to the pty master; the kernel never asks.
static lvm(lvm_reply) {
  Pack(g);
  g = host_reply(g);
  if (!ai_ok(g)) return ghelp(g);
  Unpack(g);
  Ip += 1; return Continue(); }

static union u const
  nif_screen[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_screen}, {lvm_ret0}},
  nif_scribe[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_scribe}, {lvm_ret0}},
  nif_glass[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_glass},  {lvm_ret0}},
  nif_gaze[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_gaze},   {lvm_ret0}},
  nif_reply[]  = {{lvm_reply}, {lvm_ret0}},
  nif_unfold[] = {{lvm_unfold}, {lvm_ret0}},
  nif_blit[]   = {{lvm_cur}, {.x = putcharm(5)}, {lvm_blit}, {lvm_ret0}},
  nif_blitrow[] = {{lvm_cur}, {.x = putcharm(5)}, {lvm_blitrow}, {lvm_ret0}},
  nif_damage[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_damage}, {lvm_ret0}},
  nif_gush[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_gush}, {lvm_ret0}},
  nif_swig[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_swig}, {lvm_ret0}};
AI_NIF("screen", nif_screen);
AI_NIF("scribe", nif_scribe);
AI_NIF("glass", nif_glass);
AI_NIF("gaze", nif_gaze);
AI_NIF("reply", nif_reply);
AI_NIF("unfold", nif_unfold);
AI_NIF("blit", nif_blit);
AI_NIF("blitrow", nif_blitrow);
AI_NIF("damage", nif_damage);
AI_NIF("gush", nif_gush);
AI_NIF("swig", nif_swig);
