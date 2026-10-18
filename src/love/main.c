#define _GNU_SOURCE     // sigaltstack, SA_ONSTACK, MAP_ANONYMOUS
#include "love.h"
#include "cats.h"
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
#include <stddef.h>      // offsetof
#if defined(__moonlibc__)
#endif
#include <stdnoreturn.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/utsname.h>
#include <sys/mman.h>
#include <sys/resource.h>

// the fine clock; love.c's weak default degrades to ms*1e6
love_noinline intptr_t nclock(void) {
 struct timespec ts;
 return clock_gettime(CLOCK_MONOTONIC, &ts) ? -1
  : (intptr_t) ts.tv_sec * 1000000000 + ts.tv_nsec; }

static void stdin_give(struct g *g) {
 if (!g || !ok(g)) return;
 if (g->inflag)                                          // the blocking bit was ours
  fcntl(STDIN_FILENO, F_SETFL, (int) getcharm(g->inflag)), g->inflag = 0;
 if (!g->inport || lseek(STDIN_FILENO, 0, SEEK_CUR) < 0) return;   // an unseekable door: stdin_hand's
 uintptr_t n = io_pending(g, (struct io*) g->inport)
             + (getcharm(love_stdin.io.ungetc_buf) != EOF ? 1 : 0);
 if (n) lseek(STDIN_FILENO, -(off_t) n, SEEK_CUR); }

static struct g *stdin_take(struct g *g) {
 if (!ok(g)) return g;
 if (lseek(STDIN_FILENO, 0, SEEK_CUR) < 0) {              // not seekable: a tty, or a pipe
  if (isatty(STDIN_FILENO)) return g;
  int fl = fcntl(STDIN_FILENO, F_GETFL);                  // a pipe: take the bit and the bytes
  if (fl >= 0 && ((fl & O_NONBLOCK) || fcntl(STDIN_FILENO, F_SETFL, fl | O_NONBLOCK) >= 0))
   g->inflag = putcharm(fl); }                            // already-nonblocking restores to itself
 if (!ok(g = io_alloc(g, STDIN_FILENO))) return g;
 g->inport = g->sp[0], g->sp++;
 return g; }

_lvm(k_lvm_quit);
_lvm(k_lvm_getpid);

// a process on inle speaks linux's calls, and only its uname names the kernel under it
static bool on_inle(void) {
#if defined(__moonlibc__)
 struct utsname u;
 return !uname(&u) && !strcmp(u.sysname, "Inle");
#else
 return false;
#endif
}

// on inle a twirled task is a process of the shell's
static lvm(lvm_exit) {
 if (__love_osv < 0) love_musttail return Ap(k_lvm_quit, g);
 union u *t = g->tasks;
 if (t && (t[2].x & 1) && getcharm(t[2].x) && on_inle()) love_musttail return Ap(lvm_task_quit, g);
 for (;;) stdin_give(g), exit(getcharm(Sp[0])); }


static void stdin_hand(struct g *g) {
 stdin_give(g);
 if (!g || !ok(g)) return;
 if (!g->inport || lseek(STDIN_FILENO, 0, SEEK_CUR) >= 0) return;   // seekable: the seek said it all
 unsigned char res[iobuf + 1];
 uintptr_t n = 0;
 if (getcharm(love_stdin.io.ungetc_buf) != EOF)
  res[n++] = (unsigned char) getcharm(love_stdin.io.ungetc_buf),
  love_stdin.io.ungetc_buf = putcharm(EOF);
 n += io_read_drain(g, (struct io*) g->inport, res + n, sizeof res - n);
 if (!n) return;                                                    // the fd is already exact
 int p[2];
 if (pipe(p)) return;
 pid_t pid = fork();
 if (pid < 0) return close(p[0]), (void) close(p[1]);
 if (!pid) {                                                        // the pumper: residue, then the rest
  close(p[0]);
  if (love_fd_write_all(p[1], res, n) == n)
   for (;;) {
    unsigned char buf[iobuf];
    ssize_t k = read(STDIN_FILENO, buf, sizeof buf);
    if (k < 0 && errno == EINTR) continue;
    if (k <= 0 || love_fd_write_all(p[1], buf, (uintptr_t) k) < (uintptr_t) k) break; }
  _exit(0); }                                                       // _exit: no atexit, no flush, no love
 close(p[1]);
 if (p[0] != STDIN_FILENO) dup2(p[0], STDIN_FILENO), close(p[0]); }

static void host_teeout(char const *p, size_t n) {
 while (n) {
  ssize_t w = write(STDOUT_FILENO, p, n);
  if (w < 0) { if (errno == EINTR) continue; return; }
  p += w, n -= (size_t) w; } }

