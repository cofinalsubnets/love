// host/init.c -- the init (pid-1 supervisor) nifs: SPAWN a process without
// waiting + REAP an arbitrary dead child WITH its pid. Host-only, auto-globbed +
// AI_NIF-registered (no ai.c/ai.h/main.c edit), the same discipline as net.c
// (ain) / pty.c (bao). These are the two primitives a supervisor needs that the
// existing nifs miss: run/exec/mind all BLOCK or REPLACE, and pty.c's `gather`
// reaps a KNOWN pid (handing back only the status). init/init.l drives REAL
// processes with these plus bao's generic `still` (kill): spawn returns a pid to
// track, reap is the SIGCHLD core (poll it, map the pid back to a unit, restart
// per policy). On a real pid1 reap also collects reparented orphans (waitpid(-1)).
//
//   (spawn argv)  -> child pid (a fixnum) | a NEGATIVE fixnum (-errno / -1 misuse)
//   (reap _)      -> (pid . status) of one reaped child
//                  | ()                 none pending
//                  | a NEGATIVE fixnum  (-errno, e.g. -ECHILD: no children left)
//
// argv marshaling mirrors host_exec (main.c): a chain of strings -> a NUL-
// terminated char** in the uncommitted heap gap at Hp (GC-invisible, holds no l
// pointers, consumed before any further alloc), valid across the fork. The wait-
// status decode is shared with bao via host/proc.h (proc_status).
#include "ai.h"
#include "proc.h"
#include <unistd.h>     // fork execvp _exit read close
#include <stdio.h>      // fflush
#include <string.h>     // memcpy
#include <errno.h>
#include <signal.h>     // sigprocmask, SIGCHLD/SIGTERM (sigfd)
#include <fcntl.h>      // open, O_* (openfd, for shell redirects)
#if defined(__linux__)
#include <sys/signalfd.h>   // signalfd, struct signalfd_siginfo (Linux only)
#endif

// is Sp-slot x a heap stream port, and its backing fd -- as in net.c.
#define portp(x) (((x) & 1) == 0 && ((union u*) (x))->ap == lvm_port_io)
#define port_fd(x) ((int) getcharm(((struct ai_io*) (x))->fd))

// (spawn argv) -> the child pid, or a negated errno (negative, so a caller tells
// a pid (positive) from a failure (negative) without a second value). fork +
// execvp; the parent returns immediately -- NON-BLOCKING, unlike run (waits +
// captures) and exec (replaces in place). The child inherits init's stdio (a real
// pid1 redirects to the journal); a failed exec _exit(127)s, seen by the next reap.
ai_noinline static struct ai *host_spawn(struct ai *g, ai_word argv) {
  intptr_t argc = 0;
  uintptr_t total = 0;
  for (ai_word p = argv; chainp(p); p = B(p)) {
    if (!ai_strp(A(p))) return ai_push(g, 1, putcharm(-1));   // misuse: non-string argv
    argc++, total += len(A(p)) + 1; }
  if (!argc) return ai_push(g, 1, putcharm(-1));              // empty argv
  if (!ai_ok(g = ai_have(g, (uintptr_t) argc + 1 + b2w(total)))) return g;
  argv = g->sp[0];                                            // re-root post-ai_have
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
  fflush(NULL);                                               // flush now, not twice in the child
  pid_t pid = fork();
  if (pid < 0) return ai_push(g, 1, putcharm(-errno));
  if (!pid) { execvp(cav[0], cav); _exit(127); }             // child: exec or die 127
  return ai_push(g, 1, putcharm(pid)); }                      // parent: the live pid

static lvm(lvm_spawn) {
  Pack(g);
  g = host_spawn(g, Sp[0]);
  if (!ai_ok(g)) return ghelp(g);
  Unpack(g);
  Sp[1] = Sp[0];                                              // pid over argv
  Sp += 1; Ip += 1;
  return Continue(); }

