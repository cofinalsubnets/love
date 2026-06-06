// emscripten host shim for gwen lisp.
//
// gwen's frontend contract (see g/g.h): the host must define g_clock, the
// g_stdin/g_stdout ports, and the g_fd_port_vt vtable that backs any port
// with fd >= 0. Here stdout's putc appends to a JS-visible byte buffer that
// the page drains via gwen_out_ptr/len/reset; stdin always reads EOF (the
// REPL feeds source through gwen_eval, not the stdin port). boot.g is
// embedded and evaluated once by gwen_init.
#include "gwen.h"
#include <emscripten.h>
#include <time.h>

static const char boot_g[] = G_EGG_PRE
#include "prelude.h"
  " "
#include "ev.h"
  G_EGG_POST
;

static char     out_buf[1 << 14];
static uint32_t out_len;

uintptr_t g_clock(void) {
  struct timespec ts;
  return clock_gettime(CLOCK_MONOTONIC, &ts) ? 0
       : ts.tv_sec * 1000u + ts.tv_nsec / 1000000u; }

// --- ports ----------------------------------------------------------------
// Output goes to out_buf; the page reads it back through the exports below.
static struct g *_putc(struct g *f, int c) {
  if (out_len < sizeof out_buf) out_buf[out_len++] = (char) c;
  return f; }
static struct g *_flush(struct g *f) { return f; }

// No real stdin: getc reports EOF (honouring any pushed-back byte first).
static struct g *_getc(struct g *f) {
  struct g_io *i = g_core_of(f)->io;
  if (g_getnum(i->ungetc_buf) != EOF) {
    int c = g_getnum(i->ungetc_buf);
    i->ungetc_buf = g_putnum(EOF);
    return g_core_of(f)->b = c, f; }
  i->eof_seen = g_putnum(true);
  return g_core_of(f)->b = EOF, f; }
static struct g *_ungetc(struct g *f, int c) {
  struct g_io *i = g_core_of(f)->io;
  i->ungetc_buf = g_putnum(c);
  i->eof_seen = g_putnum(false);
  return g_core_of(f)->b = c, f; }
static struct g *_eof(struct g *f) {
  struct g_io *i = g_core_of(f)->io;
  return g_core_of(f)->b = (g_getnum(i->ungetc_buf) == EOF) && g_getnum(i->eof_seen), f; }

// fd values are nominal: all I/O routes through the vtable regardless. We
// just need fd >= 0 so the dispatcher picks g_fd_port_vt over a synth slot.
struct g_io g_stdin  = { .ap = g_vm_port_io, .fd = g_putnum(0),
                         .ungetc_buf = g_putnum(EOF), .eof_seen = g_putnum(false) };
struct g_io g_stdout = { .ap = g_vm_port_io, .fd = g_putnum(1),
                         .ungetc_buf = g_putnum(EOF), .eof_seen = g_putnum(false) };
// No separate error stream in the browser host; route err to out's fd.
struct g_io g_stderr = { .ap = g_vm_port_io, .fd = g_putnum(1),
                         .ungetc_buf = g_putnum(EOF), .eof_seen = g_putnum(false) };
struct g_port_vt const g_fd_port_vt = { _getc, _ungetc, _eof, _putc, _flush };

// --- exported entry points ------------------------------------------------
static struct g *F;

EMSCRIPTEN_KEEPALIVE
int gwen_init(void) {
  F = g_ini();
  if (!g_ok(F)) return g_code_of(F);
  F = g_evals_(F, boot_g);
  return g_code_of(F); }

EMSCRIPTEN_KEEPALIVE
int gwen_eval(const char *src) {
  out_len = 0;
  F = g_evals_(F, src);
  return g_code_of(F); }

EMSCRIPTEN_KEEPALIVE char*    gwen_out_ptr(void) { return out_buf; }
EMSCRIPTEN_KEEPALIVE uint32_t gwen_out_len(void) { return out_len; }
EMSCRIPTEN_KEEPALIVE void     gwen_out_reset(void) { out_len = 0; }