static struct g *host_harkst(struct g *g, intptr_t fd, intptr_t pid, int tee) {
 g = push(g, 3, putcharm(0), putcharm(fd), putcharm(pid));
 if (ok(g)) g->sp[3] = putcharm(tee);
 return g; }

// the first ap: marshal argv at sp[0], fork, confirm the exec. g Packed; not ok only on oom
love_noinline static struct g *host_harkstart(struct g *g, int tee) {
 char **cav;
 g = love_argv_marshal(g, &cav);
 if (!cav) {                                              // a misuse, or the reserve
  if (!ok(g)) return g;
  g = host_harkst(g, -1, 0, tee);                         // then the nom: harkst's push can collect
  return push(g, 1, badarg(g)); }

 int op[2], ep[2];
 // errno saved before each push: a collection that grows the pool makes syscalls
 if (pipe(op)) { int e = errno;
  g = host_harkst(g, -1, 0, tee);
  return push(g, 1, love_err(g, e)); }
 if (pipe(ep)) { int e = errno; close(op[0]); close(op[1]);
  g = host_harkst(g, -1, 0, tee);
  return push(g, 1, love_err(g, e)); }
 fcntl(op[0], F_SETFD, FD_CLOEXEC), fcntl(ep[0], F_SETFD, FD_CLOEXEC), fcntl(ep[1], F_SETFD, FD_CLOEXEC);
 fflush(stdout);
 pid_t pid = fork();
 if (pid < 0) { int e = errno;
  close(op[0]); close(op[1]); close(ep[0]); close(ep[1]);
  g = host_harkst(g, -1, 0, tee);
  return push(g, 1, love_err(g, e)); }
 if (!pid) {
  signal(SIGPIPE, SIG_DFL);                               // the ignore must not ride the exec
  dup2(op[1], STDOUT_FILENO);
  int nul = open("/dev/null", O_RDONLY);
  if (nul >= 0) { dup2(nul, STDIN_FILENO); if (nul > 2) close(nul); }
  close(op[0]); close(op[1]); close(ep[0]);
  execvp(argv_file(cav), cav);
  int e = errno; ssize_t w = write(ep[1], &e, sizeof e); (void) w;
  _exit(127); }
 close(op[1]); close(ep[1]);
 int childerr = 0; ssize_t r;
 do r = read(ep[0], &childerr, sizeof childerr); while (r < 0 && errno == EINTR);
 close(ep[0]);
 if (childerr) {
  close(op[0]);
  int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
  g = host_harkst(g, -1, 0, tee);
  return push(g, 1, love_err(g, childerr)); }

 int fl = fcntl(op[0], F_GETFL);
 if (fl >= 0) fcntl(op[0], F_SETFL, fl | O_NONBLOCK);
 return str0(host_harkst(g, op[0], pid, tee), 1u << 16); }  // the capture at sp[0]

love_noinline static struct g *host_harkdrain(struct g *g) {
 intptr_t fd = getcharm(g->sp[2]);
 if (fd == -1) return g;                        // nothing was spawned: sp[0] is the answer
 pid_t pid = (pid_t) getcharm(g->sp[3]);
 if (fd >= 0) {
  int tee = getcharm(g->sp[4]) != 0;
  uintptr_t n = (uintptr_t) getcharm(g->sp[1]);
  for (;;) {
   uintptr_t lim = len(g->sp[0]);
   if (n == lim) {
    if (ok(g = grbufg(g, lim))) continue;
    // oom: kill the child rather than wait on it
    close((int) fd);
    kill(pid, SIGKILL);
    { int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {} }
    return g; }
   ssize_t r = read((int) fd, txt(g->sp[0]) + n, lim - n);
   if (r > 0) {
    if (tee) host_teeout(txt(g->sp[0]) + n, (size_t) r);  // ..before the buffer can move
    n += (uintptr_t) r;
    continue; }
   if (r < 0 && errno == EINTR) continue;
   g->sp[1] = putcharm((intptr_t) n);
   if (r < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
    g->next_wait_fd = (int) fd;                           // the scheduler owns the wait
    return g; }
   break; }                                               // EOF, or an unusable error
  close((int) fd);
  g->sp[2] = putcharm(-2); }                              // drained; now reap
 int st; pid_t w;
 do w = waitpid(pid, &st, WNOHANG); while (w < 0 && errno == EINTR);
 if (!w) { g->next_wake_at = love_clock() + 1; return g; }
 uintptr_t n = (uintptr_t) getcharm(g->sp[1]);
 if (n) len(g->sp[0]) = n;
 else g->sp[0] = EmptyString;
 int status = w < 0 ? -1
            : WIFEXITED(st) ? WEXITSTATUS(st)
            : WIFSIGNALED(st) ? 128 + WTERMSIG(st) : -1;
 if (!ok(g = have(g, Width(struct chain)))) return g;
 struct chain *c = ini_chain((struct chain*) bump(g, Width(struct chain)),
                                putcharm(status), g->sp[0]);
 g->sp[0] = word(c);
 g->sp[2] = putcharm(-1);
 return g; }

