// src/love/lib/bz2.c -- bzip2, both directions. the whole stream is here: its blocks are laid on
// bit boundaries, so there is no byte-aligned container for src/apps/bz2.l to hold.
//   (bz2e s level)   bytes -> a .bz2 stream, level 1..9 the block in 100k | ()
//   (bz2d s)         every .bz2 stream in s -> their bytes | 1 format, 2 corrupt, 3 end, 4 check,
//                    5 past BZ_OUTMAX
//   (bz2-new 0)      a state for reading a block at a time
//   (bz2-step st b eof)  the next block (or a stream's head or end) off b at st's bit ->
//                    (bytes . k), k whole bytes of b now behind it | -1 more of b wanted |
//                    0 every stream read | bz2d's codes. eof: b is all there is
// the coder is bzip2's pipeline: runs of four, the rotations sorted by prefix doubling,
// move-to-front with the zero runs in RUNA/RUNB, and 2..6 huffman tables refined four times.
#ifndef BZ_STANDALONE
#include "love.h"
#include "bytes.h"
#endif
#include <stdint.h>
#include <string.h>

#define BZ_RUNA 0
#define BZ_RUNB 1
#define BZ_GSIZE 50
#define BZ_MAXLEN 17                             // the coder's; a decoder takes up to 20
#define BZ_MAXSEL (2 + 900000 / BZ_GSIZE)
#define BZ_FAST 10                               // the decode table's root, in bits
#define BZ_OUTMAX ((uintptr_t) 1 << 30)          // the output is one heap string: no further

static void bz_crcs(uint32_t *t) {               // CRC-32/BZIP2: cksum's msb-first register
 for (uint32_t i = 0; i < 256; i++) t[i] = crc_msb(0, (uint8_t) i); }

// --- a growing byte sink, msb-first bits -----------------------------------------------------
struct bz_w { uint8_t *p; uintptr_t n, cap; uint64_t acc; unsigned k; int bad, big, fix; };   // fix: p is the caller's, never grown

static void bw_byte(struct bz_w *w, uint8_t b) {
 if (w->n == w->cap) {
  if (w->fix || w->n >= BZ_OUTMAX) { w->bad = 1, w->big = !w->fix; return; }
  uintptr_t c = w->cap ? w->cap * 2 : 4096;
  uint8_t *q = w->bad ? NULL : alloc(NULL, c);
  if (!q) { w->bad = 1; return; }
  if (w->n) memcpy(q, w->p, w->n);
  if (w->p) alloc(w->p, 0);
  w->p = q, w->cap = c; }
 w->p[w->n++] = b; }

static void bw_put(struct bz_w *w, uint32_t v, unsigned k) {   // k <= 32
 w->acc = w->acc << k | (v & (uint32_t) ((1ull << k) - 1)), w->k += k;
 while (w->k >= 8) w->k -= 8, bw_byte(w, (uint8_t) (w->acc >> w->k)); }

static void bw_flush(struct bz_w *w) { if (w->k) bw_put(w, 0, 8 - w->k); }

// --- the coder --------------------------------------------------------------------------------
struct bz_e {
 uint8_t *blk;                                  // the block after runs of four
 uint32_t *sa, *rk, *tmp, *cnt;                 // the rotation sort
 uint16_t *mtf;                                 // the symbols, EOB included
 uint8_t sel[BZ_MAXSEL], selm[BZ_MAXSEL];
 uint8_t len[6][258]; uint32_t code[6][258];
 uint32_t crct[256]; };

