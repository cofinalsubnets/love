// xz.c -- LZMA and LZMA2 both directions, and xz's crc64; the .xz container is src/apps/xz.l
//   (lzma2d s)               a raw LZMA2 chunk stream -> its bytes | () | 1 past XZ_MAX
//   (lzma2len s)             the stream's length through its 0x00 end byte | ()
//   (lzma2e s dict)          bytes -> a raw LZMA2 stream, dict the match window | ()
//   (lzma2e-by s base)       s coded against base, the stream carrying only s | ()
//   (lzma2d-by z base)       such a stream with its base -> s | ()
//   (lzma-new props dict n)  a state for a .lzma body (after its 13-byte head) as it comes; n
//                            -1 unknown -> the state | () | 1 a window past XZ_MAX
//   (lzma-feed st s)         the next piece in, "" once there is no more -> bytes out (all of s
//                            taken), (bytes . rest) paused with rest to feed again, or ended with
//                            ("" . rest) once the bytes are out, | () corrupt
//   (crc64 s)                CRC-64/XZ as the 8 little-endian bytes a check field holds
//   (crc64-on c s)           the same carried on: c what crc64 said of the bytes before s
//   (lzma2-new dict)         a state for LZMA2 a chunk at a time, a dict-sized window
//   (lzma2-chunk st c)       one whole chunk (control byte, header, data) -> its bytes | ()
//   (lzma2e-new dict)        lzma2e as a stream: (lzma2e-feed st b) the chunks b lets out,
//                            (lzma2e-end st) the rest and the end byte
// the decoders' dictionary is the output; the coder is an optimal parse over a binary-tree finder
#include "love.h"
#include "bytes.h"
#include "lzfind.h"
#include <stdint.h>
#include <string.h>

#define LZ_BITS 11
#define LZ_ONE (1u << LZ_BITS)
#define LZ_MOVE 5
#define LZ_TOP (1u << 24)
#define LZ_MINLEN 2
#define LZ_MAXLEN 273
#define LZ_REQ 20                               // the most input one symbol reads
// the output is one heap string: past this a stream is refused
#define XZ_MAX ((uintptr_t) 1 << 30)

typedef uint16_t lzp;

// --- the model, one shape for both directions ---------------------------------------------
struct lz_len { lzp choice, choice2, low[16][8], mid[16][8], high[256]; };
struct lz_model {
 lzp ismatch[12][16], isrep[12], isg0[12], isg1[12], isg2[12], isrep0l[12][16];
 lzp slot[4][64], spec[114], align[16];
 struct lz_len len, rep;
 unsigned lc, lp, pb, state;
 uint32_t reps[4];
 lzp *lit; };                                   // 0x300 << (lc + lp), the caller's

static void lz_reset(struct lz_model *m) {
 lzp *p = (lzp*) m, *e = (lzp*) &m->lc;         // every fixed prob, then the literals
 while (p < e) *p++ = LZ_ONE / 2;
 for (uint32_t i = 0, k = 0x300u << (m->lc + m->lp); i < k; i++) m->lit[i] = LZ_ONE / 2;
 m->state = 0; m->reps[0] = m->reps[1] = m->reps[2] = m->reps[3] = 0; }

// the props byte, pb lp lc packed as ((pb * 5) + lp) * 9 + lc
static int lz_props(struct lz_model *m, unsigned b, unsigned maxlclp) {
 if (b >= 225 || b % 9 + b / 9 % 5 > maxlclp) return 0;
 m->lc = b % 9; b /= 9; m->lp = b % 5; m->pb = b / 5;
 return 1; }

static unsigned lz_litst(unsigned s) { return s < 4 ? 0 : s < 10 ? s - 3 : s - 6; }

// --- the range decoder: normalize before each bit --------------------------------------------
// the input is p[0..n), i the next byte; past the end bad, and the coder reads zeros
struct lz_rd { const uint8_t *p; uintptr_t i, n; uint32_t range, code; int bad; };

static int rd_init(struct lz_rd *r, const uint8_t *p, const uint8_t *e) {
 if (e - p < 5 || p[0]) return 0;
 r->p = p, r->i = 5, r->n = (uintptr_t) (e - p), r->range = 0xffffffffu, r->bad = 0;
 r->code = (uint32_t) p[1] << 24 | (uint32_t) p[2] << 16 | (uint32_t) p[3] << 8 | p[4];
 return 1; }

static void rd_norm(struct lz_rd *r) {
 if (r->range < LZ_TOP) {
  r->range <<= 8;
  if (r->i < r->n) r->code = r->code << 8 | r->p[r->i++]; else r->bad = 1, r->code <<= 8; } }

// all ones where a < b, the sign of a - b where a word holds it
#if UINTPTR_MAX > 0xffffffffu
#define LZ_LT(a, b) ((uintptr_t) ((intptr_t) ((a) - (b)) >> 63))
#else
#define LZ_LT(a, b) (0 - (uintptr_t) ((a) < (b)))
#endif
#if wideld
#define LD64(p) ld64(p)
#define ST64(p, x) st64(p, x)
#else
#define LD64(p) 0
#define ST64(p, x) ((void) (x))
#endif
// the output, which is the dictionary. `pause` stops at a symbol's start where cap may not
// hold one more match (1, 2) or the input may not hold one more symbol (1): a stream fed in pieces
struct lz_out { uint8_t *b; uintptr_t n, cap, base; int pause; };

// lz.l reads the model as one table of probabilities at these offsets
#define LZ_AT(f, k) _Static_assert(offsetof(struct lz_model, f) == (k) * sizeof(lzp), #f)
LZ_AT(isrep, 192); LZ_AT(isg0, 204); LZ_AT(isg1, 216); LZ_AT(isg2, 228); LZ_AT(isrep0l, 240);
LZ_AT(slot, 432); LZ_AT(spec, 688); LZ_AT(align, 802); LZ_AT(len, 818); LZ_AT(rep, 1332); LZ_AT(lc, 1846);

// decode to lim bytes or, with eopm, the end marker: 1 done, 2 the marker, 3 paused for
// input, 0 corrupt. laid and proved by lz.l
#include "lz_gen.h"

// --- LZMA2: the chunk walk ------------------------------------------------------------------
// the header pass: total bytes, *end past the 0x00; -1 malformed
static int64_t l2_walk(const uint8_t *s, uintptr_t n, uintptr_t *end) {
 uintptr_t i = 0;
 int64_t tot = 0;
 for (;;) {
  if (i >= n) return -1;
  unsigned c = s[i];
  if (!c) { *end = i + 1; return tot; }
  if (c == 1 || c == 2) {
   if (n - i < 3) return -1;
   uintptr_t k = ((uintptr_t) s[i + 1] << 8 | s[i + 2]) + 1;
   if (n - i - 3 < k) return -1;
   tot += k; i += 3 + k; continue; }
  if (c < 0x80) return -1;
  uintptr_t h = c >= 0xc0 ? 6 : 5;
  if (n - i < h) return -1;
  uintptr_t u = ((uintptr_t) (c & 31) << 16 | (uintptr_t) s[i + 1] << 8 | s[i + 2]) + 1,
            k = ((uintptr_t) s[i + 3] << 8 | s[i + 4]) + 1;
  if (n - i - h < k) return -1;
  tot += u; i += h + k; } }

