// src/love/compress/zstd.c -- zstandard (rfc 8878), both directions. reading is a block at a time
// into a window, xxh64 over all it says, the frame src/apps/zstd.l's; writing is a whole frame.
//   (zstd-new w)        a state with a window of w bytes and room for blocks after it | ()
//   (zstd-block st b)   one block, its 3-byte header first -> the bytes it says | ()
//   (zstd-sum st)       the low 32 bits of xxh64 over every byte said, as 4 little-endian bytes
//   (zstde s level)     bytes -> one whole frame, level 1..19, its size and checksum in it | ()
//   (zstd-d s)          s one frame that says its size -> its bytes, at once | () for the walk
// the window is the output: a match reaches back into what earlier blocks said.
#ifndef ZS_STANDALONE
#include "love.h"
#include "bytes.h"
#else
#define love_inline inline __attribute__((always_inline))
#endif
#include "prefix.h"
#include <stddef.h>
#include <stdint.h>
#include <string.h>

// eight bytes as a little-endian word, and back: one load where the machine takes an unaligned
// one (bytes.h), else the gather
#if defined(wideld) && wideld
#define ZLD(p) ld64(p)
#define ZST(p, x) st64(p, x)
#else
static uint64_t ZLD(uint8_t const *p) { uint64_t w = 0; for (int i = 7; i >= 0; i--) w = w << 8 | p[i]; return w; }
static void ZST(uint8_t *p, uint64_t x) { for (int i = 0; i < 8; i++) p[i] = (uint8_t) (x >> 8 * i); }
#endif

#define ZS_BMAX ((uintptr_t) 128 << 10)          // the most a block holds or says
#define ZS_WMAX ((uintptr_t) 1 << 27)            // zstd's own default limit: past it, refused
#define ZS_MAGIC 0x7a737464u
#define ZS_SLACK 32                              // past the window and the literals: a copy runs over

struct xx_st { uint64_t v[4], total; uint8_t mem[32]; unsigned memn; };
struct zs_fse { uint16_t base; uint8_t sym, nb; };
struct zs_huf { uint8_t sym, nb; };
struct zs_st {
 uint32_t magic, have;                           // have: the tree 1 and tables 2 4 8, for repeat
 uintptr_t cap, win, n;                          // the window's bytes, the frame's window, held
 uint64_t rep[3];
 unsigned hlog, lllog, oflog, mllog;
 struct zs_fse ll[512], of[256], ml[512];
 struct zs_huf huf[1 << 11];
 struct xx_st x;                                // xxh64 on the way
 uint8_t lit[ZS_BMAX + ZS_SLACK]; };

static unsigned zs_hb(uint32_t x) { unsigned r = 0; while (x >>= 1) r++; return r; }

// --- xxh64, seed 0 -------------------------------------------------------------------------
#define XP1 0x9e3779b185ebca87ull
#define XP2 0xc2b2ae3d27d4eb4full
#define XP3 0x165667b19e3779f9ull
#define XP4 0x85ebca77c2b2ae63ull
#define XP5 0x27d4eb2f165667c5ull
static uint64_t xx_rotl(uint64_t x, unsigned r) { return x << r | x >> (64 - r); }
static uint64_t xx_round(uint64_t a, uint64_t in) { return xx_rotl(a + in * XP2, 31) * XP1; }
static uint64_t xx_merge(uint64_t h, uint64_t v) { return (h ^ xx_round(0, v)) * XP1 + XP4; }
static uint64_t xx_rd(const uint8_t *p, unsigned k) { if (k == 8) return ZLD(p); uint64_t w = 0; while (k--) w = w << 8 | p[k]; return w; }
static void xx_init(struct xx_st *S) { S->v[0] = XP1 + XP2, S->v[1] = XP2, S->v[2] = 0, S->v[3] = 0 - XP1, S->total = 0, S->memn = 0; }
static void xx_feed(struct xx_st *S, const uint8_t *p, uintptr_t n) {
 S->total += n;
 if (S->memn + n < 32) { memcpy(S->mem + S->memn, p, n), S->memn += (unsigned) n; return; }
 uint64_t a = S->v[0], b = S->v[1], c = S->v[2], d = S->v[3];
 if (S->memn) {
  unsigned k = 32 - S->memn;
  memcpy(S->mem + S->memn, p, k), p += k, n -= k;
  a = xx_round(a, xx_rd(S->mem, 8)), b = xx_round(b, xx_rd(S->mem + 8, 8));
  c = xx_round(c, xx_rd(S->mem + 16, 8)), d = xx_round(d, xx_rd(S->mem + 24, 8)); }
 for (; n >= 32; p += 32, n -= 32)
  a = xx_round(a, xx_rd(p, 8)), b = xx_round(b, xx_rd(p + 8, 8)),
  c = xx_round(c, xx_rd(p + 16, 8)), d = xx_round(d, xx_rd(p + 24, 8));
 S->v[0] = a, S->v[1] = b, S->v[2] = c, S->v[3] = d;
 memcpy(S->mem, p, n), S->memn = (unsigned) n; }
static uint64_t xx_done(const struct xx_st *S) {
 const uint64_t *v = S->v;
 uint64_t h = S->total < 32 ? XP5
  : xx_merge(xx_merge(xx_merge(xx_merge(xx_rotl(v[0], 1) + xx_rotl(v[1], 7) + xx_rotl(v[2], 12)
             + xx_rotl(v[3], 18), v[0]), v[1]), v[2]), v[3]);
 const uint8_t *p = S->mem;
 unsigned n = S->memn;
 for (h += S->total; n >= 8; p += 8, n -= 8) h = xx_rotl(h ^ xx_round(0, xx_rd(p, 8)), 27) * XP1 + XP4;
 if (n >= 4) h = xx_rotl(h ^ xx_rd(p, 4) * XP1, 23) * XP2 + XP3, p += 4, n -= 4;
 while (n--) h = xx_rotl(h ^ *p++ * XP5, 11) * XP1;
 h ^= h >> 33, h *= XP2, h ^= h >> 29, h *= XP3;
 return h ^ h >> 32; }

// --- bits: little-endian numbering, bit i of byte i/8; off either end they read 0 ------------
static uint64_t zs_bits(const uint8_t *p, intptr_t n, intptr_t pos, unsigned k) {   // k <= 32
 if (!k) return 0;
 if (pos < 0) return pos + (intptr_t) k <= 0 ? 0 : zs_bits(p, n, 0, (unsigned) (pos + (intptr_t) k)) << -pos;
 intptr_t b = pos >> 3, e = b + 8 < n ? b + 8 : n;
 uint64_t w = 0;
 if (b + 8 <= n) w = ZLD(p + b);
 else while (e > b) w = w << 8 | p[--e];
 return w >> (pos & 7) & (((uint64_t) 1 << k) - 1); }
// a backward stream: read from its last bit down, past the 1 that pads its last byte. c holds the
// eight bytes at p, u the bits of it used from the top; a reload steps p back by the whole bytes
// used. past the stream's start the bits read 0, and left goes negative
struct zs_br { const uint8_t *s, *p; uint64_t c; unsigned u; };
static int zs_brinit(struct zs_br *r, const uint8_t *p, intptr_t n) {
 if (n < 1 || !p[n - 1]) return 0;
 unsigned h = zs_hb(p[n - 1]);
 r->s = p;
 if (n >= 8) r->p = p + n - 8, r->c = ZLD(r->p), r->u = 8 - h;
 else {
  uint64_t c = 0;
  for (intptr_t i = n; i--; ) c = c << 8 | p[i];
  r->p = p, r->c = c, r->u = 8 - h + (unsigned) (64 - 8 * n); }   // the bytes low, the empty top as used
 return 1; }
