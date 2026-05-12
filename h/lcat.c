#include "../g/g.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>

// noinline this because it leaks a stack address
g_noinline uintptr_t g_clock(void) {
 struct timespec ts;
 int s = clock_gettime(CLOCK_MONOTONIC, &ts);
 return s ? 0 : ts.tv_sec  * 1e3 + ts.tv_nsec / 1e6; }

int gputc(struct g*f, int c) {
  if (c == '\\' || c == '"')
    putc(c, stdout);
  return putc(c, stdout); }
int ggetc(struct g*f) { return getc(stdin); }
int gungetc(struct g*_, int c) { return ungetc(c, stdin); }
int geof(struct g*_) { return feof(stdin); }
int gflush(struct g*) { return fflush(stdout); }

int main(int argc, char const **argv) {
 putc('"', stdout);
 enum g_status s = g_fin(g_evals_(g_ini(),
  "(:(g x e)(: r(read e)(?(= e r)0(: _(? x (puts \" \"))_(. r)(g 1 e))))(g 0 (sym 0)))"));
 putc('"', stdout);
 putc('\n', stdout);
 fflush(stdout);
 return s; }
