// src/love/lib/gz.c -- DEFLATE, both directions. one translation unit because the two halves are
// one format: RFC 1951 §3.2.5's code tables are read by the coder and the decoder alike,
// and a coder and a decoder that disagree there disagree about the format. src/apps/gz.l's
// gz-lbase/gz-lext/gz-dbase/gz-dext say the same numbers in love.
#include "love.h"
#include "bytes.h"
#include "inf.h"
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

// ===== inflate -- the C twin of src/apps/gz.l's inflate, LvNif-registered =====
// the tls.c discipline: (inflate s n) -> the bytes | () | 1 past INF_MAX, s a raw DEFLATE
// stream and n its inflated size or 0. `gz-inflate` reaches for this and falls back to gz-puff.
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
// eight unaligned bytes as a word, little-endian by construction, once per symbol --
// bytes.h's ld64 where the machine takes one load, the byte gather where it does not.
#if wideld
#define LD64(p) ld64(p)
#else
#define LD64(p) ld64le(p)
#endif

// the table roots. a code longer than its root falls through to the bit walk, so these
// only trade build cost against how often that happens: 12 bits leaves ~1% of symbols
// walking, and the fill is 2^root writes per block whatever the symbol count.
#define LROOT 12
#define DROOT 9
#define CROOT 7

// one block's decode tables: the three canonical codes and the table each indexes.
// per-call scratch on inf_run's frame, 10 KB of it -- the tightest stack under that is
// the kernel's 64 KiB boot one, where kmain inflates the source blob into its initrd.
struct inf_tabs {
 uint16_t ltab[1 << LROOT], dtab[1 << DROOT], ctab[1 << CROOT], lsym[288], dsym[32], csym[19];
 struct inf_code lit, dst, cl;
 const uint8_t *dic; uintptr_t nd; };            // the preset dictionary behind the output, nd 0 for none

// inf_run's fast lane. a literal is 15 bits at most, so the buffer is topped only when it
// holds fewer, and a length, before it is taken, to the 48 a whole pair may take: one wide
// load then serves several literals. the load wants eight bytes on; while 266 bytes of room
// remain a match never nears cap, so the copy moves whole words and lets the last run over
// into room a later byte takes. a code past its table's root leaves the lane untaken, the
// distance's looked at before its length goes, so the loop makes no call and mooncc keeps
// its state in registers. 1 at the block's end, 0 short of margin or table, -1 malformed.
static int inf_fast_run(const uint8_t *in, uintptr_t n, uintptr_t *ipp, uint64_t *bbp,
                        unsigned *bcp, uint8_t *out, uintptr_t *opp, uintptr_t cap,
                        struct inf_tabs *t) {
 const uint8_t *ie = in + n - 8, *ip = in + *ipp;
 uint8_t *op = out + *opp, *oe = out + cap - 266;
 const uint16_t *lt = t->ltab, *dt = t->dtab;
 uint64_t bb = *bbp;                            // word-wide throughout: a narrow one is
 uintptr_t bc = *bcp, e, f, sy, x, l, d;        // a zero-extend after every step
 int r = 0;
 while (op <= oe) {
  if (bc < 15) {
   if (ip > ie) break;
   bb |= LD64(ip) << bc, ip += 7 - (bc >> 3), bc |= 56; }
  if (!(e = lt[bb & ((1u << LROOT) - 1)])) break;
  sy = e >> 4;
  if (sy < 256) { bb >>= e & 15, bc -= e & 15, *op++ = (uint8_t) sy; continue; }
  if (sy == 256) { bb >>= e & 15, bc -= e & 15, r = 1; break; }
  if (sy > 285) { r = -1; break; }
  if (bc < 48) {                                // the pair, still unread, to top up for
   if (ip > ie) break;
   bb |= LD64(ip) << bc, ip += 7 - (bc >> 3), bc |= 56; }
  x = gz_lext[sy - 257];
  if (!(f = dt[(bb >> ((e & 15) + x)) & ((1u << DROOT) - 1)])) break;
  bb >>= e & 15, bc -= e & 15;
  l = gz_lbase[sy - 257] + (uintptr_t) (bb & (((uint64_t) 1 << x) - 1)), bb >>= x, bc -= x;
  bb >>= f & 15, bc -= f & 15, sy = f >> 4;
  if (sy > 29) { r = -1; break; }
  x = gz_dext[sy];
  d = gz_dbase[sy] + (uintptr_t) (bb & (((uint64_t) 1 << x) - 1)), bb >>= x, bc -= x;
  if (d > (uintptr_t) (op - out)) {             // a reach before the start: the dictionary's, or none
   uintptr_t o = (uintptr_t) (op - out), h = d - o < l ? d - o : l, k;
   if (d > o + t->nd) { r = -1; break; }
   memcpy(op, t->dic + t->nd - (d - o), h);
   for (k = h; k < l; k++) op[k] = op[k - d];
   op += l; continue; }
  { uint8_t *dp = op, *sp = op - d, *de = op + l;
#if wideld
    if (d >= 8) for (; dp < de; dp += 8, sp += 8) st64(dp, ld64(sp));
    else if (d == 1) { uint64_t v = 0x0101010101010101ull * *sp;   // a run of one byte
     for (; dp < de; dp += 8) st64(dp, v); }
    else
#endif
    for (; dp < de; dp++, sp++) *dp = *sp; }
  op += l; }
 *ipp = (uintptr_t) (ip - in), *opp = (uintptr_t) (op - out), *bbp = bb, *bcp = (unsigned) bc;
 return r; }

