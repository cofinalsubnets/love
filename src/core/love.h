#ifndef _love_h
#define _love_h
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdarg.h>

#define Width(_) b2w(sizeof(_))
#define ai_core_of(ai_) ((struct ai*)((intptr_t)(ai_)&~(sizeof(intptr_t)-1)))
#define ai_code_of(g) ((enum ai_status)((intptr_t)(g)&(sizeof(intptr_t)-1)))
#define ai_ok(g) (ai_code_of(g) == ai_status_ok)

#define putcharm(_) ((ai_word)(((uintptr_t)(ai_word)(_)<<1)|1))
#define getcharm(_) ((ai_word)(_)>>1)

#ifndef EOF
#define EOF (-1)
#endif

#ifndef NAN
#define NAN (__builtin_nanf(""))
#endif

#define ai_zero putcharm(0)
#define ai_inline inline __attribute__((always_inline))
#define ai_noinline __attribute__((noinline))
// no identical-code-folding: the data sentinels' bodies are byte-identical but
// their address is the type tag (gcc -Os runs -fipa-icf)
#if defined(__GNUC__) && !defined(__clang__)
#define ai_noicf __attribute__((noipa))
#else
#define ai_noicf
#endif
// ai_data_section / ai_data_stride / ai_data_n ride kinds.h below, laid by mx.l
// beside the enum d roster they are a layout of
#define ai_digits "0123456789abcdefghijklmnopqrstuvwxyz"
#define countof(_) (sizeof(_)/sizeof(*_))

#ifndef ai_tco
#define ai_tco 1
#endif

// musttail IS the tail-threaded vm: without it every dispatch keeps its frame and a
// long read overflows the stack, so tco=1 without it is not slower, it is broken.
// refuse rather than ship it, and name the lane that works -- tco=0 is the trampoline.
#if defined(__mooncc__) || defined(__clang__) || (defined(__GNUC__) && __GNUC__ >= 15)
#define ai_have_musttail 1
#else
#define ai_have_musttail 0
#endif
#if ai_tco && !ai_have_musttail
#error "no musttail: build -Dai_tco=0"
#endif

// port read-buffer size in bytes (the one buffered-io knob)
#ifndef ai_iobuf
#define ai_iobuf 4096
#endif