// the rotations of b[0..n) in order, into sa: prefix doubling over ranks, one stable
// counting sort a round. equal rotations may land in any order -- they read the same.
static void bz_sort(struct bz_e *e, uintptr_t n) {
 uint32_t *sa = e->sa, *rk = e->rk, *tmp = e->tmp, *cnt = e->cnt;
 const uint8_t *b = e->blk;
 uint32_t nc = 256;
 memset(cnt, 0, 256 * sizeof *cnt);
 for (uintptr_t i = 0; i < n; i++) cnt[b[i]]++;
 for (uint32_t c = 0, s = 0; c < 256; c++) { uint32_t t = cnt[c]; cnt[c] = s; s += t; }
 for (uintptr_t i = 0; i < n; i++) sa[cnt[b[i]]++] = (uint32_t) i;
 for (uintptr_t i = 0; i < n; i++) rk[i] = b[i];
 for (uintptr_t k = 1; k < n; k <<= 1) {
  // sa is in order of rk; shifted back by k it is in order of the second key
  for (uintptr_t j = 0; j < n; j++) tmp[j] = (uint32_t) (sa[j] >= k ? sa[j] - k : sa[j] + n - k);
  memset(cnt, 0, nc * sizeof *cnt);
  for (uintptr_t j = 0; j < n; j++) cnt[rk[tmp[j]]]++;
  for (uint32_t c = 0, s = 0; c < nc; c++) s += cnt[c], cnt[c] = s;
  for (uintptr_t j = n; j-- > 0; ) sa[--cnt[rk[tmp[j]]]] = tmp[j];
  uint32_t r = 0, *nr = tmp;
  nr[sa[0]] = 0;
  for (uintptr_t j = 1; j < n; j++) {
   uintptr_t a = sa[j - 1], c = sa[j], a2 = a + k, c2 = c + k;
   if (a2 >= n) a2 -= n;
   if (c2 >= n) c2 -= n;
   if (rk[a] != rk[c] || rk[a2] != rk[c2]) r++;
   nr[c] = r; }
  e->tmp = rk, e->rk = nr, rk = nr, tmp = e->tmp;
  nc = r + 1;
  if (nc == n) break; } }

// huffman lengths for f[0..n), none over lim: a zero count is taken as one, since every
// symbol wants a code, and counts are halved until the tree fits.
static void bz_lens(uint8_t *len, const uint32_t *f0, unsigned n, unsigned lim) {
 uint32_t f[258], w[516]; int par[516], act[516];
 for (unsigned i = 0; i < n; i++) f[i] = f0[i] ? f0[i] : 1;
 for (;;) {
  unsigned m = n, na = n;
  for (unsigned i = 0; i < n; i++) w[i] = f[i], par[i] = -1, act[i] = (int) i;
  while (na > 1) {                              // the two lightest, joined
   unsigned a = 0, b = 1;
   if (w[act[b]] < w[act[a]]) a = 1, b = 0;
   for (unsigned i = 2; i < na; i++) {
    if (w[act[i]] < w[act[a]]) b = a, a = i;
    else if (w[act[i]] < w[act[b]]) b = i; }
   w[m] = w[act[a]] + w[act[b]], par[m] = -1;
   par[act[a]] = par[act[b]] = (int) m;
   unsigned hi = a > b ? a : b, lo = a > b ? b : a;
   act[hi] = act[--na];
   act[lo] = (int) m++; }
  unsigned mx = 0;
  for (unsigned i = 0; i < n; i++) {
   unsigned d = 0;
   for (int p = par[i]; p >= 0; p = par[p]) d++;
   len[i] = (uint8_t) (d ? d : 1);
   if (len[i] > mx) mx = len[i]; }
  if (mx <= lim) return;
  for (unsigned i = 0; i < n; i++) f[i] = 1 + f[i] / 2; } }

static void bz_codes(uint32_t *code, const uint8_t *len, unsigned n) {
 uint32_t v = 0;
 for (unsigned l = 1; l <= 20; l++) {
  for (unsigned i = 0; i < n; i++) if (len[i] == l) code[i] = v++;
  v <<= 1; } }

