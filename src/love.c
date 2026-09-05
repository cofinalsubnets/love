// love.c -- g, stack, sys, str, sym, chain, tray. one translation unit of the runtime;
// the shared layouts and the cross-TU seam are src/love.h.
#include "love.h"
#include <stddef.h>
struct ai_chain;
// this file's own, forward-declared so order within it does not matter.
static char *add_emit(struct ai *g, char *w, word x);
static intptr_t seq_byte(word x);
// the nifs.h table lands mid-file and names these, so the whole set is declared up here
// (lvm_subn's body comes out of avm_slow, which carries no storage class of its own).
static lvm_t
 lvm_apof, lvm_bigp, lvm_books, lvm_cap, lvm_casknew, lvm_chainp, lvm_clock, lvm_cup,
 lvm_gauge, lvm_intf, lvm_key, lvm_kreg, lvm_link, lvm_mint, lvm_mintp, lvm_mods, lvm_namep,
 lvm_nclock, lvm_nomctor, lvm_nomp, lvm_packp, lvm_please, lvm_setbooks, lvm_setp,
 lvm_snip, lvm_strp, lvm_sub, lvm_subn, lvm_sunp, lvm_tune, _lvm_help_scare, _lvm_yield_c;
static struct ai
 *ai_ini_0(struct ai*g, uintptr_t len0, void *(*al)(struct ai*, void*, size_t));
static uintptr_t stringlen(struct ai *g, word x);
// the build's version string, generated into out/lib/love_version.h and surfaced
// as `love-version`. -DAiVersion wins (love0 pins "bootstrap" so a new commit never
// relinks the bootstrap); -DAiHaveVersionH says the header exists -- mooncc has
// no __has_include, so the probe alone is not enough.
#ifndef AiVersion
# if defined(AiHaveVersionH) || (defined(__has_include) && __has_include("love_version.h"))
#  include "love_version.h"
# endif
#endif
#ifndef AiVersion
#define AiVersion "unknown"
#endif
word const ai_map_gap_cell = 0; // FIXME why do we need 0 as a constant :/
struct ai_str0 const ai_str_empty = { .ap = lvm_str, .len = 0 };
struct ai_mint const ai_mint_zero = { .ap = lvm_sym, .code = 0 };
// ============================================================================
// g
// ============================================================================
enum ai_status ai_fin(struct ai *g) {
 enum ai_status s = ai_code_of(g);
 if ((g = ai_core_of(g))) {
   for (struct ai_fz *fz = g->fz; fz; fz->fn(g, fz->p), fz = fz->next); // run finalizers
   code_fin(g);                                 // ..then the native arena they hand blobs back to
   // the rem set and the major pool are ai_ini_0's own g->alloc calls, not room inside
   // the nursery -- a frontend that exits never misses them, one that fins to make room
   // for the next runtime gets nothing back without this.
   if (g->rem) g->alloc(g, g->rem, 0);
   if (g->major_pool) g->alloc(g, g->major_pool, 0);
   g->alloc(g, g, 0); }                       // ..the pool is g, so it goes last
 return s; }

// every .x here must be immortal -- a nif address, a fixnum, an out-of-pool
// constant. C cannot re-root what it holds in an array, and no ordering fixes it;
// a value that moves arrives on the stack instead (ai_defv).
struct ai *ai_defn(struct ai*g, struct ai_def const*defs, uintptr_t n) {
 for (g = ai_push(g, 1, A(ai_core_of(g)->book)); n--;
  g = ai_mapput(intern(ai_strof(ai_push(g, 1, defs[n].x), defs[n].n))));
 ai_core_of(g)->sp++;
 return g; }

// FIXME this function should pop the bound value off the stack
// ai_defn's twin for a value that moves: it rides g->sp[0], where the collector
// updates it, and is left there (a second name binds the same one; callers pop).
// the sp[1] re-read happens after the book push, so a collection inside it is accounted for.
struct ai *ai_defv(struct ai *g, char const *nm) {
 if (!ai_ok(g)) return g;
 g = ai_push(g, 1, A(g->book));           // [book, value, ..]
 if (!ai_ok(g)) return g;
 g = ai_mapput(intern(ai_strof(ai_push(g, 1, ai_core_of(g)->sp[1]), nm)));
 if (ai_ok(g)) ai_core_of(g)->sp++;                   // [value, ..]
 return g; }

// the nif + instruction registry: one `union u` table, a nif's little stream being a
// run inside it, then def1 -- the name -> value table ai_defn reads into the book,
// carrying each run's address. both are laid from the one roster in nifs.l -- edit
// that, not nifs.h; make relays it and test_clay diffs.
#include "nifs.h"

static lvm(_lvm_yield_c) { return Pack(g), g; }
union u const yield_c[] = { {_lvm_yield_c} };

// lvm_help: the default help ap -- re-encode the raised status, yield to C.
// _lvm_help_scare sits outside lvm_* on purpose: the one designed `ret`
// (vmret sounds lvm_* only), reached by tail call. the status rides the core's b,
// like every other thing an op needs beyond the stack.
static lvm(_lvm_help_scare) { return Pack(g), encode(g, (enum ai_status) g->b); }
lvm(lvm_help) {
 struct ai *c = ai_core_of(g);
 c->b = ai_code_of(g);
 ai_musttail return Ap(_lvm_help_scare, c); }

// reverse-lookup a nif value -> its source name or NULL (the printer renders nifs by name)
char const *ai_nif_name(intptr_t x) {
 for (uintptr_t i = 0; i < countof(def1); i++) if (def1[i].x == x) return def1[i].n;
 return 0; }