#if ai_tco
#define _lvm(n) struct ai *n(struct ai *restrict g, union u *Ip, ai_word *Hp, ai_word *restrict Sp)
#define Ap(fn, g) fn(g, Ip, Hp, Sp)
#define Continue() Ap(Ip->ap, g)
// the stepped/answering tails as bare calls (ai_musttail's operand may not be a comma):
// Next steps n cells, Nextp also pops k, Answer stores v at the top, Answerp under a pop
// of k, Push opens a fresh slot, Resume re-reads the packed g. the store rides inside the
// Sp argument, sequenced by its own comma, so v must not touch Hp or Ip -- sibling
// arguments, unsequenced: such a site stores first, then `ai_musttail return Next(1);`.
// n and k evaluate twice: literals only.
#define Next(n) Ip[n].ap(g, Ip + (n), Hp, Sp)
#define Nextp(n, k) Ip[n].ap(g, Ip + (n), Hp, Sp + (k))
#define Answer(v) Ip[1].ap(g, Ip + 1, Hp, (Sp[0] = (v), Sp))
#define Answerp(k, v) Ip[1].ap(g, Ip + 1, Hp, (Sp[k] = (v), Sp + (k)))
#define Push(v) Ip[1].ap(g, Ip + 1, Hp, (*++Sp = (v), Sp))
#define Resume() g->ip->ap(g, g->ip, g->hp, g->sp)
#define Pack(g) (g->ip = Ip, g->hp = Hp, g->sp = Sp)
#define Unpack(g) (Ip = g->ip, Hp = g->hp, Sp = g->sp)
// every VM tail spells `ai_musttail return ..` and every compiler is held to the jump:
// clang/gcc 15+ take the attribute, mooncc's sibcall pass spells it or refuses the
// compile -- an opportunistic miss is one frame per dispatch and a stack overflow down
// some long read. `make vmret` cross-checks the shipped binary.
// ⚠ AN LVM TAKES NO OTHER ARGUMENT, and the macros above cannot spell one: musttail
// wants matching prototypes, so a fifth parameter would leave that op's tails to the
// compiler's mood. what an op needs beyond the stack rides g->b, read at entry.
// ai_tco=1 now IMPLIES ai_have_musttail -- the refusal above makes that structural,
// so there is no opportunistic lane left to fall into here.
#define ai_musttail __attribute__((musttail))
#if defined(__GNUC__) && !defined(__clang__)
// gcc's "maybe" escape lint: an address-taken local handed to an earlier helper trips
// it, and the no-scratch-in-lvm_ discipline already forbids a frame address outliving its call
#pragma GCC diagnostic ignored "-Wmaybe-musttail-local-addr"
#endif
#else
#define _lvm(n) struct ai *n(struct ai *restrict g)
#define Ap(fn, g) fn(g)
#define Continue() g
#define Next(n) (Ip += (n), g)
#define Nextp(n, k) (Sp += (k), Ip += (n), g)
#define Answer(v) (Sp[0] = (v), Ip += 1, g)
#define Answerp(k, v) (Sp[k] = (v), Sp += (k), Ip += 1, g)
#define Push(v) (*++Sp = (v), Ip += 1, g)
#define Resume() g
#define ai_musttail
#define Hp g->hp
#define Sp g->sp
#define Ip g->ip
#define Pack(g) ((void)0)
#define Unpack(g) ((void)0)
#endif
#define lvm(n) ai_noinline ai_noicf _lvm(n)
// the pack/call/unpack most nifs wear: hand the stack to a C helper that may collect
// (any arguments past g ride along), ghelp a not-ok answer, then the tail: LvmCall takes
// the stack back and steps one; LvmCallp also lifts the answer over k operands; LvmResume
// re-enters where the helper pointed g->ip. LvmWrap is the whole op where the body is
// nothing but an LvmCall.
#define LvmPack(g, f, ...) \
 Pack(g); if (!ai_ok(g = f(g, ##__VA_ARGS__))) ai_musttail return Ap(_lvm_ghelp, g)
#define LvmCall(g, f, ...) { LvmPack(g, f, ##__VA_ARGS__); Unpack(g); ai_musttail return Next(1); }
#define LvmCallp(g, k, f, ...) { LvmPack(g, f, ##__VA_ARGS__); Unpack(g); Sp[k] = Sp[0]; ai_musttail return Nextp(1, k); }
#define LvmResume(g, f, ...) { LvmPack(g, f, ##__VA_ARGS__); ai_musttail return Resume(); }
#define LvmWrap(n, f) lvm(n) LvmCall(g, f)

typedef intptr_t ai_word;

union u;
typedef _lvm(lvm_t);

// typed n-dim array; rank 0 = scalar (no shape words); payload at shape+rank; immutable
struct ai_tray {
 lvm_t *ap;
 uintptr_t type, rank, shape[]; };

// status rides the 2 pointer tag bits: bit 0 scare, bit 1 more input wanted; eof = both
enum ai_status { ai_status_ok = 0, ai_status_scare = 1, ai_status_more = 2, ai_status_eof = 3 };

struct ai_str {
 lvm_t *ap;
 uintptr_t len;        // byte count; bytes[len] is always a NUL, so C may read bytes as a string
 char bytes[]; };
// a cask: mutable bytes behind a 2-word wrapper, recognized by ap like ports.
// public so a host nif can wrap a C struct's bytes (src/host/cb.c).
struct ai_cask { lvm_t *ap; struct ai_str *str; };
// a mint: a bare nameless point -- just the hot and its serial
struct ai_mint {
 lvm_t *ap;
 uintptr_t serial; };   // the order key; () is serial 0, every fresh mint ++next_serial
// a nom: a named point, a flat 3-word leaf. interned, so its spelling is its identity
// and its order; dig caches the spelling hash -- content, so bucket order never depends
// on intern history, which is the reproducible-build law.
struct ai_nom {
 lvm_t *ap;
 uintptr_t name, dig; };

struct ai_port_vt;   // the port's kind, in its head; spelled out below

union u {
 lvm_t *ap;
 ai_word x;
 union u *m; };

struct ai {
 union u *ip;
 ai_word *hp, *sp;
 union u *tasks,  // running tasks; the head is the running one, [6]/[7] its help and stdio
         *parked; // paused tasks
 uint16_t yield_ctr,   // cycles since last cooperative yield
          sweep_ctr;   // fairness yields since the last parked sweep;
 int next_wait_fd,     // fd the task suspended on, -1 = not waiting on I/O
     next_wait_events; // ai_wait_in (the default) or ai_wait_out (connect's handshake)
 // the VM's one word-size scratch: what the last port refill left (a byte, EOF, or
 // IoWouldBlock), what a write door landed, and the word count a Have() asks lvm_gc for.
 // the three never overlap, and the rule that keeps it so: deposit b as the last act
 // before the return that hands it back, so nothing allocates before the read.
 ai_word b;
 ai_word inflag;       // fd 0's flags as we found them (a charm), 0 = we left them alone
 uintptr_t next_serial, // mint id counter
           next_wake_at; // deadline for next yield_sw snapshot's wake_at slot; 0 = always runnable
 ai_word symbols;       // intern map (string -> canonical atom), swept each gc
 uintptr_t len;         // main-pool size in words: the core sits at its base, [end,hp) is the young heap
 struct ai_r { ai_word *x; struct ai_r *n; } *root; // gc roots list
 struct ai_fz { // finalizers
  union u *p;
  void (*fn)(struct ai*, void *);
  struct ai_fz *next; } *fz;
 // the native code arena (love.c): chunks of pages the glaze installs into, RX between
 // installs; cfree holds the blobs whose closures died. an image carries the live blobs
 // and wakes them as a chunk of their own.
 struct ai_code *code;
 struct ai_cfree *cfree;
 // what a native reads off g instead of carrying: the kind sentinels and the callout
 // drives are addresses of this binary, and a blob that held one could not ride an
 // image. jk_ini fills it; the emitter's `jk` law names the slots.
 ai_word jk[12];
 void *(*alloc)(struct ai*, void*, size_t); // alloc(g,p,n): n>0 reserve n bytes (p ignored), n==0 free p; -> block or NULL
 uintptr_t n_gc, max_len, max_heap, // gc instrumentation (cycles, peak pool len, peak live heap; words)
           n_seen, n_evac;          // Σ per collection: occupancy entering / survivors copied.
                                    // mortality = (n_seen-n_evac)/n_seen; copy-amp = n_evac/max_heap
 // the remembered set, which is the whole write barrier: old cells that took a young
 // pointer, rescanned by the next minor. rem_miss counts drops on overflow -- any miss
 // forces the next collection major, so a minor only runs under a complete set.
 ai_word *rem;
 uint32_t rem_n, rem_hi, rem_miss;   // all three bounded by AiRemCap, the fixed capacity
 // the sub-word collector scalars, adjacent so both ride the rem set's tail
 bool gc_gen;                             // set during a collection: gbump() targets major_hp, not hp
 int8_t lean;                             // resize-stickiness streak (+grow/-shrink); a resize needs |lean| >= 2
                                          // (a resize is a full copy + a total refault)
 // the two pools: the main pool is pure minor, the young heap being [end, hp); old lives
 // in major_pool, its own two-space. a minor evacuates young -> the major active half; a
 // major drains both, compacts into the spare half, flips, rebuilds symbols, runs
 // finalizers. the ranges the pass itself walks are `struct ai_gcx`, on the collector's
 // own C stack (src/core/love.c).
 ai_word *major_pool, *major_base, *major_hp;   // major: malloc base (2*major_len words), active-half base, active bump
 uintptr_t
   major_len,                     // major half size (words)
   n_minor,                       // minor collections so far (majors = n_gc - n_minor)
   minor_hi, major_hi,            // the pause gauge: peak words one minor / one major copied
                                  // (gauge[14]/[15]; test/host/gcpause.l puts wall ns against them)
   since_major, major_live0,      // young words scanned since the last major; major live right
                                  // after it. a major fires once since_major > major_live0 +
                                  // 4*minor-pool, so tenured garbage sweeps and the pool can shrink
   win_alloc, win_copied,         // sliding window (words) for the deterministic minor-resize ratio:
                                          // overhead = copied/alloc; reset on a resize (ai_please)
   n_resize,                      // pool reallocations so far -- gauge[13]; catches pool-cliff contamination
   budget,                     // total memory cap in words (2*minor + 2*major); 0 = unbounded.
                                            // appel's rule: the nursery gets the free budget after the major pool.
   minor0, major0, ratio;         // the other three live knobs: nursery floor, the major pool's
                                          // grow/shrink step, the copy-overhead setpoint. seeded at
                                          // ai_ini from ai_minor0/ai_major0/ai_gc_ratio; `tune` moves
                                          // all four. untraced: a bake does not carry them.
 union {
  intptr_t v0;
  struct {
   ai_word
     book,   // global env map; the macro table is book[zero]. GC-forwarded in v0..end.
     scare_a, scare_b, // the last scare's condition data, stashed at the raise for
     // hooks: lisp functions that C calls
     hot_read,    // 0: the p1 reader
     hot_numap,   // 1: numeric application (church exponentiation)
     hot_stack,   // 2: church addition
     hot_compose, // 3: composition (church multiplication)
     hot_opfix,   // 4: the operator factor pass
                  // 5 the help and 6 the stdio are the running task's, in its node
     hot_show,    // 7: show a value as a string
     mods,        // the module registry book: name -> module-book
     errs,        // errno vocabulary: canonical number -> its nom; ai_err reads it
     kinds,       // the kind roster: enum q row -> its nom (kinds.h); `kind` reads it
     kreg,        // the named kinds: name -> (serial . table), pinned by post.l's `coin`
     knom[16],    // the kind table's keys and the built-in coins' names (the Kn rows)
     inport;      // the buffered stdin port, or 0
   union {
    ai_word x;
    struct ai_io {
     lvm_t *ap;
     struct ai_port_vt const *vt;   // what kind of port this is -- the only answer there is
     ai_word ungetc_buf;            // pushed-back byte; putcharm(EOF) = empty
     // three words: prel's tap/jug poke this layout by index (src/core/boot/prel.l), so a word
     // added here is a renumbering there
    } *io; }; }; };
 intptr_t end[]; };

struct ai_def { char const *n; intptr_t x; };

// host nif auto-registration: AiNif("name", fn) lands the entry in the love_nifs section
// and boot drains [__start_love_nifs, __stop_love_nifs) through ai_defn, so an app adds nifs
// in its own host/<app>.c. no linker script -- the toolchain defines the bracket symbols.
// a nif rides the image as an index off this bracket, so nothing here is ever a kept absolute.
extern struct ai_def const __start_love_nifs[], __stop_love_nifs[];
#define AiNif(nm, fn) \
  static struct ai_def const __attribute__((section("love_nifs"), used)) \
    _ainif_##fn = { (nm), (intptr_t) (fn) }

// port vtable -- what a device owes, and nothing else. a NULL slot means no method
// (no readn reads end, no writen discards). neither blocks the scheduler; the generic
// layer above owns ungetc_buf.
//   writen: land up to n bytes in one motion and answer g, the count in g->b: >0 landed,
//     0 no room now (caller keeps the residue), -1 the device is gone (io_wdrain drops
//     the run). it may allocate, hence g in and g out -- land nothing after an allocating
//     step: grow, answer 0, let the caller re-derive src. only a door whose port keeps a
//     write run may refuse; the static ports cannot park, so their door must land what it
//     takes.
//   readn: drink up to n waiting bytes: >0 bytes, 0 nothing yet (the scheduler owns the
//     wait), -1 end of stream. never allocates, hence frame by value. the end is stable:
//     a spent device owes -1 to every ask, not just the first (test/front/io.l law 3).
//   athand: of the next n bytes, how many are here already -- a source whose text is in
//     memory (a C string, a charlist) counts them without a device. NULL is "ask the
//     device", so a run must come out of a buffer instead. `chug` is the one caller.
struct ai_port_vt {
 struct ai*(*flush)(struct ai*);
 struct ai *(*writen)(struct ai*, unsigned char const*, uintptr_t);
 intptr_t (*readn)(struct ai*, unsigned char*, uintptr_t);
 uintptr_t (*athand)(struct ai*, uintptr_t); };

enum ai_status ai_fin(struct ai*);

static ai_inline size_t b2w(size_t b) {
 size_t q = b / sizeof(ai_word), r = b % sizeof(ai_word);
 return q + (r ? 1 : 0); }

lvm_t lvm_ret0, lvm_cur, lvm_port_io, lvm_help, lvm_cask,
// how a frontend nif parks: set g->next_wake_at (or next_wait_fd), leave Ip
// unadvanced, `return Ap(lvm_yield_sw, g)` -- the op re-runs on reschedule.
      lvm_yield_sw,
// how a frontend nif ends the running task (inle's seated quit, the love-machine
// _exit): stack down to one word (the retval), Ip at a {lvm_task_exit} cell,
// `return Ap(lvm_task_exit, g)` -- catch then reads the retval off the node.
      lvm_task_exit;

// the vtable every port backed by a real OS fd wears; the frontend defines it,
// and its address is what says "there is an fd behind this one" (ai_io_fd).
extern struct ai_port_vt const ai_fd_port_vt;
// what a closed port wears: every door a no-op, and no fd behind it. a frontend
// owning `close` swaps this in -- that swap is the close, there is no other mark.
extern struct ai_port_vt const ai_closed_vt;
// the horn: PCM out as a heap port (src/host/horn.c). it wears the fd port's shape --
// bio_of and ai_io_fd take it as one, so the write run buffers and parks -- and its
// own door, which is where the device lives. the writen is weak here so a link
// without horn.c still stands.
extern struct ai_port_vt const ai_horn_vt;
struct ai *ai_horn_writen(struct ai*, unsigned char const*, uintptr_t);
void ai_horn_shut(struct ai_io*);               // `close` on one: shut the device under it
// the C face of the same device, for a program linked into the image with no love
// heap in hand (src/inle/doom.c reaches k_fb the same way). 16-bit stereo, the rate
// rides the open: open -> 0 | -1 no device; write -> bytes landed, 0 full, -1 gone;
// lag -> frames queued and unplayed. inle's src/inle/hda.c is the body; horn.c
// carries weak refusals for every other link.
int k_horn_open(int rate);
intptr_t k_horn_write(unsigned char const*, uintptr_t);
uintptr_t k_horn_lag(void);
void k_horn_close(void);
// ..and the same face on whichever seat this is: k_horn_* under inle, the host's own
// card otherwise (src/host/horn.c keeps that one open). what src/inle/doomsnd.c calls.
int ai_horn_open(int rate);
intptr_t ai_horn_write(unsigned char const*, uintptr_t);
uintptr_t ai_horn_lag(void);
void ai_horn_close(void);

// close an OS fd backing a heap port; weak no-op default, the host overrides
// with close(2). called by ai_io_alloc's finalizer.
void ai_fd_close(int fd);

// the fd port: the head plus the descriptor. the vt is the license to read it --
// nothing casts here without ai_io_fd, which answers -1 for every port whose door
// is not a device (a tap, a jug, a closed port: all real ports, none with an fd).
struct ai_fio { struct ai_io io; ai_word fd; };
intptr_t ai_io_fd(struct ai_io const*);
// the buffered port: the fd port plus both buffer lanes, private to the generic
// dispatch (prel's tap/jug poke the bare shape; static ports stay bare -- nothing
// traces a static). rbuf/wbuf hold an ai_str backing or 0; [rpos,rlen) bounds the
// pending read run, wlen the filled write prefix. GC walks the extension words as
// ordinary thread words.
struct ai_bio { struct ai_fio f; ai_word rbuf, rpos, rlen, wbuf, wlen; };
// the two faces host nifs need (guards inside; both 0/no-op on a bare port):
// pending = bytes waiting in the read buffer; drain pops up to n of them into dst
uintptr_t
 ai_io_pending(struct ai*, struct ai_io*),
 ai_io_read_drain(struct ai*, struct ai_io*, unsigned char*, uintptr_t),
// unread moves the position inside the run and answers how many bytes moved: n > 0 gives
// back, n < 0 takes; the borrowed run counts, so stdin's seek-back sees it. signed because
// relative does not compose -- a caller that gave back must step forward again.
 ai_io_unread(struct ai*, struct ai_io*, intptr_t),
 ai_io_wpending(struct ai*, struct ai_io*);  // ... and what the device would not take.
struct ai
 *ai_io_wflush(struct ai*, struct ai_io*),   // try to push the write run out
// close and seal call the pair: wflush, then park on a nonzero wpending (see
// lvm_yield_sw). neither may shut the fd on a residue -- a truncated stream.
 *ai_io_alloc(struct ai *g, int fd);
// raw bytes at an fd with no g machinery -- the GC-context finalizer drains a
// dying port through it. weak no-op default; the host overrides with write(2).
void ai_fd_drain(int fd, void const*, uintptr_t);

// the raw-fd lanes (src/host/fd.c): what an io op does when its operand is a charm
// rather than a port. no buffer, no seat, one motion each, and the port protocol
// on the answer -- >0 landed, 0 busy, -1 gone. `say` lands the whole run, waiting.
intptr_t ai_fd_readn(struct ai*, int fd, unsigned char *dst, uintptr_t);
intptr_t ai_fd_writen(int fd, unsigned char const *src, uintptr_t);
uintptr_t ai_fd_say(int fd, unsigned char const *src, uintptr_t);
intptr_t ai_port_fd(ai_word);                         // the fd under a love port, or -1
uintptr_t ai_fd_write_all(int, unsigned char const*, uintptr_t);   // land every byte, waiting

// the seat's other doors, one definition each: src/host/posix.c..
struct ai *ai_argv_marshal(struct ai*, char***);   // argv -> char** in the heap gap
void host_spawn_guard(struct ai*, int);            // exec-bound forks drop the pools
int ai_raw_mode(intptr_t on);                      // the (raw on) latch; main.c's repl too
size_t host_selfpath(char*, size_t);               // the one selfpath door (per-OS ladder)
// ..src/host/image.c, the carried image and the self-bake..
int image_bake(struct ai*), ai_baked_pick(void const **blob, uintptr_t *blen);
struct ai *image_load(char const*), *image_dump(struct ai*, char const*);
extern uint64_t ai_baked_image[];
extern uintptr_t ai_baked_image_len;
// ..src/core/gz.c, and src/host/src.c's own source (weak zero without a blob)
intptr_t ai_inflate_raw(unsigned char const*, uintptr_t, unsigned char*, uintptr_t),
         ai_deflate_raw(struct ai*, unsigned char const*, uintptr_t, unsigned char*, uintptr_t);
extern unsigned char const ai_srcgz[];
extern uintptr_t const ai_srcgz_len;

uintptr_t ai_clock(void); // used by garbage collector
intptr_t ai_nclock(void); // the fine interval clock (ns); weak ms-degraded default in love.c, hosts override with a real ns source
// which kernel underneath (nolibc's os.c: 0 unprobed; 1 linux, 2 freebsd,
// 3 netbsd; NEGATIVE = we ARE the kernel, inle). love.c carries a weak zero
// for seats with no nolibc aboard, where hosted is what zero reads as.
extern long __ai_osv;
void ai_sleep(uintptr_t ticks); // per-frontend deep wait for at most `ticks` ai_clock()
// units (0 = infinite); no input wakeup (parked streams go via ai_wait_fds). default no-op.

struct ai
 *ai_ini(void),
 *ai_ini_m(void*(*)(struct ai*, void*, size_t)),
 *ai_evals(struct ai*, const char*),      // ..keeping the last form's value at sp[0]
 *ai_evals_(struct ai*, const char*),
 *ai_egg_(struct ai*, char const*, char const*, char const*, char const*),  // (egg, p1, corpus, post)
 *ai_defn(struct ai*, struct ai_def const*, uintptr_t),                // immortal values only
 *ai_defv(struct ai*, char const*),                // its twin for a live heap value (rides sp[0], stays there)
 *ai_layer_(struct ai*),      // push a fresh writable layer (the runtime's enter); every frontend opens its session with it
 *ai_unsplice_(struct ai*);   // drop the link below the head (the runtime's bare leave)

// the heap-image codec (stdio-free): save compacts g and serializes into a fresh
// g->alloc'd buffer; load reconstructs a fresh g, or NULL on any mismatch (the
// caller boots normally). buffer-based so a freestanding frontend needs no filesystem.
// a kept absolute only survives a wake if it aims inside the binary's own load segments
// (one ASLR delta shifts them all); a JIT W^X page, an mmap or a shared library dies with
// the bake process, so the dump refuses it. only the host can answer that, so it answers
// by parameter and the audit owns no state here; a NULL guard is audit off. the guard is
// asked of every candidate absolute and told which object carries it (heap word offset
// plus that object's hot). answer 0 and the dump refuses.
// a refused dump names its first offenders: (heap word offset, the value, that object's ap).
// output only, and NULL asks for none -- src/port/mps2 prints them where there is no debugger.
// `why` names the step that refused: 2 the compaction scared, 3 out of memory, 4 an
// unencodable heap word, 5 the root table is too small, 6 an unencodable root,
// 8 the heap outgrew the lane floor, 10 no room for the serial ranks, 11 the rank walk
// ran out; 0 on the way out.
struct ai_image_bad { uintptr_t q[3 * 2]; int n, why; };
// the running stack is ballast, not state: its objects ride into the blob and the load side
// resets sp/ip, so a dump wherever it is called is a dump like any other.
void *ai_image_save(struct ai*, uintptr_t *outlen, struct ai_image_bad*);
struct ai
 *ai_image_load(void const *buf, uintptr_t len),
 *ai_image_load_m(void const *buf, uintptr_t len, void *(*)(struct ai*, void*, size_t));   // allocator-parameterized (a device heap has no malloc)

// the terminal scare face: prints ";; a b\n" (show forms) to the err port from
// the stashed condition data; the bare oom prints ";; oom@len=N\n".
void ai_scare_face_(struct ai*);

extern struct ai_fio ai_stdin, ai_stdout, ai_stderr;

// the boot driver: ai_egg_(g, egg, p1, corpus) applies src/core/boot/egg.l to the quoted corpus
// -- compile the compiler with c0, recompile the corpus through itself, install as `ev`.
// the list is stitched (p0 reads egg + p1; p1, evaluated a step earlier, reads the
// corpus), so p1.l is the only .l held to the pure lisp subset.

// === internal API shared with host / free ===
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
#define charmp oddp
// the blue floor: extra stack slack on every avail check, a buffer against off-by-one
// overshoots. 0 under LoveBoot so love0 keeps strict discipline; -Dai_avail_floor=N overrides.
#ifndef ai_avail_floor
# ifdef LoveBoot
#  define ai_avail_floor 0
# else
#  define ai_avail_floor 8
# endif
#endif
// the GC tail is ai_musttail like every other, and that is why lvm_gc takes its word
// count in g->b instead of a fifth parameter: musttail wants matching prototypes, so an
// extra-arg callee left this tail to the compiler's mood. it is owed now, per Have.
#define Have(n) do { if (Sp < Hp + (n) + ai_avail_floor) { \
   g->b = (n) + ai_avail_floor; ai_musttail return Ap(lvm_gc, g); } } while (0)
#define Have1() Have(1)
#define ai_pop1(g) (*(g)->sp++)
#define op(nom, n, x) lvm(nom) { intptr_t _ = (x); *(Sp += n-1) = _; Ip++; ai_musttail return Continue(); }
#define zero ai_zero
struct ai_chain { lvm_t *ap; intptr_t a, b; };
// enum q, the value-kind lattice for generic dispatch: KMint the blue floor, then KNom,
// the arithmetic lane [KCharm..KTrayO] (scalars then their tray mirrors), the sequence
// lane [KString..KChain], tablet, thread last -- each dyadic lane one contiguous range,
// `max` the within-lane promotion join. dispatch order only: the total compare order is
// cmp_rank's separate remap (love.c). KN is the matrix dimension.
// enum d is the other question: what a heap object's hot says it is. ai_typ can answer
// these nine and nothing else, so a switch over them is exhaustive and carries no
// default -- add a data sentinel and -Wswitch names every site. the two share no values;
// mx.h's ai_kind_of_d is the one crossing, and a tray is the one rep that dispatches
// four ways. both rosters are mx.l's -- edit that, not kinds.h.
#include "kinds.h"
typedef ai_word num, word;
// the unique empty string: data-segment, never moved (gcp's out-of-pool
// short-circuit); strings are immutable, so one suffices. its own type, so the
// NUL every string carries behind its bytes has storage here too.
extern const struct ai_str0 { lvm_t *ap; uintptr_t len; char bytes[8]; } ai_str_empty;
#define EmptyString ((word) &ai_str_empty)
// (): the one serial-0 mint, a data-segment const shared by every core -- immortal,
// never copied, so () is bakeable. serial 0 is never drawn, so it is unique and least;
// .ap = lvm_sym gives mintp/const-1-apply/()-print for free.
extern const struct ai_mint ai_mint_zero;
#define ZeroPoint ((word) &ai_mint_zero)
// one parked fd. the layout is poll(2)'s struct pollfd, so the host polls the block
// directly (src/host/main.c static-asserts the match). the scheduler fills .fd/.events and
// zeroes .revents, then reads .revents back: nonzero = ready, taken instead of re-asking
// the kernel per fd. filling it is optional -- all-zero is "nothing to say".
struct ai_wait_fd { int fd; short events, revents; };

// the two park directions, in poll(2)'s own bit values (src/host/main.c static-asserts
// them). never OR them and ask as one: a socket is almost always writable, so a reader
// polled for both would spin.
#define ai_wait_in  1
#define ai_wait_out 4

void ai_wait_fds(struct ai_wait_fd *fds, int n, uintptr_t ticks), // wait for a fd to be ready
    ai_ready_fds(struct ai_wait_fd *fds, int n);                  // non-blocking variant
bool ai_ready(int fd, int events);
struct ai
 *ai_please(struct ai*, uintptr_t),
 *ai_push(struct ai*, uintptr_t, ...),
 *ai_strof(struct ai*, const char*),
 *gxl(struct ai*),
 *gxr(struct ai*),
 *intern(struct ai*),
 *str0(struct ai*, uintptr_t),
 *grbufg(struct ai *g, uintptr_t len);
lvm(lvm_gc);                                    // takes its word count in g->b
// the nom a canonical errno names: 'eperm .. 'ehwpoison; 'eunknown for a number
// the numbering leaves blank, 'badarg at -1 for a call refused before any
// syscall ran. reads g->errs, interned at boot -- no allocation on any error path.
ai_word ai_err(struct ai*, int);
#define ai_badarg(g) ai_err(g, -1)
uintptr_t hash(struct ai*, word), ai_tray_bytes(struct ai_tray*);
// any value -> its enum q: KCharm for a fixnum, KCoin for a non-data heap pointer,
// else ai_typ's rep, a tray refined by element tier (KTrayZ..KTrayO).
// both the +/* matrices and the apply sentinels dispatch on this.
enum q ai_kind(word);
extern union u const numap_drive[];          // [ap; swap; ret0] driver that runs (num-ap n x); shared by fixnum + data num apply
lvm_t lvm_ap, lvm_chain, lvm_tray, lvm_sym, lvm_nom, lvm_str, lvm_big, lvm_gembox, lvm_sunbox, lvm_twinbox; // the data-kind sentinels (+ ap); defined in love.c, read by inline predicates and ai_typ
// recover a data value's rep from its ap. the sentinels tile one section at
// ai_data_stride in enum d order, so the slot is the kind: one subtract answers both
// questions, and the compiler shares it between a datp and the typ after it. the base
// is lvm_sym -- slot 0 is the start, so no linker-synthesized bracket is owed anywhere.
#if ai_data_section
static ai_inline bool in_data(void *a) {
 return (uintptr_t) ((char*) a - (char*) lvm_sym) < (uintptr_t) (ai_data_n * ai_data_stride); }
static ai_inline enum d ai_typ(union u *o) {
 return (enum d) ((uintptr_t) ((char*) o->ap - (char*) lvm_sym) / ai_data_stride); }
#else
// the seats with no section to lay ask by name instead. the order is measured frequency,
// not enum d's -- over a corpus run: chain 62%, nom 19%, string 13%, mint 5%, big 1.6%,
// the other three under a tenth of a percent each.
static ai_inline bool in_data(void *a) {
 lvm_t *p = (lvm_t*) a;
 return p == lvm_chain || p == lvm_nom || p == lvm_str || p == lvm_sym || p == lvm_big
     || p == lvm_tray || p == lvm_sunbox || p == lvm_gembox || p == lvm_twinbox; }
static ai_inline enum d ai_typ(union u *o) {
 lvm_t *p = o->ap;
 return p == lvm_chain  ? DChain
      : p == lvm_nom    ? DNom
      : p == lvm_str    ? DString
      : p == lvm_sym    ? DMint
      : p == lvm_big    ? DBig
      : p == lvm_tray   ? DTray
      : p == lvm_sunbox ? DSun
      : p == lvm_gembox ? DGem
      :                   DTwin; }   // the 9th and last: lvm_twinbox
#endif
#define str(_) ((struct ai_str*)(_))
#define lamp evenp
#define two(_) ((struct ai_chain*)(_))
#define chain_req Width(struct ai_chain)
#define mint_req Width(struct ai_mint)
#define nom_req Width(struct ai_nom)
#define cask(_) ((struct ai_cask*)(_))
static ai_inline bool chainp(word _) { return lamp(_) && cell(_)->ap == lvm_chain; }
static ai_inline void *bump(struct ai *g, uintptr_t n) {   // the mutator's: the nursery. gc.c bumps the major itself
 if (avail(g) < n) __builtin_trap();
 void *x = g->hp; g->hp += n; return x; }
static ai_inline struct ai_chain *ini_chain(struct ai_chain *w, intptr_t a, intptr_t b) {
 return w->ap = lvm_chain, w->a = a, w->b = b, w; }

static ai_inline struct ai *encode(struct ai *g, enum ai_status s) { return
  (struct ai*) ((uintptr_t) g | s); }

// call installed help with an error. _lvm prefix makes vmret skip it, since it returns to C if no help is installed
lvm_t _lvm_ghelp;
// ai_have is the phrase "this call may collect"; under AiGcStress every one does, so a
// raw local held across it goes stale on the first run rather than years later.
// AiGcCheck is the other half, checking the collector where this checks the mutator.
static ai_inline struct ai *ai_have(struct ai *g, uintptr_t n) {
#ifdef AiGcStress
 return !ai_ok(g) ? g : ai_please(g, n);
#else
 return !ai_ok(g) || avail(g) >= n ? g : ai_please(g, n);
#endif
}
static ai_inline bool strp(word _) { return lamp(_) && cell(_)->ap == lvm_str; }


// ===== the runtime internals =====
// the object layouts, the predicates and accessors over them, and the seam between
// src/love*.c's translation units. above this line is what a nif writer needs.

#include <sys/mman.h>
#include <unistd.h>

// --- kernel-internal declarations ---

// the math floor is ours on every frontend: src/apps/moon/lib/math/am.c (fdlibm and
// -lm both retired); the 32-bit lane computes in binary64 and narrows.
double am_sin(double), am_cos(double), am_atan2(double, double),
       am_sqrt(double), am_exp(double), am_log(double), am_pow(double, double),
       am_strtod(char const*, char**);   // correctly rounded read: the printer's twin
#if UINTPTR_MAX == UINT64_MAX
#define Bits 64
typedef double ai_flo_t;
#define ai_sin   am_sin
#define ai_cos   am_cos
#define ai_atan2 am_atan2
#define ai_sqrt  am_sqrt
#define ai_exp   am_exp
#define ai_log   am_log
#define ai_pow   am_pow
#elif UINTPTR_MAX == UINT32_MAX
#define Bits 32
typedef float ai_flo_t;
float am_sinf(float), am_cosf(float), am_atan2f(float, float), am_sqrtf(float),
      am_expf(float), am_logf(float), am_powf(float, float);
#define ai_sin   am_sinf
#define ai_cos   am_cosf
#define ai_atan2 am_atan2f
#define ai_sqrt  am_sqrtf
#define ai_exp   am_expf
#define ai_log   am_logf
#define ai_pow   am_powf
#endif
static ai_inline ai_flo_t ai_tan(ai_flo_t x) { return ai_sin(x) / ai_cos(x); }
static ai_inline ai_flo_t ai_atan(ai_flo_t x) { return ai_atan2(x, (ai_flo_t) 1); }

// bignum limbs: native-width wherever a double-width product type exists (64-bit
// limbs do a quarter the limb-ops); the 32-bit wasm shim (no __int128) keeps 32-bit
// limbs with a u64 accumulator. ai_dlimb/ai_sdlimb are the double-limbs.
#if UINTPTR_MAX == UINT64_MAX && defined(__SIZEOF_INT128__)
typedef uint64_t ai_limb;
typedef unsigned __int128 ai_dlimb;
typedef __int128 ai_sdlimb;
#define limb_bits 64
#else
typedef uint32_t ai_limb;
typedef uint64_t ai_dlimb;
typedef int64_t ai_sdlimb;
#define limb_bits 32
#endif
#define limb_clz(x) (__builtin_clzll((unsigned long long) (x)) - (8 * (int) sizeof(unsigned long long) - limb_bits))  // leading zeros of a nonzero limb, at limb width
#define wlimbs (Bits / limb_bits)   // limbs to hold one machine word: 1 (native-width limbs) or 2 (32-bit limbs on a 64-bit word)
// decimal digits a limb spans: floor(limb_bits * log10 2), 30103 = round(1e5 log10 2).
// the reader packs chunk digits per mul-add pass.
#define limb_dec_chunk  (limb_bits * 30103 / 100000)
// the binary-radix twins: the most digits whose product still fits a limb
#define limb_hex_chunk  ((limb_bits - 1) / 4)
#define limb_oct_chunk  ((limb_bits - 1) / 3)

#define Bytes (Bits>>3)
_Static_assert(Bytes == sizeof(uintptr_t), "word size sanity check");

#include <stdarg.h>
_Static_assert(sizeof(union u) == sizeof(intptr_t), "cell size equals word size");

// remembered-set capacity in words; g->alloc'd, so the collector stays freestanding
#define AiRemCap (1u << 12)
// initial pool sizes, words per half; both grow on demand (a tiny device overrides
// with -Dai_minor0/-Dai_major0 and accepts more collections)
#ifndef ai_minor0
# define ai_minor0 (1u << 14)   // ~128 KB minor (the main pool); the dev host boots fast
#endif
#ifndef ai_major0
# define ai_major0 (1u << 16)      // ~512 KB major-pool half; grows much less often than the minor pool
#endif
// the nursery's copy-overhead setpoint (ai_please): resize to keep copied/allocated
// inside [1/(4*ratio), 1/ratio]. larger ratio = lower overhead, more RAM.
#ifndef ai_gc_ratio
# define ai_gc_ratio 24   // the knee of the GC-reduction curve; past it RAM doubles for a flat curve
#endif
// total memory budget in words (2*minor + 2*major); 0 = unbounded. a device sets its
// RAM (-Dai_budget=131072 for a 1 MB Teensy); the nursery then sizes by appel's rule (ai_please).
#ifndef ai_budget
# define ai_budget 0
#endif
_Static_assert(-1 >> 1 == -1, "sign extended shift");
// structural test for the charm zero -- an identity, not a measure. distinct
// from ai_nilp, the language's falsy predicate (all-zero tray, unit, red net).
#define zerop(_) (word(_)==zero)
#define AB(o) A(B(o))
#define AA(o) A(A(o))
#define BA(o) B(A(o))
#define BB(o) B(B(o))
#define ptr(_) ((word*)(_))
#define datp(_) in_data(cell(_)->ap)
#define avec(g, y, ...) (mm(g,&(y)),(__VA_ARGS__),um(g))
#define mm(g,r) ((ai_core_of(g)->root=&((struct ai_r){(word*)(r),ai_core_of(g)->root})))
#define um(g) (ai_core_of(g)->root=ai_core_of(g)->root->n)


#if UINTPTR_MAX > 0xffffffffu
#define mix ((uintptr_t) 0x9e3779b97f4a7c15) // round(2^64 / phi)
#else
#define mix ((uintptr_t) 0x9e3779b9) // round(2^32 / phi)
#endif

#define typ(_) ai_typ(cell(_))

#if ai_tco
#define ai_status_yield ai_status_ok
#else
#define ai_status_yield ai_status_eof
#endif
#define str_type_width (Width(struct ai_str))
// a string's whole footprint in words: header + bytes + the NUL behind bytes[len]
#define str_width(n) (str_type_width + b2w((n) + 1))
#define op1(nom, i, x) lvm(nom) { Sp[0] = (x); Ip += i; ai_musttail return Continue(); }
#define op11(nom, x) op1(nom, 1, x)

#define pop1 ai_pop1


// one word per element: ints fold to Z, floats to R; C is the rank-0 complex pair
// (a tray rejects it at rank>=1). ordered Z < R < C, so `>= ai_R` is the float test.
// O slots hold live l words -- the one tray type the GC traces per element
// (evac_tray); O elements route through the promoting scalar dispatch (lvm_obin),
// which is what makes a bignum array add exactly instead of wrapping.
enum ai_tray_type { ai_Z, ai_R, ai_C, ai_O, };
// the math lvms' function argument, carried in g->b like every other extra arg
typedef ai_flo_t (*ai_flo1)(ai_flo_t);
typedef ai_flo_t (*ai_flo2)(ai_flo_t, ai_flo_t);
// elementwise dyadic opcodes for lvm_vbin. codes >= vop_lt produce a 0/1 mask
// (vop_eq is table-shared machinery only -- tray_eq answers `=` as a boolean).
// vop_quot is `/` (true division), vop_fquot `//` (truncating); both in the arith group.
enum vop { vop_add, vop_sub, vop_mul, vop_quot, vop_rem, vop_fquot,
           vop_band, vop_bor, vop_bxor, vop_bsl, vop_bsr,
           vop_lt, vop_le, vop_gt, vop_ge, vop_eq, };
// the bitwise codes ride the word lane (spec.l's width law): defined only where
// the cells are machine words; other operands take the whole op to the zero point
#define vop_bitp(op) ((op) >= vop_band && (op) <= vop_bsr)
word intern_checked(struct ai*, struct ai_str*);
uintptr_t intern_reserve(struct ai*);
union u *map_fill_back(union u*, uintptr_t);
lvm_t lvm_kcall,
 lvm_putn, lvm_seal, lvm_heard, lvm_worn, lvm_myself,
 lvm_nilp, lvm_putc, lvm_intern,
 lvm_saturate, lvm_ceil, lvm_peep, lvm_lamsrc, lvm_nifnom, lvm_cask, lvm_bcopy, lvm_xlat,
 lvm_coin, lvm_coinmk, lvm_load, lvm_coinp, lvm_kind, lvm_sub_coin, lvm_quot_coin,   // coins: a kind's values, typed hots on the KCoin row
 lvm_charmp, lvm_tabp, lvm_band, lvm_bor, lvm_gem, lvm_gemp,
 lvm_sin, lvm_cos, lvm_tan, lvm_atan, lvm_atan2, lvm_exp, lvm_sqrt, lvm_log, lvm_pow,
 lvm_twin, lvm_twinp, lvm_re, lvm_im, lvm_conj, lvm_abs, lvm_carg,   // complex; lvm_twin_bin declared apart below
 lvm_bxor, lvm_bsr, lvm_bsl, lvm_puts,
 lvm_string, lvm_lt,     lvm_le,   lvm_eq,     lvm_same, lvm_gt,  lvm_ge,
 lvm_sort,  lvm_tally, lvm_longp,
 lvm_pin, lvm_pull, lvm_tablet,   lvm_keys,  lvm_dig,
 lvm_unc, lvm_poke, lvm_peek,
 lvm_seek,  lvm_trim,   lvm_spin,   lvm_add,
 lvm_mul,    lvm_quot,   lvm_fquot, lvm_rem,  lvm_arg,
 lvm_bmul_start,             // the resumable bignum multiply's entry; its loop bodies are num.c's
 lvm_quote, lvm_index,  lvm_eval,   lvm_cond, lvm_jump,   lvm_defglob,
 lvm_ap,    lvm_tap,    lvm_apn,    lvm_tapn, lvm_ret,
 lvm_argap, lvm_quoteap, lvm_argtap,
 lvm_arg0, lvm_arg1, lvm_arg2, lvm_arg3,
 lvm_quo0, lvm_quo1, lvm_quo2, lvm_quo3, lvm_quom1, lvm_quom2,
 // run fusion: a whole run of loads in one op, named for its shape (see below)
 lvm_aa, lvm_aq, lvm_qa, lvm_qq,
 lvm_aap, lvm_aqp, lvm_qap, lvm_qqp,
 // load + consumer: arg fused with the op that eats it
 lvm_argcap, lvm_argcup, lvm_argtwo, lvm_argcond,
 lvm_argtwocond,                                  // load + predicate + cond
 lvm_callk, lvm_scare, lvm_yield_sw, lvm_yield_nif, lvm_task_exit, lvm_twirl, lvm_wait,
 lvm_sleep, lvm_donep, lvm_scoop, lvm_hush,
 lvm_await,
 lvm_fgetc, lvm_fungetc, lvm_chug, lvm_unchug, lvm_inhand, lvm_fputc, lvm_fputs, lvm_fflush,
 lvm_fputbn, lvm_sound0,
 lvm_trayctor, lvm_iota, lvm_rank, lvm_alen, lvm_shape, lvm_atype,   // typed multi-rank arrays
 lvm_asum, lvm_aprod, lvm_max, lvm_min, lvm_aall, lvm_inner, lvm_outer,
 lvm_litp, lvm_hotp,
 lvm_nif,         // codegen backend: emitted bytes -> applicable native value (1-arg / multi-arg)
 lvm_nifx,        // ... with an extras word (value[3]+8 = Ip+32): refs a native needs beyond the twin (the callout's clos, amble's ()/globals) ride a GC-walked cell slot, so value[1] stays the plain twin and the image revert (img_nif_interp) never dereferences a pack
 lvm_calloutdrive, lvm_calloutresume,   // the drive addresses as fixnums (probes; a native reads them off g->jk)
 lvm_jkoff,       // (jkoff x): g->jk's byte offset, what the emitter's `jk` law loads from
 lvm_natp;        // (nat? f): is f a native closure -- its code in the arena
// ⚠ THE ATTRIBUTES ARE THE DECLARATION: `lvm(n)` is `ai_noinline ai_noicf _lvm(n)`, so these
// cannot fold into the plain lvm_t list above without shedding both. ai_noicf is noipa, and the
// data sentinels below are what it is for -- see their note.
ai_noinline ai_noicf lvm_t
 lvm_0, lvm_add_seq, lvm_add_string, lvm_addh, lvm_arg0,
 lvm_atype, lvm_bin_a, lvm_bin_b, lvm_bin_unit, lvm_coinp,
 lvm_dieof, lvm_dig, lvm_gemp, lvm_heard, lvm_hotp,
 lvm_mulh, lvm_myself, lvm_nilp, lvm_quo0, lvm_quom1,
 lvm_quotn, lvm_rank, lvm_tabp, lvm_twinp, lvm_worn,
 // these carry extra operands, so they are declared apart from the plain lvm_t list
 lvm_vbin, lvm_bdiv_start, lvm_vmap1, lvm_vmap2, lvm_twin_bin, lvm_cbin, lvm_obin,
 // the data sentinels: each is the first word (ap) of its rep's heap objects and
 // tail-jumps straight to its apply handler -- the sentinel is the rep (enum d).
 // bodies are byte-identical, kept distinct by address (ai_noicf).
 data_num_apply, data_sym_apply, data_string_apply, data_pair_apply,
 lvm_sym, lvm_nom, lvm_sunbox, lvm_gembox, lvm_twinbox,
 lvm_big, lvm_tray, lvm_str, lvm_chain,
 lvm_addn, lvm_fquotn, lvm_muln,
 lvm_remn, _lvm_yieldk;
char const *ai_nif_name(intptr_t);
#define tray(_) ((struct ai_tray*)(_))
#define sym(_) ((struct ai_mint*)(_))
#define nom(_) ((struct ai_nom*)(_))
#define big(_) ((struct ai_big*)(_))
static ai_inline bool mintp(word _) { return lamp(_) && cell(_)->ap == lvm_sym; }
static ai_inline bool namep(word _) { return lamp(_) && cell(_)->ap == lvm_nom; }
static ai_inline bool packp(word _) { return lamp(_) && cell(_)->ap == lvm_tray; }
static ai_inline bool nomp(word x) { return lamp(x) && (cell(x)->ap == lvm_sym || cell(x)->ap == lvm_nom); }
// mutable flat byte string. not a data kind: the head is the behaves-as-0 lvm_cask,
// so the GC walks a cask as a plain length-2 thread and forwards the embedded ai_str
// free. earned by the build tools that back-patch an image in place.
static ai_inline bool caskp(word _) { return lamp(_) && cell(_)->ap == lvm_cask; }
// a map is a lookup-lambda with stable identity across growth: a fixed header
// [lvm_map_lookup, backing, serial, <tag>] callers hold, and an open-addressed backing
// [lvm_map_data, len, cap, k0,v0, .., <tag>] -- growth swaps header[1], so aliased
// references (ev's scopes) see later inserts. both are plain threads, no bespoke
// GC. empty slots hold map_gap, a unique out-of-pool address. (m k) -> value, () absent.
// the serial (a charm, drawn from the mint stream) is the order key: a tablet is
// mutable, so its order is its identity and never its contents.
lvm_t lvm_map_lookup, lvm_map_data;
static ai_inline bool tabp(word _) { return lamp(_) && cell(_)->ap == lvm_map_lookup; }
extern const word ai_map_gap_cell;   // one definition: map_gap is its ADDRESS
#define map_gap ((word) &ai_map_gap_cell)
#define map_min_cap 4
#define map_hint_max (1u << 24)        // the `(tablet n)` size hint saturates to this bounded green charm
static ai_inline word map_back(word m) { return cell(m)[1].x; }
static ai_inline uintptr_t map_serial(word m) { return getcharm(cell(m)[2].x); }
enum { map_head = 4 };   // the header's words, tag included
static ai_inline word *map_slots(word m) { return &cell(map_back(m))[3].x; }
static ai_inline uintptr_t map_len(word m) { return getcharm(cell(map_back(m))[1].x); }
static ai_inline uintptr_t map_cap(word m) { return getcharm(cell(map_back(m))[2].x); }
word
 ai_mapget(struct ai*, word, word, word),
 bookget(struct ai*, word, word),   // the layered global read: walks g->book (a chain of books) head-first
 macroget(struct ai*, word);        // the layered macro read: each layer's table rides its [zero] slot
struct ai *ai_mapput(struct ai*), *map_new(struct ai*);
// the byte ops read from a string or a cask; both resolve to a ai_str of bytes.
static ai_inline struct ai_str *bytes_of(word x) { return caskp(x) ? cask(x)->str : str(x); }
// a coin of a kind of its own: a typed hot [lvm_coin, kind, payload], a plain thread, no
// bespoke evac. ai_kind reads KCoin, so +/* route every coin combination to lvm_addh/mulh,
// where a struck operand is intercepted. the kind is a tablet keyed by the noms below
// (interned at boot into g->knom); every coin of a kind is struck from one table, and a
// named one is registered in g->kreg (name -> (serial . table)) by src/core/boot/post.l's `coin`.
struct ai_coin { lvm_t *ap; word kind; word payload; };
static ai_inline bool coinp(word _) { return lamp(_) && cell(_)->ap == lvm_coin; }
static ai_inline word coin_kind(word x) { return ((struct ai_coin*) x)->kind; }
static ai_inline word coin_load(word x) { return ((struct ai_coin*) x)->payload; }
// the kind table's keys, by index into g->knom. + * - / and ap are closures run inside the
// VM; net/=/</show/tally default over the payload in pure C. hot truthy = the kind's coins
// are lit? (references); absent = fresh data. star truthy = numeric: a numeral powers them
// through their own * (prel's num-ap reads it; C never does). net is a mode nom, never a
// closure -- ai_net is pure C under every truth test and must not re-enter the VM: absent =
// net of the payload, tally = the count, ratio = an (n d)-of-reals payload as n/d.
// the tail names are `kind`'s answers for the built-in coins.
enum { KnName, KnAdd, KnMul, KnApply, KnHot, KnSub, KnNet, KnStar, KnDiv,
       KnPayload, KnTally, KnRatio, KnLambda, KnCask, KnPort, KnN };
// read a kind table's slot, or () if absent / the kind is not a tablet.
static ai_inline word kind_get(struct ai *g, word kind, intptr_t i) {
 return tabp(kind) ? ai_mapget(g, zero, ai_core_of(g)->knom[i], kind) : zero; }
// arbitrary-precision integer, its own sentinel kind: flat raw limbs, moved by
// memcpy (a thread sound would misread even-and-in-pool limb words). slen = signed
// limb count, little-endian, top limb nonzero; zero always demotes, so slen is
// never 0. canonical demotion keeps charmp/sunp/bigp mutually exclusive.
struct ai_big { lvm_t *ap; intptr_t slen; ai_limb limb[]; };
static ai_inline bool bigp(word _) { return lamp(_) && cell(_)->ap == lvm_big; }
static ai_inline struct ai_big *ini_big(struct ai_big *b, intptr_t slen) {
 return b->ap = lvm_big, b->slen = slen, b; }
uintptr_t ai_big_bytes(struct ai_big*);
// canonicalize a magnitude into the smallest tier: fixnum, sun box, bignum
// (bumps *hp when it boxes); one sink shared by the reader and the arith slow paths
word ai_big_canon(ai_word **hp, ai_limb const *limb, int n, bool neg);
ai_flo_t ai_big_to_flo(word);                 // bignum -> double (used by toflo)
int ai_big_cmp(word, word);                  // -1/0/1 over two integer operands
intptr_t ai_mint_cmp(struct ai*, word, word); // -1/0/1 over two points: () < bare mints < names
bool ai_ratio_exact(struct ai*, word);  // int/ceil/saturate's exact-ratio domain: a net-mode-2 coin over integer (n d)
struct ai
 *ai_ratio_rung(struct ai*, int),     // ..and the lane: long-divide the parts (0 int, 1 ceil, 2 saturate), packed
 *ai_big_binop(struct ai*, int vop),  // vop_add..vop_rem, packed; pops one operand
 *ai_big_bitop(struct ai*, int vop),  // vop_band..vop_bxor, two's complement; pops one operand
 *ai_big_shift(struct ai*, int vop),  // vop_bsl / vop_bsr, promoting and flooring; pops one operand
 *ai_big_quot_true(struct ai*),       // `/` bignum lane: exact quotient when b | a, else a float box
 *ai_big_read_dec(struct ai*),        // sp[0] [+-]?digits token -> canonical value
 *ai_big_read_hex(struct ai*),        // ..and its [+-]?0x<hexdigits> twin
 *ai_big_read_oct(struct ai*);        // ..and [+-]?0<octdigits>, the third

// a boxed scalar float: a lean {ap, payload} box, two words
static ai_inline bool gemp(word _) { return lamp(_) && cell(_)->ap == lvm_gembox; }
static ai_inline bool sunp(word _) { return lamp(_) && cell(_)->ap == lvm_sunbox; }
static ai_inline bool twinp(word _) { return lamp(_) && cell(_)->ap == lvm_twinbox; }
static ai_inline bool trayp(word _) { return packp(_) && tray(_)->rank >= 1; }
static ai_inline bool galaxyp(word _) { return trayp(_) && tray(_)->type != ai_O; }

// FIXME uh, there's a max rank? that's not on purpose
#define maxrank 8   // bounds the stack index/stride arrays in the broadcast loop
extern size_t const
 ai_vt_[],                 // element byte size by ai_tray_type
 ai_T[];                   // element byte size by ai_tray_type (used pre-definition by lvm_gauge)
// element payload: laid out row-major just past the shape words.
static ai_inline void *tray_data(struct ai_tray *v) { return (void*) (v->shape + v->rank); }
// total element count = product of the dimensions (1 for a rank-0 scalar box).
static ai_inline uintptr_t tray_nelem(struct ai_tray *v) {
 uintptr_t n = 1;
 for (uintptr_t i = 0; i < v->rank; i++) n *= v->shape[i];
 return n; }
static ai_inline struct ai_tray *ini_tray(struct ai_tray *v, enum ai_tray_type t, uintptr_t rank) {
 return v->ap = lvm_tray, v->type = t, v->rank = rank, v; }
// the footprint of a rank-R array of n elements of type t
static ai_inline uintptr_t tray_bytes(enum ai_tray_type t, uintptr_t R, uintptr_t n) {
 return sizeof(struct ai_tray) + R * sizeof(word) + n * ai_T[t]; }
// read element i of v as a double / as an integer (sign-extending the narrow
// integer types; truncating a float toward zero for the int reader). the int
// reader is only used on integer-typed arrays in practice.
static ai_inline ai_flo_t tray_get_flo(struct ai_tray *v, uintptr_t i) {
 void *p = tray_data(v);
 return v->type == ai_R ? ((ai_flo_t*) p)[i] : (ai_flo_t) ((intptr_t*) p)[i]; }
static ai_inline intptr_t tray_get_int(struct ai_tray *v, uintptr_t i) {
 void *p = tray_data(v);
 return v->type == ai_R ? (intptr_t) ((ai_flo_t*) p)[i] : ((intptr_t*) p)[i]; }
// write element i of v, converting to v's element kind.
static ai_inline void tray_put_int(struct ai_tray *v, uintptr_t i, intptr_t x) {
 void *p = tray_data(v);
 if (v->type == ai_R) ((ai_flo_t*) p)[i] = (ai_flo_t) x; else ((intptr_t*) p)[i] = x; }
static ai_inline void tray_put_flo(struct ai_tray *v, uintptr_t i, ai_flo_t x) {
 void *p = tray_data(v);
 if (v->type == ai_R) ((ai_flo_t*) p)[i] = x; else ((intptr_t*) p)[i] = (intptr_t) x; }
// read/write element i of a ai_O array as a raw tagged l word (the GC traces
// these; see evac_tray). no conversion -- the slot is a value.
static ai_inline word tray_get_obj(struct ai_tray *v, uintptr_t i) {
 return ((word*) tray_data(v))[i]; }
static ai_inline void tray_put_obj(struct ai_tray *v, uintptr_t i, word x) {
 ((word*) tray_data(v))[i] = x; }

// truth: x is false iff (= 0 ($ x)). the net's codomain is complex (ai_net): a
// complex scalar nets itself, every other scalar nets real, aggregates sum -- so
// the net is additive exactly. common kinds short-circuit with no walk; a sum
// cannot (a later negative cancels). lockstep with ai_saturate ($): same zero conditions.
struct ai_str *nom_str(struct ai *g, word x);   // a named sym -> its name string, else 0
struct ai_zn { ai_flo_t re, im; };                     // the net: a complex value
static ai_inline struct ai_zn zn(ai_flo_t re, ai_flo_t im) {
  struct ai_zn z = {re, im}; return z; }
// the truth gate, not the total order -- the one place the two part: a net is
// nothing unless its real part is positive, so a pure phase is blue (truth cannot
// depend on which root of x^2+1 we named `i`). the lexicographic order stays as
// it was -- sorting needs totality.
// a macro, not a fn: a by-value ai_zn argument stages through push/pop, which
// bars unframe in every fn ai_nilp splices into (the hot truth-test fleet)
struct ai_zn ai_net(struct ai *, word);         // fwd: aggregates sum their elements
intptr_t ai_count(struct ai *, word);           // fwd: tally's C body (net-mode 1 reads it)
// only the two lanes that answer with no load and no call earn a line here: they
// carry the corpus (a charm truth test, `()`), and ai_net is never inlined, so a
// third lane costs more than the walk it skips. every other kind's shape is ai_net's.
static ai_inline bool ai_nilp(struct ai *g, word x) {
  if (charmp(x)) return getcharm(x) <= 0;            // a charm is its own net
  if (mintp(x)) return true;                         // a bare point nets nothing
  return ai_net(g, x).re <= 0; }

// a NaN is love's (): love admits no irreflexive value, so = reads two of them as one,
// and it nets nothing, exactly as every other point does (ai_net's chain arm says so).
static ai_inline bool ai_same_flo(ai_flo_t a, ai_flo_t b) { return a == b || (a != a && b != b); }
static ai_inline ai_flo_t ai_net_flo(ai_flo_t v) { return v != v ? 0 : v; }
// truncation toward zero / float remainder; pure and freestanding-safe (no libm)
static ai_inline ai_flo_t ai_trunc(ai_flo_t x) {
 if (x != x) return x;
 ai_flo_t m = x < 0 ? -x : x;
 if (m > (ai_flo_t) 9.22e18) return x;
 return (ai_flo_t) (int64_t) x; }
static ai_inline ai_flo_t ai_fmod(ai_flo_t a, ai_flo_t b) {
 return a - ai_trunc(a / b) * b; }

// --- numeric tower helpers ---
#define isnum(x) (charmp(x) || gemp(x) || sunp(x) || bigp(x))
#define intp(x) (charmp(x) || sunp(x) || bigp(x))   // the integer tier, all three tiers of it
// integer value of a fixnum-or-box operand (callers exclude floats and bignums)
#define toint(x) (charmp(x) ? (intptr_t) getcharm(x) : sun_get(x))
// double value of any numeric operand (a bignum widens via ai_big_to_flo)
#define toflo(x) (charmp(x) ? (ai_flo_t) getcharm(x) : gemp(x) ? gem_get(x) : sunp(x) ? (ai_flo_t) sun_get(x) : ai_big_to_flo(x))
#define twin_req Width(struct ai_twin)
// the tagged fixnum range: putcharm spends one bit
#define mincharm (INTPTR_MIN >> 1)
#define maxcharm (INTPTR_MAX >> 1)
// emit an integer/double result into `_res`, demoting to a fixnum when it fits.
// caller holds Have(box_req); takes no &local, so the caller keeps its tail call.
#define emit_int(r, R) do { intptr_t _r = (R); \
 if (_r >= mincharm && _r <= maxcharm) r = putcharm(_r); \
 else r = mk_sun(&Hp, _r); } while (0)
