// gz.c -- DEFLATE, both directions, over one copy of RFC 1951 §3.2.5's tables (gz.l's
// gz-lbase and kin say the same numbers)
#include "love.h"
#include "bytes.h"
#include "inflate.h"
#include "lzfind.h"
#include <stdint.h>
#include <string.h>

// (inflate s n) -> the bytes | () | 1 past INF_MAX; n the inflated size or 0, believed and
// verified, else a counting pass first. gz-puff's twin, held to its bytes by test/host/gzc.l,
// malformed streams too: an over-subscribed code is not refused, first writer wins, and the
// zeroed symbols read 0 past the end as peep does. str0 collects: reread the stream after it

// the output is one heap string, never grown
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

LvDef("inflate", inflate, 2, "gz");

// (inflate-new 0) -> a state cask. (inflate-feed st s) -> what s inflated to while the stream
// wants more; (out . rest) once it ends in s; () malformed; 1 past INF_MAX in one feed. an empty
// s ends the input: the tail reads against zeros as inf_run's does, an open stream is torn.
// a symbol waits for 15 bits while more may come, so every cut answers as inf_run
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

// IM_SYM's fast lane: topped below 15 bits, to 48 before a pair; 266 bytes of room ahead so a
// match copies whole words; a code past the root leaves the lane. 1 the block's end, 0 short,
// -1 malformed. bits above bc are a byte ip has not passed: masked before a feed returns
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
 union u *k = new_cask(&g, sizeof(struct inf_st), sizeof(struct inf_st));
 if (!k) return g;
 ((struct inf_st*) cask(k)->str->bytes)->magic = IS_MAGIC;
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
LvDef("inflate-new", inflate_new, 1, "gz");
LvDef("inflate-feed", inflate_feed, 2, "gz");

// (deflate s) -> the raw stream | (): gz-deflate's twin to the byte (test/host/gzdeflate.l's
// gz-deflatel states it, gzc.l holds them equal). scratch is one alloc block; count, str0 the
// answer, emit again, as str0 moves the source
#define DF_WSIZE 32768u
#define DF_WMASK 32767u
#define DF_HMASK 32767u
#define DF_CHAIN 32
#define DF_TOKMAX 16384u
#define DF_TOOFAR 4096u

// lsb-first, codes handed in reversed (gz-put); with no out it counts
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

// the length ladder is short and walked from the top (gz-lcode)
static unsigned df_lcode(unsigned v) { for (unsigned i = 28; i >= 1; i--) if (gz_lbase[i] <= v) return i; return 0; }
static unsigned df_dcode(unsigned v) {             // two codes an octave: its top two bits
 unsigned d = v - 1, e = 31 - (unsigned) __builtin_clz(d | 1);
 return d < 4 ? d : 2 * e + (d >> (e - 1) & 1); }

// canonical, shortest first, ties by symbol, stored reversed (gz-hcodes)
static void df_hcodes(const uint8_t *lens, unsigned nsym, unsigned mx, uint32_t *code) {
 uint32_t cnt[16], nxt[16], c = 0;
 unsigned i, l;
 memset(cnt, 0, sizeof cnt);
 for (i = 0; i < nsym; i++) if (lens[i]) cnt[lens[i]]++;
 for (l = 1; l <= mx && l < 16; l++) { nxt[l] = c; c = (c + cnt[l]) << 1; }
 for (i = 0; i < nsym; i++) if (lens[i]) { code[i] = df_rev(nxt[lens[i]], lens[i]); nxt[lens[i]]++; } }

// gz-run: 16 repeats the value before it, 17 and 18 zero runs; an entry is (sym << 7) + extra
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

// carved once: the finder's windows outlive every block, the rest is reused
struct df_ar {
 uint32_t *head, *prev, *tok, *fl, *fd,
          *hc, *pa, *rlb, *fc,
          *codl, *codd, *codc, *fixcl, *fixcd;
 uint64_t *keys, *w;
 uint8_t *lenl, *lend, *lenc, *fixll, *fixld, *cl; };
