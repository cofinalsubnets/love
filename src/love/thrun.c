// thrun.c -- a thread read back: thrun, the symbolic run of a thread ev wrote, which lamform
// prints and threadir hands the glaze. one translation unit of the runtime; the shared layouts
// and the cross-TU seam are src/love/love.h.
#include "love.h"

// (thrun p s ops cfg): a symbolic run of the thread at p, for post.l's threadir and lamform.
// every value pushed is a slot, a fresh mint, and the answer is (node . pairs), each pair
// (slot . node) saying how a slot was made -- or 0 for a thread ev does not write. s is the
// frame's slots, top first; ops 0, or the op names a reading may meet; cfg [names k a o c g
// cap cup two?], names a tablet from a nif to its name. it lays everything, answer and slot
// cells alike, by bumping g->hp up to lim; out of room, it is laid again in twice the room
struct thr {
 struct g *g;
 word ops, names, *cfg, *lim, pairs, node;            // node a return's
 word *s; intptr_t d;                                 // the slot list, its cells laid as garbage
 int full;                                            // past lim: the run is void
 union u *thene, *at; };                              // at: the join a stretch ended at
enum { ThrK = 1, ThrA, ThrO, ThrC, ThrG, ThrCap, ThrCup, ThrTwo };   // cfg's rows past names

static word *thr_take(struct thr *t, uintptr_t w) {
 struct g *g = t->g;
 if (t->full || g->hp + w > t->lim) return t->full = 1, (word*) 0;
 return g->hp += w, g->hp - w; }
static love_noinline word thr_cons(struct thr *t, word a, word b) {
 word *c = thr_take(t, Width(struct chain));
 return c ? word(ini_chain((struct chain*) c, a, b)) : ZeroPoint; }
static void thr_slot(struct thr *t, word y) {
 word *c = thr_take(t, 2);
 if (c) c[0] = y, c[1] = word(t->s), t->s = c; }
static love_noinline word thr_l3(struct thr *t, word a, word b, word c) {
 return thr_cons(t, a, thr_cons(t, b, thr_cons(t, c, ZeroPoint))); }
static love_noinline word thr_at(struct thr *t, intptr_t k) {        // (S k), () past the end
 for (word *n = t->s; n; n = (word*) n[1], k--) if (!k) return n[0];
 return ZeroPoint; }
static love_noinline void thr_drop(struct thr *t, intptr_t k) {
 for (; k > 0 && t->d > 0; k--, t->d--) if (t->s) t->s = (word*) t->s[1]; }
static word thr_tk(struct thr *t, word *n, intptr_t d, intptr_t k) { // the top k slots, top first
 if (k <= 0 || d <= 0) return ZeroPoint;
 return thr_cons(t, n ? n[0] : ZeroPoint, thr_tk(t, n ? (word*) n[1] : 0, d - 1, k - 1)); }
static love_noinline void thr_push(struct thr *t, word node) {
 word *m = thr_take(t, Width(struct mint)), y = m ? word(ini_missing((struct mint*) m, ++t->g->next_serial)) : ZeroPoint;
 thr_slot(t, y), t->d++;
 t->pairs = thr_cons(t, thr_cons(t, y, node), t->pairs); }
// the apply of the slot n down to the n above it, and ap1 of the one under the top to the top
static love_noinline word thr_apn(struct thr *t, intptr_t n) {
 return thr_cons(t, t->cfg[ThrA], thr_cons(t, thr_at(t, n), thr_cons(t, thr_tk(t, t->s, t->d, n), ZeroPoint))); }
static love_noinline int thr_want(struct thr *t, word nm) {
 if (!chainp(t->ops)) return 1;
 for (word l = t->ops; chainp(l); l = B(l)) if (A(l) == nm) return 1;
 return 0; }
// e lies past p, short of j, within the thread
static int thr_over(struct thr *t, union u *p, union u *j, union u *e) {
 for (union u *q = p, *end = cell(ttag(t->g, p)); q < end; q++) {
  if (q == e) return 1;
  if (q == j) return 0; }
 return 0; }
