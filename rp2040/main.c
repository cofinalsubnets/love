// Raspberry Pi Pico frontend for gwen lisp.
//
// gwen's frontend contract (see g/g.h): the host must define g_clock, the
// g_stdin/g_stdout ports, and the g_fd_port_vt vtable that backs any port
// with fd >= 0. Here both ports ride the pico USB CDC console (the board's
// own USB port enumerates as a serial device -- no UART pins used); the
// REPL line editor in repl.g drives that console exactly as it drives the
// kernel's serial console. On top of the contract we expose a handful of
// GPIO bifs so gwen programs can blink LEDs and read pins.
#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "../core/i.h"          // g.h + G_WAIT_FDS_MAX and the cooperative-wait prototypes

const uint LED_PIN = 25;        // onboard LED, lit once boot succeeds

// --- fault diagnostics (temporary) ----------------------------------------
// The RP2040 is a Cortex-M0+ (ARMv6-M): no CFSR/BFAR fault status registers,
// and it cannot do unaligned access. A fault during the prelude eval happens
// before USB is up, so nothing can print. This handler overrides the SDK's
// weak spin-loop isr_hardfault, captures the hardware-stacked exception frame
// into g_fault, and halts via bkpt so an attached SWD debugger lands here.
// Read `g_fault` to get the faulting pc/lr and the sp at fault:
//   * pc  -> arm-none-eabi-addr2line -e main.elf <pc>   (which C line faulted)
//   * sp  -> below 0x20038000 (__StackBottom) means stack overflow.
// Remove once the cause is known.
volatile struct g_fault {
  uint32_t r0, r1, r2, r3, r12, lr, pc, psr, sp, magic;
} g_fault;

__attribute__((used)) void hardfault_report(uint32_t *frame) {
  g_fault.r0  = frame[0]; g_fault.r1 = frame[1]; g_fault.r2 = frame[2];
  g_fault.r3  = frame[3]; g_fault.r12 = frame[4]; g_fault.lr = frame[5];
  g_fault.pc  = frame[6]; g_fault.psr = frame[7];
  g_fault.sp  = (uint32_t) frame;        // SP just above the stacked frame
  g_fault.magic = 0xFA017EDu;
  for (;;) __asm volatile ("bkpt 0"); }

void __attribute__((naked)) isr_hardfault(void) {
  __asm volatile (
    "movs r0, #4         \n"   // EXC_RETURN bit 2: 0 => MSP was active, 1 => PSP
    "mov  r1, lr         \n"
    "tst  r1, r0         \n"
    "bne  1f             \n"
    "mrs  r0, msp        \n"
    "b    2f             \n"
    "1: mrs r0, psp      \n"
    "2: bl  hardfault_report \n"); }

// --- clock ----------------------------------------------------------------
// Milliseconds since boot. Used by the garbage collector and (clock _).
uintptr_t g_clock(void) {
  return to_ms_since_boot(get_absolute_time()); }

// --- serial input ---------------------------------------------------------
// pico stdio has no "bytes available" probe, so we keep a one-byte
// lookahead: ser_ready peeks (non-blocking) and stashes the byte; ser_getc
// hands back the stashed byte or blocks for the next one. The REPL's line
// editor expects raw bytes (it decodes ANSI escapes itself), so we read
// through getchar_timeout_us rather than the CR/LF-translating getchar.
static int peeked = -1;

static bool ser_ready(void) {
  if (peeked < 0) {
    int c = getchar_timeout_us(0);
    if (c != PICO_ERROR_TIMEOUT) peeked = c; }
  return peeked >= 0; }

static int ser_getc(void) {
  if (peeked >= 0) { int c = peeked; peeked = -1; return c; }
  int c;
  while ((c = getchar_timeout_us(0)) == PICO_ERROR_TIMEOUT) tight_loop_contents();
  return c; }

