// src/gz.c -- DEFLATE, both directions. one translation unit because the two halves are
// one format: RFC 1951 §3.2.5's code tables are read by the coder and the decoder alike,
// and a coder and a decoder that disagree there disagree about the format. lib/gz.l's
// gz-lbase/gz-lext/gz-dbase/gz-dext say the same numbers in love.
#include "love.h"
#include <stdint.h>
#include <string.h>

static const uint16_t gz_lbase[29] = {
 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59,
 67, 83, 99, 115, 131, 163, 195, 227, 258 };
static const uint8_t gz_lext[29] = {
 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 };
static const uint16_t gz_dbase[30] = {
 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 };
static const uint8_t gz_dext[30] = {
 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 };
static const uint8_t gz_clord[19] = {
 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

// ===== inflate -- the C twin of lib/gz.l's inflate, AiNif-registered =====
// the tls.c discipline: (inflate s n) -> the bytes | (), s a raw DEFLATE stream and n its
// inflated size or 0. `gz-inflate` reaches for this and falls back to gz-puff.
// a twin, not a replacement: gz-puff stays the readable statement of RFC 1951 and the
// differential oracle (test/host/gzc.l holds the two to the same bytes over corpora and
// over torn and doctored streams). the algorithms differ on purpose -- gz-puff walks the
// canonical code a bit at a time, this reads a 64-bit window into a per-block table --
// so the two are held to the same bytes, never to the same shape.
// malformed streams answer alike too. gz-huff does not check that the code lengths
// describe a code, so an over-subscribed one decodes to nonsense there, and this
// reproduces that nonsense: the table is first-writer-wins, so a doubly-claimed slot
// answers the shortest code, and the zeroed symbol array reads 0 past its end, which is
// what `peep` answers. checking would be better engineering and a differential failure.
// the size argument is a hint and a bound -- nothing grows here, so the output is
// allocated once. a positive n is believed and verified; a wrong or absent one costs a
// counting pass first, which is the decode with the stores dropped.
// eight unaligned bytes as a word, little-endian by construction. not memcpy and not a
// cast: gcc folds this to one load, and mooncc emits shifts where memcpy would be a call
// -- 1.5x slower over the whole decode.
#define LD64(p) ((uint64_t) (p)[0]       | (uint64_t) (p)[1] <<  8 \
               | (uint64_t) (p)[2] << 16 | (uint64_t) (p)[3] << 24 \
               | (uint64_t) (p)[4] << 32 | (uint64_t) (p)[5] << 40 \
               | (uint64_t) (p)[6] << 48 | (uint64_t) (p)[7] << 56)

// the table roots. a code longer than its root falls through to the bit walk, so these
// only trade build cost against how often that happens: 12 bits leaves ~1% of symbols
// walking, and the fill is 2^root writes per block whatever the symbol count.
#define LROOT 12
#define DROOT 9
#define CROOT 7

// one canonical code: the counts and symbols the walk needs, and the table over them.
// an entry is (symbol << 4) | length, and 0 -- no code is 0 bits -- means "walk it".
struct inf_code { uint16_t cnt[16], sym[288], *tab; unsigned root; };

// one block's decode tables: the three canonical codes and the table each indexes.
// per-call scratch on inf_run's frame, 11 KB of it -- the tightest stack under that is
// the kernel's 64 KiB boot one, where kmain inflates the source blob into its initrd.
struct inf_tabs {
 uint16_t ltab[1 << LROOT], dtab[1 << DROOT], ctab[1 << CROOT];
 struct inf_code lit, dst, cl; };

static void inf_build(struct inf_code *c, const uint8_t *lens, unsigned nsym,
                      uint16_t *tab, unsigned root) {
 unsigned ofs[16], l, i, code = 0, idx = 0, size = 1u << root;
 memset(c->cnt, 0, sizeof c->cnt);
 memset(c->sym, 0, sizeof c->sym);
 memset(tab, 0, (size_t) size * sizeof *tab);
 for (i = 0; i < nsym; i++) c->cnt[lens[i]]++;
 c->cnt[0] = 0;                                  // a zero length is no code, not a code
 ofs[1] = 0;
 for (l = 1; l < 15; l++) ofs[l + 1] = ofs[l] + c->cnt[l];
 for (i = 0; i < nsym; i++) if (lens[i]) c->sym[ofs[lens[i]]++] = (uint16_t) i;
 c->tab = tab; c->root = root;
 for (l = 1; l < 16; l++) {                      // canonical order, shortest first
  for (i = 0; i < c->cnt[l]; i++, code++) {
   unsigned s = c->sym[idx++], rev = 0, b, j;
   if (l > root) continue;
   for (b = 0; b < l; b++) rev |= ((code >> b) & 1) << (l - 1 - b);   // the code, as read
   for (j = rev; j < size; j += 1u << l)
    if (!tab[j]) tab[j] = (uint16_t) ((s << 4) | l); }
  code <<= 1; } }

