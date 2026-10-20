// lr.c -- module lr, the walk our yacc's tables are read by (src/apps/kore/yacc.l)
//   (run t k c look) -> c': from cursor c, shift and reduce over the kinds k until an accept,
//   an error, a kind still to say, or LrSteps steps; c' is the next cursor, carrying the log
// t, u16s: T N S R AN GN, rlhs rlen (R each), dflt abase (S each), gdef gbase (N each), atab
//   achk (AN each), gtab gchk (GN each). an action is 0 error, under 0x8000 a shift, else a
//   reduce of rule a - 0x8000; dflt is a rule + 1, or 0; abase 0xffff wants no lookahead
// k: a u16 kind per token, 0xffff one the caller says through look; past the end is 0, $end.
//   look is a kind, or a + 65536 * (b + 1): a where the parse can shift it, else b (C's
//   typedef name, which is a declarator's name where no type may stand)
// c: u32 pos, u32 depth, u16 states; c' then u8 status (0 more, 1 accept, 2 error, 3 a kind to
//   say at pos) and u32 n, n reductions (u16 rule, u32 pos)
#include "love.h"

#define LrSteps 4096

static love_inline uintptr_t lr16(unsigned char const *p, uintptr_t x) {
 return (uintptr_t) p[2 * x] | (uintptr_t) p[2 * x + 1] << 8; }
static love_inline uintptr_t lr32(unsigned char const *p) {
 return (uintptr_t) p[0] | (uintptr_t) p[1] << 8 | (uintptr_t) p[2] << 16 | (uintptr_t) p[3] << 24; }
static love_inline void lrput16(unsigned char *p, uintptr_t v) { p[0] = (unsigned char) v, p[1] = (unsigned char) (v >> 8); }
static love_inline void lrput32(unsigned char *p, uintptr_t v) { lrput16(p, v & 0xffff), lrput16(p + 2, v >> 16); }

// would kind shift, after the reductions it calls for? the stack is read, not written: what the
// reductions push rides an overlay, and a chain too long to follow says yes
static bool lr_takes(unsigned char const *h, unsigned char const *st, uintptr_t d, uintptr_t kind) {
 uintptr_t T = lr16(h, 0), N = lr16(h, 1), S = lr16(h, 2), R = lr16(h, 3), AN = lr16(h, 4), GN = lr16(h, 5),
           ov[64], no = 0;
 unsigned char const *rlhs = h + 12, *rlen = rlhs + 2 * R, *dflt = rlen + 2 * R, *abase = dflt + 2 * S,
                     *gdef = abase + 2 * S, *gbase = gdef + 2 * N, *atab = gbase + 2 * N, *achk = atab + 2 * AN,
                     *gtab = achk + 2 * AN, *gchk = gtab + 2 * GN;
 for (int n = 0; n < 256; n++) {
  uintptr_t s = no ? ov[no - 1] : lr16(st, d - 1);
  if (s >= S) return false;
  uintptr_t df = lr16(dflt, s), a = df ? 0x8000 + df - 1 : 0, i = lr16(abase, s) + kind;
  if (lr16(abase, s) != 0xffff && kind < T && i < AN && lr16(achk, i) == s) a = lr16(atab, i);
  if (!a) return false;
  if (a < 0x8000) return true;
  uintptr_t r = a - 0x8000, L = r < R ? lr16(rlen, r) : 0, k = L < no ? L : no;
  no -= k, L -= k;
  if (L >= d) return false;
  d -= L;
  uintptr_t A = lr16(rlhs, r), q = no ? ov[no - 1] : lr16(st, d - 1), j = A < N ? lr16(gbase, A) + q : GN;
  if (no == 64) return true;
  ov[no++] = j < GN && lr16(gchk, j) == A ? lr16(gtab, j) : lr16(gdef, A); }
 return true; }

