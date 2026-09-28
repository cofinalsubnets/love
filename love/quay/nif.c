// nif -- quay's love-facing door: struct cb hosted INSIDE a cask, so the love side
// owns allocation and lifetime (the GC moves and reclaims the screen like any value)
// and the C side stays a pure byte machine re-derived from the cask on every call.
//
// the BODIES only. registration is each seat's own trick -- the host's love_nifs
// section glob (love/cb.c), the kernel's defs[] table, the playdate's own -- so this
// file names no seat and links nothing but the engine beside it.
//
//   (screen b rows cols) -> b    open a cb over cask b (cb_open)
//                         | n    b not a cask: the byte count a (cask n) needs,
//                                so the ctor is (screen (cask (screen () r c)) r c);
//                                the count carries a store a screenful of pictures deep
//                                and a thousand lines of history, and a twin grid
//                                for the main one to wait out the alternate screen in
//                         | ()   misuse: cask too small, or silly geometry
//   (scribe scr x)       -> scr  feed x through the VT parser: a byte charm,
//                                or every byte of a string/cask; () misuse
//   (regrid scr b rows cols) -> b  scr laid across into cask b as a rows x cols
//                                screen (cb_regrid): text, clusters, and pictures
//                                while the store holds them; b not a cask answers
//                                the byte count, as screen's does; () misuse
//   (glass scr i k)      -> w    word k of cell i, or (): 0 the glyph (codepoint,
//                                width, picture, face), 1 the fg, 2 the bg
//                                (the layout is quay.h's struct cb_cell); a
//                                cluster's glyph holds its base, and 3 4 5 are
//                                its marks, 0 past the last. a negative i reads
//                                the history: -cols is the newest line's first
//                                cell, back to -(held * cols)
//   (gaze scr k)         -> n    a field by key: 0 cursor, 1 rows, 2 cols,
//                                3 flag, 4 top, 5 bot, 6 and 7 a cell's width and
//                                height in pixels, 8 the lines the view looks back,
//                                9 the history's lines held; () misuse
//   (peer scr n)         -> n    look n lines back into the history (0 the live
//                                grid), clamped to what is held; answers the view
//   (mouse scr b row col how) -> s  the report a pointer event makes as the program asked
//                                (cb_mouse): b the button with its modifier bits, how
//                                0 a press, 1 a release, 2 a move; "" when not asked
//   (reply scr)          -> (b ..) drain the reply queue (DSR/DA answers ride
//                                home to the pty master) as byte charms; () quiet
//   (wet scr k)          -> n    dirty-row bits, read-and-cleared
//   (tilepx scr i x y)   -> n    pixel (x,y) of cell i's tile: 0xff over its rgb where
//                                the picture set it, 0 where not; () for no tile
//   (dye scr buf w row cur face) -> scr   grid row `row` painted into cask buf, a
//                                32bpp picture w pixels wide, by the console's own
//                                painter (paint.c) in the built-in 8x16, face a
//                                loaded one (as facerow takes) or (); cur the cell
//                                the cursor wears, -1 for none; () misuse
//   (facerow f cp r)     -> n    row r of cp's glyph in face f (a string or cask as
//                                apps/face.l lays it), the leftmost pixel bit 15;
//                                () when f is no face (cb_face_ok) or lacks cp
#include "love.h"
#include "quay.h"

