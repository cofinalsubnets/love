// inle/posix.c -- the POSIX surface, in one place: process (spawn/reap/wait/signal, the
// pid-1 supervisor's primitives and the shell's job control), fs effects and values
// (stat/readdir/rename/chmod/..), the environment, pipes and raw-fd plumbing, and the pty
// wrapper. host-only, auto-globbed + LvNif-registered. the conventions, kept throughout:
//   effect ops answer () ok | 'enoent | 'badarg
//   value ops answer the value | () absence | 'enoent | 'badarg
// an errno set at the C level comes back as the nom naming it (ai_err reads the
// boot-interned vocabulary, so no error path allocates); a call refused before a syscall
// ran answers 'badarg, which is no posix name, so the two never shadow. ok is (), so !e
// reads "it worked" on an effect op and nom? e reads "it failed" on any op.
// the argv marshal lives beside the spawns that consume it; main.c wants it, not static.
#define _GNU_SOURCE     // unshare / CLONE_* (newns), posix_openpt/grantpt/unlockpt/ptsname
#include "love.h"
#include <unistd.h>     // fork execvp _exit read close getuid/getgid symlink readlink chown
#include <stdio.h>      // fflush, rename
#include <stdlib.h>     // setenv/unsetenv, posix_openpt grantpt unlockpt ptsname
#include <string.h>     // memcpy
#include <errno.h>
#include <signal.h>     // sigprocmask kill, SIGCHLD/SIGTERM (sigfd)
#include <fcntl.h>      // open, O_*, AT_FDCWD, FD_CLOEXEC
#include <sys/stat.h>   // mkdir, stat, chmod, umask, utimensat UTIME_NOW
#include <sys/wait.h>   // waitpid, WIF* (proc_status)
#include <sys/ioctl.h>  // ioctl TIOCSCTTY TIOC[GS]WINSZ struct winsize
#include <termios.h>    // tcgetattr tcsetattr ECHO TCSANOW (ptyecho, raw)
#include <dirent.h>     // opendir/readdir/closedir
#include <sys/mman.h>       // madvise (the spawn guard)
#include <sys/resource.h>   // getrusage, RUSAGE_SELF/CHILDREN (the cpu clocks)
#include <time.h>           // clock_gettime, for ai_clock

// --- what this libc carries, asked once -------------------------------------
// which doors a lane may call, not which kernel it stands on: ours carries every door on
// all three (apps/moon/include/sys), so these are build facts under __moonlibc__ and box
// facts under anything else. mount and unshare reach only linux, and os.c leaves their
// rows unmapped elsewhere, so the call refuses with ENOSYS at run time -- the only place
// that can know, one binary meeting three kernels; compiling them out by the build's
// kernel would refuse them on a linux box too.
#if defined(__moonlibc__)
# define LvHaveSignalfd 1
# define LvHaveKqueue   1
# define LvHaveSysctl   1
# define LvHaveDontfork 1
#elif defined(__linux__)
# define LvHaveSignalfd 1
# define LvHaveDontfork 1
#elif defined(__FreeBSD__) || defined(__NetBSD__)
# define LvHaveKqueue 1
# define LvHaveSysctl 1
#endif
#if defined(__moonlibc__) || defined(__linux__)
# define LvHaveMount      1
# define LvHaveNamespaces 1
# define LvHaveStatfs     1   // linux's struct; the BSDs carry the name over another shape
#endif

#if defined(LvHaveSignalfd)
#include <sys/signalfd.h>   // signalfd, struct signalfd_siginfo
#endif
#if defined(LvHaveKqueue)
#include <sys/event.h>      // kqueue/kevent, the signal port's BSD door
#endif
#if defined(LvHaveSysctl)
#include <sys/sysctl.h>     // the BSD selfpath doors (glibc dropped the symbol)
#endif
#if defined(LvHaveMount)
#include <sys/mount.h>      // mount(2), in linux's argument shape
#endif
#if defined(LvHaveNamespaces)
#include <sched.h>          // unshare, CLONE_NEWUSER/NEWNS (newns)
#endif
#if defined(LvHaveStatfs)
#include <sys/vfs.h>        // statfs(2), the block and inode counts df reports
#endif
// outside every guard: what follows is called unconditionally below (argv_marshal,
// sigtake, the pty pair), so one kernel's feature may not gate it.
// CLOCK_REALTIME in milliseconds -- the one scale for the scheduler's deadlines,
// (clock t), and every mtime. on inle it reads the kernel's kboot/kticks scale.
ai_noinline uintptr_t ai_clock(void) {
 struct timespec ts;
 return clock_gettime(CLOCK_REALTIME, &ts) ? (uintptr_t) -1 :
  (uintptr_t) (ts.tv_sec * 1000 + ts.tv_nsec / 1000000); }

// argv: the chain of strings at g->sp[0] -> a NUL-terminated char** laid in the
// uncommitted heap gap at Hp. GC-invisible, no l pointers, valid across a fork --
// host_spawn_guard leaves the window above hp mapped for exactly this, so what execvp
// reads must live here and not in the strings. consumed before any further allocation.
// *cavp is the vector or NULL; a misuse (non-string or empty argv) leaves g ok and a
// failed reserve leaves it not ok, and each caller says what a misuse answers.
struct ai *ai_argv_marshal(struct ai *g, char ***cavp) {
 *cavp = NULL;
 word argv = g->sp[0];
 uintptr_t argc = 0, total = 0;
 for (word p = argv; chainp(p); p = B(p)) {
  if (!strp(A(p))) return g;                              // misuse: non-string argv
  argc++, total += len(A(p)) + 1; }                          // +1 for the NUL
 if (!argc) return g;                                        // empty argv
 if (!ai_ok(g = ai_have(g, argc + 1 + b2w(total)))) return g;
 argv = g->sp[0];                            // ai_have may have GC'd; argv is the only
                                             // root, at sp[0], so it is forwarded there
 char **cav = (char**) g->hp,                                // at Hp: aligned
      *blob = (char*) (g->hp + (argc + 1));                  // whole words after
 uintptr_t off = 0, i = 0;
 for (word p = argv; chainp(p); p = B(p), i++) {
  struct ai_str *s = str(A(p));
  memcpy(blob + off, txt(s), len(s));
  blob[off + len(s)] = 0;
  cav[i] = blob + off;
  off += len(s) + 1; }
 cav[argc] = NULL;
 *cavp = cav;
 return g; }

// a wait(2) status word -> the exit code, 128+signal for a signalled death (the shell
// convention), or -1 for neither. the one copy every reaper here and hark (main.c) share.
static ai_inline int proc_status(int st) {
 return WIFEXITED(st) ? WEXITSTATUS(st)
       : WIFSIGNALED(st) ? 128 + WTERMSIG(st) : -1; }

// ai_port_fd: the live fd of a port arg, or -1 for a non-port. a closed port carries the
// -3 sentinel, handed straight to the syscall, which fails with EBADF.

// a love string as a C string, NULL for a non-string: bytes[len] is always a NUL
// (love/love.h), so the bytes go to the syscall where they lie; no length cap of ours.
static ai_inline char const *str_c(word x) { return strp(x) ? txt(x) : NULL; }

// ai_argv_marshal with the misuse answer added: called with g Packed, a misuse pushes
// 'badarg and leaves *cavp NULL, oom returns !ok g with *cavp NULL too, so
// `if (!*cavp) return g` covers both.
static struct ai *argv_marshal(struct ai *g, char ***cavp) {
 g = ai_argv_marshal(g, cavp);
 return !*cavp && ai_ok(g) ? ai_push(g, 1, ai_badarg(g)) : g; }

// --- the supervisor pair: spawn without waiting, reap any dead child ------------
// (spawn argv)  -> child pid (a fixnum) | a nom ('badarg misuse)
// (glean _)     -> (pid . status) of one reaped child
//                | ()                 none pending
//                | a nom              (e.g. 'echild: no children left)
// on a real pid1 glean also collects reparented orphans (waitpid(-1)).

// SIG_IGN survives exec, so a shell that ignores the job-control signals must undo that
// in every child between fork and exec -- or ^C could never kill what it launches.
// SIGPIPE rides this too: love ignores it, but a child that inherits the ignore is a
// `yes | head` that never stops. main.c's two exec sites reset it by hand.
static void sig_dfl_job(void) {
 signal(SIGINT, SIG_DFL); signal(SIGQUIT, SIG_DFL); signal(SIGPIPE, SIG_DFL);
 signal(SIGTSTP, SIG_DFL); signal(SIGTTIN, SIG_DFL); signal(SIGTTOU, SIG_DFL);
 // ..and the mask, which sigaction does not touch and exec does not clear: a signal a
 // shell blocks to watch it (sigfd) is inherited through the exec, leaving the child
 // deaf to ^C. every exec-bound child here leaves through this one door.
 sigset_t none; sigemptyset(&none); sigprocmask(SIG_SETMASK, &none, NULL); }

// (sigign? sig) -> 1 if this signal is SIG_IGN right now, else 0. POSIX: a signal ignored
// on entry to a non-interactive shell cannot be trapped or reset; `&` is how one arrives.
ai_noinline static word host_sigignp(word sigw) {
 struct sigaction sa;
 if (!charmp(sigw)) return putcharm(0);
 if (sigaction((int) getcharm(sigw), NULL, &sa)) return putcharm(0);
 return putcharm(sa.sa_handler == SIG_IGN ? 1 : 0); }
static lvm(lvm_sigignp) { Sp[0] = host_sigignp(Sp[0]); ai_musttail return Next(1); }

// (sigclear _) -> () -- empty this process's signal mask. the exec children get it
// from sig_dfl_job above; a shell's forked subshell never execs, so it asks here.
ai_noinline static word host_sigclear(struct ai *g) {
 sigset_t none; sigemptyset(&none);
 return sigprocmask(SIG_SETMASK, &none, NULL) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_sigclear) { Sp[0] = host_sigclear(g); ai_musttail return Next(1); }

