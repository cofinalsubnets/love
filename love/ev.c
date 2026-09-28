// ev.c -- ev, vm, the lisp help. one translation unit of the runtime;
// the shared layouts and the cross-TU seam are love/love.h.
#include "love.h"
#if ai_tco
#define ai_status_yield ai_status_ok
#else
#define ai_status_yield ai_status_eof
#endif
#define argn(nom, i) lvm(nom) { Have1(); Sp[-1] = Sp[i]; Sp -= 1; Ip += 1; ai_musttail return Continue(); }
#define quon(nom, v) lvm(nom) { Have1(); Sp -= 1; Sp[0] = putcharm(v); Ip += 1; ai_musttail return Continue(); }
#define Ana(n, ...) struct ai *n(struct ai *g, struct env **c, intptr_t x, ##__VA_ARGS__)
#define Cata(n, ...) struct ai *n(struct ai *g, struct env **c, ##__VA_ARGS__)
#define incl(e, n) ((e)->len += ((n)<<1))
#define Kp (g->ip)
#define cata1(n, ...) static Cata(n) { return __VA_ARGS__, pull(g, c); }
#define forget() (ai_core_of(g)->root=(mm0),g)
static ai_inline union u *clip(struct ai *g, union u *k) {
 return tagthread(k, cell(ttag(g, k)) - k); }
struct env;
typedef Ana(ana);
typedef Cata(cata);
static Ana(ana_2, word a, word b);
static ana ana_c, ana_l, ana_q, ana_v, c0_cond_exit, c0_cond_r;
static Cata(c1_ar, lvm_t *i, word ar);
static cata c1, c1_apn, c1_cond_exit, c1_cond_pop_exit, c1_cur, c1_i,
            c1_ix, c1_recv, c1_ret, c1_var, c1_yield;
static ai_noinline Ana(analyze);
static ai_noinline word missing_tag(struct ai *g);
static bool
 lambp(struct ai *g, word x),
 lexbound(struct ai *g, struct env *d, word x);
static lvm_t
 ap_next, help_ret_more, help_ret_scare, lvm_add_coin, lvm_coin_op, lvm_mul_coin,
 lvm_numap, lvm_numtap, lvm_resume;
static struct ai
 *ai_raise(struct ai *c, word a, word b, union u const *K),
 *ana_ap(struct ai *g, struct env **c, intptr_t x),
 *ana_ap_r2l(struct ai *g, struct env **c, word x),
 *ana_d(struct ai *g, struct env **b, word exp),
 *c0_i(struct ai *g, struct env **c, lvm_t *i),
 *c0_ix(struct ai *g, struct env **c, lvm_t *i, word x),
 *c0_lambda(struct ai *g, struct env **c, intptr_t imps, intptr_t exp),
 *enscope(struct ai *g, struct env *par, word args, word imps),
 *eset(struct ai *g, struct env **c, int k, word v),
 *lbox(struct ai *g),
 *ldels(struct ai *g, word lam, word l),
 *lset(struct ai *g, word y, int k, word v),
 *pushl(struct ai*g),
 *rev(struct ai *g, word l),
 *sset(struct ai *g, word s, int k, word v);
static word
 assq(struct ai *g, word l, word k),
 eget(struct ai *g, struct env *e, int k),
 lget(struct ai *g, word y, int k),
 lidx(struct ai*g, word x, word l),
 memq(struct ai *g, word l, word k),
 sget(struct ai *g, word s, int k);
// ============================================================================
// ev
// ============================================================================
static ai_inline struct ai *pushl(struct ai*g) { return intern(ai_strof(g, "\\")); }
static ai_noinline struct ai *c0(struct ai *g, lvm_t *y);
struct ai *ai_eval(struct ai *g);

// function state using this type
struct env {
 struct env *par; // enclosing scope
 word tab, // the mutable scope, keyed by the E* fixnums: positional and closure variables,
           //   the stack of computed args and let bindings, the let's lambdas, the cond
           //   branch and exit addresses, the backpatch sites, and fars, the binding names pinned before a let's lambdas compile. ev.l's
           //   own scope is a tablet read the same way -- (c 'stk), (c 'imp), (c 'lam).
  len,     // thread length accumulator: a fixnum, so no store to it needs a barrier
  end[]; };

static Ana(ana_2, word, word);
static Cata(pull) { return ai_ok(g) ? ((cata*) pop1(g))(g, c) : g; }

// generic instruction ana aps
static ai_inline struct ai *c0_ix(struct ai *g, struct env **c, lvm_t *i, word x) {
 return incl(*c, 2), ai_push(g, 3, c1_ix, i, x); }

static ai_inline struct ai *c0_i(struct ai *g, struct env **c, lvm_t *i) {
 return incl(*c, 1), ai_push(g, 2, c1_i, i); }

// the scope's mutable fields ride a tablet, the way ev.l's own scope does ((c 'stk),
// (c 'imp), ..). ai_mapput barriers its own stores, so none of these writes carries a
// barrier of its own -- the hand-kept invariant retires with them.
enum { EStack, EArgs, EImps, ELams, EBranch, EExit, ESites, EFars };
static ai_inline word eget(struct ai *g, struct env *e, int k) {
 return ai_mapget(g, zero, putcharm(k), e->tab); }
static struct ai *eset(struct ai *g, struct env **c, int k, word v) {
 g = ai_push(g, 3, putcharm(k), v, (*c)->tab);   // sp0 key, sp1 val, sp2 map
 if (ai_ok(g = ai_mapput(g))) g->sp++;           // mapput leaves the map: drop it
 return g; }
// a let's lambda entry is (name . box). the box holds the closure's thread and its
// import row, and both a backpatch site and the capture fixpoint write THROUGH it, so
// the shared mutable cell is a real heap object rather than a cons somebody patches --
// ev.l's closure cell is the same thing (mkc/cof/cput, a tablet under key 0).
enum { LThread, LImps };
// a backpatch site is a box too: the entry whose thread fills the hole, and the hole.
// the hole is an interior pointer and has to be -- c1's clip re-points the terminator
// at the entry once emission ends, so the head this cell was indexed from is no longer
// the thread's, and no base available here stays one. gcp relocates an interior pointer
// into a thread by preserving its offset, which is what carries this across a move.
enum { SEntry, SCell };
static ai_inline word sget(struct ai *g, word s, int k) {
 return ai_mapget(g, zero, putcharm(k), s); }
static struct ai *sset(struct ai *g, word s, int k, word v) {
 g = ai_push(g, 3, putcharm(k), v, s);
 if (ai_ok(g = ai_mapput(g))) g->sp++;
 return g; }
static ai_inline word lget(struct ai *g, word y, int k) {
 return ai_mapget(g, zero, putcharm(k), B(y)); }
static struct ai *lset(struct ai *g, word y, int k, word v) {   // y must be rooted: a
 g = ai_push(g, 3, putcharm(k), v, B(y));                       //   growing put allocates
 if (ai_ok(g = ai_mapput(g))) g->sp++;
 return g; }
// sp0 is c0_lambda's (thread . imports); answers a box carrying it, in its place
static struct ai *lbox(struct ai *g) {
 g = map_new(g);                                       // sp0 map, sp1 pair
 if (!ai_ok(g)) return g;
 g = ai_push(g, 3, putcharm(LThread), A(g->sp[1]), g->sp[0]);
 if (ai_ok(g = ai_mapput(g))) g->sp++;                 // back to sp0 map, sp1 pair
 if (!ai_ok(g)) return g;
 g = ai_push(g, 3, putcharm(LImps), B(g->sp[1]), g->sp[0]);
 if (ai_ok(g = ai_mapput(g))) g->sp++;
 if (!ai_ok(g)) return g;
 return g->sp[1] = g->sp[0], g->sp++, g; }
static struct ai *enscope(struct ai *g, struct env *par, word args, word imps) {
 uintptr_t const n = Width(struct env) + Width(struct ai_tag);
 g = ai_push(g, 3, args, imps, par);
 g = map_new(g);                                   // sp0 = tab, then args/imps/par
 if (ai_ok(g = ai_have(g, n))) {
  struct env *c = bump(g, n);
  c->len = zero;
  c->tab = g->sp[0];
  c->par = (struct env*) g->sp[3];
  g->sp[3] = (word) tagthread((union u*)c, Width(struct env)); }   // env at sp3; tab/args/imps stay
 if (!ai_ok(g)) return g;
 { struct env *e = (struct env*) g->sp[3];                     // re-read after every put: a
   g = eset(g, &e, EArgs, g->sp[1]);                           // grow inside mapput would move it
   if (ai_ok(g)) e = (struct env*) g->sp[3], g = eset(g, &e, EImps, g->sp[2]); }
 return ai_ok(g) ? (g->sp += 3, g) : g; }


static word memq(struct ai *g, word l, word k) {
 for (; chainp(l); l = B(l)) if (eql(g, k, A(l))) return l;
 return 0; }

static word assq(struct ai *g, word l, word k) {
 for (; chainp(l); l = B(l)) if (eql(g, k, AA(l))) return A(l);
 return 0; }

static struct ai *append(struct ai *g) {
 uintptr_t i = 0;
 for (word l; ai_ok(g) && chainp(g->sp[0]); i++)
  l = B(g->sp[0]),
  g->sp[0] = A(g->sp[0]),
  g = ai_push(g, 1, l);
 if (!ai_ok(g)) return g;
 if (i == 0) return g->sp++, g;
 for (g->sp[0] = g->sp[i + 1]; i--; g = gxr(g));
 if (ai_ok(g)) g->sp[1] = g->sp[0], g->sp++;
 return g; }

