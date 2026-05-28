#include "g.h"
#include <stdarg.h>
_Static_assert(sizeof(union u) == sizeof(intptr_t), "cell size equals word size");
_Static_assert(-1 >> 1 == -1, "sign extended shift");
#define nilp(_) (word(_)==nil)
#define A(o) two(o)->a
#define B(o) two(o)->b
#define AB(o) A(B(o))
#define AA(o) A(A(o))
#define BA(o) B(A(o))
#define BB(o) B(B(o))
#define len(_) (((struct g_str*)(_))->len)
#define txt(_) (((struct g_str*)(_))->bytes)
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

#define oddp(_) ((uintptr_t)(_)&1)
#define evenp(_) !oddp(_)
#define typ(_) cell(_)[1].typ
#define cell(_) ((union u*)(_))

#define Have1() if (Sp == Hp) return Ap(g_vm_gc, f, 1)
#define Have(n) if (Sp < Hp + n) return Ap(g_vm_gc, f, n)
#if g_tco
#define g_status_yield g_status_ok
#else
#define g_status_yield g_status_eof
#endif
#define g_pop1(f) (*(f)->sp++)
#define str_type_width (Width(struct g_str))

#define opf(nom, op) g_vm(nom) {\
 word a = getnum(Sp[0]), b = getnum(Sp[1]);\
 *++Sp = putnum(a op b);\
 return Ip++, Continue(); }
#define op0f(nom, op) g_vm(nom) {\
 word a = getnum(Sp[0]), b = getnum(Sp[1]);\
 *++Sp = b == 0 ? nil : putnum(a op b);\
 return Ip++, Continue(); }
#define op(nom, n, x) g_vm(nom) { intptr_t _ = (x); *(Sp += n-1) = _; Ip++; return Continue(); }
#define op1(nom, i, x) g_vm(nom) { Sp[0] = (x); Ip += i; return Continue(); }
#define op11(nom, x) op1(nom, 1, x)

#define nil g_nil
#define pop1 g_pop1
#define getnum g_getnum
#define putnum g_putnum

struct g_pair { g_vm_t *ap; uintptr_t typ; intptr_t a, b; };
enum q { two_q, vec_q, sym_q, tbl_q, text_q, };
typedef g_word num, word;
enum g_vec_type {
 g_vt_u8, g_vt_u16, g_vt_u32, g_vt_u64,
 g_vt_i8, g_vt_i16, g_vt_i32, g_vt_i64,
 g_vt_f32, g_vt_f64,
};
static struct g
 *g_please(struct g*, uintptr_t),
 *have(struct g*, uintptr_t),
 *g_tput(struct g*),
 *mktbl(struct g*),
 *intern(struct g*),
 *g_reads(struct g*, struct g_io*, bool),
 *g_read1(struct g*, struct g_io*);
static struct g*g_putn(struct g *f, struct g_io *o, intptr_t n, uint8_t base);
static g_vm(g_vm_gc, uintptr_t);
static g_vm_t g_vm_kcall,
 g_vm_data,  g_vm_putn, g_vm_info, g_vm_dot,    g_vm_clock,
 g_vm_nilp,  g_vm_symnom,              g_vm_putc, g_vm_gensym, g_vm_twop,
 g_vm_len, g_vm_get,
 g_vm_nump,  g_vm_symp,   g_vm_strp,   g_vm_tblp, g_vm_band,   g_vm_bor,  g_vm_flo,  g_vm_flop,
 g_vm_sin, g_vm_cos, g_vm_tan, g_vm_atan, g_vm_atan2,
 g_vm_sqrt, g_vm_exp, g_vm_log, g_vm_pow,
 g_vm_bxor,  g_vm_bsr,    g_vm_bsl,    g_vm_bnot, g_vm_ssub,
 g_vm_scat,   g_vm_cons,   g_vm_car,  g_vm_cdr,    g_vm_puts,
 g_vm_getc,  g_vm_str,    g_vm_lt,     g_vm_le,   g_vm_eq,     g_vm_gt,  g_vm_ge,
 g_vm_put, g_vm_tdel,   g_vm_tnew,   g_vm_tkeys,
 g_vm_unc, g_vm_poke2, g_vm_peek2,
 g_vm_seek,  g_vm_trim,   g_vm_thda,   g_vm_add,
 g_vm_sub,   g_vm_mul,    g_vm_quot,   g_vm_rem,  g_vm_arg,
 g_vm_quote, g_vm_freev,  g_vm_eval,   g_vm_cond, g_vm_jump,   g_vm_defglob,
 g_vm_ap,    g_vm_tap,    g_vm_apn,    g_vm_tapn, g_vm_ret,    g_vm_lazyb,
 g_vm_callk, g_vm_yield_sw, g_vm_yield_bif, g_vm_task_exit, g_vm_spawn, g_vm_wait,
 g_vm_sleep, g_vm_donep, g_vm_kill, g_vm_key, g_vm_inspect,
 g_vm_fgetc, g_vm_fungetc, g_vm_feof, g_vm_fputc, g_vm_fputs, g_vm_fflush,
 g_vm_fread, g_vm_strin;
static uintptr_t hash(struct g*, word), g_vec_bytes(struct g_vec*);
static struct g_str *ini_str(struct g_str*, uintptr_t);
static struct g *str0(struct g*, uintptr_t);
static struct g *flo_alloc(struct g*, g_flo_t);
static double g_strtod(char const*, char**);
static int g_dtoa(double, char*, int, int max_frac);
static word g_tget(struct g*, word, word, struct g_tab*);
static struct g_atom *intern_checked(struct g*, struct g_str*);
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
 *memmove(void*restrict, void const*restrict, size_t),
 *memset(void*, int, size_t);
long strtol(char const*restrict, char**restrict, int);
size_t strlen(char const*);

#define vec(_) ((struct g_vec*)(_))
#define str(_) ((struct g_str*)(_))
#define tbl(_) ((struct g_tab*)(_))
// payload of a g_vec, type-erased. For rank 0 this is just past the
// header; for rank N it's past the N shape words.
#define vec_data(_) ((void*)(vec(_)->shape + vec(_)->rank))
#define nump oddp
#define homp evenp
#define two(_) ((struct g_pair*)(_))
#define sym(_) ((struct g_atom*)(_))
static g_inline bool twop(word _) { return homp(_) && typ(_) == two_q; }
static g_inline bool tblp(word _) { return homp(_) && typ(_) == tbl_q; }
static g_inline bool symp(word _) { return homp(_) && typ(_) == sym_q; }
static g_inline bool vecp(word _) { return homp(_) && typ(_) == vec_q; }
static g_inline bool strp(word _) { return homp(_) && typ(_) == text_q; }
static g_inline bool flop(word _) {
  return vecp(_) && vec(_)->rank == 0 && vec(_)->type == G_VT_FLO; }
static g_inline bool numericp(word _) { return nump(_) || vecp(_); }
// public predicate for frontends that need to check string args
bool g_strp(g_word x) { return strp(x); }
static g_inline struct g *encode(struct g*f, enum g_status s) { return
  (struct g*) ((uintptr_t) f | s); }
static g_inline void *bump(struct g *f, uintptr_t n) {
  if (avail(f) < n) __builtin_trap();
  void *x = f->hp; f->hp += n; return x; }
static g_inline struct g_atom *ini_anon(struct g_atom *y, uintptr_t code) {
 return y->ap = g_vm_data, y->typ = sym_q, y->nom = 0, y->code = code, y; }
static g_inline struct g_atom *ini_sym(struct g_atom *y, struct g_str *nom, uintptr_t code) {
 return y->ap = g_vm_data, y->typ = sym_q, y->nom = nom, y->code = code, y->l = y->r = 0, y; }
static struct g_str *ini_str(struct g_str *s, uintptr_t len) {
 return s->ap = g_vm_data, s->typ = text_q, s->len = len, s; }
static g_inline struct g_tab *ini_tab(struct g_tab *t, size_t len, size_t cap, struct g_kvs**tab) {
 return t->ap = g_vm_data, t->typ = tbl_q, t->len = len, t->cap = cap, t->tab = tab, t; }
static g_inline struct g_pair *ini_two(struct g_pair *w, intptr_t a, intptr_t b) {
 return w->ap = g_vm_data, w->typ = two_q, w->a = a, w->b = b, w; }
static g_inline uintptr_t rot(uintptr_t x) {
  int const s = sizeof(uintptr_t) * 4; // shift bits = word bits / 2 = sizeof(word) * 4
  return (x << s) | (x >> s); }

// --- port dispatch -------------------------------------------------------
// fd >= 0 routes through g_fd_port_vt (frontend-provided). fd <= -1 indexes
// the synthetic table. Per-port method pointers no longer live on the port
// instance; the vtable is selected by fd value.
static struct g
 *noop_getc(struct g*),
 *noop_ungetc(struct g*, int),
 *noop_eof(struct g*),
 *noop_putc(struct g*, int),
 *noop_flush(struct g*),
 *ti_getc(struct g*),
 *ti_ungetc(struct g*, int),
 *ti_eof(struct g*),
 *ci_getc(struct g*),
 *to_putc(struct g*, int),
 *to_flush(struct g*);

static struct g_port_vt const synth[] = {
 /* fd = -1, ti: read-only string source */
 { ti_getc,   ti_ungetc,   ti_eof,   noop_putc, noop_flush },
 /* fd = -2, to: write-only vec sink   */
 { noop_getc, noop_ungetc, noop_eof, to_putc,   to_flush   },
 /* fd = -3, closed port (post-close)  */
 { noop_getc, noop_ungetc, noop_eof, noop_putc, noop_flush },
 /* fd = -4, ci: read-only charlist source -- ungetc/eof read only the g_io
    fields, so ti_ungetc/ti_eof work unchanged here. */
 { ci_getc,   ti_ungetc,   ti_eof,   noop_putc, noop_flush },
};

static g_inline struct g_port_vt const *port_vt(g_word fd_tagged) {
 intptr_t fd = getnum(fd_tagged);
 return fd >= 0 ? &g_fd_port_vt : &synth[-(fd + 1)]; }