// Non-blocking readiness probe for fd 0 (serial input). Other fds report
// ready so writes/(key) on them never park. (key) and the cooperative
// fgetc wait both route through here.
bool g_ready(int fd) { return fd == 0 ? ser_ready() : fd >= 0; }

// --- cooperative waits ----------------------------------------------------
// The task scheduler (g_vm_yield_sw) parks the whole VM here when every task
// is blocked: g_sleep for a pure timed wait, g_wait_fds when tasks are
// parked on input streams. The host backs these with poll(2); we have no
// poll, so we sleep on a low-power WFE (woken by timer/USB IRQs) and re-poll
// the deadline -- and, for g_wait_fds, fd readiness -- on each wake, the same
// shape as the kernel's kwait loop. ticks are g_clock() units (ms);
// ticks == 0 means wait forever. g_wait_fds caps each WFE to a short slice so
// it still re-polls readiness even if the active stdio backend (e.g. a
// polled UART) raises no IRQ to wake us.
#define POLL_SLICE_US 2000

void g_sleep(uintptr_t ms) {
  absolute_time_t deadline = ms ? make_timeout_time_ms(ms) : at_the_end_of_time;
  while (!best_effort_wfe_or_timeout(deadline)) tight_loop_contents(); }

void g_wait_fds(int const *fds, int n, uintptr_t ms) {
  if (n <= 0) { g_sleep(ms); return; }
  if (n > G_WAIT_FDS_MAX) __builtin_trap();
  uintptr_t now = g_clock(), deadline = now + ms;
  for (;;) {
    for (int i = 0; i < n; i++) if (g_ready(fds[i])) return;
    if (ms && (now = g_clock()) >= deadline) return;
    best_effort_wfe_or_timeout(make_timeout_time_us(POLL_SLICE_US)); } }

// --- port vtable ----------------------------------------------------------
// Both ports are backed by the same serial console; the fd is nominal
// (>= 0 so the dispatcher routes here rather than to a synthetic slot).
// Serial never reaches EOF -- the console is endless -- so the dispatcher's
// eof_seen latch never trips.
static struct g *fd_getc(struct g *f) {
  struct g *fc = g_core_of(f);
  struct g_io *i = fc->io;
  if (g_getnum(i->ungetc_buf) != EOF) {
    fc->b = g_getnum(i->ungetc_buf);
    i->ungetc_buf = g_putnum(EOF);
    return f; }
  fc->b = ser_getc();
  return f; }

static struct g *fd_ungetc(struct g *f, int c) {
  struct g *fc = g_core_of(f);
  struct g_io *i = fc->io;
  i->ungetc_buf = g_putnum(c);
  i->eof_seen = g_putnum(false);
  return fc->b = c, f; }

static struct g *fd_eof(struct g *f) {
  struct g *fc = g_core_of(f);
  struct g_io *i = fc->io;
  return fc->b = (g_getnum(i->ungetc_buf) == EOF) && g_getnum(i->eof_seen), f; }

static struct g *fd_putc(struct g *f, int c) {
  if (c == '\n') putchar_raw('\r');     // cook LF -> CRLF for terminals
  putchar_raw(c);
  return f; }

static struct g *fd_flush(struct g *f) { stdio_flush(); return f; }

struct g_io g_stdin = { .ap = g_vm_port_io,
                        .fd = g_putnum(0), .ungetc_buf = g_putnum(EOF), .eof_seen = g_putnum(false), };
struct g_io g_stdout = { .ap = g_vm_port_io,
                         .fd = g_putnum(1), .ungetc_buf = g_putnum(EOF), .eof_seen = g_putnum(false), };
// No separate error stream; route err to the same fd as out (the console).
struct g_io g_stderr = { .ap = g_vm_port_io,
                         .fd = g_putnum(1), .ungetc_buf = g_putnum(EOF), .eof_seen = g_putnum(false), };
struct g_port_vt const g_fd_port_vt = { fd_getc, fd_ungetc, fd_eof, fd_putc, fd_flush };

