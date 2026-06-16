#ifndef _ai_h
#define _ai_h
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdarg.h>

#define Width(_) b2w(sizeof(_))
#define ai_core_of(ai_) ((struct ai*)((intptr_t)(ai_)&~(sizeof(intptr_t)-1)))
#define ai_code_of(g) ((enum ai_status)((intptr_t)(g)&(sizeof(intptr_t)-1)))
#define ai_ok(g) (ai_code_of(g) == ai_status_ok)

#define putfix(_) ((ai_word)(((uintptr_t)(ai_word)(_)<<1)|1))
#define getfix(_) ((ai_word)(_)>>1)

#ifndef EOF
#define EOF (-1)
#endif

#ifndef NAN
#define NAN (__builtin_nanf(""))
#endif

#define ai_nil putfix(0)
#define ai_inline inline __attribute__((always_inline))
#define ai_noinline __attribute__((noinline))
// Keep a function from being identical-code-folded with another. The data
// self-quote sentinels (flow.c) have byte-identical bodies but must keep
// distinct addresses, since their address *is* their type tag. GCC -Os runs
// -fipa-icf, which noipa disables; clang/lld only fold under an explicit
// --icf=all, which no build passes.
#if defined(__GNUC__) && !defined(__clang__)
#define ai_noicf __attribute__((noipa))
#else
#define ai_noicf
#endif
#define ai_digits "0123456789abcdefghijklmnopqrstuvwxyz"
#define countof(_) (sizeof(_)/sizeof(*_))

#ifndef ai_tco
#define ai_tco 1
#endif

#if ai_tco
#define _lvm(n, ...) struct ai *n(struct ai *restrict g, union u *Ip, ai_word *Hp, ai_word *restrict Sp, ##__VA_ARGS__)
#define Ap(fn, g, ...) fn(g, Ip, Hp, Sp, ##__VA_ARGS__)
#define Continue() Ap(Ip->ap, g)
#define Pack(g) (g->ip = Ip, g->hp = Hp, g->sp = Sp)
#define Unpack(g) (Ip = g->ip, Hp = g->hp, Sp = g->sp)
#else
#define _lvm(n, ...) struct ai *n(struct ai *restrict g, ##__VA_ARGS__)
#define Ap(fn, g, ...) fn(g, ##__VA_ARGS__)
#define Continue() g
#define Hp g->hp
#define Sp g->sp
#define Ip g->ip
#define Pack(g) ((void)0)
#define Unpack(g) ((void)0)
#endif
#define lvm(...) ai_noinline ai_noicf _lvm(__VA_ARGS__)

// ok thanks
typedef intptr_t ai_word;

union u;
typedef _lvm(lvm_t);

// Typed N-dim array. Rank 0 = scalar (no shape words); payload at
// (void*)(shape + rank). Immutable.
struct ai_tuple {
 lvm_t *ap;
 uintptr_t type, rank, shape[]; };

// Status rides the 2 pointer tag bits, read as two flags: bit 0 is the SCARE
// bit (something is wrong -- the raise site puts the relevant data on struct ai for
// the help function to read; the bare scare is oom, which has no room to say
// more), bit 1 is the MORE bit (read control flow: more input is wanted).
// more alone = incomplete; eof = more|scare -- the end is the scary case of
// wanting more.
enum ai_status { ai_status_ok = 0, ai_status_scare = 1, ai_status_more = 2, ai_status_eof = 3 };

// the atom: ap, the code (an interned symbol's name hash / a mint's serial),
// the nom (a string = interned; 0 = a mint). UNIFORM 3 words -- the l/r
// intern-tree slots died with the tree: interning lives in struct ai's
// `symbols`, a weak map from name string to the canonical atom.
struct ai_atom {
 lvm_t *ap;
 uintptr_t code;
 struct ai_str {
  lvm_t *ap;
  uintptr_t len;        // byte count
  char bytes[]; } *nom; };