// (spawn argv) -> the child pid, or the failure's nom, told apart by kind. fork + execvp;
// the parent returns at once, unlike run (waits + captures) and exec (replaces in place).
// the child inherits init's stdio; a failed exec _exit(127)s, seen by the next glean.
// spawn guard: the heap pools leave an exec-bound fork's inheritance, so fork copies no
// page tables for memory the child drops at once. scoped by the caller -- the (fork) nif
// and any child that walks the heap inherit whole. best-effort: an unaligned edge or a
// kernel without the advice keeps plain fork.
#if defined(LvHaveDontfork)
static void guard1(void *lo, void *hi, int adv) {
 uintptr_t a = ((uintptr_t) lo + 4095) & ~(uintptr_t) 4095,
           b = (uintptr_t) hi & ~(uintptr_t) 4095;
 if (b > a) (void) madvise((void*) a, (long) (b - a), adv); }
#endif
void host_spawn_guard(struct ai *g, int on) {
#if defined(LvHaveDontfork)
 int adv = on ? MADV_DONTFORK : MADV_DOFORK;
 // the ceiling is the frontier, not the block top: ai_argv_marshal lays the child's argv
 // at g->hp, so the window above hp stays mapped and is all execvp can still read.
 guard1(g, g->hp, adv);
 if (g->major_pool) guard1(g->major_pool, g->major_pool + 2 * g->major_len, adv);
#else
#endif
}

// the one fork + exec. argv rides at sp[0]; in/out/err are spawnio's fixed triple (-1: leave
// it), applied first; fdmap is a list of (childfd . srcfd) pairs and closes a list of fds,
// both read off the stack after the marshal (a GC may have moved them), -1 for none.
// pg >= 0 puts the child in that group (0: a fresh one it leads), fg hands it the terminal.
ai_noinline static struct ai *host_spawnx(struct ai *g, int in, int out, int err,
                                          int mapat, int closeat, intptr_t pg, intptr_t fg) {
 char **cav;
 g = argv_marshal(g, &cav);
 if (!cav) return g;                                         // misuse pushed -1, or oom
 word fdmap = mapat >= 0 ? g->sp[mapat] : ZeroPoint,
         closes = closeat >= 0 ? g->sp[closeat] : ZeroPoint;
 fflush(NULL);                                               // flush now, not twice in the child
 pid_t pid = fork();
 if (pid < 0) return ai_push(g, 1, ai_err(g, errno));
 if (!pid) {
  if (pg >= 0) {
   setpgid(0, (pid_t) pg);                     // 0 leads a fresh group, >0 joins it
   if (fg) { signal(SIGTTOU, SIG_IGN);          // the handoff, from the background
    tcsetpgrp(0, pg ? (pid_t) pg : getpid()); } }
  if (in  >= 0) dup2(in, 0);
  if (out >= 0) dup2(out, 1);
  if (err >= 0) dup2(err, 2);
  for (word p = fdmap; chainp(p); p = B(p)) {
   word e = A(p);
   if (!chainp(e)) continue;
   intptr_t cfd = charmp(A(e)) ? getcharm(A(e)) : -1;
   if (cfd < 0) continue;
   word sw = B(e);
   if (charmp(sw) && getcharm(sw) >= 0) dup2((int) getcharm(sw), (int) cfd);
   else close((int) cfd); }                    // () (or a negative) srcfd closes childfd
  for (word p = closes; chainp(p); p = B(p)) {
   intptr_t fd = getcharm(A(p));
   if (fd > 2) close((int) fd); }
  sig_dfl_job();                                // undo the shell's ignores (TTOU too)
  execvp(cav[0], cav);
  _exit(127); }                                 // seen by the next glean
 if (pg >= 0) setpgid(pid, (pid_t) (pg ? pg : pid));   // parent side too: no race window
 return ai_push(g, 1, putcharm(pid)); }                      // parent: the live pid

static lvm(lvm_spawn) {
 LvmCallp(g, 1, host_spawnx, -1, -1, -1, -1, -1, -1, 0) }   // pid over argv

// (glean _) -> (pid . status) of one reaped child, () if none are pending, or the
// failure's nom. the arg is a dummy, so a bare (glean) curries; call it (glean 0).
// off the wrappers' frames so their tails jump. leaves one net value at sp[0]: (), an
// errno nom, or the record -- (status) for a named pid, (pid . status) for a wildcard.
ai_noinline static struct ai *host_reap(struct ai *g, pid_t pid) {
 int st;
 pid_t r = waitpid(pid, &st, WNOHANG);
 if (r == 0) { g->sp[0] = ZeroPoint; return g; }
 if (r < 0)  { g->sp[0] = ai_err(g, errno); return g; }
 if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
 word status = putcharm(proc_status(st));
 struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                pid < 0 ? putcharm(r) : status,
                                pid < 0 ? status : ZeroPoint);   // a real ()-tailed list, not the charm-0 fossil
 g->sp[0] = word(w);
 return g; }

static lvm(lvm_reapany) {
 LvmCall(g, host_reap, -1) }

// --- the signal perceive source (signalfd; kqueue on the BSDs) ------------------
// (sigfd sigs)  -> a port over a signalfd watching `sigs` (a list of signal numbers; a
//                  non-list keeps the supervisor default SIGCHLD + SIGTERM), those signals
//                  first blocked so they queue to the fd instead of their default
//                  disposition -- which is what turns a TERM into an event, not a death.
//                  a nom on failure. SIGINT is left unblocked so ^C bails.
// (sigtake port) -> (signo . pid) of one pending signal, or () if none ready.
// SIGCHLD coalesces, so a 'chld wake still loops `glean` to harvest every zombie.
#if defined(LvHaveSignalfd) || defined(LvHaveKqueue)
#if defined(LvHaveKqueue)
// the BSD door: the port holds a kqueue fd instead. EVFILT_SIGNAL fires on send, before
// delivery, so the same blocked mask queues here too. one kernel per process, so a flag.
static int host_sigkq;
ai_noinline static int host_sigfd_kq(word a) {
 int kq = kqueue();
 if (kq < 0) return -1;
 struct kevent ch;
 if (chainp(a))
  for (word p = a; chainp(p); p = B(p)) {
   if (!charmp(A(p))) continue;
   EV_SET(&ch, getcharm(A(p)), EVFILT_SIGNAL, EV_ADD, 0, 0, 0);
   if (kevent(kq, &ch, 1, 0, 0, 0) < 0) return close(kq), -1; }
 else {
  EV_SET(&ch, SIGCHLD, EVFILT_SIGNAL, EV_ADD, 0, 0, 0);
  if (kevent(kq, &ch, 1, 0, 0, 0) < 0) return close(kq), -1;
  EV_SET(&ch, SIGTERM, EVFILT_SIGNAL, EV_ADD, 0, 0, 0);
  if (kevent(kq, &ch, 1, 0, 0, 0) < 0) return close(kq), -1; }
 fcntl(kq, F_SETFD, FD_CLOEXEC);
 host_sigkq = 1;
 return kq; }
#endif
// a list of signal numbers to watch; anything else keeps SIGCHLD + SIGTERM.
ai_noinline static struct ai *host_sigfd(struct ai *g) {
 sigset_t m;
 sigemptyset(&m);
 word a = g->sp[0];
 if (chainp(a))
  for (word p = a; chainp(p); p = B(p)) {
  if charmp(A(p)) sigaddset(&m, (int) getcharm(A(p))); }
 else { sigaddset(&m, SIGCHLD); sigaddset(&m, SIGTERM); }
 if (sigprocmask(SIG_BLOCK, &m, NULL)) return g->sp[0] = ai_err(g, errno), g;
 // the canonical door, then the BSD one where it answers -- the try is the probe.
 int fd = -1;
#if defined(LvHaveSignalfd)
 fd = signalfd(-1, &m, SFD_NONBLOCK | SFD_CLOEXEC);
#endif
#if defined(LvHaveKqueue)
 if (fd < 0) fd = host_sigfd_kq(a);          // ENOSYS: a BSD kernel; kqueue is the body
#endif
 if (fd < 0) return g->sp[0] = ai_err(g, errno), g;
 struct ai *r = ai_io_alloc(g, fd);
 if (!ai_ok(r)) return close(fd), g->sp[0] = ai_err(g, ENOMEM), g;
 g = r;
 return g->sp[1] = g->sp[0], g->sp += 1, g; }                 // port over the dummy arg
static lvm(lvm_sigfd) {
 Pack(g); g = host_sigfd(g); Unpack(g);     // host_sigfd folds every failure to (), so no ghelp
 ai_musttail return Next(1); }

// read one pending signal (non-blocking) into (signo . pid). signo is the raw canonical
// number; pid is ssi_pid -- except the kqueue lane, which names no sender: pid 0 there.
ai_noinline static struct ai *host_sigtake(struct ai *g, int fd) {
 intptr_t signo, pid;
#if defined(LvHaveKqueue)
 if (host_sigkq) {
  struct kevent ev;
  struct timespec z = {0, 0};
  int k = kevent(fd, 0, 0, &ev, 1, &z);
  if (k < 0)  { g->sp[0] = ai_err(g, errno); return g; }
  if (k != 1) { g->sp[0] = ZeroPoint; return g; }              // none ready
  signo = (intptr_t) ev.ident; pid = 0; }
 else
#endif
 {
#if defined(LvHaveSignalfd)
  struct signalfd_siginfo si;
  ssize_t n = read(fd, &si, sizeof si);
  if (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {      // EAGAIN is absence, not failure
   g->sp[0] = ai_err(g, errno); return g; }
  if (n != (ssize_t) sizeof si) { g->sp[0] = ZeroPoint; return g; }  // none ready
  signo = (intptr_t) si.ssi_signo; pid = (intptr_t) si.ssi_pid;
#else
  g->sp[0] = ai_err(g, ENOSYS); return g;   // no canonical door: the kq lane above is the only one
#endif
 }
 if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
 struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                putcharm(signo), putcharm(pid));
 g->sp[0] = word(w);
 return g; }

static lvm(lvm_sigtake) {
 int fd = (int) ai_port_fd(Sp[0]);
 if (fd < 0) { Sp[0] = ai_badarg(g); ai_musttail return Next(1); }
 LvmCall(g, host_sigtake, fd) }
#else
// a libc with neither door; keep the names present (so init.l loads) but refusing.
static lvm(lvm_sigfd)   { Sp[0] = ai_err(g, ENOSYS); ai_musttail return Next(1); }
static lvm(lvm_sigtake) { Sp[0] = ai_err(g, ENOSYS); ai_musttail return Next(1); }
#endif