// one block: b[0..n) after runs of four, crc over its raw bytes
static void bz_block(struct bz_e *e, struct bz_w *w, uintptr_t n, uint32_t crc) {
 const uint8_t *b = e->blk;
 bz_sort(e, n);
 uint8_t inuse[256] = {0}, unseq[256];
 unsigned nuse = 0;
 for (uintptr_t i = 0; i < n; i++) inuse[b[i]] = 1;
 for (unsigned c = 0; c < 256; c++) if (inuse[c]) unseq[c] = (uint8_t) nuse++;
 unsigned alpha = nuse + 2;
 // the mtf, zero runs as RUNA/RUNB in bijective base two
 uint8_t yy[256];
 uint32_t freq[258] = {0}, orig = 0;
 uintptr_t nm = 0, z = 0;
 uint16_t *mv = e->mtf;
 for (unsigned i = 0; i < nuse; i++) yy[i] = (uint8_t) i;
 for (uintptr_t j = 0; j <= n; j++) {
  int last = j == n;
  uint8_t c = 0;
  if (!last) {
   uintptr_t s = e->sa[j];
   if (!s) orig = (uint32_t) j;
   c = unseq[b[s ? s - 1 : n - 1]]; }
  if (!last && yy[0] == c) { z++; continue; }
  if (z) {
   for (z--;; z = (z - 2) / 2) {
    uint16_t r = z & 1 ? BZ_RUNB : BZ_RUNA;
    mv[nm++] = r, freq[r]++;
    if (z < 2) break; }
   z = 0; }
  if (last) break;
  unsigned p = 1;
  uint8_t t = yy[1];
  yy[1] = yy[0];
  while (t != c) { uint8_t u = t; t = yy[++p]; yy[p] = u; }
  yy[0] = c;
  mv[nm++] = (uint16_t) (p + 1), freq[p + 1]++; }
 mv[nm++] = (uint16_t) (alpha - 1), freq[alpha - 1]++;
 // the tables: seeded by cutting the alphabet into equal-frequency bands, then refined
 unsigned ng = nm < 200 ? 2 : nm < 600 ? 3 : nm < 1200 ? 4 : nm < 2400 ? 5 : 6;
 {
  uintptr_t rem = nm; unsigned gs = 0;
  for (unsigned np = ng; np > 0; np--) {
   uintptr_t want = rem / np, got = 0; int ge = (int) gs - 1;
   while (got < want && ge < (int) alpha - 1) got += freq[++ge];
   if (ge > (int) gs && np != ng && np != 1 && (ng - np) % 2 == 1) got -= freq[ge--];
   for (unsigned v = 0; v < alpha; v++) e->len[np - 1][v] = (int) v >= (int) gs && (int) v <= ge ? 0 : 15;
   gs = (unsigned) (ge + 1), rem -= got; } }
 unsigned nsel = 0;
 for (int it = 0; it < 4; it++) {
  uint32_t rf[6][258];
  memset(rf, 0, sizeof rf);
  nsel = 0;
  for (uintptr_t gs = 0; gs < nm; gs += BZ_GSIZE) {
   uintptr_t ge = gs + BZ_GSIZE < nm ? gs + BZ_GSIZE : nm;
   uint32_t cost[6] = {0};
   for (uintptr_t i = gs; i < ge; i++)
    for (unsigned t = 0; t < ng; t++) cost[t] += e->len[t][mv[i]];
   unsigned bt = 0;
   for (unsigned t = 1; t < ng; t++) if (cost[t] < cost[bt]) bt = t;
   e->sel[nsel++] = (uint8_t) bt;
   for (uintptr_t i = gs; i < ge; i++) rf[bt][mv[i]]++; }
  for (unsigned t = 0; t < ng; t++) bz_lens(e->len[t], rf[t], alpha, BZ_MAXLEN); }
 for (unsigned t = 0; t < ng; t++) bz_codes(e->code[t], e->len[t], alpha);
 {
  uint8_t pos[6];
  for (unsigned t = 0; t < ng; t++) pos[t] = (uint8_t) t;
  for (unsigned i = 0; i < nsel; i++) {
   uint8_t s = e->sel[i], j = 0, t = pos[0];
   while (t != s) { uint8_t u = t; t = pos[++j]; pos[j] = u; }
   pos[0] = t, e->selm[i] = j; } }
 bw_put(w, 0x314159, 24), bw_put(w, 0x265359, 24);
 bw_put(w, crc, 32), bw_put(w, 0, 1), bw_put(w, orig, 24);
 unsigned u16 = 0;
 for (unsigned i = 0; i < 16; i++)
  for (unsigned j = 0; j < 16; j++) if (inuse[i * 16 + j]) { u16 |= 1u << (15 - i); break; }
 bw_put(w, u16, 16);
 for (unsigned i = 0; i < 16; i++) if (u16 >> (15 - i) & 1) {
  unsigned m = 0;
  for (unsigned j = 0; j < 16; j++) m = m << 1 | inuse[i * 16 + j];
  bw_put(w, m, 16); }
 bw_put(w, ng, 3), bw_put(w, nsel, 15);
 for (unsigned i = 0; i < nsel; i++) bw_put(w, ((1u << e->selm[i]) - 1) << 1, e->selm[i] + 1u);
 for (unsigned t = 0; t < ng; t++) {
  unsigned c = e->len[t][0];
  bw_put(w, c, 5);
  for (unsigned v = 0; v < alpha; v++) {
   for (; c < e->len[t][v]; c++) bw_put(w, 2, 2);
   for (; c > e->len[t][v]; c--) bw_put(w, 3, 2);
   bw_put(w, 0, 1); } }
 for (uintptr_t i = 0, g = 0; i < nm; i++) {
  if (i && i % BZ_GSIZE == 0) g++;
  unsigned t = e->sel[g];
  bw_put(w, e->code[t][mv[i]], e->len[t][mv[i]]); } }

