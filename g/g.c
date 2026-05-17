#include "g.h"
#include <stdarg.h>
_Static_assert(sizeof(union u) == sizeof(intptr_t), "cell size equals word size");
_Static_assert(-1 >> 1 == -1, "sign extended shift");
#define nilp(_) (word(_)==g_nil)
#define A(o) two(o)->a
#define B(o) two(o)->b
#define AB(o) A(B(o))
#define AA(o) A(A(o))
#define BA(o) B(A(o))
#define BB(o) B(B(o))
#define len(_)((struct g_vec*)(_))->shape[0]
#define txt(_) ((char*)(((struct g_vec*)(_))->shape+1))
#define avail(f) ((uintptr_t)(f->sp-f->hp))
#define nom(_) sym(_)
#define ptr(_) ((num*)(_))
#define num(_) ((num)(_))
#define word(_) num(_)
#define datp(_) (cell(_)->ap==g_vm_data)
#define avec(f, y, ...) (MM(f,&(y)),(__VA_ARGS__),UM(f))
#define MM(f,r) ((g_core_of(f)->root=&((struct g_r){(word*)(r),g_core_of(f)->root})))
#define UM(f) (g_core_of(f)->root=g_core_of(f)->root->n)

#if UINTPTR_MAX > 0xffffffffu
#define mix ((uintptr_t) 0x9e3779b97f4a7c15) // round(2^64 / phi)
#else
#define mix ((uintptr_t) 0x9e3779b9) // round(2^32 / phi)
#endif

#define odd(_) ((uintptr_t)(_)&1)
#define even(_) !odd(_)
#define typ(_) cell(_)[1].typ
#define cell(_) ((union u*)(_))

#define g_vect_char g_vect_u8
#ifndef EOF
#define EOF -1
#endif
#define Have1() if (Sp == Hp) return Ap(g_vm_gc, f, 1)
#define Have(n) if (Sp < Hp + n) return Ap(g_vm_gc, f, n)
#if g_tco
#define g_status_yield g_status_ok
#else
#define g_status_yield g_status_eof
#endif
#define g_pop1(f) (*(f)->sp++)
#define str_type_width (Width(struct g_vec) + 1)

#define opf(nom, op) g_vm(nom) {\
 intptr_t a = getnum(Sp[0]), b = getnum(Sp[1]);\
 *++Sp = putnum(a op b);\
 return Ip++, Continue(); }
#define op0f(nom, op) g_vm(nom) {\
 intptr_t a = getnum(Sp[0]), b = getnum(Sp[1]);\
 *++Sp = b == 0 ? g_nil : putnum(a op b);\
 return Ip++, Continue(); }
#define op(nom, n, x) g_vm(nom) { intptr_t _ = (x); *(Sp += n-1) = _; Ip++; return Continue(); }
#define op1(nom, i, x) g_vm(nom) { Sp[0] = (x); Ip += i; return Continue(); }
#define op11(nom, x) op1(nom, 1, x)

#define nil g_nil
#define pop1 g_pop1
#define getnum g_getnum
#define putnum g_putnum
#define g_strp strp

struct g_pair { g_vm_t *ap; uintptr_t typ; intptr_t a, b; };
enum q { two_q, vec_q, sym_q, tbl_q, };
typedef g_word num, word;
enum g_vec_type { g_vect_u8, };
static struct g
 *g_please(struct g*, uintptr_t),
 *have(struct g*, uintptr_t),
 *g_tput(struct g*),
 *mktbl(struct g*),
 *intern(struct g*),
 *g_reads(struct g*, struct g_in*),
 *g_read1(struct g*, struct g_in*);
static g_vm(g_vm_gc, uintptr_t);
static g_vm_t
 g_vm_data,  g_vm_putn,   g_vm_nomsym, g_vm_info, g_vm_dot,    g_vm_clock,
 g_vm_nilp,  g_vm_symnom, g_vm_read,   g_vm_putc, g_vm_gensym, g_vm_twop,
 g_vm_len, g_vm_get,
 g_vm_nump,  g_vm_symp,   g_vm_strp,   g_vm_tblp, g_vm_band,   g_vm_bor,
 g_vm_bxor,  g_vm_bsr,    g_vm_bsl,    g_vm_bnot, g_vm_ssub,
 g_vm_scat,   g_vm_cons,   g_vm_car,  g_vm_cdr,    g_vm_puts,
 g_vm_getc,  g_vm_lt,     g_vm_le,     g_vm_eq,   g_vm_gt,     g_vm_ge,
 g_vm_put, g_vm_tdel,   g_vm_tnew,   g_vm_tkeys,
 g_vm_unc, g_vm_poke2, g_vm_peek2,
 g_vm_seek,  g_vm_trim,   g_vm_thda,   g_vm_add,
 g_vm_sub,   g_vm_mul,    g_vm_quot,   g_vm_rem,  g_vm_arg,
 g_vm_quote, g_vm_freev,  g_vm_eval,   g_vm_cond, g_vm_jump,   g_vm_defglob,
 g_vm_ap,    g_vm_tap,    g_vm_apn,    g_vm_tapn, g_vm_ret,    g_vm_lazyb;
static uintptr_t hash(struct g*, word), g_vec_bytes(struct g_vec*);
static int g_putn(struct g *f, struct g_out *o, intptr_t n, uint8_t base);
static struct g_vec *ini_vec(struct g_vec*, uintptr_t, uintptr_t, ...);
static word g_tget(struct g*, word, word, struct g_tab*);
static struct g_atom *intern_checked(struct g*, struct g_vec*);
static g_inline struct g_tag { union u *null, *head, end[]; } *ttag(union u *k) {
 while (k->x) k++;
 return (struct g_tag*) k; }
static g_inline union u *clip(union u *k) { return ttag(k)->head = k; }

// equality comparisons inline the fast identity check
static g_noinline bool eqv(struct g*, word, word); // this is for checking equality of non-identical values
static g_inline bool eql(struct g *f, word a, word b) { return a == b || eqv(f, a, b); }

int memcmp(void const*, void const*, size_t);
void *malloc(size_t), free(void*),
 *memcpy(void*restrict, void const*restrict, size_t),
 *memset(void*, int, size_t);
long strtol(char const*restrict, char**restrict, int);
size_t strlen(char const*);

#define vec(_) ((struct g_vec*)(_))
#define tbl(_) ((struct g_tab*)(_))
#define nump odd
#define two(_) ((struct g_pair*)(_))
#define sym(_) ((struct g_atom*)(_))
static g_inline bool twop(word _) { return even(_) && typ(_) == two_q; }
static g_inline bool tblp(word _) { return even(_) && typ(_) == tbl_q; }
static g_inline bool symp(word _) { return even(_) && typ(_) == sym_q; }
static g_inline bool vec_strp(struct g_vec *s) { return
  s->type == g_vect_char && s->rank == 1; }
static g_inline bool strp(word _) { return
  even(_) && typ(_) == vec_q && vec_strp((struct g_vec*)_); }
static g_inline struct g *encode(struct g*f, enum g_status s) { return
  (struct g*) ((uintptr_t) f | s); }
static g_inline void *bump(struct g *f, uintptr_t n) {
  if (avail(f) < n) __builtin_trap();
  void *x = f->hp; f->hp += n; return x; }
static g_inline struct g_atom *ini_anon(struct g_atom *y, uintptr_t code) {
 return y->ap = g_vm_data, y->typ = sym_q, y->nom = 0, y->code = code, y; }