// Threaded-error pattern: passing a non-ok f through. gzputc already
// does this; the read-side ports need it too because gzreads(false)'s
// loop can call g_z_getc on a f that gzread1 just returned g_status_more
// through (e.g. parsecl on incomplete input).
static g_inline struct g *zgetc(struct g*f)         { return g_ok(f) ? port_vt(f->io->fd)->getc(f) : f; }
static g_inline struct g *zungetc(struct g*f, int c){ return g_ok(f) ? port_vt(f->io->fd)->ungetc(f, c) : f; }
static g_inline struct g *zeof(struct g*f)          { return g_ok(f) ? port_vt(f->io->fd)->eof(f) : f; }
static g_inline struct g *zputc(struct g*f, int c)  { return port_vt(f->io->fd)->putc(f, c); }
static g_inline struct g *zflush(struct g*f)        { return port_vt(f->io->fd)->flush(f); }

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
 if (g_ok(f = have(f, n))) {
  struct env *c = bump(f, n);
  c->stack = c->branches = c->exits = c->lams = c->len = nil;
  c->args = f->sp[0], c->imps = f->sp[1], c->par = (struct env*) f->sp[2];
  c->end[0] = 0, c->end[1] = word(c);
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
 f = have(f, l + Width(struct g_tag));
 if (g_ok(f)) {
  union u *k = bump(f, l + Width(struct g_tag));
  k[l].m = NULL, k[l+1].m = memset(k, -1, l * sizeof(word));
  Kp = k + l;
  if (g_ok(f = pull(f, c))) clip(Kp); }
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

static g_vm(g_vm_yieldk) { return
 Ip = Ip[1].m,
 Pack(f),
 encode(f, g_status_yield); }

static g_inline bool iop(word x) { return homp(x) && cell(x)->ap == g_vm_port_io; }

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

static g_inline struct g *pushl(struct g*f) { return intern(g_strof(f, "\\")); }
static g_inline struct g *pushq(struct g*f) { return intern(g_strof(f, "`")); }
static g_inline struct g *push0(struct g*f) { return g_push(f, 1, nil); }

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

struct ti { struct g_io io; char const *t; word i; } ;

static struct g *ti_eof(struct g*f) {
 struct ti *i = (struct ti*) f->io;
 return f->b = (getnum(i->io.ungetc_buf) == EOF) && getnum(i->io.eof_seen), f; }

static struct g *ti_getc(struct g*f) {
 struct ti *i = (struct ti*) f->io;
 if (getnum(i->io.ungetc_buf) != EOF) {
  int c = getnum(i->io.ungetc_buf);
  i->io.ungetc_buf = putnum(EOF);
  return f->b = c, f; }
 if (!i->t[i->i]) { i->io.eof_seen = putnum(true); return f->b = EOF, f; }
 return f->b = i->t[i->i++], f; }

static struct g *ti_ungetc(struct g*f, int c) {
 struct ti *i = (struct ti*) f->io;
 i->io.ungetc_buf = putnum(c);
 i->io.eof_seen = putnum(false);
 return f->b = c, f; }

// Charlist-backed read-only port. `head` is a tagged pair pointer (or nil)
// into the gwen heap; getc walks the spine by tail-replacing it. The port
// itself lives on the gwen heap so the GC traces `head` as a regular thread
// slot (evac_thd walks every word up to the ttag).
struct ci { struct g_io io; g_word head; };

static struct g *ci_getc(struct g *f) {
 struct ci *i = (struct ci*) f->io;
 if (getnum(i->io.ungetc_buf) != EOF) {
  int c = getnum(i->io.ungetc_buf);
  i->io.ungetc_buf = putnum(EOF);
  return f->b = c, f; }
 if (!twop(i->head)) { i->io.eof_seen = putnum(true); return f->b = EOF, f; }
 int c = getnum(A(i->head));
 i->head = B(i->head);
 return f->b = c, f; }

// Heap-allocate a ci port. Expects the charlist on Sp[0]; on return Sp[0]
// holds the port (the charlist is preserved inside port->head). Same shape
// as to_alloc / g_io_alloc.
static struct g *ci_alloc(struct g *f) {
 uintptr_t n = Width(struct ci);
 if (!g_ok(f = have(f, n + Width(struct g_tag)))) return f;
 union u *k = bump(f, n + Width(struct g_tag));
 struct ci *i = (struct ci*) k;
 i->io.ap = g_vm_port_io;
 i->io.fd = putnum(-4);
 i->io.ungetc_buf = putnum(EOF);
 i->io.eof_seen = putnum(false);
 i->head = f->sp[0];
 struct g_tag *t = (struct g_tag*) (k + n);
 t->null = NULL;
 t->head = k;
 f->sp[0] = (word) i;
 return f; }

g_noinline struct g *g_evals(struct g*f, char const*s) {
 static char const *t = "((:(e a b)(? b(e(ev'ev(A b))(B b))a)e)0)";
 struct ti i = {{g_vm_port_io, putnum(-1), putnum(EOF), putnum(false)}, t, 0};
 f = push0(pushq(push0(g_eval(g_reads(f, (void*) &i, false)))));
 i.t = s, i.i = 0, i.io.ungetc_buf = putnum(EOF), i.io.eof_seen = putnum(false);
 return g_eval(gxr(gxl(gxr(gxl(g_reads(f, (void*) &i, false)))))); }

// some libc functions we use
static g_vm(g_vm_tnew) {
 Have(Width(struct g_tab) + 1);
 struct g_tab *t = (struct g_tab*) Hp;
 struct g_kvs **tab = (struct g_kvs**) (t + 1);
 return
  Hp += Width(struct g_tab) + 1,
  tab[0] = 0,
  Sp[0] = word(ini_tab(t, 0, 1, tab)),
  Ip++,
  Continue(); }

static op11(g_vm_tblp, tblp(Sp[0]) ? putnum(-1) : nil)

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

static g_vm(g_vm_get) {
 word z = Sp[0], k = Sp[1], x = Sp[2], n;
 if (homp(x) && datp(x)) switch (typ(x)) {
  case tbl_q: z = g_tget(f, z, k, tbl(x)); break;
  case text_q:
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
 intptr_t list = nil;
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
    for (uint8_t const *bs = (void*) x; len--; h ^= *bs++, h *= mix);
    return h; }
   case text_q: {
    uintptr_t n = len(x), h = mix;
    char const *bs = txt(x);
    while (n--) h ^= (uint8_t) *bs++, h *= mix;
    return h; } } }

static op11(g_vm_car, twop(Sp[0]) ? A(Sp[0]) : Sp[0])
static op11(g_vm_cdr, twop(Sp[0]) ? B(Sp[0]) : nil)
static op11(g_vm_twop, twop(Sp[0]) ? putnum(-1) : nil)
static g_vm(g_vm_cons) {
 Have(Width(struct g_pair));
 struct g_pair *w = (struct g_pair*) Hp;
 Hp += Width(struct g_pair);
 ini_two(w, Sp[0], Sp[1]);
 *++Sp = word(w);
 Ip++;
 return Continue(); }

struct g *gxl(struct g *f) {
 if (g_ok(f = have(f, Width(struct g_pair)))) {
  struct g_pair *p = bump(f, Width(struct g_pair));
  ini_two(p, f->sp[0], f->sp[1]);
  *++f->sp = (word) p; }
 return f; }

struct g *gxr(struct g *f) {
 if (g_ok(f = have(f, Width(struct g_pair)))) {
  struct g_pair *p = bump(f, Width(struct g_pair));
  ini_two(p, f->sp[1], f->sp[0]);
  *++f->sp = (word) p; }
 return f; }

static op11(g_vm_strp, strp(Sp[0]) ? putnum(-1) : nil)
static op11(g_vm_flop, flop(Sp[0]) ? putnum(-1) : nil)

// Strict parse of a gwen-string's bytes as a decimal float. g_noinline +
// by-value struct return so the &e and &buf escapes stay inside this
// frame and never reach g_vm_flo, which needs to TCO out via Continue().
struct g_strtod_r { double d; bool ok; };
static g_noinline struct g_strtod_r parse_flo_strict(char const *bytes, size_t len) {
 struct g_strtod_r r = { 0, false };
 char buf[64];
 if (len == 0 || len >= sizeof buf) return r;
 memcpy(buf, bytes, len);
 buf[len] = 0;
 char *e;
 r.d = g_strtod(buf, &e);
 r.ok = e != buf && *e == 0;
 return r; }

// (flo s) — parse a gwen string as a decimal float. Returns a rank-0
// f64 box if the entire string parses, else nil. Used by the gwen-side
// reader in repl.g to match the C reader's strtol → strtod → intern
// cascade on float-shaped tokens.
static g_vm(g_vm_flo) {
 word x = Sp[0];
 if (!strp(x)) { Sp[0] = nil; Ip += 1; return Continue(); }
 struct g_strtod_r p = parse_flo_strict(str(x)->bytes, str(x)->len);
 if (!p.ok) { Sp[0] = nil; Ip += 1; return Continue(); }
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));
 Have(req);
 struct g_vec *r = (struct g_vec*) Hp;
 Hp += req;
 r->ap = g_vm_data;
 r->typ = vec_q;
 r->type = G_VT_FLO;
 r->rank = 0;
 *(g_flo_t*) r->shape = (g_flo_t) p.d;
 Sp[0] = word(r);
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_ssub) {
 if (!strp(Sp[0])) Sp[2] = nil;
 else {
  struct g_str *s = str(Sp[0]), *t;
  intptr_t i = oddp(Sp[1]) ? getnum(Sp[1]) : 0,
           j = oddp(Sp[2]) ? getnum(Sp[2]) : 0;
  i = MAX(i, 0), i = MIN(i, (word) len(s));
  j = MAX(j, i), j = MIN(j, (word) len(s));
  if (i == j) Sp[2] = nil;
  else {
   size_t req = str_type_width + b2w(j - i);
   Have(req);
   t = (struct g_str*) Hp;
   Hp += req;
   ini_str(t, j - i);
   memcpy(txt(t), txt(s) + i, j - i);
   Sp[2] = (word) t; } }
 return Ip += 1, Sp += 2, Continue(); }

static g_vm(g_vm_scat) {
 intptr_t a = Sp[0], b = Sp[1];
 if (!strp(a)) Sp += 1;
 else if (!strp(b)) Sp[1] = a, Sp += 1;
 else {
  struct g_str *x = str(a), *y = str(b), *z;
  uintptr_t
   len = len(x) + len(y),
   req = str_type_width + b2w(len);
  Have(req);
  z = (struct g_str*) Hp;
  Hp += req;
  ini_str(z, len);
  memcpy(txt(z), txt(x), len(x));
  memcpy(txt(z) + len(x), txt(y), len(y));
  *++Sp = word(z); }
 return Ip++, Continue(); }

static size_t const vt_size[] = {
 [g_vt_u8]  = 1, [g_vt_u16] = 2, [g_vt_u32] = 4, [g_vt_u64] = 8,
 [g_vt_i8]  = 1, [g_vt_i16] = 2, [g_vt_i32] = 4, [g_vt_i64] = 8,
 [g_vt_f32] = 4, [g_vt_f64] = 8,
};

static uintptr_t g_vec_bytes(struct g_vec *v) {
 uintptr_t len = vt_size[v->type],
           rank = v->rank,
           *shape = v->shape;
 while (rank--) len *= *shape++;
 return sizeof(struct g_vec) + v->rank * sizeof(word) + len; }

// Allocate a fresh struct g_str of `len` bytes, zero-filled, push on Sp.
static struct g *str0(struct g *f, uintptr_t len) {
 uintptr_t req = str_type_width + b2w(len);
 f = have(f, req + 1);
 if (g_ok(f)) {
  struct g_str *s = bump(f, req);
  ini_str(s, len);
  memset(s->bytes, 0, len);
  *--f->sp = word(s); }
 return f; }