struct ai {
 // () IS the core: its FIRST WORD is an ap (lvm_sym, set in ai_ini), enough to make
 // (word) ai_core_of(g) a value -- symp, applies const-1 (data_sym_apply ignores nom),
 // prints (). The one true nothing, distinct from 0 (a fixnum) and "" (a string). A
 // mint's code/nom would both be 0 here, so there is NOTHING to read -- the only path
 // that would (order) identity-checks the core instead. The dust specializes on the
 // unique core: gcg leaves a forwarding pointer in this ap word so every stored () follows.
 lvm_t *ap;
 union u {
  lvm_t *ap;
  ai_word x;
  union u *m; } *ip;
 ai_word *hp, *sp;
 union u *tasks;       // task ring head (running task's node); always non-NULL after ai_ini
 uintptr_t yield_ctr,  // ap-cycles since last cooperative yield; counts up to yield_interval (level-triggered)
           next_serial, // THE MINT STREAM: one monotonic counter every fresh identity draws
                        // from -- task pids and nom serials alike (pre-incremented).
                        // a nom's serial lands in its `code` slot: its
                        // hash AND its order tiebreak -- same-name noms order by creation,
                        // GC-stable (code rides the copy), closing trichotomy.
           next_wake_at; // raw deadline for next yield_sw snapshot's wake_at slot; 0 = always runnable
 intptr_t next_wait_fd; // fd the task suspended on, -1 = not waiting on I/O. Installed into next yield_sw snapshot's wait_fd slot.
 ai_word symbols;        // the WEAK intern map (string -> the canonical atom; see struct ai_atom
                        // above): value-keyed by string content; gcg clones it untraced and
                        // sweeps it after the cheney fixpoint, so a dead atom's entry drops --
                        // dead spellings vanish. 0 only during early init.
 uintptr_t len;
 struct ai *pool;
 struct ai_r { ai_word *x; struct ai_r *n; } *root; // gc roots list
 struct ai_fz { // finalizers
  union u *p;
  void (*fn)(void *);
  struct ai_fz *next; } *fz;
 union { uintptr_t t0; ai_word *cp; };
 void *(*alloc)(struct ai*, void*, size_t);  // alloc(g,p,n): n>0 reserve n bytes (p ignored), n==0 free p; -> block or NULL
 uintptr_t b;
#ifdef AI_STAT
 uintptr_t n_gc, max_len, max_heap; // gc instrumentation (cycles, peak pool len, peak live heap; words) -- build -DAI_STAT to keep them; off, the core is 3 words leaner and gauge reports 0 for them
#endif
 union {
  intptr_t v0;
  struct {
   ai_word book;   // global env map (lookup-lambda); GC-forwarded in v0..end. The
                  // macro table is book[nil] -- no separate field. The 'missing
                  // condition tag needs no slot: it is the `missing` nif's name,
                  // so the book roots it, and the raise path reads it back with
                  // sym_probe (alloc-free, already on that path for `help`).
   ai_word scare_a, scare_b; // the last bare scare's condition data, stashed at
                  // the raise so a terminal exit can speak (ai_scare_face_);
                  // nil nil = the bare oom, which has no data. GC-traced here.
  union {
   ai_word x;
   struct ai_io {
    lvm_t *ap;
    ai_word fd;
    ai_word ungetc_buf;            // pushed-back byte; putfix(EOF) = empty
    ai_word eof_seen; } *io; };
  // The C->lisp hooks (num-ap, add, mul, help, operators) live on book
  // (GC-traced, egg-baked): no slots, no key caches -- C materializes the
  // keys by name per use (sym_probe walks the intern map allocation-free;
  // hot numeric code is compiled by the lisp compiler, which holds the
  // symbols directly, so the C dispatch only catches stragglers).
  }; };
 intptr_t end[]; };

struct ai_def { char const *n; intptr_t x; };

// Port vtable. One shape covers both directions; unused slots in a given
// port get noop_* stubs (defined in g.c) so dispatch needs no NULL guards.
struct ai_port_vt {
 struct ai*(*getc)(struct ai*),
         *(*ungetc)(struct ai*, int),
         *(*eof)(struct ai*),
         *(*putc)(struct ai*, int),
         *(*flush)(struct ai*); };

// only 2 tag bits on 32 bit so we can only have four of these
enum ai_status ai_fin(struct ai*);

static ai_inline size_t b2w(size_t b) {
 size_t q = b / sizeof(ai_word), r = b % sizeof(ai_word);
 return q + (r ? 1 : 0); }

lvm_t lvm_ret0, lvm_cur, lvm_port_io, lvm_help;

// Frontend-provided vtable for ports backed by real OS file descriptors.
// Used whenever fd >= 0. Synthetic ports (fd <= -1) route through the
// shared synth table inside g.c instead.
extern struct ai_port_vt const ai_fd_port_vt;

