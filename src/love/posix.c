// posix.c -- the POSIX surface: process and job control, fs, environment, fds, the pty.
//   effect ops answer () ok | 'enoent | 'badarg
//   value ops answer the value | () absence | 'enoent | 'badarg
// an errno comes back as its nom (boot-interned, no allocation); 'badarg is a refusal before
// any syscall, never a posix name
#define _GNU_SOURCE     // unshare / CLONE_* (newns), posix_openpt/grantpt/unlockpt/ptsname
#include "love.h"
#include "archive/srctree.h"   // the carried tree, under /love (lovefs.c)
#include "vfs.h"
#include <unistd.h>     // fork execvp _exit read close getuid/getgid symlink readlink chown
#include <stdio.h>      // fflush, rename
#include <stdlib.h>     // setenv/unsetenv, posix_openpt grantpt unlockpt ptsname
#include <string.h>     // memcpy
#include <errno.h>
#include <signal.h>     // sigprocmask kill, SIGCHLD/SIGTERM (sigfd)
#include <fcntl.h>      // open, O_*, AT_FDCWD, FD_CLOEXEC
#include <sys/stat.h>   // mkdir, stat, chmod, umask, utimensat UTIME_NOW
#include <sys/wait.h>   // waitpid, WIF* (proc_status)
#include <spawn.h>      // posix_spawnp: a kernel with no fork
#include <sys/ioctl.h>  // ioctl TIOCSCTTY TIOC[GS]WINSZ struct winsize
#include <termios.h>    // tcgetattr tcsetattr ECHO TCSANOW (ptyecho, raw)
#include <dirent.h>     // opendir/readdir/closedir
#include <fnmatch.h>    // fnmatch (glob's pattern law)
#include <regex.h>      // regcomp regexec (re's engine)
#include <sys/mman.h>       // madvise (the spawn guard)
#include <sys/resource.h>   // getrusage, RUSAGE_SELF/CHILDREN (the cpu clocks)
#include <time.h>           // clock_gettime, for love_clock

// what this libc carries, not which kernel runs it: moonlibc carries every door, and a door
// the kernel lacks answers ENOSYS at run time (one binary, three kernels)
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

#include <sys/utsname.h>     // uname(2), on every seat that links this file
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
#include <sys/reboot.h>     // reboot(2), linux's commands
#endif
#if defined(LvHaveNamespaces)
#include <sched.h>          // unshare, CLONE_NEWUSER/NEWNS (newns)
#endif
#if defined(LvHaveStatfs)
#include <sys/vfs.h>        // statfs(2), the block and inode counts df reports
#endif
// CLOCK_REALTIME in ms: the one scale for deadlines, (clock t) and every mtime
love_noinline uintptr_t love_clock(void) {
 struct timespec ts;
 return clock_gettime(CLOCK_REALTIME, &ts) ? (uintptr_t) -1 :
  (uintptr_t) (ts.tv_sec * 1000 + ts.tv_nsec / 1000000); }

// the strings at g->sp[0] -> a char** laid in the heap gap at hp, which host_spawn_guard keeps
// mapped across a fork; consumed before any further allocation. *cavp NULL with g ok is a
// misuse, with g not ok an oom. envat >= 0 lays g->sp[envat]'s K=V list after it in *cevp
static struct g *argv_env_marshal(struct g *g, char ***cavp, int envat, char ***cevp) {
 *cavp = NULL;
 if (cevp) *cevp = NULL;
 word argv = g->sp[0], env = envat >= 0 ? g->sp[envat] : ZeroPoint;
 uintptr_t argc = 0, total = 0, envc = 0, etotal = 0;
 // a (path . name) head names the child name and lays path past argv's NULL for argv_file,
 // so the exec does not walk PATH again
 word h = chainp(argv) ? A(argv) : ZeroPoint;
 int alt = chainp(h) && cstrp(A(h)) && strp(B(h));
 for (word p = argv; chainp(p); p = B(p)) {
  word e = !argc && alt ? B(h) : A(p);
  if (!cstrp(e)) return g;
  argc++, total += len(e) + 1; }
 if (!argc) return g;
 if (alt) total += len(A(h)) + 1;
 if (env != ZeroPoint && !chainp(env)) return g;             // misuse: env not a list
 for (word p = env; chainp(p); p = B(p)) {
  word e = A(p);
  if (!cstrp(e) || !len(e) || txt(e)[0] == '=' || !memchr(txt(e), '=', len(e))) return g;   // K=V
  envc++, etotal += len(e) + 1; }
 uintptr_t aw = argc + 2 + b2w(total), ew = envc ? envc + 1 + b2w(etotal) : 0;
 if (!ok(g = have(g, aw + ew))) return g;
 argv = g->sp[0];                            // have may have collected
 env = envat >= 0 ? g->sp[envat] : ZeroPoint;
 h = A(argv);
 char **cav = (char**) g->hp,
      *blob = (char*) (g->hp + (argc + 2));
 uintptr_t off = 0, i = 0;
 for (word p = argv; chainp(p); p = B(p), i++) {
  struct str *s = str(!i && alt ? B(h) : A(p));
  memcpy(blob + off, txt(s), len(s));
  blob[off + len(s)] = 0;
  cav[i] = blob + off;
  off += len(s) + 1; }
 cav[argc] = NULL;
 cav[argc + 1] = NULL;
 if (alt) {
  struct str *s = str(A(h));
  memcpy(blob + off, txt(s), len(s));
  blob[off + len(s)] = 0;
  cav[argc + 1] = blob + off; }
 if (envc) {
  char **cev = (char**) (g->hp + aw), *eb = (char*) (g->hp + aw + envc + 1);
  uintptr_t eo = 0, j = 0;
  for (word p = env; chainp(p); p = B(p), j++) {
   struct str *s = str(A(p));
   memcpy(eb + eo, txt(s), len(s));
   eb[eo + len(s)] = 0;
   cev[j] = eb + eo;
   eo += len(s) + 1; }
  cev[envc] = NULL;
  *cevp = cev; }
 *cavp = cav;
 return g; }
struct g *love_argv_marshal(struct g *g, char ***cavp) { return argv_env_marshal(g, cavp, -1, NULL); }

// a wait(2) status -> the exit code, 128+signal, or -1
static love_inline int proc_status(int st) {
 return WIFEXITED(st) ? WEXITSTATUS(st)
       : WIFSIGNALED(st) ? 128 + WTERMSIG(st) : -1; }

// NULL for a non-string or an inner NUL; bytes[len] is always a NUL (love.h)
static love_inline char const *str_c(word x) { return cstrp(x) ? txt(x) : NULL; }

// a misuse pushes 'badarg, so `if (!*cavp) return g` covers it and oom alike
static struct g *argv_marshal(struct g *g, char ***cavp) {
 g = love_argv_marshal(g, cavp);
 return !*cavp ? push(g, 1, badarg(g)) : g; }

// SIG_IGN and the mask both survive exec: every exec-bound child leaves through here, or
// ^C misses it and `yes | head` never stops. main.c's two exec sites reset by hand. what the
// shell asked to stay ignored (trap '', g->child_ign) goes back on after, as POSIX has it
static void sig_dfl_job(uint64_t ign) {
 signal(SIGINT, SIG_DFL); signal(SIGQUIT, SIG_DFL); signal(SIGPIPE, SIG_DFL);
 signal(SIGTSTP, SIG_DFL); signal(SIGTTIN, SIG_DFL); signal(SIGTTOU, SIG_DFL);
 for (int s = 1; s < 64; s++) if (ign >> s & 1) signal(s, SIG_IGN);
 sigset_t none; sigemptyset(&none); sigprocmask(SIG_SETMASK, &none, NULL); }

// (sigign? sig): POSIX lets a non-interactive shell not trap a signal ignored on entry
love_noinline static word host_sigignp(word sigw) {
 struct sigaction sa;
 if (!charmp(sigw)) return putcharm(0);
 if (sigaction((int) getcharm(sigw), NULL, &sa)) return putcharm(0);
 return putcharm(sa.sa_handler == SIG_IGN ? 1 : 0); }
static lvm(lvm_sigignp) { Sp[0] = host_sigignp(Sp[0]); love_musttail return Next(1); }

// (sigclear _): for a forked subshell, which never reaches sig_dfl_job's exec
love_noinline static word host_sigclear(struct g *g) {
 sigset_t none; sigemptyset(&none);
 return sigprocmask(SIG_SETMASK, &none, NULL) ? love_err(g, errno) : ZeroPoint; }
static lvm(lvm_sigclear) { Sp[0] = host_sigclear(g); love_musttail return Next(1); }

// (childign sigs) -> (): the signals a spawned child keeps ignored (a shell's trap '')
static lvm(lvm_childign) {
 uint64_t m = 0;
 for (word l = Sp[0]; chainp(l); l = B(l))
  if (charmp(A(l)) && getcharm(A(l)) > 0 && getcharm(A(l)) < 64) m |= (uint64_t) 1 << getcharm(A(l));
 g->child_ign = m;
 Sp[0] = ZeroPoint;
 love_musttail return Next(1); }

// the spawn guard: an exec-bound fork inherits no heap pools, so no page tables are copied;
// the (fork) nif and any child that walks the heap inherit whole. best-effort
#if defined(LvHaveDontfork)
static void guard1(void *lo, void *hi, int adv) {
 uintptr_t a = ((uintptr_t) lo + 4095) & ~(uintptr_t) 4095,
           b = (uintptr_t) hi & ~(uintptr_t) 4095;
 if (b > a) (void) madvise((void*) a, (long) (b - a), adv); }
#endif
void host_spawn_guard(struct g *g, int on) {
#if defined(LvHaveDontfork)
 int adv = on ? MADV_DONTFORK : MADV_DOFORK;
 guard1(g, g->hp, adv);                       // not the block top: the argv sits above hp
 guard1(g->major_base, g->major_base + g->major_len, adv);
#else
#endif
}

// before a fork: a seekable stdin gives back what the reader holds ahead, so parent and
// child both stand where the reader does (the offset is shared)
static void stdin_exact(struct g *g) {
 if (!g->inport || lseek(STDIN_FILENO, 0, SEEK_CUR) < 0) return;   // a pipe or a tty
 struct io *i = (struct io*) g->inport;
 int u = getcharm(love_stdin.io.ungetc_buf) != EOF;
 uintptr_t n = io_pending(g, i) + (u ? 1 : 0);
 if (!n || lseek(STDIN_FILENO, -(off_t) n, SEEK_CUR) < 0) return;
 io_unread(g, i, -(intptr_t) io_pending(g, i));
 if (u) love_stdin.io.ungetc_buf = putcharm(EOF); }