// -1 where the twin answers (), -2 where the output outruns cap. out may be NULL, and
// then nothing is stored and the answer is only how long the stream inflates to --
// which is exact, because nothing the buffer holds ever reaches a branch.
// dic is the nd bytes that come before the output, a preset dictionary (nd 0 for none)
static int64_t inf_rund(const uint8_t *in, uintptr_t n, uint8_t *out, uintptr_t cap,
                        const uint8_t *dic, uintptr_t nd) {
 uintptr_t ip = 0, op = 0;
 uint64_t bb = 0;
 unsigned bc = 0, last, typ, i;
 uint8_t lens[320];
 struct inf_tabs t;
 t.dic = dic, t.nd = nd;

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
   else { int w_ = inf_walk(&(c), bb); if (w_ < 0) return -1; (sy) = (unsigned) w_ >> 4; u_ = w_ & 15; } \
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
   inf_build(&t.lit, lens, 288, t.lsym, t.ltab, LROOT);
   for (i = 0; i < 30; i++) lens[i] = 5;
   inf_build(&t.dst, lens, 30, t.dsym, t.dtab, DROOT); }
  else {                                         // the block's own, read through a third
   unsigned hlit, hdist, hclen, tot, prev = 0;
   uint8_t cl[19];
   TAKE(5, hlit); TAKE(5, hdist); TAKE(4, hclen);
   hlit += 257; hdist += 1; hclen += 4;
   memset(cl, 0, sizeof cl);
   for (i = 0; i < hclen; i++) { unsigned v; TAKE(3, v); cl[gz_clord[i]] = (uint8_t) v; }
   inf_build(&t.cl, cl, 19, t.csym, t.ctab, CROOT);
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
   inf_build(&t.lit, lens, hlit, t.lsym, t.ltab, LROOT);
   inf_build(&t.dst, lens + hlit, hdist, t.dsym, t.dtab, DROOT); }

  for (;;) {                                     // the symbol loop, fixed or dynamic
   unsigned sy, l, d, x;
   if (out && ip + 8 <= n && op + 266 <= cap) {
    int f = inf_fast_run(in, n, &ip, &bb, &bc, out, &op, cap, &t);
    if (f < 0) return -1;
    if (f) break; }
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
   if (d > op + nd) return -1;                   // a reach before the start
   if (op + l > cap) return -2;
   if (out && d > op) {                          // into the dictionary, and maybe out again
    uintptr_t h = d - op < l ? d - op : l;
    memcpy(out + op, dic + nd - (d - op), h);
    for (uintptr_t k = h; k < l; k++) out[op + k] = out[op + k - d]; }
   else if (out) {
    // deflate lets a run overlap its own source -- dist 1 len 100 is a hundred of one
    // byte -- so the bytes go out in order and read each other back as they go, which is
    // right at every distance. eight or more apart, no byte of a word is read back inside
    // that word, and the wide move says the same thing: mooncc spends ten instructions a
    // byte on the narrow one here, so the guard pays for itself well under the old
    // 8.5-byte mean match.
    uint8_t *dp = out + op, *sp = dp - d;
    uintptr_t k = 0;
#if wideld
    if (d >= 8) for (; k + 8 <= l; k += 8) st64(dp + k, ld64(sp + k));
#endif
    for (; k < l; k++) dp[k] = sp[k]; }
   op += l; }
 } while (!last);
 return (int64_t) op;
#undef FILL
#undef TAKE
#undef SYM
}
static int64_t inf_run(const uint8_t *in, uintptr_t n, uint8_t *out, uintptr_t cap) {
 return inf_rund(in, n, out, cap, 0, 0); }

// str0 collects, so the stream is re-read off the stack after it: a C local's pointer
// into the heap is stale across the bump. tls.c pays the same toll.
// the raw-DEFLATE door for C callers with no g: src/inle/kmain.c inflates the
// source blob into its initrd through this. same law as inf_run, exported.
intptr_t inflate_raw(const unsigned char *in, uintptr_t n, unsigned char *out, uintptr_t cap) {
 return (intptr_t) inf_run(in, n, out, cap); }