// Frontend hook to close an OS file descriptor backing a heap port. Weak
// default in g.c is a no-op so kernel/pd/lcat link without having to care;
// the host overrides with close(2). Called by the finalizer that ai_io_alloc
// installs, so it runs when a heap port becomes unreachable.
void ai_fd_close(int fd);

// Heap-allocate a port for the given OS fd. Bumps Width(struct ai_io) +
// ttag, fills ap/fd/ungetc_buf/eof_seen, pushes the port pointer on Sp[0],
// and registers a finalizer that calls ai_fd_close(fd) when the port is
// collected. fd is stored as a plain integer at the C layer and tagged on
// the way in.
struct ai *ai_io_alloc(struct ai *g, int fd);

uintptr_t ai_clock(void); // used by garbage collector
void ai_sleep(uintptr_t ticks); // per-frontend deep wait for at most `ticks`
// ai_clock() units (ticks=0 means infinite). No input wakeup; the scheduler
// dispatches to ai_wait_fds when tasks are parked on streams. Default = no-op.

struct ai
 *ai_ini(void),
 *ai_ini_m(void*(*)(struct ai*, void*, size_t)),
 *ai_ini_s(void*, uintptr_t),
 *ai_evals_(struct ai*, const char*),
 *ai_defn(struct ai*, struct ai_def const*, uintptr_t);

// the terminal scare face: print ";; a b\n" (show forms) to the err port from
// the stashed condition data and answer 1; the bare scare (nil nil -- oom,
// which has no data) answers 0 so the frontend can report it raw.
int ai_scare_face_(struct ai*);

extern struct ai_io ai_stdin, ai_stdout, ai_stderr;

// Bootstrap driver (was tools/mkboot.l, now a compile-time C constructor). The
// lib/ headers are bare C string literals (lcat output), so a frontend builds
// the egg + double-bake bootstrap by juxtaposing them between these macros:
//
//   ai_evals_(g, "("
//   #include "egg.h"          // (\ egg (: ...)) -- the boot driver, lcat'd
//     ai_egg_pre
//   #include "prel.h"
//     " "
//   #include "ev.h"
//     ai_egg_post
//   #include "repl.h"          // optional: REPL, compiled by the installed ev
//   );
//
// This applies the egg driver (l/egg.l) to the quoted corpus, i.e.
// ((\ egg (: ...)) '(<prel forms> <ev forms>)): it compiles the l
// compiler with c0, recompiles the whole corpus through itself (exercising
// wev), and installs that as `ev`. Adjacent string-literal concatenation does
// all the work at compile time -- no runtime allocation, freestanding-safe.
#define ai_egg_pre " '("
#define ai_egg_post ")) "

