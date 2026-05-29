#ifndef _g_i_h
#define _g_i_h
#include "g.h"

#if UINTPTR_MAX == UINT64_MAX
#define WBITS 64
typedef double g_flo_t;
#define G_VT_FLO g_vt_f64
#define g_sin   sin
#define g_cos   cos
#define g_tan   tan
#define g_atan  atan
#define g_atan2 atan2
#define g_sqrt  sqrt
#define g_exp   exp
#define g_log   log
#define g_pow   pow
#elif UINTPTR_MAX == UINT32_MAX
#define WBITS 32
typedef float g_flo_t;
#define G_VT_FLO g_vt_f32
#define g_sin   sinf
#define g_cos   cosf
#define g_tan   tanf
#define g_atan  atanf
#define g_atan2 atan2f
#define g_sqrt  sqrtf
#define g_exp   expf
#define g_log   logf
#define g_pow   powf
#endif

#if __STDC_HOSTED__
#include <math.h>
#else
g_flo_t g_sin(g_flo_t), g_cos(g_flo_t), g_tan(g_flo_t), g_atan(g_flo_t),
        g_atan2(g_flo_t, g_flo_t), g_sqrt(g_flo_t), g_exp(g_flo_t),
        g_log(g_flo_t), g_pow(g_flo_t, g_flo_t);
#endif

#define WBYTES (WBITS>>3)
_Static_assert(WBYTES == sizeof(uintptr_t), "word size sanity check");

#define G_WAIT_FDS_MAX 8
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
 g_vt_f32, g_vt_f64, };
void g_wait_fds(int const *fds, int n, uintptr_t ticks);
bool g_ready(int fd), g_strp(g_word);
struct g
 *g_read(struct g*, struct g_io*),
 *g_pop(struct g*, uintptr_t),
 *g_please(struct g*, uintptr_t),
 *g_evals(struct g*, const char*),
 *g_push(struct g*, uintptr_t, ...),
 *g_strof(struct g*, const char*),
 *gxl(struct g*),
 *gxr(struct g*),
 *gputc(struct g*, int),
 *gputx(struct g*, intptr_t),
 *gputn(struct g*, intptr_t, uint8_t),
 *gputs(struct g*, char const*),
 *g_eval(struct g*),
 *have(struct g*, uintptr_t),
 *g_tput(struct g*),
 *mktbl(struct g*),
 *intern(struct g*),
 *g_reads(struct g*, struct g_io*, bool),
 *g_read1(struct g*, struct g_io*),
 *g_putn(struct g *f, struct g_io *o, intptr_t n, uint8_t base),
 *str0(struct g*, uintptr_t);
struct g_atom *intern_checked(struct g*, struct g_str*);
g_vm(g_vm_gc, uintptr_t);
g_vm_t g_vm_kcall,
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
 g_vm_fputn,
 g_vm_fread, g_vm_strin;
uintptr_t hash(struct g*, word), g_vec_bytes(struct g_vec*);
#define vec(_) ((struct g_vec*)(_))
#define str(_) ((struct g_str*)(_))
#define tbl(_) ((struct g_tab*)(_))
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
static g_inline bool iop(word x) { return homp(x) && cell(x)->ap == g_vm_port_io; }

int memcmp(void const*, void const*, size_t);
void *malloc(size_t), free(void*),
 *memcpy(void*restrict, void const*restrict, size_t),
 *memmove(void*restrict, void const*restrict, size_t),
 *memset(void*, int, size_t);
long strtol(char const*restrict, char**restrict, int);
size_t strlen(char const*);
double strtod(char const *restrict, char **restrict);

// Boxed scalar float access. The payload lands in `shape[]` (which is
// typed uintptr_t), so a direct `*(g_flo_t*)` cast trips strict-aliasing.
// memcpy of a fixed small size compiles to a single load/store.
static g_inline g_flo_t flo_get(word x) {
 g_flo_t r; memcpy(&r, vec(x)->shape, sizeof r); return r; }
static g_inline void flo_put(void *p, g_flo_t v) {
 memcpy(p, &v, sizeof v); }

// equality comparisons inline the fast identity check
g_noinline bool eqv(struct g*, word, word); // this is for checking equality of non-identical values
static g_inline bool eql(struct g *f, word a, word b) { return a == b || eqv(f, a, b); }

static g_inline struct g_tag { union u *null, *head, end[]; } *ttag(union u *k) {
 while (k->x) k++;
 return (struct g_tag*) k; }

static g_inline union u *clip(union u *k) { return ttag(k)->head = k; }

static g_inline struct g *encode(struct g*f, enum g_status s) { return
  (struct g*) ((uintptr_t) f | s); }

static g_inline void *bump(struct g *f, uintptr_t n) {
  if (avail(f) < n) __builtin_trap();
  void *x = f->hp; f->hp += n; return x; }

static g_inline struct g_atom *ini_anon(struct g_atom *y, uintptr_t code) {
 return y->ap = g_vm_data, y->typ = sym_q, y->nom = 0, y->code = code, y; }

static g_inline struct g_atom *ini_sym(struct g_atom *y, struct g_str *nom, uintptr_t code) {
 return y->ap = g_vm_data, y->typ = sym_q, y->nom = nom, y->code = code, y->l = y->r = 0, y; }

struct g_str *ini_str(struct g_str *s, uintptr_t len);

static g_inline struct g_vec *ini_scalar(struct g_vec *v, enum g_vec_type t) {
 return v->ap = g_vm_data, v->typ = vec_q, v->type = t, v->rank = 0, v; }

static g_inline struct g_tab *ini_tab(struct g_tab *t, size_t len, size_t cap, struct g_kvs**tab) {
 return t->ap = g_vm_data, t->typ = tbl_q, t->len = len, t->cap = cap, t->tab = tab, t; }

static g_inline struct g_pair *ini_two(struct g_pair *w, intptr_t a, intptr_t b) {
 return w->ap = g_vm_data, w->typ = two_q, w->a = a, w->b = b, w; }

static g_inline uintptr_t rot(uintptr_t x) {
  int const s = sizeof(uintptr_t) * 4; // shift bits = word bits / 2 = sizeof(word) * 4
  return (x << s) | (x >> s); }

extern struct g_port_vt const synth[];

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
struct ti { struct g_io io; char const *t; word i; } ;

// Charlist-backed read-only port. `head` is a tagged pair pointer (or nil)
// into the gwen heap; getc walks the spine by tail-replacing it. The port
// itself lives on the gwen heap so the GC traces `head` as a regular thread
// slot (evac_thd walks every word up to the ttag).
struct ci { struct g_io io; g_word head; };

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
static g_inline void *off_pool(struct g *f) {
 return f == f->pool ? (word*) f->pool + f->len : (word*) f->pool; }
static g_inline struct g *pushl(struct g*f) { return intern(g_strof(f, "\\")); }
static g_inline struct g *pushq(struct g*f) { return intern(g_strof(f, "`")); }
static g_inline struct g *push0(struct g*f) { return g_push(f, 1, nil); }
static g_inline size_t llen(word l) {
 size_t n = 0;
 while (twop(l)) n++, l = B(l);
 return n; }
word g_tget(struct g*, word, word, struct g_tab*);

static g_inline struct g *gtrap(struct g*f) { return g_core_of(f)->trap(f); }

#endif