// the canonical (linux) errno numbering, lowercase -- the spellings ai_ini_0
// interns into g->errs. 41 and 58 are blanks in the numbering itself; a kernel
// row with no canonical concept translates to 41 (os.c), which lands 'eunknown.
static struct { short v; char n[16]; } const ai_errnames[] = {
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

static struct ai *ai_ini_0(struct ai*g, uintptr_t len0, void *(*al)(struct ai*, void*, size_t)) {
 memset(g, 0, sizeof(struct ai));      // the core needs no leading ap: () is the const ZeroPoint, never (word)g
 g->len = len0, g->alloc = al;
 g->scare_a = g->scare_b = zero;        // v0..end is GC-walked: raw 0 is not a value
 g->hot_read = g->hot_numap = g->hot_stack = g->hot_compose = g->hot_opfix = g->hot_show = zero;   // unsealed: hot_hook traps until (seal-hook) fills them
 g->hp = g->end, g->sp = (word*) g + len0, g->ip = (union u*) yield_c;
 // the rem set + major pool ride g->alloc: a frontend that cannot supply them cannot run
 g->major_len = ai_major0;
 g->rem = g->alloc(g, NULL, AiRemCap * sizeof(word));
 g->major_pool = g->rem ? g->alloc(g, NULL, 2 * g->major_len * sizeof(word)) : NULL;
 if (!g->major_pool) { if (g->rem) g->alloc(g, g->rem, 0); return encode(g, ai_status_scare); }
 g->major_base = g->major_hp = g->major_pool, g->budget = ai_budget;
 g->minor0 = ai_minor0, g->major0 = ai_major0, g->ratio = ai_gc_ratio;   // the live knobs; `tune` moves them
 g->next_wait_events = ai_wait_in;
 jk_ini(g);
 // book + macro maps (lookup-lambdas) then the main task thread.
 if (ai_ok(g = map_new(g)) && ai_ok(g = map_new(g)) && ai_ok(g = ai_have(g, 9))) {
  union u *M = bump(g, 9);            // sp[0]=macro, sp[1]=book (no GC since ai_have)
  M[0].m = M;
  M[1].x = zero;   // sentinel; replaced on first yield
  M[2].x = zero;   // main pid
  M[3].x = zero;   // wake_at: zero means "always runnable"
  M[4].x = putcharm(-1);  // wait_fd: -1 = not waiting on I/O (slot value -1, non-zero)
  M[5].x = putcharm(ai_wait_in);   // wait_events: the read direction, the default
  M[6].x = zero;   // help: nothing heard until the first (hear f)
  M[7].x = zero;   // stdio: the console until the first (wear l)
  g->tasks = tagthread(M, 8);
  g->parked = NULL;   // nothing is fd-parked before the first task ever parks
  // book[zero] = macro (the macro table -- no separate field). both are on the
  // stack; push the zero key so (sp2,sp1,sp0)=(book,macro,zero) for ai_mapput.
  g = ai_push(g, 1, zero);
  g = ai_mapput(g);                     // -> sp[0] = book
  g->book = g->sp[0];                  // henceforth GC-forwarded via the v0..end loop
  // the abyss: g->book holds a chain of books, walked head-first (bookget) --
  // one link today (orth, the boot book); a later layer prepends and shadows.
  // the l-level `book` global stays the orth map (def0 pins A(g->book)).
  if (ai_ok(g = ai_have(g, Width(struct ai_chain)))) {
   struct ai_chain *ly = (void*) bump(g, Width(struct ai_chain));
   ini_chain(ly, g->sp[0], ZeroPoint);
   g->book = (word) ly; }
  g = ai_pop(g, 1);
  // the weak intern map (string -> the canonical atom), created before the
  // first intern (the def tables just below). it lives outside the traced
  // v0 region: a collection clones it untraced and sweeps it at the fixpoint.
  g = map_new(g);
  if (ai_ok(g)) g->symbols = ai_pop1(g);
  if (ai_ok(g = map_new(g))) g->mods = ai_pop1(g);   // the registry, before the first ai_modtab
  struct ai_def def0[] = {
   {"book", A(g->book)},   // the l-level book = the orth map (the chain stays C-side; `books` reads it)
   {"in", (word) &ai_stdin},
   {"out", (word) &ai_stdout},
   {"err", (word) &ai_stderr},
   // the two doors prel builds (tap and jug), so it can stamp the kind it means;
   // mopped at birth like every other raw pointer the compiler folds (love/egg.l)
   {"ci-vt", (word) &ai_ci_vt},
   {"to-vt", (word) &ai_to_vt},
   // max-charm/min-charm: this build's fixnum bounds, exposed so width-specific
   // tests gate on the real boundary (it differs on 32- vs 64-bit ports).
   {"max-charm", putcharm((word)((uintptr_t)-1 >> 2))},
   {"min-charm", putcharm(-(word)((uintptr_t)-1 >> 2) - 1)},
   // love-tco: glazed code continues by tail-jump, which only the threaded build
   // honors -- auto.l reads this and keeps the interpreter on a trampoline build
   {"love-tco", putcharm(ai_tco)}, };
  g = ai_defn(g, def0, countof(def0));
  g = ai_defn(g, def1, countof(def1));
  if (ai_ok(g = ai_strof(g, AiVersion)))            // a live string: off the stack, never an ai_def
   g = ai_pop(ai_defv(g, "love-version"), 1);
  // `love-arch`: the host CPU the glaze emits for, and the assembler target every backend
  // is registered under. A NOM, in the prel's canonical spelling (love/prel.l's arch-canon)
  // -- so a reader compares it against 'x64 rather than interning a string first, and
  // there is one word for this machine across holo, moon, kore and the seed.
#if defined(__x86_64__)
  #define AiArch "x64"
#elif defined(__aarch64__)
  #define AiArch "a64"
#elif defined(__riscv)
  #define AiArch "rv64"
#else
  #define AiArch "other"
#endif
  if (ai_ok(g = intern(ai_strof(g, AiArch))))
   g = ai_pop(ai_defv(g, "love-arch"), 1);
  // the errno vocabulary (g->errs): canonical number -> its nom, all interned
  // here so no error path ever allocates. ai_err reads it; 0 is 'eunknown, the
  // answer for the numbering's blanks, and -1 'badarg, the refused-before-any-
  // syscall answer -- neither is a posix name, so neither can shadow one.
  if (ai_ok(g = map_new(g))) {
   for (uintptr_t n = countof(ai_errnames); ai_ok(g) && n--;)
    g = ai_mapput(ai_push(intern(ai_strof(g, ai_errnames[n].n)), 1, putcharm(ai_errnames[n].v)));
   if (ai_ok(g)) g->errs = ai_pop1(g); }
  // the kind roster (g->kinds): enum q row -> its nom, `kind`'s answer for a built-in
  if (ai_ok(g = map_new(g))) {
   char const *p = ai_kind_names;
   for (intptr_t i = 0; ai_ok(g) && *p; i++) {
    while (*p == ' ') p++;
    char nm[16], *q = nm;
    while (*p && *p != ' ') *q++ = *p++;
    *q = 0;
    g = ai_mapput(ai_push(intern(ai_strof(g, nm)), 1, putcharm(i))); }
   if (ai_ok(g)) g->kinds = ai_pop1(g); }
  // the kind table's keys and the built-in coins' names (g->knom, love.h's Kn rows), and
  // the registry of named kinds (g->kreg): name -> (serial . table), pinned by post.l's `coin`
  { char const *const ns[KnN] = { "name", "+", "*", "ap", "hot", "-", "net", "star", "/",
                                  "payload", "tally", "ratio", "lambda", "cask", "port" };
    for (int i = 0; ai_ok(g) && i < KnN; i++)
     if (ai_ok(g = intern(ai_strof(g, ns[i])))) g->knom[i] = ai_pop1(g); }
  if (ai_ok(g = map_new(g))) g->kreg = ai_pop1(g);
  // the 'missing tag needs nothing here (the raise sites mint it); the reader owns
  // no operator tables -- book['operators] is seeded by the prel and factored at compile time
 }
 return g; }

word ai_err(struct ai *g, int e) {
 g = ai_core_of(g);
 word v = ai_mapget(g, 0, putcharm(e), g->errs);
 return v ? v : ai_mapget(g, 0, zero, g->errs); }

struct ai *ai_ini_m(void *(*al)(struct ai*, void*, size_t)) {
 uintptr_t const len0 = ai_minor0;   // initial minor pool; grows on demand (gen_grow)
 struct ai *g = al(NULL, NULL, 2 * len0 * sizeof(word));
 return g == NULL ? encode(g, ai_status_scare) : ai_ini_0(g, len0, al); }

void *ai_libc_alloc(struct ai*g, void *p, size_t n) { return n ? malloc(n) : (free(p), NULL); }
struct ai *ai_ini(void) { return ai_ini_m(ai_libc_alloc); }

// ============================================================================
// stack
// ============================================================================
static struct ai *ai_pushr(struct ai *g, uintptr_t m, uintptr_t n, va_list xs) {
 if (n == m) return ai_please(g, m);
 word x = va_arg(xs, word);
 mm(g, &x);
 g = ai_pushr(g, m, n + 1, xs);
 um(g);
 if (ai_ok(g)) *--g->sp = x;
 return g; }

struct ai *ai_push(struct ai *g, uintptr_t m, ...) {
 if (!ai_ok(g)) return g;
 va_list xs;
 va_start(xs, m);
 uintptr_t n = 0;
 if (avail(g) < m) g = ai_pushr(g, m, n, xs);
 else for (g->sp -= m; n < m; g->sp[n++] = va_arg(xs, word));
 va_end(xs);
 return g; }

struct ai *gxl(struct ai *g) {
 if (ai_ok(g = ai_have(g, Width(struct ai_chain)))) {
  struct ai_chain *p = bump(g, Width(struct ai_chain));
  ini_chain(p, g->sp[0], g->sp[1]);
  *++g->sp = (word) p; }
 return g; }

struct ai *gxr(struct ai *g) {
 if (ai_ok(g = ai_have(g, Width(struct ai_chain)))) {
  struct ai_chain *p = bump(g, Width(struct ai_chain));
  ini_chain(p, g->sp[1], g->sp[0]);
  *++g->sp = (word) p; }
 return g; }

// ============================================================================
// sys
// ============================================================================
op11(lvm_clock, putcharm(ai_clock() - (charmp(Sp[0]) ? getcharm(Sp[0]) : 0)))

// the fine clock: monotonic ns for differences ((nclock t) is ns minus t); clock
// stays at ms, the scheduler's scale (ns wraps 32 bits every 4.3s). weak default
// degrades to ms*1e6; hosts override with a real ns source.
__attribute__((weak)) intptr_t ai_nclock(void) {
 return (intptr_t) (ai_clock() * 1000000u); }
op11(lvm_nclock, putcharm(ai_nclock() - (charmp(Sp[0]) ? getcharm(Sp[0]) : 0)))

// (please x): a collection on demand -- () a minor, a positive charm a major;
// answers the new n_gc (the real-time lever). a forced collection observes and
// never steers: the resize window is zeroed for the call and put back, so a probe
// forcing minors can't talk the nursery into doubling (the pause gauge's first
// draft ran the pool to oom@8GB through exactly that feedback).
static lvm(lvm_please) {
 word n = Sp[0];
 Pack(g);
 if (charmp(n) && getcharm(n) > 0)
  g->since_major = g->major_live0 + 4 * (uintptr_t) g->len + 1;
 uintptr_t wa = g->win_alloc, wc = g->win_copied;
 int8_t ln = g->lean;
 g->win_alloc = g->win_copied = 0, g->lean = 0;
 if (!ai_ok(g = ai_please(g, 0))) ai_musttail return Ap(_lvm_ghelp, g);
 g->win_alloc = wa, g->win_copied = wc, g->lean = ln;
 Unpack(g);
 Sp[0] = putcharm((intptr_t) g->n_gc);
 Ip += 1; ai_musttail return Continue(); }

// (gauge 0) -> a rank-1 Z array of VM stats (full machine words, not 62-bit fixnums):
//   [0] len       pool size (words)
//   [1] heap      words used from base (core + live heap)
//   [2] stack     stack height (words)
//   [3] n_gc      collections so far
//   [4] max_len   peak pool size (words)
//   [5] max_heap  peak live heap after a collection (words)
//   [6] n_seen    Σ heap occupancy entering each collection (scanned = live + dead, words)
//   [7] n_evac    Σ heap survivors copied out each collection (live, words)
//   [8] old       the tenured set: words live in the major pool
//   [9] rem_miss  rem-set entries dropped on overflow since the last collection (a miss forces a major; ~always 0)
//  [10] rem_hi    peak remembered-set size (distinct old objects with a young field)
//  [11] n_minor   minor collections so far (majors = n_gc - n_minor)
//  [12] major_cap the major pool's reserved footprint: 2*major_len words (both halves), 0 if non-gen
//  [13] n_resize  pool reallocations so far (the pool-cliff tell)
//  [14] minor_hi  peak words one minor copied -- the pause gauge (a copying
//  [15] major_hi  peak words one major copied    collection's pause is its copy volume)
// derive: mortality = (n_seen - n_evac)/n_seen ; copy-amp = n_evac/max_heap
static lvm(lvm_gauge) {
 enum { N = 16 };
 uintptr_t const bytes = tray_bytes(ai_Z, 1, N);
 Have(b2w(bytes));
 struct ai_tray *v = (struct ai_tray*) Hp;
 Hp += b2w(bytes);
 ini_tray(v, ai_Z, 1);
 v->shape[0] = N;
 tray_put_int(v, 0, (intptr_t) g->len);
 tray_put_int(v, 1, (intptr_t) (Hp - ptr(g)));
 tray_put_int(v, 2, (intptr_t) (ptr(g) + g->len - Sp));
 tray_put_int(v, 3, (intptr_t) g->n_gc);
 tray_put_int(v, 4, (intptr_t) g->max_len);
 tray_put_int(v, 5, (intptr_t) g->max_heap);
 tray_put_int(v, 6, (intptr_t) g->n_seen);
 tray_put_int(v, 7, (intptr_t) g->n_evac);
 tray_put_int(v, 9, (intptr_t) g->rem_miss);
 tray_put_int(v, 10, (intptr_t) g->rem_hi);
 tray_put_int(v, 11, (intptr_t) g->n_minor);
 tray_put_int(v, 8, (intptr_t) (g->major_hp - g->major_base));            // words live in the major pool
 tray_put_int(v, 12, (intptr_t) (g->major_pool ? 2 * g->major_len : 0));  // major pool capacity (both halves), words
 tray_put_int(v, 13, (intptr_t) g->n_resize);
 tray_put_int(v, 14, (intptr_t) g->minor_hi);
 tray_put_int(v, 15, (intptr_t) g->major_hi);
 ai_musttail return Answer(word(v)); }

// (tune v) -> the four live GC knobs as a rank-1 Z array, in words:
//   [0] budget  total footprint cap (2*minor + 2*major); 0 = unbounded (appel's rule)
//   [1] minor0  the nursery floor every resize clamps up to
//   [2] major0  the major pool's grow/shrink step (never 0: it divides)
//   [3] ratio   copy-overhead setpoint -- hold copied/allocated inside [1/(4*ratio), 1/ratio]
// (tune ()) reads; a rank-1 4-array writes and answers what it replaced, so a probe
// can put the knobs back. seeded at ai_ini from ai_minor0/ai_major0/ai_gc_ratio.
// a knob lands at the next collection -- tightening budget frees nothing until then,
// so pair it with (please 1). a wrong shape is a silent no-op answering the current
// knobs (pin's misuse convention). these are untraced scalars ahead of v0, so a bake
// does not carry them: a woken image tunes again (host's LOVE_BUDGET_MB does exactly that).
static lvm(lvm_tune) {
 enum { N = 4 };
 uintptr_t const bytes = tray_bytes(ai_Z, 1, N);
 Have(b2w(bytes));
 word x = Sp[0];                             // read post-Have: a collection forwards the operand
 struct ai_tray *v = (struct ai_tray*) Hp;
 Hp += b2w(bytes);
 ini_tray(v, ai_Z, 1);
 v->shape[0] = N;
 tray_put_int(v, 0, (intptr_t) g->budget);
 tray_put_int(v, 1, (intptr_t) g->minor0);
 tray_put_int(v, 2, (intptr_t) g->major0);
 tray_put_int(v, 3, (intptr_t) g->ratio);
 if (galaxyp(x) && tray(x)->rank == 1 && tray(x)->shape[0] == N) {
  struct ai_tray *w = tray(x);
  intptr_t b = tray_get_int(w, 0), mi = tray_get_int(w, 1),
           ma = tray_get_int(w, 2), ra = tray_get_int(w, 3);
  g->budget = b > 0 ? (uintptr_t) b : 0;     // <= 0 is the unbounded spelling, not a refusal
  if (mi > 0) g->minor0 = (uintptr_t) mi;    // a 0 floor would let the nursery vanish
  if (ma > 0) g->major0 = (uintptr_t) ma;    // the step divides
  if (ra > 0) g->ratio = (uintptr_t) ra; }   // 0 would never grow and always shrink
 ai_musttail return Answer(word(v)); }

// (apof x): x's kind pointer (cell[0]) as a fixnum, 0 for a fixnum/immediate. the string-lane glaze
// reads the kind of a reference string at codegen time and emits a `cmp [s], kind; jne deopt` type guard.
static lvm(lvm_apof) {
 word x = Sp[0];
 Sp[0] = putcharm(lamp(x) ? (uintptr_t) cell(x)->ap : 0);
 Ip += 1;
 ai_musttail return Continue(); }

// (jkoff x) -> the byte offset of g->jk, so the emitter's `jk` law reads a slot as `ld r g off`
lvm(lvm_jkoff) { ai_musttail return Answer(putcharm((intptr_t) offsetof(struct ai, jk))); }
// (nat? f) -> 1 when f is a native closure: arity 1 enters its code directly; an
// arity>=2 cell curries through lvm_cur with the code at value[2]
lvm(lvm_natp) {
 word x = Sp[0];
 int nat = lamp(x) && (code_in(g, (uintptr_t) cell(x)->ap) ||
  (cell(x)->ap == lvm_cur && code_in(g, (uintptr_t) cell(x)[2].ap)));
 ai_musttail return Answer(putcharm(nat)); }

// default fd-keyed waits, conservative (all fds always-ready; multi-source wait
// collapses to sleep) so non-multitasking frontends link without impls
__attribute__((weak)) bool ai_ready(int fd, int events) { return true; }
__attribute__((weak)) void ai_wait_fds(struct ai_wait_fd *fds, int n, uintptr_t ticks) {
  ai_sleep(ticks); }
// the default authoritative readiness sweep: ask one at a time but fill every
// slot, so "none ready" never reads as "nobody answered"; hosts replace the loop
// with one poll(2)
__attribute__((weak)) void ai_ready_fds(struct ai_wait_fd *fds, int n) {
  for (int i = 0; i < n; i++)
    fds[i].revents = ai_ready(fds[i].fd, fds[i].events) ? fds[i].events : 0; }

__attribute__((weak)) void ai_fd_close(int fd) { }   // host overrides with close(2)
// default sleep is busy wait
__attribute__((weak)) ai_noinline void ai_sleep(uintptr_t ticks) {
  for (ticks += ai_clock(); ai_clock() < ticks;); }

// (cue? p): would `see` answer without parking? the dual of the park law -- all
// three terms (pushback, buffered run, fd), or a port with bytes in hand reads
// "not ready". it asks will you answer, not is there data: a hung-up fd reads
// ready and the see answers -1. a non-port asks about stdin (the bare (cue? 0)).
static lvm(lvm_key) {
 Sp[0] = io_route(g, iop(Sp[0]) ? Sp[0] : (word) &ai_stdin);   // the bare (cue? 0) asks about stdin, so it routes too
 struct ai_io *i = (struct ai_io*) Sp[0];
 Sp[0] = (getcharm(i->ungetc_buf) != EOF || bio_rpending(bio_of(g, i))
          || ai_ready((int) ai_io_fd(i), ai_wait_in)) ? putcharm(1) : zero;
 Ip += 1;
 ai_musttail return Continue(); }

// ============================================================================
// str
// ============================================================================
struct ai *str0(struct ai *g, uintptr_t len) {
 if (!len) { if (ai_ok(g = ai_have(g, 1))) *--g->sp = EmptyString; return g; } // never alloc empty
 uintptr_t req = str_width(len);
 if (ai_ok(g = ai_have(g, req + 1)))
  *--g->sp = word(ini_str(bump(g, req), len));
 return g; }

struct ai *ai_strof(struct ai *g, char const *cs) {
 uintptr_t len = strlen(cs);
 if (ai_ok(g = str0(g, len))) memcpy(txt(g->sp[0]), cs, len);
 return g; }

op11(lvm_strp, strp(Sp[0]) ? putcharm(1) : zero)
// a cask snips as the string of its bytes, the way `pour` already reads one: swig
// fills a buffer and the caller wants the prefix it filled, and (string b) first
// copies the whole buffer to take a corner of it -- 64K a read for a 12-byte file.
static lvm(lvm_snip) {
 if (!strp(Sp[0]) && !caskp(Sp[0])) Sp[2] = zero;
 else {
  struct ai_str *s = bytes_of(Sp[0]), *t;
  intptr_t i = oddp(Sp[1]) ? getcharm(Sp[1]) : 0,
           j = oddp(Sp[2]) ? getcharm(Sp[2]) : 0;
  i = max(i, 0), i = min(i, (word) len(s));
  j = max(j, i), j = min(j, (word) len(s));
  // an empty range (i == j) answers a string, the closest form of nothing for this
  // kind, not the bare floor (fixnum 0) -- and the empty string, never a fresh one.
  // no 0-length string is ever allocated (str0 holds the same line), which is what
  // lets two empties be id?-equal wherever they were built.
  if (j == i) Sp[2] = EmptyString;
  else {
   size_t req = str_width(j - i);
   Have(req);
   s = bytes_of(Sp[0]);                          // re-read post-Have (GC may have moved it)
   t = str(Hp);
   Hp += req;
   ini_str(t, j - i);
   memcpy(txt(t), txt(s) + i, j - i);
   Sp[2] = (word) t; } }
 ai_musttail return Nextp(1, 2); }


// applying a cask behaves as 0 (yields 1); byte-identical to lvm_port_io, kept
// distinct by ai_noicf so caskp and iop never collide
lvm(lvm_cask) {
 Ip = cell(*++Sp); *Sp = ZeroPoint; ai_musttail return Continue(); }
// (cask n) — a zeroed n-byte mutable cask; (cask charlist) — one holding those
// bytes (the bulk way in). n<=0 -> EmptyString, so no empty cask object exists.
// two heap objects under one Have, so no GC sees a half-built cask.
static lvm(lvm_casknew) {
 bool listp = chainp(Sp[0]);
 intptr_t n = charmp(Sp[0]) ? getcharm(Sp[0]) : listp ? (intptr_t) llen(Sp[0]) : 0;
 if (n <= 0) ai_musttail return Answer(EmptyString);   // no empty cask: it is ""
 uintptr_t sreq = str_width(n),
           breq = Width(struct ai_cask) + Width(struct ai_tag);
 Have(sreq + breq);
 struct ai_str *s = ini_str(str(Hp), n);
 Hp += sreq;
 if (listp) {                                                // the charlist lane, mirroring lvm_string's
  word y = Sp[0];                                            // re-read post-Have, like the cask lane there
  for (uintptr_t i = 0; i < (uintptr_t) n; y = B(y)) txt(s)[i++] = (char) getcharm(A(y)); }
 else memset(txt(s), 0, n);
 union u *k = (union u*) Hp;
 Hp += breq;
 cask(k)->ap = lvm_cask;
 cask(k)->str = s;
 tagthread(k, Width(struct ai_cask));
 ai_musttail return Answer(word(k)); }

// AArch64 wants the I-cache told about freshly written code (a no-op on x86); wasm has
// no code arena to tell and emscripten's clang has no intrinsic to tell it with, so the
// question is answered ONCE here rather than at each install -- a site that forgets the
// guard is a wasm build that dies in instruction selection, which is how this got said.
#ifdef __wasm__
#define ai_code_sync(a, b) ((void) (a), (void) (b))
#else
#define ai_code_sync(a, b) __builtin___clear_cache(a, b)
#endif

// the native code arena: hosted, the malloc heap is NX, so the glaze installs into
// chunks of pages of its own. a chunk is RX; an install opens just the blob's pages,
// writes, and seals them again (W^X, never both at once). a blob is [len, pad, code..],
// 16-aligned, so the code address is what the closure cell holds and the length word
// behind it answers a free. the code addresses live outside the GC pool; a native
// closure's finalizer hands its blob to the free list, and the next install of that
// size takes it. on inle -- one hosted-compiled binary, so the question is asked at
// RUN TIME, a negative __ai_osv -- and on a freestanding seat, RAM is executable and
// a heap copy runs, with no finalizer owed.
// one chunk; used is its bump, fixed = the image's own (shared blobs, never freed one at a
// time). own is what the allocator was handed, NULL off mmap: a seat whose executable
// window is an alias frees by the address it asked for, not the address it runs.
struct ai_code { char *base, *own; size_t len, used; int fixed; struct ai_code *next; };
struct ai_cfree { char *p; size_t n; struct ai_cfree *next; };           // a freed blob (its whole span)
#if __STDC_HOSTED__
// which kernel underneath: nolibc's os.c defines it (0 unprobed; 1..3 the
// hosted kernels; negative = we ARE the kernel). weak for seats with no
// nolibc aboard (love0 under a foreign libc, wasm), where zero reads as
// hosted -- which such a seat is.
__attribute__((weak)) long __ai_osv;
#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif
#define CodeChunk ((size_t) 1 << 20)
#define CodeHead (2 * sizeof(uintptr_t))
static size_t code_round(size_t n) { return (n + 15) & ~(size_t) 15; }
static size_t code_page(void) { long q = sysconf(_SC_PAGESIZE); return q > 0 ? (size_t) q : 4096; }   // glibc's sysconf is a cached auxv load, not a syscall
// open [p, p+n) for writing, or seal it; page-granular, so neighbours ride along -- nothing
// runs while an install writes, so that costs no one anything
static int code_open(char *p, size_t n, int prot) {
 size_t ps = code_page();
 uintptr_t lo = (uintptr_t) p & ~(ps - 1), hi = ((uintptr_t) p + n + ps - 1) & ~(ps - 1);
 return mprotect((void*) lo, hi - lo, prot); }
static struct ai_code *code_chunk(struct ai *g, size_t need) {
 size_t ps = code_page(), len = (need > CodeChunk ? need : CodeChunk);
 len = (len + ps - 1) & ~(ps - 1);
 void *b = mmap(0, len, PROT_READ | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
 if (b == MAP_FAILED) return NULL;
 struct ai_code *c = g->alloc(g, NULL, sizeof *c);
 if (!c) { munmap(b, len); return NULL; }
 c->base = b, c->own = NULL, c->len = len, c->used = 0, c->fixed = 0, c->next = g->code, g->code = c;
 return c; }
// (code_install g src n): n bytes of code -> their executable address, NULL when no seat can hold them
char *code_install(struct ai *g, char const *src, size_t n) {
 size_t need = code_round(CodeHead + n + 1);
 char *p = NULL;
 for (struct ai_cfree **l = &g->cfree; *l; l = &(*l)->next)     // first fit off the free list
  if ((*l)->n >= need) {
   struct ai_cfree *f = *l; p = f->p;
   if (f->n - need >= 32) f->p += need, f->n -= need;
   else *l = f->next, g->alloc(g, f, 0);
   break; }
 if (!p) {
  struct ai_code *c = g->code;
  if (!c || c->len - c->used < need) c = code_chunk(g, need);
  if (!c) return NULL;
  p = c->base + c->used, c->used += need; }
 if (code_open(p, need, PROT_READ | PROT_WRITE)) return NULL;
 ((uintptr_t*) p)[0] = n, ((uintptr_t*) p)[1] = 0;
 memcpy(p + CodeHead, src, n);
 p[CodeHead + n] = 0;
 if (code_open(p, need, PROT_READ | PROT_EXEC)) return NULL;
 ai_code_sync(p + CodeHead, p + CodeHead + n);
 return p + CodeHead; }
void code_free(struct ai *g, char *code) {
 char *p = code - CodeHead;
 struct ai_cfree *f;
 for (struct ai_code *c = g->code; c; c = c->next)      // the image's chunk is text: the dump packs one blob
  if (c->fixed && p >= c->base && p < c->base + c->len) return;   // per distinct BODY, so a dead closure never
 f = g->alloc(g, NULL, sizeof *f);                      // frees bytes another one is still running
 if (!f) return;                                                  // no node: the blob stays, unreachable
 f->p = p, f->n = code_round(CodeHead + ((uintptr_t*) p)[0] + 1), f->next = g->cfree, g->cfree = f; }
int code_in(struct ai *g, uintptr_t v) {                          // a code address of this session's arena?
 for (struct ai_code *c = g->code; c; c = c->next)
  if (v >= (uintptr_t) c->base && v < (uintptr_t) c->base + c->used) return 1;
 return 0; }
size_t code_len(char *code) { return ((uintptr_t*) code)[-2]; }
// the seat's executable alias for a heap block: itself, unless a seat maps its heap
// non-executable and keeps a second window that runs. inle does (src/kmain.c).
__attribute__((weak)) char *ai_code_window(char *p) { return p; }
// the image lane: a packed segment of blobs becomes a chunk of its own, sealed for the
// session -- image code is text, nothing frees it
char *code_adopt(struct ai *g, char const *src, size_t n) {
 // inle: mmap hands back the hhdm, which is NX by construction (src/mkboot.l puts the
 // bit on the whole window), and its mprotect cannot lift that off a 2 MiB entry the
 // identity map shares. so take the block through the window that runs -- the same
 // memory, the address the low map reaches it by -- and seat it as a fixed chunk, so
 // code_in and code_free read it the way they read the hosted one.
 if (__ai_osv < 0) {
  char *b = g->alloc(g, NULL, n);
  if (!b) return NULL;
  memcpy(b, src, n);
  char *x = ai_code_window(b);
  ai_code_sync(x, x + n);
  struct ai_code *c = g->alloc(g, NULL, sizeof *c);
  if (!c) { g->alloc(g, b, 0); return NULL; }
  c->base = x, c->own = b, c->len = n, c->used = n, c->fixed = 1, c->next = g->code, g->code = c;
  return x; }
 size_t ps = code_page(), len = (n + ps - 1) & ~(ps - 1);
 void *b = mmap(0, len, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
 if (b == MAP_FAILED) return NULL;
 memcpy(b, src, n);
 if (mprotect(b, len, PROT_READ | PROT_EXEC)) { munmap(b, len); return NULL; }
 ai_code_sync((char*) b, (char*) b + n);
 struct ai_code *c = g->alloc(g, NULL, sizeof *c);
 if (!c) { munmap(b, len); return NULL; }
 c->base = b, c->own = NULL, c->len = len, c->used = len, c->fixed = 1, c->next = g->code, g->code = c;   // used = len: the tail is nobody's
 return b; }
static void code_drop(struct ai *g, struct ai_code *c) {
 if (c->own) g->alloc(g, c->own, 0); else munmap(c->base, c->len); }
#else
// freestanding: RAM runs as it is; blobs live in the heap (lvm_nif) and an image's segment in the allocator
int code_in(struct ai *g, uintptr_t v) { return 0; }
// no arena, so no blob carries the length word an install writes -- and nobody asks:
// snap's code rung reaches this only behind the code_in above, which owns no address
size_t code_len(char *code) { return 0; }
void code_free(struct ai *g, char *code) { }
static void code_drop(struct ai *g, struct ai_code *c) { g->alloc(g, c->own, 0); }
// seated as a chunk like the hosted lane's, so the session owns it and code_fin frees it
char *code_adopt(struct ai *g, char const *src, size_t n) {
 char *b = g->alloc(g, NULL, n);
 if (!b) return NULL;
 memcpy(b, src, n), ai_code_sync(b, b + n);
 struct ai_code *c = g->alloc(g, NULL, sizeof *c);
 if (!c) { g->alloc(g, b, 0); return NULL; }
 c->base = c->own = b, c->len = c->used = n, c->fixed = 1, c->next = g->code, g->code = c;
 return b; }
#endif
// the arena is the session's, not the collector's: no root names a chunk, so nothing but
// the end of the session can free one. blobs still live are dead code by then.
void code_fin(struct ai *g) {
 for (struct ai_code *c = g->code, *n; c; c = n) n = c->next, code_drop(g, c), g->alloc(g, c, 0);
 for (struct ai_cfree *f = g->cfree, *n; f; f = n) n = f->next, g->alloc(g, f, 0);
 g->code = NULL, g->cfree = NULL; }

// ============================================================================
// sym
// ============================================================================
// the interning half of nom: string s -> the symbol it spells; identity on any other arg.
// the empty spelling names nothing: (intern "") is ().
lvm(lvm_intern) {
 if (strp(Sp[0])) {
  if (Sp[0] == EmptyString) ai_musttail return Answer(ZeroPoint);  // (intern "") -> () (zero-ontology: the empty spelling is the zero point)
  word y;
  Have(intern_reserve(g));
  Pack(g), y = intern_checked(g, str(g->sp[0])), Unpack(g);
  Sp[0] = y; }
 ai_musttail return Next(1); }

// (mint _) -> a fresh nameless point, identity its only property (the arg is
// ignored). `code` gets the mint serial: its hash and its order key, GC-stable.
// mints answer nomp, so they bind as gensyms.
static lvm(lvm_mint) {
 Have(Width(struct ai_mint));
 struct ai_mint *y = (struct ai_mint*) Hp;
 Hp += Width(struct ai_mint);                   // mints are uniform: ap, code
 ini_missing(y, ++g->next_serial);
 return
  Sp[0] = word(y),
  Ip += 1,
  Continue(); }

// (nom n) -> the name a string spells, a name itself, a fresh mint for anything else.
// interning, so idempotent: (nom "x") = (nom 'x) = 'x; `mint` is the one fresh constructor.
static lvm(lvm_nomctor) {
 if (strp(Sp[0]) || namep(Sp[0])) ai_musttail return Ap(lvm_intern, g);
 ai_musttail return Ap(lvm_mint, g); }

struct ai *intern(struct ai*g) {
 if (!ai_ok(g)) return g;                        // intern_reserve reads g, and ai_have's guard is
                                                 // too late (it is an argument): a caller's scare
                                                 // was dereferenced rather than propagated
 if (ai_ok(g = ai_have(g, intern_reserve(g))))   // atom + (at the load factor) the doubled backing
  g->sp[0] = intern_checked(g, str(g->sp[0]));
 return g; }

// what a fresh intern may bump: the atom, plus (at the load factor) the doubled
// backing. callers reserve this before intern_checked, so the insert never allocates.
uintptr_t intern_reserve(struct ai *g) {
 word m = g->symbols;
 uintptr_t extra = m && (map_len(m) + 1) * 4 >= map_cap(m) * 3 ? 4 + 4 * map_cap(m) : 0;
 return Width(struct ai_nom) + extra; }   // a named symbol is one flat KNom (name + serial)

// probe the weak intern map by string content; a miss mints the canonical KNom
// and inserts it. one canonical nom per spelling. bump-only in here (see intern_reserve).
ai_noinline word intern_checked(struct ai *g, struct ai_str *b) {
 word m = g->symbols;
 bool found;
 uintptr_t i = map_probe(g, m, word(b), &found);
 if (found) return map_slots(m)[2 * i + 1];
 if ((map_len(m) + 1) * 4 >= map_cap(m) * 3) {           // at load: rehash into a doubled backing
  uintptr_t ncap = 2 * map_cap(m), nmask = ncap - 1;
  union u *nb = map_fill_back(bump(g, 4 + 2 * ncap), ncap);
  word *os = map_slots(m), *ns = &nb[3].x;
  uintptr_t ocap = map_cap(m), nlen = 0;
  for (uintptr_t j = 0; j < ocap; j++) {
   word k = os[2 * j];
   if (k == map_gap) continue;
   uintptr_t x = hash(g, k) & nmask;
   while (ns[2 * x] != map_gap) x = (x + 1) & nmask;
   ns[2 * x] = k, ns[2 * x + 1] = os[2 * j + 1], nlen++; }
  nb[1].x = putcharm(nlen);
  cell(m)[1].x = (word) nb;                              // swap backing; header identity stable
  i = map_probe(g, m, word(b), &found); }
 struct ai_nom *y = ini_nom(bump(g, Width(struct ai_nom)), word(b), ++g->next_serial, nom_dig(word(b)));  // the canonical KNom: name + serial + cached spelling hash
 word *slots = map_slots(m);
 slots[2 * i] = word(b), slots[2 * i + 1] = word(y);
 cell(map_back(m))[1].x = putcharm(map_len(m) + 1);
 return word(y); }

// (nom? x): a real point -- a non-() mint or a named nom; () is the one point
// that is not nom?
op11(lvm_nomp, (nomp(Sp[0]) && Sp[0] != ZeroPoint) ? putcharm(1) : zero)
// (name? x): a named point only (KNom) -- a nom with a spelling. name? => nom?; the gap
// nom? \ name? is the anonymous-but-real mints (gensyms).
op11(lvm_namep, namep(Sp[0]) ? putcharm(1) : zero)
// (mint? x): that gap, asked directly -- a bare point, the gensym `nom` hands back.
// mint? and name? partition nom?, and () is in neither. the only way to ask, since
// `string` answers text for every point alike and a mint's spelling is "".
op11(lvm_mintp, (mintp(Sp[0]) && Sp[0] != ZeroPoint) ? putcharm(1) : zero)
op11(lvm_packp, (packp(Sp[0]) || gemp(Sp[0]) || sunp(Sp[0]) || twinp(Sp[0])) ? putcharm(1) : zero)  // the pack family: arrays + the lean gem/sun/twin scalar boxes
op11(lvm_bigp, bigp(Sp[0]) ? putcharm(1) : zero)
op11(lvm_sunp, sunp(Sp[0]) ? putcharm(1) : zero)
op11(lvm_setp, trayp(Sp[0]) ? putcharm(1) : zero)
// (int x): truncate a float scalar to a fixnum; other numbers pass through. used by
// num-ap to get an integer composition count from a non-integer numeral operator.
// int: a gem truncates toward zero, saturating at the charm bounds like the other
// rungs (the bare cast wrapped above 2^62 -- UB read as 0); an exact-ratio coin
// truncates by long division; everything else passes through.
static lvm(lvm_intf) {
 if (ai_ratio_exact(g, Sp[0])) LvmResume(g, ai_ratio_rung, 0)
 if (gemp(Sp[0])) { ai_flo_t v = gem_get(Sp[0]);
  Sp[0] = putcharm(v >= (ai_flo_t) maxcharm ? maxcharm
                 : v <= (ai_flo_t) mincharm ? mincharm
                 : v != v ? 0 : (intptr_t) v); }
 Ip += 1; ai_musttail return Continue(); }

// ============================================================================
// chain
// ============================================================================
op11(lvm_cap, chainp(Sp[0]) ? A(Sp[0]) : Sp[0])
op11(lvm_cup, chainp(Sp[0]) ? B(Sp[0]) : ZeroPoint)   // cup of an atom -> the const () (ZeroPoint), not the moving core (which had serial g->ip, not 0)
op11(lvm_books, g->book)   // the live layer chain (the abyss) -- runtime-internal, mopped at birth; ev.l's gv walks it
op11(lvm_setbooks, (g->book = Sp[0], zero))   // set the layer chain: the scope-layer door (open/use/close ride it); runtime-internal, mopped at birth
op11(lvm_kreg, ai_core_of(g)->kreg)   // (kreg _): the named-kind registry; post.l's coin/kinds read and pin it
op11(lvm_mods, g->mods)   // (mods _): the module registry book; runtime-internal, mopped at birth
// push a fresh writable layer at the head of the book chain -- the runtime's
// enter: the session's scope, every defglob's target
struct ai *ai_layer_(struct ai *g) {
 if (!ai_ok(g)) return g;
 if (!ai_ok(g = map_new(g))) return g;                 // sp[0] = the fresh layer map
 g = gxr(ai_push(g, 1, ai_core_of(g)->book));          // (layer . chain)
 if (!ai_ok(g)) return g;
 ai_core_of(g)->book = *ai_core_of(g)->sp;
 return ai_pop(g, 1); }
// drop the link just below the head -- the runtime's bare leave, the inverse of
// one `use`; nothing below the head is a no-op
struct ai *ai_unsplice_(struct ai *g) {
 if (!ai_ok(g)) return g;
 word bk = ai_core_of(g)->book;
 if (!chainp(B(bk))) return g;
 g = gxl(ai_push(g, 2, A(bk), B(B(bk))));              // (head . below-the-neighbour)
 if (!ai_ok(g)) return g;
 ai_core_of(g)->book = *ai_core_of(g)->sp;
 return ai_pop(g, 1); }

op11(lvm_chainp, (chainp(Sp[0]) && !nomp(Sp[0])) ? putcharm(1) : zero)  // the surface chain?: a real compound list. a named symbol reads (name . mint) but counts as an atom

static lvm(lvm_link) {
 Have(Width(struct ai_chain));
 struct ai_chain *w = (struct ai_chain*) Hp;
 Hp += Width(struct ai_chain);
 ini_chain(w, Sp[0], Sp[1]);
 *++Sp = word(w);
 Ip++;
 ai_musttail return Continue(); }

#define avm_slow(op, vop, ovf, fexpr) lvm(lvm_##op##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (trayp(a) || trayp(b)) { g->b = (word) (vop); ai_musttail return Ap(lvm_vbin, g); } \
 if (twinp(a) || twinp(b)) { g->b = (word) (vop); ai_musttail return Ap(lvm_twin_bin, g); } \
 if (!isnum(a) || !isnum(b)) ai_musttail return Push(ZeroPoint); \
 if (gemp(a) || gemp(b)) { word _res; Have(box_req); \
  ai_flo_t ad = toflo(a), bd = toflo(b); \
  emit_gem(_res, fexpr); \
  ai_musttail return Push(_res); } \
 if (!bigp(a) && !bigp(b)) { intptr_t av = toint(a), bv = toint(b), t; \
  if (!ovf(av, bv, &t)) { word _res; Have(box_req); emit_int(_res, t); \
   ai_musttail return Push(_res); } } \
 if ((vop) == vop_mul) ai_musttail return Ap(lvm_bmul_start, g); /* O(n^2): run yieldable */ \
 Pack(g); g = ai_big_binop(g, vop); \
 if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g); \
 ai_musttail return Resume(); }
#define avm_slowdiv(op, vop, c_op, fexpr, zarm) lvm(lvm_##op##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (trayp(a) || trayp(b)) { g->b = (word) (vop); ai_musttail return Ap(lvm_vbin, g); } \
 if (twinp(a) || twinp(b)) { g->b = (word) (vop); ai_musttail return Ap(lvm_twin_bin, g); } \
 if (!isnum(a) || !isnum(b)) ai_musttail return Push(ZeroPoint); \
 zarm; \
 if (gemp(a) || gemp(b) || b == zero) { word _res; Have(box_req); \
  ai_flo_t ad = toflo(a), bd = toflo(b); \
  emit_gem(_res, fexpr); \
  ai_musttail return Push(_res); } \
 if (!bigp(a) && !bigp(b)) { intptr_t av = toint(a), bv = toint(b); \
  if (!(av == INTPTR_MIN && bv == -1)) { word _res; Have(box_req); emit_int(_res, av c_op bv); \
   ai_musttail return Push(_res); } } \
 { g->b = (word) (vop); ai_musttail return Ap(lvm_bdiv_start, g); } }   /* big // and % run yieldable (resumable long division) */