#define emit_gem(r, R) do { r = mk_gem(&Hp, (R)); } while (0)

// RNG: state is a rank-1 i64 tray of length 4 (xoshiro256++), its payload raw
// bytes moved by memcpy -- tray_get/put_int would truncate the limbs on 32-bit
// ports. fixed 8-byte limbs make a seed reproduce on every target.
#define rng_state_len 4
#define rng_payload_bytes (rng_state_len * 8)
#define rng_tray_bytes (sizeof(struct ai_tray) + sizeof(uintptr_t) + rng_payload_bytes)
#define rng_tray_req (b2w(rng_tray_bytes))
// whichever element kind is 8 bytes wide, so ai_tray_bytes sees the full payload
#define rng_vt (Bytes == 4 ? ai_C : ai_Z)
lvm_t lvm_wheel, lvm_turn, lvm_turnf;
int memcmp(void const*, void const*, size_t);
void *malloc(size_t), free(void*),
 *memcpy(void*restrict, void const*restrict, size_t),
 *memmove(void*restrict, void const*restrict, size_t),
 *memset(void*, int, size_t);
size_t strlen(char const*);

// the lean scalar boxes: {ap, payload} GC leaves, copied like bignums
struct ai_gem { lvm_t *ap; ai_word w; };
#define gem_req Width(struct ai_gem)
#define gem(_) ((struct ai_gem*)(_))
struct ai_sun { lvm_t *ap; intptr_t w; };    // raw intptr_t payload, no bit pun
#define sun_req Width(struct ai_sun)
#define sun(_) ((struct ai_sun*)(_))
#define box_req (gem_req > sun_req ? gem_req : sun_req)     // what emit_int/emit_gem reserve
struct ai_twin { lvm_t *ap; ai_word re, im; };   // two punned-double payload words
#define twin(_) ((struct ai_twin*)(_))
// pun through a union, not memcpy(&local,..): the memcpy form escapes a stack
// local, and clang -Os then refuses the sibling call out of any inlining VM ap --
// silently breaking threaded dispatch (tools/vmret.l).
_Static_assert(sizeof(ai_flo_t) == sizeof(uintptr_t), "float box assumes ai_flo_t is pointer-width");
typedef union { uintptr_t u; ai_flo_t d; } ai_flo_pun;
static ai_inline ai_flo_t gem_get(word x) {
 return ((ai_flo_pun){ .u = ((struct ai_gem*) x)->w }).d; }