static intptr_t zs_left(struct zs_br const *r) { return (r->p - r->s) * 8 + 64 - (intptr_t) r->u; }
static love_inline void zs_reload(struct zs_br *r) {
 if (r->u > 64) return;
 if (r->p - r->s >= 8) r->p -= r->u >> 3, r->u &= 7;
 else if (r->p > r->s) {
  unsigned k = r->u >> 3;
  if (k > (unsigned) (r->p - r->s)) k = (unsigned) (r->p - r->s);
  r->p -= k, r->u -= 8 * k; }
 else return;
 r->c = ZLD(r->p); }
static love_inline uint64_t zs_peek(struct zs_br const *r, unsigned k) { return r->u >= 64 ? 0 : (r->c << r->u) >> (64 - k); }   // 1 <= k
static love_inline uint64_t zs_read(struct zs_br *r, unsigned k) { uint64_t v = k ? zs_peek(r, k) : 0; r->u += k; return v; }   // k <= 56 past a reload

// --- fse: a table's counts as written, then the decoding table they spread to ----------------
static intptr_t zs_ncount(const uint8_t *p, uintptr_t n, int16_t *norm, unsigned maxs, unsigned maxlog,
                          unsigned *alog, unsigned *nsym) {
 intptr_t lim = (intptr_t) n * 8, pos = 4;
 unsigned al = (unsigned) zs_bits(p, (intptr_t) n, 0, 4) + 5, s = 0, prev0 = 0, nb = al + 1;
 if (al > maxlog) return -1;
 int32_t rem = (1 << al) + 1, thr = 1 << al;
 while (rem > 1) {
  if (prev0) {                                   // a zero count is followed by its repeats
   for (unsigned r = 3; r == 3; ) {
    r = (unsigned) zs_bits(p, (intptr_t) n, pos, 2), pos += 2;
    for (unsigned j = 0; j < r; j++) { if (s > maxs) return -1; norm[s++] = 0; }
    if (pos > lim) return -1; } }
  int32_t max = 2 * thr - 1 - rem, v = (int32_t) zs_bits(p, (intptr_t) n, pos, nb - 1);
  if (v < max) pos += nb - 1;
  else { v = (int32_t) zs_bits(p, (intptr_t) n, pos, nb), pos += nb; if (v >= thr) v -= max; }
  if (s > maxs) return -1;
  rem -= v ? v - 1 : 1;                          // -1, less than one, takes a cell all the same
  norm[s++] = (int16_t) (v - 1), prev0 = v == 1;
  if (rem < 1 || pos > lim) return -1;
  while (rem < thr) nb--, thr >>= 1; }
 *alog = al, *nsym = s;
 return (pos + 7) / 8; }

static int zs_fsebuild(struct zs_fse *t, const int16_t *norm, unsigned ns, unsigned al) {
 uint32_t size = 1u << al, high = size - 1, sum = 0, step = (size >> 1) + (size >> 3) + 3, pos = 0;
 uint16_t next[256];
 for (unsigned s = 0; s < ns; s++)
  if (norm[s] < 0) t[high--].sym = (uint8_t) s, next[s] = 1, sum++;
  else next[s] = (uint16_t) norm[s], sum += (uint32_t) norm[s];
 if (sum != size) return 0;
 for (unsigned s = 0; s < ns; s++)
  for (int i = 0; i < norm[s]; i++) {
   t[pos].sym = (uint8_t) s;
   do pos = (pos + step) & (size - 1); while (pos > high); }
 if (pos) return 0;
 for (uint32_t u = 0; u < size; u++) {
  uint32_t x = next[t[u].sym]++;
  unsigned nb = al - zs_hb(x);
  t[u].nb = (uint8_t) nb, t[u].base = (uint16_t) ((x << nb) - size); }
 return 1; }

// --- literals: raw, one byte run, or huffman with its tree here or the last block's ----------
static intptr_t zs_tree(struct zs_st *S, const uint8_t *p, uintptr_t n) {
 uint8_t wt[256];
 unsigned nw = 0;
 uintptr_t hb = n ? p[0] : 0, used;
 if (!n) return -1;
 if (hb >= 128) {                                // the weights as they are, four bits each
  nw = (unsigned) hb - 127, used = 1 + (nw + 1) / 2;
  if (n < used) return -1;
  for (unsigned i = 0; i < nw; i++) wt[i] = i & 1 ? p[1 + i / 2] & 15 : p[1 + i / 2] >> 4; }
 else {                                          // fse over two states taking turns
  used = 1 + hb;
  if (!hb || n < used) return -1;
  int16_t norm[256];
  unsigned al, ns;
  struct zs_fse t[64];
  struct zs_br r;
  intptr_t k = zs_ncount(p + 1, hb, norm, 255, 6, &al, &ns);
  if (k < 0 || !zs_fsebuild(t, norm, ns, al) || !zs_brinit(&r, p + 1 + k, (intptr_t) hb - k)) return -1;
  unsigned s1 = (unsigned) zs_read(&r, al), s2 = (unsigned) zs_read(&r, al);
  for (;;) {
   if (nw > 253) return -1;
   zs_reload(&r);
   wt[nw++] = t[s1].sym, s1 = t[s1].base + (unsigned) zs_read(&r, t[s1].nb);
   if (zs_left(&r) < 0) { wt[nw++] = t[s2].sym; break; }
   zs_reload(&r);
   wt[nw++] = t[s2].sym, s2 = t[s2].base + (unsigned) zs_read(&r, t[s2].nb);
   if (zs_left(&r) < 0) { wt[nw++] = t[s1].sym; break; } } }
 uint32_t sum = 0, cnt[13] = {0}, at[13];
 for (unsigned i = 0; i < nw; i++) {
  if (wt[i] > 11) return -1;
  if (wt[i]) sum += 1u << (wt[i] - 1); }
 if (!sum) return -1;
 unsigned mb = zs_hb(sum) + 1;                   // the last weight is what fills the power of two
 uint32_t rest = (1u << mb) - sum;
 if (mb > 11 || rest & (rest - 1)) return -1;
 wt[nw++] = (uint8_t) (zs_hb(rest) + 1);
 for (unsigned i = 0; i < nw; i++) cnt[wt[i]]++;
 for (uint32_t w = 1, cur = 0; w <= mb; w++) at[w] = cur, cur += cnt[w] << (w - 1);
 for (unsigned s = 0; s < nw; s++)
  if (wt[s])
   for (uint32_t j = 0, w = wt[s]; j < 1u << (w - 1); j++)
    S->huf[at[w]++] = (struct zs_huf) { (uint8_t) s, (uint8_t) (mb + 1 - w) };
 S->hlog = mb;
 return (intptr_t) used; }

static int zs_hstream(const struct zs_huf *t, unsigned lg, const uint8_t *p, uintptr_t n, uint8_t *o, uintptr_t k) {
 struct zs_br r;
 if (!zs_brinit(&r, p, (intptr_t) n)) return 0;
 uintptr_t i = 0;
 for (; i + 4 <= k; i += 4) {                    // four codes of at most 11 bits to a reload
  zs_reload(&r);
  for (int j = 0; j < 4; j++) { struct zs_huf e = t[zs_peek(&r, lg)]; o[i + j] = e.sym, r.u += e.nb; } }
 for (; i < k; i++) { zs_reload(&r); struct zs_huf e = t[zs_peek(&r, lg)]; o[i] = e.sym, r.u += e.nb; }
 return zs_left(&r) == 0; }