// === internal API shared with data.c / host / free (merged from former i.h) ===
#define ai_wait_fds_max 8
#define A(o) two(o)->a
#define B(o) two(o)->b
#define len(_) (((struct ai_str*)(_))->len)
#define txt(_) (((struct ai_str*)(_))->bytes)
#define avail(g) ((uintptr_t)(g->sp-g->hp))
#define num(_) ((word)(_))
#define word(_) num(_)
#define oddp(_) ((uintptr_t)(_)&1)
#define evenp(_) !oddp(_)
#define cell(_) ((union u*)(_))
#define Have1() if (Sp == Hp) return Ap(lvm_gc, g, 1)
#define Have(n) if (Sp < Hp + n) return Ap(lvm_gc, g, n)
#define ai_pop1(g) (*(g)->sp++)
#define op(nom, n, x) lvm(nom) { intptr_t _ = (x); *(Sp += n-1) = _; Ip++; return Continue(); }
#define nil ai_nil
struct ai_pair { lvm_t *ap; intptr_t a, b; };
// The fundamental value kind for generic-op dispatch (enum q). KFix is the odd fixnum
// tag; KHom is any non-data heap pointer (text/function/map). The five DATA kinds
// (KTuple, KBig, KString, KSym, KTwo) are the ones ai_typ recovers from an ap's section
// slot (data.c go() order, via the data.h lookup); an array reads as KTuple there
// (coarse -- one array sentinel). The four KArr* kinds are NOT data sentinels: ai_kind
// alone mints them, expanding a rank>=1 tuple by its element tier (KArrZ + ai_tuple_type)
// so the array tower Z/R/C/O dispatches inline with the scalar tower it mirrors
// (KArrZ~fix, KArrR~float, KArrC~complex, KArrO~big). The diagonal is the type lattice
// by semantics then representation: arithmetic lane [KFix..KArrO] (scalars then their
// array counterparts), sequence/concat lane [KString..KTwo], then map, text last --
// so each dyadic lane is one contiguous range, `max` is the within-lane promotion join,
// and the lone undefined seam (arith <-> seq) is the KArrO|KString boundary. two (pair)
// caps the sequence lane; KMap is the map's own rung just under KHom, so the total
// order's pair < map < lambda is the enum order itself (a map is still a lookup lambda
// for +/*/apply -- the rung exists for the order and the honest matrix cells).
// KN is the matrix dimension.
enum q { KFix, KTuple, KBig, KArrZ, KArrR, KArrC, KArrO, KString, KSym, KTwo, KMap, KHom, KN };
#define ai_data_n 5     // # of data sentinels (data.c go()); the KArr* kinds interleave, so no longer KHom-KTuple
typedef ai_word num, word;
// The unique empty string -- a data-segment global the GC never moves (gcp's
// out-of-pool short-circuit). Strings are immutable, so one empty string
// suffices and zero-length ones are never heap-allocated. (the empty SYMBOL
// died in the one-nothing round: () reads as 0.)
extern const struct ai_str ai_str_empty;
#define EmptyString ((word) &ai_str_empty)
void ai_wait_fds(int const *fds, int n, uintptr_t ticks);
bool ai_ready(int fd), ai_strp(ai_word);
struct ai
 *ai_please(struct ai*, uintptr_t),
 *ai_push(struct ai*, uintptr_t, ...),
 *ai_strof(struct ai*, const char*),
 *gxl(struct ai*),
 *gxr(struct ai*),
 *intern(struct ai*),
 *ai_reads(struct ai*, struct ai_io*),
 *ai_read1(struct ai*, struct ai_io*),
 *str0(struct ai*, uintptr_t);
lvm(lvm_gc, uintptr_t);
// ai_kind maps any value to its enum q: KFix for a fixnum, KHom for a non-data heap
// pointer (text/function/map), else ai_typ's data kind -- refined for a rank>=1 tuple,
// which expands by element tier to KArrZ..KArrO (a rank-0 box stays KTuple). Lives in
// ai.c (it needs ai_typ from the generated data.h) and is shared by data.c's apply
// sentinels. Both the `+`/`*` matrices and the apply matrix dispatch on this.
enum q ai_kind(word);
// Apply dispatch matrix, indexed [static: the applied data kind, ai_typ(Ip)][dynamic:
// the argument kind, ai_kind(Sp[0])]. The data sentinels (data.c) tail-jump through
// it; the aps + the table itself live in ai.c. Row indexed by the full kind
// (ai_typ returns one of the five data kinds), so the first dimension is KN, not ai_data_n.
extern lvm_t *ai_apply_mx[KN][KN];
extern union u const numap_drive[];          // [ap; swap; ret0] driver that runs (num-ap n x); shared by fixnum + data num apply
lvm_t lvm_ap, lvm_two, lvm_tuple, lvm_sym, lvm_str, lvm_big; // sentinels + ap: data.c & inline predicates
uintptr_t hash(struct ai*, word), ai_tuple_bytes(struct ai_tuple*);
#define str(_) ((struct ai_str*)(_))
#define lamp evenp
#define two(_) ((struct ai_pair*)(_))
static ai_inline bool twop(word _) { return lamp(_) && cell(_)->ap == lvm_two; }
static ai_inline void *bump(struct ai *g, uintptr_t n) {
  if (avail(g) < n) __builtin_trap();
  void *x = g->hp; g->hp += n; return x; }
static ai_inline struct ai_pair *ini_two(struct ai_pair *w, intptr_t a, intptr_t b) {
 return w->ap = lvm_two, w->a = a, w->b = b, w; }
static ai_inline struct ai *encode(struct ai*g, enum ai_status s) { return
  (struct ai*) ((uintptr_t) g | s); }
// Raise: to the global `help` function when installed, else raise_c (ai.c).
// ghelp re-raises an already-tagged g's own status.
struct ai *ghelp2(struct ai*, enum ai_status), *ghelp(struct ai*);
static ai_inline struct ai *ai_have(struct ai *g, uintptr_t n) {
 return !ai_ok(g) || avail(g) >= n ? g : ai_please(g, n); }

#endif
