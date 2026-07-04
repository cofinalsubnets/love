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
#define _GNU_SOURCE     // unshare / CLONE_* for newns (mirrors pty.c)
#include "ai.h"
#include "proc.h"
#include <unistd.h>     // fork execvp _exit read close getuid/getgid
#include <stdio.h>      // fflush
#include <stdlib.h>     // setenv/unsetenv (the env nifs)
#include <string.h>     // memcpy
#include <errno.h>
#include <signal.h>     // sigprocmask, SIGCHLD/SIGTERM (sigfd)
#include <fcntl.h>      // open, O_* (openfd, for shell redirects)
#include <sys/stat.h>   // mkdir, stat
#include <dirent.h>     // opendir/readdir/closedir
#if defined(__linux__)
#include <sys/signalfd.h>   // signalfd, struct signalfd_siginfo (Linux only)
#include <sys/mount.h>      // mount(2)
#include <sched.h>          // unshare, CLONE_NEWUSER/NEWNS (newns)
#endif

// is Sp-slot x a heap stream port, and its backing fd -- as in net.c.
#define portp(x) (((x) & 1) == 0 && ((union u*) (x))->ap == lvm_port_io)
#define port_fd(x) ((int) getcharm(((struct ai_io*) (x))->fd))

// the child side of the ignore dance: a disposition set to SIG_IGN SURVIVES exec,
// so a shell that ignores the job-control signals must undo that in every child
// between fork and exec -- or ^C could never kill anything it launches.
static void sig_dfl_job(void) {
 signal(SIGINT, SIG_DFL); signal(SIGQUIT, SIG_DFL);
 signal(SIGTSTP, SIG_DFL); signal(SIGTTIN, SIG_DFL); signal(SIGTTOU, SIG_DFL); }

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
  if (!pid) { sig_dfl_job(); execvp(cav[0], cav); _exit(127); }   // child: default signals, exec or die 127
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
  if (r == 0) { g->sp[0] = ZeroPoint; return g; }            // none pending -> the real () (not charm 0)
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
// (sigfd sigs)  -> a PORT over a signalfd watching `sigs` (a list of signal numbers;
//                  a non-list keeps the supervisor default SIGCHLD + SIGTERM), those signals
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
// the arg may be a LIST of signal numbers to watch; anything else (the dummy-0
// convention) keeps the supervisor's classic pair, SIGCHLD + SIGTERM.
ai_noinline static struct ai *host_sigfd(struct ai *g) {
 sigset_t m;
 sigemptyset(&m);
 ai_word a = g->sp[0];
 if (chainp(a))
  for (ai_word p = a; chainp(p); p = B(p)) {
   if (A(p) & 1) sigaddset(&m, (int) getcharm(A(p))); }
 else { sigaddset(&m, SIGCHLD); sigaddset(&m, SIGTERM); }
 if (sigprocmask(SIG_BLOCK, &m, NULL)) return g->sp[0] = ZeroPoint, g;
 int fd = signalfd(-1, &m, SFD_NONBLOCK | SFD_CLOEXEC);
 if (fd < 0) return g->sp[0] = ZeroPoint, g;
 struct ai *r = ai_io_alloc(g, fd);
 if (!ai_ok(r)) return close(fd), g->sp[0] = ZeroPoint, g;    // OOM -> nil (cf. net.c lvm_listen)
 g = r;
 return g->sp[1] = g->sp[0], g->sp += 1, g; }                 // port over the dummy arg
static lvm(lvm_sigfd) {
 Pack(g); g = host_sigfd(g); Unpack(g);     // host_sigfd folds every failure to nil, so no ghelp
 return Ip++, Continue(); }

// read one signalfd_siginfo (non-blocking) into (signo . pid). signo is the raw
// number (Linux: SIGCHLD 17, SIGTERM 15); pid is ssi_pid (the dead child on SIGCHLD).
ai_noinline static struct ai *host_sigtake(struct ai *g, int fd) {
 struct signalfd_siginfo si;
 ssize_t n = (fd >= 0) ? read(fd, &si, sizeof si) : -1;
 if (n != (ssize_t) sizeof si) { g->sp[0] = ZeroPoint; return g; }   // none ready -> the real () (not charm 0)
 if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
 struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                putcharm((intptr_t) si.ssi_signo),
                                putcharm((intptr_t) si.ssi_pid));
 g->sp[0] = word(w);
 return g; }