intptr_t inflate_dict(const unsigned char *in, uintptr_t n, unsigned char *out, uintptr_t cap,
                         const unsigned char *dic, uintptr_t nd) {
 return (intptr_t) inf_rund(in, n, out, cap, dic, nd); }

// the output is one string in the heap, so a stream inflating past this answers 1 and
// is not grown into
#define INF_MAX ((uintptr_t) 1 << 30)

static love_inline struct g *host_inflate(struct g *g) {
 word sw = g->sp[0], nw = g->sp[1];
 intptr_t hint;
 int64_t want;
 int guessed;
 if (!strp(sw) || !oddp(nw)) { g->sp[1] = ZeroPoint, g->sp += 1; return g; }
 hint = getcharm(nw);
 guessed = hint > 0 && (uintptr_t) hint <= INF_MAX;
 want = guessed ? (int64_t) hint
                : inf_run((const uint8_t*) txt(sw), len(sw), 0, INF_MAX);
 for (;;) {
  if (want < 0) break;
  if (!ok(g = str0(g, (uintptr_t) want))) return g;
  if (!want) { g->sp[2] = g->sp[0], g->sp += 2; return g; }   // the counting pass read it
  { word s2 = g->sp[1];
    int64_t got = inf_run((const uint8_t*) txt(s2), len(s2),
                          (uint8_t*) txt(g->sp[0]), (uintptr_t) want);
    if (got == want) { g->sp[2] = g->sp[0], g->sp += 2; return g; } }
  g->sp += 1;                                    // the wrong-sized string, dropped
  if (!guessed) break;
  guessed = 0;                                   // the hint lied: count, then once more
  want = inf_run((const uint8_t*) txt(g->sp[0]), len(g->sp[0]), 0, INF_MAX); }
 g->sp[1] = want == -2 ? putcharm(1) : ZeroPoint, g->sp += 1;
 return g; }

static lvm(lvm_inflate) {
 LvmCall(g, host_inflate) }

static union u const nif_inflate[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_inflate}, {lvm_ret0}};
LvNif("inflate", nif_inflate, NULL);

// ===== inflate, resumable: the stream fed a piece at a time =====
// (inflate-new 0) -> a state cask. (inflate-feed st s) -> what s inflated to while the stream
// wants more; (out . rest) once it ends inside s, rest the bytes behind it; () malformed; 1 past
// INF_MAX in one feed. an empty s says the input is over: a symbol near the end is read against
// zeros then, as inf_run reads one past its last byte, and a stream still open is torn, ().
// the codes, tables and walk are inf_run's, so the two answer alike for every cut of a stream.
// a symbol waits for 15 bits while more may come: an over-subscribed table answers by its
// first writer, and a short read could land on a slot the full one would not.
#define IS_HIST 32768u
#define IS_MAGIC 0x6c6f76656966u
enum { IM_HEAD, IM_STLEN, IM_STORED, IM_TABLE, IM_CLENS, IM_LENS, IM_SYM, IM_DONE };
struct inf_st {
 uint64_t magic, bb, tot;                       // tot: every byte out since the stream began
 uint32_t bc, mode, last, rem, hlit, hdist, hclen, i, prev, stage, sy, len, hp;   // hp: the ring's next seat
 uint8_t lens[320], cl[19];
 struct inf_tabs t;                              // its tab and sym pointers go stale when the cask moves:
 uint8_t hist[IS_HIST]; };                       // inf_st_fix lays them again each feed. hist: the last
                                                 // 32 KiB out, a ring

static void inf_st_fix(struct inf_st *S) {
 S->t.lit.tab = S->t.ltab, S->t.dst.tab = S->t.dtab, S->t.cl.tab = S->t.ctab;
 S->t.lit.sym = S->t.lsym, S->t.dst.sym = S->t.dsym, S->t.cl.sym = S->t.csym; }

// one feed's output, grown by doubling
struct inf_acc { uint8_t *b; uintptr_t n, cap; };
static int inf_room(struct inf_acc *A, uintptr_t k) {
 if (A->n + k <= A->cap) return 1;
 if (A->n + k > INF_MAX) return 0;
 uintptr_t c = A->cap;
 while (c < A->n + k) c *= 2;
 uint8_t *b = alloc(NULL, c);
 if (!b) return 0;
 memcpy(b, A->b, A->n), alloc(A->b, 0);
 return A->b = b, A->cap = c, 1; }

static void inf_pull(uint64_t *bb, uint32_t *bc, const uint8_t *in, uintptr_t n, uintptr_t *ip) {
 while (*bc <= 56 && *ip < n) *bb |= (uint64_t) in[(*ip)++] << *bc, *bc += 8; }