// allocate a float box at *hpp (caller holds Have(gem_req)); no &local, so the caller keeps its tail call.
// the law, the one real-float box-write: NaN collapses to 0 so the order stays total and
// !x == (0 = $x) holds. inf rides through. glaze's jit lanes emit the same collapse.
static ai_inline word mk_gem(ai_word **hpp, ai_flo_t v) {
 if (v != v) return ZeroPoint;   // nothing is unequal to itself, come on IEEE, give me a break
 struct ai_gem *f = (struct ai_gem*) *hpp;
 *hpp += gem_req;
 f->ap = lvm_gembox;
 f->w = ((ai_flo_pun){.d = v}).u;
 return word(f); }

static ai_inline ai_flo_t twin_re(word x) {
 return ((ai_flo_pun){ .u = ((struct ai_twin*) x)->re }).d; }

static ai_inline ai_flo_t twin_im(word x) {
 return ((ai_flo_pun){ .u = ((struct ai_twin*) x)->im }).d; }

static ai_inline ai_flo_t twin_mod(word x) {   // |z|
 ai_flo_t re = twin_re(x), im = twin_im(x);
 return ai_sqrt(re * re + im * im); }

// mk_twin allocates at *hpp (caller holds Have(twin_req)); no &local taken
static ai_inline void twin_set(struct ai_twin *v, ai_flo_t re, ai_flo_t im) {
 v->re = ((ai_flo_pun){ .d = re }).u;
 v->im = ((ai_flo_pun){ .d = im }).u; }

