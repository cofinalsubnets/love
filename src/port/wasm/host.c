// emscripten host shim for love.
//
// l's frontend contract (see g/g.h): the host must define ai_clock, the
// ai_stdin/ai_stdout ports, and the ai_fd_port_vt vtable that backs any port
// with fd >= 0. Here stdout's putc appends to a JS-visible byte buffer that
// the page drains via ai_out_ptr/len/reset; stdin always reads EOF (the
// REPL feeds source through ai_eval, not the stdin port). boot.l is
// embedded and evaluated once by ai_init.
#include "love.h"
#include <emscripten.h>
#include <time.h>
#include <stdlib.h>
#include <string.h>
#include <stdnoreturn.h>

// the egg's four texts, one per ai_egg_ argument (love.h): the boot stitches the
// corpus rather than reading it whole -- p0 takes egg + p1, p1 takes corpus + post.
static const char src_egg[] =
#include "egg.h"
;
static const char src_p1[] =
#include "p1.h"
;
static const char src_corpus[] =
#include "prel.h"
 " "
#include "ev.h"
;
static const char src_post[] =
#include "post.h"
;
static const char boot_ai[] =
  "(use 'uu) (: uu (from 'uu))"   // the library layers ride post; the uu kernel keeps its one-name surface
  "(use 'kanren)"
  "(use 'cli)"                    // the shell core, last and spliced, as src/host/main.c has it:
;                                 //   read/reads/welp are reached bare (test/help.l's floor handler)

// 256K: a single ai_eval can emit a lot before the page drains it -- the
// whole test corpus (test_wasm) runs in one eval and prints ~25K of dots +
// the summary. _writen lands what fits and answers the count, so an overflowing
// eval truncates rather than overruns.
//
// ⚠ AND A FULL BUFFER SAYS SO. ai_stdout is a STATIC port: it carries no write
// run (rung 4), and zputc offers a refused byte twice before giving up, so what
// does not fit here really is on the floor. A bigger number would only move the
// cliff; the honest edge is to SAY the answer is short. out_tail is held back
// from the buffer for that one line, so a truncated eval reads as truncated
// instead of stopping mid-word.
//
// ⚠ AND IT SAYS ONLY WHAT IS TRUE -- WHICH IS NOT A BYTE COUNT. lvm_fputs answers
// a refusal by re-offering the whole remainder, and then the byte alone through
// zputc, twice: a device sees each lost byte many times over and cannot tell
// attempts from bytes. What it can tell is THAT it ran out, so that is all it says.
#define out_tail 64
static char     out_buf[1 << 18];
static uint32_t out_len;
static int      out_full;

static void out_note(void) {
  for (char const *s = "\n; output truncated -- the page's buffer is full\n"; *s; s++)
    out_buf[out_len++] = *s; }

uintptr_t ai_clock(void) {
  struct timespec ts;
  return clock_gettime(CLOCK_MONOTONIC, &ts) ? 0
       : ts.tv_sec * 1000u + ts.tv_nsec / 1000000u; }

// --- ports ----------------------------------------------------------------
// Output goes to out_buf; the page reads it back through the exports below.
static struct ai *fd_writen(struct ai *g, unsigned char const *src, uintptr_t n) {
  uintptr_t cap = sizeof out_buf - out_tail,
            room = out_len < cap ? cap - out_len : 0,
            k = room < n ? room : n;
  memcpy(out_buf + out_len, src, k);
  out_len += (uint32_t) k;
  out_full |= k < n;
  return g->b = (intptr_t) k, g; }
static struct ai *_flush(struct ai *g) { return g; }

// stdin is a ring of key bytes the page pushes (ai_key): a read lands what is queued,
// and a dry read answers 0 -- busy, the port protocol's "would block" -- so a task
// reading in parks on fd 0 and comes back when the page has pushed again. it is never
// at the end: the page can always type. only a task may park: the session's own eval
// must never read stdin, since nothing else could run to unpark it.
enum { key_n = 256 };
static unsigned char keys[key_n];
static uint32_t key_rd, key_wr;
// ..except on the session's own task: alone in the ring, nothing could ever unpark it, so
// a dry read there is the end -- a tty app typed at the repl steps ashore at once.
static intptr_t fd_readn(struct ai *g, unsigned char *dst, uintptr_t n) {
  uintptr_t k = 0;
  while (k < n && key_rd != key_wr) dst[k++] = keys[key_rd++ % key_n];
  if (!k && g->tasks->m == g->tasks && !g->parked) return -1;
  return (intptr_t) k; }
