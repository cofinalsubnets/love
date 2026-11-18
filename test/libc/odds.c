/* the odds and ends a port reaches for: the flagged fd calls, the *at family, the exits,
 * random bytes, raw syscall, the process helpers, clock_nanosleep, the signal helpers, ttyname,
 * the string kin, and the thread set (attributes, detach, kill, sigmask, atfork, names,
 * barriers, spinlocks). each answer is a flag, a sign or a count, never an address or a pid */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <sched.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/auxv.h>
#include <sys/file.h>
#include <sys/random.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include "say.h"

#if defined(__x86_64__)
# define NRgetpid 39
#elif defined(__aarch64__) || defined(__riscv)
# define NRgetpid 172
#else
# define NRgetpid 20
#endif

static int cloexec(int fd) { return (fcntl(fd, F_GETFD) & FD_CLOEXEC) != 0; }
static int nonblock(int fd) { return (fcntl(fd, F_GETFL) & O_NONBLOCK) != 0; }
static int status(int pid) { int s = 0; waitpid(pid, &s, 0); return WIFEXITED(s) ? WEXITSTATUS(s) : 100 + WTERMSIG(s); }
static int sgn(int v) { return (v > 0) - (v < 0); }

static void strs(void) {
  char b[16];
  say_n("stpcpy", stpcpy(b, "abc") - b);
  memset(b, 'x', sizeof b);
  char *e = stpncpy(b, "ab", 5);
  say_n("stpncpy", e - b); say_n("stpncpy.pad", b[2] == 0 && b[4] == 0 && b[5] == 'x');
  say_n("stpncpy.full", stpncpy(b, "abcdef", 3) - b);
  char const *m = "abcabc";
  say_n("memrchr", (char const *) memrchr(m, 'b', 6) - m); say_n("memrchr.none", memrchr(m, 'z', 6) == 0);
  explicit_bzero(b, sizeof b); say_n("explicit_bzero", b[0] == 0 && b[15] == 0);
  char const *v[][2] = { {"a1", "a2"}, {"a9", "a10"}, {"a01", "a1"}, {"a00", "a0"}, {"1.10", "1.9"},
                         {"000", "00"}, {"a", "a"}, {"item#99", "item#100"}, {"0.9", "0.10"}, {"x", ""} };
  for (int i = 0; i < 10; i++) say_n("strverscmp", sgn(strverscmp(v[i][0], v[i][1]))); }

static void fds(char const *dir) {
  int p[2];
  say_n("pipe2", pipe2(p, O_CLOEXEC | O_NONBLOCK) == 0 && cloexec(p[0]) && cloexec(p[1]) && nonblock(p[0]));
  int q = dup3(p[0], 30, O_CLOEXEC);
  say_n("dup3", q == 30 && cloexec(30)); close(30);
  errno = 0; say_n("dup3.same", dup3(p[0], p[0], 0) < 0 && errno == EINVAL);
  close(p[0]), close(p[1]);
  char f[256];
  snprintf(f, sizeof f, "%s/lock", dir);
  int a = open(f, O_RDWR | O_CREAT, 0644), b = open(f, O_RDWR);
  say_n("flock", flock(a, LOCK_EX) == 0);
  errno = 0; say_n("flock.busy", flock(b, LOCK_EX | LOCK_NB) < 0 && errno == EWOULDBLOCK);
  say_n("flock.un", flock(a, LOCK_UN) == 0 && flock(b, LOCK_EX | LOCK_NB) == 0);
  flock(b, LOCK_UN);
  say_n("lockf", lockf(a, F_LOCK, 0) == 0 && lockf(a, F_TEST, 0) == 0);
  int k = fork();
  if (!k) {
    int c = open(f, O_RDWR);
    int t = lockf(c, F_TLOCK, 0) < 0 && (errno == EAGAIN || errno == EACCES);
    errno = 0;
    int u = lockf(c, F_TEST, 0) < 0 && errno == EACCES;
    _exit(t + 2 * u); }
  say_n("lockf.other", status(k));
  lockf(a, F_ULOCK, 0); close(a), close(b);
  /* accept4 off a unix listener */
  struct sockaddr_un sa = { AF_UNIX };
  snprintf(sa.sun_path, sizeof sa.sun_path, "%s/sock", dir);
  int l = socket(AF_UNIX, SOCK_STREAM, 0);
  bind(l, (struct sockaddr *) &sa, sizeof sa); listen(l, 1);
  int c = socket(AF_UNIX, SOCK_STREAM, 0);
  connect(c, (struct sockaddr *) &sa, sizeof sa);
  int s = accept4(l, 0, 0, SOCK_CLOEXEC | SOCK_NONBLOCK);
  say_n("accept4", s >= 0 && cloexec(s) && nonblock(s));
  close(s), close(c), close(l); }

