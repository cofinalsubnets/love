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
#include <stddef.h>      // offsetof (the struct ai_wait_fd / struct pollfd assert)
#if defined(LvNolibc)
#endif
#include <stdnoreturn.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/mman.h>    // the carried source's inflate buffer (mmap, no malloc)

// ai_clock lives in i/posix.c, one body for this frontend and the kernel's.
// the fine clock's real source (the weak default in love.c degrades to ms*1e6)
ai_noinline intptr_t ai_nclock(void) {
 struct timespec ts;
 return clock_gettime(CLOCK_MONOTONIC, &ts) ? -1
  : (intptr_t) ts.tv_sec * 1000000000 + ts.tv_nsec; }


static void stdin_give(struct ai *g) {
 if (!g || !ai_ok(g)) return;
 struct ai *fc = ai_core_of(g);
 if (fc->inflag)                                          // its blocking bit was ours: back it goes
  fcntl(STDIN_FILENO, F_SETFL, (int) getcharm(fc->inflag)), fc->inflag = 0;
 if (!fc->inport || lseek(STDIN_FILENO, 0, SEEK_CUR) < 0) return;   // an unseekable door: stdin_hand's
 uintptr_t n = ai_io_pending(g, (struct ai_io*) fc->inport)
             + (getcharm(ai_stdin.io.ungetc_buf) != EOF ? 1 : 0);
 if (n) lseek(STDIN_FILENO, -(off_t) n, SEEK_CUR); }

static struct ai *stdin_take(struct ai *g) {
 if (!ai_ok(g)) return g;
 if (lseek(STDIN_FILENO, 0, SEEK_CUR) < 0) {              // not seekable: a tty, or a pipe
  if (isatty(STDIN_FILENO)) return g;
  int fl = fcntl(STDIN_FILENO, F_GETFL);                  // a pipe: take the bit and the bytes
  if (fl >= 0 && ((fl & O_NONBLOCK) || fcntl(STDIN_FILENO, F_SETFL, fl | O_NONBLOCK) >= 0))
   ai_core_of(g)->inflag = putcharm(fl); }                // already-nonblocking restores to itself
 if (!ai_ok(g = ai_io_alloc(g, STDIN_FILENO))) return g;
 struct ai *fc = ai_core_of(g);
 fc->inport = fc->sp[0], fc->sp++;
 return g; }

_lvm(k_lvm_quit);
_lvm(k_lvm_getpid);

static lvm(lvm_exit) {
 if (__ai_osv < 0) ai_musttail return Ap(k_lvm_quit, g);
 for (;;) stdin_give(g), exit(getcharm(Sp[0])); }

                                                                          //
static void stdin_hand(struct ai *g) {
 stdin_give(g);
 if (!g || !ai_ok(g)) return;
 struct ai *fc = ai_core_of(g);
 if (!fc->inport || lseek(STDIN_FILENO, 0, SEEK_CUR) >= 0) return;   // seekable: the seek said it all
 unsigned char res[ai_iobuf + 1];
 uintptr_t n = 0;
 if (getcharm(ai_stdin.io.ungetc_buf) != EOF)
  res[n++] = (unsigned char) getcharm(ai_stdin.io.ungetc_buf),
  ai_stdin.io.ungetc_buf = putcharm(EOF);
 n += ai_io_read_drain(g, (struct ai_io*) fc->inport, res + n, sizeof res - n);
 if (!n) return;                                                    // nothing owed: the fd is already exact
 int p[2];
 if (pipe(p)) return;
 pid_t pid = fork();
 if (pid < 0) return close(p[0]), (void) close(p[1]);
 if (!pid) {                                                        // the pumper: residue, then the rest
  close(p[0]);
  if (ai_fd_write_all(p[1], res, n) == n)
   for (;;) {
    unsigned char buf[ai_iobuf];
    ssize_t k = read(STDIN_FILENO, buf, sizeof buf);
    if (k < 0 && errno == EINTR) continue;                          // a signal is not an end
    if (k <= 0 || ai_fd_write_all(p[1], buf, (uintptr_t) k) < (uintptr_t) k) break; }
  _exit(0); }                                                       // _exit: no atexit, no flush, no love
 close(p[1]);
 if (p[0] != STDIN_FILENO) dup2(p[0], STDIN_FILENO), close(p[0]); }

