#ifndef _gwen_h
#define _gwen_h
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdarg.h>

#define Width(_) b2w(sizeof(_))
#define g_width Width
#define g_core_of(f) ((struct g*)((intptr_t)(f)&~(sizeof(intptr_t)-1)))
#define g_code_of(f) ((enum g_status)((intptr_t)(f)&(sizeof(intptr_t)-1)))
#define g_ok(f) (g_code_of(f) == g_status_ok)

#define g_putnum(_) ((g_word)(((uintptr_t)(g_word)(_)<<1)|1))
#define g_getnum(_) ((g_word)(_)>>1)

#ifndef EOF
#define EOF (-1)
#endif

#ifndef NAN
#define NAN (__builtin_nanf(""))
#endif

#define g_nil g_putnum(0)
#define g_inline inline __attribute__((always_inline))
#define g_noinline __attribute__((noinline))
// Keep a function from being identical-code-folded with another. The data
// self-quote sentinels (flow.c) have byte-identical bodies but must keep
// distinct addresses, since their address *is* their type tag. GCC -Os runs
// -fipa-icf, which noipa disables; clang/lld only fold under an explicit
// --icf=all, which no build passes.
#if defined(__GNUC__) && !defined(__clang__)
#define g_noicf __attribute__((noipa))
#else
#define g_noicf
#endif
#define g_digits "0123456789abcdefghijklmnopqrstuvwxyz"
#define LEN(_) (sizeof(_)/sizeof(*_))

#ifndef g_tco
#define g_tco 1
#endif

#if g_tco
#define _g_vm(n, ...) struct g *n(struct g *restrict f, union u *Ip, g_word *Hp, g_word *restrict Sp, ##__VA_ARGS__)
#define Ap(g, f, ...) g(f, Ip, Hp, Sp, ##__VA_ARGS__)
#define Continue() Ap(Ip->ap, f)
#define Pack(f) (f->ip = Ip, f->hp = Hp, f->sp = Sp)
#define Unpack(f) (Ip = f->ip, Hp = f->hp, Sp = f->sp)
#else
#define _g_vm(n, ...) struct g *n(struct g *restrict f, ##__VA_ARGS__)
#define Ap(g, f, ...) g(f, ##__VA_ARGS__)
#define Continue() f
#define Hp f->hp
#define Sp f->sp
#define Ip f->ip
#define Pack(f) ((void)0)
#define Unpack(f) ((void)0)
#endif
#define g_vm(...) g_noinline g_noicf _g_vm(__VA_ARGS__)

// ok thanks
typedef intptr_t g_word;

union u;
typedef _g_vm(g_vm_t);

// Typed N-dim array. Rank 0 = scalar (no shape words); payload at
// (void*)(shape + rank). Immutable.
struct g_vec {
 g_vm_t *ap;
 uintptr_t type, rank, shape[]; };

enum g_status { g_status_ok = 0, g_status_oom = 1, g_status_eof = 2, g_status_more = 3 };
struct g {
 union u {
  g_vm_t *ap;
  g_word x;
  union u *m; } *ip;
 g_word *hp, *sp;
 union u *tasks;       // task ring head (running task's node); always non-NULL after g_ini
 uintptr_t yield_ctr,  // ap-cycles since last cooperative yield; counts up to YIELD_INTERVAL (level-triggered)
           next_pid,   // monotonic pid counter; pre-incremented, so first spawn returns 1
           next_wake_at; // raw deadline for next yield_sw snapshot's wake_at slot; 0 = always runnable
 intptr_t next_wait_fd; // fd the task suspended on, -1 = not waiting on I/O. Installed into next yield_sw snapshot's wait_fd slot.
 struct g_atom {
  g_vm_t *ap;
  uintptr_t code;
  struct g_str {
   g_vm_t *ap;
   uintptr_t len;       // byte count
   char bytes[]; } *nom;
  struct g_atom *l, *r; } *symbols;
 uintptr_t len;
 struct g *pool;
 struct g_r { g_word *x; struct g_r *n; } *root; // gc roots list
 struct g_fz { // finalizers
  union u *p;
  void (*fn)(void *);
  struct g_fz *next; } *fz;
 union { uintptr_t t0; g_word *cp; };
 void *(*malloc)(struct g*, size_t),
      (*free)(struct g*, void*);
 union u *k; // current continuation: a thread thrown to on error (default throw_c, installed by g_ini_0)
 uintptr_t b;
 uintptr_t n_gc, max_len, max_heap; // gc instrumentation (cycles, peak pool len, peak live heap; words)
 union {
  intptr_t v0;
  struct {
   g_word dict;   // global env map (lookup-lambda); GC-forwarded in v0..end. The
                  // macro table is dict[nil] -- no separate field.
  union {
   g_word x;
   struct g_io {
    g_vm_t *ap;
    g_word fd;
    g_word ungetc_buf;            // pushed-back byte; putnum(EOF) = empty
    g_word eof_seen; } *io; };
  // rng: global RNG state (rank-1 i64 vec, len 4, xoshiro256++). Lives in &v0..end
  // so gc.c's root loop forwards it.
  g_word rng; }; };
 intptr_t end[]; };

