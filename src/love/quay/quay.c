#include "quay.h"
#include "cp437.h"
#include "cpwidth.h"
#include "cpemoji.h"

// *e <- a cell of codepoint cp in the current pen. the blank a clear or scroll
// leaves behind is cp 0 in the current pen,
// so erased ground keeps the program's background (BCE).
static void cb_pen(struct cb const *c, uint32_t cp, struct cb_cell *e) {
  e->g = cb_gw(cp, c->cur_face), e->fg = c->cur_fg, e->bg = c->cur_bg; }

// mark rows r1..r2 for repainting (inclusive; rows past 255 fold onto bit 255).
static void cb_dmg(struct cb *c, uint32_t r1, uint32_t r2) {
  if (r1 > 255) r1 = 255;
  if (r2 > 255) r2 = 255;
  for (uint32_t r = r1; r <= r2; r++) c->dmg[r >> 5] |= (uint32_t) 1 << (r & 31); }

// rows r1..r2 were written: marked, and a selection on any of them is over
static void cb_dirt(struct cb *c, uint32_t r1, uint32_t r2) {
  int32_t const cs = c->cols;
  if (c->sel0 != c->sel1 && c->sel1 > 0 && (int32_t) r1 <= (c->sel1 - 1) / cs
      && (int32_t) r2 >= (c->sel0 > 0 ? c->sel0 / cs : 0))
    c->sel0 = c->sel1 = 0, r1 = 0, r2 = c->rows - 1u;
  cb_dmg(c, r1, r2); }

void cb_fill(struct cb *c, uint32_t cp) {
  struct cb_cell cell; cb_pen(c, cp, &cell);
  for (uint32_t i = 0, j = (uint32_t) c->rows * c->cols; i < j; i++)
    c->cb[i] = cell;
  cb_dirt(c, 0, c->rows - 1u); }

void cb_clear(struct cb *c) { cb_fill(c, 0); }

// the attribute, and every cell ALREADY on the screen with it -- the characters stay put,
// their faces and colours go back to the default. the rows are marked like any other write:
// a cell whose colour changed and whose row is clean is a cell the painter will not come
// back for, so the screen would recolour only where something else happened to be writing.
void cb_recolor(struct cb *c, uint32_t fg, uint32_t bg) {
  cb_attr(c, fg, bg);
  for (uint32_t i = 0, j = (uint32_t) c->rows * c->cols; i < j; i++)
    c->cb[i].g &= 0xffffffu, c->cb[i].fg = c->cb[i].bg = cb_ink(cb_def, 0);
  cb_dirt(c, 0, c->rows - 1u); }

void cb_cur(struct cb *c, uint32_t row, uint32_t col) {
  c->wpos = (row * c->cols + col) % ((uint32_t) c->rows * c->cols); }

// what the default colours mean, and a pen reset to them
void cb_attr(struct cb *c, uint32_t fg, uint32_t bg) {
  c->def_fg = fg, c->def_bg = bg;
  c->cur_fg = c->cur_bg = cb_ink(cb_def, 0), c->cur_face = 0; }

// stamp a raw cp437 glyph with the current pen and step the cursor, no
// interpretation -- the escape-free lane for callers that mean every byte
// as a picture.
void cb_stamp(struct cb *c, uint8_t i) {
  uint32_t r = c->wpos / c->cols;
  cb_pen(c, cb_unfold(i), &c->cb[c->wpos]);
  cb_dirt(c, r, r);
  if (++c->wpos == (uint32_t) c->rows * c->cols) c->wpos = 0; }

void cb_open(struct cb *c, uint16_t rows, uint16_t cols, uint32_t sn) {
  c->wpos = c->spos = 0;
  c->rows = rows, c->cols = cols, c->cw = 8, c->ch = 16, c->pgen = 0;
  cb_store(c, sn);
  cb_hist(c, 0), c->twin = 0;
  c->flag = cb_show | cb_wrap;
  c->arg = 0, c->esc = 0, c->pn = 0, c->on = 0;
  c->ucp = 0, c->un = 0, c->ol = 0;
  for (int k = 0; k < 8; k++) c->dmg[k] = 0;
  for (uint32_t k = 0; k < cb_nclu; k++)
    for (uint32_t j = 0; j < cb_clun; j++) c->clu[k][j] = 0;
  cb_attr(c, cb_ink(cb_idx, 7), cb_ink(cb_idx, 0));
  c->sfg = c->sbg = cb_ink(cb_def, 0), c->sface = 0;
  c->top = 0, c->bot = rows - 1u;
  cb_clear(c); }

// scroll rows [t,b] up/down by n, blanking what opens. the saved cursor
// RIDES ALONG when its cell moves -- the old scroll left it pointing at
// shifted ground.
static void cb_ride(struct cb *c, uint32_t *p, uint32_t t, uint32_t b, int dn, uint32_t n) {
  uint32_t r = *p / c->cols, k = n * c->cols;
  if (r < t || r > b) return;
  if (dn < 0) { if (r >= t + n) *p -= k; }
  else        { if (r + n <= b) *p += k; } }

static void cb_keep(struct cb *c, uint32_t r);
static struct cb_cell *cb_twins(struct cb const *c);
static uint32_t cb_ncells(struct cb const *c);
static struct cb_cell *cb_nth(struct cb *c, uint32_t i);

// a row leaving the screen's top is kept in the history, but not the alternate screen's
static void cb_scup(struct cb *c, uint32_t t, uint32_t b, uint32_t n) {
  if (!n) return;
  if (n > b - t + 1u) n = b - t + 1u;
  int const kept = !t && !(c->flag & cb_alt);
  if (kept) for (uint32_t r = 0; r < n; r++) cb_keep(c, r);
  uint32_t cs = c->cols; struct cb_cell e; cb_pen(c, 0, &e);
  for (uint32_t i = t * cs, j = (b + 1u - n) * cs; i < j; i++) c->cb[i] = c->cb[i + n * cs];
  for (uint32_t i = (b + 1u - n) * cs, j = (b + 1u) * cs; i < j; i++) c->cb[i] = e;
  if (kept && c->sel0 != c->sel1) {                 // the selection rides up with its text
    c->sel0 -= (int32_t) (n * cs), c->sel1 -= (int32_t) (n * cs);
    if (c->sel0 < -(int32_t) (c->hn * cs)) c->sel0 = c->sel1 = 0; }
  if (kept) cb_dmg(c, t, b); else cb_dirt(c, t, b);
  cb_ride(c, &c->spos, t, b, -1, n); }

static void cb_scdn(struct cb *c, uint32_t t, uint32_t b, uint32_t n) {
  if (!n) return;
  if (n > b - t + 1u) n = b - t + 1u;
  uint32_t cs = c->cols; struct cb_cell e; cb_pen(c, 0, &e);
  for (uint32_t i = (b + 1u) * cs; i-- > (t + n) * cs;) c->cb[i] = c->cb[i - n * cs];
  for (uint32_t i = t * cs, j = (t + n) * cs; i < j; i++) c->cb[i] = e;
  cb_dirt(c, t, b);
  cb_ride(c, &c->spos, t, b, +1, n); }

// index: down one row, scrolling at the region's bottom margin. a
// cursor below the region (possible after DECSTBM) steps to the screen
// edge and stops.
static void cb_ind(struct cb *c) {
  uint32_t r = c->wpos / c->cols;
  c->flag &= (uint16_t) ~cb_pend;
  if (r == c->bot) cb_scup(c, c->top, c->bot, 1);
  else if (r + 1u < c->rows) c->wpos += c->cols; }

static void cb_ri(struct cb *c) {  // reverse index: the mirror
  uint32_t r = c->wpos / c->cols;
  c->flag &= (uint16_t) ~cb_pend;
  if (r == c->top) cb_scdn(c, c->top, c->bot, 1);
  else if (r) c->wpos -= c->cols; }

// absolute cursor addressing; origin mode reads rows against the
// scroll region. every deliberate move drops a pending wrap.
static void cb_goto(struct cb *c, uint32_t r, uint32_t col) {
  uint32_t lo = 0, hi = c->rows - 1u;
  if (c->flag & cb_origin) r += c->top, lo = c->top, hi = c->bot;
  if (r < lo) r = lo;
  if (r > hi) r = hi;
  if (col >= c->cols) col = c->cols - 1u;
  c->wpos = r * c->cols + col, c->flag &= (uint16_t) ~cb_pend; }

// the reply queue: answers (DSR, DA) ride home to whoever feeds the
// parser; the host drains them to the pty master, the kernel may not
// bother. a full queue drops the tail -- a late report beats a torn one.
static void cb_say(struct cb *c, char const *s) {
  while (*s && c->on < cb_outn) c->out[c->on++] = (uint8_t) *s++; }

static void cb_sayn(struct cb *c, uint32_t n) {
  char b[10]; int i = 10;   // a uint32 is at most 10 digits
  do b[--i] = (char) ('0' + n % 10u), n /= 10u; while (n);
  while (i < 10 && c->on < cb_outn) c->out[c->on++] = (uint8_t) b[i++]; }

int cb_reply(struct cb *c, uint8_t *buf) {
  int n = c->on;
  for (int i = 0; i < n; i++) buf[i] = c->out[i];
  return c->on = 0, n; }

static uint32_t cb_decn(uint8_t *o, uint32_t k, uint32_t n) {
  uint8_t b[10]; uint32_t i = 10;
  do b[--i] = (uint8_t) ('0' + n % 10u), n /= 10u; while (n);
  while (i < 10) o[k++] = b[i++];
  return k; }

uint32_t cb_mouse(struct cb const *c, uint8_t *o, uint32_t b, uint32_t row, uint32_t col, uint32_t how) {
  uint16_t const f = c->flag;
  uint32_t const btn = b & ~28u, k = 3;
  if (!(f & cb_mice) || how > 2 || (how == 1 && btn >= 64)) return 0;   // a wheel has no release
  if (f & cb_mx10) { if (how) return 0; b = btn; }                     // no modifiers either
  if (how == 2) {
    if (!(f & cb_many) && !((f & cb_mdrag) && btn != 3)) return 0;
    b += 32; }
  else if (btn == 3) return 0;
  o[0] = 033, o[1] = '[';
  if (f & cb_msgr) {
    o[2] = '<';
    uint32_t n = cb_decn(o, k, b);
    o[n++] = ';', n = cb_decn(o, n, col + 1u);
    o[n++] = ';', n = cb_decn(o, n, row + 1u);
    return o[n++] = how == 1 ? 'm' : 'M', n; }
  if (how == 1) b = (b & 28u) | 3u;                                   // a release names no button
  o[2] = 'M', o[3] = (uint8_t) (32u + b);
  o[4] = (uint8_t) (col < 222u ? 33u + col : 255u), o[5] = (uint8_t) (row < 222u ? 33u + row : 255u);  // a byte's reach
  return 6; }

// a paste can't close its bracket early or carry a sequence in: its controls go
int cb_paste1(uint8_t prev, uint8_t b) {
  if (b == '\n') return prev == '\r' ? -1 : '\r';
  return (b < 32 && b != '\t' && b != '\r') || b == 127 ? -1 : b; }

