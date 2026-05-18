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

int gputc(struct g*f, int c) { return putc(c, stdout); }
int gflush(struct g*) { return fflush(stdout); }
struct g*ggetc(struct g*f) { return !g_ok(f) ? f : (f->b = getc(stdin), f); }
struct g*gungetc(struct g*f, int c) { return !g_ok(f) ? f : (f->b = ungetc(c, stdin), f); }
struct g*geof(struct g*f) { return !g_ok(f) ? f : (f->b = feof(stdin), f); }

int main(int argc, char const **argv) {
 struct g *f;
 for (f = g_ini(); *argv; f = g_strof(f, *argv++));
 for (f = g_push(f, 1, g_nil); argc--; f = gxr(f));
 if (g_ok(f)) {
  struct g_def d[] = {{"argv", g_pop1(f)}, {0}};
  static char const p[] =
#include "boot.h"
   "(:(g e)(: r(read e)(?(= e r)0(: _(ev'ev r)(g e))))(g(sym 0)))";
  f = g_evals_(g_defs(f, d), p); }

 // finish up
 enum g_status s = g_code_of(f);
 if (s != g_status_ok) {
  f = g_core_of(f);
  if (!f) fprintf(stderr, "# f@0 %d\n", s);
  else fprintf(stderr, "# f@%lx %lx.%ld.%ld.%ld\n",
   (long unsigned) f,
   (long unsigned) f->pool,
   f->len,
   f->hp - (intptr_t*) f,
   (intptr_t*) f + f->len - f->sp); }
 g_fin(f);
 return s; }
