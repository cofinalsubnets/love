#include "i.h"

static struct g *c0(struct g *f, g_vm_t *y);

// function state using this type
struct env {
 struct env *par; // enclosing scope
 word args, imps, // positional and closure variables
  stack, // computed arguments and let bindings on stack
  lams, // lambdas defined in a local let form
  len,  // thread length accumulator
  branches, // stack for conditional alternate branch addresses
  exits,
  end[]; }; // stach for conditional exit addresses

#define Ana(n, ...) struct g *n(struct g *f, struct env **c, intptr_t x, ##__VA_ARGS__)
#define Cata(n, ...) struct g *n(struct g *f, struct env **c, ##__VA_ARGS__)
typedef Ana(ana);
typedef Cata(cata);
static ana analyze, ana_d, ana_c, ana_l, ana_q, ana_ap;
static Ana(ana_2, word, word);
static cata c1_i, c1_ix, c1_var, c1_yield, c1_ret, c1;
static g_inline Cata(pull) { return g_ok(f) ? ((cata*) pop1(f))(f, c) : f; }

#define incl(e, n) ((e)->len += ((n)<<1))
// generic instruction ana handlers
static g_inline struct g *c0_ix(struct g *f, struct env **c, g_vm_t *i, word x) {
 return incl(*c, 2), g_push(f, 3, c1_ix, i, x); }

static g_inline struct g *c0_i(struct g *f, struct env **c, g_vm_t *i) {
 return incl(*c, 1), g_push(f, 2, c1_i, i); }

static struct g *enscope(struct g *f, struct env *par, word args, word imps) {
 uintptr_t const n = Width(struct env) + Width(struct g_tag);
 f = g_push(f, 3, args, imps, par);
 if (g_ok(f = g_have(f, n))) {
  struct env *c = bump(f, n);
  c->stack = c->branches = c->exits = c->lams = c->len = nil;
  c->args = f->sp[0], c->imps = f->sp[1], c->par = (struct env*) f->sp[2];
  tag_thd((union u*) c->end, (union u*) c);
  f->sp[2] = (word) c, f->sp += 2; }
 return f; }

static word memq(struct g *f, word l, word k) {
 for (; twop(l); l = B(l)) if (eql(f, k, A(l))) return l;
 return 0; }

static word assq(struct g *f, word l, word k) {
 for (; twop(l); l = B(l)) if (eql(f, k, AA(l))) return A(l);
 return 0; }

static struct g *append(struct g *f) {
 uintptr_t i = 0;
 for (word l; g_ok(f) && twop(f->sp[0]); i++)
  l = B(f->sp[0]),
  f->sp[0] = A(f->sp[0]),
  f = g_push(f, 1, l);
 if (!g_ok(f)) return f;
 if (i == 0) return f->sp++, f;
 for (f->sp[0] = f->sp[i + 1]; i--; f = gxr(f));
 if (g_ok(f)) f->sp[1] = f->sp[0], f->sp++;
 return f; }

// don't inline this so callers can tail call optimize
static g_noinline struct g *c0(struct g *f, g_vm_t *y) {
 if (!g_ok(f = enscope(f, (struct env*) nil, nil, nil))) return f;
 struct env *c = (void*) ptr(pop1(f));
 word x = f->sp[0];
 f->sp[0] = (word) c1_yield;
 MM(f, &c); MM(f, &x);
 if (g_ok(f = analyze(f, &c, x)))
   f = c1(c0_ix(f, &c, y, word(f->ip)), &c);
 UM(f), UM(f);
 return f; }

#define Kp (f->ip)
static Cata(c1) {
 uintptr_t l = getnum((*c)->len);
 f = g_have(f, l + Width(struct g_tag));
 if (g_ok(f)) {
  union u *k = bump(f, l + Width(struct g_tag));
  memset(k, -1, l * sizeof(word)), tag_thd(k + l, k);
  Kp = k + l;
  if (g_ok(f = pull(f, c))) clip(f, Kp); }
 return f; }

static Cata(c1_yield) { return f; }

static Cata(c1_cond_pop_exit) { return
 (*c)->exits = B((*c)->exits), // pops cond expression exit address off env stack exits
 pull(f, c); }