uintptr_t cb_pasted(struct cb const *c, uint8_t *o, uint8_t const *s, uintptr_t n) {
  static char const open[] = cb_popen, shut[] = cb_pshut;
  int const br = c->flag & cb_paste;
  uintptr_t k = 0;
  if (br) for (int j = 0; open[j]; j++, k++) if (o) o[k] = (uint8_t) open[j];
  for (uintptr_t i = 0; i < n; i++) {
    int const b = cb_paste1(i ? s[i - 1] : 0, s[i]);
    if (b < 0) continue;
    if (o) o[k] = (uint8_t) b;
    k++; }
  if (br) for (int j = 0; shut[j]; j++, k++) if (o) o[k] = (uint8_t) shut[j];
  return k; }

// --- the selection ----------------------------------------------------------------------
struct cb_cell const *cb_at(struct cb const *c, intptr_t i) {
  intptr_t const back = (intptr_t) c->hn * c->cols;
  return i >= (intptr_t) c->rows * c->cols || i < -back ? 0
       : i >= 0 ? &c->cb[i] : &cb_hline(c, (uint32_t) ((i + back) / c->cols))[(i + back) % c->cols]; }

// a word's cell: not blank, not a picture, not a mark of where words end; a tail is its lead's
static int cb_wordy(struct cb const *c, intptr_t i, intptr_t row0) {
  struct cb_cell const *e = cb_at(c, i);
  if (e && cb_wide(e->g) == cb_tail && i > row0) e = cb_at(c, i - 1);
  if (!e || e->g & cb_pic) return 0;
  uint32_t const cp = cb_base(c, e->g);
  if (cp <= 32) return 0;
  for (char const *d = "\"'`()[]{}<>,;|"; *d; d++) if (cp == (uint8_t) *d) return 0;
  return 1; }

// a row's first cell: glass counts rows from 0 down and from -cols up, so floor, not truncate
static intptr_t cb_row0(struct cb const *c, intptr_t i) {
  intptr_t const cs = c->cols;
  return (i >= 0 ? i / cs : -((-i + cs - 1) / cs)) * cs; }

void cb_select(struct cb *c, intptr_t a, intptr_t b, uint32_t unit) {
  intptr_t const cs = c->cols, lo = -(intptr_t) c->hn * cs, hi = (intptr_t) c->rows * cs - 1;
  if (unit > 2) {
    if (c->sel0 != c->sel1) c->sel0 = c->sel1 = 0, cb_dmg(c, 0, c->rows - 1u);
    return; }
  if (a > b) { intptr_t const t = a; a = b, b = t; }
  a = a < lo ? lo : a > hi ? hi : a, b = b < lo ? lo : b > hi ? hi : b;
  if (unit == 1) {
    intptr_t const ra = cb_row0(c, a), rb = cb_row0(c, b);
    if (cb_wordy(c, a, ra)) while (a > ra && cb_wordy(c, a - 1, ra)) a--;
    if (cb_wordy(c, b, rb)) while (b < rb + cs - 1 && cb_wordy(c, b + 1, rb)) b++; }
  if (unit == 2) {
    a = cb_row0(c, a), b = cb_row0(c, b) + cs - 1;
    while (a > lo && cb_at(c, a - 1)->fg & cb_soft) a -= cs;
    while (b < hi && cb_at(c, b)->fg & cb_soft) b += cs; }
  if (a > cb_row0(c, a) && cb_wide(cb_at(c, a)->g) == cb_tail) a--;   // a wide char whole
  if (b < cb_row0(c, b) + cs - 1 && cb_wide(cb_at(c, b)->g) == cb_lead) b++;
  c->sel0 = (int32_t) a, c->sel1 = (int32_t) (b + 1);
  cb_dmg(c, 0, c->rows - 1u); }

static uintptr_t cb_u8(uint8_t *o, uintptr_t k, uint32_t cp) {
  uint8_t b[4]; int n;
  if (cp < 0x80) b[0] = (uint8_t) cp, n = 1;
  else if (cp < 0x800) b[0] = (uint8_t) (0xc0 | cp >> 6), b[1] = (uint8_t) (0x80 | (cp & 63)), n = 2;
  else if (cp < 0x10000) b[0] = (uint8_t) (0xe0 | cp >> 12), b[1] = (uint8_t) (0x80 | (cp >> 6 & 63)),
                         b[2] = (uint8_t) (0x80 | (cp & 63)), n = 3;
  else b[0] = (uint8_t) (0xf0 | cp >> 18), b[1] = (uint8_t) (0x80 | (cp >> 12 & 63)),
       b[2] = (uint8_t) (0x80 | (cp >> 6 & 63)), b[3] = (uint8_t) (0x80 | (cp & 63)), n = 4;
  for (int j = 0; j < n; j++, k++) if (o) o[k] = b[j];
  return k; }

uintptr_t cb_copied(struct cb const *c, uint8_t *o, intptr_t a, intptr_t b) {
  intptr_t const cs = c->cols, lo = -(intptr_t) c->hn * cs, hi = (intptr_t) c->rows * cs;
  a = a < lo ? lo : a, b = b > hi ? hi : b;
  uintptr_t k = 0, kt = 0;                          // kt: past the row's last non-blank
  for (intptr_t i = a; i < b; i++) {
    struct cb_cell const *e = cb_at(c, i);
    intptr_t const col = (i - lo) % cs;
    if (!(e->g & cb_pic) && !(cb_wide(e->g) == cb_tail && col)) {
      uint32_t const *v = cb_clu(c, e->g), cp = cb_base(c, e->g);
      k = cb_u8(o, k, cp ? cp : ' ');
      for (uint32_t m = 1; v && m < cb_clun && v[m]; m++) k = cb_u8(o, k, v[m]);
      if (cp > ' ') kt = k; }
    if (col == cs - 1 && !(e->fg & cb_soft)) {
      k = kt;
      if (i + 1 < b) { if (o) o[k] = '\n'; kt = ++k; } } }
  return k; }

// the OSC asks worth answering: colour queries (ESC]10;? fg, ESC]11;? bg)
// -- zsh and friends probe the background at line-editor startup and WAIT;
// silence costs the user a second of buffered keystrokes. the answers are
// the default pen's truth on every renderer: c0c0c0 on black.
static void cb_oscq(struct cb *c) {
  if (c->ol == 4 && c->ob[0] == '1' && c->ob[2] == ';' && c->ob[3] == '?') {
    if (c->ob[1] == '0') cb_say(c, "\033]10;rgb:c0c0/c0c0/c0c0\a");
    else if (c->ob[1] == '1') cb_say(c, "\033]11;rgb:0000/0000/0000\a"); } }

// C0 controls, live in ground state and mid-CSI alike. \n implies \r
// only under LNM (the kernel console's discipline); a raw feed keeps
// the column, which is what a pty's ONLCR-translated stream expects.
static void cb_ctl(struct cb *c, uint8_t i) {
  uint32_t cs = c->cols, col = c->wpos % cs;
  switch (i) {
   case '\r': c->wpos -= col, c->flag &= (uint16_t) ~cb_pend; return;
   case '\b': if (col) c->wpos--;
              c->flag &= (uint16_t) ~cb_pend; return;
   case '\n': case 11: case 12:  // LF VT FF
    if (c->flag & cb_lnm) c->wpos -= col;
    c->flag &= (uint16_t) ~cb_pend;
    return cb_ind(c);
   case '\t': { uint32_t nx = (col / 8u + 1u) * 8u;
    if (nx > cs - 1u) nx = cs - 1u;
    c->wpos += nx - col; return; }
   case 14: c->gset |= cb_so; return;                       // SO: G1 into GL
   case 15: c->gset &= (uint8_t) ~cb_so; return;            // SI: G0 back
   default: return; } }  // BEL and the rest of C0: swallowed whole

// DEC special graphics, 0x5f..0x7e: what ncurses' ACS letters draw -- q a line, x a
// bar, l k m j the corners, t u v w n the tees and the cross
static uint16_t const cb_decgfx[32] = {
  0x00a0, 0x25c6, 0x2592, 0x2409, 0x240c, 0x240d, 0x240a, 0x00b0, 0x00b1, 0x2424, 0x240b,
  0x2518, 0x2510, 0x250c, 0x2514, 0x253c, 0x23ba, 0x23bb, 0x2500, 0x23bc, 0x23bd, 0x251c,
  0x2524, 0x2534, 0x252c, 0x2502, 0x2264, 0x2265, 0x03c0, 0x2260, 0x00a3, 0x00b7 };

// a printing glyph. a pending wrap fires FIRST (deferred autowrap: the
// glyph that landed on the last column left the cursor there; the next
// one carries it to a fresh line), then the stamp, then the step -- a
// stamp on the last column pends rather than moving, or overwrites in
// place with autowrap off.
// a wide char is two cells, a lead holding the codepoint and a tail holding 0; one
// that meets the last column wraps first (or steps back, autowrap off). a zero-width
// one is a mark, and joins the cell before it (cb_mark). cb_unpair blanks the other
// half of whatever pair a write lands on.
static void cb_unpair(struct cb *c, uint32_t p) {
  uint32_t const cs = c->cols, col = p % cs, w = cb_wide(c->cb[p].g);
  if (w == cb_tail && col) c->cb[p - 1].g &= 0xff000000u;
  if (w == cb_lead && col + 1u < cs) c->cb[p + 1].g &= 0xff000000u; }

uint32_t const *cb_clu(struct cb const *c, uint32_t g) {
  uint32_t const k = cb_cp(g) - cb_clu0;
  return !(g & cb_pic) && cb_cp(g) >= cb_clu0 && k < cb_nclu && c->clu[k][0] ? c->clu[k] : 0; }

uint32_t cb_base(struct cb const *c, uint32_t g) {
  uint32_t const *v = cb_clu(c, g);
  return v ? cb_cp(v[0]) : cb_cp(g); }

// the slot holding v: one that already does, else a free one, else one freed by a sweep
// of the cells and the history (all but cell `skip`, whose slot v replaces); cb_nclu when
// every slot is named
static uint32_t cb_slot(struct cb *c, uint32_t const *v, uint32_t skip) {
  uint32_t k, j;
  for (k = 0; k < cb_nclu; k++) {
    for (j = 0; j < cb_clun && c->clu[k][j] == v[j]; j++) ;
    if (j == cb_clun) return k; }
  for (k = 0; k < cb_nclu && c->clu[k][0]; k++) ;
  if (k == cb_nclu) {
    uint32_t named[cb_nclu / 32] = { 0 };
    for (uint32_t i = 0, n = cb_ncells(c); i < n; i++) {
      uint32_t const g = cb_nth(c, i)->g;
      if (i != skip && cb_clu(c, g)) j = cb_cp(g) - cb_clu0, named[j >> 5] |= (uint32_t) 1 << (j & 31); }
    for (j = 0; j < cb_nclu; j++) if (!(named[j >> 5] >> (j & 31) & 1)) c->clu[j][0] = 0;
    for (k = 0; k < cb_nclu && c->clu[k][0]; k++) ; }
  if (k < cb_nclu) for (j = 0; j < cb_clun; j++) c->clu[k][j] = v[j];
  return k; }

