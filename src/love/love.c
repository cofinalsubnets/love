// love.c -- g, stack, sys, str, sym, chain, tray; the shared layouts are love.h
#include "love.h"
// a nom's cached spelling hash: hash()'s KString walk, so a nom and its name hash alike
static love_inline uintptr_t nom_dig(uintptr_t name) {
 uintptr_t n = len(name), h = mix;
 char const *bs = txt(name);
 while (n--) h ^= (uint8_t) *bs++, h *= mix;
 return h; }

// the kernel we woke on (0 unprobed, 1 linux, 2 freebsd, 3 netbsd, -1 inle): moonlibc's os.c
// owns it where linked. weak unlike the doors, since its zero is already an honest answer
__attribute__((weak)) long __love_osv;
#include <stddef.h>
struct chain;
static char *add_emit(struct g *g, char *w, word x);
static intptr_t seq_byte(word x);
// nifs.h lands mid-file and names these (lvm_subn's body comes out of avm_slow)
static lvm_t
 lvm_apof, lvm_stack, lvm_cap, lvm_casknew, lvm_chainp, lvm_clock, lvm_cup,
 lvm_gauge, lvm_intf, lvm_key, lvm_kreg, lvm_link, lvm_mint, lvm_mintp, lvm_lib, lvm_namep,
 lvm_nclock, lvm_nomctor, lvm_nomp, lvm_packp, lvm_please, lvm_setstack, lvm_setp,
 lvm_snip, lvm_sitsp, lvm_subidx, lvm_cats, lvm_strp, lvm_sub, lvm_subn, lvm_sunp, lvm_tune, _lvm_help_scare, _lvm_yield_c;
static struct g
 *ini_0(struct g*g, uintptr_t len0);
static uintptr_t stringlen(struct g *g, word x);
// `love-version`: -DLvVersion wins (love0 pins "bootstrap"); -DLvHaveVersionH since mooncc
// has no __has_include
#ifndef LvVersion
# if defined(LvHaveVersionH) || (defined(__has_include) && __has_include("love_version.h"))
#  include "love_version.h"
# endif
#endif
#ifndef LvVersion
#define LvVersion "unknown"
#endif
word const map_gap_cell = 0; // FIXME why do we need 0 as a constant :/
struct str0 const str_empty = { .ap = lvm_str, .len = 0 };
struct mint const mint_zero = { .ap = lvm_sym, .serial = 0 };
// ===== g =====
enum status fin(struct g *g) {
 enum status s = code_of(g);
 if ((g = core_of(g))) {
   for (struct fz *fz = g->fz; fz; fz->fn(g, fz->p), fz = fz->next); // run finalizers
   code_fin(g);                                 // ..then the native arena they hand blobs back to
   if (g->rem) alloc(g->rem, 0);
   if (g->major_base) image_drop(g->major_base), alloc(g->major_base, 0);
   alloc(g, 0); }                       // ..the pool is g, so it goes last
 return s; }

// pushes the map a row binds into: the book, or its module's tablet, minted into g->lib on first sight
static struct g *def_home(struct g *g, char const *m) {
 if (!ok(g)) return g;                                       // ..so g is the core, unmasked
 if (!m) return push(g, 1, A(g->stack));
 if (!ok(g = intern(strof(g, m)))) return g;              // [nom ..]
 word t = mapget(g, zero, g->sp[0], g->lib);
 if (t != zero) return g->sp[0] = t, g;                         // known: [tab ..]
 if (!ok(g = map_new(g))) return g;                          // [tab nom ..]
 if (!ok(g = push(g, 1, g->lib))) return g;              // [mods tab nom ..]
 if (!ok(g = push(g, 1, g->sp[1]))) return g;             // [tab mods tab nom ..]
 if (!ok(g = push(g, 1, g->sp[3]))) return g;             // [nom tab mods tab nom ..]
 if (!ok(g = mapput(g))) return g;                        // mods[nom] = tab: [mods tab nom ..]
 return g->sp[2] = g->sp[1], g->sp += 2, g; }                   // [tab ..]

struct g *defn(struct g*g, struct def const*defs, uintptr_t n) {
 while (n--) {
  g = mapput(intern(strof(
       push(def_home(g, defs[n].m), 1, defs[n].v.x), defs[n].n)));
  if (!ok(g)) return g;
  g->sp++; }                                                    // the home, done with
 return g; }

// FIXME this function should pop the bound value off the stack
// defn for a value that moves: it rides g->sp[0] and is left there; callers pop
struct g *defv(struct g *g, char const *nm) {
 if (!ok(g)) return g;
 g = push(g, 1, A(g->stack));           // [book, value, ..]
 if (!ok(g)) return g;
 g = mapput(intern(strof(push(g, 1, g->sp[1]), nm)));
 if (ok(g)) g->sp++;                               // [value, ..]
 return g; }

// the nif registry and def1, its name table: generated from nifs.l -- edit that, not nifs.h
#include "nifs.h"

static lvm(_lvm_yield_c) { return Pack(g), g; }
union u const yield_c[] = { {_lvm_yield_c} };

// the default help ap: re-encode the raised status (on the core's b), yield to C.
// _lvm_help_scare is outside lvm_* since vmret sounds lvm_* only
static lvm(_lvm_help_scare) { return Pack(g), encode(g, (enum status) g->b); }
lvm(lvm_help) {
 struct g *c = core_of(g);
 c->b = code_of(g);
 love_musttail return Ap(_lvm_help_scare, c); }

char const *nif_name(intptr_t x) {
 intptr_t j = def_index(x);
 return j < 0 ? 0 : def1[j].n; }
word nif_word(char const *nm) {                 // strlen + memcmp: the boards link no strcmp
 size_t n = strlen(nm);
 for (uintptr_t i = 0; i < countof(def1); i++)
  if (strlen(def1[i].n) == n && !memcmp(def1[i].n, nm, n)) return def1[i].v.x;
 return 0; }

// the canonical (linux) errno names for g->errs. 41 and 58 are blanks; os.c maps an
// unknown to 41, which lands 'eunknown
static struct { short v; char n[16]; } const errnames[] = {
 {0,"eunknown"}, {-1,"badarg"}, {1,"eperm"}, {2,"enoent"}, {3,"esrch"},
 {4,"eintr"}, {5,"eio"}, {6,"enxio"}, {7,"e2big"}, {8,"enoexec"},
 {9,"ebadf"}, {10,"echild"}, {11,"eagain"}, {12,"enomem"}, {13,"eacces"},
 {14,"efault"}, {15,"enotblk"}, {16,"ebusy"}, {17,"eexist"}, {18,"exdev"},
 {19,"enodev"}, {20,"enotdir"}, {21,"eisdir"}, {22,"einval"}, {23,"enfile"},
 {24,"emfile"}, {25,"enotty"}, {26,"etxtbsy"}, {27,"efbig"}, {28,"enospc"},
 {29,"espipe"}, {30,"erofs"}, {31,"emlink"}, {32,"epipe"}, {33,"edom"},
 {34,"erange"}, {35,"edeadlk"}, {36,"enametoolong"}, {37,"enolck"}, {38,"enosys"},
 {39,"enotempty"}, {40,"eloop"}, {42,"enomsg"}, {43,"eidrm"}, {44,"echrng"},
 {45,"el2nsync"}, {46,"el3hlt"}, {47,"el3rst"}, {48,"elnrng"}, {49,"eunatch"},
 {50,"enocsi"}, {51,"el2hlt"}, {52,"ebade"}, {53,"ebadr"}, {54,"exfull"},
 {55,"enoano"}, {56,"ebadrqc"}, {57,"ebadslt"}, {59,"ebfont"}, {60,"enostr"},
 {61,"enodata"}, {62,"etime"}, {63,"enosr"}, {64,"enonet"}, {65,"enopkg"},
 {66,"eremote"}, {67,"enolink"}, {68,"eadv"}, {69,"esrmnt"}, {70,"ecomm"},
 {71,"eproto"}, {72,"emultihop"}, {73,"edotdot"}, {74,"ebadmsg"}, {75,"eoverflow"},
 {76,"enotuniq"}, {77,"ebadfd"}, {78,"eremchg"}, {79,"elibacc"}, {80,"elibbad"},
 {81,"elibscn"}, {82,"elibmax"}, {83,"elibexec"}, {84,"eilseq"}, {85,"erestart"},
 {86,"estrpipe"}, {87,"eusers"}, {88,"enotsock"}, {89,"edestaddrreq"}, {90,"emsgsize"},
 {91,"eprototype"}, {92,"enoprotoopt"}, {93,"eprotonosupport"}, {94,"esocktnosupport"}, {95,"enotsup"},
 {96,"epfnosupport"}, {97,"eafnosupport"}, {98,"eaddrinuse"}, {99,"eaddrnotavail"}, {100,"enetdown"},
 {101,"enetunreach"}, {102,"enetreset"}, {103,"econnaborted"}, {104,"econnreset"}, {105,"enobufs"},
 {106,"eisconn"}, {107,"enotconn"}, {108,"eshutdown"}, {109,"etoomanyrefs"}, {110,"etimedout"},
 {111,"econnrefused"}, {112,"ehostdown"}, {113,"ehostunreach"}, {114,"ealready"}, {115,"einprogress"},
 {116,"estale"}, {117,"euclean"}, {118,"enotnam"}, {119,"enavail"}, {120,"eisnam"},
 {121,"eremoteio"}, {122,"edquot"}, {123,"enomedium"}, {124,"emediumtype"}, {125,"ecanceled"},
 {126,"enokey"}, {127,"ekeyexpired"}, {128,"ekeyrevoked"}, {129,"ekeyrejected"}, {130,"eownerdead"},
 {131,"enotrecoverable"}, {132,"erfkill"}, {133,"ehwpoison"} };

