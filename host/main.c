#include "ai.h"
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

ai_noinline uintptr_t ai_clock(void) {
  struct timespec ts;
  return clock_gettime(CLOCK_REALTIME, &ts) ? (uintptr_t) -1
       : (uintptr_t) (ts.tv_sec * 1000 + ts.tv_nsec / 1000000); }


static noreturn lvm(lvm_exit) { exit(getcharm(Sp[0])); }
// Shared EINTR-retry skeleton for poll-based wait. ms=0 means infinite.
// Returns only when poll succeeds (data ready / deadline elapsed) or fails
// for a non-EINTR reason.
static void poll_wait(struct pollfd *fds, nfds_t nfds, uintptr_t ms) {
  uintptr_t deadline = ms == 0 ? 0 : ai_clock() + ms;
  for (;;) {
    int t = ms == 0 ? -1 :
            ms > (uintptr_t) __INT_MAX__ ? __INT_MAX__ : (int) ms;
    if (poll(fds, nfds, t) >= 0 || errno != EINTR) return;
    if (!deadline) continue;
    uintptr_t now = ai_clock();
    if (now >= deadline) return;
    ms = deadline - now; } }

void ai_sleep(uintptr_t ms) { poll_wait(NULL, 0, ms); }

static ai_noinline int poll_wrap(int fd) {
  struct pollfd p = { .fd = fd, .events = POLLIN };
  return poll(&p, 1, 0); }

bool ai_ready(int fd) { return fd < 0 || poll_wrap(fd) > 0; }

void ai_wait_fds(int const *fds, int n, uintptr_t ms) {
  if (n <= 0) { ai_sleep(ms); return; }
  if (n > ai_wait_fds_max) __builtin_trap();
  struct pollfd p[ai_wait_fds_max];
  for (int i = 0; i < n; i++) p[i].fd = fds[i], p[i].events = POLLIN;
  poll_wait(p, n, ms); }

static struct ai *fd_getc(struct ai *g) {
  struct ai *fc = ai_core_of(g);
  struct ai_io *i = g->io;
  if (getcharm(i->ungetc_buf) != EOF) {
    fc->b = getcharm(i->ungetc_buf);
    i->ungetc_buf = putcharm(EOF);
    return g; }
  uint8_t b;
  ssize_t n = read(getcharm(i->fd), &b, 1);
  if (n <= 0) { i->eof_seen = putcharm(true); fc->b = EOF; }
  else fc->b = b;
  return g; }

static struct ai *fd_ungetc(struct ai *g, int c) {
 struct ai *fc = ai_core_of(g);
 struct ai_io *i = fc->io;
 i->ungetc_buf = putcharm(c);
 i->eof_seen = putcharm(false);
 return fc->b = c, g; }

static struct ai *fd_eof(struct ai *g) {
  struct ai *fc = ai_core_of(g);
  struct ai_io *i = fc->io;
  return fc->b = (getcharm(i->ungetc_buf) == EOF) && getcharm(i->eof_seen), g; }

static struct ai *fd_putc(struct ai *g, int c) {
 uint8_t b = c;
 if (g->io->fd == putcharm(STDOUT_FILENO)) fputc(b, stdout);
 else write(getcharm(g->io->fd), &b, 1);
 return g; }

static struct ai *fd_flush(struct ai *g) {
 if (g->io->fd == putcharm(STDOUT_FILENO)) fflush(stdout);
 return g; }

// the bulk lanes (contract in ai.h). writen drains stdio first when the fd is
// stdout -- per-byte puts ride stdio there, and the direct write(2) must land
// AFTER them or the stream interleaves. readn is one nonblocking gulp: the
// O_NONBLOCK toggle is per-call because fd flags ride the open file description,
// which a pty child shares.
static intptr_t fd_writen(struct ai *g, unsigned char const *src, uintptr_t n) {
 intptr_t fd = getcharm(g->io->fd);
 if (fd == STDOUT_FILENO) fflush(stdout);
 uintptr_t i = 0;
 while (i < n) {
  ssize_t k = write((int) fd, src + i, n - i);
  if (k < 0) { if (errno == EINTR) continue; break; }
  i += (uintptr_t) k; }
 return (intptr_t) i; }
static intptr_t fd_readn(struct ai *g, unsigned char *dst, uintptr_t n) {
 intptr_t fd = getcharm(g->io->fd);
 int fl = fcntl((int) fd, F_GETFL);
 fcntl((int) fd, F_SETFL, fl | O_NONBLOCK);
 ssize_t k = read((int) fd, dst, n);
 fcntl((int) fd, F_SETFL, fl);
 return k > 0 ? (intptr_t) k
      : k == 0 ? -1
      : (errno == EAGAIN || errno == EWOULDBLOCK) ? 0 : -1; }

struct ai_port_vt const ai_fd_port_vt =
 { fd_getc, fd_ungetc, fd_eof, fd_putc, fd_flush, fd_writen, fd_readn };