static void host_teeout(char const *p, size_t n) {
 while (n) {
  ssize_t w = write(STDOUT_FILENO, p, n);
  if (w < 0) { if (errno == EINTR) continue; return; }
  p += w, n -= (size_t) w; } }

static struct ai *host_harkst(struct ai *g, intptr_t fd, intptr_t pid, int tee) {
 g = ai_push(g, 3, putcharm(0), putcharm(fd), putcharm(pid));
 if (ai_ok(g)) g->sp[3] = putcharm(tee);
 return g; }

// the first ap: marshal argv, fork, and confirm the exec. called with g Packed;
// argv is at sp[0]. returns a not-ok g only on oom.
ai_noinline static struct ai *host_harkstart(struct ai *g, int tee) {
 char **cav;
 g = ai_argv_marshal(g, &cav);
 if (!cav) {                                              // a misuse, or the reserve
  if (!ai_ok(g)) return g;
  g = host_harkst(g, -1, 0, tee);                         // then the nom: harkst's push can collect
  return ai_push(g, 1, ai_badarg(g)); }

 int op[2], ep[2];
 // errno into a local before every state push: the push may collect, and a collection
 // that grows the pool makes syscalls of its own.
 if (pipe(op)) { int e = errno;
  g = host_harkst(g, -1, 0, tee);
  return ai_push(g, 1, ai_err(g, e)); }
 if (pipe(ep)) { int e = errno; close(op[0]); close(op[1]);
  g = host_harkst(g, -1, 0, tee);
  return ai_push(g, 1, ai_err(g, e)); }
 fcntl(ep[1], F_SETFD, FD_CLOEXEC);
 fflush(stdout);
 pid_t pid = fork();
 if (pid < 0) { int e = errno;
  close(op[0]); close(op[1]); close(ep[0]); close(ep[1]);
  g = host_harkst(g, -1, 0, tee);
  return ai_push(g, 1, ai_err(g, e)); }
 if (!pid) {                                              // child
  signal(SIGPIPE, SIG_DFL);                               // the ignore must not ride the exec
  dup2(op[1], STDOUT_FILENO);
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
  g = host_harkst(g, -1, 0, tee);
  return ai_push(g, 1, ai_err(g, childerr)); }

 int fl = fcntl(op[0], F_GETFL);
 if (fl >= 0) fcntl(op[0], F_SETFL, fl | O_NONBLOCK);
 return str0(host_harkst(g, op[0], pid, tee), 1u << 16); }  // capture -> sp[0]

ai_noinline static struct ai *host_harkdrain(struct ai *g) {
 intptr_t fd = getcharm(g->sp[2]);
 if (fd == -1) return g;                        // nothing was spawned: sp[0] is the answer
 pid_t pid = (pid_t) getcharm(g->sp[3]);
 if (fd >= 0) {
  int tee = getcharm(g->sp[4]) != 0;
  uintptr_t n = (uintptr_t) getcharm(g->sp[1]);
  for (;;) {
   uintptr_t lim = len(g->sp[0]);
   if (n == lim) {                                        // full -> double it and retry
    if (ai_ok(g = grbufg(g, lim))) continue;
    // oom mid-capture: close the pipe and kill the child rather than wait on it
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
   break; }                                               // EOF, or a read error we cannot use
  close((int) fd);
  g->sp[2] = putcharm(-2); }                              // drained; now reap
                                                          //
 int st; pid_t w;
 do w = waitpid(pid, &st, WNOHANG); while (w < 0 && errno == EINTR);
 if (!w) { g->next_wake_at = ai_clock() + 1; return g; }
 uintptr_t n = (uintptr_t) getcharm(g->sp[1]);
 if (n) len(g->sp[0]) = n;                              // fix logical length
 else g->sp[0] = EmptyString;                           // empty output -> the singleton
 int status = w < 0 ? -1
            : WIFEXITED(st) ? WEXITSTATUS(st)
            : WIFSIGNALED(st) ? 128 + WTERMSIG(st) : -1;
 if (!ai_ok(g = ai_have(g, Width(struct ai_chain)))) return g;
 struct ai_chain *c = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                putcharm(status), g->sp[0]);
 g->sp[0] = word(c);
 g->sp[2] = putcharm(-1);                             // done
 return g; }

static lvm(lvm_hark) {
 LvmCall(g, host_harkstart, 0) }