// --- foreground job control + cwd (the muscle a real shell needs) ---------------
// (wait pid)   -> block until pid exits or stops: an exit is its proc_status (exit /
//                 128+sig), a stop (^Z) is 256 + the stopping signal -- a charm above
//                 every exit status, so a shell tells "stopped" from "done".
// (signal sig disp) -> sigaction: disp 0 = default, 1 = ignore. () | a nom | 'badarg.
//                 the shell ignores INT/QUIT/TSTP so the tty's ^C/^Z reach only the
//                 foreground child; spawn's child side resets them.
// (chdir path) -> () ok | a nom | 'badarg misuse. the `cd` builtin.
// (cwd _)      -> the current directory as a string, or a nom on failure. for the prompt.
// the syscall body lives in an ai_noinline helper so the lvm_ wrapper stays a pure
// tail-jump: a stack buffer would block the sibcall to Continue() and trip `make vmret`.
// WNOHANG, and () means "still running" -- a real answer is a charm status or a nom, so
// the zero point is free to carry that fourth term and no sentinel is overloaded.
ai_noinline static word host_waitpid(struct ai *g, word arg) {
 intptr_t pid = charmp(arg) ? getcharm(arg) : 0;
 int st;
 pid_t r;
 do r = waitpid((pid_t) pid, &st, WUNTRACED | WNOHANG); while (r < 0 && errno == EINTR);
 if (!r) return ZeroPoint;                                   // alive, neither exited nor stopped
 if (r < 0) return ai_err(g, errno);
 if (WIFSTOPPED(st)) return putcharm(256 + WSTOPSIG(st));
 return putcharm(proc_status(st)); }
// (wait pid) parks rather than blocks: a live child re-arms the task for the next tick and
// yields, so a peer task runs while a foreground job is up -- a poll, one waitpid per
// millisecond per waiter. nothing is consumed before the park, so the op re-runs whole.
static lvm(lvm_waitpid) {
 word r = host_waitpid(g, Sp[0]);
 if (r == ZeroPoint) { g->next_wake_at = ai_clock() + 1; ai_musttail return Ap(lvm_yield_sw, g); }
 Sp[0] = r; ai_musttail return Next(1); }

ai_noinline static word host_posix_signal(struct ai *g, word sigw, word dw) {
 if (!charmp(sigw) || !charmp(dw)) return ai_badarg(g);
 struct sigaction sa;
 memset(&sa, 0, sizeof sa);
 sa.sa_handler = getcharm(dw) ? SIG_IGN : SIG_DFL;
 sigemptyset(&sa.sa_mask);
 return sigaction((int) getcharm(sigw), &sa, NULL) ? ai_err(g, errno) : ZeroPoint; }

static lvm(lvm_posix_signal) {
 Sp[1] = host_posix_signal(g, Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }

// a host inlines into its wrapper unless its frame holds a buffer or an address-taken
// local -- those stay ai_noinline, off the frame the musttail has to leave behind
static ai_inline word host_chdir(struct ai *g, word arg) {
 char const *buf = str_c(arg);
 if (!buf) return ai_badarg(g);
 return chdir(buf) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_chdir) { Sp[0] = host_chdir(g, Sp[0]); ai_musttail return Next(1); }

ai_noinline static struct ai *host_cwd(struct ai *g) {
 char buf[4096];
 if (!getcwd(buf, sizeof buf)) return g->sp[0] = ai_err(g, errno), g;
 if (!ai_ok(g = ai_strof(g, buf))) return g;            // oom -> !ok, wrapper ghelps
 return g->sp[1] = g->sp[0], g->sp += 1, g; }           // cwd string over the dummy arg
static lvm(lvm_cwd) {
 LvmCall(g, host_cwd) }

// (selfpath _) -> the path of the running binary, or () where the seat cannot say.
// no argv[0] fallback: a bare `cmdline` read from baked code folds to the bake's line,
// and the callers here are baked, so the operand would arrive already wrong.
ai_noinline size_t host_selfpath(char *b, size_t n) {
 // a runtime ladder, one binary meeting more than one kernel: linux's link, netbsd's
 // spelling of it, then freebsd's sysctl door -- each try answers only on its kernel.
 ssize_t r = readlink("/proc/self/exe", b, n - 1);
 if (r <= 0) r = readlink("/proc/curproc/exe", b, n - 1);
 if (r > 0) {
  b[r] = 0;
  // the suffix is the kernel's, not the path's: once our inode is unlinked the link reads
  // "PATH (deleted)" and every later open or rename names a file that is not there.
  size_t dl = sizeof " (deleted)" - 1;
  if ((size_t) r > dl && !memcmp(b + (size_t) r - dl, " (deleted)", dl))
   r -= (ssize_t) dl, b[r] = 0;
  return (size_t) r; }
#if defined(LvHaveSysctl)
 // ours always links sysctl (ENOSYS off the BSDs); glibc dropped the symbol,
 // and that build is the linux bootstrap scaffold -- /proc answered above.
 int mib[4] = { 1, 14, 12, -1 };                       // freebsd: CTL_KERN KERN_PROC KERN_PROC_PATHNAME(-1)
 size_t sz = n;
 if (!sysctl(mib, 4, b, &sz, NULL, 0) && sz) return strlen(b);
 int nmib[4] = { 1, 48, -1, 5 };                       // netbsd: KERN_PROC_ARGS(pid=-1) KERN_PROC_PATHNAME
 sz = n;
 if (!sysctl(nmib, 4, b, &sz, NULL, 0) && sz) return strlen(b);
#endif
 return 0; }

ai_noinline static struct ai *host_selfpath_ap(struct ai *g) {
 char buf[4096];
 if (!host_selfpath(buf, sizeof buf)) return g->sp[0] = ZeroPoint, g;
 if (!ai_ok(g = ai_strof(g, buf))) return g;
 return g->sp[1] = g->sp[0], g->sp += 1, g; }
static lvm(lvm_selfpath) {
 LvmCall(g, host_selfpath_ap) }

// --- pipes + redirects (the fd plumbing a shell pipeline needs) ------------------
// (pipe _)       -> (readfd . writefd) of a fresh pipe (raw fds), or a nom.
// (openfd path m) -> a raw fd opening `path`: m 0 = read, 1 = write/create/trunc,
//                   2 = write/create/append, 3 = write/create/EXCL at mode 0600 -- the one
//                   that fails on an existing name. a nom on failure, 'badarg on a bad path.
// (spawnio argv in out err closes pg fg) -> pid | a nom. fork; in the child, the
//                   job-control dance first -- pg < 0 stays in the parent's pgrp (the
//                   non-tty lane), pg = 0 leads a fresh group, pg > 0 joins that group
//                   (pipeline members join their stage-0 leader) -- and fg nonzero hands
//                   the child's group the terminal (tcsetpgrp on fd 0 before the dup2s,
//                   TTOU ignored for the handoff; the parent setpgids too, closing the
//                   race). a job in its own pgrp is what makes ^Z real: POSIX discards a
//                   stop signal sent to an orphaned group, and the shell's own group is
//                   that under a nested session. then dup2 `in`/`out`/`err` (each >=0)
//                   onto 0/1/2, close every fd in `closes` (the pipe ends the child must
//                   not leak, so a downstream reader sees EOF), reset the job signals,
//                   execvp. the parent closes its own pipe ends with `close`.
// (ttyfg pg)     -> give the terminal (fd 0) to process group pg; pg <= 0 takes it back
//                   to the caller's own group. () | a nom.
ai_noinline static struct ai *host_pipe(struct ai *g) {
 int fds[2];
 if (pipe(fds)) return g->sp[0] = ai_err(g, errno), g;
 if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return close(fds[0]), close(fds[1]), g;   // oom -> !ok
 struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                putcharm(fds[0]), putcharm(fds[1]));
 return g->sp[0] = word(w), g; }
static lvm(lvm_pipe) {
 LvmCall(g, host_pipe) }

static lvm(lvm_openfd) {
 char const *buf = str_c(Sp[0]);
 if (!buf) { Sp[1] = ai_badarg(g); Sp += 1; ai_musttail return Next(1); }
 intptr_t m = charmp(Sp[1]) ? getcharm(Sp[1]) : 0;
 int flags = m == 1 ? (O_WRONLY | O_CREAT | O_TRUNC)
           : m == 2 ? (O_WRONLY | O_CREAT | O_APPEND)
           : m == 3 ? (O_WRONLY | O_CREAT | O_EXCL)
           : O_RDONLY,
     fd = open(buf, flags, m == 3 ? 0600 : 0644);
 Sp[1] = (fd < 0) ? ai_err(g, errno) : putcharm(fd);
 ai_musttail return Nextp(1, 1); }

static lvm(lvm_spawnio) {
 int in  = charmp(Sp[1]) ? (int) getcharm(Sp[1]) : -1,
     out = charmp(Sp[2]) ? (int) getcharm(Sp[2]) : -1,
     err = charmp(Sp[3]) ? (int) getcharm(Sp[3]) : -1;
 intptr_t pg = charmp(Sp[5]) ? getcharm(Sp[5]) : -1,
          fg = charmp(Sp[6]) ? getcharm(Sp[6]) : 0;
 LvmCallp(g, 7, host_spawnx, in, out, err, -1, 4, pg, fg) }   // argv at sp[0], closes at sp[4]; pid over the 7 args

ai_noinline static word host_posix_ttyfg(struct ai *g, word pgw) {
 pid_t pg = (charmp(pgw) && getcharm(pgw) > 0) ? (pid_t) getcharm(pgw) : getpgrp();
 return tcsetpgrp(0, pg) ? ai_err(g, errno) : ZeroPoint; }

static lvm(lvm_posix_ttyfg) {
  Sp[0] = host_posix_ttyfg(g, Sp[0]);
  ai_musttail return Next(1); }

// (fdopen fd) -> a port over a raw fd -- pipe/openfd's other half. 'badarg on a non-charm
// or negative fd. the port's GC finalizer owns the fd from here: do not also close it.
static lvm(lvm_fdopen) {
 intptr_t fd = charmp(Sp[0]) ? getcharm(Sp[0]) : -1;
 if (fd < 0) ai_musttail return Answer(ai_badarg(g));
 LvmCallp(g, 1, ai_io_alloc, (int) fd) }   // port over the fd arg -- alloc pushed it