struct ai_io ai_stdin = { lvm_port_io, putcharm(STDIN_FILENO), putcharm(EOF), putcharm(false) };
struct ai_io ai_stdout = { lvm_port_io, putcharm(STDOUT_FILENO), putcharm(EOF), putcharm(false) };
struct ai_io ai_stderr = { lvm_port_io, putcharm(STDERR_FILENO), putcharm(EOF), putcharm(false) };
// Override the weak g.c default with the real POSIX close. Called by the
// finalizer that ai_io_alloc registers, so it runs when a heap port becomes
// unreachable. Static stdin/stdout don't go through this path -- they live
// outside the l heap and the GC never visits them.
void ai_fd_close(int fd) { close(fd); }
// the GC-context drain (a collected port's unflushed write run): raw write(2),
// no g machinery -- safe inside run_finalizers.
void ai_fd_drain(int fd, void const *p, uintptr_t n) {
 unsigned char const *src = p;
 uintptr_t i = 0;
 while (i < n) {
  ssize_t k = write(fd, src + i, n - i);
  if (k < 0) { if (errno == EINTR) continue; break; }
  i += (uintptr_t) k; } }

// (open path mode) — open a file with mode "r"/"w"/"a"; returns a heap port
// (closed on GC) or nil on error or misuse. mode is a l string; only the
// first byte is consulted.
//   r = read-only
//   w = write-only, truncate-or-create
//   a = write-only, append-or-create
// Errors (path too long, unknown mode, open(2) failure) all return nil.

static ai_noinline int call_open(struct ai_str *pv, struct ai_str *mv) {
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
  if (!ai_strp(Sp[0]) || !ai_strp(Sp[1])) goto fail;
  struct ai_str *pv = (struct ai_str*) Sp[0];
  struct ai_str *mv = (struct ai_str*) Sp[1];
  int fd = call_open(pv, mv);
  if (fd < 0) goto fail;
  Pack(g);
  struct ai *r = ai_io_alloc(g, fd);
  if (!ai_ok(r)) { close(fd); goto fail; }
  g = r;
  Unpack(g);
  // stack: [port, path, mode, ...] -> [port, ...]
  Sp[2] = Sp[0];
  Sp += 2;
  Ip += 1;
  return Continue();
 fail:
  Sp[1] = ZeroPoint;
  Sp += 1;
  Ip += 1;
  return Continue(); }

// (close p) — close a port, mark its fd as the closed-sentinel (-3) so
// subsequent reads/writes/flush go to the noop slot, and the finalizer
// (which checks fd >= 0) skips. Returns (). No-op on misuse, matching
// the existing fputc/etc. convention.
static lvm(lvm_close) {
  // inline "is x a port": heap pointer whose discriminator is lvm_port_io.
  if ((Sp[0] & 1) == 0 && ((union u*) Sp[0])->ap == lvm_port_io) {
    struct ai_io *io = (struct ai_io*) Sp[0];
    intptr_t fd = getcharm(io->fd);
    if (fd >= 0) {
      g->io = io;
      Pack(g);
      g = ai_io_wflush(g, io);   // buffered bytes land before the fd dies
      Unpack(g);
      close(fd);
      io->fd = putcharm(-3); } }
  Sp[0] = ZeroPoint;
  Ip += 1;
  return Continue(); }

// --- subprocess (run) + environment (getenv) ---------------------------
// Both are host-only nifs (POSIX fork/exec/wait, getenv), like open/close.
// No malloc: argv is marshalled into the uncommitted l heap gap and the
// child's stdout is captured into a growing l string (the reader's
// str0 + grow + len-fixup pattern). See core/io.c ioread1str / grbufg.

// Local copy of core/io.c's grbufg (static there): grow the string on sp[0]
// to 2*len, copying the old `len` bytes in. str0 is the public allocator.
static struct ai *host_grbufg(struct ai *g, uintptr_t len) {
 if (ai_ok(g = str0(g, 2 * len)))
  memcpy(txt(g->sp[0]), txt(g->sp[1]), len),
  g->sp[1] = g->sp[0], g->sp++;
 return g; }