// every fd love opens is cloexec; dup2 onto itself keeps the flag, so that case clears it
static void fd_give(int s, int d) {
 if (s == d) fcntl(d, F_SETFD, 0);
 else dup2(s, d); }

// love's own fds move from 3..9 to 10 up: those are the shell user's (`exec 3>&-`)
static int fd_up(int fd) {
 if (fd < 3 || fd > 9) return fd;
 int h = fcntl(fd, F_DUPFD_CLOEXEC, 10);
 return h < 0 ? fd : (close(fd), h); }

// openfd's modes: 0 read, 1 truncate, 2 append, 3 exclusive, 4 write, 5 a tty probe
static int openfd_mode(char const *path, intptr_t m) {
 int flags = m == 1 ? (O_WRONLY | O_CREAT | O_TRUNC)
           : m == 2 ? (O_WRONLY | O_CREAT | O_APPEND)
           : m == 3 ? (O_WRONLY | O_CREAT | O_EXCL)
           : m == 4 ? O_WRONLY
           : m == 5 ? (O_RDWR | O_NOCTTY | O_NONBLOCK)
           : O_RDONLY;
 return fd_up(open(path, flags | O_CLOEXEC, m == 3 ? 0600 : 0644)); }

// a deferred redirect (path mode msg), opened in the child where a fifo may block; a
// failure says msg and exits 1
static void spawn_open(int cfd, word d) {
 char const *p = str_c(A(d));
 word m = chainp(B(d)) ? A(B(d)) : ZeroPoint,
      w = chainp(B(d)) && chainp(B(B(d))) ? A(B(B(d))) : ZeroPoint;
 int fd = p ? openfd_mode(p, charmp(m) ? getcharm(m) : 0) : -1;
 if (fd < 0) {
  char const *s = str_c(w);
  if (s) (void) !write(2, s, strlen(s));
  _exit(1); }
 fd_give(fd, cfd);
 if (fd != cfd) close(fd); }

// a map's source fd: a charm or a port's fd, else -1
static intptr_t map_src(word sw) { return charmp(sw) ? getcharm(sw) : port_fd(sw); }

// a kernel with no fork (inle) spawns: the triple and fdmap become posix_spawn's actions,
// and a failed deferred redirect refuses the spawn
love_noinline static struct g *host_spawnk(struct g *g, char **cav, int const io[3],
                                           word fdmap, word closes, intptr_t pg) {
 posix_spawn_file_actions_t fa;
 posix_spawnattr_t at;
 posix_spawn_file_actions_init(&fa), posix_spawnattr_init(&at);
 if (pg >= 0) posix_spawnattr_setflags(&at, POSIX_SPAWN_SETPGROUP), posix_spawnattr_setpgroup(&at, (pid_t) pg);
 int opened[16], no = 0, e = 0;
 for (int i = 0; !e && i < 3; i++) if (io[i] >= 0) e = posix_spawn_file_actions_adddup2(&fa, io[i], i);
 for (word p = fdmap; !e && chainp(p); p = B(p)) {
  word x = A(p);
  intptr_t cfd = chainp(x) && charmp(A(x)) ? getcharm(A(x)) : -1;
  if (cfd < 0) continue;
  word sw = B(x);
  if (map_src(sw) >= 0) e = posix_spawn_file_actions_adddup2(&fa, (int) map_src(sw), (int) cfd);
  else if (!chainp(sw)) e = posix_spawn_file_actions_addclose(&fa, (int) cfd);
  else {
   char const *path = str_c(A(sw));
   word m = chainp(B(sw)) ? A(B(sw)) : ZeroPoint,
        w = chainp(B(sw)) && chainp(B(B(sw))) ? A(B(B(sw))) : ZeroPoint;
   int fd = no == 16 ? (errno = EMFILE, -1) : path ? openfd_mode(path, charmp(m) ? getcharm(m) : 0) : (errno = EINVAL, -1);
   if (fd < 0) {
    e = errno;
    char const *t = str_c(w);
    if (t) (void) !write(2, t, strlen(t));
    break; }
   opened[no++] = fd;
   e = posix_spawn_file_actions_adddup2(&fa, fd, (int) cfd); } }
 for (word p = closes; !e && chainp(p); p = B(p))
  if (getcharm(A(p)) > 2) e = posix_spawn_file_actions_addclose(&fa, (int) getcharm(A(p)));
 pid_t pid = -1;
 if (!e) e = posix_spawnp(&pid, argv_file(cav), &fa, &at, cav, environ);
 while (no) close(opened[--no]);
 posix_spawn_file_actions_destroy(&fa), posix_spawnattr_destroy(&at);
 return push(g, 1, e ? love_err(g, e) : putcharm(pid)); }

// the one fork + exec: argv at sp[0]; in/out/err -1 to leave; fdmap ((childfd . srcfd) ..)
// and closes are stack slots read after the marshal, -1 for none. pg >= 0 joins (0 leads) a group
love_noinline static struct g *host_spawnx(struct g *g, int in, int out, int err,
                                          int mapat, int closeat, intptr_t pg, intptr_t fg) {
 char **cav;
 g = argv_marshal(g, &cav);
 if (!cav) return g;
 word fdmap = mapat >= 0 ? g->sp[mapat] : ZeroPoint,
         closes = closeat >= 0 ? g->sp[closeat] : ZeroPoint;
 fflush(NULL);                                               // not twice in the child
 stdin_exact(g);
 pid_t pid = fork();
 if (pid < 0 && errno == ENOSYS) return host_spawnk(g, cav, (int[3]) { in, out, err }, fdmap, closes, pg);
 if (pid < 0) return push(g, 1, love_err(g, errno));
 if (!pid) {
  if (pg >= 0) {
   setpgid(0, (pid_t) pg);
   if (fg) { signal(SIGTTOU, SIG_IGN);          // the handoff, from the background
    tcsetpgrp(0, pg ? (pid_t) pg : getpid()); } }
  if (in  >= 0) fd_give(in, 0);
  if (out >= 0) fd_give(out, 1);
  if (err >= 0) fd_give(err, 2);
  for (word p = fdmap; chainp(p); p = B(p)) {
   word e = A(p);
   if (!chainp(e)) continue;
   intptr_t cfd = charmp(A(e)) ? getcharm(A(e)) : -1;
   if (cfd < 0) continue;
   word sw = B(e);
   if (map_src(sw) >= 0) fd_give((int) map_src(sw), (int) cfd);
   else if (chainp(sw)) spawn_open((int) cfd, sw);
   else close((int) cfd); }
  for (word p = closes; chainp(p); p = B(p)) {
   intptr_t fd = getcharm(A(p));
   if (fd > 2) close((int) fd); }
  sig_dfl_job(g->child_ign);
  execvp(argv_file(cav), cav);
  _exit(127); }
 if (pg >= 0) setpgid(pid, (pid_t) (pg ? pg : pid));   // parent side too: no race window
 return push(g, 1, putcharm(pid)); }

static lvm(lvm_spawn) {
 LvmCallp(g, 1, host_spawnx, -1, -1, -1, -1, -1, -1, 0) }

// (glean 0): sp[0] gets (), a nom, or (status) for a named pid, (pid . status) for any
love_noinline static struct g *host_reap(struct g *g, pid_t pid) {
 int st;
 pid_t r = waitpid(pid, &st, WNOHANG);
 if (r == 0) { g->sp[0] = ZeroPoint; return g; }
 if (r < 0)  { g->sp[0] = love_err(g, errno); return g; }
 if (!ok(g = have(g, Width(struct chain)))) return g;
 word status = putcharm(proc_status(st));
 struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                pid < 0 ? putcharm(r) : status,
                                pid < 0 ? status : ZeroPoint);
 g->sp[0] = word(w);
 return g; }

static lvm(lvm_reapany) {
 LvmCall(g, host_reap, -1) }

// (sigfd sigs): a port over a signalfd (kqueue on the BSDs); the signals are blocked so a
// TERM is an event, not a death. (sigtake port) -> (signo . pid) | (). SIGCHLD coalesces
#if defined(LvHaveSignalfd) || defined(LvHaveKqueue)
#if defined(LvHaveKqueue)
// EVFILT_SIGNAL fires before delivery, so the blocked mask queues here too
static int host_sigkq;
love_noinline static int host_sigfd_kq(word a) {
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
// signalfd, then kqueue: the try is the probe
static int mk_sigfd(struct g *g, void *m) {
 int fd = -1, e = ENOSYS;
#if defined(LvHaveSignalfd)
 if ((fd = signalfd(-1, m, SFD_NONBLOCK | SFD_CLOEXEC)) < 0) e = errno;
#endif
#if defined(LvHaveKqueue)
 if (fd < 0 && e == ENOSYS && (fd = host_sigfd_kq(g->sp[0])) < 0) e = errno;
#endif
 (void) g, (void) m;
 return fd < 0 ? -e : fd; }
// a non-list watches SIGCHLD + SIGTERM
love_noinline static struct g *host_sigfd(struct g *g) {
 sigset_t m;
 sigemptyset(&m);
 word a = g->sp[0];
 if (chainp(a))
  for (word p = a; chainp(p); p = B(p)) {
  if charmp(A(p)) sigaddset(&m, (int) getcharm(A(p))); }
 else { sigaddset(&m, SIGCHLD); sigaddset(&m, SIGTERM); }
 if (sigprocmask(SIG_BLOCK, &m, NULL)) return g->sp[0] = love_err(g, errno), g;
 int fd = mk_sigfd(g, &m);
 if (!ok(g = love_fd_retry(g, &fd, mk_sigfd, &m))) return g;
 if (fd < 0) return g->sp[0] = love_err(g, -fd), g;
 struct g *r = io_alloc(g, fd);
 if (!ok(r)) return close(fd), g->sp[0] = love_err(g, ENOMEM), g;
 g = r;
 return g->sp[1] = g->sp[0], g->sp += 1, g; }                 // port over the dummy arg
static lvm(lvm_sigfd) { LvmCall(g, host_sigfd) }

// kqueue names no sender: pid 0
love_noinline static struct g *host_sigtake(struct g *g, int fd) {
 intptr_t signo, pid;
#if defined(LvHaveKqueue)
 if (host_sigkq) {
  struct kevent ev;
  struct timespec z = {0, 0};
  int k = kevent(fd, 0, 0, &ev, 1, &z);
  if (k < 0)  { g->sp[0] = love_err(g, errno); return g; }
  if (k != 1) { g->sp[0] = ZeroPoint; return g; }
  signo = (intptr_t) ev.ident; pid = 0; }
 else
#endif
 {
#if defined(LvHaveSignalfd)
  struct signalfd_siginfo si;
  ssize_t n = read(fd, &si, sizeof si);
  if (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
   g->sp[0] = love_err(g, errno); return g; }
  if (n != (ssize_t) sizeof si) { g->sp[0] = ZeroPoint; return g; }
  signo = (intptr_t) si.ssi_signo; pid = (intptr_t) si.ssi_pid;
#else
  g->sp[0] = love_err(g, ENOSYS); return g;
#endif
 }
 if (!ok(g = have(g, Width(struct chain)))) return g;
 struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                putcharm(signo), putcharm(pid));
 g->sp[0] = word(w);
 return g; }