// (spawnmap argv fdmap closes pg fg) -> pid | a nom. spawnio with `fdmap`, a list of
// (childfd . srcfd) pairs applied in order in the child -- dup2(srcfd, childfd) for a
// charm srcfd >= 0, close(childfd) for () -- each srcfd reading the fd table as remapped
// so far, the POSIX left-to-right redirection law (`>f 2>&1` is ((1 . f) (2 . 1)) and the
// second entry sees the first's work). pg/fg and closes ride unchanged from spawnio.
static lvm(lvm_spawnmap) {
 intptr_t pg = charmp(Sp[3]) ? getcharm(Sp[3]) : -1,
          fg = charmp(Sp[4]) ? getcharm(Sp[4]) : 0;
 LvmCallp(g, 5, host_spawnx, -1, -1, -1, 1, 2, pg, fg) }   // argv at sp[0], fdmap sp[1], closes sp[2]; pid over the 5 args

// (getuid _) -> the real uid, a charm; always succeeds. (getgid _) -> the real gid, its
// pair -- `id` owes the primary group as a fact, not as the /etc/passwd row's guess.
static lvm(lvm_getuid) { Sp[0] = putcharm(getuid()); ai_musttail return Next(1); }
static lvm(lvm_getgid) { Sp[0] = putcharm(getgid()); ai_musttail return Next(1); }

// (fork _) -> child pid | 0 in the child | a nom. fork without exec, the shell's subshell:
// the child evals a subtree and quits, and must never return to the reader loop. the
// discipline is all in the caller -- flush out/err before, child = eval+quit.
static ai_inline word host_fork(struct ai *g) {
 fflush(NULL);
 pid_t pid = fork();
 return pid < 0 ? ai_err(g, errno) : putcharm(pid); }
static lvm(lvm_fork) { Sp[0] = host_fork(g); ai_musttail return Next(1); }

// (dup2 src dst) -> () | a nom | 'badarg. the self-redirect.
// (dup fd) -> a fresh fd duplicating fd (>= 3, clear of stdio) | a nom. the save half.
static ai_inline word host_dup2(struct ai *g, word sw, word dw) {
 return !charmp(sw) || !charmp(dw) ? ai_badarg(g) :
        dup2((int) getcharm(sw), (int) getcharm(dw)) < 0 ? ai_err(g, errno) :
        ZeroPoint; }

static lvm(lvm_dup2) { Sp[1] = host_dup2(g, Sp[0], Sp[1]); Sp += 1; ai_musttail return Next(1); }

static ai_inline word host_dup(struct ai *g, word w) {
 if (!charmp(w)) return ai_badarg(g);
 int fd = fcntl((int) getcharm(w), F_DUPFD, 3);
 return fd < 0 ? ai_err(g, errno) : putcharm(fd); }

static lvm(lvm_dup) { Sp[0] = host_dup(g, Sp[0]); ai_musttail return Next(1); }

// --- pid1 bringup: mount the early filesystems + cgroup dirs ----------------------
// (mkdir path mode) -> mkdir(2). () | a nom | 'badarg misuse. mode is octal (493 = 0755).
// (mount src tgt type) -> mount(2), flags 0 / no data (enough for proc/sysfs/tmpfs).
//   () | a nom | 'badarg misuse. needs privilege: run as pid1/root, or after (newns 0).
// (newns _) -> unshare a private user+mount namespace and selfmap to root-in-ns, so
//   (mount ...) works unprivileged. () | a nom. a real pid1 skips this, being root.
static lvm(lvm_mkdir) {
 char const *p = str_c(Sp[0]);
 if (!p) { Sp[1] = ai_badarg(g); Sp += 1; ai_musttail return Next(1); }
 intptr_t mode = charmp(Sp[1]) ? getcharm(Sp[1]) : 0755;
 Sp[1] = mkdir(p, (mode_t) mode) ? ai_err(g, errno) : ZeroPoint;
 ai_musttail return Nextp(1, 1); }

#if defined(LvHaveMount)
static ai_inline word host_mount(struct ai *g, word a, word b, word c) {
 char const *src = str_c(a), *tgt = str_c(b), *typ = str_c(c);
 if (!src || !tgt || !typ) return ai_badarg(g);
 return mount(src, tgt, typ, 0, NULL) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_mount) { Sp[2] = host_mount(g, Sp[0], Sp[1], Sp[2]); Sp += 2; ai_musttail return Next(1); }
// (mountf src tgt type flags) -> () | a nom. the same call carrying linux's MS_ word (ro,
// bind, remount, the nosuid family). it stands beside mount because a nif's arity is fixed
// and apps/init/boot.l calls the three-argument one. the data argument stays NULL, so an
// -o that is filesystem text rather than a flag (tmpfs's size=) is refused by name.
static ai_inline word host_mountf(struct ai *g, word a, word b, word c, word f) {
 char const *src = str_c(a), *tgt = str_c(b), *typ = str_c(c);
 if (!src || !tgt || !typ) return ai_badarg(g);
 return mount(src, tgt, typ, (unsigned long) getcharm(f), NULL) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_mountf) {
  Sp[3] = host_mountf(g, Sp[0], Sp[1], Sp[2], Sp[3]); Sp += 3; ai_musttail return Next(1); }
// (umount tgt) -> () | a nom. linux's umount2 at flags 0; freebsd spells it unmount with
// another shape, so it rides mount's guard.
static lvm(lvm_umount) {
  char const *t = str_c(Sp[0]);
  Sp[0] = !t ? ai_badarg(g) : (umount(t) ? ai_err(g, errno) : ZeroPoint);
  ai_musttail return Next(1); }
#else
// the call is there; our mount speaks a shape this kernel does not answer.
static lvm(lvm_mount) { Sp[2] = ai_err(g, ENOSYS); Sp += 2; ai_musttail return Next(1); }
static lvm(lvm_mountf) { Sp[3] = ai_err(g, ENOSYS); Sp += 3; ai_musttail return Next(1); }
static lvm(lvm_umount) { Sp[0] = ai_err(g, ENOSYS); ai_musttail return Next(1); }
#endif

// (chroot dir) -> () | a nom. needs privilege and says so through errno like any other
// row -- 'eperm is an answer, not a crash.
static lvm(lvm_chroot) {
  char const *p = str_c(Sp[0]);
  Sp[0] = !p ? ai_badarg(g) : (chroot(p) ? ai_err(g, errno) : ZeroPoint);
  ai_musttail return Next(1); }

// (sync _) -> (). sync(2) answers nothing and cannot fail -- the kernel schedules
// the writeback and returns -- so this is the one effect op here with no errno lane.
static lvm(lvm_sync) { sync(); Sp[0] = ZeroPoint; ai_musttail return Next(1); }

// (mknod path mode dev) -> () | a nom. mode carries the type bits (S_IFIFO, S_IFCHR,
// S_IFBLK) as well as the permissions, as mknod(2) takes them; dev is the encoded device
// number, ignored for a fifo. mkfifo is this call with S_IFIFO and dev 0, not a second nif.
static lvm(lvm_mknod) {
  char const *p = str_c(Sp[0]);
  intptr_t mode = getcharm(Sp[1]), dev = getcharm(Sp[2]);
  Sp[2] = !p ? ai_badarg(g)
             : (mknod(p, (mode_t) mode, (dev_t) dev) ? ai_err(g, errno) : ZeroPoint);
  Sp += 2; ai_musttail return Next(1); }

#if defined(LvHaveNamespaces)
static int ns_write(char const *path, char const *s) {
 int fd = open(path, O_WRONLY);
 if (fd < 0) return -1;
 ssize_t n = write(fd, s, strlen(s));
 return close(fd), (n < 0 ? -1 : 0); }
static lvm(lvm_newns) {
 long uid = (long) getuid(), gid = (long) getgid();
 if (unshare(CLONE_NEWUSER | CLONE_NEWNS)) {
   Sp[0] = ai_err(g, errno);
   ai_musttail return Next(1); }
 char b[64];
 ns_write("/proc/self/setgroups", "deny");                       // required before gid_map
 snprintf(b, sizeof b, "0 %ld 1\n", uid); ns_write("/proc/self/uid_map", b);
 snprintf(b, sizeof b, "0 %ld 1\n", gid); ns_write("/proc/self/gid_map", b);
 Sp[0] = ZeroPoint;
 ai_musttail return Next(1); }
#else
// a linux mechanism; elsewhere the name stands and refuses.
static lvm(lvm_newns) { Sp[0] = ai_err(g, ENOSYS); ai_musttail return Next(1); }
#endif