// numap: gwen handler for fixnum-as-function application ((n x) -> (num-ap n x)),
// installed once by the `set-numap` bif from prelude.g. The same handler serves every
// interpreter, so it is a singleton global rather than a `struct g` field. It points at
// a heap thread, so gcg() (gc.c) forwards it each collection.
extern g_word g_numap;

struct g_def { char const *n; intptr_t x; };

// Port vtable. One shape covers both directions; unused slots in a given
// port get noop_* stubs (defined in g.c) so dispatch needs no NULL guards.
struct g_port_vt {
 struct g*(*getc)(struct g*),
         *(*ungetc)(struct g*, int),
         *(*eof)(struct g*),
         *(*putc)(struct g*, int),
         *(*flush)(struct g*); };

// only 2 tag bits on 32 bit so we can only have four of these
enum g_status g_fin(struct g*);

static g_inline size_t b2w(size_t b) {
 size_t q = b / sizeof(g_word), r = b % sizeof(g_word);
 return q + (r ? 1 : 0); }

g_vm_t g_vm_ret0, g_vm_cur, g_vm_port_io;

// Frontend-provided vtable for ports backed by real OS file descriptors.
// Used whenever fd >= 0. Synthetic ports (fd <= -1) route through the
// shared synth table inside g.c instead.
extern struct g_port_vt const g_fd_port_vt;

// Frontend hook to close an OS file descriptor backing a heap port. Weak
// default in g.c is a no-op so kernel/pd/lcat link without having to care;
// the host overrides with close(2). Called by the finalizer that g_io_alloc
// installs, so it runs when a heap port becomes unreachable.
void g_fd_close(int fd);

// Heap-allocate a port for the given OS fd. Bumps Width(struct g_io) +
// ttag, fills ap/fd/ungetc_buf/eof_seen, pushes the port pointer on Sp[0],
// and registers a finalizer that calls g_fd_close(fd) when the port is
// collected. fd is stored as a plain integer at the C layer and tagged on
// the way in.
struct g *g_io_alloc(struct g *f, int fd);

uintptr_t g_clock(void); // used by garbage collector
void g_sleep(uintptr_t ticks); // per-frontend deep wait for at most `ticks`
// g_clock() units (ticks=0 means infinite). No input wakeup; the scheduler
// dispatches to g_wait_fds when tasks are parked on streams. Default = no-op.

struct g
 *g_ini(void),
 *g_ini_m(void*(*)(struct g*, size_t), void(*)(struct g*,void*)),
 *g_ini_s(void*, uintptr_t),
 *g_evals_(struct g*, const char*),
 *g_defn(struct g*, struct g_def const*, uintptr_t);

extern struct g_io g_stdin, g_stdout, g_stderr;

// Bootstrap driver (was tools/mkboot.g, now a compile-time C constructor). The
// lib/ headers are bare C string literals (lcat output), so a frontend builds
// the egg + double-bake bootstrap by juxtaposing them between these macros:
//
//   g_evals_(f, "("
//   #include "egg.h"          // (\ egg (: ...)) -- the boot driver, lcat'd
//     G_EGG_PRE
//   #include "prelude.h"
//     " "
//   #include "ev.h"
//     G_EGG_POST
//   #include "repl.h"          // optional: REPL, compiled by the installed ev
//   );
//
// This applies the egg driver (gwen/egg.g) to the quoted corpus, i.e.
// ((\ egg (: ...)) '(<prelude forms> <ev forms>)): it compiles the gwen
// compiler with c0, recompiles the whole corpus through itself (exercising
// wev), and installs that as `ev`. Adjacent string-literal concatenation does
// all the work at compile time -- no runtime allocation, freestanding-safe.
#define G_EGG_PRE " '("
#define G_EGG_POST ")) "

