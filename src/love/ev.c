// ev.c -- ev, vm, the lisp help; the cross-TU seam is love.h
#include "love.h"
#if __STDC_HOSTED__
#include <sys/resource.h>   // getrlimit: c0_room
#endif
#if tco
#define status_yield status_ok
#else
#define status_yield status_eof
#endif
#define argn(nom, i) lvm(nom) { Have1(); Sp[-1] = Sp[i]; Sp -= 1; Ip += 1; love_musttail return Continue(); }
#define quon(nom, v) lvm(nom) { Have1(); Sp -= 1; Sp[0] = putcharm(v); Ip += 1; love_musttail return Continue(); }
#define Ana(n, ...) struct g *n(struct g *g, struct env **c, intptr_t x, ##__VA_ARGS__)
#define Cata(n, ...) struct g *n(struct g *g, struct env **c, ##__VA_ARGS__)
#define incl(e, n) ((e)->len += ((n)<<1))
#define Kp (g->ip)
#define cata1(n, ...) static Cata(n) { return __VA_ARGS__, pull(g, c); }
#define forget() (core_of(g)->root=(mm0),g)
static love_inline union u *clip(struct g *g, union u *k) {
 return tagthread(k, cell(ttag(g, k)) - k); }
struct env;
typedef Ana(ana);
typedef Cata(cata);
static Ana(ana_2, word a, word b);
static ana ana_c, ana_l, ana_q, ana_v, c0_cond_exit, c0_cond_r;
static Cata(c1_ar, lvm_t *i, word ar);
static cata c1, c1_apn, c1_cond_exit, c1_cond_pop_exit, c1_cur, c1_i,
            c1_ix, c1_recv, c1_ret, c1_var, c1_yield;
static love_noinline Ana(analyze);
static love_noinline word missing_tag(struct g *g);
static bool
 lambp(struct g *g, word x),
 lexbound(struct g *g, struct env *d, word x);
static lvm_t
 ap_next, help_ret_more, help_ret_scare, lvm_add_coin, lvm_coin_op, lvm_mul_coin,
 lvm_numap, lvm_numtap, lvm_resume;
static struct g
 *love_raise(struct g *c, word a, word b, union u const *K),
 *ana_ap(struct g *g, struct env **c, intptr_t x),
 *ana_ap_r2l(struct g *g, struct env **c, word x),
 *ana_d(struct g *g, struct env **b, word exp),
 *c0_i(struct g *g, struct env **c, lvm_t *i),
 *c0_ix(struct g *g, struct env **c, lvm_t *i, word x),
 *c0_lambda(struct g *g, struct env **c, intptr_t imps, intptr_t exp),
 *enscope(struct g *g, struct env *par, word args, word imps),
 *eset(struct g *g, struct env **c, int k, word v),
 *lbox(struct g *g),
 *ldels(struct g *g, word lam, word l),
 *lset(struct g *g, word y, int k, word v),
 *pushl(struct g*g),
 *rev(struct g *g, word l),
 *sset(struct g *g, word s, int k, word v);
static word
 assq(struct g *g, word l, word k),
 eget(struct g *g, struct env *e, int k),
 lget(struct g *g, word y, int k),
 memq(struct g *g, word l, word k),
 sget(struct g *g, word s, int k);
// ev
static love_inline struct g *pushl(struct g*g) { return intern(strof(g, "\\")); }
static love_noinline struct g *c0(struct g *g, lvm_t *y);
struct g *eval(struct g *g);

// a function's compile state
struct env {
 struct env *par; // enclosing scope
 word tab, // the mutable scope, a tablet keyed by the E* fixnums, as ev.l's (c 'stk) (c 'imp)
  len,     // thread length: a fixnum, so no store to it needs a barrier
  end[]; };

static Ana(ana_2, word, word);
static Cata(pull) { return ok(g) ? ((cata*) pop1(g))(g, c) : g; }

static love_inline struct g *c0_ix(struct g *g, struct env **c, lvm_t *i, word x) {
 return incl(*c, 2), push(g, 3, c1_ix, i, x); }

static love_inline struct g *c0_i(struct g *g, struct env **c, lvm_t *i) {
 return incl(*c, 1), push(g, 2, c1_i, i); }

// mapput barriers its own stores, so none of these writes needs one
// fars: a let's binding names, pinned before its lambdas compile
enum { EStack, EArgs, EImps, ELams, EBranch, EExit, ESites, EFars };
static love_inline word eget(struct g *g, struct env *e, int k) {
 return mapget(g, zero, putcharm(k), e->tab); }
static struct g *eset(struct g *g, struct env **c, int k, word v) {
 g = push(g, 3, putcharm(k), v, (*c)->tab);   // sp0 key, sp1 val, sp2 map
 if (ok(g = mapput(g))) g->sp++;           // mapput leaves the map: drop it
 return g; }
// a let's lambda entry is (name . box): the box holds the thread and imports, and backpatch
// and the capture fixpoint write through it, so it is a tablet, never a patched cons (ev.l's mkc)
enum { LThread, LImps };
// a backpatch site: the entry whose thread fills the hole, and the hole -- an interior pointer,
// since c1's clip re-points the terminator; gcp keeps its offset across a move
enum { SEntry, SCell };
static love_inline word sget(struct g *g, word s, int k) {
 return mapget(g, zero, putcharm(k), s); }
static struct g *sset(struct g *g, word s, int k, word v) {
 g = push(g, 3, putcharm(k), v, s);
 if (ok(g = mapput(g))) g->sp++;
 return g; }
static love_inline word lget(struct g *g, word y, int k) {
 return mapget(g, zero, putcharm(k), B(y)); }
static struct g *lset(struct g *g, word y, int k, word v) {   // y rooted: a growing put
 g = push(g, 3, putcharm(k), v, B(y));                       //   allocates
 if (ok(g = mapput(g))) g->sp++;
 return g; }
// sp0 c0_lambda's (thread . imports) -> a box of it, in its place
static struct g *lbox(struct g *g) {
 g = map_new(g);                                       // sp0 map, sp1 pair
 if (!ok(g)) return g;
 g = push(g, 3, putcharm(LThread), A(g->sp[1]), g->sp[0]);
 if (ok(g = mapput(g))) g->sp++;                 // back to sp0 map, sp1 pair
 if (!ok(g)) return g;
 g = push(g, 3, putcharm(LImps), B(g->sp[1]), g->sp[0]);
 if (ok(g = mapput(g))) g->sp++;
 if (!ok(g)) return g;
 return g->sp[1] = g->sp[0], g->sp++, g; }
static struct g *enscope(struct g *g, struct env *par, word args, word imps) {
 uintptr_t const n = Width(struct env) + Width(struct tag);
 g = push(g, 3, args, imps, par);
 g = map_new(g);                                   // sp0 = tab, then args/imps/par
 if (ok(g = have(g, n))) {
  struct env *c = bump(g, n);
  c->len = zero;
  c->tab = g->sp[0];
  c->par = (struct env*) g->sp[3];
  g->sp[3] = (word) tagthread((union u*)c, Width(struct env)); }   // env at sp3; tab/args/imps stay
 if (!ok(g)) return g;
 { struct env *e = (struct env*) g->sp[3];                     // re-read after every put: a
   g = eset(g, &e, EArgs, g->sp[1]);                           // grow inside mapput moves it
   if (ok(g)) e = (struct env*) g->sp[3], g = eset(g, &e, EImps, g->sp[2]); }
 return ok(g) ? (g->sp += 3, g) : g; }


static word memq(struct g *g, word l, word k) {
 for (; chainp(l); l = B(l)) if (eql(g, k, A(l))) return l;
 return 0; }

static word assq(struct g *g, word l, word k) {
 for (; chainp(l); l = B(l)) if (eql(g, k, AA(l))) return A(l);
 return 0; }

static struct g *append(struct g *g) {
 uintptr_t i = 0;
 for (word l; ok(g) && chainp(g->sp[0]); i++)
  l = B(g->sp[0]),
  g->sp[0] = A(g->sp[0]),
  g = push(g, 1, l);
 if (!ok(g)) return g;
 if (i == 0) return g->sp++, g;
 for (g->sp[0] = g->sp[i + 1]; i--; g = gxr(g));
 if (ok(g)) g->sp[1] = g->sp[0], g->sp++;
 return g; }

// the C stack a compile may take below its outermost frame: 3/4 of the host's rlimit, else love_cstack
static uintptr_t c0_room(void) {
 uintptr_t room = love_cstack;
#if __STDC_HOSTED__
 struct rlimit r;
 if (__love_osv >= 0 && !getrlimit(RLIMIT_STACK, &r))
  room = r.rlim_cur == RLIM_INFINITY ? 64u << 20 : r.rlim_cur / 4 * 3 > room ? (uintptr_t) (r.rlim_cur / 4 * 3) : room;
#endif
 return room; }