static Cata(c1_apn) {
 word arity = pop1(f);
 if (arity == putnum(1)) {
  if (Kp[0].ap == g_vm_ret) Kp[0].ap = g_vm_tap;
  else Kp -= 1, Kp[0].ap = g_vm_ap; }
 else {
  if (Kp[0].ap == g_vm_ret) Kp -= 1, Kp[0].ap = g_vm_tapn, Kp[1].x = arity;
  else Kp -= 2, Kp[0].ap = g_vm_apn, Kp[1].x = arity; }
 return pull(f, c); }


static Cata(c1_i) {
 g_vm_t *i = (void*) pop1(f);
 Kp -= 1;
 Kp[0].ap = i;
 return pull(f, c); }

static Cata(c1_ix) {
 g_vm_t *i = (void*) pop1(f);
 word x = pop1(f);
 Kp -= 2;
 Kp[0].ap = i;
 Kp[1].x = x;
 return pull(f, c); }

static Cata(c1_ar, g_vm_t *i, word ar) { return
 Kp -= 2,
 Kp[0].ap = i,
 Kp[1].x = putnum(ar),
 pull(f, c); }

static Cata(c1_cur) {
 struct env *e = (void*) pop1(f);
 uintptr_t ar = llen(e->args) + llen(e->imps);
 return ar == 1 ? pull(f, c) : c1_ar(f, c, g_vm_cur, ar); }

#define C1(n, ...) static Cata(n) { return __VA_ARGS__, pull(f, c); }
static Cata(c1_ret) {
 struct env *e = (struct env*) pop1(f);
 uintptr_t ar = llen(e->args) + llen(e->imps);
 return c1_ar(f, c, g_vm_ret, ar); }

C1(c1_cond_push_branch, f = gxl(g_push(f, 2, Kp, (*c)->branches)), (*c)->branches = g_ok(f) ? pop1(f) : nil)
C1(c1_cond_push_exit, f = gxl(g_push(f, 2, Kp, (*c)->exits)), (*c)->exits = g_ok(f) ? pop1(f) : nil)
C1(c1_cond_pop_branch, Kp -= 2, Kp[0].ap = g_vm_cond, Kp[1].x = A((*c)->branches), (*c)->branches = B((*c)->branches))

static Cata(c1_cond_exit) {
 union u *a = cell(A((*c)->exits));
 if (a->ap == g_vm_ret || a->ap == g_vm_tap)
  Kp = memcpy(Kp - 2, a, 2 * sizeof(*Kp));
 else if (a->ap == g_vm_tapn)
  Kp = memcpy(Kp - 3, a, 3 * sizeof(*Kp));
 else
  Kp -= 2, Kp[0].ap = g_vm_jump, Kp[1].x = (word) a;
 return pull(f, c); }

static g_vm(_g_vm_yieldk) { return
 Ip = Ip[1].m,
 Pack(f),
 encode(f, g_status_yield); }


static struct g *g_eval(struct g *f) {
 f = c0(f, _g_vm_yieldk);
#if g_tco
 if (g_ok(f)) f = f->ip->ap(f, f->ip, f->hp, f->sp);
#else
 while (g_ok(f)) f = f->ip->ap(f);
 if (g_code_of(f) == g_status_eof) f = g_core_of(f);
#endif
 return f; }

g_vm(g_vm_lazyb) { return
 Ip[0].ap = g_vm_quote,
 Ip[1].x = AB(Ip[1].x),
 Continue(); }

static word lidx(struct g*f, word x, word l) {
 word i = 0;
 for (; twop(l); i++, l = B(l)) if (eql(f, x, A(l))) return i;
 return -1; }

static Ana(ana_v) {
 word y;
 if (!g_ok(f)) return f;
 for (struct env *d = *c;; d = d->par) {
  if (nilp(d)) return (y = g_tget(f, 0, x, f->dict)) ?
   ana_q(f, c, y) :
   (f = gxl(g_push(f, 2, x, (*c)->imps)),
    f = c0_ix(f, c, g_vm_freev, (*c)->imps = g_ok(f) ? pop1(f) : nil),
    f);
  // lambda definition of local let form?
  if ((y = assq(f, d->lams, x))) {
    if (g_ok(f = c0_ix(f, c, g_vm_lazyb, y)))
      f = ana_ap(f, c, BB(f->sp[2]));
    return f; }
  // other definition of local let form?
  if (memq(f, d->stack, x)) return
    c0_ix(f, c, g_vm_arg, putnum(lidx(f, x, d->stack)));
  // closure or lambda argument?
  if (memq(f, d->imps, x) || memq(f, d->args, x)) {
   incl(*c, 2);
   if (d != *c) // if we have found the variable in an enclosing scope then import it
    f = gxl(g_push(f, 2, x, (*c)->imps)),
    x = g_ok(f) ? A((*c)->imps = pop1(f)) : nil;
   return g_push(f, 3, c1_var, x, (*c)->stack); } } }