static lvm(lvm_sigtake) {
 int fd = (int) port_fd(Sp[0]);
 if (fd < 0) { Sp[0] = badarg(g); love_musttail return Next(1); }
 LvmCall(g, host_sigtake, fd) }
#else
// neither door: the names stay, so init.l loads
static lvm(lvm_sigfd)   { Sp[0] = love_err(g, ENOSYS); love_musttail return Next(1); }
static lvm(lvm_sigtake) { Sp[0] = love_err(g, ENOSYS); love_musttail return Next(1); }
#endif

// job control. a syscall body sits in a noinline helper so the lvm_ wrapper stays a pure
// tail-jump (`make vmret`). (wait pid): proc_status, or 256 + the signal for a stop
love_noinline static word host_waitpid(struct g *g, word arg) {
 intptr_t pid = charmp(arg) ? getcharm(arg) : 0;
 int st;
 pid_t r;
 do r = waitpid((pid_t) pid, &st, WUNTRACED | WNOHANG); while (r < 0 && errno == EINTR);
 if (!r) return ZeroPoint;                                   // still running
 if (r < 0) return love_err(g, errno);
 if (WIFSTOPPED(st)) return putcharm(256 + WSTOPSIG(st));
 return putcharm(proc_status(st)); }
// parks, polling each ms, so a peer task runs under a foreground job; the op re-runs whole
static lvm(lvm_waitpid) {
 word r = host_waitpid(g, Sp[0]);
 if (r == ZeroPoint) { g->next_wake_at = love_clock() + 1; love_musttail return Ap(lvm_yield_sw, g); }
 Sp[0] = r; love_musttail return Next(1); }

love_noinline static word host_posix_signal(struct g *g, word sigw, word dw) {
 if (!charmp(sigw) || !charmp(dw)) return badarg(g);
 struct sigaction sa;
 memset(&sa, 0, sizeof sa);
 sa.sa_handler = getcharm(dw) ? SIG_IGN : SIG_DFL;
 sigemptyset(&sa.sa_mask);
 return sigaction((int) getcharm(sigw), &sa, NULL) ? love_err(g, errno) : ZeroPoint; }

LvmWord2(posix_signal)

// a host inlines unless its frame holds a buffer or an address-taken local: those stay
// noinline, off the frame the musttail leaves
static love_inline word path1(struct g *g, word pw, int (*f)(char const*)) {
 char const *p = str_c(pw);
 return !p ? badarg(g) : f(p) ? love_err(g, errno) : ZeroPoint; }
static love_inline word path2(struct g *g, word ow, word nw, int (*f)(char const*, char const*)) {
 char const *o = str_c(ow), *n = str_c(nw);
 return !o || !n ? badarg(g) : f(o, n) ? love_err(g, errno) : ZeroPoint; }
static love_inline word host_chdir(struct g *g, word p) { return path1(g, p, chdir); }
LvmWord1(chdir)

love_noinline static struct g *host_cwd(struct g *g) {
 char buf[4096];
 if (!getcwd(buf, sizeof buf)) return g->sp[0] = love_err(g, errno), g;
 if (!ok(g = strof(g, buf))) return g;
 return g->sp[1] = g->sp[0], g->sp += 1, g; }           // over the dummy arg
static lvm(lvm_cwd) {
 LvmCall(g, host_cwd) }

// (selfpath _) -> the running binary's path, or (). no argv[0] fallback: baked code folds
// `cmdline` to the bake's line. a ladder: macos's proc_info, linux's link, netbsd's, then
// the sysctl doors
#if defined(__moonlibc__)
unsigned long __love_selfpath(char *b, unsigned long n);
#endif
love_noinline size_t host_selfpath(char *b, size_t n) {
#if defined(__moonlibc__)
 size_t k = __love_selfpath(b, n);
 if (k) return k;
#endif
 ssize_t r = readlink("/proc/self/exe", b, n - 1);
 if (r <= 0) r = readlink("/proc/curproc/exe", b, n - 1);
 if (r > 0) {
  b[r] = 0;
  // an unlinked inode's link reads "PATH (deleted)": the suffix is the kernel's
  size_t dl = sizeof " (deleted)" - 1;
  if ((size_t) r > dl && !memcmp(b + (size_t) r - dl, " (deleted)", dl))
   r -= (ssize_t) dl, b[r] = 0;
  return (size_t) r; }
#if defined(LvHaveSysctl)
 int mib[4] = { 1, 14, 12, -1 };                       // freebsd: CTL_KERN KERN_PROC KERN_PROC_PATHNAME(-1)
 size_t sz = n;
 if (!sysctl(mib, 4, b, &sz, NULL, 0) && sz) return strlen(b);
 int nmib[4] = { 1, 48, -1, 5 };                       // netbsd: KERN_PROC_ARGS(pid=-1) KERN_PROC_PATHNAME
 sz = n;
 if (!sysctl(nmib, 4, b, &sz, NULL, 0) && sz) return strlen(b);
#endif
 return 0; }

love_noinline static struct g *host_selfpath_ap(struct g *g) {
 char buf[4096];
 if (!host_selfpath(buf, sizeof buf)) return g->sp[0] = ZeroPoint, g;
 if (!ok(g = strof(g, buf))) return g;
 return g->sp[1] = g->sp[0], g->sp += 1, g; }
static lvm(lvm_selfpath) {
 LvmCall(g, host_selfpath_ap) }

// pipes and redirects. (spawnio argv in out err closes pg fg): a job in its own pgrp is what
// makes ^Z real, since POSIX drops a stop sent to an orphaned group. (setpg pid pg) is that
// dance for a forked stage that never execs; both sides call it
static int mk_pipe(struct g *g, void *fds) {
 (void) g;
 int *p = fds;
 if (pipe(p)) return -errno;
 p[0] = fd_up(p[0]), p[1] = fd_up(p[1]);
 fcntl(p[0], F_SETFD, FD_CLOEXEC), fcntl(p[1], F_SETFD, FD_CLOEXEC);   // not every libc has pipe2
 return 0; }
love_noinline static struct g *host_pipe(struct g *g) {
 int fds[2], r = mk_pipe(g, fds);
 if (!ok(g = love_fd_retry(g, &r, mk_pipe, fds))) return g;
 if (r < 0) return g->sp[0] = love_err(g, -r), g;
 if (!ok(g = have(g, Width(struct chain)))) return close(fds[0]), close(fds[1]), g;
 struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                putcharm(fds[0]), putcharm(fds[1]));
 return g->sp[0] = word(w), g; }
static lvm(lvm_pipe) {
 LvmCall(g, host_pipe) }

static int mk_openfd(struct g *g, void *env) {
 (void) env;
 int fd = openfd_mode(str_c(g->sp[0]), charmp(g->sp[1]) ? getcharm(g->sp[1]) : 0);
 return fd < 0 ? -errno : fd; }
love_noinline static struct g *host_openfd(struct g *g) {
 int fd = mk_openfd(g, NULL);
 if (!ok(g = love_fd_retry(g, &fd, mk_openfd, NULL))) return g;
 return push(g, 1, fd < 0 ? love_err(g, -fd) : putcharm(fd)); }
static lvm(lvm_openfd) {
 if (!str_c(Sp[0])) { Sp[1] = badarg(g); Sp += 1; love_musttail return Next(1); }
 LvmCallp(g, 2, host_openfd) }

static lvm(lvm_spawnio) {
 int in  = charmp(Sp[1]) ? (int) getcharm(Sp[1]) : -1,
     out = charmp(Sp[2]) ? (int) getcharm(Sp[2]) : -1,
     err = charmp(Sp[3]) ? (int) getcharm(Sp[3]) : -1;
 intptr_t pg = charmp(Sp[5]) ? getcharm(Sp[5]) : -1,
          fg = charmp(Sp[6]) ? getcharm(Sp[6]) : 0;
 LvmCallp(g, 7, host_spawnx, in, out, err, -1, 4, pg, fg) }   // closes at sp[4]

love_noinline static word host_posix_setpg(struct g *g, word pidw, word pgw) {
 if (!charmp(pidw) || !charmp(pgw)) return badarg(g);
 pid_t pid = (pid_t) getcharm(pidw), pg = (pid_t) getcharm(pgw);
 if (pid < 0 || pg < 0) return badarg(g);
 return setpgid(pid, pg) ? love_err(g, errno) : ZeroPoint; }
LvmWord2(posix_setpg)

love_noinline static word host_posix_ttyfg(struct g *g, word pgw) {
 pid_t pg = (charmp(pgw) && getcharm(pgw) > 0) ? (pid_t) getcharm(pgw) : getpgrp();
 return tcsetpgrp(0, pg) ? love_err(g, errno) : ZeroPoint; }

LvmWord1(posix_ttyfg)

// (ttypg fd): the terminal's owning group
love_noinline static word host_posix_ttypg(struct g *g, word x) {
 intptr_t fd = charmp(x) ? getcharm(x) : port_fd(x);
 if (fd < 0) return badarg(g);
 pid_t pg = tcgetpgrp((int) fd);
 return pg < 0 ? love_err(g, errno) : putcharm(pg); }

LvmWord1(posix_ttypg)

// (fdopen fd): the port's finalizer owns the fd from here; do not also close it
static lvm(lvm_fdopen) {
 intptr_t fd = charmp(Sp[0]) ? getcharm(Sp[0]) : -1;
 if (fd < 0) love_musttail return Answer(badarg(g));
 LvmCallp(g, 1, io_alloc, (int) fd) }