// noinline so callers can tail call
static love_noinline struct g *c0(struct g *g, lvm_t *y) {
 // the opfix prepass; a chain headed by a top is a constructed application, never source,
 // and skipping it ends the recursion through eval
 { word x0 = g->sp[0];
   if (chainp(x0) && (!evenp(A(x0)) || datp(A(x0)))) {
    word of = g->hook[hook_opfix];                      // sealed; zero mid-prel, where all is prefix
    if (evenp(of)) {
     g = eval(gxr(gxl(gxl(pushq(gxl(push(g, 4, x0, zero, zero, of)))))));
     if (!ok(g)) return g;
     g->sp[1] = g->sp[0], g->sp += 1; } } }
 if (!ok(g = enscope(g, (struct env*) zero, zero, zero))) return g;
 struct env *c = (void*) ptr(pop1(g));
 word x = g->sp[0];
 g->sp[0] = (word) c1_yield;
 mm(g, &c); mm(g, &x);
 char here;                                      // the floor is measured from the outermost compile
 uintptr_t base0 = g->cbase;
 if (!base0) g->cbase = (uintptr_t) &here, g->croom = c0_room();
 if (ok(g = analyze(g, &c, x)))
   g = c1(c0_ix(g, &c, y, word(g->ip)), &c);
 um(g), um(g);
 core_of(g)->cbase = base0;
 return g; }

static Cata(c1) {
 uintptr_t l = getcharm((*c)->len);
 g = have(g, l + Width(struct tag));
 if (ok(g)) {
  union u *k = bump(g, l + Width(struct tag));
  memset(k, -1, l * sizeof(word));
  Kp = tagthread(k, l) + l;
  if (ok(g = pull(g, c))) clip(g, Kp); }   // pull emits l words (may GC); Kp is the entry
 return g; }

static Cata(c1_yield) { return g; }

static Cata(c1_cond_pop_exit) { return
 g = eset(g, c, EExit, B(eget(g, *c, EExit))),
 pull(g, c); }

static Cata(c1_apn) {
 word arity = pop1(g);
 if (arity == putcharm(1)) {
  if (Kp[0].ap == lvm_ret) Kp[0].ap = lvm_tap;
  else Kp -= 1, Kp[0].ap = lvm_ap; }
 else {
  if (Kp[0].ap == lvm_ret) Kp -= 1, Kp[0].ap = lvm_tapn, Kp[1].x = arity;
  else Kp -= 2, Kp[0].ap = lvm_apn, Kp[1].x = arity; }
 return pull(g, c); }


static Cata(c1_i) {
 lvm_t *i = (void*) pop1(g);
 Kp -= 1;
 Kp[0].ap = i;
 return pull(g, c); }

static Cata(c1_ix) {
 lvm_t *i = (void*) pop1(g);
 word x = pop1(g);
 Kp -= 2;
 Kp[0].ap = i;
 Kp[1].x = x;
 gen_wb_cell(g, Kp + 1, x);
 return pull(g, c); }

// a recursive ref: `quote <thread>` if the closure is final, else `quote zero` and the cell
// stashed in the site for ana_d to backpatch
static Cata(c1_recv) {
 word y = pop1(g), site = pop1(g);
 Kp -= 2;
 Kp[0].ap = lvm_quote;
 if (zerop(site)) return
   Kp[1].x = lget(g, y, LThread), gen_wb_cell(g, Kp + 1, Kp[1].x), pull(g, c);
 { struct love_r *mm0 = g->root;                         // sset allocates
   mm(g, &site);
   Kp[1].x = zero;
   g = sset(g, site, SCell, (word) &Kp[1]);
   core_of(g)->root = mm0; }
 return pull(g, c); }

static Cata(c1_ar, lvm_t *i, word ar) { return
 Kp -= 2,
 Kp[0].ap = i,
 Kp[1].x = putcharm(ar),
 pull(g, c); }

static Cata(c1_cur) {
 struct env *e = (void*) pop1(g);
 uintptr_t ar = llen(eget(g, e, EArgs)) + llen(eget(g, e, EImps));
 return ar == 1 ? pull(g, c) : c1_ar(g, c, lvm_cur, ar); }

static Cata(c1_ret) {
 struct env *e = (struct env*) pop1(g);
 uintptr_t ar = llen(eget(g, e, EArgs)) + llen(eget(g, e, EImps));
 return c1_ar(g, c, lvm_ret, ar); }

cata1(c1_cond_push_branch, g = gxl(push(g, 2, Kp, eget(g, *c, EBranch))), g = eset(g, c, EBranch, ok(g) ? pop1(g) : zero))
cata1(c1_cond_push_exit, g = gxl(push(g, 2, Kp, eget(g, *c, EExit))), g = eset(g, c, EExit, ok(g) ? pop1(g) : zero))
cata1(c1_cond_pop_branch, Kp -= 2, Kp[0].ap = lvm_cond, Kp[1].x = A(eget(g, (*c), EBranch)),   // Kp[1] = a same-thread address: no cross-gen edge
      g = eset(g, c, EBranch, B(eget(g, *c, EBranch))))

static Cata(c1_cond_exit) {
 union u *a = cell(A(eget(g, (*c), EExit)));
 if (a->ap == lvm_ret || a->ap == lvm_tap)
  Kp = memcpy(Kp - 2, a, 2 * sizeof(*Kp));
 else if (a->ap == lvm_tapn)
  Kp = memcpy(Kp - 3, a, 3 * sizeof(*Kp));
 else
  Kp -= 2, Kp[0].ap = lvm_jump, Kp[1].x = (word) a;
 return pull(g, c); }

lvm(_lvm_yieldk) { return
 Ip = Ip[1].m,
 Pack(g),
 encode(g, status_yield); }


// no fault handler, by design: a hardware fault is a crash whose core names the site
struct g *eval(struct g *g) {
 if (!ok(g)) return g;                        // c0 reads g->sp[0] before any guard of its own
 g = c0(g, _lvm_yieldk);
#if tco
 if (ok(g)) {
#ifdef LvGcCheck
  g->unpacked = 1;                             // the registers hold hp and sp
#endif
  g = g->ip->ap(g, g->ip, g->hp, g->sp); }
 return g;
#else
 while (ok(g)) g = g->ip->ap(g);
 if (code_of(g) == status_eof) g = core_of(g);
 return g;
#endif
}

// EStack: a let's name for its slot, zero for one slot, a charm n > 0 for n operand slots in
// a row, so a walk costs the names, not the nesting
static uintptr_t es_n(word e) { return charmp(e) && getcharm(e) > 0 ? (uintptr_t) getcharm(e) : 1; }
static uintptr_t es_len(word s) { uintptr_t n = 0; for (; chainp(s); s = B(s)) n += es_n(A(s)); return n; }
static word es_idx(struct g *g, word x, word s) {     // the slots above x's
 word i = 0;
 for (; chainp(s); i += (word) es_n(A(s)), s = B(s)) if (eql(g, x, A(s))) return i;
 return -1; }
static struct g *es_push(struct g *g, struct env **c) {   // one operand slot more
 word s = eget(g, *c, EStack);
 bool run = chainp(s) && charmp(A(s)) && getcharm(A(s)) > 0;
 g = gxl(push(g, 2, putcharm(run ? getcharm(A(s)) + 1 : 1), run ? B(s) : s));
 return ok(g) ? eset(g, c, EStack, pop1(g)) : g; }
static struct g *es_pop(struct g *g, struct env **c, uintptr_t k) {   // k slots fewer
 word s = eget(g, *c, EStack);
 for (; k && chainp(s); s = B(s)) {
  uintptr_t n = es_n(A(s));
  if (n > k) {
   g = gxl(push(g, 2, putcharm(n - k), B(s)));
   return ok(g) ? eset(g, c, EStack, pop1(g)) : g; }
  k -= n; }
 return eset(g, c, EStack, s); }

static Ana(ana_v) {
 word y;
 if (!ok(g)) return g;
 for (struct env *d = *c;; d = d->par) {
  if (zerop(d)) {
   if ((y = stacklook(g, 0, x))) return ana_q(g, c, y);
   // an undefined global, lvm_index's at run time; captured only when nested, since at top
   // level imps would alias an uninitialized arg slot. x re-read: the push can GC
   if (!zerop((*c)->par))
    g = gxl(push(g, 2, x, eget(g, *c, EImps))),
    g = eset(g, c, EImps, ok(g) ? pop1(g) : zero),
    x = ok(g) ? A(eget(g, *c, EImps)) : zero;
   return c0_ix(g, c, lvm_index, x); }
  // a let's lambda
  if ((y = assq(g, eget(g, d, ELams), x))) {
   // not built yet: a backpatch site on d, the lams-owning scope
   word site = zero;
   if (zerop(lget(g, y, LThread))) {
    mm(g, &d), mm(g, &y);
    g = map_new(g);                                    // the site, at sp0
    if (ok(g)) g = sset(g, g->sp[0], SEntry, y);    // re-read sp0: a grow moves it
    if (ok(g)) g = sset(g, g->sp[0], SCell, zero);
    if (ok(g)) {
     g = gxl(push(g, 2, g->sp[0], eget(g, d, ESites)));
     if (ok(g)) g = eset(g, &d, ESites, pop1(g)), site = pop1(g); }
    um(g), um(g); }
   incl(*c, 2);
   if (ok(g = push(g, 3, c1_recv, y, site)))
    g = ana_ap(g, c, lget(g, g->sp[1], LImps));
   return g; }
  // a let binding in this scope: a direct stack slot
  if (d == *c && memq(g, eget(g, d, EStack), x)) return
    c0_ix(g, c, lvm_arg, putcharm(es_idx(g, x, eget(g, d, EStack))));
  // the shadow guard: d's let binds x (fars) before it is a lams entry or a slot, so the walk
  // must not escape to an enclosing binding of the same spelling
  if (!zerop(eget(g, d, EFars)) && memq(g, eget(g, d, EFars), x) &&
      !(!zerop(d->par) && memq(g, eget(g, d->par, EStack), x))) {
   if (!zerop((*c)->par))
    g = gxl(push(g, 2, x, eget(g, *c, EImps))),
    g = eset(g, c, EImps, ok(g) ? pop1(g) : zero),
    x = ok(g) ? A(eget(g, *c, EImps)) : zero;
   return c0_ix(g, c, lvm_index, x); }
  // a let binding, closure var or arg; from an enclosing scope, imported so c1_var's offset holds
  if (memq(g, eget(g, d, EStack), x) || memq(g, eget(g, d, EImps), x) || memq(g, eget(g, d, EArgs), x)) {
   incl(*c, 2);
   if (d != *c)
    g = gxl(push(g, 2, x, eget(g, *c, EImps))),
    g = eset(g, c, EImps, ok(g) ? pop1(g) : zero),
    x = ok(g) ? A(eget(g, *c, EImps)) : zero;
   return push(g, 3, c1_var, x, eget(g, *c, EStack)); } } }