static lvm(lvm_hark) {
 LvmCall(g, host_harkstart, 0) }

// (herald argv): hark, with the child's stdout relayed as it arrives
static lvm(lvm_herald) {
 LvmCall(g, host_harkstart, 1) }

// the shared second ap: it parks with Ip unadvanced, so the op re-runs off the stack's state
static lvm(lvm_harkdrain) {
 Pack(g);
 g = host_harkdrain(g);
 if (!ok(g)) love_musttail return Ap(_lvm_ghelp, g);
 Unpack(g);
 if (Sp[2] != putcharm(-1)) love_musttail return Ap(lvm_yield_sw, g);
 Sp[4] = Sp[0];                                           // the answer over the state
 Sp += 4; Ip += 1;
 love_musttail return Continue(); }

love_noinline static struct g *host_exec(struct g *g) {
 char **cav;
 g = love_argv_marshal(g, &cav);
 if (!cav) return push(g, 1, badarg(g));
 fflush(stdout);
 fflush(stderr);
 signal(SIGPIPE, SIG_DFL);                                 // the ignore must not ride the exec
 stdin_hand(g);                                            // the child inherits fd 0: hand it over exact
 execvp(argv_file(cav), cav);
 return push(g, 1, love_err(g, errno)); }

static lvm(lvm_exec) {
 LvmCallp(g, 1, host_exec) }

// (fexec fd argv): exec by an fd the caller opened, which survives a chroot, unlink or mount move
// glibc hides environ behind __USE_GNU
extern char **environ;

love_noinline static struct g *host_fexec(struct g *g) {
 // the fd is read before the marshal, so it needs no root
 word x = g->sp[0];
 intptr_t fd = charmp(x) ? getcharm(x) : port_fd(x);    // a charm is a raw fd
 char **cav;
 g->sp[0] = g->sp[1];                       // argv over the fd
 g = love_argv_marshal(g, &cav);
 if (!cav || fd < 0) return push(g, 1, badarg(g));
 fflush(stdout);
 fflush(stderr);
 signal(SIGPIPE, SIG_DFL);
 stdin_hand(g);                                            // as host_exec: fd 0 exact
 fexecve((int) fd, cav, environ);
 return push(g, 1, love_err(g, errno)); }

static lvm(lvm_fexec) {
 LvmCallp(g, 2, host_fexec) }   // returns only on failure; the errno nom over argv

// (getenv name): a string, or 0 if unset or misused. a love string is always NUL-terminated
static lvm(lvm_getenv) {
 char const *v = cstrp(Sp[0]) ? getenv(txt(Sp[0])) : NULL;
 if (!v) { Sp[0] = ZeroPoint; love_musttail return Next(1); }
 LvmCallp(g, 1, strof, v) }

static lvm(lvm_getpid) {
  if (__love_osv < 0) love_musttail return Ap(k_lvm_getpid, g);
  love_musttail return Answer(putcharm(getpid())); }

static union u const
  nif_hark[] = {{lvm_hark}, {lvm_harkdrain}, {lvm_ret0}},
  nif_herald[] = {{lvm_herald}, {lvm_harkdrain}, {lvm_ret0}};
LvDef("quit", exit, 1, NULL);
LvNif("hark", nif_hark, NULL);
LvNif("herald", nif_herald, NULL);
LvDef("exec", exec, 1, NULL);
LvDef("fexec", fexec, 2, NULL);
LvDef("getenv", getenv, 1, NULL);
LvDef("getpid", getpid, 1, NULL);

static struct g *env_budget(struct g *g) {
  char const *b = getenv("LOVE_BUDGET_MB");
  if (g && b && atol(b) > 0) {
    g->budget = (uintptr_t) atol(b) * (1024 * 1024 / sizeof(word));
    return g; }
  if (g && !g->budget) {                                   // half the machine's memory
    long pg = sysconf(_SC_PHYS_PAGES), sz = sysconf(_SC_PAGESIZE);
    if (pg > 0 && sz > 0) g->budget = (uintptr_t) pg * (uintptr_t) sz / 2 / sizeof(word); }
  return g; }

