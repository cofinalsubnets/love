#include "gwen.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <termios.h>
#include <time.h>
#include <poll.h>
#include <errno.h>
#include <math.h>
#include <stdnoreturn.h>
#include <sys/wait.h>

g_noinline uintptr_t g_clock(void) {
  struct timespec ts;
  return clock_gettime(CLOCK_REALTIME, &ts) ? (uintptr_t) -1
       : (uintptr_t) (ts.tv_sec * 1000 + ts.tv_nsec / 1000000); }


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

static g_noinline int poll_wrap(int fd) {
  struct pollfd p = { .fd = fd, .events = POLLIN };
  return poll(&p, 1, 0); }

bool g_ready(int fd) { return fd < 0 || poll_wrap(fd) > 0; }

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

static struct g *fd_putc(struct g *f, int c) {
 uint8_t b = c;
 if (f->io->fd == g_putnum(STDOUT_FILENO)) fputc(b, stdout);
 else write(g_getnum(f->io->fd), &b, 1);
 return f; }

static struct g *fd_flush(struct g *f) {
 if (f->io->fd == g_putnum(STDOUT_FILENO)) fflush(stdout);
 return f; }

struct g_port_vt const g_fd_port_vt = { fd_getc, fd_ungetc, fd_eof, fd_putc, fd_flush };

struct g_io g_stdin = { g_vm_port_io, g_putnum(STDIN_FILENO), g_putnum(EOF), g_putnum(false) };
struct g_io g_stdout = { g_vm_port_io, g_putnum(STDOUT_FILENO), g_putnum(EOF), g_putnum(false) };
struct g_io g_stderr = { g_vm_port_io, g_putnum(STDERR_FILENO), g_putnum(EOF), g_putnum(false) };
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

static g_noinline int call_open(struct g_str *pv, struct g_str *mv) {
  uintptr_t plen = pv->len;
  char path[4096];
  if (plen >= sizeof path || mv->len == 0) return -1;
  memcpy(path, pv->bytes, plen);
  path[plen] = 0;
  int flags;
  switch (mv->bytes[0]) {
    case 'r': flags = O_RDONLY; break;
    case 'w': flags = O_WRONLY | O_CREAT | O_TRUNC; break;
    case 'a': flags = O_WRONLY | O_CREAT | O_APPEND; break;
    default: return -1; }
  return open(path, flags, 0644); }