static Cata(c1_var) {
 word v = pop1(g), i = (word) es_len(pop1(g)); // stack inset
 for (word l = eget(g, (*c), EImps); !zerop(l); l = B(l), i++)
  if (eql(g, v, A(l))) goto out;
 for (word l = eget(g, (*c), EArgs); !zerop(l); l = B(l), i++)
  if (eql(g, v, A(l))) break;
out:
 return Kp -= 2,
        Kp[0].ap = lvm_arg,
        Kp[1].x = putcharm(i),
        pull(g, c); }

// a compile past its room of C stack scares (deep (used room)) before the stack runs out
static love_noinline bool c0_deep(struct g *g) {
 char here;
 struct g *c = core_of(g);
 return c->cbase && c->cbase > (uintptr_t) &here && c->cbase - (uintptr_t) &here > c->croom; }
static love_noinline struct g *c0_scare(struct g *g) {
 char here;
 struct g *c = core_of(g);
 intptr_t used = (intptr_t) (c->cbase - (uintptr_t) &here), room = (intptr_t) c->croom;
 g = intern(strof(g, "deep"));
 g = gxl(push(g, 2, putcharm(room), ZeroPoint));
 g = gxr(gxl(push(g, 1, putcharm(used))));
 if (ok(g)) g->scare_c = pop1(g);
 return encode(core_of(g), status_scare); }

static love_noinline Ana(analyze) {
 if (!ok(g)) return g;
 if (c0_deep(g)) return c0_scare(g);
 if (nomp(x) && x != ZeroPoint) return ana_v(g, c, x);
 if (!chainp(x)) return ana_q(g, c, x); // non-chains are self quoting
 word a = A(x), b = B(x);
 struct str *nm;                             // a special form: a 1-char named head (\ : ?)
 if (chainp(b) && (nm = nom_str(g, a)) && len(nm) == 1)  // with no operand it is (f) == f
  switch (*txt(nm)) {
   case '\\': return ana_l(g, c, b);
   case ':': return ana_d(g, c, b);
   case '?': return ana_c(g, c, b); }
 return ana_2(g, c, x, a, b); }


// nom p -> m over x, quoted data kept -> the result on sp0
static struct g *subst1(struct g *g, word x, word p, word m) {
 if (!ok(g)) return g;
 if (c0_deep(g)) return c0_scare(g);
 if (x == p) return push(g, 1, m);
 if (!chainp(x)) return push(g, 1, x);
 { struct str *nm; word a = A(x);
   if (nomp(a) && (nm = nom_str(g, a)) && len(nm) == 1 && *txt(nm) == '\\' &&
       chainp(B(x)) && !chainp(BB(x))) return push(g, 1, x); }   // (\ q): a quote is data
 struct love_r *mm0 = g->root;
 mm(g, &x); mm(g, &p); mm(g, &m);
 g = subst1(g, A(x), p, m);
 g = subst1(g, B(x), p, m);
 core_of(g)->root = mm0;
 return gxr(g); }

static struct g *c0_lambda(struct g *g, struct env **c, intptr_t imps, intptr_t exp) {
 union u *k, *ip;
 struct env *d = NULL;
 // imps rooted too: the rename loop allocates
 mm(g, &d); mm(g, &exp); mm(g, &imps);

 // a param shadowing an enclosing binder renames to a fresh mint over the whole operand list:
 // ana_d applies captures by name, and a shadow would hand a site its own value (ev.l's cplam)
 for (bool again = true; again && ok(g);) {
  again = false;
  for (word e = exp; chainp(e) && chainp(B(e)); e = B(e)) {
   word p = A(e), hit = 0; struct str *nm;
   if (!nomp(p) || ((nm = nom_str(g, p)) && len(nm) == 1 && *txt(nm) == '_')) continue;
   for (struct env *d2 = *c; !hit && !zerop(d2); d2 = d2->par)
    hit = memq(g, eget(g, d2, EArgs), p) || memq(g, eget(g, d2, EFars), p)
       || memq(g, eget(g, d2, EStack), p);
   if (!hit) continue;
   mm(g, &p);
   g = have(g, Width(struct mint));
   if (ok(g)) {
    struct mint *y = (struct mint*) bump(g, Width(struct mint));
    ini_missing(y, ++g->next_serial);
    g = subst1(g, exp, p, word(y)); }
   um(g);
   if (ok(g)) exp = pop1(g), again = true;
   break; } }

 g = enscope(g, *c, exp, imps);

 if (ok(g)) {
  d = (struct env*) pop1(g);
  exp = eget(g, d, EArgs);
  int n = 0;
  for (; chainp(B(exp)); exp = B(exp), n++) g = push(g, 1, A(exp));
  for (g = push0(g); n--; g = gxr(g));
  exp = A(exp); }

 if (ok(g)) {
  g = eset(g, &d, EArgs, g->sp[0]);
  g->sp[0] = (word) c1_yield;
  incl(d, 4);
  g = push(g, 2, c1_cur, d);
  g = analyze(g, &d, exp);
  if (ok(g = push(g, 2, c1_ret, d)))
    ip = g->ip,
    avec(g, ip, g = c1(g, &d)); }

 if (ok(g)) k = g->ip, g->ip = ip, g = gxl(push(g, 2, k, eget(g, d, EImps)));

 return um(g), um(g), um(g), g; }

static Ana(c0_cond_exit) { return
 incl(*c, 3),
 push(analyze(g, c, x), 1, c1_cond_exit); }

static Ana(c0_cond_r) { return
 !chainp(x) ? c0_cond_exit(g, c, ZeroPoint) :   // the implicit else: ()
 !chainp(B(x)) ? c0_cond_exit(g, c, A(x)) :
 (avec(g, x,
  incl(*c, 2),
  g = analyze(g, c, A(x)),
  g = push(g, 1, c1_cond_pop_branch),
  g = c0_cond_exit(g, c, AB(x)),
  g = push(g, 1, c1_cond_push_branch),
  g = c0_cond_r(g, c, BB(x))), g); }


static struct g *ana_ap_r2l(struct g *g, struct env **c, word x);
static struct g *ana_ap(struct g *g, struct env **c, intptr_t x) {
 if (!ok(g)) return g;
 // the quoted cell is read as a nif's code, so it must be a static nif, never heap: on wasm a
 // function pointer is a small index, and `[1].ap == lvm_ret0` would hold of '(3 ..)
 bool imfp =
  g->sp[0] == (word) c1_ix &&
  g->sp[1] == (word) lvm_quote &&
  evenp(g->sp[2]) && !in_data(cell(g->sp[2])->ap) && !in_heap(g, g->sp[2]);
 intptr_t
  ca = llen(x),
  va =
   imfp && cell(g->sp[2])->ap == lvm_cur ?
    getcharm(cell(g->sp[2])[1].x) :
    1;
 bool b1p = ca == 1 && imfp && cell(g->sp[2])[1].ap == lvm_ret0,
      anp = va == ca && ca > 1,
      bnp = anp && cell(g->sp[2])[3].ap == lvm_ret0;

 if (b1p) {
  lvm_t *i = cell(g->sp[2])->ap;
  g->sp += 3;
  g = c0_i(analyze(g, c, A(x)), c, i);
  return g; }

 if (bnp) { // a curried instruction
  lvm_t *i = cell(g->sp[2])[2].ap;
  g->sp += 3;
  g = c0_i(ana_ap_r2l(g, c, x), c, i);
  if (ok(g)) g = es_pop(g, c, (uintptr_t) ca);
  return g; }

 g = push(g, 1, x);
 if (ok(g = es_push(g, c))) {
  x = pop1(g), mm(g, &x);
  if (anp) { // r2l 1 n-ary ap
   g = ana_ap_r2l(g, c, x),
   incl(*c, 2),
   g = push(g, 2, c1_apn, putcharm(ca));
   if (ok(g)) g = es_pop(g, c, (uintptr_t) ca); }
  else while (chainp(x)) // l2r n 1-ary ap
   g = analyze(g, c, A(x)),
   incl(*c, 2),
   g = push(g, 2, c1_apn, putcharm(1)),
   x = B(x);
  um(g), g = es_pop(g, c, 1); }

 return g; }


static struct g *ana_ap_r2l(struct g *g, struct env **c, word x) {
 if (ok(g) && c0_deep(g)) return c0_scare(g);
 if (chainp(x)) {
  word y = A(x);
  avec(g, y, g = ana_ap_r2l(g, c, B(x)));
  g = analyze(g, c, y);
  if (ok(g)) g = es_push(g, c); }
 return g; }

