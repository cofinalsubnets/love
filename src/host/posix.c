// src/host/posix.c -- the POSIX surface, in one place: process (spawn/reap/wait/
// signal, the pid-1 supervisor's primitives and the shell's job control), fs
// effects and values (stat/readdir/rename/chmod/..), the environment, pipes and
// raw-fd plumbing, and the pty wrapper (bao's rlwrap/debugger muscle). host-only,
// auto-globbed + AiNif-registered (no love.c/love.h/main.c edit). the
// conventions, kept throughout:
//   effect ops answer () ok | 'enoent | 'badarg
//   value ops answer the value | () absence | 'enoent | 'badarg
// the rule: if the C level set errno, it comes back as the nom naming it
// (ai_err reads the boot-interned vocabulary, so no error path allocates); a
// call refused here, before any syscall ran, answers 'badarg, which is not a
// posix name, so the two can never shadow. ok is (), success with nothing more
// to say. so !e reads "it worked" on an effect op, and nom? e reads "it
// failed" on any op: errors are the only noms any of these answer.
//
// the argv marshal is here, beside the spawns that consume it; main.c wants it too, so it
// is not static. the local face adds the misuse answer: 'badarg on the stack, which is
// what every caller in this file hands back as the net value.
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
#include <time.h>           // clock_gettime, for ai_clock

// --- what this LIBC carries, asked once -------------------------------------
// the question a lane owes is which doors it may call, never which kernel it is
// standing on: ours carries every door on all three (src/apps/moon/include/sys), and
// a foreign libc carries what its own box does. so these are build facts under
// AiNolibc and box facts under anything else.
// mount(2) and unshare are LINUX-reaching, and still not this file's question:
// ours carries both symbols and os.c leaves their rows unmapped, so the call
// refuses with ENOSYS off linux at run time -- which is the only place that can
// know, since one binary meets three kernels. compiling them out by the kernel
// we were built on would refuse them on a linux box too. widening them is the
// libc's job (mount wants the BSD argument shapes; unshare is linux's own).
#if defined(AiNolibc)
# define AiHaveSignalfd 1
# define AiHaveKqueue   1
# define AiHaveSysctl   1
# define AiHaveDontfork 1
#elif defined(__linux__)
# define AiHaveSignalfd 1
# define AiHaveDontfork 1
#elif defined(__FreeBSD__) || defined(__NetBSD__)
# define AiHaveKqueue 1
# define AiHaveSysctl 1
#endif
#if defined(AiNolibc) || defined(__linux__)
# define AiHaveMount      1
# define AiHaveNamespaces 1
#endif

#if defined(AiHaveSignalfd)
#include <sys/signalfd.h>   // signalfd, struct signalfd_siginfo
#endif
#if defined(AiHaveKqueue)
#include <sys/event.h>      // kqueue/kevent, the signal port's BSD door
#endif
#if defined(AiHaveSysctl)
#include <sys/sysctl.h>     // the BSD selfpath doors (glibc dropped the symbol)
#endif
#if defined(AiHaveMount)
#include <sys/mount.h>      // mount(2), in linux's argument shape
#endif
#if defined(AiHaveNamespaces)
#include <sched.h>          // unshare, CLONE_NEWUSER/NEWNS (newns)
#endif
// ⚠ OUTSIDE every guard: what follows is called unconditionally below (argv_marshal,
// sigtake, the pty pair), so putting any of it under one kernel's feature is a build that
// only stands on that kernel.
// CLOCK_REALTIME in milliseconds -- the one scale for the scheduler's
// deadlines, (clock t), and every mtime. on inle the call lands in the
// clock_gettime arm, which reads the kernel's kboot/kticks scale.
ai_noinline uintptr_t ai_clock(void) {
 struct timespec ts;
 return clock_gettime(CLOCK_REALTIME, &ts) ? (uintptr_t) -1 :
  (uintptr_t) (ts.tv_sec * 1000 + ts.tv_nsec / 1000000); }

// argv: the chain of strings at g->sp[0] -> a NUL-terminated char** laid in the
// uncommitted heap gap at Hp. GC-invisible, holds no l pointers, and valid across a
// fork -- host_spawn_guard below leaves the window above hp mapped for exactly this, so
// what execvp reads must live here and not in the strings themselves.
// consumed before any further allocation; never bumps Hp.
//
// -> g, and *cavp is the vector or NULL. the two failures are told apart by the g:
// argv not a chain of strings, or empty, leaves g OK (each caller says what a misuse
// answers -- they do not agree), and a failed reserve leaves it not ok.
struct ai *ai_argv_marshal(struct ai *g, char ***cavp) {
 *cavp = NULL;
 ai_word argv = g->sp[0];
 uintptr_t argc = 0, total = 0;
 for (ai_word p = argv; chainp(p); p = B(p)) {
  if (!strp(A(p))) return g;                              // misuse: non-string argv
  argc++, total += len(A(p)) + 1; }                          // +1 for the NUL
 if (!argc) return g;                                        // empty argv
 if (!ai_ok(g = ai_have(g, argc + 1 + b2w(total)))) return g;
 argv = g->sp[0];                            // ai_have may have GC'd; argv is the only
                                             // root, at sp[0], so it is forwarded there
 char **cav = (char**) g->hp,                                // at Hp: aligned
      *blob = (char*) (g->hp + (argc + 1));                  // whole words after
 uintptr_t off = 0, i = 0;
 for (ai_word p = argv; chainp(p); p = B(p), i++) {
  struct ai_str *s = str(A(p));
  memcpy(blob + off, txt(s), len(s));
  blob[off + len(s)] = 0;
  cav[i] = blob + off;
  off += len(s) + 1; }
 cav[argc] = NULL;
 *cavp = cav;
 return g; }

// a wait(2) status word -> the value a reaper hands back: the exit code, or
// 128+signal for a signalled death (the shell convention), or -1 for the
// (shouldn't-happen) neither case. the way hark (main.c) decodes it -- the
// one copy every reaper here shares, so they agree on what an exit code means.
static ai_inline int proc_status(int st) {
 return WIFEXITED(st) ? WEXITSTATUS(st)
       : WIFSIGNALED(st) ? 128 + WTERMSIG(st) : -1; }

// pull a live OS fd out of a port arg, or -1 if it isn't a port. same inline
// "is x a port" as main.c's lvm_close: a heap word whose discriminator is the
// port vtable. a closed port carries the -3 sentinel; we hand that straight back
// to the syscall, which fails with EBADF -- the honest answer.