// Allocate a rank-0 G_VT_FLO g_vec wrapping v, push on Sp.
static struct g *flo_alloc(struct g *f, g_flo_t v) {
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));
 f = have(f, req + 1);
 if (g_ok(f)) {
  struct g_vec *r = bump(f, req);
  r->ap = g_vm_data;
  r->typ = vec_q;
  r->type = G_VT_FLO;
  r->rank = 0;
  *(g_flo_t*) vec_data(r) = v;
  *--f->sp = word(r); }
 return f; }

// Decimal float parser: [-+]? digits ('.' digits)? ([eE] [-+]? digits)?.
// Adequate for round-trip of literals the printer emits; not IEEE
// round-to-nearest correct. Returns 0 with *end == s when nothing was
// consumed.
static double g_strtod(char const *s, char **end) {
 char const *p = s;
 int sign = 1;
 if (*p == '-') sign = -1, p++;
 else if (*p == '+') p++;
 bool any = false;
 double v = 0;
 while ('0' <= *p && *p <= '9') v = v * 10 + (*p++ - '0'), any = true;
 if (*p == '.') {
  p++;
  double scale = 0.1;
  while ('0' <= *p && *p <= '9') v += (*p++ - '0') * scale, scale *= 0.1, any = true; }
 if (!any) { if (end) *end = (char*) s; return 0; }
 if (*p == 'e' || *p == 'E') {
  char const *q = p++;
  int esign = 1;
  if (*p == '-') esign = -1, p++;
  else if (*p == '+') p++;
  if (!('0' <= *p && *p <= '9')) p = q;                  // not a real exponent
  else {
   int e = 0;
   while ('0' <= *p && *p <= '9') e = e * 10 + (*p++ - '0');
   double scale = 1;
   while (e--) scale *= 10;
   v = esign > 0 ? v * scale : v / scale; } }
 if (end) *end = (char*) p;
 return sign * v; }

// Decimal float printer. Writes up to cap bytes into buf; returns the
// byte count written. Strategy: sign, integer part via integer math,
// then up to 15 fractional digits with trailing zeros trimmed; for very
// large or very small magnitudes, normalize to [1,10) and append eE.
static int g_dtoa(double v, char *buf, int cap, int max_frac) {
 char *p = buf, *end = buf + cap;
 if (v != v) { if (end - p >= 3) memcpy(p, "nan", 3), p += 3; return p - buf; }
 if (v < 0) { if (p < end) *p++ = '-'; v = -v; }
 if (v > 1e308) { if (end - p >= 3) memcpy(p, "inf", 3), p += 3; return p - buf; }
 int exp = 0;
 bool sci = false;
 if (v != 0 && (v >= 1e16 || v < 1e-4)) {
  sci = true;
  while (v >= 10) v /= 10, exp++;
  while (v < 1)  v *= 10, exp--; }
 // integer part, lsb-first then reversed
 uint64_t ip = (uint64_t) v;
 double frac = v - (double) ip;
 char ib[24]; int ib_n = 0;
 if (ip == 0) ib[ib_n++] = '0';
 while (ip) ib[ib_n++] = '0' + ip % 10, ip /= 10;
 while (ib_n > 0) { ib_n--; if (p < end) *p++ = ib[ib_n]; }
 // fractional digits; in non-scientific mode always emit at least ".0"
 // so the result is visually distinguishable from a fixnum.
 bool emit_frac = frac > 0 || !sci;
 if (emit_frac) {
  char fb[16]; int fb_n = 0;
  if (max_frac > 15) max_frac = 15;
  for (int i = 0; i < max_frac && frac > 0; i++) {
   frac *= 10;
   int d = (int) frac;
   if (d > 9) d = 9;
   fb[fb_n++] = '0' + d;
   frac -= d; }
  while (fb_n > 0 && fb[fb_n - 1] == '0') fb_n--;
  if (!sci && fb_n == 0) fb[fb_n++] = '0';      // force "X.0" for ints
  if (fb_n > 0) {
   if (p < end) *p++ = '.';
   for (int i = 0; i < fb_n; i++) if (p < end) *p++ = fb[i]; } }
 if (sci) {
  if (p < end) *p++ = 'e';
  if (exp < 0) { if (p < end) *p++ = '-'; exp = -exp; }
  char eb[8]; int eb_n = 0;
  if (exp == 0) eb[eb_n++] = '0';
  while (exp) eb[eb_n++] = '0' + exp % 10, exp /= 10;
  while (eb_n > 0) { eb_n--; if (p < end) *p++ = eb[eb_n]; } }
 return p - buf; }

struct g *g_strof(struct g *f, char const *cs) {
 uintptr_t len = strlen(cs);
 f = str0(f, len);
 if (g_ok(f)) memcpy(txt(f->sp[0]), cs, len);
 return f; }

// Data-sink port: a heap-allocated thread (g_vm_port_io discriminator) that
// extends struct g_io with a growable gwen-heap string buf and a tagged
// byte-count slot. fd = putnum(-2) routes to_putc/to_flush via synth[1].
// The `i` slot must be tagged because evac_thd blindly gcps every slot in
// the thread: an untagged count that happened to land in pool range would
// be falsely "forwarded".
struct to {
 struct g_io io;
 struct g_str *buf;
 g_word i; };

static struct g *to_putc(struct g *f, int c) {
 struct to *o = (struct to*) f->io;
 uintptr_t i = getnum(o->i);
 if (i >= len(o->buf)) {
  uintptr_t new_cap = len(o->buf) * 2;
  f = str0(f, new_cap);
  if (!g_ok(f)) return f;
  o = (struct to*) f->io;                 // GC may have moved it; f->out is GC-traced
  struct g_str *nb = (struct g_str*) f->sp[0];
  memcpy(txt(nb), txt(o->buf), i);
  o->buf = nb;
  f->sp++; }
 txt(o->buf)[i] = c;
 o->i = putnum(i + 1);
 return f; }
static struct g *to_flush(struct g *f) { return f; }

// No-op methods occupy unused vtable slots so dispatch needs no NULL guards.
// Misuse policy (matches existing bif behavior): reading from a write-only
// port returns EOF and latches eof_seen; writing to a read-only port
// silently discards the byte. ungetc on a write-only port ignores the
// pushed byte (subsequent reads still return EOF via noop_getc).
static struct g *noop_getc(struct g *f) {
 g_core_of(f)->io->eof_seen = putnum(true);
 return f->b = EOF, f; }
static struct g *noop_ungetc(struct g *f, int c) { (void) c; return f; }
static struct g *noop_eof(struct g *f) { return f->b = true, f; }
static struct g *noop_putc(struct g *f, int c) { (void) c; return f; }
static struct g *noop_flush(struct g *f) { return f; }

// Heap-allocate a fresh data-sink port. Bumps Width(struct to) + ttag, fills
// fields, and pushes the port pointer on Sp.
static struct g *to_alloc(struct g *f) {
 f = str0(f, 32);                          // initial buf on Sp[0]
 if (!g_ok(f)) return f;
 uintptr_t n = Width(struct to);
 if (!g_ok(f = have(f, n + Width(struct g_tag)))) return f;
 union u *k = bump(f, n + Width(struct g_tag));
 struct to *o = (struct to*) k;
 o->io.ap = g_vm_port_io;
 o->io.fd = putnum(-2);
 o->io.ungetc_buf = putnum(EOF);
 o->io.eof_seen = putnum(false);
 o->buf = (struct g_str*) f->sp[0];        // adopt the buf
 o->i = putnum(0);
 struct g_tag *t = (struct g_tag*) (k + n);
 t->null = NULL;
 t->head = k;
 f->sp[0] = (word) o;                      // replace buf slot with port
 return f; }

// Harvest the bytes written so far into a fresh exact-sized g_vec on top of
// Sp. The port stays where it was on the value stack.
static struct g *to_harvest(struct g *f, struct to *o) {
 MM(f, (g_word*) &o);
 f = str0(f, getnum(o->i));
 UM(f);
 if (!g_ok(f)) return f;
 memcpy(txt(f->sp[0]), txt(o->buf), getnum(o->i));
 return f; }

// Finalizer for heap stream ports: extract the fd and ask the frontend to
// close it. Runs inside GC (run_finalizers); fz->p still points at the
// from-space port so its fields are readable. Skip if fd < 0 — that means
// either the port was already closed explicitly (fd mutated to a synth
// sentinel) or the caller wrapped a non-OS fd.
static void io_close(void *p) {
 struct g_io *io = p;
 intptr_t fd = getnum(io->fd);
 if (fd >= 0) g_fd_close(fd); }

// Heap-allocate a stream port for the given OS fd. Pushes the port pointer
// on Sp[0] and registers io_close as its finalizer. The fd >= 0 path of
// the dispatcher routes through g_fd_port_vt, so the host's read/write
// methods see this port like any other.
struct g *g_io_alloc(struct g *f, int fd) {
 uintptr_t n = Width(struct g_io);
 if (!g_ok(f = have(f, n + Width(struct g_tag) + 1))) return f;
 union u *k = bump(f, n + Width(struct g_tag));
 struct g_io *io = (struct g_io*) k;
 io->ap = g_vm_port_io;
 io->fd = putnum(fd);
 io->ungetc_buf = putnum(EOF);
 io->eof_seen = putnum(false);
 struct g_tag *t = (struct g_tag*) (k + n);
 t->null = NULL;
 t->head = k;
 *--f->sp = (word) io;            // stack slot reserved by the +1 in have()
 // g_finalize MM-protects its `p` argument internally across its own
 // allocation, and the stack slot we just pushed will be forwarded by GC
 // if a collection happens, so Sp[0] holds the live port on return.
 return g_finalize(f, (union u*) f->sp[0], io_close); }


static g_vm(g_vm_gensym) {
 Have(Width(struct g_atom));
 struct g_atom *y;
 if (strp(Sp[0]))
   Pack(f),
   y = intern_checked(f, (struct g_str*) f->sp[0]),
   Unpack(f);
 else
  y = (struct g_atom*) Hp,
  Hp += Width(struct g_atom) - 2,
  ini_anon(y, g_clock());
 return
  Sp[0] = word(y),
  Ip += 1,
  Continue(); }

static g_vm(g_vm_symnom) {
 intptr_t y = Sp[0];
 return
  y = symp(y) && sym(y)->nom ? word(sym(y)->nom) : nil,
  Sp[0] = y,
  Ip += 1,
  Continue(); }

static struct g *intern(struct g*f) {
 if (g_ok(f = have(f, Width(struct g_atom))))
  f->sp[0] = (word) intern_checked(f, (struct g_str*) f->sp[0]);
 return f; }

// avail must be >= Width(struct g_atom) when this is called.
static  g_noinline struct g_atom *intern_checked(struct g *v, struct g_str *b) {
 uintptr_t h = rot(hash(v, word(b)));
 for (struct g_atom **y = &v->symbols, *z;;) {
  if (!(z = *y)) return *y = ini_sym(bump(v, Width(struct g_atom)), b, h);
  struct g_str *a = z->nom;
  intptr_t i = z->code < h ? -1 : z->code > h ? 1 : 0;
  if (i == 0) i = len(a) - len(b);
  if (i == 0) i = memcmp(txt(a), txt(b), len(b));
  if (i == 0) return z;
  y = i < 0 ? &z->l : &z->r; } }