// Workhorse for (run argv). Called with g Packed; argv is the single arg.
// Pushes EXACTLY ONE net value above argv on every path so the lvm_run
// shell collapses uniformly: success -> [(status . output), argv], failure
// -> [errno-or-(-1) fixnum, argv]. Returns a not-ok g only on OOM.
// &locals (pipes/pid/status) are fine here: this returns normally, it is
// not a VM-dispatch tail-call site (cf. call_open vs lvm_open).
ai_noinline static struct ai *host_run(struct ai *g, ai_word argv) {
 // pass 1: validate every element is a string; size the arg-byte blob.
 intptr_t argc = 0;
 uintptr_t total = 0;
 for (ai_word p = argv; chainp(p); p = B(p)) {
  if (!ai_strp(A(p))) return ai_push(g, 1, putcharm(-1));   // misuse
  argc++, total += len(A(p)) + 1; }                       // +1 for the NUL
 if (!argc) return ai_push(g, 1, putcharm(-1));            // empty argv

 // Reserve gap for cav (argc+1 pointers, word-aligned) + the byte blob.
 // Written into the uncommitted region at Hp -- invisible to GC, holds no
 // l pointers, consumed before any further allocation. Never bump Hp.
 if (!ai_ok(g = ai_have(g, (uintptr_t) argc + 1 + b2w(total)))) return g;
 argv = g->sp[0];          // ai_have may have GC'd; argv (the only root, at sp[0])
                           // is forwarded there -- the C local is now stale.
 char **cav = (char**) g->hp;                             // at Hp: aligned
 char *blob = (char*) (g->hp + (argc + 1));               // whole words after
 { uintptr_t off = 0; intptr_t i = 0;
   for (ai_word p = argv; chainp(p); p = B(p), i++) {         // re-walk post-ai_have
    struct ai_str *s = str(A(p));
    memcpy(blob + off, txt(s), len(s));
    blob[off + len(s)] = 0;
    cav[i] = blob + off;
    off += len(s) + 1; }
   cav[argc] = NULL; }

 // spawn: stdout pipe + a close-on-exec error pipe. On a successful exec the
 // kernel closes ep[1] -> parent reads EOF; on failure the child writes errno
 // -> parent distinguishes "couldn't spawn" from "ran and exited 127".
 int op[2], ep[2];
 if (pipe(op)) return ai_push(g, 1, putcharm(errno));
 if (pipe(ep)) { int e = errno; close(op[0]); close(op[1]); return ai_push(g, 1, putcharm(e)); }
 fcntl(ep[1], F_SETFD, FD_CLOEXEC);
 fflush(stdout);
 pid_t pid = fork();
 if (pid < 0) { int e = errno;
  close(op[0]); close(op[1]); close(ep[0]); close(ep[1]);
  return ai_push(g, 1, putcharm(e)); }
 if (!pid) {                                              // child
  dup2(op[1], STDOUT_FILENO);
  // DETACH stdin from the controlling terminal: this is a CAPTURE spawn (we want the child's
  // output, never interactive input), so give it /dev/null. Otherwise a child that touches the
  // tty -- e.g. qemu `-serial stdio` doing tcsetattr -- gets SIGTTOU/SIGTTIN as a background
  // process and STOPS, producing no output (the `make test_kernel` hang under an interactive
  // shell; invisible when run with no controlling tty). stdout is already the pipe, also non-tty.
  int nul = open("/dev/null", O_RDONLY);
  if (nul >= 0) { dup2(nul, STDIN_FILENO); if (nul > 2) close(nul); }
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
  return ai_push(g, 1, putcharm(childerr)); }

 // drain stdout into a growing l string (bulk reads; stderr inherited).
 uintptr_t n = 0, lim = 1u << 16;
 g = str0(g, lim);                                        // capture -> sp[0]
 while (ai_ok(g)) {
  if (n == lim) { g = host_grbufg(g, lim); lim *= 2; continue; }
  r = read(op[0], txt(g->sp[0]) + n, lim - n);
  if (r < 0) { if (errno == EINTR) continue; break; }
  if (!r) break;                                          // EOF
  n += (uintptr_t) r; }
 close(op[0]);
 { int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}          // reap
   if (!ai_ok(g)) return g;                                // OOM mid-drain
   if (n) len(g->sp[0]) = n;                              // fix logical length
   else g->sp[0] = EmptyString;                             // empty output -> the singleton
   int status = WIFEXITED(st) ? WEXITSTATUS(st)
              : WIFSIGNALED(st) ? 128 + WTERMSIG(st) : -1;
   if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
   struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                              putcharm(status), g->sp[0]);
   g->sp[0] = word(w); }                                  // [(status.output), argv]
 return g; }

static lvm(lvm_run) {
 Pack(g);
 g = host_run(g, Sp[0]);
 if (!ai_ok(g)) return ghelp(g);
 Unpack(g);
 Sp[1] = Sp[0];                                           // result over argv
 Sp += 1; Ip += 1;
 return Continue(); }