#define DF_ARENA (384u << 10)
static void df_carve(uint8_t *m, struct df_ar *a) {
 uint8_t *p = m;
#define DF_TAKE(f, n, ty) a->f = (ty*) p; p += ((n) * sizeof(ty) + 7u) & ~7u
 DF_TAKE(head, 32768, uint32_t); DF_TAKE(prev, 32768, uint32_t);
 DF_TAKE(tok, DF_TOKMAX, uint32_t); DF_TAKE(fl, 286, uint32_t); DF_TAKE(fd, 30, uint32_t);
 DF_TAKE(hc, 286, uint32_t); DF_TAKE(keys, 286, uint64_t);
 DF_TAKE(w, 572, uint64_t); DF_TAKE(pa, 572, uint32_t);
 DF_TAKE(rlb, 320, uint32_t); DF_TAKE(fc, 19, uint32_t);
 DF_TAKE(codl, 286, uint32_t); DF_TAKE(codd, 30, uint32_t); DF_TAKE(codc, 19, uint32_t);
 DF_TAKE(fixcl, 288, uint32_t); DF_TAKE(fixcd, 30, uint32_t);
 DF_TAKE(lenl, 286, uint8_t); DF_TAKE(lend, 30, uint8_t); DF_TAKE(lenc, 19, uint8_t);
 DF_TAKE(fixll, 288, uint8_t); DF_TAKE(fixld, 30, uint8_t); DF_TAKE(cl, 316, uint8_t); }

// prefix.h's pfx_lens, gz-hpass exactly; a code needs two symbols, so a lone one gains a partner
static unsigned df_hlens(const uint32_t *f, unsigned nsym, unsigned lim, uint8_t *lens, struct df_ar *a) {
 unsigned i, u = 0;
 for (i = 0; i < nsym; i++) a->hc[i] = f[i], u += f[i] != 0;
 if (u < 2) { if (!a->hc[0]) a->hc[0] = 1; if (!a->hc[1]) a->hc[1] = 1; }
 return pfx_lens(a->hc, nsym, lim, lens, a->keys, a->w, a->pa); }

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

static void df_flush(struct df_sink *t, struct df_ar *a, const uint32_t *tok, unsigned k, uint64_t xb,
                     const uint8_t *s, uintptr_t i0, uintptr_t i, int last);
// one block: tokenize (gz-tok), then flush
static uintptr_t df_block(const uint8_t *s, uintptr_t n, uintptr_t i, struct df_sink *t, struct df_ar *a) {
 unsigned k = 0;
 uint64_t xb = 0;
 uintptr_t i0 = i;
 memset(a->fl, 0, 286 * sizeof *a->fl);
 memset(a->fd, 0, 30 * sizeof *a->fd);
 while (i < n && k < DF_TOKMAX) {
  unsigned l = 0, d = 0;
  if (i + 3 <= n) df_find(s, n, i, a->head, a->prev, DF_CHAIN, &l, &d);
  if (l == 3 && d > DF_TOOFAR) l = 0;                           // a far three is a loss
  if (l < 3) {
   unsigned c = s[i];
   a->tok[k++] = c; a->fl[c]++;
   df_ins(s, n, i, a->head, a->prev);
   i++; }
  else {
   unsigned lc = df_lcode(l), dc = df_dcode(d), q;
   a->tok[k++] = 256u + ((uint32_t) lc << 23) + ((uint32_t) dc << 18)
               + ((uint32_t) (l - gz_lbase[lc]) << 13) + (d - gz_dbase[dc]);
   a->fl[257 + lc]++; a->fd[dc]++;
   xb += gz_lext[lc] + gz_dext[dc];
   for (q = 0; q < l; q++) df_ins(s, n, i + q, a->head, a->prev);
   i += l; } }
 df_flush(t, a, a->tok, k, xb, s, i0, i, n <= i);
 return i; }