// the twin's own decode, for the codes the table does not hold. -1 where gz-dec answers ().
static int inf_walk(const struct inf_code *c, uint64_t bb, unsigned *used) {
 int code = 0, first = 0, index = 0, cnt;
 unsigned l;
 for (l = 1; l < 16; l++) {
  code |= (int) ((bb >> (l - 1)) & 1);
  cnt = c->cnt[l];
  if (code - cnt < first) { *used = l; return c->sym[index + (code - first)]; }
  index += cnt; first = (first + cnt) << 1; code <<= 1; }
 return -1; }

// -1 where the twin answers (), -2 where the output outruns cap. out may be NULL, and
// then nothing is stored and the answer is only how long the stream inflates to --
// which is exact, because nothing the buffer holds ever reaches a branch.
static int64_t inf_run(const uint8_t *in, uintptr_t n, uint8_t *out, uintptr_t cap) {
 uintptr_t ip = 0, op = 0;
 uint64_t bb = 0;
 unsigned bc = 0, last, typ, i;
 uint8_t lens[320];
 struct inf_tabs t;

// one unaligned load where there is room. the byte loop below is the same act and
// eight times the work; the arithmetic is libdeflate's -- absorb what fits, step by the
// bytes that wholly landed, and round the count up to 56 or 63. what spilled off the top
// belongs to a byte `ip` has not passed, so it is read again and not lost.
#define FILL() do { \
   if (ip + 8 <= n) { bb |= LD64(in + ip) << bc; ip += 7 - (bc >> 3); bc |= 56; } \
   else while (bc <= 56 && ip < n) { bb |= (uint64_t) in[ip++] << bc; bc += 8; } } while (0)
#define TAKE(k, v) do { unsigned k_ = (k); \
   if (bc < k_) { FILL(); if (bc < k_) return -1; } \
   (v) = (unsigned) (bb & ((1u << k_) - 1)); bb >>= k_; bc -= k_; } while (0)
