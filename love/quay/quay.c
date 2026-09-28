#include "quay.h"
#include "cp437.h"
#include "cpwidth.h"

// *e <- a cell of codepoint cp in the current pen. the blank a clear or scroll
// leaves behind is cp 0 in the current pen,
// so erased ground keeps the program's background (BCE).
static void cb_pen(struct cb const *c, uint32_t cp, struct cb_cell *e) {
  e->g = cb_gw(cp, c->cur_face), e->fg = c->cur_fg, e->bg = c->cur_bg; }

// mark rows r1..r2 dirty (inclusive; rows past 255 fold onto bit 255).
static void cb_dirt(struct cb *c, uint32_t r1, uint32_t r2) {
  if (r1 > 255) r1 = 255;
  if (r2 > 255) r2 = 255;
  for (uint32_t r = r1; r <= r2; r++) c->dmg[r >> 5] |= (uint32_t) 1 << (r & 31); }

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
    c->cb[i].g &= 0x7fffffu, c->cb[i].fg = c->cb[i].bg = cb_ink(cb_def, 0);
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

void cb_open(struct cb *c, uint16_t rows, uint16_t cols) {
  c->wpos = c->spos = 0;
  c->rows = rows, c->cols = cols;
  c->flag = cb_show | cb_wrap;
  c->arg = 0, c->esc = 0, c->pn = 0, c->on = 0;
  c->ucp = 0, c->un = 0, c->ol = 0;
  for (int k = 0; k < 8; k++) c->dmg[k] = 0;
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

static void cb_scup(struct cb *c, uint32_t t, uint32_t b, uint32_t n) {
  if (!n) return;
  if (n > b - t + 1u) n = b - t + 1u;
  uint32_t cs = c->cols; struct cb_cell e; cb_pen(c, 0, &e);
  for (uint32_t i = t * cs, j = (b + 1u - n) * cs; i < j; i++) c->cb[i] = c->cb[i + n * cs];
  for (uint32_t i = (b + 1u - n) * cs, j = (b + 1u) * cs; i < j; i++) c->cb[i] = e;
  cb_dirt(c, t, b);
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
  char b[8]; int i = 8;
  do b[--i] = (char) ('0' + n % 10u), n /= 10u; while (n);
  while (i < 8 && c->on < cb_outn) c->out[c->on++] = (uint8_t) b[i++]; }

int cb_reply(struct cb *c, uint8_t *buf) {
  int n = c->on;
  for (int i = 0; i < n; i++) buf[i] = c->out[i];
  return c->on = 0, n; }

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
   default: return; } }  // BEL and the rest of C0: swallowed whole

// a printing glyph. a pending wrap fires FIRST (deferred autowrap: the
// glyph that landed on the last column left the cursor there; the next
// one carries it to a fresh line), then the stamp, then the step -- a
// stamp on the last column pends rather than moving, or overwrites in
// place with autowrap off.
// a wide char is two cells, a lead holding the codepoint and a tail holding 0; one
// that meets the last column wraps first (or steps back, autowrap off). a zero-width
// one is dropped. cb_unpair blanks the other half of whatever pair a write lands on.
static void cb_unpair(struct cb *c, uint32_t p) {
  uint32_t const cs = c->cols, col = p % cs, w = cb_wide(c->cb[p].g);
  if (w == cb_tail && col) c->cb[p - 1].g &= 0xff000000u;
  if (w == cb_lead && col + 1u < cs) c->cb[p + 1].g &= 0xff000000u; }