static struct g *ini_0(struct g*g, uintptr_t len0) {
 memset(g, 0, sizeof(struct g));
 g->len = len0;
 g->scare_a = g->scare_b = g->scare_c = zero;   // v0..end is GC-walked: raw 0 is not a value
 for (int i = 0; i < hook_n; i++) g->hook[i] = zero;   // unsealed: hot_hook traps until (seal-hook) fills them
 g->hp = g->end, g->sp = (word*) g + len0, g->ip = (union u*) yield_c;
 g->major_len = love_major0;
 g->rem = alloc(NULL, LvRemCap * sizeof(word));
 g->major_base = g->rem ? alloc(NULL, g->major_len * sizeof(word)) : NULL;
 if (!g->major_base) { if (g->rem) alloc(g->rem, 0); return encode(g, status_scare); }
 g->major_hp = g->major_base, g->budget = love_budget;
 g->minor0 = love_minor0, g->major0 = love_major0, g->ratio = gc_ratio;   // the live knobs; `tune` moves them
 g->next_wait_events = wait_in;
 // the kind sentinels and drives a native reaches through g: a blob holds no binary address
 g->reach[ReachChain] = (word) lvm_chain, g->reach[ReachStr] = (word) lvm_str, g->reach[ReachMap] = (word) lvm_map_lookup;
 g->reach[ReachNom] = (word) lvm_nom, g->reach[ReachMint] = (word) lvm_sym, g->reach[ReachGem] = (word) lvm_gembox;
 g->reach[ReachCask] = (word) lvm_cask, g->reach[ReachDrive] = (word) callout_drive, g->reach[ReachResume] = (word) callout_resume;
 g->fair = 64, g->ticks = 0, g->reach[ReachCur] = (word) lvm_cur, g->reach[ReachUnc] = (word) lvm_unc, g->reach[ReachGap] = map_gap;
 // book + macro maps, then the main task thread
 if (ok(g = map_new(g)) && ok(g = map_new(g)) && ok(g = have(g, 9))) {
  union u *M = bump(g, 9);            // sp[0]=macro, sp[1]=book
  M[0].m = M;
  M[1].x = zero;   // sentinel; replaced on first yield
  M[2].x = zero;   // main pid
  M[3].x = zero;   // wake_at: zero means "always runnable"
  M[4].x = putcharm(-1);  // wait_fd: -1 = not waiting on I/O
  M[5].x = putcharm(wait_in);   // wait_events: the read direction, the default
  M[6].x = ZeroPoint;   // help: () until the first (hear f)
  M[7].x = ZeroPoint;   // stdio: () until the first (wear l)
  g->tasks = tagthread(M, 8);
  g->parked = NULL;
  // book[zero] = macro: the macro table has no field of its own
  g = push(g, 1, zero);
  g = mapput(g);                     // -> sp[0] = book
  g->stack = g->sp[0];
  // g->stack is a chain of books walked head-first (stacklook): a later layer prepends and shadows
  if (ok(g = have(g, Width(struct chain)))) {
   struct chain *ly = (void*) bump(g, Width(struct chain));
   ini_chain(ly, g->sp[0], ZeroPoint);
   g->stack = (word) ly; }
  g = pop(g, 1);
  // the weak intern map, before the first intern; outside the traced v0 region
  g = map_new(g);
  if (ok(g)) g->symbols = pop1(g);
  if (ok(g = map_new(g))) g->lib = pop1(g);   // the registry, before the first modtab
  struct def def0[] = {
   {"in", {.x = (word) &love_stdin}, 0},
   {"out", {.x = (word) &love_stdout}, 0},
   {"err", {.x = (word) &love_stderr}, 0},
   // the doors prel builds tap and jug from; mopped at birth (egg.l)
   {"ci-vt", {.x = (word) &ci_vt}, 0},
   {"to-vt", {.x = (word) &to_vt}, 0},
   // this build's fixnum bounds, which differ by word width
   {"max-charm", {.x = putcharm((word)((uintptr_t)-1 >> 2))}, 0},
   {"min-charm", {.x = putcharm(-(word)((uintptr_t)-1 >> 2) - 1)}, 0},
   // glazed code tail-jumps, which only the threaded build honors: auto.l reads this
   {"love-tco", {.x = putcharm(tco)}, 0}, };
  g = defn(g, def0, countof(def0));
  // the book, the orth map (the chain stays C-side), read after the rows above: each one
  // allocates, so a copy taken with them could be moved
  if (ok(g = push(g, 1, A(g->stack))) && ok(g = defv(g, "book"))) g->sp++;
  // an instruction row binds as its op charm: no code address belongs in a love value
  for (uintptr_t j = 0; j < countof(def1); j++) {
   struct def d = def1[j];
   if (!nif_cell(d.v.k)) d.v.x = putcharm(op_index((intptr_t) d.v.ap));
   g = defn(g, &d, 1); }
  if (ok(g = strof(g, LvVersion)))            // a live string, so defv, not a def
   g = pop(defv(g, "love-version"), 1);
  // `love-arch`: the glaze's target, a nom in prel.l's arch-canon spelling
#if defined(__x86_64__)
  #define LvArch "x64"
#elif defined(__aarch64__)
  #define LvArch "a64"
#elif defined(__riscv)
  #define LvArch "rv64"
#elif defined(__wasm__)
  #define LvArch "wasm"
#else
  #define LvArch "other"
#endif
  if (ok(g = intern(strof(g, LvArch))))
   g = pop(defv(g, "love-arch"), 1);
  // g->errs: errno -> its nom, interned here so no error path allocates. -1 'badarg is refused
  // before any syscall
  if (ok(g = map_new(g))) {
   for (uintptr_t n = countof(errnames); ok(g) && n--;)
    g = mapput(push(intern(strof(g, errnames[n].n)), 1, putcharm(errnames[n].v)));
   if (ok(g)) g->errs = pop1(g); }
  // the kind roster (g->kinds): enum q row -> its nom, `kind`'s answer for a built-in
  if (ok(g = map_new(g))) {
   char const *p = kind_names;
   for (intptr_t i = 0; ok(g) && *p; i++) {
    while (*p == ' ') p++;
    char nm[16], *q = nm;
    while (*p && *p != ' ') *q++ = *p++;
    *q = 0;
    g = mapput(push(intern(strof(g, nm)), 1, putcharm(i))); }
   if (ok(g)) g->kinds = pop1(g); }
  // g->knom: love.h's Kn rows; g->kreg: name -> (serial . table), pinned by post.l's `coin`
  { char const *const ns[KnN] = { "name", "+", "*", "ap", "-", "net", "star", "/",
                                  "payload", "<", "=", "int", "ceil", "lambda", "cask", "port", "coin" };
    for (int i = 0; ok(g) && i < KnN; i++)
     if (ok(g = intern(strof(g, ns[i])))) g->knom[i] = pop1(g); }
  { char const *const ns[RnN] = { "\\", "list", "hash", "tuple", "tablet", "iota", "mono", "torn", "@", ",", "weave" };
    for (int i = 0; ok(g) && i < RnN; i++)
     if (ok(g = intern(strof(g, ns[i])))) g->rnom[i] = pop1(g); }
  if (ok(g = map_new(g))) g->kreg = pop1(g);
 }
 return g; }

word love_err(struct g *g, int e) {
 g = core_of(g);
 word v = mapget(g, 0, putcharm(e), g->errs);
 return v ? v : mapget(g, 0, zero, g->errs); }

// the system process, a mutable global: inle's /proc reads it from under the syscall
// boundary, where no g is in hand. moved only by gen_grow
struct g *love_system;

// the once-laid tables, filled by the first start (ini or love_image_load), read-only after.
// arm32 has no exchange, and its boards start one core before any interrupt
static int once_lock, once_done;
static love_inline void once_take(int *l) {
#if !defined(__arm__)
 while (__sync_lock_test_and_set(l, 1)) continue;
#else
 (void) l;
#endif
 }
static love_inline void once_give(int *l) {
#if !defined(__arm__)
 __sync_lock_release(l);
#else
 (void) l;
#endif
 }
