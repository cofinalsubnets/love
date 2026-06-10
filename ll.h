#ifndef _gwen_h
#define _gwen_h
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdarg.h>

#define Width(_) b2w(sizeof(_))
#define g_core_of(g) ((struct g*)((intptr_t)(g)&~(sizeof(intptr_t)-1)))
#define g_code_of(g) ((enum g_status)((intptr_t)(g)&(sizeof(intptr_t)-1)))
#define g_ok(g) (g_code_of(g) == g_status_ok)

#define putfix(_) ((g_word)(((uintptr_t)(g_word)(_)<<1)|1))
#define getfix(_) ((g_word)(_)>>1)

#ifndef EOF
#define EOF (-1)
#endif

#ifndef NAN
#define NAN (__builtin_nanf(""))
#endif

#define g_nil putfix(0)
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
#define _g_vm(n, ...) struct g *n(struct g *restrict g, union u *Ip, g_word *Hp, g_word *restrict Sp, ##__VA_ARGS__)
#define Ap(fn, g, ...) fn(g, Ip, Hp, Sp, ##__VA_ARGS__)
#define Continue() Ap(Ip->ap, g)
#define Pack(g) (g->ip = Ip, g->hp = Hp, g->sp = Sp)
#define Unpack(g) (Ip = g->ip, Hp = g->hp, Sp = g->sp)
#else
#define _g_vm(n, ...) struct g *n(struct g *restrict g, ##__VA_ARGS__)
#define Ap(fn, g, ...) fn(g, ##__VA_ARGS__)
#define Continue() g
#define Hp g->hp
#define Sp g->sp
#define Ip g->ip
#define Pack(g) ((void)0)
#define Unpack(g) ((void)0)
#endif
#define g_vm(...) g_noinline g_noicf _g_vm(__VA_ARGS__)

// ok thanks
typedef intptr_t g_word;

union u;
typedef _g_vm(g_vm_t);

// Typed N-dim array. Rank 0 = scalar (no shape words); payload at
// (void*)(shape + rank). Immutable.
struct g_tuple {
 g_vm_t *ap;
 uintptr_t type, rank, shape[]; };

// Status rides the 2 pointer tag bits, read as two flags: bit 0 is the SCARE
// bit (something is wrong -- the thrower puts the relevant data on struct g for
// the trap function to read; the bare scare is oom, which has no room to say
// more), bit 1 is the MORE bit (read control flow: more input is wanted).
// more alone = incomplete; eof = more|scare -- the end is the scary case of
// wanting more.
enum g_status { g_status_ok = 0, g_status_scare = 1, g_status_more = 2, g_status_eof = 3 };
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
    g_word ungetc_buf;            // pushed-back byte; putfix(EOF) = empty
    g_word eof_seen; } *io; };
  // rng: global RNG state (rank-1 i64 tuple, len 4, xoshiro256++). Lives in &v0..end
  // so gc.c's root loop forwards it.
  g_word rng;
  // Pre-interned dict keys for the hot/warm C->lisp hooks: num-ap, scomb,
  // bcomb (per-apply) and the reader's operator table (per-token). The values
  // live on dict (GC-traced, egg-baked; no cache slots), resolved per use;
  // keys interned at init so lookups never allocate. In v0..end so the gc root
  // loop forwards them. The cold trap key has no slot: gtrap2 probes the
  // symbol tree by name (sym_probe).
  g_word numap_sym, scomb_sym, bcomb_sym, operators_sym; }; };
 intptr_t end[]; };

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
struct g *g_io_alloc(struct g *g, int fd);

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

// Bootstrap driver (was tools/mkboot.l, now a compile-time C constructor). The
// lib/ headers are bare C string literals (lcat output), so a frontend builds
// the egg + double-bake bootstrap by juxtaposing them between these macros:
//
//   g_evals_(g, "("
//   #include "egg.h"          // (\ egg (: ...)) -- the boot driver, lcat'd
//     G_EGG_PRE
//   #include "prelude.h"
//     " "
//   #include "ev.h"
//     G_EGG_POST
//   #include "repl.h"          // optional: REPL, compiled by the installed ev
//   );
//
// This applies the egg driver (ll/egg.l) to the quoted corpus, i.e.
// ((\ egg (: ...)) '(<prelude forms> <ev forms>)): it compiles the ll
// compiler with c0, recompiles the whole corpus through itself (exercising
// wev), and installs that as `ev`. Adjacent string-literal concatenation does
// all the work at compile time -- no runtime allocation, freestanding-safe.
#define G_EGG_PRE " '("
#define G_EGG_POST ")) "