static op11(g_vm_symp, symp(Sp[0]) ? putnum(-1) : nil)

static struct g *grbufn(struct g *f) {
 if (g_ok(f = have(f, str_type_width + 2))) {
  union u *k = bump(f, str_type_width + 1);
  *--f->sp = word(k);
  struct g_str *o = (struct g_str*) k;
  ini_str(o, sizeof(intptr_t)); }
 return f; }

static struct g *grbufg(struct g *f) {
 if (!g_ok(f)) return f;
 size_t len = len(f->sp[0]),
        req = str_type_width + 2 * b2w(len);
 if (g_ok(f = have(f, req))) {
  struct g_str *o = bump(f, req);
  ini_str(o, 2 * len);
  memcpy(txt(o), txt(f->sp[0]), len);
  f->sp[0] = (word) o; }
 return f; }


////
/// " the parser "
//
//
// get the next significant character from the stream. MM-protect the C
// `i` parameter across the multiple port_* calls — each push triggers a
// have() check that may GC and move heap ports.

static struct g* g_z_getc(struct g*f) {
 while (g_ok(f = zgetc(f))) switch (f->b) {
  default: return f;
  case '#': case ';':
   while (g_ok(f = zeof(f)) && !f->b && g_ok(f = zgetc(f)) && f->b != '\n' && f->b != '\r');
  case 0: case ' ': case '\t': case '\n': case '\r': case '\f':
   continue; }
 return f; }

static struct g *gzreads(struct g *f, bool nested);
static struct g *gzread1(struct g*f) {
 if (!g_ok(f = g_z_getc(f))) goto out;
 int c = f->b;
 switch (c) {
  case '(':  f = gzreads(f, true); goto out;
  case ')': case EOF:  f = encode(f, g_status_eof); goto out;
  case '\'':
   f = gzread1(f);
   if (g_code_of(f) == g_status_eof)               // quote with no operand
    f = encode(g_core_of(f), g_status_more);
   f = gxl(pushq(gxr(push0(f)))); goto out;
  case '"': {
   size_t n = 0;
   struct g_str *b = 0;
   MM(f, (g_word*) &b);
   f = grbufn(f);
   for (size_t lim = sizeof(word); g_ok(f); f = grbufg(f), lim *= 2)
    for (b = (struct g_str*) f->sp[0]; n < lim; txt(b)[n++] = c) {
     if (!g_ok(f = zgetc(f))) goto out_str;     // threaded; char in f->b
     c = f->b;
     if (c == '\\') {                               // escape: take next char
      if (!g_ok(f = zgetc(f))) goto out_str;
      if ((c = f->b) == EOF) { f = encode(f, g_status_more); goto out_str; }
      if (c == 'n') c = '\n';
      else if (c == 't') c = '\t';
      else if (c == 'r') c = '\r';
      else if (c == '0') c = '\0';
      else if (c == 'x') {                          // \xHH: two hex digits
       if (!g_ok(f = zgetc(f))) goto out_str;
       int h1 = f->b;
       if (h1 == EOF) { f = encode(f, g_status_more); goto out_str; }
       if (!g_ok(f = zgetc(f))) goto out_str;
       int h2 = f->b;
       if (h2 == EOF) { f = encode(f, g_status_more); goto out_str; }
       int v1 = h1 <= '9' ? h1 - '0' : (h1 | 0x20) - 'a' + 10;
       int v2 = h2 <= '9' ? h2 - '0' : (h2 | 0x20) - 'a' + 10;
       c = ((v1 & 0xf) << 4) | (v2 & 0xf); } }
     else if (c == EOF) { f = encode(f, g_status_more); goto out_str; }
     else if (c == '"') { len(b) = n; goto out_str; } }
out_str: UM(f); goto out; } }

 {
  uintptr_t n = 1, lim = sizeof(intptr_t);
  struct g_str *b = 0;
  MM(f, (g_word*) &b);
  if (g_ok(f = grbufn(f)))
   for (txt((struct g_str*) f->sp[0])[0] = c; g_ok(f); f = grbufg(f), lim *= 2)
    for (b = (struct g_str*) f->sp[0]; n < lim; txt(b)[n++] = c) {
     if (!g_ok(f = zgetc(f))) goto out_atom;
     switch (c = f->b) {
      default: continue;
      case ' ': case '\n': case '\t': case '\r': case '\f': case ';': case '#':
      case '(': case ')': case '"': case '\'': case 0 : case EOF:
       f = zungetc(f, c);
       if (!g_ok(f)) goto out_atom;
       b = (struct g_str*) f->sp[0];
       len(b) = n;
       txt(b)[n] = 0; // zero terminate for strtol ; n < lim so this is safe
       char *e;
       long j = strtol(txt(b), &e, 0);
       if (*e == 0) f->sp[0] = putnum(j);
       else {
        char *fe;
        double d = g_strtod(txt(b), &fe);
        if (fe != txt(b) && *fe == 0) {
         f = flo_alloc(f, d);                  // pushes box; collapse scratch slot
         if (g_ok(f)) f->sp[1] = f->sp[0], f->sp++;
        } else f = intern(f); }
       goto out_atom; } }
out_atom: UM(f); }
out: return f; }

static struct g *g_read1(struct g*f, struct g_io *i) {
 return g_core_of(f)->io = i, gzread1(f); }

static struct g *gzreads(struct g *f, bool nested) {
 intptr_t n = 0;
 for (int c; g_ok(f = g_z_getc(f)); n++) {
  c = f->b;
  if (c == ')') break;                          // list closed
  if (c == EOF) {                               // end of input...
   if (nested) return encode(f, g_status_more); 
   break; }                                     //  ...at top level: done
  f = zungetc(f, c);
  f = gzread1(f); }
 for (f = push0(f); n--; f = gxr(f));
 return f; }

static struct g *g_reads(struct g *f, struct g_io* i, bool nested) {
 return g_core_of(f)->io = i, gzreads(f, nested); }

// Read one datum, transactionally. On g_status_more (or any non-ok
// result) the VM stack is rolled back to its pre-parse depth, so a
// deferred parse leaves no residue and the identical input can be
// re-read once more of it arrives. The depth is kept as a word count,
// not a pointer, because a collection during the parse relocates the
// stack. The input source (g_in) is untouched -- the caller manages it.
struct g *g_read(struct g *f, struct g_io *i) {
 if (!g_ok(f)) return f;
 uintptr_t depth = ((word*) f + f->len) - f->sp;
 f = g_read1(f, i);
 if (!g_ok(f)) {
  struct g *c = g_core_of(f);
  c->sp = (word*) c + c->len - depth; }
 return f; }


// (fread port e) — read one datum from `port`. On success returns the
// datum. On clean EOF returns `e` (the caller-supplied sentinel). On
// g_status_more (EOF reached inside an unfinished form) returns the port
// itself — distinct from `e`, so callers like the REPL editor can tell
// "this charlist parses to nothing" apart from "this charlist is mid-form,
// keep editing." `(: read (fread in))` in boot.g recovers the old single-
// arg `read` for stdin. Misuse (non-port at Sp[0]) leaves `e` in place.
static g_vm(g_vm_fread) {
 if (!iop(Sp[0])) { Sp += 1; Ip += 1; return Continue(); }
 struct g_io *i = (struct g_io*) Sp[0];
 Pack(f);
 f = g_read(f, i);
 if (g_ok(f)) {
  // Sp[0]=datum, Sp[1]=port, Sp[2]=e. Want top=datum, consume 2.
  f->sp[2] = f->sp[0];
  f->sp += 2;
 } else switch (g_code_of(f)) {
  case g_status_eof:
   f = g_core_of(f);
   f->sp += 1;                                   // pop port; top = e
   break;
  case g_status_more:
   f = g_core_of(f);
   f->sp[1] = f->sp[0];                          // e := port; pop one
   f->sp += 1;
   break;
  default: return f; }                           // propagate other errors
 Unpack(f);
 Ip += 1;
 return Continue(); }

// (strin cl) — make a read-only synth port (fd=-4, ci) whose getc walks
// the charlist `cl`. The port stays live on the gwen heap and is GC-
// traced; its `head` slot is updated each getc.
static g_vm(g_vm_strin) {
 Pack(f);
 if (!g_ok(f = ci_alloc(f))) return f;
 Unpack(f);
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_str) {
 uintptr_t n = llen(Sp[0]);
 // FIXME use Have instead of Pack/Unpack
 Pack(f);
 if (!g_ok(f = str0(f, n))) return f;
 // sp[0] is the new string; sp[1] is the original charlist.
 char *t = txt(f->sp[0]);
 uintptr_t i = 0;
 for (word l = f->sp[1]; twop(l); l = B(l)) t[i++] = (char) getnum(A(l));
 f->sp[1] = f->sp[0];
 f->sp += 1;
 Unpack(f);
 Ip += 1;
 return Continue(); }

static struct g *ggetc(struct g*f), *gflush(struct g*f);
static g_vm(g_vm_getc) {
 if (!g_ready(getnum(g_stdin.fd))) {
  f->next_wait_fd = getnum(g_stdin.fd);
  return Ap(g_vm_yield_sw, f); }
 Pack(f);
 if (!g_ok(f = ggetc(f))) return f;
 Unpack(f);
 Sp[0] = putnum(f->b);
 Ip += 1;
 return Continue(); }


// (fgetc port) — like (getc _) but on an explicit port. Cooperative wait
// uses the port's own fd.
static g_vm(g_vm_fgetc) {
 if (iop(Sp[0])) {
   struct g_io *i = (struct g_io*) Sp[0];
   if (!g_ready(getnum(i->fd))) {
    f->next_wait_fd = getnum(i->fd);
    return Ap(g_vm_yield_sw, f); }
   Pack(f);
   f->io = i;
   if (!g_ok(f = zgetc(f))) return f;
   Unpack(f);
   Sp[0] = putnum(f->b); }
 Ip += 1;
 return Continue(); }

// (fungetc port byte) — push back one byte, return the byte.
static g_vm(g_vm_fungetc) {
 if (iop(Sp[0])) {
  struct g_io *i = (struct g_io*) Sp[0];
  Pack(f);
  f->io = i;
  if (!g_ok(f = zungetc(f, getnum(f->sp[1])))) return f;
  Unpack(f); }
 Sp += 1;
 Ip += 1;
 return Continue(); }

// (feof port) — -1 if at end of stream, nil otherwise.
static g_vm(g_vm_feof) {
 if (iop(Sp[0])) {
  struct g_io *i = (struct g_io*) Sp[0];
  Pack(f);
  f->io = i;
  if (!g_ok(f = zeof(f))) return f;
  Unpack(f);
  Sp[0] = f->b ? putnum(-1) : nil; }
 Ip += 1;
 return Continue(); }

struct g*gputs(struct g*f, char const*s) {
 while (*s) f = gputc(f, *s++);
 return f; }

