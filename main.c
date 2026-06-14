#include "love.h"
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


static noreturn lvm(lvm_exit) { exit(getfix(Sp[0])); }
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
  if (n > g_wait_fds_max) __builtin_trap();
  struct pollfd p[g_wait_fds_max];
  for (int i = 0; i < n; i++) p[i].fd = fds[i], p[i].events = POLLIN;
  poll_wait(p, n, ms); }

static struct g *fd_getc(struct g *g) {
  struct g *fc = g_core_of(g);
  struct g_io *i = g->io;
  if (getfix(i->ungetc_buf) != EOF) {
    fc->b = getfix(i->ungetc_buf);
    i->ungetc_buf = putfix(EOF);
    return g; }
  uint8_t b;
  ssize_t n = read(getfix(i->fd), &b, 1);
  if (n <= 0) { i->eof_seen = putfix(true); fc->b = EOF; }
  else fc->b = b;
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
 uint8_t b = c;
 if (g->io->fd == putfix(STDOUT_FILENO)) fputc(b, stdout);
 else write(getfix(g->io->fd), &b, 1);
 return g; }

static struct g *fd_flush(struct g *g) {
 if (g->io->fd == putfix(STDOUT_FILENO)) fflush(stdout);
 return g; }

struct g_port_vt const g_fd_port_vt = { fd_getc, fd_ungetc, fd_eof, fd_putc, fd_flush };

struct g_io g_stdin = { lvm_port_io, putfix(STDIN_FILENO), putfix(EOF), putfix(false) };
struct g_io g_stdout = { lvm_port_io, putfix(STDOUT_FILENO), putfix(EOF), putfix(false) };
struct g_io g_stderr = { lvm_port_io, putfix(STDERR_FILENO), putfix(EOF), putfix(false) };
// Override the weak g.c default with the real POSIX close. Called by the
// finalizer that g_io_alloc registers, so it runs when a heap port becomes
// unreachable. Static stdin/stdout don't go through this path -- they live
// outside the l heap and the GC never visits them.
void g_fd_close(int fd) { close(fd); }

// (open path mode) — open a file with mode "r"/"w"/"a"; returns a heap port
// (closed on GC) or nil on error or misuse. mode is a l string; only the
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