// === internal API shared with data.c / host / free (merged from former i.h) ===
#define G_WAIT_FDS_MAX 8
#define A(o) two(o)->a
#define B(o) two(o)->b
#define len(_) (((struct g_str*)(_))->len)
#define txt(_) (((struct g_str*)(_))->bytes)
#define avail(g) ((uintptr_t)(g->sp-g->hp))
#define num(_) ((word)(_))
#define word(_) num(_)
#define oddp(_) ((uintptr_t)(_)&1)
#define evenp(_) !oddp(_)
#define cell(_) ((union u*)(_))
#define Have1() if (Sp == Hp) return Ap(g_vm_gc, g, 1)
#define Have(n) if (Sp < Hp + n) return Ap(g_vm_gc, g, n)
#define g_pop1(g) (*(g)->sp++)
#define op(nom, n, x) g_vm(nom) { intptr_t _ = (x); *(Sp += n-1) = _; Ip++; return Continue(); }
#define nil g_nil
struct g_pair { g_vm_t *ap; intptr_t a, b; };
// The fundamental value kind for generic-op dispatch (enum q). KFix is the odd fixnum
// tag; KLam is any non-data heap pointer (thread/function/map). The five DATA kinds
// (KTuple, KBig, KString, KSym, KTwo) are the ones g_typ recovers from an ap's section
// slot (data.c go() order, via the data.h lookup); an array reads as KTuple there
// (coarse -- one array sentinel). The four KArr* kinds are NOT data sentinels: g_kind
// alone mints them, expanding a rank>=1 tuple by its element tier (KArrZ + g_tuple_type)
// so the array tower Z/R/C/O dispatches inline with the scalar tower it mirrors
// (KArrZ~fix, KArrR~float, KArrC~complex, KArrO~big). The diagonal is the type lattice
// by semantics then representation: arithmetic lane [KFix..KArrO] (scalars then their
// array counterparts), sequence/concat lane [KString..KTwo], thread last -- so each
// dyadic lane is one contiguous range, `max` is the within-lane promotion join, and the
// lone undefined seam (arith <-> seq) is the KArrO|KString boundary. two (pair) caps the
// sequence lane just under KLam (a pair is its own Church eliminator -- the most
// lambda-like datum). KN is the matrix dimension.
enum q { KFix, KTuple, KBig, KArrZ, KArrR, KArrC, KArrO, KString, KSym, KTwo, KLam, KN };
#define G_DATA_N 5     // # of data sentinels (data.c go()); the KArr* kinds interleave, so no longer KLam-KTuple
typedef g_word num, word;
// The unique empty string and empty (anonymous) symbol -- data-segment globals the
// GC never moves (gcp's out-of-pool short-circuit). Strings are immutable, so one
// empty string suffices and zero-length ones are never heap-allocated; g_sym_empty
// is the additive identity for `+` on symbols. See ll.c for the rationale.
extern const struct g_str g_str_empty;
extern const struct g_atom g_sym_empty;
#define EmptyString ((word) &g_str_empty)
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
// g_kind maps any value to its enum q: KFix for a fixnum, KLam for a non-data heap
// pointer (thread/function/map), else g_typ's data kind -- refined for a rank>=1 tuple,
// which expands by element tier to KArrZ..KArrO (a rank-0 box stays KTuple). Lives in
// ll.c (it needs g_typ from the generated data.h) and is shared by data.c's apply
// sentinels. Both the `+`/`*` matrices and the apply matrix dispatch on this.
enum q g_kind(word);
// Apply dispatch matrix, indexed [static: the applied data kind, g_typ(Ip)][dynamic:
// the argument kind, g_kind(Sp[0])]. The data sentinels (data.c) tail-jump through
// it; the handlers + the table itself live in ll.c. Row indexed by the full kind
// (g_typ returns one of the five data kinds), so the first dimension is KN, not G_DATA_N.
extern g_vm_t *g_apply_mx[KN][KN];
extern union u const numap_drive[];          // [ap; swap; ret0] driver that runs (num-ap n x); shared by fixnum + data num apply
g_vm_t g_vm_ap, g_vm_two, g_vm_tuple, g_vm_sym, g_vm_str, g_vm_big; // sentinels + ap: data.c & inline predicates
uintptr_t hash(struct g*, word), g_tuple_bytes(struct g_tuple*);
#define str(_) ((struct g_str*)(_))
#define lamp evenp
#define two(_) ((struct g_pair*)(_))
static g_inline bool twop(word _) { return lamp(_) && cell(_)->ap == g_vm_two; }
static g_inline void *bump(struct g *g, uintptr_t n) {
  if (avail(g) < n) __builtin_trap();
  void *x = g->hp; g->hp += n; return x; }
static g_inline struct g_pair *ini_two(struct g_pair *w, intptr_t a, intptr_t b) {
 return w->ap = g_vm_two, w->a = a, w->b = b, w; }
static g_inline struct g *encode(struct g*g, enum g_status s) { return
  (struct g*) ((uintptr_t) g | s); }
// Throw: to the global `trap` function when installed, else throw_c (ll.c).
// gtrap re-throws an already-tagged g's own status.
struct g *gtrap2(struct g*, enum g_status), *gtrap(struct g*);
static g_inline struct g *g_have(struct g *g, uintptr_t n) {
 return !g_ok(g) || avail(g) >= n ? g : g_please(g, n); }

#endif