static void ats(char const *dir) {
  int d = open(dir, O_RDONLY | O_DIRECTORY);
  struct stat st;
  say_n("mkdirat", mkdirat(d, "sub", 0755) == 0 && fstatat(d, "sub", &st, 0) == 0 && S_ISDIR(st.st_mode));
  int f = openat(d, "sub/f", O_WRONLY | O_CREAT, 0600); close(f);
  say_n("symlinkat", symlinkat("sub/f", d, "ln") == 0);
  say_n("fstatat.nofollow", fstatat(d, "ln", &st, AT_SYMLINK_NOFOLLOW) == 0 && S_ISLNK(st.st_mode));
  say_n("fstatat.follow", fstatat(d, "ln", &st, 0) == 0 && S_ISREG(st.st_mode));
  say_n("linkat", linkat(d, "sub/f", d, "hard", 0) == 0 && fstatat(d, "hard", &st, 0) == 0 && st.st_nlink == 2);
  say_n("linkat.follow", linkat(d, "ln", d, "hard2", AT_SYMLINK_FOLLOW) == 0 && fstatat(d, "hard2", &st, AT_SYMLINK_NOFOLLOW) == 0 && S_ISREG(st.st_mode));
  say_n("renameat", renameat(d, "hard2", d, "sub/moved") == 0 && faccessat(d, "sub/moved", F_OK, 0) == 0);
  say_n("faccessat", faccessat(d, "sub/f", R_OK | W_OK, AT_EACCESS) == 0);
  say_n("fchmodat", fchmodat(d, "sub/f", 0640, 0) == 0 && fstatat(d, "sub/f", &st, 0) == 0 && (st.st_mode & 0777) == 0640);
  say_n("fchownat", fchownat(d, "ln", (unsigned) -1, (unsigned) -1, AT_SYMLINK_NOFOLLOW) == 0);
  errno = 0; say_n("faccessat.none", faccessat(d, "nope", F_OK, 0) < 0 && errno == ENOENT);
  unlinkat(d, "sub/moved", 0), unlinkat(d, "sub/f", 0), unlinkat(d, "ln", 0), unlinkat(d, "hard", 0);
  say_n("unlinkat.dir", unlinkat(d, "sub", AT_REMOVEDIR) == 0);
  close(d); }

static int qfd = -1;
static void qbye(void) { write(qfd, "q", 1); }
static void bye(void) { write(qfd, "a", 1); }

static void procs(void) {
  int k = fork();
  if (!k) _Exit(9);
  say_n("_Exit", status(k));
  int p[2];
  pipe(p);
  if (!(k = fork())) {
    qfd = p[1];
    at_quick_exit(qbye), atexit(bye);
    quick_exit(4); }
  close(p[1]);
  char b[8] = {0};
  long n = read(p[0], b, sizeof b - 1);
  say_n("quick_exit", status(k)); say_s("quick_exit.ran", n > 0 ? b : "");
  close(p[0]);
  if (!(k = vfork())) _exit(7);
  say_n("vfork", status(k));
  if (!(k = fork())) {
    char *av[] = { "sh", "-c", "exit $X", 0 }, *ev[] = { "X=5", "PATH=/usr/bin:/bin", 0 };
    execvpe("sh", av, ev);
    _exit(99); }
  say_n("execvpe", status(k));
  pipe(p);
  if (!(k = fork())) {
    close(p[0]);
    if (daemon(1, 1) < 0) _exit(1);
    char r = getsid(0) == getpid() ? 'y' : 'n';
    write(p[1], &r, 1);
    _exit(0); }
  close(p[1]);
  char r = 0;
  read(p[0], &r, 1);
  status(k);
  say_n("daemon", r == 'y');
  close(p[0]);
  /* the kernel's own numbers: getpid is 20 on the BSDs; an unknown call is SIGSYS there unless ignored */
  struct utsname u;
  uname(&u);
  long gp = strcmp(u.sysname, "Linux") ? 20 : NRgetpid;
  say_n("syscall", syscall(gp) == getpid());
  signal(SIGSYS, SIG_IGN);
  errno = 0; say_n("syscall.err", syscall(gp + 100000) == -1 && errno == ENOSYS);
  signal(SIGSYS, SIG_DFL);
  say_n("sched_yield", sched_yield());
  unsigned char rb[64] = {0};
  say_n("getrandom", getrandom(rb, sizeof rb, 0));
  int nz = 0; for (int i = 0; i < 64; i++) nz += rb[i] != 0;
  say_n("getrandom.some", nz > 32);
  say_n("getentropy", getentropy(rb, 32));
  errno = 0; say_n("getentropy.big", getentropy(rb, 257) < 0 && errno == EIO);
  say_n("getpagesize", getpagesize() == sysconf(_SC_PAGESIZE) && getauxval(AT_PAGESZ) == (unsigned long) getpagesize()); }