int love_once(void) {
 once_take(&once_lock);
 if (!once_done) once_done = ops_fill();
 int ok = once_done;
 once_give(&once_lock);
 return ok; }

struct g *ini(void) {
 if (!love_once()) return encode(NULL, status_scare);
 uintptr_t const len0 = love_minor0;
 struct g *g = alloc(NULL, len0 * sizeof(word));
 if (g == NULL) return encode(g, status_scare);
 g = ini_0(g, len0);
 return ok(g) ? (love_system = g) : g; }

// ===== stack =====
static struct g *pushr(struct g *g, uintptr_t m, uintptr_t n, va_list xs) {
 if (n == m) return please(g, m);
 word x = va_arg(xs, word);
 mm(g, &x);
 g = pushr(g, m, n + 1, xs);
 um(g);
 if (ok(g)) *--g->sp = x;
 return g; }

// push may collect: when the stack meets the heap, or on the push a law counted down to
struct g *push(struct g *g, uintptr_t m, ...) {
 if (!ok(g)) return g;
 va_list xs;
 va_start(xs, m);
 uintptr_t n = 0;
#ifdef LvGcStress
 g = pushr(g, m, n, xs);              // push may collect, so under stress every one does, as have does
#else
 if (avail(g) < m || (g->push_gc && !--g->push_gc)) g = pushr(g, m, n, xs);
 else for (g->sp -= m; n < m; g->sp[n++] = va_arg(xs, word));
#endif
 va_end(xs);
 return g; }

struct g *gxl(struct g *g) {
 if (ok(g = have(g, Width(struct chain)))) {
  struct chain *p = bump(g, Width(struct chain));
  ini_chain(p, g->sp[0], g->sp[1]);
  *++g->sp = (word) p; }
 return g; }

struct g *gxr(struct g *g) {
 if (ok(g = have(g, Width(struct chain)))) {
  struct chain *p = bump(g, Width(struct chain));
  ini_chain(p, g->sp[1], g->sp[0]);
  *++g->sp = (word) p; }
 return g; }

// ===== sys =====
op11(lvm_clock, putcharm(love_clock() - (charmp(Sp[0]) ? getcharm(Sp[0]) : 0)))

// monotonic ns, for differences; clock stays ms, since ns wraps 32 bits every 4.3s
op11(lvm_nclock, putcharm(nclock() - (charmp(Sp[0]) ? getcharm(Sp[0]) : 0)))

// (please x): () a minor, a positive charm a major; answers n_gc. force leaves the nursery be
static lvm(lvm_please) {
 word n = Sp[0];
 Pack(g);
 if (!ok(g = force(g, charmp(n) && getcharm(n) > 0))) love_musttail return Ap(_lvm_ghelp, g);
 Unpack(g);
 Sp[0] = putcharm((intptr_t) g->n_gc);
 Ip += 1; love_musttail return Continue(); }

// (gauge 0) -> a list of seventeen VM stats:
//   [0] len       pool size (words)
//   [1] heap      words used from base (core + live heap)
//   [2] stack     stack height (words)
//   [3] n_gc      collections so far
//   [4] max_len   peak pool size (words)
//   [5] max_heap  peak live heap after a collection (words)
//   [6] n_seen    Σ heap occupancy entering each collection (scanned = live + dead, words)
//   [7] n_evac    Σ heap survivors copied out each collection (live, words)
//   [8] old       the tenured set: words live in the major pool
//   [9] rem_miss  rem-set entries dropped on overflow since the last collection
//  [10] rem_hi    peak remembered-set size
//  [11] n_minor   minor collections so far (majors = n_gc - n_minor)
//  [12] major_cap the major pool's reserved footprint: major_len words
//  [13] n_resize  pool reallocations so far
//  [14] minor_hi  peak words one minor copied (the pause)
//  [15] major_hi  peak words one major copied
//  [16] ticks     work in 64-step units: native refills and fairness yields, a clock-free cost
static lvm(lvm_gauge) {
 enum { N = 17 };
 Have(N * Width(struct chain));
 struct chain *c = (struct chain*) Hp;
 Hp += N * Width(struct chain);
 #define Gs(i, v) ini_chain(c + (i), putcharm((intptr_t) (v)), (i) + 1 < N ? (intptr_t) word(c + (i) + 1) : (intptr_t) ZeroPoint)
 Gs(0, g->len);
 Gs(1, Hp - ptr(g));
 Gs(2, ptr(g) + g->len - Sp);
 Gs(3, g->n_gc);
 Gs(4, g->max_len);
 Gs(5, g->max_heap);
 Gs(6, g->n_seen);
 Gs(7, g->n_evac);
 Gs(8, g->major_hp - g->major_base);
 Gs(9, g->rem_miss);
 Gs(10, g->rem_hi);
 Gs(11, g->n_minor);
 Gs(12, g->major_len);
 Gs(13, g->n_resize);
 Gs(14, g->minor_hi);
 Gs(15, g->major_hi);
 Gs(16, g->ticks);
 #undef Gs
 love_musttail return Answer(word(c)); }

// (tune v) -> the four live GC knobs as a list, in words:
//   [0] budget  total footprint cap (minor + 2*major); 0 = unbounded
//   [1] minor0  the nursery floor every resize clamps up to
//   [2] major0  the major pool's grow/shrink step
//   [3] ratio   the nursery grows while copied/allocated tops 1/ratio
// (tune ()) reads; four numbers write and answer the old ones; a wrong shape just reads.
// a knob lands at the next collection; a bake does not carry them, so a woken image tunes again
static lvm(lvm_tune) {
 enum { N = 4 };
 Have(N * Width(struct chain));
 word x = Sp[0];                             // post-Have
 struct chain *c = (struct chain*) Hp;
 Hp += N * Width(struct chain);
 #define Ts(i, v) ini_chain(c + (i), putcharm((intptr_t) (v)), (i) + 1 < N ? (intptr_t) word(c + (i) + 1) : (intptr_t) ZeroPoint)
 Ts(0, g->budget);
 Ts(1, g->minor0);
 Ts(2, g->major0);
 Ts(3, g->ratio);
 #undef Ts
 word x1 = chainp(x) ? B(x) : ZeroPoint, x2 = chainp(x1) ? B(x1) : ZeroPoint,
      x3 = chainp(x2) ? B(x2) : ZeroPoint;
 if (chainp(x3) && B(x3) == ZeroPoint && charmp(A(x)) && charmp(A(x1)) && charmp(A(x2)) && charmp(A(x3))) {
  intptr_t b = getcharm(A(x)), mi = getcharm(A(x1)), ma = getcharm(A(x2)), ra = getcharm(A(x3));
  // a knob no heap could hold is refused, as a 0 is: the sizers scale them
  g->budget = b > 0 ? (uintptr_t) b : 0;     // <= 0 is unbounded, not a refusal
  if (mi > 0 && (uintptr_t) mi <= words_max / 4) g->minor0 = (uintptr_t) mi;
  if (ma > 0 && (uintptr_t) ma <= words_max / 4) g->major0 = (uintptr_t) ma;   // the step divides
  if (ra > 0 && ra <= 1024) g->ratio = (uintptr_t) ra; }   // a vast one overflows the grow test
 love_musttail return Answer(word(c)); }

// (apof x): x's kind pointer as a fixnum, 0 for an immediate; the glaze's type guards read it
static lvm(lvm_apof) {
 word x = Sp[0];
 Sp[0] = putcharm(evenp(x) ? (uintptr_t) cell(x)->ap : 0);
 Ip += 1;
 love_musttail return Continue(); }

lvm(lvm_reach_offset) { love_musttail return Answer(putcharm((intptr_t) offsetof(struct g, reach))); }
// (nat? f): a native closure, entered directly at arity 1 or through lvm_cur with the code at
// value[2]; a woken one's entry may still be lvm_lazy, its header naming the code
lvm(lvm_natp) {
 word x = Sp[0];
 union u *k = evenp(x) ? cell(x) : NULL, *e = k && k->ap == lvm_cur ? k + 2 : k;
 int nat = e && (code_in(g, (uintptr_t)(e->ap == lvm_lazy ? k[-1].ap : e->ap))
                 || (e->ap == lvm_deferfwd && k[-1].ap == lvm_deferfwd));   // a deferred one that declined: its twin still at value[1]
 love_musttail return Answer(putcharm(nat)); }
// (arena 0) -> [mapped bumped free spans]: the code arena's bytes and its free list's length
lvm(lvm_arena) {
 enum { N = 4 };
 Have(N * Width(struct chain));
 struct chain *c = (struct chain*) Hp;
 Hp += N * Width(struct chain);
 for (int i = 0; i < N; i++) ini_chain(c + i, putcharm((intptr_t) code_stat(g, i)), i + 1 < N ? (intptr_t) word(c + i + 1) : (intptr_t) ZeroPoint);
 love_musttail return Answer(word(c)); }
