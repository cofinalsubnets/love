/* popen and system against glibc's: the default shell, then $LOVE_SH split into words around
 * stray spaces (glibc ignores it, so it names the same shell and the answers agree) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include "say.h"

static void run(char const *k) {
  char b[64] = {0};
  FILE *f = popen("echo $#; printf piped", "r");
  size_t n = f ? fread(b, 1, sizeof b - 1, f) : 0;
  int st = f ? pclose(f) : -1;
  say_s(k, n ? b : "(none)");
  say_n("pclose", WIFEXITED(st) ? WEXITSTATUS(st) : -1);
  fflush(stdout);
  st = system("exit 3");
  say_n("system", WIFEXITED(st) ? WEXITSTATUS(st) : -1);
  FILE *w = popen("wc -c", "w");
  fputs("seven!\n", w);
  fflush(stdout);
  pclose(w); }

int main(void) {
  run("default");
  setenv("LOVE_SH", "  /bin/sh   ", 1);
  run("love_sh");
  return 0; }