// (herald argv) -- hark, teeing: identical to (hark argv), same (status . output)
// answer, but the child's stdout is relayed as it arrives instead of only at
// exit. for a caller that just reprints what it captured; see the `tee` note above.
static lvm(lvm_herald) {
 LvmCall(g, host_harkstart, 1) }

// the shared second ap. it parks -- Ip unadvanced, so the whole op re-runs on
// reschedule and reads its state back off the stack.
static lvm(lvm_harkdrain) {
 Pack(g);
 g = host_harkdrain(g);
 if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g);
 Unpack(g);
 if (Sp[2] != putcharm(-1)) ai_musttail return Ap(lvm_yield_sw, g);
 Sp[4] = Sp[0];                                           // the answer over the state
 Sp += 4; Ip += 1;
 ai_musttail return Continue(); }

ai_noinline static struct ai *host_exec(struct ai *g) {
 char **cav;
 g = ai_argv_marshal(g, &cav);
 if (!cav) return ai_ok(g) ? ai_push(g, 1, ai_badarg(g)) : g;
 fflush(stdout);
 fflush(stderr);
 signal(SIGPIPE, SIG_DFL);                                 // ... nor this one
 stdin_hand(g);                                            // the child inherits fd 0: hand it over exact
 execvp(cav[0], cav);
 return ai_push(g, 1, ai_err(g, errno)); }                  // exec failed -> its nom

static lvm(lvm_exec) {
 LvmCallp(g, 1, host_exec) }   // returns only on failure; the errno nom over argv

// (getenv name) -> string, or zero if unset / misused. zero = absent, not an error.
// the name goes to getenv where it lies: a love string's bytes[len] is always a NUL.
static lvm(lvm_getenv) {
 char const *v = strp(Sp[0]) ? getenv(txt(Sp[0])) : NULL;
 if (!v) { Sp[0] = ZeroPoint; ai_musttail return Next(1); }
 LvmCallp(g, 1, ai_strof, v) }

static lvm(lvm_getpid) {
  if (__ai_osv < 0) ai_musttail return Ap(k_lvm_getpid, g);
  ai_musttail return Answer(putcharm(getpid())); }

static union u const
 nif_exit[] = {{lvm_exit}, {lvm_ret0}},
 nif_hark[] = {{lvm_hark}, {lvm_harkdrain}, {lvm_ret0}},
 nif_herald[] = {{lvm_herald}, {lvm_harkdrain}, {lvm_ret0}},
 nif_exec[] = {{lvm_exec}, {lvm_ret0}},
 nif_getenv[] = {{lvm_getenv}, {lvm_ret0}},
 nif_getpid[] = {{lvm_getpid}, {lvm_ret0}};
LvNif("quit", nif_exit, NULL);
LvNif("hark", nif_hark, NULL);
LvNif("herald", nif_herald, NULL);
LvNif("exec", nif_exec, NULL);
LvNif("getenv", nif_getenv, NULL);
LvNif("getpid", nif_getpid, NULL);

static struct ai *env_budget(struct ai *g) {
  char const *b = getenv("LOVE_BUDGET_MB");
  if (g && b && atol(b) > 0) {
    g->budget = (uintptr_t) atol(b) * (1024 * 1024 / sizeof(word));
    return g; }
  if (g && !g->budget) {
    int fd = open("/proc/meminfo", O_RDONLY);
    if (fd >= 0) { char mb[64]; long n = (long) read(fd, mb, sizeof mb - 1);
      close(fd);
      if (n > 8 && !memcmp(mb, "MemTotal", 8)) { mb[n] = 0;
        char *p = mb; while (*p && (*p < '0' || *p > '9')) p++;
        uintptr_t kb = 0; while (*p >= '0' && *p <= '9') kb = kb * 10 + (uintptr_t)(*p++ - '0');
        g->budget = kb * 1024 / 2 / sizeof(word); } } }
  return g; }

// LOVE_NO_GLAZE: a pure-interpreter session -- ev back to base-ev and the natjit hook
// cleared. a session knob like LOVE_NO_IMAGE: it governs a run, never the artifact.
#ifdef LvGlazed
static char const glaze_off[] = "(: ev (cite 'glaze 'base-ev) natjit ())";
#else
static char const glaze_off[] = "";
#endif

