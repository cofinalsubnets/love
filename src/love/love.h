#ifndef _love_h
#define _love_h
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdarg.h>

struct g; union u;

// the public face: what a nif, a frontend or a seat needs. the internals follow

// --- the word and its tags ---
#define love_inline inline __attribute__((always_inline))
#define love_noinline __attribute__((noinline))
// no identical-code folding: the data sentinels' bodies match, and their address is the type tag
#if defined(__GNUC__) && !defined(__clang__) && !defined(__mooncc__)
#define noicf __attribute__((noipa))
#else
#define noicf
#endif
typedef intptr_t word;
#define Width(_) b2w(sizeof(_))
static love_inline size_t b2w(size_t b) {
 size_t q = b / sizeof(word), r = b % sizeof(word);
 return q + (r ? 1 : 0); }
#define countof(_) (sizeof(_)/sizeof(*_))
#define putcharm(_) ((word)(((uintptr_t)(word)(_)<<1)|1))
#define getcharm(_) ((word)(_)>>1)
#define zero putcharm(0)
#define word(_) ((word)(_))   // the cast with its parens; the inner `word` is the typedef
#define oddp(_) ((uintptr_t)(_)&1)
#define evenp(_) !oddp(_)
#define cell(_) ((union u*)(_))
#define charmp oddp
#ifndef EOF
#define EOF (-1)
#endif

// --- build knobs ---
// each #ifndef is a default, the guard a -D door
#ifndef tco
#define tco 1
#endif
// tco=1 without musttail keeps a frame per dispatch and overflows: broken, not slow. tco=0 trampolines
#if defined(__mooncc__) || defined(__clang__) || (defined(__GNUC__) && __GNUC__ >= 15)
#define have_musttail 1
#else
#define have_musttail 0
#endif
#if tco && !have_musttail
#error "no musttail: build -Dtco=0"
#endif
// port read-buffer bytes
#ifndef iobuf
#define iobuf 4096
#endif
// slack on every avail check against off-by-one overshoots; 0 under Love0, to keep it strict
#ifndef avail_floor
# ifdef Love0
#  define avail_floor 0
# else
#  define avail_floor 8
# endif
#endif
// this link bakes the crew from the source it carries; love0 lays that blob, wasm has no self on disk
#if !defined(Love0) && !defined(__wasm__)
# define LvBakeSrc 1
#endif
// initial pool sizes in words; both grow on demand
#ifndef love_minor0
# define love_minor0 (1u << 14)   // ~128 KB
#endif
#ifndef love_major0
# define love_major0 (1u << 16)      // ~512 KB
#endif
#ifndef gc_qn
# define gc_qn 2   // q = gc_qn / gc_qd: the nursery's ceiling, q of the live set (gcsize.v's nurse)
#endif
#ifndef gc_qd
# define gc_qd 1
#endif
#ifndef gc_fn
# define gc_fn 2   // f = gc_fn / gc_fd: a major leaves room for f of its survivors (gcsize.v's more)
#endif
#ifndef gc_fd
# define gc_fd 1
#endif
// the nursery grows while copied/allocated tops 1/ratio (please)
#ifndef gc_ratio
# define gc_ratio 24   // the knee: past it RAM doubles for a flat curve
#endif
// total budget in words (minor + 2*major), 0 unbounded; a device sets its RAM
#ifndef love_budget
# define love_budget 0
#endif
// the C stack bytes c0 may take where the seat says no more: inle's boot stack is a MiB over
// the page tables; a host takes three quarters of its rlimit
#ifndef love_cstack
# define love_cstack (768u << 10)
#endif

// --- status ---
// status rides the 2 pointer tag bits: bit 0 scare, bit 1 more input wanted; eof = both
enum status { status_ok = 0, status_scare = 1, status_more = 2, status_eof = 3 };
#define core_of(p) ((struct g*)((intptr_t)(p)&~(sizeof(intptr_t)-1)))
#define code_of(g) ((enum status)((intptr_t)(g)&(sizeof(intptr_t)-1)))
#define ok(g) (code_of(g) == status_ok)
static love_inline struct g *encode(struct g *g, enum status s) { return
  (struct g*) ((uintptr_t) g | s); }
// the largest ask in words: past it refused, never wrapped. Have adds it to Hp, and a
// kernel heap sits in the top half, so 2^40 (2^26 on 32-bit) keeps far from a wrap
#define words_max ((uintptr_t) -1 >> (sizeof(uintptr_t) > 4 ? 24 : 6))
// a * b, saturating at half the word -- still past words_max, so still a refusal
static love_inline uintptr_t mulsat(uintptr_t a, uintptr_t b) {
 uintptr_t const h = (uintptr_t) 1 << (4 * sizeof(uintptr_t)), top = (uintptr_t) -1 >> 1;
 return (a < h && b < h) || !a || b <= top / a ? a * b : top; }

// --- the vm calling convention ---
#if tco
#define _lvm(n) struct g *n(struct g *restrict g, union u *Ip, word *Hp, word *restrict Sp)
#define Ap(fn, g) fn(g, Ip, Hp, Sp)
#define Continue() Ap(Ip->ap, g)
// bare calls, as musttail's operand may not be a comma. the store is unsequenced against the
// other arguments, so v must not touch Hp or Ip; n and k evaluate twice: literals
#define Next(n) Ip[n].ap(g, Ip + (n), Hp, Sp)
#define Nextp(n, k) Ip[n].ap(g, Ip + (n), Hp, Sp + (k))
#define Answer(v) Ip[1].ap(g, Ip + 1, Hp, (Sp[0] = (v), Sp))
#define Answerp(k, v) Ip[1].ap(g, Ip + 1, Hp, (Sp[k] = (v), Sp + (k)))
#define Push(v) Ip[1].ap(g, Ip + 1, Hp, (*++Sp = (v), Sp))
#ifdef LvGcCheck
// marks whether g->hp/sp are true, so scratch taken unpacked traps (gap)
#define Pack(g) (g->ip = Ip, g->hp = Hp, g->sp = Sp, g->unpacked = 0)
#define Unpack(g) (Ip = g->ip, Hp = g->hp, Sp = g->sp, g->unpacked = 1)
#else
#define Pack(g) (g->ip = Ip, g->hp = Hp, g->sp = Sp)
#define Unpack(g) (Ip = g->ip, Hp = g->hp, Sp = g->sp)
#endif
// every vm tail is `love_musttail return ..`, held to the jump (make vmret checks). musttail
// wants matching prototypes, so an op's extra argument rides g->b
#define love_musttail __attribute__((musttail))
#if defined(__GNUC__) && !defined(__clang__) && !defined(__mooncc__)
// no frame address outlives its call in an lvm_ anyway
#pragma GCC diagnostic ignored "-Wmaybe-musttail-local-addr"
#endif
#else
#define _lvm(n) struct g *n(struct g *restrict g)
#define Ap(fn, g) fn(g)
#define Continue() g
#define Next(n) (Ip += (n), g)
#define Nextp(n, k) (Sp += (k), Ip += (n), g)
#define Answer(v) (Sp[0] = (v), Ip += 1, g)
#define Answerp(k, v) (Sp[k] = (v), Sp += (k), Ip += 1, g)
#define Push(v) (*++Sp = (v), Ip += 1, g)
#define love_musttail
#define Hp g->hp
#define Sp g->sp
#define Ip g->ip
#define Pack(g) ((void)0)
#define Unpack(g) ((void)0)
#endif
#define lvm(n) love_noinline noicf _lvm(n)
typedef _lvm(lvm_t);
union u {
 lvm_t *ap;
 word x;
 union u *m;
 union u const *k; };   // threaded code is const: .rodata, or flash