static lvm(lvm_sigtake) {
 if (!portp(Sp[0])) { Sp[0] = ZeroPoint; return Ip++, Continue(); }
 int fd = port_fd(Sp[0]);
 Pack(g);
 g = host_sigtake(g, fd);
 if (!ai_ok(g)) return ghelp(g);
 Unpack(g);
 Ip += 1; return Continue(); }
#else
// signalfd is Linux-only; keep the names present (so init.l loads) but inert.
static lvm(lvm_sigfd)   { Sp[0] = ZeroPoint; return Ip++, Continue(); }
static lvm(lvm_sigtake) { Sp[0] = ZeroPoint; return Ip++, Continue(); }
#endif

// --- foreground job control + cwd (the muscle a real shell needs) ---------------
// (wait pid)   -> BLOCK until pid exits OR STOPS: an exit is its proc_status (exit /
//                 128+sig), a stop (^Z: SIGTSTP/SIGSTOP) is 256 + the stopping signal
//                 -- a charm above every exit status, so a shell tells "stopped, job
//                 it" (< 255 st) from "done". -errno on failure. the foreground wait:
//                 spawn (inherited stdio) then wait, so a command owns the terminal
//                 and the prompt returns only when it is done or parked.
// (signal sig disp) -> sigaction: disp 0 = default, 1 = ignore. () | positive errno |
//                 EINVAL misuse (the effect convention). the shell ignores INT/QUIT/
//                 TSTP so the tty's ^C/^Z reach only the foreground child; spawn's
//                 child side resets them (an IGNORED disposition survives exec).
// (chdir path) -> () ok | -errno | -1 misuse. the `cd` builtin.
// (cwd _)      -> the current directory as a string, or () on failure. for the prompt.
// The syscall body lives in an ai_noinline helper so the lvm_ wrapper stays a pure tail-jump (no ret):
// the syscall + any stack buffer would otherwise block the sibcall to Continue() and trip `make vmret`.
ai_noinline static ai_word host_waitpid(ai_word arg) {
 intptr_t pid = (arg & 1) ? getcharm(arg) : 0;
 int st;
 pid_t r;
 do r = waitpid((pid_t) pid, &st, WUNTRACED); while (r < 0 && errno == EINTR);
 if (r < 0) return putcharm(-errno);
 if (WIFSTOPPED(st)) return putcharm(256 + WSTOPSIG(st));
 return putcharm(proc_status(st)); }
static lvm(lvm_waitpid) { Sp[0] = host_waitpid(Sp[0]); return Ip++, Continue(); }

ai_noinline static ai_word host_posix_signal(ai_word sigw, ai_word dw) {
 if (!(sigw & 1) || !(dw & 1)) return putcharm(EINVAL);
 struct sigaction sa;
 memset(&sa, 0, sizeof sa);
 sa.sa_handler = getcharm(dw) ? SIG_IGN : SIG_DFL;
 sigemptyset(&sa.sa_mask);
 return sigaction((int) getcharm(sigw), &sa, NULL) ? putcharm(errno) : ZeroPoint; }
static lvm(lvm_posix_signal) {
 Sp[1] = host_posix_signal(Sp[0], Sp[1]);
 Sp += 1; return Ip++, Continue(); }


// copy an ai string into a NUL-terminated C buffer; false on non-string / too long.
static bool str_cbuf(ai_word x, char *buf, size_t cap) {
 if (!ai_strp(x)) return false;
 struct ai_str *s = (struct ai_str*) x;
 if ((size_t) s->len >= cap) return false;
 memcpy(buf, s->bytes, s->len);
 buf[s->len] = 0;
 return true; }

ai_noinline static ai_word host_chdir(ai_word arg) {
 char buf[4096];
 if (!str_cbuf(arg, buf, sizeof buf)) return putcharm(-1);
 return chdir(buf) ? putcharm(-errno) : ZeroPoint; }
static lvm(lvm_chdir) { Sp[0] = host_chdir(Sp[0]); return Ip++, Continue(); }