// don't inline this so callers can tail call optimize
static ai_noinline struct ai *c0(struct ai *g, lvm_t *y) {
 // every in-place store below is precisely barriered (gen_wb_cell/two), so a
 // mid-compile collection stays minor. the opfix prepass runs first; a chain whose
 // head is already a top is a constructed direct application (never readable
 // source): skipped, which also terminates the recursion through ai_eval.
 { word x0 = g->sp[0];
   if (chainp(x0) && (!evenp(A(x0)) || datp(A(x0)))) {
    word of = g->hot_opfix;                      // sealed: a book rebind can't reach this lane;
    if (evenp(of)) {                              // pre-seal (mid-prel bootstrap) it is zero and
                                                 // the pass skips -- everything there is prefix
     g = ai_eval(gxr(gxl(gxl(pushq(gxl(ai_push(g, 4, x0, zero, zero, of)))))));
     if (!ai_ok(g)) return g;
     g->sp[1] = g->sp[0], g->sp += 1; } } }
 if (!ai_ok(g = enscope(g, (struct env*) zero, zero, zero))) return g;
 struct env *c = (void*) ptr(pop1(g));
 word x = g->sp[0];
 g->sp[0] = (word) c1_yield;
 mm(g, &c); mm(g, &x);
 if (ai_ok(g = analyze(g, &c, x)))
   g = c1(c0_ix(g, &c, y, word(g->ip)), &c);
 um(g), um(g);
 return g; }

static Cata(c1) {
 uintptr_t l = getcharm((*c)->len);
 g = ai_have(g, l + Width(struct ai_tag));
 if (ai_ok(g)) {
  union u *k = bump(g, l + Width(struct ai_tag));
  memset(k, -1, l * sizeof(word));
  Kp = tagthread(k, l) + l;
  if (ai_ok(g = pull(g, c))) clip(g, Kp); }   // pull emits l words (may GC); Kp now = entry
 return g; }

static Cata(c1_yield) { return g; }