static ai_inline word mk_twin(ai_word **hpp, ai_flo_t re, ai_flo_t im) {
 struct ai_twin *v = (struct ai_twin*) *hpp;
 *hpp += twin_req;
 v->ap = lvm_twinbox;
 twin_set(v, re, im);
 return word(v); }

static ai_inline intptr_t sun_get(word x) { return ((struct ai_sun*) x)->w; }

// allocate a sun box at *hpp (caller holds Have(sun_req)); no &local taken
static ai_inline word mk_sun(ai_word **hpp, intptr_t v) {
 struct ai_sun *w = (struct ai_sun*) *hpp; *hpp += sun_req;
 w->ap = lvm_sunbox; w->w = v; return word(w); }

// a tray key -> a row-major element offset: a fixnum on a rank-1 tray, else a
// shape-list of `rank` fixnums. -1 = wrong rank or out of bounds (the caller's miss
// lane). peep reads through it, pin writes through it: one index law. answers by
// value, never through an out-param: an escaping &local costs its caller the tail jump.
static ai_inline intptr_t tray_off(struct ai_tray *v, word k) {
 if (v->rank == 1 && charmp(k)) {
  intptr_t ix = getcharm(k);
  return ix >= 0 && ix < (intptr_t) v->shape[0] ? ix : -1; }
 if (!chainp(k)) return -1;
 uintptr_t a = 0, o = 0;
 for (word l = k;; l = B(l)) {
  if (!chainp(l)) return a == v->rank ? (intptr_t) o : -1;
  word ki = A(l);
  if (a >= v->rank || !charmp(ki)) return -1;
  intptr_t ix = getcharm(ki);
  if (ix < 0 || ix >= (intptr_t) v->shape[a]) return -1;
  o = o * v->shape[a] + (uintptr_t) ix, a++; } }