// LOVE_NO_GLAZE: a pure-interpreter session, never the artifact
#ifdef LvGlazed
static char const glaze_off[] = "(: ev (cite 'glaze 'base-ev) natjit ())";
#else
static char const glaze_off[] = "";
#endif

// the session tail of both the egg boot and the image wake, love0's too; the rest is post.l's cli-line
static struct g *run_program(struct g *g, bool replp) {
  if (replp) (void) raw_mode(1);
  if (__love_osv > 0 && on_inle()) g = evals_(g, "(task-doors-on 0)");
  g = love_open(g);
  char const *ng = getenv("LOVE_NO_GLAZE");
  if (ng && *ng) g = evals_(g, glaze_off);
  return evals(g, replp ? "(cli-line cmdline 1)" : "(cli-line cmdline 0)"); }

#ifdef Love0
// love0's boot is inle/boot.c
struct g *boot(struct g *g, bool argp, char const *bake, char const *bake_load, char const *bake_out);
#else
// src/inle/tasks.l, by which a process on inle runs its own stages
static char const src_tasks[] =
#include "tasks.h"
 ;
#ifdef LvBakeSrc
#include "archive/srctree.h"
static char const src_distlist[] =
#include "distlist.h"
 ;

// lay the roster cat from the carried source beside `at`: the crew baked when no -l names one.
// 1 laid, 0 refused; per-process, as image.c's bake scratch
static int bsrc_lay_cat(char *cat, size_t n, char const *at) {
  char exe[4096];                                    // the kernel's PATH_MAX
  if (!srctree_len) return 0;                     // noblob.c: no source aboard
  if (!at && !(at = host_selfpath(exe, sizeof exe) ? exe : NULL)) return 0;
  struct tree *t = tree_carried();
  if (!t) return fprintf(stderr, "love: bake: the carried source will not open\n"), 0;
  snprintf(cat, n, "%s.bakecat.%ld.l", at, (long) getpid());
  int fd = open(cat, O_WRONLY | O_CREAT | O_TRUNC, 0600);
  if (fd < 0) {                                      // a read-only install
    fprintf(stderr, "love: bake: %s is not writable\n", cat);
    return 0; }
  for (char const *p = src_distlist; *p;) {
    while (*p == ' ' || *p == '\n') p++;
    char w[256]; size_t wl = 0;
    while (*p && *p != ' ' && *p != '\n' && wl < 255) w[wl++] = *p++;
    if (!wl) break;
    w[wl] = 0;
    intptr_t i = tree_find(t, w, wl);
    unsigned char const *m = i < 0 ? NULL : tree_bytes(t, t->rows + i);
    uintptr_t ml = i < 0 ? 0 : t->rows[i].len;
    if (!m || (ml && write(fd, m, ml) != (ssize_t) ml)) {
      fprintf(stderr, "love: bake: %s %s\n", w,
              i < 0 ? "is not in the carried source" : m ? "would not write" : "will not decode");
      close(fd), unlink(cat);
      return 0; } }
  return close(fd), 1; }

// a cross seed's egg stub says 2 (source.l seed-mark): its first run bakes in place, then
// re-runs the line from the image; a bake that will not go runs from the egg
static void self_bake(char const **argv) {
  char exe[4096];
  if (baked_image_len != 16 || baked_image[0] != 2 || !host_selfpath(exe, sizeof exe)) return;
  fprintf(stderr, "love: a fresh egg: baking %s in place\n", exe);
  pid_t pid = fork();
  if (pid < 0) return;
  if (!pid) {
    char const *bv[] = { exe, "bake", NULL };
    execv(exe, (char *const *) bv);
    _exit(127); }
  int st; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
  if (!WIFEXITED(st) || WEXITSTATUS(st))
    return (void) fprintf(stderr, "love: the bake did not go: running unbaked\n");
  execv(exe, (char *const *) argv);
  fprintf(stderr, "love: baked, but can't run again: running unbaked\n"); }
#else
#define bsrc_lay_cat(cat, n, at) 0
#define self_bake(argv) ((void) 0)
#endif