// a symbol off `c`: the table where it reaches, the walk where it does not
#define SYM(c, t, root, sy) do { unsigned u_; uint16_t e_; \
   FILL(); e_ = (t)[bb & ((1u << (root)) - 1)]; \
   if (e_) { (sy) = e_ >> 4; u_ = e_ & 15; } \
   else { int w_ = inf_walk(&(c), bb, &u_); if (w_ < 0) return -1; (sy) = (unsigned) w_; } \
   if (bc < u_) return -1; \
   bb >>= u_; bc -= u_; } while (0)

 do {
  TAKE(1, last); TAKE(2, typ);
  if (typ == 0) {                                // stored: to the byte, then raw
   uintptr_t pos;
   unsigned ln, nl, drop = bc & 7;
   bb >>= drop; bc -= drop;
   pos = ip - (bc >> 3);                         // what is buffered is whole bytes now
   if (pos + 4 > n) return -1;
   ln = in[pos] | ((unsigned) in[pos + 1] << 8);
   nl = in[pos + 2] | ((unsigned) in[pos + 3] << 8);
   if (((ln ^ 0xffff) & 0xffff) != nl || pos + 4 + ln > n) return -1;
   if (op + ln > cap) return -2;
   if (out) memcpy(out + op, in + pos + 4, ln);
   op += ln; ip = pos + 4 + ln; bb = 0; bc = 0;
   continue; }
  if (typ == 3) return -1;

  if (typ == 1) {                                // the fixed code, RFC 1951 §3.2.6
   for (i = 0; i < 288; i++) lens[i] = i < 144 ? 8 : i < 256 ? 9 : i < 280 ? 7 : 8;
   inf_build(&t.lit, lens, 288, t.ltab, LROOT);
   for (i = 0; i < 30; i++) lens[i] = 5;
   inf_build(&t.dst, lens, 30, t.dtab, DROOT); }
  else {                                         // the block's own, read through a third
   unsigned hlit, hdist, hclen, tot, prev = 0;
   uint8_t cl[19];
   TAKE(5, hlit); TAKE(5, hdist); TAKE(4, hclen);
   hlit += 257; hdist += 1; hclen += 4;
   memset(cl, 0, sizeof cl);
   for (i = 0; i < hclen; i++) { unsigned v; TAKE(3, v); cl[gz_clord[i]] = (uint8_t) v; }
   inf_build(&t.cl, cl, 19, t.ctab, CROOT);
   memset(lens, 0, sizeof lens);
   tot = hlit + hdist;
   // a run may overshoot `tot` and the twin lets it: it writes into a tablet, which has
   // no end, and stops on the next look. so the write is clamped and the cursor is not.
   for (i = 0; i < tot; ) {
    unsigned sy, r, v, k;
    SYM(t.cl, t.ctab, CROOT, sy);
    if (sy < 16)       { r = 1; v = sy; }
    else if (sy == 16) { TAKE(2, r); r += 3; v = prev; }
    else if (sy == 17) { TAKE(3, r); r += 3; v = 0; }
    else if (sy == 18) { TAKE(7, r); r += 11; v = 0; }
    else return -1;
    for (k = 0; k < r; k++) if (i + k < sizeof lens) lens[i + k] = (uint8_t) v;
    i += r; prev = v; }
   inf_build(&t.lit, lens, hlit, t.ltab, LROOT);
   inf_build(&t.dst, lens + hlit, hdist, t.dtab, DROOT); }

  for (;;) {                                     // the symbol loop, fixed or dynamic
   unsigned sy, l, d, x;
   SYM(t.lit, t.ltab, LROOT, sy);
   if (sy < 256) {
    if (op >= cap) return -2;
    if (out) out[op] = (uint8_t) sy;
    op++; continue; }
   if (sy == 256) break;
   if (sy > 285) return -1;
   sy -= 257;
   l = gz_lbase[sy];
   if (gz_lext[sy]) { TAKE(gz_lext[sy], x); l += x; }
   SYM(t.dst, t.dtab, DROOT, sy);
   if (sy > 29) return -1;
   d = gz_dbase[sy];
   if (gz_dext[sy]) { TAKE(gz_dext[sy], x); d += x; }
   if (d > op) return -1;                        // a reach before the start
   if (op + l > cap) return -2;
   if (out) {
    // eight in order, and that is not a word move. deflate lets a run overlap its own
    // source -- dist 1 len 100 is a hundred of one byte -- and written out in sequence
    // these read each byte back as they go, so they are the byte loop with its counter
    // gone and are right at every distance, no guard to get wrong. a real word move,
    // guarded at eight, was measured and is slower in both lanes (gcc 22 ms against 20,
    // mooncc 39 against 37): mean match here is 8.5 bytes, one word and a tail, and the
    // branch to choose costs what the wide store saves. the plain loop is slower again
    // (mooncc 42), which is the counter and nothing else.
    uint8_t *dp = out + op, *sp = dp - d;
    unsigned k = 0;
    for (; k + 8 <= l; k += 8) {
     dp[k]     = sp[k];     dp[k + 1] = sp[k + 1]; dp[k + 2] = sp[k + 2];
     dp[k + 3] = sp[k + 3]; dp[k + 4] = sp[k + 4]; dp[k + 5] = sp[k + 5];
     dp[k + 6] = sp[k + 6]; dp[k + 7] = sp[k + 7]; }
    for (; k < l; k++) dp[k] = sp[k]; }
   op += l; }
 } while (!last);
 return (int64_t) op;
#undef FILL
#undef TAKE
#undef SYM
}

// str0 collects, so the stream is re-read off the stack after it: a C local's pointer
// into the heap is stale across the bump. tls.c pays the same toll.
// the raw-DEFLATE door for C callers with no g: src/kmain.c inflates the
// source blob into its initrd through this. same law as inf_run, exported.
intptr_t ai_inflate_raw(const unsigned char *in, uintptr_t n, unsigned char *out, uintptr_t cap) {
 return (intptr_t) inf_run(in, n, out, cap); }

