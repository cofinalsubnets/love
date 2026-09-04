// src/inflate.c -- the C twin of lib/gz.l's inflate, auto-globbed and AiNif-registered,
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
#include "love.h"
#include <stdint.h>
#include <string.h>

// RFC 1951 §3.2.5, and lib/gz.l's gz-lbase/gz-lext/gz-dbase/gz-dext say them again
static const uint16_t inf_lbase[29] = {
 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59,
 67, 83, 99, 115, 131, 163, 195, 227, 258 };
static const uint8_t inf_lext[29] = {
 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 };
static const uint16_t inf_dbase[30] = {
 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 };
static const uint8_t inf_dext[30] = {
 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 };
static const uint8_t inf_clord[19] = {
 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

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
   for (i = 0; i < hclen; i++) { unsigned v; TAKE(3, v); cl[inf_clord[i]] = (uint8_t) v; }
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
   l = inf_lbase[sy];
   if (inf_lext[sy]) { TAKE(inf_lext[sy], x); l += x; }
   SYM(t.dst, t.dtab, DROOT, sy);
   if (sy > 29) return -1;
   d = inf_dbase[sy];
   if (inf_dext[sy]) { TAKE(inf_dext[sy], x); d += x; }
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
 Pack(g); g = host_inflate(g);
 if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g);
 Unpack(g);
 ai_musttail return Next(1); }

static union u const nif_inflate[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_inflate}, {lvm_ret0}};
AiNif("inflate", nif_inflate);