// is cp in a table of runs (cpemoji.h), each entry opening or closing one in turn: an odd
// count of entries at or below it
static int cb_in(uint32_t const *t, uintptr_t n, uint32_t cp) {
  uintptr_t lo = 0, hi = n;
  while (lo < hi) {
    uintptr_t const m = (lo + hi) / 2;
    if (t[m] <= cp) lo = m + 1; else hi = m; }
  return lo & 1; }
static int cb_vs16(uint32_t cp) { return cb_in(cpvs, sizeof cpvs / sizeof *cpvs, cp); }
static int cb_xp(uint32_t cp) { return cb_in(cpxp, sizeof cpxp / sizeof *cpxp, cp); }
static int cb_regional(uint32_t cp) { return cp >= 0x1f1e6u && cp <= 0x1f1ffu; }

// under ?2027, VS16 after a narrow character with an emoji style, or any join (any),
// makes its cell a wide char's lead and the next its tail. on the last column, the pair
// wraps to the next line as a wide char would there; with autowrap off it stays narrow
static void cb_emoji(struct cb *c, uint32_t p, int any) {
  uint32_t const cs = c->cols;
  struct cb_cell e = c->cb[p];
  if (cs < 2 || e.g & cb_pic || cb_wide(e.g) || !(any || cb_vs16(cb_base(c, e.g)))) return;
  e.fg &= ~cb_soft;
  if (p % cs == cs - 1u) {
    if (!(c->flag & cb_pend)) return;
    c->cb[p].g &= 0xff000000u, c->cb[p].fg |= cb_soft, cb_dirt(c, p / cs, p / cs);
    c->flag &= (uint16_t) ~cb_pend, c->wpos -= c->wpos % cs, cb_ind(c);
    p = c->wpos;
    cb_unpair(c, p); }
  cb_unpair(c, p + 1u);
  c->cb[p] = e, c->cb[p].g |= (uint32_t) cb_lead << 21;
  c->cb[p + 1u] = e, c->cb[p + 1u].g = (e.g & 0xff000000u) | (uint32_t) cb_tail << 21;
  cb_dirt(c, p / cs, p / cs);
  c->flag &= (uint16_t) ~cb_pend;
  if ((p + 1u) % cs == cs - 1u) { c->wpos = p + 1u; if (c->flag & cb_wrap) c->flag |= cb_pend; }
  else c->wpos = p + 2u; }

// the cell before the cursor -- the one a pending wrap sits on, a wide char's lead for
// its tail -- or ~0u for none
static uint32_t cb_prev(struct cb const *c) {
  uint32_t const cs = c->cols;
  uint32_t p = c->wpos;
  if (!(c->flag & cb_pend)) { if (!(p % cs)) return ~0u; p--; }
  if (cb_wide(c->cb[p].g) == cb_tail && p % cs) p--;
  return p; }

// under ?2027, does cp join the cluster before the cursor rather than take cells: an emoji
// modifier after a pictograph, a pictograph after a ZWJ that ends one, a regional indicator
// after a lone one -- while the cluster has room ('text's gcnext keeps the same rules)
static int cb_joins(struct cb const *c, uint32_t cp) {
  uint32_t const p = cb_prev(c);
  if (!(c->flag & cb_gc) || p == ~0u) return 0;
  uint32_t const g = c->cb[p].g, *v = cb_clu(c, g), b = cb_base(c, g);
  uint32_t n = 1;
  if (v) for (n = 0; n < cb_clun && v[n]; n++) ;
  if (g & cb_pic || !cb_cp(g) || n == cb_clun) return 0;
  if (cp >= 0x1f3fbu && cp <= 0x1f3ffu) return cb_xp(b);
  if (cb_regional(cp)) return n == 1 && cb_regional(b);
  return cb_xp(cp) && cb_xp(b) && v && v[n - 1] == 0x200du; }

// a mark joins the cell before the cursor, keeping its pen, as does a character ?2027
// joins there (cb_joins), which widens it. none there, a picture, or a full cluster: the
// mark is dropped (though a VS16 still widens, cb_emoji)
static void cb_mark(struct cb *c, uint32_t m) {
  uint32_t const cs = c->cols, p = cb_prev(c);
  if (p == ~0u) return;
  uint32_t const g = c->cb[p].g, *o = cb_clu(c, g);
  if (g & cb_pic || !cb_cp(g) || cb_wide(g) == cb_tail) return;
  uint32_t v[cb_clun] = { cb_cp(g) }, n = 1;
  if (o) for (n = 0; n < cb_clun && o[n]; n++) v[n] = o[n];
  if (n < cb_clun) {
    v[n] = m;
    uint32_t const k = cb_slot(c, v, p);
    if (k < cb_nclu) c->cb[p].g = (g & 0xffe00000u) | (cb_clu0 + k), cb_dirt(c, p / cs, p / cs); }
  if (c->flag & cb_gc && (m == 0xfe0fu || cb_width(m))) cb_emoji(c, p, m != 0xfe0fu); }

static void cb_glyph(struct cb *c, uint32_t cp) {
  uint32_t cs = c->cols, w = cb_width(cp);
  if (!w || cb_joins(c, cp)) return cb_mark(c, cp);
  if (w == 2 && cs < 2) w = 1;
  if (c->flag & cb_pend) {                          // the row wraps: its last cell says so
    c->flag &= (uint16_t) ~cb_pend, c->wpos -= c->wpos % cs;
    c->cb[c->wpos + cs - 1u].fg |= cb_soft, cb_ind(c); }
  if (w == 2 && c->wpos % cs == cs - 1u) {
    if (c->flag & cb_wrap) c->wpos -= cs - 1u, c->cb[c->wpos + cs - 1u].fg |= cb_soft, cb_ind(c);
    else c->wpos--; }
  uint32_t const p = c->wpos;
  cb_unpair(c, p);
  if (w == 2) cb_unpair(c, p + 1u);
  cb_pen(c, cp, &c->cb[p]);
  if (w == 2) {
    c->cb[p].g |= (uint32_t) cb_lead << 21;
    cb_pen(c, 0, &c->cb[p + 1u]);
    c->cb[p + 1u].g |= (uint32_t) cb_tail << 21; }
  cb_dirt(c, p / cs, p / cs);
  uint32_t const last = p + w - 1u;
  if (last % cs == cs - 1u) { c->wpos = last; if (c->flag & cb_wrap) c->flag |= cb_pend; }
  else c->wpos = last + 1u; }

// row r after an erase or a shift: a lead with no tail beside it, or a tail with no
// lead, is blanked -- half a wide char draws as nothing
static void cb_mend(struct cb *c, uint32_t r) {
  uint32_t const cs = c->cols, rb = r * cs;
  for (uint32_t j = 0; j < cs; j++) {
    uint32_t const w = cb_wide(c->cb[rb + j].g);
    if (w == cb_lead && (j + 1u == cs || cb_wide(c->cb[rb + j + 1u].g) != cb_tail))
      c->cb[rb + j].g &= 0xff000000u;
    if (w == cb_tail && (!j || cb_wide(c->cb[rb + j - 1u].g) != cb_lead))
      c->cb[rb + j].g &= 0xff000000u; } }

// --- the store: pictures, after the cells ---------------------------------------------
static uint8_t *cb_sbase(struct cb const *c) {
  return (uint8_t*) (c->cb + (uintptr_t) c->rows * c->cols); }
static struct cb_img *cb_imgs(struct cb const *c) { return (struct cb_img*) cb_sbase(c); }
static uint32_t *cb_pal(struct cb const *c) { return (uint32_t*) (cb_sbase(c) + cb_nimg * sizeof(struct cb_img)); }
uint32_t const *cb_ipx(struct cb const *c) { return (uint32_t const*) (cb_sbase(c) + cb_shead); }
static uint32_t *cb_spx(struct cb *c) { return (uint32_t*) (cb_sbase(c) + cb_shead); }
// the arena's words, 0 for a screen with no store
static uint32_t cb_words(struct cb const *c) { return c->sn > cb_shead ? (c->sn - cb_shead) / 4u : 0; }
static uint32_t cb_gen(struct cb *c) { return ++c->pgen ? c->pgen : ++c->pgen; }   // never 0

// an empty store of sn bytes: no pictures, the registers black, nothing decoding
void cb_store(struct cb *c, uint32_t sn) {
  c->sn = sn >= cb_shead ? sn : 0, c->stop = 0, c->sslot = 0, c->sm = 0;
  if (!c->sn) return;
  struct cb_img *im = cb_imgs(c);
  uint32_t *pal = cb_pal(c);
  for (uint32_t k = 0; k < cb_nimg; k++) im[k] = (struct cb_img) { 0, 0, 0, 0, 0, 0 };
  c->kopen = 0, c->kslot = 0;
  for (uint32_t k = 0; k < 256; k++) pal[k] = 0; }

// --- the history: a ring of lines after the store --------------------------------------
static struct cb_cell *cb_ring(struct cb const *c) { return (struct cb_cell*) (cb_sbase(c) + c->sn); }

struct cb_cell const *cb_hline(struct cb const *c, uint32_t k) {
  return k < c->hn ? cb_ring(c) + (uintptr_t) ((c->hh + k) % c->hl) * c->cols : 0; }

void cb_hist(struct cb *c, uint32_t hl) { c->hl = hl, c->hh = c->hn = c->view = 0, c->sel0 = c->sel1 = 0; }

void cb_twin(struct cb *c, uint32_t on) { c->twin = on ? 1u : 0u; }

// the twin grid, or 0 for a screen laid without one
static struct cb_cell *cb_twins(struct cb const *c) {
  return c->twin ? cb_ring(c) + (uintptr_t) c->hl * c->cols : 0; }

// grid row r, a history line in its place for as many rows as the view looks back
struct cb_cell const *cb_seen(struct cb const *c, uint32_t r) {
  return r < c->view ? cb_hline(c, c->hn - c->view + r) : c->cb + (uintptr_t) (r - c->view) * c->cols; }

void cb_peer(struct cb *c, uint32_t n) {
  n = n < c->hn ? n : c->hn;
  if (n != c->view) c->view = n, cb_dmg(c, 0, c->rows - 1u); }

// a line into the history: the next free one, else the oldest's place. a reader looking
// back goes on seeing the same lines
static void cb_line(struct cb *c, struct cb_cell const *row, uint32_t w) {
  if (!c->hl) return;
  struct cb_cell *d;
  if (c->hn < c->hl) d = cb_ring(c) + (uintptr_t) ((c->hh + c->hn++) % c->hl) * c->cols;
  else d = cb_ring(c) + (uintptr_t) c->hh * c->cols, c->hh = (c->hh + 1u) % c->hl;
  struct cb_cell const blank = { 0, cb_ink(cb_def, 0), cb_ink(cb_def, 0) };
  for (uint32_t k = 0; k < c->cols; k++) d[k] = k < w ? row[k] : blank;
  if (c->view) c->view = c->view < c->hn ? c->view + 1u : c->hn, cb_dmg(c, 0, c->rows - 1u); }