ai_noinline static struct ai *host_cwd(struct ai *g) {
 char buf[4096];
 if (!getcwd(buf, sizeof buf)) return g->sp[0] = ZeroPoint, g;
 if (!ai_ok(g = ai_strof(g, buf))) return g;            // OOM -> !ok, wrapper ghelps
 return g->sp[1] = g->sp[0], g->sp += 1, g; }           // cwd string over the dummy arg
static lvm(lvm_cwd) {
 Pack(g); g = host_cwd(g);
 if (!ai_ok(g)) return ghelp(g);
 Unpack(g);
 return Ip++, Continue(); }

// --- pipes + redirects (the fd plumbing a shell pipeline needs) ------------------
// (pipe _)       -> (readfd . writefd) of a fresh pipe (raw fds), or -errno.
// (openfd path m) -> a raw fd opening `path`: m 0 = read, 1 = write/create/trunc,
//                   2 = write/create/append. -errno on failure, -1 on a bad path.
// (spawnio argv in out err closes pg fg) -> pid. fork; in the child: the JOB-CONTROL
//                   dance first -- pg < 0 stays in the parent's pgrp (the legacy /
//                   non-tty lane), pg = 0 LEADS a fresh process group, pg > 0 JOINS
//                   that group (pipeline members join their stage-0 leader) -- and fg
//                   nonzero hands the child's group the TERMINAL (tcsetpgrp on fd 0
//                   BEFORE the dup2s, TTOU ignored for the handoff; the parent
//                   setpgids too, closing the race). A job in its OWN pgrp is what
//                   makes ^Z real: a stop signal to an ORPHANED group is discarded
//                   by POSIX, and the shell's own group is exactly that under a
//                   nested session. then dup2 `in`/`out`/`err` (each >=0) onto fd
//                   0/1/2, close every fd in the list `closes` (the pipe ends the
//                   child must not leak, so a downstream reader sees EOF), reset the
//                   job signals, execvp. The parent keeps its fds and closes the
//                   pipe ends itself with shutfd. -errno on a fork/marshal failure.
// (ttyfg pg)     -> give the terminal (fd 0) to process group pg; pg <= 0 takes it
//                   BACK to the caller's own group (the shell reclaiming the tty
//                   after a foreground job ends or stops). () | positive errno.
// (shutfd fd)    -> close a raw fd (the parent's pipe ends). () ok | -errno.
ai_noinline static struct ai *host_pipe(struct ai *g) {
 int fds[2];
 if (pipe(fds)) return g->sp[0] = putcharm(-errno), g;
 if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return close(fds[0]), close(fds[1]), g;   // OOM -> !ok
 struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                putcharm(fds[0]), putcharm(fds[1]));
 return g->sp[0] = word(w), g; }
static lvm(lvm_pipe) {
 Pack(g); g = host_pipe(g);
 if (!ai_ok(g)) return ghelp(g);
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

ai_noinline static struct ai *host_spawnio(struct ai *g, int in, int out, int err,
                                            intptr_t pg, intptr_t fg) {
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
  if (pg >= 0) {
   setpgid(0, (pid_t) pg);                     // 0 leads a fresh group, >0 joins it
   if (fg) { signal(SIGTTOU, SIG_IGN);          // the handoff, from the background
             tcsetpgrp(0, pg ? (pid_t) pg : getpid()); } }
  if (in  >= 0) dup2(in, 0);
  if (out >= 0) dup2(out, 1);
  if (err >= 0) dup2(err, 2);
  for (ai_word p = closes; chainp(p); p = B(p)) {
   intptr_t fd = getcharm(A(p));
   if (fd > 2) close((int) fd); }
  sig_dfl_job();                                // undo the shell's ignores (TTOU too)
  execvp(cav[0], cav);
  _exit(127); }
 if (pg >= 0) setpgid(pid, (pid_t) (pg ? pg : pid));   // parent side too: no race window
 return ai_push(g, 1, putcharm(pid)); }