static love_inline bool lambp(struct g *g, word x) {
 struct str *n;
 return chainp(x) && chainp(B(x)) && chainp(B(B(x))) &&
  (n = nom_str(g, A(x))) && len(n) == 1 && txt(n)[0] == '\\'; }

// onto a fresh spine, the source never written
static struct g *rev(struct g *g, word l) {          // -> the reversed copy, pushed
 struct love_r *mm0 = core_of(g)->root;
 mm(g, &l);
 g = push(g, 1, zero);
 for (; ok(g) && chainp(l); l = B(l)) g = gxl(push(g, 1, A(l)));
 return forget(); }

static struct g *ldels(struct g *g, word lam, word l);

// a lexically bound nom shadows a macro (ev.l's wx/cprop twin); binders only, since imps
// may record undefined globals
static bool lexbound(struct g *g, struct env *d, word x) {
 for (; !zerop(d); d = d->par)
  if (memq(g, eget(g, d, EArgs), x) || memq(g, eget(g, d, EStack), x) ||
      memq(g, eget(g, d, EFars), x) || assq(g, eget(g, d, ELams), x)) return true;
 return false; }

static love_inline Ana(ana_2, word a, word b) {
 if (nomp(a) && (x = stacklook_macro(core_of(g), a)) && !lexbound(g, *c, a)) {  // the scope walk only on a macro hit
  g = push(g, 1, b);                             // the operands, held over the expansion
  g = eval(gxr(gxl(gxl(pushq(gxl(push(g, 4, b, zero, zero, x)))))));
  // the expansion takes the opfix prepass, with c0's guard; the operands came in factored,
  // so the pass keeps them whole: (of '(e . operands))
  word e = ok(g) ? g->sp[0] : 0, of = core_of(g)->hook[hook_opfixp];
  if (chainp(e) && (!evenp(A(e)) || datp(A(e))) && evenp(of)) {
   g = eval(gxr(gxl(gxl(pushq(gxl(gxl(push(g, 5, e, g->sp[1], zero, zero, of))))))));
   if (ok(g)) g->sp[2] = g->sp[0], g->sp += 2; }
  else if (ok(g)) g->sp[1] = g->sp[0], g->sp += 1;
  return analyze(g, c, ok(g) ? pop1(g) : 0); }
 if (!chainp(b)) return analyze(g, c, a);  // (f) == f, below the macro lane
 return avec(g, b, g = analyze(g, c, a)),
        ana_ap(g, c, b); }

love_inline Ana(ana_q) { return c0_ix(g, c, lvm_quote, x); }
static love_inline Ana(ana_l) {
  if (!chainp(B(x))) return ana_q(g, c, A(x)); // one operand, no params: quote
  return g = c0_lambda(g, c, zero, x),
         analyze(g, c, ok(g) ? pop1(g) : 0); }
static Ana(c0_cond_r);
static love_inline Ana(ana_c) {
 return !chainp(B(x)) ? analyze(g, c, A(x)) :
    (g = push(g, 2, x, c1_cond_pop_exit),
     g = c0_cond_r(g, c, ok(g) ? pop1(g) : zero),
     push(g, 1, c1_cond_push_exit)); }
// the let form: sequential and recursive binding
static love_inline struct g *ana_d(struct g *g, struct env **b, word exp) {
 if (!chainp(B(exp))) return analyze(g, b, A(exp));
 struct love_r *mm0 = core_of(g)->root;
 mm(g, &exp);
 // the letrec*-value rewrite is prel.l's boxfix once it exists, shared with ev.l's feel
 if (ok(g = intern(strof(g, "boxfix")))) {
  word bf = stacklook(g, 0, pop1(g));
  if (bf && evenp(bf)) {
   g = eval(gxr(gxl(gxl(pushq(gxl(push(g, 4, exp, zero, zero, bf)))))));
   if (ok(g)) exp = pop1(g); } }
 g = enscope(g, *b, eget(g, (*b), EArgs), eget(g, (*b), EImps));
 if (!ok(g)) return forget();
 struct env *q = (struct env*) pop1(g), **c = &q;
 word nom = zero, def = zero, ndef = zero, lam = zero,
      v = zero, d = zero, e = zero, os = zero;
 mm(g, &nom), mm(g, &def), mm(g, &ndef), mm(g, &lam);
 mm(g, &d); mm(g, &e); mm(g, &v); mm(g, &q); mm(g, &os);

 // the binding names pinned before any lambda compiles, or a walk resolves an inner nom to an
 // enclosing sibling and under-applies (ev.l avb's 'far guard)
 for (d = exp; chainp(d) && chainp(B(d)); d = BB(d)) {
  for (e = A(d); chainp(e) && !nomp(e); e = A(e)); // (f x..) define-sugar to the name
  g = gxl(push(g, 2, e, eget(g, q, EFars)));
  if (!ok(g)) return forget();
  g = eset(g, &q, EFars, pop1(g)); }

 // vars and defs, each earlier binding exposed on the enclosing stack so a sibling ref
 // captures rather than reading a same-named global; restored before emission
 os = eget(g, *b, EStack);
 while (chainp(exp) && chainp(B(exp))) {
  for (d = A(exp), e = AB(exp); chainp(d) && !nomp(d); e = pop1(g), d = A(d)) {  // a named sym is a chain: stop at it
   g = gxl(push(g, 2, e, zero));
   g = append(gxl(pushl(push(g, 1, B(d)))));
   if (!ok(g)) return forget(); }
  g = gxl(push(g, 2, d, nom));
  g = gxl(push(g, 2, e, def));
  if (!ok(g)) return forget();
  def = pop1(g), nom = pop1(g);
  if (lambp(g, e)) {
   g = push(g, 2, d, lam);
   g = gxl(gxr(lbox(c0_lambda(g, c, zero, B(e)))));
   if (!ok(g)) return forget();
   lam = pop1(g); }
  g = gxl(push(g, 2, d, eget(g, *b, EStack)));
  g = eset(g, b, EStack, ok(g) ? pop1(g) : zero);
  exp = BB(exp); }
 g = eset(g, b, EStack, os);

 intptr_t l = llen(nom);
 bool oddp = chainp(exp),
      globp = !oddp && zerop(eget(g, (*b), EArgs)); // top level: global bindings
 if (!oddp) { // no body: the last definition's name
  g = gxl(push(g, 2, A(nom), zero));
  if (!ok(g)) return forget();
  exp = pop1(g); }

 // the capture fixpoint: if e needs d then e needs d's variables
 word j, vars, var;
 do for (j = 0, d = lam; chainp(d); d = B(d))
  for (e = lam; chainp(e); e = B(e)) if (d != e)
   if (memq(g, lget(g, A(e), LImps), AA(d)))
    for (v = lget(g, A(d), LImps); chainp(v); v = B(v))
     if (!memq(g, vars = lget(g, A(e), LImps), var = A(v)))
      j++,
      g = gxl(push(g, 2, var, vars)),
      g = lset(g, A(e), LImps, ok(g) ? pop1(g) : zero);
 while (j);

 // the defined functions leave the import lists: bound lazily when the function runs
 for (e = lam; ok(g) && chainp(e); e = B(e)) {
  g = ldels(g, lam, lget(g, A(e), LImps));
  if (ok(g)) g = lset(g, A(e), LImps, pop1(g)); }

 g = eset(g, c, ELams, lam);
 g = append(gxl(pushl(push(g, 2, nom, exp))));

 if (!ok(g)) return forget();
 exp = pop1(g);

 // the provisional closures cleared, so a ref mid-rebuild takes a backpatch site rather than
 // the stale closure; the imports kept
 for (d = lam; ok(g) && chainp(d); d = B(d)) g = lset(g, A(d), LThread, zero);

 // ndef: def with each closure for its source, consed over the reversed def into literal order
 for (e = nom, v = def; ok(g) && chainp(e); e = B(e), v = B(v)) {
  word nv;
  if (lambp(g, A(v))) {
   d = assq(g, lam, A(e));
   size_t nb = llen(lget(g, d, LImps)); // frozen: sites already applied it
   g = c0_lambda(g, c, lget(g, d, LImps), BA(v));
   if (!ok(g)) return forget();
   g = lset(g, d, LThread, A(g->sp[0]));        // the pair stays on the stack: either
   if (ok(g)) g = lset(g, d, LImps, B(g->sp[0]));   // put can move it
   if (!ok(g)) return forget();
   if (llen(lget(g, d, LImps)) != nb) __builtin_trap(); // growth: those sites under-apply (ev.l's 'imports-grew)
   nv = g->sp[0], g->sp++; }
  else nv = A(v);
  g = gxl(push(g, 2, nv, ndef));
  if (ok(g)) ndef = pop1(g); }
 if (!ok(g)) return forget();

 // closures final: backpatch each recursive ref
 for (d = eget(g, (*c), ESites); chainp(d); d = B(d)) {
  union u *hole = cell(sget(g, A(d), SCell));
  hole->x = lget(g, sget(g, A(d), SEntry), LThread), gen_wb_cell(g, hole, hole->x); }
 g = eset(g, c, ESites, zero);

 g = rev(g, nom);   // literal order
 if (!ok(g)) return forget();
 nom = pop1(g);
 g = analyze(g, b, exp);
 g = gxl(push(g, 2, zero, e = eget(g, *b, EStack)));
 g = eset(g, b, EStack, ok(g) ? pop1(g) : zero);
 for (def = ndef; chainp(nom); nom = B(nom), def = B(def))
  g = analyze(g, b, A(def)),
  g = globp && !mintp(A(nom)) ? c0_ix(g, b, lvm_defglob, A(nom)) : g,   // a `_` row (opfix's fresh nom) never reaches the book
  g = gxl(push(g, 2, A(nom), eget(g, *b, EStack))),
  g = eset(g, b, EStack, ok(g) ? pop1(g) : zero);
 return
  g = eset(g, b, EStack, e),
  incl(*b, 2),
  g = push(g, 2, c1_apn, putcharm(l)),
  forget(); }

