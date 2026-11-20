// src/love/audio/tones.c -- the tones doors: voices as small graphs of operators (tones.h, run
// by tonerun.c) for harp's timbres, doom's FM instruments, the gamelan's chimes. love lays each
// voice's operators and decides their envelopes (src/apps/harp/ops.l); this hands them the frames.
// (tones ops st n f0 rate) -> a float tray: n frames of left, n of right, then each operator's
//   last two outputs (for its feedback, handed back next time as st; any other st, () say, is
//   all at rest), then scratch; with ws a workspace of (tones-ws k), k >= the operators times n,
//   the scratch is laid there and left out of the answer. ops is a float tray of rows of tn_row
//   numbers, as tones.h lays them. | () for a bad argument
#include "love.h"
#include "tones.h"

_Static_assert(sizeof(tn_flo) == sizeof(flo_t), "tones.h's float is love's");

// a workspace: a state holding its magic and k, then k floats a run lays its scratch in, kept
// from one run to the next so the scratch is not made again. a str's bytes are word aligned,
// all a flo_t needs, wherever the gc lays it
#define TW_MAGIC ((uintptr_t) 0x746f6e65)
struct tw_head { uintptr_t magic, k; };
static uintptr_t tw_floats(word x) {
 struct str const *s = state_str(x);
 struct tw_head const *h = s ? (struct tw_head const *) s->bytes : 0;
 return h && s->len >= sizeof *h && h->magic == TW_MAGIC && (s->len - sizeof *h) / sizeof(flo_t) >= h->k ? h->k : 0; }
static flo_t *tw_data(word x) { return (flo_t *) (state_str(x)->bytes + sizeof(struct tw_head)); }

// (tones-ws k): a workspace for k floats of scratch
love_noinline static struct g *host_tones_ws(struct g *g) {
 word *a = g->sp;
 if (!(a[0] & 1) || getcharm(a[0]) < 0 || getcharm(a[0]) > 1 << 24) { a[0] = ZeroPoint; return g; }
 uintptr_t const k = (uintptr_t) getcharm(a[0]), n = sizeof(struct tw_head) + k * sizeof(flo_t);
 union u *s = new_state(&g, n, sizeof(struct tw_head));
 if (!s) return g;
 struct tw_head *h = (struct tw_head *) ((struct state *) s)->str->bytes;
 h->magic = TW_MAGIC, h->k = k;
 g->sp[0] = word(s);
 return g; }
static lvm(lvm_tones_ws) { LvmCallp(g, 0, host_tones_ws) }

love_noinline static struct g *host_tones(struct g *g) {
 word *a = g->sp;
 // (tones ops st n f0 rate ws)
 if (!galaxyp(a[0]) || tray(a[0])->type != love_R || !(a[2] & 1) || !isnum(a[3]) || !isnum(a[4])) { a[0] = ZeroPoint; return g; }
 intptr_t const n = getcharm(a[2]);
 uintptr_t const no = tray_nelem(tray(a[0])) / tn_row;
 if (n < 0 || n > 1 << 22 || no > 4096 || tray_nelem(tray(a[0])) % tn_row) { a[0] = ZeroPoint; return g; }
 int const inws = tw_floats(a[5]) >= no * (uintptr_t) n;
 uintptr_t const len = 2 * (uintptr_t) n + 2 * no + (inws ? 0 : no * (uintptr_t) n), w = b2w(tray_bytes(love_R, 1, len));
 if (!ok(g = have(g, w))) return g;
 a = g->sp;
 struct tray *out = ini_tray(bump(g, w), love_R, 1);
 out->shape[0] = len;
 // the workspace read after the allocation, which may move it
 flo_t *d = tray_data(out), *L = d, *R = d + n, *st = d + 2 * n, *sc = inws ? tw_data(a[5]) : st + 2 * no;
 for (uintptr_t i = 0; i < 2 * (uintptr_t) n; i++) d[i] = 0;
 flo_t const *ops = tray_data(tray(a[0])), rate = toflo(a[4]);
 int64_t const f0 = (int64_t) toflo(a[3]);
 if (rate <= 0) { a[0] = ZeroPoint; return g; }
 // the outputs carried in, read after the allocation, which may move them
 word const s0 = a[1];
 int const carried = galaxyp(s0) && tray(s0)->type == love_R && tray_nelem(tray(s0)) == 2 * no;
 for (uintptr_t j = 0; j < 2 * no; j++) st[j] = carried ? tray_get_flo(tray(s0), j) : 0;
 tones_run(ops, no, st, n, f0, rate, L, R, sc);
 a[0] = word(out);
 return g; }
