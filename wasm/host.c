// emscripten host shim for ai.
//
// l's frontend contract (see g/g.h): the host must define g_clock, the
// g_stdin/g_stdout ports, and the g_fd_port_vt vtable that backs any port
// with fd >= 0. Here stdout's putc appends to a JS-visible byte buffer that
// the page drains via ai_out_ptr/len/reset; stdin always reads EOF (the
// REPL feeds source through ai_eval, not the stdin port). boot.l is
// embedded and evaluated once by ai_init.
#include "ai.h"
#include <emscripten.h>
#include <time.h>
#include <stdlib.h>
#include <stdnoreturn.h>

static const char boot_ai[] = "("
#include "egg.h"
  g_egg_pre
#include "prelude.h"
  " "
#include "ev.h"
  g_egg_post
;

// 256K: a single ai_eval can emit a lot before the page drains it -- the
// whole test corpus (test_wasm) runs in one eval and prints ~25K of dots +
// the summary. Output past the cap is dropped (never overruns, see _putc).
static char     out_buf[1 << 18];
static uint32_t out_len;

uintptr_t g_clock(void) {
  struct timespec ts;
  return clock_gettime(CLOCK_MONOTONIC, &ts) ? 0
       : ts.tv_sec * 1000u + ts.tv_nsec / 1000000u; }

// --- ports ----------------------------------------------------------------
// Output goes to out_buf; the page reads it back through the exports below.
static struct g *_putc(struct g *g, int c) {
  if (out_len < sizeof out_buf) out_buf[out_len++] = (char) c;
  return g; }
static struct g *_flush(struct g *g) { return g; }

// No real stdin: getc reports EOF (honouring any pushed-back byte first).
static struct g *_getc(struct g *g) {
  struct g_io *i = g_core_of(g)->io;
  if (getfix(i->ungetc_buf) != EOF) {
    int c = getfix(i->ungetc_buf);
    i->ungetc_buf = putfix(EOF);
    return g_core_of(g)->b = c, g; }
  i->eof_seen = putfix(true);
  return g_core_of(g)->b = EOF, g; }
static struct g *_ungetc(struct g *g, int c) {
  struct g_io *i = g_core_of(g)->io;
  i->ungetc_buf = putfix(c);
  i->eof_seen = putfix(false);
  return g_core_of(g)->b = c, g; }
static struct g *_eof(struct g *g) {
  struct g_io *i = g_core_of(g)->io;
  return g_core_of(g)->b = (getfix(i->ungetc_buf) == EOF) && getfix(i->eof_seen), g; }

// fd values are nominal: all I/O routes through the vtable regardless. We
// just need fd >= 0 so the dispatcher picks g_fd_port_vt over a synth slot.
struct g_io g_stdin  = { .ap = lvm_port_io, .fd = putfix(0),
                         .ungetc_buf = putfix(EOF), .eof_seen = putfix(false) };
struct g_io g_stdout = { .ap = lvm_port_io, .fd = putfix(1),
                         .ungetc_buf = putfix(EOF), .eof_seen = putfix(false) };
// No separate error stream in the browser host; route err to out's fd.
struct g_io g_stderr = { .ap = lvm_port_io, .fd = putfix(1),
                         .ungetc_buf = putfix(EOF), .eof_seen = putfix(false) };
struct g_port_vt const g_fd_port_vt = { _getc, _ungetc, _eof, _putc, _flush };

// (exit n) -- a frontend nif, like main.c's and kmain.c's. The wasm host needs
// it for the same reason they do: the test harness aborts a failed assert with
// (exit 1), and -- subtler -- a closure captures its free globals at creation,
// so a body that merely MENTIONS `exit` (e.g. an assert's unrun fail branch)
// raises (scare 'missing 'exit) at the define if the name is absent. Without
// this, every assert fired a spurious missing-scare on wasm, inflating help-log.
// emscripten maps exit() to an ExitStatus the JS caller catches (see test.mjs).
static noreturn lvm(lvm_exit) { exit(getfix(Sp[0])); }
static union u const nif_exit[] = {{lvm_exit}, {lvm_ret0}};

// --- exported entry points ------------------------------------------------
static struct g *F;

EMSCRIPTEN_KEEPALIVE
int ai_init(void) {
  F = g_ini();
  if (!g_ok(F)) return g_code_of(F);
  struct g_def d[] = {{"exit", (g_word) nif_exit}};
  F = g_defn(F, d, countof(d));
  if (!g_ok(F)) return g_code_of(F);
  F = g_evals_(F, boot_ai);
  return g_code_of(F); }

EMSCRIPTEN_KEEPALIVE
int ai_eval(const char *src) {
  out_len = 0;
  F = g_evals_(F, src);
  return g_code_of(F); }

EMSCRIPTEN_KEEPALIVE char*    ai_out_ptr(void) { return out_buf; }
EMSCRIPTEN_KEEPALIVE uint32_t ai_out_len(void) { return out_len; }
EMSCRIPTEN_KEEPALIVE void     ai_out_reset(void) { out_len = 0; }