// a woken native's entry until its code is seated. the header names the code, one word behind
// an arity-1 entry and three behind a curried one's
lvm(lvm_lazy) {
 union u *h = Ip[-2].ap == lvm_cur && oddp(Ip[-1].x) ? Ip - 3 : Ip - 1;
 if (code_seat(g, (char const*) h->ap)) { Pack(g); love_musttail return Ap(_lvm_ghelp, encode(g, status_scare)); }
 Ip->ap = h->ap;
 love_musttail return Continue(); }

// (cue? p): would `see` answer without parking? any of the park law's three terms (pushback, a
// buffered run, the fd). a hung-up fd is ready (see answers -1); a non-port asks stdin
static lvm(lvm_key) {
 Sp[0] = io_route(g, iop(Sp[0]) ? Sp[0] : (word) &love_stdin);
 struct io *i = (struct io*) Sp[0];
 Sp[0] = (getcharm(i->ungetc_buf) != EOF || io_pending(g, i)
          || ready((int) io_fd(i), wait_in)) ? putcharm(1) : zero;
 Ip += 1;
 love_musttail return Continue(); }

// ===== str =====
struct g *str0(struct g *g, uintptr_t len) {
 if (!len) { if (ok(g = have(g, 1))) *--g->sp = EmptyString; return g; } // never alloc empty
 uintptr_t req = str_width(len);
 if (ok(g = have(g, req + 1)))
  *--g->sp = word(ini_str(bump(g, req), len));
 return g; }

struct g *strof(struct g *g, char const *cs) {
 uintptr_t len = strlen(cs);
 if (ok(g = str0(g, len))) memcpy(txt(g->sp[0]), cs, len);
 return g; }

op11(lvm_strp, strp(Sp[0]) ? putcharm(1) : zero)
// a cask snips as the string of its bytes, as `pour` reads one. a charlist cuts the same:
// (string (snip l i j)) is (snip (string l) i j)
static lvm(lvm_snip) {
 intptr_t i = oddp(Sp[1]) ? getcharm(Sp[1]) : 0,
          j = oddp(Sp[2]) ? getcharm(Sp[2]) : 0;
 if (Sp[0] == ZeroPoint) Sp[2] = ZeroPoint;
 else if (chainp(Sp[0]) && !nomp(Sp[0])) {
  intptr_t n = (intptr_t) llen(Sp[0]);
  i = max(i, 0), i = min(i, n);
  j = max(j, i), j = min(j, n);
  if (j == i) Sp[2] = ZeroPoint;
  else {
   uintptr_t req = (uintptr_t) (j - i) * Width(struct chain);
   Have(req);
   word y = Sp[0];                               // post-Have
   for (intptr_t k = 0; k < i; k++) y = B(y);
   struct chain *base = (struct chain*) Hp, *w = base;
   Hp += req;
   for (intptr_t k = i; k < j; k++, y = B(y), w++) ini_chain(w, A(y), word(w + 1));
   w[-1].b = ZeroPoint;
   Sp[2] = word(base); } }
 else if (trayp(Sp[0]) && tray(Sp[0])->rank == 1) {
  struct tray *v = tray(Sp[0]);
  intptr_t n = (intptr_t) v->shape[0];
  i = max(i, 0), i = min(i, n);
  j = max(j, i), j = min(j, n);
  uintptr_t m = (uintptr_t) (j - i), req = b2w(tray_bytes(v->type, 1, m));
  Have(req);
  v = tray(Sp[0]);                               // post-Have
  struct tray *t = (struct tray*) Hp;
  Hp += req;
  ini_tray(t, v->type, 1), t->shape[0] = m;
  memcpy(tray_data(t), (char*) tray_data(v) + (uintptr_t) i * love_T[v->type], m * love_T[v->type]);
  Sp[2] = word(t); }
 else if (!strp(Sp[0]) && !caskp(Sp[0])) Sp[2] = zero;
 else {
  struct str *s = bytes_of(Sp[0]), *t;
  i = max(i, 0), i = min(i, (word) len(s));
  j = max(j, i), j = min(j, (word) len(s));
  // no 0-length string is ever allocated (str0 too), so two empties are ==-equal
  if (j == i) Sp[2] = EmptyString;
  else {
   size_t req = str_width(j - i);
   Have(req);
   s = bytes_of(Sp[0]);                          // post-Have
   t = str(Hp);
   Hp += req;
   ini_str(t, j - i);
   memcpy(txt(t), txt(s) + i, j - i);
   Sp[2] = (word) t; } }
 love_musttail return Nextp(1, 2); }

// (sits? s i t): (= t (snip s i (i + #t))) in place; an empty t is 1 anywhere
static lvm(lvm_sitsp) {
 word v = zero;
 if ((strp(Sp[0]) || caskp(Sp[0])) && strp(Sp[2])) {
  struct str *s = bytes_of(Sp[0]), *t = str(Sp[2]);
  intptr_t i = oddp(Sp[1]) ? getcharm(Sp[1]) : 0, m = (intptr_t) len(t);
  if (!m || (0 <= i && i + m <= (intptr_t) len(s) && !memcmp(txt(s) + i, txt(t), (size_t) m))) v = putcharm(1); }
 love_musttail return Answerp(2, v); }

// (subidx s t i): the first index >= i where t sits in s, or -1; an empty t is at i while i <= #s
static lvm(lvm_subidx) {
 intptr_t r = -1;
 if (strp(Sp[0]) && strp(Sp[1])) {
  struct str *s = str(Sp[0]), *t = str(Sp[1]);
  intptr_t n = (intptr_t) len(s), m = (intptr_t) len(t), i = oddp(Sp[2]) ? getcharm(Sp[2]) : 0;
  if (!m) r = i <= n ? i : -1;
  else for (intptr_t k = max(i, 0); k + m <= n; k++) {
   char const *p = memchr(txt(s) + k, txt(t)[0], (size_t) (n - m - k + 1));
   if (!p) break;
   k = p - txt(s);
   if (!memcmp(p, txt(t), (size_t) m)) { r = k; break; } } }
 love_musttail return Answerp(2, putcharm(r)); }

// (cats l): the foldr of + over l, in one allocation when the pieces are all strings or all
// lists (the last list shared, as + shares it); anything else goes to the hook
static lvm(lvm_cats) {
 uintptr_t nstr = 0, nlist = 0, other = 0, bytes = 0, cells = 0, lastn = 0;
 word p = Sp[0], one = ZeroPoint;
 for (; chainp(p) && !nomp(p); p = B(p)) {
  word x = A(p);
  if (x == ZeroPoint) continue;
  if (strp(x)) nstr++, bytes += len(x), one = x;
  else if (chainp(x) && !nomp(x)) {
   uintptr_t k = 0;
   word q = x;
   for (; chainp(q) && !nomp(q); q = B(q)) k++;
   if (q != ZeroPoint) other++;
   else nlist++, cells += lastn, lastn = k, one = x; }
  else other++; }
 if (p != ZeroPoint || other || (nstr && nlist)) {
  Have(2);
  word h = hot_hook(g->hook[hook_cats]), l = Sp[0], *dst = Sp - 2;
  dst[0] = l, dst[1] = h, dst[2] = word(Ip + 1);
  Sp = dst, Ip = (union u*) callout_drive;
  love_musttail return Continue(); }
 if (nstr + nlist <= 1) love_musttail return Answer(one);
 if (nstr) {
  if (!bytes) love_musttail return Answer(EmptyString);
  Have(str_width(bytes));
  struct str *t = ini_str(str(Hp), bytes);
  Hp += str_width(bytes);
  char *w = txt(t);
  for (p = Sp[0]; chainp(p); p = B(p))                           // post-Have
   if (strp(A(p))) memcpy(w, txt(A(p)), len(A(p))), w += len(A(p));
  love_musttail return Answer(word(t)); }
 Have(cells * Width(struct chain));
 struct chain *w = (struct chain*) Hp, *prev = 0;
 Hp += cells * Width(struct chain);
 word head = ZeroPoint;
 uintptr_t k = 0;
 for (p = Sp[0]; chainp(p); p = B(p)) {
  word x = A(p);
  if (x == ZeroPoint) continue;
  if (++k == nlist) { prev->b = x; break; }                      // the last piece is shared
  for (; chainp(x); x = B(x), w++) {
   ini_chain(w, A(x), ZeroPoint);
   if (prev) prev->b = word(w); else head = word(w);
   prev = w; } }
 love_musttail return Answer(head); }

// applying a cask yields 1; byte-identical to lvm_port_io, kept apart by noicf so caskp and iop never collide
lvm(lvm_cask) {
 Ip = cell(*++Sp); *Sp = ZeroPoint; love_musttail return Continue(); }
