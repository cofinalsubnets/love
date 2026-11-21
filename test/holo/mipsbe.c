/* mipsbe: byte order, time64 and signals on a big-endian o32 kernel; every answer a fact, never a clock */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <signal.h>
#include <time.h>
#include <unistd.h>
#include <errno.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <arpa/inet.h>

static volatile sig_atomic_t got, gcode, gsig, alrm;
static void onusr(int s, siginfo_t *si, void *uc) { (void) uc; got++; gsig = si->si_signo; gcode = si->si_code; (void) s; }
static void onalrm(int s) { (void) s; alrm = 1; }

struct bf { unsigned a : 3, b : 5, c : 8, d : 16; };

int main(void) {
  union { uint32_t w; unsigned char b[4]; } u = { 0x01020304 };
  printf("bytes %d %d %d %d\n", u.b[0], u.b[1], u.b[2], u.b[3]);
  printf("htonl id %d\n", htonl(0x01020304) == 0x01020304);
  union { uint64_t q; uint32_t w[2]; } p = { 0x1122334455667788ull };
  printf("pair hi first %d\n", p.w[0] == 0x11223344u && p.w[1] == 0x55667788u);
  union { double d; unsigned char b[8]; } f = { 1.0 };
  printf("double %02x%02x\n", f.b[0], f.b[1]);
  union { struct bf s; uint32_t w; } bb; memset(&bb, 0, sizeof bb);
  bb.s.a = 5; bb.s.b = 17; bb.s.c = 0xab; bb.s.d = 0x1234;
  printf("bitfield %08x\n", (unsigned) bb.w);
  long long ll = -2; unsigned long long ul = 0xffffffffull;
  printf("ll %lld %llu %lld\n", ll * 3000000000ll, ul * 3, (long long) 9000000000ll / 7);

  printf("time_t %d timespec %d\n", (int) sizeof(time_t), (int) sizeof(struct timespec));
  time_t far = 4102444800;                      /* 2100-01-01T00:00:00Z, past 2038 */
  struct tm tm; gmtime_r(&far, &tm);
  printf("2100 %d-%02d-%02d %02d wday %d\n", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_wday);
  struct timespec a, b, rq = { 0, 20000000 }, rm = { 7, 7 };
  clock_gettime(CLOCK_MONOTONIC, &a);
  int ns = nanosleep(&rq, &rm);
  clock_gettime(CLOCK_MONOTONIC, &b);
  long long dt = (long long) (b.tv_sec - a.tv_sec) * 1000000000ll + (b.tv_nsec - a.tv_nsec);
  printf("nanosleep %d slept>=20ms %d nsec<1e9 %d\n", ns, dt >= 20000000ll, b.tv_nsec >= 0 && b.tv_nsec < 1000000000);
  struct timespec rt; clock_gettime(CLOCK_REALTIME, &rt);
  printf("realtime after 2020 %d\n", rt.tv_sec > 1577836800);
  struct stat st; stat(".", &st);
  printf("stat mtime nsec<1e9 %d\n", st.st_mtim.tv_nsec >= 0 && st.st_mtim.tv_nsec < 1000000000);

  struct sigaction sa; memset(&sa, 0, sizeof sa);
  sa.sa_sigaction = onusr; sa.sa_flags = SA_SIGINFO; sigemptyset(&sa.sa_mask);
  printf("sigaction %d\n", sigaction(SIGUSR1, &sa, 0));
  raise(SIGUSR1);
  printf("usr1 got %d signo ok %d code %d\n", (int) got, gsig == SIGUSR1, (int) gcode);
  sigset_t m, o; sigemptyset(&m); sigaddset(&m, SIGUSR1);
  sigprocmask(SIG_BLOCK, &m, &o);
  kill(getpid(), SIGUSR1);

  printf("blocked got %d\n", (int) got);
  sigprocmask(SIG_SETMASK, &o, 0);
  printf("unblocked got %d\n", (int) got);
  signal(SIGALRM, onalrm); alarm(1); pause();
  printf("alarm %d\n", (int) alrm);
  pid_t c = fork();
  if (c == 0) { for (;;) pause(); }
  kill(c, SIGTERM);
  int ws = 0; waitpid(c, &ws, 0);
  printf("child termsig %d %d\n", WIFSIGNALED(ws), WIFSIGNALED(ws) ? WTERMSIG(ws) == SIGTERM : -1);
  c = fork();
  if (c == 0) _exit(37);
  waitpid(c, &ws, 0);
  printf("child exit %d\n", WEXITSTATUS(ws));
  errno = 0; printf("kill bad %d errno ESRCH %d\n", kill(-99999, 0), errno == ESRCH);
  printf("SIGUSR1 %d SIGCHLD %d EAGAIN %d\n", SIGUSR1, SIGCHLD, EAGAIN);
  return 0;
}
