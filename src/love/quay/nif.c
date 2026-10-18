// nif -- quay's love-facing door: a struct cb inside a cask, so love owns its lifetime and
// the C side re-derives it on every call. the bodies only: each host registers them its own way
//
//   (screen b rows cols) -> b    open a cb over cask b (cb_open)
//                         | n    b not a cask: the bytes a (cask n) needs, so the ctor
//                                is (screen (cask (screen () r c)) r c)
//                         | ()   misuse: cask too small, or silly geometry
//   (scribe scr x)       -> scr  feed a byte charm, or every byte of a string/cask
//                         | n    replies pending: only the first n went in -- reply, then
//                                scribe the rest
//   (regrid scr b rows cols) -> b  scr laid into cask b as a rows x cols screen (cb_regrid);
//                                b not a cask answers the byte count, as screen's does
//   (glass scr i k)      -> w    word k of cell i (quay.h's struct cb_cell): 0 the glyph,
//                                1 the fg, 2 the bg, 3 to 11 a cluster's rest, 0 past its
//                                last. a negative i reads history: -cols the newest line
//   (gaze scr k)         -> n    0 cursor, 1 rows, 2 cols, 3 flag, 4 top, 5 bot, 6 7 a
//                                cell's pixel w h, 8 the view's lookback, 9 history held,
//                                10 11 the selection's first cell and one past its last
//   (peer scr n)         -> n    view n lines back (0 live), clamped; answers the view
//   (mouse scr b row col how) -> s  the report the program asked for (cb_mouse): how 0
//                                press, 1 release, 2 move; "" when not asked
//   (select scr a b u)   -> scr  select cells a..b by cell (u 0), word (1) or line (2);
//                                another u clears
//   (copied scr a b)     -> s    cells [a, b) as text (cb_copied)
//   (pasted scr s)       -> s    s as a paste into this screen (cb_pasted), bracketed
//                                when asked (?2004)
//   (picture scr slot k) -> n|s  a live picture's width (k 0), height (1), gen (2), pixels
//                                as base64 rgba (3) or raw (4), tile span w (5) h (6)
//   (reply scr)          -> (b ..) drain the reply queue (DSR/DA) as byte charms
//   (wet scr k)          -> n    dirty-row bits, read-and-cleared
//   (tilepx scr i x y)   -> n    pixel (x,y) of cell i's tile: 0xff over its rgb, 0 unset
//   (dye scr buf w row cur font) -> scr   row painted into cask buf, 32bpp w pixels wide,
//                                by paint.c; font () for the built-in 8x16; cur -1 for none
//   (limned scr k n f fg bg) -> (s took f fg bg)   cells k..k+n-1 as an outer terminal's
//                                escapes (mitty/limn.l's row), the pen threaded in and out,
//                                stopping at a picture's tile
//   (fontrow f cp r)     -> n    row r of cp's glyph in font f (as font.l lays it), the
//                                leftmost pixel bit 15; () for no font or no cp
//   misuse answers () throughout
#include "love.h"
#include "quay.h"