static Cata(c1_cond_pop_exit) { return
 g = eset(g, c, EExit, B(eget(g, *c, EExit))), // pops cond expression exit address off env exits
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

// emit a recursive-function ref: bake `quote <the box's thread>` if the closure is final, else
// `quote zero` + stash the operand cell in the site for ana_d to backpatch.
static Cata(c1_recv) {
 word y = pop1(g), site = pop1(g);
 Kp -= 2;
 Kp[0].ap = lvm_quote;
 if (zerop(site)) return
   Kp[1].x = lget(g, y, LThread), gen_wb_cell(g, Kp + 1, Kp[1].x), pull(g, c);
 { struct ai_r *mm0 = g->root;                         // sset allocates: root site first
   mm(g, &site);
   Kp[1].x = zero;
   g = sset(g, site, SCell, (word) &Kp[1]);
   ai_core_of(g)->root = mm0; }
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

cata1(c1_cond_push_branch, g = gxl(ai_push(g, 2, Kp, eget(g, *c, EBranch))), g = eset(g, c, EBranch, ai_ok(g) ? pop1(g) : zero))
cata1(c1_cond_push_exit, g = gxl(ai_push(g, 2, Kp, eget(g, *c, EExit))), g = eset(g, c, EExit, ai_ok(g) ? pop1(g) : zero))
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
 encode(g, ai_status_yield); }


// a hardware fault is a crash on every target: no handler, no recovery -- a fault
// means an invariant is already broken, and the immediate core dump names the site.
// (a barrier here once turned that class into a silent per-call siglongjmp storm.)
struct ai *ai_eval(struct ai *g) {
 if (!ai_ok(g)) return g;                        // c0 reads g->sp[0] before any guard of its own
 g = c0(g, _lvm_yieldk);
#if ai_tco
 if (ai_ok(g)) g = g->ip->ap(g, g->ip, g->hp, g->sp);
 return g;
#else
 while (ai_ok(g)) g = g->ip->ap(g);
 if (ai_code_of(g) == ai_status_eof) g = ai_core_of(g);
 return g;
#endif
}

static word lidx(struct ai*g, word x, word l) {
 word i = 0;
 for (; chainp(l); i++, l = B(l)) if (eql(g, x, A(l))) return i;
 return -1; }

static Ana(ana_v) {
 word y;
 if (!ai_ok(g)) return g;
 for (struct env *d = *c;; d = d->par) {
  if (zerop(d)) {
   if ((y = stacklook(g, 0, x))) return ana_q(g, c, y);
   // undefined global: resolved by lvm_index at run time. record it as a captured
   // free variable only when nested -- at top level imps would alias an
   // uninitialized arg slot. re-read x from the imps hook: the push above can GC.
   if (!zerop((*c)->par))
    g = gxl(ai_push(g, 2, x, eget(g, *c, EImps))),
    g = eset(g, c, EImps, ai_ok(g) ? pop1(g) : zero),
    x = ai_ok(g) ? A(eget(g, *c, EImps)) : zero;
   return c0_ix(g, c, lvm_index, x); }
  // lambda definition of local let form?
  if ((y = assq(g, eget(g, d, ELams), x))) {
   // recursive-fn ref: record a backpatch site on d (the lams-owning scope) when
   // the closure isn't built yet, then apply the captured imports.
   word site = zero;
   if (zerop(lget(g, y, LThread))) {
    mm(g, &d), mm(g, &y);
    g = map_new(g);                                    // site = a box, at sp0
    if (ai_ok(g)) g = sset(g, g->sp[0], SEntry, y);    // re-read sp0: a grow can move it
    if (ai_ok(g)) g = sset(g, g->sp[0], SCell, zero);
    if (ai_ok(g)) {
     g = gxl(ai_push(g, 2, g->sp[0], eget(g, d, ESites))); // (site . eget(g, d, ESites))
     if (ai_ok(g)) g = eset(g, &d, ESites, pop1(g)), site = pop1(g); }
    um(g), um(g); }
   incl(*c, 2);
   if (ai_ok(g = ai_push(g, 3, c1_recv, y, site)))
    g = ana_ap(g, c, lget(g, g->sp[1], LImps));
   return g; }
  // let binding in the *current* scope -> a direct stack slot.
  if (d == *c && memq(g, eget(g, d, EStack), x)) return
    c0_ix(g, c, lvm_arg, putcharm(lidx(g, x, eget(g, d, EStack))));
  // the shadow guard: d's let binds x (fars) but x is not yet a lams entry or a
  // slot -- the nom is this let's, so the walk must not escape to an enclosing
  // binding of the same spelling. import it; the rebuild resolves it through lams.
  if (!zerop(eget(g, d, EFars)) && memq(g, eget(g, d, EFars), x) &&
      !(!zerop(d->par) && memq(g, eget(g, d->par, EStack), x))) {
   if (!zerop((*c)->par))
    g = gxl(ai_push(g, 2, x, eget(g, *c, EImps))),
    g = eset(g, c, EImps, ai_ok(g) ? pop1(g) : zero),
    x = ai_ok(g) ? A(eget(g, *c, EImps)) : zero;
   return c0_ix(g, c, lvm_index, x); }
  // a let binding, closure var, or lambda arg. if from an enclosing scope, import
  // it into this scope's imps so the offset c1_var emits is valid in this frame.
  if (memq(g, eget(g, d, EStack), x) || memq(g, eget(g, d, EImps), x) || memq(g, eget(g, d, EArgs), x)) {
   incl(*c, 2);
   if (d != *c) // found in an enclosing scope -> import (capture) it
    g = gxl(ai_push(g, 2, x, eget(g, *c, EImps))),
    g = eset(g, c, EImps, ai_ok(g) ? pop1(g) : zero),
    x = ai_ok(g) ? A(eget(g, *c, EImps)) : zero;
   return ai_push(g, 3, c1_var, x, eget(g, *c, EStack)); } } }


static Cata(c1_var) {
 word v = pop1(g), i = llen(pop1(g)); // stack inset
 for (word l = eget(g, (*c), EImps); !zerop(l); l = B(l), i++)
  if (eql(g, v, A(l))) goto out;
 for (word l = eget(g, (*c), EArgs); !zerop(l); l = B(l), i++)
  if (eql(g, v, A(l))) break;
out:
 return Kp -= 2,
        Kp[0].ap = lvm_arg,
        Kp[1].x = putcharm(i),
        pull(g, c); }

static ai_noinline Ana(analyze) {
 if (nomp(x) && x != ZeroPoint) return ana_v(g, c, x); // lookup symbol as variable
 if (!chainp(x)) return ana_q(g, c, x); // non-chains are self quoting
 word a = A(x), b = B(x);                        // it must be a chain
 // if it is a special form then do that
 struct ai_str *nm;                             // a special form is headed by a 1-char named symbol (\ : ?)
 if (chainp(b) && (nm = nom_str(g, a)) && len(nm) == 1)  // chainp: (\) (:) (?) hold no operand to
                                                // consume, so an empty form is not a special form at
                                                // all -- it falls to (f) == f like every other head.
                                                // nom_str is 0 for a bare mint / the core / a non-sym
  switch (*txt(nm)) {
   case '\\': return ana_l(g, c, b);
   case ':': return ana_d(g, c, b);
   case '?': return ana_c(g, c, b); }
 return ana_2(g, c, x, a, b); }


// substitute nom p -> m over x, quoted data kept; answers the result on sp0. runs
// only on a lambda being renamed, so the fresh spine costs what it renames.
static struct ai *subst1(struct ai *g, word x, word p, word m) {
 if (!ai_ok(g)) return g;
 if (x == p) return ai_push(g, 1, m);
 if (!chainp(x)) return ai_push(g, 1, x);
 { struct ai_str *nm; word a = A(x);
   if (nomp(a) && (nm = nom_str(g, a)) && len(nm) == 1 && *txt(nm) == '\\' &&
       chainp(B(x)) && !chainp(BB(x))) return ai_push(g, 1, x); }   // (\ q): a quote is data
 struct ai_r *mm0 = g->root;
 mm(g, &x); mm(g, &p); mm(g, &m);
 g = subst1(g, A(x), p, m);
 g = subst1(g, B(x), p, m);
 ai_core_of(g)->root = mm0;
 return gxr(g); }

static struct ai *c0_lambda(struct ai *g, struct env **c, intptr_t imps, intptr_t exp) {
 union u *k, *ip;
 struct env *d = NULL;
 // imps is rooted like the rest: the rename loop below mints and substitutes, and a
 // collection there leaves an unrooted argument pointing into the from-space.
 mm(g, &d); mm(g, &exp); mm(g, &imps);

 // a param that shadows an enclosing binder renames to a fresh mint over the whole
 // operand list -- one cluster, so a like-named inner : renames with it and a
 // pre-pin read still sees the outer. ana_d applies a sibling's captures by name at
 // each reference site, and a shadow would hand the site its own value (ev.l's
 // cplam holds the same law; there boxfix cells cover the let-value names this
 // lane's EFars/EStack rows stand for).
 for (bool again = true; again && ai_ok(g);) {
  again = false;
  for (word e = exp; chainp(e) && chainp(B(e)); e = B(e)) {
   word p = A(e), hit = 0; struct ai_str *nm;
   if (!nomp(p) || ((nm = nom_str(g, p)) && len(nm) == 1 && *txt(nm) == '_')) continue;
   for (struct env *d2 = *c; !hit && !zerop(d2); d2 = d2->par)
    hit = memq(g, eget(g, d2, EArgs), p) || memq(g, eget(g, d2, EFars), p)
       || memq(g, eget(g, d2, EStack), p);
   if (!hit) continue;
   mm(g, &p);
   g = ai_have(g, Width(struct ai_mint));
   if (ai_ok(g)) {
    struct ai_mint *y = (struct ai_mint*) bump(g, Width(struct ai_mint));
    ini_missing(y, ++g->next_serial);
    g = subst1(g, exp, p, word(y)); }
   um(g);
   if (ai_ok(g)) exp = pop1(g), again = true;
   break; } }

 g = enscope(g, *c, exp, imps);

 if (ai_ok(g)) {
  d = (struct env*) pop1(g);
  exp = eget(g, d, EArgs);
  int n = 0; // push exp args onto stack
  for (; chainp(B(exp)); exp = B(exp), n++) g = ai_push(g, 1, A(exp));
  for (g = push0(g); n--; g = gxr(g));
  exp = A(exp); }

 if (ai_ok(g)) {
  g = eset(g, &d, EArgs, g->sp[0]);
  g->sp[0] = (word) c1_yield;
  incl(d, 4);
  g = ai_push(g, 2, c1_cur, d);
  g = analyze(g, &d, exp);
  if (ai_ok(g = ai_push(g, 2, c1_ret, d)))
    ip = g->ip,
    avec(g, ip, g = c1(g, &d)); }

 if (ai_ok(g)) k = g->ip, g->ip = ip, g = gxl(ai_push(g, 2, k, eget(g, d, EImps)));

 return um(g), um(g), um(g), g; }

static Ana(c0_cond_exit) { return
 incl(*c, 3),
 ai_push(analyze(g, c, x), 1, c1_cond_exit); }

static Ana(c0_cond_r) { return
 !chainp(x) ? c0_cond_exit(g, c, ZeroPoint) :   // clauses ran out: implicit else -> () (zero-ontology: the same () the reader terminates lists with)
 !chainp(B(x)) ? c0_cond_exit(g, c, A(x)) :
 (avec(g, x,
  incl(*c, 2),
  g = analyze(g, c, A(x)),
  g = ai_push(g, 1, c1_cond_pop_branch),
  g = c0_cond_exit(g, c, AB(x)),
  g = ai_push(g, 1, c1_cond_push_branch),
  g = c0_cond_r(g, c, BB(x))), g); }


static struct ai *ana_ap_r2l(struct ai *g, struct env **c, word x);
static struct ai *ana_ap(struct ai *g, struct env **c, intptr_t x) {
 if (!ai_ok(g)) return g;
 // a quoted cell is read below as a nif's code (ap, [1].ap, [3].ap) -- so it must be a
 // nif: a static table, never a heap value. a chain's cap, a closure's second word and a
 // partial's argument are payload, and on a seat where a function pointer is a small
 // table index (wasm) an odd index IS a charm, so `[1].ap == lvm_ret0` would hold of
 // '(3 ..) or a lambda and inline it as an instruction
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

 if (b1p) { // inline an instruction
  lvm_t *i = cell(g->sp[2])->ap;
  g->sp += 3;
  g = c0_i(analyze(g, c, A(x)), c, i);
  return g; }

 if (bnp) { // inline a curried instruction
  lvm_t *i = cell(g->sp[2])[2].ap;
  g->sp += 3;
  g = c0_i(ana_ap_r2l(g, c, x), c, i); // r2l arg eval
  if (ai_ok(g)) { word s = eget(g, *c, EStack); while (ca--) s = B(s); g = eset(g, c, EStack, s); }
  return g; }

 if (ai_ok(g = gxl(ai_push(g, 3, zero, eget(g, *c, EStack), x)))) {
  g = eset(g, c, EStack, pop1(g)), x = pop1(g), mm(g, &x);
  if (anp) { // r2l 1 n-ary ap
   g = ana_ap_r2l(g, c, x),
   incl(*c, 2),
   g = ai_push(g, 2, c1_apn, putcharm(ca));
   if (ai_ok(g)) { word s = eget(g, *c, EStack); while (ca--) s = B(s); g = eset(g, c, EStack, s); } }
  else while (chainp(x)) // l2r n 1-ary ap
   g = analyze(g, c, A(x)),
   incl(*c, 2),
   g = ai_push(g, 2, c1_apn, putcharm(1)),
   x = B(x);
  um(g), g = eset(g, c, EStack, B(eget(g, *c, EStack))); }

 return g; }


static struct ai *ana_ap_r2l(struct ai *g, struct env **c, word x) {
 if (chainp(x)) {
  word y = A(x);
  avec(g, y, g = ana_ap_r2l(g, c, B(x)));
  g = analyze(g, c, y);
  g = gxl(ai_push(g, 2, zero, eget(g, *c, EStack)));
  if (ai_ok(g)) g = eset(g, c, EStack, pop1(g)); }
 return g; }

static ai_inline bool lambp(struct ai *g, word x) {
 struct ai_str *n;                                      // headed by the named symbol \ (nom_str 0 for a bare mint / non-sym)
 return chainp(x) && chainp(B(x)) && chainp(B(B(x))) &&
  (n = nom_str(g, A(x))) && len(n) == 1 && txt(n)[0] == '\\'; }

// reversal onto a FRESH spine: the source is read and never written, so no holder of it
// sees a list turn around. l is rooted because gxl allocates and a collection moves it;
// ai_push roots its own argument (ai_pushr), so A(l) crossing one is safe.
static struct ai *rev(struct ai *g, word l) {          // answers the reversed copy, pushed
 struct ai_r *mm0 = ai_core_of(g)->root;
 mm(g, &l);
 g = ai_push(g, 1, zero);
 for (; ai_ok(g) && chainp(l); l = B(l)) g = gxl(ai_push(g, 1, A(l)));
 return forget(); }

static struct ai *ldels(struct ai *g, word lam, word l);

// a lexically bound nom shadows a macro of the same spelling (ev.l's wx/cprop
// carry the twin guard). binder rosters only -- imps may record undefined globals.
static bool lexbound(struct ai *g, struct env *d, word x) {
 for (; !zerop(d); d = d->par)
  if (memq(g, eget(g, d, EArgs), x) || memq(g, eget(g, d, EStack), x) ||
      memq(g, eget(g, d, EFars), x) || assq(g, eget(g, d, ELams), x)) return true;
 return false; }

static ai_inline Ana(ana_2, word a, word b) {
 if ((x = stacklook_macro(ai_core_of(g), a)) && !lexbound(g, *c, a)) {  // macro table = each layer's [zero] slot, walked; the scope walk only on a macro hit
  g = ai_eval(gxr(gxl(gxl(pushq(gxl(ai_push(g, 4, b, zero, zero, x)))))));
  // the expansion is source again: it takes the opfix prepass a read form took, so a binder
  // a macro built (:- is one) lowers its patterns like one the reader saw. the same guard as
  // c0's: a lambda-headed chain is a constructed application, and pre-seal the pass is zero
  word e = ai_ok(g) ? g->sp[0] : 0, of = ai_core_of(g)->hot_opfix;
  if (chainp(e) && (!evenp(A(e)) || datp(A(e))) && evenp(of)) {
   g = ai_eval(gxr(gxl(gxl(pushq(gxl(ai_push(g, 4, e, zero, zero, of)))))));
   if (ai_ok(g)) g->sp[1] = g->sp[0], g->sp += 1; }
  return analyze(g, c, ai_ok(g) ? pop1(g) : 0); }
 if (!chainp(b)) return analyze(g, c, a);  // (f) == f -- below the macro lane, which has no value to be
 return avec(g, b, g = analyze(g, c, a)),
        ana_ap(g, c, b); }

ai_inline Ana(ana_q) { return c0_ix(g, c, lvm_quote, x); }
static ai_inline Ana(ana_l) {
  if (!chainp(B(x))) return ana_q(g, c, A(x)); // one operand, no params: quote
  return g = c0_lambda(g, c, zero, x),
         analyze(g, c, ai_ok(g) ? pop1(g) : 0); }
static Ana(c0_cond_r);
static ai_inline Ana(ana_c) {
 return !chainp(B(x)) ? analyze(g, c, A(x)) :
    (g = ai_push(g, 2, x, c1_cond_pop_exit),
     g = c0_cond_r(g, c, ai_ok(g) ? pop1(g) : zero),
     ai_push(g, 1, c1_cond_push_exit)); }
// this is the longest C function :(
// it handles the let special form in a way to support sequential and recursive binding.
static ai_inline struct ai *ana_d(struct ai *g, struct env **b, word exp) {
 if (!chainp(B(exp))) return analyze(g, b, A(exp));
 struct ai_r *mm0 = ai_core_of(g)->root;
 mm(g, &exp);
 // delegate the letrec*-value rewrite to the l `boxfix` prepass once that global
 // exists: forward-referenced bindings indirect through nom-keyed cells (prel.l).
 // ev.l runs the same pass in feel, so both lanes share one boxfix.
 if (ai_ok(g = intern(ai_strof(g, "boxfix")))) {
  word bf = stacklook(g, 0, pop1(g));
  if (bf && evenp(bf)) {
   g = ai_eval(gxr(gxl(gxl(pushq(gxl(ai_push(g, 4, exp, zero, zero, bf)))))));
   if (ai_ok(g)) exp = pop1(g); } }
 g = enscope(g, *b, eget(g, (*b), EArgs), eget(g, (*b), EImps));
 if (!ai_ok(g)) return forget();
 struct env *q = (struct env*) pop1(g), **c = &q;
 // lots of variables :(
 word nom = zero, def = zero, ndef = zero, lam = zero,
      v = zero, d = zero, e = zero, os = zero;
 mm(g, &nom), mm(g, &def), mm(g, &ndef), mm(g, &lam);
 mm(g, &d); mm(g, &e); mm(g, &v); mm(g, &q); mm(g, &os);

 // pin the let's binding names on q before any lambda compiles (the shadow set):
 // the walk must see an inner-bound nom as bound here while lams is still zero,
 // or it resolves to an enclosing sibling and under-applies (cf. ev.l avb's 'far guard)
 for (d = exp; chainp(d) && chainp(B(d)); d = BB(d)) {
  for (e = A(d); chainp(e) && !nomp(e); e = A(e)); // unroll (f x..) define-sugar to the name
  g = gxl(ai_push(g, 2, e, eget(g, q, EFars)));
  if (!ai_ok(g)) return forget();
  g = eset(g, &q, EFars, pop1(g)); }

 // collect vars and defs into two lists, exposing the preceding bindings on the
 // enclosing stack so a sibling ref captures as a free variable instead of a
 // same-named global; the stack is restored before any code is emitted.
 os = eget(g, *b, EStack);
 while (chainp(exp) && chainp(B(exp))) {
  for (d = A(exp), e = AB(exp); chainp(d) && !nomp(d); e = pop1(g), d = A(d)) {  // a named sym is a chain now: stop the (f x) define-sugar unroll at the name
   g = gxl(ai_push(g, 2, e, zero));
   g = append(gxl(pushl(ai_push(g, 1, B(d)))));
   if (!ai_ok(g)) return forget(); }
  g = gxl(ai_push(g, 2, d, nom));
  g = gxl(ai_push(g, 2, e, def));
  if (!ai_ok(g)) return forget();
  def = pop1(g), nom = pop1(g);
  // if it's a lambda compile it and record in lam list
  if (lambp(g, e)) {
   g = ai_push(g, 2, d, lam);
   g = gxl(gxr(lbox(c0_lambda(g, c, zero, B(e)))));
   if (!ai_ok(g)) return forget();
   lam = pop1(g); }
  g = gxl(ai_push(g, 2, d, eget(g, *b, EStack))); // expose this binding to later siblings
  g = eset(g, b, EStack, ai_ok(g) ? pop1(g) : zero);
  exp = BB(exp); }
 g = eset(g, b, EStack, os);  // restore: emission below rebuilds the real frame

 intptr_t l = llen(nom);
 bool oddp = chainp(exp),
      globp = !oddp && zerop(eget(g, (*b), EArgs)); // we check this again later to make global bindings at top level
 if (!oddp) { // if there's no body then evaluate the name of the last definition
  g = gxl(ai_push(g, 2, A(nom), zero));
  if (!ai_ok(g)) return forget();
  exp = pop1(g); }

 // find closures: for each pair of bound functions, if e needs d then e needs d's variables
 word j, vars, var;
 do for (j = 0, d = lam; chainp(d); d = B(d)) // for each bound function variable
  for (e = lam; chainp(e); e = B(e)) if (d != e) // for each other bound function variable
   if (memq(g, lget(g, A(e), LImps), AA(d))) // if you need this function
    for (v = lget(g, A(d), LImps); chainp(v); v = B(v)) // then you need its variables
     if (!memq(g, vars = lget(g, A(e), LImps), var = A(v))) // only add if it's not already there
      j++,
      g = gxl(ai_push(g, 2, var, vars)),
      g = lset(g, A(e), LImps, ai_ok(g) ? pop1(g) : zero);
 while (j);

 // now delete defined functions from the closure variable lists
 // they will be bound lazily when the function runs
 for (e = lam; ai_ok(g) && chainp(e); e = B(e)) {
  g = ldels(g, lam, lget(g, A(e), LImps));
  if (ai_ok(g)) g = lset(g, A(e), LImps, pop1(g)); }

 g = eset(g, c, ELams, lam);
 g = append(gxl(pushl(ai_push(g, 2, nom, exp))));

 if (!ai_ok(g)) return forget();
 exp = pop1(g);

 //
 // all the code emissions are below here (??)
 //

 // clear each function's provisional closure so a ref hit mid-rebuild defers to a
 // backpatch site rather than baking the stale closure; keep the import sets (BB).
 for (d = lam; ai_ok(g) && chainp(d); d = B(d)) g = lset(g, A(d), LThread, zero);

 // ndef is def with each closure standing where its source did. built by consing over a
 // def that is still in reverse order, so ndef lands in literal order and needs no rev.
 for (e = nom, v = def; ai_ok(g) && chainp(e); e = B(e), v = B(v)) {
  word nv;
  if (lambp(g, A(v))) {
   d = assq(g, lam, A(e));
   size_t nb = llen(lget(g, d, LImps)); // the import row is frozen here: sites already applied it
   g = c0_lambda(g, c, lget(g, d, LImps), BA(v));
   if (!ai_ok(g)) return forget();
   g = lset(g, d, LThread, A(g->sp[0]));        // the pair stays on the stack across both
   if (ai_ok(g)) g = lset(g, d, LImps, B(g->sp[0]));   // puts: either can move it
   if (!ai_ok(g)) return forget();
   if (llen(lget(g, d, LImps)) != nb) __builtin_trap(); // growth = those sites under-apply (cf. ev.l weave's 'imports-grew scare)
   nv = g->sp[0], g->sp++; }
  else nv = A(v);
  g = gxl(ai_push(g, 2, nv, ndef));
  if (ai_ok(g)) ndef = pop1(g); }
 if (!ai_ok(g)) return forget();

 // closures final -> backpatch each recorded recursive-fn ref with its thread.
 for (d = eget(g, (*c), ESites); chainp(d); d = B(d)) {
  union u *hole = cell(sget(g, A(d), SCell));
  hole->x = lget(g, sget(g, A(d), SEntry), LThread), gen_wb_cell(g, hole, hole->x); }
 g = eset(g, c, ESites, zero);

 g = rev(g, nom);   // put in literal order
 if (!ai_ok(g)) return forget();
 nom = pop1(g);
 g = analyze(g, b, exp);
 g = gxl(ai_push(g, 2, zero, e = eget(g, *b, EStack))); // push function stack rep
 g = eset(g, b, EStack, ai_ok(g) ? pop1(g) : zero);
 for (def = ndef; chainp(nom); nom = B(nom), def = B(def))
  g = analyze(g, b, A(def)),
  g = globp ? c0_ix(g, b, lvm_defglob, A(nom)) : g,
  g = gxl(ai_push(g, 2, A(nom), eget(g, *b, EStack))),
  g = eset(g, b, EStack, ai_ok(g) ? pop1(g) : zero);
 return
  g = eset(g, b, EStack, e),
  incl(*b, 2),
  g = ai_push(g, 2, c1_apn, putcharm(l)),
  forget(); }

// drop the bound functions from a closure-variable list, onto a FRESH spine: the source
// is read and never written. tail first, so the copy builds back to front and the kept
// cells cons onto an answer that is already whole. lam and l are rooted across it --
// gxl allocates, and the recursion carries both over that.
static struct ai *ldels(struct ai *g, word lam, word l) {
 if (!ai_ok(g)) return g;
 if (!chainp(l)) return ai_push(g, 1, zero);
 struct ai_r *mm0 = g->root;
 mm(g, &lam), mm(g, &l);
 g = ldels(g, lam, B(l));
 if (ai_ok(g) && !assq(g, lam, A(l))) g = gxl(ai_push(g, 1, A(l)));
 return forget(); }

lvm(lvm_defglob) {
 Have(3);
 Sp -= 3;
 word k = Ip[1].x, v = Sp[3];
 Sp[0] = k, Sp[1] = v, Sp[2] = A(g->stack), Pack(g);          // a pin lands in the head layer
 if (!ai_ok(g = ai_mapput(g))) ai_musttail return Ap(_lvm_ghelp, g);
 Unpack(g), Sp += 1, Ip += 2;
 ai_musttail return Continue(); }

// lvm_index (the late-bound global read) is defined below lvm_scare: its
// miss path is the missing condition and borrows the whole help apparatus.

lvm(lvm_eval) { Ip++; LvmResume(g, c0, lvm_jump) }

// ai_evals_ lives with the boot stitch it shares its machinery with, at the
// foot of the reader section.

// ============================================================================
// vm
// ============================================================================
// the hooks (love.h): lisp the C lanes reach by slot, handed over by (seal-hook n f).
// hot_hook traps on an unsealed slot -- a clean failure, never a wild read.
word hot_hook(word h) { if (!evenp(h)) __builtin_trap(); return h; }

// `+`/`*` of two functions build a new function (church add / composition) from
// hooks 2 and 3; the C aps reuse numap_drive to compute the partial.
// fixnum application dispatches to (num-ap n x): numeric x -> x**n, function x ->
// x iterated n times. the drive is [ap, ap_next, ret0] over [n, num-ap, x, ret];
// lvm_numap is the non-tail form, lvm_numtap the tail form; the fused arg/quote
// variants push their argument and bump Ip so the layout lines up, then divert.
// ap_next applies the partial to the next argument: swap the result into operator
// position, then ap -- one ap_next cell in a drive = one more curried argument.
static lvm(ap_next) {
 word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t;
 ai_musttail return Ap(lvm_ap, g); }
union u const numap_drive[] = { {lvm_ap}, {.ap = ap_next}, {.ap = lvm_ret0} };

// --- the stackless call-out bridge (the glaze call-out arc) ---
// a native blob applies clos to arg the way the VM does: build [arg, clos, RET] on
// Sp, point Ip at callout_drive, tail-jump. RET is the blob's own native resume
// point, so control returns entirely through Continue() tail-jumps -- no C frame is
// pinned across the sub-run, so a deep callee grows the VM stack, never the C stack.
union u const callout_drive[] = { {lvm_ap}, {.ap = lvm_ret0} };
// (calloutdrive x) -> the drive's address as a fixnum (a probe; a native reaches it through g->reach)
lvm(lvm_calloutdrive) { ai_musttail return Answer(putcharm((intptr_t) callout_drive)); }
// the walkable resume: v1's RET was a stack-interior pointer, which a collection
// with a call-out pending fed to gcp. here the frame is [arg, clos, tag(bb - entry),
// entry] -- the resume rides as an odd charm offset (the walk skips it) plus the
// blob's raw out-of-pool base, and lvm_resume jumps base+offset. relocation-safe.
union u const callout_resume[] = { {lvm_ap}, {.ap = lvm_resume} };
lvm(lvm_calloutresume) { ai_musttail return Answer(putcharm((intptr_t) callout_resume)); }
// --- (sortby le l): the merge sort with a love comparator, as one C loop that hands each
// compare back to the VM. the values ride two object trays (the comparator may collect, so
// nothing lives in the gap), the merge's cursors ride the stack as charms, and a compare is
// the numap frame [x, le, y] under a drive whose tail re-enters the step with the answer at
// Sp[0]; a comparator that is a cur of arity two takes the apn frame straight into its body,
// no partial minted per compare. contiguous runs, the left taken when (le x y): stable for a
// comparator that answers 1 on ties. the spine is laid once at the end, the way sort lays its own.
enum { sb_va = 1, sb_vb, sb_w, sb_lo, sb_x, sb_y, sb_o, sb_hi, sb_n, sb_pend, sb_le, sb_k };   // off Sp; Sp[0] = the answer, sb_k the caller's next op
// sb_pend: () before the first compare, 1 with a compare's answer waiting, sb_done once the
// merge is over. the spine's reservation collects like any other, and a collection re-enters
// the step at its top, where a stale 1 consumed the last answer a second time and re-ran the
// last pass over the swapped trays -- an answer of two sorted runs, and not a permutation.
#define sb_done putcharm(2)
static lvm_t sortby_step;
static union u const sortby_drive[] = { {lvm_ap}, {.ap = ap_next}, {.ap = sortby_step} };
static union u const sortby_text[] = { {.ap = sortby_step} };
static struct ai *sortby_setup(struct ai *g) {
 uintptr_t n = (uintptr_t) ai_count(g, g->sp[1]), words = b2w(tray_bytes(ai_O, 1, n));
 if (!ai_ok(g = ai_have(g, 2 * words + sb_k + 1))) return g;
 word le = g->sp[0], l = g->sp[1];                                  // re-read past the reservation
 struct ai_tray *a = (struct ai_tray*) g->hp; g->hp += words; ini_tray(a, ai_O, 1); a->shape[0] = n;
 struct ai_tray *b = (struct ai_tray*) g->hp; g->hp += words; ini_tray(b, ai_O, 1); b->shape[0] = n;
 uintptr_t i = 0;
 for (word p = l; chainp(p); p = B(p)) tray_put_obj(a, i++, A(p));
 for (i = 0; i < n; i++) tray_put_obj(b, i, zero);
 word k = word(g->ip + 1);                                            // a nif runs inline: its continuation is the caller's next op
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
 if (Sp[sb_pend] == sb_done) goto spine;                             // a collection at the reservation below re-entered the step: the merge is over
 if (Sp[sb_pend] != zero) {                                          // the answer to (le a[x] a[y]): the left when true
  if (__builtin_expect(!ai_leafp(Sp[0]), 0)) ai_musttail return Ap(lvm_measure, g);   // a compound answer: measured, then the step again
  bool left = !leaf_nilp(Sp[0]);
  word v = tray_get_obj(tray(Sp[sb_va]), left ? x++ : y++);
  tray_put_obj(tray(Sp[sb_vb]), o++, v);
  gen_wb(g, Sp[sb_vb], v); }                                         // b may have aged under a collection the comparator ran
 for (;;) {
  if (x < m && y < hi) {                                             // the next compare: save the cursors, lay [x le y], run the drive
   word xv = tray_get_obj(tray(Sp[sb_va]), x), yv = tray_get_obj(tray(Sp[sb_va]), y);
   Sp[sb_w] = putcharm(w), Sp[sb_lo] = putcharm(lo), Sp[sb_hi] = putcharm(hi);
   Sp[sb_x] = putcharm(x), Sp[sb_y] = putcharm(y), Sp[sb_o] = putcharm(o), Sp[sb_pend] = putcharm(1);
   word le = Sp[sb_le];
   union u *k = oddp(le) ? 0 : cell(le);
   if (k && k[0].ap == lvm_cur && k[1].x == putcharm(2)) {         // a cur of arity two: the apn frame [x y ret], straight into its body
    Sp -= 2, Sp[0] = xv, Sp[1] = yv, Sp[2] = word(sortby_drive + 2);
    Ip = k + 2;
    ai_musttail return Continue(); }
   Sp -= 2, Sp[0] = xv, Sp[1] = le, Sp[2] = yv;                    // anything else curries through the drive
   Ip = (union u*) sortby_drive;
   ai_musttail return Continue(); }
  while (x < m) { word v = tray_get_obj(tray(Sp[sb_va]), x++); tray_put_obj(tray(Sp[sb_vb]), o++, v); gen_wb(g, Sp[sb_vb], v); }
  while (y < hi) { word v = tray_get_obj(tray(Sp[sb_va]), y++); tray_put_obj(tray(Sp[sb_vb]), o++, v); gen_wb(g, Sp[sb_vb], v); }
  lo += 2 * w;
  if (lo >= n) {                                                     // a pass done: the runs swap trays and double
   word t = Sp[sb_va]; Sp[sb_va] = Sp[sb_vb], Sp[sb_vb] = t;
   w *= 2, lo = 0;
   if (w >= n) break; }
  x = o = lo, m = min(lo + w, n), y = m, hi = min(lo + 2 * w, n); }
 Sp[sb_pend] = sb_done;                                              // the merge is over: nothing below may re-run it
spine:
 Have(n * Width(struct ai_chain));                                    // the spine, laid from the sorted tray (re-read post-GC)
 struct ai_tray *a = tray(Sp[sb_va]);
 struct ai_chain *spine = (struct ai_chain*) Hp;
 Hp += n * Width(struct ai_chain);
 for (uintptr_t i = 0; i < n; i++) ini_chain(spine + i, tray_get_obj(a, i), word(spine + i + 1));
 spine[n - 1].b = ZeroPoint;
 Ip = (union u*) Sp[sb_k];
 Sp += sb_k;                                                          // [ans state.. le k ..] -> [spine ..]: two operands in, one answer out
 Sp[0] = word(spine);
 ai_musttail return Continue(); }
lvm(lvm_sortby) {
 word l = Sp[1];
 if (nomp(l) || !chainp(l) || !chainp(B(l))) ai_musttail return Push(l);   // under two elements: the list itself
 LvmResume(g, sortby_setup) }

// ============================================================================
// the lisp help calling convention
// ============================================================================
// an installed help makes a raise the call (help a b) through help_drive
// (numap_drive's 2-arg twin) into a per-class epilogue: help_ret_more delivers the
// help's result to the raise site's resume text -- despite the name, the
// deliberate-scare lane, what makes (scare a b) and `missing` resumable; a bare
// scare is observed, then takes the default escape to C.
// the epilogue's arithmetic is the raise site's 3-word frame [resume a b], not
// the help frame the drive consumes, so the two sizes move apart.
static lvm(help_ret_more) {   // [result resume a b ..] -> resume sees result
 Ip = cell(Sp[1]);
 Sp[3] = Sp[0];
 Sp += 3;
 ai_musttail return Continue(); }
static lvm(help_ret_scare) {  // result ignored: scares are not (yet) resumable
 return Pack(g), encode(g, ai_status_scare); }
static union u const help_more_k[] = { {help_ret_more} };
static union u const help_scare_k[] = { {help_ret_scare} };
static union u const help_drive[] =
 { {lvm_ap}, {.ap = ap_next}, {.ap = lvm_ret0} };

// raise a scare with data a/b at the heard help as (help a b); with nothing heard (or
// still too tight after a collect) hand the scare-encoded core back to C.
// callers Pack first (ip stays at the raise site); a/b survive the collect in
// the scare_a/b stash, so the raise buys its own frame and never allocates.
static struct ai *ai_raise(struct ai *c, word a, word b, union u const *K) {
 c->scare_a = a, c->scare_b = b;  // for the exit face
 word h = *task_help(c);
 if (h != ZeroPoint && avail(c) < 4) {
  struct ai *p = ai_please(c, 4);
  if (!ai_ok(p)) return encode(ai_core_of(p), ai_status_scare);
  c = p;                                        // moved: re-derive every pointer
  a = c->scare_a, b = c->scare_b;
  h = *task_help(c); }
 if (h != ZeroPoint && avail(c) >= 4) {
  word *sp = c->sp -= 4;          // [a h b K | raise site data ..]
  sp[0] = a, sp[1] = h;
  sp[2] = b;
  sp[3] = word(K);
  c->ip = (union u*) help_drive;
#if ai_tco
  return c->ip->ap(c, c->ip, c->hp, c->sp);
#else
  return c;                       // ok-g: the trampoline dispatches help_drive
#endif
 }
 return encode(c, ai_status_scare);
}
// re-raise a failed op's scare: bare data, observe-then-terminal.
lvm(_lvm_ghelp) { return ai_raise(ai_core_of(g), zero, zero, help_scare_k); }
// (scare a b): the deliberate raise. the raise point is a clean boundary, so the
// help's result is delivered back as the value via the more continuation; with nothing heard
// it is terminal.
lvm(lvm_scare) {
 Have1();                          // the resume push only: ai_raise buys its own frame
 word a = Sp[0], b = Sp[1];
 *--Sp = word(Ip + 1);             // [resume a b ..]: help_more_k's layout
 return Pack(g), ai_raise(g, a, b, help_more_k); }
// the missing miss sentinel: a private static address no book value can equal,
// so a name bound to zero stays distinct from no entry at all.
static union u const no_entry[1];
// the GC-free C-data emitters (defined below), forward-declared for lvm_index's unheard-miss face.
struct ai *ioputs(struct ai*, char const*),
                 *ioputc(struct ai*, int);
struct ai *zflush(struct ai*);
// a missing read with nothing heard answers ZeroPoint: absence is a point, not a
// quantity -- a number would exponentiate under a numeral where a unit absorbs, which
// is what keeps (i love you) = 1. distinct from 0 and "".
// the 'missing tag is minted where it is used: both callers are cold, so a short-lived
// string beats a core slot. may collect, so Pack first and hold no heap local across
// it; answers the tag, or 0 if the intern failed.
static ai_noinline word missing_tag(struct ai *g) {
 struct ai *h = intern(ai_strof(g, "missing"));
 return ai_ok(h) ? ai_pop1(h) : 0; }

// a read of the live book by name -- the global twin of boxfix's (missing cell
// 'nom). a miss raises (help 'missing nom); with nothing heard it reads the zero point.
// the site never self-patches: a later define is seen, a rebind honoured.
lvm(lvm_index) {
 Have1();                          // room for the push first (may GC; no live local held yet)
 word v = stacklook(g, word(no_entry), Ip[1].x);
 if (v != word(no_entry)) return
  *--Sp = v,                       // present: push the live value, no quote patch
  Ip += 2,
  Continue();
 word h = *task_help(g);
 if (h == ZeroPoint) {
#if __STDC_HOSTED__
  // nothing heard (file mode): the zero point is silent, so surface ";; missing <nom>"
  // on err and still answer it. missing-specific -- a deliberate scare stays
  // terminal. nom_str + ioput* hold no heap operand -> no GC, so Sp/Ip survive.
  struct ai_str *nm = nom_str(g, Ip[1].x);
  if (nm) { struct ai_io *sv = g->io; g->io = &ai_stderr.io;
            g = ioputs(g, ";; missing ");
            for (uintptr_t i = 0; ai_ok(g) && i < nm->len; i++) g = ioputc(g, nm->bytes[i]);
            g = ai_core_of(zflush(ioputc(g, '\n')));  // best effort: a failed write stays off g
            g->io = sv; }
#endif
  *--Sp = ZeroPoint; ai_musttail return Next(2); }
 Pack(g);                          // the tag is minted only on the lane that carries it
 word a = missing_tag(g);          // may collect
 if (!a) ai_musttail return Ap(_lvm_ghelp, g);   // no tag to be had: the bare scare, still packed
 Unpack(g);
 Have(3);                          // after the intern: a collect here re-dispatches the
                                   // whole op, so `a` is either untouched or never read
 word b = Ip[1].x;
 Sp -= 3;
 Sp[0] = word(Ip + 2), Sp[1] = a, Sp[2] = b;   // help_more_k's layout
 return Pack(g), ai_raise(g, a, b, help_more_k); }
// the fused aps bump Ip so it points at an operand, not a re-runnable instruction --
// a plain Have() would re-dispatch into it. gc by hand and re-Ap (idempotent up to here).
#define NumapHave(self) if (Sp < Hp + 2) { \
 Pack(g); g = ai_please(g, 2); if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g); \
 Unpack(g); ai_musttail return Ap(self, g); }