// the bound functions dropped from an import list, onto a fresh spine, tail first
static struct g *ldels(struct g *g, word lam, word l) {
 if (!ok(g)) return g;
 if (!chainp(l)) return push(g, 1, zero);
 struct love_r *mm0 = g->root;
 mm(g, &lam), mm(g, &l);
 g = ldels(g, lam, B(l));
 if (ok(g) && !assq(g, lam, A(l))) g = gxl(push(g, 1, A(l)));
 return forget(); }

lvm(lvm_defglob) {
 Have(3);
 Sp -= 3;
 word k = Ip[1].x, v = Sp[3];
 Sp[0] = k, Sp[1] = v, Sp[2] = A(g->stack), Pack(g);          // into the head layer
 if (!ok(g = mapput(g))) love_musttail return Ap(_lvm_ghelp, g);
 Unpack(g), Sp += 1, Ip += 2;
 love_musttail return Continue(); }

lvm(lvm_eval) { Ip++; LvmResume(g, c0, lvm_jump) }

// vm
// the hooks (love.h): lisp the C lanes reach by slot, from (seal-hook n f); an unsealed one traps
word hot_hook(word h) { if (!evenp(h)) __builtin_trap(); return h; }

// numap_drive [ap, ap_next, ret0] runs a hook over [n, hook, x, ret]: a fixnum applied, or
// + and * of functions. each ap_next applies the partial to one more curried argument
static lvm(ap_next) {
 word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t;
 love_musttail return Ap(lvm_ap, g); }
union u const numap_drive[] = { {lvm_ap}, {.ap = ap_next}, {.ap = lvm_ret0} };
// ..and over four arguments, for hook_obin: [k hook as bs sh ret]
union u const obin_drive[] = { {lvm_ap}, {.ap = ap_next}, {.ap = ap_next}, {.ap = ap_next}, {.ap = lvm_ret0} };

// the glaze's call-out: a native blob lays [arg, clos, RET] and tail-jumps here, so a deep
// callee grows the VM stack, never the C stack
union u const callout_drive[] = { {lvm_ap}, {.ap = lvm_ret0} };
// a probe; a native reaches the drive through g->reach
lvm(lvm_calloutdrive) { love_musttail return Answer(putcharm((intptr_t) callout_drive)); }
// the walkable resume [arg, clos, charm(bb - entry), entry]: an odd offset the walk skips and
// the blob's out-of-pool base, never a stack-interior pointer gcp would be fed
union u const callout_resume[] = { {lvm_ap}, {.ap = lvm_resume} };
lvm(lvm_calloutresume) { love_musttail return Answer(putcharm((intptr_t) callout_resume)); }
// (sortby le l): a merge sort handing each compare back to the VM. values ride two object
// trays, the cursors the stack as charms (the comparator may collect); stable when le answers 1 on ties
enum { sb_va = 1, sb_vb, sb_w, sb_lo, sb_x, sb_y, sb_o, sb_hi, sb_n, sb_pend, sb_le, sb_k };   // off Sp; Sp[0] = the answer, sb_k the caller's next op
// sb_pend: () before the first compare, 1 with an answer waiting, sb_done once merged -- a
// collection at the spine's reservation re-enters the step, which must not re-run a pass
#define sb_done putcharm(2)
static lvm_t sortby_step;
static union u const sortby_drive[] = { {lvm_ap}, {.ap = ap_next}, {.ap = sortby_step} };
static union u const sortby_text[] = { {.ap = sortby_step} };
static struct g *sortby_setup(struct g *g) {
 uintptr_t n = (uintptr_t) love_count(g, g->sp[1]), words = b2w(tray_bytes(love_O, 1, n));
 if (!ok(g = have(g, 2 * words + sb_k + 1))) return g;
 word le = g->sp[0], l = g->sp[1];                                  // re-read past the reservation
 struct tray *a = (struct tray*) g->hp; g->hp += words; ini_tray(a, love_O, 1); a->shape[0] = n;
 struct tray *b = (struct tray*) g->hp; g->hp += words; ini_tray(b, love_O, 1); b->shape[0] = n;
 uintptr_t i = 0;
 for (word p = l; chainp(p); p = B(p)) tray_put_obj(a, i++, A(p));
 for (i = 0; i < n; i++) tray_put_obj(b, i, zero);
 word k = word(g->ip + 1);                                            // a nif runs inline: the caller's next op
 g->sp -= sb_k - 1;                                                   // [le l ..] -> [ans state.. le k ..]
 word *s = g->sp;
 s[0] = zero, s[sb_va] = word(a), s[sb_vb] = word(b);
 s[sb_w] = putcharm(1), s[sb_lo] = putcharm(0), s[sb_x] = putcharm(0), s[sb_y] = putcharm(min(1, n));
 s[sb_o] = putcharm(0), s[sb_hi] = putcharm(min(2, n)), s[sb_n] = putcharm(n), s[sb_pend] = zero, s[sb_le] = le, s[sb_k] = k;
 g->ip = (union u*) sortby_text;
 return g; }
static lvm(sortby_step) {
 uintptr_t n = getcharm(Sp[sb_n]), w = getcharm(Sp[sb_w]), lo = getcharm(Sp[sb_lo]),
           x = getcharm(Sp[sb_x]), y = getcharm(Sp[sb_y]), o = getcharm(Sp[sb_o]), hi = getcharm(Sp[sb_hi]),
           m = min(lo + w, n);
 if (Sp[sb_pend] == sb_done) goto spine;
 if (Sp[sb_pend] != zero) {                                          // (le a[x] a[y]): the left when true
  if (__builtin_expect(!leafp(Sp[0]), 0)) love_musttail return Ap(lvm_measure, g);   // a compound answer: measured, then the step again
  bool left = !leaf_nilp(Sp[0]);
  word v = tray_get_obj(tray(Sp[sb_va]), left ? x++ : y++);
  tray_put_obj(tray(Sp[sb_vb]), o++, v);
  gen_wb(g, Sp[sb_vb], v); }                                         // b may have aged under the comparator
 for (;;) {
  if (x < m && y < hi) {                                             // the next compare
   word xv = tray_get_obj(tray(Sp[sb_va]), x), yv = tray_get_obj(tray(Sp[sb_va]), y);
   Sp[sb_w] = putcharm(w), Sp[sb_lo] = putcharm(lo), Sp[sb_hi] = putcharm(hi);
   Sp[sb_x] = putcharm(x), Sp[sb_y] = putcharm(y), Sp[sb_o] = putcharm(o), Sp[sb_pend] = putcharm(1);
   word le = Sp[sb_le];
   union u *k = oddp(le) ? 0 : cell(le);
   if (k && k[0].ap == lvm_cur && k[1].x == putcharm(2)) {         // arity two: [x y ret] straight into its body
    Sp -= 2, Sp[0] = xv, Sp[1] = yv, Sp[2] = word(sortby_drive + 2);
    Ip = k + 2;
    love_musttail return Continue(); }
   Sp -= 2, Sp[0] = xv, Sp[1] = le, Sp[2] = yv;                    // anything else curries through the drive
   Ip = (union u*) sortby_drive;
   love_musttail return Continue(); }
  while (x < m) { word v = tray_get_obj(tray(Sp[sb_va]), x++); tray_put_obj(tray(Sp[sb_vb]), o++, v); gen_wb(g, Sp[sb_vb], v); }
  while (y < hi) { word v = tray_get_obj(tray(Sp[sb_va]), y++); tray_put_obj(tray(Sp[sb_vb]), o++, v); gen_wb(g, Sp[sb_vb], v); }
  lo += 2 * w;
  if (lo >= n) {                                                     // a pass done: the runs swap trays and double
   word t = Sp[sb_va]; Sp[sb_va] = Sp[sb_vb], Sp[sb_vb] = t;
   w *= 2, lo = 0;
   if (w >= n) break; }
  x = o = lo, m = min(lo + w, n), y = m, hi = min(lo + 2 * w, n); }
 Sp[sb_pend] = sb_done;
spine:
 Have(n * Width(struct chain));                                    // the spine, from the sorted tray (re-read post-GC)
 struct tray *a = tray(Sp[sb_va]);
 struct chain *spine = (struct chain*) Hp;
 Hp += n * Width(struct chain);
 for (uintptr_t i = 0; i < n; i++) ini_chain(spine + i, tray_get_obj(a, i), word(spine + i + 1));
 spine[n - 1].b = ZeroPoint;
 Ip = (union u*) Sp[sb_k];
 Sp += sb_k;                                                          // [ans state.. le k ..] -> [spine ..]
 Sp[0] = word(spine);
 love_musttail return Continue(); }