static int zs_huf(struct zs_st *S, const uint8_t *p, uintptr_t n, unsigned ns, uintptr_t rg) {
 if (ns == 1) return zs_hstream(S->huf, S->hlog, p, n, S->lit, rg);
 if (n < 10) return 0;
 uintptr_t a = p[0] | (uintptr_t) p[1] << 8, b = p[2] | (uintptr_t) p[3] << 8,
           c = p[4] | (uintptr_t) p[5] << 8, seg = (rg + 3) / 4;
 if (6 + a + b + c >= n || 3 * seg > rg) return 0;
 p += 6;
 return zs_hstream(S->huf, S->hlog, p, a, S->lit, seg)
     && zs_hstream(S->huf, S->hlog, p + a, b, S->lit + seg, seg)
     && zs_hstream(S->huf, S->hlog, p + a + b, c, S->lit + 2 * seg, seg)
     && zs_hstream(S->huf, S->hlog, p + a + b + c, n - 6 - a - b - c, S->lit + 3 * seg, rg - 3 * seg); }

// -> the section's length, the literals at *lit
static intptr_t zs_lits(struct zs_st *S, const uint8_t *b, uintptr_t n, const uint8_t **lit, uintptr_t *nl) {
 if (!n) return -1;
 unsigned t = b[0] & 3, f = b[0] >> 2 & 3;
 if (t < 2) {
  uintptr_t hs = f == 1 ? 2 : f == 3 ? 3 : 1;
  if (n < hs) return -1;
  uintptr_t sz = f == 1 ? (uintptr_t) (b[0] >> 4) + ((uintptr_t) b[1] << 4)
               : f == 3 ? (uintptr_t) (b[0] >> 4) + ((uintptr_t) b[1] << 4) + ((uintptr_t) b[2] << 12)
               : (uintptr_t) b[0] >> 3;
  if (sz > ZS_BMAX) return -1;
  *nl = sz;
  if (!t) { if (n - hs < sz) return -1; *lit = b + hs; return (intptr_t) (hs + sz); }
  if (n - hs < 1) return -1;
  memset(S->lit, b[hs], sz), *lit = S->lit;
  return (intptr_t) (hs + 1); }
 unsigned hs = f < 2 ? 3 : f + 2, bits = f < 2 ? 10 : f == 2 ? 14 : 18;
 if (n < hs) return -1;
 uint64_t h = 0;
 for (unsigned i = hs; i--; ) h = h << 8 | b[i];
 uintptr_t rg = (uintptr_t) (h >> 4) & ((1u << bits) - 1), cz = (uintptr_t) (h >> (4 + bits)) & ((1u << bits) - 1);
 if (rg > ZS_BMAX || n - hs < cz) return -1;
 const uint8_t *p = b + hs;
 uintptr_t m = cz;
 if (t == 2) {
  intptr_t k = zs_tree(S, p, m);
  if (k < 0) return -1;
  p += k, m -= (uintptr_t) k, S->have |= 1; }
 else if (!(S->have & 1)) return -1;
 if (!zs_huf(S, p, m, f ? 4 : 1, rg)) return -1;
 *lit = S->lit, *nl = rg;
 return (intptr_t) (hs + cz); }

// --- sequences --------------------------------------------------------------------------------
static const uint32_t zs_llbase[36] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18,
 20, 22, 24, 28, 32, 40, 48, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536 };
static const uint8_t zs_llbits[36] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
 1, 1, 2, 2, 3, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
static const uint32_t zs_mlbase[53] = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 37, 39, 41, 43, 47, 51, 59, 67, 83,
 99, 131, 259, 515, 1027, 2051, 4099, 8195, 16387, 32771, 65539 };
static const uint8_t zs_mlbits[53] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4,
 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
static const int16_t zs_lldef[36] = { 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 2, 2, 2, 2, 2,
 2, 2, 2, 2, 3, 2, 1, 1, 1, 1, 1, -1, -1, -1, -1 };
static const int16_t zs_mldef[53] = { 1, 4, 3, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1 };
static const int16_t zs_ofdef[29] = { 1, 1, 1, 1, 1, 1, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
 1, 1, 1, -1, -1, -1, -1, -1 };

// a table by its mode: the default, one symbol, laid out here, or the last block's
static int zs_table(struct zs_st *S, unsigned mode, const uint8_t *p, uintptr_t n, uintptr_t *i,
                    struct zs_fse *t, unsigned *lg, const int16_t *def, unsigned dn, unsigned dlog,
                    unsigned maxs, unsigned maxlog, unsigned bit) {
 if (mode == 0) { if (!zs_fsebuild(t, def, dn, dlog)) return 0; *lg = dlog; }
 else if (mode == 1) {
  if (*i >= n || p[*i] > maxs) return 0;
  t[0].sym = p[(*i)++], t[0].nb = 0, t[0].base = 0, *lg = 0; }
 else if (mode == 2) {
  int16_t norm[256];
  unsigned al, ns;
  intptr_t k = zs_ncount(p + *i, n - *i, norm, maxs, maxlog, &al, &ns);
  if (k < 0 || !zs_fsebuild(t, norm, ns, al)) return 0;
  *i += (uintptr_t) k, *lg = al; }
 else if (!(S->have & bit)) return 0;
 S->have |= bit;
 return 1; }

// n bytes from a to o eight at a time, running over by up to seven: the room is the caller's, and
// a reads only behind what o writes when they are eight or more apart
static love_inline void zs_wild(uint8_t *o, uint8_t const *a, uintptr_t n) { for (uintptr_t j = 0; j < n; j += 8) ZST(o + j, ZLD(a + j)); }
// a match of ml at off behind o: under eight apart, the first sixteen a byte at a time, then wide
// from a whole number of periods, eight or more, back
static love_inline void zs_match(uint8_t *o, uintptr_t off, uintptr_t ml) {
 uint8_t const *a = o - off;
 if (off >= 8) { zs_wild(o, a, ml); return; }
 uintptr_t j = 0;
 for (; j < ml && j < 16; j++) o[j] = a[j];
 if (j < ml) { uintptr_t d = off * ((8 + off - 1) / off); zs_wild(o + j, o + j - d, ml - j); } }