static void sleeps(void) {
  struct timespec t = { 0, 1000000 }, now;
  say_n("clock_nanosleep", clock_nanosleep(CLOCK_MONOTONIC, 0, &t, 0));
  clock_gettime(CLOCK_MONOTONIC, &now);
  now.tv_nsec += 2000000; if (now.tv_nsec >= 1000000000) now.tv_nsec -= 1000000000, now.tv_sec++;
  say_n("clock_nanosleep.abs", clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &now, 0));
  t.tv_sec = 0, t.tv_nsec = 0;
  say_n("clock_nanosleep.past", clock_nanosleep(CLOCK_REALTIME, TIMER_ABSTIME, &t, 0));
  errno = 0;
  t.tv_nsec = 2000000000;
  say_n("clock_nanosleep.bad", clock_nanosleep(CLOCK_MONOTONIC, 0, &t, 0) == EINVAL && errno == 0); }

static volatile int hit;
static void on(int s) { hit = s; }

static void sigs(char const *dir) {
  signal(SIGUSR1, on);
  sigset_t bl, old, none;
  sigemptyset(&bl); sigaddset(&bl, SIGUSR1); sigemptyset(&none);
  sigprocmask(SIG_BLOCK, &bl, &old);
  raise(SIGUSR1);
  say_n("sigsuspend.pending", hit);
  errno = 0;
  int r = sigsuspend(&none);
  say_n("sigsuspend", r == -1 && errno == EINTR && hit == SIGUSR1);
  sigprocmask(SIG_SETMASK, &old, 0);
  say_n("killpg", killpg(getpgrp(), 0));
  errno = 0; say_n("killpg.bad", killpg(-1, 0) < 0 && errno == EINVAL);
  char f[256];
  snprintf(f, sizeof f, "%s/err", dir);
  fflush(stdout);
  int e = dup(2), o = open(f, O_RDWR | O_CREAT | O_TRUNC, 0600);
  dup2(o, 2);
  psignal(SIGINT, "odds"); psignal(SIGTERM, 0);
  dup2(e, 2), close(e);
  char b[64] = {0};
  pread(o, b, sizeof b - 1, 0);
  close(o);
  for (char *c = b; *c; c++) if (*c == '\n') *c = '|';
  say_s("psignal", b); }

static void ttys(void) {
  errno = 0; say_n("ttyname.none", ttyname(-1) == 0 && errno == EBADF);
  int p[2]; pipe(p);
  errno = 0; say_n("ttyname.pipe", ttyname(p[0]) == 0 && errno == ENOTTY);
  close(p[0]), close(p[1]);
  int m = posix_openpt(O_RDWR | O_NOCTTY);
  if (m < 0) { say_s("ttyname", "no pty"); return; }
  grantpt(m), unlockpt(m);
  char sn[64];
  ptsname_r(m, sn, sizeof sn);
  int s = open(sn, O_RDWR | O_NOCTTY);
  char *t = ttyname(s);
  say_n("ttyname", t && strcmp(t, sn) == 0);
  char b[64];
  say_n("ttyname_r", ttyname_r(s, b, sizeof b) == 0 && strcmp(b, sn) == 0);
  say_n("ttyname_r.short", ttyname_r(s, b, 4) == ERANGE);
  close(s), close(m); }

/* -- threads */
static int done;
static void *bump(void *a) { __atomic_add_fetch(&done, 1, __ATOMIC_SEQ_CST); return 0; }
static pthread_barrier_t bar;
static int serial;
static void *meet(void *a) { if (pthread_barrier_wait(&bar) == PTHREAD_BARRIER_SERIAL_THREAD) __atomic_add_fetch(&serial, 1, __ATOMIC_SEQ_CST); return 0; }
static pthread_spinlock_t sp;
static long tally;
static void *spin(void *a) { for (int i = 0; i < 20000; i++) { pthread_spin_lock(&sp); tally++; pthread_spin_unlock(&sp); } return 0; }
static volatile int got, waiting;
static pthread_t gotby;
static void onk(int s) { got = s; gotby = pthread_self(); }
static void *sleeper(void *a) { waiting = 1; while (!got) sched_yield(); return 0; }
static void *named(void *a) { while (!got) sched_yield(); return 0; }
static char afb[8];
static int afn;
static void afp(void) { afb[afn++] = 'p'; }
static void afa(void) { afb[afn++] = 'a'; }
static void afc(void) { afb[afn++] = 'c'; }