// --- the general POSIX fs surface -- these serve any program, not just the supervisor,
// so their C symbols wear the posix_ prefix; the love names stay the plain POSIX words.
// (stat path|fd) -> (size mtime mode ns uid gid nlink blocks ino atime ctime dev rdev
//                   blksize) | a nom ('enoent absent, 'eacces unreadable, ..) | 'badarg.
//                   a charm is an open fd and the answer is fstat's, the tuple the same.
//                   size in bytes, mtime in milliseconds (the (clock t) scale), mode the
//                   raw st_mode charm (love reads the S_IFMT bits itself: (& mode 61440)
//                   is 32768 file, 16384 dir, 40960 link); ns is that mtime whole in
//                   nanoseconds, one charm to year 2262, so two writes in one millisecond
//                   still order (cook). blocks is st_blocks, 512-byte units -- disk usage
//                   and not the size, so a sparse file says less than it is. atime and
//                   ctime ride in nanoseconds; dev is the filesystem the file is on and
//                   rdev the device a node names (0 for everything else), both the
//                   kernel's packed word, which love splits into major and minor itself;
//                   blksize is the io block a write wants to be a multiple of.
//                   the tail is append-only and a reader asks `tally` before it reads
//                   past ns: the kernel's own stat (inle/kmain.c) answers the first four.
// (lstat path)   -> the same tuple, of the link itself where the path names one -- du and
//                   `stat` owe the link's own blocks and mode. on a charm it is `stat`.
// (readdir path) -> the entry names, a list of strings ("." and ".." dropped); an empty
//                   directory is (), told from every failure by kind: a nom | 'badarg.
//                   no order promised (readdir order, prepended) -- sort in love.
// (unlink path)  -> () ok | a nom | 'badarg misuse.
// (lseek fd off whence) -> the new offset | a nom | 'badarg misuse. raw fds, the openfd
//                   lane -- not ports (a port's read buffer would desync under a seek).
//                   whence: 0 SET, 1 CUR, 2 END, a stranger 'einval and not a quiet SET.
ai_noinline static struct ai *host_stat_tuple(struct ai *g, int follow) {
 word x = g->sp[0];
 struct stat st;
 if (charmp(x)) {
  if (getcharm(x) < 0) return g->sp[0] = ai_badarg(g), g;
  if (fstat((int) getcharm(x), &st)) return g->sp[0] = ai_err(g, errno), g; }
 else {
  char const *p = str_c(x);
  if (!p) return g->sp[0] = ai_badarg(g), g;
  if (follow ? stat(p, &st) : lstat(p, &st)) return g->sp[0] = ai_err(g, errno), g; }
 intptr_t ms = (intptr_t) st.st_mtim.tv_sec * 1000 + st.st_mtim.tv_nsec / 1000000,
          ns = (intptr_t) st.st_mtim.tv_sec * 1000000000 + st.st_mtim.tv_nsec,
          as = (intptr_t) st.st_atim.tv_sec * 1000000000 + st.st_atim.tv_nsec,
          cs = (intptr_t) st.st_ctim.tv_sec * 1000000000 + st.st_ctim.tv_nsec;
 if (!ai_ok(g = ai_have(g, 14 * Width(struct ai_chain)))) return g;
 size_t const C = Width(struct ai_chain);
 struct ai_chain *c = ini_chain(bump(g, C), putcharm(st.st_blksize), ZeroPoint);
 c = ini_chain(bump(g, C), putcharm((intptr_t) st.st_rdev), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) st.st_dev), word(c));
 c = ini_chain(bump(g, C), putcharm(cs), word(c));
 c = ini_chain(bump(g, C), putcharm(as), word(c));
 c = ini_chain(bump(g, C), putcharm(st.st_ino), word(c));
 c = ini_chain(bump(g, C), putcharm(st.st_blocks), word(c));
 c = ini_chain(bump(g, C), putcharm(st.st_nlink), word(c));
 c = ini_chain(bump(g, C), putcharm(st.st_gid), word(c));
 c = ini_chain(bump(g, C), putcharm(st.st_uid), word(c));
 c = ini_chain(bump(g, C), putcharm(ns), word(c));
 c = ini_chain(bump(g, C), putcharm(st.st_mode), word(c));
 c = ini_chain(bump(g, C), putcharm(ms), word(c));
 c = ini_chain(bump(g, C), putcharm(st.st_size), word(c));
 return g->sp[0] = word(c), g; }

ai_inline static struct ai *host_posix_stat(struct ai *g) {
 return host_stat_tuple(g, 1); }
ai_inline static struct ai *host_posix_lstat(struct ai *g) {
 return host_stat_tuple(g, 0); }

static lvm(lvm_posix_lstat) {
 LvmCall(g, host_posix_lstat) }

static lvm(lvm_posix_stat) {
 LvmCall(g, host_posix_stat) }

// (statfs path) -> (bsize blocks bfree bavail files ffree frsize) | a nom | 'badarg.
//                  what the filesystem holding the path has, in blocks of frsize (bsize
//                  where a kernel leaves frsize at 0). bavail is what an ordinary user may
//                  take and sits under bfree by the reserve root keeps. files/ffree are
//                  the inode counts, 0 where the filesystem has none. linux's shape alone:
//                  the BSDs spell the call over another struct, so a BSD hears 'enosys.
#if defined(LvHaveStatfs)
ai_noinline static struct ai *host_posix_statfs(struct ai *g) {
 char const *p = str_c(g->sp[0]);
 if (!p) return g->sp[0] = ai_badarg(g), g;
 struct statfs fs;
 if (statfs(p, &fs)) return g->sp[0] = ai_err(g, errno), g;
 if (!ai_ok(g = ai_have(g, 7 * Width(struct ai_chain)))) return g;
 size_t const C = Width(struct ai_chain);
 struct ai_chain *c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_frsize), ZeroPoint);
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_ffree), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_files), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_bavail), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_bfree), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_blocks), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_bsize), word(c));
 return g->sp[0] = word(c), g; }
#else
ai_noinline static struct ai *host_posix_statfs(struct ai *g) {
 return g->sp[0] = ai_err(g, ENOSYS), g; }
#endif
static lvm(lvm_posix_statfs) {
 LvmCall(g, host_posix_statfs) }

// (birth path follow) -> the file's creation time in nanoseconds | () where the filesystem
//                  keeps none | a nom | 'badarg. no struct stat here has a seat for one,
//                  so __ai_birth reads the BSDs' own stat and linux's statx. its own call
//                  and not a fifteenth seat in the stat tuple, which du and ls walk a
//                  million times a tree.
#if defined(__moonlibc__)
ai_noinline static word host_posix_birth(struct ai *g, word pw, word fw) {
 char const *p = str_c(pw);
 if (!p) return ai_badarg(g);
 struct timespec b;
 int r = __ai_birth(p, charmp(fw) && getcharm(fw), &b);
 return r < 0 ? ai_err(g, errno)
      : r     ? ZeroPoint
      : putcharm((intptr_t) b.tv_sec * 1000000000 + b.tv_nsec); }
static lvm(lvm_posix_birth) {
 Sp[1] = host_posix_birth(g, Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }
#else
// moonlibc is where the three kernels are known; love0 is not it. the name stands, refusing.
static lvm(lvm_posix_birth) { Sp[1] = ai_err(g, ENOSYS); ai_musttail return Nextp(1, 1); }
#endif

// (rusage who) -> (user sys), cpu microseconds. who: 0 this process, -1 the children it
//                 has already reaped, which is how `time` differences a spawn.
ai_noinline static struct ai *host_posix_rusage(struct ai *g) {
 word x = g->sp[0];
 if (!charmp(x)) return g->sp[0] = ai_badarg(g), g;
 struct rusage ru;
 if (getrusage((int) getcharm(x), &ru)) return g->sp[0] = ai_err(g, errno), g;
 intptr_t u = (intptr_t) ru.ru_utime.tv_sec * 1000000 + ru.ru_utime.tv_usec,
          s = (intptr_t) ru.ru_stime.tv_sec * 1000000 + ru.ru_stime.tv_usec;
 if (!ai_ok(g = ai_have(g, 2 * Width(struct ai_chain)))) return g;
 size_t const C = Width(struct ai_chain);
 struct ai_chain *c = ini_chain(bump(g, C), putcharm(s), ZeroPoint);
 c = ini_chain(bump(g, C), putcharm(u), word(c));
 return g->sp[0] = word(c), g; }
static lvm(lvm_posix_rusage) {
 LvmCall(g, host_posix_rusage) }

static ai_inline struct ai *host_posix_readdir(struct ai *g) {
 char const *p = str_c(g->sp[0]);
 if (!p) return g->sp[0] = ai_badarg(g), g;
 DIR *d = opendir(p);
 if (!d) return g->sp[0] = ai_err(g, errno), g;
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
 LvmCall(g, host_posix_readdir) }

static ai_inline word host_posix_unlink(struct ai *g, word arg) {
 char const *p = str_c(arg);
 if (!p) return ai_badarg(g);
 return unlink(p) ? ai_err(g, errno) : ZeroPoint; }

static lvm(lvm_posix_unlink) {
  Sp[0] = host_posix_unlink(g, Sp[0]);
  ai_musttail return Next(1); }

// (setenv name val) -> () | a nom | 'badarg misuse; a non-string val unsets the name.
// (environ _)       -> the environment as a list of "name=value" strings (the raw POSIX
//                      shape -- split at the first '=' in love; no order promised).
static ai_inline word host_posix_setenv(struct ai *g, word nw, word vw) {
 char const *n = str_c(nw), *v = str_c(vw);
 if (!n) return ai_badarg(g);
 if (!v) return unsetenv(n) ? ai_err(g, errno) : ZeroPoint;
 return setenv(n, v, 1) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_setenv) {
 Sp[1] = host_posix_setenv(g, Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }

extern char **environ;
static ai_inline struct ai *host_posix_environ(struct ai *g) {
 g->sp[0] = ZeroPoint;                                        // the accumulator, over the dummy arg
 for (char **e = environ; e && *e; e++) {
  if (!ai_ok(g = ai_strof(g, *e))) return g;                  // pushes: entry over acc
  if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
  struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 g->sp[0], g->sp[1]);
  *++g->sp = word(w); }
 return g; }

static lvm(lvm_posix_environ) {
 LvmCall(g, host_posix_environ) }

static ai_inline word host_posix_lseek(struct ai *g, word fdw, word offw, word whw) {
 if (!charmp(fdw) || !charmp(offw) || !charmp(whw)) return ai_badarg(g);
 intptr_t w = getcharm(whw);
 // the three by name, a platform's numbers being its own; anything else goes down as -1,
 // so the row answers 'einval rather than seeking to 0 and calling it success.
 int wh = w == 0 ? SEEK_SET : w == 1 ? SEEK_CUR : w == 2 ? SEEK_END : -1;
 off_t r = lseek((int) getcharm(fdw), (off_t) getcharm(offw), wh);
 return r < 0 ? ai_err(g, errno) : putcharm((intptr_t) r); }

static lvm(lvm_posix_lseek) {
 Sp[2] = host_posix_lseek(g, Sp[0], Sp[1], Sp[2]);
 ai_musttail return Nextp(1, 2); }

static union u const
  nif_spawn[]   = {{lvm_spawn}, {lvm_ret0}},
  nif_reapany[] = {{lvm_reapany}, {lvm_ret0}},
  nif_sigfd[]   = {{lvm_sigfd}, {lvm_ret0}},
  nif_sigtake[] = {{lvm_sigtake}, {lvm_ret0}},
  nif_waitpid[] = {{lvm_waitpid}, {lvm_ret0}},
  nif_chdir[]   = {{lvm_chdir}, {lvm_ret0}},
  nif_cwd[]     = {{lvm_cwd}, {lvm_ret0}},
  nif_selfpath[] = {{lvm_selfpath}, {lvm_ret0}},
  nif_pipe[]    = {{lvm_pipe}, {lvm_ret0}},
  nif_openfd[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_openfd}, {lvm_ret0}},
  nif_spawnio[] = {{lvm_cur}, {.x = putcharm(7)}, {lvm_spawnio}, {lvm_ret0}},
  nif_fdopen[]  = {{lvm_fdopen}, {lvm_ret0}},
  nif_spawnmap[] = {{lvm_cur}, {.x = putcharm(5)}, {lvm_spawnmap}, {lvm_ret0}},
  nif_getuid[]  = {{lvm_getuid}, {lvm_ret0}},
  nif_getgid[]  = {{lvm_getgid}, {lvm_ret0}},
  nif_fork[]    = {{lvm_fork}, {lvm_ret0}},
  nif_dup2[]    = {{lvm_cur}, {.x = putcharm(2)}, {lvm_dup2}, {lvm_ret0}},
  nif_dup[]     = {{lvm_dup}, {lvm_ret0}},
  nif_mkdir[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_mkdir}, {lvm_ret0}},
  nif_mount[]   = {{lvm_cur}, {.x = putcharm(3)}, {lvm_mount}, {lvm_ret0}},
  nif_mountf[]  = {{lvm_cur}, {.x = putcharm(4)}, {lvm_mountf}, {lvm_ret0}},
  nif_umount[]  = {{lvm_umount}, {lvm_ret0}},
  nif_chroot[]  = {{lvm_chroot}, {lvm_ret0}},
  nif_sync[]    = {{lvm_sync}, {lvm_ret0}},
  nif_mknod[]   = {{lvm_cur}, {.x = putcharm(3)}, {lvm_mknod}, {lvm_ret0}},
  nif_newns[]   = {{lvm_newns}, {lvm_ret0}},
  nif_posix_stat[]    = {{lvm_posix_stat}, {lvm_ret0}},
  nif_posix_lstat[]   = {{lvm_posix_lstat}, {lvm_ret0}},
  nif_posix_statfs[]  = {{lvm_posix_statfs}, {lvm_ret0}},
  nif_posix_rusage[]  = {{lvm_posix_rusage}, {lvm_ret0}},
  nif_posix_birth[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_birth}, {lvm_ret0}},
  nif_posix_readdir[] = {{lvm_posix_readdir}, {lvm_ret0}},
  nif_posix_unlink[]  = {{lvm_posix_unlink}, {lvm_ret0}},
  nif_posix_lseek[]   = {{lvm_cur}, {.x = putcharm(3)}, {lvm_posix_lseek}, {lvm_ret0}},
  nif_sigclear[]      = {{lvm_sigclear}, {lvm_ret0}},
  nif_sigignp[]       = {{lvm_sigignp}, {lvm_ret0}},
  nif_posix_signal[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_signal}, {lvm_ret0}},
  nif_posix_ttyfg[]   = {{lvm_posix_ttyfg}, {lvm_ret0}},
  nif_posix_setenv[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_setenv}, {lvm_ret0}},
  nif_posix_environ[] = {{lvm_posix_environ}, {lvm_ret0}};