static lvm(lvm_numap) {
 NumapHave(lvm_numap);
 word h = hot_hook(g->hot_numap);
 word n = Sp[1], x = Sp[0], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = n, dst[1] = h, dst[2] = x, dst[3] = ret;
 Sp = dst; Ip = (union u*) numap_drive; ai_musttail return Continue(); }
static lvm(lvm_numtap) {
 NumapHave(lvm_numtap);
 word h = hot_hook(g->hot_numap);
 word fs = getcharm(Ip[1].x), n = Sp[1], x = Sp[0], *dst = &Sp[fs + 2] - 3, ret = Sp[fs + 2];
 dst[0] = n, dst[1] = h, dst[2] = x, dst[3] = ret;
 Sp = dst; Ip = (union u*) numap_drive; ai_musttail return Continue(); }

// (seal-hook n f): install f as core hook n (0 read, 1 num-ap, 2 stack, 3 compose,
// 4 opfix, 5 the help, 6 the task's stdio, 7 show, 8 measure). 5 and 6 are the dynamic slots and
// alone skip the lambda gate -- 5 takes a help or (), 6 a 3-chain or (); anything else
// traps. a switch, not a table: a slot[] would be an address-taken local (the lvm
// scratch rule).
lvm(lvm_seal) {
 if (getcharm(Sp[0]) != 5 && getcharm(Sp[0]) != 6 && !evenp(Sp[1])) __builtin_trap();   // the two dynamic slots alone skip the gate
 Pack(g);                        // 5 and 6 store into the node, and their barrier reads g->hp
 switch (getcharm(Sp[0])) {
  case 0: g->hot_read = Sp[1]; break;
  case 1: g->hot_numap = Sp[1]; break;
  case 2: g->hot_arrange = Sp[1]; break;
  case 3: g->hot_compose = Sp[1]; break;
  case 4: g->hot_opfix = Sp[1]; break;
  case 5: *task_help(g) = Sp[1], gen_wb_cell(g, task_help(g), Sp[1]); break;
  case 6: *task_io(g) = chainp(Sp[1]) ? Sp[1] : ZeroPoint, gen_wb_cell(g, task_io(g), *task_io(g)); break;   // anything but a chain hands the console back
  case 7: g->hot_show = Sp[1]; break;
  case 8: g->hot_net = Sp[1]; break;
  default: __builtin_trap(); }
 Sp += 1, Sp[0] = zero, Ip += 1;
 ai_musttail return Continue(); }