static void bz_efree(struct bz_e *e) {
 void *p[] = {e->blk, e->sa, e->rk, e->tmp, e->cnt, e->mtf};
 for (unsigned i = 0; i < sizeof p / sizeof *p; i++) if (p[i]) alloc(p[i], 0);
 alloc(e, 0); }

// s[0..n) -> a whole .bz2 stream in *w; 0 ok, -1 out of memory
static int bz_enc(const uint8_t *s, uintptr_t n, unsigned level, struct bz_w *w) {
 uintptr_t lim = level * 100000u - 19, bn = lim + 8;
 struct bz_e *e = alloc(NULL, sizeof *e);
 if (!e) return -1;
 memset(e, 0, sizeof *e);
 e->blk = alloc(NULL, bn);
 e->sa = alloc(NULL, bn * 4), e->rk = alloc(NULL, bn * 4);
 e->tmp = alloc(NULL, bn * 4), e->cnt = alloc(NULL, (bn > 256 ? bn : 256) * 4);
 e->mtf = alloc(NULL, (bn + 2) * 2);
 if (!e->blk || !e->sa || !e->rk || !e->tmp || !e->cnt || !e->mtf) return bz_efree(e), -1;
 bz_crcs(e->crct);
 bw_put(w, 0x425a68, 24), bw_put(w, 48 + level, 8);
 uint32_t all = 0;
 for (uintptr_t i = 0; i < n; ) {
  uintptr_t k = 0;
  uint32_t crc = 0xffffffffu;
  while (i < n) {                                // runs of four and more: four and a count
   uintptr_t r = 1;
   while (i + r < n && r < 255 && s[i + r] == s[i]) r++;
   uintptr_t sz = r < 4 ? r : 5;
   if (k + sz > lim) break;
   for (uintptr_t j = 0; j < r; j++) crc = crc << 8 ^ e->crct[(crc >> 24 ^ s[i]) & 255];
   for (uintptr_t j = 0; j < (r < 4 ? r : 4); j++) e->blk[k++] = s[i];
   if (r >= 4) e->blk[k++] = (uint8_t) (r - 4);
   i += r; }
  crc = ~crc;
  all = (all << 1 | all >> 31) ^ crc;
  bz_block(e, w, k, crc); }
 bw_put(w, 0x177245, 24), bw_put(w, 0x385090, 24), bw_put(w, all, 32);
 bw_flush(w);
 bz_efree(e);
 return w->bad ? -1 : 0; }

// --- the decoder ------------------------------------------------------------------------------
struct bz_r { const uint8_t *p; uintptr_t i, n; uint64_t acc; unsigned k; };

static void br_fill(struct bz_r *r) {            // at least 57 bits in hand; zeros past the end
 while (r->k <= 56) r->acc = r->acc << 8 | (r->i < r->n ? r->p[r->i] : 0), r->i++, r->k += 8; }
static uint32_t br_peek(struct bz_r *r, unsigned k) { return (uint32_t) (r->acc >> (r->k - k)) & (uint32_t) ((1ull << k) - 1); }
static uint32_t br_get(struct bz_r *r, unsigned k) {   // k <= 32
 if (r->k < k) br_fill(r);
 uint32_t v = br_peek(r, k);
 return r->k -= k, v; }