// the chunks into out (cap exact): 0 ok, -1 corrupt. a dict reset first, props before the
// first LZMA chunk and after a 0x01
static int l2_dec(const uint8_t *s, uint8_t *out, uintptr_t cap, struct lz_model *m, uintptr_t pre) {
 struct lz_out o = { out, pre, cap, 0, 0 };        // pre bytes of out said already: a preset base
 struct lz_rd r;
 uintptr_t i = 0;
 int needdict = !pre, needprops = 1;
 for (;;) {
  unsigned c = s[i];
  if (!c) return o.n == cap ? 0 : -1;
  if (c >= 0xe0 || c == 1) { needprops = 1; needdict = 0; o.base = o.n; }
  else if (needdict) return -1;
  if (c < 0x80) {
   uintptr_t k = ((uintptr_t) s[i + 1] << 8 | s[i + 2]) + 1;
   if (cap - o.n < k) return -1;
   memcpy(o.b + o.n, s + i + 3, k); o.n += k; i += 3 + k; continue; }
  uintptr_t u = ((uintptr_t) (c & 31) << 16 | (uintptr_t) s[i + 1] << 8 | s[i + 2]) + 1,
            k = ((uintptr_t) s[i + 3] << 8 | s[i + 4]) + 1, h = 5;
  if (c >= 0xc0) {
   if (!lz_props(m, s[i + 5], 4)) return -1;
   needprops = 0; h = 6; }
  else if (needprops) return -1;
  if (c >= 0xa0) lz_reset(m);
  if (cap - o.n < u || !rd_init(&r, s + i + h, s + i + h + k)) return -1;
  if (lz_run(m, &r, &o, o.n + u, 0) != 1) return -1;
  rd_norm(&r);                                   // the coder flushes a byte the last bit left
  if (r.bad || r.i != r.n || r.code) return -1;
  i += h + k; } }

// --- the range coder ------------------------------------------------------------------------
struct lz_rc { uint8_t *b; uintptr_t n, cap; uint64_t low; uint32_t range; uint8_t cache; uintptr_t csz; };

static void rc_init(struct lz_rc *e, uint8_t *b, uintptr_t cap) {
 e->b = b; e->n = 0; e->cap = cap; e->low = 0; e->range = 0xffffffffu; e->cache = 0; e->csz = 1; }

static void rc_shift(struct lz_rc *e) {
 if ((uint32_t) e->low < 0xff000000u || (e->low >> 32)) {
  uint8_t t = e->cache;
  do { if (e->n < e->cap) e->b[e->n] = (uint8_t) (t + (e->low >> 32)); e->n++; t = 0xff; }
  while (--e->csz);
  e->cache = (uint8_t) (e->low >> 24); }
 e->csz++;
 e->low = (e->low & 0x00ffffffu) << 8; }

static void rc_bit(struct lz_rc *e, lzp *p, unsigned bit) {
 uint32_t b = (e->range >> LZ_BITS) * *p;
 if (!bit) { e->range = b; *p += (LZ_ONE - *p) >> LZ_MOVE; }
 else { e->low += b; e->range -= b; *p -= *p >> LZ_MOVE; }
 while (e->range < LZ_TOP) e->range <<= 8, rc_shift(e); }

static void rc_direct(struct lz_rc *e, uint32_t v, unsigned n) {
 while (n--) {
  e->range >>= 1;
  if ((v >> n) & 1) e->low += e->range;
  while (e->range < LZ_TOP) e->range <<= 8, rc_shift(e); } }

static void rc_flush(struct lz_rc *e) { for (int i = 0; i < 5; i++) rc_shift(e); }
static uintptr_t rc_size(struct lz_rc *e) { return e->n + e->csz + 4; }

static void rc_tree(struct lz_rc *e, lzp *p, unsigned n, unsigned v) {
 unsigned m = 1;
 while (n--) { unsigned b = (v >> n) & 1; rc_bit(e, p + m, b); m = m << 1 | b; } }

static void rc_rtree(struct lz_rc *e, lzp *p, unsigned n, unsigned v) {
 unsigned m = 1;
 while (n--) { unsigned b = v & 1; v >>= 1; rc_bit(e, p + m, b); m = m << 1 | b; } }

static void rc_len(struct lz_rc *e, struct lz_len *l, unsigned ps, unsigned v) {
 if (v < 8) { rc_bit(e, &l->choice, 0); rc_tree(e, l->low[ps], 3, v); return; }
 rc_bit(e, &l->choice, 1);
 if (v < 16) { rc_bit(e, &l->choice2, 0); rc_tree(e, l->mid[ps], 3, v - 8); return; }
 rc_bit(e, &l->choice2, 1); rc_tree(e, l->high, 8, v - 16); }

// --- the coder's symbols (lc 4, lp 0, pb 0: text and code both pay) ----------------------------
#define XE_LC 4
#define XE_PB 0
#define XE_PBM ((1u << XE_PB) - 1)

static void xe_lit(struct lz_model *m, struct lz_rc *e, const uint8_t *s, uintptr_t p) {
 unsigned st = m->state;
 rc_bit(e, &m->ismatch[st][p & XE_PBM], 0);
 lzp *pr = m->lit + 0x300 * ((p ? s[p - 1] : 0) >> (8 - XE_LC));
 if (st >= 7) {                    // off drops to 0 at the first bit off the match byte
  unsigned mb = s[p - m->reps[0] - 1], off = 0x100, sym = s[p] | 0x100;
  do {
   mb <<= 1;
   rc_bit(e, pr + off + (mb & off) + (sym >> 8), (sym >> 7) & 1);
   sym <<= 1;
   off &= ~(mb ^ sym); } while (sym < 0x10000); }
 else rc_tree(e, pr, 8, s[p]);
 m->state = lz_litst(st); }

static unsigned xe_slot(uint32_t d) {
 if (d < 4) return d;
 unsigned n = 31;
 while (!(d >> n)) n--;
 return 2 * n + ((d >> (n - 1)) & 1); }

static void xe_match(struct lz_model *m, struct lz_rc *e, uintptr_t p, uint32_t d, unsigned len) {
 unsigned st = m->state, ps = p & XE_PBM;
 rc_bit(e, &m->ismatch[st][ps], 1); rc_bit(e, &m->isrep[st], 0);
 rc_len(e, &m->len, ps, len - LZ_MINLEN);
 m->state = st < 7 ? 7 : 10;
 unsigned ls = len - LZ_MINLEN < 3 ? len - LZ_MINLEN : 3, slot = xe_slot(d);
 rc_tree(e, m->slot[ls], 6, slot);
 if (slot >= 4) {
  unsigned fb = (slot >> 1) - 1;
  uint32_t base = (2 | (slot & 1)) << fb, red = d - base;
  if (slot < 14) rc_rtree(e, m->spec + base - slot - 1, fb, red);
  else rc_direct(e, red >> 4, fb - 4), rc_rtree(e, m->align, 4, red & 15); }
 m->reps[3] = m->reps[2]; m->reps[2] = m->reps[1]; m->reps[1] = m->reps[0]; m->reps[0] = d; }

static void xe_rep(struct lz_model *m, struct lz_rc *e, uintptr_t p, unsigned idx, unsigned len) {
 unsigned st = m->state, ps = p & XE_PBM;
 rc_bit(e, &m->ismatch[st][ps], 1); rc_bit(e, &m->isrep[st], 1);
 if (!idx) {
  rc_bit(e, &m->isg0[st], 0); rc_bit(e, &m->isrep0l[st][ps], len != 1);
  if (len == 1) { m->state = st < 7 ? 9 : 11; return; } }
 else {
  uint32_t d = m->reps[idx];
  rc_bit(e, &m->isg0[st], 1);
  rc_bit(e, &m->isg1[st], idx != 1);
  if (idx != 1) { rc_bit(e, &m->isg2[st], idx == 3); if (idx == 3) m->reps[3] = m->reps[2]; m->reps[2] = m->reps[1]; }
  m->reps[1] = m->reps[0]; m->reps[0] = d; }
 rc_len(e, &m->rep, ps, len - LZ_MINLEN);
 m->state = st < 7 ? 8 : 11; }

// --- the match finder: lzfind.h's tree over the whole input, the window its dict -----------
#define XE_H4BITS 20
#define XE_DEPTH 48
#define XE_SKIPDEPTH 8                          // a position indexed with no matches asked
#define XE_NICE 96
#define XE_MAXM 64

// --- prices, in 16ths of a bit, off the model as it stands -----------------------------------
#define XP_INF 0x3fffffffu
#define XP_LENS (LZ_MAXLEN - LZ_MINLEN + 1)
struct xe_px {
 uint16_t bit[128];                               // a bit's price by its prob's top 7 bits
 uint32_t len[4][XP_LENS], rep[4][XP_LENS];       // by posstate
 uint32_t slot[4][64], dist[4][128], align[16];   // by the length's state, min(len - 2, 3)
 unsigned left; };                                // ops until the tables are priced again