static Cata(c1_var) {
 word v = pop1(f), i = llen(pop1(f)); // stack inset
 for (word l = (*c)->imps; !nilp(l); l = B(l), i++)
  if (eql(f, v, A(l))) goto out;
 for (word l = (*c)->args; !nilp(l); l = B(l), i++)
  if (eql(f, v, A(l))) break;
out:
 return Kp -= 2,
        Kp[0].ap = g_vm_arg,
        Kp[1].x = putnum(i),
        pull(f, c); }

static g_noinline Ana(analyze) {
 if (symp(x)) return ana_v(f, c, x); // lookup symbol as variable
 if (!twop(x)) return ana_q(f, c, x); // non-pairs are self quoting
 word a = A(x), b = B(x);                        // it must be a pair
 if (!twop(b)) return analyze(f, c, a); // singleton list has value of element
 // if it is a special form then do that
 if (symp(a) && nom(a)->nom && len(nom(a)->nom) == 1)
  switch (*txt(nom(a)->nom)) {
   case '`': return ana_q(f, c, A(b));
   case '\\': return ana_l(f, c, b);
   case ':': return ana_d(f, c, b);
   case '?': return ana_c(f, c, b); }
 return ana_2(f, c, x, a, b); }


static struct g *c0_lambda(struct g *f, struct env **c, intptr_t imps, intptr_t exp) {
 union u *k, *ip;
 struct env *d = NULL;
 MM(f, &d); MM(f, &exp);
 f = enscope(f, *c, exp, imps);

 if (g_ok(f)) {
  d = (struct env*) pop1(f);
  exp = d->args;
  int n = 0; // push exp args onto stack
  for (; twop(B(exp)); exp = B(exp), n++) f = g_push(f, 1, A(exp));
  for (f = push0(f); n--; f = gxr(f));
  exp = A(exp); }

 if (g_ok(f)) {
  d->args = f->sp[0];
  f->sp[0] = (word) c1_yield;
  incl(d, 4);
  f = g_push(f, 2, c1_cur, d);
  f = analyze(f, &d, exp);
  if (g_ok(f = g_push(f, 2, c1_ret, d)))
    ip = f->ip,
    avec(f, ip, f = c1(f, &d)); }

 if (g_ok(f)) k = f->ip, f->ip = ip, f = gxl(g_push(f, 2, k, d->imps));

 return UM(f), UM(f), f; }

static Ana(c0_cond_exit) { return
 incl(*c, 3),
 g_push(analyze(f, c, x), 1, c1_cond_exit); }

static Ana(c0_cond_r) { return
 !twop(x) ? c0_cond_exit(f, c, nil) :
 !twop(B(x)) ? c0_cond_exit(f, c, A(x)) :
 (avec(f, x,
  incl(*c, 2),
  f = analyze(f, c, A(x)),
  f = g_push(f, 1, c1_cond_pop_branch),
  f = c0_cond_exit(f, c, AB(x)),
  f = g_push(f, 1, c1_cond_push_branch),
  f = c0_cond_r(f, c, BB(x))), f); }


static struct g *ana_ap_r2l(struct g *f, struct env **c, word x);
static struct g *ana_ap(struct g *f, struct env **c, intptr_t x) {
 if (!g_ok(f)) return f;
 bool imfp =
  f->sp[0] == (word) c1_ix &&
  f->sp[1] == (word) g_vm_quote &&
  homp(f->sp[2]);
 intptr_t
  ca = llen(x),
  va =
   imfp && cell(f->sp[2])->ap == g_vm_cur ?
    getnum(cell(f->sp[2])[1].x) :
    1;
 bool b1p = ca == 1 && imfp && cell(f->sp[2])[1].ap == g_vm_ret0,
      anp = va == ca && ca > 1,
      bnp = anp && cell(f->sp[2])[3].ap == g_vm_ret0;

 if (b1p) { // inline an instruction
  g_vm_t *i = cell(f->sp[2])->ap;
  f->sp += 3;
  f = c0_i(analyze(f, c, A(x)), c, i);
  return f; }