// the three spellings of tokens tok[0..k) (counted in fl and fd, xb extra bits) costed, the
// cheapest written (gz-flush). the dynamic code wins its tie with the fixed one
// the three spellings of a block of len bytes, counted in fl and fd (xb extra bits), costed
struct df_plan { unsigned mxl, mxd, mxc, hlit, hdist, hclen, nr; uint64_t dyn, fix, raw; };
static uint64_t df_price(struct df_ar *a, uint64_t xb, uintptr_t len, struct df_plan *p) {
 unsigned j2;
 a->fl[256]++;                                                  // end-of-block, always sent
 p->mxl = df_hlens(a->fl, 286, 15, a->lenl, a), p->mxd = df_hlens(a->fd, 30, 15, a->lend, a);
 for (p->hlit = 286; p->hlit > 257 && !a->lenl[p->hlit - 1]; p->hlit--) ;
 for (p->hdist = 30; p->hdist > 1 && !a->lend[p->hdist - 1]; p->hdist--) ;
 memcpy(a->cl, a->lenl, p->hlit); memcpy(a->cl + p->hlit, a->lend, p->hdist);
 p->nr = df_run(a->cl, p->hlit + p->hdist, a->rlb);
 memset(a->fc, 0, 19 * sizeof *a->fc);
 for (j2 = 0; j2 < p->nr; j2++) a->fc[a->rlb[j2] >> 7]++;
 p->mxc = df_hlens(a->fc, 19, 7, a->lenc, a);
 for (p->hclen = 19; p->hclen > 4 && !a->lenc[gz_clord[p->hclen - 1]]; p->hclen--) ;
 p->dyn = 17 + p->hclen * 3 + df_ccost(a->rlb, a->lenc, p->nr)
        + df_cost(a->fl, a->lenl, 286) + df_cost(a->fd, a->lend, 30) + xb;
 p->fix = 3 + df_cost(a->fl, a->fixll, 286) + df_cost(a->fd, a->fixld, 30) + xb;
 p->raw = len < 65536 ? 42 + (uint64_t) len * 8 : p->dyn + p->fix;   // no stored spelling past len
 uint64_t c = p->dyn <= p->fix ? p->dyn : p->fix;
 return p->raw < c ? p->raw : c; }

static void df_flush(struct df_sink *t, struct df_ar *a, const uint32_t *tok, unsigned k, uint64_t xb,
                     const uint8_t *s, uintptr_t i0, uintptr_t i, int last) {
 struct df_plan p;
 unsigned j2;
 df_price(a, xb, i - i0, &p);
 if (p.raw < (p.dyn <= p.fix ? p.dyn : p.fix)) df_wstored(t, s, i0, i, last);
 else if (p.fix < p.dyn) {
  df_put(t, last ? 1 : 0, 1); df_put(t, 1, 2);
  df_wtoks(t, tok, k, a->fixcl, a->fixll, a->fixcd, a->fixld); }
 else {
  df_hcodes(a->lenl, 286, p.mxl, a->codl);
  df_hcodes(a->lend, 30, p.mxd, a->codd);
  df_hcodes(a->lenc, 19, p.mxc, a->codc);
  df_put(t, last ? 1 : 0, 1); df_put(t, 2, 2);
  df_put(t, p.hlit - 257, 5); df_put(t, p.hdist - 1, 5); df_put(t, p.hclen - 4, 4);
  for (j2 = 0; j2 < p.hclen; j2++) df_put(t, a->lenc[gz_clord[j2]], 3);
  for (j2 = 0; j2 < p.nr; j2++) {
   uint32_t v = a->rlb[j2]; unsigned sy = v >> 7;
   df_put(t, a->codc[sy], a->lenc[sy]);
   if (df_clx(sy)) df_put(t, v & 127, df_clx(sy)); }
  df_wtoks(t, tok, k, a->codl, a->lenl, a->codd, a->lend); } }

// --- the best lane: an optimal parse, priced off the pass before (zopfli's way) -------------
// a block's matches are found once (lzfind.h): at each position, every length the tree reaches at
// its nearest distance. each pass is the cheapest path through them, costed in 16ths of a bit
#ifndef DF_OBLOCK
#define DF_OBLOCK (1u << 17)                    // input bytes one block parses
#endif
#ifndef DF_OITERS
#define DF_OITERS 2
#endif
#define DF_OINF 0xffffffffu
#ifndef DF_ODEPTH
#define DF_ODEPTH 48                            // the finder's tree walk
#endif
#define DF_OMAXM 64
#ifndef DF_OGRID
#define DF_OGRID 128                            // split points a block weighs, at most
#endif
#define DF_OSTEP 32                             // tokens between two, at least
#ifndef DF_ONICE
#define DF_ONICE 258
#endif
struct df_opt { uint32_t *price, *mo, *tok, *best; uint16_t *ml, *md, *len, *dist; uintptr_t capm;
                struct lzf f; uint32_t cl[286], cd[30], clen[259], ls[DF_OMAXM], ds[DF_OMAXM]; };

