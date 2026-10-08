// src/love/lib/xz.c -- LZMA and LZMA2, both directions, and xz's crc64. the codec only: src/apps/xz.l
// holds the .xz container, the block headers and the index, and says which door to take.
//   (lzma2d s)               a raw LZMA2 chunk stream -> its bytes | () | 1 past XZ_MAX
//   (lzma2len s)             the stream's length through its 0x00 end byte | ()
//   (lzma2e s dict)          bytes -> a raw LZMA2 stream, dict the match window | ()
//   (lzma2e-by s base)       s coded against base: the stream reaches into base as if it had
//                            just been said, and carries only s | ()
//   (lzma2d-by z base)       such a stream with its base -> s | ()
//   (lzmad s props dict n)   a .lzma body (after its 13-byte head) -> its bytes | () | 1 past
//                            XZ_MAX; n -1 unknown
//   (crc64 s)                CRC-64/XZ as the 8 little-endian bytes a check field holds
//   (crc64-on c s)           the same carried on: c what crc64 said of the bytes before s
//   (lzma2-new dict)         a state for LZMA2 a chunk at a time: the model, and a window of
//                            dict bytes (and a chunk's room) in place of the whole output
//   (lzma2-chunk st c)       one whole chunk (control byte, header, data) -> its bytes | ()
// the decoders read the output as their dictionary, so the window is everything said so far.
// the coder prices its way: an optimal parse over a binary-tree match finder.
#ifndef XZ_STANDALONE
#include "love.h"
#include "bytes.h"
#endif
#include <stdint.h>
#include <string.h>

#define LZ_BITS 11
#define LZ_ONE (1u << LZ_BITS)
#define LZ_MOVE 5
#define LZ_TOP (1u << 24)
#define LZ_MINLEN 2
#define LZ_MAXLEN 273
// the output is one string in the heap: past this a stream is refused, not grown into
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
 if (b >= 225) return 0;
 m->lc = b % 9; b /= 9; m->lp = b % 5; m->pb = b / 5;
 return m->lc + m->lp <= maxlclp; }

static unsigned lz_litst(unsigned s) { return s < 4 ? 0 : s < 10 ? s - 3 : s - 6; }

// --- the range decoder: normalize before each bit --------------------------------------------
struct lz_rd { const uint8_t *p, *e; uint32_t range, code; int bad; };

static int rd_init(struct lz_rd *r, const uint8_t *p, const uint8_t *e) {
 if (e - p < 5 || p[0]) return 0;
 r->p = p + 5; r->e = e; r->range = 0xffffffffu; r->bad = 0;
 r->code = (uint32_t) p[1] << 24 | (uint32_t) p[2] << 16 | (uint32_t) p[3] << 8 | p[4];
 return 1; }

static void rd_norm(struct lz_rd *r) {
 if (r->range < LZ_TOP) {
  r->range <<= 8;
  if (r->p < r->e) r->code = r->code << 8 | *r->p++; else r->bad = 1, r->code <<= 8; } }

// the decoder's steps, on lz_run's locals (rg the range, cd the code, ip the input to r->e):
// written in place so the loop makes no call and mooncc keeps them in registers. word-wide, as
// a narrow one is a zero-extend after every step; a range under LZ_TOP shifted still fits 32 bits.
// past the input's end ip counts on over zeros, so a short stream is ip > r->e, asked per symbol.
#define LZ_NORM() if (rg < LZ_TOP) { rg <<= 8, cd = cd << 8 | (ip < r->e ? *ip : 0), ip++; }
#define LZ_BIT(pp, b) { lzp *p_ = (pp); uintptr_t w_ = *p_, q_; LZ_NORM() q_ = (rg >> LZ_BITS) * w_; \
 if (cd < q_) rg = q_, *p_ = (lzp) (w_ + ((LZ_ONE - w_) >> LZ_MOVE)), b = 0; \
 else rg -= q_, cd -= q_, *p_ = (lzp) (w_ - (w_ >> LZ_MOVE)), b = 1; }
// ..and without a branch, for the bits of a tree, whose outcomes no predictor guesses: k_ is
// all ones for a 1. the range keeps its bound or loses it, the prob moves toward the outcome.
#define LZ_BITF(pp, b) { lzp *p_ = (pp); uintptr_t w_ = *p_, q_, k_; LZ_NORM() q_ = (rg >> LZ_BITS) * w_; \
 b = cd >= q_, k_ = 0 - b; \
 rg = (q_ & ~k_) | ((rg - q_) & k_), cd -= q_ & k_; \
 *p_ = (lzp) (w_ + (((LZ_ONE - w_) >> LZ_MOVE) & ~k_) - ((w_ >> LZ_MOVE) & k_)); }