// not every row here is the module's: the ones registered with NULL stay on the book,
// because a seat shadows each with a global of its own (inle/kmain.c's bindings and no-op
// roster, and the four inle/main.c's seat-doors tablet swaps). a global name reads the
// live book (love/ev.c's lvm_index), which is how the shadow is reached, so a module
// splice above the base would hide it for good and the crew would call the host's door on
// a seat with no host. the line is syscall vs seat door, and only the seats can say which.
LvNif("spawn", nif_spawn, NULL);
LvNif("glean", nif_reapany, NULL);
LvNif("sigfd", nif_sigfd, "posix");
LvNif("sigtake", nif_sigtake, "posix");
LvNif("sigclear", nif_sigclear, "posix");
LvNif("sigign?", nif_sigignp, "posix");
LvNif("wait", nif_waitpid, NULL);
LvNif("chdir", nif_chdir, "posix");
LvNif("cwd", nif_cwd, "posix");
LvNif("selfpath", nif_selfpath, "posix");
LvNif("pipe", nif_pipe, NULL);
LvNif("openfd", nif_openfd, "posix");
LvNif("spawnio", nif_spawnio, NULL);
LvNif("fdopen", nif_fdopen, NULL);
LvNif("spawnmap", nif_spawnmap, NULL);
LvNif("getuid", nif_getuid, NULL);
LvNif("getgid", nif_getgid, "posix");
LvNif("fork", nif_fork, NULL);
LvNif("dup2", nif_dup2, NULL);
LvNif("dup", nif_dup, NULL);
LvNif("mkdir", nif_mkdir, "posix");
LvNif("mount", nif_mount, "posix");
LvNif("mountf", nif_mountf, "posix");
LvNif("umount", nif_umount, "posix");
LvNif("chroot", nif_chroot, "posix");
LvNif("sync", nif_sync, "posix");
LvNif("mknod", nif_mknod, "posix");
LvNif("newns", nif_newns, "posix");
LvNif("stat", nif_posix_stat, "posix");
LvNif("lstat", nif_posix_lstat, "posix");
LvNif("statfs", nif_posix_statfs, "posix");
LvNif("rusage", nif_posix_rusage, "posix");
LvNif("birth", nif_posix_birth, "posix");
LvNif("readdir", nif_posix_readdir, "posix");
LvNif("unlink", nif_posix_unlink, "posix");
LvNif("lseek", nif_posix_lseek, "posix");
LvNif("signal", nif_posix_signal, NULL);
LvNif("ttyfg", nif_posix_ttyfg, NULL);
LvNif("setenv", nif_posix_setenv, NULL);
LvNif("environ", nif_posix_environ, NULL);
// --- the rest of the fs surface: the effect ops the fs tools ride (mv, ln, touch,
// chmod, chown -- apps/kore/fs.l and friends) -------------------------------------
//   (rename old new)      -> () | a nom | 'badarg  (mv's heart; same filesystem)
//   (symlink target path) -> () | a nom | 'badarg  (path becomes a link to target)
//   (readlink path)       -> the target string | a nom | 'badarg
//   (chmod path mode)     -> () | a nom | 'badarg  (mode the raw permission charm)
//   (chown path uid gid)  -> () | a nom | 'badarg  (-1 leaves that id alone)
//   (utime path ms)       -> () | a nom | 'badarg  (mtime and atime on the stat
//                            scale, milliseconds; a non-charm ms reads "now")
//   (umask mask)          -> the previous mask | 'badarg misuse (always succeeds)
//   (rmdir path)          -> () | a nom | 'badarg  (the empty-directory unlink)
//   (hardlink old new)    -> () | a nom | 'badarg  (link(2); `link` the word is the
//                            chain ctor, so the nif wears the long form)
static ai_inline word host_posix_rename(struct ai *g, word ow, word nw) {
 char const *o = str_c(ow), *n = str_c(nw);
 if (!o || !n) return ai_badarg(g);
 return rename(o, n) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_rename) {
 Sp[1] = host_posix_rename(g, Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }

static ai_inline word host_posix_symlink(struct ai *g, word tw, word pw) {
 char const *t = str_c(tw), *p = str_c(pw);
 if (!t || !p) return ai_badarg(g);
 return symlink(t, p) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_symlink) {
 Sp[1] = host_posix_symlink(g, Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }

ai_noinline static struct ai *host_posix_readlink(struct ai *g) {
 char const *p = str_c(g->sp[0]);
 char b[4096];
 if (!p) return g->sp[0] = ai_badarg(g), g;
 ssize_t n = readlink(p, b, sizeof b - 1);
 if (n < 0) return g->sp[0] = ai_err(g, errno), g;
 b[n] = 0;
 if (!ai_ok(g = ai_strof(g, b))) return g;                    // pushes: target over path
 return g->sp[1] = g->sp[0], g->sp += 1, g; }
static lvm(lvm_posix_readlink) {
 LvmCall(g, host_posix_readlink) }

static ai_inline word host_posix_chmod(struct ai *g, word pw, word mw) {
 char const *p = str_c(pw);
 if (!p || !charmp(mw)) return ai_badarg(g);
 return chmod(p, (mode_t) getcharm(mw)) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_chmod) {
 Sp[1] = host_posix_chmod(g, Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }

static ai_inline word host_posix_chown(struct ai *g, word pw, word uw, word gw) {
 char const *p = str_c(pw);
 if (!p || !charmp(uw) || !charmp(gw)) return ai_badarg(g);
 return chown(p, (uid_t) getcharm(uw), (gid_t) getcharm(gw)) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_chown) {
 Sp[2] = host_posix_chown(g, Sp[0], Sp[1], Sp[2]);
 ai_musttail return Nextp(1, 2); }

ai_noinline static word host_posix_utime(struct ai *g, word pw, word msw) {
 char const *p = str_c(pw);
 if (!p) return ai_badarg(g);
 struct timespec ts[2];
 if charmp(msw) {
  intptr_t ms = getcharm(msw);
  ts[0].tv_sec = ts[1].tv_sec = (time_t) (ms / 1000);
  ts[0].tv_nsec = ts[1].tv_nsec = (long) (ms % 1000) * 1000000;
 } else
  ts[0].tv_sec = ts[1].tv_sec = 0, ts[0].tv_nsec = ts[1].tv_nsec = UTIME_NOW;
 return utimensat(AT_FDCWD, p, ts, 0) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_utime) {
 Sp[1] = host_posix_utime(g, Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }

static ai_inline word host_posix_rmdir(struct ai *g, word pw) {
 char const *p = str_c(pw);
 if (!p) return ai_badarg(g);
 return rmdir(p) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_rmdir) { Sp[0] = host_posix_rmdir(g, Sp[0]); ai_musttail return Next(1); }

static ai_inline word host_posix_hardlink(struct ai *g, word ow, word nw) {
 char const *o = str_c(ow), *n = str_c(nw);
 if (!o || !n) return ai_badarg(g);
 return link(o, n) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_hardlink) {
 Sp[1] = host_posix_hardlink(g, Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }

// (copyfile src dst) -> bytes copied | a nom ('badarg misuse). src's bytes into dst
// without passing through the heap. bytes only -- mode is the caller's to set.
// a plain read/write loop: copy_file_range is linux-only and may short-copy or refuse
// with EXDEV/EINVAL, so a correct use needs this loop under it anyway.
// the buffer lives in the helper, not the lvm_ -- 64K owed at a tail turns the jump into
// a ret and grows the stack every dispatch (love.h's no-scratch rule).
ai_noinline static word host_posix_copyfile(struct ai *g, word sw, word dw) {
 char const *s = str_c(sw), *d = str_c(dw);
 if (!s || !d) return ai_badarg(g);
 int in = open(s, O_RDONLY);
 if (in < 0) return ai_err(g, errno);
 int out = open(d, O_WRONLY | O_CREAT | O_TRUNC, 0666);
 if (out < 0) { int e = errno; close(in); return ai_err(g, e); }
 char buf[1 << 15];                               // the helper's own frame, never a global
 intptr_t done = 0, err = 0;
 for (;;) {
  ssize_t n = read(in, buf, sizeof buf);
  if (n < 0) { if (errno == EINTR) continue; err = errno; break; }
  if (n == 0) break;
  for (ssize_t off = 0; off < n; ) {              // a short write is not an error
   ssize_t w = write(out, buf + off, (size_t) (n - off));
   if (w < 0) { if (errno == EINTR) continue; err = errno; goto shut; }
   off += w, done += w; } }
shut:
 close(in);
 if (close(out) && !err) err = errno;             // the write may land only here
 return err ? ai_err(g, (int) err) : putcharm(done); }
static lvm(lvm_posix_copyfile) {
 Sp[1] = host_posix_copyfile(g, Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }

static lvm(lvm_posix_umask) {
 Sp[0] = charmp(Sp[0]) ? putcharm((intptr_t) umask((mode_t) getcharm(Sp[0])))
                     : ai_badarg(g);
 ai_musttail return Next(1); }

static union u const
  nif_posix_rename[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_rename}, {lvm_ret0}},
  nif_posix_symlink[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_symlink}, {lvm_ret0}},
  nif_posix_readlink[] = {{lvm_posix_readlink}, {lvm_ret0}},
  nif_posix_chmod[]    = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_chmod}, {lvm_ret0}},
  nif_posix_chown[]    = {{lvm_cur}, {.x = putcharm(3)}, {lvm_posix_chown}, {lvm_ret0}},
  nif_posix_utime[]    = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_utime}, {lvm_ret0}},
  nif_posix_umask[]    = {{lvm_posix_umask}, {lvm_ret0}},
  nif_posix_rmdir[]    = {{lvm_posix_rmdir}, {lvm_ret0}},
  nif_posix_hardlink[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_hardlink}, {lvm_ret0}},
  nif_posix_copyfile[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_copyfile}, {lvm_ret0}};