static struct g*gzputc(struct g*f, int c) { return g_ok(f) ? port_vt(f->io->fd)->putc(f, c) : f; }

static struct g*gzputn(struct g *f, intptr_t n, uint8_t b) {
 uintptr_t
  m = n >= 0 || b != 10 ? (uintptr_t) n : (f = gzputc(f, '-'), -(uintptr_t) n),
  q = m / b,
  r = m % b;
 if (q) f = gzputn(f, q, b);
 return gzputc(f, g_digits[r]); }

static struct g *g_putn(struct g *f, struct g_io *o, intptr_t n, uint8_t b) {
 g_core_of(f)->io = o;
 return gzputn(f, n, b); }

static struct g*gvzprintf(struct g*f, char const *fmt, va_list xs) {
 for (int c; (c = *fmt++);) {
  if (c != '%') f = gzputc(f, c);
  else pass: switch ((c = *fmt++)) {
   case 0: goto out;
   case 'l': goto pass;
   case 'b': f = gzputn(f, va_arg(xs, uintptr_t), 2); continue;
   case 'o': f = gzputn(f, va_arg(xs, uintptr_t), 8); continue;
   case 'd': f = gzputn(f, va_arg(xs, uintptr_t), 10); continue;
   case 'x': f = gzputn(f, va_arg(xs, uintptr_t), 16); continue;
   default: f = gzputc(f, c); } } out:
 return f; }


static struct g *gzprintf(struct g *f, char const *fmt, ...) {
 va_list xs;
 va_start(xs, fmt);
 f = gvzprintf(f, fmt, xs);
 va_end(xs);
 return f; }

static struct g *gzputx(struct g *f, intptr_t x);

static g_inline struct g*gzput_two(struct g*f, word x) {
 MM(f, &x);
 struct g_str *n;
 if (symp(A(x)) && (n = sym(A(x))->nom) && len(n) == 1 && txt(n)[0] == '`' && twop(B(x))) {
   f = gzputc(f, '\'');
   f = gzputx(f, AB(x));
   goto out; }
 for (f = gzputc(f, '(');; f = gzputc(f, ' '), x = B(x)) {
  f = gzputx(f, A(x));
  if (!twop(B(x))) { f = gzputc(f, ')'); goto out; } }
out: return UM(f), f; }


static g_inline struct g*gzput_vec(struct g*f, word x) {
 MM(f, &x);
 if (vec(x)->rank == 0 && vec(x)->type == G_VT_FLO) {
  char buf[32];
  // 7 sig digits is enough for round-trip on f32; 15 for f64.
  int max_frac = sizeof(g_flo_t) == 4 ? 7 : 15;
  int n = g_dtoa((double) *(g_flo_t*) vec_data(x), buf, (int) sizeof buf, max_frac);
  for (int i = 0; g_ok(f) && i < n; i++) f = gzputc(f, buf[i]);
  return UM(f), f; }
 uintptr_t type = vec(x)->type, rank = vec(x)->rank;
 f = gzprintf(f, "#vec@%x:%d.%d", vec(x), type, rank);
 for (uintptr_t i = 0; i < rank && g_ok(f); i++)
  f = gzprintf(f, ".%d", (intptr_t) vec(x)->shape[i]);
 return UM(f), f; }

static g_inline struct g*gzput_str(struct g*f, word x) {
 MM(f, &x);
 uintptr_t slen = len(x);
 f = gzputc(f, '"');
 for (uintptr_t i = 0; g_ok(f) && i < slen; i++) {
  char c = txt(x)[i];
  if (c == '\\' || c == '"') f = gzputc(f, '\\');
  else if (c == '\n') f = gzputc(f, '\\'), c = 'n';
  else if (c == '\t') f = gzputc(f, '\\'), c = 't';
  else if (c == '\r') f = gzputc(f, '\\'), c = 'r';
  else if (c == '\0') f = gzputc(f, '\\'), c = '0';
  else if ((unsigned char) c < 32) {           // other ctl bytes -> \xHH
   f = gzputc(f, '\\');
   f = gzputc(f, 'x');
   f = gzputc(f, g_digits[(c >> 4) & 0xf]);
   c = g_digits[c & 0xf]; }
  f = gzputc(f, c); }
 f = gzputc(f, '"');
 return UM(f), f; }


static g_inline struct g*gzput_sym(struct g*f, word x) {
 MM(f, &x);
 struct g_str *s = sym(x)->nom;
 if (s) {
  uintptr_t slen = len(s);
  for (uintptr_t i = 0; g_ok(f) && i < slen; i++)
   f = gzputc(f, txt(s)[i]); }
 else f = gzprintf(f, "#sym@%x", x);
 return UM(f), f; }

static g_inline struct g*gzput_tbl(struct g*f, word x) {
 return gzprintf(f, "#tab@%x:%d/%d", x, tbl(x)->len, tbl(x)->cap); }

static struct g *gzputx(struct g *f, intptr_t x) {
 if (nump(x)) return gzprintf(f, "%d", getnum(x));
 if (!datp(x)) return gzprintf(f, "#%lx", (long) x);
 switch (typ(x)) {
   default: __builtin_trap();
   case two_q: return gzput_two(f, x);
   case vec_q: return gzput_vec(f, x);
   case sym_q: return gzput_sym(f, x);
   case tbl_q: return gzput_tbl(f, x);
   case text_q: return gzput_str(f, x); } }

static struct g *gfputx(struct g *f, struct g_io *o, intptr_t x) {
 return g_core_of(f)->io = o, gzputx(f, x); }

struct g *gputx(struct g*f, word x) {
 return gfputx(f, &g_stdout, x); }

struct g *gputn(struct g*f, intptr_t n, uint8_t b) {
  return g_putn(f, &g_stdout, n, b); }

static g_vm(g_vm_putc) {
 Pack(f);
 if (!g_ok(f = gputc(f, getnum(*Sp)))) return f;
 Unpack(f);
 Ip += 1;
 return Continue(); }

// (fputc port byte) — write byte to port; return byte.
static g_vm(g_vm_fputc) {
 if (iop(Sp[0])) {
  struct g_io *o = (struct g_io*) Sp[0];
  Pack(f);
  f->io = o;
  if (!g_ok(f = zputc(f, getnum(f->sp[1])))) return f;
  Unpack(f); }
 Sp += 1;
 Ip += 1;
 return Continue(); }

// (fflush port) — flush; return the port.
static g_vm(g_vm_fflush) {
 if (iop(Sp[0])) {
  struct g_io *o = (struct g_io*) Sp[0];
  Pack(f);
  f->io = o;
  if (!g_ok(f = zflush(f))) return f;
  Unpack(f); }
 Ip += 1;
 return Continue(); }

// (fputs port s) — write every byte of string s through port; return the
// port. No-op when args are misused (non-port or non-string). Re-reads
// Sp[1] each iteration so GC inside zputc (e.g., growing a sink buffer)
// can forward the string safely.
static g_vm(g_vm_fputs) {
 if (iop(Sp[0]) && strp(Sp[1])) {
  Pack(f);
  f->io = (struct g_io*) f->sp[0];
  for (uintptr_t i = 0; g_ok(f) && i < len(f->sp[1]);)
   f = zputc(f, txt(f->sp[1])[i++]);
  if (!g_ok(f)) return f;
  Unpack(f); }
 Sp += 1;
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_puts) {
 if (strp(Sp[0])) {
  Pack(f);
  for (uintptr_t i = 0; i < len(f->sp[0]);) f = gputc(f, txt(f->sp[0])[i++]);
  if (!g_ok(f = gflush(f))) return f;
  Unpack(f); }
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_putn) {
 Pack(f);
 uintptr_t n = getnum(Sp[0]), b = getnum(Sp[1]);
 if (!g_ok(f = g_putn(f, &g_stdout, n, b))) return f;
 Unpack(f);
 Sp[1] = Sp[0];
 Sp += 1;
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_dot) {
 Pack(f);
 if (!g_ok(f = gfputx(f, &g_stdout, f->sp[0]))) return f;
 Unpack(f);
 Ip += 1;
 return Continue(); }

// (inspect x) -> string. Alloc a heap data-sink, gfputx x into it, harvest.
// Stack walk:
//   in:                  Sp = [x, ...]
//   after to_alloc:      Sp = [port, x, ...]
//   after gfputx:        Sp = [port, x, ...]  (slots may be forwarded)
//   after to_harvest:    Sp = [str, port, x, ...]
//   drop port and x:     Sp = [str, ...]
static g_vm(g_vm_inspect) {
 Pack(f);
 if (!g_ok(f = to_alloc(f))) return f;
 if (!g_ok(f = gfputx(f, (struct g_io*) f->sp[0], f->sp[1]))) return f;
 if (!g_ok(f = to_harvest(f, (struct to*) f->sp[0]))) return f;
 f->sp[2] = f->sp[0];
 f->sp += 2;
 Unpack(f);
 Ip += 1;
 return Continue(); }

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
     if (la != lb || memcmp(vec(a), vec(b), la)) return false;
     break; }
    case text_q:
     if (len(a) != len(b) || memcmp(txt(a), txt(b), len(a))) return false;
     break; } }
  if (w == base) return true;              // worklist drained: all equal
  b = *--w, a = *--w; } }

opf(g_vm_bsr, >>)
opf(g_vm_bsl, <<)

// Truncation toward zero. Magnitudes above 2^63 are already
// integer-valued in double precision, so we leave them alone instead of
// risking an int64 overflow on the round-trip. NaN passes through.
static g_inline g_flo_t g_trunc(g_flo_t x) {
 if (x != x) return x;
 g_flo_t m = x < 0 ? -x : x;
 if (m > (g_flo_t) 9.22e18) return x;
 return (g_flo_t)(int64_t) x; }

// Float remainder via truncated quotient. Matches libm's fmod() for
// the cases we care about. When b == 0, x/b is ±inf or NaN, ±inf*0 is
// NaN, so the result is NaN — same as libm.
static g_inline g_flo_t g_fmod(g_flo_t a, g_flo_t b) {
 return a - g_trunc(a / b) * b; }

// Generic arithmetic dispatcher. Both fixnums + no overflow → fixnum
// result; otherwise (mixed nump/flop, overflow, /0, both flop) → double
// result. Division/remainder by zero promote to IEEE values (±inf or
// NaN), not nil. Non-numeric operands return nil.
// g_noinline + by-value struct return keeps the &t overflow-out-param
// off the g_vm caller's frame, preserving TCO.
enum arith_op { AOP_ADD, AOP_SUB, AOP_MUL, AOP_QUOT, AOP_REM };
struct arith_r { word v; g_flo_t d; bool isflo; bool isnil; };