// the session layer: boot is over and the base is never the head again, so a top-level
// definition lands here. never popped -- its lifetime is the session, which is what lets a
// catted app's files share one vocabulary; the egg boot and the image wake both converge.
// l/boot/post.l's `cli-line` is this tail entire, spliced with its module: the argv[0] verb
// door, the positional rail, the repl, the stdin drink. the isatty answer is all C still owns.
// both seats run this one: love0 is never interactive and never glazed, so replp is false
// and glaze_off is the empty text there -- the seat shows in the ANSWERS, not in a fork.
// the tty is one terminal, so its cooked baseline and its atexit live in posix.c, which the
// (raw on) nif drives; the capture-once latch there is what makes a repl that raws after
// bao already did restore the true baseline rather than a raw one.
static struct ai *run_program(struct ai *g, bool replp) {
  if (replp) (void) ai_raw_mode(1);
  g = ai_open_(g);
  if (getenv("LOVE_NO_GLAZE")) g = ai_evals_(g, glaze_off);
  return ai_evals(g, replp ? "(cli-line cmdline 1)" : "(cli-line cmdline 0)"); }

#ifdef Love0
// love0's seat is its own translation unit: i/boot.c, linked only into love0.
struct ai *boot(struct ai *g, bool argp, char const *bake, char const *bake_load, char const *bake_out);
#else
#ifdef LvBakeSrc
#include "ustar.h"
static char const src_distlist[] =
#include "distlist.h"
 ;