static g_inline struct g_atom *ini_sym(struct g_atom *y, struct g_vec *nom, uintptr_t code) {
 return y->ap = g_vm_data, y->typ = sym_q, y->nom = nom, y->code = code, y->l = y->r = 0, y; }
static g_inline struct g_vec *ini_str(struct g_vec *s, uintptr_t len) {
 return ini_vec(s, g_vect_char, 1, len), s; }
static g_inline struct g_tab *ini_tab(struct g_tab *t, size_t len, size_t cap, struct g_kvs**tab) {
 return t->ap = g_vm_data, t->typ = tbl_q, t->len = len, t->cap = cap, t->tab = tab, t; }
static g_inline struct g_pair *ini_two(struct g_pair *w, intptr_t a, intptr_t b) {
 return w->ap = g_vm_data, w->typ = two_q, w->a = a, w->b = b, w; }
static g_inline uintptr_t rot(uintptr_t x) {
  int const s = sizeof(uintptr_t) * 4; // shift bits = word bits / 2 = sizeof(word) * 4
  return (x << s) | (x >> s); }

static int g_stdin_getc  (struct g *f, struct g_in *_)        { return ggetc(f); }
static int g_stdin_ungetc(struct g *f, int c, struct g_in *_) { return gungetc(f, c); }
static int g_stdin_eof   (struct g *f, struct g_in *_)        { return geof(f); }
static int g_stdout_putc (struct g *f, int c, struct g_out *_){ return gputc(f, c); }
static struct g_in  g_stdin  = { g_stdin_getc, g_stdin_ungetc, g_stdin_eof };
static struct g_out g_stdout = { g_stdout_putc, gflush };
static struct g *c0(struct g *f, g_vm_t *y);