static void xp_init(struct xe_px *x) {             // -log2 by squaring: four fraction bits
 for (uint32_t i = 0; i < 128; i++) {
  uint32_t w = i << 4 | 8, e = 0;
  for (int j = 0; j < 4; j++) { w = w * w, e <<= 1; while (w >= (1u << 16)) w >>= 1, e++; }
  x->bit[i] = (uint16_t) ((11 << 4) - 15 - e); }
 x->left = 0; }
static uint32_t xp_bit(const struct xe_px *x, lzp p, unsigned b) { return x->bit[(b ? LZ_ONE - p : p) >> 4]; }
static uint32_t xp_tree(const struct xe_px *x, const lzp *p, unsigned n, unsigned v) {
 uint32_t c = 0;
 for (unsigned m = 1; n--; ) { unsigned b = (v >> n) & 1; c += xp_bit(x, p[m], b); m = m << 1 | b; }
 return c; }
static uint32_t xp_rtree(const struct xe_px *x, const lzp *p, unsigned n, unsigned v) {
 uint32_t c = 0;
 for (unsigned m = 1; n--; v >>= 1) { unsigned b = v & 1; c += xp_bit(x, p[m], b); m = m << 1 | b; }
 return c; }
static void xp_lens(const struct xe_px *x, const struct lz_len *l, uint32_t t[4][XP_LENS]) {
 uint32_t c0 = xp_bit(x, l->choice, 0), c1 = xp_bit(x, l->choice, 1);
 uint32_t c10 = c1 + xp_bit(x, l->choice2, 0), c11 = c1 + xp_bit(x, l->choice2, 1);
 for (unsigned ps = 0; ps < 4; ps++)
  for (unsigned v = 0; v < XP_LENS; v++)
   t[ps][v] = v < 8 ? c0 + xp_tree(x, l->low[ps], 3, v)
            : v < 16 ? c10 + xp_tree(x, l->mid[ps], 3, v - 8) : c11 + xp_tree(x, l->high, 8, v - 16); }
static void xp_price(struct xe_px *x, const struct lz_model *m) {
 xp_lens(x, &m->len, x->len), xp_lens(x, &m->rep, x->rep);
 for (unsigned ls = 0; ls < 4; ls++) {
  for (unsigned sl = 0; sl < 64; sl++)            // the direct bits ride the slot, a bit each
   x->slot[ls][sl] = xp_tree(x, m->slot[ls], 6, sl) + (sl >= 14 ? ((sl >> 1) - 5) << 4 : 0);
  for (uint32_t d = 0; d < 128; d++) {
   unsigned sl = xe_slot(d), fb = (sl >> 1) - 1;
   uint32_t base = sl < 4 ? 0 : (2 | (sl & 1)) << fb;
   x->dist[ls][d] = x->slot[ls][sl] + (sl >= 4 ? xp_rtree(x, m->spec + base - sl - 1, fb, d - base) : 0); } }
 for (unsigned i = 0; i < 16; i++) x->align[i] = xp_rtree(x, m->align, 4, i);
 x->left = 256; }
static uint32_t xp_dist(const struct xe_px *x, uint32_t d, unsigned len) {
 unsigned ls = len - LZ_MINLEN < 3 ? len - LZ_MINLEN : 3;
 if (d < 128) return x->dist[ls][d];
 unsigned sl = xe_slot(d), fb = (sl >> 1) - 1;
 return x->slot[ls][sl] + x->align[(d - ((2 | (sl & 1)) << fb)) & 15]; }
static uint32_t xp_lit(const struct xe_px *x, const struct lz_model *m, unsigned st, const uint8_t *s,
                       uintptr_t p, uint32_t r0) {
 const lzp *pr = m->lit + 0x300 * ((p ? s[p - 1] : 0) >> (8 - XE_LC));
 if (st < 7) return xp_tree(x, pr, 8, s[p]);
 unsigned mb = s[p - r0 - 1], off = 0x100, sym = s[p] | 0x100;
 uint32_t c = 0;
 do {
  mb <<= 1;
  c += xp_bit(x, pr[off + (mb & off) + (sym >> 8)], (sym >> 7) & 1);
  sym <<= 1, off &= ~(mb ^ sym); } while (sym < 0x10000);
 return c; }

// --- the optimal parse: the cheapest way through the next stretch, priced ---------------------
// node i, i bytes on: its cheapest price, the op that reached it (back: rep 0..3, distance + 4,
// XB_LIT, XB_SHORT) from prev, and the state and reps that leaves
#define XE_OPTS 2048
#define XB_LIT 0xffffffffu
#define XB_SHORT 0xfffffffeu
struct xe_node { uint32_t price, back, reps[4]; uint16_t prev, len, ext; uint8_t state; };
struct xe_op { uint32_t back, len; };

static void xn_take(struct xe_node *nd, uint32_t i, uint32_t price, uint32_t from, uint32_t back) {
 if (price < nd[i].price) nd[i].price = price, nd[i].prev = (uint16_t) from, nd[i].back = back, nd[i].ext = 0; }
// back, then a literal, then rep0 for ext bytes; with XN_LR0, back is the literal itself
#define XN_LR0 0x8000u
static void xn_take3(struct xe_node *nd, uint32_t i, uint32_t price, uint32_t from, uint32_t back, unsigned ext) {
 if (price < nd[i].price) nd[i].price = price, nd[i].prev = (uint16_t) from, nd[i].back = back, nd[i].ext = (uint16_t) ext; }
static void xn_state(struct xe_node *nd, uint32_t i) {   // node i's state and reps, off its op
 struct xe_node *a = nd + nd[i].prev, *b = nd + i;
 unsigned st = a->state;
 memcpy(b->reps, a->reps, sizeof b->reps);
 if (b->back == XB_LIT) b->state = (uint8_t) lz_litst(st);
 else if (b->back == XB_SHORT) b->state = st < 7 ? 9 : 11;
 else if (b->back < 4) {
  uint32_t d = a->reps[b->back];
  for (unsigned k = b->back; k; k--) b->reps[k] = b->reps[k - 1];
  b->reps[0] = d, b->state = st < 7 ? 8 : 11; }
 else {
  b->reps[3] = b->reps[2], b->reps[2] = b->reps[1], b->reps[1] = b->reps[0];
  b->reps[0] = b->back - 4, b->state = st < 7 ? 7 : 10; }
 if (b->ext) b->state = (b->ext & XN_LR0 ? b->state : lz_litst(b->state)) < 7 ? 8 : 11; }

// a literal at q in state st, then rep0 r0 as far as it runs below end: the price, and the run in *L
static uint32_t xe_lr0(const struct xe_px *x, const struct lz_model *m, const uint8_t *s, uintptr_t q,
                       unsigned st, uint32_t r0, uintptr_t end, unsigned *L) {
 uintptr_t q1 = q + 1;
 *L = 0;
 if (q1 + 2 > end || q1 <= r0) return XP_INF;
 const uint8_t *r = s + q1 - r0 - 1;
 if (r[0] != s[q1] || r[1] != s[q1 + 1]) return XP_INF;
 *L = lzf_mlen(r, s + q1, end - q1 > XE_NICE ? XE_NICE : (unsigned) (end - q1));
 unsigned st2 = lz_litst(st), ps = q & XE_PBM, ps2 = q1 & XE_PBM;
 return xp_bit(x, m->ismatch[st][ps], 0) + xp_lit(x, m, st, s, q, r0)
      + xp_bit(x, m->ismatch[st2][ps2], 1) + xp_bit(x, m->isrep[st2], 1) + xp_bit(x, m->isg0[st2], 0)
      + xp_bit(x, m->isrep0l[st2][ps2], 1) + x->rep[ps2][*L - 2]; }