// `+`/`*` over a lambda operand: build the combinator partial (stack/compose g g)
// through numap_drive. Ip is at the re-runnable +/* opcode, so a plain Have is
// safe; the slots are read after it (v0..end is what the GC updates).
lvm(lvm_addh) {
 if (coinp(Sp[0]) || coinp(Sp[1])) ai_musttail return Ap(lvm_add_coin, g);
 Have(2);
 word h = hot_hook(g->hot_arrange);
 word fa = Sp[0], ga = Sp[1], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = fa, dst[1] = h, dst[2] = ga, dst[3] = ret;
 Sp = dst; Ip = (union u*) numap_drive; ai_musttail return Continue(); }
lvm(lvm_mulh) {
 if (coinp(Sp[0]) || coinp(Sp[1])) ai_musttail return Ap(lvm_mul_coin, g);
 Have(2);
 word h = hot_hook(g->hot_compose);
 word fa = Sp[0], ga = Sp[1], *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = fa, dst[1] = h, dst[2] = ga, dst[3] = ret;
 Sp = dst; Ip = (union u*) numap_drive; ai_musttail return Continue(); }

// coin +/*/-//: run the coin's kind method over the raw operands via numap_drive.
// two distinct kinds have no canonical combination -> zero (the method never sees
// a foreign payload); a missing method is zero too. the ()-identity never
// reaches here -- the dispatchers hoist the mint case. Ip is still the opcode
// (Ap preserves it), so word(Ip + 1) is the true return.
static lvm(lvm_coin_op) {
 intptr_t slot = g->b;                              // the kind slot, off the scratch
 word a = Sp[0], b = Sp[1];
 if (coinp(a) && coinp(b) && coin_kind(a) != coin_kind(b))
  ai_musttail return Push(ZeroPoint);             // two distinct newtypes: no canonical +/*
 word f = kind_get(g, coinp(a) ? coin_kind(a) : coin_kind(b), slot);
 if (f == ZeroPoint) ai_musttail return Push(ZeroPoint);   // no method: ()
 Have(2);
 a = Sp[0], b = Sp[1];                              // re-read post-GC
 f = kind_get(g, coinp(a) ? coin_kind(a) : coin_kind(b), slot);
 word *dst = Sp - 2, ret = word(Ip + 1);
 dst[0] = a, dst[1] = f, dst[2] = b, dst[3] = ret;
 Sp = dst; Ip = (union u*) numap_drive; ai_musttail return Continue(); }