// Re-derive the struct cb from a cask arg, or 0 if it isn't one / doesn't
// hold a sane screen. The cask is OPEN DATA -- the love side can pin any byte
// of it -- so every entry clamps the header fields the C loops trust: a
// scribbled screen may paint garbage, never read or write out of bounds.
static struct cb *scr_ok(word x) {
 if (x & 1 || ((union u*) x)->ap != lvm_cask) return 0;
 struct ai_str *s = ((struct ai_cask*) x)->str;
 if (s->len < sizeof(struct cb)) return 0;
 struct cb *c = (struct cb*) s->bytes;
 uintptr_t n = (uintptr_t) c->rows * c->cols;
 if (!c->rows || !c->cols || cb_size(c->rows, c->cols, 0) > s->len) return 0;
 if (cb_size(c->rows, c->cols, c->sn) > s->len || (c->sn && c->sn < cb_shead)) c->sn = 0, c->sslot = 0;
 if (cb_size(c->rows, c->cols, c->sn) + cb_hsize(c->hl, c->cols) > s->len) c->hl = 0;
 if (c->twin && cb_size(c->rows, c->cols, c->sn) + cb_hsize(c->hl, c->cols) + cb_tsize(c->rows, c->cols) > s->len)
  c->twin = 0;
 if (c->hn > c->hl) c->hn = c->hl;
 if (c->hh >= c->hl) c->hh = 0;
 if (c->view > c->hn) c->view = c->hn;
 if (!c->cw || !c->ch) c->cw = 8, c->ch = 16;
 if (c->sslot >= cb_nimg) c->sslot = 0;
 if (c->wpos >= n) c->wpos = 0;
 if (c->spos >= n) c->spos = 0;
 if (c->bot >= c->rows) c->bot = (uint16_t) (c->rows - 1u);
 if (c->top > c->bot) c->top = 0;
 if (c->esc > 15) c->esc = 0;
 if (c->kslot >= cb_nimg) c->kslot = 0, c->kopen = 0;
 if (c->kf != 24 && c->kf != 32 && c->kf != 100) c->kf = 32;
 if (c->pn > 8) c->pn = 8;
 if (c->on > cb_outn) c->on = 0;
 if (c->un > 3) c->un = 0;
 if (c->ol > 6) c->ol = 6;
 return c; }

// (screen b rows cols): open a screen over cask b. A non-cask b answers the
// byte count the cask needs -- the size protocol that keeps sizeof(struct cb)
// out of the surface. Geometry is capped well under the u32 cell indices.
// the store a rows x cols screen gets, or ~0u for a geometry refused
static uint32_t scr_sn(word rw, word kw) {
 intptr_t const r = (rw & 1) ? getcharm(rw) : 0, k = (kw & 1) ? getcharm(kw) : 0;
 if (r < 1 || k < 1 || r > 65535 || k > 65535 || (uintptr_t) r * (uintptr_t) k > (uintptr_t) 1 << 22) return ~0u;
 return r * k <= 131072 ? cb_sdefault(r, k) : 0; }   // no store past 64 MB of one

// the history a screen cols wide gets: a thousand lines, fewer past 4 MB of them
static uint32_t scr_hl(uint16_t cols) {
 uint32_t const most = (uint32_t) ((4u << 20) / cb_hsize(1, cols));
 return most < 1000u ? most : 1000u; }

static lvm(lvm_screen) {
 word b = Sp[0], out = ZeroPoint;
 uint32_t const sn = scr_sn(Sp[1], Sp[2]);
 if (sn != ~0u) {
  uint16_t const r = (uint16_t) getcharm(Sp[1]), k = (uint16_t) getcharm(Sp[2]);
  uint32_t const hl = scr_hl(k);
  uintptr_t need = cb_size(r, k, sn) + cb_hsize(hl, k) + cb_tsize(r, k);
  if ((b & 1) || ((union u*) b)->ap != lvm_cask) out = putcharm(need);
  else {
   struct ai_str *s = ((struct ai_cask*) b)->str;
   if (s->len >= need) {
    cb_open((struct cb*) s->bytes, r, k, sn);
    cb_hist((struct cb*) s->bytes, hl), cb_twin((struct cb*) s->bytes, 1);
    out = b; } } }
 Sp[2] = out;
 Sp += 2; Ip += 1; ai_musttail return Continue(); }

// (regrid scr b rows cols): as screen, but the new grid starts from scr's. b must be a
// cask of its own -- the two may not overlap
static lvm(lvm_regrid) {
 struct cb *c = scr_ok(Sp[0]);
 word b = Sp[1], out = ZeroPoint;
 uint32_t const sn = scr_sn(Sp[2], Sp[3]);
 if (c && sn != ~0u) {
  uint16_t const r = (uint16_t) getcharm(Sp[2]), k = (uint16_t) getcharm(Sp[3]);
  uint32_t const hl = scr_hl(k);
  uintptr_t need = cb_size(r, k, sn) + cb_hsize(hl, k) + cb_tsize(r, k);
  if ((b & 1) || ((union u*) b)->ap != lvm_cask) out = putcharm(need);
  else {
   struct ai_str *s = ((struct ai_cask*) b)->str;
   if (s->len >= need && (uint8_t*) s->bytes != (uint8_t*) c) {
    cb_regrid((struct cb*) s->bytes, c, r, k, sn, hl, 1);
    out = b; } } }
 Sp[3] = out;
 Sp += 3; Ip += 1; ai_musttail return Continue(); }