// function state using this type
struct env {
 struct env *par; // enclosing scope
 word args, imps, // positional and closure variables
  stack, // computed arguments and let bindings on stack
  lams, // lambdas defined in a local let form
  len,  // thread length accumulator
  branches, // stack for conditional alternate branch addresses
  exits; }; // stach for conditional exit addresses

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
 f = g_push(f, 3, args, imps, par);
 uintptr_t const n = Width(struct env);
 if (g_ok(f = have(f, n + Width(struct g_tag)))) {
  union u *k = bump(f, n + Width(struct g_tag));
  struct g_tag *t = (struct g_tag*) (k + n);
  t->null = NULL, t->head = k;
  struct env *c = (struct env*) k;
  c->stack = c->branches = c->exits = c->lams = c->len = nil;
  c->args = f->sp[0], c->imps = f->sp[1], c->par = (struct env*) f->sp[2];
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

static size_t llen(word l) {
 size_t n = 0;
 while (twop(l)) n++, l = B(l);
 return n; }


// don't inline this so callers can tail call optimize
static g_noinline struct g *c0(struct g *f, g_vm_t *y) {
 f = enscope(f, (struct env*) nil, nil, nil);
 if (!g_ok(f)) return f;
 struct env *c = (void*) ptr(pop1(f));
 word x = f->sp[0];
 f->sp[0] = (word) c1_yield;
 MM(f, &c); MM(f, &x);
 if (g_ok(f = analyze(f, &c, x))) f = c0_ix(f, &c, y, word(f->ip));
 if (g_ok(f = c1(f, &c))) UM(f), UM(f);
 return f; }


#define Kp (f->ip)
static Cata(c1) {
 uintptr_t l = getnum((*c)->len);
 f = have(f, l + Width(struct g_tag));
 if (g_ok(f)) {
  union u *k = bump(f, l + Width(struct g_tag));
  struct g_tag *t = (void*) (k + l);
  t->null = NULL;
  t->head = memset(k, -1, l * sizeof(word));
  Kp = (void*) t;
  f = pull(f, c); }
 if (g_ok(f)) clip(f->ip);
 return f; }

static Cata(c1_yield) { return f; }

static Cata(c1_cond_pop_exit) { return
 (*c)->exits = B((*c)->exits), // pops cond expression exit address off env stack exits
 pull(f, c); }

static Cata(c1_apn) {
 word arity = pop1(f);
 if (arity == g_putnum(1)) {
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

static g_vm(g_vm_yieldk) { return
 Ip = Ip[1].m,
 Pack(f),
 encode(f, g_status_yield); }

struct g *g_eval(struct g *f) {
 f = c0(f, g_vm_yieldk);
#if g_tco
 if (g_ok(f)) f = f->ip->ap(f, f->ip, f->hp, f->sp);
#else
 while (g_ok(f)) f = f->ip->ap(f);
 if (g_code_of(f) == g_status_eof) f = g_core_of(f);
#endif
 return f; }

static g_vm(g_vm_lazyb) { return
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


static g_inline struct g *pushl(struct g*f) {
  return intern(g_strof(f, "\\")); }
static g_inline struct g *pushq(struct g*f) {
  return intern(g_strof(f, "`")); }
static g_inline struct g *push0(struct g*f) {
  return g_push(f, 1, nil); }

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
  for (f = g_push(f, 1, nil); n--; f = gxr(f));
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
  even(f->sp[2]);
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
  struct g_vec *n;
  return twop(x) && symp(A(x)) && twop(B(x)) &&
    (n = sym(A(x))->nom) && len(n) == 1 && txt(n)[0] == '\\'; }

static g_inline word reverse(word l) {
 word m, n = nil;
 while (twop(l)) m = l, l = B(l), B(m) = n, n = m;
 return n; }

static word ldels(struct g *f, word lam, word l);

static g_inline Ana(ana_2, word a, word b) {
 if ((x = g_tget(f, 0, a, g_core_of(f)->macro)))
  return f = g_push(f, 4, b, nil, nil, x),
         f = g_eval(gxr(gxl(gxl(pushq(gxl(f)))))),
         analyze(f, c, g_ok(f) ? pop1(f) : 0);
 return avec(f, b, f = analyze(f, c, a)),
        ana_ap(f, c, b); }

static g_inline Ana(ana_q) {
    return c0_ix(f, c, g_vm_quote, x); }
static g_inline Ana(ana_l) {
   return f = c0_lambda(f, c, nil, x),
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

 nom = reverse(nom); // put in literal order
 f = analyze(f, b, exp);
 f = gxl(g_push(f, 2, nil, e = (*b)->stack)); // push function stack rep
 (*b)->stack = g_ok(f) ? pop1(f) : nil;
 for (def = reverse(def); twop(nom); nom = B(nom), def = B(def))
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

static g_vm(g_vm_defglob) {
 Have(3);
 Sp -= 3;
 struct g_tab *t = f->dict;
 word k = Ip[1].x, v = Sp[3];
 return Sp[0] = k, Sp[1] = v, Sp[2] = (word) t, Pack(f),
  !g_ok(f = g_tput(f)) ? f : (Unpack(f), Sp += 1, Ip += 2, Continue()); }

g_vm(g_vm_freev) { return
 Ip[0].ap = g_vm_quote,
 Ip[1].x = g_tget(f, nil, Ip[1].x, f->dict),
 Continue(); }

g_vm(g_vm_eval) { return
 Ip++,
 Pack(f),
 f = c0(f, g_vm_jump),
 !g_ok(f) ? f : (Unpack(f),
                 Continue()); }

struct ti { struct g_in in; char const *t; word i; } ;
static int _eof(struct g*f, struct ti *i) { return !i->t[i->i]; }
static int _getc(struct g*f, struct ti *i) { return _eof(f, i) ? EOF : i->t[i->i++]; }
static int _ungetc(struct g*f, int _, struct ti *i) { return i->t[i->i = i->i ? i->i - 1 : i->i]; }
g_noinline struct g *g_evals(struct g*f, char const*s) {
 static char const *t = "((:(e a b)(? b(e(ev'ev(A b))(B b))a)e)0)";
 struct ti i = {{(void*)_getc, (void*)_ungetc, (void*)_eof}, t, 0};
 f = push0(pushq(push0(g_eval(g_reads(f, (void*) &i)))));
 i.t = s, i.i = 0;
 return g_eval(gxr(gxl(gxr(gxl(g_reads(f, (void*) &i)))))); }

// some libc functions we use
g_vm(g_vm_tnew) {
 Have(Width(struct g_tab) + 1);
 struct g_tab *t = (struct g_tab*) Hp;
 struct g_kvs **tab = (struct g_kvs**) (t + 1);
 return
  Hp += Width(struct g_tab) + 1,
  tab[0] = 0,
  Sp[0] = word(ini_tab(t, 0, 1, tab)),
  Ip++,
  Continue(); }

op11(g_vm_tblp, tblp(Sp[0]) ? putnum(-1) : g_nil)

// relies on table capacity being a power of 2
static g_inline uintptr_t index_of_key(struct g *f, struct g_tab *t, intptr_t k) {
 return (t->cap - 1) & hash(f, k); }

static g_noinline struct g *g_tput(struct g *f) {
 if (!g_ok(f)) return f;
 struct g_tab *t = (struct g_tab*) f->sp[2];
 word v = f->sp[1], k = f->sp[0];
 uintptr_t i = index_of_key(f, t, k);
 struct g_kvs *e = t->tab[i];
 while (e && !eql(f, k, e->key)) e = e->next;

 if (e) return e->val = v, f->sp += 2, f;

 if (!g_ok(f = have(f, Width(struct g_kvs) + 1))) return f;
 e = bump(f, Width(struct g_kvs));
 t = (struct g_tab*) f->sp[2];
 k = f->sp[0], v = f->sp[1];
 e->key = k, e->val = v, e->next = t->tab[i];
 t->tab[i] = e;
 intptr_t cap0 = t->cap, load = ++t->len / cap0;

 if (load < 2) return f->sp += 2, f;

 // grow the table
 intptr_t cap1 = 2 * cap0;
 struct g_kvs **tab0, **tab1;

 if (!g_ok(f = have(f, cap1 + 1))) return f;
 tab1 = bump(f, cap1);
 t = (struct g_tab*) f->sp[2];
 tab0 = t->tab;
 memset(tab1, 0, cap1 * sizeof(intptr_t));
 for (t->cap = cap1, t->tab = tab1; cap0--;)
  for (struct g_kvs *e, *es = tab0[cap0]; es;
   e = es,
   es = es->next,
   i = (cap1-1) & hash(f, e->key),
   e->next = tab1[i],
   tab1[i] = e);

 return f->sp += 2, f; }

static struct g_kvs *gtabdelr(struct g *f, struct g_tab *t, intptr_t k, intptr_t *v, struct g_kvs *e) {
 if (e) {
  if (eql(f, e->key, k)) return
   t->len--,
   *v = e->val,
   e->next;
  e->next = gtabdelr(f, t, k, v, e->next); }
 return e; }

static g_noinline intptr_t gtabdel(struct g *f, struct g_tab *t, intptr_t k, intptr_t v) {
 uintptr_t idx = index_of_key(f, t, k);
 t->tab[idx] = gtabdelr(f, t, k, &v, t->tab[idx]);
 if (t->cap > 1 && t->len / t->cap < 1) {
  intptr_t cap = t->cap;
  struct g_kvs *coll = 0, *x, *y; // collect all entries in one list
  for (intptr_t i = 0; i < cap; i++)
   for (x = t->tab[i], t->tab[i] = 0; x;)
    y = x, x = x->next, y->next = coll, coll = y;
  t->cap = cap >>= 1;
  for (intptr_t i; coll;)
   i = (cap - 1) & hash(f, coll->key),
   x = coll->next,
   coll->next = t->tab[i],
   t->tab[i] = coll,
   coll = x; }
 return v; }

g_vm(g_vm_get) {
  word z = Sp[0], k = Sp[1], x = Sp[2], n;
  if (even(x) && datp(x)) switch (typ(x)) {
    case tbl_q: z = g_tget(f, z, k, tbl(x)); break;
    case vec_q:
      if (nump(k) && (n = getnum(k)) >= 0 && n < (word) len(x))
        z = putnum(txt(x)[n]);
      break;
    case two_q:
      if (nump(k) && (n = getnum(k)) >= 0) {
       while (n-- && twop(x = B(x)));
       if (twop(x)) z = A(x); } }
  return Sp[2] = z, Sp += 2, Ip += 1, Continue(); }

static g_vm(g_vm_put) {
 if (!tblp(Sp[2])) Sp += 2;
 else {
  Pack(f);
  if (!g_ok(f = g_tput(f))) return f;
  Unpack(f); }
 return Ip += 1, Continue(); }

static g_vm(g_vm_tdel) {
 if (tblp(Sp[1])) Sp[2] = gtabdel(f, (struct g_tab*) Sp[1], Sp[2], Sp[0]);
 return Sp += 2, Ip += 1, Continue(); }

static g_vm(g_vm_tkeys) {
 intptr_t list = g_nil;
 if (tblp(Sp[0])) {
  struct g_tab *t = (struct g_tab*) Sp[0];
  intptr_t len = t->len;
  Have(len * Width(struct g_pair));
  struct g_pair *pairs = (struct g_pair*) Hp;
  Hp += len * Width(struct g_pair);
  for (uintptr_t i = t->cap; i;)
   for (struct g_kvs *e = t->tab[--i]; e; e = e->next)
    ini_two(pairs, e->key, list),
    list = (intptr_t) pairs, pairs++; }
 Sp[0] = list;
 Ip += 1;
 return Continue(); }

static struct g *mktbl(struct g*f) {
 if (g_ok(f = have(f, Width(struct g_tab) + 2))) {
  struct g_tab *t = bump(f, Width(struct g_tab) + 1);
  *--f->sp = word(t);
  struct g_kvs **tab = (struct g_kvs**) (t + 1);
  tab[0] = 0, ini_tab(t, 0, 1, tab); }
 return f; }

static g_inline void *off_pool(struct g *f) {
 return f == f->pool ? (word*) f->pool + f->len : (word*) f->pool; }

// iterative structural hash of a pair. the worklist holds deferred
// a-sides while we walk the b-spine in O(1). pairs are immutable and
// eagerly built, so the graph is acyclic and the worklist is bounded by
// the pair count < a semispace. overflow can only mean a mutation bug
// introduced a cycle -- trap rather than run off the end of the space.
static g_noinline uintptr_t hash_two(struct g *f, word x) {
 word *base = off_pool(f), *top = base + f->len, *w = base;
 for (uintptr_t h = mix;; x = *--w) {
  while (twop(x)) {
   if (w == top) __builtin_trap();       // worklist overflow: a cycle
   h = (h ^ mix) * mix;                  // mark a pair node
   *w++ = A(x), x = B(x); }
  h = (h ^ hash(f, x)) * mix;          // x is a leaf: hash won't recur
  if (w == base) return h; } }

// general hashing method...
static uintptr_t hash(struct g *f, intptr_t x) {
 if (nump(x)) return rot(x*mix);
 if (!datp(x)) {
   // it's a function, hash by length
   uintptr_t r = mix, *y = (uintptr_t *) x;
   while (*y++) r ^= r * mix;
   return r; }
 switch (typ(x)) {
   default: __builtin_trap();
   case two_q: return hash_two(f, x);
   case sym_q: return sym(x)->code;
   case tbl_q: return mix;
   case vec_q: {
    uintptr_t len = g_vec_bytes(vec(x)), h = mix;
    for (uint8_t *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return h; } } }


op11(g_vm_car, twop(Sp[0]) ? A(Sp[0]) : Sp[0])
op11(g_vm_cdr, twop(Sp[0]) ? B(Sp[0]) : g_nil)
op11(g_vm_twop, twop(Sp[0]) ? putnum(-1) : g_nil)
g_vm(g_vm_cons) {
 Have(Width(struct g_pair));
 struct g_pair *w = (struct g_pair*) Hp;
 Hp += Width(struct g_pair);
 ini_two(w, Sp[0], Sp[1]);
 *++Sp = word(w);
 Ip++;
 return Continue(); }

struct g *gxl(struct g *f) {
 f = have(f, Width(struct g_pair));
 if (g_ok(f)) {
  struct g_pair *p = bump(f, Width(struct g_pair));
  ini_two(p, f->sp[0], f->sp[1]);
  *++f->sp = (intptr_t) p; }
 return f; }

struct g *gxr(struct g *f) {
 f = have(f, Width(struct g_pair));
 if (g_ok(f)) {
  struct g_pair *p = bump(f, Width(struct g_pair));
  ini_two(p, f->sp[1], f->sp[0]);
  *++f->sp = (intptr_t) p; }
 return f; }

op11(g_vm_strp, strp(Sp[0]) ? putnum(-1) : g_nil)

g_vm(g_vm_ssub) {
 if (!strp(Sp[0])) Sp[2] = g_nil;
 else {
  struct g_vec*s = (struct g_vec*) Sp[0], *t;
  intptr_t i = odd(Sp[1]) ? getnum(Sp[1]) : 0,
           j = odd(Sp[2]) ? getnum(Sp[2]) : 0;
  i = MAX(i, 0), i = MIN(i, (word) len(s));
  j = MAX(j, i), j = MIN(j, (word) len(s));
  if (i == j) Sp[2] = g_nil;
  else {
   size_t req = str_type_width + b2w(j - i);
   Have(req);
   t = (struct g_vec*) Hp;
   Hp += req;
   ini_str(t, j - i);
   memcpy(txt(t), txt(s) + i, j - i);
   Sp[2] = (word) t; } }
 return Ip += 1, Sp += 2, Continue(); }

g_vm(g_vm_scat) {
 intptr_t a = Sp[0], b = Sp[1];
 if (!strp(a)) Sp += 1;
 else if (!strp(b)) Sp[1] = a, Sp += 1;
 else {
  struct g_vec *x = vec(a), *y = vec(b), *z;
  uintptr_t
   len = len(x) + len(y),
   req = str_type_width + b2w(len);
  Have(req);
  z = (struct g_vec*) Hp;
  Hp += req;
  ini_str(z, len);
  memcpy(txt(z), txt(x), len(x));
  memcpy(txt(z) + len(x), txt(y), len(y));
  *++Sp = word(z); }
 return Ip++, Continue(); }

static size_t const vt_size[] = { [g_vect_u8]  = 1, };

uintptr_t g_vec_bytes(struct g_vec *v) {
 uintptr_t len = vt_size[v->type],
           rank = v->rank,
           *shape = v->shape;
 while (rank--) len *= *shape++;
 return sizeof(struct g_vec) + v->rank * sizeof(word) + len; }

static void ini_vecv(struct g_vec *v, uintptr_t type, uintptr_t rank, va_list xs) {
 uintptr_t *shape = v->shape;
 v->ap = g_vm_data;
 v->typ = vec_q;
 v->type = type;
 v->rank = rank;
 while (rank--) *shape++ = va_arg(xs, uintptr_t); }

static struct g_vec *ini_vec(struct g_vec *v, uintptr_t type, uintptr_t rank, ...) {
 va_list xs;
 va_start(xs, rank);
 ini_vecv(v, type, rank, xs);
 va_end(xs);
 return v; }

static struct g *vec0(struct g*f, uintptr_t type, uintptr_t rank, ...) {
 uintptr_t len = vt_size[type];
 va_list xs;
 va_start(xs, rank);
 for (uintptr_t i = rank; i--; len *= va_arg(xs, uintptr_t));
 va_end(xs);
 uintptr_t nbytes = sizeof(struct g_vec) + rank * sizeof(word) + len,
           ncells = b2w(nbytes);
 f = have(f, ncells + 1);
 if (g_ok(f)) {
  struct g_vec *v = bump(f, ncells);
  *--f->sp = word(v);
  va_start(xs, rank);
  ini_vecv(v, type, rank, xs);
  memset(v->shape + rank, 0, len);
  va_end(xs); }
 return f; }

struct g *g_strof(struct g *f, char const *cs) {
 uintptr_t len = strlen(cs);
 f = vec0(f, g_vect_char, 1, len);
 if (g_ok(f)) memcpy(txt(f->sp[0]), cs, len);
 return f; }

g_vm(g_vm_gensym) {
 if (strp(Sp[0])) return Ap(g_vm_nomsym, f);
 uintptr_t const req = Width(struct g_atom) - 2;
 Have(req);
 struct g_atom *y = (struct g_atom*) Hp;
 return
  Hp += req,
  ini_anon(y, g_clock()),
  Sp[0] = word(y),
  Ip += 1,
  Continue(); }

g_vm(g_vm_symnom) {
 intptr_t y = Sp[0];
 return
  y = symp(y) && sym(y)->nom ? word(sym(y)->nom) : g_nil,
  Sp[0] = y,
  Ip += 1,
  Continue(); }

static struct g *intern(struct g*f) {
 if (g_ok(f = have(f, Width(struct g_atom))))
  f->sp[0] = (word) intern_checked(f, (struct g_vec*) f->sp[0]);
 return f; }

// avail must be >= Width(struct g_atom) when this is called.
static  g_noinline struct g_atom *intern_checked(struct g *v, struct g_vec *b) {
 uintptr_t h = rot(hash(v, word(b)));
 for (struct g_atom **y = &v->symbols, *z;;) {
  if (!(z = *y)) return *y = ini_sym(bump(v, Width(struct g_atom)), b, h);
  struct g_vec *a = z->nom;
  intptr_t i = z->code < h ? -1 : z->code > h ? 1 : 0;
  if (i == 0) i = len(a) - len(b);
  if (i == 0) i = memcmp(txt(a), txt(b), len(b));
  if (i == 0) return z;
  y = i < 0 ? &z->l : &z->r; } }


op11(g_vm_symp, symp(Sp[0]) ? putnum(-1) : g_nil)

g_vm(g_vm_nomsym) {
 Have(Width(struct g_atom));
 struct g_atom *y;
 return
  Pack(f),
  y = intern_checked(f, (struct g_vec*) f->sp[0]),
  Unpack(f),
  Sp[0] = word(y),
  Ip += 1,
  Continue(); }

static struct g *grbufn(struct g *f) {
 if (g_ok(f = have(f, str_type_width + 2))) {
  union u *k = bump(f, str_type_width + 1);
  *--f->sp = word(k);
  struct g_vec *o = (struct g_vec*) k;
  ini_str(o, sizeof(intptr_t)); }
 return f; }

static struct g *grbufg(struct g *f) {
 if (!g_ok(f)) return f;
 size_t len = len(f->sp[0]),
        req = str_type_width + 2 * b2w(len);
 if (g_ok(f = have(f, req))) {
  struct g_vec *o = bump(f, req);
  ini_str(o, 2 * len);
  memcpy(txt(o), txt(f->sp[0]), len);
  f->sp[0] = (word) o; }
 return f; }

////
/// " the parser "
//
//
// get the next significant character from the stream
static int g_r_getc(struct g*f, struct g_in *i) {
 for (int c;;) switch (c = i->getc(f, i)) {
  default: return c;
  case '#': case ';':
   while (!i->eof(f, i) && (c = i->getc(f, i)) != '\n' && c != '\r');
  case 0: case ' ': case '\t': case '\n': case '\r': case '\f':
   continue; } }


static struct g *g_read1(struct g*f, struct g_in *i) {
 if (!g_ok(f)) return f;
 int c = g_r_getc(f, i);
 switch (c) {
  case '(':  return g_reads(f, i);
  case ')': case EOF:  return encode(f, g_status_eof);
  case '\'': return gxl(pushq(gxr(g_push(g_read1(f, i), 1, g_nil))));
  case '"': {
   size_t n = 0;
   f = grbufn(f);
   for (size_t lim = sizeof(word); g_ok(f); f = grbufg(f), lim *= 2)
    for (struct g_vec *b = (struct g_vec*) f->sp[0]; n < lim; txt(b)[n++] = c)
     if ((c = i->getc(f, i)) == EOF || c == '"' ||
         (c == '\\' && (c =i->getc(f, i)) == EOF))
      return len(b) = n, f;
   return f; } }

 uintptr_t n = 1, lim = sizeof(intptr_t);
 if (g_ok(f = grbufn(f)))
  for (txt(f->sp[0])[0] = c; g_ok(f); f = grbufg(f), lim *= 2)
   for (struct g_vec *b = (struct g_vec*) f->sp[0]; n < lim; txt(b)[n++] = c)
    switch (c = i->getc(f, i)) {
     default: continue;
     case ' ': case '\n': case '\t': case '\r': case '\f': case ';': case '#':
     case '(': case ')': case '"': case '\'': case 0 : case EOF:
      i->ungetc(f, c, i);
      len(b) = n;
      txt(b)[n] = 0; // zero terminate for strtol ; n < lim so this is safe
      char *e;
      long j = strtol(txt(b), &e, 0);
      if (*e == 0) f->sp[0] = putnum(j);
      else f = intern(f);
      return f; }
 return f; }

static struct g *g_reads(struct g *f, struct g_in* i) {
 intptr_t n = 0;
 for (int c; g_ok(f); n++) {
  c = g_r_getc(f, i);
  if (c == EOF || c == ')') break;
  i->ungetc(f, c, i);
  f = g_read1(f, i); }
 for (f = g_push(f, 1, g_nil); n--; f = gxr(f));
 return f; }

static g_vm(g_vm_read) {
 switch (Pack(f), g_code_of(f = g_read1(f, &g_stdin))) {
  default: return f;
  case g_status_eof:
   f = g_core_of(f); // nothing to read
   Unpack(f);
   Ip += 1;
   return Continue();
  case g_status_ok:
   Unpack(f);
   Sp[1] = Sp[0];
   Sp += 1;
   Ip += 1;
   return Continue(); } }

static g_vm(g_vm_getc) {
 Pack(f);
 int i = ggetc(f);
 Unpack(f);
 Sp[0] = putnum(i);
 Ip += 1;
 return Continue(); }

int gputs(struct g*f, char const*s) {
 int n = 0;
 while (*s) n += gputc(f, *s++);
 return n; }

static int g_putn(struct g *f, struct g_out *o, intptr_t n, uint8_t b) {
 uintptr_t
  m = n >= 0 || b != 10 ? (uintptr_t) n : (o->putc(f, '-', o), -(uintptr_t) n),
  q = m / b,
  r = m % b;
 if (q) g_putn(f, o, q, b);
 return o->putc(f, g_digits[r], o); }

static int gvfprintf(struct g*f, struct g_out*o, char const *fmt, va_list xs) {
 int c;
 while ((c = *fmt++)) {
  if (c != '%') o->putc(f, c, o);
  else pass: switch ((c = *fmt++)) {
   case 0: return c;
   case 'l': goto pass;
   case 'b': c = g_putn(f, o, va_arg(xs, uintptr_t), 2); continue;
   case 'o': c = g_putn(f, o, va_arg(xs, uintptr_t), 8); continue;
   case 'd': c = g_putn(f, o, va_arg(xs, uintptr_t), 10); continue;
   case 'x': c = g_putn(f, o, va_arg(xs, uintptr_t), 16); continue;
   default: c = o->putc(f, c, o); } }
 return c; }

static int gfprintf(struct g *f, struct g_out *o, char const *fmt, ...) {
 va_list xs;
 va_start(xs, fmt);
 int r = gvfprintf(f, o, fmt, xs);
 va_end(xs);
 return r; }



static int gfputx(struct g *f, struct g_out *o, intptr_t x) {
 if (nump(x)) return gfprintf(f, o, "%d", getnum(x));
 if (!datp(x)) return gfprintf(f, o, "#%lx", (long) x);
 switch (typ(x)) {
   default: __builtin_trap();
   case two_q: {
     struct g_vec *n;
     if (symp(A(x)) && (n = sym(A(x))->nom) && len(n) == 1 && txt(n)[0] == '`' && twop(B(x)))
       return o->putc(f, '\'', o), gfputx(f, o, AB(x));
     for (o->putc(f, '(', o);; o->putc(f, ' ', o), x = B(x)) {
      gfputx(f, o, A(x));
      if (!twop(B(x))) return o->putc(f, ')', o); } }
   case vec_q: {
     struct g_vec *v = vec(x);
     int r = 0;
     if (!vec_strp(v)) {
      uintptr_t type = v->type, rank = v->rank, *shape = v->shape;
      r = gfprintf(f, o, "#vec@%x:%d.%d", v, type, rank);
      for (uintptr_t i = rank, *j = shape; i--; r = gfprintf(f, o, ".%d", (intptr_t) *j++)); }
     else {
      uintptr_t len = len(v);
      char *text = txt(v);
      o->putc(f, '"', o);
      for (char c; len--; o->putc(f, c, o))
       if ((c = *text++) == '\\' || c == '"') o->putc(f, '\\', o);
      r = o->putc(f, '"', o); }
     return r; }
   case sym_q: {
     int r = 0;
     struct g_vec *s = sym(x)->nom;
     if (s && vec_strp(s)) for (uintptr_t i = 0; i < len(s); r = o->putc(f, txt(s)[i++], o));
     else r = gfprintf(f, o, "#sym@%x", x);
     return r; }
   case tbl_q: return gfprintf(f, o, "#tab:%d/%d@%x", tbl(x)->len, tbl(x)->cap, x); } }

int gputx(struct g*f, word x) {
 return gfputx(f, &g_stdout, x); }
int gputn(struct g*f, intptr_t n, uint8_t b) {
  return g_putn(f, &g_stdout, n, b); }

static g_vm(g_vm_putc) {
 gputc(f, getnum(*Sp));
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_puts) {
 if (strp(Sp[0])) {
  struct g_vec *s = vec(Sp[0]);
  for (uintptr_t i = 0; i < len(s);) gputc(f, txt(s)[i++]);
  gflush(f); }
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_putn) {
 uintptr_t n = getnum(Sp[0]), b = getnum(Sp[1]);
 g_putn(f, &g_stdout, n, b);
 Sp[1] = Sp[0];
 Sp += 1;
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_dot) { return
 gfputx(f, &g_stdout, Sp[0]),
 Ip += 1,
 Continue(); }

static g_noinline bool eqv(struct g *f, word a, word b) {
 word *base = off_pool(f), *top = base + f->len, *w = base;
 for (;;) {
  if (a != b) {
   if (((a | b) & 1) || !datp(a) || !datp(b) || typ(a) != typ(b)) return false;
   switch (typ(a)) {
    default: return false;
    case two_q:
     if (top - w < 2) __builtin_trap();     // worklist overflow: a cycle
     *w++ = B(a), *w++ = B(b), a = A(a), b = A(b);
     continue;
    case vec_q: {
     size_t la = g_vec_bytes(vec(a)), lb = g_vec_bytes(vec(b));
     if (la != lb || memcmp(vec(a), vec(b), la)) return false; } } }
  if (w == base) return true;              // worklist drained: all equal
  b = *--w, a = *--w; } }

opf(g_vm_bsr, >>)
opf(g_vm_bsl, <<)
opf(g_vm_mul, *)

op0f(g_vm_quot, /)
op0f(g_vm_rem, %)
op(g_vm_add, 2, (Sp[0]+Sp[1]-1)|1)
op(g_vm_sub, 2, (Sp[0]-Sp[1])|1)
op(g_vm_eq, 2, eql(f, Sp[0], Sp[1]) ? putnum(-1) : g_nil)
op(g_vm_lt, 2, Sp[0] < Sp[1] ? putnum(-1) : g_nil)
op(g_vm_le, 2, Sp[0] <= Sp[1] ? putnum(-1) : g_nil)
op(g_vm_gt, 2, Sp[0] > Sp[1] ? putnum(-1) : g_nil)
op(g_vm_ge, 2, Sp[0] >= Sp[1] ? putnum(-1) : g_nil)
op(g_vm_bnot, 1, ~Sp[0] | 1)
op(g_vm_band, 2, (Sp[0] & Sp[1]) | 1)
op(g_vm_bor, 2, (Sp[0] | Sp[1]) | 1)
op(g_vm_bxor, 2, (Sp[0] ^ Sp[1]) | 1)
op(g_vm_nump, 1, odd(Sp[0]) ? putnum(-1) : g_nil)
op11(g_vm_nilp, nilp(Sp[0]) ? putnum(-1) : g_nil)

static g_vm(g_vm_info) {
 size_t const req = 4 * Width(struct g_pair);
 Have(req);
 struct g_pair *si = (struct g_pair*) Hp;
 Hp += req;
 Sp[0] = word(si);
 ini_two(si, putnum(f), word(si + 1));
 ini_two(si + 1, putnum(f->len), word(si + 2));
 ini_two(si + 2, putnum(Hp - ptr(f)), word(si + 3));
 ini_two(si + 3, putnum(ptr(f) + f->len - Sp), g_nil);
 Ip += 1;
 return Continue(); }

op11(g_vm_clock, putnum(g_clock() - getnum(Sp[0])))
static g_vm(g_vm_unc) {
  Have1();
  *--Sp = Ip[1].x;
  Ip = Ip[2].m;
  return Continue(); }

g_vm(g_vm_cur) {
 size_t const S = 3 + Width(struct g_tag);
 Have(S + 2);
 union u *k = (union u*) Hp, *j = k;
 Hp += S;
 size_t n = getnum(Ip[1].x);
 // FIXME this does not always need to be a runtime check
 if (n > 2) Hp += 2,
            j += 2,
            k[0].ap = g_vm_cur,
            k[1].x = putnum(n - 1);
 return
  j[0].ap = g_vm_unc,
  j[1].x = *Sp++,
  j[2].m = Ip + 2,
  j[3].x = 0,
  j[4].m = k,
  Ip = cell(*Sp),
  Sp[0] = word(k),
  Continue(); }

static g_vm(g_vm_jump) { return Ip = Ip[1].m, Continue(); }
static g_vm(g_vm_cond) { return Ip = nilp(*Sp++) ? Ip[1].m : Ip + 2, Continue(); }

// load instructions
//
static g_vm(g_vm_quote) {
 Have1();
 Sp -= 1;
 Sp[0] = Ip[1].x;
 Ip += 2;
 return Continue(); }

static g_vm(g_vm_data) {
 intptr_t x = word(Ip);
 Sp += 1;
 Ip = cell(Sp[0]);
 Sp[0] = x;
 return Continue(); }


// push a value from the stack
static g_vm(g_vm_arg) {
 Have1();
 Sp[-1] = Sp[getnum(Ip[1].x)];
 Sp -= 1;
 Ip += 2;
 return Continue(); }

// call and return
// apply function to one argument
static g_vm(g_vm_ap) {
 union u *k;
 if (odd(Sp[1])) Ip++, Sp++;
 else k = cell(Sp[1]), Sp[1] = word(Ip + 1), Ip = k;
 return Continue(); }

// tail call
static g_vm(g_vm_tap) {
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getnum(Ip[1].x) + 1;
 if (even(j)) Ip = cell(j), Sp[0] = x;
 else Sp += 1, Ip = cell(Sp[0]), Sp[0] = j;
 return Continue(); }

// apply to multiple arguments
static g_vm(g_vm_apn) {
 size_t n = getnum(Ip[1].x);
 union u *r = Ip + 2; // return address
 // this instruction is only emitted when the callee is known to be a function
 // so putting a value off the stack into Ip is safe. the +2 is cause we leave
 // the currying instruction in there... should be skipped in compiler instead FIXME
 Ip = cell(Sp[n]) + 2;
 Sp[n] = word(r); // store return address
 return Continue(); }

// tail call
static g_vm(g_vm_tapn) {
 size_t n = getnum(Ip[1].x),
        r = getnum(Ip[2].x);
 Ip = cell(Sp[n]) + 2;
 word *o = Sp;
 for (Sp += r + 1; n--; Sp[n] = o[n]);
 return Continue(); }

// return
static g_vm(g_vm_ret) {
 word n = getnum(Ip[1].x) + 1;
 Ip = cell(Sp[n]);
 Sp[n] = Sp[0];
 Sp += n;
 return Continue(); }

g_vm(g_vm_ret0) { return
 Ip = cell(Sp[1]),
 Sp[1] = Sp[0],
 Sp += 1,
 Continue(); }

static g_noinline g_vm(g_vm_gc, uintptr_t n) {
  Pack(f);
  f = g_please(f, n);
  if (g_ok(f)) return Unpack(f), Continue();
  return f; }

static g_vm(g_vm_trim) {
 clip(cell(Sp[0]));
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_seek) {
 Sp[1] = word(cell(Sp[1]) + getnum(Sp[0]));
 Sp += 1;
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_peek2) {
 Sp[1] = (cell(Sp[1]) + getnum(Sp[0]))->x;
 Sp += 1;
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_poke2) {
 union u *c = cell(Sp[2]) + getnum(Sp[0]);
 c->x = Sp[1];
 Sp[2] = (word) c;
 Sp += 2;
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_thda) {
 size_t n = getnum(Sp[0]);
 Have(n + Width(struct g_tag));
 union u *k = (union u*) Hp;
 Hp += n + Width(struct g_tag);
 struct g_tag *t = (void*) (k + n);
 t->null = NULL;
 t->head = k;
 memset(k, -1, n * sizeof(word));
 Sp[0] = word(k);
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_len) {
  word x = Sp[0], l = 0;
  if (!nump(x) && datp(x)) switch (typ(x)) {
    case tbl_q: l = tbl(x)->len; break;
    case vec_q: l = vec(x)->shape[0]; break;
    case two_q: do l++, x = B(x); while (twop(x)); }
  Sp[0] = putnum(l);
  Ip += 1;
  return Continue(); }


static word gcp(struct g*, word, word const *, word const *);

static g_inline struct g *have(struct g *f, uintptr_t n) {
 return !g_ok(f) || avail(f) >= n ? f : g_please(f, n); }

static struct g *g_pushr(struct g *f, uintptr_t m, uintptr_t n, va_list xs) {
 if (n == m) return g_please(f, m);
 word x = va_arg(xs, word);
 MM(f, &x);
 f = g_pushr(f, m, n + 1, xs);
 UM(f);
 if (g_ok(f)) *--f->sp = x;
 return f; }

struct g *g_push(struct g *f, uintptr_t m, ...) {
 if (!g_ok(f)) return f;
 va_list xs;
 va_start(xs, m);
 uintptr_t n = 0;
 if (avail(f) < m) f = g_pushr(f, m, n, xs);
 else for (f->sp -= m; n < m; f->sp[n++] = va_arg(xs, word));
 va_end(xs);
 return f; }

static g_inline void evac_data(struct g *g, word const *const p0, word const*const t0) {
  switch (typ(g->cp)) {
   default: __builtin_trap();
   case vec_q:
     g->cp += b2w(g_vec_bytes(vec(g->cp))); return;
   case sym_q:
     g->cp += Width(struct g_atom) - (sym(g->cp)->nom ? 0 : 2); return;
   case two_q: {
     struct g_pair *w = (struct g_pair*) g->cp;
     g->cp += Width(struct g_pair);
     w->a = gcp(g, w->a, p0, t0);
     w->b = gcp(g, w->b, p0, t0);
     return; }
   case tbl_q: {
     struct g_tab *t = (struct g_tab*) g->cp;
     g->cp += Width(struct g_tab) + t->cap + t->len * Width(struct g_kvs);
     for (intptr_t i = 0, lim = t->cap; i < lim; i++)
      for (struct g_kvs*e = t->tab[i]; e;
       e->key = gcp(g, e->key, p0, t0),
       e->val = gcp(g, e->val, p0, t0),
       e = e->next);
     return; } } }

static g_inline void evac_thd(struct g *g, word const *const p0, word const*const t0) {
  for (g->cp += 2; g->cp[-2]; g->cp[-2] = gcp(g, g->cp[-2], p0, t0), g->cp++); }

static g_noinline struct g *gcg(struct g*g, struct g *p1, uintptr_t len1, struct g *f) {
 memcpy(g, f, sizeof(struct g));
 g->pool = (void*) p1;
 g->len = len1;
 uintptr_t const len0 = f->len;
 word const *p0 = ptr(f),
            *t0 = ptr(f) + len0, // source top
            *sp0 = f->sp;
 word h = t0 - sp0; // stack height
 g->sp = ptr(g) + len1 - h;
 g->hp = g->cp = g->end;
 g->ip = cell(gcp(g, word(g->ip), p0, t0));
 g->symbols = 0;
 for (word i = 0; i < g->end - &g->v0; i++) (&g->v0)[i] = gcp(g, (&g->v0)[i], p0, t0);               // core live variables
 for (word n = 0; n < h; n++) g->sp[n] = gcp(g, sp0[n], p0, t0);                     // stack
 for (struct g_r *s = g->root; s; s = s->n) *s->x = gcp(g, *s->x, p0, t0); // C live variables
 while (g->cp < g->hp) (datp(g->cp) ? evac_data : evac_thd)(g, p0, t0);              // cheney algorithm
 // done
 return g; }


static g_noinline struct g *g_please(struct g *f, uintptr_t req0) {
 uintptr_t const
  t0 = f->t0, // end of last gc period
  t1 = g_clock(), // end of current non-gc period
  len0 = f->len;
 // find alternate pool
 struct g *g = off_pool(f);
 f = gcg(g, f->pool, f->len, f);
 uintptr_t const
  v_lo = 4,
  v_hi = v_lo * v_lo,
  req = req0 + len0 - avail(f),
  t2 = g_clock();
 uintptr_t
  len1 = len0,
  v = t2 == t1 ? v_hi : (t2 - t0) / (t2 - t1);
 if (len1 < req || v < v_lo) // if too small
  do len1 <<= 1, v <<= 1; // then grow
  while (len1 < req || v < v_lo);
 else if (len1 > 2 * req && v > v_hi) // else if too big
  do len1 >>= 1, v >>= 1; // then shrink
  while (len1 > 2 * req && v > v_hi);
 else return f->t0 = t2, f; // else right size -> all done
 return // allocate a new pool with target size
  !(g = f->malloc(f, len1 * 2 * sizeof(word))) ? // if malloc fails but pool is big enough
   encode(f, req <= len0 ? g_status_ok : g_status_oom) : // we can still report success
  (g = gcg(g, g, len1, f),
   f->free(f, f->pool),
   g->t0 = g_clock(),
   g); }


static g_inline word copy_data(struct g *f, union u *src, word const *const p0, word const *const t0) {
 switch (typ(src)) {
  default: __builtin_trap();
  case two_q: {
   struct g_pair *dst = bump(f, Width(struct g_pair));
   ini_two(dst, A(src), B(src));
   src->ap = (g_vm_t*) dst;
   return word(dst); }
  case vec_q: {
   uintptr_t bytes = g_vec_bytes(vec(src));
   struct g_vec *dst = bump(f, b2w(bytes));
   src->ap = memcpy(dst, src, bytes);
   return word(dst); }
  case sym_q: {
   struct g_atom *dst;
   if (sym(src)->nom) dst = intern_checked(f, (struct g_vec*) gcp(f, word(sym(src)->nom), p0, t0));
   else dst = bump(f, Width(struct g_atom) - 2),
        ini_anon(dst, sym(src)->code);
   return word(src->ap = (g_vm_t*) dst); }
  case tbl_q: {
   uintptr_t len = tbl(src)->len, cap = tbl(src)->cap;
   struct g_tab *dst = bump(f, Width(struct g_tab) + cap + Width(struct g_kvs) * len);
   struct g_kvs **tab = (struct g_kvs**) (dst + 1),
                *dd = (struct g_kvs*) (tab + cap);
   ini_tab(dst, len, cap, tab);
   src->ap = (g_vm_t*) dst;
   for (struct g_kvs *d, *s, *last; cap--; tab[cap] = last)
    for (s = tbl(src)->tab[cap], last = NULL; s;
     d = dd++, d->key = s->key, d->val = s->val, d->next = last,
     last = d, s = s->next);
   return word(dst); } } }

static g_inline word copy_thread(struct g *f, union u *src, word const *const p0, word const *const t0) {
 // it's a thread, find the end to find the head
 struct g_tag *t = ttag(src);
 union u *ini = t->head, *d = bump(f, t->end - ini), *dst = d;
 // copy source contents to dest and write dest addresses to source
 for (union u*s = ini; (d->x = s->x); s++->x = (word) d++);
 ((struct g_tag*) d)->head = dst;
 return (word) (dst + (src - ini)); }

static g_noinline intptr_t gcp(struct g *f, word x, word const *p0, word const *t0) {
 // if it's a number or it's outside managed memory then return it
 if (nump(x) || ptr(x) < p0 || ptr(x) >= t0) return x;
 union u *src = cell(x);
 x = src->x; // get its contents
 // if it contains a pointer to the new space then return the pointer
 return even(x) && ptr(f) <= ptr(x) && ptr(x) < ptr(f) + f->len ? x :
        x == (word) g_vm_data ? copy_data(f, src, p0, t0) :
                                copy_thread(f, src, p0, t0); }


enum g_status g_fin(struct g *f) {
 enum g_status s = g_code_of(f);
 if ((f = g_core_of(f))) f->free(f, f->pool);
 return s; }

#define S1(i) {{i}, {g_vm_ret0}}
#define S2(i) {{g_vm_cur},{.x=putnum(2)},{i}, {g_vm_ret0}}
#define S3(i) {{g_vm_cur},{.x=putnum(3)},{i}, {g_vm_ret0}}
#define bifs(_) \
 _(bif_clock, "clock", S1(g_vm_clock)) _(bif_addr, "vminfo", S1(g_vm_info))\
 _(bif_add, "+", S2(g_vm_add)) _(bif_sub, "-", S2(g_vm_sub)) _(bif_mul, "*", S2(g_vm_mul))\
 _(bif_quot, "/", S2(g_vm_quot)) _(bif_rem, "%", S2(g_vm_rem)) \
 _(bif_lt, "<", S2(g_vm_lt))  _(bif_le, "<=", S2(g_vm_le)) _(bif_eq, "=", S2(g_vm_eq))\
 _(bif_ge, ">=", S2(g_vm_ge))  _(bif_gt, ">", S2(g_vm_gt)) \
 _(bif_bnot, "~", S1(g_vm_bnot)) _(bif_bsl, "<<", S2(g_vm_bsl)) _(bif_bsr, ">>", S2(g_vm_bsr))\
 _(bif_band, "&", S2(g_vm_band)) _(bif_bor, "|", S2(g_vm_bor)) _(bif_bxor, "^", S2(g_vm_bxor))\
 _(bif_cons, "X", S2(g_vm_cons)) _(bif_car, "A", S1(g_vm_car)) _(bif_cdr, "B", S1(g_vm_cdr)) \
 _(bif_cons2, "cons", S2(g_vm_cons)) _(bif_car2, "car", S1(g_vm_car)) _(bif_cdr2, "cdr", S1(g_vm_cdr)) \
 _(bif_ssub, "ssub", S3(g_vm_ssub)) _(bif_scat, "scat", S2(g_vm_scat)) \
 _(bif_dot, ".", S1(g_vm_dot)) _(bif_read, "read", S1(g_vm_read)) _(bif_getc, "getc", S1(g_vm_getc))\
 _(bif_putc, "putc", S1(g_vm_putc)) _(bif_prn, "putn", S2(g_vm_putn)) _(bif_puts, "puts", S1(g_vm_puts))\
 _(bif_sym, "sym", S1(g_vm_gensym)) _(bif_nom, "nom", S1(g_vm_symnom)) _(bif_thd, "thd", S1(g_vm_thda))\
 _(bif_peek, "peek", S2(g_vm_peek2)) _(bif_poke, "poke", S3(g_vm_poke2)) _(bif_trim, "trim", S1(g_vm_trim))\
 _(bif_seek, "seek", S2(g_vm_seek)) _(bif_len, "len", S1(g_vm_len)) _(bif_get, "get", S3(g_vm_get))\
 _(bif_put, "put", S3(g_vm_put)) _(bif_tnew, "new", S1(g_vm_tnew)) _(bif_tabkeys, "tkeys", S1(g_vm_tkeys))\
 _(bif_tabdel, "tdel", S3(g_vm_tdel)) _(bif_twop, "twop", S1(g_vm_twop)) _(bif_strp, "strp", S1(g_vm_strp))\
 _(bif_symp, "symp", S1(g_vm_symp)) _(bif_tblp, "tblp", S1(g_vm_tblp)) _(bif_nump, "nump", S1(g_vm_nump))\
 _(bif_nilp, "nilp", S1(g_vm_nilp)) _(bif_ev, "ev", S1(g_vm_eval))
#define built_in_function(n, _, d) static union u const n[] = d;
bifs(built_in_function);
#define insts(_) _(g_vm_unc) _(g_vm_freev) _(g_vm_ret) _(g_vm_ap) _(g_vm_tap) _(g_vm_apn) _(g_vm_tapn)\
  _(g_vm_jump) _(g_vm_cond) _(g_vm_arg) _(g_vm_quote) _(g_vm_cur) _(g_vm_defglob) _(g_vm_lazyb) _(g_vm_ret0)
#define biff(b, n, _) {n, (intptr_t) b},
#define i_entry(i) {#i, (intptr_t) i},

static g_vm(g_vm_yield) { return Pack(f), f; }
static union u yield[] = { {g_vm_yield} };
static struct g_def const def1[] = { bifs(biff) insts(i_entry) {0}};
g_noinline struct g *g_ini_m(g_malloc_t *ma, g_free_t *fr) {
 uintptr_t const len0 = 1 << 10;
 struct g *f = ma(NULL, 2 * len0 * sizeof(word));
 if (f == NULL) return encode(f, g_status_oom);
 memset(f, 0, sizeof(struct g));
 f->len = len0, f->pool = (void*) f, f->malloc = ma, f->free = fr;
 f->hp = f->end, f->sp = (word*) f + len0, f->ip = yield, f->t0 = g_clock();
 if (!g_ok(f = mktbl(mktbl(f)))) return f;
 word m = pop1(f), d = pop1(f);
 f->macro = tbl(m), f->dict = tbl(d);
 struct g_def def0[] = { {"globals", d, }, {"macros", m, }, {0}, };
 return g_defs(g_defs(f, def0), def1); }

void *g_libc_malloc(struct g*f, size_t n) { return malloc(n); }
void g_libc_free(struct g*f, void *x) { free(x); }

g_inline struct g *g_pop(struct g*f, uintptr_t n) { return g_core_of(f)->sp += n, f; }

static g_inline struct g *symof(char const *n, struct g *f) {
  return intern(g_strof(f, n)); }
struct g *g_defs(struct g*f, struct g_def const*defs) {
 if (!g_ok(f)) return f;
 f = g_push(f, 1, f->dict);
 for (int n = 0; defs[n].n; n++)
  f = g_tput(symof(defs[n].n, g_push(f, 1, defs[n].x)));
 if (g_ok(f)) f->sp++;
 return f; }

static word g_tget(struct g *f, word zero, word k, struct g_tab *t) {
 uintptr_t i = index_of_key(f, t, k);
 struct g_kvs *e = t->tab[i];
 while (e && !eql(f, k, e->key)) e = e->next;
 return e ? e->val : zero; }