// inflate the carried blob (gzip: skip the header fields, ISIZE names the tar)
static unsigned char *bsrc_untar(uintptr_t *outn) {
  uintptr_t o = 0, un = 0;
  if (!ai_gz_body(ai_srcgz, ai_srcgz_len, &o, &un)) return NULL;
  unsigned char *t = mmap(NULL, un ? un : 1, PROT_READ | PROT_WRITE,
                          MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (t == MAP_FAILED) return NULL;
  if (ai_inflate_raw(ai_srcgz + o, ai_srcgz_len - o - 8, t, un) != (intptr_t) un)
    return munmap(t, un), NULL;
  return *outn = un, t; }

// find a tree-relative path in the ustar block. the archive's paths carry a top component,
// so match past it; a symlink member chases its target against its own directory.
static unsigned char const *bsrc_find(unsigned char const *t, uintptr_t n,
                                    char const *path, uintptr_t *len, int hop) {
  uintptr_t pl = strlen(path);
  if (hop > 3 || !pl) return NULL;
  for (uintptr_t o = 0; o + 512 <= n && t[o];) {
    unsigned char const *h = t + o;
    uintptr_t sz = ai_ustar_octal(h + 124, 12);
    if (ai_ustar_member(h)) {
      char nm[256];
      uintptr_t ln = ai_ustar_name(h, nm, sizeof nm);
      if (ln == pl && !memcmp(nm, path, pl)) {
        if (!ai_ustar_islink(h)) return *len = sz, t + o + 512;
        char tgt[101], cn[256];
        tgt[ai_ustar_link(h, tgt, sizeof tgt - 1)] = 0;
        cn[ai_lnk_canon(path, tgt, cn, sizeof cn - 1)] = 0;
        return bsrc_find(t, n, cn, len, hop + 1); } }
    o += 512 + ((sz + 511) & ~(uintptr_t) 511); }
  return NULL; }

// lay the roster cat from the carried source, beside `at`: the crew a binary bakes when
// no -l names one, which is how a raw love emits its baked state with no tree to hand.
// 1 laid, 0 refused -- no blob aboard, nowhere to write, or a roster name the archive
// does not carry. per-process, for the reason the bake's scratch is (i/image.c).
static int bsrc_lay_cat(char *cat, size_t n, char const *at) {
  char exe[4096];                                    // the kernel's own PATH_MAX, not a cap of ours
  if (ai_srcgz_len < 18) return 0;                   // i/noblob.c's zero: this link carries no source
  if (!at && !(at = host_selfpath(exe, sizeof exe) ? exe : NULL)) return 0;
  uintptr_t un = 0;
  unsigned char *t = bsrc_untar(&un);
  if (!t) return fprintf(stderr, "love: bake: the carried source will not inflate\n"), 0;
  snprintf(cat, n, "%s.bakecat.%ld.l", at, (long) getpid());
  int fd = open(cat, O_WRONLY | O_CREAT | O_TRUNC, 0600);
  if (fd < 0) {                                      // a read-only seat -- /usr/bin, a container layer
    fprintf(stderr, "love: bake: %s is not writable\n", cat);
    return munmap(t, un), 0; }
  for (char const *p = src_distlist; *p;) {
    while (*p == ' ' || *p == '\n') p++;
    char w[256]; size_t wl = 0;
    while (*p && *p != ' ' && *p != '\n' && wl < 255) w[wl++] = *p++;
    if (!wl) break;
    w[wl] = 0;
    uintptr_t ml = 0;
    unsigned char const *m = bsrc_find(t, un, w, &ml, 0);
    // a roster name the archive does not carry (a stale distlist), or a full filesystem
    if (!m || (ml && write(fd, m, ml) != (ssize_t) ml)) {
      fprintf(stderr, "love: bake: %s %s\n", w,
              m ? "would not write" : "is not in the carried source");
      close(fd), unlink(cat), munmap(t, un);
      return 0; } }
  return close(fd), munmap(t, un), 1; }
#else
#define bsrc_lay_cat(cat, n, at) 0
#endif

// read-eval one .l file into the booting session, loudly: a bake's cat has no shell help,
// so a raise in it must end the bake rather than seal a half-built artifact.
// the path is a value, never spliced into the source, so the text stays data whatever it
// holds. q is closed, or its finalizer would still be reachable at the seal and carry an
// fd into the image; and the name is rebound to () rather than pulled, since the seal has
// already dropped the book. either way the name must stop holding the path, or an absolute
// one bakes the baker's directory in.
static struct ai *bake_eval_file(struct ai *g, char const *path) {
  uintptr_t xn = strlen(path);
  if (!ai_ok(g = str0(g, xn))) return g;
  if (xn) memcpy(txt(g->sp[0]), path, xn);
  g = ai_defv(g, "bake-load");
  if (!ai_ok(g)) return g;
  ai_core_of(g)->sp++;
  g = ai_evals_(g,
    "(: open (cite 'posix 'open) close (cite 'posix 'close)"    // the fs doors are a module's
    "   q (open bake-load \"r\")"
    " (? q (: _ (reads q) (close q))"
    "      (: _ (say err (\"love: bake: cannot open \" + bake-load)) _ (put err 10) (quit 1))))");
  return ai_ok(g) ? ai_evals_(g, "(: bake-load ())") : g; }

// FIXME waaaaaaaaaaaaaaaaaaaaay too much code in string literals
static struct ai *boot(struct ai *g, bool argp, char const *bake, char const *bake_load,
                       char const *bake_out) {
  // leave the internal names in global scope too. only an unbaked boot reaches this; the
  // `guts` module egg.l registers is how a baked one gets at them (cite 'guts 'peek).
  char const *nm = getenv("LOVE_NO_MOP");
  if (nm && *nm) g = ai_evals_(g, "(: nomop 1)");
  g = ai_cats_egg(g);                                    // prel then ev's half, and the printer with `@`
  g = ai_cats_lib(g);                                   // register every baked module; the uses below are splices
  g = ai_evals_(g,
    "(borrow 'kanren)"
    "(borrow 'overlay)"
    "(: overlay (cite 'overlay)"
    "   ev ((cite 'overlay 'ov-hook) ev))"
    "(borrow 'uu)"
    "(: uu (cite 'uu))"
    "(borrow 'holo)"
  );
  g = ai_shelve_(g);
  g = ai_evals_(g, "(borrow 'cli)(borrow 'verbs)");
  g = ai_shelve_(g);
  // kanren, overlay and uu come off: the latter two already have their accessor bound
  // above, so the splice bought only ambient names -- `C`, `Q`, `src`, `glob`, `walk`,
  // `var`, `con`, `est` are what this tree calls its locals. kanren keeps a named surface.
  // unsplice drops one link at a time, so bao comes off with them and goes straight back
  // on: read/reads for cli, `@` for every later compile.
  for (int i = 0; i < 4; i++) g = ai_shelve_(g);       // bao, uu, overlay, kanren
  // FIXME what is this even doing? we just used bao a couple of lines ago? what is "hoist"?
  g = ai_evals_(g, "(borrow 'cli)"
    "(transcribe 'kanren ())"                                 // \\\, &&&, |||, zz -- macros, not names
    "(: unify (cite 'kanren 'unify)  ufail (cite 'kanren 'ufail)"
    "   ufail? (cite 'kanren 'ufail?)  var (cite 'kanren 'var)"
    "   s_plus (cite 'kanren 's_plus)  s_star (cite 'kanren 's_star)"
    "   === (cite 'kanren '===)  =/= (cite 'kanren '=/=))");
  g = ai_cats_glaze(g);                                     // a no-op on an unglazed arch
#ifdef LvGlazed
  g = ai_shelve_(g);                                   // holo back to non-ambient
#endif

  g = ai_evals_(g,
    "(: spawn0 spawn  spawnio0 spawnio  spawnmap0 spawnmap  wait0 wait"
    "   seat-doors (: t (tablet 4) _ (pin t 0 spawn0) _ (pin t 1 spawnio0)"
    "                 _ (pin t 2 spawnmap0) _ (pin t 3 wait0) t)"
    "   (spawn argv) (peep seat-doors 0 0 argv)"
    "   (spawnio argv i o e cl pg fg) (peep seat-doors 1 0 argv i o e cl pg fg)"
    "   (spawnmap argv fdm cl pg fg) (peep seat-doors 2 0 argv fdm cl pg fg)"
    "   (wait p) (peep seat-doors 3 0 p))");

  // FIXME why are we pulling from book here, that's what mop is for
  g = ai_evals_(g, bake
    ? "(: _ (pull book 'nif 0) _ (pull book 'nifx 0) _ (pull book 'born 0) (pull book 'book 0))"
    : "(: _ (pull book 'nif 0) _ (pull book 'nifx 0) (pull book 'book 0))");

  if (bake) {                                            // the bake verb: snapshot the post-warm heap, then exit
    // a bake egg-boots whatever this binary carries, so the crew is never aboard here.
    // -l names it; with nothing named the carried source is the roster, which is the
    // raw -> baked direction of the verb (`love bake -n` is the other).
    char cat[4096 + 40];                               // a path, and ".bakecat.<pid>.l"
    if (!bake_load && bsrc_lay_cat(cat, sizeof cat, bake_out)) bake_load = cat;
    if (bake_load) {
      int ok = ai_ok(g = bake_eval_file(g, bake_load));
      if (bake_load == cat) unlink(cat);
      if (!ok) return g; }
    int rc = *bake ? (int) ai_core_of(g = image_dump(g, bake))->b : image_bake(g, bake_out, 0);
    if (rc) fprintf(stderr, "love: bake failed (rc=%d)\n", rc);
    exit(rc ? 1 : 0); }
  return run_program(g, !argp && isatty(STDIN_FILENO)); }
#endif

ai_noinline static struct ai *argv_chain(struct ai *g, char const **v, int argc, int skip) {
  int n = 0;
  if (argc > 0) g = ai_strof(g, v[0]), n++;                  // argv[0] is always the program
  for (int i = 1 + skip; i < argc; i++) g = ai_strof(g, v[i]), n++;
  for (g = ai_push(g, 1, ZeroPoint); n--; g = gxr(g));   // () terminates, as a love list does
  return g; }


// a __builtin_trap guard fired: `ud2` / `brk #0` / `ebreak`, so it lands here as
// SIGILL (SIGTRAP on the arm and riscv seats) with si_addr at the instruction.
// the kernel's k_exception prints this same line; hosted had only a bare 132.
// it names the SIGNAL and not the cause: a jump into data raises SIGILL too, and
// an address called a trap sends a reader hunting a guard that is not there --
// where it really was one, the address says so.
// write and raise only -- a handler may call nothing the VM or malloc owns, so
// the address is spelled by hand. it does not resume: the default disposition
// goes back on and the signal is re-raised, so the exit status and the core stay
// what they were.
static void trap_note(int s, siginfo_t *si, void *ctx) {
  char b[48], *p = b;
  for (char const *m = s == SIGTRAP ? "*** love: SIGTRAP at 0x"
                                    : "*** love: SIGILL at 0x"; *m; m++) *p++ = *m;
  uintptr_t a = si ? (uintptr_t) si->si_addr : 0;
  int seen = 0;
  for (int i = (int) sizeof a * 8 - 4; i >= 0; i -= 4) {
    unsigned d = (unsigned) (a >> i) & 15;
    if (d || seen || !i) *p++ = "0123456789abcdef"[d], seen = 1; }
  *p++ = '\n';
  (void) ctx;
  (void) write(2, b, (size_t) (p - b));
  signal(s, SIG_DFL);
  raise(s); }

// SIGTRAP only where the trap instruction raises it -- on x86 it is the
// debugger's, and naming a breakpoint "love: trap" would be a lie.
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

int main(int argc, char const **argv) {
  signal(SIGPIPE, SIG_IGN);
  trap_note_on();
  struct ai *g = NULL;
  char const *image_load_path = NULL, *bake = NULL,   // see boot(): "" = self-bake, a path = an image file
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
  // a leading wake with nothing to wake. the arity error is C's because the parse is:
  // the registry's row would complain about the one thing this invocation got right.
  else if (argc == 2 && !strcmp(argv[1], "wake"))
   return fprintf(stderr, "love: wake needs an image path\n"), 2;
  if (image_load_path && !(g = image_load(image_load_path))) image_load_path = NULL;   // NULL -> normal boot
  char const *noimg = getenv("LOVE_NO_IMAGE");
  uintptr_t woke_ms = 0;                       // what the wake cost, for `born` below
  if (!g && !bake && !(noimg && *noimg)) {
   uintptr_t t0 = ai_clock(), blen = 0;
   void const *bimg = NULL;
   if (ai_baked_pick(&bimg, &blen) && (g = ai_image_load(bimg, blen)))
    woke_ms = ai_clock() - t0,
    image_load_path = "<baked>"; }                                     // a loaded image is the booted state: skip the egg warm
  if (!g) g = ai_ini();
  // -n lays the stub back and saves no heap, so it skips the warm outright: the strip is
  // instant, and it answers for a binary whose own corpus would not boot.
  if (bare) {
    int rc = image_bake(g, bake_out, 1);
    if (rc) fprintf(stderr, "love: bake failed (rc=%d)\n", rc);
    exit(rc ? 1 : 0); }
  g = env_budget(g);                               // the LOVE_BUDGET_MB cap, on whichever g won (fresh or woken image)
  bool argp = argc - skip > 1;
  if (!bake) g = argv_chain(g, argv, argc, skip);   // the line past the primes -- sp[0]
  if (ai_ok(g)) {
    g = ai_defn(g, __start_love_nifs, __stop_love_nifs - __start_love_nifs);
    if (!bake) {
      g = ai_defv(g, "cmdline");
      if (ai_ok(g)) g->sp++; }          // the book holds it now
    if (image_load_path && ai_ok(g = ai_defv(ai_strof(g, image_load_path), "love-image"))) g->sp++;
    if (!bake) {
      char const *osn =
#if defined(LvNolibc)
        __ai_osv  < 0 ? "inle" :
        __ai_osv == 1 ? "linux" : __ai_osv == 2 ? "freebsd" : __ai_osv == 3 ? "netbsd" : 0;
#elif defined(__linux__)
        "linux";
#elif defined(__FreeBSD__)
        "freebsd";
#elif defined(__NetBSD__)
        "netbsd";
#else
        0;
#endif
      if (osn && ai_ok(g = intern(ai_strof(g, osn)))) {
        g = ai_defv(g, "love-os");
        if (ai_ok(g)) ai_core_of(g)->sp++; } }
    if (image_load_path && ai_ok(g = ai_push(g, 1, putcharm((intptr_t) woke_ms)))) {
      g = ai_defv(g, "born");
      if (ai_ok(g)) ai_core_of(g)->sp++; }
    if (!bake) g = stdin_take(g);
    // an egg warm, or a woken image straight to the program -- the wake skips the warm
    g = image_load_path ? run_program(g, !argp && isatty(STDIN_FILENO))
                        : boot(g, argp, bake, bake_load, bake_out); }
  if (ai_code_of(g) == ai_status_scare) ai_scare_face_(g);
  // the program's status is cli-line's answer, a charm, left at sp[0] by ai_evals: the
  // process answers with it. a scare answers 1 through ai_fin, ahead of it.
  int rc = (image_load_path || argp) && ai_ok(g) && charmp(ai_core_of(g)->sp[0])
         ? (int) (getcharm(ai_core_of(g)->sp[0]) & 255) : 0;
  stdin_give(g);
  enum ai_status s = ai_fin(g);
  return s ? (int) s : rc; }