// a bare mint (() too) is not a number, so a numeric lane has nothing to compute with
// and answers (), either side: - / // % & | ^ << >>. the sequence ops keep their own
// band rules and never come here -- () is the unit of + (joining nothing on) and the
// annihilator of * (repeating a sequence an absent number of times). comparisons and
// `=` stay strict.
// the ordered comparisons (< <= > >=) and their total order over all values are
// defined after vcmp_int/vcmp_flo (the per-op helpers they reuse), by lvm_vbin.


avm_slow(add, vop_add, __builtin_add_overflow, ad + bd)
avm_slow(sub, vop_sub, __builtin_sub_overflow, ad - bd)
avm_slow(mul, vop_mul, __builtin_mul_overflow, ad * bd)

avm_slowdiv(fquot, vop_fquot, /, ai_trunc(ad / bd), (void) 0)  // `//` truncating: float operand floors toward zero
// a % 0 = a, in the numerator's own rep. a zero modulus is no modulus (Z/0Z is Z, and the
// class of a is {a}), and it is what keeps a = (a // n) * n + (a % n) true at n = 0 --
// where (a // 0) * 0 is () and () is the unit of +, so the remainder carries the whole a.
avm_slowdiv(rem, vop_rem, %, ai_fmod(ad, bd),
            if (b == zero || (gemp(b) && toflo(b) == 0)) ai_musttail return Push(a))