// a love string as a C string, or NULL for a non-string: bytes[len] is always a NUL
// (src/core/love.h), so the bytes go to the syscall where they lie. a path the kernel finds
// too long comes back ENAMETOOLONG, which is a truer answer than a cap of ours.
static ai_inline char const *str_c(ai_word x) { return strp(x) ? txt(x) : NULL; }

// the argv marshal: the chain of strings at g->sp[0] -> argc+1 char** + the
// NUL-joined byte blob, laid in the uncommitted heap gap at Hp -- GC-invisible,
// holds no l pointers, valid across a fork, consumed (execvp'd) before any
// further allocation. called with g Packed. two failure faces: a misuse (non-
// string element / empty argv) pushes 'badarg and leaves *cavp NULL (the
// caller returns g as-is, 'badarg already the net value); oom returns !ok g
// (*cavp NULL too, so `if (!*cavp) return g` covers both).
static struct ai *argv_marshal(struct ai *g, char ***cavp) {
 g = ai_argv_marshal(g, cavp);
 return !*cavp && ai_ok(g) ? ai_push(g, 1, ai_badarg(g)) : g; }

// --- the supervisor pair: spawn without waiting, reap any dead child ------------
// (spawn argv)  -> child pid (a fixnum) | a nom ('badarg misuse)
// (glean _)     -> (pid . status) of one reaped child
//                | ()                 none pending
//                | a nom              (e.g. 'echild: no children left)
// src/apps/init/init.l drives real processes with these plus the generic `still` (kill):
// spawn returns a pid to track, glean is the SIGCHLD core (poll it, map the pid
// back to a unit, restart per policy). on a real pid1 glean also collects
// reparented orphans (waitpid(-1)).

// the child side of the ignore dance: a disposition set to SIG_IGN survives exec,
// so a shell that ignores the job-control signals must undo that in every child
// between fork and exec -- or ^C could never kill anything it launches.
// SIGPIPE rides this too, and it is the one that bites hardest: love ignores it
// so a write to a hung-up peer answers "the device is gone" instead of killing the
// runtime -- but a child that inherited the ignore is a `yes | head` that never
// stops. every fork/exec in the tree resets it (here, and by hand at main.c's two
// exec sites, which are outside this file).
static void sig_dfl_job(void) {
 signal(SIGINT, SIG_DFL); signal(SIGQUIT, SIG_DFL); signal(SIGPIPE, SIG_DFL);
 signal(SIGTSTP, SIG_DFL); signal(SIGTTIN, SIG_DFL); signal(SIGTTOU, SIG_DFL);
 // ..and the mask, which sigaction does not touch and exec does not clear. a shell
 // watching a signal blocks it (sigfd), and a blocked signal is inherited straight
 // through the exec -- so `trap .. INT` in lush would have made every command it
 // runs deaf to ^C. every exec-bound child here leaves through this one door.
 sigset_t none; sigemptyset(&none); sigprocmask(SIG_SETMASK, &none, NULL); }

// (sigign? sig) -> 1 if this signal is SIG_IGN right now, else 0. POSIX: a signal
// ignored on entry to a non-interactive shell cannot be trapped or reset, and a
// `&` from the calling shell is how a script most often gets one -- so a shell
// that cannot ask this trapped signals its caller had deliberately turned off.
ai_noinline static ai_word host_sigignp(ai_word sigw) {
 struct sigaction sa;
 if (!charmp(sigw)) return putcharm(0);
 if (sigaction((int) getcharm(sigw), NULL, &sa)) return putcharm(0);
 return putcharm(sa.sa_handler == SIG_IGN ? 1 : 0); }
static lvm(lvm_sigignp) { Sp[0] = host_sigignp(Sp[0]); ai_musttail return Next(1); }

// (sigclear _) -> () -- empty this process's signal mask. the exec children get it
// from sig_dfl_job above; a shell's forked subshell never execs, so it asks here.
ai_noinline static ai_word host_sigclear(struct ai *g) {
 sigset_t none; sigemptyset(&none);
 return sigprocmask(SIG_SETMASK, &none, NULL) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_sigclear) { Sp[0] = host_sigclear(g); ai_musttail return Next(1); }

// (spawn argv) -> the child pid, or the failure's nom (a caller tells a pid, a
// charm, from a failure, a nom, by kind alone). fork +
// execvp; the parent returns immediately -- non-blocking, unlike run (waits +
// captures) and exec (replaces in place). the child inherits init's stdio (a real
// pid1 redirects to the journal); a failed exec _exit(127)s, seen by the next glean.
// spawn guard: the heap pools leave an exec-bound fork's inheritance, so fork copies no
// page tables for memory the child drops at once. the cost it removes scales with 4 KB
// PTEs, so it grows with the heap -- 300 spawns at a 151 MB live heap take 350 ms guarded
// and 820-1080 unguarded. scoped by the caller: the (fork) nif and any child that walks
// the heap inherit whole, as fork means. best-effort -- an unaligned edge or a kernel
// without the advice keeps plain fork.
#if defined(AiHaveDontfork)
static void guard1(void *lo, void *hi, int adv) {
 uintptr_t a = ((uintptr_t) lo + 4095) & ~(uintptr_t) 4095,
           b = (uintptr_t) hi & ~(uintptr_t) 4095;
 if (b > a) (void) madvise((void*) a, (long) (b - a), adv); }
#endif
void host_spawn_guard(struct ai *g, int on) {
#if defined(AiHaveDontfork)
 int adv = on ? MADV_DONTFORK : MADV_DOFORK;
 // the ceiling is the frontier, not the block top: ai_argv_marshal lays the
 // child's argv at g->hp, so the window above hp stays mapped and is the one
 // thing execvp can still read; the live bulk below it the child never looks
 // at. nothing allocates between the two calls, so the ranges agree.
 guard1(g, g->hp, adv);
 if (g->major_pool) guard1(g->major_pool, g->major_pool + 2 * g->major_len, adv);
#else
#endif
}