// a C helper that may collect, ghelp on not-ok: LvmCall steps one, LvmCallp lifts the
// answer over k operands, LvmResume re-enters at g->ip
#define LvmPack(g, f, ...) \
 Pack(g); if (!ok(g = f(g, ##__VA_ARGS__))) love_musttail return Ap(_lvm_ghelp, g)
#define LvmCall(g, f, ...) { LvmPack(g, f, ##__VA_ARGS__); Unpack(g); love_musttail return Next(1); }
#define LvmCallp(g, k, f, ...) { LvmPack(g, f, ##__VA_ARGS__); Unpack(g); Sp[k] = Sp[0]; love_musttail return Nextp(1, k); }
#define LvmResume(g, f, ...) { LvmPack(g, f, ##__VA_ARGS__); Unpack(g); love_musttail return Continue(); }
#define LvmWrap(n, f) lvm(n) LvmCall(g, f)
// lvm_X over a word-answering host_X of the top 1, 2 or 3 words: its answer replaces them
#define LvmWord1(x) static lvm(lvm_##x) { Sp[0] = host_##x(g, Sp[0]); love_musttail return Next(1); }
#define LvmWord2(x) static lvm(lvm_##x) { Sp[1] = host_##x(g, Sp[0], Sp[1]); love_musttail return Nextp(1, 1); }
#define LvmWord3(x) static lvm(lvm_##x) { Sp[2] = host_##x(g, Sp[0], Sp[1], Sp[2]); love_musttail return Nextp(1, 2); }
// a variable ask is held to the room Sp - Hp, which no n can wrap; a small constant keeps
// the one-instruction Hp + n, which wraps only within 32 KB of the address space's top
#define room(Hp, Sp) (((uintptr_t) (Sp) - (uintptr_t) (Hp)) / sizeof(word))
#define have_gc(n) { g->b = (n) + avail_floor; love_musttail return Ap(lvm_gc, g); }
#define Have(n) do { \
  if (__builtin_constant_p(n) && (n) <= 4096) { if (Sp < Hp + (n) + avail_floor) have_gc(n) } \
  else if (room(Hp, Sp) < (uintptr_t) (n) + avail_floor) have_gc(n) } while (0)
#define Have1() Have(1)
#define pop1(g) (*(g)->sp++)
#define op(nom, n, x) lvm(nom) { intptr_t _ = (x); *(Sp += n-1) = _; Ip++; love_musttail return Continue(); }
#define op1(nom, i, x) lvm(nom) { Sp[0] = (x); Ip += i; love_musttail return Continue(); }
#define op11(nom, x) op1(nom, 1, x)
// calls the installed help; the _lvm prefix makes vmret skip it, as it returns to C with none
lvm_t _lvm_ghelp;
lvm(lvm_gc);                                    // takes its word count in g->b

// --- heap objects ---
struct str {
 lvm_t *ap;
 uintptr_t len;        // bytes[len] is always a NUL
 char bytes[]; };
// a cask: mutable bytes behind a 2-word wrapper, known by its ap
struct cask { lvm_t *ap; struct str *str; };
// a mint: a nameless point, its hot and serial
struct mint {
 lvm_t *ap;
 uintptr_t serial; };   // the order key; () is serial 0, every fresh mint ++next_serial
// a nom: an interned named point; dig caches the spelling hash, so bucket order is not intern history
struct nom {
 lvm_t *ap;
 uintptr_t name, dig; };
struct chain { lvm_t *ap; intptr_t a, b; };
// an immutable typed n-dim array; rank 0 a scalar; payload at shape+rank
struct tray {
 lvm_t *ap;
 uintptr_t type, rank, shape[]; };
#define A(o) two(o)->a
#define B(o) two(o)->b
#define len(_) (((struct str*)(_))->len)
#define txt(_) (((struct str*)(_))->bytes)
#define AB(o) A(B(o))
#define AA(o) A(A(o))
#define BA(o) B(A(o))
#define BB(o) B(B(o))
#define ptr(_) ((word*)(_))
#define str(_) ((struct str*)(_))
#define two(_) ((struct chain*)(_))
#define chain_req Width(struct chain)
#define mint_req Width(struct mint)
#define nom_req Width(struct nom)
#define cask(_) ((struct cask*)(_))
#define tray(_) ((struct tray*)(_))
#define sym(_) ((struct mint*)(_))
#define nom(_) ((struct nom*)(_))
#define big(_) ((struct big*)(_))
// the unique empty string, out of pool; its own type so the trailing NUL has storage
extern const struct str0 { lvm_t *ap; uintptr_t len; char bytes[8]; } str_empty;
#define EmptyString ((word) &str_empty)
// (): the one serial-0 mint, a const shared by every core so it bakes; serial 0 is never drawn
extern const struct mint mint_zero;
#define ZeroPoint ((word) &mint_zero)

// --- the core ---
struct port_vt;
// the reader's names (g->rnom): its wraps, two lone chars, the torn answer, the flow
enum { RnQuote, RnList, RnHash, RnTuple, RnTablet, RnIota, RnMono, RnTorn, RnAt, RnComma, RnWeave, RnN };
// lisp functions C calls, by (seal-hook n f)'s n; the task's own sit in its node: -1 help, -2 stdio
enum hook {
 hook_numap,     // numeric application (church exponentiation)
 hook_arrange,   // church addition (prel's `arrange`)
 hook_compose,   // composition (church multiplication)
 hook_opfix,     // the operator factor pass
 hook_show,      // show a value as a string
 hook_net,       // the measure of a compound value (prel's `measure`), what C's truth asks
 hook_flow,      // a port as a charlist (post.l's `flow`), the reader's port door
 hook_cats,      // cats over a list no fast lane takes (prel's foldr of +)
 hook_obin,      // an object tray's cells no C lane takes: a tray, a coin, a twin (prel's)
 hook_opfixp,    // the factor pass over a macro's (expansion . operands), the operands kept whole
 hook_n };

struct g {
 union u *ip;
 word *hp, *sp;
 union u *tasks,  // running tasks; the head is the running one, [6]/[7] its help and stdio
         *parked; // paused tasks
 uint16_t yield_ctr,   // cycles since the last yield
          sweep_ctr;   // fairness yields since the last parked sweep
 int next_wait_fd,     // -1 none
     next_wait_events; // wait_in, or wait_out (connect's handshake)
 // the one scratch word: a port refill, a write's count, a Have's ask. set it as the last
 // act before the return that hands it back
 word b;
 word inflag;           // fd 0's flags as found (a charm), 0 left alone
 uintptr_t next_serial,
           next_wake_at, // the next snapshot's wake_at; 0 always runnable
           clock_at;     // the last sweep tick's clock
 word symbols;          // the weak intern map
 uintptr_t len;         // main pool words: the core at its base, [end,hp) young
 struct love_r { word *x; struct love_r *n; } *root;
 struct fz { // finalizers
  union u *p;
  void (*fn)(struct g*, void *);
  struct fz *next; } *fz;
 // the native code arena (love.c), RX between installs; cfree, blobs whose closures died
 struct code *code;
 struct cfree *cfree;
 // binary addresses a native reads off g, as a blob holding one could not ride an image
 word reach[12];
 intptr_t fair;   // right past reach, where the glaze reads it: native code's countdown, a step
                  // or a call takes one, at 0 it refills
 uintptr_t ticks; // the refills and the vm's fairness yields: work in 64-step units
 uintptr_t n_gc, max_len, max_heap, // collections, peak pool len, peak live heap
           n_seen, n_evac;          // Σ occupancy entering, survivors copied
 // the rem set: old cells that took a young pointer; a rem_miss forces the next collection major
 word *rem;
 uint32_t rem_n, rem_hi, rem_miss;   // bounded by LvRemCap
 uint64_t child_ign;                      // bit n: signal n stays ignored in a spawned child
 int8_t lean;                             // grow streak; a grow needs lean >= 2
#ifdef LvGcCheck
 bool unpacked;                           // the registers ahead of hp and sp (Pack, Unpack)
#endif
 // the main pool is all nursery, young [end, hp); old lives in the major block
 word *major_base, *major_hp;
 uintptr_t
   major_len,
   n_minor,                       // majors = n_gc - n_minor
   minor_hi, major_hi,            // peak words one minor / major copied (gauge[14]/[15])
   major_live0,                   // live after the last major: the budget's live set
   win_alloc, win_copied,         // the resize window: overhead = copied/alloc
   n_resize,                      // gauge[13]
   budget,                     // words (minor + 2*major), 0 unbounded
   walk,                          // the most room a walk under one op wanted past the gap: the op takes it, runs again
   minor0, major0, ratio,         // nursery floor, major step, setpoint: `tune` moves them, a bake drops them
   push_gc;                       // a law's: collect on this many pushes on, 0 none (push-gc)
 uintptr_t cbase, croom;          // c0's outermost C frame (0 outside one), and the stack it may take
 uintptr_t ask;                   // the collector's ask while it works: an oom's first datum
 struct pool *pool;               // the threads C kernels share out over (pool.c), made at the first ask
 union {
  intptr_t v0;
  struct {
   word
     stack,  // the books checked out, ours on top; the macro table is stack[zero]'s
     scare_a, scare_b, // the last scare's condition data
     scare_c,    // a C lane's reason, (tag . datum), for the re-raise
     hook[hook_n],
     lib,        // name -> book (borrow, cite, leave)
     errs,        // errno -> its nom
     kinds,       // enum q row -> its nom (kinds.h)
     kreg,        // name -> (serial . table), post.l's `coin`
     knom[20],    // the kind table's keys and the built-in coins' names
     rnom[RnN],   // interned at boot so a read allocates none
     inport;      // the buffered stdin port, or 0
   union {
    word x;
    struct io {
     lvm_t *ap;
     struct port_vt const *vt;   // the port's kind
     word ungetc_buf;               // putcharm(EOF) empty
     // prel's tap/jug poke this layout by index: a word added renumbers there
    } *io; }; }; };
 intptr_t end[]; };

// --- nif registration ---
// .k a nif's threaded code, .ap an lvm_, .x a word; every one immortal (defn). m the module,
// NULL for the global book
struct def { char const *n; union u v; char const *m; };

// LvNif("name", fn, "mod") lays a row in love_nifs, which boot drains through defn; a nif
// rides the image as an index off the bracket. not weak: ld leaves a weak undefined at 0, so
// a link with no LvNif defines the pair itself. the alignment is the array's stride; a literal for mooncc
#if UINTPTR_MAX > 0xffffffffu
#define LvDefAlign 8
#else
#define LvDefAlign 4
#endif
extern struct def const __start_love_nifs[], __stop_love_nifs[];
// nothing references a row: retain keeps --gc-sections from dropping the section
#if defined(__GNUC__) && !defined(__mooncc__) && __GNUC__ >= 11
#define LvNifKeep , retain
#else
#define LvNifKeep
#endif
#define LvNif(nm, fn, mod) \
  static struct def const \
    __attribute__((section("love_nifs"), used, aligned(LvDefAlign) LvNifKeep)) \
    _ainif_##fn = { (nm), { .k = (fn) }, (mod) }
// LvDef("name", x, n, mod): lvm_x as an n-ary nif, currying through lvm_cur
#define LvTab1(f) {{f}, {lvm_ret0}}
#define LvTabN(f, n) {{lvm_cur}, {.x = putcharm(n)}, {f}, {lvm_ret0}}
#define LvTab2(f) LvTabN(f, 2)
#define LvTab3(f) LvTabN(f, 3)
#define LvTab4(f) LvTabN(f, 4)
#define LvTab5(f) LvTabN(f, 5)
#define LvTab6(f) LvTabN(f, 6)
#define LvTab7(f) LvTabN(f, 7)
#define LvTab8(f) LvTabN(f, 8)
#define LvDef(nm, x, n, mod) static union u const nif_##x[] = LvTab##n(lvm_##x); LvNif(nm, nif_##x, mod)

// --- ports ---
// what a device owes; NULL is no method (no readn reads end, no writen discards). none blocks.
//   writen: up to n bytes, count in g->b: >0 landed, 0 no room now, -1 gone. it may
//     allocate, so land nothing after an allocating step
//   readn: up to n waiting bytes: >0, 0 nothing yet, -1 end, owed to every later ask too
//     (test/front/io.l law 3). never allocates
//   athand: of the next n bytes, how many are here; NULL asks the device
struct port_vt {
 struct g*(*flush)(struct g*);
 struct g *(*writen)(struct g*, unsigned char const*, uintptr_t);
 intptr_t (*readn)(struct g*, unsigned char*, uintptr_t);
 uintptr_t (*athand)(struct g*, uintptr_t); };
lvm_t lvm_ret0, lvm_cur, lvm_port_io, lvm_help, lvm_cask,
// a nif parks: set next_wake_at or next_wait_fd, leave Ip, tail to lvm_yield_sw; it re-runs
      lvm_yield_sw,
// a nif ends the task: stack down to the retval, Ip at a {lvm_task_exit} cell, tail to it
      lvm_task_exit,
// a quit where a task is a process: its worn fds close, then lvm_task_exit
      lvm_task_quit;

// every OS fd port's vtable, the frontend's: its address says an fd is behind (io_fd)
extern struct port_vt const love_fd_port_vt;
// a closed port's: every door a no-op. swapping it in is the close, there is no other mark
extern struct port_vt const closed_vt;
// the horn: PCM out as a port in the fd port's shape, so the write run buffers and parks
// (horn.c). the writen is weak, so a link without horn.c stands
extern struct port_vt const love_horn_vt;
struct g *love_horn_writen(struct g*, unsigned char const*, uintptr_t);
intptr_t love_horn_readn(struct g*, unsigned char*, uintptr_t);
void love_horn_shut(struct io*);               // `close` on one: shut the device under it
// its C face, 16-bit stereo: open -> 0 | -1; write -> bytes, 0 full, -1 gone; lag -> frames
// queued. inle/hda.c the body, horn.c the weak refusals
int k_horn_open(int rate);
intptr_t k_horn_write(unsigned char const*, uintptr_t);
uintptr_t k_horn_lag(void);
void k_horn_close(void);
// the mic, 16-bit: open -> 0 | -1; read -> whole frames' bytes, 0 dry, -1 gone; lag -> unread frames
int k_horn_in_open(int rate, int chans);
intptr_t k_horn_read(unsigned char*, uintptr_t);
uintptr_t k_horn_in_lag(void);
void k_horn_in_close(void);
// the same face on any seat: k_horn_* under inle, else the host's card (horn.c)
int love_horn_open(int rate);
intptr_t love_horn_write(unsigned char const*, uintptr_t);
uintptr_t love_horn_lag(void);
void love_horn_close(void);

// weak no-op, the host's close(2); io_alloc's finalizer calls it
void love_fd_close(int fd);

// the fd port; nothing casts to it without io_fd, -1 for a tap, a jug or a closed port
struct fio { struct io io; word fd; };
intptr_t io_fd(struct io const*);
// the buffered port: rbuf/wbuf a str or 0, [rpos,rlen) the read run, wlen the write prefix.
// static ports stay bare
struct bio { struct fio f; word rbuf, rpos, rlen, wbuf, wlen; };
// 0 or no-op on a bare port: pending, the read buffer's bytes; drain pops up to n
uintptr_t
 io_pending(struct g*, struct io*),
 io_read_drain(struct g*, struct io*, unsigned char*, uintptr_t),
// moves the run's position, answering how far: n > 0 gives back, n < 0 takes
 io_unread(struct g*, struct io*, intptr_t),
 io_wpending(struct g*, struct io*);  // what the device would not take
struct g
 *io_wflush(struct g*, struct io*),
// close and seal wflush, then park on a nonzero wpending: never shut an fd on a residue
 *io_alloc(struct g *g, int fd);
// raw bytes at an fd, for the finalizer draining a dying port; weak no-op, the host's write(2)
void love_fd_drain(int fd, void const*, uintptr_t);

// the raw-fd lanes (fd.c), for a charm operand: unbuffered, >0 landed, 0 busy, -1 gone
intptr_t love_fd_readn(struct g*, int fd, unsigned char *dst, uintptr_t);
intptr_t love_fd_writen(int fd, unsigned char const *src, uintptr_t);
uintptr_t love_fd_say(int fd, unsigned char const *src, uintptr_t);
intptr_t port_fd(word);                         // the fd under a love port, or -1
uintptr_t love_fd_write_all(int, unsigned char const*, uintptr_t);   // land every byte, waiting
extern struct port_vt const to_vt, closed_vt, ci_vt;
// poll(2)'s struct pollfd, so the host polls the block directly (main.c static-asserts it)
struct wait_fd { int fd; short events, revents; };

// poll(2)'s bits (main.c asserts). never OR them: a socket is nearly always writable, a reader spins
#define wait_in  1
#define wait_out 4

void wait_fds(struct wait_fd *fds, int n, uintptr_t ticks),
    ready_fds(struct wait_fd *fds, int n);                  // non-blocking
bool ready(int fd, int events);

// --- the seat's doors ---
// posix.c..
struct g *love_argv_marshal(struct g*, char***);   // argv -> char** in the heap gap
// the file a marshalled argv execs: the path a (path . name) head laid past the NULL, else argv[0]
static love_inline char const *argv_file(char **cav) {
 char **p = cav;
 while (*p) p++;
 return p[1] ? p[1] : cav[0]; }
void host_spawn_guard(struct g*, int);            // exec-bound forks drop the pools
int raw_mode(intptr_t on);                      // the (raw on) latch; main.c's repl too
size_t host_selfpath(char*, size_t);
// ..image.c..
int image_bake(struct g*, char const *out, int bare), baked_pick(void const **blob, uintptr_t *blen);
struct g *image_load(char const*, int*), *image_dump(struct g*, char const*);
extern uint64_t baked_image[];
extern uintptr_t baked_image_len;
// ..gz.c and the other codecs..
intptr_t inflate_raw(unsigned char const*, uintptr_t, unsigned char*, uintptr_t),
         inflate_dict(unsigned char const*, uintptr_t, unsigned char*, uintptr_t, unsigned char const*, uintptr_t),
         deflate_raw(struct g*, unsigned char const*, uintptr_t, unsigned char*, uintptr_t),
         deflate_dict(struct g*, unsigned char const*, uintptr_t, unsigned char const*, uintptr_t, unsigned char*, uintptr_t);
intptr_t bz2_into(unsigned char const*, uintptr_t, unsigned char*, uintptr_t),
         lzma2_into(unsigned char const*, uintptr_t, unsigned char*, uintptr_t);
uint32_t crc32(unsigned char const*, uintptr_t);
// the thread pool (pool.c): fn(ctx, i) for chunks 0..n-1, C kernels only
void par_run(struct g*, intptr_t, void (*)(void*, intptr_t), void*);
intptr_t par_width(struct g*, intptr_t);
// the carried source (archive/srctree.h); noblob.c's zero without one
extern unsigned char const srctree[];
extern uintptr_t const srctree_len;
// /love on the host (lovefs.c): the one tree (NULL none), a path's place in it (-1 not the
// tree's, -2 absent, -3 a directory, else its entry) and canonical name, stat, listing, a read port
struct tree *tree_carried(void);
intptr_t lovefs_at(char const *p, char *c, uintptr_t *cn);
struct vfs_st;
int lovefs_stat_at(char const *c, uintptr_t cn, struct vfs_st *st);
int lovefs_child(char const *c, uintptr_t cn, int *cur, char const **name, uintptr_t *len, bool *dir);
struct g *lovefs_port(struct g *g, uintptr_t i);
extern unsigned char const rootfs[];          // src/inle/rootfs/ as a plain tar
extern uintptr_t const rootfs_len;

uintptr_t love_clock(void);
intptr_t nclock(void); // ns; the null seat degrades to ms
// the kernel underneath (moonlibc's os.c): 0 unprobed, 1 linux, 2 freebsd, 3 netbsd, <0 inle
extern long __love_osv;
void love_sleep(uintptr_t ticks); // at most ticks (0 forever), no input wakeup; default no-op

// the one door to the heap: every pool and scratch block. the seat's (alloc.c)
void *alloc(void *p, size_t n);  // n>0 reserve (p ignored), n==0 free p; -> block or NULL

// --- the runtime's entry ---
// egg applies boot/egg.l to the corpus: the compiler by c0, then the corpus through itself as `ev`
struct g
 *ini(void),
 *evals(struct g*, const char*),      // ..keeping the last form's value at sp[0]
 *evals_(struct g*, const char*),
 *egg(struct g*, char const*, char const*, char const*),  // (egg, corpus, post)
 *defn(struct g*, struct def const*, uintptr_t),                // immortal values only
 *defv(struct g*, char const*),                // a live heap value at sp[0], left there
 *love_open(struct g*),      // a fresh writable layer: every session opens with it
 *shelve(struct g*);   // drop the link below the head
enum status fin(struct g*);
// the stdio-free image codec. a kept absolute must aim inside the binary's own load segments,
// which one ASLR delta shifts; anything else is refused. a refusal names its first offenders
// (word offset, value, ap) and why: 2 compaction scared, 3 oom, 4 an unencodable word, 5 root
// table small, 6 an unencodable root, 8 past the lane floor, 10 no room for ranks, 11 rank walk out
struct image_bad { uintptr_t q[3 * 2]; int n, why; };
// the running stack rides as ballast; load resets sp/ip
void *image_save(struct g*, uintptr_t *outlen, struct image_bad*);
// chunk: a stream chunk's words (0 default); hot: nhot ranges [a, b) a profile touched, laid
// first, more ranges ahead of fewer
struct image_opt { uintptr_t chunk; uint64_t const *hot; uintptr_t nhot; };
void *image_save2(struct g*, uintptr_t *outlen, struct image_bad*, struct image_opt const*);
struct g
 *love_image_load(void const *buf, uintptr_t len, int kept);   // kept: buf outlives the session; 2: and the image may wake lazily
int image_why(void const *buf, uintptr_t len);   // a header refused: 0 no, 1 another format, 2 another binary's, 3 other C, 4 damaged
uint64_t image_carried_c(void);                  // the carried C's crc and length, 0 for none
// a lazy image's pool given up: its pages open, its state gone
void image_drop(word const *pool);
// before a warm fork: wake what any process of this image would
void image_warm(void);
void code_warm(struct g *g);

// ";; a b\n" to the err port from the stashed data; the bare scare ";; oom (ask nursery major)\n"
void scare_face(struct g*);

extern struct fio love_stdin, love_stdout, love_stderr;

// --- allocation and roots ---
#define avail(g) ((uintptr_t)(g->sp-g->hp))
#define avec(g, y, ...) (mm(g,&(y)),(__VA_ARGS__),um(g))
#define mm(g,r) ((core_of(g)->root=&((struct love_r){(word*)(r),core_of(g)->root})))
#define um(g) (core_of(g)->root=core_of(g)->root->n)
extern struct g *love_system;   // only gen_grow moves it
struct g
 *please(struct g*, uintptr_t),
 *force(struct g*, bool),
 *love_fd_retry(struct g*, int*, int (*)(struct g*, void*), void*),
 *push(struct g*, uintptr_t, ...),
 *strof(struct g*, const char*),
 *gxl(struct g*),
 *gxr(struct g*),
 *intern(struct g*),
 *str0(struct g*, uintptr_t),
 *grbufg(struct g *g, uintptr_t len);
// an errno's nom, 'eunknown for a blank, 'badarg at -1; interned at boot, so no error allocates
word love_err(struct g*, int);
#define badarg(g) love_err(g, -1)
uintptr_t hash(struct g*, word), love_tray_bytes(struct tray*);
// "this call may collect": under LvGcStress every one does, so a raw local across it goes stale
static love_inline struct g *have(struct g *g, uintptr_t n) {
#ifdef LvGcStress
 return !ok(g) ? g : please(g, n);
#else
 return !ok(g) || avail(g) >= n ? g : please(g, n);
#endif
}
// a walk keeps its worklist in the gap it was lent: spent, it asks for twice the region and
// gives up, and its op takes the room and runs again. walks nest, so the ask is the largest
static love_inline void walk_short(struct g *g, word const *base, word const *hi, uintptr_t want) {
 uintptr_t n = (uintptr_t) (hi - base), w = (n < 32 ? 64 : 2 * n) + want;
 if (w > g->walk) g->walk = w; }
// the ask is on top of the room there is: an op's own scratch may sit ahead of the walk's.
// a host lane's: the room taken (which may collect), the ask cleared; operands ride the stack
static love_inline struct g *walk_room(struct g *g) {
 uintptr_t w = g->walk + (uintptr_t) (g->sp - g->hp);
 g->walk = 0;
 return have(g, w); }
// an op's: the room through lvm_gc, which runs the op again on its operands as they were
#define WalkAgain() do { if (g->walk) { uintptr_t _w = g->walk + room(Hp, Sp); g->walk = 0; have_gc(_w) } } while (0)
static love_inline void *bump(struct g *g, uintptr_t n) {   // the nursery's; gc.c bumps the major
 if (avail(g) < n) __builtin_trap();
 void *x = g->hp; g->hp += n; return x; }

// the internals: object layouts, predicates, accessors, the seam between translation units
#include <sys/mman.h>
#include <unistd.h>
int memcmp(void const*, void const*, size_t);
void *malloc(size_t), free(void*),
 *memcpy(void*restrict, void const*restrict, size_t),
 *memmove(void*restrict, void const*restrict, size_t),
 *memset(void*, int, size_t),
 *(memchr)(void const*, int, size_t);   // parenthesized: c23 glibc spells memchr as a macro
size_t strlen(char const*);

// --- the machine ---
#if UINTPTR_MAX == UINT64_MAX
#define Bits 64
typedef double flo_t;
#elif UINTPTR_MAX == UINT32_MAX
#define Bits 32
typedef float flo_t;
#endif
// bignum limbs: native width where a double-width product exists, else 32-bit; dlimb doubles
#if UINTPTR_MAX == UINT64_MAX && defined(__SIZEOF_INT128__)
typedef uint64_t love_limb;
typedef unsigned __int128 dlimb;
typedef __int128 sdlimb;
#define limb_bits 64
#else
typedef uint32_t love_limb;
typedef uint64_t dlimb;
typedef int64_t sdlimb;
#define limb_bits 32
#endif
#define wlimbs (Bits / limb_bits)   // limbs to a word
#define Bytes (Bits>>3)
_Static_assert(Bytes == sizeof(uintptr_t), "word size sanity check");

_Static_assert(sizeof(union u) == sizeof(intptr_t), "cell size equals word size");
_Static_assert(-1 >> 1 == -1, "sign extended shift");
#if UINTPTR_MAX > 0xffffffffu
#define mix ((uintptr_t) 0x9e3779b97f4a7c15) // round(2^64 / phi)
#else
#define mix ((uintptr_t) 0x9e3779b9) // round(2^32 / phi)
#endif
#define min(p,q) ((p)<(q)?(p):(q))
#define max(p,q) ((p)>(q)?(p):(q))
static love_inline uintptr_t rot(uintptr_t x) {
  int const s = sizeof(uintptr_t) * 4; // half the word
  return (x << s) | (x >> s); }

// --- kinds ---
// enum q, the dispatch lattice: each dyadic lane one contiguous range, max the promotion join
// (cmp_rank remaps for compare order). enum d: what a heap object's hot says it is, so a switch
// needs no default. both rosters are laid by mx.l: edit that, not kinds.h
#include "kinds.h"
// any value -> its enum q, a tray refined by element tier
enum q kind(word);
extern union u const numap_drive[], obin_drive[];          // [ap; swap; ret0], runs (num-ap n x)
lvm_t lvm_ap, lvm_chain, lvm_tray, lvm_sym, lvm_nom, lvm_str, lvm_big, lvm_gembox, lvm_twinbox; // the data sentinels (+ ap)
// the sentinels tile one section at data_stride in enum d order from lvm_sym: the slot is the kind
#if data_section
static love_inline bool in_data(void *a) {
 return (uintptr_t) ((char*) a - (char*) lvm_sym) < (uintptr_t) (data_n * data_stride); }
static love_inline enum d love_typ(union u *o) {
 return (enum d) ((uintptr_t) ((char*) o->ap - (char*) lvm_sym) / data_stride); }
#else
// no section: ask by name, in measured frequency order, not enum d's
static love_inline bool in_data(void *a) {
 lvm_t *p = (lvm_t*) a;
 return p == lvm_chain || p == lvm_nom || p == lvm_str || p == lvm_sym || p == lvm_big
     || p == lvm_tray || p == lvm_gembox || p == lvm_twinbox; }
static love_inline enum d love_typ(union u *o) {
 lvm_t *p = o->ap;
 return p == lvm_chain  ? DChain
      : p == lvm_nom    ? DNom
      : p == lvm_str    ? DString
      : p == lvm_sym    ? DMint
      : p == lvm_big    ? DBig
      : p == lvm_tray   ? DTray
      : p == lvm_gembox ? DGem
      :                   DTwin; }
#endif
#define typ(_) love_typ(cell(_))
#define datp(_) in_data(cell(_)->ap)
// the charm zero, structurally: not nil?
#define zerop(_) (word(_)==zero)
static love_inline bool chainp(word _) { return evenp(_) && cell(_)->ap == lvm_chain; }
static love_inline bool strp(word _) { return evenp(_) && cell(_)->ap == lvm_str; }
// a string the kernel reads whole: no NUL inside
static love_inline bool cstrp(word _) { return strp(_) && strlen(txt(_)) == len(_); }
static love_inline bool mintp(word _) { return evenp(_) && cell(_)->ap == lvm_sym; }
static love_inline bool namep(word _) { return evenp(_) && cell(_)->ap == lvm_nom; }
static love_inline bool packp(word _) { return evenp(_) && cell(_)->ap == lvm_tray; }
static love_inline bool nomp(word x) { return evenp(x) && (cell(x)->ap == lvm_sym || cell(x)->ap == lvm_nom); }
// not a data kind: the GC walks a cask as a length-2 thread, forwarding its str free
static love_inline bool caskp(word _) { return evenp(_) && cell(_)->ap == lvm_cask; }

// --- the instruction roster ---
char const *nif_name(intptr_t);
lvm_t lvm_kcall,
 lvm_putn, lvm_seal, lvm_heard, lvm_worn, lvm_myself,
 lvm_nilp, lvm_putc, lvm_intern,
 lvm_saturate, lvm_ceil, lvm_peep, lvm_nifnom, lvm_cask, lvm_bcopy, lvm_xlat,
 lvm_coin, lvm_coinmk, lvm_load, lvm_coinp, lvm_kind, lvm_sub_coin, lvm_quot_coin,
 lvm_charmp, lvm_tabp, lvm_band, lvm_bor, lvm_gem, lvm_gemp,
 lvm_sin, lvm_cos, lvm_tan, lvm_atan, lvm_atan2, lvm_exp, lvm_sqrt, lvm_log, lvm_pow,
 lvm_twin, lvm_twinp, lvm_re, lvm_im, lvm_conj, lvm_abs, lvm_carg,
 lvm_bxor, lvm_bsr, lvm_bsl, lvm_puts,
 lvm_string, lvm_lt,     lvm_le,   lvm_eq,     lvm_same, lvm_gt,  lvm_ge, lvm_elem, lvm_eleq,
 lvm_sort,  lvm_sortby, lvm_tally, lvm_longp,
 lvm_pin, lvm_pull, lvm_tablet,   lvm_keys,  lvm_dig,
 lvm_unc, lvm_poke, lvm_peek, lvm_pick, lvm_place, lvm_stem, lvm_span,
 lvm_seek,  lvm_trim,   lvm_spin,   lvm_thrun, lvm_add,
 lvm_mul,    lvm_quot,   lvm_fquot, lvm_rem,  lvm_arg,
 lvm_bmul_start,             // the resumable bignum multiply (num.c)
 lvm_quote, lvm_index,  lvm_eval,   lvm_cond, lvm_jump,   lvm_defglob,
 lvm_ap,    lvm_tap,    lvm_apn,    lvm_tapn, lvm_ret,
 lvm_apo,   lvm_tapo,   lvm_uncn, lvm_part, lvm_tpart, lvm_apo_miss,
 lvm_argap, lvm_quoteap, lvm_argtap,
 lvm_arg0, lvm_arg1, lvm_arg2, lvm_arg3,
 lvm_quo0, lvm_quo1, lvm_quo2, lvm_quo3, lvm_quom1, lvm_quom2,
 // a run of loads in one op, named for its shape
 lvm_aa, lvm_aq, lvm_qa, lvm_qq,
 lvm_aap, lvm_aqp, lvm_qap, lvm_qqp,
 // arg fused with the op that eats it
 lvm_argcap, lvm_argcup, lvm_argtwo, lvm_argcond,
 lvm_argtwocond,                                  // load + predicate + cond
 lvm_callk, lvm_scare, lvm_yield_sw, lvm_yield_nif, lvm_task_exit, lvm_twirl, lvm_wait,
 lvm_sleep, lvm_donep, lvm_scoop, lvm_hush, lvm_deadlock,
 lvm_await,
 lvm_fgetc, lvm_fungetc, lvm_chug, lvm_unchug, lvm_inhand, lvm_fputc, lvm_fputs, lvm_fflush,
 lvm_fputbn, lvm_sound, lvm_sounds,
 lvm_trayctor, lvm_iota, lvm_rank, lvm_alen, lvm_shape, lvm_atype,
 lvm_bitlen,
 lvm_asum, lvm_aprod, lvm_max, lvm_min, lvm_aall, lvm_aany, lvm_max2, lvm_min2, lvm_floor, lvm_inner, lvm_outer,
 lvm_litp, lvm_hotp,
 lvm_nif,         // emitted bytes -> a native
 lvm_nifx,        // ..with an extras word at Ip+32, GC-walked, so value[1] stays the plain twin
 lvm_calloutdrive, lvm_calloutresume,   // the drive addresses as fixnums (probes)
 lvm_reach_offset,       // g->reach's byte offset, what the emitter loads from
 lvm_natp,        // (nat? f): code in the arena
 lvm_arena,       // (arena 0): the code arena's [mapped bumped free spans]
 lvm_lazy,        // a woken native's entry, until its chunk of the image's code is seated
 lvm_deferfwd,    // a deferred native's code slot until its compile patches it (tablet.c)
 lvm_firstcall;   // ..and a first-call one's, until that call (LOVE_LAZY_GLAZE)
// these carry lvm()'s attributes, so they cannot join the plain list above
love_noinline noicf lvm_t
 lvm_0, lvm_add_seq, lvm_add_string, lvm_addh, lvm_arg0,
 lvm_atype, lvm_bin_a, lvm_bin_b, lvm_bin_unit, lvm_coinp,
 lvm_dieof, lvm_dig, lvm_gemp, lvm_heard, lvm_hotp,
 lvm_mulh, lvm_myself, lvm_nilp, lvm_quo0, lvm_quom1,
 lvm_quotn, lvm_rank, lvm_tabp, lvm_twinp, lvm_worn,
 lvm_vbin, lvm_bdiv_start, lvm_vmap1, lvm_vmap1z, lvm_vmap2, lvm_twin_bin, lvm_cbin, lvm_obin,
 // the data sentinels: byte-identical bodies kept apart by address (noicf)
 data_num_apply, data_sym_apply, data_string_apply, data_pair_apply,
 lvm_sym, lvm_nom, lvm_gembox, lvm_twinbox,
 lvm_big, lvm_tray, lvm_str, lvm_chain,
 lvm_addn, lvm_fquotn, lvm_muln,
 lvm_remn, _lvm_yieldk;
lvm_t lvm_wheel, lvm_turn, lvm_turnf;

// --- strings, noms and mints ---
#define str_type_width (Width(struct str))
// header, bytes, and the NUL
#define str_width(n) (str_type_width + b2w((n) + 1))
static love_inline struct mint *ini_missing(struct mint *y, uintptr_t serial) {
 return y->ap = lvm_sym, y->serial = serial, y; }
static love_inline struct nom *ini_nom(struct nom *y, uintptr_t name, uintptr_t dig) {
 return y->ap = lvm_nom, y->name = name, y->dig = dig, y; }
static love_inline struct str *ini_str(struct str *s, uintptr_t len) {
 s->ap = lvm_str, s->len = len;
 ((word*) s->bytes)[b2w(len + 1) - 1] = 0;   // tail word first: pad and NUL stay zero under the fill
 return s; }
static love_inline struct chain *ini_chain(struct chain *w, intptr_t a, intptr_t b) {
 return w->ap = lvm_chain, w->a = a, w->b = b, w; }
word intern_checked(struct g*, struct str*);
uintptr_t intern_reserve(struct g*);
struct str *nom_str(struct g *g, word x);   // a nom's name, else 0
static love_inline struct str *bytes_of(word x) { return caskp(x) ? cask(x)->str : str(x); }
// a cask's str, or NULL for anything else
static love_inline struct str *cask_str(word x) { return caskp(x) ? cask(x)->str : NULL; }
// a cask's bytes, 8-aligned to hold a C state, and their count; NULL for anything else
static love_inline uint8_t *cask_bytes(word x, uintptr_t *n) {
 struct str *s = cask_str(x);
 return s && !((uintptr_t) s->bytes & 7) ? (*n = s->len, (uint8_t*) s->bytes) : NULL; }

// --- numbers ---
#define isnum(x) (charmp(x) || gemp(x) || bigp(x))
#define intp(x) (charmp(x) || bigp(x))
// no floats; a magnitude past the word truncates to its low word, as a tray cell takes
#define toint(x) (charmp(x) ? (intptr_t) getcharm(x) : wbig_get(x))
#define toflo(x) (charmp(x) ? (flo_t) getcharm(x) : gemp(x) ? gem_get(x) : big_to_flo(x))
#define twin_req Width(struct twin)
#define mincharm (INTPTR_MIN >> 1)
#define maxcharm (INTPTR_MAX >> 1)
// a result into r, a fixnum when it fits; under Have(box_req), no &local, so the tail call stays
#define emit_int(r, R) do { intptr_t _r = (R); \
 if (_r >= mincharm && _r <= maxcharm) r = putcharm(_r); \
 else r = mk_wbig(&Hp, _r); } while (0)
#define emit_gem(r, R) do { r = mk_gem(&Hp, (R)); } while (0)
// love's `sun`: raw limbs, moved by memcpy as a thread walk would misread them. slen the
// signed limb count, little-endian, top limb nonzero; never 0, as zero demotes
struct big { lvm_t *ap; intptr_t slen; love_limb limb[]; };
static love_inline bool bigp(word _) { return evenp(_) && cell(_)->ap == lvm_big; }
static love_inline struct big *ini_big(struct big *b, intptr_t slen) {
 return b->ap = lvm_big, b->slen = slen, b; }
uintptr_t big_bytes(struct big*);
// a magnitude into the smaller tier, bumping *hp when it boxes
word big_canon(word **hp, love_limb const *limb, int n, bool neg);
flo_t big_to_flo(word);
int big_cmp(word, word);
intptr_t love_mint_cmp(struct g*, word, word); // () < bare mints < names
bool numband(struct g*, word);            // orders as a number (cmp_rank 2)
intptr_t love_cmp3(struct g*, word, word);     // the order sort and < share
void love_fault_note(int, void*);              // a fault no handler owns (main.c)
struct g
 *big_binop(struct g*, int vop),  // vop_add..vop_rem; each pops one operand
 *big_bitop(struct g*, int vop),  // two's complement
 *big_shift(struct g*, int vop),  // promoting and flooring
 *big_quot_true(struct g*),       // `/`: exact when b | a, else a float
 *big_read_dec(struct g*),        // sp[0] token -> canonical value
 *big_read_hex(struct g*),
 *big_read_oct(struct g*);
static love_inline bool gemp(word _) { return evenp(_) && cell(_)->ap == lvm_gembox; }
static love_inline bool twinp(word _) { return evenp(_) && cell(_)->ap == lvm_twinbox; }
// the lean scalar boxes, GC leaves copied like bignums
struct gem { lvm_t *ap; union { word w; flo_t d; }; };
#define gem_req Width(struct gem)
#define gem(_) ((struct gem*)(_))
#define wbig_req b2w(sizeof(struct big) + wlimbs * sizeof(love_limb))   // a word-sized magnitude
#define box_req (gem_req > wbig_req ? gem_req : wbig_req)
struct twin { lvm_t *ap; union { word re; flo_t dre; }; union { word im; flo_t dim; }; };
#define twin(_) ((struct twin*)(_))
// payloads through the union, never a stack temporary, whose address costs a caller its sibcalls
_Static_assert(sizeof(flo_t) == sizeof(uintptr_t), "float box assumes flo_t is pointer-width");
static love_inline flo_t gem_get(word x) { return ((struct gem*) x)->d; }
// the one float box-write, under Have(gem_req): NaN collapses to () so the order stays total;
// glaze's lanes emit the same collapse
static love_inline word mk_gem(word **hpp, flo_t v) {
 if (v != v) return ZeroPoint;
 struct gem *f = (struct gem*) *hpp;
 *hpp += gem_req;
 f->ap = lvm_gembox;
 f->d = v;
 return word(f); }
static love_inline flo_t twin_re(word x) { return ((struct twin*) x)->dre; }
static love_inline flo_t twin_im(word x) { return ((struct twin*) x)->dim; }
static love_inline void twin_set(struct twin *v, flo_t re, flo_t im) {
 v->dre = re, v->dim = im; }
static love_inline word mk_twin(word **hpp, flo_t re, flo_t im) {
 struct twin *v = (struct twin*) *hpp;
 *hpp += twin_req;
 v->ap = lvm_twinbox;
 twin_set(v, re, im);
 return word(v); }
// the low word of a boxed integer, two's complement: mod 2^w past a word, as a tray cell takes
static love_inline intptr_t wbig_get(word x) {
 struct big *b = (struct big*) x;
 intptr_t sl = b->slen;
 int n = (int) (sl < 0 ? -sl : sl);
 uintptr_t u = 0;
 for (int i = 0; i < n && i < wlimbs; i++) u |= (uintptr_t) b->limb[i] << (limb_bits * i);
 return (intptr_t) (sl < 0 ? (uintptr_t) 0 - u : u); }
// a word past the charm range as a bignum, under Have(wbig_req); never 0, as callers demote
static love_inline word mk_wbig(word **hpp, intptr_t v) {
 struct big *b = (struct big*) *hpp;
 bool neg = v < 0;
 uintptr_t m = neg ? (uintptr_t) 0 - (uintptr_t) v : (uintptr_t) v;   // |INTPTR_MIN| survives unsigned
 int n = wlimbs;
 for (int i = 0; i < wlimbs; i++) b->limb[i] = (love_limb) (m >> (limb_bits * i));
 while (n > 1 && b->limb[n-1] == 0) n--;
 ini_big(b, neg ? -n : n);
 *hpp += b2w(sizeof(struct big) + (size_t) n * sizeof(love_limb));
 return word(b); }
// love admits no irreflexive value: = reads two NaNs as one
static love_inline bool same_flo(flo_t a, flo_t b) { return a == b || (a != a && b != b); }
// truncation toward zero and float remainder, no libm
static love_inline flo_t love_trunc(flo_t x) {
 if (x != x) return x;
 flo_t m = x < 0 ? -x : x;
 if (m > (flo_t) 9.22e18) return x;
 return (flo_t) (int64_t) x; }
static love_inline flo_t love_fmod(flo_t a, flo_t b) {
 return a - love_trunc(a / b) * b; }
// the math lvms' function argument, in g->b
typedef flo_t (*flo1)(flo_t);
typedef flo_t (*flo2)(flo_t, flo_t);

// --- trays ---
// a word per element. C is the rank-0 complex pair; Z < R < C, so >= love_R is the float test.
// O slots hold live words, traced per element, dispatched through lvm_obin
enum tray_type { love_Z, love_R, love_C, love_O, };
// lvm_vbin's ops: >= vop_lt make a 0/1 mask (vop_eq table-shared only: tray_eq answers =)
enum vop { vop_add, vop_sub, vop_mul, vop_quot, vop_rem, vop_fquot,
           vop_band, vop_bor, vop_bxor, vop_bsl, vop_bsr, vop_max, vop_min,
           vop_lt, vop_le, vop_gt, vop_ge, vop_eq, };
static love_inline bool trayp(word _) { return packp(_) && tray(_)->rank >= 1; }
static love_inline bool galaxyp(word _) { return trayp(_) && tray(_)->type != love_O; }
static love_inline bool objtrayp(word _) { return trayp(_) && tray(_)->type == love_O; }
// FIXME a max rank is not on purpose
#define maxrank 8   // bounds the broadcast loop's stack arrays
extern size_t const
 vt_[],                 // element bytes by tray_type
 love_T[];                   // the same, for lvm_gauge before its definition
// the row-major payload, past the shape words
static love_inline void *tray_data(struct tray *v) { return (void*) (v->shape + v->rank); }
static love_inline uintptr_t tray_nelem(struct tray *v) {
 uintptr_t n = 1;
 for (uintptr_t i = 0; i < v->rank; i++) n = mulsat(n, v->shape[i]);
 return n; }
static love_inline struct tray *ini_tray(struct tray *v, enum tray_type t, uintptr_t rank) {
 return v->ap = lvm_tray, v->type = t, v->rank = rank, v; }
// a count no heap holds answers past words_max, which the allocator refuses
static love_inline uintptr_t tray_bytes(enum tray_type t, uintptr_t R, uintptr_t n) {
 if (n >= words_max) return (words_max + 1) * sizeof(word);
 return sizeof(struct tray) + R * sizeof(word) + n * love_T[t]; }
static love_inline flo_t tray_get_flo(struct tray *v, uintptr_t i) {
 void *p = tray_data(v);
 return v->type == love_R ? ((flo_t*) p)[i] : (flo_t) ((intptr_t*) p)[i]; }
static love_inline intptr_t tray_get_int(struct tray *v, uintptr_t i) {
 void *p = tray_data(v);
 return v->type == love_R ? (intptr_t) ((flo_t*) p)[i] : ((intptr_t*) p)[i]; }
static love_inline void tray_put_int(struct tray *v, uintptr_t i, intptr_t x) {
 void *p = tray_data(v);
 if (v->type == love_R) ((flo_t*) p)[i] = (flo_t) x; else ((intptr_t*) p)[i] = x; }
static love_inline void tray_put_flo(struct tray *v, uintptr_t i, flo_t x) {
 void *p = tray_data(v);
 if (v->type == love_R) ((flo_t*) p)[i] = x; else ((intptr_t*) p)[i] = (intptr_t) x; }
static love_inline word tray_get_obj(struct tray *v, uintptr_t i) {
 return ((word*) tray_data(v))[i]; }
static love_inline void tray_put_obj(struct tray *v, uintptr_t i, word x) {
 ((word*) tray_data(v))[i] = x; }
// x at element i in v's tier; false for a non-number into a numeric tray. v is fresh: no barrier
static love_inline bool tray_put(struct tray *v, uintptr_t i, word x) {
 if (v->type == love_O) return tray_put_obj(v, i, x), true;
 if (v->type == love_C) {
  flo_t *fp = tray_data(v);
  if (twinp(x)) fp[2*i] = twin_re(x), fp[2*i+1] = twin_im(x);
  else if (isnum(x)) fp[2*i] = toflo(x), fp[2*i+1] = 0;
  else return false;
  return true; }
 if (!isnum(x)) return false;
 if (v->type >= love_R) tray_put_flo(v, i, toflo(x));
 else tray_put_int(v, i, gemp(x) ? (intptr_t) gem_get(x) : toint(x));
 return true; }
uintptr_t bshape(word a, word b, uintptr_t *R);
void bshape_put(uintptr_t *shape, uintptr_t R, word a, word b),
     bstride(struct tray *v, uintptr_t R, intptr_t *c);
flo_t vop_flo(int op, flo_t a, flo_t b);
// the broadcast odometer, rightmost axis fastest, carrying each operand's offset by its stride
// (0 on a size-1 axis); in the fill's frame, so an lvm wrapper stays a leaf
struct bcast { uintptr_t R; uintptr_t const *shape; intptr_t oa, ob, ca[maxrank], cb[maxrank], idx[maxrank]; };
static love_inline void bc_open(struct bcast *w, struct tray *va, struct tray *vb,
                              uintptr_t R, uintptr_t const *shape) {
 w->R = R, w->shape = shape, w->oa = w->ob = 0;
 for (uintptr_t j = 0; j < R; j++) w->idx[j] = 0;
 bstride(va, R, w->ca), bstride(vb, R, w->cb); }
static love_inline void bc_step(struct bcast *w) {
 for (intptr_t j = (intptr_t) w->R - 1; j >= 0; j--) {
  if (++w->idx[j] < (intptr_t) w->shape[j]) { w->oa += w->ca[j], w->ob += w->cb[j]; return; }
  w->idx[j] = 0, w->oa -= ((intptr_t) w->shape[j] - 1) * w->ca[j], w->ob -= ((intptr_t) w->shape[j] - 1) * w->cb[j]; } }

// --- maps ---
// a map: a fixed header [lvm_map_lookup, backing, serial, tag] and an open-addressed backing
// [lvm_map_data, len, cap, k,v.., tag] that growth swaps, so aliases see later inserts. both
// plain threads, empty slots map_gap. mutable, so the serial is its order, never its contents
lvm_t lvm_map_lookup, lvm_map_data;
static love_inline bool tabp(word _) { return evenp(_) && cell(_)->ap == lvm_map_lookup; }
extern const word map_gap_cell;
#define map_gap ((word) &map_gap_cell)
#define map_min_cap 4
// serial, len and cap are charms, so gc scans both as threads
struct tablet { lvm_t *ap; word back, serial; };
struct tablet_back { lvm_t *ap; word len, cap, slot[]; };   // slot: cap k,v pairs
#define tablet(_) ((struct tablet*)(_))
#define tablet_back(_) ((struct tablet_back*)(_))
enum { map_head = sizeof(struct tablet) / sizeof(word) + 1 };   // tag included
static love_inline uintptr_t map_back_words(uintptr_t cap) { return Width(struct tablet_back) + 1 + 2 * cap; }
static love_inline word map_back(word m) { return tablet(m)->back; }
static love_inline uintptr_t map_serial(word m) { return getcharm(tablet(m)->serial); }
static love_inline word *map_slots(word m) { return tablet_back(map_back(m))->slot; }
static love_inline uintptr_t map_len(word m) { return getcharm(tablet_back(map_back(m))->len); }
static love_inline uintptr_t map_cap(word m) { return getcharm(tablet_back(map_back(m))->cap); }
static love_inline void map_len_set(word m, uintptr_t n) { tablet_back(map_back(m))->len = putcharm(n); }
word
 mapget(struct g*, word, word, word),
 stacklook(struct g*, word, word),
 stacklook_macro(struct g*, word);
struct g *mapput(struct g*), *map_new(struct g*);
union u *map_fill_back(union u*, uintptr_t);

// --- coins ---
// a typed hot [lvm_coin, kind, payload], a plain thread on the KHot row (lvm_addh/mulh). the
// kind a tablet keyed by g->knom, a named one in g->kreg
struct coin { lvm_t *ap; word kind; word payload; };
static love_inline bool coinp(word _) { return evenp(_) && cell(_)->ap == lvm_coin; }
static love_inline word coin_kind(word x) { return ((struct coin*) x)->kind; }
static love_inline word coin_load(word x) { return ((struct coin*) x)->payload; }
// the kind table's keys: closures run in the VM. absent, net is the payload's, < and = the
// coin band then the payload (a map key or sort reads the payload regardless), int and ceil
// the measure's. star truthy: a numeral powers through its *. KnLambda on: `kind`'s answers
enum { KnName, KnAdd, KnMul, KnApply, KnSub, KnNet, KnStar, KnDiv,
       KnPayload, KnLt, KnEq, KnInt, KnCeil, KnLambda, KnCask, KnPort, KnCoin, KnN };
// a kind table's slot, () if absent or not a tablet
static love_inline word kind_get(struct g *g, word kind, intptr_t i) {
 return tabp(kind) ? mapget(g, ZeroPoint, core_of(g)->knom[i], kind) : ZeroPoint; }

// --- truth and equality ---
// x is false iff its net's real part is not positive. the net is complex and additive, so a
// sum cannot short-circuit: a later negative cancels
flo_t net_re(word), net_im(word);             // x must be leafp
intptr_t love_count(struct g *, word);           // tally's C body
_lvm(lvm_measure);                              // Sp[0] measured by love, the op re-run
_lvm(lvm_coin_rung);                            // the coin through its kind's slot g->b, the op re-run
word nif_word(char const *);                 // by roster name, 0 for none
// a leaf C nets itself; a chain, an object tray or a coin love nets
static love_inline bool leafp(word x) {
  if (charmp(x)) return true;
  if (coinp(x)) return false;
  if (!datp(x)) return true;
  return typ(x) != DChain && (typ(x) != DTray || tray(x)->type != love_O); }
// a compound goes through lvm_measure first
static love_inline bool leaf_nilp(word x) {
  if (charmp(x)) return getcharm(x) <= 0;
  if (mintp(x)) return true;
  return net_re(x) <= 0; }
love_noinline bool eqv(struct g*, word, word); // non-identical values
// identity is the whole equality of charms and noms, so eql settles them inline
static love_inline bool eql(struct g *g, word a, word b) {
 return a == b ? true : (a & b & 1) || (nomp(a) && nomp(b)) ? false : eqv(g, a, b); }

// --- the collector ---
// the rem set's capacity in words
#define LvRemCap (1u << 12)
// a thread ends with a tag word, its head pointer | 2; an external pointer may carry the bits,
// never into the pool
#define thread_tag 2
static love_inline bool tagp(word x, word const *lo, word const *hi) {
 word const *p = (word const*) (x & ~(word) 3);
 return (x & 3) == thread_tag && p >= lo && p < hi; }
// the pools a heap pointer may live in between collections
static love_inline bool in_live_pool(struct g *g, word const *p) {
 if (p >= ptr(g) && p < ptr(g) + g->len) return true;
 return p >= g->major_base && p < g->major_base + g->major_len; }
static love_inline union u *tagthread(union u *h, uintptr_t len) {
  return h[len].x = word(h) | thread_tag, h; }
// a tablet's header at h over backing b, tagged: the word callers hold
static love_inline word ini_tablet(union u *h, word b, word serial) {
 struct tablet *t = tablet(h);
 t->ap = lvm_map_lookup, t->back = b, t->serial = serial;
 return word(tagthread(h, Width(struct tablet))); }
#define topof(g) ((word*)g+g->len)
static love_inline struct tag { union u *head; union u end[]; } *ttag(struct g*g, union u *k) {
 // k forward to its terminator, in whichever pool holds it
 word *lo, *hi;
 if (ptr(k) >= g->major_base && ptr(k) < g->major_hp) lo = g->major_base, hi = g->major_hp;
 else lo = ptr(g), hi = topof(g);
 while (!tagp(k->x, lo, hi)) k++;
 return (struct tag*) k; }
static love_inline union u *tag_head(struct tag *t) {
 return cell(word(t->head) & ~(word) 3); }

// a non-allocating walk's scratch, the free room [hp, sp): true only if its vm op packed first
static love_inline word *gap(struct g *g, word **top) {
#ifdef LvGcCheck
 if (g->unpacked) __builtin_trap();
#endif
 return *top = g->sp, g->hp; }

// --- stack and op helpers ---
static love_inline struct g *pushq(struct g*g) { return intern(strof(g, "\\")); }
static love_inline struct g *push0(struct g*g) { return push(g, 1, zero); }
static love_inline size_t llen(word l) {
 size_t n = 0;
 while (chainp(l)) n++, l = B(l);
 return n; }
static love_inline struct g*pop(struct g*g, uintptr_t n) {
 return core_of(g)->sp += n, g; }
#define avm_unit(a, b) \
 if (mintp(a) || mintp(b)) love_musttail return Push(ZeroPoint)
#define cmp_lt(nom, vop) lvm(nom) { \
 word a = Sp[0], b = Sp[1]; \
 if (__builtin_expect(charmp(a) && charmp(b), 1)) { \
  intptr_t r = vcmp_int(vop, a, b); \
  if (Ip[1].ap == lvm_cond) { Sp += 2; Ip = r ? Ip + 3 : Ip[2].m; love_musttail return Continue(); } \
  love_musttail return Push(r ? putcharm(1) : zero); } \
 g->b = (word) (vop); love_musttail return Ap(lvm_cmp_ord, g); }