// a run of loads: 'a an arg operand, 'q a quote operand, '0'..'3' an immediate arg, and
// immediate quotes 'z' 'o' 't' 'h' 'm' 'n' (0 1 2 3 -1 -2); a trailing '+' carries the apply
static struct { lvm_t *op; char s[4]; } const thr_ldt[] = {
 {lvm_arg, "a"}, {lvm_quote, "q"}, {lvm_argap, "a+"}, {lvm_quoteap, "q+"},
 {lvm_aa, "aa"}, {lvm_aq, "aq"}, {lvm_qa, "qa"}, {lvm_qq, "qq"},
 {lvm_aap, "aa+"}, {lvm_aqp, "aq+"}, {lvm_qap, "qa+"}, {lvm_qqp, "qq+"},
 {lvm_arg0, "0"}, {lvm_arg1, "1"}, {lvm_arg2, "2"}, {lvm_arg3, "3"},
 {lvm_quo0, "z"}, {lvm_quo1, "o"}, {lvm_quo2, "t"}, {lvm_quo3, "h"}, {lvm_quom1, "m"}, {lvm_quom2, "n"} };
static int thr_run(struct thr *t, union u *p, union u *st);
// a cond: the then arm first, which finds the join if there is one; the else arm runs to it.
// answers as the run does: 0 fails, 1 returns t->node, 2 joins at t->at with t->s
static love_noinline int thr_branch(struct thr *t, word test, union u *a, union u *e, union u *st) {
 word *s0 = t->s; intptr_t d0 = t->d;
 union u *th = t->thene;
 t->thene = e;
 int k = thr_run(t, a, st);
 t->thene = th;
 if (k == 2) {
  union u *j = t->at;
  word top = thr_at(t, 0);
  t->s = s0, t->d = d0, t->thene = 0;
  k = thr_run(t, e, j);
  t->thene = th;
  if (k != 2) return 0;
  word c = thr_cons(t, t->cfg[ThrC], thr_cons(t, word(j), thr_l3(t, test, top, thr_at(t, 0))));
  t->s = s0, t->d = d0;
  thr_push(t, c);
  return thr_run(t, j, st); }
 if (k != 1) return 0;
 word n1 = t->node;
 t->s = s0, t->d = d0;
 if (thr_run(t, e, st) != 1) return 0;
 t->node = thr_cons(t, t->cfg[ThrC], thr_cons(t, putcharm(0), thr_l3(t, test, n1, t->node)));
 return 1; }
