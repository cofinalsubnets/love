// host/pty.c -- bao's pty-wrapper nifs (the rlwrap/debugger muscle): spawn a
// program on a fresh pseudo-terminal, reap it without blocking, signal it, and
// read/write its window size. Self-contained host nif file: auto-globbed +
// AI_NIF-registered, no edit to ai.c / ai.h / main.c (see host/host.c).
//
// The keystone, (mind argv), is host_run (main.c) with the stdout PIPE swapped
// for a pty pair: the same argv-marshal-into-the-uncommitted-gap + close-on-exec
// errno-pipe handshake, but the child's 0/1/2 become the pty SLAVE and the parent
// keeps the MASTER as a heap port (ai_io_alloc). So bao's editor talks to any
// program over the master the way a terminal would.
//
//   (mind argv)      -> (pid . master-port) | a fixnum (errno, or -1 = misuse)
//   (reap pid)         -> (status)   exited (a PAIR, truthy even at status 0)
//                       | ()         still running
//                       | errno      waitpid error (e.g. ECHILD)
//   (kill pid sig)     -> () ok | errno   (caller passes (0 - pid) for the group)
//   (winsize _)        -> (rows . cols) of the controlling tty (stdout), or ()
//   (setwinsize p r c) -> () ok | errno   push a size onto a master port
//
// (winsize) takes a dummy arg (ignored, like getpid): a bare (winsize) is the
// function itself -- (f) == f at zero operands -- so the call is (winsize 0).
#define _GNU_SOURCE     // posix_openpt/grantpt/unlockpt/ptsname (not in gnu23's default set)
#include "ai.h"
#include <stdlib.h>     // posix_openpt grantpt unlockpt ptsname
#include <unistd.h>     // fork setsid dup2 close execvp read write _exit
#include <fcntl.h>      // open O_RDWR O_NOCTTY fcntl FD_CLOEXEC
#include <errno.h>
#include <string.h>     // memcpy
#include <signal.h>     // kill
#include <sys/ioctl.h>  // ioctl TIOCSCTTY TIOC[GS]WINSZ struct winsize
#include <sys/wait.h>   // waitpid WNOHANG WIF* WEXITSTATUS WTERMSIG
#include <termios.h>    // tcgetattr tcsetattr ECHO TCSANOW (ptyecho)

// Pull a live OS fd out of a port arg, or -1 if it isn't a port. Same inline
// "is x a port" as main.c's lvm_close: a heap word whose discriminator is the
// port vtable. A closed port carries the -3 sentinel; we hand that straight back
// to the ioctl, which fails with EBADF -- the honest answer.
static intptr_t port_fd(ai_word x) {
  if ((x & 1) == 0 && ((union u*) x)->ap == lvm_port_io)
    return getcharm(((struct ai_io*) x)->fd);
  return -1; }

// Decode a wait(2) status word the way host_run does: exit code, or 128+signal,
// or -1 for the (shouldn't-happen) neither case.
static int decode_status(int st) {
  return WIFEXITED(st) ? WEXITSTATUS(st)
       : WIFSIGNALED(st) ? 128 + WTERMSIG(st) : -1; }