// `/` true division: exact integer when b divides a, a float box otherwise
// (the truncating quotient is `//`)
lvm(lvm_quotn) {
 word a = Sp[0], b = Sp[1];
 if (trayp(a) || trayp(b)) { g->b = (word) vop_quot; ai_musttail return Ap(lvm_vbin, g); }
 if (twinp(a) || twinp(b)) { g->b = (word) vop_quot; ai_musttail return Ap(lvm_twin_bin, g); }
 if (!isnum(a) || !isnum(b)) ai_musttail return Push(ZeroPoint);
 if (gemp(a) || gemp(b) || b == zero) { word _res; Have(box_req);   // ±inf/NaN on ÷0
  ai_flo_t ad = toflo(a), bd = toflo(b);
  emit_gem(_res, ad / bd);
  ai_musttail return Push(_res); }
 if (!bigp(a) && !bigp(b)) { intptr_t av = toint(a), bv = toint(b);  // bv != 0 (b != zero)
  if (!(av == INTPTR_MIN && bv == -1)) {                            // INT_MIN/-1 is exact but overflows -> bignum lane
   if (av % bv == 0) { word _res; Have(box_req); emit_int(_res, av / bv);
    ai_musttail return Push(_res); }
   word _res; Have(box_req);                                        // inexact -> promote to float
   emit_gem(_res, (ai_flo_t) av / (ai_flo_t) bv);
   ai_musttail return Push(_res); } }
 LvmResume(g, ai_big_quot_true) }

