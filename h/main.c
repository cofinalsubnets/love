#include "../g/g.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <termios.h>
#include <time.h>
#include <poll.h>

g_noinline uintptr_t g_clock(void) {
  struct timespec ts;
  return clock_gettime(CLOCK_REALTIME, &ts) ? (uintptr_t) -1
       : (uintptr_t) (ts.tv_sec * 1000 + ts.tv_nsec / 1000000); }

// --- host output -----------------------------------------------------
static struct g *_putc(struct g *f, int c, struct g_out*) { return putchar(c), f; }
static struct g *_flush(struct g *f, struct g_out*)       { return fflush(stdout), f; }
static struct g_out _g_stdout = { _putc, _flush };
struct g_out *g_stdout = &_g_stdout;

// --- raw terminal mode -----------------------------------------------
static struct termios saved_termios;
static void restore_termios(void) {
  tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios); }

static void raw_mode(void) {
  tcgetattr(STDIN_FILENO, &saved_termios);
  atexit(restore_termios);                 // restore on normal exit
  struct termios raw = saved_termios;
  raw.c_lflag &= ~(ICANON | ECHO | ISIG | IEXTEN);  // no line buffering/echo
  raw.c_iflag &= ~(IXON | ICRNL | BRKINT | INPCK | ISTRIP);
  raw.c_cc[VMIN] = 1;                      // block for one byte
  raw.c_cc[VTIME] = 0;
  tcsetattr(STDIN_FILENO, TCSANOW, &raw); }
  // c_oflag is left alone, so '\n' on output still becomes CR-LF.

// (key?) backend: non-consuming check whether the next (getc 0) would return
// immediately. True iff stdin has a byte ready (or is at EOF — poll returns
// POLLIN for that too). Never consumes input.
bool g_key(void) {
  struct pollfd p = { .fd = STDIN_FILENO, .events = POLLIN };
  return poll(&p, 1, 0) > 0; }

// Deep wait: block for up to `ms` ms or until stdin becomes readable,
// whichever comes first. Called by the scheduler when every task is sleeping;
// the early return on input lets a task suspended in g_vm_getc resume without
// having to wait out the full sleep deadline. POLLIN fires for EOF too, so an
// EOF'd stdin never holds the deadline. ms is clamped to INT_MAX (~24 days)
// to fit poll()'s int timeout.
void g_wait(uintptr_t ms) {
  struct pollfd p = { .fd = STDIN_FILENO, .events = POLLIN };
  poll(&p, 1, ms > (uintptr_t) __INT_MAX__ ? __INT_MAX__ : (int) ms); }

// --- host input ------------------------------------------------------
// raw_stdin is the byte source at f->in: non-interactively the parser
// reads it directly; interactively the gwen line editor (boot.g) reads
// its keystrokes through it. one byte per getc, delivered in f->b. it
// never allocates the gwen heap, so f stays valid across a getc.
static struct g *raw_getc(struct g *f, struct g_in*) {
  return g_core_of(f)->b = fgetc(stdin), f; }
static struct g *raw_ungetc(struct g *f, int c, struct g_in*) {
  return g_core_of(f)->b = ungetc(c, stdin), f; }
static struct g *raw_eof(struct g *f, struct g_in*) {
  return g_core_of(f)->b = feof(stdin), f; }
static struct g_in raw_stdin = { raw_getc, raw_ungetc, raw_eof };
struct g_in *g_stdin = &raw_stdin;

static char const
boot[] =
#include "boot.h"
,
infix[] =
#include "infix.h"
,
repl[] =
#include "repl.h"
,
  rel[] = "(:(g e)(: r(read e)(?(= e r)0(: _(ev 'ev r)(g e))))(g(sym 0)))"
  ;
// --- main: load the prelude and run the REPL script ------------------
int main(int argc, char const **argv) {
  struct g *f = g_ini();
  bool is_repl = isatty(STDIN_FILENO);
  // disable stdio read-ahead so g_key (poll on STDIN_FILENO) reflects the
  // true byte-available state — otherwise fgetc slurps bytes into a libc
  // buffer that poll cannot see, and g_vm_getc yields when bytes are
  // actually ready. needed for both raw and pipe modes.
  setvbuf(stdin, NULL, _IONBF, 0);
  if (is_repl) raw_mode();                 // interactive: raw tty; the line
                                           // editor is now pure gwen (boot.g)
  for (; *argv; f = g_strof(f, *argv++));
  for (f = g_push(f, 1, g_nil); argc--; f = gxr(f));
  if (g_ok(f)) {
    struct g_def d[] = {{"argv", g_pop1(f)}, {0}};
    f = g_defs(f, d);
    f = g_evals_(f, boot);
    f = g_evals_(f, infix);                  // load infix surface language
    f = g_evals_(f, repl);                   // load editor/parser defs
    f = g_evals_(f, is_repl ? "(repl 0 0)" : rel); }
  enum g_status s = g_code_of(f);
  g_fin(f);
  return s; }