// (scribe scr x): the feed. A charm is one byte; a string or cask pours every
// byte through cb_putc (the hot path: one nif call per pty read). Returns the
// screen back so feeds chain. No allocation, so the pointer holds throughout.
static lvm(lvm_scribe) {
 struct cb *c = scr_ok(Sp[0]);
 word x = Sp[1], out = ZeroPoint;
 if (c) {
  out = Sp[0];
  if (x & 1) cb_putc(c, (char) (getcharm(x) & 0xff));
  else if (strp(x)) {
   struct ai_str *s = str(x);
   for (uintptr_t i = 0; i < s->len; i++) cb_putc(c, s->bytes[i]); }
  else if (((union u*) x)->ap == lvm_cask) {
   struct ai_str *s = ((struct ai_cask*) x)->str;
   for (uintptr_t i = 0; i < s->len; i++) cb_putc(c, s->bytes[i]); }
  else out = ZeroPoint; }
 Sp[1] = out;
 Sp += 1; Ip += 1; ai_musttail return Continue(); }

// (glass scr i k): look through to one word of one cell.
static lvm(lvm_glass) {
 struct cb *c = scr_ok(Sp[0]);
 word out = ZeroPoint;
 if (c && (Sp[1] & 1) && (Sp[2] & 1)) {
  intptr_t const i = getcharm(Sp[1]), k = getcharm(Sp[2]), back = (intptr_t) c->hn * c->cols;
  if (i >= -back && i < (intptr_t) c->rows * c->cols && k >= 0 && k < 6) {
   struct cb_cell const e = i >= 0 ? c->cb[i] : cb_hline(c, (uint32_t) ((i + back) / c->cols))[(i + back) % c->cols];
   uint32_t const *v = cb_clu(c, e.g);
   out = putcharm(k == 0 ? (v ? (e.g & 0xffe00000u) | cb_cp(v[0]) : e.g) : k == 1 ? e.fg : k == 2 ? e.bg
                  : v ? cb_cp(v[k - 2]) : 0u); } }
 Sp[2] = out;
 Sp += 2; Ip += 1; ai_musttail return Continue(); }

// (gaze scr k): one header field by key -- no allocation, so a render loop
// polls the cursor for free. 0 cursor, 1 rows, 2 cols, 3 flag, 4 top, 5 bot.
static lvm(lvm_gaze) {
 struct cb *c = scr_ok(Sp[0]);
 word out = ZeroPoint;
 if (c && (Sp[1] & 1)) switch (getcharm(Sp[1])) {
  case 0: out = putcharm(c->wpos); break;
  case 1: out = putcharm(c->rows); break;
  case 2: out = putcharm(c->cols); break;
  case 3: out = putcharm(c->flag); break;
  case 4: out = putcharm(c->top);  break;
  case 5: out = putcharm(c->bot);  break;
  case 6: out = putcharm(c->cw);   break;
  case 7: out = putcharm(c->ch);   break;
  case 8: out = putcharm(c->view); break;
  case 9: out = putcharm(c->hn);   break;
  default: break; }
 Sp[1] = out;
 Sp += 1; Ip += 1; ai_musttail return Continue(); }

// (peer scr n): the view n lines back, clamped; answers where it landed
static lvm(lvm_peer) {
 struct cb *c = scr_ok(Sp[0]);
 word out = ZeroPoint;
 if (c && (Sp[1] & 1)) {
  intptr_t const n = getcharm(Sp[1]);
  cb_peer(c, n < 0 ? 0u : n > (intptr_t) c->hn ? c->hn : (uint32_t) n);
  out = putcharm(c->view); }
 Sp[1] = out;
 Sp += 1; Ip += 1; ai_musttail return Continue(); }