// (exec argv) -> REPLACE this process with argv[0], inheriting stdio (the real
// terminal). Unlike (run argv) -- which forks, pipes the child's stdout into a
// captured string, and waits -- exec hands the tty straight to the child, so an
// INTERACTIVE program drives the terminal. On success it never returns; on a bad
// argv or a failed exec it returns an errno (or -1) fixnum, exactly like run's
// spawn-failure path. cook execs its terminal recipe steps this way (the repl,
// gdb, the qemu run targets). Marshals argv into cav like host_run, then execvp
// in place -- no allocation between the build and the exec, so cav stays valid.
ai_noinline static struct ai *host_exec(struct ai *g, ai_word argv) {
 intptr_t argc = 0;
 uintptr_t total = 0;
 for (ai_word p = argv; chainp(p); p = B(p)) {
  if (!ai_strp(A(p))) return ai_push(g, 1, putcharm(-1));   // misuse
  argc++, total += len(A(p)) + 1; }
 if (!argc) return ai_push(g, 1, putcharm(-1));            // empty argv
 if (!ai_ok(g = ai_have(g, (uintptr_t) argc + 1 + b2w(total)))) return g;
 argv = g->sp[0];                                          // re-root post-ai_have
 char **cav = (char**) g->hp;
 char *blob = (char*) (g->hp + (argc + 1));
 { uintptr_t off = 0; intptr_t i = 0;
   for (ai_word p = argv; chainp(p); p = B(p), i++) {
    struct ai_str *s = str(A(p));
    memcpy(blob + off, txt(s), len(s));
    blob[off + len(s)] = 0;
    cav[i] = blob + off;
    off += len(s) + 1; }
   cav[argc] = NULL; }
 fflush(stdout); fflush(stderr);
 execvp(cav[0], cav);
 return ai_push(g, 1, putcharm(errno)); }                  // exec failed -> errno

static lvm(lvm_exec) {
 Pack(g);
 g = host_exec(g, Sp[0]);                                  // returns only on failure
 if (!ai_ok(g)) return ghelp(g);
 Unpack(g);
 Sp[1] = Sp[0];                                            // errno fixnum over argv
 Sp += 1; Ip += 1;
 return Continue(); }

// Copy the name to a C string and look it up. Factored out (ai_noinline) so the
// memcpy(&name,...) escape can't defeat lvm_getenv's tail call (cf. call_open).
ai_noinline static char const *host_getenv(struct ai_str *nv) {
 char name[4096];
 if (nv->len >= sizeof name) return NULL;
 memcpy(name, nv->bytes, nv->len);
 name[nv->len] = 0;
 return getenv(name); }

// (getenv name) -> string, or nil if unset / misused. nil = absent, not an
// error; the run fixnum-error convention does not apply here.
static lvm(lvm_getenv) {
 char const *v = ai_strp(Sp[0]) ? host_getenv((struct ai_str*) Sp[0]) : NULL;
 if (!v) { Sp[0] = ZeroPoint; Ip += 1; return Continue(); }
 Pack(g);
 if (!ai_ok(g = ai_strof(g, v))) return ghelp(g);
 Unpack(g);
 Sp[1] = Sp[0];
 Sp += 1; Ip += 1;
 return Continue(); }

// (getpid x) -> the running process id (x ignored). The host-nif worked example,
// merged here from the former host/host.c. NOTE: unlike the host/*.c nifs, main.c
// is linked into love0 too, so getpid is present in the bootstrap as well -- not a
// pure host-glob nif. net.c (ain) / pty.c (bao) are the live not-in-love0 ones.
static lvm(lvm_getpid) { return Sp[0] = putcharm(getpid()), Ip++, Continue(); }

// --- PARTIAL-GLAZE PROTOTYPE (flag-gated; see love/glaze/emit.l cgir bridge) -----------
// pg_dyad: a stable-address, allocation-free fixnum dyadic op, called DIRECTLY from
// emitted native code (SysV: rdi=op, rsi=a, rdx=b; untagged machine ints in and out).
// It stands in for "the VM op's C body" that partial glazing splices in when the glaze
// grammar has no recognizer for an op. op: 0=shl 1=shr(arith) 2=min 3=max. No g/heap
// access, so the bridge needs no GC Pack/reload -- only the caller-saved register spill.
// The address is a link-time constant (never GC-moved), handed to the emitter by pgaddr.
ai_noinline intptr_t ai_pg_dyad(intptr_t op, intptr_t a, intptr_t b) {
 switch (op) {
  case 0:  return a << b;
  case 1:  return a >> b;
  case 2:  return a < b ? a : b;
  default: return a > b ? a : b; } }
// (pgaddr x) -> the address of ai_pg_dyad as a fixnum (x ignored). The emitter reads it
// once and embeds it as the callr target. Fixnum-safe: code addresses are < 2^62.
static lvm(lvm_pgaddr) { return Sp[0] = putcharm((intptr_t) ai_pg_dyad), Ip++, Continue(); }
static union u const nif_pgaddr[] = {{lvm_pgaddr}, {lvm_ret0}};