static intptr_t zs_seqs(struct zs_st *S, uint8_t *w, const uint8_t *p, uintptr_t n, const uint8_t *lit, uintptr_t nl) {
 uintptr_t i, ns;
 if (n < 1) return -1;
 unsigned b0 = p[0];
 if (b0 < 128) ns = b0, i = 1;
 else if (b0 < 255) { if (n < 2) return -1; ns = ((uintptr_t) (b0 - 128) << 8) + p[1], i = 2; }
 else { if (n < 3) return -1; ns = p[1] + ((uintptr_t) p[2] << 8) + 0x7f00, i = 3; }
 uint8_t *o0 = w + S->n, *o = o0, *oe = o0 + ZS_BMAX;
 const uint8_t *le = lit + nl,                   // ..and how far literals may be read over
               *ls = lit >= S->lit && lit < S->lit + sizeof S->lit ? S->lit + sizeof S->lit : le;
 if (!ns) { if (i != n) return -1; memcpy(o, lit, nl); return (intptr_t) nl; }
 if (i >= n) return -1;
 unsigned m = p[i++];
 if (m & 3 || !zs_table(S, m >> 6, p, n, &i, S->ll, &S->lllog, zs_lldef, 36, 6, 35, 9, 2)
     || !zs_table(S, m >> 4 & 3, p, n, &i, S->of, &S->oflog, zs_ofdef, 29, 5, 31, 8, 4)
     || !zs_table(S, m >> 2 & 3, p, n, &i, S->ml, &S->mllog, zs_mldef, 53, 6, 52, 9, 8)) return -1;
 struct zs_br r;
 if (!zs_brinit(&r, p + i, (intptr_t) (n - i))) return -1;
 unsigned sl = (unsigned) zs_read(&r, S->lllog), so = (unsigned) zs_read(&r, S->oflog),
          sm = (unsigned) zs_read(&r, S->mllog);
 uint64_t r0 = S->rep[0], r1 = S->rep[1], r2 = S->rep[2];
 for (uintptr_t k = 0; k < ns; k++) {
  unsigned oc = S->of[so].sym, mc = S->ml[sm].sym, lc = S->ll[sl].sym;
  zs_reload(&r);                                 // the extra bits: offset; then match and literals
  uint64_t ov = ((uint64_t) 1 << oc) + zs_read(&r, oc), off;
  zs_reload(&r);
  uintptr_t ml = zs_mlbase[mc] + (uintptr_t) zs_read(&r, zs_mlbits[mc]),
            ll = zs_llbase[lc] + (uintptr_t) zs_read(&r, zs_llbits[lc]);
  if (ov > 3) off = ov - 3, r2 = r1, r1 = r0, r0 = off;
  else {                                         // a repeat: with no literals, one further along
   unsigned x = (unsigned) ov - 1 + !ll;
   if (!x) off = r0;
   else {
    off = x == 1 ? r1 : x == 2 ? r2 : r0 - 1;
    if (x > 1) r2 = r1;
    r1 = r0, r0 = off; } }
  if (k + 1 < ns) {                              // the states on: literals, match, offset
   zs_reload(&r);
   sl = S->ll[sl].base + (unsigned) zs_read(&r, S->ll[sl].nb);
   sm = S->ml[sm].base + (unsigned) zs_read(&r, S->ml[sm].nb);
   so = S->of[so].base + (unsigned) zs_read(&r, S->of[so].nb); }
  if (ll > (uintptr_t) (le - lit) || ll + ml > (uintptr_t) (oe - o)) return -1;
  if (lit + ll + 8 <= ls) zs_wild(o, lit, ll); else memcpy(o, lit, ll);
  o += ll, lit += ll;
  if (!off || off > (uint64_t) (o - w)) return -1;
  zs_match(o, (uintptr_t) off, ml), o += ml; }
 if (zs_left(&r) || (uintptr_t) (le - lit) > (uintptr_t) (oe - o)) return -1;
 memcpy(o, lit, (uintptr_t) (le - lit)), o += le - lit;
 S->rep[0] = r0, S->rep[1] = r1, S->rep[2] = r2;
 return o - o0; }

// --- a block ----------------------------------------------------------------------------------
// room past the window, so it slides about once a window said; a big one a quarter at a time
static uintptr_t zs_room(uintptr_t w) { return w > (16u << 20) ? w / 4 : w > ZS_BMAX ? w : ZS_BMAX; }
// the window slides when a block may not fit: the frame's window kept, the rest let go
static void zs_slide(struct zs_st *S, uint8_t *w) {
 if (S->cap - S->n >= ZS_BMAX) return;
 uintptr_t keep = S->win < S->n ? S->win : S->n;
 memmove(w, w + S->n - keep, keep), S->n = keep; }
// -> how many bytes it said, after the window's S->n; -1 malformed
static intptr_t zs_block(struct zs_st *S, uint8_t *w, const uint8_t *b, uintptr_t n) {
 if (n < 3) return -1;
 uintptr_t h = b[0] | (uintptr_t) b[1] << 8 | (uintptr_t) b[2] << 16, type = h >> 1 & 3, sz = h >> 3;
 b += 3, n -= 3;
 if (type == 3 || sz > ZS_BMAX) return -1;
 zs_slide(S, w);
 uint8_t *o = w + S->n;
 if (type == 0) { if (n != sz) return -1; memcpy(o, b, sz); }
 else if (type == 1) { if (n != 1) return -1; memset(o, b[0], sz); }
 else {
  const uint8_t *lit;
  uintptr_t nl;
  intptr_t k = n == sz ? zs_lits(S, b, n, &lit, &nl) : -1, got = k < 0 ? -1 : zs_seqs(S, w, b + k, n - (uintptr_t) k, lit, nl);
  if (got < 0) return -1;
  sz = (uintptr_t) got; }
 xx_feed(&S->x, o, sz), S->n += sz;
 return (intptr_t) sz; }

// a frame whole, when s is one frame that says its size and nothing else, into one buffer: no
// window slides and no block is copied out alone -> the bytes (n + ZS_SLACK from alloc, *on
// set) | NULL for any other shape or a fault, which zstd.l's walk then reads and names
#define ZS_WHOLE ((uintptr_t) 1 << 30)
static const uint8_t zs_dn[4] = { 0, 1, 2, 4 }, zs_fz[4] = { 0, 2, 4, 8 };
static uint8_t *zs_whole(const uint8_t *s, uintptr_t n, uintptr_t *on) {
 if (n < 6 || xx_rd(s, 4) != 0xfd2fb528u) return NULL;
 unsigned d = s[4], ss = d >> 5 & 1, dn = zs_dn[d & 3], fz = d >> 6 ? zs_fz[d >> 6] : ss;
 uintptr_t i = 5 + !ss + dn + fz;
 if (!fz || d & 8 || n < i || (dn && xx_rd(s + 5 + !ss, dn))) return NULL;
 uint64_t fcs = xx_rd(s + 5 + !ss + dn, fz) + (fz == 2 ? 256 : 0);
 if (fcs > ZS_WHOLE) return NULL;
 struct zs_st *S = alloc(NULL, sizeof *S);
 uint8_t *w = S ? alloc(NULL, (uintptr_t) fcs + ZS_BMAX + ZS_SLACK) : NULL;
 int good = w != NULL;
 if (good) {
  memset(S, 0, offsetof(struct zs_st, lit));
  S->cap = (uintptr_t) fcs + ZS_BMAX, S->win = (uintptr_t) fcs, S->rep[0] = 1, S->rep[1] = 4, S->rep[2] = 8;
  xx_init(&S->x); }
 for (int last = 0; good && !last; ) {
  if (n - i < 3) { good = 0; break; }
  uintptr_t bh = (uintptr_t) xx_rd(s + i, 3), k = (bh >> 1 & 3) == 1 ? 1 : bh >> 3;
  if (n - i - 3 < k || zs_block(S, w, s + i, 3 + k) < 0 || S->n > fcs) { good = 0; break; }
  i += 3 + k, last = (int) (bh & 1); }
 if (good && S->n != fcs) good = 0;
 if (good && d & 4) good = n - i >= 4 && xx_rd(s + i, 4) == (xx_done(&S->x) & 0xffffffffu), i += 4;
 if (good && i != n) good = 0;                   // frames after it: the walk's
 if (S) alloc(S, 0);
 if (!good) { if (w) alloc(w, 0); return NULL; }
 *on = (uintptr_t) fcs;
 return w; }

// ===== the coder: a hash-chain parse, huffman literals, fse sequences =====
struct ze_bw { uint8_t *p, *e; uint64_t acc; unsigned nb; int bad; };   // bits out, low first
static void ze_bits(struct ze_bw *w, uint64_t v, unsigned k) {          // k <= 32
 w->acc |= (v & (((uint64_t) 1 << k) - 1)) << w->nb, w->nb += k;
 for (; w->nb >= 8; w->acc >>= 8, w->nb -= 8)
  if (w->p < w->e) *w->p++ = (uint8_t) w->acc; else w->bad = 1; }
static void ze_flush(struct ze_bw *w) { if (w->nb) ze_bits(w, 0, 8 - w->nb); }
static void ze_close(struct ze_bw *w) { ze_bits(w, 1, 1), ze_flush(w); }   // a backward stream's mark