// (spawnmap argv fdmap closes pg fg): fdmap applies in order, each entry seeing the table as
// remapped so far -- POSIX's left-to-right law (`>f 2>&1` is ((1 . f) (2 . 1)))
static lvm(lvm_spawnmap) {
 intptr_t pg = charmp(Sp[3]) ? getcharm(Sp[3]) : -1,
          fg = charmp(Sp[4]) ? getcharm(Sp[4]) : 0;
 LvmCallp(g, 5, host_spawnx, -1, -1, -1, 1, 2, pg, fg) }   // fdmap sp[1], closes sp[2]

static lvm(lvm_getuid) { Sp[0] = putcharm(getuid()); love_musttail return Next(1); }
static lvm(lvm_getgid) { Sp[0] = putcharm(getgid()); love_musttail return Next(1); }

// (fork _): the shell's subshell; the child must never return to the reader loop
static love_inline word host_fork(struct g *g) {
 fflush(NULL);
 stdin_exact(g);
 image_warm(), code_warm(g);   // what earlier children woke, so this one starts with it
 pid_t pid = fork();
 return pid < 0 ? love_err(g, errno) : putcharm(pid); }
static lvm(lvm_fork) { Sp[0] = host_fork(g); love_musttail return Next(1); }

// (dup fd) lands at 10 and up, clear of the shell user's 0-9
static love_inline word host_dup2(struct g *g, word sw, word dw) {
 return !charmp(sw) || !charmp(dw) ? badarg(g) :
        (sw == dw ? fcntl((int) getcharm(dw), F_SETFD, 0)       // the laid fd rides an exec
                  : dup2((int) getcharm(sw), (int) getcharm(dw))) < 0 ? love_err(g, errno) :
        ZeroPoint; }

static lvm(lvm_dup2) { Sp[1] = host_dup2(g, Sp[0], Sp[1]); Sp += 1; love_musttail return Next(1); }

static int mk_dup(struct g *g, void *env) {
 (void) env;
 int fd = fcntl((int) getcharm(g->sp[0]), F_DUPFD_CLOEXEC, 10);
 return fd < 0 ? -errno : fd; }
love_noinline static struct g *host_dup(struct g *g) {
 if (!charmp(g->sp[0])) return g->sp[0] = badarg(g), g;
 int fd = mk_dup(g, NULL);
 if (!ok(g = love_fd_retry(g, &fd, mk_dup, NULL))) return g;
 return g->sp[0] = fd < 0 ? love_err(g, -fd) : putcharm(fd), g; }

static lvm(lvm_dup) { LvmCall(g, host_dup) }

// pid1 bringup. (newns _) unshares a user+mount namespace as root-in-ns, so mount works
// unprivileged
static lvm(lvm_mkdir) {
 char const *p = str_c(Sp[0]);
 if (!p) { Sp[1] = badarg(g); Sp += 1; love_musttail return Next(1); }
 intptr_t mode = charmp(Sp[1]) ? getcharm(Sp[1]) : 0755;
 Sp[1] = mkdir(p, (mode_t) mode) ? love_err(g, errno) : ZeroPoint;
 love_musttail return Nextp(1, 1); }

#if defined(LvHaveMount)
static love_inline word host_mount(struct g *g, word a, word b, word c) {
 char const *src = str_c(a), *tgt = str_c(b), *typ = str_c(c);
 if (!src || !tgt || !typ) return badarg(g);
 return mount(src, tgt, typ, 0, NULL) ? love_err(g, errno) : ZeroPoint; }
static lvm(lvm_mount) { Sp[2] = host_mount(g, Sp[0], Sp[1], Sp[2]); Sp += 2; love_musttail return Next(1); }
// (mountf src tgt type flags): mount with linux's MS_ word, beside it since a nif's arity is
// fixed (init/boot.l calls mount). data stays NULL
static love_inline word host_mountf(struct g *g, word a, word b, word c, word f) {
 char const *src = str_c(a), *tgt = str_c(b), *typ = str_c(c);
 if (!src || !tgt || !typ) return badarg(g);
 return mount(src, tgt, typ, (unsigned long) getcharm(f), NULL) ? love_err(g, errno) : ZeroPoint; }
static lvm(lvm_mountf) {
  Sp[3] = host_mountf(g, Sp[0], Sp[1], Sp[2], Sp[3]); Sp += 3; love_musttail return Next(1); }
static lvm(lvm_umount) {
  char const *t = str_c(Sp[0]);
  Sp[0] = !t ? badarg(g) : (umount(t) ? love_err(g, errno) : ZeroPoint);
  love_musttail return Next(1); }
// (reboot how): 0 restarts, 1 powers off, 2 halts; the caller syncs first
static lvm(lvm_reboot) {
  intptr_t h = charmp(Sp[0]) ? getcharm(Sp[0]) : -1;
  int cmd = h == 0 ? (int) RB_AUTOBOOT : h == 1 ? (int) RB_POWER_OFF : h == 2 ? (int) RB_HALT_SYSTEM : 0;
  Sp[0] = !cmd ? badarg(g) : (reboot(cmd), love_err(g, errno));
  love_musttail return Next(1); }
#else
static lvm(lvm_reboot) { Sp[0] = love_err(g, ENOSYS); love_musttail return Next(1); }
static lvm(lvm_mount) { Sp[2] = love_err(g, ENOSYS); Sp += 2; love_musttail return Next(1); }
static lvm(lvm_mountf) { Sp[3] = love_err(g, ENOSYS); Sp += 3; love_musttail return Next(1); }
static lvm(lvm_umount) { Sp[0] = love_err(g, ENOSYS); love_musttail return Next(1); }
#endif

static lvm(lvm_chroot) {
  char const *p = str_c(Sp[0]);
  Sp[0] = !p ? badarg(g) : (chroot(p) ? love_err(g, errno) : ZeroPoint);
  love_musttail return Next(1); }

// sync(2) cannot fail
static lvm(lvm_sync) { sync(); Sp[0] = ZeroPoint; love_musttail return Next(1); }

// (mknod path mode dev): mode carries the type bits; mkfifo is S_IFIFO with dev 0
static lvm(lvm_mknod) {
  char const *p = str_c(Sp[0]);
  intptr_t mode = getcharm(Sp[1]), dev = getcharm(Sp[2]);
  Sp[2] = !p ? badarg(g)
             : (mknod(p, (mode_t) mode, (dev_t) dev) ? love_err(g, errno) : ZeroPoint);
  Sp += 2; love_musttail return Next(1); }

#if defined(LvHaveNamespaces)
static int ns_write(char const *path, char const *s) {
 int fd = open(path, O_WRONLY);
 if (fd < 0) return -1;
 ssize_t n = write(fd, s, strlen(s));
 return close(fd), (n < 0 ? -1 : 0); }
static lvm(lvm_newns) {
 long uid = (long) getuid(), gid = (long) getgid();
 if (unshare(CLONE_NEWUSER | CLONE_NEWNS)) {
   Sp[0] = love_err(g, errno);
   love_musttail return Next(1); }
 char b[64];
 ns_write("/proc/self/setgroups", "deny");                       // required before gid_map
 snprintf(b, sizeof b, "0 %ld 1\n", uid); ns_write("/proc/self/uid_map", b);
 snprintf(b, sizeof b, "0 %ld 1\n", gid); ns_write("/proc/self/gid_map", b);
 Sp[0] = ZeroPoint;
 love_musttail return Next(1); }
#else
static lvm(lvm_newns) { Sp[0] = love_err(g, ENOSYS); love_musttail return Next(1); }
#endif

// the fs surface. (stat path|fd) -> (size mtime mode ns uid gid nlink blocks ino atime ctime
// dev rdev blksize): mtime in ms, ns/atime/ctime in ns, blocks in 512s, mode raw st_mode.
// the tail is append-only; inle's stat (src/inle/kmain.c) answers only the first four
static int lovefs_stat(char const *p, struct stat *st) {   // 1 the tree's (mode 0 absent), 0 the OS's
 char c[256];
 uintptr_t cn;
 struct vfs_st vs;
 if (lovefs_at(p, c, &cn) == -1) return 0;
 memset(st, 0, sizeof *st);
 if (!lovefs_stat_at(c, cn, &vs)) return 1;
 st->st_mode = vs.kind == 2 ? S_IFDIR | 0555 : S_IFREG | 0444;
 st->st_size = vs.kind == 2 ? 0 : (off_t) vs.size;
 st->st_nlink = 1, st->st_uid = getuid(), st->st_gid = getgid();
 st->st_ino = (ino_t) (vs.i + 1);
 st->st_blocks = (blkcnt_t) ((st->st_size + 511) / 512), st->st_blksize = 4096;
 st->st_mtim.tv_sec = st->st_atim.tv_sec = st->st_ctim.tv_sec = (time_t) (vs.ms / 1000);
 st->st_mtim.tv_nsec = st->st_atim.tv_nsec = st->st_ctim.tv_nsec = (long) (vs.ms % 1000) * 1000000;
 return 1; }

love_noinline static struct g *host_stat_tuple(struct g *g, int follow) {
 word x = g->sp[0];
 struct stat st;
 if (charmp(x)) {
  if (getcharm(x) < 0) return g->sp[0] = badarg(g), g;
  if (fstat((int) getcharm(x), &st)) return g->sp[0] = love_err(g, errno), g; }
 else {
  char const *p = str_c(x);
  if (!p) return g->sp[0] = badarg(g), g;
  if (lovefs_stat(p, &st)) {
   if (st.st_mode == 0) return g->sp[0] = love_err(g, ENOENT), g; }
  else if (follow ? stat(p, &st) : lstat(p, &st)) return g->sp[0] = love_err(g, errno), g; }
 intptr_t ms = (intptr_t) st.st_mtim.tv_sec * 1000 + st.st_mtim.tv_nsec / 1000000,
          ns = (intptr_t) st.st_mtim.tv_sec * 1000000000 + st.st_mtim.tv_nsec,
          as = (intptr_t) st.st_atim.tv_sec * 1000000000 + st.st_atim.tv_nsec,
          cs = (intptr_t) st.st_ctim.tv_sec * 1000000000 + st.st_ctim.tv_nsec;
 if (!ok(g = have(g, 14 * Width(struct chain)))) return g;
 size_t const C = Width(struct chain);
 struct chain *c = ini_chain(bump(g, C), putcharm(st.st_blksize), ZeroPoint);
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

love_inline static struct g *host_posix_stat(struct g *g) {
 return host_stat_tuple(g, 1); }
love_inline static struct g *host_posix_lstat(struct g *g) {
 return host_stat_tuple(g, 0); }

static lvm(lvm_posix_lstat) {
 LvmCall(g, host_posix_lstat) }

static lvm(lvm_posix_stat) {
 LvmCall(g, host_posix_stat) }

// (statfs path) -> (bsize blocks bfree bavail files ffree frsize fsid0 fsid1 namelen type),
// append-only; linux's struct alone, so a BSD hears 'enosys
#if defined(LvHaveStatfs)
love_noinline static struct g *host_posix_statfs(struct g *g) {
 char const *p = str_c(g->sp[0]);
 if (!p) return g->sp[0] = badarg(g), g;
 struct statfs fs;
 if (statfs(p, &fs)) return g->sp[0] = love_err(g, errno), g;
 if (!ok(g = have(g, 11 * Width(struct chain)))) return g;
 size_t const C = Width(struct chain);
 uint32_t id[2];                                  // glibc's fsid_t and moonlibc's int[2] alike
 memcpy(id, &fs.f_fsid, sizeof id);
 struct chain *c = ini_chain(bump(g, C), putcharm((intptr_t) (unsigned long) fs.f_type), ZeroPoint);
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_namelen), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) id[1]), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) id[0]), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_frsize), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_ffree), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_files), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_bavail), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_bfree), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_blocks), word(c));
 c = ini_chain(bump(g, C), putcharm((intptr_t) fs.f_bsize), word(c));
 return g->sp[0] = word(c), g; }