static lvm(lvm_spawnio) {
 int in  = (Sp[1] & 1) ? (int) getcharm(Sp[1]) : -1;
 int out = (Sp[2] & 1) ? (int) getcharm(Sp[2]) : -1;
 int err = (Sp[3] & 1) ? (int) getcharm(Sp[3]) : -1;
 intptr_t pg = (Sp[5] & 1) ? getcharm(Sp[5]) : -1;
 intptr_t fg = (Sp[6] & 1) ? getcharm(Sp[6]) : 0;
 Pack(g);
 g = host_spawnio(g, in, out, err, pg, fg);  // argv at sp[0], closes at sp[4]
 if (!ai_ok(g)) return ghelp(g);
 Unpack(g);
 Sp[7] = Sp[0];                              // pid over the 7 args
 Sp += 7; Ip += 1;
 return Continue(); }

ai_noinline static ai_word host_posix_ttyfg(ai_word pgw) {
 pid_t pg = ((pgw & 1) && getcharm(pgw) > 0) ? (pid_t) getcharm(pgw) : getpgrp();
 return tcsetpgrp(0, pg) ? putcharm(errno) : ZeroPoint; }
static lvm(lvm_posix_ttyfg) { Sp[0] = host_posix_ttyfg(Sp[0]); return Ip++, Continue(); }

static lvm(lvm_shutfd) {
 intptr_t fd = (Sp[0] & 1) ? getcharm(Sp[0]) : -1;
 Sp[0] = (fd >= 0 && close((int) fd)) ? putcharm(-errno) : ZeroPoint;
 return Ip++, Continue(); }

// --- pid1 bringup: mount the early filesystems + cgroup dirs ----------------------
// (mkdir path mode) -> mkdir(2). () | -errno | -1 misuse. mode is octal (493 = 0755).
// also makes cgroup dirs (cgroup-v2 placement is then `open` + `say` the control file).
// (mount src tgt type) -> mount(2), flags 0 / no data (enough for proc/sysfs/tmpfs).
//   () | -errno | -1 misuse. needs privilege: run as pid1/root, or after (newns 0).
// (newns _) -> unshare a private USER+MOUNT namespace and selfmap to root-in-ns, so
//   (mount ...) works UNPRIVILEGED (the standard setgroups-deny + uid_map/gid_map).
//   () | -errno. a real pid1 skips this -- it already IS root.
// () on success, a POSITIVE errno on failure (so `!`/truthiness tells them apart --
// the pty/net convention; -errno would net falsey like the () success).
static lvm(lvm_mkdir) {
 char p[4096];
 if (!str_cbuf(Sp[0], p, sizeof p)) { Sp[1] = putcharm(EINVAL); Sp += 1; return Ip++, Continue(); }
 intptr_t mode = (Sp[1] & 1) ? getcharm(Sp[1]) : 0755;
 Sp[1] = mkdir(p, (mode_t) mode) ? putcharm(errno) : ZeroPoint;
 Sp += 1; return Ip++, Continue(); }

#if defined(__linux__)
ai_noinline static ai_word host_mount(ai_word a, ai_word b, ai_word c) {
 char src[1024], tgt[1024], typ[64];
 if (!str_cbuf(a, src, sizeof src) || !str_cbuf(b, tgt, sizeof tgt) || !str_cbuf(c, typ, sizeof typ))
  return putcharm(EINVAL);
 return mount(src, tgt, typ, 0, NULL) ? putcharm(errno) : ZeroPoint; }
static lvm(lvm_mount) { Sp[2] = host_mount(Sp[0], Sp[1], Sp[2]); Sp += 2; return Ip++, Continue(); }

static int ns_write(char const *path, char const *s) {
 int fd = open(path, O_WRONLY);
 if (fd < 0) return -1;
 ssize_t n = write(fd, s, strlen(s));
 return close(fd), (n < 0 ? -1 : 0); }
static lvm(lvm_newns) {
 long uid = (long) getuid(), gid = (long) getgid();
 if (unshare(CLONE_NEWUSER | CLONE_NEWNS)) { Sp[0] = putcharm(errno); return Ip++, Continue(); }
 char b[64];
 ns_write("/proc/self/setgroups", "deny");                       // required before gid_map
 snprintf(b, sizeof b, "0 %ld 1\n", uid); ns_write("/proc/self/uid_map", b);
 snprintf(b, sizeof b, "0 %ld 1\n", gid); ns_write("/proc/self/gid_map", b);
 Sp[0] = ZeroPoint; return Ip++, Continue(); }