 if (bnp) { // inline a curried instruction
  g_vm_t *i = cell(f->sp[2])[2].ap;
  f->sp += 3;
  f = c0_i(ana_ap_r2l(f, c, x), c, i); // r2l arg eval
  if (g_ok(f)) while (ca--) (*c)->stack = B((*c)->stack);
  return f; }

 if (g_ok(f = gxl(g_push(f, 3, nil, (*c)->stack, x)))) {
  (*c)->stack = pop1(f), x = pop1(f), MM(f, &x);
  if (anp) { // r2l 1 n-ary ap
   f = ana_ap_r2l(f, c, x),
   incl(*c, 2),
   f = g_push(f, 2, c1_apn, putnum(ca));
   if (g_ok(f)) while (ca--) (*c)->stack = B((*c)->stack); }
  else while (twop(x)) // l2r n 1-ary ap
   f = analyze(f, c, A(x)),
   incl(*c, 2),
   f = g_push(f, 2, c1_apn, putnum(1)),
   x = B(x);
  UM(f), (*c)->stack = B((*c)->stack); }

 return f; }


static struct g *ana_ap_r2l(struct g *f, struct env **c, word x) {
 if (twop(x)) {
  word y = A(x);
  avec(f, y, f = ana_ap_r2l(f, c, B(x)));
  f = analyze(f, c, y);
  f = gxl(g_push(f, 2, nil, (*c)->stack));
  if (g_ok(f)) (*c)->stack = pop1(f); }
 return f; }

static g_inline bool lambp(struct g *f, word x) {
 struct g_str *n;
 return twop(x) && symp(A(x)) && twop(B(x)) &&
  (n = sym(A(x))->nom) && len(n) == 1 && txt(n)[0] == '\\'; }

static g_inline word rev(word l) {
 word m, n = nil;
 while (twop(l)) m = l, l = B(l), B(m) = n, n = m;
 return n; }

static word ldels(struct g *f, word lam, word l);

static g_inline Ana(ana_2, word a, word b) {
 if ((x = g_tget(f, 0, a, g_core_of(f)->macro)))
  return f = g_eval(gxr(gxl(gxl(pushq(gxl(g_push(f, 4, b, nil, nil, x))))))),
         analyze(f, c, g_ok(f) ? pop1(f) : 0);
 return avec(f, b, f = analyze(f, c, a)),
        ana_ap(f, c, b); }

static g_inline Ana(ana_q) { return c0_ix(f, c, g_vm_quote, x); }
static g_inline Ana(ana_l) { return f = c0_lambda(f, c, nil, x),
                                    analyze(f, c, g_ok(f) ? pop1(f) : 0); }
static Ana(c0_cond_r);
static g_inline Ana(ana_c) {
 return !twop(B(x)) ? analyze(f, c, A(x)) :
    (f = g_push(f, 2, x, c1_cond_pop_exit),
     f = c0_cond_r(f, c, g_ok(f) ? pop1(f) : nil),
     g_push(f, 1, c1_cond_push_exit)); }