// store x at element i, converting to v's tier: O takes any value verbatim, C packs
// (re,im) (a real rides in as (r,0)), R/Z take a number. false = a non-number into a
// numeric tray, which leaves the slot alone. v is the caller's fresh tray -- an
// object slot gaining a young word needs no barrier only because nothing old is written.
static ai_inline bool tray_put(struct ai_tray *v, uintptr_t i, word x) {
 if (v->type == ai_O) return tray_put_obj(v, i, x), true;
 if (v->type == ai_C) {
  ai_flo_t *fp = tray_data(v);
  if (twinp(x)) fp[2*i] = twin_re(x), fp[2*i+1] = twin_im(x);
  else if (isnum(x)) fp[2*i] = toflo(x), fp[2*i+1] = 0;
  else return false;
  return true; }
 if (!isnum(x)) return false;
 if (v->type >= ai_R) tray_put_flo(v, i, toflo(x));
 else tray_put_int(v, i, charmp(x) ? (intptr_t) getcharm(x)
                      : gemp(x) ? (intptr_t) gem_get(x) : sun_get(x));
 return true; }

// equality comparisons inline the fast identity check. ⚠ eqv is declared HERE, not with the
// other bools at the tail: eql below calls it, and a caller cannot precede its declaration.
ai_noinline bool eqv(struct ai*, word, word); // this is for checking equality of non-identical values
// eqv has no value-equality for distinct charms or distinct noms -- identity is
// their whole equality -- so eql settles both inline and skips the noinline call
static ai_inline bool eql(struct ai *g, word a, word b) {
 return a == b ? true : (a & b & 1) || (nomp(a) && nomp(b)) ? false : eqv(g, a, b); }