static uintptr_t br_used(struct bz_r *r) { return r->i * 8 - r->k; }  // bits consumed

struct bz_tab {
 uint16_t fast[1 << BZ_FAST];                    // sym << 5 | len, or 0 past the root
 uint32_t limit[22], base[22]; uint16_t perm[258]; unsigned minl, maxl; };

static int bz_tbuild(struct bz_tab *t, const uint8_t *len, unsigned n) {
 unsigned cnt[22] = {0};
 t->minl = 32, t->maxl = 0;
 for (unsigned i = 0; i < n; i++) {
  cnt[len[i]]++;
  if (len[i] < t->minl) t->minl = len[i];
  if (len[i] > t->maxl) t->maxl = len[i]; }
 uint32_t code = 0, k = 0;
 memset(t->fast, 0, sizeof t->fast);
 for (unsigned l = 1; l <= 20; l++) {
  t->base[l] = code - k;                        // code c of length l is perm[c - base[l]]
  for (unsigned i = 0; i < n; i++) if (len[i] == l) {
   t->perm[k++] = (uint16_t) i;
   if (l <= BZ_FAST) {
    uint32_t lo = code << (BZ_FAST - l), hi = lo + (1u << (BZ_FAST - l));
    if (hi > 1u << BZ_FAST) return 0;           // over-subscribed
    for (uint32_t j = lo; j < hi; j++) t->fast[j] = (uint16_t) (i << 5 | l); }
   code++; }
  if (code > 1u << l) return 0;
  t->limit[l] = code;                            // one past the last code of this length
  code <<= 1; }
 return 1; }

static int bz_sym(struct bz_r *r, const struct bz_tab *t) {
 if (r->k < 20) br_fill(r);
 uint16_t f = t->fast[br_peek(r, BZ_FAST)];
 if (f) return r->k -= f & 31, f >> 5;
 for (unsigned l = BZ_FAST + 1; l <= t->maxl; l++) {
  uint32_t c = br_peek(r, l);
  if (c < t->limit[l]) return r->k -= l, t->perm[c - t->base[l]]; }
 return -1; }

struct bz_d { uint32_t tt[900000]; struct bz_tab tab[6]; uint8_t sel[BZ_MAXSEL]; uint32_t crct[256]; };

