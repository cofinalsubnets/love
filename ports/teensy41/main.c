// Teensy 4.1 (i.MX RT1062) frontend for love -- bare metal, no Teensyduino.
//
// love's frontend contract (ai.h): the host defines g_clock, the
// g_stdin/g_stdout ports, the g_fd_port_vt vtable, and the cooperative-wait
// hooks. Here the console is LPUART6 on pin0(RX)/pin1(TX) at 115200 8N1,
// reachable over a 3.3 V USB-serial adapter -- the analogue of the rp2040
// port's UART0 console (USB CDC is a TODO, see README). The arch backend
// (teensy41.c) owns the FlexSPI boot image, startup, clocks, LPUART, GPT
// timer, and GPIO; this file is just the love glue plus a few GPIO nifs. The
// REPL line editor in repl.l drives the console exactly as it drives the
// kernel's.
#include "../../ai.h"
#include "teensy41.h"

#ifndef EOF
#define EOF (-1)
#endif

// --- cooperative waits ----------------------------------------------------
// The host backs these with poll(2); we have only the free-running GPT timer
// and a polled LPUART, so spin against a g_clock() deadline (ticks are ms;
// ticks==0 means wait forever). No IRQs are enabled, so there is nothing to
// WFE on -- a tight poll keeps (key)/timed sleeps re-checking readiness. Same
// shape as the host's poll_wait, minus the kernel.
void g_sleep(uintptr_t ms) {
  if (!ms) { for (;;) __asm volatile("wfi"); }   // infinite: park (reset to exit)
  uintptr_t start = g_clock();
  while (g_clock() - start < ms) __asm volatile("nop"); }

bool g_ready(int fd) { return fd == 0 ? serial_rx_ready() : fd >= 0; }

void g_wait_fds(int const *fds, int n, uintptr_t ms) {
  if (n <= 0) { g_sleep(ms); return; }
  if (n > g_wait_fds_max) __builtin_trap();
  uintptr_t start = g_clock();
  for (;;) {
    for (int i = 0; i < n; i++) if (g_ready(fds[i])) return;
    if (ms && g_clock() - start >= ms) return;
    __asm volatile("nop"); } }

// --- port vtable ----------------------------------------------------------
// Both ports ride LPUART6; the fd is nominal (>= 0 so the dispatcher routes
// here). Serial never reaches EOF, so the dispatcher's eof_seen latch never
// trips.
static struct g *fd_getc(struct g *g) {
  struct g *fc = g_core_of(g);
  struct g_io *i = fc->io;
  if (getfix(i->ungetc_buf) != EOF) {
    fc->b = getfix(i->ungetc_buf);
    i->ungetc_buf = putfix(EOF);
    return g; }
  fc->b = serial_getc();
  return g; }

static struct g *fd_ungetc(struct g *g, int c) {
  struct g *fc = g_core_of(g);
  struct g_io *i = fc->io;
  i->ungetc_buf = putfix(c);
  i->eof_seen = putfix(false);
  return fc->b = c, g; }

static struct g *fd_eof(struct g *g) {
  struct g *fc = g_core_of(g);
  struct g_io *i = fc->io;
  return fc->b = (getfix(i->ungetc_buf) == EOF) && getfix(i->eof_seen), g; }

static struct g *fd_putc(struct g *g, int c) {
  if (c == '\n') serial_putc('\r');     // cook LF -> CRLF for terminals
  serial_putc(c);
  return g; }

static struct g *fd_flush(struct g *g) { return g; }   // LPUART has no buffer here

struct g_io g_stdin  = { .ap = lvm_port_io, .fd = putfix(0), .ungetc_buf = putfix(EOF), .eof_seen = putfix(false) };
struct g_io g_stdout = { .ap = lvm_port_io, .fd = putfix(1), .ungetc_buf = putfix(EOF), .eof_seen = putfix(false) };
// No separate error stream; route err to the console too.
struct g_io g_stderr = { .ap = lvm_port_io, .fd = putfix(1), .ungetc_buf = putfix(EOF), .eof_seen = putfix(false) };
struct g_port_vt const g_fd_port_vt = { fd_getc, fd_ungetc, fd_eof, fd_putc, fd_flush };

// --- GPIO builtins --------------------------------------------------------
// (gpio_init pin)    -- claim a GPIO2 bit (pin 13 also gets its pad muxed); returns the pin.
// (gpio_dir pin out) -- direction: out non-nil => output; returns out.
// (gpio_put pin val) -- drive an output: val non-nil => high; returns val.
// (gpio_get pin)     -- sample an input; returns 1 (high) or 0 (low).
// nil is putfix(0), so getfix(arg) != 0 reads a number or nil correctly.
static lvm(g_gpio_init) {
  gpio_init(getfix(Sp[0]));           // leaves Sp[0] (the pin) as the result
  Ip += 1;
  return Continue(); }

static lvm(g_gpio_get) {
  Sp[0] = putfix(gpio_get(getfix(Sp[0])));
  Ip += 1;
  return Continue(); }

static lvm(g_gpio_dir) {
  unsigned pin = getfix(Sp[0]);
  int out = getfix(Sp[1]) != 0;
  gpio_set_dir(pin, out);
  Sp[1] = putfix(out);
  Sp += 1;
  Ip += 1;
  return Continue(); }

static lvm(g_gpio_put) {
  unsigned pin = getfix(Sp[0]);
  int val = getfix(Sp[1]) != 0;
  gpio_put(pin, val);
  Sp[1] = putfix(val);
  Sp += 1;
  Ip += 1;
  return Continue(); }

// 1-arg nifs run their thunk directly; 2-arg nifs build a 2-slot frame with
// lvm_cur first (mirrors the host's nif_open shape).
static union u const
  nif_gpio_init[] = {{g_gpio_init}, {lvm_ret0}},
  nif_gpio_get[]  = {{g_gpio_get}, {lvm_ret0}},
  nif_gpio_dir[]  = {{lvm_cur}, {.x = putfix(2)}, {g_gpio_dir}, {lvm_ret0}},
  nif_gpio_put[]  = {{lvm_cur}, {.x = putfix(2)}, {g_gpio_put}, {lvm_ret0}};

static struct g_def defs[] = {
  {"gpio_init", (intptr_t) nif_gpio_init},
  {"gpio_dir",  (intptr_t) nif_gpio_dir},
  {"gpio_put",  (intptr_t) nif_gpio_put},
  {"gpio_get",  (intptr_t) nif_gpio_get}, };

// --- entry ----------------------------------------------------------------
// cstartup (teensy41.c) has set up the FPU, .data/.bss, VTOR, clocks, and the
// console before calling us. The static pool is the whole love heap (we run
// RAM out of the 512 KB OCRAM2; no malloc); the rest of OCRAM2 above it is the
// C stack. The bootstrap egg compiles the love compiler with the C evaluator,
// recompiles it with itself, installs it, then we run the REPL -- identical to
// host/free, just smaller. The pool is sized to leave headroom for the stack
// under __stack_top__; if the self-hosting double-bake OOMs on real silicon,
// shrink it, move RAM to PSRAM (0x70000000), or trim the egg.
static uint8_t pool[384 * (1 << 10)];

int main(void) {
  struct g *g = g_defn(g_ini_s(pool, sizeof pool), defs, countof(defs));
  g = g_evals_(g, "("
#include "egg.h"
    g_egg_pre
#include "prelude.h"
    " "
#include "ev.h"
    g_egg_post
#include "repl.h"
    "(shell 0)");
  // The REPL only returns on a fatal error. Idle low-power afterward.
  (void) g;
  for (;;) __asm volatile("wfi"); }