static void cb_keep(struct cb *c, uint32_t r) { cb_line(c, c->cb + (uintptr_t) r * c->cols, c->cols); }

// every cell that can name a cluster or a picture: the grid's, the main grid's while it waits
// in the twin, then the history's
static uint32_t cb_ntwin(struct cb const *c) {
  return c->twin && c->flag & cb_alt ? (uint32_t) c->rows * c->cols : 0; }
static uint32_t cb_ncells(struct cb const *c) {
  return (uint32_t) c->rows * c->cols + cb_ntwin(c) + c->hn * c->cols; }
static struct cb_cell *cb_nth(struct cb *c, uint32_t i) {
  uint32_t const n = (uint32_t) c->rows * c->cols, t = n + cb_ntwin(c);
  if (i < n) return c->cb + i;
  if (i < t) return cb_twins(c) + (i - n);
  return cb_ring(c) + (uintptr_t) ((c->hh + (i - t) / c->cols) % c->hl) * c->cols + (i - t) % c->cols; }

// a live picture that fits its arena, or 0: a painter may trust what this answers
struct cb_img const *cb_img(struct cb const *c, uint32_t slot) {
  if (!slot || slot >= cb_nimg || !cb_words(c)) return 0;
  struct cb_img const *im = cb_imgs(c) + slot;
  if (!im->live || !im->w || !im->h || im->w > 65536u || im->h > 65536u) return 0;
  uint64_t const end = (uint64_t) im->off + (uint64_t) im->w * im->h;
  return end <= cb_words(c) ? im : 0; }

// the sweep: a picture no cell (nor history line) names is dropped -- save, with ids, one kitty holds by id
// for a later placement -- and the rest packed down in the order they were laid, which is
// the order of their offsets
static void cb_sweep(struct cb *c, int ids) {
  struct cb_img *im = cb_imgs(c);
  uint32_t *px = cb_spx(c), seen[cb_nimg / 32] = { 0 }, top = 0;
  for (uint32_t k = 0; k < cb_nimg; k++) im[k].live = im[k].live && cb_img(c, k) ? 2u : 0u;
  for (uint32_t i = 0, n = cb_ncells(c); i < n; i++) {
    uint32_t const g = cb_nth(c, i)->g;
    if (g & cb_pic && im[cb_tslot(g)].live == 2) im[cb_tslot(g)].live = 3; }
  if (ids) for (uint32_t k = 0; k < cb_nimg; k++) if (im[k].live == 2 && im[k].id) im[k].live = 3;
  for (;;) {
    uint32_t best = 0;
    for (uint32_t k = 1; k < cb_nimg; k++)
      if (im[k].live == 3 && !(seen[k >> 5] >> (k & 31) & 1) && (!best || im[k].off < im[best].off)) best = k;
    if (!best) break;
    seen[best >> 5] |= (uint32_t) 1 << (best & 31);
    uint32_t const n = im[best].w * im[best].h;
    if (im[best].off != top) for (uint32_t j = 0; j < n; j++) px[top + j] = px[im[best].off + j];
    im[best].off = top, top += n; }
  for (uint32_t k = 0; k < cb_nimg; k++) im[k].live = im[k].live == 3;
  c->stop = top; }

// a cell index carried from a grid `ocols` wide, its rows shifted up by `from` -- the
// cursor's and DECSC's. what falls outside the new grid lands on its edge.
static uint32_t cb_carry(uint32_t pos, uint32_t ocols, uint32_t from,
                         uint32_t rows, uint32_t cols) {
  uint32_t r = pos / ocols, k = pos % ocols;
  r = r > from ? r - from : 0;
  if (r >= rows) r = rows - 1u;
  if (k >= cols) k = cols - 1u;
  return r * cols + k; }

// old's pictures into c's empty store, packed in slot order while they fit: the ones a
// carried cell names first, then the ones kitty holds by id. a tile of one left behind blanks
static void cb_restock(struct cb *c, struct cb const *old) {
  uint32_t const n = cb_ncells(c), room = cb_words(c);
  struct cb_img const *oi = cb_imgs(old);
  struct cb_img *ni = cb_imgs(c);
  uint32_t *px = cb_spx(c), *pal = cb_pal(c), named[cb_nimg / 32] = { 0 }, top = 0;
  for (uint32_t i = 0; i < n; i++) {
    uint32_t const g = cb_nth(c, i)->g, t = cb_tslot(g);
    if (g & cb_pic) named[t >> 5] |= (uint32_t) 1 << (t & 31); }
  for (uint32_t k = 0; room && k < 256; k++) pal[k] = cb_pal(old)[k];
  for (uint32_t pass = 0; room && pass < 2; pass++)
    for (uint32_t k = 1; k < cb_nimg; k++) {
      uint32_t const on = named[k >> 5] >> (k & 31) & 1;
      struct cb_img const *im = (pass ? !on && oi[k].id : on) ? cb_img(old, k) : 0;
      uint32_t const m = im ? im->w * im->h : 0;
      if (!im || m > room - top) continue;
      for (uint32_t j = 0; j < m; j++) px[top + j] = cb_ipx(old)[im->off + j];
      ni[k] = *im, ni[k].off = top, ni[k].live = 1, top += m; }
  c->stop = top;
  for (uint32_t i = 0; i < n; i++) {
    uint32_t const g = cb_nth(c, i)->g;
    if (g & cb_pic && !(room && ni[cb_tslot(g)].live)) cb_nth(c, i)->g = g & 0xff000000u; } }

// old laid across into c, a fresh rows x cols screen with a store of sn bytes: the pen, the
// modes, the clusters and a parser mid-sequence come whole; the cells row for row, clipped
// where c is narrower, scrolled up only as far as the cursor's row needs, so shrinking
// spends the blank tail under a prompt before it touches a line; the pictures they name as
// far as the store holds them. nothing reflows -- a line wrapped at the old width stays
// broken where it was. the history comes too, hl lines of it, its lines clipped or widened
// like the rows, and the rows the shrink scrolled away join it; and a main grid waiting out
// the alternate screen, from its top, into c's twin when tw (else it is lost, and the way
// out clears). c and old may not overlap
void cb_regrid(struct cb *c, struct cb const *old, uint16_t rows, uint16_t cols, uint32_t sn, uint32_t hl,
               uint32_t tw) {
  uint32_t const orows = old->rows, ocols = old->cols, cr = old->wpos / ocols,
                 from = cr >= rows ? cr - rows + 1u : 0, w = cols < ocols ? cols : ocols;
  *c = *old;
  c->rows = rows, c->cols = cols;
  cb_store(c, sn);
  c->top = 0, c->bot = (uint16_t) (rows - 1u);   // the old region addressed the old rows
  c->flag &= (uint16_t) ~cb_pend;                 // a pending wrap named the old last column
  struct cb_cell const blank = { 0, cb_ink(cb_def, 0), cb_ink(cb_def, 0) };   // the default pen
  for (uint32_t i = 0, n = (uint32_t) rows * cols; i < n; i++) c->cb[i] = blank;
  for (uint32_t r = from, dr = 0; r < orows && dr < rows; r++, dr++) {
    for (uint32_t k = 0; k < w; k++) c->cb[dr * cols + k] = old->cb[r * ocols + k];
    cb_mend(c, dr); }
  cb_hist(c, hl), cb_twin(c, tw);
  struct cb_cell *nt = cb_twins(c);
  struct cb_cell const *ot = old->flag & cb_alt ? cb_twins(old) : 0;
  if (nt) for (uint32_t i = 0, n = (uint32_t) rows * cols; i < n; i++) nt[i] = blank;
  if (nt && ot)
    for (uint32_t r = 0; r < orows && r < rows; r++)
      for (uint32_t k = 0; k < w; k++) nt[r * cols + k] = ot[r * ocols + k];
  for (uint32_t k = 0; k < old->hn; k++) cb_line(c, cb_hline(old, k), w);
  if (!(old->flag & cb_alt)) for (uint32_t r = 0; r < from; r++) cb_line(c, old->cb + r * ocols, w);
  cb_restock(c, old);
  c->wpos = cb_carry(old->wpos, ocols, from, rows, cols);
  c->spos = cb_carry(old->spos, ocols, from, rows, cols);
  c->gset = old->gset, c->sgset = old->sgset;
  cb_dirt(c, 0, rows - 1u); }

// --- sixel: DECSIXEL into a canvas at the store's top, tiles at the cursor at the end ---
// the canvas is a screen's width of pixels wide and as deep as the arena leaves (at most
// 256 cells); rows are cleared as bands first reach them. a pixel set is 0xff over its rgb.
static void cb_six_open(struct cb *c) {
  c->sslot = 0;
  if (!cb_words(c)) return;
  cb_sweep(c, 1);
  uint32_t k = 1;
  while (k < cb_nimg && cb_imgs(c)[k].live) k++;
  if (k == cb_nimg) cb_sweep(c, 0), k = 1;
  while (k < cb_nimg && cb_imgs(c)[k].live) k++;
  uint32_t const stride = (uint32_t) c->cols * c->cw, room = cb_words(c) - c->stop;
  uint32_t h = stride ? room / stride : 0;
  if (h > 256u * c->ch) h = 256u * c->ch;
  if (k == cb_nimg || h < 6) return;
  cb_imgs(c)[k] = (struct cb_img) { c->stop, stride, h, 0, 0, 0 };
  c->sslot = (uint16_t) k, c->sx = c->sy = c->sw = c->sh = 0, c->sreg = 0, c->srep = 1, c->sm = 0; }

// a colour off HLS, sixel's hue wheel putting blue at 0, red at 120 and green at 240;
// l and s in percent, the arithmetic in ten-thousandths
static uint32_t cb_hls1(uint32_t m1, uint32_t m2, uint32_t hh) {
  hh %= 360u;
  if (hh < 60) return m1 + (m2 - m1) * hh / 60u;
  if (hh < 180) return m2;
  if (hh < 240) return m1 + (m2 - m1) * (240u - hh) / 60u;
  return m1; }
static uint32_t cb_hls(uint32_t h, uint32_t l, uint32_t s) {
  l = (l > 100 ? 100 : l) * 100u, s = (s > 100 ? 100 : s) * 100u;
  uint32_t const std = (h + 240u) % 360u;           // the usual wheel: red at 0
  uint32_t const m2 = l <= 5000 ? l * (10000u + s) / 10000u : l + s - l * s / 10000u,
                 m1 = 2u * l - m2;
  uint32_t const r = cb_hls1(m1, m2, std + 120u), g = cb_hls1(m1, m2, std),
                 b = cb_hls1(m1, m2, std + 240u);
  return (r * 255u / 10000u) << 16 | (g * 255u / 10000u) << 8 | b * 255u / 10000u; }

static uint32_t cb_pct(uint16_t v) { return (v > 100 ? 100u : v) * 255u / 100u; }