// the struct cb in a cask, or 0. love can pin any byte of it, so every field the C loops
// trust is clamped: a scribbled screen may paint garbage, never go out of bounds
static struct cb *scr_ok(word x) {
 struct str *s = cask_str(x);
 if (!s || s->len < sizeof(struct cb)) return 0;
 struct cb *c = (struct cb*) s->bytes;
 uintptr_t n = (uintptr_t) c->rows * c->cols;
 if (!c->rows || !c->cols || cb_size(c->rows, c->cols, 0) > s->len) return 0;
 if (cb_size(c->rows, c->cols, c->sn) > s->len || (c->sn && c->sn < cb_shead)) c->sn = 0, c->sslot = 0;
 if (cb_size(c->rows, c->cols, c->sn) + cb_hsize(c->hl, c->cols) > s->len) c->hl = 0;
 if (c->twin && cb_size(c->rows, c->cols, c->sn) + cb_hsize(c->hl, c->cols) + cb_tsize(c->rows, c->cols) > s->len)
  c->twin = 0;
 if (c->cx > cb_clumax - cb_nclu || cb_laid(c) > s->len) c->cx = 0;
 if (c->hn > c->hl) c->hn = c->hl;
 if (c->hh >= c->hl) c->hh = 0;
 if (c->view > c->hn) c->view = c->hn;
 if (c->sel0 >= c->sel1 || c->sel0 < -(int32_t) (c->hn * c->cols) || c->sel1 > (int32_t) n) c->sel0 = c->sel1 = 0;
 if (!c->cw || !c->ch) c->cw = 8, c->ch = 16;
 if (c->sslot >= cb_nimg) c->sslot = 0;
 if (c->wpos >= n) c->wpos = 0;
 if (c->spos >= n) c->spos = 0;
 if (c->bot >= c->rows) c->bot = (uint16_t) (c->rows - 1u);
 if (c->top > c->bot) c->top = 0;
 if (c->esc > 15) c->esc = 0;
 if (c->kslot >= cb_nimg) c->kslot = 0, c->kopen = 0;
 if (c->kf != 24 && c->kf != 32 && c->kf != 100) c->kf = 32;
 if (c->pn > cb_pmax) c->pn = cb_pmax;
 if (c->ps > 5) c->ps = 0;
 if (c->on > cb_outn) c->on = 0;
 if (c->un > 3) c->un = 0;
 if (c->ol > 6) c->ol = 6;
 return c; }

// the store a rows x cols screen gets, or ~0u for a geometry refused; capped well under
// the u32 cell indices
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
  if (!caskp(b)) out = putcharm(need);
  else {
   struct str *s = ((struct cask*) b)->str;
   if (s->len >= need) {
    cb_open((struct cb*) s->bytes, r, k, sn);
    cb_hist((struct cb*) s->bytes, hl), cb_twin((struct cb*) s->bytes, 1);
    out = b; } } }
 Sp[2] = out;
 Sp += 2; Ip += 1; love_musttail return Continue(); }

// (regrid scr b rows cols): as screen, but the new grid starts from scr's. b must be a
// cask of its own -- the two may not overlap
static lvm(lvm_regrid) {
 struct cb *c = scr_ok(Sp[0]);
 word b = Sp[1], out = ZeroPoint;
 uint32_t const sn = scr_sn(Sp[2], Sp[3]);
 if (c && sn != ~0u) {
  uint16_t const r = (uint16_t) getcharm(Sp[2]), k = (uint16_t) getcharm(Sp[3]);
  uint32_t const hl = scr_hl(k);
  uintptr_t need = cb_size(r, k, sn) + cb_hsize(hl, k) + cb_tsize(r, k) + cb_xsize(c->cx);
  if (!caskp(b)) out = putcharm(need);
  else {
   struct str *s = ((struct cask*) b)->str;
   if (s->len >= need && (uint8_t*) s->bytes != (uint8_t*) c) {
    cb_regrid((struct cb*) s->bytes, c, r, k, sn, hl, 1);
    out = b; } } }
 Sp[3] = out;
 Sp += 3; Ip += 1; love_musttail return Continue(); }

// grow the cluster pool of the screen at sp[0], doubling, into a new cask when its own is
// short. g packed; a pool at cb_clumax stays
love_noinline static struct g *scr_grow(struct g *g) {
 struct cb *c = scr_ok(g->sp[0]);
 uint32_t const most = cb_clumax - cb_nclu, add = c->cx ? c->cx : cb_nclu,
                cx = add < most - c->cx ? c->cx + add : most;
 uintptr_t const n = cb_laid(c) + cb_xsize(cx - c->cx), len = cask(g->sp[0])->str->len;
 if (n > len) {
  if (!ok(g = have(g, str_width(n)))) return g;
  struct str *o = cask(g->sp[0])->str, *s = ini_str(str(g->hp), n);
  g->hp += str_width(n);
  memcpy(s->bytes, o->bytes, len);
  cask(g->sp[0])->str = s;
  gen_wb(g, g->sp[0], word(s)); }
 cb_xclu(scr_ok(g->sp[0]), cx);
 return g; }