#define LZ_TREE(pp, n, v) { lzp *t_ = (pp); uintptr_t m_ = 1, b_; \
 while (m_ < ((uintptr_t) 1 << (n))) { LZ_BITF(t_ + m_, b_) m_ = m_ << 1 | b_; } \
 v = m_ - ((uintptr_t) 1 << (n)); }
#define LZ_RTREE(pp, n, v) { lzp *t_ = (pp); uintptr_t m_ = 1, b_, v_ = 0; \
 for (uintptr_t i_ = 0; i_ < (n); i_++) { LZ_BITF(t_ + m_, b_) m_ = m_ << 1 | b_, v_ |= b_ << i_; } \
 v = v_; }
#define LZ_LEN(l, ps, v) { uintptr_t c_; LZ_BIT(&(l)->choice, c_) \
 if (!c_) LZ_TREE((l)->low[ps], 3, v) \
 else { LZ_BIT(&(l)->choice2, c_) \
        if (!c_) { LZ_TREE((l)->mid[ps], 3, v) v += 8; } \
        else { LZ_TREE((l)->high, 8, v) v += 16; } } }

// the output, which is the dictionary. `grow` lets a sizeless .lzma double it as it goes.
struct lz_out { uint8_t *b; uintptr_t n, cap, base; int grow, big; };

static int out_room(struct lz_out *o, uintptr_t k) {
 if (o->n + k <= o->cap) return 1;
 if (!o->grow) return 0;
 if (o->n + k > XZ_MAX) return o->big = 1, 0;
 uintptr_t c = o->cap < 65536 ? 65536 : o->cap;
 while (c < o->n + k) c *= 2;
 uint8_t *nb = alloc(NULL, c);
 if (!nb) return 0;
 if (o->n) memcpy(nb, o->b, o->n);
 if (o->b) alloc(o->b, 0);
 o->b = nb; o->cap = c; return 1; }

