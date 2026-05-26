#include "../g/g.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <termios.h>
#include <time.h>
#include <poll.h>
#include <errno.h>

g_noinline uintptr_t g_clock(void) {
  struct timespec ts;
  return clock_gettime(CLOCK_REALTIME, &ts) ? (uintptr_t) -1
       : (uintptr_t) (ts.tv_sec * 1000 + ts.tv_nsec / 1000000); }

// --- host output -----------------------------------------------------
// write(2) directly to STDOUT_FILENO — no FILE* / libc stream buffering.
// _flush is a no-op since every byte hits the fd immediately.
static struct g *_putc(struct g *f, int c, struct g_out*) {
  uint8_t b = c;
  ssize_t r = write(STDOUT_FILENO, &b, 1);
  (void) r;
  return f; }
static struct g *_flush(struct g *f, struct g_out*) { return f; }
static struct g_out _g_stdout = { g_vm_port_out, _putc, _flush, g_putnum(STDOUT_FILENO) };
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

// Shared EINTR-retry skeleton for poll-based wait. ms=0 means infinite.
// Returns only when poll succeeds (data ready / deadline elapsed) or fails
// for a non-EINTR reason.
static void poll_wait(struct pollfd *fds, nfds_t nfds, uintptr_t ms) {
  uintptr_t deadline = ms == 0 ? 0 : g_clock() + ms;
  for (;;) {
    int t = ms == 0 ? -1 :
            ms > (uintptr_t) __INT_MAX__ ? __INT_MAX__ : (int) ms;
    if (poll(fds, nfds, t) >= 0 || errno != EINTR) return;
    if (!deadline) continue;
    uintptr_t now = g_clock();
    if (now >= deadline) return;
    ms = deadline - now; } }

void g_sleep(uintptr_t ms) { poll_wait(NULL, 0, ms); }

bool g_ready(int fd) {
  if (fd < 0) return true;
  struct pollfd p = { .fd = fd, .events = POLLIN };
  return poll(&p, 1, 0) > 0; }

void g_wait_fds(int const *fds, int n, uintptr_t ms) {
  if (n <= 0) { g_sleep(ms); return; }
  if (n > G_WAIT_FDS_MAX) __builtin_trap();
  struct pollfd p[G_WAIT_FDS_MAX];
  for (int i = 0; i < n; i++) p[i].fd = fds[i], p[i].events = POLLIN;
  poll_wait(p, n, ms); }

// --- host input ------------------------------------------------------
// raw_stdin is the byte source at f->in: non-interactively the parser
// reads it directly; interactively the gwen line editor (boot.g) reads
// its keystrokes through it. one byte per getc, delivered in f->b. it
// never allocates the gwen heap, so f stays valid across a getc.
// read(2) directly from i->fd — no FILE* / libc stream buffering. ungetc
// is one byte stashed in i->ungetc_buf; EOF is tracked in i->eof_seen,
// set when read returns 0 and cleared by ungetc.
static struct g *raw_getc(struct g *f, struct g_in *i) {
  struct g *fc = g_core_of(f);
  if (g_getnum(i->ungetc_buf) != EOF) {
    fc->b = g_getnum(i->ungetc_buf);
    i->ungetc_buf = g_putnum(EOF);
    return f; }
  uint8_t b;
  ssize_t n = read(g_getnum(i->fd), &b, 1);
  if (n <= 0) { i->eof_seen = g_putnum(true); fc->b = EOF; }
  else fc->b = b;
  return f; }
static struct g *raw_ungetc(struct g *f, int c, struct g_in *i) {
  i->ungetc_buf = g_putnum(c);
  i->eof_seen = g_putnum(false);
  return g_core_of(f)->b = c, f; }
static struct g *raw_eof(struct g *f, struct g_in *i) {
  return g_core_of(f)->b = (g_getnum(i->ungetc_buf) == EOF) && g_getnum(i->eof_seen), f; }
static struct g_in raw_stdin = { g_vm_port_in, raw_getc, raw_ungetc, raw_eof,
                                  g_putnum(STDIN_FILENO), g_putnum(EOF), g_putnum(false) };
struct g_in *g_stdin = &raw_stdin;

static char const
boot[] =
#include "boot.h"
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
  if (is_repl) raw_mode();                 // interactive: raw tty; the line
                                           // editor is now pure gwen (boot.g)
  for (; *argv; f = g_strof(f, *argv++));
  for (f = g_push(f, 1, g_nil); argc--; f = gxr(f));
  if (g_ok(f)) {
    struct g_def d[] = {{"argv", g_pop1(f)}, {0}};
    f = g_defs(f, d);
    f = g_evals_(f, boot);
    f = g_evals_(f, repl);                   // load editor/parser defs
    f = g_evals_(f, is_repl ? "(repl 0 0)" : rel); }
  enum g_status s = g_code_of(f);
  g_fin(f);
  return s; }