ai_noinline static struct ai *host_inflate(struct ai *g) {
 ai_word sw = g->sp[0], nw = g->sp[1];
 intptr_t hint;
 int64_t want;
 int guessed;
 if (!strp(sw) || !oddp(nw)) { g->sp[1] = ZeroPoint, g->sp += 1; return g; }
 hint = getcharm(nw);
 guessed = hint > 0;
 want = guessed ? (int64_t) hint
                : inf_run((const uint8_t*) txt(sw), len(sw), 0, (uintptr_t) -1);
 for (;;) {
  if (want < 0) break;
  if (!ai_ok(g = str0(g, (uintptr_t) want))) return g;
  if (!want) { g->sp[2] = g->sp[0], g->sp += 2; return g; }   // the counting pass read it
  { ai_word s2 = g->sp[1];
    int64_t got = inf_run((const uint8_t*) txt(s2), len(s2),
                          (uint8_t*) txt(g->sp[0]), (uintptr_t) want);
    if (got == want) { g->sp[2] = g->sp[0], g->sp += 2; return g; } }
  g->sp += 1;                                    // the wrong-sized string, dropped
  if (!guessed) break;
  guessed = 0;                                   // the hint lied: count, then once more
  want = inf_run((const uint8_t*) txt(g->sp[0]), len(g->sp[0]), 0, (uintptr_t) -1); }
 g->sp[1] = ZeroPoint, g->sp += 1;
 return g; }

static lvm(lvm_inflate) {
 LvmCall(g, host_inflate) }

static union u const nif_inflate[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_inflate}, {lvm_ret0}};
AiNif("inflate", nif_inflate);

// ===== deflate -- the C twin of lib/gz.l's DEFLATE coder, AiNif-registered =====
// the same discipline as inflate above: (deflate s) -> the raw stream | ().
// a twin held to the bytes: same greedy parse (chain 32, min match 3, the far-3
// refusal at 4096), same 16384-symbol blocks each costed stored/fixed/dynamic, same
// two-queue Huffman merge with its leaf-wins tie, same halving walk back under the
// depth limit -- so `cmp` over any input is the differential. gz-deflate stays the
// readable statement; test/host/gzc.l holds the two to the same bytes.
// why it exists: the love coder is 35x-to-13x off C, but its real cost is the heap.
// interpreted DEFLATE churns cells per symbol, and on the love0 egg that runs selfpack
// the heap grows toward the budget before a collection pays. this is a fixed window
// and some tables.
// scratch is not the heap: the off semispace where it is big enough (the major pool's
// spare half is dead between collections), one g->alloc block where it is not. the
// shape is inflate's counting pass twice over -- count, str0 the exact answer,
// re-derive and emit -- because str0 may collect and a collection flips that half.
#define DF_WSIZE 32768u
#define DF_WMASK 32767u
#define DF_HMASK 32767u
#define DF_CHAIN 32
#define DF_TOKMAX 16384u
#define DF_TOOFAR 4096u

// the bit sink: LSB-first bytes, codes handed in already reversed (gz-put's law).
// with no out it counts, which is the whole first pass.
struct df_sink { uint8_t *out; uintptr_t op, cap; uint64_t acc; unsigned nb; int err; };

static void df_put(struct df_sink *t, uint32_t v, unsigned k) {
 t->acc |= (uint64_t) (v & ((1u << k) - 1)) << t->nb;
 t->nb += k;
 while (t->nb >= 8) {
  if (t->out) { if (t->op >= t->cap) { t->err = 1; return; } t->out[t->op] = (uint8_t) (t->acc & 255); }
  t->op++; t->acc >>= 8; t->nb -= 8; } }

static void df_align(struct df_sink *t) {
 if (!t->nb) return;
 if (t->out) { if (t->op >= t->cap) { t->err = 1; return; } t->out[t->op] = (uint8_t) (t->acc & 255); }
 t->op++; t->acc = 0; t->nb = 0; }

static uint32_t df_rev(uint32_t v, unsigned k) {
 uint32_t a = 0; unsigned i;
 for (i = 0; i < k; i++) { a = (a << 1) | (v & 1); v >>= 1; }
 return a; }

// the ladders are short and walked from the top (gz-lcode/gz-dcode)
static unsigned df_lcode(unsigned v) { for (unsigned i = 28; i >= 1; i--) if (gz_lbase[i] <= v) return i; return 0; }
static unsigned df_dcode(unsigned v) { for (unsigned i = 29; i >= 1; i--) if (gz_dbase[i] <= v) return i; return 0; }