// --- fse, the writing side of zs_fsebuild's spread --------------------------------------------
struct ze_fse { uint16_t st[512]; uint32_t dnb[256]; int32_t dfs[256]; unsigned al; };
static int ze_fsebuild(struct ze_fse *c, const int16_t *norm, unsigned ns, unsigned al) {
 uint32_t size = 1u << al, high = size - 1, step = (size >> 1) + (size >> 3) + 3, pos = 0, cum[257];
 uint8_t sym[512];
 for (unsigned s = 0; s < ns; s++) if (norm[s] < 0) sym[high--] = (uint8_t) s;
 for (unsigned s = 0; s < ns; s++)
  for (int i = 0; i < norm[s]; i++) {
   sym[pos] = (uint8_t) s;
   do pos = (pos + step) & (size - 1); while (pos > high); }
 if (pos) return 0;
 cum[0] = 0;
 for (unsigned s = 0; s < ns; s++) cum[s + 1] = cum[s] + (norm[s] < 0 ? 1 : (uint32_t) norm[s]);
 for (uint32_t u = 0; u < size; u++) c->st[cum[sym[u]]++] = (uint16_t) (size + u);
 int32_t total = 0;
 for (unsigned s = 0; s < ns; s++) {
  int32_t k = norm[s];
  if (!k) c->dnb[s] = ((al + 1) << 16) - size, c->dfs[s] = 0;
  else if (k < 2) c->dnb[s] = (al << 16) - size, c->dfs[s] = total - 1, total++;
  else {
   uint32_t mbo = al - zs_hb((uint32_t) k - 1);
   c->dnb[s] = (mbo << 16) - ((uint32_t) k << mbo), c->dfs[s] = total - k, total += k; } }
 c->al = al;
 return 1; }
static uint32_t ze_finit(const struct ze_fse *c, unsigned s) {
 uint32_t nbo = (c->dnb[s] + (1u << 15)) >> 16, v = (nbo << 16) - c->dnb[s];
 return c->st[(int32_t) (v >> nbo) + c->dfs[s]]; }
static uint32_t ze_fenc(struct ze_bw *w, const struct ze_fse *c, uint32_t st, unsigned s) {
 uint32_t nbo = (st + c->dnb[s]) >> 16;
 ze_bits(w, st, nbo);
 return c->st[(int32_t) (st >> nbo) + c->dfs[s]]; }
// counts -> a distribution summing to 1 << al, every symbol seen at least 1
static void ze_norm(const uint32_t *cnt, unsigned ns, uint32_t total, unsigned al, int16_t *norm) {
 int32_t size = 1 << al, sum = 0;
 unsigned big = 0;
 for (unsigned s = 0; s < ns; s++) {
  int32_t v = cnt[s] ? (int32_t) (((uint64_t) cnt[s] * (uint32_t) size + total / 2) / total) : 0;
  if (cnt[s] && v < 1) v = 1;
  norm[s] = (int16_t) v, sum += v;
  if (cnt[s] > cnt[big]) big = s; }
 while (sum > size) {                            // the largest give back what rounding added
  unsigned m = big;
  for (unsigned s = 0; s < ns; s++) if (norm[s] > norm[m]) m = s;
  int32_t take = sum - size < norm[m] - 1 ? sum - size : norm[m] - 1;
  if (take < 1) break;
  norm[m] = (int16_t) (norm[m] - take), sum -= take; }
 norm[big] = (int16_t) (norm[big] + size - sum); }
// the table's counts as zs_ncount reads them
static void ze_ncount(struct ze_bw *w, const int16_t *norm, unsigned al) {
 int32_t rem = (1 << al) + 1, thr = 1 << al;
 unsigned nb = al + 1, s = 0, prev0 = 0;
 ze_bits(w, al - 5, 4);
 while (rem > 1) {
  if (prev0) {
   unsigned st = s;
   while (!norm[s]) s++;
   for (; s >= st + 3; st += 3) ze_bits(w, 3, 2);
   ze_bits(w, s - st, 2); }
  int32_t c = norm[s++], max = 2 * thr - 1 - rem;
  rem -= c < 0 ? -c : c;
  if (++c >= thr) c += max;
  ze_bits(w, (uint32_t) c, nb - (c < max));
  prev0 = c == 1;
  while (rem < thr) nb--, thr >>= 1; }
 ze_flush(w); }
static unsigned ze_al(uintptr_t n, unsigned maxs, unsigned maxlog) {   // a table's size, as zstd picks it
 unsigned al = maxlog, src = n > 1 ? zs_hb((uint32_t) (n - 1)) : 0, mn = zs_hb(maxs) + 2;
 if (src >= 2 && src - 2 < al) al = src - 2;
 if (mn > al) al = mn;
 return al < 5 ? 5 : al > maxlog ? maxlog : al; }

// --- literals ---------------------------------------------------------------------------------
// a huffman stream, read last symbol first, so written backward
static uintptr_t ze_hstream(const uint8_t *lit, uintptr_t n, const uint16_t *code, const uint8_t *len, uint8_t *o, uintptr_t cap) {
 struct ze_bw w = { o, o + cap, 0, 0, 0 };
 for (uintptr_t i = n; i--; ) ze_bits(&w, code[lit[i]], len[lit[i]]);
 ze_close(&w);
 return w.bad ? 0 : (uintptr_t) (w.p - o); }

// the weights in two fse states taking turns, as zs_tree reads them -> bytes | 0
static uintptr_t ze_hwts(const uint8_t *wt, unsigned nw, uint8_t *o, uintptr_t cap) {
 uint32_t cnt[12] = {0}, mx = 0;
 unsigned ns = 0;
 for (unsigned i = 0; i < nw; i++) cnt[wt[i]]++;
 for (unsigned s = 0; s < 12; s++) if (cnt[s]) ns = s + 1, mx = cnt[s] > mx ? cnt[s] : mx;
 if (nw < 2 || mx == nw || mx == 1) return 0;
 int16_t norm[12];
 struct ze_fse c;
 ze_norm(cnt, ns, nw, 6, norm);
 if (!ze_fsebuild(&c, norm, ns, 6)) return 0;
 struct ze_bw w = { o, o + cap, 0, 0, 0 };
 ze_ncount(&w, norm, 6);
 uintptr_t hd = (uintptr_t) (w.p - o);
 const uint8_t *ip = wt + nw;
 uint32_t s1, s2;
 if (nw & 1) s1 = ze_finit(&c, *--ip), s2 = ze_finit(&c, *--ip), s1 = ze_fenc(&w, &c, s1, *--ip);
 else s2 = ze_finit(&c, *--ip), s1 = ze_finit(&c, *--ip);
 while (ip > wt) s2 = ze_fenc(&w, &c, s2, *--ip), s1 = ze_fenc(&w, &c, s1, *--ip);
 ze_bits(&w, s2, 6), ze_bits(&w, s1, 6);
 ze_close(&w);
 return w.bad || (uintptr_t) (w.p - o) <= hd ? 0 : (uintptr_t) (w.p - o); }