#else
love_noinline static struct g *host_posix_statfs(struct g *g) {
 return g->sp[0] = love_err(g, ENOSYS), g; }
#endif
static lvm(lvm_posix_statfs) {
 LvmCall(g, host_posix_statfs) }

// (birth path follow): creation time in ns | (); its own call, off the stat tuple du and ls walk
#if defined(__moonlibc__)
love_noinline static word host_posix_birth(struct g *g, word pw, word fw) {
 char const *p = str_c(pw);
 if (!p) return badarg(g);
 struct timespec b;
 int r = __love_birth(p, charmp(fw) && getcharm(fw), &b);
 return r < 0 ? love_err(g, errno)
      : r     ? ZeroPoint
      : putcharm((intptr_t) b.tv_sec * 1000000000 + b.tv_nsec); }
LvmWord2(posix_birth)
#else
static lvm(lvm_posix_birth) { Sp[1] = love_err(g, ENOSYS); love_musttail return Nextp(1, 1); }
#endif

// (rusage who) -> (user sys) in us; who 0 self, -1 the reaped children
love_noinline static struct g *host_posix_rusage(struct g *g) {
 word x = g->sp[0];
 if (!charmp(x)) return g->sp[0] = badarg(g), g;
 struct rusage ru;
 if (getrusage((int) getcharm(x), &ru)) return g->sp[0] = love_err(g, errno), g;
 intptr_t u = (intptr_t) ru.ru_utime.tv_sec * 1000000 + ru.ru_utime.tv_usec,
          s = (intptr_t) ru.ru_stime.tv_sec * 1000000 + ru.ru_stime.tv_usec;
 if (!ok(g = have(g, 2 * Width(struct chain)))) return g;
 size_t const C = Width(struct chain);
 struct chain *c = ini_chain(bump(g, C), putcharm(s), ZeroPoint);
 c = ini_chain(bump(g, C), putcharm(u), word(c));
 return g->sp[0] = word(c), g; }
static lvm(lvm_posix_rusage) {
 LvmCall(g, host_posix_rusage) }

love_noinline static struct g *lovefs_readdir(struct g *g, char const *c, uintptr_t cn) {
 g->sp[0] = ZeroPoint;
 char const *q;
 uintptr_t cl;
 bool dir;
 for (int cur = 0; lovefs_child(c, cn, &cur, &q, &cl, &dir) >= 0; ) {
  if (!ok(g = str0(g, cl))) return g;
  memcpy(txt(g->sp[0]), q, cl);
  if (!ok(g = have(g, Width(struct chain)))) return g;
  struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                 g->sp[0], g->sp[1]);
  g->sp[1] = word(w);
  g->sp += 1; }
 return g; }

static love_inline struct g *host_posix_readdir(struct g *g) {
 char const *p = str_c(g->sp[0]);
 if (!p) return g->sp[0] = badarg(g), g;
 { char rel[256];
   uintptr_t rn;
   intptr_t i = lovefs_at(p, rel, &rn);
   if (i == -3) return lovefs_readdir(g, rel, rn);
   if (i != -1) return g->sp[0] = love_err(g, i == -2 ? ENOENT : ENOTDIR), g; }
 DIR *d = opendir(p);
 if (!d) return g->sp[0] = love_err(g, errno), g;
 g->sp[0] = ZeroPoint;                                        // the accumulator
 for (struct dirent *e; (e = readdir(d));) {
  if (e->d_name[0] == '.' && (!e->d_name[1] || (e->d_name[1] == '.' && !e->d_name[2])))
   continue;
  if (!ok(g = strof(g, e->d_name))) return closedir(d), g;
  if (!ok(g = have(g, Width(struct chain)))) return closedir(d), g;
  struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                 g->sp[0], g->sp[1]);         // slots re-read past the GC
  g->sp[1] = word(w);
  g->sp += 1; }
 closedir(d);
 return g; }

static lvm(lvm_posix_readdir) {
 LvmCall(g, host_posix_readdir) }

static love_inline word host_posix_unlink(struct g *g, word p) { return path1(g, p, unlink); }

LvmWord1(posix_unlink)

// (fnmatch pat s): no flags; an inner NUL never matches
static love_inline word host_fnmatch(struct g *g, word p, word t) {
 (void) g; char const *a = str_c(p), *b = str_c(t);
 return putcharm(a && b && !fnmatch(a, b, 0)); }
LvmWord2(fnmatch)

// (regcomp p fl) -> (b n) | -e. moonlibc's program holds no pointer, so b copies it; another
// libc's b is fl and p, compiled again at each regexec
static love_inline struct g *host_regcomp(struct g *g) {
 char const *p = str_c(g->sp[0]);
 word f = g->sp[1];
 if (!p || !charmp(f) || getcharm(f) & ~255) return g->sp[0] = badarg(g), g;
 regex_t re;
 int rc = regcomp(&re, p, (int) getcharm(f));
 if (rc) return g->sp[0] = putcharm(-rc), g;
#ifdef REG_UTF8
 uintptr_t z = re.re_size;
#else
 uintptr_t z = strlen(p) + 1;
#endif
 if (ok(g = have(g, str_width(z) + 2 * Width(struct chain)))) {
  struct str *b = ini_str((struct str*) bump(g, str_width(z)), z);
#ifdef REG_UTF8
  memcpy(b->bytes, re.re_prog, z);
#else
  b->bytes[0] = (char) getcharm(f), memcpy(b->bytes + 1, txt(g->sp[0]), z - 1);
#endif
  word l = word(ini_chain((struct chain*) bump(g, Width(struct chain)), putcharm((intptr_t) re.re_nsub), ZeroPoint));
  g->sp[0] = word(ini_chain((struct chain*) bump(g, Width(struct chain)), word(b), l)); }
 regfree(&re);
 return g; }
static lvm(lvm_regcomp) {
 LvmCallp(g, 1, host_regcomp) }

// (regexec b s i ef) -> (so eo ..) to the last of nine groups that took part, -1 for one that
// did not | () | -e; what lies before i is still the text
static love_inline struct g *host_regexec(struct g *g) {
 word b = g->sp[0], s = g->sp[1], i = g->sp[2], e = g->sp[3];
 if (!strp(b) || !len(b) || !strp(s) || !charmp(i) || !charmp(e) || getcharm(i) < 0 || getcharm(i) > (intptr_t) len(s))
  return g->sp[0] = badarg(g), g;
 regmatch_t m[10] = {{(regoff_t) getcharm(i), (regoff_t) len(s)}};
 int ef = (int) getcharm(e) | REG_STARTEND, rc, k = 10;
#ifdef REG_UTF8
 regex_t re = {0, txt(b), len(b)};
 rc = regexec(&re, txt(s), 10, m, ef);
#else
 regex_t re;
 rc = regcomp(&re, txt(b) + 1, (unsigned char) txt(b)[0]);
 if (!rc) rc = regexec(&re, txt(s), 10, m, ef), regfree(&re);
#endif
 if (rc) return g->sp[0] = rc == REG_NOMATCH ? ZeroPoint : putcharm(-rc), g;
 while (k > 1 && m[k - 1].rm_so < 0) k--;
 if (!ok(g = have(g, 2 * (uintptr_t) k * Width(struct chain)))) return g;
 word l = ZeroPoint;
 for (int j = 2 * k; j--;)
  l = word(ini_chain((struct chain*) bump(g, Width(struct chain)),
                     putcharm(j & 1 ? m[j / 2].rm_eo : m[j / 2].rm_so), l));
 return g->sp[0] = l, g; }
static lvm(lvm_regexec) {
 LvmCallp(g, 3, host_regexec) }

// (setenv name val): a non-string val unsets
static love_inline word host_posix_setenv(struct g *g, word nw, word vw) {
 char const *n = str_c(nw), *v = str_c(vw);
 if (!n || (!v && strp(vw))) return badarg(g);
 if (!v) return unsetenv(n) ? love_err(g, errno) : ZeroPoint;
 return setenv(n, v, 1) ? love_err(g, errno) : ZeroPoint; }
LvmWord2(posix_setenv)

extern char **environ;
static love_inline struct g *host_posix_environ(struct g *g) {
 g->sp[0] = ZeroPoint;                                        // the accumulator
 for (char **e = environ; e && *e; e++) {
  if (!ok(g = strof(g, *e))) return g;
  if (!ok(g = have(g, Width(struct chain)))) return g;
  struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                 g->sp[0], g->sp[1]);
  *++g->sp = word(w); }
 return g; }

static lvm(lvm_posix_environ) {
 LvmCall(g, host_posix_environ) }

// (uname _) -> (sysname nodename release version machine)
love_noinline static struct g *host_posix_uname(struct g *g) {
 struct utsname u;
 if (uname(&u)) return g->sp[0] = love_err(g, errno), g;
 char const *f[] = { u.machine, u.version, u.release, u.nodename, u.sysname };   // last first
 g->sp[0] = ZeroPoint;
 for (int i = 0; i < 5; i++) {
  if (!ok(g = strof(g, f[i]))) return g;
  if (!ok(g = have(g, Width(struct chain)))) return g;
  struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                 g->sp[0], g->sp[1]);
  *++g->sp = word(w); }
 return g; }