// === internal API shared with vt.c / host / free (merged from former i.h) ===
#define G_WAIT_FDS_MAX 8
#define A(o) two(o)->a
#define B(o) two(o)->b
#define len(_) (((struct g_str*)(_))->len)
#define txt(_) (((struct g_str*)(_))->bytes)
#define avail(f) ((uintptr_t)(f->sp-f->hp))
#define num(_) ((word)(_))
#define word(_) num(_)
#define oddp(_) ((uintptr_t)(_)&1)
#define evenp(_) !oddp(_)
#define cell(_) ((union u*)(_))
#define Have1() if (Sp == Hp) return Ap(g_vm_gc, f, 1)
#define Have(n) if (Sp < Hp + n) return Ap(g_vm_gc, f, n)
#define g_pop1(f) (*(f)->sp++)
#define op(nom, n, x) g_vm(nom) { intptr_t _ = (x); *(Sp += n-1) = _; Ip++; return Continue(); }
#define nil g_nil
struct g_pair { g_vm_t *ap; intptr_t a, b; };
// Data-sentinel kinds. Ordered so that, with K_FIX prepended and K_LAM appended,
// they form `enum kind` by a bare +K_VEC shift (see g_kind) and group the dispatch
// matrices' diagonals by lane: numbers (vec/big), sequences (two/text/sym).
// The section map in vt.c (go()) and vt.ld pin sentinel <-> slot to match.
enum q { vec_q, big_q, two_q, text_q, sym_q, };
#define G_DATA_VT_N 5
typedef g_word num, word;
// The unique empty string and empty (anonymous) symbol -- data-segment globals the
// GC never moves (gcp's out-of-pool short-circuit). Strings are immutable, so one
// empty string suffices and zero-length ones are never heap-allocated; g_sym_empty
// is the additive identity for `+` on symbols. See gwen.c for the rationale.
extern const struct g_str g_str_empty;
extern const struct g_atom g_sym_empty;
#define EMPTY_STR ((word) &g_str_empty)
#define EMPTY_SYM ((word) &g_sym_empty)
void g_wait_fds(int const *fds, int n, uintptr_t ticks);
bool g_ready(int fd), g_strp(g_word);
struct g
 *g_please(struct g*, uintptr_t),
 *g_push(struct g*, uintptr_t, ...),
 *g_strof(struct g*, const char*),
 *gxl(struct g*),
 *gxr(struct g*),
 *intern(struct g*),
 *g_reads(struct g*, struct g_io*),
 *g_read1(struct g*, struct g_io*),
 *str0(struct g*, uintptr_t);
g_vm(g_vm_gc, uintptr_t);
// Generic-op dispatch kind: the fundamental value kind by pure arithmetic on the
// data-sentinel index g_typ with a fixnum (K_FIX) prepended and a thread/function
// (K_LAM) appended -- so K_VEC..K_SYM are exactly enum q + K_VEC (enum q is ordered
// to make this a bare shift; see gwen.h's enum q). NO subtype classification (interned
// vs uninterned sym, box vs array) at this level -- the handler's job. The order
// groups the matrix diagonals by lane: numbers (fix/vec/big), sequences (two/text/
// sym), then thread last (its row+column a uniform precedence band; maps are threads).
// Both the `+`/`*` matrices and the apply matrix dispatch on this; g_kind lives in
// gwen.c (it needs g_typ from the generated vt.h) and is used by vt.c's sentinels.
enum kind { K_FIX, K_VEC, K_BIG, K_TWO, K_TEXT, K_SYM, K_LAM, K_N };
enum kind g_kind(word);
// Apply dispatch matrix, indexed [static: the applied data kind, g_typ(Ip)][dynamic:
// the argument kind, g_kind(Sp[0])]. The data_vt sentinels (vt.c) tail-jump through
// it; the handlers + the table itself live in gwen.c.
extern g_vm_t *g_apply_mx[G_DATA_VT_N][K_N];
extern g_word g_numap;                 // gwen num-ap handler (vm.c); the numeral-apply driver below targets it
extern g_word g_scomb, g_bcomb;        // `+`/`*` thread combinators (S / compose), installed from the prelude
extern union u numap_drive[];          // [ap; swap; ret0] driver that runs (num-ap n x); shared by fixnum + data num apply
g_vm_t g_vm_ap, g_vm_two, g_vm_vec, g_vm_sym, g_vm_text, g_vm_big; // sentinels + ap: vt.c & inline predicates
uintptr_t hash(struct g*, word), g_vec_bytes(struct g_vec*);
#define str(_) ((struct g_str*)(_))
#define homp evenp
#define two(_) ((struct g_pair*)(_))
static g_inline bool twop(word _) { return homp(_) && cell(_)->ap == g_vm_two; }
static g_inline void *bump(struct g *f, uintptr_t n) {
  if (avail(f) < n) __builtin_trap();
  void *x = f->hp; f->hp += n; return x; }
static g_inline struct g_pair *ini_two(struct g_pair *w, intptr_t a, intptr_t b) {
 return w->ap = g_vm_two, w->a = a, w->b = b, w; }
static g_inline struct g *encode(struct g*f, enum g_status s) { return
  (struct g*) ((uintptr_t) f | s); }
// Throw status s: transfer control to the continuation installed at f->k,
// carrying s encoded into the f handed to it. The default k (throw_c, set in
// g_ini_0) immediately yields that back to the C driver -- same escape the old
// trap did; installing a gwen thread at f->k would instead land throws in gwen.
static g_inline struct g *gtrap2(struct g*f, enum g_status s) {
 struct g *c = g_core_of(f);
 c->ip = c->k;                                  // resume at the continuation
#if g_tco
 return c->k->ap(encode(c, s), c->k, c->hp, c->sp);
#else
 return c->k->ap(encode(c, s));
#endif
}
// Throw on an already-tagged f: re-throw its own status to f->k.
static g_inline struct g *gtrap(struct g*f) { return gtrap2(g_core_of(f), g_code_of(f)); }
static g_inline struct g *g_have(struct g *f, uintptr_t n) {
 return !g_ok(f) || avail(f) >= n ? f : g_please(f, n); }

#endif