static lvm(lvm_open) {
  if (!g_strp(Sp[0]) || !g_strp(Sp[1])) goto fail;
  struct g_str *pv = (struct g_str*) Sp[0];
  struct g_str *mv = (struct g_str*) Sp[1];
  int fd = call_open(pv, mv);
  if (fd < 0) goto fail;
  Pack(g);
  struct g *r = g_io_alloc(g, fd);
  if (!g_ok(r)) { close(fd); goto fail; }
  g = r;
  Unpack(g);
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
static lvm(lvm_close) {
  // inline "is x a port": heap pointer whose discriminator is lvm_port_io.
  if ((Sp[0] & 1) == 0 && ((union u*) Sp[0])->ap == lvm_port_io) {
    struct g_io *io = (struct g_io*) Sp[0];
    intptr_t fd = getfix(io->fd);
    if (fd >= 0) {
      close(fd);
      io->fd = putfix(-3); } }
  Sp[0] = g_nil;
  Ip += 1;
  return Continue(); }

// --- subprocess (run) + environment (getenv) ---------------------------
// Both are host-only nifs (POSIX fork/exec/wait, getenv), like open/close.
// No malloc: argv is marshalled into the uncommitted l heap gap and the
// child's stdout is captured into a growing l string (the reader's
// str0 + grow + len-fixup pattern). See core/io.c gzread1str / grbufg.

// Local copy of core/io.c's grbufg (static there): grow the string on sp[0]
// to 2*len, copying the old `len` bytes in. str0 is the public allocator.
static struct g *host_grbufg(struct g *g, uintptr_t len) {
 if (g_ok(g = str0(g, 2 * len)))
  memcpy(txt(g->sp[0]), txt(g->sp[1]), len),
  g->sp[1] = g->sp[0], g->sp++;
 return g; }

// Workhorse for (run argv). Called with g Packed; argv is the single arg.
// Pushes EXACTLY ONE net value above argv on every path so the lvm_run
// shell collapses uniformly: success -> [(status . output), argv], failure
// -> [errno-or-(-1) fixnum, argv]. Returns a not-ok g only on OOM.
// &locals (pipes/pid/status) are fine here: this returns normally, it is
// not a VM-dispatch tail-call site (cf. call_open vs lvm_open).
g_noinline static struct g *host_run(struct g *g, g_word argv) {
 // pass 1: validate every element is a string; size the arg-byte blob.
 intptr_t argc = 0;
 uintptr_t total = 0;
 for (g_word p = argv; twop(p); p = B(p)) {
  if (!g_strp(A(p))) return g_push(g, 1, putfix(-1));   // misuse
  argc++, total += len(A(p)) + 1; }                       // +1 for the NUL
 if (!argc) return g_push(g, 1, putfix(-1));            // empty argv

 // Reserve gap for cav (argc+1 pointers, word-aligned) + the byte blob.
 // Written into the uncommitted region at Hp -- invisible to GC, holds no
 // l pointers, consumed before any further allocation. Never bump Hp.
 if (!g_ok(g = g_have(g, (uintptr_t) argc + 1 + b2w(total)))) return g;
 argv = g->sp[0];          // g_have may have GC'd; argv (the only root, at sp[0])
                           // is forwarded there -- the C local is now stale.
 char **cav = (char**) g->hp;                             // at Hp: aligned
 char *blob = (char*) (g->hp + (argc + 1));               // whole words after
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
 if (pipe(op)) return g_push(g, 1, putfix(errno));
 if (pipe(ep)) { int e = errno; close(op[0]); close(op[1]); return g_push(g, 1, putfix(e)); }
 fcntl(ep[1], F_SETFD, FD_CLOEXEC);
 fflush(stdout);
 pid_t pid = fork();
 if (pid < 0) { int e = errno;
  close(op[0]); close(op[1]); close(ep[0]); close(ep[1]);
  return g_push(g, 1, putfix(e)); }
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
  return g_push(g, 1, putfix(childerr)); }

 // drain stdout into a growing l string (bulk reads; stderr inherited).
 uintptr_t n = 0, lim = 1u << 16;
 g = str0(g, lim);                                        // capture -> sp[0]
 while (g_ok(g)) {
  if (n == lim) { g = host_grbufg(g, lim); lim *= 2; continue; }
  r = read(op[0], txt(g->sp[0]) + n, lim - n);
  if (r < 0) { if (errno == EINTR) continue; break; }
  if (!r) break;                                          // EOF
  n += (uintptr_t) r; }
 close(op[0]);
 { int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}          // reap
   if (!g_ok(g)) return g;                                // OOM mid-drain
   if (n) len(g->sp[0]) = n;                              // fix logical length
   else g->sp[0] = EmptyString;                             // empty output -> the singleton
   int status = WIFEXITED(st) ? WEXITSTATUS(st)
              : WIFSIGNALED(st) ? 128 + WTERMSIG(st) : -1;
   if (!g_ok(g = g_have(g, Width(struct g_pair)))) return g;
   struct g_pair *w = ini_two((struct g_pair*) bump(g, Width(struct g_pair)),
                              putfix(status), g->sp[0]);
   g->sp[0] = word(w); }                                  // [(status.output), argv]
 return g; }

static lvm(lvm_run) {
 Pack(g);
 g = host_run(g, Sp[0]);
 if (!g_ok(g)) return ghelp(g);
 Unpack(g);
 Sp[1] = Sp[0];                                           // result over argv
 Sp += 1; Ip += 1;
 return Continue(); }

// Copy the name to a C string and look it up. Factored out (g_noinline) so the
// memcpy(&name,...) escape can't defeat lvm_getenv's tail call (cf. call_open).
g_noinline static char const *host_getenv(struct g_str *nv) {
 char name[4096];
 if (nv->len >= sizeof name) return NULL;
 memcpy(name, nv->bytes, nv->len);
 name[nv->len] = 0;
 return getenv(name); }

// (getenv name) -> string, or nil if unset / misused. nil = absent, not an
// error; the run fixnum-error convention does not apply here.
static lvm(lvm_getenv) {
 char const *v = g_strp(Sp[0]) ? host_getenv((struct g_str*) Sp[0]) : NULL;
 if (!v) { Sp[0] = g_nil; Ip += 1; return Continue(); }
 Pack(g);
 if (!g_ok(g = g_strof(g, v))) return ghelp(g);
 Unpack(g);
 Sp[1] = Sp[0];
 Sp += 1; Ip += 1;
 return Continue(); }

static union u const
 nif_exit[] = {{lvm_exit}, {lvm_ret0}},
 nif_open[] = {{lvm_cur}, {.x = putfix(2)}, {lvm_open}, {lvm_ret0}},
 nif_close[] = {{lvm_close}, {lvm_ret0}},
 nif_run[] = {{lvm_run}, {lvm_ret0}},
 nif_getenv[] = {{lvm_getenv}, {lvm_ret0}};