// --- the Huffman lengths: sorted leaves + the internal queue, ties to the leaf,
// --- and the halving walk when the code outgrows the format (gz-hpass exactly).
// scratch rows are the caller's; pa is zeroed here because depth chases it to 0.
static unsigned df_hlens(uint32_t *f, unsigned nsym, unsigned lim, uint8_t *lens,
                         uint32_t *hc, uint32_t *keys, uint32_t *w, uint32_t *sy, uint32_t *pa) {
 unsigned i, u = 0, pass;
 for (i = 0; i < nsym; i++) hc[i] = f[i];
 for (i = 0; i < nsym; i++) if (hc[i]) u++;
 if (u < 2) { if (!hc[0]) hc[0] = 1; if (!hc[1]) hc[1] = 1; }   // a code needs two symbols
 for (pass = 0;; pass++) {
  unsigned nl = 0, top, li, ii, mx = 0;
  for (i = 0; i < nsym; i++) if (hc[i]) keys[nl++] = (hc[i] << 9) + i;
  unsigned a; for (a = 1; a < nl; a++) {                      // counts ride their symbol; ties to
   uint32_t v = keys[a]; unsigned b = a;                      // the lower symbol, sort ascending
   while (b && keys[b - 1] > v) { keys[b] = keys[b - 1]; b--; }
   keys[b] = v; }
  for (i = 0; i < nl; i++) { w[i] = keys[i] >> 9; sy[i] = keys[i] & 511; }
  memset(pa, 0, (2 * nl - 1) * sizeof *pa);
  li = 0; ii = nl;
  for (top = nl; top + 1 <= 2 * nl - 1; top++) {
   unsigned a, b;
#define DF_PICK(L, I) ((L) < nl && ((I) >= top || w[L] <= w[I]))
   if (DF_PICK(li, ii)) a = li++; else a = ii++;
   if (DF_PICK(li, ii)) b = li++; else b = ii++;
#undef DF_PICK
   w[top] = w[a] + w[b]; pa[a] = top + 1; pa[b] = top + 1; }
  memset(lens, 0, nsym);
  for (i = 0; i < nl; i++) {
   unsigned d = 0, p = pa[i];
   while (p) { d++; p = pa[p - 1]; }
   lens[sy[i]] = (uint8_t) d;
   if (d > mx) mx = d; }
  if (mx <= lim || pass >= 32) return mx;
  for (i = 0; i < nsym; i++) if (hc[i]) { uint32_t h = hc[i] >> 1; hc[i] = h ? h : 1; } } }

// canonical, shortest first, ties by symbol, stored reversed (gz-hcodes)
static void df_hcodes(const uint8_t *lens, unsigned nsym, unsigned mx, uint32_t *code) {
 uint32_t cnt[16], nxt[16], c = 0;
 unsigned i, l;
 memset(cnt, 0, sizeof cnt);
 for (i = 0; i < nsym; i++) if (lens[i]) cnt[lens[i]]++;
 for (l = 1; l <= mx && l < 16; l++) { nxt[l] = c; c = (c + cnt[l]) << 1; }
 for (i = 0; i < nsym; i++) if (lens[i]) { code[i] = df_rev(nxt[lens[i]], lens[i]); nxt[lens[i]]++; } }

// the code lengths, run-length coded: a value once before 16 may repeat it,
// 17 and 18 the zero runs (gz-run); an entry is (sym << 7) + extra.
static unsigned df_run(const uint8_t *cl, unsigned tot, uint32_t *rl) {
 unsigned i = 0, j = 0;
 while (i < tot) {
  unsigned v = cl[i], r = 1;
  while (i + r < tot && cl[i + r] == v) r++;
  if (v) {
   rl[j++] = ((uint32_t) v << 7); i++; r--;
   while (r >= 3) { unsigned t = r > 6 ? 6 : r; rl[j++] = (16u << 7) + (t - 3); i += t; r -= t; }
   while (r) { rl[j++] = ((uint32_t) v << 7); i++; r--; } }
  else {
   while (r >= 11) { unsigned t = r > 138 ? 138 : r; rl[j++] = (18u << 7) + (t - 11); i += t; r -= t; }
   if (r >= 3) { rl[j++] = (17u << 7) + (r - 3); i += r; r = 0; }
   while (r) { rl[j++] = (0u << 7); i++; r--; } } }
 return j; }

static unsigned df_clx(unsigned sy) {
 return sy == 16 ? 2 : sy == 17 ? 3 : sy == 18 ? 7 : 0; }

// what a block would cost, in bits (gz-cost / gz-ccost)
static uint64_t df_cost(const uint32_t *f, const uint8_t *lens, unsigned nsym) {
 uint64_t a = 0; unsigned i;
 for (i = 0; i < nsym; i++) a += (uint64_t) f[i] * lens[i];
 return a; }
static uint64_t df_ccost(const uint32_t *rl, const uint8_t *lenc, unsigned nr) {
 uint64_t a = 0; unsigned i;
 for (i = 0; i < nr; i++) { unsigned sy = rl[i] >> 7; a += lenc[sy] + df_clx(sy); }
 return a; }