// -> how many ops, in ops, to cover the stretch from p (avail bytes on at most)
static unsigned xe_plan(struct lz_model *m, struct lzf *f, struct xe_px *x, struct xe_node *nd,
                        struct xe_op *ops, uint32_t *ls, uint32_t *ds, uintptr_t p, uintptr_t end) {
 const uint8_t *s = f->s;
 uint32_t end_ = 0, cur;
 nd[0].price = 0, nd[0].state = (uint8_t) m->state, memcpy(nd[0].reps, m->reps, sizeof nd[0].reps);
 for (cur = 0; ; cur++) {
  uintptr_t q = p + cur;
  if (cur && cur == end_) break;
  if (cur) xn_state(nd, cur);
  if (q >= end || cur >= XE_OPTS) { end_ = cur; break; }
  unsigned avail = end - q > LZ_MAXLEN ? LZ_MAXLEN : (unsigned) (end - q);
  struct xe_node *c = nd + cur;
  unsigned st = c->state, ps = q & XE_PBM;
  uint32_t base = c->price, pm1 = base + xp_bit(x, m->ismatch[st][ps], 1);
  uint32_t prep = pm1 + xp_bit(x, m->isrep[st], 1);
  // the literal, and rep0 for one byte
  if (end_ < cur + 1) nd[++end_].price = XP_INF;
  xn_take(nd, cur + 1, base + xp_bit(x, m->ismatch[st][ps], 0) + xp_lit(x, m, st, s, q, c->reps[0]),
          cur, XB_LIT);
  if (q > c->reps[0] && s[q] == s[q - c->reps[0] - 1])
   xn_take(nd, cur + 1, prep + xp_bit(x, m->isg0[st], 0) + xp_bit(x, m->isrep0l[st][ps], 0), cur, XB_SHORT);
  else {                                          // a literal, then rep0 in the state it leaves
   unsigned L2; uint32_t pr = xe_lr0(x, m, s, q, st, c->reps[0], end, &L2);
   if (L2) { while (end_ < cur + 1 + L2) nd[++end_].price = XP_INF;
             xn_take3(nd, cur + 1 + L2, base + pr, cur, XB_LIT, L2 | XN_LR0); } }
  // the reps
  unsigned rl[4], rmax = 0, ri = 0;
  for (unsigned i = 0; i < 4; i++) {
   rl[i] = 0;
   if (avail < 2 || q <= c->reps[i]) continue;
   const uint8_t *r = s + q - c->reps[i] - 1;
   if (r[0] == s[q] && r[1] == s[q + 1]) rl[i] = lzf_mlen(r, s + q, avail);
   if (rl[i] > rmax) rmax = rl[i], ri = i; }
  // the matches, from the finder; one at nice length (or a rep) is taken whole
  unsigned k = lzf_all(f, q, avail, LZ_MAXLEN, ls, ds), ml = k ? ls[k - 1] : 0;
  if (rmax >= XE_NICE || ml >= XE_NICE) {
   uint32_t L = rmax >= ml ? rmax : ml;
   while (end_ < cur + L) nd[++end_].price = XP_INF;
   nd[cur + L].price = 0, nd[cur + L].prev = (uint16_t) cur, nd[cur + L].ext = 0;
   nd[cur + L].back = rmax >= ml ? ri : ds[k - 1] + 4;
   end_ = cur + L; cur = end_; break; }
  uint32_t top = cur + (rmax > ml ? rmax : ml);
  while (end_ < top) nd[++end_].price = XP_INF;
  for (unsigned i = 0; i < 4; i++) {
   if (rl[i] < 2) continue;
   uint32_t pr = prep + (i == 0 ? xp_bit(x, m->isg0[st], 0) + xp_bit(x, m->isrep0l[st][ps], 1)
                       : xp_bit(x, m->isg0[st], 1) + (i == 1 ? xp_bit(x, m->isg1[st], 0)
                         : xp_bit(x, m->isg1[st], 1) + xp_bit(x, m->isg2[st], i == 3)));
   for (unsigned L = 2; L <= rl[i]; L++) xn_take(nd, cur + L, pr + x->rep[ps][L - 2], cur, i);
   unsigned L = rl[i], L2; uint32_t p3 = xe_lr0(x, m, s, q + L, st < 7 ? 8 : 11, c->reps[i], end, &L2);
   if (L2) { while (end_ < cur + L + 1 + L2) nd[++end_].price = XP_INF;
             xn_take3(nd, cur + L + 1 + L2, pr + x->rep[ps][L - 2] + p3, cur, i, L2); } }
  uint32_t pmat = pm1 + xp_bit(x, m->isrep[st], 0);
  for (unsigned j = 0, L = 2; j < k; j++)
   for (; L <= ls[j]; L++)
    xn_take(nd, cur + L, pmat + x->len[ps][L - 2] + xp_dist(x, ds[j], L), cur, ds[j] + 4);
  for (unsigned j = 0; j < k; j++) {               // each match at its longest, a literal, then rep0
   unsigned L = ls[j], L2; uint32_t p3 = xe_lr0(x, m, s, q + L, st < 7 ? 7 : 10, ds[j], end, &L2);
   if (L2) { while (end_ < cur + L + 1 + L2) nd[++end_].price = XP_INF;
             xn_take3(nd, cur + L + 1 + L2, pmat + x->len[ps][L - 2] + xp_dist(x, ds[j], L) + p3, cur, ds[j] + 4, L2); } } }
 // back from the end, the ops in order
 unsigned n = 0;
 for (uint32_t i = cur; i; i = nd[i].prev) nd[i].len = (uint16_t) (i - nd[i].prev), n += !nd[i].ext ? 1 : nd[i].ext & XN_LR0 ? 2 : 3;
 unsigned k = n;
 for (uint32_t i = cur; i; i = nd[i].prev) {
  unsigned e = nd[i].ext & ~XN_LR0, two = nd[i].ext & XN_LR0;
  if (e) k--, ops[k].back = 0, ops[k].len = e;
  if (e && !two) k--, ops[k].back = XB_LIT, ops[k].len = 1;
  k--, ops[k].back = nd[i].back, ops[k].len = nd[i].len - (two ? e : e ? e + 1 : 0); }
 return n; }

// a chunk takes XE_CU bytes at most and lays XE_CC; one that does not shrink goes raw
#define XE_CU (2u << 20)
#define XE_CC 65536u
#define XE_CSLACK 256u

struct xe_arena { struct lz_model m; lzp lit[0x300 << XE_LC]; uint8_t cs[XE_CC + XE_CSLACK];
                  uint32_t h2[1u << 16], h3[1u << 16], h4[1u << XE_H4BITS];
                  struct xe_px px; struct xe_node nd[XE_OPTS + 2 * LZ_MAXLEN + 4]; struct xe_op ops[XE_OPTS + 2 * LZ_MAXLEN + 4];
                  uint32_t ls[XE_MAXM], ds[XE_MAXM]; };

// where the chunks stand: the next one's start, and what it must reset
struct xe_ck { uintptr_t p; int first, needprops, needstate; };
// one chunk from c->p over s[0..n), a's model carried -> its bytes in out | -1
static int64_t xe_chunk(const uint8_t *s, uintptr_t n, struct xe_arena *a, struct lzf *f, struct xe_ck *c,
                        uint8_t *out, uintptr_t cap) {
 struct lz_model *m = &a->m;
 uintptr_t p = c->p, o = 0, start = p, uend = n - p > XE_CU ? p + XE_CU : n;
 unsigned rst = c->first ? 3 : c->needprops ? 2 : c->needstate ? 1 : 0;
 struct lz_rc e;
 if (rst) lz_reset(m), a->px.left = 0;
 rc_init(&e, a->cs, sizeof a->cs);
 unsigned pn = 0, pi = 0;                         // a plan holds within its chunk
 while (p < uend && rc_size(&e) < XE_CC - XE_CSLACK) {
  if (pi == pn) {
   if (!a->px.left) xp_price(&a->px, m);
   pn = xe_plan(m, f, &a->px, a->nd, a->ops, a->ls, a->ds, p, uend), pi = 0; }
  struct xe_op *op = a->ops + pi++;
  if (a->px.left) a->px.left--;
  if (op->back == XB_LIT) xe_lit(m, &e, s, p);
  else if (op->back == XB_SHORT) xe_rep(m, &e, p, 0, 1);
  else if (op->back < 4) xe_rep(m, &e, p, op->back, op->len);
  else xe_match(m, &e, p, op->back - 4, op->len);
  p += op->len;
  lzf_ins(f, p, LZ_MAXLEN); }
 rc_flush(&e);
 c->p = p;
 uintptr_t u = p - start, k = e.n;
 if (k > XE_CC) return -1;
 if (k < u) {
  if (cap - o < k + 6) return -1;
  out[o++] = (uint8_t) (0x80 | rst << 5 | (u - 1) >> 16);
  out[o++] = (uint8_t) ((u - 1) >> 8); out[o++] = (uint8_t) (u - 1);
  out[o++] = (uint8_t) ((k - 1) >> 8); out[o++] = (uint8_t) (k - 1);
  if (rst >= 2) out[o++] = (uint8_t) (XE_PB * 45 + XE_LC);
  memcpy(out + o, a->cs, k); o += k;
  c->first = c->needprops = c->needstate = 0; }
 else {
  for (uintptr_t q = start; q < p; ) {
   uintptr_t r = p - q > 65536 ? 65536 : p - q;
   if (cap - o < r + 3) return -1;
   out[o++] = c->first ? 1 : 2; out[o++] = (uint8_t) ((r - 1) >> 8); out[o++] = (uint8_t) (r - 1);
   memcpy(out + o, s + q, r); o += r; q += r;
   if (c->first) c->needprops = 1;
   c->first = 0; }
  c->needstate = 1; }
 return (int64_t) o; }