lvm(lvm_sortby) {
 word l = Sp[1];
 if (nomp(l) || !chainp(l) || !chainp(B(l))) love_musttail return Push(l);   // under two elements: the list itself
 LvmResume(g, sortby_setup) }

// a raise calls (help a b) through help_drive; help_ret_more hands the result to the raise site's
// [resume a b], so (scare a b) and `missing` resume; a bare scare is observed, then escapes to C
static lvm(help_ret_more) {   // [result resume a b ..] -> resume sees result
 Ip = cell(Sp[1]);
 Sp[3] = Sp[0];
 Sp += 3;
 love_musttail return Continue(); }
static lvm(help_ret_scare) {  // result ignored: scares are not (yet) resumable
 return Pack(g), encode(g, status_scare); }
static union u const help_more_k[] = { {help_ret_more} };
static union u const help_scare_k[] = { {help_ret_scare} };
static union u const help_drive[] =
 { {lvm_ap}, {.ap = ap_next}, {.ap = lvm_ret0} };

// with nothing heard, or still too tight after a collect, the scare goes back to C. callers
// Pack first; a/b ride the scare_a/b stash across the collect
love_noinline static struct g *love_raise(struct g *c, word a, word b, union u const *K) {
 c->scare_a = a, c->scare_b = b;  // for the exit face
 word h = *task_help(c);
 if (h != ZeroPoint && avail(c) < 4) {
  struct g *p = please(c, 4);
  if (!ok(p)) return encode(core_of(p), status_scare);
  c = p;                                        // moved: re-derive
  a = c->scare_a, b = c->scare_b;
  h = *task_help(c); }
 if (h != ZeroPoint && avail(c) >= 4) {
  word *sp = c->sp -= 4;          // [a h b K | raise site data ..]
  sp[0] = a, sp[1] = h;
  sp[2] = b;
  sp[3] = word(K);
  c->ip = (union u*) help_drive;
#if tco
  return c->ip->ap(c, c->ip, c->hp, c->sp);
#else
  return c;                       // ok-g: the trampoline dispatches help_drive
#endif
 }
 return encode(c, status_scare);
}
// a failed op's scare: the reason a C lane left, else bare; terminal
lvm(_lvm_ghelp) {
 struct g *c = core_of(g);
 word r = c->scare_c;                          // (tag . datum), or zero
 c->scare_c = zero;
 return love_raise(c, chainp(r) ? A(r) : zero, chainp(r) ? B(r) : zero, help_scare_k); }
// a wait nothing could wake: terminal. the tag may collect, so it is minted packed
static love_noinline word deadlock_tag(struct g *g) {
 struct g *h = intern(strof(g, "deadlock"));
 return ok(h) ? pop1(h) : 0; }
lvm(lvm_deadlock) {
 Pack(g);
 word a = deadlock_tag(g);
 if (!a) love_musttail return Ap(_lvm_ghelp, g);
 return love_raise(g, a, zero, help_scare_k); }
// (scare a b): the help's result is its value; with nothing heard, terminal
lvm(lvm_scare) {
 Have1();                          // the resume push only: love_raise buys its own frame
 word a = Sp[0], b = Sp[1];
 *--Sp = word(Ip + 1);             // [resume a b ..]: help_more_k's layout
 return Pack(g), love_raise(g, a, b, help_more_k); }
// a name bound to zero is distinct from no entry
static union u const no_entry[1];
struct g *ioputs(struct g*, char const*),
                 *ioputc(struct g*, int);
struct g *zflush(struct g*);
// may collect: Pack first and hold no heap local across it -> the tag, or 0
static love_noinline word missing_tag(struct g *g) {
 struct g *h = intern(strof(g, "missing"));
 return ok(h) ? pop1(h) : 0; }

// the live book by name, never self-patching. a miss raises (help 'missing nom); with nothing
// heard it reads ZeroPoint, a point not a quantity, so (i love you) = 1
lvm(lvm_index) {
 Have1();                          // may GC: no live local yet
 word v = stacklook(g, word(no_entry), Ip[1].x);
 if (v != word(no_entry)) return
  *--Sp = v,
  Ip += 2,
  Continue();
 word h = *task_help(g);
 if (h == ZeroPoint) {
#if __STDC_HOSTED__
  // nothing heard: ";; missing <nom>" on err. nom_str and ioput* do not collect
  struct str *nm = nom_str(g, Ip[1].x);
  if (nm) { struct io *sv = g->io; g->io = &love_stderr.io;
            g = ioputs(g, ";; missing ");
            for (uintptr_t i = 0; ok(g) && i < nm->len; i++) g = ioputc(g, nm->bytes[i]);
            g = core_of(zflush(ioputc(g, '\n')));  // best effort: a failed write stays off g
            g->io = sv; }
#endif
  *--Sp = ZeroPoint; love_musttail return Next(2); }
 Pack(g);
 word a = missing_tag(g);          // may collect
 if (!a) love_musttail return Ap(_lvm_ghelp, g);   // no tag to be had: the bare scare, still packed
 Unpack(g);
 Have(3);                          // a collect here re-dispatches the op: `a` is never read stale
 word b = Ip[1].x;
 Sp -= 3;
 Sp[0] = word(Ip + 2), Sp[1] = a, Sp[2] = b;   // help_more_k's layout
 return Pack(g), love_raise(g, a, b, help_more_k); }
// the fused aps leave Ip on an operand, where a plain Have() would re-dispatch: gc and re-Ap
#define NumapHave(self) if (Sp < Hp + 2) { \
 Pack(g); g = please(g, 2); if (!ok(g)) love_musttail return Ap(_lvm_ghelp, g); \
 Unpack(g); love_musttail return Ap(self, g); }
static lvm(lvm_numap) {
 NumapHave(lvm_numap);
 word h = hot_hook(g->hook[hook_numap]);
 word n = Sp[1], x = Sp[0], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = n, dst[1] = h, dst[2] = x, dst[3] = ret;
 Sp = dst; Ip = (union u*) numap_drive; love_musttail return Continue(); }
static lvm(lvm_numtap) {
 NumapHave(lvm_numtap);
 word h = hot_hook(g->hook[hook_numap]);
 word fs = getcharm(Ip[1].x), n = Sp[1], x = Sp[0], *dst = &Sp[fs + 2] - 3, ret = Sp[fs + 2];
 dst[0] = n, dst[1] = h, dst[2] = x, dst[3] = ret;
 Sp = dst; Ip = (union u*) numap_drive; love_musttail return Continue(); }

// (seal-hook n f): hook n, behind the lambda gate; -1 the task's help and -2 its stdio skip it.
// any other n traps
lvm(lvm_seal) {
 intptr_t n = getcharm(Sp[0]);
 if (n >= 0 && n < hook_n) {
  if (!evenp(Sp[1])) __builtin_trap();
  g->hook[n] = Sp[1]; }
 else {
  Pack(g);                        // the barrier reads g->hp
  if (n == -1) *task_help(g) = Sp[1], gen_wb_cell(g, task_help(g), Sp[1]);
  else if (n == -2) *task_io(g) = chainp(Sp[1]) ? Sp[1] : ZeroPoint, gen_wb_cell(g, task_io(g), *task_io(g));   // anything but a chain hands the console back
  else __builtin_trap(); }
 Sp += 1, Sp[0] = zero, Ip += 1;
 love_musttail return Continue(); }

// + and * over a lambda: the combinator partial through numap_drive. Ip is at the re-runnable
// opcode, so a plain Have is safe
lvm(lvm_addh) {
 if (coinp(Sp[0]) || coinp(Sp[1])) love_musttail return Ap(lvm_add_coin, g);
 Have(2);
 word h = hot_hook(g->hook[hook_arrange]);
 word fa = Sp[0], ga = Sp[1], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = fa, dst[1] = h, dst[2] = ga, dst[3] = ret;
 Sp = dst; Ip = (union u*) numap_drive; love_musttail return Continue(); }
lvm(lvm_mulh) {
 if (coinp(Sp[0]) || coinp(Sp[1])) love_musttail return Ap(lvm_mul_coin, g);
 Have(2);
 word h = hot_hook(g->hook[hook_compose]);
 word fa = Sp[0], ga = Sp[1], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = fa, dst[1] = h, dst[2] = ga, dst[3] = ret;
 Sp = dst; Ip = (union u*) numap_drive; love_musttail return Continue(); }

// coin +/*/-//: the kind's method over the raw operands; two kinds, or no method, answer ().
// Ap keeps Ip on the opcode, so word(Ip + 1) is the return
static lvm(lvm_coin_op) {
 intptr_t slot = g->b;                              // the kind slot, off the scratch
 word a = Sp[0], b = Sp[1];
 if (coinp(a) && coinp(b) && coin_kind(a) != coin_kind(b))
  love_musttail return Push(ZeroPoint);
 word f = kind_get(g, coinp(a) ? coin_kind(a) : coin_kind(b), slot);
 if (f == ZeroPoint) love_musttail return Push(ZeroPoint);
 Have(2);
 a = Sp[0], b = Sp[1];                              // re-read post-GC
 f = kind_get(g, coinp(a) ? coin_kind(a) : coin_kind(b), slot);
 word *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = a, dst[1] = f, dst[2] = b, dst[3] = ret;
 Sp = dst; Ip = (union u*) numap_drive; love_musttail return Continue(); }