// `-`: fixnum fast path, the () unit, then coins (`-` has no kind matrix, so the
// interception lives here), then the numeric slow lane
static lvm(lvm_sub) {
 word a = Sp[0], b = Sp[1];
 if (charmp(a) && charmp(b)) { intptr_t t;
  if (!__builtin_sub_overflow((intptr_t) getcharm(a), (intptr_t) getcharm(b), &t) &&
      t >= mincharm && t <= maxcharm)
   ai_musttail return Push(putcharm(t)); }
 avm_unit(a, b);
 if (coinp(a) || coinp(b)) ai_musttail return Ap(lvm_sub_coin, g);
 ai_musttail return Ap(lvm_subn, g); }
// lvm_mul + its kind matrix live after the `+` string lane, below.

// `+` on sequences is order-preserving concatenation, a scalar lifting into the
// sequence on the side it appears:
//   str + str  -> byte concat          list + list -> spine append
//   str + list -> (link str list)      list + str  -> (append list (list str))
//   nom + str  -> byte concat          text + list -> the bytes SPLICE in
// text and chain are one monoid: a string or named symbol against a list contributes
// its bytes as elements, never itself as one. a number is foreign to both bands: it
// arrives as the band's unit, so the other operand answers whole.
// one byte from a number, strictly an exact integer 0..255 (rep-blind: 66.0 is
// 66); anything else answers -1.
static ai_inline intptr_t seq_byte(word x) {
 if (charmp(x)) { intptr_t v = getcharm(x); return v < 0 || v > 255 ? -1 : v; }
 if (gemp(x)) { ai_flo_t f = gem_get(x);
  if (!(f >= 0 && f <= 255)) return -1;                 // range first (nan fails); cast below is safe
  return f != (ai_flo_t) (intptr_t) f ? -1 : (intptr_t) f; }
 return -1; }