// --- tasks ---
// the running task heads the run ring, a node [next, ip, pid, wake at, wait fd, events, help,
// stdio, stack..]; help and stdio are hooks 5 and 6
static love_inline word *task_help(struct g *g) { return &g->tasks[6].x; }
static love_inline word *task_io(struct g *g) { return &g->tasks[7].x; }
#define yield_interval 64
// fairness yields between parked sweeps: a sweep is a syscall, a yield is not
#define sweep_interval 16
// clears a stale park intention first, as lvm_fgetc leaves the fd on a read; g->parked too,
// as a server with every client blocked leaves a self-ring
#define YieldCheck() \
  if (__builtin_expect((g->tasks->m != g->tasks || g->parked) && ++g->yield_ctr >= yield_interval, 0)) \
    { g->next_wait_fd = -1; g->next_wake_at = 0; love_musttail return Ap(lvm_yield_sw, g); }

// the seam between translation units: anything not named here is static to its file
// def1 for the image codec; a count, as an extern array has no complete type
extern struct def const *const love_def1;
extern uintptr_t const def1_n;
extern union u const callout_drive[], callout_resume[];
extern union u const yield_c[];
struct bio *bio_of(struct g *g, struct io *i);
char *code_install(struct g *g, char const *src, size_t n), *code_adopt(struct g *g, char const *src, size_t n),
     *code_lazy(struct g *g, size_t n, unsigned char const *z, size_t nz, unsigned char const *tab, uintptr_t nch,
                unsigned char const *dz, size_t ndz, size_t nd, int kept);