// the parameter command in flight, now its numbers are in
static void cb_six_cmd(struct cb *c) {
  if (c->sm == '!') c->srep = c->pn && c->pv[0] ? c->pv[0] : 1u;
  else if (c->sm == '#' && c->pn) {
    uint32_t const r = c->pv[0] & 255u;
    if (c->pn >= 5 && c->pv[1] == 2)
      cb_pal(c)[r] = cb_pct(c->pv[2]) << 16 | cb_pct(c->pv[3]) << 8 | cb_pct(c->pv[4]);
    else if (c->pn >= 5 && c->pv[1] == 1)
      cb_pal(c)[r] = cb_hls(c->pv[2] % 360u, c->pv[3], c->pv[4]);
    c->sreg = r; }
  c->sm = 0, c->pn = 0, c->arg = 0; }

// one sixel byte
static void cb_six(struct cb *c, uint8_t i) {
  if (c->sm) {
    if (i >= '0' && i <= '9') { if (c->arg < 6553) c->arg = (uint16_t) (c->arg * 10 + (i - '0')); return; }
    if (c->pn < cb_pmax) c->pv[c->pn++] = c->arg;
    c->arg = 0;
    if (i == ';') return;
    cb_six_cmd(c); }
  if (!c->sslot) return;
  struct cb_img const *cv = cb_imgs(c) + c->sslot;
  if (i == '#' || i == '!' || i == '"') { c->sm = i, c->pn = 0, c->arg = 0; return; }
  if (i == '$') { c->sx = 0; return; }
  if (i == '-') { c->sx = 0, c->sy += 6; return; }
  if (i < '?' || i > '~') return;
  uint32_t const bits = i - '?', stride = cv->w;
  if (c->sy + 6 > c->sh) {                          // a band's first touch clears its rows
    uint32_t const to = c->sy + 6 < cv->h ? c->sy + 6 : cv->h;
    for (uint32_t y = c->sh; y < to; y++)
      for (uint32_t x = 0; x < stride; x++) cb_spx(c)[cv->off + y * stride + x] = 0;
    if (to > c->sh) c->sh = to; }
  uint32_t const ink = 0xff000000u | cb_pal(c)[c->sreg];
  for (uint32_t n = 0; n < c->srep && c->sx + n < stride; n++) {
    uint32_t const x = c->sx + n;
    for (uint32_t b = 0; b < 6; b++)
      if (bits >> b & 1 && c->sy + b < cv->h) cb_spx(c)[cv->off + (c->sy + b) * stride + x] = ink;
    if (bits && x + 1 > c->sw) c->sw = x + 1; }
  c->sx += c->srep, c->srep = 1; }

static void cb_ind(struct cb *c);

// picture k's tiles at the cursor, a text row a cell row, scrolling as text would. the
// cursor then ends under it at its first column (sixel), or beside its last tile on its
// last row (kitty), or stays where it was (kitty's C=1)
enum { cb_under_pic = 0, cb_beside_pic = 1, cb_stay = 2 };
static void cb_place(struct cb *c, uint32_t k, int after) {
  struct cb_img const *im = cb_img(c, k);
  if (!im) return;
  uint32_t const cs = c->cols, col0 = c->wpos % cs, save = c->wpos;
  uint32_t tw = (im->w + c->cw - 1u) / c->cw, th = (im->h + c->ch - 1u) / c->ch;
  if (tw > 256) tw = 256;
  if (th > 256) th = 256;
  if (col0 + tw > cs) tw = cs - col0;
  c->flag &= (uint16_t) ~cb_pend;
  for (uint32_t ty = 0; ty < th; ty++) {
    if (ty) cb_ind(c);
    uint32_t const rb = c->wpos - c->wpos % cs;
    for (uint32_t tx = 0; tx < tw; tx++) {
      uint32_t const p = rb + col0 + tx;
      cb_unpair(c, p);
      cb_pen(c, 0, &c->cb[p]);
      c->cb[p].g = cb_tile(k, tx, ty); }
    cb_mend(c, rb / cs), cb_dirt(c, rb / cs, rb / cs); }
  if (after == cb_stay) { c->wpos = save; return; }
  if (after == cb_beside_pic) {
    uint32_t const rb = c->wpos - c->wpos % cs, end = col0 + tw;
    if (end < cs) c->wpos = rb + end;
    else { c->wpos = rb + cs - 1u; if (c->flag & cb_wrap) c->flag |= cb_pend; }
    return; }
  cb_ind(c);
  c->wpos = c->wpos - c->wpos % cs + col0; }

// the string's end: the canvas packed to its own width becomes the slot's picture, and its
// tiles land at the cursor, a text row a cell row, scrolling as text would. the cursor
// ends under the picture, at the column it started in
static void cb_six_close(struct cb *c) {
  if (c->sm) cb_six(c, 0);
  uint32_t const k = c->sslot;
  c->sslot = 0;
  if (!k) return;
  struct cb_img *im = cb_imgs(c) + k;
  uint32_t const w = c->sw, h = c->sh < im->h ? c->sh : im->h, stride = im->w;
  if (!w || !h) return;
  uint32_t *px = cb_spx(c);
  for (uint32_t y = 1; y < h; y++)
    for (uint32_t x = 0; x < w; x++) px[im->off + y * w + x] = px[im->off + y * stride + x];
  im->w = w, im->h = h, im->live = 1, im->gen = cb_gen(c);
  c->stop = im->off + w * h;
  cb_place(c, k, 0); }

// --- kitty graphics, a subset: APC G key=value,..;base64 ST -----------------------------
// a=t stores an image by id, a=T stores and places it, a=p places one stored, a=q asks
// whether it would take one, a=d deletes (all, or by id). f=24 and f=32 raw pixels, or
// f=100 a PNG (png.c), direct (t=d), sent whole or in m=1 chunks; c and r size the
// placement in cells, nearest pixel. compression and the other media answer an error. an image a kitty id holds outlives
// its placements until a delete or a store too full to keep it.
static void cb_kit_reply(struct cb *c, int ok, char const *err) {
  if (!c->ki || c->kq >= 2 || (ok && c->kq == 1)) return;
  cb_say(c, "\033_Gi="), cb_sayn(c, c->ki), cb_say(c, ";"), cb_say(c, ok ? "OK" : err), cb_say(c, "\033\\"); }

static void cb_kit_open(struct cb *c) {
  c->kkey = 0, c->kval = 0, c->kvc = 0, c->kacc = 0, c->kn = 0, c->kpad = 0, c->km = 0;
  if (c->kopen) return;                      // a chunk: only m and q are its own
  c->ka = 't', c->kf = 32, c->ks = c->kv = c->ki = c->kc = c->kr = 0;
  c->kq = 0, c->kcur = 0, c->kd = 'a', c->kt = 'd', c->ko = 0; }

static void cb_kit_key(struct cb *c) {
  uint32_t const v = c->kval;
  uint8_t const k = c->kkey, ch = c->kvc;
  c->kkey = 0, c->kval = 0, c->kvc = 0;
  if (!k || (c->kopen && k != 'm' && k != 'q')) return;
  switch (k) {
   case 'a': c->ka = ch; break;   case 'd': c->kd = ch; break;
   case 't': c->kt = ch; break;   case 'o': c->ko = ch; break;
   case 'f': c->kf = (uint8_t) v; break;   case 's': c->ks = v; break;
   case 'v': c->kv = v; break;    case 'i': c->ki = v; break;
   case 'm': c->km = (uint8_t) v; break;   case 'q': c->kq = (uint8_t) v; break;
   case 'c': c->kc = v; break;    case 'r': c->kr = v; break;
   case 'C': c->kcur = (uint8_t) v; break;
   default: break; } }

// a free slot with room for n words at the store's top: the sweep first keeps what ids
// hold, then, pressed, lets it go. 0 for none
static uint32_t cb_kit_slot(struct cb *c, uint32_t n) {
  for (int ids = 1; ids >= 0; ids--) {
    cb_sweep(c, ids);
    uint32_t k = 1;
    while (k < cb_nimg && cb_imgs(c)[k].live) k++;
    if (k < cb_nimg && n <= cb_words(c) - c->stop) return k; }
  return 0; }

// a copy of picture k at c x r cells (one of them 0: kept to the aspect), nearest pixel
static uint32_t cb_kit_scale(struct cb *c, uint32_t k) {
  struct cb_img const *im = cb_img(c, k);
  if (!im || (!c->kc && !c->kr)) return k;
  uint32_t W = c->kc * c->cw, H = c->kr * c->ch;
  if (!W) W = im->w * H / im->h;
  if (!H) H = im->h * W / im->w;
  if (W > 256u * c->cw) W = 256u * c->cw;
  if (H > 256u * c->ch) H = 256u * c->ch;
  if (!W || !H) return k;
  // no sweep here: k itself may be one no cell names yet
  uint32_t k2 = 1;
  while (k2 < cb_nimg && cb_imgs(c)[k2].live) k2++;
  if (k2 == cb_nimg || (uint64_t) W * H > cb_words(c) - c->stop) return k;
  uint32_t *px = cb_spx(c);
  uint32_t const off = c->stop;
  for (uint32_t y = 0; y < H; y++)
    for (uint32_t x = 0; x < W; x++)
      px[off + y * W + x] = px[im->off + (uint64_t) y * im->h / H * im->w + (uint64_t) x * im->w / W];
  cb_imgs(c)[k2] = (struct cb_img) { off, W, H, 1, 0, cb_gen(c) };
  c->stop = off + W * H;
  return k2; }

static void cb_kit_show(struct cb *c, uint32_t k) {
  cb_place(c, cb_kit_scale(c, k), c->kcur == 1 ? cb_stay : cb_beside_pic); }

// the delete: every placement, or every one of image i (whose store then goes too)
static void cb_kit_del(struct cb *c) {
  int const byid = c->kd == 'i' || c->kd == 'I';
  if (byid && !c->ki) return;
  struct cb_img *im = cb_imgs(c);
  for (uint32_t i = 0, n = (uint32_t) c->rows * c->cols; i < n; i++) {
    uint32_t const g = c->cb[i].g;
    if (!(g & cb_pic) || (byid && im[cb_tslot(g)].id != c->ki)) continue;
    c->cb[i].g = 0;
    cb_dirt(c, i / c->cols, i / c->cols); }
  for (uint32_t k = 1; k < cb_nimg; k++) if (!byid || im[k].id == c->ki) im[k].id = 0; }

// the keys are in: act, or open the transfer the payload fills
static void cb_kit_begin(struct cb *c) {
  if (c->kopen) return;
  if (c->ka == 'd') return cb_kit_del(c);
  if (c->ka == 'p') {
    for (uint32_t k = 1; k < cb_nimg; k++)
      if (c->ki && cb_imgs(c)[k].id == c->ki && cb_img(c, k)) return cb_kit_show(c, k), cb_kit_reply(c, 1, 0);
    return cb_kit_reply(c, 0, "ENOENT:no such image"); }
  if (c->ka != 't' && c->ka != 'T' && c->ka != 'q') return cb_kit_reply(c, 0, "EINVAL:action");
  if (c->kt != 'd' || c->ko) return cb_kit_reply(c, 0, "EINVAL:medium");
  if (c->kf != 24 && c->kf != 32 && c->kf != 100) return cb_kit_reply(c, 0, "EINVAL:format");
  // a PNG's size is its own: it takes the store's whole top to land in, pixels and all
  int const png = c->kf == 100;
  if (!png && (!c->ks || !c->kv || c->ks > 65536u || c->kv > 65536u)) return cb_kit_reply(c, 0, "EINVAL:size");
  uint32_t const k = cb_kit_slot(c, png ? 1u : c->ks * c->kv);
  if (!k) return cb_kit_reply(c, 0, "ENOSPC:store full");
  cb_imgs(c)[k] = (struct cb_img) { c->stop, png ? 0u : c->ks, png ? 0u : c->kv, 0, c->ki, 0 };
  c->kslot = k, c->kpix = 0, c->kpx = 0, c->kbyte = 0, c->kopen = 1; }