static void df_wtoks(struct df_sink *t, const uint32_t *tok, unsigned k,
                     const uint32_t *codl, const uint8_t *lenl,
                     const uint32_t *codd, const uint8_t *lend) {
 unsigned i;
 for (i = 0; i < k; i++) {
  uint32_t v = tok[i];
  if (v < 256) { df_put(t, codl[v], lenl[v]); continue; }
  uint32_t u = v - 256;
  unsigned lc = u >> 23, dc = (u >> 18) & 31;
  df_put(t, codl[257 + lc], lenl[257 + lc]);
  if (gz_lext[lc]) df_put(t, (u >> 13) & 31, gz_lext[lc]);
  df_put(t, codd[dc], lend[dc]);
  if (gz_dext[dc]) df_put(t, u & 8191, gz_dext[dc]); }
 df_put(t, codl[256], lenl[256]); }                             // 256 ends the block

static void df_wstored(struct df_sink *t, const uint8_t *s, uintptr_t i0, uintptr_t i1, int last) {
 uintptr_t len = i1 - i0, k;
 df_put(t, last ? 1 : 0, 1); df_put(t, 0, 2);
 df_align(t);                                                   // a stored block starts at a byte
 df_put(t, (uint32_t) (len & 255), 8);          df_put(t, (uint32_t) ((len >> 8) & 255), 8);
 df_put(t, (uint32_t) ((len ^ 65535) & 255), 8); df_put(t, (uint32_t) (((len ^ 65535) >> 8) & 255), 8);
 for (k = 0; k < len; k++) df_put(t, s[i0 + k], 8); }

// the arena, carved once: the finder's two windows outlive every block, the rest
// is per block or per code and merely reused.
struct df_ar {
 uint32_t *head, *prev, *tok, *fl, *fd,
          *hc, *keys, *w, *sy, *pa, *rlb, *fc,
          *codl, *codd, *codc, *fixcl, *fixcd;
 uint8_t *lenl, *lend, *lenc, *fixll, *fixld, *cl; };
#define DF_ARENA (384u << 10)
static void df_carve(uint8_t *m, struct df_ar *a) {
 uint8_t *p = m;
#define DF_TAKE(f, n, ty) a->f = (ty*) p; p += ((n) * sizeof(ty) + 7u) & ~7u
 DF_TAKE(head, 32768, uint32_t); DF_TAKE(prev, 32768, uint32_t);
 DF_TAKE(tok, DF_TOKMAX, uint32_t); DF_TAKE(fl, 286, uint32_t); DF_TAKE(fd, 30, uint32_t);
 DF_TAKE(hc, 286, uint32_t); DF_TAKE(keys, 286, uint32_t);
 DF_TAKE(w, 571, uint32_t); DF_TAKE(sy, 571, uint32_t); DF_TAKE(pa, 571, uint32_t);
 DF_TAKE(rlb, 320, uint32_t); DF_TAKE(fc, 19, uint32_t);
 DF_TAKE(codl, 286, uint32_t); DF_TAKE(codd, 30, uint32_t); DF_TAKE(codc, 19, uint32_t);
 DF_TAKE(fixcl, 288, uint32_t); DF_TAKE(fixcd, 30, uint32_t);
 DF_TAKE(lenl, 286, uint8_t); DF_TAKE(lend, 30, uint8_t); DF_TAKE(lenc, 19, uint8_t);
 DF_TAKE(fixll, 288, uint8_t); DF_TAKE(fixld, 30, uint8_t); DF_TAKE(cl, 316, uint8_t); }

#define DF_HASH(s, i) (((((uint32_t) (s)[i] << 10) ^ ((uint32_t) (s)[(i) + 1] << 5)) ^ (s)[(i) + 2]) & DF_HMASK)
static void df_ins(const uint8_t *s, uintptr_t n, uintptr_t i, uint32_t *head, uint32_t *prev) {
 if (i + 2 < n) {
  uint32_t h = DF_HASH(s, i);
  prev[i & DF_WMASK] = head[h];
  head[h] = (uint32_t) i + 1; } }