// --- GPIO builtins --------------------------------------------------------
// (gpio_init pin)    -- claim a pin for SIO; returns the pin.
// (gpio_dir pin out) -- set direction: out non-nil => output; returns out.
// (gpio_put pin val) -- drive an output pin: val non-nil => high; returns val.
// (gpio_get pin)     -- sample an input pin; returns 1 (high) or 0 (low).
// Truthiness follows gwen: nil is g_putnum(0), so g_getnum(arg) != 0 reads
// either a number or nil correctly.
static g_vm(g_gpio_init) {
  gpio_init(g_getnum(Sp[0]));           // leaves Sp[0] (the pin) as the result
  Ip += 1;
  return Continue(); }

static g_vm(g_gpio_get) {
  Sp[0] = g_putnum(gpio_get(g_getnum(Sp[0])));
  Ip += 1;
  return Continue(); }

static g_vm(g_gpio_dir) {
  unsigned pin = g_getnum(Sp[0]);
  int out = g_getnum(Sp[1]) != 0;
  gpio_set_dir(pin, out);
  Sp[1] = g_putnum(out);
  Sp += 1;
  Ip += 1;
  return Continue(); }

static g_vm(g_gpio_put) {
  unsigned pin = g_getnum(Sp[0]);
  int val = g_getnum(Sp[1]) != 0;
  gpio_put(pin, val);
  Sp[1] = g_putnum(val);
  Sp += 1;
  Ip += 1;
  return Continue(); }

// 1-arg bifs run their thunk directly; 2-arg bifs build a 2-slot frame
// with g_vm_cur first (mirrors pd/main.c's cur_set).
static union u
  bif_gpio_init[] = {{g_gpio_init}, {g_vm_ret0}},
  bif_gpio_get[]  = {{g_gpio_get}, {g_vm_ret0}},
  bif_gpio_dir[]  = {{g_vm_cur}, {.x = g_putnum(2)}, {g_gpio_dir}, {g_vm_ret0}},
  bif_gpio_put[]  = {{g_vm_cur}, {.x = g_putnum(2)}, {g_gpio_put}, {g_vm_ret0}};

static struct g_def defs[] = {
  {"gpio_init", (intptr_t) bif_gpio_init},
  {"gpio_dir",  (intptr_t) bif_gpio_dir},
  {"gpio_put",  (intptr_t) bif_gpio_put},
  {"gpio_get",  (intptr_t) bif_gpio_get}, };

// --- prelude --------------------------------------------------------------
// boot.g + repl.g, embedded as a C string by the host's lcat (the pico
// CMake build invokes `make -C ../h boot.h repl.h` to regenerate them).
static char const boot[] =
#include "prelude.h"
,
  repl[] =
//#include "repl.h"
"(: yy (sym 0) (repl _ _) (: r (read yy) (, (? (!= r yy) (, (. (ev r)) (putc 10))) (repl _ _))))"
;

static uint8_t pool[200 * (1<<10)];
#include <stdio.h>
int main() {
  stdio_init_all();

  gpio_init(LED_PIN);
  gpio_set_dir(LED_PIN, GPIO_OUT);

  struct g *f = g_defn(g_ini_s(pool, sizeof pool), defs, LEN(defs));
  f = g_evals_(f, boot);
  f = g_evals_(f, repl);
  if (g_ok(f)) {
    gpio_put(LED_PIN, 1);               // alive: prelude loaded
    f = g_evals_(f, "(repl 0 0)");
    while (1) printf("yay\n"), g_sleep(1000);
  }    // serial read-eval-print loop
  else {
    while (1)
     printf("nope s=%d l=%d\n", g_code_of(f), g_core_of(f)->len),

     g_sleep(1000);
  }
  g_fin(f);

  // The REPL only returns on a fatal error; hold the LED off and idle.
  gpio_put(LED_PIN, 0);
  while (1) tight_loop_contents(); }