static g_vm(g_vm_open) {
  if (!g_strp(Sp[0]) || !g_strp(Sp[1])) goto fail;
  struct g_str *pv = (struct g_str*) Sp[0];
  struct g_str *mv = (struct g_str*) Sp[1];
  int fd = call_open(pv, mv);
  if (fd < 0) goto fail;
  Pack(f);
  struct g *r = g_io_alloc(f, fd);
  if (!g_ok(r)) { close(fd); goto fail; }
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

// --- subprocess (run) + environment (getenv) ---------------------------
// Both are host-only bifs (POSIX fork/exec/wait, getenv), like open/close.
// No malloc: argv is marshalled into the uncommitted gwen heap gap and the
// child's stdout is captured into a growing gwen string (the reader's
// str0 + grow + len-fixup pattern). See core/io.c gzread1str / grbufg.

// Local copy of core/io.c's grbufg (static there): grow the string on sp[0]
// to 2*len, copying the old `len` bytes in. str0 is the public allocator.
static struct g *host_grbufg(struct g *f, uintptr_t len) {
 if (g_ok(f = str0(f, 2 * len)))
  memcpy(txt(f->sp[0]), txt(f->sp[1]), len),
  f->sp[1] = f->sp[0], f->sp++;
 return f; }

// Workhorse for (run argv). Called with f Packed; argv is the single arg.
// Pushes EXACTLY ONE net value above argv on every path so the g_vm_run
// shell collapses uniformly: success -> [(status . output), argv], failure
// -> [errno-or-(-1) fixnum, argv]. Returns a not-ok f only on OOM.
// &locals (pipes/pid/status) are fine here: this returns normally, it is
// not a VM-dispatch tail-call site (cf. call_open vs g_vm_open).
g_noinline static struct g *host_run(struct g *f, g_word argv) {
 // pass 1: validate every element is a string; size the arg-byte blob.
 intptr_t argc = 0;
 uintptr_t total = 0;
 for (g_word p = argv; twop(p); p = B(p)) {
  if (!g_strp(A(p))) return g_push(f, 1, g_putnum(-1));   // misuse
  argc++, total += len(A(p)) + 1; }                       // +1 for the NUL
 if (!argc) return g_push(f, 1, g_putnum(-1));            // empty argv

 // Reserve gap for cav (argc+1 pointers, word-aligned) + the byte blob.
 // Written into the uncommitted region at Hp -- invisible to GC, holds no
 // gwen pointers, consumed before any further allocation. Never bump Hp.
 if (!g_ok(f = g_have(f, (uintptr_t) argc + 1 + b2w(total)))) return f;
 argv = f->sp[0];          // g_have may have GC'd; argv (the only root, at sp[0])
                           // is forwarded there -- the C local is now stale.
 char **cav = (char**) f->hp;                             // at Hp: aligned
 char *blob = (char*) (f->hp + (argc + 1));               // whole words after
 { uintptr_t off = 0; intptr_t i = 0;
   for (g_word p = argv; twop(p); p = B(p), i++) {         // re-walk post-g_have
    struct g_str *s = str(A(p));
    memcpy(blob + off, txt(s), len(s));
    blob[off + len(s)] = 0;
    cav[i] = blob + off;
    off += len(s) + 1; }
   cav[argc] = NULL; }

 // spawn: stdout pipe + a close-on-exec error pipe. On a successful exec the
 // kernel closes ep[1] -> parent reads EOF; on failure the child writes errno
 // -> parent distinguishes "couldn't spawn" from "ran and exited 127".
 int op[2], ep[2];
 if (pipe(op)) return g_push(f, 1, g_putnum(errno));
 if (pipe(ep)) { int e = errno; close(op[0]); close(op[1]); return g_push(f, 1, g_putnum(e)); }
 fcntl(ep[1], F_SETFD, FD_CLOEXEC);
 fflush(stdout);
 pid_t pid = fork();
 if (pid < 0) { int e = errno;
  close(op[0]); close(op[1]); close(ep[0]); close(ep[1]);
  return g_push(f, 1, g_putnum(e)); }
 if (!pid) {                                              // child
  dup2(op[1], STDOUT_FILENO);
  close(op[0]); close(op[1]); close(ep[0]);
  execvp(cav[0], cav);
  int e = errno; ssize_t w = write(ep[1], &e, sizeof e); (void) w;
  _exit(127); }
 close(op[1]); close(ep[1]);                              // parent
 int childerr = 0; ssize_t r;
 do r = read(ep[0], &childerr, sizeof childerr); while (r < 0 && errno == EINTR);
 close(ep[0]);
 if (childerr) {                                          // exec failed
  close(op[0]);
  int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
  return g_push(f, 1, g_putnum(childerr)); }

 // drain stdout into a growing gwen string (bulk reads; stderr inherited).
 uintptr_t n = 0, lim = 1u << 16;
 f = str0(f, lim);                                        // capture -> sp[0]
 while (g_ok(f)) {
  if (n == lim) { f = host_grbufg(f, lim); lim *= 2; continue; }
  r = read(op[0], txt(f->sp[0]) + n, lim - n);
  if (r < 0) { if (errno == EINTR) continue; break; }
  if (!r) break;                                          // EOF
  n += (uintptr_t) r; }
 close(op[0]);
 { int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}          // reap
   if (!g_ok(f)) return f;                                // OOM mid-drain
   len(f->sp[0]) = n;                                     // fix logical length
   int status = WIFEXITED(st) ? WEXITSTATUS(st)
              : WIFSIGNALED(st) ? 128 + WTERMSIG(st) : -1;
   if (!g_ok(f = g_have(f, Width(struct g_pair)))) return f;
   struct g_pair *w = ini_two((struct g_pair*) bump(f, Width(struct g_pair)),
                              g_putnum(status), f->sp[0]);
   f->sp[0] = word(w); }                                  // [(status.output), argv]
 return f; }