// (calloutdrive x) -> the address of callout_drive as a fixnum (x ignored) -- the glaze emitter reads
// it once and bakes it as the `li Ip` immediate for a native-lane call-out (cf. pgaddr / ai_pg_dyad).
// callout_drive is the STACKLESS call-out bridge (ai.c): a native blob threads a closure application
// through the VM stack -- no re-entrant C frame -- so a deep/re-entrant callee grows Sp, not the C
// stack. (The retired re-entrant ai_call1 driver + its callout1 POC nif are gone with it.)
static lvm(lvm_calloutdrive) { return Sp[0] = putcharm((intptr_t) ai_calloutdrive()), Ip++, Continue(); }
static union u const nif_calloutdrive[] = {{lvm_calloutdrive}, {lvm_ret0}};
// (calloutresume x) -> the address of callout_resume (the WALKABLE resume drive, ai.c) as a fixnum.
static lvm(lvm_calloutresume) { return Sp[0] = putcharm((intptr_t) ai_calloutresume()), Ip++, Continue(); }
static union u const nif_calloutresume[] = {{lvm_calloutresume}, {lvm_ret0}};

static union u const
 nif_exit[] = {{lvm_exit}, {lvm_ret0}},
 nif_open[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_open}, {lvm_ret0}},
 nif_close[] = {{lvm_close}, {lvm_ret0}},
 nif_run[] = {{lvm_run}, {lvm_ret0}},
 nif_exec[] = {{lvm_exec}, {lvm_ret0}},
 nif_getenv[] = {{lvm_getenv}, {lvm_ret0}},
 nif_getpid[] = {{lvm_getpid}, {lvm_ret0}};
// Register in the ai_nifs section (drained in main below). An app thread adds its
// own nifs the same way in its OWN host/<app>.c -- auto-globbed, AI_NIF-registered,
// NO edit here or to ai.c/ai.h:
//   #include "ai.h"                                       // the nif-writing surface
//   static lvm(lvm_foo) { ... return Sp[0] = <v>, Ip++, Continue(); }
//   static union u const nif_foo[] = {{lvm_foo}, {lvm_ret0}};  // 1-arg; curry for more
//   AI_NIF("foo", nif_foo);
AI_NIF("quit", nif_exit);
AI_NIF("open", nif_open);
AI_NIF("close", nif_close);
AI_NIF("run", nif_run);
AI_NIF("exec", nif_exec);
AI_NIF("getenv", nif_getenv);
AI_NIF("getpid", nif_getpid);
AI_NIF("pgaddr", nif_pgaddr);
AI_NIF("calloutdrive", nif_calloutdrive);
AI_NIF("calloutresume", nif_calloutresume);

// --- the boot script ---------------------------------------------------
// Everything the two builds disagree about lives in this ONE conditional
// region: the baked lisp text plus a `boot` entry that main tail-calls after
// the universal setup (argv pins + the host nif defs above).
// AI_BUDGET_MB: cap the whole GC footprint (2*minor + 2*major) at N megabytes -- the runtime
// face of the ai_budget tunable (the field is set-at-runtime by design). The BENCH use: pin
// the pool so an A/B compares identical GC schedules -- the resize controller can't wander
// across a pool boundary between the two sides (the pool-cliff contamination class). Applied
// to the LIVE g in main, after boot or image wake, so both boot paths honor it.
static struct ai *env_budget(struct ai *g) {
  char const *b = getenv("AI_BUDGET_MB");
  if (g && b && atol(b) > 0) g->budget = (uintptr_t) atol(b) * (1024 * 1024 / sizeof(ai_word));
  return g; }

#ifdef GL_BOOTSTRAP
// love0: the CLI driver is the sed-wrapped raw text (it can't lcat its own arg
// ap). Self-test: the whole test corpus, baked in (sed-wrapped), run
// twice -- once compiled by the C bootstrap compiler (c0), once by the
// self-hosted ev installed from ev.l -- so one love0 invocation exercises both
// compilers (and -Dai_tco=0 makes it the trampoline path). s2cldef installs
// s2cl (string -> charlist); runner drinks the baked corpus (the global
// `tests`) through reads (the shell core, love/bao.l), whose `(ev 'ev r)` indirection
// late-binds to whatever `ev` is now, so the same shell drives the c0 pass and
// (after the egg) the self-hosted pass.
static char const cli[] =
#include "cli0.h"
 ;
static char const tests0[] =
#include "tests0.h"
 ;
static char const
 s2cldef[] = "(: (s2cl s) ((: (g i) (? (< i (tally s)) (link (peep s i 0) (g (+ 1 i))))) 0))",
 runner[] = "(reads (tap (s2cl tests)))";   // the stream shell (love/bao.l) drinks the baked corpus