// (wet scr k): dirty-row bits for rows 32k..32k+31, read-and-cleared --
// the renderer's shopping list. bit 255 stands for row 255 and past.
static lvm(lvm_damage) {
 struct cb *c = scr_ok(Sp[0]);
 word out = ZeroPoint;
 if (c && (Sp[1] & 1)) {
  intptr_t k = getcharm(Sp[1]);
  if (k >= 0 && k < 8) {
   out = putcharm(c->dmg[k]);
   c->dmg[k] = 0; } }
 Sp[1] = out;
 Sp += 1; Ip += 1; ai_musttail return Continue(); }

// (tilepx scr i x y): one pixel of cell i's tile, as the painter reads it
static lvm(lvm_tilepx) {
 struct cb *c = scr_ok(Sp[0]);
 word out = ZeroPoint;
 if (c && (Sp[1] & 1) && (Sp[2] & 1) && (Sp[3] & 1)) {
  uintptr_t const i = (uintptr_t) getcharm(Sp[1]);
  intptr_t const x = getcharm(Sp[2]), y = getcharm(Sp[3]);
  if (i < (uintptr_t) c->rows * c->cols && x >= 0 && y >= 0 && x < c->cw && y < c->ch) {
   uint32_t const g = c->cb[i].g;
   struct cb_img const *im = g & cb_pic ? cb_img(c, cb_tslot(g)) : 0;
   if (im) {
    uint32_t const X = cb_ttx(g) * c->cw + (uint32_t) x, Y = cb_tty(g) * c->ch + (uint32_t) y;
    out = putcharm(X < im->w && Y < im->h ? cb_ipx(c)[im->off + Y * im->w + X] : 0u); } } }
 Sp[3] = out;
 Sp += 3; Ip += 1; ai_musttail return Continue(); }

// the bytes of a string or cask, or 0
static struct ai_str *nif_bytes(word x) {
 if (x & 1) return 0;
 if (strp(x)) return str(x);
 if (((union u*) x)->ap == lvm_cask) return ((struct ai_cask*) x)->str;
 return 0; }

// (dye scr buf w row cur face): one row of the screen as pixels, the same draw the
// kernel's framebuffer takes. the paper is buf, clipped to its own bytes; a face that
// fails its vetting is no face. no allocation, so every pointer holds throughout
static lvm(lvm_dye) {
 struct cb *c = scr_ok(Sp[0]);
 struct ai_str *b = !(Sp[1] & 1) && ((union u*) Sp[1])->ap == lvm_cask ? ((struct ai_cask*) Sp[1])->str : 0;
 word out = ZeroPoint;
 if (c && b && (Sp[2] & 1) && (Sp[3] & 1) && (Sp[4] & 1)) {
  intptr_t const w = getcharm(Sp[2]), row = getcharm(Sp[3]), cur = getcharm(Sp[4]);
  if (w > 0 && row >= 0 && row < c->rows) {
   struct ai_str *f = nif_bytes(Sp[5]);
   uint8_t const *qf = f && cb_face_ok((uint8_t const*) f->bytes, f->len) ? (uint8_t const*) f->bytes : 0;
   struct cb_paper const p = { (uint32_t*) b->bytes, (uintptr_t) w, (uintptr_t) w, b->len / 4u / (uintptr_t) w, 1 };
   struct font const ft = { (uint8_t const*) cleat_8x16, 8, 16 };
   cb_paint(&p, c, &ft, qf, (uint16_t) row, 0, 0, cur < 0 ? ~0u : (uint32_t) cur);
   out = Sp[0]; } }
 Sp[5] = out;
 Sp += 5; Ip += 1; ai_musttail return Continue(); }