// the readiness the scheduler asks: fd 0 has keys or has not; an output fd always.
bool ai_ready(int fd, int events) { return fd ? true : key_rd != key_wr; }
// ..and a wait on fds cannot be had: only the page can push a key, and it does so
// between evals, so a wait naming fds answers at once and the parked task is asked again
// on the next eval. a wait on the clock alone (sleepers, no fds) still sleeps: a task
// resting while its parent catches it is the corpus's own timing law.
void ai_wait_fds(struct ai_wait_fd *fds, int n, uintptr_t ticks) {
  if (!n && ticks) ai_sleep(ticks);
  (void) fds; }

// fd values are nominal: all I/O routes through the vtable regardless.
struct ai_fio ai_stdin  = { { .ap = lvm_port_io, .vt = &ai_fd_port_vt,
                         .ungetc_buf = putcharm(EOF) }, .fd = putcharm(0) };
struct ai_fio ai_stdout = { { .ap = lvm_port_io, .vt = &ai_fd_port_vt,
                         .ungetc_buf = putcharm(EOF) }, .fd = putcharm(1) };
// No separate error stream in the browser host; route err to out's fd.
struct ai_fio ai_stderr = { { .ap = lvm_port_io, .vt = &ai_fd_port_vt,
                         .ungetc_buf = putcharm(EOF) }, .fd = putcharm(1) };
struct ai_port_vt const ai_fd_port_vt = { _flush, fd_writen, fd_readn, NULL };

#include "../fdrow.h"                    // ai_fd_readn / ai_fd_say off the two above

// (exit n) -- a frontend nif, like main.c's and kmain.c's. The wasm host needs
// it for the same reason they do: the test harness aborts a failed assert with
// (exit 1), and -- subtler -- a closure captures its free globals at creation,
// so a body that merely MENTIONS `exit` (e.g. an assert's unrun fail branch)
// raises (scare 'missing 'exit) at the define if the name is absent. Without
// this, every assert fired a spurious missing-scare on wasm, inflating help-log.
// emscripten maps exit() to an ExitStatus the JS caller catches (see test.mjs).
static noreturn lvm(lvm_exit) { exit(getcharm(Sp[0])); }
static union u const nif_exit[] = {{lvm_exit}, {lvm_ret0}};

// --- the console: quay's screen, and the page's mirror of it ---------------
// the engine and its love door ride along by unity include, as src/host/cb.c has them;
// the palette is the .rodata table paint.c spends, so the page's colours are the
// framebuffer's. (mirror scr) copies a screen's head and cells here for the page to lay
// (src/port/wasm/cells.js) -- a copy, since the cask moves with the heap and the page
// reads after the eval returns. answers the cell count, or () for a screen too big.
#include "quay/quay.c"
#include "quay/nif.c"
#include "quay/xterm256.h"
enum { mir_head = 4, mir_max = 1 << 16 };
static uint32_t mir[mir_head + mir_max];   // rows cols cursor flag, then the cells
static lvm(lvm_mirror) {
  struct cb *c = scr_ok(Sp[0]);
  uintptr_t n = c ? (uintptr_t) c->rows * c->cols : 0;
  if (c && n <= mir_max) {
    mir[0] = c->rows, mir[1] = c->cols, mir[2] = c->wpos, mir[3] = c->flag;
    memcpy(mir + mir_head, c->cb, n * 4);
    Sp[0] = putcharm(n); }
  else Sp[0] = ZeroPoint;
  Ip += 1; ai_musttail return Continue(); }
static union u const nif_mirror[] = {{lvm_mirror}, {lvm_ret0}};
EMSCRIPTEN_KEEPALIVE uint32_t*       ai_mirror(void)  { return mir; }
EMSCRIPTEN_KEEPALIVE uint32_t const* ai_palette(void) { return xterm256; }
EMSCRIPTEN_KEEPALIVE uint32_t        ai_unfold(uint32_t g_) { return g_ < 256 ? cb_unfold((uint8_t) g_) : 0; }