// (reap _) -> (pid . status) of one reaped child, () if none are pending, or a
// negated errno (e.g. -ECHILD when no children remain). The pid is the CAR so the
// supervisor maps it back to a unit; status is proc_status (exit code / 128+sig).
// waitpid(-1, WNOHANG) reaps ANY child -- incl. reparented orphans on a real pid1.
// The arg is a dummy (ignored), so a bare (reap) curries; call it (reap 0).
ai_noinline static struct ai *host_reapany(struct ai *g) {
  int st;
  pid_t r = waitpid(-1, &st, WNOHANG);
  if (r == 0) { g->sp[0] = ai_nil; return g; }               // none pending
  if (r < 0)  { g->sp[0] = putcharm(-errno); return g; }     // error (ECHILD = none alive)
  if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
  struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 putcharm(r), putcharm(proc_status(st)));
  g->sp[0] = word(w);
  return g; }

static lvm(lvm_reapany) {
  Pack(g);
  g = host_reapany(g);
  if (!ai_ok(g)) return ghelp(g);
  Unpack(g);
  Ip += 1; return Continue(); }

// --- the signal perceive source (Linux signalfd) --------------------------------
// (sigfd _)     -> a PORT over a signalfd watching SIGCHLD + SIGTERM, those signals
//                  first BLOCKED (sigprocmask) so they QUEUE to the fd instead of
//                  their default disposition -- SIGCHLD's discard, SIGTERM's KILL.
//                  That queuing is exactly what turns a TERM into a graceful EVENT,
//                  not a death. () on failure. SIGINT is left unblocked so ^C bails.
// (sigtake port) -> (signo . pid) of ONE pending signal, or () if none ready.
// The supervisor PARKS with the core `(await sig)` (cooperative -- the scheduler
// merges the sigfd with a heartbeat task's timer in one ai_wait_fds, the {nic, clock}
// story for {signals, clock}), then sigtake reads the record. SIGCHLD coalesces, so a
// 'chld wake still loops `reap` to harvest every zombie.
#if defined(__linux__)
static lvm(lvm_sigfd) {
 sigset_t m;
 sigemptyset(&m);
 sigaddset(&m, SIGCHLD);
 sigaddset(&m, SIGTERM);
 if (sigprocmask(SIG_BLOCK, &m, NULL)) goto fail;
 int fd = signalfd(-1, &m, SFD_NONBLOCK | SFD_CLOEXEC);
 if (fd < 0) goto fail;
 Pack(g);
 struct ai *r = ai_io_alloc(g, fd);
 if (!ai_ok(r)) { close(fd); goto fail; }    // OOM -> nil (cf. net.c lvm_listen)
 g = r;
 Unpack(g);
 Sp[1] = Sp[0];                              // port over the dummy arg
 Sp += 1; Ip += 1;
 return Continue();
 fail:
 Sp[0] = ai_nil; Ip += 1;
 return Continue(); }

// read one signalfd_siginfo (non-blocking) into (signo . pid). signo is the raw
// number (Linux: SIGCHLD 17, SIGTERM 15); pid is ssi_pid (the dead child on SIGCHLD).
ai_noinline static struct ai *host_sigtake(struct ai *g, int fd) {
 struct signalfd_siginfo si;
 ssize_t n = (fd >= 0) ? read(fd, &si, sizeof si) : -1;
 if (n != (ssize_t) sizeof si) { g->sp[0] = ai_nil; return g; }   // EAGAIN / short read
 if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
 struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                putcharm((intptr_t) si.ssi_signo),
                                putcharm((intptr_t) si.ssi_pid));
 g->sp[0] = word(w);
 return g; }

static lvm(lvm_sigtake) {
 if (!portp(Sp[0])) { Sp[0] = ai_nil; return Ip++, Continue(); }
 int fd = port_fd(Sp[0]);
 Pack(g);
 g = host_sigtake(g, fd);
 if (!ai_ok(g)) return ghelp(g);
 Unpack(g);
 Ip += 1; return Continue(); }
#else
// signalfd is Linux-only; keep the names present (so init.l loads) but inert.
static lvm(lvm_sigfd)   { Sp[0] = ai_nil; return Ip++, Continue(); }
static lvm(lvm_sigtake) { Sp[0] = ai_nil; return Ip++, Continue(); }
#endif