// gz-find: down the chain, nearest wins a tie, a full-limit match taken at once
static void df_find(const uint8_t *s, uintptr_t n, uintptr_t i, const uint32_t *head,
                    const uint32_t *prev, unsigned *rl, unsigned *rd) {
 unsigned lim = (n - i) < 258 ? (unsigned) (n - i) : 258;
 uint32_t k = head[DF_HASH(s, i)];
 int d = DF_CHAIN;
 unsigned bl = 0, bd = 0;
 while (k && d) {
  uintptr_t p = k - 1, dist = i - p;
  unsigned l = 0;
  if (dist > DF_WSIZE) break;
  while (l < lim && s[i + l] == s[p + l]) l++;
  k = prev[p & DF_WMASK]; d--;
  if (l > bl) {
   if (l >= lim) { *rl = l; *rd = (unsigned) dist; return; }
   bl = l; bd = (unsigned) dist; } }
 *rl = bl; *rd = bd; }

// one block: tokenize (gz-tok), then the three spellings costed and the cheapest
// written (gz-flush). the dynamic code wins its tie with the fixed one.
static uintptr_t df_block(const uint8_t *s, uintptr_t n, uintptr_t i, struct df_sink *t, struct df_ar *a) {
 unsigned k = 0;
 uint64_t xb = 0;
 uintptr_t i0 = i;
 int last;
 memset(a->fl, 0, 286 * sizeof *a->fl);
 memset(a->fd, 0, 30 * sizeof *a->fd);
 while (i < n && k < DF_TOKMAX) {
  unsigned l = 0, d = 0;
  if (i + 3 <= n) df_find(s, n, i, a->head, a->prev, &l, &d);
  if (l == 3 && d > DF_TOOFAR) l = 0;                           // a far three is a loss
  if (l < 3) {
   unsigned c = s[i];
   a->tok[k++] = c; a->fl[c]++;
   df_ins(s, n, i, a->head, a->prev); i++; }
  else {
   unsigned lc = df_lcode(l), dc = df_dcode(d), q;
   a->tok[k++] = 256u + ((uint32_t) lc << 23) + ((uint32_t) dc << 18)
               + ((uint32_t) (l - gz_lbase[lc]) << 13) + (d - gz_dbase[dc]);
   a->fl[257 + lc]++; a->fd[dc]++;
   xb += gz_lext[lc] + gz_dext[dc];
   for (q = 0; q < l; q++) df_ins(s, n, i + q, a->head, a->prev);
   i += l; } }
 last = n <= i;
 a->fl[256]++;                                                  // end-of-block, always sent
 unsigned mxl = df_hlens(a->fl, 286, 15, a->lenl, a->hc, a->keys, a->w, a->sy, a->pa),
          mxd = df_hlens(a->fd, 30, 15, a->lend, a->hc, a->keys, a->w, a->sy, a->pa),
          hlit, hdist, hclen, nr, j2, mxc;
 uint64_t dyn, fix, raw;

 for (hlit = 286; hlit > 257 && !a->lenl[hlit - 1]; hlit--) ;
 for (hdist = 30; hdist > 1 && !a->lend[hdist - 1]; hdist--) ;
 memcpy(a->cl, a->lenl, hlit); memcpy(a->cl + hlit, a->lend, hdist);
 nr = df_run(a->cl, hlit + hdist, a->rlb);
 memset(a->fc, 0, 19 * sizeof *a->fc);
 for (j2 = 0; j2 < nr; j2++) a->fc[a->rlb[j2] >> 7]++;
 mxc = df_hlens(a->fc, 19, 7, a->lenc, a->hc, a->keys, a->w, a->sy, a->pa);
 for (hclen = 19; hclen > 4 && !a->lenc[gz_clord[hclen - 1]]; hclen--) ;
 dyn = 17 + hclen * 3 + df_ccost(a->rlb, a->lenc, nr)
     + df_cost(a->fl, a->lenl, 286) + df_cost(a->fd, a->lend, 30) + xb;
 fix = 3 + df_cost(a->fl, a->fixll, 286) + df_cost(a->fd, a->fixld, 30) + xb;
 raw = (i - i0) < 65536 ? 42 + (uint64_t) (i - i0) * 8 : dyn + fix;   // no stored spelling past len
 if (raw < (dyn <= fix ? dyn : fix)) df_wstored(t, s, i0, i, last);
 else if (fix < dyn) {
  df_put(t, last ? 1 : 0, 1); df_put(t, 1, 2);
  df_wtoks(t, a->tok, k, a->fixcl, a->fixll, a->fixcd, a->fixld); }
 else {
  df_hcodes(a->lenl, 286, mxl, a->codl);
  df_hcodes(a->lend, 30, mxd, a->codd);
  df_hcodes(a->lenc, 19, mxc, a->codc);
  df_put(t, last ? 1 : 0, 1); df_put(t, 2, 2);
  df_put(t, hlit - 257, 5); df_put(t, hdist - 1, 5); df_put(t, hclen - 4, 4);
  for (j2 = 0; j2 < hclen; j2++) df_put(t, a->lenc[gz_clord[j2]], 3);
  for (j2 = 0; j2 < nr; j2++) {
   uint32_t v = a->rlb[j2]; unsigned sy = v >> 7;
   df_put(t, a->codc[sy], a->lenc[sy]);
   if (df_clx(sy)) df_put(t, v & 127, df_clx(sy)); }
  df_wtoks(t, a->tok, k, a->codl, a->lenl, a->codd, a->lend); }
 return i; }