// the literals section -> its bytes; raw, one byte run, or huffman where that is shorter
static uintptr_t ze_lits(const uint8_t *lit, uintptr_t n, uint8_t *o, uintptr_t cap) {
 uint32_t cnt[256] = {0};
 unsigned maxs = 0, k = 0;
 for (uintptr_t i = 0; i < n; i++) cnt[lit[i]]++;
 for (unsigned s = 0; s < 256; s++) if (cnt[s]) maxs = s, k++;
 if (k == 1 && n > 2) {                          // one byte, over and over
  uintptr_t hs = n < 32 ? 1 : n < 4096 ? 2 : 3;
  if (hs == 1) o[0] = (uint8_t) (n << 3 | 1);
  else if (hs == 2) o[0] = (uint8_t) (n << 4 | 4 | 1), o[1] = (uint8_t) (n >> 4);
  else o[0] = (uint8_t) (n << 4 | 12 | 1), o[1] = (uint8_t) (n >> 4), o[2] = (uint8_t) (n >> 12);
  o[hs] = lit[0];
  return hs + 1; }
 uintptr_t hs = n < 32 ? 1 : n < 4096 ? 2 : 3, raw = hs + n;
 if (k >= 2 && n >= 64) {
  uint8_t len[256], wt[256];
  uint16_t code[256];
  uint32_t at[13] = {0}, cw[13] = {0};
  uint32_t hc[256];
  uint64_t keys[256], hw[512];
  uint32_t pa[512];
  memcpy(hc, cnt, (maxs + 1) * sizeof *hc);                // pfx_lens halves its counts in place
  unsigned mb = pfx_lens(hc, maxs + 1, 11, len, keys, hw, pa);
  for (unsigned s = 0; s <= maxs; s++) wt[s] = len[s] ? (uint8_t) (mb + 1 - len[s]) : 0, cw[wt[s]]++;
  for (uint32_t w = 1, cur = 0; w <= mb; w++) at[w] = cur, cur += cw[w] << (w - 1);
  for (unsigned s = 0; s <= maxs; s++)
   if (wt[s]) code[s] = (uint16_t) (at[wt[s]] >> (wt[s] - 1)), at[wt[s]] += 1u << (wt[s] - 1);
  uint8_t *t = o + 5;                            // the tree past the widest header
  uintptr_t tz = 0, room = cap > 5 ? cap - 5 : 0;
  if (room > 130 && (tz = ze_hwts(wt, maxs, t + 1, room - 1)) && tz < 128) t[0] = (uint8_t) tz, tz++;
  else if (maxs <= 128 && room > 66) {
   t[0] = (uint8_t) (127 + maxs), tz = 1 + (maxs + 1) / 2;
   for (unsigned i = 0; i < maxs; i += 2) t[1 + i / 2] = (uint8_t) (wt[i] << 4 | (i + 1 < maxs ? wt[i + 1] : 0)); }
  else tz = 0;
  if (tz) {
   uint8_t *sp = t + tz;
   uintptr_t left = room - tz, cz = 0, four = n > 1023;
   if (!four) {
    cz = ze_hstream(lit, n, code, len, sp, left);
    if (!cz || tz + cz > 1023) four = 1; }
   if (four && left > 6) {
    uintptr_t seg = (n + 3) / 4, z[4], at4 = 6;
    for (unsigned j = 0; j < 4 && at4 < left; j++) {
     uintptr_t a = j * seg, b = j < 3 ? a + seg : n;
     z[j] = ze_hstream(lit + a, b - a, code, len, sp + at4, left - at4);
     if (!z[j] || (j < 3 && z[j] > 65535)) { at4 = 0; break; }
     at4 += z[j]; }
    if (at4 >= left) at4 = 0;
    if (at4) for (unsigned j = 0; j < 3; j++) sp[2 * j] = (uint8_t) z[j], sp[2 * j + 1] = (uint8_t) (z[j] >> 8);
    cz = at4; }
   uintptr_t c = tz + cz, big = n > c ? n : c;
   unsigned f = !four ? 0 : big <= 1023 ? 1 : big <= 16383 ? 2 : 3, h = f < 2 ? 3 : f + 2,
            bits = f < 2 ? 10 : f == 2 ? 14 : 18;
   if (cz && h + c < raw) {
    uint64_t v = 2 | (uint64_t) f << 2 | (uint64_t) n << 4 | (uint64_t) c << (4 + bits);
    memmove(o + h, t, c);
    for (unsigned i = 0; i < h; i++) o[i] = (uint8_t) (v >> 8 * i);
    return h + c; } } }
 if (raw > cap) return 0;
 if (hs == 1) o[0] = (uint8_t) (n << 3);
 else if (hs == 2) o[0] = (uint8_t) (n << 4 | 4), o[1] = (uint8_t) (n >> 4);
 else o[0] = (uint8_t) (n << 4 | 12), o[1] = (uint8_t) (n >> 4), o[2] = (uint8_t) (n >> 12);
 memcpy(o + hs, lit, n);
 return raw; }

// --- sequences --------------------------------------------------------------------------------
struct ze_seq { uint32_t ll, ml, ov; };
static unsigned ze_code(const uint32_t *base, unsigned n, uint32_t v) {   // the last base at or under v
 unsigned lo = 0, hi = n - 1;
 while (lo < hi) { unsigned m = (lo + hi + 1) / 2; if (base[m] <= v) lo = m; else hi = m - 1; }
 return lo; }
// a table for one of the three: one symbol, the default where it is short, else laid out here
static unsigned ze_table(const uint8_t *cd, uintptr_t ns, unsigned maxs, unsigned maxlog,
                         const int16_t *def, unsigned dn, unsigned dlog, struct ze_fse *c, struct ze_bw *w) {
 uint32_t cnt[64] = {0};
 unsigned top = 0, k = 0;
 int16_t norm[64];
 for (uintptr_t i = 0; i < ns; i++) cnt[cd[i]]++;
 for (unsigned s = 0; s <= maxs; s++) if (cnt[s]) top = s, k++;
 if (k == 1) {
  for (unsigned s = 0; s <= top; s++) norm[s] = s == top;
  ze_fsebuild(c, norm, top + 1, 0), ze_bits(w, top, 8);
  return 1; }
 if (ns < 32 && top < dn && def[top] != 0) {
  ze_fsebuild(c, def, dn, dlog);
  return 0; }
 unsigned al = ze_al(ns, top, maxlog);
 ze_norm(cnt, top + 1, (uint32_t) ns, al, norm);
 ze_fsebuild(c, norm, top + 1, al), ze_ncount(w, norm, al);
 return 2; }
static uintptr_t ze_seqs(const struct ze_seq *sq, uintptr_t ns, uint8_t *cd, uint8_t *o, uintptr_t cap) {
 struct ze_bw w = { o, o + cap, 0, 0, 0 };
 if (ns < 128) ze_bits(&w, ns, 8);
 else if (ns < 0x7f00) ze_bits(&w, (ns >> 8) + 128, 8), ze_bits(&w, ns & 255, 8);
 else ze_bits(&w, 255, 8), ze_bits(&w, ns - 0x7f00, 16);
 if (!ns) return w.bad ? 0 : (uintptr_t) (w.p - o);
 uint8_t *mp = w.p;
 ze_bits(&w, 0, 8);                              // the modes, laid once the tables are chosen
 uint8_t *llc = cd, *ofc = cd + ns, *mlc = cd + 2 * ns;
 for (uintptr_t i = 0; i < ns; i++)
  llc[i] = (uint8_t) ze_code(zs_llbase, 36, sq[i].ll), mlc[i] = (uint8_t) ze_code(zs_mlbase, 53, sq[i].ml),
  ofc[i] = (uint8_t) zs_hb(sq[i].ov);
 struct ze_fse cl, co, cm;
 unsigned ml = ze_table(llc, ns, 35, 9, zs_lldef, 36, 6, &cl, &w),
          mo = ze_table(ofc, ns, 31, 8, zs_ofdef, 29, 5, &co, &w),
          mm = ze_table(mlc, ns, 52, 9, zs_mldef, 53, 6, &cm, &w);
 if (w.bad) return 0;
 *mp = (uint8_t) (ml << 6 | mo << 4 | mm << 2);
 uintptr_t n = ns - 1;
 uint32_t sl = ze_finit(&cl, llc[n]), so = ze_finit(&co, ofc[n]), sm = ze_finit(&cm, mlc[n]);
 for (uintptr_t i = ns; i--; ) {
  if (i < n)
   so = ze_fenc(&w, &co, so, ofc[i]), sm = ze_fenc(&w, &cm, sm, mlc[i]), sl = ze_fenc(&w, &cl, sl, llc[i]);
  ze_bits(&w, sq[i].ll - zs_llbase[llc[i]], zs_llbits[llc[i]]);
  ze_bits(&w, sq[i].ml - zs_mlbase[mlc[i]], zs_mlbits[mlc[i]]);
  ze_bits(&w, sq[i].ov, ofc[i]); }
 ze_bits(&w, sm, cm.al), ze_bits(&w, so, co.al), ze_bits(&w, sl, cl.al);
 ze_close(&w);
 return w.bad ? 0 : (uintptr_t) (w.p - o); }