// (cask n): a zeroed n-byte mutable cask; (cask charlist): one holding those bytes. n <= 0 is ""
static lvm(lvm_casknew) {
 bool listp = chainp(Sp[0]);
 intptr_t n = charmp(Sp[0]) ? getcharm(Sp[0]) : listp ? (intptr_t) llen(Sp[0]) : 0;
 if (n <= 0) love_musttail return Answer(EmptyString);
 uintptr_t sreq = str_width(n),
           breq = Width(struct cask) + Width(struct tag);
 Have(sreq + breq);
 struct str *s = ini_str(str(Hp), n);
 Hp += sreq;
 if (listp) {
  word y = Sp[0];                                            // post-Have
  for (uintptr_t i = 0; i < (uintptr_t) n; y = B(y)) txt(s)[i++] = (char) getcharm(A(y)); }
 else memset(txt(s), 0, n);
 union u *k = (union u*) Hp;
 Hp += breq;
 cask(k)->ap = lvm_cask;
 cask(k)->str = s;
 tagthread(k, Width(struct cask));
 love_musttail return Answer(word(k)); }

// tell the I-cache about fresh code; wasm has no arena and no intrinsic, so a site never asks directly
#ifdef __wasm__
#define code_sync(a, b) ((void) (a), (void) (b))
#else
#define code_sync(a, b) __builtin___clear_cache(a, b)
#endif

// the native code arena: hosted, RX page chunks outside the GC pool, opened W only while an
// install writes (W^X). a blob is [len, span, code..], 16-aligned; span is what its install
// took, which a free hands back: off the bump chunk's end it retracts, else it joins the free
// list, by address, merged with its neighbours, lowest fit first. inle (asked at run time:
// __love_osv < 0) and freestanding seats run heap copies, no finalizer owed.
// fixed = the image's own chunk, never freed blob by blob; own = what the allocator handed,
// NULL off mmap, freed by that address and not the window it runs at
struct code { char *base, *own; size_t len, used; int fixed; struct lazy *lz; struct code *next; };
struct cfree { char *p; size_t n; struct cfree *next; };           // a free span, the list by address
#if __STDC_HOSTED__
#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif
#define CodeChunk ((size_t) 1 << 20)
#define CodeHead (2 * sizeof(uintptr_t))
static size_t code_round(size_t n) { return (n + 15) & ~(size_t) 15; }
static size_t code_page(void) { long q = sysconf(_SC_PAGESIZE); return q > 0 ? (size_t) q : 4096; }
// open [p, p+n) for writing, or seal it; neighbours on the page ride along, and nothing runs meanwhile
static int code_open(char *p, size_t n, int prot) {
 size_t ps = code_page();
 uintptr_t lo = (uintptr_t) p & ~(ps - 1), hi = ((uintptr_t) p + n + ps - 1) & ~(ps - 1);
 return mprotect((void*) lo, hi - lo, prot); }
// the chunk installs bump: the newest that is the arena's, not an image's
static struct code *code_bump(struct g *g) {
 struct code *c = g->code;
 while (c && c->fixed) c = c->next;
 return c; }
// [p, p+n) back to the arena. a free span is only ever beside another of the same chunk
static void code_release(struct g *g, char *p, size_t n) {
 struct code *c = g->code, *b = code_bump(g);
 while (c && !(p >= c->base && p < c->base + c->len)) c = c->next;
 if (!c) return;
 if (c == b && p + n == c->base + c->used) {                     // the bump's top: retract, and past a span below it
  c->used -= n;
  for (struct cfree **l = &g->cfree, *f; (f = *l); l = &f->next)
   if (f->p + f->n == c->base + c->used) { c->used -= f->n, *l = f->next, alloc(f, 0); break; }
  return; }
 struct cfree *pre = NULL, *nx = g->cfree;
 while (nx && nx->p < p) pre = nx, nx = nx->next;
 int lo = pre && pre->p >= c->base && pre->p + pre->n == p, hi = nx && nx->p == p + n && nx->p < c->base + c->len;
 if (lo && hi) pre->n += n + nx->n, pre->next = nx->next, alloc(nx, 0);
 else if (lo) pre->n += n;
 else if (hi) nx->p = p, nx->n += n;
 else {
  struct cfree *f = alloc(NULL, sizeof *f);
  if (!f) return;                                                  // no node: the span stays, unreachable
  f->p = p, f->n = n, f->next = nx;
  if (pre) pre->next = f; else g->cfree = f; } }