static lvm(lvm_tones) { LvmCallp(g, 5, host_tones) }

// (mixall ps n): 2n frames, left then right, the sum of each piece [y gl gr o] of the list ps in
// order: y's frame o + i at i where it falls in y's first n, at gl and gr. a side whose gain
// is 0 is not touched; a piece that is not one is skipped
love_noinline static struct g *host_mixall(struct g *g) {
 word *a = g->sp;
 if (!(a[1] & 1)) { a[0] = ZeroPoint; return g; }
 intptr_t const n = getcharm(a[1]);
 if (n < 0 || n > 1 << 22) { a[0] = ZeroPoint; return g; }
 uintptr_t const w = b2w(tray_bytes(love_R, 1, 2 * (uintptr_t) n));
 if (!ok(g = have(g, w))) return g;
 a = g->sp;
 struct tray *out = ini_tray(bump(g, w), love_R, 1);
 out->shape[0] = 2 * (uintptr_t) n;
 flo_t *L = tray_data(out), *R = L + n;
 for (intptr_t i = 0; i < 2 * n; i++) L[i] = 0;
 for (word p = a[0]; chainp(p); p = B(p)) {
  word q = A(p), y, gl, gr, o;
  if (!chainp(q) || !chainp(B(q)) || !chainp(BB(q)) || !chainp(B(BB(q)))) continue;
  y = A(q), gl = AB(q), gr = A(BB(q)), o = A(B(BB(q)));
  if (!galaxyp(y) || tray(y)->type != love_R || !isnum(gl) || !isnum(gr) || !(o & 1)) continue;
  intptr_t const off = getcharm(o);
  if (tray_nelem(tray(y)) < (uintptr_t) n || off <= -n || off >= n) continue;
  // the frames i whose off + i falls in y's first n
  intptr_t const i0 = off < 0 ? -off : 0, i1 = off > 0 ? n - off : n;
  flo_t const *ys = (flo_t const *) tray_data(tray(y)) + off, fl = toflo(gl), fr = toflo(gr);
  if (fl != 0) for (intptr_t i = i0; i < i1; i++) L[i] += ys[i] * fl;
  if (fr != 0) for (intptr_t i = i0; i < i1; i++) R[i] += ys[i] * fr; }
 a[0] = word(out);
 return g; }
static lvm(lvm_mixall) { LvmCallp(g, 1, host_mixall) }

// --- a mixer: voices run in C chunk by chunk, so a song's chunk is one call ---
// (tones-voice R at end rate) -> a voice: rows R from frame at, heard till end, its outputs and
//   where it stands kept in the voice from call to call; asked out of order it reruns from at in
//   4096s, as ops.l's reach does. () for a bad argument
// (tones-echo v taps) -> v heard again at each [frames-behind gain] of taps, from what it laid
//   (play.l's echoed): a fresh voice, heard till end plus the farthest tap
// (tones-loop v k) -> v asked at frame f mod k, a fresh voice
// (tones-mix ps base n g ws) -> the sum of the pieces ps over the n frames from base, in order:
//   [v gl gr] a voice at gl and gr, its taps after it at gl and gr times theirs, or [y gl gr o]
//   as mixall's. g a number: 4n bytes, each frame left then right as 16-bit le, the sum times g
//   held to the range and cut toward zero, as play.l's pack. else 2n floats, left then right.
//   ws a (tones-ws k) its scratch is laid in when big enough. the voices are moved on
#define TV_MAGIC ((uintptr_t) 0x766f6963)
enum { tv_taps = 4, tv_step = 4096 };
struct tv_head {
 uintptr_t magic, no, ntap, hlen;
 int64_t at, end, next, loop, hnext;
 flo_t rate, tg[tv_taps];
 int64_t td[tv_taps]; };