// --- the parse --------------------------------------------------------------------------------
// a level: the window, the hash, how far down a chain, a length that ends the search, lazy or not
struct ze_cfg { unsigned wlog, hlog, depth, good, lazy; };
static const uint16_t ze_depth[20] = { 1, 1, 2, 4, 6, 8, 12, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192 };
static struct ze_cfg ze_cfg(int lv) {
 return (struct ze_cfg) { lv <= 2 ? 20 : lv <= 5 ? 21 : lv <= 12 ? 22 : 23, lv <= 2 ? 17 : lv <= 3 ? 18 : lv <= 6 ? 19 : 20,
                          ze_depth[lv], lv <= 3 ? 24 : lv <= 9 ? 64 : lv <= 15 ? 128 : 256, lv >= 4 }; }
struct ze_mf { const uint8_t *s; uintptr_t n, wmask, ins; uint32_t *head, *chain; unsigned hlog, depth, good; };
static uint32_t ze_h4(const uint8_t *p, unsigned hl) { return (uint32_t) (xx_rd(p, 4) * 2654435761u) >> (32 - hl); }
static void ze_upto(struct ze_mf *m, uintptr_t p) {     // every position before p in its chain
 for (; m->ins < p && m->ins + 4 <= m->n; m->ins++) {
  uint32_t h = ze_h4(m->s + m->ins, m->hlog);
  m->chain[m->ins & m->wmask] = m->head[h], m->head[h] = (uint32_t) m->ins + 1; } }
static uintptr_t ze_len(const uint8_t *a, const uint8_t *b, uintptr_t lim) {
 uintptr_t k = 0;
 for (uint64_t x, y; k + 8 <= lim; k += 8) {
  memcpy(&x, a + k, 8), memcpy(&y, b + k, 8);
  if (x != y) break; }
 while (k < lim && a[k] == b[k]) k++;
 return k; }
// the longest match at p reaching no further than e -> its length, *off its distance
static uintptr_t ze_find(struct ze_mf *m, uintptr_t p, uintptr_t e, uint64_t *off) {
 uintptr_t best = 0;
 if (p + 4 > m->n) return 0;
 ze_upto(m, p);
 uint32_t c = m->head[ze_h4(m->s + p, m->hlog)];
 for (unsigned d = 0; c && d < m->depth; d++) {
  uintptr_t q = c - 1;
  if (q >= p || p - q > m->wmask) break;
  if (m->s[q + best] == m->s[p + best]) {
   uintptr_t k = ze_len(m->s + q, m->s + p, e - p);
   if (k > best) best = k, *off = p - q;
   if (p + best == e || best >= m->good) break; }
  uint32_t nx = m->chain[q & m->wmask];
  if (nx >= c) break;
  c = nx; }
 return best >= 4 ? best : 0; }
// the reader's repeat code for off, else off + 3; rep moved as the reader moves it
static uint32_t ze_ov(uint64_t *rep, uintptr_t ll, uint64_t off) {
 for (unsigned ov = 1; ov <= 3; ov++) {
  unsigned x = ov - 1 + !ll;
  if ((x == 0 ? rep[0] : x == 1 ? rep[1] : x == 2 ? rep[2] : rep[0] - 1) == off) {
   if (x) { if (x > 1) rep[2] = rep[1]; rep[1] = rep[0], rep[0] = off; }
   return ov; } }
 rep[2] = rep[1], rep[1] = rep[0], rep[0] = off;
 return (uint32_t) off + 3; }

// one block of s at [a, e) -> its bytes, header first, in o
static uintptr_t ze_block(struct ze_mf *m, const struct ze_cfg *cf, uintptr_t a, uintptr_t e, int last,
                          uint64_t *rep, uint8_t *lit, struct ze_seq *sq, uint8_t *cd, uint8_t *o, uintptr_t cap) {
 const uint8_t *s = m->s;
 uintptr_t n = e - a, p = a, l0 = a, nl = 0, ns = 0, body = 0;
 uint64_t rp[3] = { rep[0], rep[1], rep[2] };
 int same = n > 0;
 for (uintptr_t i = a + 1; same && i < e; i++) same = s[i] == s[a];
 if (same && n > 3) {
  o[0] = (uint8_t) (n << 3 | 2 | last), o[1] = (uint8_t) (n >> 5), o[2] = (uint8_t) (n >> 13), o[3] = s[a];
  return 4; }
 while (p < e) {
  uint64_t off = 0, o2 = 0, r0 = rp[0];
  uintptr_t k = 0;
  if (p >= r0 && p - r0 < p && r0 <= m->wmask) {             // the last distance again, first
   uintptr_t r = ze_len(s + p - r0, s + p, e - p);
   if (r >= 4) k = r, off = r0; }
  uintptr_t f = ze_find(m, p, e, &o2);
  if (f > k + 1) k = f, off = o2;
  if (k && cf->lazy && p + 1 < e) {              // one step on, a longer one wins
   uintptr_t f1 = ze_find(m, p + 1, e, &o2);
   if (f1 > k + 1) { p++; k = f1, off = o2; } }
  if (!k) { p += 1 + ((p - l0) >> 8); continue; }   // a long run of nothing found is passed over faster
  uintptr_t ll = p - l0;
  memcpy(lit + nl, s + l0, ll), nl += ll;
  sq[ns].ll = (uint32_t) ll, sq[ns].ml = (uint32_t) k, sq[ns].ov = ze_ov(rp, ll, off), ns++;
  p += k, l0 = p; }
 memcpy(lit + nl, s + l0, e - l0), nl += e - l0;
 if (cap > 3) {
  uintptr_t lz = ze_lits(lit, nl, o + 3, cap - 3), sz = lz ? ze_seqs(sq, ns, cd, o + 3 + lz, cap - 3 - lz) : 0;
  body = lz && sz ? lz + sz : 0; }
 if (body && body < n) {
  o[0] = (uint8_t) (body << 3 | 4 | last), o[1] = (uint8_t) (body >> 5), o[2] = (uint8_t) (body >> 13);
  rep[0] = rp[0], rep[1] = rp[1], rep[2] = rp[2];
  return 3 + body; }
 if (n + 3 > cap) return 0;                      // stored: the reader's repeats stand as they were
 o[0] = (uint8_t) (n << 3 | last), o[1] = (uint8_t) (n >> 5), o[2] = (uint8_t) (n >> 13);
 memcpy(o + 3, s + a, n);
 return 3 + n; }