// 1 a symbol, 0 wait for input, -1 malformed
static int inf_sym1(const struct inf_code *c, unsigned root, uint64_t *bb, uint32_t *bc,
                    const uint8_t *in, uintptr_t n, uintptr_t *ip, int eof, unsigned *sy) {
 unsigned u;
 if (*bc < 15) inf_pull(bb, bc, in, n, ip);
 if (*bc < 15 && !eof) return 0;
 uint16_t e = c->tab[*bb & ((1u << root) - 1)];
 if (e) *sy = e >> 4, u = e & 15;
 else { int w = inf_walk(c, *bb); if (w < 0) return -1; *sy = (unsigned) w >> 4, u = w & 15; }
 if (*bc < u) return -1;                         // eof, and the code runs past it
 return *bb >>= u, *bc -= u, 1; }

// the fast lane of IM_SYM, inf_fast_run's shape: a literal is 15 bits at most, so the buffer is
// topped only when it holds fewer, and before a length is taken to the 48 its pair may take,
// one wide load serving several literals while eight input bytes remain. the output grows
// ahead of the lane, 266 bytes of room at a time, so a match copies whole words and may run
// over into room a later byte takes; a reach behind this feed reads the ring a byte at a
// time. a code past its table's root leaves the lane untaken, so the loop makes no call.
// 1 at the block's end, 0 short of input, table or room, -1 malformed. the load leaves
// bits above bc from a byte ip has not passed; they go before a feed returns
static int inf_fast(struct inf_st *S, const uint8_t *in, uintptr_t n, uintptr_t *ipp,
                    uint64_t *bbp, uint32_t *bcp, struct inf_acc *A) {
 const uint8_t *ip = in + *ipp, *ie = in + n - 8;
 const uint16_t *lt = S->t.ltab, *dt = S->t.dtab;
 uint64_t bb = *bbp;
 uintptr_t bc = *bcp, e, f, sy, x, l, d, before = S->tot - A->n;   // before: every byte out ahead of A
 int r = 0;
 for (;;) {
  if (A->cap - A->n < 266 && !inf_room(A, 266)) break;   // near the cap: the slow path says exactly
  uint8_t *b = A->b, *op = b + A->n, *oe = b + A->cap - 266;
  while (op <= oe) {
   if (bc < 15) {
    if (ip > ie) goto stop;
    bb |= LD64(ip) << bc, ip += 7 - (bc >> 3), bc |= 56; }
   if (!(e = lt[bb & ((1u << LROOT) - 1)])) goto stop;
   sy = e >> 4;
   if (sy < 256) { bb >>= e & 15, bc -= e & 15, *op++ = (uint8_t) sy; continue; }
   if (sy == 256) { bb >>= e & 15, bc -= e & 15, r = 1; goto stop; }
   if (sy > 285) { r = -1; goto stop; }
   if (bc < 48) {                                // the pair, still unread, to top up for
    if (ip > ie) goto stop;
    bb |= LD64(ip) << bc, ip += 7 - (bc >> 3), bc |= 56; }
   x = gz_lext[sy - 257];
   if (!(f = dt[(bb >> ((e & 15) + x)) & ((1u << DROOT) - 1)])) goto stop;
   bb >>= e & 15, bc -= e & 15;
   l = gz_lbase[sy - 257] + (uintptr_t) (bb & (((uint64_t) 1 << x) - 1)), bb >>= x, bc -= x;
   bb >>= f & 15, bc -= f & 15, sy = f >> 4;
   if (sy > 29) { r = -1; goto stop; }
   x = gz_dext[sy];
   d = gz_dbase[sy] + (uintptr_t) (bb & (((uint64_t) 1 << x) - 1)), bb >>= x, bc -= x;
   uintptr_t o = (uintptr_t) (op - b);
   if (d > before + o) { r = -1; goto stop; }    // a reach before the start
   uint8_t *dp = op, *sp = op - d, *de = op + l;
   if (d > o)                                     // behind this feed's output: the ring
    for (uintptr_t j = o; dp < de; dp++, j++)
     *dp = d <= j ? b[j - d] : S->hist[(S->hp - (d - j)) & (IS_HIST - 1)];
#if wideld
   else if (d >= 8) for (; dp < de; dp += 8, sp += 8) st64(dp, ld64(sp));
   else if (d == 1) { uint64_t v = 0x0101010101010101ull * *sp;   // a run of one byte
    for (; dp < de; dp += 8) st64(dp, v); }
#endif
   else for (; dp < de; dp++, sp++) *dp = *sp;
   op += l; }
  S->tot = before + (uintptr_t) (op - b), A->n = (uintptr_t) (op - b);
  continue;
 stop:
  S->tot = before + (uintptr_t) (op - b), A->n = (uintptr_t) (op - b);
  break; }
 if (bc < 64) bb &= ((uint64_t) 1 << bc) - 1;   // what is past bc is ip's byte, read again next
 *bbp = bb, *bcp = (uint32_t) bc, *ipp = (uintptr_t) (ip - in);
 return r; }