static uint32_t df_l2(uint32_t x) {             // 16 log2 x, by squaring: four fraction bits
 unsigned e = 31 - (unsigned) __builtin_clz(x), f = 0;
 uint64_t w = e >= 15 ? x >> (e - 15) : (uint64_t) x << (15 - e);
 for (int j = 0; j < 4; j++) { w = w * w >> 15, f <<= 1; if (w >= 1u << 16) w >>= 1, f |= 1; }
 return e << 4 | f; }

// the costs off counts: entropy, an unseen symbol as one in the total
static void df_ocost(uint32_t *c, const uint32_t *f, unsigned nsym) {
 uint32_t tot = 0;
 for (unsigned j = 0; j < nsym; j++) tot += f[j];
 uint32_t lt = df_l2(tot ? tot : 1);
 for (unsigned j = 0; j < nsym; j++) c[j] = f[j] ? lt - df_l2(f[j]) : lt; }

// the cheapest path through s[i + u .. i + v) under o's costs, as tokens -> how many, counted in
// fl and fd, extra bits in *xb. o's matches are the block's from i
static unsigned df_opath(const uint8_t *s, uintptr_t i, uintptr_t u, uintptr_t v, struct df_opt *o,
                         struct df_ar *a, uint32_t *tok, uint64_t *xb) {
 uintptr_t B = v - u;
 const uint8_t *b = s + i + u;
 const uint32_t *mo = o->mo + u;
 for (unsigned l = 3; l <= 258; l++) {
  unsigned lc = df_lcode(l);
  o->clen[l] = o->cl[257 + lc] + (gz_lext[lc] << 4); }
 o->price[0] = 0;
 for (uintptr_t j = 1; j <= B; j++) o->price[j] = DF_OINF;
 for (uintptr_t j = 0; j < B; j++) {
  uint32_t c = o->price[j];
  if (c + o->cl[b[j]] < o->price[j + 1]) o->price[j + 1] = c + o->cl[b[j]], o->len[j + 1] = 1;
  unsigned lo = 3, top = B - j < 258 ? (unsigned) (B - j) : 258;
  for (uint32_t m = mo[j]; m < mo[j + 1] && lo <= top; m++) {
   unsigned hi = o->ml[m] < top ? o->ml[m] : top, dc = df_dcode(o->md[m]);
   uint32_t cd = c + o->cd[dc] + (gz_dext[dc] << 4);
   for (unsigned l = lo; l <= hi; l = l < DF_ONICE || l == hi ? l + 1 : hi)   // past nice, only its whole
    if (cd + o->clen[l] < o->price[j + l]) o->price[j + l] = cd + o->clen[l], o->len[j + l] = (uint16_t) l, o->dist[j + l] = o->md[m];
   lo = hi + 1; } }
 unsigned k = 0;
 for (uintptr_t j = B; j; j -= o->len[j]) k++;
 unsigned n = k;
 memset(a->fl, 0, 286 * sizeof *a->fl), memset(a->fd, 0, 30 * sizeof *a->fd), *xb = 0;
 for (uintptr_t j = B; j; j -= o->len[j]) {
  unsigned l = o->len[j];
  if (l == 1) { unsigned c = b[j - 1]; tok[--k] = c, a->fl[c]++; continue; }
  unsigned d = o->dist[j], lc = df_lcode(l), dc = df_dcode(d);
  tok[--k] = 256u + ((uint32_t) lc << 23) + ((uint32_t) dc << 18) + ((uint32_t) (l - gz_lbase[lc]) << 13) + (d - gz_dbase[dc]);
  a->fl[257 + lc]++, a->fd[dc]++, *xb += gz_lext[lc] + gz_dext[dc]; }
 return n; }