// one block after its magic -> 0 | an error; its bytes appended to w, their crc checked
static int bz_dblock(struct bz_d *d, struct bz_r *r, unsigned level, struct bz_w *w, uint32_t *bcrc) {
 uint32_t want = br_get(r, 32);
 if (br_get(r, 1)) return 2;                     // randomised: no coder since 0.9.5 lays it
 uint32_t orig = br_get(r, 24);
 uint8_t seq[256]; unsigned nuse = 0;
 unsigned u16 = br_get(r, 16);
 for (unsigned i = 0; i < 16; i++) if (u16 >> (15 - i) & 1) {
  unsigned m = br_get(r, 16);
  for (unsigned j = 0; j < 16; j++) if (m >> (15 - j) & 1) seq[nuse++] = (uint8_t) (i * 16 + j); }
 if (!nuse) return 2;
 unsigned alpha = nuse + 2, ng = br_get(r, 3), ns = br_get(r, 15);
 if (ng < 2 || ng > 6 || !ns) return 2;
 uint8_t pos[6];
 for (unsigned t = 0; t < ng; t++) pos[t] = (uint8_t) t;
 for (unsigned i = 0; i < ns; i++) {
  unsigned j = 0;
  while (br_get(r, 1)) if (++j >= ng) return 2;
  uint8_t v = pos[j];
  for (; j; j--) pos[j] = pos[j - 1];
  pos[0] = v;
  if (i < BZ_MAXSEL) d->sel[i] = v; }
 if (ns > BZ_MAXSEL) ns = BZ_MAXSEL;
 for (unsigned t = 0; t < ng; t++) {
  uint8_t len[258];
  int c = (int) br_get(r, 5);
  for (unsigned v = 0; v < alpha; v++) {
   for (;;) {
    if (c < 1 || c > 20) return 2;
    if (!br_get(r, 1)) break;
    c += br_get(r, 1) ? -1 : 1; }
   len[v] = (uint8_t) c; }
  if (!bz_tbuild(&d->tab[t], len, alpha)) return 2;
  if (br_used(r) > r->n * 8) return 3; }
 // the symbols: mtf and zero runs back to the bwt's last column, in tt's low byte
 uint32_t cnt[256] = {0}, max = level * 100000u, nb = 0, run = 0, rw = 1;
 uint8_t yy[256];
 for (unsigned i = 0; i < 256; i++) yy[i] = (uint8_t) i;
 for (unsigned g = 0, left = 0;; left--) {
  if (!left) {
   if (g >= ns) return 2;
   left = BZ_GSIZE, g++;
   if (br_used(r) > r->n * 8) return 3; }
  int s = bz_sym(r, &d->tab[d->sel[g - 1]]);
  if (s < 0) return 2;
  if (s <= BZ_RUNB) {
   if (rw > max) return 2;
   run += rw << s, rw <<= 1;
   continue; }
  if (run) {
   uint8_t c = seq[yy[0]];
   if (run > max - nb) return 2;
   cnt[c] += run;
   while (run--) d->tt[nb++] = c;
   run = 0, rw = 1; }
  if ((unsigned) s == alpha - 1) break;
  if (nb >= max) return 2;
  unsigned k = (unsigned) s - 1;
  uint8_t v = yy[k];
  memmove(yy + 1, yy, k);
  yy[0] = v;
  cnt[seq[v]]++, d->tt[nb++] = seq[v]; }
 if (br_used(r) > r->n * 8) return 3;
 if (orig >= nb) return 2;
 uint32_t cf[256];
 for (uint32_t c = 0, s = 0; c < 256; c++) cf[c] = s, s += cnt[c];
 for (uint32_t i = 0; i < nb; i++) d->tt[cf[d->tt[i] & 255]++] |= i << 8;
 // walk it, the runs of four undone on the way out
 uint32_t p = d->tt[orig] >> 8, crc = 0xffffffffu;
 int last = -1; unsigned same = 0;
 for (uint32_t i = 0; i < nb; i++) {
  p = d->tt[p];
  uint8_t c = (uint8_t) p;
  p >>= 8;
  if (same == 4) {
   for (unsigned j = 0; j < c; j++) crc = crc << 8 ^ d->crct[(crc >> 24 ^ (uint32_t) last) & 255], bw_byte(w, (uint8_t) last);
   same = 0, last = -1;
   continue; }
  crc = crc << 8 ^ d->crct[(crc >> 24 ^ c) & 255], bw_byte(w, c);
  same = c == last ? same + 1 : 1, last = c; }
 if (w->bad) return -1;
 if (~crc != want) return 4;
 return *bcrc = want, 0; }

// every stream in s[0..n) -> 0 | an error; -1 out of memory
static int bz_dec(const uint8_t *s, uintptr_t n, struct bz_w *w) {
 struct bz_d *d = alloc(NULL, sizeof *d);
 if (!d) return -1;
 bz_crcs(d->crct);
 struct bz_r r = { s, 0, n, 0, 0 };
 int rc = 0;
 for (unsigned nstream = 0;; nstream++) {
  uintptr_t at = br_used(&r) / 8;
  if (at + 4 > n || s[at] != 'B' || s[at + 1] != 'Z' || s[at + 2] != 'h' || s[at + 3] < '1' || s[at + 3] > '9') {
   rc = nstream ? 0 : at + 4 > n && !memcmp(s + at, "BZh", n - at < 3 ? n - at : 3) ? 3 : 1;
   break; }                                      // after the first, what follows is trailing garbage
  unsigned level = s[at + 3] - '0';
  r.i = at + 4, r.k = 0, r.acc = 0;
  uint32_t all = 0;
  for (;;) {
   uint32_t m1 = br_get(&r, 24), m2 = br_get(&r, 24);
   if (br_used(&r) > n * 8) { rc = 3; break; }
   if (m1 == 0x314159 && m2 == 0x265359) {
    uint32_t b;
    if ((rc = bz_dblock(d, &r, level, w, &b))) break;
    all = (all << 1 | all >> 31) ^ b; }
   else if (m1 == 0x177245 && m2 == 0x385090) {
    uint32_t c = br_get(&r, 32);
    if (br_used(&r) > n * 8) rc = 3;
    else if (c != all) rc = 4;
    r.k -= r.k % 8;                              // the stream ends on a byte
    break; }
   else { rc = 2; break; } }
  if (rc) break; }
 if (rc == 2 && br_used(&r) > n * 8) rc = 3;      // nonsense read off the end is a short stream
 alloc(d, 0);
 return w->bad ? -1 : rc; }