// threads (and every sounded heap object) end with one tag word: the object's own
// head pointer with bit 1 set. the terminator test is the tag bits and the payload
// pointing back into the pool -- an embedded external pointer can carry (x&3)==2
// but never points into the pool.
#define ai_thread_tag 2
static ai_inline bool tagp(word x, word const *lo, word const *hi) {
 word const *p = (word const*) (x & ~(word) 3);
 return (x & 3) == ai_thread_tag && p >= lo && p < hi; }
// the collection: the state that means something only for the span of one pass, held
// on the C stack of whoever drives it. it is not in the core because between two
// collections there is no answer for any of it, and a stale range is exactly how a
// walk leaves the heap. every function below that can be reached from gcp takes it.
struct ai_gcx {
 word const *p0, *t0;        // the from-space under trace
 word const *f2lo, *f2hi;    // a second from-space (0 = unused); a major traces {major ∪ minor} in one pass
 word *to_lo, *to_hi;        // where survivors land: the tagp range [to_lo, to_hi)
 word *fwd;                  // the forwarding floor: word0 in [fwd, to_hi) = a copy made this pass
 word *cp; };                // the cheney scan cursor
// the pools a heap pointer may live in between collections -- the question bio_of asks
// of a port (heap bio, or the static it cannot own a buffer for).
static ai_inline bool in_live_pool(struct ai *g, word const *p) {
 if (p >= ptr(g) && p < ptr(g) + g->len) return true;             // minor / main pool
 return g->major_pool && p >= g->major_pool && p < g->major_pool + 2 * g->major_len; }   // both major halves
// GC scans run with different [lo,hi), so a terminator must be recognized by which
// live pool its head lands in, not the caller's single range -- else a young-pointing
// terminator under the major range is gcp'd as a field and followed off the heap.
// mid-pass the to-space is a third range: a fresh pair gen_major has not flipped to
// yet, or the new pool gen_grow is copying into -- neither is a pool of g's yet.
static ai_inline bool tagl(struct ai *g, struct ai_gcx *X, word x) {   // range-independent terminator test
 if ((x & 3) != ai_thread_tag) return false;
 word const *p = (word const*) (x & ~(word) 3);
 return (X->to_lo && p >= X->to_lo && p < X->to_hi) || in_live_pool(g, p); }
static ai_inline union u *tagthread(union u *h, uintptr_t len) {
  return h[len].x = word(h) | ai_thread_tag, h; }
#define topof(g) ((word*)g+g->len)
static ai_inline struct ai_tag { union u *head; union u end[]; } *ttag(struct ai*g, union u *k) {
 // scan k forward to its terminator; a tenured object lives in the major pool, so pick the range
 word *lo, *hi;
 if (ptr(k) >= g->major_base && ptr(k) < g->major_hp) lo = g->major_base, hi = g->major_hp;
 else lo = ptr(g), hi = topof(g);
 while (!tagp(k->x, lo, hi)) k++;
 return (struct ai_tag*) k; }
static ai_inline union u *tag_head(struct ai_tag *t) {
 return cell(word(t->head) & ~(word) 3); }

static ai_inline union u *clip(struct ai *g, union u *k) {
 return tagthread(k, cell(ttag(g, k)) - k); }



static ai_inline struct ai_mint *ini_missing(struct ai_mint *y, uintptr_t serial) {
 return y->ap = lvm_sym, y->serial = serial, y; }

// the spelling hash a fresh nom caches in its `dig` slot (same fnv walk as the
// KString lane in hash(), so a nom and its name string hash alike)
static ai_inline uintptr_t nom_dig(uintptr_t name) {
 uintptr_t n = len(name), h = mix;
 char const *bs = txt(name);
 while (n--) h ^= (uint8_t) *bs++, h *= mix;
 return h; }