// passes over [u, v) from o's costs, each priced off the one before: the cheapest in o->best,
// how many in *bk, extra bits in *bxb -> its bits
static uint64_t df_opass(const uint8_t *s, uintptr_t i, uintptr_t u, uintptr_t v, struct df_opt *o,
                         struct df_ar *a, unsigned *bk, uint64_t *bxb) {
 uint64_t bbits = ~(uint64_t) 0, xb;
 for (unsigned it = 0; it < DF_OITERS; it++) {
  unsigned k = df_opath(s, i, u, v, o, a, o->tok, &xb);
  uint32_t fl[286], fd[30];
  struct df_plan p;
  memcpy(fl, a->fl, sizeof fl), memcpy(fd, a->fd, sizeof fd);
  uint64_t bits = df_price(a, xb, v - u, &p);
  if (bits < bbits) bbits = bits, *bk = k, *bxb = xb, memcpy(o->best, o->tok, k * sizeof *o->tok);
  df_ocost(o->cl, fl, 286), df_ocost(o->cd, fd, 30); }
 return bbits; }

// tokens tok[0..k) counted into fl and fd, their extra bits -> how many bytes they cover
static uintptr_t df_ocount(const uint32_t *tok, unsigned k, uint32_t *fl, uint32_t *fd, uint64_t *xb) {
 uintptr_t len = 0;
 for (unsigned j = 0; j < k; j++) {
  uint32_t v = tok[j];
  if (v < 256) { fl[v]++, len++; continue; }
  uint32_t w = v - 256;
  unsigned lc = w >> 23, dc = (w >> 18) & 31;
  fl[257 + lc]++, fd[dc]++, *xb += gz_lext[lc] + gz_dext[dc], len += gz_lbase[lc] + ((w >> 13) & 31); }
 return len; }

// the grid's blocks [ga, gb) priced off its running counts
static uint64_t df_gcost(struct df_ar *a, const uint32_t *cnt, const uint64_t *xbp, const uintptr_t *pos,
                         unsigned ga, unsigned gb) {
 const uint32_t *x = cnt + (uintptr_t) ga * 316, *y = cnt + (uintptr_t) gb * 316;
 struct df_plan p;
 for (unsigned j = 0; j < 286; j++) a->fl[j] = y[j] - x[j];
 for (unsigned j = 0; j < 30; j++) a->fd[j] = y[286 + j] - x[286 + j];
 return df_price(a, xbp[gb] - xbp[ga], pos[gb] - pos[ga], &p); }