// With args, run the build tool (lcat / gen_data) through the CLI driver.
// With no args, self-test: eval prel+bao (the shell core) and run the baked corpus
// via c0, then bootstrap the self-hosted ev (egg) and run the corpus again through it.
static struct ai *boot(struct ai *g, bool argp) {
  if (argp) {                                          // a build tool (lcat etc.): bake prel+bao FIRST so the CLI's
    g = ai_evals_(g,                                   // own loader/printer (eval1/bye reach for map/jot/tap/puts/putc)
#include "prel0.h"                                     // have the prel surface before they load the first file -- else
#include "bao0.h"                                      // loading prel.l ITSELF misses every prel fn its loader uses.
    );
    return ai_evals_(g, cli); }
  g = ai_strof(g, tests0);                            // the baked corpus, as a string
  struct ai_def td[] = {{"tests", ai_pop1(g)}};
  g = ai_defn(g, td, countof(td));
  g = ai_evals_(g,                                    // prel + bao (the shell core), compiled by c0
#include "prel0.h"
#include "bao0.h"
  );
  g = ai_evals_(g,                                    // the crew/holo/ assembler service (neutral core + both backends),
#include "holo0.h"                                     //   baked into the bootstrap so the corpus can test it under c0
#include "x640.h"                                     //   AND the self-hosted ev. Globals persist across the egg warm
#include "arm640.h"                                   //   below, so one eval here serves both corpus passes.
#include "seal0.h"                                    // the module boundary: seal.l closes holo.l's scope layer as the `holo` book
  );
  g = ai_evals_(g,                                    // the uu kernel (love/uu.l, sweep at its tail): the corpus's uu
#include "uu0.h"                                       //   files drive it through the `uu` book under c0 AND the self-hosted ev
  );
  g = ai_evals_(g, s2cldef);
  g = ai_evals_(g, runner);                           // pass 1: corpus via ev = the c0 nif
  g = ai_evals_(g, "("                                // bootstrap: install the self-hosted ev
#include "egg0.h"
    "'("
#include "prel0.h"
#include "ev0.h"
    "))");
  return ai_evals_(g, runner); }                      // pass 2: corpus via the self-hosted ev

#else
// the full ai: raw terminal mode for the interactive REPL (love0 never needs
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
 rel[] = "(reads in)";   // non-tty stdin: the stream shell (love/bao.l) drinks the in port
// a tty: launch the bao shell. bao IS the baked shell core now (love/bao.l, baked to
// bao.h, evaled in the egg-warm below), DEFINE-ONLY -- it installs (bao _)/shell/...
// but does not launch, so the same image serves a pipe (the bare `rel` runner) and
// the corpus self-test. The frontend launches it on a tty by evaling "(bao 0)".
static char const baolaunch[] = "(bao 0)";   // bao.l is define-only -> the frontend starts it

// NOTE: the native-JIT experiment was retracted. It proved one durable finding
// (you can run native code from a buf -- (eat 1 (toast bytes) x) -- and the kernel's
// HHDM is executable, so a kernel JIT needs only a trampoline; see love/glaze/probe.l) and
// one real speedup (reduction reassociation), which now lives baked in the C builtins
// asum/aprod/amax/amin. The scalar/array kernels themselves were a net loss or
// unused, so only eat (the curried eat1/eat2 nifs) + toast remain. See love/glaze/README.md.

// --bake [PATH] / --wake PATH: the heap-image snapshot (doc/snapshot.md). `--bake` boots fully,
// then lays the post-warm image back into the binary's OWN .image section (host/image.c's
// copy + patch + atomic-rename -- no objcopy, ETXTBSY-proof) and exits; `--bake PATH` writes a
// plain image file instead (the debug/inspection lane). `--wake PATH` boots from an image file
// (any mismatch falls back to a normal egg boot). Opt-in flags; a normal run is the same code path.
extern int image_dump(struct ai*, char const*);          // host/image.c (file I/O around ai.c's codec)
extern int image_bake(struct ai*);                       // host/image.c (the self-bake)
extern struct ai *image_load(char const*);
static char const *image_dump_path = NULL;
static bool image_bake_p = false;                        // --bake with no PATH: patch the binary itself
// The baked post-boot image: a reserve in its own .image section (host/image_baked.c), filled by
// `ai --bake` (the binary boots, snapshots itself, and lays the result back into its own body).
// Loaded at startup when its magic validates; else a normal egg boot.
extern uint64_t ai_baked_image[];
extern uintptr_t ai_baked_image_len;
// the glaze (native JIT, love/glaze/{emit,auto}.l), x86-64 only. Baked but evaled ONLY
// before a --bake -- so a normal boot never pays the ~810 ms native-compile of
// its self-tests, while the dumped snapshot carries the JIT always-on at zero startup
// (Phase 4, doc/snapshot.md). The asserts compile transient native closures; the
// gen_major inside image_dump drops them, so the serialized heap is pure closures
// (ev rebound to auto-ev) with no W^X arena to serialize -- natives JIT lazily on load.
#if defined(__x86_64__) || defined(__aarch64__)
static char const glaze_emit[] =
#include "emit.h"
 ;
static char const glaze_auto[] =
#include "auto.h"
 ;
static char const glaze_export[] =              // love/glaze/export.l: sweep the span into the `glaze` book
#include "gexport.h"
 ;