// (facerow f cp r): the painter's own reading of a face, vetting and all
static lvm(lvm_facerow) {
 word f = Sp[0], out = ZeroPoint;
 struct ai_str *s = 0;
 if (!(f & 1) && strp(f)) s = str(f);
 else if (!(f & 1) && ((union u*) f)->ap == lvm_cask) s = ((struct ai_cask*) f)->str;
 if (s && (Sp[1] & 1) && (Sp[2] & 1) && cb_face_ok((uint8_t const*) s->bytes, s->len)) {
  intptr_t cp = getcharm(Sp[1]), r = getcharm(Sp[2]);
  uint8_t const *g = cp >= 0 && r >= 0 && r < 16
                     ? cb_face_rows((uint8_t const*) s->bytes, (uint32_t) cp) : 0;
  if (g) out = putcharm((uintptr_t) g[2 * r] | (uintptr_t) g[2 * r + 1] << 8); }
 Sp[2] = out;
 Sp += 2; Ip += 1; ai_musttail return Continue(); }

// Workhorse for (reply scr), called with g Packed and the screen at sp[0].
// Drains the queue into a stack buffer FIRST (ai_have may move the cask),
// then builds the byte list tail-first. Returns a not-ok g only on OOM.
ai_noinline static struct ai *host_reply(struct ai *g) {
 struct cb *c = scr_ok(g->sp[0]);
 uint8_t buf[cb_outn];
 int n = c ? cb_reply(c, buf) : 0;
 if (!n) { g->sp[0] = ZeroPoint; return g; }
 if (!ai_ok(g = ai_have(g, (uintptr_t) n * Width(struct ai_chain)))) return g;
 word tail = ZeroPoint;
 for (int i = n; i-- > 0;) {
  struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                   putcharm(buf[i]), tail);
  tail = word(w); }
 g->sp[0] = tail;
 return g; }

// (reply scr): what the terminal wants to say back (DSR position reports, DA).
// The app forwards these bytes to the pty master; the kernel never asks.
static lvm(lvm_reply) {
 Pack(g);
 g = host_reply(g);
 if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g);
 Unpack(g);
 Ip += 1; ai_musttail return Continue(); }

// (mouse scr b row col how): the bytes are laid before Have, which may move the cask
static lvm(lvm_mouse) {
 struct cb *c = scr_ok(Sp[0]);
 uint8_t buf[cb_mousen];
 uint32_t n = 0;
 if (c && (Sp[1] & Sp[2] & Sp[3] & Sp[4] & 1) && getcharm(Sp[1]) >= 0 && getcharm(Sp[2]) >= 0
     && getcharm(Sp[3]) >= 0 && getcharm(Sp[4]) >= 0)
  n = cb_mouse(c, buf, (uint32_t) getcharm(Sp[1]), (uint32_t) getcharm(Sp[2]),
               (uint32_t) getcharm(Sp[3]), (uint32_t) getcharm(Sp[4]));
 if (!n) Sp[4] = word(EmptyString);
 else {
  Have(str_width(n));
  struct ai_str *s = ini_str(str(Hp), n); Hp += str_width(n);
  memcpy(txt(s), buf, n);
  Sp[4] = word(s); }
 Sp += 4; Ip += 1; ai_musttail return Continue(); }

static union u const
  nif_screen[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_screen}, {lvm_ret0}},
  nif_scribe[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_scribe}, {lvm_ret0}},
  nif_glass[]  = {{lvm_cur}, {.x = putcharm(3)}, {lvm_glass},  {lvm_ret0}},
  nif_gaze[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_gaze},   {lvm_ret0}},
  nif_reply[]  = {{lvm_reply}, {lvm_ret0}},
  nif_damage[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_damage}, {lvm_ret0}},
  nif_facerow[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_facerow}, {lvm_ret0}},
  nif_tilepx[]  = {{lvm_cur}, {.x = putcharm(4)}, {lvm_tilepx},  {lvm_ret0}},
  nif_dye[]     = {{lvm_cur}, {.x = putcharm(6)}, {lvm_dye},     {lvm_ret0}},
  nif_regrid[]  = {{lvm_cur}, {.x = putcharm(4)}, {lvm_regrid},  {lvm_ret0}},
  nif_peer[]    = {{lvm_cur}, {.x = putcharm(2)}, {lvm_peer},    {lvm_ret0}},
  nif_mouse[]   = {{lvm_cur}, {.x = putcharm(5)}, {lvm_mouse},   {lvm_ret0}};
