// inle/xz.c -- LZMA and LZMA2, both directions, and xz's crc64. the codec only: apps/xz.l
// holds the .xz container, the block headers and the index, and says which door to take.
//   (lzma2d s)               a raw LZMA2 chunk stream -> its bytes | ()
//   (lzma2len s)             the stream's length through its 0x00 end byte | ()
//   (lzma2e s dict)          bytes -> a raw LZMA2 stream, dict the match window | ()
//   (lzmad s props dict n)   a .lzma body (after its 13-byte head) -> its bytes | (); n -1 unknown
//   (crc64 s)                CRC-64/XZ as the 8 little-endian bytes a check field holds
// the decoders read the output as their dictionary, so the window is everything said so far.
// the coder's parse is a fast one: reps first, the longest chain match, one lazy look.
#ifndef XZ_STANDALONE
#include "love.h"
#endif
#include <stdint.h>
#include <string.h>

#define LZ_BITS 11
#define LZ_ONE (1u << LZ_BITS)
#define LZ_MOVE 5
#define LZ_TOP (1u << 24)
#define LZ_MINLEN 2
#define LZ_MAXLEN 273

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

static unsigned rd_bit(struct lz_rd *r, lzp *p) {
 rd_norm(r);
 uint32_t b = (r->range >> LZ_BITS) * *p;
 if (r->code < b) { r->range = b; *p += (LZ_ONE - *p) >> LZ_MOVE; return 0; }
 r->range -= b; r->code -= b; *p -= *p >> LZ_MOVE; return 1; }

static unsigned rd_tree(struct lz_rd *r, lzp *p, unsigned n) {
 unsigned m = 1;
 for (unsigned i = 0; i < n; i++) m = m << 1 | rd_bit(r, p + m);
 return m - (1u << n); }

static unsigned rd_rtree(struct lz_rd *r, lzp *p, unsigned n) {
 unsigned m = 1, v = 0;
 for (unsigned i = 0; i < n; i++) { unsigned b = rd_bit(r, p + m); m = m << 1 | b; v |= b << i; }
 return v; }

static uint32_t rd_direct(struct lz_rd *r, unsigned n) {
 uint32_t v = 0;
 while (n--) {
  rd_norm(r);
  r->range >>= 1;
  if (r->code >= r->range) r->code -= r->range, v = v << 1 | 1; else v <<= 1; }
 return v; }

static unsigned rd_len(struct lz_rd *r, struct lz_len *l, unsigned ps) {
 if (!rd_bit(r, &l->choice)) return rd_tree(r, l->low[ps], 3);
 if (!rd_bit(r, &l->choice2)) return 8 + rd_tree(r, l->mid[ps], 3);
 return 16 + rd_tree(r, l->high, 8); }

// the output, which is the dictionary. `grow` lets a sizeless .lzma double it as it goes.
struct lz_out { uint8_t *b; uintptr_t n, cap, base; int grow; };

static int out_room(struct lz_out *o, uintptr_t k) {
 if (o->n + k <= o->cap) return 1;
 if (!o->grow) return 0;
 uintptr_t c = o->cap < 65536 ? 65536 : o->cap;
 while (c < o->n + k) c *= 2;
 uint8_t *nb = ai_alloc(NULL, c);
 if (!nb) return 0;
 if (o->n) memcpy(nb, o->b, o->n);
 if (o->b) ai_alloc(o->b, 0);
 o->b = nb; o->cap = c; return 1; }