static struct code *code_chunk(struct g *g, size_t need) {
 size_t ps = code_page(), len = (need > CodeChunk ? need : CodeChunk);
 len = (len + ps - 1) & ~(ps - 1);
 void *b = mmap(0, len, PROT_READ | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
 if (b == MAP_FAILED) return NULL;
 struct code *c = alloc(NULL, sizeof *c), *o = code_bump(g);
 if (!c) { munmap(b, len); return NULL; }
 if (o && o->used < o->len) {                                     // the old bump's tail is free space now
  char *t = o->base + o->used;
  size_t tn = o->len - o->used;
  o->used = o->len, code_release(g, t, tn); }
 c->base = b, c->own = NULL, c->len = len, c->used = 0, c->fixed = 0, c->lz = NULL, c->next = g->code, g->code = c;
 return c; }
// (code_install g src n): n bytes of code -> their executable address, NULL when no seat can hold them
char *code_install(struct g *g, char const *src, size_t n) {
 size_t need = code_round(CodeHead + n + 1), span = need;
 char *p = NULL;
 for (struct cfree **l = &g->cfree; *l; l = &(*l)->next)     // first fit, lowest address first
  if ((*l)->n >= need) {
   struct cfree *f = *l; p = f->p;
   if (f->n - need >= 32) f->p += need, f->n -= need;
   else span = f->n, *l = f->next, alloc(f, 0);                  // taken whole: the blob owns the rest
   break; }
 if (!p) {
  struct code *c = code_bump(g);
  if (!c || c->len - c->used < need) c = code_chunk(g, need);
  if (!c) return NULL;
  p = c->base + c->used, c->used += need; }
 if (code_open(p, span, PROT_READ | PROT_WRITE)) return code_release(g, p, span), NULL;
 ((uintptr_t*) p)[0] = n, ((uintptr_t*) p)[1] = span;
 memcpy(p + CodeHead, src, n);
 p[CodeHead + n] = 0;
 if (code_open(p, span, PROT_READ | PROT_EXEC)) return code_release(g, p, span), NULL;
 code_sync(p + CodeHead, p + CodeHead + n);
 return p + CodeHead; }
void code_free(struct g *g, char *code) {
 char *p = code - CodeHead;
 for (struct code *c = g->code; c; c = c->next)      // the image packs one blob per body, so its
  if (c->fixed && p >= c->base && p < c->base + c->len) return;   // chunk frees nothing
 code_release(g, p, ((uintptr_t*) p)[1]); }
// the arena, one figure at a time: 0 mapped, 1 bumped, 2 free, 3 free spans, over the chunks
// installs own. a figure, not an array, so the nif keeps no local across its tail
uintptr_t code_stat(struct g *g, int i) {
 uintptr_t s = 0;
 if (i < 2) { for (struct code *c = g->code; c; c = c->next) if (!c->fixed) s += i ? c->used : c->len; }
 else for (struct cfree *f = g->cfree; f; f = f->next) s += i == 2 ? f->n : 1;
 return s; }
int code_in(struct g *g, uintptr_t v) {
 for (struct code *c = g->code; c; c = c->next)
  if (v >= (uintptr_t) c->base && v < (uintptr_t) c->base + c->used) return 1;
 return 0; }
size_t code_len(char *code) { return ((uintptr_t*) code)[-2]; }

// the image's segment, a fixed chunk written through *w. inle's hhdm is NX and mprotect cannot
// lift it off a shared 2 MiB entry, so there the block runs through code_window's low map
static struct code *code_region(struct g *g, size_t n, char **w) {
 struct code *c = alloc(NULL, sizeof *c);
 if (!c) return NULL;
 if (__love_osv < 0) {
  char *b = alloc(NULL, n);
  if (!b) { alloc(c, 0); return NULL; }
  c->base = code_window(b), c->own = *w = b, c->len = c->used = n; }
 else {
  size_t ps = code_page(), len = (n + ps - 1) & ~(ps - 1);
  void *b = mmap(0, len, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (b == MAP_FAILED) { alloc(c, 0); return NULL; }
  c->base = *w = b, c->own = NULL, c->len = c->used = len; }       // the tail is nobody's
 c->fixed = 1, c->lz = NULL, c->next = g->code, g->code = c;
 return c; }
// a heap block is writable as it is
static int code_wopen(struct code *c, char *p, size_t n, int seal) {
 return c->own ? 0 : code_open(p, n, seal ? PROT_READ | PROT_EXEC : PROT_READ | PROT_WRITE); }
static void code_drop(struct g *g, struct code *c) {
 if (c->own) alloc(c->own, 0); else munmap(c->base, c->len); }
// a byte a chunk, shared across fork: which chunks any process of this image has seated
static unsigned char *code_wants(size_t n) {
 void *b = __love_osv < 0 ? MAP_FAILED : mmap(0, n, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANONYMOUS, -1, 0);
 return b == MAP_FAILED ? NULL : b; }
static void code_unwant(unsigned char *w, size_t n) { if (w) munmap(w, n); }
#else
// freestanding: RAM runs as it is; blobs live in the heap (lvm_nif) and an image's segment in the allocator
int code_in(struct g *g, uintptr_t v) { return 0; }
size_t code_len(char *code) { return 0; }
void code_free(struct g *g, char *code) { }
uintptr_t code_stat(struct g *g, int i) { return 0; }
static void code_drop(struct g *g, struct code *c) { alloc(c->own, 0); }
static struct code *code_region(struct g *g, size_t n, char **w) {
 struct code *c = alloc(NULL, sizeof *c);
 char *b = c ? alloc(NULL, n) : NULL;
 if (!b) { if (c) alloc(c, 0); return NULL; }
 c->base = c->own = *w = b, c->len = c->used = n, c->fixed = 1, c->lz = NULL, c->next = g->code, g->code = c;
 return c; }
static int code_wopen(struct code *c, char *p, size_t n, int seal) { return 0; }
static unsigned char *code_wants(size_t n) { return NULL; }
static void code_unwant(unsigned char *w, size_t n) { }
#endif
// a packed segment, seated whole
char *code_adopt(struct g *g, char const *src, size_t n) {
 char *w;
 struct code *c = code_region(g, n, &w);
 if (!c || code_wopen(c, c->base, n, 0)) return NULL;
 memcpy(w, src, n);
 if (code_wopen(c, c->base, n, 1)) return NULL;
 code_sync(c->base, c->base + n);
 return c->base; }
// a segment deflated a chunk at a time, each seated when a native in it first runs. the
// image's table rows are (start, zstart, digest): tab keeps two, sum the third; dic is the preset dictionary
struct lazy { unsigned char const *z, *dz; char *w; unsigned char *seated, *dic, *want; uint64_t *sum; uintptr_t n, nz, nch, nd, ndz; uint64_t tab[]; };
static int code_seat1(struct code *c, uintptr_t k) {
 struct lazy *l = c->lz;
 if (l->seated[k]) return 0;
 if (l->dz && inflate_raw(l->dz, l->ndz, l->dic, l->nd) != (intptr_t) l->nd) return -1;   // the first seat inflates dic
 l->dz = NULL;
 uintptr_t a = (uintptr_t) l->tab[2 * k], b = k + 1 < l->nch ? (uintptr_t) l->tab[2 * k + 2] : l->n,
           za = (uintptr_t) l->tab[2 * k + 1], zb = k + 1 < l->nch ? (uintptr_t) l->tab[2 * k + 3] : l->nz;
 if (image_sum(l->z + za, zb - za, 0) != l->sum[k]                   // a damaged chunk never runs
     || code_wopen(c, c->base + a, b - a, 0)
     || inflate_dict(l->z + za, zb - za, (unsigned char*) l->w + a, b - a, l->dic, l->nd) != (intptr_t)(b - a)
     || code_wopen(c, c->base + a, b - a, 1)) return -1;
 code_sync(c->base + a, c->base + b);
 if (l->want) l->want[k] = 1;
 return l->seated[k] = 1, 0; }
// kept: z outlives the session, else every chunk is seated now. NULL on a bad table
char *code_lazy(struct g *g, size_t n, unsigned char const *z, size_t nz, unsigned char const *tab, uintptr_t nch,
                unsigned char const *dz, size_t ndz, size_t nd, int kept) {
 char *w;
 struct code *c = code_region(g, n, &w);
 struct lazy *l = c ? alloc(NULL, sizeof *l + nch * (3 * sizeof(uint64_t) + 1) + nd) : NULL;
 if (!l) return NULL;
 l->z = z, l->w = w, l->n = n, l->nz = nz, l->nch = nch, l->sum = l->tab + 2 * nch;
 l->seated = (unsigned char*)(l->sum + nch), l->dic = l->seated + nch, l->nd = nd, l->dz = nd ? dz : NULL, l->ndz = ndz;
 for (uintptr_t k = 0; k < nch; k++)
  memcpy(l->tab + 2 * k, tab + 24 * k, 16), memcpy(l->sum + k, tab + 24 * k + 16, 8);
 memset(l->seated, 0, nch);
 l->want = NULL;
 c->lz = l;
 for (uintptr_t k = 0; k < nch; k++) {
  uint64_t a = l->tab[2 * k], za = l->tab[2 * k + 1],
           b = k + 1 < nch ? l->tab[2 * k + 2] : n, zb = k + 1 < nch ? l->tab[2 * k + 3] : nz;
  if (a >= b || za >= zb || b > n || zb > nz || (k == 0 && a)) return NULL; }
 if (kept) l->want = code_wants(nch);
 if (!kept)
  for (uintptr_t k = 0; k < nch; k++) if (code_seat1(c, k)) return NULL;
 return c->base; }
int code_seat(struct g *g, char const *a) {
 for (struct code *c = g->code; c; c = c->next)
  if (c->lz && a >= c->base && a < c->base + c->lz->n) {
   uintptr_t off = (uintptr_t)(a - c->base), lo = 0, hi = c->lz->nch;
   while (hi - lo > 1) { uintptr_t m = (lo + hi) / 2; if (c->lz->tab[2 * m] <= off) lo = m; else hi = m; }
   return code_seat1(c, lo); }
 return 0; }
// before a warm fork: every chunk some process of this image seated, seated here as well
void code_warm(struct g *g) {
 for (struct code *c = g->code; c; c = c->next)
  if (c->lz && c->lz->want)
   for (uintptr_t k = 0; k < c->lz->nch; k++) if (c->lz->want[k] && !c->lz->seated[k] && code_seat1(c, k)) return; }
// the arena is the session's, not the collector's: only its end frees a chunk
void code_fin(struct g *g) {
 for (struct code *c = g->code, *n; c; c = n) {
  n = c->next, code_drop(g, c);
  if (c->lz) code_unwant(c->lz->want, c->lz->nch), alloc(c->lz, 0);
  alloc(c, 0); }
 for (struct cfree *f = g->cfree, *n; f; f = n) n = f->next, alloc(f, 0);
 g->code = NULL, g->cfree = NULL; }

// ===== sym =====
// string s -> the symbol it spells; identity on any other arg
lvm(lvm_intern) {
 if (strp(Sp[0])) {
  if (Sp[0] == EmptyString) love_musttail return Answer(ZeroPoint);  // the empty spelling names ()
  word y;
  Have(intern_reserve(g));
  Pack(g), y = intern_checked(g, str(g->sp[0])), Unpack(g);
  Sp[0] = y; }
 love_musttail return Next(1); }

// (mint _) -> a fresh nameless point; its serial is its GC-stable hash and order key
static lvm(lvm_mint) {
 Have(Width(struct mint));
 struct mint *y = (struct mint*) Hp;
 Hp += Width(struct mint);
 ini_missing(y, ++g->next_serial);
 return
  Sp[0] = word(y),
  Ip += 1,
  Continue(); }

// (nom n): the name a string spells, a name itself, a fresh mint for anything else
static lvm(lvm_nomctor) {
 if (strp(Sp[0]) || namep(Sp[0])) love_musttail return Ap(lvm_intern, g);
 love_musttail return Ap(lvm_mint, g); }

struct g *intern(struct g*g) {
 if (!ok(g)) return g;                        // intern_reserve reads g before have's guard
 if (ok(g = have(g, intern_reserve(g))))
  g->sp[0] = intern_checked(g, str(g->sp[0]));
 return g; }

// what a fresh intern may bump: the atom, plus at the load factor the doubled backing
uintptr_t intern_reserve(struct g *g) {
 word m = g->symbols;
 uintptr_t extra = m && (map_len(m) + 1) * 4 >= map_cap(m) * 3 ? map_back_words(2 * map_cap(m)) : 0;
 return Width(struct nom) + extra; }

// one canonical nom per spelling, minted on a miss; bump-only (intern_reserve)
love_noinline word intern_checked(struct g *g, struct str *b) {
 word m = g->symbols;
 bool found;
 uintptr_t i = map_probe(g, m, word(b), &found);
 if (found) return map_slots(m)[2 * i + 1];
 if ((map_len(m) + 1) * 4 >= map_cap(m) * 3) {
  uintptr_t ncap = 2 * map_cap(m), nmask = ncap - 1;
  union u *nb = map_fill_back(bump(g, map_back_words(ncap)), ncap);
  word *os = map_slots(m), *ns = tablet_back(nb)->slot;
  uintptr_t ocap = map_cap(m), nlen = 0;
  for (uintptr_t j = 0; j < ocap; j++) {
   word k = os[2 * j];
   if (k == map_gap) continue;
   uintptr_t x = hash(g, k) & nmask;
   while (ns[2 * x] != map_gap) x = (x + 1) & nmask;
   ns[2 * x] = k, ns[2 * x + 1] = os[2 * j + 1], nlen++; }
  tablet_back(nb)->len = putcharm(nlen);
  tablet(m)->back = (word) nb, gen_wb(g, m, (word) nb);  // the header keeps its identity
  i = map_probe(g, m, word(b), &found); }
 struct nom *y = ini_nom(bump(g, Width(struct nom)), word(b), nom_dig(word(b)));
 word *slots = map_slots(m);
 slots[2 * i] = word(b), slots[2 * i + 1] = word(y);
 gen_wb(g, map_back(m), word(y));                        // a fresh atom in a tenured backing
 map_len_set(m, map_len(m) + 1);
 return word(y); }

// (nom? x): a non-() mint or a named nom
op11(lvm_nomp, (nomp(Sp[0]) && Sp[0] != ZeroPoint) ? putcharm(1) : zero)
op11(lvm_namep, namep(Sp[0]) ? putcharm(1) : zero)
// mint? and name? partition nom?; the only way to ask, since a mint's spelling is ""
op11(lvm_mintp, (mintp(Sp[0]) && Sp[0] != ZeroPoint) ? putcharm(1) : zero)
op11(lvm_packp, (packp(Sp[0]) || gemp(Sp[0]) || bigp(Sp[0]) || twinp(Sp[0])) ? putcharm(1) : zero)  // arrays + every boxed number
op11(lvm_sunp, bigp(Sp[0]) ? putcharm(1) : zero)
op11(lvm_setp, trayp(Sp[0]) ? putcharm(1) : zero)
// (int x): a gem truncates toward zero, saturating at the charm bounds; a coin whose kind
// spells 'int takes that; the rest pass through
static lvm(lvm_intf) {
 if (trayp(Sp[0])) {                            // a float tray truncates to an int tray, the rest pass
  if (tray(Sp[0])->type != love_R) { Ip += 1; love_musttail return Continue(); }
  g->b = (word) (uintptr_t) (love_trunc); love_musttail return Ap(lvm_vmap1z, g); }
 if (coinp(Sp[0]) && kind_get(g, coin_kind(Sp[0]), KnInt) != ZeroPoint) { g->b = (word) KnInt; love_musttail return Ap(lvm_coin_rung, g); }
 if (gemp(Sp[0])) { flo_t v = gem_get(Sp[0]);
  Sp[0] = putcharm(v >= (flo_t) maxcharm ? maxcharm
                 : v <= (flo_t) mincharm ? mincharm
                 : v != v ? 0 : (intptr_t) v); }
 Ip += 1; love_musttail return Continue(); }

// ===== chain =====
op11(lvm_cap, chainp(Sp[0]) ? A(Sp[0]) : Sp[0])
op11(lvm_cup, chainp(Sp[0]) ? B(Sp[0]) : ZeroPoint)
op11(lvm_stack, g->stack)   // the layer chain; these three are mopped at birth
op11(lvm_setstack, (g->stack = Sp[0], zero))
op11(lvm_kreg, g->kreg)   // post.l's coin/kinds read and pin it
op11(lvm_lib, g->lib)
// push a fresh writable layer at the head of the book chain: the session's scope
struct g *love_open(struct g *g) {
 if (!ok(g = map_new(g))) return g;
 g = gxr(push(g, 1, g->stack));                      // (layer . chain)
 if (!ok(g)) return g;
 g->stack = *g->sp;
 return pop(g, 1); }
// drop the link just below the head: the inverse of one `borrow`
struct g *shelve(struct g *g) {
 if (!ok(g)) return g;
 word bk = g->stack;
 if (!chainp(B(bk))) return g;
 g = gxl(push(g, 2, A(bk), B(B(bk))));              // (head . below-the-neighbour)
 if (!ok(g)) return g;
 g->stack = *g->sp;
 return pop(g, 1); }

op11(lvm_chainp, (chainp(Sp[0]) && !nomp(Sp[0])) ? putcharm(1) : zero)  // a nom is chainp in C but an atom here

static lvm(lvm_link) {
 Have(Width(struct chain));
 struct chain *w = (struct chain*) Hp;
 Hp += Width(struct chain);
 ini_chain(w, Sp[0], Sp[1]);
 *++Sp = word(w);
 Ip++;
 love_musttail return Continue(); }

#define avm_slow(op, vop, ovf, fexpr) lvm(lvm_##op##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (trayp(a) || trayp(b)) { g->b = (word) (vop); love_musttail return Ap(lvm_vbin, g); } \
 if (twinp(a) || twinp(b)) { g->b = (word) (vop); love_musttail return Ap(lvm_twin_bin, g); } \
 if (!isnum(a) || !isnum(b)) love_musttail return Push(ZeroPoint); \
 if (gemp(a) || gemp(b)) { word _res; Have(box_req); \
  flo_t ad = toflo(a), bd = toflo(b); \
  emit_gem(_res, fexpr); \
  love_musttail return Push(_res); } \
 if (!bigp(a) && !bigp(b)) { intptr_t av = toint(a), bv = toint(b), t; \
  if (!ovf(av, bv, &t)) { word _res; Have(box_req); emit_int(_res, t); \
   love_musttail return Push(_res); } } \
 if ((vop) == vop_mul) love_musttail return Ap(lvm_bmul_start, g); /* O(n^2): run yieldable */ \
 Pack(g); g = big_binop(g, vop); \
 if (!ok(g)) love_musttail return Ap(_lvm_ghelp, g); \
 Unpack(g); love_musttail return Continue(); }
#define avm_slowdiv(op, vop, c_op, fexpr, zarm) lvm(lvm_##op##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (trayp(a) || trayp(b)) { g->b = (word) (vop); love_musttail return Ap(lvm_vbin, g); } \
 if (twinp(a) || twinp(b)) { g->b = (word) (vop); love_musttail return Ap(lvm_twin_bin, g); } \
 if (!isnum(a) || !isnum(b)) love_musttail return Push(ZeroPoint); \
 zarm; \
 if (gemp(a) || gemp(b) || b == zero) { word _res; Have(box_req); \
  flo_t ad = toflo(a), bd = toflo(b); \
  emit_gem(_res, fexpr); \
  love_musttail return Push(_res); } \
 if (!bigp(a) && !bigp(b)) { intptr_t av = toint(a), bv = toint(b); \
  if (!(av == INTPTR_MIN && bv == -1)) { word _res; Have(box_req); emit_int(_res, av c_op bv); \
   love_musttail return Push(_res); } } \
 { g->b = (word) (vop); love_musttail return Ap(lvm_bdiv_start, g); } }   /* big // and % run yieldable */