LvNif("rename", nif_posix_rename, "posix");
LvNif("symlink", nif_posix_symlink, "posix");
LvNif("readlink", nif_posix_readlink, "posix");
LvNif("chmod", nif_posix_chmod, "posix");
LvNif("chown", nif_posix_chown, "posix");
LvNif("utime", nif_posix_utime, "posix");
LvNif("umask", nif_posix_umask, "posix");
LvNif("rmdir", nif_posix_rmdir, "posix");
LvNif("hardlink", nif_posix_hardlink, NULL);
LvNif("copyfile", nif_posix_copyfile, "posix");
// --- the pty wrapper: bao's rlwrap/debugger muscle ------------------------------
// spawn a program on a fresh pseudo-terminal, reap it without blocking, signal it, and
// read/write its window size. (tether argv) is hark (main.c) with the stdout pipe swapped
// for a pty pair: the same argv marshal + close-on-exec errno-pipe handshake, but the
// child's 0/1/2 become the pty slave and the parent keeps the master as a heap port.
//
//   (tether argv)      -> (pid . master-port) | a nom ('badarg misuse)
//   (reap pid)         -> (status)   exited (a pair, truthy even at status 0)
//                       | ()         still running
//                       | a nom      waitpid error (e.g. 'echild)
//   (kill pid sig)     -> () ok | a nom  (caller passes (0 - pid) for the group)
//   (tty fd)           -> (rows . cols) of the terminal on fd, or a nom
//   (settty p r c)     -> () ok | a nom  push a size onto a master port
//
// (tty) names the fd it asks about: a charm (0 in, 1 out, 2 err) or a port over one. size
// and isatty are one question -- TIOCGWINSZ answers only for a terminal -- so a pair means
// one and 'enotty anything else. a nom is truthy, so the caller's test is `two?`, not `?`.

// called with g Packed; argv is the sole GC root at g->sp[0]. leaves exactly one net value
// above argv on every non-oom path; a not-ok g only on oom, which lvm_tether ghelps.
ai_noinline static struct ai *host_tether(struct ai *g) {
  // no l allocation between the marshal and the fork, or the uncommitted gap moves
 char **cav;
 g = argv_marshal(g, &cav);
 if (!cav) return g;                               // misuse pushed -1, or oom

  // open the master, unlock the slave, copy the slave path (ptsname's buffer is
  // static -- snapshot it for the child, which inherits the snapshot across fork).
 int mfd = posix_openpt(O_RDWR | O_NOCTTY);
 if (mfd < 0) return ai_push(g, 1, ai_err(g, errno));
 if (grantpt(mfd) || unlockpt(mfd)) { int e = errno; close(mfd); return ai_push(g, 1, ai_err(g, e)); }
 char sname[128];
 { char const *p = ptsname(mfd);
  if (!p || strlen(p) >= sizeof sname) { close(mfd); return ai_push(g, 1, ai_err(g, p ? ENAMETOOLONG : errno)); }
  memcpy(sname, p, strlen(p) + 1); }

  // close-on-exec errno pipe: child writes its setup/exec errno here; a clean
  // exec closes the write end -> parent reads EOF (childerr stays 0).
 int ep[2];
 if (pipe(ep)) { int e = errno; close(mfd); return ai_push(g, 1, ai_err(g, e)); }
 fcntl(ep[1], F_SETFD, FD_CLOEXEC);

 pid_t pid = fork();
 if (pid < 0) { int e = errno; close(mfd); close(ep[0]); close(ep[1]); return ai_push(g, 1, ai_err(g, e)); }
 if (!pid) {                                       // child
  close(mfd); close(ep[0]);
  sig_dfl_job();                                  // the ignores must not ride the exec
  int e;
  if (setsid() < 0) { e = errno; goto childfail; }
  int sfd = open(sname, O_RDWR);                  // opening a tty in a fresh session claims it as ctty
  if (sfd < 0) { e = errno; goto childfail; }
  ioctl(sfd, TIOCSCTTY, 0);                       // belt-and-braces; harmless if already ctty
  dup2(sfd, 0); dup2(sfd, 1); dup2(sfd, 2);
  if (sfd > 2) close(sfd);
  execvp(cav[0], cav);
  e = errno;
  childfail:
  { ssize_t w = write(ep[1], &e, sizeof e); (void) w; }
  _exit(127); }

 close(ep[1]);                                     // parent
 int childerr = 0; ssize_t r;
 do r = read(ep[0], &childerr, sizeof childerr); while (r < 0 && errno == EINTR);
 close(ep[0]);
 if (childerr) {                                   // setup/exec failed in the child
  close(mfd);
  int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
  return ai_push(g, 1, ai_err(g, childerr)); }

  // success: master -> heap port (pushes it to sp[0]; argv slides to sp[1]).
 struct ai *io = ai_io_alloc(g, mfd);
 if (!ai_ok(io)) {                                 // oom: tear the child down, then ghelp
  kill(pid, SIGKILL);
  int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
  close(mfd);
  return io; }
 g = io;
 if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;   // port at sp[0] kept as a root
 struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 putcharm(pid), g->sp[0]);
 g->sp[0] = word(w);                               // [(pid . port), argv]
 return g; }

static lvm(lvm_tether) {
 LvmCallp(g, 1, host_tether) }   // result over argv

// (reap pid): non-blocking wait. a reaped child's decoded status comes back as a
// one-element list, so "exited 0" (a pair) and "still running" (()) do not collapse.
static lvm(lvm_reap) {
 LvmCall(g, host_reap, (pid_t) (charmp(Sp[0]) ? getcharm(Sp[0]) : 0)) }

// (kill pid sig): POSIX kill(2), a negative pid signalling the process group. () | a nom |
// 'badarg -- a non-charm pid may not fold to 0, which would signal the caller's own group.
static lvm(lvm_kill) {
 if (!charmp(Sp[0]) || !charmp(Sp[1])) {
  Sp[1] = ai_badarg(g); ai_musttail return Nextp(1, 1); }
 Sp[1] = kill((pid_t) getcharm(Sp[0]), (int) getcharm(Sp[1])) ? ai_err(g, errno) : ZeroPoint;
 ai_musttail return Nextp(1, 1); }

// the &ws ioctl + the chain alloc live here so lvm_tty's Continue() tail-jumps. overwrites
// sp[0] with (rows . cols) or a nom; a not-ok g only on oom, which lvm_tty ghelps.
ai_noinline static struct ai *host_tty(struct ai *g) {
 struct winsize ws;
 word x = g->sp[0];
 intptr_t fd = charmp(x) ? getcharm(x) : ai_port_fd(x);   // a charm is a raw fd
 if (fd < 0) { g->sp[0] = ai_badarg(g); return g; }
 if (ioctl((int) fd, TIOCGWINSZ, &ws) < 0) { g->sp[0] = ai_err(g, errno); return g; }
 if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
 struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 putcharm(ws.ws_row), putcharm(ws.ws_col));
 g->sp[0] = word(w);
 return g; }

// (tty fd): the terminal on fd as (rows . cols); a nom ('enotty) if fd is none, 'badarg
// for an operand that is neither a charm fd nor a port.
static lvm(lvm_tty) {
 LvmCall(g, host_tty) }

// (settty port rows cols): push a window size onto a master port; the kernel raises
// SIGWINCH on the slave's foreground group. () | a nom (a non-port or closed -> 'ebadf).
// the ioctl sits off lvm_settty's frame so its Continue() tail-jumps; 0 or the errno.
ai_noinline static int host_settty(intptr_t fd, intptr_t row, intptr_t col) {
 struct winsize ws = {0};
 ws.ws_row = (unsigned short) row;
 ws.ws_col = (unsigned short) col;
 return ioctl((int) fd, TIOCSWINSZ, &ws) ? -errno : 0; }