static ai_inline struct ai_nom *ini_nom(struct ai_nom *y, uintptr_t name, uintptr_t dig) {
 return y->ap = lvm_nom, y->name = name, y->dig = dig, y; }

static ai_inline struct ai_str *ini_str(struct ai_str *s, uintptr_t len) {
 s->ap = lvm_str, s->len = len;
 ((word*) s->bytes)[b2w(len + 1) - 1] = 0;   // tail word first: pad + NUL stay zero under the fill
 return s; }

// the unique empty string: data-segment, immortal (gcp's out-of-pool
// short-circuit); a zero-length string is never heap-allocated.
// () -- the one serial-0 mint, shared by every core (serial 0 is never drawn, so
// it is unique + least in the order). see the ZeroPoint macro in love.h.


static ai_inline uintptr_t rot(uintptr_t x) {
  int const s = sizeof(uintptr_t) * 4; // shift bits = word bits / 2 = sizeof(word) * 4
  return (x << s) | (x >> s); }

// the four doors that are not a device; spelled out beside their readn/writen
extern struct ai_port_vt const ai_to_vt, ai_closed_vt, ai_ci_vt;

// the pool's spare half: the core sits at the base of the active one, so the scratch
// a walk borrows starts one pool length up
static ai_inline void *off_pool(struct ai *g) { return (word*) g + g->len; }
static ai_inline struct ai *pushq(struct ai*g) { return intern(ai_strof(g, "\\")); }
static ai_inline struct ai *push0(struct ai*g) { return ai_push(g, 1, zero); }
static ai_inline size_t llen(word l) {
 size_t n = 0;
 while (chainp(l)) n++, l = B(l);
 return n; }
static ai_inline struct ai*ai_pop(struct ai*g, uintptr_t n) {
 return ai_core_of(g)->sp += n, g; }

// ============================================================================
// macros (hoisted from all merged units; see section banners below)
// ============================================================================






#define min(p,q) ((p)<(q)?(p):(q))
#define max(p,q) ((p)>(q)?(p):(q))




#define limb_base ((ai_dlimb) 1 << limb_bits)

#define yield_interval 64
// fairness yields between parked-ring sweeps, a separate counter from yield_interval:
// a yield walks the short run ring, a sweep is a syscall over the parked ring, and one
// knob cannot price both. this bounds only how long a ready parked task waits behind
// a peer that never blocks -- an i/o task sweeps on its own blocking path first.
#define sweep_interval 16
// a fairness yield clears any stale one-shot park intention first: lvm_fgetc never
// clears the fd on a successful read, and a periodic yield that inherited it would
// park this task on that fd for good. g->parked joins the guard: a server whose
// every client is blocked leaves a self-ring, and a tasks-only test stops firing.
#define YieldCheck() \
  if ((g->tasks->m != g->tasks || g->parked) && ++g->yield_ctr >= yield_interval) \
    { g->next_wait_fd = -1; g->next_wake_at = 0; ai_musttail return Ap(lvm_yield_sw, g); }
#define argn(nom, i) lvm(nom) { Have1(); Sp[-1] = Sp[i]; Sp -= 1; Ip += 1; ai_musttail return Continue(); }
#define quon(nom, v) lvm(nom) { Have1(); Sp -= 1; Sp[0] = putcharm(v); Ip += 1; ai_musttail return Continue(); }

#define Ana(n, ...) struct ai *n(struct ai *g, struct env **c, intptr_t x, ##__VA_ARGS__)
#define Cata(n, ...) struct ai *n(struct ai *g, struct env **c, ##__VA_ARGS__)
#define incl(e, n) ((e)->len += ((n)<<1))
#define Kp (g->ip)
#define cata1(n, ...) static Cata(n) { return __VA_ARGS__, pull(g, c); }
#define forget() (ai_core_of(g)->root=(mm0),g)




#define avm_unit(a, b) \
 if (mintp(a) || mintp(b)) ai_musttail return Push(ZeroPoint)
#define avm_div(op, c_op) lvm(lvm_##op) { \
 word a = Sp[0], b = Sp[1]; \
 if (charmp(a) && charmp(b)) { \
  intptr_t av = getcharm(a), bv = getcharm(b); \
  if (bv != 0 && !(av == INTPTR_MIN && bv == -1)) { \
   intptr_t t = av c_op bv; \
   if (t >= mincharm && t <= maxcharm) \
    ai_musttail return Push(putcharm(t)); } } \
 avm_unit(a, b); \
 ai_musttail return Ap(lvm_##op##n, g); }
#define bit_slow(n, c_op, vop) lvm(lvm_##n##_slow) {          \
 word a = Sp[0], b = Sp[1], _res;                                     \
 if (!intp(a) || !intp(b)) ai_musttail return Push(ZeroPoint);        \
 if (bigp(a) || bigp(b)) { Pack(g); g = ai_big_bitop(g, vop);         \
  if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g);                \
  ai_musttail return Resume(); }                                      \
 Have(box_req);                                                       \
 emit_int(_res, toint(a) c_op toint(b));                                    \
 ai_musttail return Push(_res); }
#define mvm1(n) lvm(lvm_##n) { g->b = (ai_word) (uintptr_t) (ai_##n); ai_musttail return Ap(lvm_math1, g); }
#define m1(_) _(sin) _(cos) _(tan) _(atan)   // the real-only unaries; sqrt/exp/log widen to complex and have their own aps
#define cmp_lt(nom, vop) lvm(nom) { \
 word a = Sp[0], b = Sp[1]; \
 if (__builtin_expect(charmp(a) && charmp(b), 1)) { \
  intptr_t r = vcmp_int(vop, a, b); \
  if (Ip[1].ap == lvm_cond) { Sp += 2; Ip = r ? Ip + 3 : Ip[2].m; ai_musttail return Continue(); } \
  ai_musttail return Push(r ? putcharm(1) : zero); } \
 g->b = (ai_word) (vop); ai_musttail return Ap(lvm_cmp_ord, g); }

// --------------------------------------------------------------------------
// THE TU SEAM. src/love*.c is one runtime cut into translation units so no single
// one is the whole build's critical path; everything not named here stays static to
// its own file. an always_inline that crosses loses the attribute: a call to one
// cannot cross a TU, and hoisting the body here drags its callees along too.
// --------------------------------------------------------------------------
struct ai; struct ai_bio; struct ai_cask; struct ai_def; struct ai_io; struct ai_mint; struct ai_nom; struct ai_port_vt; struct ai_r; struct ai_str; struct ai_tray; struct arib; struct clonf; struct env; struct img_ctx;
// nifs.h lands in love.c, so def1 reaches the image codec through these. a count,
// because countof wants the array's complete type and an extern one has none.
extern struct ai_def const *const ai_def1;
extern uintptr_t const ai_def1_n;
extern union u const callout_drive[];
extern union u const yield_c[];
struct ai_bio *bio_of(struct ai *g, struct ai_io *i);
char *code_install(struct ai *g, char const *src, size_t n), *code_adopt(struct ai *g, char const *src, size_t n);
char *ai_code_window(char *p);
void code_free(struct ai *g, char *code), code_fin(struct ai *g), jk_ini(struct ai *g);
int code_in(struct ai *g, uintptr_t v);
size_t code_len(char *code);
// the jk slots (g->jk): what a native reads off g -- the emitter's `jk` law names them the same
enum { JkChain, JkStr, JkMap, JkNom, JkMint, JkGem, JkCask, JkDrive, JkResume, JkCur, JkUnc };
union u *fn_base(union u *k, int *nargs);
struct ai
 *ai_eval_(struct ai *g),
 *ioputc(struct ai*g, int c),
 *ioputs(struct ai*g, char const *s),
 *gen_grow(struct ai *g, uintptr_t len1),
 *gen_major(struct ai *g, uintptr_t req0, bool *tight),
 *ored(struct ai *g, int kind), *zflush(struct ai*g);
uintptr_t
 bshape(word a, word b, uintptr_t *R),
 shash(struct ai *g, word x, struct arib *env, word *base),
 hash_at(struct ai *g, intptr_t x, word *base),
 map_probe(struct ai *g, word m, word k, bool *found);
struct ai_str *seq_cat(struct ai *g, void *w, word a, word b);
intptr_t
 fn_arg(union u *k, int i, int nargs),
 *task_io(struct ai *g),
 vcmp_flo(int op, ai_flo_t a, ai_flo_t b),
 vcmp_int(int op, intptr_t a, intptr_t b),
 io_route(struct ai *g, word x),
 hot_hook(word h),
 fn_src(struct ai *c, union u *k, word x);
void
 *ai_libc_alloc(struct ai*g, void *p, size_t n),
 bshape_put(uintptr_t *shape, uintptr_t R, word a, word b),
 bstride(struct ai_tray *v, uintptr_t R, intptr_t *c),
 gen_wb(struct ai *g, word src, word p),
 gen_wb_cell(struct ai *g, void *cl, word v);
// the broadcast walk every elementwise lane runs: an odometer over the result shape
// (rightmost axis fastest) carrying each operand's flat offset, oa and ob, by that
// operand's stride on the axis (0 on a scalar, or an axis of size 1). the arrays sit
// in the fill's own frame, so an lvm wrapper stays a leaf and its tail a jump.
struct bcast { uintptr_t R; uintptr_t const *shape; intptr_t oa, ob, ca[maxrank], cb[maxrank], idx[maxrank]; };
static ai_inline void bc_open(struct bcast *w, struct ai_tray *va, struct ai_tray *vb,
                              uintptr_t R, uintptr_t const *shape) {
 w->R = R, w->shape = shape, w->oa = w->ob = 0;
 for (uintptr_t j = 0; j < R; j++) w->idx[j] = 0;
 bstride(va, R, w->ca), bstride(vb, R, w->cb); }
static ai_inline void bc_step(struct bcast *w) {          // one tick: an axis advances, the ones past it wrap
 for (intptr_t j = (intptr_t) w->R - 1; j >= 0; j--) {
  if (++w->idx[j] < (intptr_t) w->shape[j]) { w->oa += w->ca[j], w->ob += w->cb[j]; return; }
  w->idx[j] = 0, w->oa -= ((intptr_t) w->shape[j] - 1) * w->ca[j], w->ob -= ((intptr_t) w->shape[j] - 1) * w->cb[j]; } }
ai_flo_t vop_flo(int op, ai_flo_t a, ai_flo_t b);
bool
 bio_rpending(struct ai_bio *b),
 wait_buffered(struct ai *g, lvm_t *ap, word x, int fd),
 clo_nfhash(struct ai *g, word x, uintptr_t *out, word *base),
 fn_partialp(union u *k),
 in_heap(struct ai *c, word x),
 iop(word x),
 lam_isp(struct ai *g, word x);
#endif