#else
static lvm(lvm_mount) { Sp[2] = putcharm(ENOSYS); Sp += 2; return Ip++, Continue(); }   // Linux-only
static lvm(lvm_newns) { Sp[0] = putcharm(ENOSYS); return Ip++, Continue(); }
#endif

// --- the general POSIX fs surface (the posix_ symbol namespace; doc/posix.md L0,
// staging step 1) -- these serve any program, not just the supervisor, so their C
// symbols wear the posix_ prefix; the ai names stay the plain POSIX words.
// (stat path)    -> (size mtime mode) | () -- absence (or unreadability) is nothing.
//                   size in bytes, mtime in MILLISECONDS (the (clock t) scale), mode
//                   the raw st_mode charm: kind reads off the S_IFMT bits in ai
//                   ((& mode 61440): 32768 file, 16384 dir, 40960 link) and the
//                   permission bits ride along.
// (readdir path) -> the entry names, a list of strings ("." and ".." dropped), or ()
//                   on failure. NO order promised (readdir order, prepended) -- sort in ai.
// (unlink path)  -> () ok | a POSITIVE errno | EINVAL misuse (the mkdir convention:
//                   an effect op nets truthy exactly when something went wrong).
// (lseek fd off whence) -> the new offset | -errno | -1 misuse (the value-op
//                   convention: negative = failure, like spawn/wait). RAW fds, the
//                   openfd lane -- NOT ports (a port's read buffer would desync
//                   under a seek). whence: 0 SET, 1 CUR, 2 END.
ai_noinline static struct ai *host_posix_stat(struct ai *g) {
 char p[4096];
 struct stat st;
 if (!str_cbuf(g->sp[0], p, sizeof p) || stat(p, &st))
  return g->sp[0] = ZeroPoint, g;                             // absent -> the real ()
#if defined(__APPLE__)
 intptr_t ms = (intptr_t) st.st_mtimespec.tv_sec * 1000 + st.st_mtimespec.tv_nsec / 1000000;
#else
 intptr_t ms = (intptr_t) st.st_mtim.tv_sec * 1000 + st.st_mtim.tv_nsec / 1000000;
#endif
 if (!ai_ok(g = ai_have(g, 3 * Width(struct ai_chain)))) return g;
 struct ai_chain *c = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                putcharm((intptr_t) st.st_mode), ZeroPoint);
 c = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)), putcharm(ms), word(c));
 c = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
               putcharm((intptr_t) st.st_size), word(c));
 g->sp[0] = word(c);
 return g; }
static lvm(lvm_posix_stat) {
 Pack(g); g = host_posix_stat(g);
 if (!ai_ok(g)) return ghelp(g);
 Unpack(g);
 return Ip++, Continue(); }

ai_noinline static struct ai *host_posix_readdir(struct ai *g) {
 char p[4096];
 if (!str_cbuf(g->sp[0], p, sizeof p)) return g->sp[0] = ZeroPoint, g;
 DIR *d = opendir(p);
 if (!d) return g->sp[0] = ZeroPoint, g;
 g->sp[0] = ZeroPoint;                                        // the accumulator, over the path
 for (struct dirent *e; (e = readdir(d));) {
  if (e->d_name[0] == '.' && (!e->d_name[1] || (e->d_name[1] == '.' && !e->d_name[2])))
   continue;                                                  // "." and ".."
  if (!ai_ok(g = ai_strof(g, e->d_name))) return closedir(d), g;   // pushes: name over acc
  if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return closedir(d), g;
  struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 g->sp[0], g->sp[1]);         // (name . acc), slots re-read post-GC
  g->sp[1] = word(w);
  g->sp += 1; }                                               // pop the name
 closedir(d);
 return g; }
static lvm(lvm_posix_readdir) {
 Pack(g); g = host_posix_readdir(g);
 if (!ai_ok(g)) return ghelp(g);
 Unpack(g);
 return Ip++, Continue(); }

ai_noinline static ai_word host_posix_unlink(ai_word arg) {
 char p[4096];
 if (!str_cbuf(arg, p, sizeof p)) return putcharm(EINVAL);
 return unlink(p) ? putcharm(errno) : ZeroPoint; }
static lvm(lvm_posix_unlink) { Sp[0] = host_posix_unlink(Sp[0]); return Ip++, Continue(); }