// --- foreground job control + cwd (the muscle a real shell needs) ---------------
// (wait pid)   -> BLOCK until pid exits; its proc_status (exit / 128+sig), or -errno.
//                 the foreground wait: spawn (inherited stdio) then wait, so a command
//                 owns the terminal and the prompt returns only when it is done.
// (chdir path) -> () ok | -errno | -1 misuse. the `cd` builtin.
// (cwd _)      -> the current directory as a string, or () on failure. for the prompt.
static lvm(lvm_waitpid) {
 intptr_t pid = (Sp[0] & 1) ? getcharm(Sp[0]) : 0;
 int st;
 pid_t r;
 do r = waitpid((pid_t) pid, &st, 0); while (r < 0 && errno == EINTR);
 Sp[0] = (r < 0) ? putcharm(-errno) : putcharm(proc_status(st));
 return Ip++, Continue(); }

// copy an ai string into a NUL-terminated C buffer; false on non-string / too long.
static bool str_cbuf(ai_word x, char *buf, size_t cap) {
 if (!ai_strp(x)) return false;
 struct ai_str *s = (struct ai_str*) x;
 if ((size_t) s->len >= cap) return false;
 memcpy(buf, s->bytes, s->len);
 buf[s->len] = 0;
 return true; }

static lvm(lvm_chdir) {
 char buf[4096];
 if (!str_cbuf(Sp[0], buf, sizeof buf)) { Sp[0] = putcharm(-1); return Ip++, Continue(); }
 Sp[0] = chdir(buf) ? putcharm(-errno) : ai_nil;
 return Ip++, Continue(); }

static lvm(lvm_cwd) {
 char buf[4096];
 if (!getcwd(buf, sizeof buf)) { Sp[0] = ai_nil; return Ip++, Continue(); }
 Pack(g);
 if (!ai_ok(g = ai_strof(g, buf))) return ghelp(g);
 Unpack(g);
 Sp[1] = Sp[0];                 // cwd string over the dummy arg
 Sp += 1; Ip += 1;
 return Continue(); }

// --- pipes + redirects (the fd plumbing a shell pipeline needs) ------------------
// (pipe _)       -> (readfd . writefd) of a fresh pipe (raw fds), or -errno.
// (openfd path m) -> a raw fd opening `path`: m 0 = read, 1 = write/create/trunc,
//                   2 = write/create/append. -errno on failure, -1 on a bad path.
// (spawnio argv in out err closes) -> pid. fork; in the child dup2 `in`/`out`/`err`
//                   (each >=0) onto fd 0/1/2, close every fd in the list `closes`
//                   (the pipe ends the child must not leak, so a downstream reader
//                   sees EOF), then execvp. The parent keeps its fds and closes the
//                   pipe ends itself with shutfd. -errno on a fork/marshal failure.
// (shutfd fd)    -> close a raw fd (the parent's pipe ends). () ok | -errno.
static lvm(lvm_pipe) {
 int fds[2];
 if (pipe(fds)) { Sp[0] = putcharm(-errno); return Ip++, Continue(); }
 Pack(g);
 if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) { close(fds[0]); close(fds[1]); return ghelp(g); }
 struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                putcharm(fds[0]), putcharm(fds[1]));
 g->sp[0] = word(w);
 Unpack(g);
 return Ip++, Continue(); }

static lvm(lvm_openfd) {
 char buf[4096];
 if (!str_cbuf(Sp[0], buf, sizeof buf)) { Sp[1] = putcharm(-1); Sp += 1; return Ip++, Continue(); }
 intptr_t m = (Sp[1] & 1) ? getcharm(Sp[1]) : 0;
 int flags = m == 1 ? (O_WRONLY | O_CREAT | O_TRUNC)
           : m == 2 ? (O_WRONLY | O_CREAT | O_APPEND)
           : O_RDONLY;
 int fd = open(buf, flags, 0644);
 Sp[1] = (fd < 0) ? putcharm(-errno) : putcharm(fd);
 Sp += 1; return Ip++, Continue(); }