static void cb_kit_byte(struct cb *c, uint32_t b) {
  if (c->kf == 100) {                        // a PNG's bytes, raw, at the store's top
    uint32_t const off = cb_imgs(c)[c->kslot].off;
    if (off < cb_words(c) && c->kpix < (cb_words(c) - off) * 4u)
      ((uint8_t*) (cb_spx(c) + off))[c->kpix] = (uint8_t) b;
    c->kpix++;
    return; }
  uint32_t const bpp = c->kf / 8u;
  c->kpx = c->kpx << 8 | b;
  if (++c->kbyte < bpp) return;
  uint32_t const a = bpp == 4 ? c->kpx & 255u : 255u, rgb = bpp == 4 ? c->kpx >> 8 : c->kpx;
  struct cb_img const *im = cb_imgs(c) + c->kslot;
  if (c->kpix < im->w * im->h && im->off + c->kpix < cb_words(c))
    cb_spx(c)[im->off + c->kpix] = a >= 128 ? 0xff000000u | (rgb & 0xffffffu) : 0;
  c->kpix++, c->kpx = 0, c->kbyte = 0; }

static void cb_kit_b64(struct cb *c, uint8_t i) {
  if (!c->kopen) return;
  uint32_t v;
  if (i >= 'A' && i <= 'Z') v = i - 'A';
  else if (i >= 'a' && i <= 'z') v = i - 'a' + 26u;
  else if (i >= '0' && i <= '9') v = i - '0' + 52u;
  else if (i == '+') v = 62;
  else if (i == '/') v = 63;
  else if (i == '=') v = 0, c->kpad++;
  else return;
  c->kacc = c->kacc << 6 | v;
  if (++c->kn < 4) return;
  uint32_t const n = c->kpad < 3 ? 3u - c->kpad : 0;
  for (uint32_t j = 0; j < n; j++) cb_kit_byte(c, c->kacc >> (16 - 8 * j) & 255u);
  c->kacc = 0, c->kn = 0, c->kpad = 0; }

// the command's end: a chunk waits for the next; the last one finishes what it asked
static void cb_kit_end(struct cb *c) {
  if (c->kn > 1) {                           // an unpadded tail: its whole bytes
    uint32_t const n = c->kn - 1u;
    c->kacc <<= 6 * (4 - c->kn);
    for (uint32_t j = 0; j < n; j++) cb_kit_byte(c, c->kacc >> (16 - 8 * j) & 255u); }
  c->kacc = 0, c->kn = 0, c->kpad = 0;
  if (!c->kopen || c->km == 1) return;
  c->kopen = 0;
  uint32_t const k = c->kslot;
  struct cb_img *im = cb_imgs(c) + k;
  if (c->kf == 100) {                        // the PNG laid out as pixels where its bytes were
    uintptr_t const cap = im->off < cb_words(c) ? (uintptr_t) (cb_words(c) - im->off) * 4u : 0;
    uint32_t w = 0, h = 0;
    if (c->kpix > cap) return cb_kit_reply(c, 0, "ENOSPC:store full");
    if (cb_png((uint8_t*) (cb_spx(c) + im->off), c->kpix, cap, &w, &h)) return cb_kit_reply(c, 0, "EBADPNG:png");
    im->w = w, im->h = h; }
  else if (c->kpix < im->w * im->h) return cb_kit_reply(c, 0, "EINVAL:short");
  if (c->ka == 'q') return cb_kit_reply(c, 1, 0);          // asked, not kept
  if (c->ki) for (uint32_t j = 1; j < cb_nimg; j++) if (j != k && cb_imgs(c)[j].id == c->ki) cb_imgs(c)[j].id = 0;
  im->live = 1, im->gen = cb_gen(c), c->stop = im->off + im->w * im->h;
  if (c->ka == 'T') cb_kit_show(c, k);
  cb_kit_reply(c, 1, 0); }

// RIS: everything back to the floor -- pens, faces, region, modes,
// cursor, ground. LNM survives: the newline discipline belongs to the
// console (the kernel set it at boot), not to the program resetting.
static void cb_ris(struct cb *c) {
  uint16_t lnm = c->flag & cb_lnm;
  c->gset = c->sgset = 0;
  c->cur_fg = c->cur_bg = cb_ink(cb_def, 0), c->cur_face = 0;
  c->top = 0, c->bot = c->rows - 1u;
  c->flag = (uint16_t) (cb_show | cb_wrap | lnm);
  c->wpos = c->spos = 0;
  c->esc = 0, c->pn = 0, c->arg = 0, c->on = 0, c->un = 0, c->ol = 0, c->sslot = 0, c->sm = 0, c->kopen = 0;
  cb_clear(c); }

static void cb_save(struct cb *c) {  // DECSC: cursor + pen + charsets
  c->spos = c->wpos, c->sgset = c->gset;
  c->sfg = c->cur_fg, c->sbg = c->cur_bg, c->sface = c->cur_face; }

static void cb_restore(struct cb *c) {  // DECRC
  c->wpos = c->spos, c->gset = c->sgset, c->flag &= (uint16_t) ~cb_pend;
  c->cur_fg = c->sfg, c->cur_bg = c->sbg, c->cur_face = c->sface; }

// DECSTR, the soft reset: the pen, the region, origin mode, the saved cursor and the
// charsets back to the floor; the screen and the cursor stay
static void cb_decstr(struct cb *c) {
  c->cur_fg = c->cur_bg = cb_ink(cb_def, 0), c->cur_face = 0;
  c->top = 0, c->bot = c->rows - 1u, c->flag &= (uint16_t) ~cb_origin;
  c->gset = c->sgset = 0, c->spos = 0, c->sfg = c->sbg = c->cur_fg, c->sface = 0; }

// SGR: the pen. colours by index (8 + bright 8 + 256) or 38;2 rgb, faces in
// the glyph word's top byte.
static uint32_t cb_chan(uint16_t v) { return v > 255 ? 255u : v; }
static void cb_sgr(struct cb *c) {
  static uint8_t const on[10] = { 0, cb_bold, cb_dim, cb_ital, cb_under, cb_blink, 0, cb_rev, cb_hide, cb_strike };
  for (uint8_t k = 0; k < c->pn; k++) {
    uint16_t p = c->pv[k];
    if (p == 0) c->cur_fg = c->cur_bg = cb_ink(cb_def, 0), c->cur_face = 0;
    else if (p < 10) c->cur_face |= on[p];
    else if (p == 22) c->cur_face &= (uint8_t) ~(cb_bold | cb_dim);
    else if (p >= 23 && p <= 29 && p != 26) c->cur_face &= (uint8_t) ~on[p - 20];
    else if (p >= 30 && p <= 37) c->cur_fg = cb_ink(cb_idx, p - 30);
    else if (p == 39) c->cur_fg = cb_ink(cb_def, 0);
    else if (p >= 40 && p <= 47) c->cur_bg = cb_ink(cb_idx, p - 40);
    else if (p == 49) c->cur_bg = cb_ink(cb_def, 0);
    else if (p >= 90 && p <= 97) c->cur_fg = cb_ink(cb_idx, p - 90 + 8);
    else if (p >= 100 && p <= 107) c->cur_bg = cb_ink(cb_idx, p - 100 + 8);
    else if ((p == 38 || p == 48) && k + 2 < c->pn && c->pv[k + 1] == 5) {
      uint32_t v = cb_ink(cb_idx, c->pv[k + 2] & 255);
      if (p == 38) c->cur_fg = v; else c->cur_bg = v;
      k += 2; }
    else if ((p == 38 || p == 48) && k + 4 < c->pn && c->pv[k + 1] == 2) {
      uint32_t v = cb_ink(cb_rgb, cb_chan(c->pv[k + 2]) << 16 | cb_chan(c->pv[k + 3]) << 8
                                  | cb_chan(c->pv[k + 4]));
      if (p == 38) c->cur_fg = v; else c->cur_bg = v;
      k += 4; } } }

// DECRQM (CSI ? Ps $ p, CSI Ps $ p): a mode's state as CSI ? Ps ; s $ y -- 1 set, 2 reset,
// 0 one quay does not know
static void cb_rqm(struct cb *c, int priv) {
  uint16_t const p = c->pv[0], f = c->flag;
  int s = 0;
  if (!priv) s = p == 20 ? (f & cb_lnm ? 1 : 2) : 0;
  else if (p == 7) s = f & cb_wrap ? 1 : 2;
  else if (p == 25) s = f & cb_show ? 1 : 2;
  else if (p == 6) s = f & cb_origin ? 1 : 2;
  else if (p == 9 || p == 1000 || p == 1002 || p == 1003)
    s = (f & cb_mice) == (p == 9 ? cb_mx10 : p == 1000 ? cb_mbtn : p == 1002 ? cb_mdrag : cb_many) ? 1 : 2;
  else if (p == 1006) s = f & cb_msgr ? 1 : 2;
  else if (p == 2004) s = f & cb_paste ? 1 : 2;
  else if (p == 2027) s = f & cb_gc ? 1 : 2;
  else if (p == 47 || p == 1047 || p == 1049) s = f & cb_alt ? 1 : 2;
  cb_say(c, priv ? "\033[?" : "\033["), cb_sayn(c, p), cb_say(c, ";"), cb_sayn(c, (uint32_t) s), cb_say(c, "$y"); }