// decode until `lim` bytes stand in the output or, with eopm, the end marker says so.
// -> 1 done, 2 the marker seen, 0 corrupt. a match may not run past lim. the coder, the
// state and rep0 ride locals, back in r and m at the end for the next chunk; the other reps
// move only on a rep, and stay in m.
static int lz_run(struct lz_model *m, struct lz_rd *r, struct lz_out *o, uintptr_t lim, int eopm) {
 uintptr_t rg = r->range, cd = r->code, st = m->state, r0 = m->reps[0], n = o->n, b, len, d;
 const uint8_t *ip = r->p;
 uint8_t *ob = o->b;
 int rc = 1;
 if (r->bad) ip = r->e + 1;
 if (eopm) lim = ~(uintptr_t) 0;
 while (n < lim) {
  uintptr_t ps = n & (((uintptr_t) 1 << m->pb) - 1);
  if (ip > r->e) { rc = 0; break; }
  LZ_BIT(&m->ismatch[st][ps], b)
  if (!b) {
   if (n >= o->cap) {
    o->n = n;
    if (!out_room(o, 1)) { rc = 0; break; }
    ob = o->b; }
   uintptr_t prev = n > o->base ? ob[n - 1] : 0, s = 1;
   lzp *p = m->lit + 0x300 * (((n & (((uintptr_t) 1 << m->lp) - 1)) << m->lc) + (prev >> (8 - m->lc)));
   if (st >= 7) {                                 // led by the byte at rep0 while the bits agree:
    if (n - o->base <= r0) { rc = 0; break; }     // off stays 0x100 until one differs, then 0
    uintptr_t mb = ob[n - r0 - 1], off = 0x100, mbit;
    while (s < 0x100) {
     mb <<= 1, mbit = mb & off;
     LZ_BITF(p + off + mbit + s, b)
     s = s << 1 | b, off &= (0 - b) ^ ~mbit; } }
   else while (s < 0x100) { LZ_BITF(p + s, b) s = s << 1 | b; }
   ob[n++] = (uint8_t) s;
   st = st < 4 ? 0 : st < 10 ? st - 3 : st - 6;
   continue; }
  LZ_BIT(&m->isrep[st], b)
  if (!b) {
   LZ_LEN(&m->len, ps, len)
   st = st < 7 ? 7 : 10;
   uintptr_t slot, v;
   LZ_TREE(m->slot[len < 3 ? len : 3], 6, slot)
   d = slot;
   if (slot >= 4) {
    uintptr_t fb = (slot >> 1) - 1;
    d = (2 | (slot & 1)) << fb;
    if (slot < 14) { LZ_RTREE(m->spec + d - slot - 1, fb, v) d += v; }
    else {
     v = 0;
     for (uintptr_t k = fb - 4; k; k--) {         // the direct bits, half the range each
      LZ_NORM()
      rg >>= 1, b = cd >= rg;
      cd -= rg & (0 - b), v = v << 1 | b; }
     d += v << 4;
     LZ_RTREE(m->align, 4, v) d += v; } }
   if (d == 0xffffffffu) { rc = eopm && ip <= r->e ? 2 : 0; break; }
   m->reps[3] = m->reps[2], m->reps[2] = m->reps[1], m->reps[1] = (uint32_t) r0, r0 = d; }
  else {
   LZ_BIT(&m->isg0[st], b)
   if (!b) {
    LZ_BIT(&m->isrep0l[st][ps], b)
    if (!b) {                                     // the short rep: one byte from rep0
     if (n - o->base <= r0) { rc = 0; break; }
     if (n >= o->cap) {
      o->n = n;
      if (!out_room(o, 1)) { rc = 0; break; }
      ob = o->b; }
     ob[n] = ob[n - r0 - 1], n++;
     st = st < 7 ? 9 : 11;
     continue; } }
   else {
    LZ_BIT(&m->isg1[st], b)
    if (!b) d = m->reps[1];
    else {
     LZ_BIT(&m->isg2[st], b)
     if (!b) d = m->reps[2]; else d = m->reps[3], m->reps[3] = m->reps[2];
     m->reps[2] = m->reps[1]; }
    m->reps[1] = (uint32_t) r0, r0 = d; }
   LZ_LEN(&m->rep, ps, len)
   st = st < 7 ? 8 : 11; }
  len += LZ_MINLEN;
  if (n - o->base <= r0 || ip > r->e || lim - n < len) { rc = 0; break; }
  if (o->cap - n < len) {
   o->n = n;
   if (!out_room(o, len)) { rc = 0; break; }
   ob = o->b; }
  uint8_t *dp = ob + n, *sp = dp - r0 - 1, *de = dp + len;
#if wideld
  if (r0 >= 7 && o->cap - n >= len + 8)              // whole words, the last running into room
   for (; dp < de; dp += 8, sp += 8) st64(dp, ld64(sp));
  else
#endif
  for (; dp < de; dp++, sp++) *dp = *sp;
  n += len; }
 r->range = (uint32_t) rg, r->code = (uint32_t) cd, r->bad = ip > r->e, r->p = r->bad ? r->e : ip;
 m->state = (unsigned) st, m->reps[0] = (uint32_t) r0;
 o->n = n;
 return rc; }

// --- LZMA2: the chunk walk ------------------------------------------------------------------
// the header pass alone sizes the output and finds the end byte; -> total bytes, *end the
// offset past 0x00; -1 a malformed walk.
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