// the machine: 1 the stream ended, 0 it wants more, -1 malformed, -2 past INF_MAX
static int inf_step(struct inf_st *S, const uint8_t *in, uintptr_t n, int eof, uintptr_t *ipp, struct inf_acc *A) {
 uint64_t bb = S->bb;
 uint32_t bc = S->bc;
 uintptr_t ip = 0;
 int r = 0;
#define NEED(k) do { if (bc < (k)) { inf_pull(&bb, &bc, in, n, &ip); if (bc < (k)) goto wait; } } while (0)
#define BITS(k) ((unsigned) (bb & ((1ull << (k)) - 1)))
#define DROP(k) (bb >>= (k), bc -= (k))
#define SYM1(c, root) do { int s_ = inf_sym1(&(c), root, &bb, &bc, in, n, &ip, eof, &S->sy); \
   if (s_ <= 0) { if (s_) goto bad; goto wait; } } while (0)
#define EMIT(k) do { if (!inf_room(A, k)) goto big; } while (0)
 for (;;) switch (S->mode) {
 case IM_HEAD:
  NEED(3);
  S->last = BITS(1); { unsigned typ = (bb >> 1) & 3; DROP(3);
  if (typ == 0) { DROP(bc & 7); S->mode = IM_STLEN; }
  else if (typ == 3) goto bad;
  else if (typ == 1) {                           // the fixed code, RFC 1951 §3.2.6
   unsigned i;
   for (i = 0; i < 288; i++) S->lens[i] = i < 144 ? 8 : i < 256 ? 9 : i < 280 ? 7 : 8;
   inf_build(&S->t.lit, S->lens, 288, S->t.lsym, S->t.ltab, LROOT);
   for (i = 0; i < 30; i++) S->lens[i] = 5;
   inf_build(&S->t.dst, S->lens, 30, S->t.dsym, S->t.dtab, DROOT);
   S->mode = IM_SYM, S->stage = 0; }
  else S->mode = IM_TABLE; }
  break;
 case IM_STLEN:
  NEED(32);
  { unsigned ln = BITS(16), nl = (unsigned) (bb >> 16) & 0xffff;
    if (((ln ^ 0xffff) & 0xffff) != nl) goto bad;
    DROP(32); S->rem = ln; S->mode = IM_STORED; }
  break;
 case IM_STORED:                                 // what the bit buffer holds is whole bytes now
  while (S->rem && bc >= 8) { EMIT(1); A->b[A->n++] = (uint8_t) BITS(8); DROP(8); S->rem--; S->tot++; }
  if (S->rem) {
   uintptr_t k = n - ip < S->rem ? n - ip : S->rem;
   EMIT(k); memcpy(A->b + A->n, in + ip, k); A->n += k, ip += k, S->rem -= (uint32_t) k, S->tot += k;
   if (S->rem) goto wait; }
  S->mode = S->last ? IM_DONE : IM_HEAD;
  break;
 case IM_TABLE:
  NEED(14);
  S->hlit = BITS(5) + 257, S->hdist = ((bb >> 5) & 31) + 1, S->hclen = ((bb >> 10) & 15) + 4;
  DROP(14);
  memset(S->cl, 0, sizeof S->cl), S->i = 0, S->mode = IM_CLENS;
  break;
 case IM_CLENS:
  while (S->i < S->hclen) { NEED(3); S->cl[gz_clord[S->i++]] = (uint8_t) BITS(3); DROP(3); }
  inf_build(&S->t.cl, S->cl, 19, S->t.csym, S->t.ctab, CROOT);
  memset(S->lens, 0, sizeof S->lens), S->i = 0, S->prev = 0, S->stage = 0, S->mode = IM_LENS;
  break;
 case IM_LENS:
  // a run may overshoot hlit + hdist, and the twin lets it: the write is clamped, the cursor not
  while (S->i < S->hlit + S->hdist) {
   unsigned r_, v, k;
   if (!S->stage) { SYM1(S->t.cl, CROOT); S->stage = 1; }
   if (S->sy < 16)       { r_ = 1; v = S->sy; }
   else if (S->sy == 16) { NEED(2); r_ = BITS(2) + 3; DROP(2); v = S->prev; }
   else if (S->sy == 17) { NEED(3); r_ = BITS(3) + 3; DROP(3); v = 0; }
   else if (S->sy == 18) { NEED(7); r_ = BITS(7) + 11; DROP(7); v = 0; }
   else goto bad;
   for (k = 0; k < r_; k++) if (S->i + k < sizeof S->lens) S->lens[S->i + k] = (uint8_t) v;
   S->i += r_, S->prev = v, S->stage = 0; }
  inf_build(&S->t.lit, S->lens, S->hlit, S->t.lsym, S->t.ltab, LROOT);
  inf_build(&S->t.dst, S->lens + S->hlit, S->hdist, S->t.dsym, S->t.dtab, DROOT);
  S->mode = IM_SYM, S->stage = 0;
  break;
 case IM_SYM:                                    // stage: 0 a symbol, 1 its length's extra, 2 the
  for (;;) {                                     // distance's symbol, 3 its extra
   if (S->stage == 0 && ip + 8 <= n) {          // the fast lane: eight bytes on, a whole pair fits
    int e_ = inf_fast(S, in, n, &ip, &bb, &bc, A);
    if (e_ < 0) { if (e_ == -2) goto big; goto bad; }
    if (e_) { S->mode = S->last ? IM_DONE : IM_HEAD; break; } }
   if (S->stage == 0) {
    SYM1(S->t.lit, LROOT);
    if (S->sy < 256) { EMIT(1); A->b[A->n++] = (uint8_t) S->sy; S->tot++; continue; }
    if (S->sy == 256) { S->mode = S->last ? IM_DONE : IM_HEAD; break; }
    if (S->sy > 285) goto bad;
    S->sy -= 257, S->stage = 1; }
   if (S->stage == 1) {
    unsigned x = gz_lext[S->sy];
    NEED(x); S->len = gz_lbase[S->sy] + BITS(x); DROP(x); S->stage = 2; }
   if (S->stage == 2) { SYM1(S->t.dst, DROOT); if (S->sy > 29) goto bad; S->stage = 3; }
   { unsigned x = gz_dext[S->sy], d, l = S->len;
     NEED(x); d = gz_dbase[S->sy] + BITS(x);
     if (d > S->tot) goto bad;                   // a reach before the start
     DROP(x); EMIT(l);
     uint8_t *b = A->b;                          // behind this feed's output, the ring
     for (uintptr_t k = A->n, e = A->n + l; k < e; k++)
      b[k] = d <= k ? b[k - d] : S->hist[(S->hp - (d - k)) & (IS_HIST - 1)];
     A->n += l, S->tot += l, S->stage = 0; } }
  break;
 case IM_DONE: r = 1; goto wait;
 default: goto bad; }