static lvm(lvm_posix_uname) {
 LvmCall(g, host_posix_uname) }

// (sysconf _) -> (pagesize cpus-conf cpus-online phys-pages avphys-pages), () where none
love_noinline static struct g *host_posix_sysconf(struct g *g) {
 int const k[] = { _SC_AVPHYS_PAGES, _SC_PHYS_PAGES, _SC_NPROCESSORS_ONLN,
                   _SC_NPROCESSORS_CONF, _SC_PAGESIZE };                   // last first
 g->sp[0] = ZeroPoint;
 for (int i = 0; i < 5; i++) {
  long v = sysconf(k[i]);
  if (!ok(g = have(g, Width(struct chain)))) return g;
  struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                 v < 0 ? ZeroPoint : putcharm(v), g->sp[0]);
  g->sp[0] = word(w); }
 return g; }
static lvm(lvm_posix_sysconf) {
 LvmCall(g, host_posix_sysconf) }

static love_inline word host_posix_lseek(struct g *g, word fdw, word offw, word whw) {
 if (!charmp(fdw) || !charmp(offw) || !charmp(whw)) return badarg(g);
 intptr_t w = getcharm(whw);
 // raw fds only: a port's buffer would desync. a stranger whence is -1, so 'einval, not SET
 int wh = w == 0 ? SEEK_SET : w == 1 ? SEEK_CUR : w == 2 ? SEEK_END : -1;
 off_t r = lseek((int) getcharm(fdw), (off_t) getcharm(offw), wh);
 return r < 0 ? love_err(g, errno) : putcharm((intptr_t) r); }

LvmWord3(posix_lseek)

// a NULL row stays on the book: a seat shadows it with a global (src/inle/kmain.c, main.c's
// seat-doors), reached through the live book, which a module splice would hide for good
LvDef("spawn", spawn, 1, NULL);
LvDef("glean", reapany, 1, NULL);
LvDef("sigfd", sigfd, 1, "posix");
LvDef("sigtake", sigtake, 1, "posix");
LvDef("sigclear", sigclear, 1, "posix");
LvDef("childign", childign, 1, "posix");
LvDef("sigign?", sigignp, 1, "posix");
LvDef("wait", waitpid, 1, NULL);
LvDef("chdir", chdir, 1, "posix");
LvDef("fnmatch", fnmatch, 2, "posix");
LvDef("regcomp", regcomp, 2, "posix");
LvDef("regexec", regexec, 4, "posix");
LvDef("cwd", cwd, 1, "posix");
LvDef("selfpath", selfpath, 1, "posix");
LvDef("uname", posix_uname, 1, "posix");
LvDef("sysconf", posix_sysconf, 1, "posix");
LvDef("pipe", pipe, 1, NULL);
LvDef("openfd", openfd, 2, "posix");
LvDef("spawnio", spawnio, 7, NULL);
LvDef("fdopen", fdopen, 1, NULL);
LvDef("spawnmap", spawnmap, 5, NULL);
LvDef("getuid", getuid, 1, NULL);
LvDef("getgid", getgid, 1, "posix");
LvDef("fork", fork, 1, NULL);
LvDef("dup2", dup2, 2, NULL);
LvDef("dup", dup, 1, NULL);
LvDef("mkdir", mkdir, 2, "posix");
LvDef("mount", mount, 3, "posix");
LvDef("mountf", mountf, 4, "posix");
LvDef("umount", umount, 1, "posix");
LvDef("chroot", chroot, 1, "posix");
LvDef("sync", sync, 1, "posix");
LvDef("reboot", reboot, 1, "posix");
LvDef("mknod", mknod, 3, "posix");
LvDef("newns", newns, 1, "posix");
LvDef("stat", posix_stat, 1, "posix");
LvDef("lstat", posix_lstat, 1, "posix");
LvDef("statfs", posix_statfs, 1, "posix");
LvDef("rusage", posix_rusage, 1, "posix");
LvDef("birth", posix_birth, 2, "posix");
LvDef("readdir", posix_readdir, 1, "posix");
LvDef("unlink", posix_unlink, 1, "posix");
LvDef("lseek", posix_lseek, 3, "posix");
LvDef("signal", posix_signal, 2, NULL);
LvDef("ttyfg", posix_ttyfg, 1, NULL);
LvDef("ttypg", posix_ttypg, 1, NULL);
LvDef("setpg", posix_setpg, 2, NULL);
LvDef("setenv", posix_setenv, 2, NULL);
LvDef("environ", posix_environ, 1, NULL);
// the fs tools' effect ops. (utime path ms): a non-charm ms is now. hardlink is link(2),
// `link` being the chain ctor
static love_inline word host_posix_rename(struct g *g, word o, word n) { return path2(g, o, n, rename); }
LvmWord2(posix_rename)

static love_inline word host_posix_symlink(struct g *g, word o, word n) { return path2(g, o, n, symlink); }
LvmWord2(posix_symlink)

love_noinline static struct g *host_posix_readlink(struct g *g) {
 char const *p = str_c(g->sp[0]);
 char b[4096];
 if (!p) return g->sp[0] = badarg(g), g;
 uintptr_t rn;
 intptr_t i = lovefs_at(p, b, &rn);                        // the tree holds no links
 if (i != -1) return g->sp[0] = love_err(g, i == -2 ? ENOENT : EINVAL), g;
 ssize_t n = readlink(p, b, sizeof b - 1);
 if (n < 0) return g->sp[0] = love_err(g, errno), g;
 b[n] = 0;
 if (!ok(g = strof(g, b))) return g;
 return g->sp[1] = g->sp[0], g->sp += 1, g; }
static lvm(lvm_posix_readlink) {
 LvmCall(g, host_posix_readlink) }

static love_inline word host_posix_chmod(struct g *g, word pw, word mw) {
 char const *p = str_c(pw);
 if (!p || !charmp(mw)) return badarg(g);
 return chmod(p, (mode_t) getcharm(mw)) ? love_err(g, errno) : ZeroPoint; }
LvmWord2(posix_chmod)

static love_inline word host_posix_chown(struct g *g, word pw, word uw, word gw) {
 char const *p = str_c(pw);
 if (!p || !charmp(uw) || !charmp(gw)) return badarg(g);
 return chown(p, (uid_t) getcharm(uw), (gid_t) getcharm(gw)) ? love_err(g, errno) : ZeroPoint; }
LvmWord3(posix_chown)
static love_inline word host_posix_lchown(struct g *g, word pw, word uw, word gw) {
 char const *p = str_c(pw);
 if (!p || !charmp(uw) || !charmp(gw)) return badarg(g);
 return lchown(p, (uid_t) getcharm(uw), (gid_t) getcharm(gw)) ? love_err(g, errno) : ZeroPoint; }
LvmWord3(posix_lchown)

love_noinline static word host_posix_utime(struct g *g, word pw, word msw) {
 char const *p = str_c(pw);
 if (!p) return badarg(g);
 struct timespec ts[2];
 if charmp(msw) {
  intptr_t ms = getcharm(msw);
  ts[0].tv_sec = ts[1].tv_sec = (time_t) (ms / 1000);
  ts[0].tv_nsec = ts[1].tv_nsec = (long) (ms % 1000) * 1000000;
 } else
  ts[0].tv_sec = ts[1].tv_sec = 0, ts[0].tv_nsec = ts[1].tv_nsec = UTIME_NOW;
 return utimensat(AT_FDCWD, p, ts, 0) ? love_err(g, errno) : ZeroPoint; }
LvmWord2(posix_utime)

static love_inline word host_posix_rmdir(struct g *g, word p) { return path1(g, p, rmdir); }
LvmWord1(posix_rmdir)

static love_inline word host_posix_hardlink(struct g *g, word o, word n) { return path2(g, o, n, link); }
LvmWord2(posix_hardlink)

// (copyfile src dst) -> bytes copied: off the heap, bytes only. copy_file_range would still
// need this loop under it
love_noinline static word host_posix_copyfile(struct g *g, word sw, word dw) {
 char const *s = str_c(sw), *d = str_c(dw);
 if (!s || !d) return badarg(g);
 int in = open(s, O_RDONLY | O_CLOEXEC);
 if (in < 0) return love_err(g, errno);
 int out = open(d, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0666);
 if (out < 0) { int e = errno; close(in); return love_err(g, e); }
 char buf[1 << 15];                               // in the helper, never the lvm_ (love.h)
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
 return err ? love_err(g, (int) err) : putcharm(done); }
LvmWord2(posix_copyfile)

// (rlimit res which): which 0 soft, 1 hard; -1 unlimited. (setrlimit res soft hard): () keeps one
static love_inline int host_rlres(intptr_t i) {
 switch (i) { case 0: return RLIMIT_CPU;   case 1: return RLIMIT_FSIZE; case 2: return RLIMIT_DATA;
              case 3: return RLIMIT_STACK; case 4: return RLIMIT_CORE;  case 5: return RLIMIT_NPROC;
              case 6: return RLIMIT_NOFILE; case 7: return RLIMIT_AS;   default: return -1; } }
love_noinline static word host_posix_rlimit(struct g *g, word rw, word ww) {
 if (!charmp(rw) || !charmp(ww)) return badarg(g);
 int r = host_rlres(getcharm(rw));
 intptr_t w = getcharm(ww);
 if (r < 0 || (w != 0 && w != 1)) return badarg(g);
 struct rlimit l;
 if (getrlimit(r, &l)) return love_err(g, errno);
 rlim_t v = w ? l.rlim_max : l.rlim_cur;
 return putcharm(v == RLIM_INFINITY ? -1 : (intptr_t) v); }
LvmWord2(posix_rlimit)
love_noinline static word host_posix_setrlimit(struct g *g, word rw, word sw, word hw) {
 if (!charmp(rw)) return badarg(g);
 int r = host_rlres(getcharm(rw));
 if (r < 0) return badarg(g);
 struct rlimit l;
 if (getrlimit(r, &l)) return love_err(g, errno);
 if (charmp(sw)) l.rlim_cur = getcharm(sw) < 0 ? RLIM_INFINITY : (rlim_t) getcharm(sw);
 if (charmp(hw)) l.rlim_max = getcharm(hw) < 0 ? RLIM_INFINITY : (rlim_t) getcharm(hw);
 return setrlimit(r, &l) ? love_err(g, errno) : ZeroPoint; }
static lvm(lvm_posix_setrlimit) {
 Sp[2] = host_posix_setrlimit(g, Sp[0], Sp[1], Sp[2]); Sp += 2; love_musttail return Next(1); }