// a mint (() too) is not a number: a numeric lane answers () either side. + and * keep their own
// band rules, () the unit of + and the annihilator of *

avm_slow(add, vop_add, __builtin_add_overflow, ad + bd)
avm_slow(sub, vop_sub, __builtin_sub_overflow, ad - bd)
avm_slow(mul, vop_mul, __builtin_mul_overflow, ad * bd)

avm_slowdiv(fquot, vop_fquot, /, love_trunc(ad / bd), (void) 0)  // truncating toward zero
// a % 0 = a, which keeps a = (a // n) * n + (a % n) at n = 0: (a // 0) * 0 is (), the unit of +
avm_slowdiv(rem, vop_rem, %, love_fmod(ad, bd),
            if (b == zero || (gemp(b) && toflo(b) == 0)) love_musttail return Push(a))

// `/`: an exact integer when b divides a, else a float
lvm(lvm_quotn) {
 word a = Sp[0], b = Sp[1];
 if (trayp(a) || trayp(b)) { g->b = (word) vop_quot; love_musttail return Ap(lvm_vbin, g); }
 if (twinp(a) || twinp(b)) { g->b = (word) vop_quot; love_musttail return Ap(lvm_twin_bin, g); }
 if (!isnum(a) || !isnum(b)) love_musttail return Push(ZeroPoint);
 if (gemp(a) || gemp(b) || b == zero) { word _res; Have(box_req);   // ±inf/NaN on ÷0
  flo_t ad = toflo(a), bd = toflo(b);
  emit_gem(_res, ad / bd);
  love_musttail return Push(_res); }
 if (!bigp(a) && !bigp(b)) { intptr_t av = toint(a), bv = toint(b);  // bv != 0
  if (!(av == INTPTR_MIN && bv == -1)) {                            // exact but overflows: the bignum lane
   if (av % bv == 0) { word _res; Have(box_req); emit_int(_res, av / bv);
    love_musttail return Push(_res); }
   word _res; Have(box_req);
   emit_gem(_res, (flo_t) av / (flo_t) bv);
   love_musttail return Push(_res); } }
 LvmResume(g, big_quot_true) }