static void threads(void) {
  pthread_attr_t at;
  size_t ss = 0;
  int ds = -1;
  pthread_attr_init(&at);
  say_n("attr.stack.min", pthread_attr_setstacksize(&at, PTHREAD_STACK_MIN - 1) == EINVAL);
  pthread_attr_setstacksize(&at, 256 * 1024);
  pthread_attr_getstacksize(&at, &ss);
  say_n("attr.stack", ss == 256 * 1024);
  pthread_attr_setdetachstate(&at, PTHREAD_CREATE_DETACHED);
  pthread_attr_getdetachstate(&at, &ds);
  say_n("attr.detach", ds == PTHREAD_CREATE_DETACHED);
  /* detached threads, created past several generations so their stacks go back */
  for (int r = 0; r < 4; r++)
    for (int i = 0; i < 25; i++) { pthread_t t; pthread_create(&t, &at, bump, 0); }
  while (__atomic_load_n(&done, __ATOMIC_SEQ_CST) < 100) sched_yield();
  say_n("detached", done);
  pthread_t j;
  pthread_create(&j, 0, bump, 0);
  while (__atomic_load_n(&done, __ATOMIC_SEQ_CST) < 101) sched_yield();
  say_n("pthread_detach", pthread_detach(j));
  pthread_attr_destroy(&at);
  /* sigmask: the thread's own */
  sigset_t s, o;
  sigemptyset(&s); sigaddset(&s, SIGUSR2);
  say_n("pthread_sigmask", pthread_sigmask(SIG_BLOCK, &s, 0));
  pthread_sigmask(SIG_SETMASK, 0, &o);
  say_n("pthread_sigmask.held", sigismember(&o, SIGUSR2));
  say_n("pthread_sigmask.bad", pthread_sigmask(99, &s, 0) == EINVAL);
  pthread_sigmask(SIG_UNBLOCK, &s, 0);
  /* kill: a signal at one thread runs its handler there */
  signal(SIGUSR1, onk);
  pthread_t w;
  pthread_create(&w, 0, sleeper, 0);
  while (!waiting) sched_yield();
  say_n("pthread_kill.probe", pthread_kill(w, 0));
  say_n("pthread_kill", pthread_kill(w, SIGUSR1));
  pthread_join(w, 0);
  say_n("pthread_kill.there", got == SIGUSR1 && pthread_equal(gotby, w));
  /* names */
  got = 0;
  pthread_t n;
  char nb[16] = {0};
  pthread_create(&n, 0, named, 0);
  say_n("setname", pthread_setname_np(n, "odds-worker"));
  say_n("getname", pthread_getname_np(n, nb, sizeof nb)); say_s("getname.is", nb);
  say_n("setname.long", pthread_setname_np(n, "0123456789abcdef") == ERANGE);
  say_n("getname.short", pthread_getname_np(n, nb, 8) == ERANGE);
  got = 1;
  pthread_join(n, 0);
  /* atfork: prepare, then parent here and child there */
  pthread_atfork(afp, afa, afc);
  int p[2];
  pipe(p);
  int k = fork();
  if (!k) { write(p[1], afb, strlen(afb)); _exit(0); }
  close(p[1]);
  char cb[8] = {0};
  read(p[0], cb, sizeof cb - 1);
  status(k), close(p[0]);
  say_s("atfork.parent", afb); say_s("atfork.child", cb);
  /* a barrier of five: one serial each round */
  pthread_barrier_init(&bar, 0, 5);
  for (int r = 0; r < 3; r++) {
    pthread_t b[5];
    for (int i = 0; i < 5; i++) pthread_create(&b[i], 0, meet, 0);
    for (int i = 0; i < 5; i++) pthread_join(b[i], 0); }
  say_n("barrier.serial", serial);
  pthread_barrier_destroy(&bar);
  say_n("barrier.zero", pthread_barrier_init(&bar, 0, 0) == EINVAL);
  /* spinlocks */
  pthread_spin_init(&sp, PTHREAD_PROCESS_PRIVATE);
  pthread_t q[4];
  for (int i = 0; i < 4; i++) pthread_create(&q[i], 0, spin, 0);
  for (int i = 0; i < 4; i++) pthread_join(q[i], 0);
  say_n("spin", tally);
  pthread_spin_lock(&sp);
  say_n("spin.try", pthread_spin_trylock(&sp) == EBUSY);
  pthread_spin_unlock(&sp);
  say_n("spin.try.free", pthread_spin_trylock(&sp));
  pthread_spin_destroy(&sp); }

int main(void) {
  char dir[] = "/tmp/odds.XXXXXX";
  if (!mkdtemp(dir)) return 1;
  strs(); fds(dir); ats(dir); procs(); sleeps(); sigs(dir); ttys(); threads();
  char f[256];
  snprintf(f, sizeof f, "%s/lock", dir); unlink(f);
  snprintf(f, sizeof f, "%s/sock", dir); unlink(f);
  snprintf(f, sizeof f, "%s/err", dir); unlink(f);
  rmdir(dir);
  return 0; }