static lvm(lvm_add_coin) { g->b = (word) (KnAdd); ai_musttail return Ap(lvm_coin_op, g); }
static lvm(lvm_mul_coin) { g->b = (word) (KnMul); ai_musttail return Ap(lvm_coin_op, g); }
// `-` and `/` have no kind matrix; lvm_sub/lvm_quot intercept coins themselves and land here.
lvm(lvm_sub_coin) { g->b = (word) (KnSub); ai_musttail return Ap(lvm_coin_op, g); }
lvm(lvm_quot_coin) { g->b = (word) (KnDiv); ai_musttail return Ap(lvm_coin_op, g); }

// applying a coin: run the kind's ap closure as `((f self) arg)`; absent, a coin
// is an opaque handle -- nothing to answer with, () -- like a cask/port. self is the value at Ip (the apply
// trampoline sets Ip = the applied object); arg/ret are on the stack.
lvm(lvm_coin) {
 if (kind_get(g, coin_kind(word(Ip)), KnApply) == ZeroPoint) {   // no 'ap: applying the coin answers ()
  Ip = cell(*++Sp); *Sp = ZeroPoint; ai_musttail return Continue(); }
 Have(2);
 word self = word(Ip), f = kind_get(g, coin_kind(self), KnApply);
 word arg = Sp[0], ret = Sp[1], *dst = Sp - 2;
 dst[0] = self, dst[1] = f, dst[2] = arg, dst[3] = ret;
 Sp = dst; Ip = (union u*) numap_drive; ai_musttail return Continue(); }

// (strike kind payload) -> a fresh coin of the kind over the payload.
lvm(lvm_coinmk) {
 Have(Width(struct ai_coin) + Width(struct ai_tag));
 union u *k = (union u*) Hp;
 Hp += Width(struct ai_coin) + Width(struct ai_tag);
 ((struct ai_coin*) k)->ap = lvm_coin;
 ((struct ai_coin*) k)->kind = Sp[0];
 ((struct ai_coin*) k)->payload = Sp[1];
 tagthread(k, Width(struct ai_coin));
 ai_musttail return Push(word(k)); }
// (load x) -> the payload of a coin, else x itself (a plain value loads as itself).
lvm(lvm_load) {
 Sp[0] = coinp(Sp[0]) ? coin_load(Sp[0]) : Sp[0];
 ai_musttail return Next(1); }
// (kind x) -> the nom of the kind x dispatches as: the roster row's (g->kinds), refined
// inside the hot row -- a struck coin's own name, coin for one whose kind has none,
// else lambda, cask, port
lvm(lvm_kind) {
 word x = Sp[0], n = ZeroPoint;
 if (coinp(x)) { n = kind_get(g, coin_kind(x), KnName); if (n == ZeroPoint) n = g->knom[KnCoin]; }
 else if (caskp(x)) n = g->knom[KnCask];
 else if (iop(x)) n = g->knom[KnPort];
 else if (ai_kind(x) == KHot) n = g->knom[KnLambda];
 Sp[0] = n == ZeroPoint ? ai_mapget(g, zero, putcharm(ai_kind(x)), g->kinds) : n;
 ai_musttail return Next(1); }