// rows, then st (2 no), then the history ring (hlen), all flo_t
static struct tv_head *tv_of(word x) {
 struct str *s = state_str(x);
 struct tv_head *h = s && s->len >= sizeof(struct tv_head) ? (struct tv_head *) s->bytes : 0;
 return h && h->magic == TV_MAGIC ? h : 0; }
static flo_t *tv_rows(struct tv_head *h) { return (flo_t *) (h + 1); }
static flo_t *tv_st(struct tv_head *h) { return tv_rows(h) + h->no * tn_row; }
static flo_t *tv_hist(struct tv_head *h) { return tv_st(h) + 2 * h->no; }
static uintptr_t tv_bytes(uintptr_t no, uintptr_t hlen) {
 return sizeof(struct tv_head) + (no * tn_row + 2 * no + hlen) * sizeof(flo_t); }

love_noinline static struct g *host_tones_voice(struct g *g) {
 word *a = g->sp;
 if (!galaxyp(a[0]) || tray(a[0])->type != love_R || !(a[1] & 1) || !isnum(a[2]) || !isnum(a[3])) { a[0] = ZeroPoint; return g; }
 uintptr_t const no = tray_nelem(tray(a[0])) / tn_row;
 if (no == 0 || no > 4096 || tray_nelem(tray(a[0])) % tn_row || toflo(a[3]) <= 0) { a[0] = ZeroPoint; return g; }
 uintptr_t const nb = tv_bytes(no, 0);
 union u *s = new_state(&g, nb, nb);
 if (!s) return g;
 a = g->sp;
 struct tv_head *h = (struct tv_head *) ((struct state *) s)->str->bytes;
 h->magic = TV_MAGIC, h->no = no, h->at = getcharm(a[1]), h->end = (a[2] & 1) ? getcharm(a[2]) : (int64_t) toflo(a[2]), h->next = h->at, h->rate = toflo(a[3]);
 flo_t const *R = tray_data(tray(a[0]));
 for (uintptr_t i = 0; i < no * tn_row; i++) tv_rows(h)[i] = R[i];
 a[0] = word(s);
 return g; }
static lvm(lvm_tones_voice) { LvmCallp(g, 3, host_tones_voice) }

// a fresh copy of the voice atop the stack with room for hlen of history, or 0
static struct tv_head *tv_copy(struct g **gp, uintptr_t hlen, word *out) {
 struct tv_head *h = tv_of((*gp)->sp[0]);
 if (!h) return 0;
 uintptr_t const no = h->no, nb = tv_bytes(no, hlen);
 union u *s = new_state(gp, nb, nb);
 if (!s) return 0;
 h = tv_of((*gp)->sp[0]);   // read again: the allocation may move it
 struct tv_head *c = (struct tv_head *) ((struct state *) s)->str->bytes;
 uintptr_t const keep = tv_bytes(no, 0);
 for (uintptr_t i = 0; i < keep; i++) ((char *) c)[i] = ((char const *) h)[i];
 c->hlen = hlen;
 *out = word(s);
 return c; }

love_noinline static struct g *host_tones_echo(struct g *g) {
 word *a = g->sp;
 int64_t d[tv_taps], mx = 0;
 flo_t gn[tv_taps];
 uintptr_t k = 0;
 for (word p = a[1]; chainp(p); p = B(p)) {
  word q = A(p);
  if (k == tv_taps || !chainp(q) || !chainp(B(q)) || !(A(q) & 1) || !isnum(AB(q)) || getcharm(A(q)) < 1) { a[0] = ZeroPoint; return g; }
  d[k] = getcharm(A(q)), gn[k] = toflo(AB(q)), mx = d[k] > mx ? d[k] : mx, k++; }
 if (!tv_of(a[0]) || mx > 1 << 22) { a[0] = ZeroPoint; return g; }
 word o;
 struct tv_head *c = tv_copy(&g, (uintptr_t) mx + tv_step, &o);
 if (!ok(g)) return g;
 a = g->sp;
 if (!c) { a[0] = ZeroPoint; return g; }
 c->ntap = k, c->hnext = INT64_MIN;
 for (uintptr_t i = 0; i < k; i++) c->td[i] = d[i], c->tg[i] = gn[i];
 a[0] = o;
 return g; }