static lvm(lvm_add_coin) { g->b = (word) (KnAdd); love_musttail return Ap(lvm_coin_op, g); }
static lvm(lvm_mul_coin) { g->b = (word) (KnMul); love_musttail return Ap(lvm_coin_op, g); }
// lvm_sub and lvm_quot intercept coins themselves
lvm(lvm_sub_coin) { g->b = (word) (KnSub); love_musttail return Ap(lvm_coin_op, g); }
lvm(lvm_quot_coin) { g->b = (word) (KnDiv); love_musttail return Ap(lvm_coin_op, g); }

// a coin applied: ((f self) arg) by the kind's ap, else () -- self is Ip, the applied object
lvm(lvm_coin) {
 if (kind_get(g, coin_kind(word(Ip)), KnApply) == ZeroPoint) {
  Ip = cell(*++Sp); *Sp = ZeroPoint; love_musttail return Continue(); }
 Have(2);
 word self = word(Ip), f = kind_get(g, coin_kind(self), KnApply);
 word arg = Sp[0], ret = Sp[1], *dst = Sp - 2;
 dst[0] = self, dst[1] = f, dst[2] = arg, dst[3] = ret;
 Sp = dst; Ip = (union u*) numap_drive; love_musttail return Continue(); }

// (strike kind payload) -> a fresh coin of the kind over the payload.
lvm(lvm_coinmk) {
 Have(Width(struct coin) + Width(struct tag));
 union u *k = (union u*) Hp;
 Hp += Width(struct coin) + Width(struct tag);
 ((struct coin*) k)->ap = lvm_coin;
 ((struct coin*) k)->kind = Sp[0];
 ((struct coin*) k)->payload = Sp[1];
 tagthread(k, Width(struct coin));
 love_musttail return Push(word(k)); }
// (load x) -> a coin's payload, else x
lvm(lvm_load) {
 Sp[0] = coinp(Sp[0]) ? coin_load(Sp[0]) : Sp[0];
 love_musttail return Next(1); }
// (kind x) -> the kind's nom off g->kinds, refined in the hot row: a coin's own name or coin,
// else lambda, cask, port
lvm(lvm_kind) {
 word x = Sp[0], n = ZeroPoint;
 if (coinp(x)) { n = kind_get(g, coin_kind(x), KnName); if (n == ZeroPoint) n = g->knom[KnCoin]; }
 else if (caskp(x)) n = g->knom[KnCask];
 else if (iop(x)) n = g->knom[KnPort];
 else if (kind(x) == KHot) n = g->knom[KnLambda];
 if (n == ZeroPoint) Pack(g), n = mapget(g, zero, putcharm(kind(x)), g->kinds);   // packed: the probe's walks use the free room
 Sp[0] = n;
 love_musttail return Next(1); }
op11(lvm_coinp, coinp(Sp[0]) ? putcharm(1) : zero)   // a struck coin, not the rest of the hot row

lvm(lvm_ap) {
 union u *k;
 if (oddp(Sp[1])) love_musttail return Ap(lvm_numap, g);
 k = cell(Sp[1]), Sp[1] = word(Ip + 1), Ip = k;
 YieldCheck();
 love_musttail return Continue(); }

// tail call
lvm(lvm_tap) {
 if (oddp(Sp[1])) love_musttail return Ap(lvm_numtap, g);
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getcharm(Ip[1].x) + 1;
 Ip = cell(j), Sp[0] = x;
 YieldCheck();
 love_musttail return Continue(); }

// the callee must be a cur of exactly n: the compiler's width is a guess about a name, so a
// miss scares rather than entering a non-function past its prologue
static bool apn_ok(word f, size_t n) {
 return evenp(f) && cell(f)[0].ap == lvm_cur && cell(f)[1].x == putcharm(n); }

lvm(lvm_apn) {
 size_t n = getcharm(Ip[1].x);
 union u *r = Ip + 2;
 if (!apn_ok(Sp[n], n)) return Pack(g), love_raise(g, zero, zero, help_scare_k);
 Ip = cell(Sp[n]) + 2;                    // FIXME: past the cur; the compiler should skip it
 Sp[n] = word(r);
 YieldCheck();
 love_musttail return Continue(); }

// tail call
lvm(lvm_tapn) {
 size_t n = getcharm(Ip[1].x),
        r = getcharm(Ip[2].x);
 if (!apn_ok(Sp[n], n)) return Pack(g), love_raise(g, zero, zero, help_scare_k);
 Ip = cell(Sp[n]) + 2;
 word *o = Sp;
 for (Sp += r + 1; n--; Sp[n] = o[n]);
 YieldCheck();
 love_musttail return Continue(); }

lvm(lvm_ret) {
 word n = getcharm(Ip[1].x) + 1;
 Ip = cell(Sp[n]); Sp[n] = Sp[0]; Sp += n; love_musttail return Continue(); }

lvm(lvm_ret0) { return
 Ip = cell(Sp[1]),
 Sp[1] = Sp[0],
 Sp += 1,
 Continue(); }
// [result, charm(bb - entry), entry]: the result to Sp[0], then the blob's resume label.
// Ip is dead across a call-out, the blobs keep theirs in a Sp slot
static lvm(lvm_resume) {
 lvm_t *t = (lvm_t*) (Sp[2] + ((word) Sp[1] >> 1));
 Sp[2] = Sp[0];
 Sp += 2;
 love_musttail return Ap(t, g); }

// kcall : x = Sp[0], k = Ip[1] -> Ip = k, Sp[0] = x
lvm(lvm_kcall) {
 word x = Sp[0];
 union u *stack = Ip + 2, *end = (union u*) ttag(g, stack);
 uintptr_t height = end - stack;
 Have(height);
 *(Sp = memmove(topof(g) - height, stack, height * sizeof(word))) = x;
 Ip = Ip[1].m;
 love_musttail return Continue(); }

// callk : i = Sp[0], k = Ip + 1 -> Ip = i, Sp[0] = k
lvm(lvm_callk) {
 word f_val = Sp[0];                         // the call_cc arg
 if (oddp(f_val)) love_musttail return Next(1);
 word height = topof(g) - Sp;
 uintptr_t n = 2 + height;                   // lvm_kcall, ip + 1, the stack
 Have(n + Width(struct tag) + 1);
 union u *k = (union u*) Hp;
 Hp += n + Width(struct tag);
 k[0].ap = lvm_kcall;
 k[1].m  = Ip + 1;
 memcpy(k + 2, Sp, height * sizeof(word));
 Sp -= 1;
 Sp[0] = word(tagthread(k, n));
 Sp[1] = f_val;
 love_musttail return Ap(lvm_ap, g); }



lvm(lvm_jump) { Ip = Ip[1].m; love_musttail return Continue(); }
// the only compiled truthiness branch (`?`, `&&`, `||`): a compound is measured
lvm(lvm_cond) {
 word x = Sp[0];
 if (charmp(x)) { Ip = getcharm(x) <= 0 ? Ip[1].m : Ip + 2; Sp += 1; love_musttail return Continue(); }
 if (!leafp(x)) love_musttail return Ap(lvm_measure, g);
 Ip = leaf_nilp(*Sp++) ? Ip[1].m : Ip + 2; love_musttail return Continue(); }
lvm(lvm_unc) {
 Have1();
 *--Sp = Ip[1].x;
 Ip = Ip[2].m;
 love_musttail return Continue(); }

lvm(lvm_cur) {
 size_t const S = 3 + Width(struct tag);
 Have(S + 2);
 union u *k = (union u*) Hp, *j = k;
 Hp += S;
 size_t n = getcharm(Ip[1].x);
 // FIXME: not always a runtime check
 if (n > 2) Hp += 2,
            j += 2,
            k[0].ap = lvm_cur,
            k[1].x = putcharm(n - 1);
 return
  j[0].ap = lvm_unc,
  j[1].x = *Sp++,
  j[2].m = Ip + 2,
  Ip = cell(*Sp),
  Sp[0] = (word) tagthread(k, j + 3 - k),
  Continue(); }

lvm(lvm_quote) {
 Have1();
 Sp -= 1;
 Sp[0] = Ip[1].x;
 Ip += 2;
 love_musttail return Continue(); }

// a port applied answers 1, as 0 does; the cask's twin body, kept apart by noicf
lvm(lvm_port_io) {
  Ip = cell(*++Sp);
  *Sp = putcharm(1);
  love_musttail return Continue(); }

lvm(lvm_arg) {
 Have1();
 Sp[-1] = Sp[getcharm(Ip[1].x)];
 Sp -= 1;
 Ip += 2;
 love_musttail return Continue(); }

// fused (arg <idx> ; ap); resume Ip+2
lvm(lvm_argap) {
 if (__builtin_expect(oddp(Sp[0]), 0)) {              // a fixnum operator: num-ap
  Have1();
  Sp[-1] = Sp[getcharm(Ip[1].x)], Sp -= 1, Ip += 1;   // so numap's Ip+1 resumes at Ip+2
  love_musttail return Ap(lvm_numap, g); }
 Have1();
 Sp[-1] = Sp[getcharm(Ip[1].x)];
 Sp -= 1;
 union u *k = cell(Sp[1]); Sp[1] = word(Ip + 2), Ip = k;
 YieldCheck();
 love_musttail return Continue(); }