// the feed, g packed with [scr x] at sp. answers at sp[1] as scribe does
love_noinline static struct g *scr_pour(struct g *g) {
 struct cb *c = scr_ok(g->sp[0]);
 word x = g->sp[1];
 struct str *s = !c || (x & 1) ? 0 : strp(x) ? str(x) : ((union u*) x)->ap == lvm_cask ? cask(x)->str : 0;
 uintptr_t const n = (x & 1) ? 1 : s ? s->len : 0;
 if (!c || (!(x & 1) && !s)) return g->sp[1] = ZeroPoint, g;
 uintptr_t i = 0;
 for (; i < n && !cb_full(c); i++) {
  cb_putc(c, (char) ((x & 1) ? getcharm(x) & 0xff : s->bytes[i]));
  if (c->cfull && c->cx < cb_clumax - cb_nclu) {
   if (!ok(g = scr_grow(g))) return g;
   c = scr_ok(g->sp[0]), x = g->sp[1];
   if (!(x & 1)) s = strp(x) ? str(x) : cask(x)->str; } }
 g->sp[1] = i == n ? g->sp[0] : putcharm(i);
 return g; }

// (scribe scr x): the hot path, one call per pty read
static lvm(lvm_scribe) {
 Pack(g);
 g = scr_pour(g);
 if (!ok(g)) love_musttail return Ap(_lvm_ghelp, g);
 Unpack(g);
 Sp += 1; Ip += 1; love_musttail return Continue(); }

static lvm(lvm_glass) {
 struct cb *c = scr_ok(Sp[0]);
 word out = ZeroPoint;
 if (c && (Sp[1] & 1) && (Sp[2] & 1)) {
  intptr_t const k = getcharm(Sp[2]);
  struct cb_cell const *e = cb_at(c, getcharm(Sp[1]));
  if (e && k >= 0 && k < cb_clun + 2) {
   uint32_t const *v = cb_clu(c, e->g);
   out = putcharm(k == 0 ? (v ? (e->g & 0xffe00000u) | cb_cp(v[0]) : e->g) : k == 1 ? e->fg & ~cb_soft : k == 2 ? e->bg
                  : v ? cb_cp(v[k - 2]) : 0u); } }
 Sp[2] = out;
 Sp += 2; Ip += 1; love_musttail return Continue(); }

// (gaze scr k): no allocation, so a render loop polls for free
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
  case 10: out = putcharm(c->sel0); break;
  case 11: out = putcharm(c->sel1); break;
  default: break; }
 Sp[1] = out;
 Sp += 1; Ip += 1; love_musttail return Continue(); }

static lvm(lvm_peer) {
 struct cb *c = scr_ok(Sp[0]);
 word out = ZeroPoint;
 if (c && (Sp[1] & 1)) {
  intptr_t const n = getcharm(Sp[1]);
  cb_peer(c, n < 0 ? 0u : n > (intptr_t) c->hn ? c->hn : (uint32_t) n);
  out = putcharm(c->view); }
 Sp[1] = out;
 Sp += 1; Ip += 1; love_musttail return Continue(); }

// (wet scr k): rows 32k..32k+31; bit 255 stands for row 255 and past
static lvm(lvm_damage) {
 struct cb *c = scr_ok(Sp[0]);
 word out = ZeroPoint;
 if (c && (Sp[1] & 1)) {
  intptr_t k = getcharm(Sp[1]);
  if (k >= 0 && k < 8) {
   out = putcharm(c->dmg[k]);
   c->dmg[k] = 0; } }
 Sp[1] = out;
 Sp += 1; Ip += 1; love_musttail return Continue(); }

static lvm(lvm_tilepx) {
 struct cb *c = scr_ok(Sp[0]);
 word out = ZeroPoint;
 if (c && (Sp[1] & 1) && (Sp[2] & 1) && (Sp[3] & 1)) {
  struct cb_cell const *e = cb_at(c, getcharm(Sp[1]));
  intptr_t const x = getcharm(Sp[2]), y = getcharm(Sp[3]);
  if (e && x >= 0 && y >= 0 && x < c->cw && y < c->ch) {
   uint32_t const g = e->g;
   struct cb_img const *im = g & cb_pic ? cb_img(c, cb_tslot(g)) : 0;
   if (im) {
    uint32_t const X = cb_ttx(g) * c->cw + (uint32_t) x, Y = cb_tty(g) * c->ch + (uint32_t) y;
    out = putcharm(cb_ipick(c, im, X, Y)); } } }
 Sp[3] = out;
 Sp += 3; Ip += 1; love_musttail return Continue(); }