static uintptr_t ze_cap(uintptr_t n) { return n + 3 * (n / ZS_BMAX + 1) + 32; }
// s whole -> the frame in o, cap ze_cap(n) | 0
static uintptr_t ze_frame(const uint8_t *s, uintptr_t n, int lv, uint8_t *o, uintptr_t cap) {
 struct ze_cfg cf = ze_cfg(lv);
 while (cf.wlog > 10 && (uintptr_t) 1 << (cf.wlog - 1) >= n) cf.wlog--;
 if (cf.hlog > cf.wlog) cf.hlog = cf.wlog;
 int ss = n <= (uintptr_t) 1 << cf.wlog;
 unsigned fz = ss && n < 256 ? 1 : n < 65536 + 256 && n >= 256 ? 2 : n < ((uint64_t) 1 << 32) ? 4 : 8,
          ff = fz == 1 ? 0 : fz == 2 ? 1 : fz == 4 ? 2 : 3;
 uintptr_t at = 0;
 uint64_t fcs = fz == 2 ? n - 256 : n;
 o[at++] = 0x28, o[at++] = 0xb5, o[at++] = 0x2f, o[at++] = 0xfd;
 o[at++] = (uint8_t) (ff << 6 | (unsigned) ss << 5 | 4);
 if (!ss) o[at++] = (uint8_t) ((cf.wlog - 10) << 3);
 for (unsigned i = 0; i < fz; i++) o[at++] = (uint8_t) (fcs >> 8 * i);
 uintptr_t wsz = (uintptr_t) 1 << cf.wlog;
 struct ze_mf m = { s, n, wsz - 1, 0, alloc(NULL, ((uintptr_t) 1 << cf.hlog) * 4), alloc(NULL, wsz * 4), cf.hlog, cf.depth, cf.good };
 uint8_t *lit = alloc(NULL, ZS_BMAX), *cd = alloc(NULL, 3 * (ZS_BMAX / 3 + 1));
 struct ze_seq *sq = alloc(NULL, (ZS_BMAX / 3 + 1) * sizeof *sq);
 int good = m.head && m.chain && lit && cd && sq;
 if (good) memset(m.head, 0, ((uintptr_t) 1 << cf.hlog) * 4);
 uint64_t rep[3] = { 1, 4, 8 };
 for (uintptr_t a = 0; good; ) {
  uintptr_t e = n - a > ZS_BMAX ? a + ZS_BMAX : n,
            k = ze_block(&m, &cf, a, e, e == n, rep, lit, sq, cd, o + at, cap - at);
  if (!k) good = 0;
  at += k, a = e;
  if (a == n) break; }
 if (m.head) alloc(m.head, 0);
 if (m.chain) alloc(m.chain, 0);
 if (lit) alloc(lit, 0);
 if (cd) alloc(cd, 0);
 if (sq) alloc(sq, 0);
 if (!good || at + 4 > cap) return 0;
 struct xx_st x;
 xx_init(&x), xx_feed(&x, s, n);
 uint64_t h = xx_done(&x);
 for (int i = 0; i < 4; i++) o[at++] = (uint8_t) (h >> 8 * i);
 return at; }

#ifndef ZS_STANDALONE
// ===== the nifs: str0 may collect, so the state is found again after it =====
#define ZS_HEAD ((sizeof(struct zs_st) + 7) & ~(uintptr_t) 7)
static struct str *zs_cask(word x) {
 struct str *s = cask_str(x);
 struct zs_st *S = s && s->len > ZS_HEAD ? (struct zs_st*) s->bytes : NULL;
 return S && S->magic == ZS_MAGIC && S->cap + ZS_SLACK == s->len - ZS_HEAD ? s : NULL; }

love_noinline static struct g *host_zstd_new(struct g *g) {
 word ww = g->sp[0];
 if (!oddp(ww) || getcharm(ww) < 0 || (uintptr_t) getcharm(ww) > ZS_WMAX) return g->sp[0] = ZeroPoint, g;
 uintptr_t win = (uintptr_t) getcharm(ww), cap = win + zs_room(win), n = ZS_HEAD + cap + ZS_SLACK;
 union u *k = new_cask(&g, n, offsetof(struct zs_st, lit));
 if (!k) return g;
 struct zs_st *S = (struct zs_st*) cask(k)->str->bytes;
 S->magic = ZS_MAGIC, S->cap = cap, S->win = win, S->rep[0] = 1, S->rep[1] = 4, S->rep[2] = 8;
 xx_init(&S->x);
 return g->sp[0] = word(k), g; }

love_noinline static struct g *host_zstd_block(struct g *g) {
 struct str *cs = zs_cask(g->sp[0]);
 if (!cs || !strp(g->sp[1])) return g->sp[1] = ZeroPoint, g->sp += 1, g;
 struct zs_st *S = (struct zs_st*) cs->bytes;
 intptr_t got = zs_block(S, (uint8_t*) cs->bytes + ZS_HEAD, (const uint8_t*) txt(g->sp[1]), len(g->sp[1]));
 if (got < 0) return S->magic = 0, g->sp[1] = ZeroPoint, g->sp += 1, g;   // a torn state is no state
 uintptr_t o0 = S->n - (uintptr_t) got;
 if (!ok(g = str0(g, (uintptr_t) got))) return g;   // pushes: out over st and b
 memcpy(txt(g->sp[0]), zs_cask(g->sp[1])->bytes + ZS_HEAD + o0, (uintptr_t) got);
 return g->sp[2] = g->sp[0], g->sp += 2, g; }

love_noinline static struct g *host_zstd_sum(struct g *g) {
 if (!zs_cask(g->sp[0])) return g->sp[0] = ZeroPoint, g;
 if (!ok(g = str0(g, 4))) return g;
 uint64_t h = xx_done(&((const struct zs_st*) zs_cask(g->sp[1])->bytes)->x);
 for (int i = 0; i < 4; i++) ((uint8_t*) txt(g->sp[0]))[i] = (uint8_t) (h >> 8 * i);
 return g->sp[1] = g->sp[0], g->sp++, g; }

love_noinline static struct g *host_zstd_d(struct g *g) {
 uintptr_t on = 0;
 uint8_t *w = strp(g->sp[0]) ? zs_whole((const uint8_t*) txt(g->sp[0]), len(g->sp[0]), &on) : NULL;
 if (!w) return g->sp[0] = ZeroPoint, g;
 if (ok(g = str0(g, on))) memcpy(txt(g->sp[0]), w, on), g->sp[1] = g->sp[0], g->sp++;   // pushes: out over s
 alloc(w, 0);
 return g; }

love_noinline static struct g *host_zstde(struct g *g) {
 word sw = g->sp[0], lw = g->sp[1];
 if (!strp(sw) || !oddp(lw) || getcharm(lw) < 1 || getcharm(lw) > 19) return g->sp[1] = ZeroPoint, g->sp += 1, g;
 uintptr_t n = len(sw), cap = ze_cap(n), got;
 uint8_t *out = alloc(NULL, cap);
 got = out ? ze_frame((const uint8_t*) txt(sw), n, (int) getcharm(lw), out, cap) : 0;
 if (got && ok(g = str0(g, got))) {             // pushes: out over the two
  memcpy(txt(g->sp[0]), out, got);
  g->sp[2] = g->sp[0], g->sp += 2; }
 else if (ok(g)) g->sp[1] = ZeroPoint, g->sp += 1;
 if (out) alloc(out, 0);
 return g; }

static LvmWrap(lvm_zstd_new, host_zstd_new)
static LvmWrap(lvm_zstd_block, host_zstd_block)
static LvmWrap(lvm_zstd_sum, host_zstd_sum)
static LvmWrap(lvm_zstde, host_zstde)
static LvmWrap(lvm_zstd_d, host_zstd_d)

LvDef("zstd-new", zstd_new, 1, "zstd");
LvDef("zstd-block", zstd_block, 2, "zstd");
LvDef("zstd-sum", zstd_sum, 1, "zstd");
LvDef("zstde", zstde, 2, "zstd");
LvDef("zstd-d", zstd_d, 1, "zstd");
#endif