// decode the chunks into out (cap its exact size). -> 0 ok, -1 corrupt. the reset rules:
// a dict reset first, props before the first LZMA chunk and after a 0x01.
static int l2_dec(const uint8_t *s, uint8_t *out, uintptr_t cap, struct lz_model *m, uintptr_t pre) {
 struct lz_out o = { out, pre, cap, 0, 0, 0 };        // pre bytes of out said already: a preset base
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
  if (r.bad || r.p != r.e || r.code) return -1;
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

// --- the coder's symbols (lc 3, lp 0, pb 2) ---------------------------------------------------
#define XE_PBM 3u

static void xe_lit(struct lz_model *m, struct lz_rc *e, const uint8_t *s, uintptr_t p) {
 unsigned st = m->state;
 rc_bit(e, &m->ismatch[st][p & XE_PBM], 0);
 lzp *pr = m->lit + 0x300 * ((p ? s[p - 1] : 0) >> 5);
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

// --- the match finder: a binary tree over the whole input, the window its dict -------------
// each position under a 4-byte hash roots a tree of the earlier ones sharing it, ordered by
// what follows them, so one walk down finds the longest matches and re-roots the tree at the
// new position. 2- and 3-byte heads find the nearest short ones. entries are position + 1.
#define XE_H4BITS 20
#define XE_DEPTH 48
#define XE_SKIPDEPTH 8                          // a position indexed with no matches asked
#define XE_NICE 96
#define XE_MAXM 64

struct xe_mf { const uint8_t *s; uintptr_t n; uint32_t *h2, *h3, *h4, *son, wmask, dict; uintptr_t ins; };

static uint32_t xe_h3(const uint8_t *s) { return ((uint32_t) s[0] << 16 ^ (uint32_t) s[1] << 8 ^ s[2]) * 2654435761u >> 16; }
static uint32_t xe_h4(const uint8_t *s) {
 return ((uint32_t) s[0] | (uint32_t) s[1] << 8 | (uint32_t) s[2] << 16 | (uint32_t) s[3] << 24) * 2654435761u >> (32 - XE_H4BITS); }

static unsigned xe_mlen(const uint8_t *a, const uint8_t *b, unsigned lim) {
 unsigned k = 0;
#if wideld
 for (; k + 8 <= lim; k += 8) {                 // a word at a time: the first byte that differs
  uint64_t x = ld64(a + k) ^ ld64(b + k);       // is the lowest set one, little-endian
  if (x) return k + (unsigned) (__builtin_ctzll(x) >> 3); }
#endif
 while (k < lim && a[k] == b[k]) k++;
 return k; }

// position p into the heads and its tree; with ls, every match longer than the nearer ones
// (lengths rising in ls, distances less one in ds) -> how many. lim the bytes p may match.
static unsigned xe_bt(struct xe_mf *f, uintptr_t p, unsigned lim, uint32_t *ls, uint32_t *ds) {
 const uint8_t *s = f->s, *sp = s + p;
 unsigned k = 0, best = 1;
 uintptr_t reach = f->dict < f->wmask ? f->dict : f->wmask;
 if (p + 2 > f->n) return 0;
 uint32_t h2 = (uint32_t) sp[0] | (uint32_t) sp[1] << 8, c2 = f->h2[h2];
 f->h2[h2] = (uint32_t) p + 1;
 if (ls && c2 && p - (c2 - 1) <= reach && lim >= 2 && s[c2 - 1] == sp[0] && s[c2] == sp[1])
  best = 2, ls[0] = 2, ds[0] = (uint32_t) (p - c2), k = 1;
 if (p + 3 > f->n) return k;
 uint32_t h3 = xe_h3(sp), c3 = f->h3[h3];
 f->h3[h3] = (uint32_t) p + 1;
 if (ls && c3 && p - (c3 - 1) <= reach && lim >= 3) {
  unsigned l = xe_mlen(s + c3 - 1, sp, lim);
  if (l >= 3) {
   if (k && ds[0] == p - c3) k = 0;               // the same match, longer
   best = l, ls[k] = l, ds[k] = (uint32_t) (p - c3), k++; } }
 if (p + 4 > f->n) return k;
 uint32_t h4 = xe_h4(sp), c = f->h4[h4];
 f->h4[h4] = (uint32_t) p + 1;
 uint32_t *lo = f->son + 2 * (p & f->wmask), *hi = lo + 1;   // the new root's two sides
 unsigned llo = 0, lhi = 0, depth = ls ? XE_DEPTH : XE_SKIPDEPTH, cut = lim < XE_NICE ? lim : XE_NICE;
 for (;;) {
  uintptr_t q = c - 1;
  if (!c || p - q > reach || !depth--) { *lo = *hi = 0; break; }
  uint32_t *pair = f->son + 2 * (q & f->wmask);
  unsigned l = llo < lhi ? llo : lhi;
  l += xe_mlen(s + q + l, sp + l, cut - l);
  if (l > best && ls && k < XE_MAXM) {
   if (k && ds[k - 1] == p - q - 1) k--;
   best = l, ls[k] = l, ds[k] = (uint32_t) (p - q - 1), k++; }
  if (l >= cut) { *lo = pair[0], *hi = pair[1]; break; }    // its subtrees become the root's
  if (s[q + l] < sp[l]) *lo = c, lo = pair + 1, c = *lo, llo = l;
  else *hi = c, hi = pair, c = *hi, lhi = l; }
 return k; }

// index every position below upto that is not yet, with no matches asked
static void xe_ins(struct xe_mf *f, uintptr_t upto) {
 for (; f->ins < upto; f->ins++) {
  uintptr_t left = f->n - f->ins;
  xe_bt(f, f->ins, left > LZ_MAXLEN ? LZ_MAXLEN : (unsigned) left, NULL, NULL); } }

// the matches at p -> how many; a position a plan that ran further indexed already has none
static unsigned xe_all(struct xe_mf *f, uintptr_t p, unsigned avail, uint32_t *ls, uint32_t *ds) {
 xe_ins(f, p);
 if (f->ins != p) return 0;
 f->ins = p + 1;
 return xe_bt(f, p, avail, ls, ds); }

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
   uint32_t base = (2 | (sl & 1)) << fb;
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
 const lzp *pr = m->lit + 0x300 * ((p ? s[p - 1] : 0) >> 5);
 if (st < 7) return xp_tree(x, pr, 8, s[p]);
 unsigned mb = s[p - r0 - 1], off = 0x100, sym = s[p] | 0x100;
 uint32_t c = 0;
 do {
  mb <<= 1;
  c += xp_bit(x, pr[off + (mb & off) + (sym >> 8)], (sym >> 7) & 1);
  sym <<= 1, off &= ~(mb ^ sym); } while (sym < 0x10000);
 return c; }

// --- the optimal parse: the cheapest way through the next stretch, priced ---------------------
// node i is the input i bytes on: its cheapest price from the plan's start, the op that reached
// it (back: a rep 0..3, a match's distance + 4, XB_LIT or XB_SHORT) from node prev, and the
// state and reps that path leaves. a plan runs until no op from a node reached so far reaches
// further, or a match at nice length is taken whole, or XE_OPTS.
#define XE_OPTS 2048
#define XB_LIT 0xffffffffu
#define XB_SHORT 0xfffffffeu
struct xe_node { uint32_t price, back, reps[4]; uint16_t prev, len; uint8_t state; };
struct xe_op { uint32_t back, len; };

static void xn_take(struct xe_node *nd, uint32_t i, uint32_t price, uint32_t from, uint32_t back) {
 if (price < nd[i].price) nd[i].price = price, nd[i].prev = (uint16_t) from, nd[i].back = back; }
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
  b->reps[0] = b->back - 4, b->state = st < 7 ? 7 : 10; } }