// the one fork + exec. argv rides at sp[0]; in/out/err are spawnio's fixed triple
// (-1: leave it), applied first; fdmap is a list of (childfd . srcfd) pairs and closes a list
// of fds, both read off the stack AFTER the marshal (a GC may have moved them), -1 for
// none. pg >= 0 puts the child in that group (0: a fresh one it leads), fg hands it the
// terminal. pushes the pid, or a nom.
ai_noinline static struct ai *host_spawnx(struct ai *g, int in, int out, int err,
                                          int mapat, int closeat, intptr_t pg, intptr_t fg) {
 char **cav;
 g = argv_marshal(g, &cav);
 if (!cav) return g;                                         // misuse pushed -1, or oom
 ai_word fdmap = mapat >= 0 ? g->sp[mapat] : ZeroPoint,
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
  for (ai_word p = fdmap; chainp(p); p = B(p)) {
   ai_word e = A(p);
   if (!chainp(e)) continue;
   intptr_t cfd = charmp(A(e)) ? getcharm(A(e)) : -1;
   if (cfd < 0) continue;
   ai_word sw = B(e);
   if (charmp(sw) && getcharm(sw) >= 0) dup2((int) getcharm(sw), (int) cfd);
   else close((int) cfd); }                    // () (or a negative) srcfd closes childfd
  for (ai_word p = closes; chainp(p); p = B(p)) {
   intptr_t fd = getcharm(A(p));
   if (fd > 2) close((int) fd); }
  sig_dfl_job();                                // undo the shell's ignores (TTOU too)
  execvp(cav[0], cav);
  _exit(127); }                                 // seen by the next glean
 if (pg >= 0) setpgid(pid, (pid_t) (pg ? pg : pid));   // parent side too: no race window
 return ai_push(g, 1, putcharm(pid)); }                      // parent: the live pid

static lvm(lvm_spawn) {
 LvmCallp(g, 1, host_spawnx, -1, -1, -1, -1, -1, -1, 0) }   // pid over argv