static g_noinline struct arith_r do_arith(word a, word b, enum arith_op op) {
 struct arith_r r = { 0, 0, false, false };
 if (nump(a) && nump(b)) {
  intptr_t av = getnum(a), bv = getnum(b), t = 0;
  bool do_float = false;
  switch (op) {
   case AOP_ADD: do_float = __builtin_add_overflow(av, bv, &t); break;
   case AOP_SUB: do_float = __builtin_sub_overflow(av, bv, &t); break;
   case AOP_MUL: do_float = __builtin_mul_overflow(av, bv, &t); break;
   case AOP_QUOT:
    if (bv == 0) do_float = true;
    else if (av == INTPTR_MIN && bv == -1) do_float = true;
    else t = av / bv;
    break;
   case AOP_REM:
    if (bv == 0) do_float = true;
    else if (av == INTPTR_MIN && bv == -1) t = 0;
    else t = av % bv;
    break; }
  // Also require the result to fit the tagged-fixnum range (one bit lost).
  if (!do_float && (t < (INTPTR_MIN >> 1) || t > (INTPTR_MAX >> 1)))
   do_float = true;
  if (!do_float) { r.v = putnum(t); return r; } }
 // Float path: require both operands numeric.
 if (!(nump(a) || flop(a)) || !(nump(b) || flop(b))) {
  r.isnil = true; return r; }
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : *(g_flo_t*) vec_data(a);
 g_flo_t bd = nump(b) ? (g_flo_t) getnum(b) : *(g_flo_t*) vec_data(b);
 g_flo_t rd = 0;
 switch (op) {
  case AOP_ADD: rd = ad + bd; break;
  case AOP_SUB: rd = ad - bd; break;
  case AOP_MUL: rd = ad * bd; break;
  case AOP_QUOT: rd = ad / bd; break;         // ±inf or NaN on bd == 0
  case AOP_REM:  rd = g_fmod(ad, bd); break;  // NaN on bd == 0
 }
 r.isflo = true; r.d = rd;
 return r; }

#define ARITH_OP(nom, op_tag) g_vm(nom) {                                  \
 struct arith_r r = do_arith(Sp[0], Sp[1], op_tag);                        \
 if (r.isnil)  { Sp[1] = nil;  Sp += 1; Ip++; return Continue(); }         \
 if (!r.isflo) { Sp[1] = r.v;  Sp += 1; Ip++; return Continue(); }         \
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));              \
 Have(req);                                                                \
 struct g_vec *v = (struct g_vec*) Hp;                                     \
 Hp += req;                                                                \
 v->ap = g_vm_data;                                                        \
 v->typ = vec_q;                                                           \
 v->type = G_VT_FLO;                                                       \
 v->rank = 0;                                                              \
 *(g_flo_t*) v->shape = r.d;                                               \
 Sp[1] = word(v);                                                          \
 Sp += 1; Ip++; return Continue(); }

ARITH_OP(g_vm_add,  AOP_ADD)
ARITH_OP(g_vm_sub,  AOP_SUB)
ARITH_OP(g_vm_mul,  AOP_MUL)
ARITH_OP(g_vm_quot, AOP_QUOT)
ARITH_OP(g_vm_rem,  AOP_REM)

// Mixed-numeric ordered comparison. Same nump-fast-path, else widen.
// Non-numeric operands return nil (matches existing degraded behavior
// on cross-type compares but well-defined).
#define CMP_OP(nom, c_op) g_vm(nom) {                                      \
 word a = Sp[0], b = Sp[1];                                                \
 word x;                                                                   \
 if (nump(a) && nump(b)) x = (a c_op b) ? putnum(-1) : nil;                \
 else if ((nump(a) || flop(a)) && (nump(b) || flop(b))) {                  \
  g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : *(g_flo_t*) vec_data(a);    \
  g_flo_t bd = nump(b) ? (g_flo_t) getnum(b) : *(g_flo_t*) vec_data(b);    \
  x = (ad c_op bd) ? putnum(-1) : nil;                                     \
 } else x = nil;                                                           \
 Sp[1] = x; Sp += 1; Ip++; return Continue(); }

CMP_OP(g_vm_lt, <)
CMP_OP(g_vm_le, <=)
CMP_OP(g_vm_gt, >)
CMP_OP(g_vm_ge, >=)

// (= a b) — value-equality with numeric promotion across nump/flop.
// Falls through to eql for non-numeric operands so symbol/pair/string
// identity is unchanged. Note: this is strictly looser than eqv, which
// still rejects mixed-type pairs (so table keys 3 and 3.0 stay distinct).
static g_vm(g_vm_eq) {
 word a = Sp[0], b = Sp[1];
 bool eq;
 if (nump(a) && nump(b)) eq = a == b;
 else if ((nump(a) || flop(a)) && (nump(b) || flop(b))) {
  g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : *(g_flo_t*) vec_data(a);
  g_flo_t bd = nump(b) ? (g_flo_t) getnum(b) : *(g_flo_t*) vec_data(b);
  eq = ad == bd;
 } else eq = eql(f, a, b);
 Sp[1] = eq ? putnum(-1) : nil;
 Sp += 1; Ip++; return Continue(); }
op(g_vm_bnot, 1, ~Sp[0] | 1)
op(g_vm_band, 2, (Sp[0] & Sp[1]) | 1)
op(g_vm_bor, 2, (Sp[0] | Sp[1]) | 1)
op(g_vm_bxor, 2, (Sp[0] ^ Sp[1]) | 1)
op(g_vm_nump, 1, oddp(Sp[0]) ? putnum(-1) : nil)
op11(g_vm_nilp, nilp(Sp[0]) ? putnum(-1) : nil)

// Unary math bif: nump/flop arg → double via vec_data, call fn, allocate
// rank-0 f64 inline. Non-numeric arg → nil. TCO-clean (no & escapes).
#define MATH1_OP(nom, fn) g_vm(nom) {                                      \
 word a = Sp[0];                                                           \
 if (!nump(a) && !flop(a)) { Sp[0] = nil; Ip++; return Continue(); }       \
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : *(g_flo_t*) vec_data(a);     \
 g_flo_t rd = fn(ad);                                                      \
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));              \
 Have(req);                                                                \
 struct g_vec *v = (struct g_vec*) Hp;                                     \
 Hp += req;                                                                \
 v->ap = g_vm_data;                                                        \
 v->typ = vec_q;                                                           \
 v->type = G_VT_FLO;                                                       \
 v->rank = 0;                                                              \
 *(g_flo_t*) v->shape = rd;                                                \
 Sp[0] = word(v);                                                          \
 Ip++; return Continue(); }

#define MATH2_OP(nom, fn) g_vm(nom) {                                      \
 word a = Sp[0], b = Sp[1];                                                \
 if ((!nump(a) && !flop(a)) || (!nump(b) && !flop(b)))                     \
  { Sp[1] = nil; Sp += 1; Ip++; return Continue(); }                       \
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : *(g_flo_t*) vec_data(a);     \
 g_flo_t bd = nump(b) ? (g_flo_t) getnum(b) : *(g_flo_t*) vec_data(b);     \
 g_flo_t rd = fn(ad, bd);                                                  \
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));              \
 Have(req);                                                                \
 struct g_vec *v = (struct g_vec*) Hp;                                     \
 Hp += req;                                                                \
 v->ap = g_vm_data;                                                        \
 v->typ = vec_q;                                                           \
 v->type = G_VT_FLO;                                                       \
 v->rank = 0;                                                              \
 *(g_flo_t*) v->shape = rd;                                                \
 Sp[1] = word(v);                                                          \
 Sp += 1; Ip++; return Continue(); }

MATH1_OP(g_vm_sin,   g_sin)
MATH1_OP(g_vm_cos,   g_cos)
MATH1_OP(g_vm_tan,   g_tan)
MATH1_OP(g_vm_atan,  g_atan)
MATH1_OP(g_vm_sqrt,  g_sqrt)
MATH1_OP(g_vm_exp,   g_exp)
MATH1_OP(g_vm_log,   g_log)
MATH2_OP(g_vm_atan2, g_atan2)
MATH2_OP(g_vm_pow,   g_pow)

static g_vm(g_vm_info) {
 size_t const req = 4 * Width(struct g_pair);
 Have(req);
 struct g_pair *si = (struct g_pair*) Hp;
 Hp += req;
 Sp[0] = word(si);
 ini_two(si, putnum(f), word(si + 1));
 ini_two(si + 1, putnum(f->len), word(si + 2));
 ini_two(si + 2, putnum(Hp - ptr(f)), word(si + 3));
 ini_two(si + 3, putnum(ptr(f) + f->len - Sp), nil);
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
 word x = word(Ip);
 Ip = cell(*++Sp);
 *Sp = x;
 return Continue(); }

// Single unified port discriminator. Behaviorally identical to g_vm_data
// (capture self, pop one, return self) but a distinct symbol so the GC's
// `datp` check routes ports through evac_thd (thread walker) rather than
// evac_data.
g_vm(g_vm_port_io) {
 word x = word(Ip);
 Ip = cell(*++Sp);
 *Sp = x;
 return Continue(); }


// push a value from the stack
static g_vm(g_vm_arg) {
 Have1();
 Sp[-1] = Sp[getnum(Ip[1].x)];
 Sp -= 1;
 Ip += 2;
 return Continue(); }

#define YIELD_INTERVAL 64
#define YieldCheck() \
  if (f->tasks->m != f->tasks && ++f->yield_ctr >= YIELD_INTERVAL) \
    return Ap(g_vm_yield_sw, f)

// apply function to one argument
static g_noinline g_vm(g_vm_ap) {
 union u *k;
 if (oddp(Sp[1])) Ip++, Sp++;
 else k = cell(Sp[1]), Sp[1] = word(Ip + 1), Ip = k;
 YieldCheck();
 return Continue(); }

// tail call
static g_vm(g_vm_tap) {
 intptr_t x = Sp[0], j = Sp[1];
 Sp += getnum(Ip[1].x) + 1;
 if (homp(j)) Ip = cell(j), Sp[0] = x;
 else Sp += 1, Ip = cell(Sp[0]), Sp[0] = j;
 YieldCheck();
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
 YieldCheck();
 return Continue(); }