bad: r = -1; goto wait;
big: r = -2;
wait:
 S->bb = bb, S->bc = bc, *ipp = ip;
 return r;
#undef NEED
#undef BITS
#undef DROP
#undef SYM1
#undef EMIT
}

static struct str *inf_cask(word x) {
 struct str *s = cask_str(x);
 return s && s->len == sizeof(struct inf_st) && ((struct inf_st*) s->bytes)->magic == IS_MAGIC ? s : NULL; }

static love_noinline struct g *host_inflate_new(struct g *g) {
 uintptr_t sreq = str_width(sizeof(struct inf_st)), breq = Width(struct cask) + Width(struct tag);
 if (!ok(g = have(g, sreq + breq))) return g;
 struct str *s = ini_str(bump(g, sreq), sizeof(struct inf_st));
 memset(s->bytes, 0, sizeof(struct inf_st));
 ((struct inf_st*) s->bytes)->magic = IS_MAGIC;
 union u *k = bump(g, breq);
 cask(k)->ap = lvm_cask, cask(k)->str = s;
 tagthread(k, Width(struct cask));
 return g->sp[0] = word(k), g; }

static love_noinline struct g *host_inflate_feed(struct g *g) {
 struct str *cs = inf_cask(g->sp[0]);
 if (!cs || !strp(g->sp[1])) return g->sp[1] = ZeroPoint, g->sp += 1, g;
 struct inf_st *S = (struct inf_st*) cs->bytes;
 const uint8_t *in = (const uint8_t*) txt(g->sp[1]);
 uintptr_t n = len(g->sp[1]), ip = 0, cap = 4 * n + 4096;
 struct inf_acc A = { alloc(NULL, cap), 0, cap };
 if (!A.b) return g->sp[1] = putcharm(1), g->sp += 1, g;
 inf_st_fix(S);
 int r = inf_step(S, in, n, !n, &ip, &A);
 if (!r && !n) r = -1;                           // the input is over and the stream is not
 uintptr_t on = A.n, rn = 0;
 uint8_t tail[8];
 for (uintptr_t k = on < IS_HIST ? 0 : on - IS_HIST; k < on; ) {   // the output's last 32 KiB into the ring
  uintptr_t h = S->hp, m = IS_HIST - h < on - k ? IS_HIST - h : on - k;
  memcpy(S->hist + h, A.b + k, m), k += m, S->hp = (uint32_t) ((h + m) & (IS_HIST - 1)); }
 if (r == 1) {                                   // the rest: whole bytes still buffered, then the feed's tail
  S->bb >>= S->bc & 7, S->bc -= S->bc & 7;
  for (; S->bc; S->bb >>= 8, S->bc -= 8) tail[rn++] = (uint8_t) S->bb;
  S->mode = IM_DONE; }
 if (r < 0) { alloc(A.b, 0); return g->sp[1] = r == -2 ? putcharm(1) : ZeroPoint, g->sp += 1, g; }
 uintptr_t tn = r == 1 ? rn + (n - ip) : 0,
           need = str_width(on) + (r == 1 ? str_width(tn) + Width(struct chain) : 0);
 if (!ok(g = have(g, need))) { alloc(A.b, 0); return g; }
 struct str *o = ini_str(bump(g, str_width(on)), on);
 memcpy(o->bytes, A.b, on);
 alloc(A.b, 0);
 if (r != 1) return g->sp[1] = word(o), g->sp += 1, g;
 struct str *t = ini_str(bump(g, str_width(tn)), tn);
 memcpy(t->bytes, tail, rn), memcpy(t->bytes + rn, txt(g->sp[1]) + ip, n - ip);   // re-read: have may move it
 struct chain *c = ini_chain(bump(g, Width(struct chain)), (intptr_t) o, (intptr_t) t);
 return g->sp[1] = word(c), g->sp += 1, g; }