op11(lvm_coinp, coinp(Sp[0]) ? putcharm(1) : zero)   // (coin? x): a struck coin, and not the rest of the hot row

// apply function to one argument
lvm(lvm_ap) {
 union u *k;
 if (oddp(Sp[1])) ai_musttail return Ap(lvm_numap, g);
 k = cell(Sp[1]), Sp[1] = word(Ip + 1), Ip = k;
 YieldCheck();
 ai_musttail return Continue(); }

// tail call
lvm(lvm_tap) {
 if (oddp(Sp[1])) ai_musttail return Ap(lvm_numtap, g);         // fixnum operator -> num-ap, deliver to caller
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getcharm(Ip[1].x) + 1;
 Ip = cell(j), Sp[0] = x;
 YieldCheck();
 ai_musttail return Continue(); }

// apply to multiple arguments
lvm(lvm_apn) {
 size_t n = getcharm(Ip[1].x);
 union u *r = Ip + 2; // return address
 // this instruction is only emitted when the callee is known to be a function
 // so putting a value off the stack into Ip is safe. the +2 is cause we leave
 // the currying instruction in there... should be skipped in compiler instead FIXME
 Ip = cell(Sp[n]) + 2;
 Sp[n] = word(r); // store return address
 YieldCheck();
 ai_musttail return Continue(); }

// tail call
lvm(lvm_tapn) {
 size_t n = getcharm(Ip[1].x),
        r = getcharm(Ip[2].x);
 Ip = cell(Sp[n]) + 2;
 word *o = Sp;
 for (Sp += r + 1; n--; Sp[n] = o[n]);
 YieldCheck();
 ai_musttail return Continue(); }

// return
lvm(lvm_ret) {
 word n = getcharm(Ip[1].x) + 1;
 Ip = cell(Sp[n]); Sp[n] = Sp[0]; Sp += n; ai_musttail return Continue(); }

lvm(lvm_ret0) { return
 Ip = cell(Sp[1]),
 Sp[1] = Sp[0],
 Sp += 1,
 Continue(); }
// the walkable call-out resume (see callout_resume above): Sp[0]=result, Sp[1]=tag(bb - entry),
// Sp[2]=entry (the blob's W^X base). deliver the result where the blob expects it (Sp[0] on entry,
// two frame words consumed -- the same landing as the retired retB path) and tail-jump the blob's
// resume label. Ip is dead across a call-out (the blobs cache their twin in a Sp slot), so it rides
// through unchanged.
static lvm(lvm_resume) {
 lvm_t *t = (lvm_t*) (Sp[2] + ((word) Sp[1] >> 1));
 Sp[2] = Sp[0];
 Sp += 2;
 ai_musttail return Ap(t, g); }

// kcall : x = Sp[0], k = Ip[1] -> Ip = k, Sp[0] = x
lvm(lvm_kcall) {
 word x = Sp[0];
 union u *stack = Ip + 2, *end = (union u*) ttag(g, stack);
 uintptr_t height = end - stack;
 Have(height);
 *(Sp = memmove(topof(g) - height, stack, height * sizeof(word))) = x;
 Ip = Ip[1].m;
 ai_musttail return Continue(); }

// callk : i = Sp[0], k = Ip + 1 -> Ip = i, Sp[0] = k
lvm(lvm_callk) {
 word f_val = Sp[0];                         // g, the call_cc arg
 if (oddp(f_val)) ai_musttail return Next(1);
 word height = topof(g) - Sp;
 uintptr_t n = 2 + height;                   // lvm_kcall + (ip + 1) + stack = thread_contents
 Have(n + Width(struct ai_tag) + 1);          // thread_contents + thread_tag + 1 stack = _mem_req
 union u *k = (union u*) Hp;
 Hp += n + Width(struct ai_tag);              // thread_contents + thread_tag = _heap_alloc
 k[0].ap = lvm_kcall;                       // 
 k[1].m  = Ip + 1;                           // resume at next instruction
 memcpy(k + 2, Sp, height * sizeof(word));
 Sp -= 1;
 Sp[0] = word(tagthread(k, n));
 Sp[1] = f_val;
 ai_musttail return Ap(lvm_ap, g); }



lvm(lvm_jump) { Ip = Ip[1].m; ai_musttail return Continue(); }
// the only compiled truthiness branch (`?`, and the `&&`/`||` macros). uses the
// language falsy predicate so an all-zero tray (boxed 0.0, zero int box,
// all-zero array) takes the false arm, lifting "0 is the only false scalar".
lvm(lvm_cond) {
 word x = Sp[0];
 if (charmp(x)) { Ip = getcharm(x) <= 0 ? Ip[1].m : Ip + 2; Sp += 1; ai_musttail return Continue(); }
 if (!ai_leafp(x)) ai_musttail return Ap(lvm_measure, g);
 Ip = leaf_nilp(*Sp++) ? Ip[1].m : Ip + 2; ai_musttail return Continue(); }
lvm(lvm_unc) {
 Have1();
 *--Sp = Ip[1].x;
 Ip = Ip[2].m;
 ai_musttail return Continue(); }

lvm(lvm_cur) {
 size_t const S = 3 + Width(struct ai_tag);
 Have(S + 2);
 union u *k = (union u*) Hp, *j = k;
 Hp += S;
 size_t n = getcharm(Ip[1].x);
 // FIXME this does not always need to be a runtime check
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

// load instructions
//
lvm(lvm_quote) {
 Have1();
 Sp -= 1;
 Sp[0] = Ip[1].x;
 Ip += 2;
 ai_musttail return Continue(); }

// a port has no function meaning either: applying it behaves as 0 (yields 1), like
// a cask (byte-identical body, kept distinct by ai_noicf -- see lvm_cask).
lvm(lvm_port_io) {
  Ip = cell(*++Sp);
  *Sp = putcharm(1);
  ai_musttail return Continue(); }

// push a value from the stack
lvm(lvm_arg) {
 Have1();
 Sp[-1] = Sp[getcharm(Ip[1].x)];
 Sp -= 1;
 Ip += 2;
 ai_musttail return Continue(); }

// fused (arg <idx> ; ap): the dominant "call a function on a local" shape, one
// dispatch saved; resume is Ip+2 (2-word op)
lvm(lvm_argap) {
 if (__builtin_expect(oddp(Sp[0]), 0)) {              // fixnum operator -> num-ap, resume at Ip+2
  Have1();
  Sp[-1] = Sp[getcharm(Ip[1].x)], Sp -= 1, Ip += 1;   // push local under operator; resume now Ip+2
  ai_musttail return Ap(lvm_numap, g); }
 Have1();
 Sp[-1] = Sp[getcharm(Ip[1].x)];
 Sp -= 1;
 union u *k = cell(Sp[1]); Sp[1] = word(Ip + 2), Ip = k;
 YieldCheck();
 ai_musttail return Continue(); }

// fused (quote <v> ; ap): a call with a constant arg; resume Ip+2
lvm(lvm_quoteap) {
 if (__builtin_expect(oddp(Sp[0]), 0)) {              // fixnum operator -> num-ap, resume at Ip+2
  Have1();
  Sp[-1] = Ip[1].x, Sp -= 1, Ip += 1;               // push const under operator; resume now Ip+2
  ai_musttail return Ap(lvm_numap, g); }
 Have1();
 Sp -= 1;
 Sp[0] = Ip[1].x;
 union u *k = cell(Sp[1]); Sp[1] = word(Ip + 2), Ip = k;
 YieldCheck();
 ai_musttail return Continue(); }

// fused (arg <idx> ; tap <fs>): the single-arg tail-call shape, e.g. a tail (loop x)
lvm(lvm_argtap) {
 if (__builtin_expect(oddp(Sp[0]), 0)) {              // fixnum operator -> num-ap, deliver to caller
  Have1();
  Sp[-1] = Sp[getcharm(Ip[1].x)], Sp -= 1, Ip += 1;   // push local under operator; fs operand now Ip[1]
  ai_musttail return Ap(lvm_numtap, g); }
 Have1();
 Sp[-1] = Sp[getcharm(Ip[1].x)];
 Sp -= 1;
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getcharm(Ip[2].x) + 1;
 Ip = cell(j), Sp[0] = x;
 YieldCheck();
 ai_musttail return Continue(); }

// operand-specialized arg/quote: 1-word ops for the hottest indices/constants
argn(lvm_arg0, 0) argn(lvm_arg1, 1) argn(lvm_arg2, 2) argn(lvm_arg3, 3)
quon(lvm_quo0, 0) quon(lvm_quo1, 1) quon(lvm_quo2, 2) quon(lvm_quo3, 3)
quon(lvm_quom1, -1) quon(lvm_quom2, -2)

// run fusion: one op for a whole run of consecutive loads, specialized on the
// shape of the run rather than on an operand's value. the name spells the run in
// source order -- `a` an arg (its index the operand), `q` a quote (its constant
// the operand) -- and a trailing `p` says the last load carries the apply (it was
// argap/quoteap). the apply can only sit at the end: an ap hands control away and
// resumes at a fixed Ip, and a run has no dispatchable point in its middle.
//
// the operands ride in source order, so an index is written as the compiler saw
// it -- relative to the Sp of its own load. pushing left to right off a moving Sp
// makes that come out right with no arithmetic: by the time PushA(2) runs, Sp has
// already dropped past the first push, which is exactly the frame the second load
// was compiled against.
#define PushA(k) (Sp[-1] = Sp[getcharm(Ip[k].x)], Sp -= 1)
#define PushQ(k) (Sp[-1] = Ip[k].x, Sp -= 1)
// pure run, 2 loads: op + 2 operands = 3 words.
#define frun2(nom, p1, p2) lvm(nom) { Have(2); p1(1); p2(2); Ip += 3; ai_musttail return Continue(); }
// ... with the apply on the second load. the operator is what the first load
// pushed (cf. lvm_argap, which reads it at Sp[0] before its own push), so the
// fixnum test sits between the two. the numap lane bumps Ip to leave numap's
// `ret = Ip+1` landing past the whole op.
#define frun2p(nom, p1, p2) lvm(nom) { \
 Have(2); p1(1); \
 if (__builtin_expect(oddp(Sp[0]), 0)) { p2(2); Ip += 2; ai_musttail return Ap(lvm_numap, g); } \
 p2(2); \
 union u *k = cell(Sp[1]); Sp[1] = word(Ip + 3), Ip = k; \
 YieldCheck(); \
 ai_musttail return Continue(); }