static void xe_arena_init(struct xe_arena *a) {
 memset(a->h2, 0, sizeof a->h2), memset(a->h3, 0, sizeof a->h3), memset(a->h4, 0, sizeof a->h4);
 a->m.lit = a->lit; a->m.lc = XE_LC; a->m.lp = 0; a->m.pb = XE_PB;
 xp_init(&a->px); }

// the whole stream into out (cap the worst case) -> its length, or -1. the bytes below p0 are a
// base the decoder holds already: indexed, never coded
static int64_t xe_go(const uint8_t *s, uintptr_t n, uint32_t dict, uint8_t *out, uintptr_t cap,
                     struct xe_arena *a, uint32_t *son, uint32_t wmask, uintptr_t p0) {
 struct lzf f = { s, n, a->h2, a->h3, a->h4, son, wmask, dict, 0, XE_H4BITS, XE_DEPTH, XE_SKIPDEPTH, XE_NICE, XE_MAXM };
 struct xe_ck c = { p0, !p0, 1, 1 };
 uintptr_t o = 0;
 xe_arena_init(a);
 lzf_ins(&f, p0, LZ_MAXLEN);
 while (c.p < n) {
  int64_t k = xe_chunk(s, n, a, &f, &c, out + o, cap - o);
  if (k < 0) return -1;
  o += (uintptr_t) k; }
 if (cap - o < 1) return -1;
 out[o++] = 0;
 return (int64_t) o; }

static uintptr_t xe_cap(uintptr_t n) { return n + 16 * (n / 65536 + 2); }

// the coder as a stream: one state, fed in pieces, xe_go's chunks. it holds offsets, as its string
// may move; its buffer keeps the dictionary behind the next chunk and the chunk with what its
// last position indexes past it, and slides by whole son cycles, the tables with it
#define XS_MAGIC 0x787a7365u
struct xs_st { uint32_t magic, dict, wmask; uintptr_t w, size, cap, n, ins, oar, oson, obuf; struct xe_ck c; };
#define XS_UP(x) (((x) + 63) & ~(uintptr_t) 63)
static uintptr_t xs_lay(struct xs_st *S, uint32_t dict) {
 uintptr_t w = 1, at = XS_UP(sizeof *S);
 while (w < dict) w <<= 1;
 memset(S, 0, sizeof *S);
 S->dict = dict, S->w = w, S->wmask = (uint32_t) (w - 1), S->cap = dict + w + XE_CU + LZ_MAXLEN;
 S->oar = at, at += XS_UP(sizeof(struct xe_arena));
 S->oson = at, at += XS_UP(2 * w * sizeof(uint32_t));
 S->obuf = at, at += S->cap + 16;
 return S->size = at; }
// the arena's model and the finder over the buffer as it stands
static struct xe_arena *xs_view(struct xs_st *S, struct lzf *f) {
 uint8_t *B = (uint8_t*) S;
 struct xe_arena *a = (struct xe_arena*) (B + S->oar);
 a->m.lit = a->lit;
 *f = (struct lzf) { B + S->obuf, S->n, a->h2, a->h3, a->h4, (uint32_t*) (B + S->oson), S->wmask, S->dict, S->ins,
                     XE_H4BITS, XE_DEPTH, XE_SKIPDEPTH, XE_NICE, XE_MAXM };
 return a; }
static void xs_rebase(uint32_t *t, uintptr_t n, uint32_t by) {
 for (uintptr_t i = 0; i < n; i++) t[i] = t[i] > by ? t[i] - by : 0; }
static void xs_slide(struct xs_st *S, struct xe_arena *a, struct lzf *f) {
 uint8_t *B = (uint8_t*) S;
 uintptr_t by = S->c.p > S->dict ? (S->c.p - S->dict) / S->w * S->w : 0;
 memmove(B + S->obuf, B + S->obuf + by, S->n - by);
 S->n -= by, S->c.p -= by, f->ins -= by, f->n = S->n;
 xs_rebase(a->h2, 1u << 16, (uint32_t) by), xs_rebase(a->h3, 1u << 16, (uint32_t) by);
 xs_rebase(a->h4, 1u << XE_H4BITS, (uint32_t) by), xs_rebase(f->son, 2 * S->w, (uint32_t) by); }
// the most a feed of n bytes, or an end, may lay
static uintptr_t xs_room(const struct xs_st *S, uintptr_t n, int end) {
 uintptr_t open = S->n - S->c.p + n;
 return !end && open < XE_CU + LZ_MAXLEN ? 16 : xe_cap(open) + 16; }
// n bytes of in, and with end the last chunks and the end mark -> what is laid in o | -1 torn
static intptr_t xs_feed(struct xs_st *S, const uint8_t *in, uintptr_t n, int end, uint8_t *o, uintptr_t cap) {
 struct lzf f;
 struct xe_arena *a = xs_view(S, &f);
 uint8_t *buf = (uint8_t*) S + S->obuf;
 uintptr_t at = 0;
 int64_t k;
 for (;;) {
  while (S->n - S->c.p >= XE_CU + LZ_MAXLEN) {
   f.n = S->n;
   if ((k = xe_chunk(buf, S->n, a, &f, &S->c, o + at, cap - at)) < 0) return S->magic = 0, -1;
   at += (uintptr_t) k; }
  if (!n) break;
  if (S->n == S->cap) xs_slide(S, a, &f);
  uintptr_t t = S->cap - S->n < n ? S->cap - S->n : n;
  memcpy(buf + S->n, in, t), S->n += t, in += t, n -= t; }
 if (end) {
  f.n = S->n;
  while (S->c.p < S->n) {
   if ((k = xe_chunk(buf, S->n, a, &f, &S->c, o + at, cap - at)) < 0) return S->magic = 0, -1;
   at += (uintptr_t) k; }
  if (cap - at < 1) return S->magic = 0, -1;
  o[at++] = 0, S->magic = 0; }
 S->ins = f.ins;
 return (intptr_t) at; }

// --- crc64 ----------------------------------------------------------------------------------
// eight bytes a step, as hash.c's crc32; the tables are write-once and idempotent
static uint64_t crc64_t[8][256];
static int crc64_ready;
static void crc64_init(void) {
 for (unsigned i = 0; i < 256; i++) {
  uint64_t v = i;
  for (int k = 0; k < 8; k++) v = v & 1 ? v >> 1 ^ 0xc96c5795d7870f42ull : v >> 1;
  crc64_t[0][i] = v; }
 for (unsigned i = 0; i < 256; i++) {           // table k is table 0 shifted k bytes on
  uint64_t v = crc64_t[0][i];
  for (int k = 1; k < 8; k++) v = crc64_t[0][v & 255] ^ v >> 8, crc64_t[k][i] = v; }
 crc64_ready = 1; }