// -> how many ops, in ops, to cover the stretch from p (avail bytes on at most)
static unsigned xe_plan(struct lz_model *m, struct xe_mf *f, struct xe_px *x, struct xe_node *nd,
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
  // the reps
  unsigned rl[4], rmax = 0, ri = 0;
  for (unsigned i = 0; i < 4; i++) {
   rl[i] = 0;
   if (avail < 2 || q <= c->reps[i]) continue;
   const uint8_t *r = s + q - c->reps[i] - 1;
   if (r[0] == s[q] && r[1] == s[q + 1]) rl[i] = xe_mlen(r, s + q, avail);
   if (rl[i] > rmax) rmax = rl[i], ri = i; }
  // the matches, from the finder; one at nice length (or a rep) is taken whole
  unsigned k = xe_all(f, q, avail, ls, ds), ml = k ? ls[k - 1] : 0;
  if (rmax >= XE_NICE || ml >= XE_NICE) {
   uint32_t L = rmax >= ml ? rmax : ml;
   while (end_ < cur + L) nd[++end_].price = XP_INF;
   nd[cur + L].price = 0, nd[cur + L].prev = (uint16_t) cur;
   nd[cur + L].back = rmax >= ml ? ri : ds[k - 1] + 4;
   end_ = cur + L; cur = end_; break; }
  uint32_t top = cur + (rmax > ml ? rmax : ml);
  while (end_ < top) nd[++end_].price = XP_INF;
  for (unsigned i = 0; i < 4; i++) {
   if (rl[i] < 2) continue;
   uint32_t pr = prep + (i == 0 ? xp_bit(x, m->isg0[st], 0) + xp_bit(x, m->isrep0l[st][ps], 1)
                       : xp_bit(x, m->isg0[st], 1) + (i == 1 ? xp_bit(x, m->isg1[st], 0)
                         : xp_bit(x, m->isg1[st], 1) + xp_bit(x, m->isg2[st], i == 3)));
   for (unsigned L = 2; L <= rl[i]; L++) xn_take(nd, cur + L, pr + x->rep[ps][L - 2], cur, i); }
  uint32_t pmat = pm1 + xp_bit(x, m->isrep[st], 0);
  for (unsigned j = 0, L = 2; j < k; j++)
   for (; L <= ls[j]; L++)
    xn_take(nd, cur + L, pmat + x->len[ps][L - 2] + xp_dist(x, ds[j], L), cur, ds[j] + 4); }
 // back from the end, the ops in order
 unsigned n = 0;
 for (uint32_t i = cur; i; i = nd[i].prev) nd[i].len = (uint16_t) (i - nd[i].prev), n++;
 unsigned k = n;
 for (uint32_t i = cur; i; i = nd[i].prev) k--, ops[k].back = nd[i].back, ops[k].len = nd[i].len;
 return n; }