static lvm(lvm_tones_echo) { LvmCallp(g, 1, host_tones_echo) }

love_noinline static struct g *host_tones_loop(struct g *g) {
 word *a = g->sp;
 if (!tv_of(a[0]) || !(a[1] & 1) || getcharm(a[1]) < 1) { a[0] = ZeroPoint; return g; }
 int64_t const k = getcharm(a[1]);
 word o;
 struct tv_head *c = tv_copy(&g, tv_of(g->sp[0])->hlen, &o);
 if (!ok(g)) return g;
 a = g->sp;
 if (!c) { a[0] = ZeroPoint; return g; }
 c->loop = k;
 a[0] = o;
 return g; }
static lvm(lvm_tones_loop) { LvmCallp(g, 1, host_tones_loop) }

// the voice over the n frames from f0 into y (its left; yr the right, scratch), moved on
static void tv_run(struct tv_head *h, int64_t f0, intptr_t n, flo_t *y, flo_t *yr, flo_t *sc) {
 flo_t *st = tv_st(h);
 if (f0 != h->next) {
  for (uintptr_t j = 0; j < 2 * h->no; j++) st[j] = 0;
  if (f0 <= h->at) h->next = f0;
  else for (int64_t p = h->at; p < f0; ) {
   intptr_t const m = (intptr_t) (f0 - p < tv_step ? f0 - p : tv_step);
   for (intptr_t i = 0; i < m; i++) y[i] = yr[i] = 0;
   tones_run(tv_rows(h), h->no, st, m, p, h->rate, y, yr, sc);
   p += m, h->next = p; } }
 for (intptr_t i = 0; i < n; i++) y[i] = yr[i] = 0;
 tones_run(tv_rows(h), h->no, st, n, f0, h->rate, y, yr, sc);
 h->next = f0 + n; }

static void mix_add(flo_t *L, flo_t *R, flo_t const *y, intptr_t i0, intptr_t i1, flo_t fl, flo_t fr) {
 if (fl != 0) for (intptr_t i = i0; i < i1; i++) L[i] += y[i] * fl;
 if (fr != 0) for (intptr_t i = i0; i < i1; i++) R[i] += y[i] * fr; }