// --- a block at a time --------------------------------------------------------------------
// bz_dec's walk cut at its blocks: the state is where in the input the next one starts and
// what the stream has said so far. a block that runs past what the caller holds is left
// unread for a longer try -- the caller holds more than any block can take
#define BZ_MAGIC 0x627a3273u
struct bz_st { uint64_t magic, bit; uint32_t mode, level, all, nstream; };
enum { BZ_MORE = 10, BZ_DONE = 11 };
static int bz_step(struct bz_st *S, struct bz_d *d, const uint8_t *s, uintptr_t n, int eof, struct bz_w *w) {
 uintptr_t at = S->bit / 8;
 if (!S->mode) {                                 // a stream's head, on a byte
  if (n - at < 4 && !eof) return BZ_MORE;
  if (n - at < 4 || s[at] != 'B' || s[at + 1] != 'Z' || s[at + 2] != 'h' || s[at + 3] < '1' || s[at + 3] > '9')
   return S->nstream ? BZ_DONE : n - at < 4 && !memcmp(s + at, "BZh", n - at < 3 ? n - at : 3) ? 3 : 1;
  S->level = s[at + 3] - '0', S->all = 0, S->mode = 1, S->bit = (at + 4) * 8;
  return 0; }
 struct bz_r r = { s, at, n, 0, 0 };
 if (S->bit % 8) br_get(&r, S->bit % 8);
 uint32_t m1 = br_get(&r, 24), m2 = br_get(&r, 24);
 int rc;
 if (br_used(&r) > n * 8) return eof ? 3 : BZ_MORE;
 if (m1 == 0x314159 && m2 == 0x265359) {
  uint32_t b;
  rc = bz_dblock(d, &r, S->level, w, &b);
  if (rc && br_used(&r) > n * 8) return eof ? 3 : BZ_MORE;
  if (rc) return rc < 0 ? (w->big ? 5 : -1) : rc;
  S->all = (S->all << 1 | S->all >> 31) ^ b, S->bit = br_used(&r);
  return 0; }
 if (m1 == 0x177245 && m2 == 0x385090) {
  uint32_t c = br_get(&r, 32);
  if (br_used(&r) > n * 8) return eof ? 3 : BZ_MORE;
  if (c != S->all) return 4;
  r.k -= r.k % 8;                                // the stream ends on a byte
  S->bit = br_used(&r), S->mode = 0, S->nstream++;
  return 0; }
 return 2; }

#ifndef BZ_STANDALONE
// ===== the nifs: str0 may collect, so a string is re-read off the stack after it =====
love_noinline static struct g *host_bz2e(struct g *g) {
 word sw = g->sp[0], lw = g->sp[1];
 if (!strp(sw) || !oddp(lw) || getcharm(lw) < 1 || getcharm(lw) > 9) {
  g->sp[1] = ZeroPoint, g->sp += 1; return g; }
 struct bz_w w = {0};
 int rc = bz_enc((const uint8_t*) txt(sw), len(sw), (unsigned) getcharm(lw), &w);
 if (!rc && ok(g = str0(g, w.n))) {           // pushes: out over the two
  memcpy(txt(g->sp[0]), w.p, w.n);
  g->sp[2] = g->sp[0], g->sp += 2; }
 else if (ok(g)) g->sp[1] = ZeroPoint, g->sp += 1;
 if (w.p) alloc(w.p, 0);
 return g; }