// (prio which who): which 0 process, 1 group, 2 user; who 0 the caller
static love_inline word host_posix_prio(struct g *g, word ww, word hw) {
 if (!charmp(ww) || !charmp(hw)) return badarg(g);
 errno = 0;
 int n = getpriority((int) getcharm(ww), (id_t) getcharm(hw));
 return n == -1 && errno ? love_err(g, errno) : putcharm(n); }
LvmWord2(posix_prio)
static love_inline word host_posix_setprio(struct g *g, word ww, word hw, word nw) {
 if (!charmp(ww) || !charmp(hw) || !charmp(nw)) return badarg(g);
 return setpriority((int) getcharm(ww), (id_t) getcharm(hw), (int) getcharm(nw))
        ? love_err(g, errno) : ZeroPoint; }
LvmWord3(posix_setprio)

// (truncate path|fd n make): made first when make is truthy
love_noinline static word host_posix_truncate(struct g *g, word pw, word nw, word mw) {
 if (!charmp(nw) || getcharm(nw) < 0) return badarg(g);
 if (charmp(pw)) return ftruncate((int) getcharm(pw), (off_t) getcharm(nw)) ? love_err(g, errno) : ZeroPoint;
 char const *p = str_c(pw);
 if (!p) return badarg(g);
 int fd = open(p, O_WRONLY | O_NONBLOCK | O_CLOEXEC | (charmp(mw) && getcharm(mw) > 0 ? O_CREAT : 0), 0666);
 if (fd < 0) return love_err(g, errno);
 int e = ftruncate(fd, (off_t) getcharm(nw)) ? errno : 0;
 close(fd);
 return e ? love_err(g, e) : ZeroPoint; }
LvmWord3(posix_truncate)

// (setsid ctty): a truthy ctty takes fd 0's terminal as the controlling one
static love_noinline word host_posix_setsid(struct g *g, word cw) {
 pid_t s = setsid();
 if (s < 0) return love_err(g, errno);
 if (charmp(cw) && getcharm(cw) > 0 && ioctl(0, TIOCSCTTY, 1)) return love_err(g, errno);
 return putcharm(s); }
LvmWord1(posix_setsid)

// (fsync path data): fdatasync when data is truthy
love_noinline static word host_posix_fsync(struct g *g, word pw, word dw) {
 char const *p = str_c(pw);
 if (!p) return badarg(g);
 int fd = open(p, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
 if (fd < 0) return love_err(g, errno);
 int e = (charmp(dw) && getcharm(dw) > 0 ? fdatasync(fd) : fsync(fd)) ? errno : 0;
 close(fd);
 return e ? love_err(g, e) : ZeroPoint; }
LvmWord2(posix_fsync)

static lvm(lvm_posix_umask) {
 Sp[0] = charmp(Sp[0]) ? putcharm((intptr_t) umask((mode_t) getcharm(Sp[0])))
                     : badarg(g);
 love_musttail return Next(1); }

LvDef("rename", posix_rename, 2, "posix");
LvDef("symlink", posix_symlink, 2, "posix");
LvDef("readlink", posix_readlink, 1, "posix");
LvDef("chmod", posix_chmod, 2, "posix");
LvDef("chown", posix_chown, 3, "posix");
LvDef("lchown", posix_lchown, 3, "posix");
LvDef("utime", posix_utime, 2, "posix");
LvDef("umask", posix_umask, 1, "posix");
LvDef("rlimit", posix_rlimit, 2, "posix");
LvDef("setrlimit", posix_setrlimit, 3, "posix");
LvDef("prio", posix_prio, 2, "posix");
LvDef("setprio", posix_setprio, 3, "posix");
LvDef("truncate", posix_truncate, 3, "posix");
LvDef("setsid", posix_setsid, 1, "posix");
LvDef("fsync", posix_fsync, 2, "posix");
LvDef("rmdir", posix_rmdir, 1, "posix");
LvDef("hardlink", posix_hardlink, 2, NULL);
LvDef("copyfile", posix_copyfile, 2, "posix");
// the pty wrapper. (tether argv) -> (pid . master-port): hark (main.c) with a pty pair for
// the stdout pipe; the child's 0/1/2 are the slave. tetherenv sets env's K=V in the child
love_noinline static struct g *host_tether(struct g *g, int envat) {
  // no allocation between the marshal and the fork, or the gap moves
 char **cav, **cev;
 g = argv_env_marshal(g, &cav, envat, &cev);
 if (!cav) return ok(g) ? push(g, 1, badarg(g)) : g;
  // ptsname's buffer is static: snapshot it
 int mfd = posix_openpt(O_RDWR | O_NOCTTY);
 if (mfd < 0) return push(g, 1, love_err(g, errno));
 fcntl(mfd, F_SETFD, FD_CLOEXEC);                  // a later child may not read this one
 if (grantpt(mfd) || unlockpt(mfd)) { int e = errno; close(mfd); return push(g, 1, love_err(g, e)); }
 char sname[128];
 { char const *p = ptsname(mfd);
  if (!p || strlen(p) >= sizeof sname) { close(mfd); return push(g, 1, love_err(g, p ? ENAMETOOLONG : errno)); }
  memcpy(sname, p, strlen(p) + 1); }

  // the child's errno comes back here; a clean exec closes it, so EOF
 int ep[2];
 if (pipe(ep)) { int e = errno; close(mfd); return push(g, 1, love_err(g, e)); }
 fcntl(ep[0], F_SETFD, FD_CLOEXEC), fcntl(ep[1], F_SETFD, FD_CLOEXEC);

 pid_t pid = fork();
 if (pid < 0) { int e = errno; close(mfd); close(ep[0]); close(ep[1]); return push(g, 1, love_err(g, e)); }
 if (!pid) {
  close(mfd); close(ep[0]);
  sig_dfl_job(g->child_ign);
  int e;
  if (setsid() < 0) { e = errno; goto childfail; }
  int sfd = open(sname, O_RDWR);                  // opening a tty in a fresh session claims it as ctty
  if (sfd < 0) { e = errno; goto childfail; }
  ioctl(sfd, TIOCSCTTY, 0);                       // harmless if already ctty
  dup2(sfd, 0); dup2(sfd, 1); dup2(sfd, 2);
  if (sfd > 2) close(sfd);
  for (char **v = cev; v && *v; v++) {           // the gap is this child's own copy
   char *eq = strchr(*v, '=');
   *eq = 0;
   if (setenv(*v, eq + 1, 1)) { e = errno; goto childfail; } }
  execvp(argv_file(cav), cav);
  e = errno;
  childfail:
  { ssize_t w = write(ep[1], &e, sizeof e); (void) w; }
  _exit(127); }

 close(ep[1]);
 int childerr = 0; ssize_t r;
 do r = read(ep[0], &childerr, sizeof childerr); while (r < 0 && errno == EINTR);
 close(ep[0]);
 if (childerr) {
  close(mfd);
  int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
  return push(g, 1, love_err(g, childerr)); }

 struct g *io = io_alloc(g, mfd);
 if (!ok(io)) {                                 // oom: tear the child down
  kill(pid, SIGKILL);
  int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
  close(mfd);
  return io; }
 g = io;
 if (!ok(g = have(g, Width(struct chain)))) return g;
 struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                 putcharm(pid), g->sp[0]);
 g->sp[0] = word(w);
 return g; }

static lvm(lvm_tether) {
 LvmCallp(g, 1, host_tether, -1) }
static lvm(lvm_tetherenv) {
 LvmCallp(g, 2, host_tether, 1) }    // env at sp[1]

// (reap pid) -> (status) | (): a list, so exited 0 is truthy apart from still running
static lvm(lvm_reap) {
 LvmCall(g, host_reap, (pid_t) (charmp(Sp[0]) ? getcharm(Sp[0]) : 0)) }

// a non-charm pid may not fold to 0, which signals the caller's own group
static lvm(lvm_kill) {
 if (!charmp(Sp[0]) || !charmp(Sp[1])) {
  Sp[1] = badarg(g); love_musttail return Nextp(1, 1); }
 Sp[1] = kill((pid_t) getcharm(Sp[0]), (int) getcharm(Sp[1])) ? love_err(g, errno) : ZeroPoint;
 love_musttail return Nextp(1, 1); }

// (tty fd) -> (rows . cols) | 'enotty: size and isatty are one question, so test with two?
love_noinline static struct g *host_tty(struct g *g) {
 struct winsize ws;
 word x = g->sp[0];
 intptr_t fd = charmp(x) ? getcharm(x) : port_fd(x);   // a charm is a raw fd
 if (fd < 0) { g->sp[0] = badarg(g); return g; }
 if (ioctl((int) fd, TIOCGWINSZ, &ws) < 0) { g->sp[0] = love_err(g, errno); return g; }
 if (!ok(g = have(g, Width(struct chain)))) return g;
 struct chain *w = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                 putcharm(ws.ws_row), putcharm(ws.ws_col));
 g->sp[0] = word(w);
 return g; }

static lvm(lvm_tty) {
 LvmCall(g, host_tty) }

// (settty port rows cols): the kernel raises SIGWINCH on the slave's foreground group
love_noinline static int host_settty(intptr_t fd, intptr_t row, intptr_t col) {
 struct winsize ws = {0};
 ws.ws_row = (unsigned short) row;
 ws.ws_col = (unsigned short) col;
 return ioctl((int) fd, TIOCSWINSZ, &ws) ? -errno : 0; }

static lvm(lvm_settty) {
 intptr_t fd  = port_fd(Sp[0]),
          row = charmp(Sp[1]) ? getcharm(Sp[1]) : 0,
          col = charmp(Sp[2]) ? getcharm(Sp[2]) : 0;
 int rc = host_settty(fd, row, col);
 Sp[2] = rc ? love_err(g, -rc) : ZeroPoint;
 love_musttail return Nextp(1, 2); }

// (ptyecho port on): ECHO only, so a line-editing wrapper owns the echo; ICANON stays
love_noinline static int host_ptyecho(intptr_t fd, intptr_t on) {
 struct termios t;
 if (fd < 0) return -EBADF;
 if (tcgetattr((int) fd, &t)) return -errno;
 if (on) t.c_lflag |= ECHO; else t.c_lflag &= ~(tcflag_t) ECHO;
 return tcsetattr((int) fd, TCSANOW, &t) ? -errno : 0; }