static int64_t df_go(const uint8_t *s, uintptr_t n, uint8_t *out, uintptr_t cap, uint8_t *m) {
 struct df_ar a;
 struct df_sink t;
 uintptr_t i = 0;
 unsigned j;
 df_carve(m, &a);
 memset(a.head, 0, 32768 * sizeof *a.head);
 memset(a.prev, 0, 32768 * sizeof *a.prev);
 for (j = 0; j < 288; j++) a.fixll[j] = j < 144 ? 8 : j < 256 ? 9 : j < 280 ? 7 : 8;
 for (j = 0; j < 30; j++) a.fixld[j] = 5;
 df_hcodes(a.fixll, 288, 9, a.fixcl);
 df_hcodes(a.fixld, 30, 5, a.fixcd);
 t.out = out; t.op = 0; t.cap = cap; t.acc = 0; t.nb = 0; t.err = 0;
 do i = df_block(s, n, i, &t, &a); while (i < n && !t.err);
 df_align(&t);
 return t.err ? -2 : (int64_t) t.op; }

// str0 collects, so both the source and the spare half are re-derived after it:
// a pointer held across the bump is stale, and a major collection flips the halves.
static uint8_t *df_arena(struct ai *g, int *alloced) {
 *alloced = 0;
 if (g->major_pool && g->major_len * sizeof(ai_word) >= DF_ARENA)
  return (uint8_t*) ((g->major_base == g->major_pool) ? g->major_pool + g->major_len : g->major_pool);
 void *p = g->alloc(g, NULL, DF_ARENA);
 if (p) *alloced = 1;
 return (uint8_t*) p; }

// the image lane: deflate raw bytes into the caller's buffer, one pass, no love stack.
// its arena is always its own -- df_arena may hand back the major pool's spare half, and
// a dump is walking a compacted heap that owns it.
intptr_t ai_deflate_raw(struct ai *g, unsigned char const *in, uintptr_t n,
                        unsigned char *out, uintptr_t cap) {
 uint8_t *m = g->alloc(g, NULL, DF_ARENA);
 int64_t got;
 if (!m) return -1;
 got = df_go(in, n, out, cap, m);
 g->alloc(g, m, 0);
 return (intptr_t) got; }

ai_noinline static struct ai *host_deflate(struct ai *g) {
 ai_word sw = g->sp[0];
 uint8_t *m;
 int alloced;
 int64_t want, got;
 if (!strp(sw)) { g->sp[0] = ZeroPoint; return g; }
 m = df_arena(g, &alloced);
 if (!m) { g->sp[0] = ZeroPoint; return g; }
 want = df_go((const uint8_t*) txt(sw), len(sw), 0, (uintptr_t) -1, m);
 if (alloced) g->alloc(g, m, 0);
 if (want < 0) { g->sp[0] = ZeroPoint; return g; }
 if (!ai_ok(g = str0(g, (uintptr_t) want))) return g;
 m = df_arena(g, &alloced);
 if (!m) { g->sp[1] = ZeroPoint, g->sp += 1; return g; }
 got = df_go((const uint8_t*) txt(g->sp[1]), len(g->sp[1]),
             (uint8_t*) txt(g->sp[0]), (uintptr_t) want, m);
 if (alloced) g->alloc(g, m, 0);
 g->sp[1] = got != want ? ZeroPoint : g->sp[0];
 return g->sp++, g; }

static LvmWrap(lvm_deflate, host_deflate)

// one operand, so the run is {impl, ret0} -- src/nifs.l states the law and lvm_cur
// curries once unconditionally, which at arity one hands the body an operand too many.
static union u const nif_deflate[] = {{lvm_deflate}, {lvm_ret0}};
AiNif("deflate", nif_deflate);