// read-eval a bake's cat: a raise ends the bake. the path is a value, never spliced. q is closed
// or its finalizer bakes an fd in; bake-load is rebound to () or the path bakes in
static struct g *bake_eval_file(struct g *g, char const *path) {
  uintptr_t xn = strlen(path);
  if (!ok(g = str0(g, xn))) return g;
  if (xn) memcpy(txt(g->sp[0]), path, xn);
  g = defv(g, "bake-load");
  if (!ok(g)) return g;
  g->sp++;
  g = evals_(g,
    "(: open (cite 'posix 'open) close (cite 'posix 'close)"    // the fs doors are a module's
    "   q (open bake-load \"r\")"
    " (? q (: _ (reads q) (close q))"
    "      (: _ (say err (\"love: bake: cannot open \" + bake-load)) _ (put err 10) (quit 1))))");
  return ok(g) ? evals_(g, "(: bake-load ())") : g; }

// FIXME too much code in string literals
static struct g *boot(struct g *g, bool argp, char const *bake, char const *bake_load,
                       char const *bake_out) {
  // LOVE_NO_MOP keeps the internal names (egg.l)
  char const *nm = getenv("LOVE_NO_MOP");
  if (nm && *nm) g = evals_(g, "(: nomop 1)");
  g = evals_(g, "(: latemop 1)");                   // the egg leaves its mop here, run past the glaze
  g = cats_egg(g);                                    // prel then ev's half, and the printer with `@`
  g = cats_lib(g);                                   // register every baked module
  g = evals_(g,
    "(borrow 'kanren)"
    "(borrow 'overlay)"
    "(: overlay (cite 'overlay)"
    "   ev ((cite 'overlay 'ov-hook) ev))"
    "(borrow 'uu)"
    "(: uu (cite 'uu))"
    "(borrow 'holo)"
  );
  g = shelve(g);
  g = evals_(g, "(borrow 'cli)(borrow 'verbs)");
  g = shelve(g);
  // off, so their names don't shadow the tree's locals; bao comes off with them and goes back on
  for (int i = 0; i < 4; i++) g = shelve(g);        // bao, uu, overlay, kanren
  // FIXME what is this doing? bao was just used
  g = evals_(g, "(borrow 'cli)"
    "(transcribe 'kanren ())"                                 // \\\, &&&, |||, zz -- macros, not names
    "(: unify (cite 'kanren 'unify)  ufail (cite 'kanren 'ufail)"
    "   ufail? (cite 'kanren 'ufail?)  var (cite 'kanren 'var)"
    "   s_plus (cite 'kanren 's_plus)  s_star (cite 'kanren 's_star)"
    "   === (cite 'kanren '===)  =/= (cite 'kanren '=/=))");
  g = cats_glaze(g);                                     // a no-op on an unglazed arch
#ifdef LvGlazed
  g = shelve(g);                                    // holo back to non-ambient
#endif
  g = evals_(g, "(latemop ())");                    // the egg's mop

  g = evals_(g,
    "(: spawn0 spawn  spawnio0 spawnio  spawnmap0 spawnmap  wait0 wait"
    "   tether0 tether  still0 still  tty0 tty  settty0 settty  raw0 raw  ttyfg0 ttyfg  ttypg0 ttypg"
    "   seat-doors (: t (tablet 11) _ (pin t 0 spawn0) _ (pin t 1 spawnio0)"
    "                 _ (pin t 2 spawnmap0) _ (pin t 3 wait0)"
    "                 _ (pin t 4 tether0) _ (pin t 5 still0) _ (pin t 6 tty0) _ (pin t 7 settty0)"
    "                 _ (pin t 8 raw0) _ (pin t 9 ttyfg0) _ (pin t 10 ttypg0) t)"
    "   (spawn argv) (peep seat-doors 0 0 argv)"
    "   (spawnio argv i o e cl pg fg) (peep seat-doors 1 0 argv i o e cl pg fg)"
    "   (spawnmap argv fdm cl pg fg) (peep seat-doors 2 0 argv fdm cl pg fg)"
    "   (wait p) (peep seat-doors 3 0 p)"
    "   (tether argv) (peep seat-doors 4 0 argv)"
    "   (still p sig) (peep seat-doors 5 0 p sig)"
    "   (tty fd) (peep seat-doors 6 0 fd)"
    "   (settty fd r c) (peep seat-doors 7 0 fd r c)"
    "   (raw on) (peep seat-doors 8 0 on)"
    "   (ttyfg pg) (peep seat-doors 9 0 pg)"
    "   (ttypg fd) (peep seat-doors 10 0 fd))");
  // inle has no fork: a shell's own stage (['thunk f]) runs as a task in its heap
  g = evals_(g, src_tasks);
  g = evals_(g,
    "(: (task-doors-on _)"
    "   (: (th? a) (two? a && <a = 'thunk)  (nofg gp) 0"
    "      (run a f0 f1 f2 pg fg) (task-run [<>a] a f0 f1 f2 pg fg nofg)"
    "      (io i o e) (: (one n f) (charm? f && 0 <= f ? [(n . f)] ()) (one 0 i + (one 1 o + one 2 e)))"
    // a process started from inside a task takes the stdio that task wears
    "      (host a m cl pg fg) (spawnmap0 a (task-worn m) cl pg fg)"
    "      _ (pin seat-doors 0 (\\ a (? (th? a) (run a -1 -1 -1 -1 0)"
    "                                (two? (worn ())) (host a () () -1 0)"
    "                                (spawn0 a))))"
    "      _ (pin seat-doors 1 (\\ a i o e cl pg fg"
    "                         (? (th? a) (run a (task-fdw i) (task-fdw o) (task-fdw e) pg fg)"
    "                            (two? (worn ())) (host a (io i o e) cl pg fg)"
    "                            (spawnio0 a i o e cl pg fg))))"
    "      _ (pin seat-doors 2 (\\ a m cl pg fg"
    "                         (th? a ? (task-map m (\\ x y z (run a x y z pg fg)))"
    "                            (host a m cl pg fg))))"
    "      _ (pin seat-doors 3 (\\ p (task? p ? (task-wait p) (wait0 p))))"
    "      (pin seat-doors 5 (\\ p s (? (task? p) (task-still p s)"
    "                                   (charm? p && p < 0 && two? (task-members -p)) (task-still p s)"
    "                                   (still0 p s))))))");

  // FIXME why pull from book here? that's mop's job
  g = evals_(g, bake
    ? "(: _ (pull book 'nif 0) _ (pull book 'nifx 0) _ (pull book 'born 0) (pull book 'book 0))"
    : "(: _ (pull book 'nif 0) _ (pull book 'nifx 0) (pull book 'book 0))");

  if (bake) {                                            // snapshot the post-warm heap, then exit
    // the crew is never aboard: -l names it, else the carried source's roster
    char cat[4096 + 40];                               // a path, and ".bakecat.<pid>.l"
    if (!bake_load && bsrc_lay_cat(cat, sizeof cat, bake_out)) bake_load = cat;
    if (bake_load) {
      int ok = ok(g = bake_eval_file(g, bake_load));
      if (bake_load == cat) unlink(cat);
      if (!ok) return g; }
    int rc = *bake ? (int) core_of(g = image_dump(g, bake))->b : image_bake(g, bake_out, 0);
    if (rc) fprintf(stderr, "love: bake failed (rc=%d)\n", rc);
    exit(rc ? 1 : 0); }
  return run_program(g, !argp && isatty(STDIN_FILENO)); }