static uint64_t xz_crc64_on(uint64_t c0, const uint8_t *p, uintptr_t n) {
 uint64_t c = ~c0;
 if (!crc64_ready) crc64_init();
 for (; n >= 8; p += 8, n -= 8) {
  uint64_t x = c ^ ld64le(p);
  c = crc64_t[7][x & 255] ^ crc64_t[6][x >> 8 & 255] ^ crc64_t[5][x >> 16 & 255] ^ crc64_t[4][x >> 24 & 255]
    ^ crc64_t[3][x >> 32 & 255] ^ crc64_t[2][x >> 40 & 255] ^ crc64_t[1][x >> 48 & 255] ^ crc64_t[0][x >> 56]; }
 for (; n; n--) c = crc64_t[0][(c ^ *p++) & 255] ^ c >> 8;
 return ~c; }
static uint64_t xz_crc64(const uint8_t *p, uintptr_t n) { return xz_crc64_on(0, p, n); }

// --- LZMA2 a chunk at a time ---------------------------------------------------------------
// the window: the last dict bytes and a chunk's room past them. a slide is by a multiple of 16,
// so the position bits read the same off the window as off the whole output
#define L2_CHUNK ((uintptr_t) 1 << 21)
#define L2_ROOM(d) (((d) < L2_CHUNK ? L2_CHUNK : (d) < ((uintptr_t) 1 << 23) ? (d) : (uintptr_t) 1 << 23) + 16)
#define L2_MAGIC 0x6c7a6d6132u
struct l2_st { uint64_t magic, n, base, cap, dict; uint32_t needdict, needprops;
               struct lz_model m; lzp lit[0x300 << 4]; };
static void l2_slide(struct l2_st *S, uint8_t *win, uintptr_t need) {
 if (S->n + need <= S->cap) return;
 uintptr_t shift = (S->n - (S->n < S->dict ? S->n : S->dict)) & ~(uintptr_t) 15, keep = S->n - shift;
 memmove(win, win + shift, keep);
 S->n = keep, S->base = S->base > shift ? S->base - shift : 0; }
// one chunk -> how many bytes it put out, from *o0 in the window; -1 malformed
static intptr_t l2_step(struct l2_st *S, uint8_t *win, const uint8_t *s, uintptr_t n, uintptr_t *o0) {
 if (!n || !s[0]) return -1;                    // the end byte is the caller's
 unsigned c = s[0];
 if (c >= 0xe0 || c == 1) S->needprops = 1, S->needdict = 0, S->base = S->n;
 else if (S->needdict) return -1;
 if (c < 0x80) {
  if (c > 2 || n < 3) return -1;
  uintptr_t k = ((uintptr_t) s[1] << 8 | s[2]) + 1;
  if (n != 3 + k) return -1;
  l2_slide(S, win, k);
  *o0 = S->n, memcpy(win + S->n, s + 3, k), S->n += k;
  return (intptr_t) k; }
 if (n < 5) return -1;
 uintptr_t u = ((uintptr_t) (c & 31) << 16 | (uintptr_t) s[1] << 8 | s[2]) + 1,
           k = ((uintptr_t) s[3] << 8 | s[4]) + 1, h = 5;
 if (c >= 0xc0) {
  if (n < 6 || !lz_props(&S->m, s[5], 4)) return -1;
  S->needprops = 0, h = 6; }
 else if (S->needprops) return -1;
 if (n != h + k) return -1;
 if (c >= 0xa0) lz_reset(&S->m);
 l2_slide(S, win, u);
 struct lz_out o = { win, S->n, S->cap, S->base, 0 };
 struct lz_rd r;
 if (!rd_init(&r, s + h, s + h + k) || lz_run(&S->m, &r, &o, o.n + u, 0) != 1) return -1;
 rd_norm(&r);
 if (r.bad || r.i != r.n || r.code) return -1;
 *o0 = S->n, S->n = o.n;
 return (intptr_t) u; }

// the lzma model with room for lc + lp up to lim, from alloc -> or NULL
static struct lz_model *lz_new(unsigned lclp) {
 struct lz_model *m = alloc(NULL, sizeof *m + ((uintptr_t) 0x300 << lclp) * sizeof(lzp));
 if (m) m->lit = (lzp*) (m + 1);
 return m; }

#ifndef XZ_STANDALONE
// the nifs: str0 may collect, so a string is re-read off the stack after it
love_noinline static struct g *host_lzma2len(struct g *g) {
 word sw = g->sp[0];
 uintptr_t end;
 g->sp[0] = strp(sw) && l2_walk((const uint8_t*) txt(sw), len(sw), &end) >= 0
            ? putcharm((intptr_t) end) : ZeroPoint;
 return g; }

// a raw LZMA2 stream into exactly cap bytes, for a caller with no g -> cap, or -1
intptr_t lzma2_into(unsigned char const *s, uintptr_t n, unsigned char *out, uintptr_t cap) {
 uintptr_t end;
 if (l2_walk(s, n, &end) != (int64_t) cap) return -1;
 struct lz_model *m = lz_new(4);
 int ok = m && !l2_dec(s, out, cap, m, 0);
 if (m) alloc(m, 0);
 return ok ? (intptr_t) cap : -1; }

love_noinline static struct g *host_lzma2d(struct g *g) {
 word sw = g->sp[0];
 uintptr_t end;
 int64_t want = strp(sw) ? l2_walk((const uint8_t*) txt(sw), len(sw), &end) : -1;
 if (want < 0) { g->sp[0] = ZeroPoint; return g; }
 if ((uint64_t) want > XZ_MAX) { g->sp[0] = putcharm(1); return g; }
 if (!ok(g = str0(g, (uintptr_t) want))) return g;   // pushes: out over s
 struct lz_model *m = lz_new(4);
 int ok = m && !l2_dec((const uint8_t*) txt(g->sp[1]), (uint8_t*) txt(g->sp[0]), (uintptr_t) want, m, 0);
 if (m) alloc(m, 0);
 g->sp[1] = ok ? g->sp[0] : ZeroPoint;
 return g->sp++, g; }

love_noinline static struct g *host_lzma2e(struct g *g) {
 word sw = g->sp[0], dw = g->sp[1];
 if (!strp(sw) || !oddp(dw) || getcharm(dw) < 4096 || getcharm(dw) > (1l << 30)) {
  g->sp[1] = ZeroPoint, g->sp += 1; return g; }
 uintptr_t n = len(sw), cap = xe_cap(n), w = 1;
 uint32_t dict = (uint32_t) getcharm(dw), wmask;
 if (n <= dict) w = n ? n : 1, wmask = ~(uint32_t) 0;      // the whole input in reach: no wrap
 else { while (w < dict) w <<= 1; wmask = (uint32_t) (w - 1); }
 struct xe_arena *a = alloc(NULL, sizeof *a);
 uint32_t *son = alloc(NULL, 2 * w * sizeof *son);
 uint8_t *out = alloc(NULL, cap);
 int64_t got = a && son && out
               ? xe_go((const uint8_t*) txt(sw), n, dict, out, cap, a, son, wmask, 0) : -1;
 if (a) alloc(a, 0);
 if (son) alloc(son, 0);
 if (got >= 0 && ok(g = str0(g, (uintptr_t) got))) {  // pushes: out over the two
  memcpy(txt(g->sp[0]), out, (size_t) got);
  g->sp[2] = g->sp[0], g->sp += 2; }
 else if (ok(g)) g->sp[1] = ZeroPoint, g->sp += 1;
 if (out) alloc(out, 0);
 return g; }

// base then s in one buffer, coded from where s starts; the whole of it in reach
love_noinline static struct g *host_lzma2e_by(struct g *g) {
 word sw = g->sp[0], bw = g->sp[1];
 if (!strp(sw) || !strp(bw) || len(sw) + len(bw) > XZ_MAX) { g->sp[1] = ZeroPoint, g->sp += 1; return g; }
 uintptr_t nb = len(bw), n = nb + len(sw), w = n ? n : 1, cap = xe_cap(len(sw));
 uint8_t *in = alloc(NULL, w);
 struct xe_arena *a = alloc(NULL, sizeof *a);
 uint32_t *son = alloc(NULL, 2 * w * sizeof *son);
 uint8_t *out = alloc(NULL, cap);
 int64_t got = -1;
 if (in && a && son && out) {
  memcpy(in, txt(bw), nb), memcpy(in + nb, txt(sw), len(sw));
  got = xe_go(in, n, (uint32_t) (n < 4096 ? 4096 : n), out, cap, a, son, ~(uint32_t) 0, nb); }
 if (in) alloc(in, 0);
 if (a) alloc(a, 0);
 if (son) alloc(son, 0);
 if (got >= 0 && ok(g = str0(g, (uintptr_t) got))) {  // pushes: out over the two
  memcpy(txt(g->sp[0]), out, (size_t) got);
  g->sp[2] = g->sp[0], g->sp += 2; }
 else if (ok(g)) g->sp[1] = ZeroPoint, g->sp += 1;
 if (out) alloc(out, 0);
 return g; }

