#ifndef _g_h
#define _g_h
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
   struct g_tab {
    g_vm_t *ap;
    uintptr_t len, cap;
    struct g_kvs {
     intptr_t key, val;
     struct g_kvs *next; } **tab;
   } *dict, *macro;
  union {
   g_word x;
   struct g_io {
    g_vm_t *ap;
    g_word fd;
    g_word ungetc_buf;            // pushed-back byte; putnum(EOF) = empty
    g_word eof_seen; } *io; }; }; }; // set by getc on read-returning-0, cleared by ungetc
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
//   g_evals_(f, G_EGG_PRE
//   #include "prelude.h"
//     " "
//   #include "ev.h"
//     G_EGG_POST
//   #include "repl.h"          // optional: REPL, compiled by the installed ev
//   );
//
// egg = '(<prelude forms> <ev forms>); the driver compiles the gwen compiler
// with c0, recompiles the whole corpus through itself (exercising wev), and
// installs that as `ev`. Adjacent string-literal concatenation does all the
// work at compile time -- no runtime allocation, freestanding-safe.
#define G_EGG_PRE "(: egg '("
#define G_EGG_POST ") (go e z a) (? a (go e (e (car a)) (cdr a)) z) t0 (clock 0)" \
  " e (go (go ev 0 egg) 0 egg) (put 'boot_ms (clock t0) (put 'ev e globals))) "
#endif