static g_vm(g_vm_run) {
 Pack(f);
 f = host_run(f, Sp[0]);
 if (!g_ok(f)) return gtrap(f);
 Unpack(f);
 Sp[1] = Sp[0];                                           // result over argv
 Sp += 1; Ip += 1;
 return Continue(); }

// Copy the name to a C string and look it up. Factored out (g_noinline) so the
// memcpy(&name,...) escape can't defeat g_vm_getenv's tail call (cf. call_open).
g_noinline static char const *host_getenv(struct g_str *nv) {
 char name[4096];
 if (nv->len >= sizeof name) return NULL;
 memcpy(name, nv->bytes, nv->len);
 name[nv->len] = 0;
 return getenv(name); }

// (getenv name) -> string, or nil if unset / misused. nil = absent, not an
// error; the run fixnum-error convention does not apply here.
static g_vm(g_vm_getenv) {
 char const *v = g_strp(Sp[0]) ? host_getenv((struct g_str*) Sp[0]) : NULL;
 if (!v) { Sp[0] = g_nil; Ip += 1; return Continue(); }
 Pack(f);
 if (!g_ok(f = g_strof(f, v))) return gtrap(f);
 Unpack(f);
 Sp[1] = Sp[0];
 Sp += 1; Ip += 1;
 return Continue(); }

static union u const
 bif_exit[] = {{g_vm_exit}, {g_vm_ret0}},
 bif_open[] = {{g_vm_cur}, {.x = g_putnum(2)}, {g_vm_open}, {g_vm_ret0}},
 bif_close[] = {{g_vm_close}, {g_vm_ret0}},
 bif_run[] = {{g_vm_run}, {g_vm_ret0}},
 bif_getenv[] = {{g_vm_getenv}, {g_vm_ret0}};

static char const
 rel[] = "(:(g e)(: r(read e)(?(= e r)0(: _(ev'ev r)(g e))))(g(gensym 0)))",
 cli[] =
  "(: (load1 p)"
  "   (: q (open p \"r\")"
  "      (? q ((: (g e q) (: r (fread q e) (? (= e r) 0 (: _ (ev 'ev r) (g e q))))) (gensym 0) q)"
  "           (: _ (fputs err (scat \"gl: cannot open \" p)) (exit 1)))))"
  "(: (strip-l a)"
  "   (? (& (twop a) (= (car a) \"-l\"))"
  "      (: _ (load1 (car (cdr a))) (strip-l (cdr (cdr a))))"
  "      a))"
  "(: argv (strip-l argv))"
  "(? (twop argv) (load1 (car argv))"
  "   ((: (g e) (: r (fread in e) (? (= e r) 0 (: _ (ev 'ev r) (g e))))) (gensym 0)))"
  ;

int main(int argc, char const **argv) {
  struct g *f = g_ini();
  bool argp = argc > 1;
  bool replp = !argp && isatty(STDIN_FILENO);
  if (replp) raw_mode();
  char const **av = argp ? argv + 1 : argv;
  int ac = argp ? argc - 1 : argc;
  for (; *av; f = g_strof(f, *av++));
  for (f = g_push(f, 1, g_nil); ac--; f = gxr(f));
  if (g_ok(f)) {
    struct g_def d[] = {{"exit", (g_word) bif_exit},
                        {"open", (g_word) bif_open},
                        {"close", (g_word) bif_close},
                        {"run", (g_word) bif_run},
                        {"getenv", (g_word) bif_getenv},
                        {"argv", g_pop1(f)}, };
    f = g_defn(f, d, LEN(d));
#ifndef GL_BOOTSTRAP
    f = g_evals_(f, G_EGG_PRE
#include "prelude.h"
    " "
#include "ev.h"
    G_EGG_POST
#include "repl.h"
    );
#endif
    f = g_evals_(f, argp ? cli : replp ? "(repl 0 0)" : rel); }
  switch (g_code_of(f)) {
   default: break;
   case g_status_oom: fprintf(stderr, "# oom@len=%ld\n", (long) g_core_of(f)->len); break; }
  return g_fin(f); }