// list lane. the matrix routes only list-involved pairs here (src/mx.l's five cells),
// and lvm_add has already answered for () and every mint, so one operand is a chain and
// the other is a chain, a string or a named symbol -- nothing else arrives.
// list+list -> spine append; text <-> list -> the bytes splice; anything else adjoins.
lvm(lvm_add_seq) {
 word a = Sp[0], b = Sp[1];
 if (chainp(a) && chainp(b)) {                         // list + list -> append a..b
  uintptr_t n = llen(a); Have(n * Width(struct ai_chain));
  a = Sp[0], b = Sp[1];
  struct ai_chain *base = (struct ai_chain*) Hp, *w = base;
  Hp += n * Width(struct ai_chain);
  for (word l = a; chainp(l); l = B(l), w++) ini_chain(w, A(l), word(w + 1));
  (w - 1)->b = b;                                // last cdr -> b
  ai_musttail return Push(word(base)); }
 // elt <-> list: exactly one is a chain, the both-chains lane having answered above.
 // said to the compiler rather than tested -- the fact is the matrix's, not something
 // the optimizer can see, and without it the selects below re-test what is already known.
 if (!chainp(a) && !chainp(b)) __builtin_unreachable();
 // front is where the element or its bytes land -- ahead of the list when it is the
 // left operand, at the tail when it is the right.
 bool front = chainp(b);
 word lst = chainp(a) ? a : b, elt = chainp(a) ? b : a;
 if (strp(elt) || nomp(elt)) {              // TEXT SPLICES as its bytes -- the charlist hom, so text
  uintptr_t n = stringlen(g, elt),          // and chain are ONE monoid and + associates across the two.
            m = front ? 0 : llen(lst);      // adjoining instead would merge two texts concatenated first.
  Have((n + m) * Width(struct ai_chain));
  a = Sp[0], b = Sp[1];                                        // re-read post-GC
  front = chainp(b);
  lst = chainp(a) ? a : b, elt = chainp(a) ? b : a;
  struct ai_str *sx = strp(elt) ? str(elt) : nom_str(g, elt);   // a nameless mint has no bytes: n = 0
  unsigned char const *t = sx ? (unsigned char const*) txt(sx) : 0;
  struct ai_chain *base = (struct ai_chain*) Hp, *bw = base + m;
  Hp += (n + m) * Width(struct ai_chain);
  for (uintptr_t i = 0; i < n; i++) ini_chain(bw + i, putcharm(t[i]), word(bw + i + 1));
  if (n) bw[n - 1].b = front ? lst : ZeroPoint;
  if (front) ai_musttail return Push(n ? word(bw) : lst);
  struct ai_chain *w = base;                                    // text on the right: spine, then the bytes
  for (word l = lst; chainp(l); l = B(l), w++) ini_chain(w, A(l), word(w + 1));
  w[-1].b = n ? word(bw) : ZeroPoint;
  ai_musttail return Push(word(base)); }
 if (front) { Sp[0] = elt, Sp[1] = lst; ai_musttail return Ap(lvm_link, g); }  // (link elt list)
 uintptr_t n = llen(lst) + 1; Have(n * Width(struct ai_chain));        // append elt at tail
 lst = chainp(Sp[0]) ? Sp[0] : Sp[1], elt = chainp(Sp[0]) ? Sp[1] : Sp[0];
 struct ai_chain *base = (struct ai_chain*) Hp, *w = base;
 Hp += n * Width(struct ai_chain);
 for (word l = lst; chainp(l); l = B(l), w++) ini_chain(w, A(l), word(w + 1));
 ini_chain(w, elt, ZeroPoint);                     // trailing (elt . ()) -- list terminator (zero-ontology)
 ai_musttail return Push(word(base)); }