// DEC private / ANSI modes (CSI ? .. h/l and CSI .. h/l). the alternate screen
// (47/1047/1049): the main grid waits in the twin and a cleared grid takes its place,
// then comes back whole on the way out. a screen laid with no twin clears instead.
static void cb_mode(struct cb *c, int priv, int on) {
  for (uint8_t k = 0; k < c->pn; k++) {
    uint16_t p = c->pv[k];
    if (!priv) {
      if (p == 20) c->flag = on ? c->flag | cb_lnm : c->flag & (uint16_t) ~cb_lnm; }
    else if (p == 7) c->flag = on ? c->flag | cb_wrap : c->flag & (uint16_t) ~cb_wrap;
    else if (p == 25) c->flag = on ? c->flag | cb_show : c->flag & (uint16_t) ~cb_show;
    else if (p == 9 || p == 1000 || p == 1002 || p == 1003) {       // one tracking at a time
      uint16_t const m = p == 9 ? cb_mx10 : p == 1000 ? cb_mbtn : p == 1002 ? cb_mdrag : cb_many;
      c->flag = (uint16_t) ((c->flag & ~cb_mice) | (on ? m : 0)); }
    else if (p == 1006) c->flag = on ? c->flag | cb_msgr : c->flag & (uint16_t) ~cb_msgr;
    else if (p == 2004) c->flag = on ? c->flag | cb_paste : c->flag & (uint16_t) ~cb_paste;
    else if (p == 2027) c->flag = on ? c->flag | cb_gc : c->flag & (uint16_t) ~cb_gc;
    else if (p == 6) {
      c->flag = on ? c->flag | cb_origin : c->flag & (uint16_t) ~cb_origin;
      cb_goto(c, 0, 0); }
    else if (p == 47 || p == 1047 || p == 1049) {
      struct cb_cell *tw = cb_twins(c);
      uint32_t const n = (uint32_t) c->rows * c->cols;
      if (on) {
        if (tw && !(c->flag & cb_alt)) for (uint32_t i = 0; i < n; i++) tw[i] = c->cb[i];
        cb_save(c), cb_clear(c), c->wpos = 0, c->flag = (uint16_t) ((c->flag & ~cb_pend) | cb_alt); }
      else {
        if (tw && c->flag & cb_alt) for (uint32_t i = 0; i < n; i++) c->cb[i] = tw[i];
        else cb_clear(c);
        cb_dirt(c, 0, c->rows - 1u), cb_restore(c), c->flag &= (uint16_t) ~cb_alt; } } } }

// the CSI dispatch, one final byte at a time. n/m: the first two
// parameters with their traditional default of 1.
static void cb_csi(struct cb *c, uint8_t i) {
  uint32_t n = c->pv[0] ? c->pv[0] : 1, m = c->pn > 1 && c->pv[1] ? c->pv[1] : 1;
  uint32_t cs = c->cols, r = c->wpos / cs, col = c->wpos % cs;
  uint32_t rb = r * cs, re = rb + cs;  // this row's span
  int priv = c->flag & cb_priv, gt = c->flag & cb_gt;
  c->flag &= (uint16_t) ~(cb_priv | cb_gt);
  switch (i) {
   case 'A': { uint32_t lo = r >= c->top ? c->top : 0;
    cb_cur(c, r > lo + n ? r - n : lo, col), c->flag &= (uint16_t) ~cb_pend; return; }
   case 'B': case 'e': { uint32_t hi = r <= c->bot ? c->bot : c->rows - 1u;
    cb_cur(c, r + n < hi ? r + n : hi, col), c->flag &= (uint16_t) ~cb_pend; return; }
   case 'C': c->wpos = col + n < cs ? c->wpos + n : re - 1u;
    c->flag &= (uint16_t) ~cb_pend; return;
   case 'D': c->wpos = col > n ? c->wpos - n : rb;
    c->flag &= (uint16_t) ~cb_pend; return;
   case 'E': { uint32_t hi = r <= c->bot ? c->bot : c->rows - 1u;
    cb_cur(c, r + n < hi ? r + n : hi, 0), c->flag &= (uint16_t) ~cb_pend; return; }
   case 'F': { uint32_t lo = r >= c->top ? c->top : 0;
    cb_cur(c, r > lo + n ? r - n : lo, 0), c->flag &= (uint16_t) ~cb_pend; return; }
   case 'G': case '`': c->wpos = rb + (n - 1u < cs ? n - 1u : cs - 1u);
    c->flag &= (uint16_t) ~cb_pend; return;
   case 'd': return cb_goto(c, n - 1u, col);
   case 'H': case 'f': return cb_goto(c, n - 1u, m - 1u);
   case 'J': { if (c->pv[0] == 3) return cb_hist(c, c->hl), cb_dirt(c, 0, c->rows - 1u);
    struct cb_cell e; cb_pen(c, 0, &e); uint32_t all = (uint32_t) c->rows * cs;
    uint32_t lo = c->pv[0] == 1 ? 0 : c->wpos, hi = c->pv[0] == 1 ? c->wpos + 1u : all;
    if (c->pv[0] >= 2) lo = 0, hi = all;
    for (uint32_t p = lo; p < hi; p++) c->cb[p] = e;
    if (hi > lo) cb_mend(c, lo / cs), cb_mend(c, (hi - 1u) / cs), cb_dirt(c, lo / cs, (hi - 1u) / cs);
    return; }
   case 'K': { struct cb_cell e; cb_pen(c, 0, &e);
    uint32_t lo = c->pv[0] == 1 ? rb : c->wpos, hi = c->pv[0] == 1 ? c->wpos + 1u : re;
    if (c->pv[0] >= 2) lo = rb, hi = re;
    for (uint32_t p = lo; p < hi; p++) c->cb[p] = e;
    cb_mend(c, r), cb_dirt(c, r, r);
    return; }
   case 'L': if (r >= c->top && r <= c->bot) cb_scdn(c, r, c->bot, n); return;
   case 'M': if (r >= c->top && r <= c->bot) cb_scup(c, r, c->bot, n); return;
   case '@': { if (n > cs - col) n = cs - col;
    struct cb_cell e; cb_pen(c, 0, &e);
    for (uint32_t p = re; p-- > c->wpos + n;) c->cb[p] = c->cb[p - n];
    for (uint32_t p = c->wpos, j = c->wpos + n; p < j; p++) c->cb[p] = e;
    cb_mend(c, r), cb_dirt(c, r, r);
    return; }
   case 'P': { if (n > cs - col) n = cs - col;
    struct cb_cell e; cb_pen(c, 0, &e);
    for (uint32_t p = c->wpos; p < re - n; p++) c->cb[p] = c->cb[p + n];
    for (uint32_t p = re - n; p < re; p++) c->cb[p] = e;
    cb_mend(c, r), cb_dirt(c, r, r);
    return; }
   case 'X': { if (n > cs - col) n = cs - col;
    struct cb_cell e; cb_pen(c, 0, &e);
    for (uint32_t p = c->wpos, j = c->wpos + n; p < j; p++) c->cb[p] = e;
    cb_mend(c, r), cb_dirt(c, r, r);
    return; }
   case 'S':
    if (!priv) return cb_scup(c, c->top, c->bot, n);
    // XTSMGRAPHICS: read (1) or read the most (4) of the registers (1) or the geometry (2)
    if (c->pn >= 2 && (c->pv[1] == 1 || c->pv[1] == 4) && cb_words(c)) {
      if (c->pv[0] == 1) return cb_say(c, "\033[?1;0;256S");
      if (c->pv[0] == 2) return cb_say(c, "\033[?2;0;"), cb_sayn(c, (uint32_t) c->cols * c->cw),
                              cb_say(c, ";"), cb_sayn(c, (uint32_t) c->rows * c->ch), cb_say(c, "S"); }
    cb_say(c, "\033[?"), cb_sayn(c, c->pv[0]), cb_say(c, ";3;0S");   // 3: a failure
    return;
   case 'T': return cb_scdn(c, c->top, c->bot, n);
   case 'r': if (!priv) {
     uint32_t t = c->pv[0] ? c->pv[0] : 1, b = c->pn > 1 && c->pv[1] ? c->pv[1] : c->rows;
     if (t < b && b <= c->rows) c->top = (uint16_t) (t - 1u), c->bot = (uint16_t) (b - 1u), cb_goto(c, 0, 0); }
    return;
   case 'm': return cb_sgr(c);
   case 'h': return cb_mode(c, priv, 1);
   case 'l': return cb_mode(c, priv, 0);
   case 'n':
    if (c->pv[0] == 6) cb_say(c, "\033["), cb_sayn(c, r + 1u), cb_say(c, ";"),
                       cb_sayn(c, col + 1u), cb_say(c, "R");
    else if (c->pv[0] == 5) cb_say(c, "\033[0n");
    return;
   case 'c':                                // DA: a VT220 with ansi colour, sixel where a store is
    return cb_say(c, gt ? "\033[>0;0;0c" : cb_words(c) ? "\033[?62;4;22c" : "\033[?62;22c");
   case 't':                                // the sizes a picture is fitted to
    if (c->pv[0] == 14) cb_say(c, "\033[4;"), cb_sayn(c, (uint32_t) c->rows * c->ch), cb_say(c, ";"),
                        cb_sayn(c, (uint32_t) c->cols * c->cw), cb_say(c, "t");
    else if (c->pv[0] == 16) cb_say(c, "\033[6;"), cb_sayn(c, c->ch), cb_say(c, ";"),
                             cb_sayn(c, c->cw), cb_say(c, "t");
    else if (c->pv[0] == 18) cb_say(c, "\033[8;"), cb_sayn(c, c->rows), cb_say(c, ";"),
                             cb_sayn(c, c->cols), cb_say(c, "t");
    return;
   case 's': return cb_save(c);
   case 'u': return cb_restore(c);
   default: return; } }  // anything else: politely nothing