// one block of the best lane from i: its matches, a parse of the whole, split where two codes
// cost less than one, and each part parsed again on its own -> where it ends
static uintptr_t df_oblock(const uint8_t *s, uintptr_t n, uintptr_t i, struct df_sink *t, struct df_ar *a,
                           struct df_opt *o) {
 uintptr_t e = n - i > DF_OBLOCK ? i + DF_OBLOCK : n, B = e - i, nm = 0;
 for (uintptr_t j = 0; j < B; j++) {
  if (o->capm - nm < 258) {                      // alloc keeps nothing: grown by a copy
   uintptr_t c2 = o->capm * 2 + 4096;
   uint16_t *l2 = alloc(NULL, c2 * sizeof *l2), *d2 = l2 ? alloc(NULL, c2 * sizeof *d2) : NULL;
   if (!d2) { if (l2) alloc(l2, 0); t->err = 1; return n; }
   if (nm) memcpy(l2, o->ml, nm * sizeof *l2), memcpy(d2, o->md, nm * sizeof *d2);
   if (o->ml) alloc(o->ml, 0), alloc(o->md, 0);
   o->ml = l2, o->md = d2, o->capm = c2; }
  o->mo[j] = (uint32_t) nm;
  uintptr_t left = n - i - j;
  unsigned k = lzf_all(&o->f, i + j, left < 258 ? (unsigned) left : 258, 258, o->ls, o->ds);
  for (unsigned q = 0; q < k; q++)
   if (o->ls[q] >= 3) o->ml[nm] = (uint16_t) o->ls[q], o->md[nm] = (uint16_t) (o->ds[q] + 1), nm++; }
 o->mo[B] = (uint32_t) nm;
 // the whole, from the fixed code's lengths
 for (unsigned j = 0; j < 286; j++) o->cl[j] = (uint32_t) a->fixll[j] << 4;
 for (unsigned j = 0; j < 30; j++) o->cd[j] = 5u << 4;
 unsigned bk = 0;
 uint64_t bxb = 0;
 df_opass(s, i, 0, B, o, a, &bk, &bxb);
 // the grid: running counts every g tokens
 unsigned g = bk / DF_OGRID > DF_OSTEP ? bk / DF_OGRID : DF_OSTEP, G = (bk + g - 1) / g;
 uint32_t *cnt = alloc(NULL, (uintptr_t) (G + 1) * 316 * sizeof *cnt + (G + 1) * (sizeof(uint64_t) + sizeof(uintptr_t))
                             + 2 * (G + 1) * sizeof(unsigned));
 if (!cnt) { t->err = 1; return n; }
 uint64_t *xbp = (uint64_t*) (cnt + (uintptr_t) (G + 1) * 316);
 uintptr_t *pos = (uintptr_t*) (xbp + G + 1);
 unsigned *st = (unsigned*) (pos + G + 1), sn = 0, ga, gb;
 memset(cnt, 0, 316 * sizeof *cnt), xbp[0] = 0, pos[0] = 0;
 for (unsigned q = 0; q < G; q++) {
  uint32_t *c = cnt + (uintptr_t) (q + 1) * 316;
  unsigned k0 = q * g, k1 = k0 + g < bk ? k0 + g : bk;
  memcpy(c, c - 316, 316 * sizeof *c), xbp[q + 1] = xbp[q];
  pos[q + 1] = pos[q] + df_ocount(o->best + k0, k1 - k0, c, c + 286, xbp + q + 1); }
 // split [ga, gb) at its cheapest point while that pays; the parts in order, left first
 st[sn++] = 0, st[sn++] = G;
 while (sn) {
  gb = st[--sn], ga = st[--sn];
  uint64_t bc = df_gcost(a, cnt, xbp, pos, ga, gb);
  unsigned at = 0, lo = ga + 1, hi = gb - 1;
  while (lo <= hi && gb - ga > 1) {               // nine points across, then between the best's neighbours
   unsigned w = hi - lo, k = w < 9 ? w + 1 : 9, bi = 0, pt[9];
   uint64_t bv = ~(uint64_t) 0;
   for (unsigned q = 0; q < k; q++) {
    pt[q] = k == w + 1 ? lo + q : lo + (unsigned) ((uint64_t) w * q / (k - 1));
    uint64_t two = df_gcost(a, cnt, xbp, pos, ga, pt[q]) + df_gcost(a, cnt, xbp, pos, pt[q], gb);
    if (two < bv) bv = two, bi = q; }
   if (bv < bc) bc = bv, at = pt[bi];
   if (k == w + 1) break;
   lo = bi ? pt[bi - 1] + 1 : lo, hi = bi + 1 < k ? pt[bi + 1] - 1 : hi; }
  if (at) { st[sn++] = at, st[sn++] = gb, st[sn++] = ga, st[sn++] = at; continue; }
  if (!ga && gb == G) {                           // the whole, as parsed
   memset(a->fl, 0, 286 * sizeof *a->fl), memset(a->fd, 0, 30 * sizeof *a->fd), bxb = 0;
   df_ocount(o->best, bk, a->fl, a->fd, &bxb);
   df_flush(t, a, o->best, bk, bxb, s, i, e, e >= n);
   break; }
  // a part: parsed again from its own counts, then written
  const uint32_t *x = cnt + (uintptr_t) ga * 316, *y = cnt + (uintptr_t) gb * 316;
  uint32_t fl[286], fd[30];
  for (unsigned j = 0; j < 286; j++) fl[j] = y[j] - x[j];
  for (unsigned j = 0; j < 30; j++) fd[j] = y[286 + j] - x[286 + j];
  df_ocost(o->cl, fl, 286), df_ocost(o->cd, fd, 30);
  unsigned pk = 0;
  uint64_t pxb = 0;
  df_opass(s, i, pos[ga], pos[gb], o, a, &pk, &pxb);
  memset(a->fl, 0, 286 * sizeof *a->fl), memset(a->fd, 0, 30 * sizeof *a->fd), pxb = 0;
  df_ocount(o->best, pk, a->fl, a->fd, &pxb);
  df_flush(t, a, o->best, pk, pxb, s, i + pos[ga], i + pos[gb], gb == G && e >= n); }
 alloc(cnt, 0);
 return e; }