// --- text lane: strings + symbols ---
// the string tower is string (0) < uninterned-sym (1) < named-sym|num (2); mixing
// demotes to the lower rank (min keeps the partner's type). the concat is built
// as one string in operand order, then returned per rank: as-is / fresh mint / interned.
struct ai_str *nom_str(struct ai *g, word x) {   // symbol -> name string, or 0 (a bare mint / the zero point / a non-symbol)
 return namep(x) ? str(nom(x)->name) : 0; }  // a named point (KNom) carries its name; a bare mint is nameless

static ai_inline uintptr_t stringlen(struct ai *g, word x) {  // bytes x contributes to a concat
 if (strp(x)) return len(x);
 if (nomp(x)) { struct ai_str *n = nom_str(g, x); return n ? n->len : 0; }
 return 1; }                                            // number -> one byte
                                                        //
ai_inline char *add_emit(struct ai *g, char *w, word x) {  // append x's bytes; return advanced w
 if (strp(x)) return (void) memcpy(w, txt(x), len(x)), w + len(x);
 if (nomp(x)) { struct ai_str *n = nom_str(g, x);
  return n ? ((void) memcpy(w, txt(n), n->len), w + n->len) : w; }
 return *w = (char) seq_byte(x), w + 1; }               // number -> one byte (unreachable from + since the
                                                        // degenerate lane; symbol paths never land here)