#endif
#if defined(__x86_64__) || defined(__aarch64__)
static char const glaze_hook[] =                // love/glaze/hook.l: install book['natjit] -- the ala
#include "hook.h"                               //   creation hook (glaze EVERY embedded closure, not just (ev '(\..))); the hook's lanes take `arch` (= (intern ai-arch)) so aarch64 emits its own code
 ;
#endif
// the post-warm dispatch (shared by boot() and the --wake path, which skips the warm).
static struct ai *run_program(struct ai *g, bool argp, bool replp) {
  if (argp) return ai_evals_(g, cli);
  if (!replp) return ai_evals_(g, rel);
  return ai_evals_(g, baolaunch); }      // a tty: launch the baked bao shell: (bao 0)

static struct ai *boot(struct ai *g, bool argp) {
  bool replp = !argp && isatty(STDIN_FILENO);
  if (replp) raw_mode();
  g = ai_evals_(g, "("
#include "egg.h"
    "'("
#include "prel.h"
#include "ev.h"
    "))"
#include "post.h"                                       // the post-egg layer (parser combinators, ...), evaled ONCE after the egg
#include "uu.h"                                          // uu's NbE kernel (love/uu.l, sweep at its tail) -- one global name, the
                                                         //   `uu` book; the corpus + an overlay reach (uu 'vof) through it
#include "holo.h"                                         // the crew/holo/ assembler -- a post-egg language SERVICE, built as a
#if defined(__x86_64__)                                  //   scope MODULE: holo.l opens a named layer ((enter 'holo)), the core +
#include "x64.h"                                         //   the NATIVE backend load into it, and seal.l's (leave ()) REGISTERS
#elif defined(__aarch64__)                               //   the layer as the module `holo` -- orth stays clean; (use 'holo)
#include "arm64.h"                                       //   splices it, (from 'holo 'assemble) probes it. native-ONLY here: the
#endif                                                   //   glaze emits for the running arch, mooncc.image carries ALL backends
                                                         //   (crew/build.mk moonfiles), a test that wants a cross backend loads it
                                                         //   at runtime ((enter ()) (use 'holo) <backend.l> (leave ()) -- the
                                                         //   test_glaze/test_raw_arm64 recipes), and love0 keeps every backend so
                                                         //   the corpus's cross-arch asserts still run under both its compilers.
#include "seal.h"
#include "bao.h"
  );
  // welow (church+HOF lowering, book['welow]) is a USER-code pass. A JIT must NOT lower its own
  // source during self-bake: the glaze REASONS about the very church/HOF forms welow rewrites, so
  // lowering its source changes its behavior (a group's __outer tail miscompiles -> wrong capture).
  // Turn welow off across the toolchain's own post-egg load, restore it below so user code still lowers.
  g = ai_evals_(g, "(: wsave welow welow 0)");
#if defined(__x86_64__) || defined(__aarch64__)
  g = ai_evals_(g, "(use 'holo)");                       // splice the assembler module below orth for the glaze's load: its bare
                                                         //   assemble/assemble-at reads FOLD at compile (the capture law), so the
                                                         //   glaze's closures stay self-contained after the (leave ()) below.
  g = ai_evals_(g, glaze_emit);                          // load the native JIT post-egg -> ev = auto-ev, glaze always-on
  g = ai_evals_(g, glaze_auto);                          // (no fragile stale image; base-ev captures the hatched ev).
  g = ai_evals_(g, glaze_export);                        // the glaze module boundary: its names sweep into the `glaze` book
                                                         // ~680ms from-scratch; the image snapshots past it. arm64: the integer + scalar-float lanes (leaf, counted/n-var loops, group, call-out) are native via BOTH auto-ev and the natjit hook; only the float-GRID lane + castbuild fall to interp (auto.l's `x86?` gate).
  g = ai_evals_(g, glaze_hook);                          // install natjit: glaze embedded closures at creation, not just (ev '(\..)); arch-parameterized, so aarch64 too
  g = ai_evals_(g, "(leave ())");                        // a bare leave clears the use-stack: holo off the chain, orth alone again
#endif
  g = ai_evals_(g, "(: welow wsave)");                   // toolchain baked -> welow back on for USER code
#if defined(__x86_64__) || defined(__aarch64__)
  // AI_NO_GLAZE: a pure-interpreter session -- ev back to base-ev (kept in the
  // glaze module book) and the natjit creation hook cleared. The forensics twin
  // of AI_NO_IMAGE: it isolates glaze-lane decisions from interpreter behavior.
  if (getenv("AI_NO_GLAZE")) g = ai_evals_(g, "(: ev (glaze 'base-ev) natjit ())");
#endif