// cb_put1 interprets a working VT subset, one folded byte at a time: C0
// controls (with LNM ruling \n), ESC 7/8/D/E/M/c/#8, CSI cursor addressing
// (A-H, f, G, d, E, F), erase (J 0-3, K 0-2, X), edit (@ P L M), scroll (S T,
// DECSTBM r), SGR colours + faces, DEC modes (autowrap, cursor, origin,
// the alternate screen), and DSR/DA replies via the reply queue.
// OSC/DCS bodies are swallowed whole; charset designators too. anything
// printable is stamped as a glyph with the current pen.
static void cb_put1(struct cb *c, uint8_t i) {
  switch (c->esc) {
   case 1:                                  // after ESC
    c->esc = 0;
    switch (i) {
     case '[': c->esc = 2, c->arg = 0, c->pn = 0, c->ci = 0;
      c->flag &= (uint16_t) ~(cb_priv | cb_junk | cb_gt); return;
     case ']': c->esc = 7, c->ol = 0; return;       // OSC: capture the head (colour asks answer)
     case 'P': c->esc = 9, c->pn = 0, c->arg = 0; return;  // DCS: its parameters, then its final
     case '^': c->esc = 3; return;                          // PM: swallow
     case '_': c->esc = 12; return;                         // APC: kitty's G, else swallowed
     case '(': c->esc = 4; return;          // G0's charset
     case ')': c->esc = 16; return;         // G1's
     case '*': case '+': c->esc = 17; return;  // G2 G3: designated and never invoked
     case '#': c->esc = 6; return;
     case '7': return cb_save(c);           // DECSC
     case '8': return cb_restore(c);        // DECRC
     case 'D': return cb_ind(c);            // IND
     case 'E': c->wpos -= c->wpos % c->cols; return cb_ind(c);  // NEL
     case 'M': return cb_ri(c);             // RI
     case 'c': return cb_ris(c);            // RIS
     case 'Z': return cb_say(c, "\033[?6c");
     default: return; }                     // '=' '>' and friends: nothing to keep
   case 2:                                  // within CSI ESC [ ...
    if (i == 27) { c->esc = 1; return; }    // a fresh ESC abandons the sequence
    if (i == 127) return;                   // DEL: nothing, anywhere
    if (i < ' ') return cb_ctl(c, i);       // C0 controls run even mid-sequence
    if (i >= '0' && i <= '9') {
      if (c->arg < 6553) c->arg = (uint16_t) (c->arg * 10 + (i - '0'));
      return; }
    if (i == ';' || i == ':') {              // ':' -- colon-form SGR subparameters
      if (c->pn < cb_pmax) c->pv[c->pn++] = c->arg;
      c->arg = 0;
      return; }
    if (i == '>') { c->flag |= cb_gt; return; }     // the secondary-DA marker
    if (i == '?' || i == '=' || i == '<') { c->flag |= cb_priv; return; }
    if (i <= '/') { c->flag |= cb_junk, c->ci = i; return; }  // an intermediate: kept for DECRQM
    if (c->pn < cb_pmax) c->pv[c->pn++] = c->arg;        // the final parameter
    c->esc = 0;
    if (c->flag & cb_junk) {
      int const priv = !!(c->flag & cb_priv);
      c->flag &= (uint16_t) ~(cb_junk | cb_priv | cb_gt);
      if (c->ci == '$' && i == 'p') cb_rqm(c, priv);
      if (c->ci == '!' && i == 'p') cb_decstr(c);
      return; }
    return cb_csi(c, i);
   case 3:                                  // a DCS/PM/APC body on its way to ST
    if (i == 7) c->esc = 0;
    else if (i == 27) c->esc = 5;
    return;
   case 5: c->esc = 0; return;              // the byte after ESC ends it (ST's backslash)
   case 7:                                  // an OSC body: head captured for the colour asks
    if (i == 7) { c->esc = 0; return cb_oscq(c); }
    if (i == 27) { c->esc = 8; return; }
    if (c->ol < 5) c->ob[c->ol++] = i; else c->ol = 6;
    return;
   case 8:                                  // OSC's ST tail
    c->esc = 0;
    if (i == '\\') return cb_oscq(c);
    return;
   case 4:                                  // G0 designated: 0 graphics, B (or any other) ascii
    c->esc = 0, c->gset = (uint8_t) (i == '0' ? c->gset | cb_g0 : c->gset & ~cb_g0); return;
   case 16:
    c->esc = 0, c->gset = (uint8_t) (i == '0' ? c->gset | cb_g1 : c->gset & ~cb_g1); return;
   case 17: c->esc = 0; return;
   case 9:                                  // a DCS's parameters: 'q' is sixel, anything else swallowed
    if (i == 27) { c->esc = 5; return; }
    if (i >= '0' && i <= '9') { if (c->arg < 6553) c->arg = (uint16_t) (c->arg * 10 + (i - '0')); return; }
    if (i == ';') { if (c->pn < cb_pmax) c->pv[c->pn++] = c->arg; c->arg = 0; return; }
    if (i < 0x40) { if (i >= 0x20) c->esc = 3; return; }   // an intermediate: none of ours
    if (c->pn < cb_pmax) c->pv[c->pn++] = c->arg;
    if (i != 'q') { c->esc = 3; return; }
    c->sp2 = (uint8_t) (c->pn > 1 ? c->pv[1] : 0), c->pn = 0, c->arg = 0;
    c->esc = 10;
    return cb_six_open(c);
   case 10:                                 // a sixel body, to ST
    if (i == 27) { c->esc = 11; return; }
    if (i == 0x18 || i == 0x1a) { c->esc = 0, c->sslot = 0, c->sm = 0; return; }   // CAN, SUB: dropped
    return cb_six(c, i);
   case 12:                                 // an APC's first byte: G is kitty graphics
    if (i == 'G') { cb_kit_open(c); c->esc = 13; return; }
    c->esc = i == 27 ? 5 : 3;
    return;
   case 13:                                 // kitty's keys, a=T,f=32,..: ; opens the payload
    if (i == 0x18 || i == 0x1a) { c->esc = 0, c->kopen = 0; return; }
    if (i == 27 || i == ';') { cb_kit_key(c), cb_kit_begin(c); c->esc = i == 27 ? 15 : 14; return; }
    if (i == ',') return cb_kit_key(c);
    if (i == '=') return;
    if (i >= '0' && i <= '9' && c->kkey) { if (c->kval < 429496729u) c->kval = c->kval * 10u + (i - '0'); return; }
    if (i > ' ' && i < 0x7f) { if (!c->kkey) c->kkey = i; else c->kvc = i; }
    return;
   case 14:                                 // kitty's payload, base64 to ST
    if (i == 27) { c->esc = 15; return; }
    if (i == 0x18 || i == 0x1a) { c->esc = 0, c->kopen = 0; return; }
    return cb_kit_b64(c, i);
   case 15:                                 // ESC inside kitty: \ ends it; anything else ends it too, and begins
    cb_kit_end(c), c->esc = 0;
    if (i == '\\') return;
    c->esc = 1;
    return cb_put1(c, i);
   case 11:                                 // ESC inside sixel: \ ends it; anything else ends it too, and begins
    cb_six_close(c), c->esc = 0;
    if (i == '\\') return;
    c->esc = 1;
    return cb_put1(c, i);
   case 6:                                  // ESC # ...
    if (i == '8') {                         // DECALN: the E screen, region home
      c->top = 0, c->bot = c->rows - 1u, c->wpos = 0, c->flag &= (uint16_t) ~cb_pend;
      cb_fill(c, 'E'); }
    c->esc = 0;
    return;
   default:
    if (i == 27) { c->esc = 1; return; }    // ESC: begin a sequence
    if (i == 127) return;                   // DEL: nothing, anywhere
    if (i < ' ') return cb_ctl(c, i);
    if (i >= 0x5f && i <= 0x7e && c->gset & (c->gset & cb_so ? cb_g1 : cb_g0))
      return cb_glyph(c, cb_decgfx[i - 0x5f]);              // DEC graphics in GL
    return cb_glyph(c, i); } }

// the built-in fonts draw the cp437 page (cp437.h, laid by quay.l): a codepoint's
// glyph is ascii as itself, else the fold's -- the classic page plus aliases that
// MEAN one of ours. anything else, astral planes included, wears the ■.
int cb_437x(uint32_t cp) {
  if (cp < 0x7f) return (int) cp;
  uintptr_t lo = 0, hi = sizeof cp437_fold / sizeof *cp437_fold;
  while (lo < hi) {
    uintptr_t m = (lo + hi) / 2;
    uint32_t k = cp437_fold[m] >> 8;
    if (k == cp) return (int) (cp437_fold[m] & 255u);
    if (k < cp) lo = m + 1; else hi = m; }
  return -1; }

uint8_t cb_437(uint32_t cp) { int g = cb_437x(cp); return g < 0 ? 0xfe : (uint8_t) g; }

static uint32_t cb_rd16(uint8_t const *b, uintptr_t i) { return (uint32_t) b[i] | (uint32_t) b[i + 1] << 8; }

// a font is 12 bytes of head, the directory, the pages and the glyphs, each index in
// range: a page names a real page, a glyph a real glyph. anything else is no font
int cb_font_ok(uint8_t const *b, uintptr_t n) {
  if (!b || n < cb_qf_head + 2u * cb_qf_dir) return 0;
  if (b[0] != 'q' || b[1] != 'f' || b[2] != '1' || b[3] || b[4] != 8 || b[5] != 16) return 0;
  uint32_t const np = cb_rd16(b, 6), ng = cb_rd16(b, 8) | cb_rd16(b, 10) << 16;
  uintptr_t const pg0 = cb_qf_head + 2u * cb_qf_dir, gl0 = pg0 + (uintptr_t) np * 512u;
  if (np > cb_qf_dir || (uint64_t) n != gl0 + (uint64_t) ng * 32u) return 0;
  for (uint32_t d = 0; d < cb_qf_dir; d++) {
    uint32_t const p = cb_rd16(b, cb_qf_head + 2u * d);
    if (p != 0xffff && p >= np) return 0; }
  for (uintptr_t k = 0; k < (uintptr_t) np * 256u; k++)
    if (cb_rd16(b, pg0 + 2u * k) > ng) return 0;
  return 1; }

// cp's 16 rows in a vetted font, or 0
uint8_t const *cb_font_rows(uint8_t const *b, uint32_t cp) {
  if (!b || cp >= 0x110000u) return 0;
  uint32_t const np = cb_rd16(b, 6), p = cb_rd16(b, cb_qf_head + 2u * (cp >> 8));
  if (p == 0xffff) return 0;
  uintptr_t const pg0 = cb_qf_head + 2u * cb_qf_dir;
  uint32_t const gi = cb_rd16(b, pg0 + (uintptr_t) p * 512u + 2u * (cp & 255u));
  return gi ? b + pg0 + (uintptr_t) np * 512u + (uintptr_t) (gi - 1u) * 32u : 0; }

// the columns cp takes, off 'text's own runs (cpwidth.h, laid by quay.l): each entry
// cp << 2 | w opens a run of width w. below U+0300 everything printable is one
uint8_t cb_width(uint32_t cp) {
  if (cp < 0x300) return cp ? 1 : 0;
  uintptr_t lo = 0, hi = sizeof cpwidth / sizeof *cpwidth;
  while (hi - lo > 1) {
    uintptr_t m = (lo + hi) / 2;
    if (cpwidth[m] >> 2 <= cp) lo = m; else hi = m; }
  return (uint8_t) (cpwidth[lo] & 3u); }

// a cp437 glyph byte's codepoint: the page read forward
uint32_t cb_unfold(uint8_t g) { return cp437[g]; }

// a finished codepoint. C1 controls, surrogates and past-unicode land as U+FFFD, so
// nothing a cell holds can mean a control to a painter re-emitting it; mid-sequence
// it is a byte the parser speaks nothing for.
static void cb_uni(struct cb *c, uint32_t cp) {
  if (cp < 0xa0 || (cp >= 0xd800 && cp < 0xe000) || cp > 0x10ffff) cp = 0xfffd;
  if (c->esc) cb_put1(c, 0xfe);
  else cb_glyph(c, cp); }

// cb_putc: the byte door. utf-8 decodes here -- a lead opens a sequence
// (state rides in ucp/un), continuations accumulate, and the finished
// codepoint is the cell's. a torn sequence lands a U+FFFD and the tearing
// byte rides on; raw cp437 art goes through cb_stamp, which never interprets.
void cb_putc(struct cb *c, char _i) {
  uint8_t i = (uint8_t) _i;
  if (c->un) {                                   // continuations expected
    if (i >= 0x80 && i < 0xc0) {
      c->ucp = c->ucp << 6 | (i & 0x3fu);
      if (--c->un) return;
      return cb_uni(c, c->ucp); }                // complete: deliver
    c->un = 0;                                   // torn: a U+FFFD, and i rides on
    cb_uni(c, 0xfffd); }
  if (i >= 0x80) {
    if (i >= 0xc2 && i < 0xe0) { c->un = 1, c->ucp = i & 0x1fu; return; }
    if (i >= 0xe0 && i < 0xf0) { c->un = 2, c->ucp = i & 0x0fu; return; }
    if (i >= 0xf0 && i < 0xf5) { c->un = 3, c->ucp = i & 0x07u; return; }
    return cb_uni(c, 0xfffd); }                  // stray continuation / bad lead
  cb_put1(c, i); }