// (setenv name val) -> () | positive errno | EINVAL misuse; a NON-STRING val UNSETS
// (the absence lane: (setenv n ()) clears n from the environment).
// (environ _)       -> the environment as a list of "NAME=value" strings (the raw
//                      POSIX shape -- split at the first '=' in ai; no order promised).
ai_noinline static ai_word host_posix_setenv(ai_word nw, ai_word vw) {
 char n[1024], v[4096];
 if (!str_cbuf(nw, n, sizeof n)) return putcharm(EINVAL);
 if (!ai_strp(vw)) return unsetenv(n) ? putcharm(errno) : ZeroPoint;
 if (!str_cbuf(vw, v, sizeof v)) return putcharm(EINVAL);
 return setenv(n, v, 1) ? putcharm(errno) : ZeroPoint; }
static lvm(lvm_posix_setenv) {
 Sp[1] = host_posix_setenv(Sp[0], Sp[1]);
 Sp += 1; return Ip++, Continue(); }

extern char **environ;
ai_noinline static struct ai *host_posix_environ(struct ai *g) {
 g->sp[0] = ZeroPoint;                                        // the accumulator, over the dummy arg
 for (char **e = environ; e && *e; e++) {
  if (!ai_ok(g = ai_strof(g, *e))) return g;                  // pushes: entry over acc
  if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
  struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 g->sp[0], g->sp[1]);
  g->sp[1] = word(w);
  g->sp += 1; }
 return g; }
static lvm(lvm_posix_environ) {
 Pack(g); g = host_posix_environ(g);
 if (!ai_ok(g)) return ghelp(g);
 Unpack(g);
 return Ip++, Continue(); }

ai_noinline static ai_word host_posix_lseek(ai_word fdw, ai_word offw, ai_word whw) {
 if (!(fdw & 1) || !(offw & 1)) return putcharm(-1);
 int wh = (whw & 1) ? (int) getcharm(whw) : 0;
 wh = wh == 1 ? SEEK_CUR : wh == 2 ? SEEK_END : SEEK_SET;
 off_t r = lseek((int) getcharm(fdw), (off_t) getcharm(offw), wh);
 return r < 0 ? putcharm(-errno) : putcharm((intptr_t) r); }
static lvm(lvm_posix_lseek) {
 Sp[2] = host_posix_lseek(Sp[0], Sp[1], Sp[2]);
 Sp += 2; return Ip++, Continue(); }

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
  nif_spawnio[] = {{lvm_cur}, {.x = putcharm(7)}, {lvm_spawnio}, {lvm_ret0}},
  nif_shutfd[]  = {{lvm_shutfd}, {lvm_ret0}},
  nif_mkdir[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_mkdir}, {lvm_ret0}},
  nif_mount[]   = {{lvm_cur}, {.x = putcharm(3)}, {lvm_mount}, {lvm_ret0}},
  nif_newns[]   = {{lvm_newns}, {lvm_ret0}},
  nif_posix_stat[]    = {{lvm_posix_stat}, {lvm_ret0}},
  nif_posix_readdir[] = {{lvm_posix_readdir}, {lvm_ret0}},
  nif_posix_unlink[]  = {{lvm_posix_unlink}, {lvm_ret0}},
  nif_posix_lseek[]   = {{lvm_cur}, {.x = putcharm(3)}, {lvm_posix_lseek}, {lvm_ret0}},
  nif_posix_signal[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_signal}, {lvm_ret0}},
  nif_posix_ttyfg[]   = {{lvm_posix_ttyfg}, {lvm_ret0}},
  nif_posix_setenv[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_setenv}, {lvm_ret0}},
  nif_posix_environ[] = {{lvm_posix_environ}, {lvm_ret0}};
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
AI_NIF("mkdir", nif_mkdir);
AI_NIF("mount", nif_mount);
AI_NIF("newns", nif_newns);
AI_NIF("stat",    nif_posix_stat);
AI_NIF("readdir", nif_posix_readdir);
AI_NIF("unlink",  nif_posix_unlink);
AI_NIF("lseek",   nif_posix_lseek);
AI_NIF("signal",  nif_posix_signal);
AI_NIF("ttyfg",   nif_posix_ttyfg);
AI_NIF("setenv",  nif_posix_setenv);
AI_NIF("environ", nif_posix_environ);