// the whole stream into out (cap bytes, sized by the caller for the worst case) -> its
// length, or -1. a chunk is coded speculatively into cs; one that does not shrink goes raw.
#define XE_CU (2u << 20)
#define XE_CC 65536u
#define XE_CSLACK 256u

struct xe_arena { struct lz_model m; lzp lit[0x300 << 3]; uint8_t cs[XE_CC + XE_CSLACK];
                  uint32_t h2[1u << 16], h3[1u << 16], h4[1u << XE_H4BITS];
                  struct xe_px px; struct xe_node nd[XE_OPTS + LZ_MAXLEN + 2]; struct xe_op ops[XE_OPTS + 1];
                  uint32_t ls[XE_MAXM], ds[XE_MAXM]; };

// the bytes below p0 are a base the decoder holds already: indexed, never coded
static int64_t xe_go(const uint8_t *s, uintptr_t n, uint32_t dict, uint8_t *out, uintptr_t cap,
                     struct xe_arena *a, uint32_t *son, uint32_t wmask, uintptr_t p0) {
 struct lz_model *m = &a->m;
 struct xe_mf f = { s, n, a->h2, a->h3, a->h4, son, wmask, dict, 0 };
 uintptr_t p = p0, o = 0;
 int first = !p0, needprops = 1, needstate = 1;
 memset(a->h2, 0, sizeof a->h2), memset(a->h3, 0, sizeof a->h3), memset(a->h4, 0, sizeof a->h4);
 xe_ins(&f, p0);
 m->lit = a->lit; m->lc = 3; m->lp = 0; m->pb = 2;
 xp_init(&a->px);
 while (p < n) {
  uintptr_t start = p, uend = n - p > XE_CU ? p + XE_CU : n;
  unsigned rst = first ? 3 : needprops ? 2 : needstate ? 1 : 0;
  struct lz_rc e;
  if (rst) lz_reset(m), a->px.left = 0;
  rc_init(&e, a->cs, sizeof a->cs);
  unsigned pn = 0, pi = 0;                         // a plan holds within its chunk
  while (p < uend && rc_size(&e) < XE_CC - XE_CSLACK) {
   if (pi == pn) {
    if (!a->px.left) xp_price(&a->px, m);
    pn = xe_plan(m, &f, &a->px, a->nd, a->ops, a->ls, a->ds, p, uend), pi = 0; }
   struct xe_op *op = a->ops + pi++;
   if (a->px.left) a->px.left--;
   if (op->back == XB_LIT) xe_lit(m, &e, s, p);
   else if (op->back == XB_SHORT) xe_rep(m, &e, p, 0, 1);
   else if (op->back < 4) xe_rep(m, &e, p, op->back, op->len);
   else xe_match(m, &e, p, op->back - 4, op->len);
   p += op->len;
   xe_ins(&f, p); }
  rc_flush(&e);
  uintptr_t u = p - start, c = e.n;
  if (c > XE_CC) return -1;
  if (c < u) {
   if (cap - o < c + 6) return -1;
   out[o++] = (uint8_t) (0x80 | rst << 5 | (u - 1) >> 16);
   out[o++] = (uint8_t) ((u - 1) >> 8); out[o++] = (uint8_t) (u - 1);
   out[o++] = (uint8_t) ((c - 1) >> 8); out[o++] = (uint8_t) (c - 1);
   if (rst >= 2) out[o++] = 0x5d;
   memcpy(out + o, a->cs, c); o += c;
   first = needprops = needstate = 0; }
  else {
   for (uintptr_t q = start; q < p; ) {
    uintptr_t k = p - q > 65536 ? 65536 : p - q;
    if (cap - o < k + 3) return -1;
    out[o++] = first ? 1 : 2; out[o++] = (uint8_t) ((k - 1) >> 8); out[o++] = (uint8_t) (k - 1);
    memcpy(out + o, s + q, k); o += k; q += k;
    if (first) needprops = 1;
    first = 0; }
   needstate = 1; } }
 if (cap - o < 1) return -1;
 out[o++] = 0;
 return (int64_t) o; }