// the bytes of a string or cask, or 0
static struct str *nif_bytes(word x) {
 if (x & 1) return 0;
 if (strp(x)) return str(x);
 if (((union u*) x)->ap == lvm_cask) return ((struct cask*) x)->str;
 return 0; }

// (dye ..): the kernel framebuffer's draw, clipped to buf; a font failing its vetting is
// none. no allocation, so every pointer holds
static lvm(lvm_dye) {
 struct cb *c = scr_ok(Sp[0]);
 struct str *b = cask_str(Sp[1]);
 word out = ZeroPoint;
 if (c && b && (Sp[2] & 1) && (Sp[3] & 1) && (Sp[4] & 1)) {
  intptr_t const w = getcharm(Sp[2]), row = getcharm(Sp[3]), cur = getcharm(Sp[4]);
  if (w > 0 && row >= 0 && row < c->rows) {
   struct str *f = nif_bytes(Sp[5]);
   uint8_t const *qf = f && cb_font_ok((uint8_t const*) f->bytes, f->len) ? (uint8_t const*) f->bytes : 0;
   struct cb_paper const p = { (uint32_t*) b->bytes, (uintptr_t) w, (uintptr_t) w, b->len / 4u / (uintptr_t) w, 1 };
   struct font const ft = { (uint8_t const*) cleat_8x16, 8, 16 };
   cb_paint(&p, c, &ft, qf, (uint16_t) row, 0, 0, cur < 0 ? ~0u : (uint32_t) cur);
   out = Sp[0]; } }
 Sp[5] = out;
 Sp += 5; Ip += 1; love_musttail return Continue(); }

static lvm(lvm_fontrow) {
 word f = Sp[0], out = ZeroPoint;
 struct str *s = 0;
 if (!(f & 1) && strp(f)) s = str(f);
 else if (caskp(f)) s = cask(f)->str;
 if (s && (Sp[1] & 1) && (Sp[2] & 1) && cb_font_ok((uint8_t const*) s->bytes, s->len)) {
  intptr_t cp = getcharm(Sp[1]), r = getcharm(Sp[2]);
  uint8_t const *g = cp >= 0 && r >= 0 && r < 16
                     ? cb_font_rows((uint8_t const*) s->bytes, (uint32_t) cp) : 0;
  if (g) out = putcharm((uintptr_t) g[2 * r] | (uintptr_t) g[2 * r + 1] << 8); }
 Sp[2] = out;
 Sp += 2; Ip += 1; love_musttail return Continue(); }

// (reply scr)'s body, g packed: the queue drains to a stack buffer before have moves the cask
love_noinline static struct g *host_reply(struct g *g) {
 struct cb *c = scr_ok(g->sp[0]);
 uint8_t buf[cb_outn];
 int n = c ? cb_reply(c, buf) : 0;
 if (!n) { g->sp[0] = ZeroPoint; return g; }
 if (!ok(g = have(g, (uintptr_t) n * Width(struct chain)))) return g;
 word tail = ZeroPoint;
 for (int i = n; i-- > 0;) {
  struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                   putcharm(buf[i]), tail);
  tail = word(w); }
 g->sp[0] = tail;
 return g; }

// the app forwards these to the pty master
static lvm(lvm_reply) {
 Pack(g);
 g = host_reply(g);
 if (!ok(g)) love_musttail return Ap(_lvm_ghelp, g);
 Unpack(g);
 Ip += 1; love_musttail return Continue(); }

// (mouse ..): the bytes are laid before Have, which may move the cask
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
  struct str *s = ini_str(str(Hp), n); Hp += str_width(n);
  memcpy(txt(s), buf, n);
  Sp[4] = word(s); }
 Sp += 4; Ip += 1; love_musttail return Continue(); }