int code_seat(struct g *g, char const *a);
uint64_t image_sum(void const *p, uintptr_t n, uint64_t h);
char *code_window(char *p);
void code_free(struct g *g, char *code), code_fin(struct g *g);
uintptr_t code_stat(struct g *g, int i);
int code_in(struct g *g, uintptr_t v);
// the instruction table (snap.c): word <-> index, negative not one, address 0 no such index
intptr_t op_index(intptr_t ap), op_resolve(intptr_t i), def_index(intptr_t x), fn_nif(intptr_t f);
intptr_t image_seat(word v);   // an out-of-pool word's image index, -1 none

// a cell as a value, or () for the machine's own words: a terminator, an instruction, a glazed
// body. a pool pointer is asked first, keeping the table scan off the common peek
static love_inline word cellval(struct g *g, word w) {
 if ((w & 3) == thread_tag) return ZeroPoint;
 if (evenp(w) && in_live_pool(g, ptr(w))) return w;
 return op_index((intptr_t) w) >= 0 || w == (word) lvm_lazy || (evenp(w) && code_in(g, (uintptr_t) w))
  ? ZeroPoint : w; }
int nif_cell(union u const *k);
// love_once lays the tables before the first g, 0 when it could not
int love_once(void), ops_fill(void);
size_t code_len(char *code);
// g->reach's slots: the emitter's `reach` law names them the same
enum { ReachChain, ReachStr, ReachMap, ReachNom, ReachMint, ReachGem, ReachCask, ReachDrive, ReachResume, ReachCur, ReachUnc, ReachGap };
union u *fn_base(union u *k, int *nargs);
struct g
 *eval(struct g *g),
 *ioputc(struct g*g, int c),
 *ioputs(struct g*g, char const *s),
 *gen_grow(struct g *g, uintptr_t len1),
 *gen_major(struct g *g, uintptr_t req0, bool *tight),
 *ored(struct g *g, int kind), *zflush(struct g*g);
uintptr_t
 hash_at(struct g *g, intptr_t x, word *base, word *end),
 map_probe(struct g *g, word m, word k, bool *found);
struct str *seq_cat(struct g *g, void *w, word a, word b);
intptr_t
 fn_arg(union u *k, int i, int nargs),
 fn_meaning(struct g *c, word x),
 vcmp_flo(int op, flo_t a, flo_t b),
 vcmp_int(int op, intptr_t a, intptr_t b),
 io_route(struct g *g, word x),
 hot_hook(word h);
void
 gen_wb(struct g *g, word src, word p),
 gen_wb_cell(struct g *g, void *cl, word v);
int hash_leaf(struct g *g, word x, uintptr_t *out, word *src);
bool
 bio_rpending(struct bio *b),
 wait_buffered(struct g *g, lvm_t *ap, word x, int fd),
 fn_partialp(union u *k),
 fn_carrier(union u *k),
 in_heap(struct g *c, word x),
 iop(word x),
 lam_isp(struct g *g, word x);
#endif

