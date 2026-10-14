/* test/kernel/c/hello.c -- a C program as an inle process (test/kernel/cprog.l, uproc.l): its
 * words, its cwd and its environment are its own, its status goes back. on x64 the kernel's
 * memory is not its own: `peek` reads the kernel's image and faults, `poke` hands it to write,
 * which refuses. `spin F` computes without a call until F turns up, so only the timer gets
 * the machine back; `cat` pours stdin to stdout, which waits on whoever writes the pipe */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>

int main(int argc, char **argv) {
  char d[256];
  if (argc == 2 && !strcmp(argv[1], "peek")) return *(volatile char*) (uintptr_t) 0xffffff8000200000ull;
  if (argc == 2 && !strcmp(argv[1], "poke")) return write(1, (void*) (uintptr_t) 0xffffff8000200000ull, 1) < 0 ? 3 : 4;
  if (argc == 3 && !strcmp(argv[1], "spin"))
    for (volatile unsigned long i = 0;; i++)
      if (!(i & 0xffffff) && open(argv[2], O_RDONLY) >= 0) return 5;
  if (argc == 2 && !strcmp(argv[1], "cat")) {
    for (long n; (n = read(0, d, sizeof d)) > 0;)
      if (write(1, d, (size_t) n) != n) return 1;
    return 0; }
  char const *h = getenv("HELLO");
  printf("hello from C:");
  for (int i = 1; i < argc; i++) printf(" %s", argv[i]);
  printf(" in %s, HELLO=%s\n", getcwd(d, sizeof d) ? d : "?", h ? h : "unset");
  return argc > 1 ? atoi(argv[argc - 1]) & 255 : 0; }