// (picture ..): pixels laid straight from the store, counted first for Have
static lvm(lvm_picture) {
 struct cb *c = scr_ok(Sp[0]);
 struct cb_img const *im = c && (Sp[1] & Sp[2] & 1) && getcharm(Sp[1]) > 0 && getcharm(Sp[1]) < cb_nimg
                           ? cb_img(c, (uint32_t) getcharm(Sp[1])) : 0;
 intptr_t const k = (Sp[2] & 1) ? getcharm(Sp[2]) : -1;
 word out = ZeroPoint;
 if (im && k >= 0 && k < 3) out = putcharm(k == 0 ? im->w : k == 1 ? im->h : im->gen);
 else if (im && (k == 5 || k == 6)) out = putcharm(k == 5 ? cb_iw(im) : cb_ih(im));
 else if (im && k == 3 && (uint64_t) im->off + (uint64_t) im->w * im->h <= (c->sn - cb_shead) / 4u) {
  static char const abc[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  uintptr_t const nb = (uintptr_t) im->w * im->h * 4u, n = (nb + 2) / 3 * 4;
  Have(str_width(n));
  struct str *s = ini_str(str(Hp), n); Hp += str_width(n);
  uint32_t const *px = cb_ipx(c) + im->off;
  uint8_t *o = (uint8_t*) txt(s);
  uint32_t acc = 0, got = 0;
  for (uintptr_t i = 0; i < nb; i++) {
   uint32_t const v = px[i / 4], j = i % 4;
   acc = acc << 8 | (j == 0 ? v >> 16 & 255u : j == 1 ? v >> 8 & 255u : j == 2 ? v & 255u : v >> 24 ? 255u : 0u);
   if (++got == 3) {
    *o++ = (uint8_t) abc[acc >> 18 & 63], *o++ = (uint8_t) abc[acc >> 12 & 63];
    *o++ = (uint8_t) abc[acc >> 6 & 63], *o++ = (uint8_t) abc[acc & 63], acc = got = 0; } }
  if (got) {
   acc <<= 8 * (3 - got);
   *o++ = (uint8_t) abc[acc >> 18 & 63], *o++ = (uint8_t) abc[acc >> 12 & 63];
   *o++ = got == 2 ? (uint8_t) abc[acc >> 6 & 63] : '=', *o++ = '='; }
  out = word(s); }
 else if (im && k == 4 && (uint64_t) im->off + (uint64_t) im->w * im->h <= (c->sn - cb_shead) / 4u) {
  uintptr_t const n = (uintptr_t) im->w * im->h;
  Have(str_width(n * 4));
  struct str *s = ini_str(str(Hp), n * 4); Hp += str_width(n * 4);
  uint32_t const *px = cb_ipx(c) + im->off;
  uint8_t *o = (uint8_t*) txt(s);
  for (uintptr_t i = 0; i < n; i++, o += 4)
   o[0] = (uint8_t) (px[i] >> 16), o[1] = (uint8_t) (px[i] >> 8), o[2] = (uint8_t) px[i], o[3] = px[i] >> 24 ? 255u : 0u;
  out = word(s); }
 Sp[2] = out;
 Sp += 2; Ip += 1; love_musttail return Continue(); }

static lvm(lvm_select) {
 struct cb *c = scr_ok(Sp[0]);
 word out = ZeroPoint;
 if (c && (Sp[1] & Sp[2] & Sp[3] & 1)) {
  intptr_t const u = getcharm(Sp[3]);
  cb_select(c, getcharm(Sp[1]), getcharm(Sp[2]), u < 0 ? 3u : (uint32_t) u);
  out = Sp[0]; }
 Sp[3] = out;
 Sp += 3; Ip += 1; love_musttail return Continue(); }

// (copied scr a b): counted first, as pasted is
static lvm(lvm_copied) {
 struct cb *c = scr_ok(Sp[0]);
 if (!c || !(Sp[1] & Sp[2] & 1)) { Sp[2] = ZeroPoint; Sp += 2; Ip += 1; love_musttail return Continue(); }
 intptr_t const a = getcharm(Sp[1]), b = getcharm(Sp[2]);
 uintptr_t const n = cb_copied(c, 0, a, b);
 Have(str_width(n));
 struct str *s = ini_str(str(Hp), n); Hp += str_width(n);
 cb_copied(c, (uint8_t*) txt(s), a, b);
 Sp[2] = word(s);
 Sp += 2; Ip += 1; love_musttail return Continue(); }

// (pasted scr s): counted first, so Have's restart repeats nothing but the count
static lvm(lvm_pasted) {
 struct cb *c = scr_ok(Sp[0]);
 if (!c || !strp(Sp[1])) { Sp[1] = ZeroPoint; Sp += 1; Ip += 1; love_musttail return Continue(); }
 struct str *in = str(Sp[1]);
 uintptr_t const n = cb_pasted(c, 0, (uint8_t const*) txt(in), len(in));
 Have(str_width(n));
 struct str *s = ini_str(str(Hp), n); Hp += str_width(n);
 cb_pasted(c, (uint8_t*) txt(s), (uint8_t const*) txt(in), len(in));
 Sp[1] = word(s);
 Sp += 1; Ip += 1; love_musttail return Continue(); }

// limn's row in C: pn[0] the face (-1 none said yet), 1 the fg, 2 the bg; stops at a
// picture's tile, which limn.l paints its own way. o 0 only counts
static uintptr_t limn_s(uint8_t *o, uintptr_t at, char const *s) {
 for (; *s; s++, at++) if (o) o[at] = (uint8_t) *s;
 return at; }
static uintptr_t limn_n(uint8_t *o, uintptr_t at, uint32_t v) {
 char b[10]; int i = 0;
 do b[i++] = (char) ('0' + v % 10), v /= 10; while (v);
 while (i--) { if (o) o[at] = (uint8_t) b[i]; at++; }
 return at; }
static uintptr_t limn_u8(uint8_t *o, uintptr_t at, uint32_t cp) {
 uint8_t b[4]; int n;
 if (!cp) cp = ' ';
 if (cp < 0x80) b[0] = (uint8_t) cp, n = 1;
 else if (cp < 0x800) b[0] = (uint8_t) (0xc0 | cp >> 6), b[1] = (uint8_t) (0x80 | (cp & 63)), n = 2;
 else if (cp < 0x10000) b[0] = (uint8_t) (0xe0 | cp >> 12), b[1] = (uint8_t) (0x80 | (cp >> 6 & 63)),
                        b[2] = (uint8_t) (0x80 | (cp & 63)), n = 3;
 else b[0] = (uint8_t) (0xf0 | cp >> 18), b[1] = (uint8_t) (0x80 | (cp >> 12 & 63)),
      b[2] = (uint8_t) (0x80 | (cp >> 6 & 63)), b[3] = (uint8_t) (0x80 | (cp & 63)), n = 4;
 for (int i = 0; i < n; i++, at++) if (o) o[at] = b[i];
 return at; }
// a colour word's SGR, base 38 for the fg and 48 for the bg
static uintptr_t limn_ink(uint8_t *o, uintptr_t at, uint32_t base, uint32_t k) {
 uint32_t const v = k & 0xffffffu;
 switch (k >> 24 & 3) {
  case cb_idx: return limn_n(o, limn_s(o, limn_n(o, at, base), ";5;"), v);
  case cb_rgb: at = limn_s(o, limn_n(o, at, base), ";2;");
   at = limn_s(o, limn_n(o, at, v >> 16), ";");
   return limn_n(o, limn_s(o, limn_n(o, at, v >> 8 & 255), ";"), v & 255);
  default: return limn_n(o, at, base + 1); } }
static uintptr_t limn_cells(struct cb const *c, uint8_t *o, intptr_t k, intptr_t n, intptr_t pn[3], intptr_t *took) {
 static uint8_t const bit[8] = { cb_bold, cb_dim, cb_ital, cb_under, cb_blink, cb_rev, cb_hide, cb_strike };
 static char const *const on[8] = { ";1", ";2", ";3", ";4", ";5", ";7", ";8", ";9" };
 uintptr_t at = 0;
 intptr_t i = 0;
 for (; i < n; i++) {
  struct cb_cell const *e = cb_at(c, k + i);
  if (!e) continue;
  uint32_t const *v = cb_clu(c, e->g);
  uint32_t g = v ? (e->g & 0xffe00000u) | cb_cp(v[0]) : e->g;
  if (c->sel0 <= k + i && k + i < c->sel1) g ^= (uint32_t) cb_rev << 24;
  if (cb_wide(g) == cb_tail) continue;
  if (g & cb_pic) break;
  intptr_t const fa = g >> 24, fg = e->fg & ~cb_soft & 0x3ffffffu, bg = e->bg;
  if (pn[0] != fa || pn[1] != fg || pn[2] != bg) {
   at = limn_s(o, at, "\033[0");
   for (int b = 0; b < 8; b++) if (fa & bit[b]) at = limn_s(o, at, on[b]);
   at = limn_ink(o, limn_s(o, at, ";"), 38, (uint32_t) fg);
   at = limn_s(o, limn_ink(o, limn_s(o, at, ";"), 48, (uint32_t) bg), "m");
   pn[0] = fa, pn[1] = fg, pn[2] = bg; }
  int const vs = cb_wide(g) == cb_lead && v && cb_cp(v[1]);
  if (vs) at = limn_s(o, at, "\033[2X\0337");
  at = limn_u8(o, at, cb_cp(g));
  for (int m = 1; v && m < cb_clun && cb_cp(v[m]); m++) at = limn_u8(o, at, cb_cp(v[m]));
  if (vs) at = limn_s(o, at, "\0338\033[2C"); }
 *took = i;
 return at; }

// (limned ..): counted, then laid after have, which may move the cask
love_noinline static struct g *host_limned(struct g *g) {
 word *a = g->sp;
 struct cb *c = scr_ok(a[0]);
 if (!c || !(a[1] & a[2] & a[3] & a[4] & a[5] & 1)) { a[0] = ZeroPoint; return g; }
 intptr_t const k = getcharm(a[1]), n = getcharm(a[2]);
 intptr_t pn[3] = { getcharm(a[3]), getcharm(a[4]), getcharm(a[5]) }, took = 0;
 uintptr_t const len = limn_cells(c, 0, k, n, pn, &took);
 if (!ok(g = have(g, str_width(len) + 5 * chain_req))) return g;
 a = g->sp, c = scr_ok(a[0]);
 pn[0] = getcharm(a[3]), pn[1] = getcharm(a[4]), pn[2] = getcharm(a[5]);
 struct str *s = ini_str(bump(g, str_width(len)), len);
 limn_cells(c, (uint8_t*) txt(s), k, n, pn, &took);
 intptr_t const tail[4] = { took, pn[0], pn[1], pn[2] };
 word l = ZeroPoint;
 for (int i = 4; i-- > 0;) l = word(ini_chain((struct chain*) bump(g, chain_req), putcharm(tail[i]), l));
 a[0] = word(ini_chain((struct chain*) bump(g, chain_req), word(s), l));
 return g; }
static lvm(lvm_limned) { LvmCallp(g, 5, host_limned) }

static union u const
  nif_screen[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_screen}, {lvm_ret0}},
  nif_scribe[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_scribe}, {lvm_ret0}},
  nif_glass[]  = {{lvm_cur}, {.x = putcharm(3)}, {lvm_glass},  {lvm_ret0}},
  nif_gaze[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_gaze},   {lvm_ret0}},
  nif_reply[]  = {{lvm_reply}, {lvm_ret0}},
  nif_damage[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_damage}, {lvm_ret0}},
  nif_fontrow[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_fontrow}, {lvm_ret0}},
  nif_tilepx[]  = {{lvm_cur}, {.x = putcharm(4)}, {lvm_tilepx},  {lvm_ret0}},
  nif_dye[]     = {{lvm_cur}, {.x = putcharm(6)}, {lvm_dye},     {lvm_ret0}},
  nif_regrid[]  = {{lvm_cur}, {.x = putcharm(4)}, {lvm_regrid},  {lvm_ret0}},
  nif_peer[]    = {{lvm_cur}, {.x = putcharm(2)}, {lvm_peer},    {lvm_ret0}},
  nif_mouse[]   = {{lvm_cur}, {.x = putcharm(5)}, {lvm_mouse},   {lvm_ret0}},
  nif_pasted[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_pasted},  {lvm_ret0}},
  nif_select[]  = {{lvm_cur}, {.x = putcharm(4)}, {lvm_select},  {lvm_ret0}},
  nif_copied[]  = {{lvm_cur}, {.x = putcharm(3)}, {lvm_copied},  {lvm_ret0}},
  nif_picture[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_picture}, {lvm_ret0}},
  nif_limned[]  = {{lvm_cur}, {.x = putcharm(6)}, {lvm_limned},  {lvm_ret0}};