static uintptr_t xe_cap(uintptr_t n) { return n + 16 * (n / 65536 + 2); }

// --- crc64 ----------------------------------------------------------------------------------
static uint64_t xz_crc64_on(uint64_t c0, const uint8_t *p, uintptr_t n) {
 uint64_t t[256], c = ~c0;
 for (unsigned i = 0; i < 256; i++) {
  uint64_t v = i;
  for (int k = 0; k < 8; k++) v = v & 1 ? v >> 1 ^ 0xc96c5795d7870f42ull : v >> 1;
  t[i] = v; }
 while (n--) c = t[(c ^ *p++) & 255] ^ c >> 8;
 return ~c; }
static uint64_t xz_crc64(const uint8_t *p, uintptr_t n) { return xz_crc64_on(0, p, n); }

// --- LZMA2 a chunk at a time ---------------------------------------------------------------
// the window holds the last dict bytes out and room for one chunk's (2 MiB at most); a chunk
// that would not fit slides it down first, by a multiple of 16 so the position bits (pb, lp,
// at most 4 each) read the same off the window as off the whole output. a match reaches no
// further back than the window holds, which is every distance the dictionary allows. the
// reset rules are l2_dec's.
#define L2_ROOM (((uintptr_t) 1 << 21) + 16)
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
 struct lz_out o = { win, S->n, S->cap, S->base, 0, 0 };
 struct lz_rd r;
 if (!rd_init(&r, s + h, s + h + k) || lz_run(&S->m, &r, &o, o.n + u, 0) != 1) return -1;
 rd_norm(&r);
 if (r.bad || r.p != r.e || r.code) return -1;
 *o0 = S->n, S->n = o.n;
 return (intptr_t) u; }

// the lzma model with room for lc + lp up to lim, from alloc -> or NULL
static struct lz_model *lz_new(unsigned lclp) {
 struct lz_model *m = alloc(NULL, sizeof *m + ((uintptr_t) 0x300 << lclp) * sizeof(lzp));
 if (m) m->lit = (lzp*) (m + 1);
 return m; }

#ifndef XZ_STANDALONE
// ===== the nifs: str0 may collect, so a string is re-read off the stack after it =====
love_noinline static struct g *host_lzma2len(struct g *g) {
 word sw = g->sp[0];
 uintptr_t end;
 g->sp[0] = strp(sw) && l2_walk((const uint8_t*) txt(sw), len(sw), &end) >= 0
            ? putcharm((intptr_t) end) : ZeroPoint;
 return g; }

// a raw LZMA2 stream into exactly cap bytes of out, for a C caller with no g (src/love/lib/srctree.c)
// -> cap, or -1 for one that is torn or says more or less than that
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

love_noinline static struct g *host_lzmad(struct g *g) {
 word sw = g->sp[0], pw = g->sp[1], nw = g->sp[3];
 struct lz_model *m = NULL;
 struct lz_model pm;
 if (!strp(sw) || !oddp(pw) || !oddp(nw) || !oddp(g->sp[2]) || getcharm(nw) < -1
     || getcharm(pw) < 0 || !lz_props(&pm, (unsigned) getcharm(pw), 12)
     || !(m = lz_new(pm.lc + pm.lp))) {
  g->sp[3] = ZeroPoint, g->sp += 3; return g; }
 m->lc = pm.lc; m->lp = pm.lp; m->pb = pm.pb;
 lz_reset(m);
 intptr_t want = getcharm(nw);
 struct lz_rd r;
 int rc = 0;
 if (want >= 0 && (uintptr_t) want > XZ_MAX) {
  alloc(m, 0);
  g->sp[3] = putcharm(1), g->sp += 3; return g; }
 if (want >= 0) {                                   // the size is known: straight into the string
  if (!ok(g = str0(g, (uintptr_t) want))) { alloc(m, 0); return g; }
  struct lz_out o = { (uint8_t*) txt(g->sp[0]), 0, (uintptr_t) want, 0, 0, 0 };
  const uint8_t *s = (const uint8_t*) txt(g->sp[1]);
  rc = rd_init(&r, s, s + len(g->sp[1])) && lz_run(m, &r, &o, (uintptr_t) want, 0) && !r.bad;
  alloc(m, 0);
  g->sp[4] = rc ? g->sp[0] : ZeroPoint, g->sp += 4;
  return g; }
 struct lz_out o = { NULL, 0, 0, 0, 1, 0 };
 const uint8_t *s = (const uint8_t*) txt(sw);
 rc = rd_init(&r, s, s + len(sw)) && lz_run(m, &r, &o, 0, 1) == 2;
 alloc(m, 0);
 if (rc && ok(g = str0(g, o.n))) {
  if (o.n) memcpy(txt(g->sp[0]), o.b, o.n);
  g->sp[4] = g->sp[0], g->sp += 4; }
 else if (ok(g)) g->sp[3] = o.big ? putcharm(1) : ZeroPoint, g->sp += 3;
 if (o.b) alloc(o.b, 0);
 return g; }

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
 struct str *s = cask_str(x);
 struct l2_st *S = s && s->len > L2_HEAD ? (struct l2_st*) s->bytes : NULL;
 return S && S->magic == L2_MAGIC && S->cap == s->len - L2_HEAD ? s : NULL; }