struct ai_str *seq_cat(struct ai *g, void *w, word a, word b) {
 struct ai_str *z = ini_str(str(w), stringlen(g, a) + stringlen(g, b));
 return add_emit(g, add_emit(g, txt(z), a), b), z; }

lvm(lvm_add_string) {
 word a = Sp[0], b = Sp[1];
 if (trayp(a) || trayp(b)) ai_musttail return Push(ZeroPoint); // array <-> string: undefined
 if ((!strp(a) && seq_byte(a) < 0) || (!strp(b) && seq_byte(b) < 0)) ai_musttail return Push(ZeroPoint);
 uintptr_t n = stringlen(g, a) + stringlen(g, b);
 if (!n) ai_musttail return Push(EmptyString);
 uintptr_t req = str_width(n);
 Have(req);
 a = Sp[0], b = Sp[1];                                  // re-read post-GC
 struct ai_str *z = seq_cat(g, Hp, a, b);                     // a's bytes then b's, in order
 Hp += req;
 *++Sp = word(z);
 Ip++; ai_musttail return Continue(); }
lvm(lvm_0) {                             // unsupported mix (array <-> string)
 ai_musttail return Push(ZeroPoint); }
// the unit lane: a bare mint rides through +/*. the dispatchers early-out a mint
// first, so these cells are belt and braces -- but they say the true thing, so
// the matrix stands correct on its own (mx.v checks the whole square).
lvm(lvm_bin_unit) {                       // a point is the identity; of two, the later stands (lvm_add's fast path says the same)
 word a = Sp[0], b = Sp[1];
 ai_musttail return Push(nomp(a) ? b : a); }
// the degenerate lane: a mixed pair with no lawful crossing answers the higher
// band's operand whole -- the foreigner arrives as that band's unit, since the
// only hom a group has into a free monoid is trivial. this is what restores +
// associativity (the byte law and the element-adjoin law could not associate).
lvm(lvm_bin_a) { word a = Sp[0]; ai_musttail return Push(a); }
lvm(lvm_bin_b) { word b = Sp[1]; ai_musttail return Push(b); }

// ============================================================================
// tray
// ============================================================================
size_t const ai_T[] = {
 [ai_Z] = Bytes,
 [ai_R] = Bytes,
 [ai_C] = 2 * Bytes,      // complex scalar: (re, im)
 [ai_O] = Bytes, };       // object: one tagged l word per element

uintptr_t ai_tray_bytes(struct ai_tray *v) {
 return tray_bytes(v->type, v->rank, tray_nelem(v)); }

// these are love.h's data-apply shims: one TU has to hold the body.
#if ai_data_section
// the slot is the kind. each sentinel lays in its own input section love.data.N,
// N its enum d value, on a grain of ai_data_stride -- so a run of one-fn sections
// tiles at exactly that, and ai_typ is one divide on (ap - lvm_sym) with in_data one
// unsigned compare (love.h). ld is told the tiling outright, in scripts mx.l lays
// from the same roster enum d comes from; holo needs no telling -- it lays each
// section on the grain the object declares, which is the same thing.
#define DSENT(nn, name, handler) \
 __attribute__((section("love.data." #nn), used, aligned(ai_data_stride))) \
 lvm(name) { ai_musttail return Ap(handler, g); }
DSENT(0,  lvm_sym,     data_sym_apply)
DSENT(1,  lvm_nom,     data_sym_apply)
DSENT(2,  lvm_sunbox,  data_num_apply)
DSENT(3,  lvm_gembox,  data_num_apply)
DSENT(4,  lvm_twinbox, data_num_apply)
DSENT(5,  lvm_big,     data_num_apply)
DSENT(6,  lvm_tray,    data_num_apply)
DSENT(7,  lvm_str,     data_string_apply)
DSENT(8,  lvm_chain,   data_pair_apply)
#else
lvm(lvm_tray)   { ai_musttail return Ap(data_num_apply, g); }
lvm(lvm_big)   { ai_musttail return Ap(data_num_apply, g); }
lvm(lvm_str)   { ai_musttail return Ap(data_string_apply, g); }
lvm(lvm_sym)   { ai_musttail return Ap(data_sym_apply, g); }
lvm(lvm_nom)   { ai_musttail return Ap(data_sym_apply, g); }
lvm(lvm_chain) { ai_musttail return Ap(data_pair_apply, g); }
lvm(lvm_gembox)   { ai_musttail return Ap(data_num_apply, g); }
lvm(lvm_sunbox)  { ai_musttail return Ap(data_num_apply, g); }
lvm(lvm_twinbox)  { ai_musttail return Ap(data_num_apply, g); }
#endif

// def1 is nifs.h's, and this TU is where that header lands; snap.c walks the
// same table to number the aps it serializes.
struct ai_def const *const ai_def1 = def1;
uintptr_t const ai_def1_n = countof(def1);