// fused (quote <v> ; ap); resume Ip+2
lvm(lvm_quoteap) {
 if (__builtin_expect(oddp(Sp[0]), 0)) {
  Have1();
  Sp[-1] = Ip[1].x, Sp -= 1, Ip += 1;
  love_musttail return Ap(lvm_numap, g); }
 Have1();
 Sp -= 1;
 Sp[0] = Ip[1].x;
 union u *k = cell(Sp[1]); Sp[1] = word(Ip + 2), Ip = k;
 YieldCheck();
 love_musttail return Continue(); }

// fused (arg <idx> ; tap <fs>)
lvm(lvm_argtap) {
 if (__builtin_expect(oddp(Sp[0]), 0)) {
  Have1();
  Sp[-1] = Sp[getcharm(Ip[1].x)], Sp -= 1, Ip += 1;   // fs now at Ip[1]
  love_musttail return Ap(lvm_numtap, g); }
 Have1();
 Sp[-1] = Sp[getcharm(Ip[1].x)];
 Sp -= 1;
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getcharm(Ip[2].x) + 1;
 Ip = cell(j), Sp[0] = x;
 YieldCheck();
 love_musttail return Continue(); }

// 1-word arg and quote ops for the hottest operands
argn(lvm_arg0, 0) argn(lvm_arg1, 1) argn(lvm_arg2, 2) argn(lvm_arg3, 3)
quon(lvm_quo0, 0) quon(lvm_quo1, 1) quon(lvm_quo2, 2) quon(lvm_quo3, 3)
quon(lvm_quom1, -1) quon(lvm_quom2, -2)

// run fusion: one op per run of loads, named in source order (a arg, q quote, p a final apply);
// each index is relative to its own load's Sp, as pushing left to right gives
#define PushA(k) (Sp[-1] = Sp[getcharm(Ip[k].x)], Sp -= 1)
#define PushQ(k) (Sp[-1] = Ip[k].x, Sp -= 1)
#define frun2(nom, p1, p2) lvm(nom) { Have(2); p1(1); p2(2); Ip += 3; love_musttail return Continue(); }
// the operator is what the first load pushed, so the fixnum test sits between; Ip += 2 lands
// numap's Ip+1 past the op
#define frun2p(nom, p1, p2) lvm(nom) { \
 Have(2); p1(1); \
 if (__builtin_expect(oddp(Sp[0]), 0)) { p2(2); Ip += 2; love_musttail return Ap(lvm_numap, g); } \
 p2(2); \
 union u *k = cell(Sp[1]); Sp[1] = word(Ip + 3), Ip = k; \
 YieldCheck(); \
 love_musttail return Continue(); }
frun2(lvm_aa, PushA, PushA) frun2(lvm_aq, PushA, PushQ)
frun2(lvm_qa, PushQ, PushA) frun2(lvm_qq, PushQ, PushQ)
frun2p(lvm_aap, PushA, PushA) frun2p(lvm_aqp, PushA, PushQ)
frun2p(lvm_qap, PushQ, PushA) frun2p(lvm_qqp, PushQ, PushQ)
// load + consumer fusion: arg with the accessor, predicate or branch that eats it, the
// corpus's commonest consumers. the parameter is not `x`, which would hit Ip[1].x
#define fld(nom, val) lvm(nom) { Have1(); word v = Sp[getcharm(Ip[1].x)]; Sp[-1] = (val); Sp -= 1; Ip += 2; love_musttail return Continue(); }
fld(lvm_argcap, chainp(v) ? A(v) : v)
fld(lvm_argcup, chainp(v) ? B(v) : ZeroPoint)
fld(lvm_argtwo, (chainp(v) && !nomp(v)) ? putcharm(1) : zero)
// arg + cond: [Ip]=argcond [Ip+1]=idx [Ip+2]=else [Ip+3]=then. a compound is measured
// as [x measure land op], landing at [ans op ..]
static lvm(lvm_argcond_land) {
 Ip = cell(Sp[1]);
 Ip = leaf_nilp(Sp[0]) ? Ip[2].m : Ip + 3;
 Sp += 2; love_musttail return Continue(); }
static union u const argcond_land[] = { {.ap = lvm_argcond_land} };
lvm(lvm_argcond) {
 word x = Sp[getcharm(Ip[1].x)];
 if (__builtin_expect(!charmp(x) && !leafp(x), 0)) {
  Have(4);
  word *dst = Sp - 4;
  dst[0] = Sp[getcharm(Ip[1].x)], dst[1] = hot_hook(g->hook[hook_net]), dst[2] = word(argcond_land), dst[3] = word(Ip);
  Sp = dst; Ip = (union u*) callout_drive; love_musttail return Continue(); }
 Ip = leaf_nilp(x) ? Ip[2].m : Ip + 3; love_musttail return Continue(); }
// load + predicate + cond, `(? (two? b) ..)`: [Ip]=op [Ip+1]=idx [Ip+2]=else
#define fldc(nom, test) lvm(nom) { word v = Sp[getcharm(Ip[1].x)]; \
 Ip = (test) ? Ip + 3 : Ip[2].m; love_musttail return Continue(); }
fldc(lvm_argtwocond, chainp(v) && !nomp(v))            // two? answers a charm: no leaf_nilp needed

// the cell doors: peek/poke move values, pick/place instructions, so no code address reaches
// love (pick answers an op index). a wrong cell is safe and meaningless; only bounds are checked
// a terminator: 2 mod 4 into a live pool, which no pointer, charm or instruction is (thumb's
// are odd, wasm's 8 apart)
static love_inline bool termp(struct g *g, word x) {
 return (x & 3) == thread_tag && in_live_pool(g, (word const*) (x & ~(word) 3)); }

lvm(lvm_trim) {
 if (evenp(Sp[0])) clip(g, cell(Sp[0]));
 return Ip++, Continue(); }

// (seek i v): the cell i away, or () past the object. up crosses out at a terminator; down,
// where the object below may not be a thread, is held to v's own head
lvm(lvm_seek) {
 intptr_t i = getcharm(Sp[0]);
 word v = Sp[1], r = ZeroPoint;
 if (evenp(v)) {
  union u *b = cell(v), *e = b + i;
  if (!in_live_pool(g, ptr(b))) r = word(e);       // a static nif: no terminator to ask
  else if (in_live_pool(g, ptr(e))) {
   union u *p = i < 0 ? e : b + 1, *q = i < 0 ? b : e + 1;
   while (p < q && !termp(g, p->x)) p++;
   if (p == q && (i >= 0 || e >= tag_head(ttag(g, b)))) r = word(e); } }
 return Sp[1] = r, Sp++, Ip++, Continue(); }

// (stem v): the head of v's object, which a lambda's value hides behind a leading source
// cell. (span v): the cells from v to the terminator. both () off the heap
lvm(lvm_stem) { return
 Sp[0] = evenp(Sp[0]) && in_heap(g, Sp[0]) ? word(tag_head(ttag(g, cell(Sp[0])))) : ZeroPoint,
 Ip++, Continue(); }

lvm(lvm_span) { return
 Sp[0] = evenp(Sp[0]) && in_heap(g, Sp[0])
  ? putcharm(cell(ttag(g, cell(Sp[0]))) - cell(Sp[0])) : ZeroPoint,
 Ip++, Continue(); }

lvm(lvm_peek) {
 word w = evenp(Sp[1]) ? (cell(Sp[1]) + getcharm(Sp[0]))->x : ZeroPoint;
 return Sp[1] = cellval(g, w), Sp++, Ip++, Continue(); }

// (pick i v): the instruction at cell i as its op index, () where a value sits
lvm(lvm_pick) {
 word w = evenp(Sp[1]) ? (cell(Sp[1]) + getcharm(Sp[0]))->x : ZeroPoint;
 intptr_t j = op_index((intptr_t) w);
 return Sp[1] = j < 0 ? ZeroPoint : putcharm(j),
 Sp++, Ip++, Continue(); }

lvm(lvm_poke) {
 if (!evenp(Sp[2])) { *(Sp += 2) = ZeroPoint; love_musttail return Next(1); }
 union u *c = cell(Sp[2]) + getcharm(Sp[0]);
 Pack(g);                    // young reads g->hp, which the live Hp may be ahead of
 if (termp(g, c->x)) { *(Sp += 2) = ZeroPoint; love_musttail return Next(1); }  // never over the wall
 gen_wb_cell(g, c, Sp[1]);   // the cell is in a tagged span, never a chain's field
 c->x = Sp[1]; *(Sp += 2) = word(c); love_musttail return Next(1); }

// (place i c v): instruction c into cell i, barriered as poke is
lvm(lvm_place) {
 intptr_t a = charmp(Sp[1]) ? op_resolve(getcharm(Sp[1])) : 0;   // an index is a charm, always
 if (!evenp(Sp[2]) || !a) { *(Sp += 2) = ZeroPoint; love_musttail return Next(1); }
 union u *c = cell(Sp[2]) + getcharm(Sp[0]);
 Pack(g);
 if (termp(g, c->x)) { *(Sp += 2) = ZeroPoint; love_musttail return Next(1); }
 gen_wb_cell(g, c, (word) a);
 c->x = (word) a; *(Sp += 2) = word(c); love_musttail return Next(1); }

lvm(lvm_spin) {
 size_t n = getcharm(Sp[0]);
 Have(n + Width(struct tag));
 union u *k = (union u*) Hp;
 Hp += n + Width(struct tag);
 Sp[0] = word(memset(tagthread(k, n), -1, n * sizeof(word)));
 love_musttail return Next(1); }