ai_noinline static struct ai *host_spawnio(struct ai *g, int in, int out, int err) {
 ai_word argv = g->sp[0];
 intptr_t argc = 0; uintptr_t total = 0;
 for (ai_word p = argv; chainp(p); p = B(p)) {
  if (!ai_strp(A(p))) return ai_push(g, 1, putcharm(-1));
  argc++, total += len(A(p)) + 1; }
 if (!argc) return ai_push(g, 1, putcharm(-1));
 if (!ai_ok(g = ai_have(g, (uintptr_t) argc + 1 + b2w(total)))) return g;
 argv = g->sp[0];                            // re-root post-ai_have (closes too, below)
 ai_word closes = g->sp[4];
 char **cav = (char**) g->hp;
 char *blob = (char*) (g->hp + (argc + 1));
 { uintptr_t off = 0; intptr_t i = 0;
   for (ai_word p = argv; chainp(p); p = B(p), i++) {
    struct ai_str *s = str(A(p));
    memcpy(blob + off, txt(s), len(s)); blob[off + len(s)] = 0;
    cav[i] = blob + off; off += len(s) + 1; }
   cav[argc] = NULL; }
 fflush(NULL);
 pid_t pid = fork();
 if (pid < 0) return ai_push(g, 1, putcharm(-errno));
 if (!pid) {
  if (in  >= 0) dup2(in, 0);
  if (out >= 0) dup2(out, 1);
  if (err >= 0) dup2(err, 2);
  for (ai_word p = closes; chainp(p); p = B(p)) {
   intptr_t fd = getcharm(A(p));
   if (fd > 2) close((int) fd); }
  execvp(cav[0], cav);
  _exit(127); }
 return ai_push(g, 1, putcharm(pid)); }

static lvm(lvm_spawnio) {
 int in  = (Sp[1] & 1) ? (int) getcharm(Sp[1]) : -1;
 int out = (Sp[2] & 1) ? (int) getcharm(Sp[2]) : -1;
 int err = (Sp[3] & 1) ? (int) getcharm(Sp[3]) : -1;
 Pack(g);
 g = host_spawnio(g, in, out, err);          // argv at sp[0], closes at sp[4]
 if (!ai_ok(g)) return ghelp(g);
 Unpack(g);
 Sp[5] = Sp[0];                              // pid over the 5 args
 Sp += 5; Ip += 1;
 return Continue(); }

static lvm(lvm_shutfd) {
 intptr_t fd = (Sp[0] & 1) ? getcharm(Sp[0]) : -1;
 Sp[0] = (fd >= 0 && close((int) fd)) ? putcharm(-errno) : ai_nil;
 return Ip++, Continue(); }

static union u const
  nif_spawn[]   = {{lvm_spawn}, {lvm_ret0}},
  nif_reapany[] = {{lvm_reapany}, {lvm_ret0}},
  nif_sigfd[]   = {{lvm_sigfd}, {lvm_ret0}},
  nif_sigtake[] = {{lvm_sigtake}, {lvm_ret0}},
  nif_waitpid[] = {{lvm_waitpid}, {lvm_ret0}},
  nif_chdir[]   = {{lvm_chdir}, {lvm_ret0}},
  nif_cwd[]     = {{lvm_cwd}, {lvm_ret0}},
  nif_pipe[]    = {{lvm_pipe}, {lvm_ret0}},
  nif_openfd[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_openfd}, {lvm_ret0}},
  nif_spawnio[] = {{lvm_cur}, {.x = putcharm(5)}, {lvm_spawnio}, {lvm_ret0}},
  nif_shutfd[]  = {{lvm_shutfd}, {lvm_ret0}};
AI_NIF("spawn", nif_spawn);
AI_NIF("reap",  nif_reapany);
AI_NIF("sigfd", nif_sigfd);
AI_NIF("sigtake", nif_sigtake);
AI_NIF("wait",  nif_waitpid);
AI_NIF("chdir", nif_chdir);
AI_NIF("cwd",   nif_cwd);
AI_NIF("pipe",  nif_pipe);
AI_NIF("openfd", nif_openfd);
AI_NIF("spawnio", nif_spawnio);
AI_NIF("shutfd", nif_shutfd);