static int thr_run(struct thr *t, union u *p, union u *st) {
 struct g *g = t->g;
 for (;;) {
  if (t->full) return 0;
  if (p == st) return t->at = p, 2;
  if (!in_live_pool(g, ptr(p))) return 0;
  lvm_t *op = p->ap;
  char const *ld = 0;
  for (uintptr_t i = 0; i < countof(thr_ldt) && !ld; i++) if (thr_ldt[i].op == op) ld = thr_ldt[i].s;
  if (ld) {
   intptr_t i = 1;
   for (; *ld && *ld != '+'; ld++) {
    char c = *ld;
    intptr_t q = c == 'z' ? 0 : c == 'o' ? 1 : c == 't' ? 2 : c == 'h' ? 3 : c == 'm' ? -1 : -2;
    thr_push(t, c == 'a' ? thr_at(t, getcharm(p[i++].x))
              : c >= '0' && c <= '3' ? thr_at(t, c - '0')
              : thr_cons(t, t->cfg[ThrK], thr_cons(t, c == 'q' ? cellval(g, p[i++].x) : putcharm(q), ZeroPoint))); }
   if (*ld == '+') { word n = thr_apn(t, 1); thr_drop(t, 2), thr_push(t, n); }
   p += i;
   continue; }
  if (op == lvm_ret) return t->node = thr_at(t, 0), 1;
  if (op == lvm_argtap) thr_push(t, thr_at(t, getcharm(p[1].x)));
  if (op == lvm_tap || op == lvm_argtap) return t->node = thr_apn(t, 1), 1;
  if (op == lvm_rev) {                                // the top n slots, end for end
   intptr_t n = getcharm(p[1].x);
   for (intptr_t i = 0, j = n - 1; i < j; i++, j--) {
    word *a = t->s, *b = t->s;
    for (intptr_t k = 0; k < i && a; k++) a = (word*) a[1];
    for (intptr_t k = 0; k < j && b; k++) b = (word*) b[1];
    if (a && b) { word x = a[0]; a[0] = b[0], b[0] = x; } }
   p += 2;
   continue; }
  if (op == lvm_tapn || op == lvm_tapo) return t->node = thr_apn(t, getcharm(p[1].x)), 1;
  if (op == lvm_ap || op == lvm_apn || op == lvm_apo) {
   intptr_t n = op == lvm_ap ? 1 : getcharm(p[1].x);
   word a = thr_apn(t, n);
   thr_drop(t, n + 1), thr_push(t, a), p += op == lvm_ap ? 1 : 2;
   continue; }
  // a jump over the else arm ends a then arm at its join; any other is a cond the
  // compiler folded, its dead arm jumped over, and the reading goes on where it lands
  if (op == lvm_jump) {
   union u *j = p[1].m, *e = t->thene;
   if (j == st || (e && thr_over(t, p, j, e))) return t->at = j, 2;
   p = j;
   continue; }
  if (op == lvm_cond) { word x = thr_at(t, 0); thr_drop(t, 1); return thr_branch(t, x, p + 2, p[1].m, st); }
  if (op == lvm_argcond) return thr_branch(t, thr_at(t, getcharm(p[1].x)), p + 3, p[2].m, st);
  word f = op == lvm_argcap ? t->cfg[ThrCap] : op == lvm_argcup ? t->cfg[ThrCup]
         : op == lvm_argtwo || op == lvm_argtwocond ? t->cfg[ThrTwo] : 0;
  if (f) {
   if (!thr_want(t, f)) return 0;
   word n = thr_l3(t, t->cfg[ThrO], f, thr_cons(t, thr_at(t, getcharm(p[1].x)), ZeroPoint));
   if (op == lvm_argtwocond) return thr_branch(t, n, p + 3, p[2].m, st);
   thr_push(t, n), p += 2;
   continue; }
  if (op == lvm_index) {
   if (chainp(t->ops)) return 0;
   thr_push(t, thr_cons(t, t->cfg[ThrG], thr_cons(t, cellval(g, p[1].x), ZeroPoint))), p += 2;
   continue; }
  // a nif's body op: the cell's shape says its arity, and names says its name
  word const *k = (word const*) fn_nif((intptr_t) op);
  intptr_t n = !k ? 0 : k[1] == (word) lvm_ret0 && k[0] == (word) op ? 1
             : k[0] == (word) lvm_cur && k[3] == (word) lvm_ret0 && k[2] == (word) op ? getcharm(k[1]) : 0;
  word nm = n ? mapget(g, ZeroPoint, word(k), t->names) : ZeroPoint;
  if (nm == ZeroPoint || !thr_want(t, nm)) return 0;
  word o = thr_l3(t, t->cfg[ThrO], nm, thr_tk(t, t->s, t->d, n));
  thr_drop(t, n), thr_push(t, o), p += 1; } }
// thrun over its operands p s ops cfg (sp[0..3]), packed: the answer in sp[3] -- 0 for a
// thread ev does not write -- laid on the young heap. a run that ran out of room is given
// back, its mints' serials too, and run again in twice the room, which may collect
static struct g *thrun(struct g *g) {
 for (uintptr_t want = 0;; want = 2 * want + 64) {
  if (want && !ok(g = have(g, want))) return g;
  word *sp = g->sp, *hp0 = g->hp, cfgv[1 + ThrTwo];
  uintptr_t sn = g->next_serial;
  intptr_t nc = 0;
  for (word l = sp[3]; chainp(l) && nc <= ThrTwo; l = B(l)) cfgv[nc++] = A(l);
  int r = 0;
  word ans = 0;
  struct thr t = { g, sp[2], nc > ThrTwo ? cfgv[0] : 0, cfgv, g->sp, ZeroPoint, ZeroPoint, 0, 0, 0, 0, 0 };
  if (evenp(sp[0]) && nc > ThrTwo && tabp(cfgv[0])) {
   word *prev = 0;                                    // the frame's slots, in list order: the head the top
   for (word l = sp[1], *c; chainp(l) && (c = thr_take(&t, 2)); l = B(l), t.d++) {
    c[0] = A(l), c[1] = 0;
    if (prev) prev[1] = word(c); else t.s = c;
    prev = c; }
   r = thr_run(&t, cell(sp[0]), 0) == 1;
   if (r) ans = thr_cons(&t, t.node, t.pairs); }
  if (!t.full) {                                       // the operands stay as they were until the run fits
   if (r) sp[3] = ans;
   else g->hp = hp0, g->next_serial = sn, sp[3] = putcharm(0);
   return g->sp += 3, g; }
  want = (uintptr_t) (g->hp - hp0);
  g->hp = hp0, g->next_serial = sn; } }
LvmWrap(lvm_thrun, thrun)