// --- the boot script ---------------------------------------------------
// Everything the two builds disagree about lives in this ONE conditional
// region: the baked lisp text plus a `boot` entry that main tail-calls after
// the universal setup (argv pins + the host nif defs above).
#ifdef GL_BOOTSTRAP
// love0: the CLI driver is the sed-wrapped raw text (it can't lcat its own arg
// ap). Self-test: the whole test corpus, baked in (sed-wrapped), run
// twice -- once compiled by the C bootstrap compiler (c0), once by the
// self-hosted ev installed from ev.l -- so one love0 invocation exercises both
// compilers (and -Dg_tco=0 makes it the trampoline path). s2cldef installs
// s2cl (string -> charlist); runner drinks the baked corpus (the global
// `tests`) through zevs (repl.l), whose `(ev 'ev r)` indirection late-binds
// to whatever `ev` is now, so the same shell drives the c0 pass and (after
// the egg) the self-hosted pass.
static char const cli[] =
#include "cli0.h"
 ;
static char const tests0[] =
#include "tests0.h"
 ;
static char const
 s2cldef[] = "(: (s2cl s) ((: (g i) (? (< i (tally s)) (cons (peep s i 0) (g (+ 1 i))))) 0))",
 runner[] = "(zevs (sip (s2cl tests)))";   // the stream shell (repl.l) drinks the baked corpus

// With args, run the build tool (lcat / gen_data) through the CLI driver.
// With no args, self-test: eval prelude+repl and run the baked corpus via c0,
// then bootstrap the self-hosted ev (egg) and run the corpus again through it.
static struct g *boot(struct g *g, bool argp) {
  if (argp) return g_evals_(g, cli);
  g = g_strof(g, tests0);                            // the baked corpus, as a string
  struct g_def td[] = {{"tests", g_pop1(g)}};
  g = g_defn(g, td, countof(td));
  g = g_evals_(g,                                    // prelude + repl, compiled by c0
#include "prelude0.h"
#include "repl0.h"
  );
  g = g_evals_(g, s2cldef);
  g = g_evals_(g, runner);                           // pass 1: corpus via ev = the c0 nif
  g = g_evals_(g, "("                                // bootstrap: install the self-hosted ev
#include "egg0.h"
    "'("
#include "prelude0.h"
#include "ev0.h"
    "))");
  return g_evals_(g, runner); }                      // pass 2: corpus via the self-hosted ev

#else
// the full love: raw terminal mode for the interactive REPL (love0 never needs
// it -- a build tool / self-test is non-interactive); the CLI driver is the
// canonicalized lcat header; `rel` is the non-tty stdin runner.
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

static char const cli[] =
#include "cli.h"
 ;
static char const
 rel[] = "(zevs in)";   // non-tty stdin: the stream shell (repl.l) drinks the in port

// NOTE: the always-on native-JIT self-install was REVERTED -- a benchmark showed
// the scalar opfix hook is a net pessimization (a native function called from the
// interpreted loop pays a call-boundary tax -- putfix marshal, the `call` nif, the
// 2R decode -- heavier than interpreting the small arithmetic body). The JIT only
// wins when it OWNS the loop: the explicit array kernels (afold/ajit/amap/areduce,
// jit/array.l) run 35-50x by staying native across every iteration. So opjit stays
// DORMANT (book['opjit]=0) and the kernels are invoked explicitly. See jit/README.md.

static struct g *boot(struct g *g, bool argp) {
  bool replp = !argp && isatty(STDIN_FILENO);
  if (replp) raw_mode();
  g = g_evals_(g, "("
#include "egg.h"
    "'("
#include "prelude.h"
#include "ev.h"
    "))"
#include "repl.h"
  );
  return g_evals_(g, argp ? cli : replp ? "(shell 0)" : rel); }
#endif

int main(int argc, char const **argv) {
  struct g *g = g_ini();
  bool argp = argc > 1;
  // The WHOLE C argv (incl. argv[0]/program name): cli.l drops the head for its own
  // use, while `cmdline` keeps the full list, pinned for user visibility.
  char const **av = argv;
  int ac = argc;
  for (; *av; g = g_strof(g, *av++));
  for (g = g_push(g, 1, g_nil); ac--; g = gxr(g));
  if (g_ok(g)) {
    g_word full_argv = g_pop1(g);                // shared by `argv` and `cmdline`
    struct g_def d[] = {{"exit", (g_word) nif_exit},
                        {"open", (g_word) nif_open},
                        {"close", (g_word) nif_close},
                        {"run", (g_word) nif_run},
                        {"getenv", (g_word) nif_getenv},
                        {"argv", full_argv},
                        {"cmdline", full_argv}, };
    g = g_defn(g, d, countof(d));
    g = boot(g, argp); }
  switch (g_code_of(g)) {
   default: break;
   case g_status_scare:               // the honest face: "# a b" when the scare
    if (!g_scare_face_(g))            // said something; bare (no data) = oom
     fprintf(stderr, "# oom@len=%ld\n", (long) g_core_of(g)->len);
    break; }
  return g_fin(g); }