love_noinline static struct g *host_lzma2_new(struct g *g) {
 word dw = g->sp[0];
 if (!oddp(dw) || getcharm(dw) < 4096 || (uintptr_t) getcharm(dw) > XZ_MAX) return g->sp[0] = ZeroPoint, g;
 uintptr_t dict = (uintptr_t) getcharm(dw), n = L2_HEAD + dict + L2_ROOM,
           sreq = str_width(n), breq = Width(struct cask) + Width(struct tag);
 if (!ok(g = have(g, sreq + breq))) return g;
 struct str *s = ini_str(bump(g, sreq), n);
 memset(s->bytes, 0, L2_HEAD);
 struct l2_st *S = (struct l2_st*) s->bytes;
 S->magic = L2_MAGIC, S->cap = dict + L2_ROOM, S->dict = dict, S->needdict = S->needprops = 1;
 union u *k = bump(g, breq);
 cask(k)->ap = lvm_cask, cask(k)->str = s;
 tagthread(k, Width(struct cask));
 return g->sp[0] = word(k), g; }
love_noinline static struct g *host_lzma2_chunk(struct g *g) {
 struct str *cs = l2_cask(g->sp[0]);
 if (!cs || !strp(g->sp[1])) return g->sp[1] = ZeroPoint, g->sp += 1, g;
 struct l2_st *S = (struct l2_st*) cs->bytes;
 S->m.lit = S->lit;                                 // the cask moves: the pointer is laid again
 uintptr_t o0 = 0;
 intptr_t got = l2_step(S, (uint8_t*) cs->bytes + L2_HEAD, (const uint8_t*) txt(g->sp[1]), len(g->sp[1]), &o0);
 if (got < 0) return g->sp[1] = ZeroPoint, g->sp += 1, g;
 if (!ok(g = str0(g, (uintptr_t) got))) return g;   // pushes: out over st and c
 memcpy(txt(g->sp[0]), l2_cask(g->sp[1])->bytes + L2_HEAD + o0, (uintptr_t) got);
 return g->sp[2] = g->sp[0], g->sp += 2, g; }

static LvmWrap(lvm_crc64_on, host_crc64_on)
static LvmWrap(lvm_lzma2_new, host_lzma2_new)
static LvmWrap(lvm_lzma2_chunk, host_lzma2_chunk)
static LvmWrap(lvm_lzma2len, host_lzma2len)
static LvmWrap(lvm_lzma2d, host_lzma2d)
static LvmWrap(lvm_lzma2e, host_lzma2e)
static LvmWrap(lvm_lzma2e_by, host_lzma2e_by)
static LvmWrap(lvm_lzma2d_by, host_lzma2d_by)
static LvmWrap(lvm_lzmad, host_lzmad)
static LvmWrap(lvm_crc64, host_crc64)

LvDef("lzma2len", lzma2len, 1, "xz");
LvDef("lzma2d", lzma2d, 1, "xz");
LvDef("lzma2e", lzma2e, 2, "xz");
LvDef("lzma2e-by", lzma2e_by, 2, "xz");
LvDef("lzma2d-by", lzma2d_by, 2, "xz");
LvDef("lzmad", lzmad, 4, "xz");
LvDef("crc64", crc64, 1, "xz");
LvDef("crc64-on", crc64_on, 2, "xz");
LvDef("lzma2-new", lzma2_new, 1, "xz");
LvDef("lzma2-chunk", lzma2_chunk, 2, "xz");
#endif