// this is the longest C function :(
// it handles the let special form in a way to support sequential and recursive binding.
static g_inline struct g *ana_d(struct g *f, struct env **b, word exp) {
 if (!twop(B(exp))) return analyze(f, b, A(exp));
 struct g_r *mm = g_core_of(f)->root;
#define forget() (g_core_of(f)->root=(mm),f)
 MM(f, &exp);
 f = enscope(f, *b, (*b)->args, (*b)->imps);
 if (!g_ok(f)) return forget();
 struct env *q = (struct env*) pop1(f), **c = &q;
 // lots of variables :(
 word nom = nil, def = nil, lam = nil,
      v = nil, d = nil, e = nil;
 MM(f, &nom), MM(f, &def), MM(f, &lam);
 MM(f, &d); MM(f, &e); MM(f, &v); MM(f, &q);

 // collect vars and defs into two lists
 while (twop(exp) && twop(B(exp))) {
  for (d = A(exp), e = AB(exp); twop(d); e = pop1(f), d = A(d)) {
   f = gxl(g_push(f, 2, e, nil));
   f = append(gxl(pushl(g_push(f, 1, B(d)))));
   if (!g_ok(f)) return forget(); }
  f = gxl(g_push(f, 2, d, nom));
  f = gxl(g_push(f, 2, e, def));
  if (!g_ok(f)) return forget();
  def = pop1(f), nom = pop1(f);
  // if it's a lambda compile it and record in lam list
  if (lambp(f, e)) {
   f = g_push(f, 2, d, lam);
   f = gxl(gxr(c0_lambda(f, c, nil, B(e))));
   if (!g_ok(f)) return forget();
   lam = pop1(f); }
  exp = BB(exp); }

 intptr_t ll = llen(nom);
 bool oddp = twop(exp),
      globp = !oddp && nilp((*b)->args); // we check this again later to make global bindings at top level
 if (!oddp) { // if there's no body then evaluate the name of the last definition
  f = gxl(g_push(f, 2, A(nom), nil));
  if (!g_ok(f)) return forget();
  exp = pop1(f); }

 // find closures
 // for each function f with closure C(f)
 // for each function g with closure C(g)
 // if f in C(g) then C(g) include C(f)
 word j, vars, var;
 do for (j = 0, d = lam; twop(d); d = B(d)) // for each bound function variable
  for (e = lam; twop(e); e = B(e)) if (d != e) // for each other bound function variable
   if (memq(f, BB(A(e)), AA(d))) // if you need this function
    for (v = BB(A(d)); twop(v); v = B(v)) // then you need its variables
     if (!memq(f, vars = BB(A(e)), var = A(v))) // only add if it's not already there
      j++,
      f = gxl(g_push(f, 2, var, vars)),
      BB(A(e)) = g_ok(f) ? pop1(f) : nil;
 while (j);

 // now delete defined functions from the closure variable lists
 // they will be bound lazily when the function runs
 for (e = lam; twop(e); BB(A(e)) = ldels(f, lam, BB(A(e))), e = B(e));

 (*c)->lams = lam;
 f = append(gxl(pushl(g_push(f, 2, nom, exp))));

 if (!g_ok(f)) return forget();
 exp = pop1(f);

 //
 // all the code emissions are below here (??)
 //

 for (e = nom, v = def; twop(e); e = B(e), v = B(v))
  if (lambp(f, A(v))) {
   d = assq(f, lam, A(e));
   f = c0_lambda(f, c, BB(d), BA(v));
   if (!g_ok(f)) return forget();
   A(v) = B(d) = pop1(f); }

 nom = rev(nom); // put in literal order
 f = analyze(f, b, exp);
 f = gxl(g_push(f, 2, nil, e = (*b)->stack)); // push function stack rep
 (*b)->stack = g_ok(f) ? pop1(f) : nil;
 for (def = rev(def); twop(nom); nom = B(nom), def = B(def))
  f = analyze(f, b, A(def)),
  f = globp ? c0_ix(f, b, g_vm_defglob, A(nom)) : f,
  f = gxl(g_push(f, 2, A(nom), (*b)->stack)),
  (*b)->stack = g_ok(f) ? pop1(f) : nil;
 return
  (*b)->stack = e,
  incl(*b, 2),
  f = g_push(f, 2, c1_apn, putnum(ll)),
  forget(); }

static word ldels(struct g *f, word lam, word l) {
 if (!twop(l)) return nil;
 word m = ldels(f, lam, B(l));
 if (!assq(f, lam, A(l))) B(l) = m, m = l;
 return m; }

g_vm(g_vm_defglob) {
 Have(3);
 Sp -= 3;
 struct g_tab *t = f->dict;
 word k = Ip[1].x, v = Sp[3];
 return Sp[0] = k, Sp[1] = v, Sp[2] = (word) t, Pack(f),
  !g_ok(f = g_tput(f)) ? gtrap(f) : (Unpack(f), Sp += 1, Ip += 2, Continue()); }

g_vm(g_vm_freev) { return
 Ip[0].ap = g_vm_quote,
 Ip[1].x = g_tget(f, nil, Ip[1].x, f->dict),
 Continue(); }

g_vm(g_vm_eval) { return Ip++, Pack(f),
 !g_ok(f = c0(f, g_vm_jump)) ? gtrap(f) : (Unpack(f), Continue()); }

g_noinline struct g *g_evals_(struct g*f, char const*s) {
 static char const *t = "((:(e a b)(? b(e(ev'ev(A b))(B b))a)e)0)";
 struct ti i = {{g_vm_port_io, putnum(-1), putnum(EOF), putnum(false)}, t, 0};
 f = push0(pushq(push0(g_eval(g_reads(f, (void*) &i)))));
 i.t = s, i.i = 0, i.io.ungetc_buf = putnum(EOF), i.io.eof_seen = putnum(false);
 return g_pop(g_eval(gxr(gxl(gxr(gxl(g_reads(f, (void*) &i)))))), 1); }