// tail call
static g_vm(g_vm_tapn) {
 size_t n = getnum(Ip[1].x),
        r = getnum(Ip[2].x);
 Ip = cell(Sp[n]) + 2;
 word *o = Sp;
 for (Sp += r + 1; n--; Sp[n] = o[n]);
 YieldCheck();
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

static g_vm(g_vm_trim) { return
 clip(cell(Sp[0])),
 Ip += 1,
 Continue(); }

static g_vm(g_vm_seek) { return
 Sp[1] = word(cell(Sp[1]) + getnum(Sp[0])),
 Sp += 1,
 Ip += 1,
 Continue(); }

static g_vm(g_vm_peek2) { return
 Sp[1] = (cell(Sp[1]) + getnum(Sp[0]))->x,
 Sp += 1,
 Ip += 1,
 Continue(); }

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
 k[n].m = NULL, k[n+1].m = k;
 memset(k, -1, n * sizeof(word));
 Sp[0] = word(k);
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_len) {
  word x = Sp[0], l = 0;
  if (!nump(x) && datp(x)) switch (typ(x)) {
    case tbl_q: l = tbl(x)->len; break;
    case text_q: l = len(x); break;
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

static g_inline void evac_two(struct g*f, word const*const p0, word const*const t0) {
 struct g_pair *w = (struct g_pair*) f->cp;
 f->cp += Width(struct g_pair);
 w->a = gcp(f, w->a, p0, t0);
 w->b = gcp(f, w->b, p0, t0); }

static g_inline void evac_vec(struct g*f, word const*const p0, word const*const t0) {
 f->cp += b2w(g_vec_bytes(vec(f->cp))); }

static g_inline void evac_str(struct g*f, word const*const p0, word const*const t0) {
 f->cp += b2w(sizeof(struct g_str) + str(f->cp)->len); }

static g_inline void evac_sym(struct g*f, word const*const p0, word const*const t0) {
 f->cp += Width(struct g_atom) - (sym(f->cp)->nom ? 0 : 2); }

static g_inline void evac_tbl(struct g*f, word const*const p0, word const*const t0) {
 struct g_tab *t = (struct g_tab*) f->cp;
 f->cp += Width(struct g_tab) + t->cap + t->len * Width(struct g_kvs);
 for (intptr_t i = 0, lim = t->cap; i < lim; i++)
  for (struct g_kvs*e = t->tab[i]; e;
   e->key = gcp(f, e->key, p0, t0),
   e->val = gcp(f, e->val, p0, t0),
   e = e->next); }

static g_inline void evac_thd(struct g *g, word const *const p0, word const*const t0) {
  for (g->cp += 2; g->cp[-2]; g->cp[-2] = gcp(g, g->cp[-2], p0, t0), g->cp++); }

static g_inline void evac_data(struct g *g, word const *const p0, word const*const t0) {
  switch (typ(g->cp)) {
   default: __builtin_trap();
   case vec_q: return evac_vec(g, p0, t0);
   case sym_q: return evac_sym(g, p0, t0);
   case two_q: return evac_two(g, p0, t0);
   case tbl_q: return evac_tbl(g, p0, t0);
   case text_q: return evac_str(g, p0, t0); } }

static g_inline void run_finalizers(struct g*g) {
 struct g_fz *new_fz = NULL;
 for (struct g_fz *fz = g->fz; fz; fz = fz->next) {
  word fwd = fz->p->x;
  if (homp(fwd) && ptr(g) <= ptr(fwd) && ptr(fwd) < ptr(g) + g->len) {
   struct g_fz *nn = bump(g, Width(struct g_fz));
   nn->p = cell(fwd), nn->fn = fz->fn, nn->next = new_fz, new_fz = nn;
  } else fz->fn(fz->p); }
 g->fz = new_fz; }

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
 g->tasks = cell(gcp(g, word(g->tasks), p0, t0));
 g->symbols = 0;
 for (word i = 0; i < g->end - &g->v0; i++) (&g->v0)[i] = gcp(g, (&g->v0)[i], p0, t0);               // core live variables
 for (word n = 0; n < h; n++) g->sp[n] = gcp(g, sp0[n], p0, t0);                     // stack
 for (struct g_r *s = g->root; s; s = s->n) *s->x = gcp(g, *s->x, p0, t0); // C live variables
 while (g->cp < g->hp) (datp(g->cp) ? evac_data : evac_thd)(g, p0, t0);              // cheney algorithm
 run_finalizers(g);
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

struct g *g_finalize(struct g *f, union u *p, void (*fn)(void *)) {
 if (g_ok(f = have(g_push(f, 1, p), Width(struct g_fz)))) {
  p = cell(pop1(f));
  struct g_fz *n = bump(f, Width(struct g_fz));
  n->p = p, n->fn = fn, n->next = f->fz, f->fz = n; }
 return f; }

static g_inline word copy_two(struct g*f, struct g_pair *src, word const *const p0, word const *const t0) {
 struct g_pair *dst = bump(f, Width(struct g_pair));
 ini_two(dst, src->a, src->b);
 src->ap = (g_vm_t*) dst;
 return word(dst); }

static g_inline word copy_vec(struct g*f, struct g_vec *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = g_vec_bytes(src);
 struct g_vec *dst = bump(f, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

static g_inline word copy_str(struct g*f, struct g_str *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = sizeof(struct g_str) + src->len;
 struct g_str *dst = bump(f, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

static g_inline word copy_sym(struct g*f, struct g_atom *src, word const *const p0, word const*const t0) {
 struct g_atom *dst;
 if (src->nom) dst = intern_checked(f, (struct g_str*) gcp(f, word(src->nom), p0, t0));
 else dst = bump(f, Width(struct g_atom) - 2),
      ini_anon(dst, src->code);
 return word(src->ap = (g_vm_t*) dst); }

static g_inline word copy_tbl(struct g*f, struct g_tab *src, word const*const p0, word const*const t0) {
 uintptr_t len = src->len, cap = src->cap;
 struct g_tab *dst = bump(f, Width(struct g_tab) + cap + Width(struct g_kvs) * len);
 struct g_kvs **tab = (struct g_kvs**) (dst + 1),
              *dd = (struct g_kvs*) (tab + cap);
 ini_tab(dst, len, cap, tab);
 src->ap = (g_vm_t*) dst;
 for (struct g_kvs *d, *s, *last; cap--; tab[cap] = last)
  for (s = src->tab[cap], last = NULL; s;
   d = dd++, d->key = s->key, d->val = s->val, d->next = last,
   last = d, s = s->next);
 return word(dst); }

static g_inline word copy_data(struct g *f, union u *src, word const *const p0, word const *const t0) {
 switch (typ(src)) {
  default: __builtin_trap();
  case two_q: return copy_two(f, two(src), p0, t0);
  case vec_q: return copy_vec(f, vec(src), p0, t0);
  case sym_q: return copy_sym(f, sym(src), p0, t0);
  case tbl_q: return copy_tbl(f, tbl(src), p0, t0);
  case text_q: return copy_str(f, str(src), p0, t0); } }

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
 return homp(x) && ptr(f) <= ptr(x) && ptr(x) < ptr(f) + f->len ? x :
        x == (word) g_vm_data ? copy_data(f, src, p0, t0) :
                                copy_thread(f, src, p0, t0); }


enum g_status g_fin(struct g *f) {
 enum g_status s = g_code_of(f);
 if ((f = g_core_of(f))) {
   for (struct g_fz *fz = f->fz; fz; fz->fn(fz->p), fz = fz->next); // run finalizers
   f->free(f, f->pool); }
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
 _(bif_dot, ".", S1(g_vm_dot)) _(bif_fread, "fread", S2(g_vm_fread)) _(bif_getc, "getc", S1(g_vm_getc))\
 _(bif_str, "str", S1(g_vm_str)) _(bif_strin, "strin", S1(g_vm_strin))\
 _(bif_putc, "putc", S1(g_vm_putc)) _(bif_prn, "putn", S2(g_vm_putn)) _(bif_puts, "puts", S1(g_vm_puts))\
 _(bif_sym, "sym", S1(g_vm_gensym)) _(bif_nom, "nom", S1(g_vm_symnom)) _(bif_thd, "thd", S1(g_vm_thda))\
 _(bif_peek, "peek", S2(g_vm_peek2)) _(bif_poke, "poke", S3(g_vm_poke2)) _(bif_trim, "trim", S1(g_vm_trim))\
 _(bif_seek, "seek", S2(g_vm_seek)) _(bif_len, "len", S1(g_vm_len)) _(bif_get, "get", S3(g_vm_get))\
 _(bif_put, "put", S3(g_vm_put)) _(bif_tnew, "new", S1(g_vm_tnew)) _(bif_tabkeys, "tkeys", S1(g_vm_tkeys))\
 _(bif_tabdel, "tdel", S3(g_vm_tdel)) _(bif_twop, "twop", S1(g_vm_twop)) _(bif_strp, "strp", S1(g_vm_strp))\
 _(bif_flo, "flo", S1(g_vm_flo)) _(bif_flop, "flop", S1(g_vm_flop))\
 _(bif_sin, "sin", S1(g_vm_sin)) _(bif_cos, "cos", S1(g_vm_cos))\
 _(bif_tan, "tan", S1(g_vm_tan)) _(bif_atan, "atan", S1(g_vm_atan))\
 _(bif_sqrt, "sqrt", S1(g_vm_sqrt)) _(bif_exp, "exp", S1(g_vm_exp))\
 _(bif_log, "log", S1(g_vm_log))\
 _(bif_atan2, "atan2", S2(g_vm_atan2)) _(bif_pow, "pow", S2(g_vm_pow))\
 _(bif_symp, "symp", S1(g_vm_symp)) _(bif_tblp, "tblp", S1(g_vm_tblp)) _(bif_nump, "nump", S1(g_vm_nump))\
 _(bif_nilp, "nilp", S1(g_vm_nilp)) _(bif_ev, "ev", S1(g_vm_eval))\
 _(bif_callk, "call_cc", S1(g_vm_callk)) _(bif_yield, "yield", S1(g_vm_yield_bif)) \
 _(bif_spawn, "spawn", S2(g_vm_spawn)) _(bif_wait, "wait", S1(g_vm_wait)) \
 _(bif_sleep, "sleep", S1(g_vm_sleep)) _(bif_donep, "done?", S1(g_vm_donep)) \
 _(bif_kill, "kill", S1(g_vm_kill)) \
 _(bif_key, "key?", S1(g_vm_key)) \
 _(bif_inspect, "inspect", S1(g_vm_inspect)) \
 _(bif_fgetc, "fgetc", S1(g_vm_fgetc)) \
 _(bif_fungetc, "fungetc", S2(g_vm_fungetc)) \
 _(bif_feof, "feof", S1(g_vm_feof)) \
 _(bif_fputc, "fputc", S2(g_vm_fputc)) \
 _(bif_fputs, "fputs", S2(g_vm_fputs)) \
 _(bif_fflush, "fflush", S1(g_vm_fflush))
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
 struct g_def def0[] = {
  {"globals", d, },
  {"macros", m, },
  {"in", (intptr_t) &g_stdin},
  {"out", (intptr_t) &g_stdout},
  {0}, };
 if (g_ok(f = have(g_defs(g_defs(f, def0), def1), 7))) {
  union u *M = bump(f, 7);
  M[0].m = M;
  M[1].x = nil;   // sentinel; replaced on first yield
  M[2].x = nil;   // main pid
  M[3].x = nil;   // wake_at: nil means "always runnable"
  M[4].x = putnum(-1);  // wait_fd: -1 = not waiting on I/O (slot value -1, non-zero)
  M[5].m = NULL;
  M[6].m = f->tasks = M; }
 return f; }

void *g_libc_malloc(struct g*f, size_t n) { return malloc(n); }
void g_libc_free(struct g*f, void *x) { free(x); }

// default sleep is busy wait
__attribute__((weak)) void g_sleep(uintptr_t ticks) {
  for (ticks += g_clock(); g_clock() < ticks;); }

// Default fd-keyed waits. Frontends override; defaults are conservative
// (all fds always-ready; multi-source wait collapses to plain sleep) so
// frontends that don't multitask (lcat, pd) link without providing impls.
__attribute__((weak)) bool g_ready(int fd) { (void) fd; return true; }
__attribute__((weak)) void g_wait_fds(int const *fds, int n, uintptr_t ticks) {
  (void) fds; (void) n; g_sleep(ticks); }

// Default fd close is a no-op. The host overrides with close(2); kernel
// and pd don't have real OS fds to release, so the no-op is correct.
__attribute__((weak)) void g_fd_close(int fd) { (void) fd; }

// Math hooks. Weak defaults trap so calls on a frontend without an
// override fail loudly (kernel/pico/esp until internal impls land).
// Host and pd override via libm.
#define WEAK_TRAP1(nom) __attribute__((weak)) g_flo_t nom(g_flo_t x) \
  { (void) x; __builtin_trap(); }
#define WEAK_TRAP2(nom) __attribute__((weak)) g_flo_t nom(g_flo_t x, g_flo_t y) \
  { (void) x; (void) y; __builtin_trap(); }
WEAK_TRAP1(g_sin)  WEAK_TRAP1(g_cos)  WEAK_TRAP1(g_tan)
WEAK_TRAP1(g_atan) WEAK_TRAP1(g_sqrt) WEAK_TRAP1(g_exp)
WEAK_TRAP1(g_log)
WEAK_TRAP2(g_atan2) WEAK_TRAP2(g_pow)

extern g_inline struct g *g_pop(struct g*f, uintptr_t n) { return g_core_of(f)->sp += n, f; }
static g_inline struct g *symof(char const *n, struct g *f) { return intern(g_strof(f, n)); }

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

static struct g *ggetc(struct g*f)  { return g_core_of(f)->io = &g_stdin, port_vt(g_stdin.fd)->getc(f); }
struct g *gputc(struct g*f, int c)  { return g_core_of(f)->io = &g_stdout, port_vt(g_stdout.fd)->putc(f, c); }
static struct g *gflush(struct g*f) { return g_core_of(f)->io = &g_stdout, port_vt(g_stdout.fd)->flush(f); }

#define topof(f) ((word*)f+f->len)

// kcall : x = Sp[0], k = Ip[1] -> Ip = k, Sp[0] = x
static g_vm(g_vm_kcall) {
 word x = Sp[0];
 union u *stack = Ip + 2, *end = (union u*) ttag(stack);
 uintptr_t height = end - stack;
 Have(height);
 *(Sp = memmove(topof(f) - height, stack, height * sizeof(word))) = x;
 Ip = Ip[1].m;
 return Continue(); }

// callk : i = Sp[0], k = Ip + 1 -> Ip = i, Sp[0] = k
static g_vm(g_vm_callk) {
 word f_val = Sp[0];                         // f, the call_cc arg
 if (oddp(f_val)) return Ip += 1, Continue();
 word height = topof(f) - Sp;
 uintptr_t n = 2 + height;                   // g_vm_kcall + (ip + 1) + stack = thread_contents
 Have(n + Width(struct g_tag) + 1);          // thread_contents + thread_tag + 1 stack = _mem_req
 union u *k = (union u*) Hp;
 Hp += n + Width(struct g_tag);              // thread_contents + thread_tag = _heap_alloc
 k[0].ap = g_vm_kcall;                       // 
 k[1].m  = Ip + 1;                           // resume at next instruction
 memcpy(k + 2, Sp, height * sizeof(word));
 k[n].m = NULL;
 k[n+1].m = k;
 Sp -= 1;
 Sp[0] = word(k);
 Sp[1] = f_val;
 return Ap(g_vm_ap, f); }

// g_vm_yield_sw_mono can't call g_wait_fds directly with a stack pointer
static g_noinline void g_wait_fd(int const fd, int n, uintptr_t ms) {
  g_wait_fds(&fd, n, ms); }

// monotask fast path
static g_noinline g_vm(g_vm_yield_sw_mono) {
 uintptr_t my_wake = f->next_wake_at;
 int my_wait_fd = f->next_wait_fd;
 f->next_wake_at = 0;
 f->next_wait_fd = -1;
 f->yield_ctr = 0;
 if (my_wake) for (uintptr_t now; my_wake > (now = g_clock());)
  my_wait_fd >= 0 ? g_wait_fd(my_wait_fd, 1, my_wake - now) : g_sleep(my_wake - now);
 else if (my_wait_fd >= 0)
  while (!g_ready(my_wait_fd)) g_wait_fd(my_wait_fd, 1, 0);
 return Continue(); }

// First non-dormant peer in the ring whose wake_at <= now and whose
// wait_fd is either unset or actually ready. Without the wait_fd check
// a task parked on stdin would be scheduled immediately, busy-looping
// through yield_sw and filling the heap with stale task nodes.
static g_inline union u *find_runnable(union u *head, uintptr_t now) {
 for (union u *n = head->m; n != head; n = n->m)
  if (n[1].m->ap != g_vm_task_exit && (uintptr_t) getnum(n[3].x) <= now) {
   int wf = (int) getnum(n[4].x);
   if (wf < 0 || g_ready(wf)) return n; }
 return NULL; }

static g_noinline union u *yield_sw_wait(struct g *f, uintptr_t my_wake, int my_wait_fd) {
 uintptr_t min_wake = my_wake;
 int fds[G_WAIT_FDS_MAX], nfds = 0;
 if (my_wait_fd >= 0) fds[nfds++] = my_wait_fd;
 for (union u *n = f->tasks->m; n != f->tasks; n = n->m)
  if (n[1].m->ap != g_vm_task_exit) {
   uintptr_t wa = (uintptr_t) getnum(n[3].x);
   if (wa && (!min_wake || wa < min_wake)) min_wake = wa;
   int wf = (int) getnum(n[4].x);
   if (wf >= 0 && nfds < G_WAIT_FDS_MAX) fds[nfds++] = wf; }
 if (!min_wake && !nfds) return NULL;
 uintptr_t now = g_clock();
 if (!min_wake) g_wait_fds(fds, nfds, 0);
 else if (min_wake > now) g_wait_fds(fds, nfds, min_wake - now);
 now = g_clock();
 if (my_wait_fd >= 0 && g_ready(my_wait_fd)) return NULL;
 return find_runnable(f->tasks, now); }

static g_noinline g_vm(g_vm_yield_sw) {
 if (f->tasks->m == f->tasks) return Ap(g_vm_yield_sw_mono, f);
 union u *next = find_runnable(f->tasks, g_clock());
 uintptr_t my_wake = f->next_wake_at;
 int my_wait_fd = f->next_wait_fd;
 if (!next) {
  next = yield_sw_wait(f, my_wake, my_wait_fd);
  if (!next) {
   f->next_wake_at = 0;
   f->next_wait_fd = -1;
   if (f->yield_ctr >= YIELD_INTERVAL) f->yield_ctr = 0;
   return Continue(); } }
 word my_height = topof(f) - Sp;
 union u *next_stack = next + 5, *end = (union u*) ttag(next_stack);
 uintptr_t restore_h = end - next_stack,
           need = my_height + restore_h + 7;
 if (Sp < Hp + need) {
  Pack(f);
  if (!g_ok(f = g_please(g_push(f, 1, next), need))) return f;
  next = cell(pop1(f));
  Unpack(f);
  next_stack = next + 5; }   // recompute: next was forwarded by gc
 f->next_wake_at = 0;
 f->next_wait_fd = -1;
 union u *prev = next;
 while (prev->m != f->tasks) prev = prev->m;
 union u *N = (union u*) Hp;
 Hp += need - restore_h;
 N[0].m = f->tasks->m;
 N[1].m = Ip;
 N[2].x = f->tasks[2].x;
 N[3].x = putnum((intptr_t) my_wake);
 N[4].x = putnum(my_wait_fd);
 memcpy(N + 5, Sp, my_height * sizeof(word));
 N[5 + my_height].m = NULL;
 N[6 + my_height].m = prev->m = N;
 f->yield_ctr = 0;
 f->tasks = next;
 Sp = memmove(topof(f) - restore_h, next_stack, restore_h * sizeof(word));
 Ip = next[1].m;
 return Continue(); }

static g_vm(g_vm_yield_bif) { return Ip++, Ap(g_vm_yield_sw, f); }
static g_vm(g_vm_task_exit) { return Ap(g_vm_yield_sw, f); }

static union u spawn_body[] = { {g_vm_ap}, {.ap = g_vm_task_exit} };
static g_vm(g_vm_spawn) {
 Have(9);
 // New task node N: [next, saved_ip=spawn_body, pid, wake_at=0, wait_io=0, stack[0..1]=x,fn, NULL, HEAD]
 union u *N = (union u*) Hp;
 Hp += 9;
 word fn = Sp[0], x = Sp[1];
 uintptr_t pid = ++f->next_pid;
 N[0].m = f->tasks->m;
 N[1].m = (union u*) spawn_body;
 N[2].x = Sp[1] = putnum(pid);
 N[3].x = nil;         // wake_at: sentinel for "always runnable"
 N[4].x = putnum(-1);  // wait_fd: -1 = not waiting on I/O
 N[5].x = x;
 N[6].x = fn;
 N[7].m = NULL;
 N[8].m = f->tasks->m = N;
// f->yield_ctr = 0;
 Sp += 1;
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_wait) {
 word pid_arg = Sp[0], ret = nil;
 intptr_t target = getnum(pid_arg);
 for (union u *node = f->tasks->m; node != f->tasks; node = node->m) {
  if (getnum(node[2].x) != target) continue;
  if (node[1].m->ap == g_vm_task_exit) {
   // dormant: dormant task's stack is just [retval] at node[5]
   ret = node[5].x;
   union u *prev = node;
   while (prev->m != node) prev = prev->m;
   prev->m = node->m;
   break; }
   // still running: yield without advancing Ip (re-enter wait on resume)
  return Ap(g_vm_yield_sw, f); }
 Sp[0] = ret;
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_donep) {
 word pid_arg = Sp[0], result = putnum(-1);
 intptr_t target = getnum(pid_arg);
 for (union u *node = f->tasks->m; node != f->tasks; node = node->m)
  if (getnum(node[2].x) == target) {
   if (node[1].m->ap != g_vm_task_exit) result = nil;
   break; }
 Sp[0] = result;
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_kill) {
 word pid_arg = Sp[0], result = nil;
 intptr_t target = getnum(pid_arg);
 union u *prev = f->tasks;
 for (union u *node = prev->m; node != f->tasks; prev = node, node = node->m)
  if (getnum(node[2].x) == target) {
   prev->m = node->m;
   result = putnum(-1);
   break; }
 Sp[0] = result;
 Ip += 1;
 return Continue(); }

static g_vm(g_vm_sleep) {
 word n = Sp[0];
 Sp[0] = nil;
 Ip += 1;
 if (!nump(n) || getnum(n) <= 0) return Continue();
 f->next_wake_at = (uintptr_t) g_clock() + getnum(n);
 return Ap(g_vm_yield_sw, f); }

static g_vm(g_vm_key) {
 Sp[0] = (getnum(g_stdin.ungetc_buf) != EOF || g_ready(getnum(g_stdin.fd))) ? putnum(-1) : nil;
 Ip += 1;
 return Continue(); }