static LvmWrap(lvm_inflate_new, host_inflate_new)
static LvmWrap(lvm_inflate_feed, host_inflate_feed)
static union u const nif_inflate_new[] = {{lvm_inflate_new}, {lvm_ret0}};
static union u const nif_inflate_feed[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_inflate_feed}, {lvm_ret0}};
LvNif("inflate-new", nif_inflate_new, NULL);
LvNif("inflate-feed", nif_inflate_feed, NULL);

// ===== deflate -- the C twin of src/apps/gz.l's DEFLATE coder, LvNif-registered =====
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
// spare half is dead between collections), one alloc block where it is not. the
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
 uint8_t *lenl, *lend, *lenc, *fixll, *fixld, *cl;
 unsigned chain, lazy; };                                       // the twin's 32 and greedy; the image lane digs
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
                    const uint32_t *prev, unsigned chain, unsigned *rl, unsigned *rd) {
 unsigned lim = (n - i) < 258 ? (unsigned) (n - i) : 258;
 uint32_t k = head[DF_HASH(s, i)];
 unsigned d = chain;
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
 unsigned cl = 0, cd = 0, held = 0;                              // lazy: the match found one on
 while (i < n && k < DF_TOKMAX) {
  unsigned l = 0, d = 0, in = 0;
  if (held) l = cl, d = cd, held = 0;
  else if (i + 3 <= n) df_find(s, n, i, a->head, a->prev, a->chain, &l, &d);
  if (l == 3 && d > DF_TOOFAR) l = 0;                           // a far three is a loss
  if (a->lazy && l >= 3 && l < 258 && i + 4 <= n) {             // a longer one a byte on wins it
   if (!in) df_ins(s, n, i, a->head, a->prev), in = 1;
   df_find(s, n, i + 1, a->head, a->prev, a->chain, &cl, &cd);
   if (cl == 3 && cd > DF_TOOFAR) cl = 0;
   if (cl > l) held = 1, l = 0; }
  if (l < 3) {
   unsigned c = s[i];
   a->tok[k++] = c; a->fl[c]++;
   if (!in) df_ins(s, n, i, a->head, a->prev);
   i++; }
  else {
   unsigned lc = df_lcode(l), dc = df_dcode(d), q;
   a->tok[k++] = 256u + ((uint32_t) lc << 23) + ((uint32_t) dc << 18)
               + ((uint32_t) (l - gz_lbase[lc]) << 13) + (d - gz_dbase[dc]);
   a->fl[257 + lc]++; a->fd[dc]++;
   xb += gz_lext[lc] + gz_dext[dc];
   for (q = in; q < l; q++) df_ins(s, n, i + q, a->head, a->prev);
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

// s[0..i0) is the preset dictionary: in the window, never sent
static int64_t df_go(const uint8_t *s, uintptr_t i0, uintptr_t n, uint8_t *out, uintptr_t cap, uint8_t *m, int best) {
 struct df_ar a;
 struct df_sink t;
 uintptr_t i = i0;
 unsigned j;
 df_carve(m, &a);
 a.chain = best ? 4096 : DF_CHAIN, a.lazy = !!best;
 memset(a.head, 0, 32768 * sizeof *a.head);
 memset(a.prev, 0, 32768 * sizeof *a.prev);
 for (j = 0; j < 288; j++) a.fixll[j] = j < 144 ? 8 : j < 256 ? 9 : j < 280 ? 7 : 8;
 for (j = 0; j < 30; j++) a.fixld[j] = 5;
 df_hcodes(a.fixll, 288, 9, a.fixcl);
 df_hcodes(a.fixld, 30, 5, a.fixcd);
 t.out = out; t.op = 0; t.cap = cap; t.acc = 0; t.nb = 0; t.err = 0;
 for (uintptr_t q = 0; q < i0; q++) df_ins(s, n, q, a.head, a.prev);
 do i = df_block(s, n, i, &t, &a); while (i < n && !t.err);
 df_align(&t);
 return t.err ? -2 : (int64_t) t.op; }

// str0 collects, so both the source and the spare half are re-derived after it:
// a pointer held across the bump is stale, and a major collection flips the halves.
static uint8_t *df_arena(struct g *g, int *alloced) {
 *alloced = 0;
 if (g->major_len * sizeof(word) >= DF_ARENA) return (uint8_t*) g->major_spare;
 void *p = alloc(NULL, DF_ARENA);
 if (p) *alloced = 1;
 return (uint8_t*) p; }

// the image lane: deflate raw bytes into the caller's buffer, one pass, no love stack.
// it is no twin: a lazy parse down a 4096 chain, zlib -9's, a bake-time cost for bytes.
// its arena is always its own -- df_arena may hand back the major pool's spare half, and
// a dump is walking a compacted heap that owns it.
intptr_t deflate_raw(struct g *g, unsigned char const *in, uintptr_t n,
                        unsigned char *out, uintptr_t cap) {
 uint8_t *m = alloc(NULL, DF_ARENA);
 int64_t got;
 if (!m) return -1;
 got = df_go(in, 0, n, out, cap, m, 1);
 alloc(m, 0);
 return (intptr_t) got; }
// ..and against a preset dictionary, which the inflater is handed as inflate_dict's dic
intptr_t deflate_dict(struct g *g, unsigned char const *in, uintptr_t n,
                         unsigned char const *dic, uintptr_t nd, unsigned char *out, uintptr_t cap) {
 uint8_t *m = alloc(NULL, DF_ARENA), *s = m ? alloc(NULL, nd + n) : NULL;
 int64_t got = -1;
 if (s) memcpy(s, dic, nd), memcpy(s + nd, in, n), got = df_go(s, nd, nd + n, out, cap, m, 1);
 if (s) alloc(s, 0);
 if (m) alloc(m, 0);
 return (intptr_t) got; }

love_noinline static struct g *host_deflate(struct g *g) {
 word sw = g->sp[0];
 uint8_t *m;
 int alloced;
 int64_t want, got;
 if (!strp(sw)) { g->sp[0] = ZeroPoint; return g; }
 m = df_arena(g, &alloced);
 if (!m) { g->sp[0] = ZeroPoint; return g; }
 want = df_go((const uint8_t*) txt(sw), 0, len(sw), 0, (uintptr_t) -1, m, 0);
 if (alloced) alloc(m, 0);
 if (want < 0) { g->sp[0] = ZeroPoint; return g; }
 if (!ok(g = str0(g, (uintptr_t) want))) return g;
 m = df_arena(g, &alloced);
 if (!m) { g->sp[1] = ZeroPoint, g->sp += 1; return g; }
 got = df_go((const uint8_t*) txt(g->sp[1]), 0, len(g->sp[1]),
             (uint8_t*) txt(g->sp[0]), (uintptr_t) want, m, 0);
 if (alloced) alloc(m, 0);
 g->sp[1] = got != want ? ZeroPoint : g->sp[0];
 return g->sp++, g; }

// (deflate-best s) -> the raw stream | (): the image lane's coder, no twin of the love one --
// a lazy parse down a 4096 chain, zlib -9's, for bytes that are written once and read often
// (the dist tarball, gzip -9). the parse is dear, so it runs once, into a buffer at
// deflate's own bound (stored blocks: five bytes a block over the input), then the string
love_noinline static struct g *host_deflate_best(struct g *g) {
 word sw = g->sp[0];
 if (!strp(sw)) return g->sp[0] = ZeroPoint, g;
 uintptr_t n = len(sw), cap = n + n / 1024 + 64;
 uint8_t *out = alloc(NULL, cap);
 intptr_t got = out ? deflate_raw(g, (const uint8_t*) txt(sw), n, out, cap) : -1;
 if (got < 0) { if (out) alloc(out, 0); return g->sp[0] = ZeroPoint, g; }
 if (ok(g = str0(g, (uintptr_t) got))) memcpy(txt(g->sp[0]), out, (uintptr_t) got), g->sp[1] = g->sp[0], g->sp++;
 alloc(out, 0);
 return g; }

static LvmWrap(lvm_deflate, host_deflate)
static LvmWrap(lvm_deflate_best, host_deflate_best)

// one operand, so the run is {impl, ret0} -- src/love/nifs.l states the law and lvm_cur
// curries once unconditionally, which at arity one hands the body an operand too many.
static union u const nif_deflate[] = {{lvm_deflate}, {lvm_ret0}},
                     nif_deflate_best[] = {{lvm_deflate_best}, {lvm_ret0}};
LvNif("deflate", nif_deflate, NULL);
LvNif("deflate-best", nif_deflate_best, NULL);