// Workhorse for (mind argv), called with g Packed; argv is the single arg and
// the sole GC root at g->sp[0]. Leaves EXACTLY ONE net value above argv on every
// non-OOM path (so lvm_ptyrun collapses uniformly, cf. host_run): the
// (pid . master-port) chain on success, an errno/-1 fixnum otherwise. Returns a
// not-ok g only on OOM (lvm_ptyrun routes that to ghelp).
ai_noinline static struct ai *host_ptyrun(struct ai *g, ai_word argv) {
  // pass 1: every element a string; size the NUL-terminated arg blob.
  intptr_t argc = 0; uintptr_t total = 0;
  for (ai_word p = argv; chainp(p); p = B(p)) {
    if (!ai_strp(A(p))) return ai_push(g, 1, putcharm(-1));   // misuse
    argc++, total += len(A(p)) + 1; }
  if (!argc) return ai_push(g, 1, putcharm(-1));              // empty argv

  // Marshal cav (argc+1 pointers) + the byte blob into the uncommitted heap gap
  // at Hp -- invisible to GC, holds no l pointers, consumed (execvp'd) in the
  // child before any further allocation. NO l allocation between here and fork:
  // openpt/grantpt/unlockpt/ptsname/pipe don't touch the heap, so the gap holds.
  if (!ai_ok(g = ai_have(g, (uintptr_t) argc + 1 + b2w(total)))) return g;
  argv = g->sp[0];                                  // ai_have may have GC'd; re-root
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

  // open the master, unlock the slave, copy the slave path (ptsname's buffer is
  // static -- snapshot it for the child, which inherits the snapshot across fork).
  int mfd = posix_openpt(O_RDWR | O_NOCTTY);
  if (mfd < 0) return ai_push(g, 1, putcharm(errno));
  if (grantpt(mfd) || unlockpt(mfd)) { int e = errno; close(mfd); return ai_push(g, 1, putcharm(e)); }
  char sname[128];
  { char const *p = ptsname(mfd);
    if (!p || strlen(p) >= sizeof sname) { close(mfd); return ai_push(g, 1, putcharm(p ? ENAMETOOLONG : errno)); }
    memcpy(sname, p, strlen(p) + 1); }

  // close-on-exec errno pipe: child writes its setup/exec errno here; a clean
  // exec closes the write end -> parent reads EOF (childerr stays 0).
  int ep[2];
  if (pipe(ep)) { int e = errno; close(mfd); return ai_push(g, 1, putcharm(e)); }
  fcntl(ep[1], F_SETFD, FD_CLOEXEC);

  pid_t pid = fork();
  if (pid < 0) { int e = errno; close(mfd); close(ep[0]); close(ep[1]); return ai_push(g, 1, putcharm(e)); }
  if (!pid) {                                       // child
    close(mfd); close(ep[0]);
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
    return ai_push(g, 1, putcharm(childerr)); }

  // success: master -> heap port (pushes it to sp[0]; argv slides to sp[1]).
  struct ai *io = ai_io_alloc(g, mfd);
  if (!ai_ok(io)) {                                 // OOM: tear the child down, then ghelp
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

static lvm(lvm_ptyrun) {
  Pack(g);
  g = host_ptyrun(g, Sp[0]);
  if (!ai_ok(g)) return ghelp(g);
  Unpack(g);
  Sp[1] = Sp[0];                                    // result over argv
  Sp += 1; Ip += 1;
  return Continue(); }

// (reap pid): non-blocking wait. A reaped child returns its decoded status as a
// ONE-ELEMENT LIST so the result is a present chain even at status 0 -- a caller
// polling in a loop tells "exited 0" (a pair) from "still running" (()) without
// the two collapsing to the same blue. A bare fixnum means waitpid itself erred.
static lvm(lvm_reap) {
  intptr_t pid = (Sp[0] & 1) ? getcharm(Sp[0]) : 0;
  int st;
  pid_t r = waitpid((pid_t) pid, &st, WNOHANG);
  if (r == 0) { Sp[0] = ai_nil; Ip += 1; return Continue(); }          // still running
  if (r < 0)  { Sp[0] = putcharm(errno); Ip += 1; return Continue(); } // waitpid error
  Pack(g);
  if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return ghelp(g);
  struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 putcharm(decode_status(st)), ai_nil);
  Unpack(g);
  Sp[0] = word(w);
  Ip += 1; return Continue(); }

// (kill pid sig): POSIX kill(2). A negative pid (the caller writes (0 - pid),
// never -pid -- that lexes as a kebab name) signals the process group. Returns
// () on success, the errno fixnum on failure.
static lvm(lvm_kill) {
  intptr_t pid = (Sp[0] & 1) ? getcharm(Sp[0]) : 0;
  intptr_t sig = (Sp[1] & 1) ? getcharm(Sp[1]) : 0;
  Sp[1] = kill((pid_t) pid, (int) sig) ? putcharm(errno) : ai_nil;
  Sp += 1; Ip += 1; return Continue(); }

// (winsize): the controlling tty's size as (rows . cols), read off stdout; () if
// stdout isn't a tty (ioctl fails). The size to MIRROR onto a wrapped child.
static lvm(lvm_winsize) {
  struct winsize ws;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) < 0) { Sp[0] = ai_nil; Ip += 1; return Continue(); }
  Pack(g);
  if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return ghelp(g);
  struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 putcharm(ws.ws_row), putcharm(ws.ws_col));
  Unpack(g);
  Sp[0] = word(w);
  Ip += 1; return Continue(); }

// (setwinsize port rows cols): push a window size onto a master port; the kernel
// raises SIGWINCH on the slave's foreground group. () on success, errno on
// failure (incl. a non-port / closed port -> EBADF).
static lvm(lvm_setwinsize) {
  intptr_t fd = port_fd(Sp[0]);
  struct winsize ws = {0};
  ws.ws_row = (Sp[1] & 1) ? (unsigned short) getcharm(Sp[1]) : 0;
  ws.ws_col = (Sp[2] & 1) ? (unsigned short) getcharm(Sp[2]) : 0;
  int rc = ioctl((int) fd, TIOCSWINSZ, &ws);
  Sp[2] = rc ? putcharm(errno) : ai_nil;
  Sp += 2; Ip += 1; return Continue(); }

// (ptyecho port on): toggle the pty's input ECHO. on = 0 / () clears it so a
// line-editing wrapper (bao's edraw) owns the echo and the child's cooked-mode
// echo doesn't double it; a truthy `on` restores it. ICANON is left intact -- the
// child still reads whole lines and sees VEOF. tcsetattr on the master fd sets the
// shared pty termios. () on success, errno on failure (non-port / closed -> EBADF).
static lvm(lvm_ptyecho) {
  intptr_t fd = port_fd(Sp[0]);
  struct termios t;
  int rc;
  if (fd < 0) rc = EBADF;
  else if (tcgetattr((int) fd, &t)) rc = errno;
  else {
    intptr_t on = (Sp[1] & 1) ? getcharm(Sp[1]) : 0;
    if (on) t.c_lflag |= ECHO; else t.c_lflag &= ~(tcflag_t) ECHO;
    rc = tcsetattr((int) fd, TCSANOW, &t) ? errno : 0; }
  Sp[1] = rc ? putcharm(rc) : ai_nil;
  Sp += 1; Ip += 1; return Continue(); }

static union u const
  nif_ptyrun[]     = {{lvm_ptyrun}, {lvm_ret0}},
  nif_reap[]       = {{lvm_reap}, {lvm_ret0}},
  nif_kill[]       = {{lvm_cur}, {.x = putcharm(2)}, {lvm_kill}, {lvm_ret0}},
  nif_winsize[]    = {{lvm_winsize}, {lvm_ret0}},
  nif_setwinsize[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_setwinsize}, {lvm_ret0}},
  nif_ptyecho[]    = {{lvm_cur}, {.x = putcharm(2)}, {lvm_ptyecho}, {lvm_ret0}};
AI_NIF("mind", nif_ptyrun);
AI_NIF("gather", nif_reap);
AI_NIF("still", nif_kill);
AI_NIF("winsize", nif_winsize);
AI_NIF("setwinsize", nif_setwinsize);
AI_NIF("ptyecho", nif_ptyecho);