// --- exported entry points ------------------------------------------------
static struct ai *F;

// (ai_key b): one key byte into stdin's ring. a full ring drops the byte and says so.
// a key owes the parked reader a look: the scheduler sweeps parked fds only every
// sweep_interval fair yields, so the push arms the sweep and the page's next step --
// a fair yield -- asks fd 0 at once rather than sixteen steps later.
EMSCRIPTEN_KEEPALIVE int ai_key(int b) {
  if (key_wr - key_rd >= key_n) return 0;
  keys[key_wr++ % key_n] = (unsigned char) b;
  if (F && ai_ok(F)) ai_core_of(F)->sweep_ctr = sweep_interval;
  return 1; }

EMSCRIPTEN_KEEPALIVE
int ai_init(void) {
  F = ai_ini();
  if (!ai_ok(F)) return ai_code_of(F);
  // BOUND the collector (the Appel knob): wasm32 has a HARD 2 GB ceiling and
  // ALLOW_MEMORY_GROWTH cannot pass it, so an unbounded pair of pools walks off the end --
  // and it does it at a DOUBLING, where a few percent more live asks for twice the pool.
  // a quarter of the ceiling, like every other bounded seat: the transient peak while a
  // resize holds both halves is double the budget.
  if (ai_ok(F)) ai_core_of(F)->budget = (2048u << 20) / sizeof(ai_word) / 4;
  struct ai_def d[] = {{"exit", (ai_word) nif_exit},
    {"screen", (ai_word) nif_screen}, {"scribe", (ai_word) nif_scribe},
    {"glass", (ai_word) nif_glass},   {"gaze", (ai_word) nif_gaze},
    {"reply", (ai_word) nif_reply},   {"unfold", (ai_word) nif_unfold},
    {"wet", (ai_word) nif_damage},    {"mirror", (ai_word) nif_mirror}};
  F = ai_defn(F, d, countof(d));
  if (!ai_ok(F)) return ai_code_of(F);
  F = ai_egg_(F, src_egg, src_p1, src_corpus, src_post);
  F = ai_evals_(F, boot_ai);
  // THE SESSION: a fresh writable layer, C-side -- everything the page ever
  // feeds through ai_eval defglobs here, never in the base.
  F = ai_layer_(F);
  return ai_code_of(F); }

EMSCRIPTEN_KEEPALIVE
int ai_eval(const char *src) {
  out_len = 0, out_full = 0;
  F = ai_evals_(F, src);
  if (out_full) out_note();
  return ai_code_of(F); }

// (ai_runnable): is a task other than the session's runnable now -- in the run ring,
// not landed, its wake (if any) due? a fair yield is one time slice, so the page yields
// until this says no: the app has parked on stdin, or sleeps, or is done.
EMSCRIPTEN_KEEPALIVE int ai_runnable(void) {
  struct ai *g = ai_core_of(F);
  uintptr_t now = ai_clock();
  for (union u *n = g->tasks->m; n != g->tasks; n = n->m) {
    if (n[1].m->ap == lvm_task_exit) continue;
    uintptr_t wake = (uintptr_t) getcharm(n[3].x);
    if (!wake || wake <= now) return 1; }
  return 0; }
// (ai_alive): does a task other than the session's live -- in the run ring and not
// landed, or parked? the page's app and whatever it opened through the door.
EMSCRIPTEN_KEEPALIVE int ai_alive(void) {
  struct ai *g = ai_core_of(F);
  if (g->parked) return 1;
  for (union u *n = g->tasks->m; n != g->tasks; n = n->m)
    if (n[1].m->ap != lvm_task_exit) return 1;
  return 0; }
EMSCRIPTEN_KEEPALIVE char*    ai_out_ptr(void) { return out_buf; }
EMSCRIPTEN_KEEPALIVE uint32_t ai_out_len(void) { return out_len; }
EMSCRIPTEN_KEEPALIVE void     ai_out_reset(void) { out_len = 0; }