// every stream in s into exactly cap bytes of out, for a C caller with no g (src/love/lib/srctree.c)
// -> cap, or -1 for a stream that is torn or says more or less than that
intptr_t bz2_into(unsigned char const *s, uintptr_t n, unsigned char *out, uintptr_t cap) {
 struct bz_w w = { .p = out, .cap = cap, .fix = 1 };
 return bz_dec(s, n, &w) || w.n != cap ? -1 : (intptr_t) cap; }

love_noinline static struct g *host_bz2d(struct g *g) {
 word sw = g->sp[0];
 if (!strp(sw)) { g->sp[0] = ZeroPoint; return g; }
 struct bz_w w = {0};
 int rc = bz_dec((const uint8_t*) txt(sw), len(sw), &w);
 if (w.big) g->sp[0] = putcharm(5);
 else if (rc > 0) g->sp[0] = putcharm(rc);
 else if (rc < 0) g->sp[0] = ZeroPoint;
 else if (ok(g = str0(g, w.n))) {
  if (w.n) memcpy(txt(g->sp[0]), w.p, w.n);
  g->sp[1] = g->sp[0], g->sp++; }
 if (w.p) alloc(w.p, 0);
 return g; }

static struct str *bz_cask(word x) {
 struct str *s = cask_str(x);
 return s && s->len == sizeof(struct bz_st) && ((struct bz_st*) s->bytes)->magic == BZ_MAGIC ? s : NULL; }
love_noinline static struct g *host_bz2_new(struct g *g) {
 uintptr_t sreq = str_width(sizeof(struct bz_st)), breq = Width(struct cask) + Width(struct tag);
 if (!ok(g = have(g, sreq + breq))) return g;
 struct str *s = ini_str(bump(g, sreq), sizeof(struct bz_st));
 memset(s->bytes, 0, sizeof(struct bz_st));
 ((struct bz_st*) s->bytes)->magic = BZ_MAGIC;
 union u *k = bump(g, breq);
 cask(k)->ap = lvm_cask, cask(k)->str = s;
 tagthread(k, Width(struct cask));
 return g->sp[0] = word(k), g; }
love_noinline static struct g *host_bz2_step(struct g *g) {
 struct str *cs = bz_cask(g->sp[0]);
 if (!cs || !strp(g->sp[1])) return g->sp[2] = ZeroPoint, g->sp += 2, g;
 struct bz_st *S = (struct bz_st*) cs->bytes;
 struct bz_d *d = S->mode ? alloc(NULL, sizeof *d) : NULL;
 if (S->mode && !d) return g->sp[2] = ZeroPoint, g->sp += 2, g;
 if (d) bz_crcs(d->crct);
 struct bz_w w = {0};
 int rc = bz_step(S, d, (const uint8_t*) txt(g->sp[1]), len(g->sp[1]), oddp(g->sp[2]) && getcharm(g->sp[2]), &w);
 if (d) alloc(d, 0);
 if (rc) {
  if (w.p) alloc(w.p, 0);
  return g->sp[2] = rc == BZ_MORE ? putcharm(-1) : rc == BZ_DONE ? putcharm(0) : rc < 0 ? ZeroPoint : putcharm(rc),
         g->sp += 2, g; }
 uintptr_t k = S->bit / 8;                       // the bytes behind it, for the caller to drop
 S->bit -= 8 * k;
 if (!ok(g = have(g, str_width(w.n) + Width(struct chain)))) { if (w.p) alloc(w.p, 0); return g; }
 struct str *o = ini_str(bump(g, str_width(w.n)), w.n);
 if (w.n) memcpy(o->bytes, w.p, w.n);
 if (w.p) alloc(w.p, 0);
 struct chain *c = ini_chain(bump(g, Width(struct chain)), (intptr_t) o, putcharm((intptr_t) k));
 return g->sp[2] = word(c), g->sp += 2, g; }

static LvmWrap(lvm_bz2e, host_bz2e)
static LvmWrap(lvm_bz2d, host_bz2d)
static LvmWrap(lvm_bz2_new, host_bz2_new)
static LvmWrap(lvm_bz2_step, host_bz2_step)

LvDef("bz2e", bz2e, 2, "bz2");
LvDef("bz2d", bz2d, 1, "bz2");
LvDef("bz2-new", bz2_new, 1, "bz2");
LvDef("bz2-step", bz2_step, 3, "bz2");
#endif