#endif

// the knobs this process reads once, at boot or wake, each empty taken as unset. boot-env
// holds each as it was here, and a warm fork inherits that heap, so lush forks only for a
// child whose knobs match
static char const *const boot_knobs[] = {
  "LOVE_BUDGET_MB", "LOVE_NO_GLAZE", "LOVE_NO_IMAGE", "LOVE_NO_MOP", "LOVE_TOUCH_OUT" };
love_noinline static struct g *boot_env(struct g *g) {
  uintptr_t n = sizeof boot_knobs / sizeof *boot_knobs;
  for (uintptr_t i = 0; i < n; i++) {
    char const *v = getenv(boot_knobs[i]);
    g = strof(g, boot_knobs[i]);
    g = v && *v ? strof(g, v) : push(g, 1, ZeroPoint);     // unset or empty is ()
    g = gxr(gxr(push(g, 1, ZeroPoint))); }                   // [name value]
  g = push(g, 1, ZeroPoint);
  for (uintptr_t i = 0; i < n; i++) g = gxr(g);
  return defv(g, "boot-env"); }

love_noinline static struct g *argv_chain(struct g *g, char const **v, int argc, int skip) {
  int n = 0;
  if (argc > 0) g = strof(g, v[0]), n++;                  // argv[0] is always the program
  for (int i = 1 + skip; i < argc; i++) g = strof(g, v[i]), n++;
  for (g = push(g, 1, ZeroPoint); n--; g = gxr(g));
  return g; }

// a trap guard or a jump into data: name the signal and address, as k_exception does, then
// re-raise under the default. write only: a handler may call nothing the VM or malloc owns
static void fault_line(char const *m, uintptr_t a) {
  char b[64], *p = b;
  for (; *m; m++) *p++ = *m;
  int seen = 0;
  for (int i = (int) sizeof a * 8 - 4; i >= 0; i -= 4) {
    unsigned d = (unsigned) (a >> i) & 15;
    if (d || seen || !i) *p++ = "0123456789abcdef"[d], seen = 1; }
  *p++ = '\n';
  (void) write(2, b, (size_t) (p - b)); }