// (glean _) -> (pid . status) of one reaped child, () if none are pending, or
// the failure's nom (e.g. 'echild when no children remain). the pid is the car so the
// supervisor maps it back to a unit; status is proc_status (exit code / 128+sig).
// waitpid(-1, WNOHANG) reaps any child -- incl. reparented orphans on a real pid1.
// the arg is a dummy (ignored), so a bare (glean) curries; call it (glean 0).
// waitpid(WNOHANG) + the chain alloc, off the wrappers' frames so their tails jump
// (cf. host_tether). leaves exactly one net value at sp[0]: () still running / none
// pending, an errno nom, or the record -- (status) for a named pid, (pid . status)
// when the wait was a wildcard and the pid is news. not-ok g only on oom.
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
// (sigfd sigs)  -> a port over a signalfd watching `sigs` (a list of signal numbers;
//                  a non-list keeps the supervisor default SIGCHLD + SIGTERM), those signals
//                  first blocked (sigprocmask) so they queue to the fd instead of
//                  their default disposition -- SIGCHLD's discard, SIGTERM's kill.
//                  that queuing is exactly what turns a TERM into a graceful event,
//                  not a death. a nom on failure. SIGINT is left unblocked so ^C bails.
// (sigtake port) -> (signo . pid) of one pending signal, or () if none ready.
// the supervisor parks with the core `(await sig)` (cooperative -- the scheduler
// merges the sigfd with a heartbeat task's timer in one wait, the {nic, clock}
// story for {signals, clock}), then sigtake reads the record. SIGCHLD coalesces, so a
// 'chld wake still loops `glean` to harvest every zombie.
#if defined(AiHaveSignalfd) || defined(AiHaveKqueue)
#if defined(AiHaveKqueue)
// the BSD door: the port holds a kqueue fd instead. EVFILT_SIGNAL fires on
// send -- before delivery processing -- so the same blocked mask queues here
// too (probed on both boxes). one kernel per process, so one flavor: a flag.
static int host_sigkq;
ai_noinline static int host_sigfd_kq(ai_word a) {
 int kq = kqueue();
 if (kq < 0) return -1;
 struct kevent ch;
 if (chainp(a))
  for (ai_word p = a; chainp(p); p = B(p)) {
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
// the arg may be a list of signal numbers to watch; anything else (the dummy-0
// convention) keeps the supervisor's classic pair, SIGCHLD + SIGTERM.
ai_noinline static struct ai *host_sigfd(struct ai *g) {
 sigset_t m;
 sigemptyset(&m);
 ai_word a = g->sp[0];
 if (chainp(a))
  for (ai_word p = a; chainp(p); p = B(p)) {
  if charmp(A(p)) sigaddset(&m, (int) getcharm(A(p))); }
 else { sigaddset(&m, SIGCHLD); sigaddset(&m, SIGTERM); }
 if (sigprocmask(SIG_BLOCK, &m, NULL)) return g->sp[0] = ai_err(g, errno), g;
 // every door this libc carries, in order: the canonical one, then the BSD one
 // where it answers -- the try is the probe, as selfpath's ladder below.
 int fd = -1;
#if defined(AiHaveSignalfd)
 fd = signalfd(-1, &m, SFD_NONBLOCK | SFD_CLOEXEC);
#endif
#if defined(AiHaveKqueue)
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

// read one pending signal (non-blocking) into (signo . pid). signo is the raw
// canonical number (SIGCHLD 17, SIGTERM 15); pid is ssi_pid (the dead child on
// SIGCHLD) -- except the kqueue lane, which names no sender: pid 0 there, and a
// 'chld consumer loops glean for the pids anyway.
ai_noinline static struct ai *host_sigtake(struct ai *g, int fd) {
 intptr_t signo, pid;
#if defined(AiHaveKqueue)
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
#if defined(AiHaveSignalfd)
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
//                 128+sig), a stop (^Z: SIGTSTP/SIGSTOP) is 256 + the stopping signal
//                 -- a charm above every exit status, so a shell tells "stopped, job
//                 it" (< 255 st) from "done". a nom on failure. the foreground wait:
//                 spawn (inherited stdio) then wait, so a command owns the terminal
//                 and the prompt returns only when it is done or parked.
// (signal sig disp) -> sigaction: disp 0 = default, 1 = ignore. () | a nom |
//                 'badarg misuse (the effect convention). the shell ignores INT/QUIT/
//                 TSTP so the tty's ^C/^Z reach only the foreground child; spawn's
//                 child side resets them (an ignored disposition survives exec).
// (chdir path) -> () ok | a nom | 'badarg misuse. the `cd` builtin.
// (cwd _)      -> the current directory as a string, or a nom on failure. for the prompt.
// the syscall body lives in an ai_noinline helper so the lvm_ wrapper stays a pure tail-jump (no ret):
// the syscall + any stack buffer would otherwise block the sibcall to Continue() and trip `make vmret`.
// WNOHANG, and the unit means "still running". a real answer is a charm status
// (256+sig for a stop) or a failure's nom, so the zero point is free to carry
// the fourth term -- no sentinel is overloaded.
ai_noinline static ai_word host_waitpid(struct ai *g, ai_word arg) {
 intptr_t pid = charmp(arg) ? getcharm(arg) : 0;
 int st;
 pid_t r;
 do r = waitpid((pid_t) pid, &st, WUNTRACED | WNOHANG); while (r < 0 && errno == EINTR);
 if (!r) return ZeroPoint;                                   // alive, neither exited nor stopped
 if (r < 0) return ai_err(g, errno);
 if (WIFSTOPPED(st)) return putcharm(256 + WSTOPSIG(st));
 return putcharm(proc_status(st)); }
// (wait pid) waits by parking, not by blocking: a live child re-arms the task for the
// next tick and yields, so a peer task runs while a foreground job is up. it is A
// poll and should be read as one -- one waitpid per millisecond per waiting task,
// because SIGCHLD is not in the scheduler's wait set and a pid is not an fd. that is
// rung 5's shape for the write residue, and the same trade: honest and small, and
// correct until something measures it hurting. nothing is consumed before the park
// (WNOHANG left the child exactly as it found it), so the op re-runs whole.
static lvm(lvm_waitpid) {
 ai_word r = host_waitpid(g, Sp[0]);
 if (r == ZeroPoint) { g->next_wake_at = ai_clock() + 1; ai_musttail return Ap(lvm_yield_sw, g); }
 Sp[0] = r; ai_musttail return Next(1); }

ai_noinline static ai_word host_posix_signal(struct ai *g, ai_word sigw, ai_word dw) {
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
static ai_inline ai_word host_chdir(struct ai *g, ai_word arg) {
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
// the one door for it: the prel's library walk, the seed's bin/love, moon's include
// root, lux's re-exec, lush's am-I-that-tool test and the self-bake's re-open
// (src/host/image.c) all start here.
// no argv[0] fallback, and not for want of argv[0] -- the book has it as `cmdline`.
// it is that a bare `cmdline` read from baked code folds to the bake's line, and the
// callers here are baked, so the operand would arrive already wrong. a seat with no
// door below writes the walk where the line is read live.
ai_noinline size_t host_selfpath(char *b, size_t n) {
 // a runtime ladder, because one binary meets more than one kernel: linux's
 // link, then netbsd's spelling of it, then freebsd's sysctl door -- each try
 // answers only on its kernel, so the tries are the OS probe.
 ssize_t r = readlink("/proc/self/exe", b, n - 1);
 if (r <= 0) r = readlink("/proc/curproc/exe", b, n - 1);
 if (r > 0) {
  b[r] = 0;
  // ⚠ the suffix is the KERNEL's, not the path's: once our own inode is unlinked the
  // link reads "PATH (deleted)", and every use of it after that -- an open, a rename
  // target -- names a file that is not there. a concurrent self-bake unlinks us the
  // moment it renames its image over the path we both live at, so the door that answers
  // "where am I" has to answer the place, not the inode's obituary.
  size_t dl = sizeof " (deleted)" - 1;
  if ((size_t) r > dl && !memcmp(b + (size_t) r - dl, " (deleted)", dl))
   r -= (ssize_t) dl, b[r] = 0;
  return (size_t) r; }
#if defined(AiHaveSysctl)
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
//                   2 = write/create/append, 3 = write/create/EXCL at mode 0600 --
//                   the one that fails on an existing name, which is what makes a
//                   mktemp a claim and not a guess. a nom on failure, 'badarg on a bad path.
// (spawnio argv in out err closes pg fg) -> pid. fork; in the child: the job-control
//                   dance first -- pg < 0 stays in the parent's pgrp (the legacy /
//                   non-tty lane), pg = 0 leads a fresh process group, pg > 0 joins
//                   that group (pipeline members join their stage-0 leader) -- and fg
//                   nonzero hands the child's group the terminal (tcsetpgrp on fd 0
//                   before the dup2s, TTOU ignored for the handoff; the parent
//                   setpgids too, closing the race). a job in its own pgrp is what
//                   makes ^Z real: a stop signal to an orphaned group is discarded
//                   by POSIX, and the shell's own group is exactly that under a
//                   nested session. then dup2 `in`/`out`/`err` (each >=0) onto fd
//                   0/1/2, close every fd in the list `closes` (the pipe ends the
//                   child must not leak, so a downstream reader sees EOF), reset the
//                   job signals, execvp. the parent keeps its fds and closes the
//                   pipe ends itself with `close`, which takes a raw fd too.
//                   a nom on a fork/marshal failure.
// (ttyfg pg)     -> give the terminal (fd 0) to process group pg; pg <= 0 takes it
//                   back to the caller's own group (the shell reclaiming the tty
//                   after a foreground job ends or stops). () | a nom.
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

ai_noinline static ai_word host_posix_ttyfg(struct ai *g, ai_word pgw) {
 pid_t pg = (charmp(pgw) && getcharm(pgw) > 0) ? (pid_t) getcharm(pgw) : getpgrp();
 return tcsetpgrp(0, pg) ? ai_err(g, errno) : ZeroPoint; }

static lvm(lvm_posix_ttyfg) {
  Sp[0] = host_posix_ttyfg(g, Sp[0]);
  ai_musttail return Next(1); }

// (fdopen fd) -> a port over a raw fd -- pipe/openfd's other half, so love reads
// and writes its own plumbing (a command substitution drains a pipe with slurp, a
// heredoc body pours in with say). 'badarg on a non-charm / negative fd; oom
// ghelps. the port's GC finalizer owns the fd from here: hand it over, don't
// close it too.
static lvm(lvm_fdopen) {
 intptr_t fd = charmp(Sp[0]) ? getcharm(Sp[0]) : -1;
 if (fd < 0) ai_musttail return Answer(ai_badarg(g));
 LvmCallp(g, 1, ai_io_alloc, (int) fd) }   // port over the fd arg -- alloc pushed it

// (spawnmap argv fdmap closes pg fg) -> pid | a nom. spawnio generalized: instead
// of the hardwired in/out/err triple, `fdmap` is a list of (childfd . srcfd) pairs
// applied in order in the child -- dup2(srcfd, childfd) for a charm srcfd >= 0,
// close(childfd) for () -- and each srcfd reads the fd table as remapped so far,
// which is exactly the POSIX left-to-right redirection law (`>f 2>&1` maps
// ((1 . f) (2 . 1)) and the second entry sees the first's work). pg/fg and the
// closes list ride unchanged from spawnio (the job-control dance + the pipe ends
// the child must not leak). spawnio stays for its callers; this is the shell's lane.
static lvm(lvm_spawnmap) {
 intptr_t pg = charmp(Sp[3]) ? getcharm(Sp[3]) : -1,
          fg = charmp(Sp[4]) ? getcharm(Sp[4]) : 0;
 LvmCallp(g, 5, host_spawnx, -1, -1, -1, 1, 2, pg, fg) }   // argv at sp[0], fdmap sp[1], closes sp[2]; pid over the 5 args

// (getuid _) -> the real uid, a charm. the shell's # vs $ prompt; always succeeds.
// (getgid _) -> the real gid, its pair -- `id` owes the primary group as a fact, and
//               the /etc/passwd row is only where the group usually is, not where it is.
static lvm(lvm_getuid) { Sp[0] = putcharm(getuid()); ai_musttail return Next(1); }
static lvm(lvm_getgid) { Sp[0] = putcharm(getgid()); ai_musttail return Next(1); }

// (fork _) -> child pid | 0 in the child | a nom. fork without exec -- the
// shell's subshell: the child evals a subtree and quits, and must never return
// to the reader loop (doc/misc/posix.md's open question, answered conservatively:
// the child owns a full copy-on-write address space, so the GC is fine; the
// discipline is all in the caller -- flush out/err before, child = eval+quit).
static ai_inline ai_word host_fork(struct ai *g) {
 fflush(NULL);
 pid_t pid = fork();
 return pid < 0 ? ai_err(g, errno) : putcharm(pid); }
static lvm(lvm_fork) { Sp[0] = host_fork(g); ai_musttail return Next(1); }

// (dup2 src dst) -> () | a nom | 'badarg. the self-redirect (a forked subshell
// laying its own fdmap, a compound's `done < file` swap).
// (dup fd) -> a fresh fd duplicating fd (>= 3, clear of stdio) | a nom. the
// save half of the swap.
static ai_inline ai_word host_dup2(struct ai *g, ai_word sw, ai_word dw) {
 return !charmp(sw) || !charmp(dw) ? ai_badarg(g) :
        dup2((int) getcharm(sw), (int) getcharm(dw)) < 0 ? ai_err(g, errno) :
        ZeroPoint; }

static lvm(lvm_dup2) { Sp[1] = host_dup2(g, Sp[0], Sp[1]); Sp += 1; ai_musttail return Next(1); }

static ai_inline ai_word host_dup(struct ai *g, ai_word w) {
 if (!charmp(w)) return ai_badarg(g);
 int fd = fcntl((int) getcharm(w), F_DUPFD, 3);
 return fd < 0 ? ai_err(g, errno) : putcharm(fd); }

static lvm(lvm_dup) { Sp[0] = host_dup(g, Sp[0]); ai_musttail return Next(1); }

// --- pid1 bringup: mount the early filesystems + cgroup dirs ----------------------
// (mkdir path mode) -> mkdir(2). () | a nom | 'badarg misuse. mode is octal (493 = 0755).
// also makes cgroup dirs (cgroup-v2 placement is then `open` + `say` the control file).
// (mount src tgt type) -> mount(2), flags 0 / no data (enough for proc/sysfs/tmpfs).
//   () | a nom | 'badarg misuse. needs privilege: run as pid1/root, or after (newns 0).
// (newns _) -> unshare a private user+mount namespace and selfmap to root-in-ns, so
//   (mount ...) works unprivileged (the standard setgroups-deny + uid_map/gid_map).
//   () | a nom. a real pid1 skips this -- it already is root.
static lvm(lvm_mkdir) {
 char const *p = str_c(Sp[0]);
 if (!p) { Sp[1] = ai_badarg(g); Sp += 1; ai_musttail return Next(1); }
 intptr_t mode = charmp(Sp[1]) ? getcharm(Sp[1]) : 0755;
 Sp[1] = mkdir(p, (mode_t) mode) ? ai_err(g, errno) : ZeroPoint;
 ai_musttail return Nextp(1, 1); }

#if defined(AiHaveMount)
static ai_inline ai_word host_mount(struct ai *g, ai_word a, ai_word b, ai_word c) {
 char const *src = str_c(a), *tgt = str_c(b), *typ = str_c(c);
 if (!src || !tgt || !typ) return ai_badarg(g);
 return mount(src, tgt, typ, 0, NULL) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_mount) { Sp[2] = host_mount(g, Sp[0], Sp[1], Sp[2]); Sp += 2; ai_musttail return Next(1); }
#else
// the call is there; our mount speaks a shape this kernel does not answer.
static lvm(lvm_mount) { Sp[2] = ai_err(g, ENOSYS); Sp += 2; ai_musttail return Next(1); }
#endif

#if defined(AiHaveNamespaces)
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

// --- the general POSIX fs surface (the posix_ symbol namespace; doc/misc/posix.md L0,
// staging step 1) -- these serve any program, not just the supervisor, so their C
// symbols wear the posix_ prefix; the love names stay the plain POSIX words.
// (stat path|fd) -> (size mtime mode ns uid gid nlink blocks ino) | a nom
//                   ('enoent absent, 'eacces unreadable, ..) | 'badarg. a charm is an
//                   open fd and the answer is fstat's, the tuple the same either way.
//                   size in bytes, mtime in milliseconds (the (clock t) scale), mode
//                   the raw st_mode charm: kind reads off the S_IFMT bits in love
//                   ((& mode 61440): 32768 file, 16384 dir, 40960 link) and the
//                   permission bits ride along; ns the same mtime whole in nanoseconds,
//                   one charm (fits a fixnum to year 2262) -- the resolution a builder
//                   wants, where two writes in one millisecond still order (cook).
//                   blocks is st_blocks, 512-byte units, which is disk usage and not
//                   the size (du's whole subject; a sparse file says less than it is).
// the tail is append-only and a reader asks `tally` before it
//                   reads past ns: the kernel's own stat (src/inle/kmain.c) answers the
//                   first four alone, having no ownership to tell about.
// (lstat path)   -> the same tuple, of the link itself where the path names one. du and
//                   `stat` owe the link's own blocks and mode, not its target's, and a
//                   dangling link still has a truth to tell about itself. on a charm it
//                   is `stat`: an fd already names the thing and no link is in the way.
// (readdir path) -> the entry names, a list of strings ("." and ".." dropped); an
//                   empty directory is (), told from every failure by kind: a nom
//                   ('enoent, 'enotdir, 'eacces ..) | 'badarg. no order promised
//                   (readdir order, prepended) -- sort in love.
// (unlink path)  -> () ok | a nom | 'badarg misuse.
// (lseek fd off whence) -> the new offset | a nom | 'badarg misuse. raw fds, the
//                   openfd lane -- not ports (a port's read buffer would desync
//                   under a seek). whence: 0 SET, 1 CUR, 2 END, and a stranger is the
//                   row's 'einval rather than a quiet SET.
ai_noinline static struct ai *host_stat_tuple(struct ai *g, int follow) {
 ai_word x = g->sp[0];
 struct stat st;
 if (charmp(x)) {
  if (getcharm(x) < 0) return g->sp[0] = ai_badarg(g), g;
  if (fstat((int) getcharm(x), &st)) return g->sp[0] = ai_err(g, errno), g; }
 else {
  char const *p = str_c(x);
  if (!p) return g->sp[0] = ai_badarg(g), g;
  if (follow ? stat(p, &st) : lstat(p, &st)) return g->sp[0] = ai_err(g, errno), g; }
 intptr_t ms = (intptr_t) st.st_mtim.tv_sec * 1000 + st.st_mtim.tv_nsec / 1000000,
          ns = (intptr_t) st.st_mtim.tv_sec * 1000000000 + st.st_mtim.tv_nsec;
 if (!ai_ok(g = ai_have(g, 9 * Width(struct ai_chain)))) return g;
 size_t const C = Width(struct ai_chain);
 struct ai_chain *c = ini_chain(bump(g, C), putcharm(st.st_ino), ZeroPoint);
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

static ai_inline ai_word host_posix_unlink(struct ai *g, ai_word arg) {
 char const *p = str_c(arg);
 if (!p) return ai_badarg(g);
 return unlink(p) ? ai_err(g, errno) : ZeroPoint; }

static lvm(lvm_posix_unlink) {
  Sp[0] = host_posix_unlink(g, Sp[0]);
  ai_musttail return Next(1); }

// (setenv name val) -> () | a nom | 'badarg misuse; a non-string val unsets
// (the absence lane: (setenv n ()) clears n from the environment).
// (environ _)       -> the environment as a list of "name=value" strings (the raw
//                      POSIX shape -- split at the first '=' in love; no order promised).
static ai_inline ai_word host_posix_setenv(struct ai *g, ai_word nw, ai_word vw) {
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

static ai_inline ai_word host_posix_lseek(struct ai *g, ai_word fdw, ai_word offw, ai_word whw) {
 if (!charmp(fdw) || !charmp(offw) || !charmp(whw)) return ai_badarg(g);
 intptr_t w = getcharm(whw);
 // the three by name, a platform's numbers being its own; anything else goes down
 // as -1, which no seat takes, so the row answers 'einval. reading a stranger as
 // SET would seek to 0 and call it success.
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
  nif_newns[]   = {{lvm_newns}, {lvm_ret0}},
  nif_posix_stat[]    = {{lvm_posix_stat}, {lvm_ret0}},
  nif_posix_lstat[]   = {{lvm_posix_lstat}, {lvm_ret0}},
  nif_posix_readdir[] = {{lvm_posix_readdir}, {lvm_ret0}},
  nif_posix_unlink[]  = {{lvm_posix_unlink}, {lvm_ret0}},
  nif_posix_lseek[]   = {{lvm_cur}, {.x = putcharm(3)}, {lvm_posix_lseek}, {lvm_ret0}},
  nif_sigclear[]      = {{lvm_sigclear}, {lvm_ret0}},
  nif_sigignp[]       = {{lvm_sigignp}, {lvm_ret0}},
  nif_posix_signal[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_signal}, {lvm_ret0}},
  nif_posix_ttyfg[]   = {{lvm_posix_ttyfg}, {lvm_ret0}},
  nif_posix_setenv[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_posix_setenv}, {lvm_ret0}},
  nif_posix_environ[] = {{lvm_posix_environ}, {lvm_ret0}};
AiNif("spawn", nif_spawn);
AiNif("glean",  nif_reapany);
AiNif("sigfd", nif_sigfd);
AiNif("sigtake", nif_sigtake);
AiNif("sigclear", nif_sigclear);
AiNif("sigign?", nif_sigignp);
AiNif("wait",  nif_waitpid);
AiNif("chdir", nif_chdir);
AiNif("cwd",   nif_cwd);
AiNif("selfpath", nif_selfpath);
AiNif("pipe",  nif_pipe);
AiNif("openfd", nif_openfd);
AiNif("spawnio", nif_spawnio);
AiNif("fdopen", nif_fdopen);
AiNif("spawnmap", nif_spawnmap);
AiNif("getuid", nif_getuid);
AiNif("getgid", nif_getgid);
AiNif("fork", nif_fork);
AiNif("dup2", nif_dup2);
AiNif("dup", nif_dup);
AiNif("mkdir", nif_mkdir);
AiNif("mount", nif_mount);
AiNif("newns", nif_newns);
AiNif("stat",    nif_posix_stat);
AiNif("lstat",   nif_posix_lstat);
AiNif("readdir", nif_posix_readdir);
AiNif("unlink",  nif_posix_unlink);
AiNif("lseek",   nif_posix_lseek);
AiNif("signal",  nif_posix_signal);
AiNif("ttyfg",   nif_posix_ttyfg);
AiNif("setenv",  nif_posix_setenv);
AiNif("environ", nif_posix_environ);
// --- the rest of the fs surface: the effect ops the fs tools ride ---------------
// (mv, ln, touch, chmod, chown -- src/apps/kore/fs.l and friends).
//   (rename old new)      -> () | a nom | 'badarg  (mv's heart; same filesystem)
//   (symlink target path) -> () | a nom | 'badarg  (path becomes a link to target)
//   (readlink path)       -> the target string | a nom | 'badarg
//   (chmod path mode)     -> () | a nom | 'badarg  (mode the raw permission charm)
//   (chown path uid gid)  -> () | a nom | 'badarg  (-1 leaves that id alone)
//   (utime path ms)       -> () | a nom | 'badarg  (mtime and atime on the stat
//                            scale, milliseconds; a non-charm ms reads "now")
//   (umask mask)          -> the previous mask | 'badarg misuse (always succeeds)
//   (rmdir path)          -> () | a nom | 'badarg  (the empty-directory unlink)
//   (hardlink old new)    -> () | a nom | 'badarg  (link(2); `link` the word is
//                            the chain ctor, the most spoken name in the prel,
//                            so the nif wears the long form)
static ai_inline ai_word host_posix_rename(struct ai *g, ai_word ow, ai_word nw) {
 char const *o = str_c(ow), *n = str_c(nw);
 if (!o || !n) return ai_badarg(g);
 return rename(o, n) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_rename) {
 Sp[1] = host_posix_rename(g, Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }

static ai_inline ai_word host_posix_symlink(struct ai *g, ai_word tw, ai_word pw) {
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

static ai_inline ai_word host_posix_chmod(struct ai *g, ai_word pw, ai_word mw) {
 char const *p = str_c(pw);
 if (!p || !charmp(mw)) return ai_badarg(g);
 return chmod(p, (mode_t) getcharm(mw)) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_chmod) {
 Sp[1] = host_posix_chmod(g, Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }

static ai_inline ai_word host_posix_chown(struct ai *g, ai_word pw, ai_word uw, ai_word gw) {
 char const *p = str_c(pw);
 if (!p || !charmp(uw) || !charmp(gw)) return ai_badarg(g);
 return chown(p, (uid_t) getcharm(uw), (gid_t) getcharm(gw)) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_chown) {
 Sp[2] = host_posix_chown(g, Sp[0], Sp[1], Sp[2]);
 ai_musttail return Nextp(1, 2); }

ai_noinline static ai_word host_posix_utime(struct ai *g, ai_word pw, ai_word msw) {
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

static ai_inline ai_word host_posix_rmdir(struct ai *g, ai_word pw) {
 char const *p = str_c(pw);
 if (!p) return ai_badarg(g);
 return rmdir(p) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_rmdir) { Sp[0] = host_posix_rmdir(g, Sp[0]); ai_musttail return Next(1); }

static ai_inline ai_word host_posix_hardlink(struct ai *g, ai_word ow, ai_word nw) {
 char const *o = str_c(ow), *n = str_c(nw);
 if (!o || !n) return ai_badarg(g);
 return link(o, n) ? ai_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_hardlink) {
 Sp[1] = host_posix_hardlink(g, Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }

// (copyfile src dst) -> bytes copied | a nom ('badarg misuse).
// src's bytes into dst, without either passing through the heap.
// the one that wanted it is the seed: `love source` lays bin/love by copying the running
// artifact, ~12 MB, and slurping that made a love string the collector then had to carry
// through a two-space flip. bytes only -- mode is the caller's to set, which is what both
// callers already did (kore's ucopy chmods from its own stat, src-lay-love wants 493).
// a plain read/write loop, and not because copy_file_range is unavailable: that call is
// linux-only (4.5, cross-fs 5.3) and may short-copy or refuse with EXDEV/EINVAL anyway, so
// a correct use needs this loop under it regardless. the loop is the contract; the syscall
// would be one guarded branch inside it, worth adding when a profile asks.
// and the buffer lives in a helper, not in the lvm_ -- 64K owed at a tail turns the jump
// into a ret and grows the stack every dispatch (love.h's no-scratch rule).
ai_noinline static ai_word host_posix_copyfile(struct ai *g, ai_word sw, ai_word dw) {
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
AiNif("rename",   nif_posix_rename);
AiNif("symlink",  nif_posix_symlink);
AiNif("readlink", nif_posix_readlink);
AiNif("chmod",    nif_posix_chmod);
AiNif("chown",    nif_posix_chown);
AiNif("utime",    nif_posix_utime);
AiNif("umask",    nif_posix_umask);
AiNif("rmdir",    nif_posix_rmdir);
AiNif("hardlink", nif_posix_hardlink);
AiNif("copyfile", nif_posix_copyfile);
// --- the pty wrapper: bao's rlwrap/debugger muscle ------------------------------
// spawn a program on a fresh pseudo-terminal, reap it without blocking, signal
// it, and read/write its window size. the keystone, (tether argv), is hark
// (main.c) with the stdout pipe swapped for a pty pair: the same argv marshal +
// close-on-exec errno-pipe handshake, but the child's 0/1/2 become the pty slave
// and the parent keeps the master as a heap port (ai_io_alloc). so bao's editor
// talks to any program over the master the way a terminal would.
//
//   (tether argv)      -> (pid . master-port) | a nom ('badarg misuse)
//   (reap pid)         -> (status)   exited (a pair, truthy even at status 0)
//                       | ()         still running
//                       | a nom      waitpid error (e.g. 'echild)
//   (kill pid sig)     -> () ok | a nom  (caller passes (0 - pid) for the group)
//   (winsize _)        -> (rows . cols) of the controlling tty (stdout), or a nom
//   (setwinsize p r c) -> () ok | a nom  push a size onto a master port
//
// (winsize) takes a dummy arg (ignored, like getpid): a bare (winsize) is the
// function itself -- (f) == f at zero operands -- so the call is (winsize 0).

// workhorse for (tether argv), called with g Packed; argv is the single arg and
// the sole GC root at g->sp[0]. leaves exactly one net value above argv on every
// non-oom path (so lvm_tether collapses uniformly, cf. hark): the
// (pid . master-port) chain on success, an errno nom / 'badarg otherwise.
// returns a not-ok g only on oom (lvm_tether routes that to ghelp).
ai_noinline static struct ai *host_tether(struct ai *g) {
  // no l allocation between the marshal and the fork: openpt/grantpt/unlockpt/
  // ptsname/pipe don't touch the heap, so the uncommitted gap holds.
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

// workhorse for (reap pid), called with g Packed and pid at g->sp[0]. the &st
// (reap pid): non-blocking wait. a reaped child returns its decoded status as a
// one-element list so the result is a present chain even at status 0 -- a caller
// polling in a loop tells "exited 0" (a pair) from "still running" (()) without
// the two collapsing to the same blue. a nom means waitpid itself erred.
static lvm(lvm_reap) {
 LvmCall(g, host_reap, (pid_t) (charmp(Sp[0]) ? getcharm(Sp[0]) : 0)) }

// (kill pid sig): POSIX kill(2). a negative pid signals the process group.
// () ok | a nom | 'badarg -- a non-charm pid may not fold to 0, which would
// signal the caller's own whole group.
static lvm(lvm_kill) {
 if (!charmp(Sp[0]) || !charmp(Sp[1])) {
  Sp[1] = ai_badarg(g); ai_musttail return Nextp(1, 1); }
 Sp[1] = kill((pid_t) getcharm(Sp[0]), (int) getcharm(Sp[1])) ? ai_err(g, errno) : ZeroPoint;
 ai_musttail return Nextp(1, 1); }

// workhorse for (winsize), called with g Packed (the dummy arg sits at sp[0]).
// the &ws ioctl + the chain alloc live here so lvm_winsize's Continue() tail-jumps
// (cf. host_tether). overwrites sp[0] with (rows . cols), or a nom if stdout
// isn't a tty. returns a not-ok g only on oom (lvm_winsize routes that to ghelp).
ai_noinline static struct ai *host_winsize(struct ai *g) {
 struct winsize ws;
 if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) < 0) { g->sp[0] = ai_err(g, errno); return g; }
 if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
 struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 putcharm(ws.ws_row), putcharm(ws.ws_col));
 g->sp[0] = word(w);
 return g; }

// (winsize): the controlling tty's size as (rows . cols), read off stdout; a nom
// ('enotty) if stdout isn't one. the size to mirror onto a wrapped child.
static lvm(lvm_winsize) {
 LvmCall(g, host_winsize) }

// (setwinsize port rows cols): push a window size onto a master port; the kernel
// raises SIGWINCH on the slave's foreground group. () on success, a nom on
// failure (incl. a non-port / closed port -> 'ebadf).
// the &ws ioctl for (setwinsize), off lvm_setwinsize's frame so its Continue()
// tail-jumps. returns 0 or the errno.
ai_noinline static int host_setwinsize(intptr_t fd, intptr_t row, intptr_t col) {
 struct winsize ws = {0};
 ws.ws_row = (unsigned short) row;
 ws.ws_col = (unsigned short) col;
 return ioctl((int) fd, TIOCSWINSZ, &ws) ? -errno : 0; }

static lvm(lvm_setwinsize) {
 intptr_t fd  = ai_port_fd(Sp[0]),
          row = charmp(Sp[1]) ? getcharm(Sp[1]) : 0,
          col = charmp(Sp[2]) ? getcharm(Sp[2]) : 0;
 int rc = host_setwinsize(fd, row, col);
 Sp[2] = rc ? ai_err(g, -rc) : ZeroPoint;
 ai_musttail return Nextp(1, 2); }

// (ptyecho port on): toggle the pty's input ECHO. on = 0 / () clears it so a
// line-editing wrapper (bao's edraw) owns the echo and the child's cooked-mode
// echo doesn't double it; a truthy `on` restores it. ICANON is left intact -- the
// child still reads whole lines and sees VEOF. tcsetattr on the master fd sets the
// shared pty termios. () on success, a nom on failure (non-port / closed ->
// 'ebadf). the &t tcget/tcsetattr for (ptyecho), off lvm_ptyecho's frame so its
// Continue() tail-jumps. returns 0 or a negated errno (EBADF for a non-port fd).
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

// (raw on): own the interactive terminal discipline on stdin (fd 0). a truthy
// `on` puts the tty in raw mode (no ICANON/ECHO/ISIG, VMIN=1) so bao's editor is
// the sole echo; on = 0 / () restores the cooked termios captured at the first
// raw-on. bao's (shell _) calls (raw 1) because the bin/bao launch
// (love -l bao.l -e "(bao 0)") passes argv, so main.c's argp path never raws --
// without this the kernel tty echo doubles every line the editor draws. () on
// success, a nom on failure ('enotty: stdin is no tty).
// one terminal, so one saved baseline and one atexit -- main.c's repl calls this too
// (ai_raw_mode). two owners each capturing their own cooked state would be correct only
// by atexit's LIFO ordering.
static struct termios raw_cooked;
static int raw_have_cooked = 0;
static void raw_restore(void) {
 if (raw_have_cooked) tcsetattr(STDIN_FILENO, TCSANOW, &raw_cooked); }
// all the &t termios work + the capture-once/atexit state for (raw on), off
// lvm_raw's frame so its Continue() tail-jumps. returns 0 or the errno.
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

// (swig port b): drink whatever the fd has waiting into cask b, without blocking
// (the caller parks on `see` for the first byte; swig drains the rest of the gulp).
// n bytes read; 0 = nothing waiting or eof (the next see tells those apart); a
// nom = failure ('badarg misuse). the chunk lane a per-byte see cannot be.
static lvm(lvm_swig) {
 ai_word p = Sp[0], x = Sp[1], out = ai_badarg(g);
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
// posix surface like everything above, and one body per behaviour (plan C2):
// on inle the open(2)/close(2) below land in src/inle/sys.c's arms, so the ramfs
// answers the same nif. ⚠ `open`'s PRESENCE in the book is what lights up
// prel's module walk (src/core/boot/prel.l's fsopen, by peep) and salt's config read --
// both gate on the name, so the registration below is the whole wiring.

// mode is a l string; only the first byte is consulted: r read, w truncate-or-
// create, a append-or-create. an unknown mode is misuse ('badarg upstairs);
// open(2)'s refusal comes up as its nom, so the caller that cares tells 'etxtbsy
// (relinking a binary that is running) from 'enoent by name.
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

// (open path mode) -- a heap port (closed on GC), or a nom: open(2)'s errno,
// 'badarg for misuse (a non-string argument, an unknown mode). the value-op
// convention at the head of this file. ⚠ a failure is TRUTHY now (a nom nets
// positive), so a caller may not ask ? of the answer -- port? is the success
// test, nom? the failure test, and both are exact.
static lvm(lvm_open) {
  long rc = -1;
  if (!strp(Sp[0]) || !strp(Sp[1])) goto fail;
  struct ai_str *pv = str(Sp[0]), *mv = str(Sp[1]);
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

// (close x) -- a port, or a raw fd from openfd/pipe/dup. on a port: flush, close,
// and HAND IT THE CLOSED VT, so every later read, write and flush finds the door
// that does nothing and the finalizer, which asks the vt for an fd, skips; answers
// (). on a charm: close(2), () ok | a nom. no-op on anything else.
static lvm(lvm_close) {
  if (charmp(Sp[0])) {
    intptr_t fd = getcharm(Sp[0]);
    Sp[0] = (fd >= 0 && close((int) fd)) ? ai_err(g, errno) : ZeroPoint;
    ai_musttail return Next(1); }
  // inline "is x a port": heap pointer whose discriminator is lvm_port_io.
  if (cell(Sp[0])->ap == lvm_port_io) {
    struct ai_io *io = (struct ai_io*) Sp[0];
    intptr_t fd = ai_io_fd(io);
    if (fd >= 0) {
      g->io = io;
      Pack(g);
      g = ai_io_wflush(g, io);   // buffered bytes land before the fd dies
      if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g);
      // the device would not take the whole run: park and come back. nothing has been
      // mutated yet -- the fd is open and Ip unadvanced -- so the re-run is this same
      // close from the top. blocking here would stop every task for one slow peer.
      if (ai_io_wpending(g, (struct ai_io*) g->sp[0])) {
        Unpack(g);
        g->next_wake_at = ai_clock() + 1;
        ai_musttail return Ap(lvm_yield_sw, g); }
      Unpack(g);
      close(fd);
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
  nif_winsize[]    = {{lvm_winsize}, {lvm_ret0}},
  nif_setwinsize[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_setwinsize}, {lvm_ret0}},
  nif_ptyecho[]    = {{lvm_cur}, {.x = putcharm(2)}, {lvm_ptyecho}, {lvm_ret0}};
AiNif("tether", nif_tether);
AiNif("gather", nif_reap);
AiNif("still", nif_kill);
AiNif("winsize", nif_winsize);
AiNif("setwinsize", nif_setwinsize);
AiNif("ptyecho", nif_ptyecho);
AiNif("raw", nif_raw);
AiNif("swig", nif_swig);
AiNif("open", nif_open);
AiNif("close", nif_close);