// s[0..i0) is the preset dictionary: in the window, never sent
static int64_t df_go(const uint8_t *s, uintptr_t i0, uintptr_t n, uint8_t *out, uintptr_t cap, uint8_t *m, int best) {
 struct df_ar a;
 struct df_sink t;
 uintptr_t i = i0;
 unsigned j;
 df_carve(m, &a);
 memset(a.head, 0, 32768 * sizeof *a.head);
 memset(a.prev, 0, 32768 * sizeof *a.prev);
 for (j = 0; j < 288; j++) a.fixll[j] = j < 144 ? 8 : j < 256 ? 9 : j < 280 ? 7 : 8;
 for (j = 0; j < 30; j++) a.fixld[j] = 5;
 df_hcodes(a.fixll, 288, 9, a.fixcl);
 df_hcodes(a.fixld, 30, 5, a.fixcd);
 t.out = out; t.op = 0; t.cap = cap; t.acc = 0; t.nb = 0; t.err = 0;
 if (best) {
  struct df_opt *o = alloc(NULL, sizeof *o);
  uintptr_t nb = (DF_OBLOCK + 1) * (3 * sizeof(uint32_t) + 3 * sizeof(uint16_t)) + DF_OBLOCK * sizeof(uint32_t),
            nf = (3u << 16) + 2 * DF_WSIZE;
  uint8_t *b = o ? alloc(NULL, nb + nf * sizeof(uint32_t)) : NULL;
  if (!b) { if (o) alloc(o, 0); return -1; }
  uint32_t *h = (uint32_t*) (b + nb);
  memset(h, 0, (3u << 16) * sizeof *h);
  o->f = (struct lzf) { s, n, h, h + (1u << 16), h + (2u << 16), h + (3u << 16), DF_WMASK, DF_WSIZE, 0,
                        16, DF_ODEPTH, 8, 258, DF_OMAXM };
  lzf_ins(&o->f, i0, 258);
  o->price = (uint32_t*) b, o->mo = o->price + DF_OBLOCK + 1, o->tok = o->mo + DF_OBLOCK + 1,
  o->best = o->tok + DF_OBLOCK + 1, o->len = (uint16_t*) (o->best + DF_OBLOCK),
  o->dist = o->len + DF_OBLOCK + 1, o->ml = o->md = NULL, o->capm = 0;
  do i = df_oblock(s, n, i, &t, &a, o); while (i < n && !t.err);
  alloc(o->ml, 0), alloc(o->md, 0), alloc(b, 0), alloc(o, 0); }
 else {
  for (uintptr_t q = 0; q < i0; q++) df_ins(s, n, q, a.head, a.prev);
  do i = df_block(s, n, i, &t, &a); while (i < n && !t.err); }
 df_align(&t);
 return t.err ? -2 : (int64_t) t.op; }

// the image lane, no twin: into the caller's buffer, the optimal parse
intptr_t deflate_raw(struct g *g, unsigned char const *in, uintptr_t n,
                        unsigned char *out, uintptr_t cap) {
 uint8_t *m = alloc(NULL, DF_ARENA);
 int64_t got;
 if (!m) return -1;
 got = df_go(in, 0, n, out, cap, m, 1);
 alloc(m, 0);
 return (intptr_t) got; }
// against a preset dictionary, inflate_dict's dic
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
 uint8_t *m = strp(sw) ? alloc(NULL, DF_ARENA) : NULL;
 int64_t want, got;
 if (!m) { g->sp[0] = ZeroPoint; return g; }
 want = df_go((const uint8_t*) txt(sw), 0, len(sw), 0, (uintptr_t) -1, m, 0);
 if (want < 0) { alloc(m, 0); g->sp[0] = ZeroPoint; return g; }
 if (!ok(g = str0(g, (uintptr_t) want))) return alloc(m, 0), g;   // the source is re-read off the stack: str0 may move it
 got = df_go((const uint8_t*) txt(g->sp[1]), 0, len(g->sp[1]),
             (uint8_t*) txt(g->sp[0]), (uintptr_t) want, m, 0);
 alloc(m, 0);
 g->sp[1] = got != want ? ZeroPoint : g->sp[0];
 return g->sp++, g; }

// (deflate-best s) -> the raw stream | (): the image lane once, into a buffer at the stored bound
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

// arity one runs {impl, ret0}: lvm_cur would hand one operand too many (nifs.l)
LvDef("deflate", deflate, 1, "gz");
LvDef("deflate-best", deflate_best, 1, "gz");