// decode until `lim` bytes stand in the output or, with eopm, the end marker says so.
// -> 1 done, 2 the marker seen, 0 corrupt. a match may not run past lim.
static int lz_run(struct lz_model *m, struct lz_rd *r, struct lz_out *o, uintptr_t lim, int eopm) {
 unsigned pbm = (1u << m->pb) - 1, lpm = (1u << m->lp) - 1;
 while (o->n < lim || eopm) {
  uintptr_t pos = o->n;
  unsigned ps = pos & pbm, st = m->state;
  if (r->bad) return 0;
  if (!rd_bit(r, &m->ismatch[st][ps])) {
   unsigned prev = pos > o->base ? o->b[pos - 1] : 0;
   lzp *p = m->lit + 0x300 * (((pos & lpm) << m->lc) + (prev >> (8 - m->lc)));
   unsigned s = 1;
   if (st >= 7) {
    if (pos - o->base <= m->reps[0]) return 0;
    unsigned mb = o->b[pos - m->reps[0] - 1];
    while (s < 0x100) {
     unsigned mbit = (mb >> 7) & 1, b;
     mb <<= 1;
     b = rd_bit(r, p + 0x100 + (mbit << 8) + s);
     s = s << 1 | b;
     if (b != mbit) break; } }
   while (s < 0x100) s = s << 1 | rd_bit(r, p + s);
   if (!out_room(o, 1)) return 0;
   o->b[o->n++] = (uint8_t) s;
   m->state = lz_litst(st);
   continue; }
  unsigned len;
  if (!rd_bit(r, &m->isrep[st])) {
   len = rd_len(r, &m->len, ps);
   m->state = st < 7 ? 7 : 10;
   unsigned ls = len < 3 ? len : 3, slot = rd_tree(r, m->slot[ls], 6);
   uint32_t d = slot;
   if (slot >= 4) {
    unsigned fb = (slot >> 1) - 1;
    d = (2 | (slot & 1)) << fb;
    if (slot < 14) d += rd_rtree(r, m->spec + d - slot - 1, fb);
    else d += rd_direct(r, fb - 4) << 4, d += rd_rtree(r, m->align, 4); }
   if (d == 0xffffffffu) return eopm && !r->bad ? 2 : 0;
   m->reps[3] = m->reps[2]; m->reps[2] = m->reps[1]; m->reps[1] = m->reps[0]; m->reps[0] = d; }
  else {
   if (!rd_bit(r, &m->isg0[st])) {
    if (!rd_bit(r, &m->isrep0l[st][ps])) {        // the short rep: one byte from rep0
     if (pos - o->base <= m->reps[0] || !out_room(o, 1)) return 0;
     o->b[o->n] = o->b[pos - m->reps[0] - 1]; o->n++;
     m->state = st < 7 ? 9 : 11;
     continue; } }
   else {
    uint32_t d;
    if (!rd_bit(r, &m->isg1[st])) d = m->reps[1];
    else {
     if (!rd_bit(r, &m->isg2[st])) d = m->reps[2];
     else d = m->reps[3], m->reps[3] = m->reps[2];
     m->reps[2] = m->reps[1]; }
    m->reps[1] = m->reps[0]; m->reps[0] = d; }
   len = rd_len(r, &m->rep, ps);
   m->state = st < 7 ? 8 : 11; }
  len += LZ_MINLEN;
  uint32_t d = m->reps[0];
  if (pos - o->base <= d || r->bad) return 0;
  if (!eopm && lim - pos < len) return 0;
  if (!out_room(o, len)) return 0;
  uint8_t *dp = o->b + pos, *sp = dp - d - 1;
  for (unsigned k = 0; k < len; k++) dp[k] = sp[k];
  o->n += len; }
 return 1; }

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
static int l2_dec(const uint8_t *s, uint8_t *out, uintptr_t cap, struct lz_model *m) {
 struct lz_out o = { out, 0, cap, 0, 0 };
 struct lz_rd r;
 uintptr_t i = 0;
 int needdict = 1, needprops = 1;
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

// --- the match finder: a hash chain over the whole input, the window its dict --------------
#define XE_HBITS 16
#define XE_DEPTH 48
#define XE_NICE 96

struct xe_mf { const uint8_t *s; uintptr_t n; uint32_t *head, *prev, wmask, dict; uintptr_t ins;
               uintptr_t cpos; unsigned clen, clen1; uint32_t cdist, cdist1; };

static uint32_t xe_hash(const uint8_t *s) {
 return ((uint32_t) s[0] << 16 ^ (uint32_t) s[1] << 8 ^ s[2]) * 2654435761u >> (32 - XE_HBITS); }

static void xe_ins(struct xe_mf *f, uintptr_t upto) {    // index every position below upto
 for (; f->ins < upto && f->ins + 3 <= f->n; f->ins++) {
  uint32_t h = xe_hash(f->s + f->ins);
  f->prev[f->ins & f->wmask] = f->head[h];
  f->head[h] = (uint32_t) f->ins + 1; }
 if (f->ins < upto) f->ins = upto; }

static unsigned xe_mlen(const uint8_t *a, const uint8_t *b, unsigned lim) {
 unsigned k = 0;
 while (k < lim && a[k] == b[k]) k++;
 return k; }

// the longest match at p within avail -> len (0 for none under 3), its distance, and the
// best before it (nearer, shorter), so the parse can trade a byte for a much shorter reach.
static unsigned xe_find(struct xe_mf *f, uintptr_t p, unsigned avail, uint32_t *dist,
                        unsigned *len1, uint32_t *dist1) {
 if (f->cpos == p + 1) { *dist = f->cdist; *len1 = f->clen1; *dist1 = f->cdist1; return f->clen; }
 unsigned best = 0, b1 = 0;
 uint32_t bd = 0, bd1 = 0;
 if (avail >= 3 && p + 3 <= f->n) {
  xe_ins(f, p);
  uint32_t c = f->head[xe_hash(f->s + p)];
  unsigned depth = XE_DEPTH;
  while (c && depth--) {
   uintptr_t q = c - 1;
   if (p - q > f->dict || p - q > f->wmask) break;
   if (f->s[q + best] == f->s[p + best] || best < 3) {
    unsigned l = xe_mlen(f->s + q, f->s + p, avail);
    if (l > best) {
     b1 = best, bd1 = bd;
     best = l; bd = (uint32_t) (p - q - 1);
     if (l >= XE_NICE || l == avail) break; } }
   uint32_t nx = f->prev[q & f->wmask];
   if (nx >= c) break;
   c = nx; }
  xe_ins(f, p + 1); }
 if (best < 3) best = 0;
 f->cpos = p + 1; f->clen = best; f->cdist = bd; f->clen1 = b1; f->cdist1 = bd1;
 *dist = bd; *len1 = b1; *dist1 = bd1;
 return best; }

#define XE_CHANGE(small, big) (((big) >> 7) > (small))

// -> 0 a literal, else the length; *kind 0..3 a rep, 4 a match (*d its distance)
static unsigned xe_parse(struct lz_model *m, struct xe_mf *f, uintptr_t p, unsigned avail,
                         unsigned *kind, uint32_t *d) {
 const uint8_t *s = f->s;
 unsigned rl = 0, ri = 0;
 if (avail < 2) return 0;
 for (unsigned i = 0; i < 4; i++) {
  if (p <= m->reps[i]) continue;
  const uint8_t *q = s + p - m->reps[i] - 1;
  if (q[0] != s[p] || q[1] != s[p + 1]) continue;
  unsigned l = xe_mlen(q, s + p, avail);
  if (l > rl) rl = l, ri = i; }
 if (rl >= XE_NICE) { *kind = ri; xe_ins(f, p + 1); return rl; }
 unsigned l1; uint32_t d1;
 uint32_t md;
 unsigned ml = xe_find(f, p, avail, &md, &l1, &d1);
 if (ml >= XE_NICE) { *kind = 4; *d = md; return ml; }
 if (ml && l1 + 1 == ml && l1 >= 3 && XE_CHANGE(d1, md)) ml = l1, md = d1;
 if (ml == 3 && md >= 0x8000) ml = 0;              // a far triple costs more than its bytes
 if (rl >= 2 && (rl + 1 >= ml || (rl + 2 >= ml && md >= 0x200) || (rl + 3 >= ml && md >= 0x8000))) {
  *kind = ri; return rl; }
 if (!ml) return 0;
 if (avail > ml + 1 && ml < 64) {                 // the lazy look, one byte on
  unsigned nl1; uint32_t nd, nd1;
  unsigned nl = xe_find(f, p + 1, avail - 1, &nd, &nl1, &nd1);
  if (nl && ((nl >= ml && nd < md) || (nl == ml + 1 && !XE_CHANGE(md, nd))
             || nl > ml + 1 || (nl + 1 >= ml && ml >= 3 && XE_CHANGE(nd, md))))
   return 0;
  unsigned lim = ml > 3 ? ml - 1 : 2;
  for (unsigned i = 0; i < 4; i++)
   if (p + 1 > m->reps[i] && xe_mlen(s + p + 1, s + p - m->reps[i], lim) == lim) return 0; }
 *kind = 4; *d = md; return ml; }

// the whole stream into out (cap bytes, sized by the caller for the worst case) -> its
// length, or -1. a chunk is coded speculatively into cs; one that does not shrink goes raw.
#define XE_CU (2u << 20)
#define XE_CC 65536u
#define XE_CSLACK 256u

struct xe_arena { struct lz_model m; lzp lit[0x300 << 3]; uint8_t cs[XE_CC + XE_CSLACK]; uint32_t head[1u << XE_HBITS]; };

static int64_t xe_go(const uint8_t *s, uintptr_t n, uint32_t dict, uint8_t *out, uintptr_t cap,
                     struct xe_arena *a, uint32_t *prev, uint32_t wmask) {
 struct lz_model *m = &a->m;
 struct xe_mf f = { s, n, a->head, prev, wmask, dict, 0, 0, 0, 0, 0, 0 };
 uintptr_t p = 0, o = 0;
 int first = 1, needprops = 1, needstate = 1;
 memset(a->head, 0, sizeof a->head);
 m->lit = a->lit; m->lc = 3; m->lp = 0; m->pb = 2;
 while (p < n) {
  uintptr_t start = p, uend = n - p > XE_CU ? p + XE_CU : n;
  unsigned rst = first ? 3 : needprops ? 2 : needstate ? 1 : 0;
  struct lz_rc e;
  if (rst) lz_reset(m);
  rc_init(&e, a->cs, sizeof a->cs);
  while (p < uend && rc_size(&e) < XE_CC - XE_CSLACK) {
   unsigned avail = uend - p > LZ_MAXLEN ? LZ_MAXLEN : (unsigned) (uend - p), kind = 0;
   uint32_t d = 0;
   unsigned l = xe_parse(m, &f, p, avail, &kind, &d);
   if (!l) { xe_lit(m, &e, s, p); p++; continue; }
   if (kind == 4) xe_match(m, &e, p, d, l); else xe_rep(m, &e, p, kind, l);
   p += l;
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
static uint64_t xz_crc64(const uint8_t *p, uintptr_t n) {
 uint64_t t[256], c = ~(uint64_t) 0;
 for (unsigned i = 0; i < 256; i++) {
  uint64_t v = i;
  for (int k = 0; k < 8; k++) v = v & 1 ? v >> 1 ^ 0xc96c5795d7870f42ull : v >> 1;
  t[i] = v; }
 while (n--) c = t[(c ^ *p++) & 255] ^ c >> 8;
 return ~c; }

// the lzma model with room for lc + lp up to lim, from ai_alloc -> or NULL
static struct lz_model *lz_new(unsigned lclp) {
 struct lz_model *m = ai_alloc(NULL, sizeof *m + ((uintptr_t) 0x300 << lclp) * sizeof(lzp));
 if (m) m->lit = (lzp*) (m + 1);
 return m; }

#ifndef XZ_STANDALONE
// ===== the nifs: str0 may collect, so a string is re-read off the stack after it =====
ai_noinline static struct ai *host_lzma2len(struct ai *g) {
 word sw = g->sp[0];
 uintptr_t end;
 g->sp[0] = strp(sw) && l2_walk((const uint8_t*) txt(sw), len(sw), &end) >= 0
            ? putcharm((intptr_t) end) : ZeroPoint;
 return g; }

ai_noinline static struct ai *host_lzma2d(struct ai *g) {
 word sw = g->sp[0];
 uintptr_t end;
 int64_t want = strp(sw) ? l2_walk((const uint8_t*) txt(sw), len(sw), &end) : -1;
 if (want < 0) { g->sp[0] = ZeroPoint; return g; }
 if (!ai_ok(g = str0(g, (uintptr_t) want))) return g;   // pushes: out over s
 struct lz_model *m = lz_new(4);
 int ok = m && !l2_dec((const uint8_t*) txt(g->sp[1]), (uint8_t*) txt(g->sp[0]), (uintptr_t) want, m);
 if (m) ai_alloc(m, 0);
 g->sp[1] = ok ? g->sp[0] : ZeroPoint;
 return g->sp++, g; }

ai_noinline static struct ai *host_lzma2e(struct ai *g) {
 word sw = g->sp[0], dw = g->sp[1];
 if (!strp(sw) || !oddp(dw) || getcharm(dw) < 4096 || getcharm(dw) > (1l << 30)) {
  g->sp[1] = ZeroPoint, g->sp += 1; return g; }
 uintptr_t n = len(sw), cap = xe_cap(n), w = 1;
 uint32_t dict = (uint32_t) getcharm(dw);
 while (w < dict && w < n) w <<= 1;
 struct xe_arena *a = ai_alloc(NULL, sizeof *a);
 uint32_t *prev = ai_alloc(NULL, w * sizeof *prev);
 uint8_t *out = ai_alloc(NULL, cap);
 int64_t got = a && prev && out
               ? xe_go((const uint8_t*) txt(sw), n, dict, out, cap, a, prev, (uint32_t) (w - 1)) : -1;
 if (a) ai_alloc(a, 0);
 if (prev) ai_alloc(prev, 0);
 if (got >= 0 && ai_ok(g = str0(g, (uintptr_t) got))) {  // pushes: out over the two
  memcpy(txt(g->sp[0]), out, (size_t) got);
  g->sp[2] = g->sp[0], g->sp += 2; }
 else if (ai_ok(g)) g->sp[1] = ZeroPoint, g->sp += 1;
 if (out) ai_alloc(out, 0);
 return g; }

ai_noinline static struct ai *host_lzmad(struct ai *g) {
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
 if (want >= 0) {                                   // the size is known: straight into the string
  if (!ai_ok(g = str0(g, (uintptr_t) want))) { ai_alloc(m, 0); return g; }
  struct lz_out o = { (uint8_t*) txt(g->sp[0]), 0, (uintptr_t) want, 0, 0 };
  const uint8_t *s = (const uint8_t*) txt(g->sp[1]);
  rc = rd_init(&r, s, s + len(g->sp[1])) && lz_run(m, &r, &o, (uintptr_t) want, 0) && !r.bad;
  ai_alloc(m, 0);
  g->sp[4] = rc ? g->sp[0] : ZeroPoint, g->sp += 4;
  return g; }
 struct lz_out o = { NULL, 0, 0, 0, 1 };
 const uint8_t *s = (const uint8_t*) txt(sw);
 rc = rd_init(&r, s, s + len(sw)) && lz_run(m, &r, &o, 0, 1) == 2;
 ai_alloc(m, 0);
 if (rc && ai_ok(g = str0(g, o.n))) {
  if (o.n) memcpy(txt(g->sp[0]), o.b, o.n);
  g->sp[4] = g->sp[0], g->sp += 4; }
 else if (ai_ok(g)) g->sp[3] = ZeroPoint, g->sp += 3;
 if (o.b) ai_alloc(o.b, 0);
 return g; }

ai_noinline static struct ai *host_crc64(struct ai *g) {
 if (!strp(g->sp[0])) { g->sp[0] = ZeroPoint; return g; }
 if (!ai_ok(g = str0(g, 8))) return g;
 uint64_t c = xz_crc64((const uint8_t*) txt(g->sp[1]), len(g->sp[1]));
 for (int i = 0; i < 8; i++) ((uint8_t*) txt(g->sp[0]))[i] = (uint8_t) (c >> 8 * i);
 g->sp[1] = g->sp[0];
 return g->sp++, g; }

static LvmWrap(lvm_lzma2len, host_lzma2len)
static LvmWrap(lvm_lzma2d, host_lzma2d)
static LvmWrap(lvm_lzma2e, host_lzma2e)
static LvmWrap(lvm_lzmad, host_lzmad)
static LvmWrap(lvm_crc64, host_crc64)

static union u const
 nif_lzma2len[] = {{lvm_lzma2len}, {lvm_ret0}},
 nif_lzma2d[]   = {{lvm_lzma2d}, {lvm_ret0}},
 nif_lzma2e[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_lzma2e}, {lvm_ret0}},
 nif_lzmad[]    = {{lvm_cur}, {.x = putcharm(4)}, {lvm_lzmad}, {lvm_ret0}},
 nif_crc64[]    = {{lvm_crc64}, {lvm_ret0}};
LvNif("lzma2len", nif_lzma2len, NULL);
LvNif("lzma2d", nif_lzma2d, NULL);
LvNif("lzma2e", nif_lzma2e, NULL);
LvNif("lzmad", nif_lzmad, NULL);
LvNif("crc64", nif_crc64, NULL);
#endif