static void cb_glyph(struct cb *c, uint32_t cp) {
  uint32_t cs = c->cols, w = cb_width(cp);
  if (!w) return;
  if (w == 2 && cs < 2) w = 1;
  if (c->flag & cb_pend)
    c->flag &= (uint16_t) ~cb_pend, c->wpos -= c->wpos % cs, cb_ind(c);
  if (w == 2 && c->wpos % cs == cs - 1u) {
    if (c->flag & cb_wrap) c->wpos -= cs - 1u, cb_ind(c);
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

// RIS: everything back to the floor -- pens, faces, region, modes,
// cursor, ground. LNM survives: the newline discipline belongs to the
// console (the kernel set it at boot), not to the program resetting.
static void cb_ris(struct cb *c) {
  uint16_t lnm = c->flag & cb_lnm;
  c->cur_fg = c->cur_bg = cb_ink(cb_def, 0), c->cur_face = 0;
  c->top = 0, c->bot = c->rows - 1u;
  c->flag = (uint16_t) (cb_show | cb_wrap | lnm);
  c->wpos = c->spos = 0;
  c->esc = 0, c->pn = 0, c->arg = 0, c->on = 0, c->un = 0, c->ol = 0;
  cb_clear(c); }

static void cb_save(struct cb *c) {  // DECSC: cursor + pen
  c->spos = c->wpos;
  c->sfg = c->cur_fg, c->sbg = c->cur_bg, c->sface = c->cur_face; }

static void cb_restore(struct cb *c) {  // DECRC
  c->wpos = c->spos, c->flag &= (uint16_t) ~cb_pend;
  c->cur_fg = c->sfg, c->cur_bg = c->sbg, c->cur_face = c->sface; }

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

// DEC private / ANSI modes (CSI ? .. h/l and CSI .. h/l). the alternate
// screen (47/1047/1049) is save-and-clear / clear-and-restore over the
// ONE grid cb carries -- a full-screen program looks right; the ground
// it painted over is gone, the honest price of one buffer.
static void cb_mode(struct cb *c, int priv, int on) {
  for (uint8_t k = 0; k < c->pn; k++) {
    uint16_t p = c->pv[k];
    if (!priv) {
      if (p == 20) c->flag = on ? c->flag | cb_lnm : c->flag & (uint16_t) ~cb_lnm; }
    else if (p == 7) c->flag = on ? c->flag | cb_wrap : c->flag & (uint16_t) ~cb_wrap;
    else if (p == 25) c->flag = on ? c->flag | cb_show : c->flag & (uint16_t) ~cb_show;
    else if (p == 6) {
      c->flag = on ? c->flag | cb_origin : c->flag & (uint16_t) ~cb_origin;
      cb_goto(c, 0, 0); }
    else if (p == 47 || p == 1047 || p == 1049) {
      if (on) cb_save(c), cb_clear(c), c->wpos = 0, c->flag &= (uint16_t) ~cb_pend;
      else cb_clear(c), cb_restore(c); } } }

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
   case 'J': { struct cb_cell e; cb_pen(c, 0, &e); uint32_t all = (uint32_t) c->rows * cs;
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
   case 'S': return cb_scup(c, c->top, c->bot, n);
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
   case 'c':                                // DA: a VT102, honestly; >c the secondary ask
    return cb_say(c, gt ? "\033[>0;0;0c" : "\033[?6c");
   case 's': return cb_save(c);
   case 'u': return cb_restore(c);
   default: return; } }  // anything else: politely nothing

// cb_put1 interprets a working VT subset, one folded byte at a time: C0
// controls (with LNM ruling \n), ESC 7/8/D/E/M/c/#8, CSI cursor addressing
// (A-H, f, G, d, E, F), erase (J/K 0-2, X), edit (@ P L M), scroll (S T,
// DECSTBM r), SGR colours + faces, DEC modes (autowrap, cursor, origin,
// the one-grid alternate screen), and DSR/DA replies via the reply queue.
// OSC/DCS bodies are swallowed whole; charset designators too. anything
// printable is stamped as a glyph with the current pen.
static void cb_put1(struct cb *c, uint8_t i) {
  switch (c->esc) {
   case 1:                                  // after ESC
    c->esc = 0;
    switch (i) {
     case '[': c->esc = 2, c->arg = 0, c->pn = 0;
      c->flag &= (uint16_t) ~(cb_priv | cb_junk | cb_gt); return;
     case ']': c->esc = 7, c->ol = 0; return;       // OSC: capture the head (colour asks answer)
     case 'P': case '^': case '_': c->esc = 3; return;  // DCS/PM/APC: swallow
     case '(': case ')': case '*': case '+': c->esc = 4; return;  // charset designator
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
      if (c->pn < 8) c->pv[c->pn++] = c->arg;
      c->arg = 0;
      return; }
    if (i == '>') { c->flag |= cb_gt; return; }     // the secondary-DA marker
    if (i == '?' || i == '=' || i == '<') { c->flag |= cb_priv; return; }
    if (i <= '/') { c->flag |= cb_junk; return; }  // intermediates we don't speak
    if (c->pn < 8) c->pv[c->pn++] = c->arg;        // the final parameter
    c->esc = 0;
    if (c->flag & cb_junk) { c->flag &= (uint16_t) ~(cb_junk | cb_priv | cb_gt); return; }
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
   case 4: c->esc = 0; return;              // the designated charset: discarded
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
    return cb_glyph(c, i); } }

// the built-in faces draw the cp437 page (cp437.h, laid by quay.l): a codepoint's
// glyph is ascii as itself, else the fold's -- the classic page plus aliases that
// MEAN one of ours. anything else, astral planes included, wears the ■.
uint8_t cb_437(uint32_t cp) {
  if (cp < 0x7f) return (uint8_t) cp;
  uintptr_t lo = 0, hi = sizeof cp437_fold / sizeof *cp437_fold;
  while (lo < hi) {
    uintptr_t m = (lo + hi) / 2;
    uint32_t k = cp437_fold[m] >> 8;
    if (k == cp) return (uint8_t) cp437_fold[m];
    if (k < cp) lo = m + 1; else hi = m; }
  return 0xfe; }

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