love_noinline static struct g *host_tones_mix(struct g *g) {
 word *a = g->sp;
 // (tones-mix ps base n g ws)
 if (!(a[1] & 1) || !(a[2] & 1)) { a[0] = ZeroPoint; return g; }
 int64_t const base = getcharm(a[1]);
 intptr_t const n = getcharm(a[2]);
 int const packed = isnum(a[3]);
 if (n < 0 || n > tv_step) { a[0] = ZeroPoint; return g; }
 // the scratch: the sum's two sides, a voice's two, and its operators' n each at the most
 uintptr_t no = 0;
 for (word p = a[0]; chainp(p); p = B(p)) {
  struct tv_head *h = chainp(A(p)) ? tv_of(A(A(p))) : 0;
  if (h && h->no > no) no = h->no; }
 uintptr_t const need = 2 * (uintptr_t) n + 2 * tv_step + no * tv_step;
 int const inws = tw_floats(a[4]) >= need;
 uintptr_t const ob = packed ? 4 * (uintptr_t) n : 0,
                 w = packed ? str_width(ob) : b2w(tray_bytes(love_R, 1, 2 * (uintptr_t) n)),
                 ws = inws ? 0 : b2w(tray_bytes(love_R, 1, need));
 if (!ok(g = have(g, w + ws))) return g;
 a = g->sp;
 struct str *os = 0;
 struct tray *ot = 0;
 flo_t *L, *R, *sc;
 if (packed) os = ini_str(bump(g, w), ob);
 else ot = ini_tray(bump(g, w), love_R, 1), ot->shape[0] = 2 * (uintptr_t) n;
 if (inws) sc = tw_data(a[4]);
 else { struct tray *t = ini_tray(bump(g, ws), love_R, 1); t->shape[0] = need, sc = tray_data(t); }
 if (packed) L = sc, sc += 2 * n; else L = tray_data(ot);
 R = L + n;
 flo_t *y = sc, *yr = sc + tv_step, *osc = sc + 2 * tv_step;
 for (intptr_t i = 0; i < 2 * n; i++) L[i] = 0;
 for (word p = a[0]; chainp(p); p = B(p)) {
  word q = A(p);
  if (!chainp(q) || !chainp(B(q)) || !chainp(BB(q))) continue;
  word const v = A(q), gl = AB(q), gr = A(BB(q));
  if (!isnum(gl) || !isnum(gr)) continue;
  flo_t const fl = toflo(gl), fr = toflo(gr);
  struct tv_head *h = tv_of(v);
  if (h) {
   int64_t const f0 = h->loop ? base % h->loop : base;
   if (!h->ntap) { tv_run(h, f0, n, y, yr, osc); mix_add(L, R, y, 0, n, fl, fr); continue; }
   // echoed: the voice itself while it sounds, laid in the ring, then its taps from the ring
   flo_t *hs = tv_hist(h);
   uintptr_t const hl = h->hlen;
   if (f0 != h->hnext) for (uintptr_t i = 0; i < hl; i++) hs[i] = 0;
   int const cur = f0 < h->end;
   if (cur) tv_run(h, f0, n, y, yr, osc);
   for (intptr_t i = 0; i < n; i++) hs[(uintptr_t) ((f0 + i) % (int64_t) hl)] = cur ? y[i] : 0;
   h->hnext = f0 + n;
   if (cur) mix_add(L, R, y, 0, n, fl, fr);
   for (uintptr_t k = 0; k < h->ntap; k++) {
    int64_t const d = h->td[k];
    flo_t const tl = fl * h->tg[k], tr = fr * h->tg[k];
    for (intptr_t i = 0; i < n; i++) {
     int64_t const t = f0 + i - d;
     yr[i] = t < 0 ? 0 : hs[(uintptr_t) (t % (int64_t) hl)]; }
    mix_add(L, R, yr, 0, n, tl, tr); }
   continue; }
  // a piece as mixall's
  if (!chainp(B(BB(q)))) continue;
  word const o = A(B(BB(q)));
  if (!galaxyp(v) || tray(v)->type != love_R || !(o & 1)) continue;
  intptr_t const off = getcharm(o);
  if (tray_nelem(tray(v)) < (uintptr_t) n || off <= -n || off >= n) continue;
  intptr_t const i0 = off < 0 ? -off : 0, i1 = off > 0 ? n - off : n;
  mix_add(L, R, (flo_t const *) tray_data(tray(v)) + off, i0, i1, fl, fr); }
 if (!packed) { a[0] = word(ot); return g; }
 flo_t const gn = toflo(a[3]);
 unsigned char *b = (unsigned char *) os->bytes;
 for (intptr_t i = 0; i < n; i++)
  for (int c = 0; c < 2; c++) {
   flo_t x = (c ? R : L)[i] * gn;
   x = x < (flo_t) -32768 ? (flo_t) -32768 : x;
   x = x > (flo_t) 32767 ? (flo_t) 32767 : x;
   intptr_t const v = flo_word(x);
   b[4 * i + 2 * c] = (unsigned char) v, b[4 * i + 2 * c + 1] = (unsigned char) (v >> 8); }
 a[0] = word(os);
 return g; }
static lvm(lvm_tones_mix) { LvmCallp(g, 4, host_tones_mix) }

LvDef("tones", tones, 6, "dsp");
LvDef("tones-voice", tones_voice, 4, "dsp");
LvDef("tones-echo", tones_echo, 2, "dsp");
LvDef("tones-loop", tones_loop, 2, "dsp");
LvDef("tones-mix", tones_mix, 5, "dsp");
LvDef("tones-ws", tones_ws, 1, "dsp");
LvDef("mixall", mixall, 2, "dsp");
