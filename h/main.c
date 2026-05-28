#include "../g/g.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <time.h>
#include <poll.h>
#include <errno.h>
#include <stdnoreturn.h>

g_noinline uintptr_t g_clock(void) {
  struct timespec ts;
  return clock_gettime(CLOCK_REALTIME, &ts) ? (uintptr_t) -1
       : (uintptr_t) (ts.tv_sec * 1000 + ts.tv_nsec / 1000000); }

static struct g *_putc(struct g *f, int c) {
  uint8_t b = c;
  ssize_t r = write(g_getnum(f->io->fd), &b, 1);
  (void) r;
  return f; }
static struct g *_flush(struct g *f) { return f; }
struct g_io g_stdout = { g_vm_port_io, g_putnum(STDOUT_FILENO), g_putnum(EOF), g_putnum(false) };

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

static noreturn g_vm(g_vm_exit) { exit(g_getnum(Sp[0])); }
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

static struct g *fd_getc(struct g *f) {
  struct g *fc = g_core_of(f);
  struct g_io *i = f->io;
  if (g_getnum(i->ungetc_buf) != EOF) {
    fc->b = g_getnum(i->ungetc_buf);
    i->ungetc_buf = g_putnum(EOF);
    return f; }
  uint8_t b;
  ssize_t n = read(g_getnum(i->fd), &b, 1);
  if (n <= 0) { i->eof_seen = g_putnum(true); fc->b = EOF; }
  else fc->b = b;
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
struct g_io g_stdin = { g_vm_port_io, g_putnum(STDIN_FILENO), g_putnum(EOF), g_putnum(false) };

struct g_port_vt const g_fd_port_vt = { fd_getc, fd_ungetc, fd_eof, _putc, _flush };

// Override the weak g.c default with the real POSIX close. Called by the
// finalizer that g_io_alloc registers, so it runs when a heap port becomes
// unreachable. Static stdin/stdout don't go through this path -- they live
// outside the gwen heap and the GC never visits them.
void g_fd_close(int fd) { close(fd); }

// (open path mode) — open a file with mode "r"/"w"/"a"; returns a heap port
// (closed on GC) or nil on error or misuse. mode is a gwen string; only the
// first byte is consulted.
//   r = read-only
//   w = write-only, truncate-or-create
//   a = write-only, append-or-create
// Errors (path too long, unknown mode, open(2) failure) all return nil.
static g_vm(g_vm_open) {
  if (!g_strp(Sp[0]) || !g_strp(Sp[1])) goto fail;
  struct g_vec *pv = (struct g_vec*) Sp[0];
  struct g_vec *mv = (struct g_vec*) Sp[1];
  uintptr_t plen = pv->shape[0];
  char path[4096];
  if (plen >= sizeof path || mv->shape[0] == 0) goto fail;
  memcpy(path, (char*)(pv->shape + 1), plen);
  path[plen] = 0;
  int flags;
  switch (((char*)(mv->shape + 1))[0]) {
    case 'r': flags = O_RDONLY; break;
    case 'w': flags = O_WRONLY | O_CREAT | O_TRUNC; break;
    case 'a': flags = O_WRONLY | O_CREAT | O_APPEND; break;
    default: goto fail; }
  int fd = open(path, flags, 0644);
  if (fd < 0) goto fail;
  Pack(f);
  struct g *r = g_io_alloc(f, fd);
  if (!g_ok(r)) { close(fd); return r; }
  f = r;
  Unpack(f);
  // stack: [port, path, mode, ...] -> [port, ...]
  Sp[2] = Sp[0];
  Sp += 2;
  Ip += 1;
  return Continue();
 fail:
  Sp[1] = g_nil;
  Sp += 1;
  Ip += 1;
  return Continue(); }

// (close p) — close a port, mark its fd as the closed-sentinel (-3) so
// subsequent reads/writes/flush go to the noop slot, and the finalizer
// (which checks fd >= 0) skips. Returns nil. No-op on misuse, matching
// the existing fputc/etc. convention.
static g_vm(g_vm_close) {
  // inline "is x a port": heap pointer whose discriminator is g_vm_port_io.
  if ((Sp[0] & 1) == 0 && ((union u*) Sp[0])->ap == g_vm_port_io) {
    struct g_io *io = (struct g_io*) Sp[0];
    intptr_t fd = g_getnum(io->fd);
    if (fd >= 0) {
      close(fd);
      io->fd = g_putnum(-3); } }
  Sp[0] = g_nil;
  Ip += 1;
  return Continue(); }

static union u const
 bif_exit[] = {{g_vm_exit}, {g_vm_ret0}},
 bif_open[] = {{g_vm_cur}, {.x = g_putnum(2)}, {g_vm_open}, {g_vm_ret0}},
 bif_close[] = {{g_vm_close}, {g_vm_ret0}};

static char const
boot[] =
#include "boot.h"
#include "repl.h"
,
 rel[] = "(:(g e)(: r(read e)(?(= e r)0(: _(ev'ev r)(g e))))(g(sym 0)))"
  ;
// --- main: load the prelude and run the REPL script ------------------
int main(int argc, char const **argv) {
  struct g *f = g_ini();
  bool replp = isatty(STDIN_FILENO);
  if (replp) raw_mode();
  for (; *argv; f = g_strof(f, *argv++));
  for (f = g_push(f, 1, g_nil); argc--; f = gxr(f));
  if (g_ok(f)) {
    struct g_def d[] = {{"exit", (g_word) bif_exit},
                        {"open", (g_word) bif_open},
                        {"close", (g_word) bif_close},
                        {"argv", g_pop1(f)},
                        {0}};
    f = g_evals(g_evals_(g_defs(f, d), boot), replp ? "(repl 0 0)" : rel); }
  return g_fin(f); }