static lvm(lvm_settty) {
 intptr_t fd  = ai_port_fd(Sp[0]),
          row = charmp(Sp[1]) ? getcharm(Sp[1]) : 0,
          col = charmp(Sp[2]) ? getcharm(Sp[2]) : 0;
 int rc = host_settty(fd, row, col);
 Sp[2] = rc ? ai_err(g, -rc) : ZeroPoint;
 ai_musttail return Nextp(1, 2); }

// (ptyecho port on): toggle the pty's input ECHO so a line-editing wrapper owns the echo;
// ICANON is left intact, the child still reading whole lines and seeing VEOF. tcsetattr on
// the master fd sets the shared pty termios. off lvm_ptyecho's frame so its Continue()
// tail-jumps; returns 0 or a negated errno (EBADF for a non-port fd).
ai_noinline static int host_ptyecho(intptr_t fd, intptr_t on) {
 struct termios t;
 if (fd < 0) return -EBADF;
 if (tcgetattr((int) fd, &t)) return -errno;
 if (on) t.c_lflag |= ECHO; else t.c_lflag &= ~(tcflag_t) ECHO;
 return tcsetattr((int) fd, TCSANOW, &t) ? -errno : 0; }

static lvm(lvm_ptyecho) {
 intptr_t fd = ai_port_fd(Sp[0]),
          on = charmp(Sp[1]) ? getcharm(Sp[1]) : 0;
 int rc = host_ptyecho(fd, on);
 Sp[1] = rc ? ai_err(g, -rc) : ZeroPoint;
 ai_musttail return Nextp(1, 1); }

// (raw on): own the interactive terminal discipline on stdin. a truthy `on` puts the tty
// in raw mode (no ICANON/ECHO/ISIG, VMIN=1) so bao's editor is the sole echo; on = 0 / ()
// restores the cooked termios captured at the first raw-on. () | a nom ('enotty).
// one terminal, so one saved baseline and one atexit -- main.c's repl calls ai_raw_mode
// too, and two owners each capturing their own cooked state would ride atexit's LIFO.
static struct termios raw_cooked;
static int raw_have_cooked = 0;
static void raw_restore(void) {
 if (raw_have_cooked) tcsetattr(STDIN_FILENO, TCSANOW, &raw_cooked); }
// off lvm_raw's frame so its Continue() tail-jumps; returns 0 or the errno.
ai_noinline int ai_raw_mode(intptr_t on) {
 struct termios t;
 if (tcgetattr(STDIN_FILENO, &t)) return -errno;
 if (!on) { raw_restore(); return 0; }
 if (!raw_have_cooked) { raw_cooked = t; raw_have_cooked = 1; atexit(raw_restore); }
 t.c_lflag &= ~(tcflag_t) (ICANON | ECHO | ISIG | IEXTEN);
 t.c_iflag &= ~(tcflag_t) (IXON | ICRNL | BRKINT | INPCK | ISTRIP);
 t.c_cc[VMIN] = 1; t.c_cc[VTIME] = 0;
 return tcsetattr(STDIN_FILENO, TCSANOW, &t) ? -errno : 0; }
static lvm(lvm_raw) {
 intptr_t on = charmp(Sp[0]) ? getcharm(Sp[0]) : 0;
 int rc = ai_raw_mode(on);
 Sp[0] = rc ? ai_err(g, -rc) : ZeroPoint;
 ai_musttail return Next(1); }

// (swig port b): drink whatever the fd has waiting into cask b, without blocking.
// n bytes read; 0 = nothing waiting or eof (the next see tells those apart); a nom =
// failure ('badarg misuse).
static lvm(lvm_swig) {
 word p = Sp[0], x = Sp[1], out = ai_badarg(g);
 if (!charmp(p) && ((union u*) p)->ap == lvm_port_io
      && !charmp(x) && ((union u*) x)->ap == lvm_cask) {
  struct ai_io *io = (struct ai_io*) p;
  intptr_t fd = ai_io_fd(io);
  struct ai_str *s = cask(x)->str;
    // the port's own pending run comes first: a buffered see may have gulped
    // ahead of us, and reading the fd past it would scramble the byte order
  if (s->len && ai_io_pending(g, io)) {
   uintptr_t k = ai_io_read_drain(g, io, (unsigned char*) s->bytes, s->len);
   Sp[1] = putcharm((intptr_t) k);
   ai_musttail return Nextp(1, 1); }
  if (fd >= 0 && s->len) {
   int fl = fcntl((int) fd, F_GETFL);
   fcntl((int) fd, F_SETFL, fl | O_NONBLOCK);
   ssize_t k = read((int) fd, s->bytes, s->len);
   fcntl((int) fd, F_SETFL, fl);
   out = k > 0 ? putcharm(k)
          : k == 0 ? putcharm(0)
          : (errno == EAGAIN || errno == EWOULDBLOCK) ? putcharm(0)
          : ai_err(g, errno); } }
 Sp[1] = out;
 ai_musttail return Nextp(1, 1); }

// --- the port doors: (open path mode) and (close p) --------------------------
// on inle the open(2)/close(2) below land in inle/sys.c's arms, so the ramfs answers the
// same nif. `open`'s presence in the book is what lights up prel's module walk
// (love/boot/prel.l's fsopen, by peep) and salt's config read, both gating on the name.

// mode is a l string; only the first byte is consulted: r read, w truncate-or-create,
// a append-or-create. an unknown mode is misuse ('badarg); open(2)'s refusal comes up as
// its nom, so a caller tells 'etxtbsy (relinking a running binary) from 'enoent by name.
static int call_open(struct ai_str *pv, struct ai_str *mv) {
  if (mv->len == 0) return -1;
  int flags;
  switch (mv->bytes[0]) {
    case 'r': flags = O_RDONLY; break;
    case 'w': flags = O_WRONLY | O_CREAT | O_TRUNC; break;
    case 'a': flags = O_WRONLY | O_CREAT | O_APPEND; break;
    default: return -1; }
  int fd = open(pv->bytes, flags, 0644);
  return fd < 0 ? -errno : fd; }

// (open path mode) -- a heap port (closed on GC), or a nom: open(2)'s errno, 'badarg for
// misuse. a failure is truthy (a nom nets positive), so a caller may not ask ? of the
// answer -- port? is the success test, nom? the failure test.
static lvm(lvm_open) {
  long rc = -1;
  if (!strp(Sp[0]) || !strp(Sp[1])) goto fail;
  struct ai_str *pv = str(Sp[0]), *mv = str(Sp[1]);
  // heap and stack ride registers under ai_tco, and a seat whose open reports them
  // (inle's /proc/gauge) reads them off the struct: this Pack is that write-back.
  Pack(g);
  int fd = call_open(pv, mv);
  if (fd < 0) { rc = fd; goto fail; }
  Pack(g);
  struct ai *r = ai_io_alloc(g, fd);
  if (!ai_ok(r)) { close(fd); rc = -ENOMEM; goto fail; }
  g = r;
  Unpack(g);
  // stack: [port, path, mode, ...] -> [port, ...]
  Sp[2] = Sp[0];
  ai_musttail return Nextp(1, 2);
 fail:
  Sp[1] = rc == -1 ? ai_badarg(g) : ai_err(g, (int) -rc);
  ai_musttail return Nextp(1, 1); }

// (close x) -- a port, or a raw fd from openfd/pipe/dup. on a port: flush, close, and hand
// it the closed vt, so every later read, write and flush finds the door that does nothing
// and the finalizer, which asks the vt for an fd, skips. on a charm: close(2). no-op else.
static lvm(lvm_close) {
  if (charmp(Sp[0])) {
    intptr_t fd = getcharm(Sp[0]);
    Sp[0] = (fd >= 0 && close((int) fd)) ? ai_err(g, errno) : ZeroPoint;
    ai_musttail return Next(1); }
  // inline "is x a port": heap pointer whose discriminator is lvm_port_io.
  if (cell(Sp[0])->ap == lvm_port_io) {
    struct ai_io *io = (struct ai_io*) Sp[0];
    intptr_t fd = ai_io_fd(io);
    bool horn = io->vt == &ai_horn_vt;       // its device shuts its own way, after the run lands
    if (fd >= 0 || horn) {
      g->io = io;
      Pack(g);
      g = ai_io_wflush(g, io);   // buffered bytes land before the fd dies
      if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g);
      // the device would not take the whole run: park and come back. nothing is mutated
      // yet -- the fd is open and Ip unadvanced -- so the re-run is this close from the top.
      if (ai_io_wpending(g, (struct ai_io*) g->sp[0])) {
        Unpack(g);
        g->next_wake_at = ai_clock() + 1;
        ai_musttail return Ap(lvm_yield_sw, g); }
      Unpack(g);
      if (horn) ai_horn_shut((struct ai_io*) Sp[0]); else close(fd);
      ((struct ai_io*) Sp[0])->vt = &ai_closed_vt; } }   // re-read: wflush may collect
  Sp[0] = ZeroPoint;
  ai_musttail return Next(1); }

static union u const
  nif_open[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_open}, {lvm_ret0}},
  nif_close[] = {{lvm_close}, {lvm_ret0}},
  nif_raw[]        = {{lvm_raw}, {lvm_ret0}},
  nif_swig[]       = {{lvm_cur}, {.x = putcharm(2)}, {lvm_swig}, {lvm_ret0}},
  nif_tether[]     = {{lvm_tether}, {lvm_ret0}},
  nif_reap[]       = {{lvm_reap}, {lvm_ret0}},
  nif_kill[]       = {{lvm_cur}, {.x = putcharm(2)}, {lvm_kill}, {lvm_ret0}},
  nif_tty[]        = {{lvm_tty}, {lvm_ret0}},
  nif_settty[]     = {{lvm_cur}, {.x = putcharm(3)}, {lvm_settty}, {lvm_ret0}},
  nif_ptyecho[]    = {{lvm_cur}, {.x = putcharm(2)}, {lvm_ptyecho}, {lvm_ret0}};
LvNif("tether", nif_tether, "posix");
LvNif("gather", nif_reap, "posix");
LvNif("still", nif_kill, NULL);
LvNif("tty", nif_tty, NULL);
LvNif("settty", nif_settty, "posix");
LvNif("ptyecho", nif_ptyecho, "posix");
LvNif("raw", nif_raw, NULL);
LvNif("swig", nif_swig, "posix");
LvNif("open", nif_open, "posix");
LvNif("close", nif_close, "posix");