static love_inline struct g *host_lr_run(struct g *g) {
 word t = g->sp[0], k = g->sp[1], c = g->sp[2], lk = g->sp[3];
 if (!strp(t) || len(t) < 12 || !strp(k) || len(k) & 1 || !strp(c) || len(c) < 10 || !charmp(lk) || getcharm(lk) < 0)
  return g->sp[0] = ZeroPoint, g;
 unsigned char const *h = (unsigned char const*) txt(t);
 uintptr_t T = lr16(h, 0), N = lr16(h, 1), S = lr16(h, 2), R = lr16(h, 3), AN = lr16(h, 4), GN = lr16(h, 5),
           d0 = lr32((unsigned char const*) txt(c) + 4);
 if (len(t) != 2 * (6 + 2 * R + 2 * S + 2 * N + 2 * AN + 2 * GN) || !T || d0 < 1 || d0 > 0xffffff || len(c) < 8 + 2 * d0)
  return g->sp[0] = ZeroPoint, g;
 uintptr_t most = 8 + 2 * (d0 + LrSteps) + 5 + 6 * LrSteps;
 if (!ok(g = have(g, str_width(most)))) return g;
 t = g->sp[0], k = g->sp[1], c = g->sp[2];
 h = (unsigned char const*) txt(t);
 unsigned char const *rlhs = h + 12, *rlen = rlhs + 2 * R, *dflt = rlen + 2 * R, *abase = dflt + 2 * S,
                     *gdef = abase + 2 * S, *gbase = gdef + 2 * N, *atab = gbase + 2 * N, *achk = atab + 2 * AN,
                     *gtab = achk + 2 * AN, *gchk = gtab + 2 * GN,
                     *K = (unsigned char const*) txt(k), *C = (unsigned char const*) txt(c);
 // the answer is laid where the nursery stands and bumped by its own size once known: the
 // states grow in place, the log runs at the far end and moves down behind them
 struct str *o = (struct str*) g->hp;
 unsigned char *b = (unsigned char*) o->bytes, *st = b + 8, *lg = st + 2 * (d0 + LrSteps) + 5;
 uintptr_t nk = len(k) / 2, pos = lr32(C), d = d0, look = (uintptr_t) getcharm(lk), n = 0, z = 0, steps = 0;
 memcpy(st, C + 8, 2 * d0);
 for (;; steps++) {
  if (steps == LrSteps) { z = 0; break; }
  uintptr_t s = lr16(st, d - 1), a, df = s < S ? lr16(dflt, s) : 0, kind = 0;
  if (s >= S) { z = 2; break; }
  a = df ? 0x8000 + df - 1 : 0;
  if (lr16(abase, s) != 0xffff) {
   kind = pos < nk ? lr16(K, pos) : 0;
   if (kind == 0xffff) {
    if (look == 0xffff) { z = 3; break; }
    if (look > 0xffff) look = lr_takes(h, st, d, look & 0xffff) ? look & 0xffff : (look >> 16) - 1;
    kind = look; }
   uintptr_t i = lr16(abase, s) + kind;
   if (kind < T && i < AN && lr16(achk, i) == s) a = lr16(atab, i); }
  if (!a) { z = 2; break; }
  if (a < 0x8000) {
   if (!kind) { z = 1; break; }   // a shift of $end is the accept
   lrput16(st + 2 * d++, a), pos++, look = 0xffff;
   continue; }
  uintptr_t r = a - 0x8000, L = r < R ? lr16(rlen, r) : d;
  if (L >= d) { z = 2; break; }
  d -= L;
  uintptr_t A = lr16(rlhs, r), q = lr16(st, d - 1), i = A < N ? lr16(gbase, A) + q : GN;
  lrput16(st + 2 * d++, i < GN && lr16(gchk, i) == A ? lr16(gtab, i) : lr16(gdef, A));
  lrput16(lg + 6 * n, r), lrput32(lg + 6 * n + 2, pos), n++; }
 uintptr_t at = 8 + 2 * d, m = at + 5 + 6 * n, w = str_width(m);
 lrput32(b, pos), lrput32(b + 4, d), b[at] = (unsigned char) z, lrput32(b + at + 1, n);
 memmove(b + at + 5, lg, 6 * n);
 memset(b + m, 0, (w - str_type_width) * sizeof(word) - m);
 o->ap = lvm_str, o->len = m, g->hp += w;
 return g->sp[0] = word(o), g; }
static lvm(lvm_lr_run) {
 LvmCallp(g, 3, host_lr_run) }

LvDef("run", lr_run, 4, "lr");
