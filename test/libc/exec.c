/* exec's variadic pair against glibc's: execl and execlp hand a shell 300 arguments, and the
 * shell says how many it was given, so an argv cut short anywhere shows as a smaller count */
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include "say.h"

#define X10 "x", "x", "x", "x", "x", "x", "x", "x", "x", "x"
#define X100 X10, X10, X10, X10, X10, X10, X10, X10, X10, X10
#define X300 X100, X100, X100

static void run(int path) {
  fflush(stdout);
  if (fork() == 0) {
    if (path) execlp("sh", "sh", "-c", "echo $#", "sh", X300, (char *) 0);
    else execl("/bin/sh", "sh", "-c", "echo $#", "sh", X300, (char *) 0);
    _exit(127); }
  int st; wait(&st);
  say_n(path ? "execlp.status" : "execl.status", WIFEXITED(st) ? WEXITSTATUS(st) : -1); }

int main(void) {
  run(0);
  run(1);
  return 0; }