frun2(lvm_aa, PushA, PushA) frun2(lvm_aq, PushA, PushQ)
frun2(lvm_qa, PushQ, PushA) frun2(lvm_qq, PushQ, PushQ)
frun2p(lvm_aap, PushA, PushA) frun2p(lvm_aqp, PushA, PushQ)
frun2p(lvm_qap, PushQ, PushA) frun2p(lvm_qqp, PushQ, PushQ)
// load + consumer fusion -- the other axis. a run's loads are only half the story:
// something eats them, and measured on the corpus that consumer is overwhelmingly an
// accessor, a predicate or a branch, not arithmetic (cup 133.7M, `?` 128.8M, cap 80.7M,
// two? 77.5M vs + at 5.5M -- 64% of every load dispatch goes into the first four).
// so these fuse `arg` with the op that consumes it: 2 words, exactly what the
// operand-specialized arg0..3 plus a 1-word op already cost, for one dispatch instead
// of two. the parameter is not named `x`: the body says Ip[1].x, and a macro parameter
// of that name would substitute into the member access.
#define fld(nom, val) lvm(nom) { Have1(); word v = Sp[getcharm(Ip[1].x)]; Sp[-1] = (val); Sp -= 1; Ip += 2; ai_musttail return Continue(); }
fld(lvm_argcap, chainp(v) ? A(v) : v)
fld(lvm_argcup, chainp(v) ? B(v) : ZeroPoint)
fld(lvm_argtwo, (chainp(v) && !nomp(v)) ? putcharm(1) : zero)
// arg + cond: the test never reaches the stack at all -- no push, no pop, one op.
// layout [Ip]=argcond [Ip+1]=idx [Ip+2]=else-addr [Ip+3]=then, matching lvm_cond's
// own targets shifted by our operand (cf. the cmp_lt note).
// argcond's operand stays in its argument slot, so a compound is measured under a landing
// cell with the op's own address beside it: [x measure land op], the landing at [ans op ..]
static lvm(lvm_argcond_land) {
 Ip = cell(Sp[1]);
 Ip = leaf_nilp(Sp[0]) ? Ip[2].m : Ip + 3;
 Sp += 2; ai_musttail return Continue(); }
static union u const argcond_land[] = { {.ap = lvm_argcond_land} };
lvm(lvm_argcond) {
 word x = Sp[getcharm(Ip[1].x)];
 if (__builtin_expect(!charmp(x) && !ai_leafp(x), 0)) {
  Have(4);
  word *dst = Sp - 4;
  dst[0] = Sp[getcharm(Ip[1].x)], dst[1] = hot_hook(g->hot_net), dst[2] = word(argcond_land), dst[3] = word(Ip);
  Sp = dst; Ip = (union u*) callout_drive; ai_musttail return Continue(); }
 Ip = leaf_nilp(x) ? Ip[2].m : Ip + 3; ai_musttail return Continue(); }
// ... and the rung above: load + predicate + cond, all three in one op. measured, this
// is where `?` actually lives: only 7.1M conds test a bare local, while 86.1M test the
// result of a fused load+accessor -- `(? (two? b) ..)` is the shape, 64.4M of it. the
// whole test then costs one dispatch and no stack traffic. layout [Ip]=op [Ip+1]=idx
// [Ip+2]=else, so the emit consumes the predicate's op cell and the cond's, no new word.
#define fldc(nom, test) lvm(nom) { word v = Sp[getcharm(Ip[1].x)]; \
 Ip = (test) ? Ip + 3 : Ip[2].m; ai_musttail return Continue(); }
fldc(lvm_argtwocond, chainp(v) && !nomp(v))            // two? answers a charm: no leaf_nilp needed

// the cell doors. peek/poke move values and pick/place instructions -- two pairs because a
// thread cell's kind is its position, not its content, and only reading can decide it: a
// code word is exactly one the op table names, a value word never is. so no code address
// reaches love: pick answers an index, and every door answers () rather than dereferencing
// a charm. what a door cannot know is whether the caller picked the right cell -- pick at a
// value cell and place at an op cell are safe and meaningless. the bounds below are the
// half that IS structural.
//
// a terminator word: the tag bits plus a payload pointing into a live pool. nothing else a
// cell may hold is 2 mod 4 -- a heap pointer is word-aligned, a charm odd, an instruction
// at least 4-aligned (thumb's interworking bit makes it odd instead, and wasm's synthetic
// addresses are laid 8 apart) -- so this misreads no value and no op.
static ai_inline bool ai_termp(struct ai *g, word x) {
 return (x & 3) == ai_thread_tag && in_live_pool(g, (word const*) (x & ~(word) 3)); }

lvm(lvm_trim) {
 if (evenp(Sp[0])) clip(g, cell(Sp[0]));
 return Ip++, Continue(); }

// (seek i v): the cell i steps away, or () if the step leaves the object. an object ends at
// its own terminator, so a step up crosses out exactly when a cell it steps over is one --
// O(|i|), and i is 1 or 2 at every call site. a step down meets the object below only when
// that object is a thread; any other ends in no terminator, so a step down no terminator
// stopped is held to the object's own head, read off its terminator
lvm(lvm_seek) {
 intptr_t i = getcharm(Sp[0]);
 word v = Sp[1], r = ZeroPoint;
 if (evenp(v)) {
  union u *b = cell(v), *e = b + i;
  if (!in_live_pool(g, ptr(b))) r = word(e);       // a static nif run: no terminator to ask
  else if (in_live_pool(g, ptr(e))) {
   union u *p = i < 0 ? e : b + 1, *q = i < 0 ? b : e + 1;
   while (p < q && !ai_termp(g, p->x)) p++;
   if (p == q && (i >= 0 || e >= tag_head(ttag(g, b)))) r = word(e); } }
 return Sp[1] = r, Sp++, Ip++, Continue(); }

// (stem v): the head of the object v points into -- what a lambda's value hides when it
// reserves a leading source cell. (span v): the cells from v up to the terminator, so a
// walk knows its length without stepping to the wall. both () off the heap.
lvm(lvm_stem) { return
 Sp[0] = evenp(Sp[0]) && in_heap(g, Sp[0]) ? word(tag_head(ttag(g, cell(Sp[0])))) : ZeroPoint,
 Ip++, Continue(); }

lvm(lvm_span) { return
 Sp[0] = evenp(Sp[0]) && in_heap(g, Sp[0])
  ? putcharm(cell(ttag(g, cell(Sp[0]))) - cell(Sp[0])) : ZeroPoint,
 Ip++, Continue(); }

// what a cell hands back as a value, or (). the three refusals are all the machine's own
// words, never love's: a terminator (the heap's bookkeeping), an instruction the op table
// names, and a glazed body in the code arena -- which no table names, so `pick` cannot see
// it either and a raw code address would otherwise ride out. a pool pointer is none of the
// three, and asking that first is also what keeps the table scan off the common peek.
static ai_inline word ai_cellval(struct ai *g, word w) {
 if ((w & 3) == ai_thread_tag) return ZeroPoint;
 if (evenp(w) && in_live_pool(g, ptr(w))) return w;
 return ai_op_index((intptr_t) w) >= 0 || (evenp(w) && code_in(g, (uintptr_t) w))
  ? ZeroPoint : w; }

lvm(lvm_peek) {
 word w = evenp(Sp[1]) ? (cell(Sp[1]) + getcharm(Sp[0]))->x : ZeroPoint;
 return Sp[1] = ai_cellval(g, w), Sp++, Ip++, Continue(); }

// (pick i v): the instruction at cell i as its op index, () where a value sits
lvm(lvm_pick) {
 word w = evenp(Sp[1]) ? (cell(Sp[1]) + getcharm(Sp[0]))->x : ZeroPoint;
 intptr_t j = ai_op_index((intptr_t) w);
 return Sp[1] = j < 0 ? ZeroPoint : putcharm(j),
 Sp++, Ip++, Continue(); }

lvm(lvm_poke) {
 if (!evenp(Sp[2])) { *(Sp += 2) = ZeroPoint; ai_musttail return Next(1); }
 union u *c = cell(Sp[2]) + getcharm(Sp[0]);
 Pack(g);                    // ai_young reads g->hp -- the live Hp may be ahead (the lvm-context law)
 if (ai_termp(g, c->x)) { *(Sp += 2) = ZeroPoint; ai_musttail return Next(1); }  // never over the wall
 gen_wb_cell(g, c, Sp[1]);   // poke's contract: the target cell sits in a tagged span (a spin
                             // thread, an env) -- never a chain's field (ev boxes those; a chain
                             // has no terminator for the remembered cell-walk).
 c->x = Sp[1]; *(Sp += 2) = word(c); ai_musttail return Next(1); }

// (place i c v): write instruction c into cell i. the barrier runs as poke's does -- a code
// word roots nothing, but the cell it lands in is the same cell poke's contract describes.
lvm(lvm_place) {
 intptr_t a = charmp(Sp[1]) ? ai_op_resolve(getcharm(Sp[1])) : 0;   // an index is a charm, always
 if (!evenp(Sp[2]) || !a) { *(Sp += 2) = ZeroPoint; ai_musttail return Next(1); }
 union u *c = cell(Sp[2]) + getcharm(Sp[0]);
 Pack(g);
 if (ai_termp(g, c->x)) { *(Sp += 2) = ZeroPoint; ai_musttail return Next(1); }
 gen_wb_cell(g, c, (word) a);
 c->x = (word) a; *(Sp += 2) = word(c); ai_musttail return Next(1); }

lvm(lvm_spin) {
 size_t n = getcharm(Sp[0]);
 Have(n + Width(struct ai_tag));
 union u *k = (union u*) Hp;
 Hp += n + Width(struct ai_tag);
 Sp[0] = word(memset(tagthread(k, n), -1, n * sizeof(word)));
 ai_musttail return Next(1); }