// the base laid first in the output, the stream decoded after it, the base cut off
love_noinline static struct g *host_lzma2d_by(struct g *g) {
 word zw = g->sp[0], bw = g->sp[1];
 uintptr_t end, nb = strp(bw) ? len(bw) : 0;
 int64_t want = strp(zw) && strp(bw) ? l2_walk((const uint8_t*) txt(zw), len(zw), &end) : -1;
 if (want < 0 || (uint64_t) want + nb > XZ_MAX) { g->sp[1] = ZeroPoint, g->sp += 1; return g; }
 uint8_t *buf = alloc(NULL, nb + (uintptr_t) want + 1);
 struct lz_model *m = lz_new(4);
 int good = buf && m;
 if (good) memcpy(buf, txt(bw), nb), good = !l2_dec((const uint8_t*) txt(zw), buf, nb + (uintptr_t) want, m, nb);
 if (m) alloc(m, 0);
 if (good && ok(g = str0(g, (uintptr_t) want))) {
  memcpy(txt(g->sp[0]), buf + nb, (size_t) want);
  g->sp[2] = g->sp[0], g->sp += 2; }
 else if (ok(g)) g->sp[1] = ZeroPoint, g->sp += 1;
 if (buf) alloc(buf, 0);
 return g; }

// a .lzma body as it comes, in a cask: the model, the coder between feeds, the input a symbol
// might still want, and a window of the last dict bytes with LM_ROOM past them, slid down by
// a multiple of 16 as l2_slide does. a feed answers what its input decoded, LM_ROOM at most:
// past that it pauses and hands back the input it did not reach
#define LM_ROOM ((uintptr_t) 1 << 20)
#define LM_MAGIC 0x6c7a6d6131u
struct lm_st { uint64_t magic, n, cap, dict, tot, want, litn; uint32_t range, code, pend, started, done;
               uint8_t pin[LZ_REQ + 4]; struct lz_model m; };
#define LM_HEAD ((sizeof(struct lm_st) + 7) & ~(uintptr_t) 7)
static struct str *lm_cask(word x) {
 struct str *s = state_str(x);
 struct lm_st *S = s && s->len > LM_HEAD ? (struct lm_st*) s->bytes : NULL;
 return S && S->magic == LM_MAGIC && LM_HEAD + S->litn * sizeof(lzp) + S->cap == s->len ? s : NULL; }
love_noinline static struct g *host_lzma_new(struct g *g) {
 word pw = g->sp[0], dw = g->sp[1], nw = g->sp[2];
 struct lz_model pm;
 if (!oddp(pw) || !oddp(dw) || !oddp(nw) || getcharm(nw) < -1 || getcharm(pw) < 0
     || !lz_props(&pm, (unsigned) getcharm(pw), 12))
  return g->sp[2] = ZeroPoint, g->sp += 2, g;
 uintptr_t dict = (uintptr_t) getcharm(dw) & 0xffffffffu;
 intptr_t want = getcharm(nw);
 if (dict < 4096) dict = 4096;
 if (want >= 0 && (uintptr_t) want < dict) dict = want < 4096 ? 4096 : (uintptr_t) want;
 if (dict > XZ_MAX) return g->sp[2] = putcharm(1), g->sp += 2, g;
 uintptr_t litn = (uintptr_t) 0x300 << (pm.lc + pm.lp), cap = dict + LM_ROOM,
           n = LM_HEAD + litn * sizeof(lzp) + cap;
 union u *k = new_state(&g, n, LM_HEAD);
 if (!k) return g;
 struct lm_st *S = (struct lm_st*) ((struct state*) k)->str->bytes;
 S->magic = LM_MAGIC, S->cap = cap, S->dict = dict, S->litn = litn, S->want = (uint64_t) want;
 S->m.lc = pm.lc, S->m.lp = pm.lp, S->m.pb = pm.pb, S->m.lit = (lzp*) ((char*) S + LM_HEAD);
 lz_reset(&S->m);
 return g->sp[2] = word(k), g->sp += 2, g; }
love_noinline static struct g *host_lzma_feed(struct g *g) {
 struct str *cs = lm_cask(g->sp[0]);
 if (!cs || !strp(g->sp[1])) return g->sp[1] = ZeroPoint, g->sp += 1, g;
 struct lm_st *S = (struct lm_st*) cs->bytes;
 uintptr_t sn = len(g->sp[1]), in = S->pend + sn, o0 = S->n, used = 0;
 int last = !sn, rc = S->done ? 2 : 1;
 uint8_t *buf = alloc(NULL, in + 1);
 if (!buf) return g->sp[1] = ZeroPoint, g->sp += 1, g;
 memcpy(buf, S->pin, S->pend), memcpy(buf + S->pend, txt(g->sp[1]), sn);
 if (!S->done) {
  uint8_t *win = (uint8_t*) cs->bytes + LM_HEAD + S->litn * sizeof(lzp);
  S->m.lit = (lzp*) (cs->bytes + LM_HEAD);          // the cask moves: the pointer is laid again
  if (S->cap - S->n <= LZ_MAXLEN) {
   uintptr_t shift = (S->n - (S->n < S->dict ? S->n : S->dict)) & ~(uintptr_t) 15;
   memmove(win, win + shift, S->n - shift), S->n -= shift, o0 = S->n; }
  struct lz_rd r = { buf, 0, in, S->range, S->code, 0 };
  if (!S->started) {
   if (in < 5 && !last) rc = 3;
   else if (!rd_init(&r, buf, buf + in)) rc = 0;
   else S->started = 1; }
  if (S->started && rc == 1) {
   int known = S->want != (uint64_t) -1;
   struct lz_out o = { win, S->n, S->cap - S->n < LM_ROOM ? S->cap : S->n + LM_ROOM, 0, last ? 2 : 1 };
   rc = known && S->tot == S->want ? 1 : lz_run(&S->m, &r, &o, known ? S->n + (S->want - S->tot) : 0, !known);
   if (r.bad && rc) rc = 0;
   S->tot += o.n - S->n, S->n = o.n, S->range = r.range, S->code = r.code;
   if (rc == 1 && known && S->tot == S->want) rc = 2;
   else if (rc == 1 && last && o.n < o.cap - LZ_MAXLEN) rc = 0;   // the input over, the stream not
   used = r.i; }
  if (rc == 2) S->done = 1; }
 if (!rc) return S->magic = 0, alloc(buf, 0), g->sp[1] = ZeroPoint, g->sp += 1, g;
 uintptr_t on = S->n - o0, rest = in - used;
 if (rc == 3) {                                       // the rest kept for the next feed
  memcpy(S->pin, buf + used, rest), S->pend = (uint32_t) rest, rest = 0; }
 else S->pend = 0;
 uintptr_t need = str_width(on) + (rc == 3 ? 0 : str_width(rest) + Width(struct chain));
 if (!ok(g = have(g, need))) return alloc(buf, 0), g;
 cs = lm_cask(g->sp[0]), S = (struct lm_st*) cs->bytes;       // have may move it
 struct str *o = ini_str(bump(g, str_width(on)), on);
 memcpy(o->bytes, cs->bytes + LM_HEAD + S->litn * sizeof(lzp) + o0, on);
 if (rc == 3) return alloc(buf, 0), g->sp[1] = word(o), g->sp += 1, g;
 struct str *t = ini_str(bump(g, str_width(rest)), rest);
 memcpy(t->bytes, buf + used, rest);
 alloc(buf, 0);
 struct chain *c = ini_chain(bump(g, Width(struct chain)), (intptr_t) o, (intptr_t) t);
 return g->sp[1] = word(c), g->sp += 1, g; }