static lvm(lvm_ptyecho) {
 intptr_t fd = port_fd(Sp[0]),
          on = charmp(Sp[1]) ? getcharm(Sp[1]) : 0;
 int rc = host_ptyecho(fd, on);
 Sp[1] = rc ? love_err(g, -rc) : ZeroPoint;
 love_musttail return Nextp(1, 1); }

// (termios fd) -> (iflag oflag cflag lflag speed cc0..cc16) in linux's spelling; speed from
// c_ospeed, else CBAUD. settermios takes it back; a negative speed keeps cflag's CBAUD
static const unsigned tio_baud[][2] = {
 {0, 0}, {50, 1}, {75, 2}, {110, 3}, {134, 4}, {150, 5}, {200, 6}, {300, 7}, {600, 8},
 {1200, 9}, {1800, 10}, {2400, 11}, {4800, 12}, {9600, 13}, {19200, 14}, {38400, 15},
 {57600, 4097}, {115200, 4098}, {230400, 4099}, {460800, 4100}, {500000, 4101},
 {576000, 4102}, {921600, 4103}, {1000000, 4104}, {1152000, 4105}, {1500000, 4106},
 {2000000, 4107}, {2500000, 4108}, {3000000, 4109}, {3500000, 4110}, {4000000, 4111}};
#define TIO_NB (sizeof tio_baud / sizeof *tio_baud)
// the libcs whose struct termios names the speeds (musl's are __c_ispeed, kept private)
#if defined __moonlibc__ || defined _HAVE_STRUCT_TERMIOS_C_OSPEED
#define TIO_SPEEDS 1
#else
#define TIO_SPEEDS 0
#endif
love_noinline static struct g *host_termios(struct g *g) {
 word x = g->sp[0];
 intptr_t fd = charmp(x) ? getcharm(x) : port_fd(x);
 struct termios t;
 if (fd < 0) return g->sp[0] = badarg(g), g;
 memset(&t, 0, sizeof t);
 if (tcgetattr((int) fd, &t)) return g->sp[0] = love_err(g, errno), g;
 intptr_t sp = 0;
#if TIO_SPEEDS
 sp = (intptr_t) t.c_ospeed;
#endif
 if (!sp) for (unsigned k = 0; k < TIO_NB; k++)
  if (tio_baud[k][1] == (t.c_cflag & 4111u)) sp = tio_baud[k][0];
 size_t const C = Width(struct chain);
 if (!ok(g = have(g, 22 * C))) return g;
 struct chain *c = 0;
 word l = ZeroPoint;
 for (int k = 16; k >= 0; k--) c = ini_chain(bump(g, C), putcharm(t.c_cc[k]), l), l = word(c);
 intptr_t hd[5] = {t.c_iflag, t.c_oflag, t.c_cflag, t.c_lflag, sp};
 for (int k = 4; k >= 0; k--) c = ini_chain(bump(g, C), putcharm(hd[k]), l), l = word(c);
 return g->sp[0] = l, g; }
static lvm(lvm_termios) {
 LvmCall(g, host_termios) }

love_noinline static word host_settermios(struct g *g, word x, word l) {
 intptr_t fd = charmp(x) ? getcharm(x) : port_fd(x), v[22];
 struct termios t;
 int n = 0;
 for (; n < 22 && chainp(l) && charmp(A(l)); n++, l = B(l)) v[n] = getcharm(A(l));
 if (fd < 0 || n < 22) return badarg(g);
 memset(&t, 0, sizeof t);
 if (tcgetattr((int) fd, &t)) return love_err(g, errno);
 t.c_iflag = (tcflag_t) v[0], t.c_oflag = (tcflag_t) v[1], t.c_lflag = (tcflag_t) v[3];
 t.c_cflag = (tcflag_t) v[2];
 if (v[4] >= 0) {                                // a negative speed keeps cflag's own
  t.c_cflag &= ~4111u;
  for (unsigned k = 0; k < TIO_NB; k++)
   if (tio_baud[k][0] == (unsigned) v[4]) t.c_cflag |= tio_baud[k][1];
#if TIO_SPEEDS
  t.c_ispeed = t.c_ospeed = (speed_t) v[4];
#endif
  }
 for (int k = 0; k < 17; k++) t.c_cc[k] = (cc_t) v[5 + k];
 return tcsetattr((int) fd, TCSADRAIN, &t) ? love_err(g, errno) : ZeroPoint; }
LvmWord2(settermios)

// (raw on): off restores the cooked termios from the first raw-on. one baseline and one
// atexit, shared with main.c's repl, or two owners would ride atexit's LIFO
static struct termios raw_cooked;
static int raw_have_cooked = 0;
static void raw_restore(void) {
 if (raw_have_cooked) tcsetattr(STDIN_FILENO, TCSANOW, &raw_cooked); }
love_noinline int raw_mode(intptr_t on) {
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
 int rc = raw_mode(on);
 Sp[0] = rc ? love_err(g, -rc) : ZeroPoint;
 love_musttail return Next(1); }

// (swig port b): what the fd has waiting into cask b, unblocking; 0 is nothing or eof
static lvm(lvm_swig) {
 word p = Sp[0], x = Sp[1], out = badarg(g);
 if (!charmp(p) && ((union u*) p)->ap == lvm_port_io
      && caskp(x)) {
  struct io *io = (struct io*) p;
  intptr_t fd = io_fd(io);
  struct str *s = cask(x)->str;
    // the port's buffered bytes first, or the order scrambles
  if (s->len && io_pending(g, io)) {
   uintptr_t k = io_read_drain(g, io, (unsigned char*) s->bytes, s->len);
   Sp[1] = putcharm((intptr_t) k);
   love_musttail return Nextp(1, 1); }
  if (fd >= 0 && s->len) {
   int fl = fcntl((int) fd, F_GETFL);
   fcntl((int) fd, F_SETFL, fl | O_NONBLOCK);
   ssize_t k = read((int) fd, s->bytes, s->len);
   fcntl((int) fd, F_SETFL, fl);
   out = k > 0 ? putcharm(k)
          : k == 0 ? putcharm(0)
          : (errno == EAGAIN || errno == EWOULDBLOCK) ? putcharm(0)
          : love_err(g, errno); } }
 Sp[1] = out;
 love_musttail return Nextp(1, 1); }

// the port doors. on inle open(2)/close(2) land in src/inle/sys.c; on the host /love is the
// carried tree's. `open` in the book lights up prel's module walk (fsopen) and salt's config read
// mode's first byte: r read, w truncate-or-create, a append-or-create
static int call_open(struct str *pv, struct str *mv) {
  if (mv->len == 0) return -1;
  int flags;
  switch (mv->bytes[0]) {
    case 'r': flags = O_RDONLY; break;
    case 'w': flags = O_WRONLY | O_CREAT | O_TRUNC; break;
    case 'a': flags = O_WRONLY | O_CREAT | O_APPEND; break;
    default: return -1; }
  int fd = fd_up(open(pv->bytes, flags | O_CLOEXEC, 0644));
  return fd < 0 ? -errno : fd; }
static int mk_open(struct g *g, void *env) { (void) env; return call_open(str(g->sp[0]), str(g->sp[1])); }

// a nom is truthy: test with port? or nom?, never ?. LvmCallp's Pack writes back the registers
// a seat's open may report (inle's /proc/gauge)
love_noinline static struct g *host_open(struct g *g) {
  { char rel[256];
    uintptr_t rn;
    struct str *mv = str(g->sp[1]);
    intptr_t i = lovefs_at(str(g->sp[0])->bytes, rel, &rn);
    if (i != -1) {                                // /love: read-only
      char m = mv->len ? mv->bytes[0] : 0;
      word e = m != 'r' && m != 'w' && m != 'a' ? badarg(g)
             : m != 'r' ? love_err(g, EROFS)
             : i == -2 ? love_err(g, ENOENT)
             : i == -3 ? love_err(g, EISDIR) : ZeroPoint;
      return e != ZeroPoint ? push(g, 1, e) : lovefs_port(g, (uintptr_t) i); } }
  int fd = mk_open(g, NULL);
  if (!ok(g = love_fd_retry(g, &fd, mk_open, NULL))) return g;
  if (fd < 0) return push(g, 1, fd == -1 ? badarg(g) : love_err(g, -fd));
  struct g *r = io_alloc(g, fd);
  return ok(r) ? r : (close(fd), push(g, 1, love_err(g, ENOMEM))); }
static lvm(lvm_open) {
  if (!cstrp(Sp[0]) || !strp(Sp[1])) { Sp[1] = badarg(g); love_musttail return Nextp(1, 1); }
  LvmCallp(g, 2, host_open) }

// (close x), a port or a raw fd: a port gets the closed vt, so later doors and the finalizer skip
static lvm(lvm_close) {
  if (charmp(Sp[0])) {
    intptr_t fd = getcharm(Sp[0]);
    Sp[0] = (fd >= 0 && close((int) fd)) ? love_err(g, errno) : ZeroPoint;
    love_musttail return Next(1); }
  if (cell(Sp[0])->ap == lvm_port_io) {
    struct io *io = (struct io*) Sp[0];
    intptr_t fd = io_fd(io);
    bool horn = io->vt == &love_horn_vt;       // its device shuts its own way, after the run lands
    if (fd >= 0 || horn) {
      g->io = io;
      Pack(g);
      g = io_wflush(g, io);
      if (!ok(g)) love_musttail return Ap(_lvm_ghelp, g);
      // a short write parks; nothing is mutated yet, so the re-run is this close whole
      if (io_wpending(g, (struct io*) g->sp[0])) {
        Unpack(g);
        g->next_wake_at = love_clock() + 1;
        love_musttail return Ap(lvm_yield_sw, g); }
      Unpack(g);
      if (horn) love_horn_shut((struct io*) Sp[0]); else close(fd);
      ((struct io*) Sp[0])->vt = &closed_vt; } }   // re-read: wflush may collect
  Sp[0] = ZeroPoint;
  love_musttail return Next(1); }

LvDef("tether", tether, 1, NULL);
LvDef("tetherenv", tetherenv, 2, "posix");
LvDef("gather", reap, 1, "posix");
LvDef("still", kill, 2, NULL);
LvDef("tty", tty, 1, NULL);
LvDef("settty", settty, 3, NULL);
LvDef("ptyecho", ptyecho, 2, "posix");
LvDef("termios", termios, 1, "posix");
LvDef("settermios", settermios, 2, "posix");
LvDef("raw", raw, 1, NULL);
LvDef("swig", swig, 2, "posix");
LvDef("open", open, 2, "posix");
LvDef("close", close, 1, "posix");