static void trap_note(int s, siginfo_t *si, void *ctx) {
  (void) ctx;
  fault_line(s == SIGTRAP ? "*** love: SIGTRAP at 0x" : "*** love: SIGILL at 0x", si ? (uintptr_t) si->si_addr : 0);
  signal(s, SIG_DFL);
  raise(s); }

// a C walk past the stack: the handler runs on its own stack, whose base holds the main
// stack's top and limit; any other fault goes back to the default and retries
void love_fault_note(int s, void *v) {
  siginfo_t *si = v;
  stack_t o;
  uintptr_t a = si ? (uintptr_t) si->si_addr : 0;
  if (!sigaltstack(NULL, &o) && o.ss_sp) {
    uintptr_t const *k = (uintptr_t const*) o.ss_sp, top = k[0], lim = k[1];
    if (a < top && top - a <= lim) {
      fault_line("*** love: stack overflow at 0x", a);
      signal(s, SIG_DFL);
      raise(s);
      return; } }
  signal(s, SIG_DFL); }
static void stack_note(int s, siginfo_t *si, void *ctx) { (void) ctx; love_fault_note(s, si); }
static void stack_note_on(void const *top) {
  size_t n = 1 << 18;                               // a lazy wake decodes its chunk on it too
  void *m = mmap(NULL, n, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (m == MAP_FAILED) return;
  struct rlimit r;
  uintptr_t cap = UINTPTR_MAX / 4,                  // no limit, or one past the word: a quarter of it
            lim = !getrlimit(RLIMIT_STACK, &r) && r.rlim_cur != RLIM_INFINITY && r.rlim_cur < cap ? (uintptr_t) r.rlim_cur : cap;
  ((uintptr_t*) m)[0] = (uintptr_t) top, ((uintptr_t*) m)[1] = lim + ((uintptr_t) 1 << 20);   // a guard's width past the limit
  stack_t ss = { .ss_sp = m, .ss_flags = 0, .ss_size = n };
  if (sigaltstack(&ss, NULL)) { munmap(m, n); return; }
  struct sigaction sa;
  memset(&sa, 0, sizeof sa);
  sa.sa_sigaction = stack_note;
  sa.sa_flags = SA_SIGINFO | SA_ONSTACK;
  sigemptyset(&sa.sa_mask);
  sigaction(SIGSEGV, &sa, NULL);
  sigaction(SIGBUS, &sa, NULL); }

// SIGTRAP only where the trap instruction raises it; on x86 it is the debugger's
static void trap_note_on(void) {
  struct sigaction sa;
  memset(&sa, 0, sizeof sa);
  sa.sa_sigaction = trap_note;
  sa.sa_flags = SA_SIGINFO;
  sigemptyset(&sa.sa_mask);
  sigaction(SIGILL, &sa, NULL);
#if defined(__aarch64__) || defined(__riscv)
  sigaction(SIGTRAP, &sa, NULL);
#endif
}

#if defined(INLE_DROID)
int k_droid_main(int argc, char const **argv);       // the kernel as a process (src/inle/droid/arch.c)
#endif
int main(int argc, char const **argv) {
#if defined(INLE_DROID)
  if (argc < 2 || strcmp(argv[1], "bake")) return k_droid_main(argc, argv);   // bake runs hosted, as love's
#endif
  signal(SIGPIPE, SIG_IGN);
  trap_note_on();
  stack_note_on(&argc);
  struct g *g = NULL;
  char const *image_load_path = NULL, *bake = NULL,   // bake: "" = self-bake, a path = an image file
             *bake_load = NULL,                      // bake -l CAT: read-eval it before the seal
             *bake_out = NULL;                       // bake -o OUT: a copy of the binary, not this one
  int skip = 0, bare = 0;                            // words that are the prime's, not the program's; bake -n
#ifndef Love0
  if (argc >= 2 && !strcmp(argv[1], "bake")) {
   int i = 2, in_place = 0;                        // bake [-l CAT] [-i] [-o OUT] [-n] [IMAGE]
   for (; i < argc && argv[i][0] == '-' && argv[i][1]; i++)
    if (!strcmp(argv[i], "-l") && i + 1 < argc) bake_load = argv[++i];
    else if (!strcmp(argv[i], "-o") && i + 1 < argc) bake_out = argv[++i];
    else if (!strcmp(argv[i], "-n")) bare = 1;      // no image: the stub back, and no snapshot
    else if (!strcmp(argv[i], "-i")) in_place = 1;  // -i says the default -- this binary -- out loud
    else
     return fprintf(stderr, "love: bake [-l CAT] [-i] [-o OUT] [-n] [IMAGE]\n"), 2;
   bake = i < argc ? argv[i] : "";
   if (*bake && (bake_out || bare))                 // a named IMAGE is a plain image file, never a binary
    return fprintf(stderr, "love: bake: IMAGE writes an image; -o and -n write a binary\n"), 2;
   if (in_place && bake_out)                        // one says this binary, the other a copy
    return fprintf(stderr, "love: bake: -i and -o name different targets\n"), 2;
   skip = (i < argc ? i + 1 : i) - 1; }
  else
#endif
  if (argc >= 3 && !strcmp(argv[1], "wake"))
   image_load_path = argv[2], skip = 2;
  else if (argc == 2 && !strcmp(argv[1], "wake"))
   return fprintf(stderr, "love: wake needs an image path\n"), 2;
  // a named image that will not wake is an error, never an egg boot in its place
  int why = 0;
  if (image_load_path && !(g = image_load(image_load_path, &why))) {
   static char const *const says[] = { "torn", "another format, arch or word", "baked by a binary whose tables differ",
                                       "baked from other C", "damaged: its digest does not match" };
   return access(image_load_path, R_OK)
    ? (fprintf(stderr, "love: wake: %s: cannot open\n", image_load_path), 1)
    : (fprintf(stderr, "love: wake: %s: not an image this binary can wake (%s)\n", image_load_path, says[why]), 2); }
  char const *noimg = getenv("LOVE_NO_IMAGE");
  uintptr_t woke_ms = 0;                       // what the wake cost, for `born` below
  if (!g && !bake && !(noimg && *noimg)) {
   uintptr_t t0 = love_clock(), blen = 0;
   void const *bimg = NULL;
   if (baked_pick(&bimg, &blen) && (g = love_image_load(bimg, blen, 2)))
    woke_ms = love_clock() - t0,
    image_load_path = "<baked>"; }                                     // the booted state: no egg warm
#ifndef Love0
  if (!g && !bake && !(noimg && *noimg)) self_bake(argv);
#endif
  bool woke = g != NULL;
  if (!g) g = ini();
  // -n saves no heap, so it skips the warm: it works for a binary whose corpus will not boot
  if (bare) {
    int rc = image_bake(g, bake_out, 1);
    if (rc) fprintf(stderr, "love: bake failed (rc=%d)\n", rc);
    exit(rc ? 1 : 0); }
  g = env_budget(g);                               // on whichever g won
  bool argp = argc - skip > 1;
  if (!bake) g = argv_chain(g, argv, argc, skip);   // the line past the primes -- sp[0]
  if (ok(g)) {
    if (!woke) g = defn(g, __start_love_nifs, __stop_love_nifs - __start_love_nifs);   // a woken book has them, mopped
    if (!bake) {
      g = defv(g, "cmdline");
      if (ok(g)) g->sp++; }
    if (image_load_path && ok(g = defv(strof(g, image_load_path), "love-image"))) g->sp++;
    if (!bake) {
      char const *osn =
#if defined(__moonlibc__)
        __love_osv  < 0 ? "inle" :
        __love_osv == 1 ? (on_inle() ? "inle" : "linux") : __love_osv == 2 ? "freebsd" : __love_osv == 3 ? "netbsd"
        : __love_osv == 4 ? "macos" : 0;
#elif defined(__linux__)
        "linux";
#elif defined(__FreeBSD__)
        "freebsd";
#elif defined(__NetBSD__)
        "netbsd";
#elif defined(__APPLE__)
        "macos";
#else
        0;
#endif
      if (osn && ok(g = intern(strof(g, osn)))) {
        g = defv(g, "love-os");
        if (ok(g)) g->sp++; }
      if (ok(g = boot_env(g))) g->sp++; }
    if (image_load_path && ok(g = push(g, 1, putcharm((intptr_t) woke_ms)))) {
      g = defv(g, "born");
      if (ok(g)) g->sp++; }
    if (!bake) g = stdin_take(g);
    g = image_load_path ? run_program(g, !argp && isatty(STDIN_FILENO))
                        : boot(g, argp, bake, bake_load, bake_out); }
  if (code_of(g) == status_scare) scare_face(g);
  // the status is cli-line's charm at sp[0]; a scare answers 1 through fin
  int rc = (image_load_path || argp) && ok(g) && charmp(g->sp[0])
         ? (int) (getcharm(g->sp[0]) & 255) : 0;
  stdin_give(g);
  enum status s = fin(g);
  return s ? (int) s : rc; }