love_noinline static struct g *host_crc64(struct g *g) {
 if (!strp(g->sp[0])) { g->sp[0] = ZeroPoint; return g; }
 if (!ok(g = str0(g, 8))) return g;
 uint64_t c = xz_crc64((const uint8_t*) txt(g->sp[1]), len(g->sp[1]));
 for (int i = 0; i < 8; i++) ((uint8_t*) txt(g->sp[0]))[i] = (uint8_t) (c >> 8 * i);
 g->sp[1] = g->sp[0];
 return g->sp++, g; }

love_noinline static struct g *host_crc64_on(struct g *g) {
 word cw = g->sp[0], sw = g->sp[1];
 if (!strp(cw) || len(cw) != 8 || !strp(sw)) return g->sp[1] = ZeroPoint, g->sp += 1, g;
 if (!ok(g = str0(g, 8))) return g;              // pushes: out over c and s
 uint64_t c = 0;
 for (int i = 0; i < 8; i++) c |= (uint64_t) ((const uint8_t*) txt(g->sp[1]))[i] << 8 * i;
 c = xz_crc64_on(c, (const uint8_t*) txt(g->sp[2]), len(g->sp[2]));
 for (int i = 0; i < 8; i++) ((uint8_t*) txt(g->sp[0]))[i] = (uint8_t) (c >> 8 * i);
 return g->sp[2] = g->sp[0], g->sp += 2, g; }

#define L2_HEAD ((sizeof(struct l2_st) + 7) & ~(uintptr_t) 7)
static struct str *l2_cask(word x) {
 struct str *s = state_str(x);
 struct l2_st *S = s && s->len > L2_HEAD ? (struct l2_st*) s->bytes : NULL;
 return S && S->magic == L2_MAGIC && S->cap == s->len - L2_HEAD ? s : NULL; }
love_noinline static struct g *host_lzma2_new(struct g *g) {
 word dw = g->sp[0];
 if (!oddp(dw) || getcharm(dw) < 4096 || (uintptr_t) getcharm(dw) > XZ_MAX) return g->sp[0] = ZeroPoint, g;
 uintptr_t dict = (uintptr_t) getcharm(dw), n = L2_HEAD + dict + L2_ROOM(dict);
 union u *k = new_state(&g, n, L2_HEAD);
 if (!k) return g;
 struct l2_st *S = (struct l2_st*) ((struct state*) k)->str->bytes;
 S->magic = L2_MAGIC, S->cap = dict + L2_ROOM(dict), S->dict = dict, S->needdict = S->needprops = 1;
 return g->sp[0] = word(k), g; }
love_noinline static struct g *host_lzma2_chunk(struct g *g) {
 struct str *cs = l2_cask(g->sp[0]);
 if (!cs || !strp(g->sp[1])) return g->sp[1] = ZeroPoint, g->sp += 1, g;
 struct l2_st *S = (struct l2_st*) cs->bytes;
 S->m.lit = S->lit;                                 // the cask moves: the pointer is laid again
 uintptr_t o0 = 0;
 intptr_t got = l2_step(S, (uint8_t*) cs->bytes + L2_HEAD, (const uint8_t*) txt(g->sp[1]), len(g->sp[1]), &o0);
 if (got < 0) return S->magic = 0, g->sp[1] = ZeroPoint, g->sp += 1, g;   // a torn state is no state
 if (!ok(g = str0(g, (uintptr_t) got))) return g;   // pushes: out over st and c
 memcpy(txt(g->sp[0]), l2_cask(g->sp[1])->bytes + L2_HEAD + o0, (uintptr_t) got);
 return g->sp[2] = g->sp[0], g->sp += 2, g; }

// (lzma2e-new dict) -> a coder of one raw LZMA2 stream | (). (lzma2e-feed st b) -> the bytes b
// lets out, maybe "" | () torn; (lzma2e-end st) -> the rest and the end mark, the state spent
static struct str *xs_cask(word x) {
 struct str *s = state_str(x);
 struct xs_st *S = s && s->len >= sizeof(struct xs_st) ? (struct xs_st*) s->bytes : NULL;
 return S && S->magic == XS_MAGIC && S->size == s->len ? s : NULL; }
love_noinline static struct g *host_lzma2e_new(struct g *g) {
 word dw = g->sp[0];
 if (!oddp(dw) || getcharm(dw) < 4096 || getcharm(dw) > (1l << 30)) return g->sp[0] = ZeroPoint, g;
 struct xs_st L;
 uintptr_t n = xs_lay(&L, (uint32_t) getcharm(dw));
 union u *k = new_state(&g, n, L.obuf);            // the tables zero, the buffer not
 if (!k) return g;
 struct xs_st *S = (struct xs_st*) ((struct state*) k)->str->bytes;
 struct lzf f;
 memcpy(S, &L, sizeof L), S->magic = XS_MAGIC, S->c = (struct xe_ck) { 0, 1, 1, 1 };
 xe_arena_init(xs_view(S, &f));
 return g->sp[0] = word(k), g; }
static struct g *xs_lay1(struct g *g, int end) {
 uintptr_t ar = !end;                              // args past the state
 struct str *cs = xs_cask(g->sp[0]);
 if (!cs || (!end && !strp(g->sp[1]))) return g->sp[ar] = ZeroPoint, g->sp += ar, g;
 struct xs_st *S = (struct xs_st*) cs->bytes;
 uintptr_t n = end ? 0 : len(g->sp[1]), cap = xs_room(S, n, end);
 uint8_t *out = alloc(NULL, cap);
 intptr_t got = out ? xs_feed(S, end ? (const uint8_t*) "" : (const uint8_t*) txt(g->sp[1]), n, end, out, cap) : -1;
 if (got >= 0 && ok(g = str0(g, (uintptr_t) got))) {   // pushes: out over the args
  memcpy(txt(g->sp[0]), out, (uintptr_t) got);
  g->sp[ar + 1] = g->sp[0], g->sp += ar + 1; }
 else if (ok(g)) g->sp[ar] = ZeroPoint, g->sp += ar;
 if (out) alloc(out, 0);
 return g; }
love_noinline static struct g *host_lzma2e_feed(struct g *g) { return xs_lay1(g, 0); }
love_noinline static struct g *host_lzma2e_end(struct g *g) { return xs_lay1(g, 1); }

static LvmWrap(lvm_crc64_on, host_crc64_on)
static LvmWrap(lvm_lzma2e_new, host_lzma2e_new)
static LvmWrap(lvm_lzma2e_feed, host_lzma2e_feed)
static LvmWrap(lvm_lzma2e_end, host_lzma2e_end)
static LvmWrap(lvm_lzma2_new, host_lzma2_new)
static LvmWrap(lvm_lzma2_chunk, host_lzma2_chunk)
static LvmWrap(lvm_lzma2len, host_lzma2len)
static LvmWrap(lvm_lzma2d, host_lzma2d)
static LvmWrap(lvm_lzma2e, host_lzma2e)
static LvmWrap(lvm_lzma2e_by, host_lzma2e_by)
static LvmWrap(lvm_lzma2d_by, host_lzma2d_by)
static LvmWrap(lvm_lzma_new, host_lzma_new)
static LvmWrap(lvm_lzma_feed, host_lzma_feed)
static LvmWrap(lvm_crc64, host_crc64)

LvDef("lzma2len", lzma2len, 1, "xz");
LvDef("lzma2d", lzma2d, 1, "xz");
LvDef("lzma2e", lzma2e, 2, "xz");
LvDef("lzma2e-by", lzma2e_by, 2, "xz");
LvDef("lzma2d-by", lzma2d_by, 2, "xz");
LvDef("crc64", crc64, 1, "xz");
LvDef("crc64-on", crc64_on, 2, "xz");
LvDef("lzma2-new", lzma2_new, 1, "xz");
LvDef("lzma2-chunk", lzma2_chunk, 2, "xz");
LvDef("lzma-new", lzma_new, 3, "xz");
LvDef("lzma-feed", lzma_feed, 2, "xz");
LvDef("lzma2e-new", lzma2e_new, 1, "xz");
LvDef("lzma2e-feed", lzma2e_feed, 2, "xz");
LvDef("lzma2e-end", lzma2e_end, 1, "xz");
#endif
