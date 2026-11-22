/* test/kernel/c/hello.c -- a C program as an inle process (test/kernel/cprog.l, uproc.l): its
 * words, its cwd and its environment are its own, its status goes back. on x64 the kernel's
 * memory is not its own: `peek` reads the kernel's image and faults, `poke` hands it to write,
 * which refuses. `spin F` computes without a call until F turns up, so only the timer gets
 * the machine back; `cat` pours stdin to stdout, which waits on whoever writes the pipe;
 * `fork` makes a child whose memory is a copy, a static and a heap block written there alone;
 * `cow` shares a mapping's pages with the child till one side writes: a page the child has
 * copied the parent writes in place, a page still shared it copies (the kernel's free pages
 * say which), the kernel's own writes land on one side, and a fork of the fork sees its own */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/wait.h>

#if defined(__riscv)
#define K_PEEK 0xffffffe000200000ull           // inside rv64's image window, the kernel's alone
#else
#define K_PEEK 0xffffff8000200000ull
#endif

int main(int argc, char **argv) {
  char d[256];
  if (argc == 2 && !strcmp(argv[1], "peek")) return *(volatile char*) (uintptr_t) K_PEEK;
  if (argc == 2 && !strcmp(argv[1], "poke")) return write(1, (void*) (uintptr_t) K_PEEK, 1) < 0 ? 3 : 4;
  if (argc == 3 && !strcmp(argv[1], "spin"))
    for (volatile unsigned long i = 0;; i++)
      if (!(i & 0xffffff) && open(argv[2], O_RDONLY) >= 0) return 5;
  if (argc == 2 && !strcmp(argv[1], "cat")) {
    for (long n; (n = read(0, d, sizeof d)) > 0;)
      if (write(1, d, (size_t) n) != n) return 1;
    return 0; }
  if (argc == 2 && !strcmp(argv[1], "fork")) {
    static int mark = 1;
    char *hp = malloc(64);
    int p[2], st = 0;
    if (!hp || pipe(p)) return 1;
    strcpy(hp, "P");
    pid_t k = fork();
    if (k < 0) return 2;
    if (!k) {
      mark = 2, hp[0] = 'C', close(p[0]);
      return write(p[1], "kid", 3) == 3 && mark == 2 && getppid() != getpid() ? 9 : 1; }
    close(p[1]);
    long n = read(p[0], d, sizeof d);
    if (waitpid(k, &st, 0) != k) return 3;
    printf("forked: %.*s %d mark %d heap %s\n", n > 0 ? (int) n : 0, d, WEXITSTATUS(st), mark, hp);
    return 0; }
  if (argc == 2 && !strcmp(argv[1], "cow")) {
    size_t const n = 1 << 20;                    // past malloc's 128 KB: a mapping of its own
    char *b = malloc(n), x;
    int up[2], dn[2], st = 0;
    if (!b || pipe(up) || pipe(dn)) return 1;
    memset(b, 'P', n);
    pid_t k = fork();
    if (k < 0) return 2;
    if (!k) {
      b[0] = 'C';
      if (write(up[1], "c", 1) != 1 || read(dn[0], b + 16384, 1) != 1) return 1;
      pid_t g = fork();
      if (g < 0) return 2;
      if (!g) { b[4096] = 'G'; return b[0] == 'C' && b[4096] == 'G' && b[16384] == 'd' && b[8192] == 'P' ? 7 : 1; }
      if (waitpid(g, &st, 0) != g || WEXITSTATUS(st) != 7) return 4;
      if (write(up[1], "kid", 3) != 3) return 1;
      return b[0] == 'C' && b[4096] == 'P' && b[8192] == 'P' && b[12288] == 'P' && b[16384] == 'd' ? 9 : 1; }
    if (read(up[0], &x, 1) != 1) return 3;
    long f0 = sysconf(_SC_AVPHYS_PAGES);
    b[0] = 'Q';
    long f1 = sysconf(_SC_AVPHYS_PAGES);
    b[8192] = 'R';
    long f2 = sysconf(_SC_AVPHYS_PAGES);
    if (write(dn[1], "d", 1) != 1 || read(up[0], b + 12288, 3) != 3) return 3;
    if (waitpid(k, &st, 0) != k) return 3;
    printf("cow: %d inplace %d copied %d mine %d\n", WEXITSTATUS(st), f0 - f1 < 2, f1 - f2 >= 16,
           b[0] == 'Q' && b[4096] == 'P' && b[8192] == 'R' && !memcmp(b + 12288, "kid", 3) && b[16384] == 'P');
    return 0; }
  char const *h = getenv("HELLO");
  printf("hello from C:");
  for (int i = 1; i < argc; i++) printf(" %s", argv[i]);
  printf(" in %s, HELLO=%s\n", getcwd(d, sizeof d) ? d : "?", h ? h : "unset");
  return argc > 1 ? atoi(argv[argc - 1]) & 255 : 0; }
