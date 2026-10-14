/* test/kernel/c/hello.c -- a C program as an inle process (test/kernel/cprog.l): its words, its
 * cwd and its environment are its own, its status goes back */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv) {
  char d[256];
  char const *h = getenv("HELLO");
  printf("hello from C:");
  for (int i = 1; i < argc; i++) printf(" %s", argv[i]);
  printf(" in %s, HELLO=%s\n", getcwd(d, sizeof d) ? d : "?", h ? h : "unset");
  return argc > 1 ? atoi(argv[argc - 1]) & 255 : 0; }