// `-` has no kind matrix, so coins are caught here
static lvm(lvm_sub) {
 word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) { intptr_t t;
  if (!__builtin_sub_overflow((intptr_t) getcharm(a), (intptr_t) getcharm(b), &t) &&
      t >= mincharm && t <= maxcharm)
   love_musttail return Push(putcharm(t)); }
 avm_unit(a, b);
 if (coinp(a) || coinp(b)) love_musttail return Ap(lvm_sub_coin, g);
 love_musttail return Ap(lvm_subn, g); }

// `+` on sequences concatenates in order: text and chain are one monoid, so text against a
// list splices in as its bytes, never as one element.
// seq_byte: an exact integer 0..255 in any rep (66.0 is 66), else -1
static love_inline intptr_t seq_byte(word x) {
 if (charmp(x)) { intptr_t v = getcharm(x); return v < 0 || v > 255 ? -1 : v; }
 if (gemp(x)) { flo_t f = gem_get(x);
  if (!(f >= 0 && f <= 255)) return -1;                 // range first (nan fails), so the cast is safe
  return f != (flo_t) (intptr_t) f ? -1 : (intptr_t) f; }
 return -1; }
// the list lane (mx.l's five cells): one operand a chain, the other a chain, string or named symbol
lvm(lvm_add_seq) {
 word a = Sp[0], b = Sp[1];
 if (chainp(a) && chainp(b)) {
  uintptr_t n = llen(a); Have(n * Width(struct chain));
  a = Sp[0], b = Sp[1];
  struct chain *base = (struct chain*) Hp, *w = base;
  Hp += n * Width(struct chain);
  for (word l = a; chainp(l); l = B(l), w++) ini_chain(w, A(l), word(w + 1));
  (w - 1)->b = b;
  love_musttail return Push(word(base)); }
 if (!chainp(a) && !chainp(b)) __builtin_unreachable();   // the matrix's fact, told to the optimizer
 bool front = chainp(b);                                  // the element lands ahead of the list
 word lst = chainp(a) ? a : b, elt = chainp(a) ? b : a;
 if (strp(elt) || nomp(elt)) {              // text splices as its bytes, so + associates across kinds
  uintptr_t n = stringlen(g, elt),
            m = front ? 0 : llen(lst);
  Have((n + m) * Width(struct chain));
  a = Sp[0], b = Sp[1];                                        // post-Have
  front = chainp(b);
  lst = chainp(a) ? a : b, elt = chainp(a) ? b : a;
  struct str *sx = strp(elt) ? str(elt) : nom_str(g, elt);   // a mint has no bytes: n = 0
  unsigned char const *t = sx ? (unsigned char const*) txt(sx) : 0;
  struct chain *base = (struct chain*) Hp, *bw = base + m;
  Hp += (n + m) * Width(struct chain);
  for (uintptr_t i = 0; i < n; i++) ini_chain(bw + i, putcharm(t[i]), word(bw + i + 1));
  if (n) bw[n - 1].b = front ? lst : ZeroPoint;
  if (front) love_musttail return Push(n ? word(bw) : lst);
  struct chain *w = base;
  for (word l = lst; chainp(l); l = B(l), w++) ini_chain(w, A(l), word(w + 1));
  w[-1].b = n ? word(bw) : ZeroPoint;
  love_musttail return Push(word(base)); }
 if (front) { Sp[0] = elt, Sp[1] = lst; love_musttail return Ap(lvm_link, g); }  // (. elt list)
 uintptr_t n = llen(lst) + 1; Have(n * Width(struct chain));
 lst = chainp(Sp[0]) ? Sp[0] : Sp[1], elt = chainp(Sp[0]) ? Sp[1] : Sp[0];
 struct chain *base = (struct chain*) Hp, *w = base;
 Hp += n * Width(struct chain);
 for (word l = lst; chainp(l); l = B(l), w++) ini_chain(w, A(l), word(w + 1));
 ini_chain(w, elt, ZeroPoint);
 love_musttail return Push(word(base)); }

// --- text lane: strings + symbols ---
struct str *nom_str(struct g *g, word x) {   // a name's string, or 0
 return namep(x) ? str(nom(x)->name) : 0; }

static love_inline uintptr_t stringlen(struct g *g, word x) {  // bytes x contributes to a concat
 if (strp(x)) return len(x);
 if (nomp(x)) { struct str *n = nom_str(g, x); return n ? n->len : 0; }
 return 1; }                                            // number -> one byte

love_inline char *add_emit(struct g *g, char *w, word x) {
 if (strp(x)) return (void) memcpy(w, txt(x), len(x)), w + len(x);
 if (nomp(x)) { struct str *n = nom_str(g, x);
  return n ? ((void) memcpy(w, txt(n), n->len), w + n->len) : w; }
 return *w = (char) seq_byte(x), w + 1; }               // number -> one byte
struct str *seq_cat(struct g *g, void *w, word a, word b) {
 struct str *z = ini_str(str(w), stringlen(g, a) + stringlen(g, b));
 return add_emit(g, add_emit(g, txt(z), a), b), z; }

lvm(lvm_add_string) {
 word a = Sp[0], b = Sp[1];
 if (trayp(a) || trayp(b)) love_musttail return Push(ZeroPoint);
 if ((!strp(a) && seq_byte(a) < 0) || (!strp(b) && seq_byte(b) < 0)) love_musttail return Push(ZeroPoint);
 uintptr_t n = stringlen(g, a) + stringlen(g, b);
 if (!n) love_musttail return Push(EmptyString);
 uintptr_t req = str_width(n);
 Have(req);
 a = Sp[0], b = Sp[1];                                  // post-Have
 struct str *z = seq_cat(g, Hp, a, b);
 Hp += req;
 *++Sp = word(z);
 Ip++; love_musttail return Continue(); }
lvm(lvm_0) {                             // unsupported mix (array <-> string)
 love_musttail return Push(ZeroPoint); }
// the unit lane: the dispatchers catch a mint first, but the matrix stands on its own (mx.v)
lvm(lvm_bin_unit) {                       // a point is the identity; of two, the greater stands
 word a = Sp[0], b = Sp[1];
 love_musttail return Push(nomp(a) ? (nomp(b) && love_mint_cmp(g, a, b) > 0 ? a : b) : a); }
// the degenerate lane: a mixed pair with no lawful crossing answers the higher band's operand
// whole, the foreigner arriving as its unit -- what keeps + associative
lvm(lvm_bin_a) { word a = Sp[0]; love_musttail return Push(a); }
lvm(lvm_bin_b) { word b = Sp[1]; love_musttail return Push(b); }

// ===== tray =====
size_t const love_T[] = {
 [love_Z] = Bytes,
 [love_R] = Bytes,
 [love_C] = 2 * Bytes,      // complex scalar: (re, im)
 [love_O] = Bytes, };       // object: one tagged l word per element

uintptr_t love_tray_bytes(struct tray *v) {
 return tray_bytes(v->type, v->rank, tray_nelem(v)); }

// love.h's data-apply shims
#if data_section
// each sentinel in section love.data.N (N its enum d) on a data_stride grain, so love_typ is one
// divide on (ap - lvm_sym). ld's scripts are laid by mx.l from enum d's roster
#define DSENT(nn, name, handler) \
 __attribute__((section("love.data." #nn), used, aligned(data_stride))) \
 lvm(name) { love_musttail return Ap(handler, g); }
DSENT(0,  lvm_sym,     data_sym_apply)
DSENT(1,  lvm_nom,     data_sym_apply)
DSENT(2,  lvm_gembox,  data_num_apply)
DSENT(3,  lvm_twinbox, data_num_apply)
DSENT(4,  lvm_big,     data_num_apply)
DSENT(5,  lvm_tray,    data_num_apply)
DSENT(6,  lvm_str,     data_string_apply)
DSENT(7,  lvm_chain,   data_pair_apply)
#else
lvm(lvm_tray)   { love_musttail return Ap(data_num_apply, g); }
lvm(lvm_big)   { love_musttail return Ap(data_num_apply, g); }
lvm(lvm_str)   { love_musttail return Ap(data_string_apply, g); }
lvm(lvm_sym)   { love_musttail return Ap(data_sym_apply, g); }
lvm(lvm_nom)   { love_musttail return Ap(data_sym_apply, g); }
lvm(lvm_chain) { love_musttail return Ap(data_pair_apply, g); }
lvm(lvm_gembox)   { love_musttail return Ap(data_num_apply, g); }
lvm(lvm_twinbox)  { love_musttail return Ap(data_num_apply, g); }
#endif

// snap.c walks def1 to number the aps it serializes
struct def const *const love_def1 = def1;
uintptr_t const def1_n = countof(def1);
// a def1 row is a value (a nif's run in nifs[]) or an instruction: at run time the union is one
// word, so the address says which. ini_0 and snap.c's op table split on it
int nif_cell(union u const *k) {
 return (uintptr_t) ((char const*) k - (char const*) nifs) < sizeof nifs; }