  if (image_dump_path || image_bake_p) {                 // --bake: snapshot the post-warm heap, then exit
#if defined(__x86_64__) || defined(__aarch64__)
    // auto.l's self-tests ran auto-ev, filling the `memo` compile cache with native nif
    // closures (ap = a W^X mmap addr) that can't be serialized. Empty it: the image boots
    // with a clean cache (natives JIT lazily on the loaded runtime's first ev, as designed).
    // BOTH glazing arches -- the guard was x86-only from when the glaze was too, so an arm64
    // host bake carried the whole cache into img_nif_interp's revert (or a refused bake).
    g = ai_evals_(g, "(: c ((peep book 'glaze 0) 'cache) (map (\\ k (pull c k 0)) (keys c)))");
#endif
    // HIDE the raw machine-code-execution seam from USERS (who boot this image): the glaze folded
    // `nif` into its closures, so pulling it off the book is safe. eat/toast/nif off, then seal `book`.
    // The no-image dev/test binary keeps them (egg.l defers book-removal) as the test knob.
    g = ai_evals_(g, "(: _ (pull book 'eat 0) _ (pull book 'toast 0) _ (pull book 'nif 0) _ (pull book 'nifx 0) (pull book 'book 0))");
    int rc = image_dump_path ? image_dump(g, image_dump_path) : image_bake(g);
    if (rc) fprintf(stderr, "ai: bake failed (rc=%d)\n", rc);
    exit(rc ? 1 : 0); }
  return run_program(g, argp, replp); }
#endif

int main(int argc, char const **argv) {
  struct ai *g = NULL;
#ifndef GL_BOOTSTRAP
  // --bake [PATH] / --wake PATH must lead the args; strip them (keep argv[0]).
  char const *image_load_path = NULL;
  if (argc >= 2 && !strcmp(argv[1], "--bake")) {
    if (argc >= 3) { image_dump_path = argv[2]; argv[2] = argv[0], argv += 2, argc -= 2; }
    else           { image_bake_p = true; argv[1] = argv[0], argv += 1, argc -= 1; } }
  else if (argc >= 3 && !strcmp(argv[1], "--wake")) { image_load_path = argv[2]; argv[2] = argv[0], argv += 2, argc -= 2; }
  if (image_load_path && !(g = image_load(image_load_path))) image_load_path = NULL;   // NULL -> normal boot
  // AUTO-LOAD: with no image flag, wake the image baked into the binary's own .image section, so a
  // plain `ai` is glazed-by-default at ~4 ms cold start instead of the ~230 ms egg eval. Opt out with
  // AI_NO_IMAGE (the bench does, to control glazed-vs-interp itself). Any problem -- unbaked, stale,
  // truncated -- makes the load return NULL, so we fall through to the normal egg boot. Never wrong.
  if (!g && !image_dump_path && !image_bake_p && !getenv("AI_NO_IMAGE")) {
    if (ai_baked_image_len && (g = ai_image_load(ai_baked_image, ai_baked_image_len)))
      image_load_path = "<baked>"; }                                     // a loaded image is the booted state: skip the egg warm
#endif
  if (!g) g = ai_ini();
  g = env_budget(g);                               // the AI_BUDGET_MB cap, on whichever g won (fresh or woken image)
  bool argp = argc > 1;
  // The WHOLE C argv (incl. argv[0]/program name): cli.l drops the head for its own
  // use, while `cmdline` keeps the full list, pinned for user visibility.
  char const **av = argv;
  int ac = argc;
  for (; *av; g = ai_strof(g, *av++));
  for (g = ai_push(g, 1, ai_nil); ac--; g = gxr(g));
  if (ai_ok(g)) {
    ai_word full_argv = ai_pop1(g);                // shared by `argv` and `cmdline`
    // the static nifs (exit/open/close/run/getenv + any host/*.c app nifs) come
    // from the ai_nifs section; argv/cmdline are runtime values, defined here.
    g = ai_defn(g, __start_ai_nifs, __stop_ai_nifs - __start_ai_nifs);
    struct ai_def d[] = {{"argv", full_argv}, {"cmdline", full_argv}};
    g = ai_defn(g, d, countof(d));      // re-pins the host nifs (live addresses) into the loaded book too
#ifndef GL_BOOTSTRAP
    if (image_load_path) {              // --wake: skip the egg warm, dispatch straight to the program
      bool replp = !argp && isatty(STDIN_FILENO);
      if (replp) raw_mode();
#if defined(__x86_64__) || defined(__aarch64__)
      // the AI_NO_GLAZE knob on the image path: the book nom is sealed away in an
      // image, but a body-less top-level : still pins -- no book access needed.
      if (getenv("AI_NO_GLAZE")) g = ai_evals_(g, "(: ev (glaze 'base-ev) natjit ())");
#endif
      g = run_program(g, argp, replp);
    } else
#endif
    g = boot(g, argp); }
  switch (ai_code_of(g)) {
   default: break;
   case ai_status_scare:               // the honest face: ";; a b" when the scare
    if (!ai_scare_face_(g))            // said something; bare (no data) = oom
     fprintf(stderr, ";; oom@len=%ld\n", (long) ai_core_of(g)->len);
    break; }
  return ai_fin(g); }
