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

static struct g *_putc(struct g*f, int c, struct g_out*) { return putc(c, stdout), f; }
static struct g* _flush(struct g*f, struct g_out*o) { fflush(stdout); return f; }
static struct g*_getc(struct g*f, struct g_in*) { return g_core_of(f)->b = getc(stdin), f; }
static struct g* _ungetc(struct g*f, int c, struct g_in*) { return g_core_of(f)->b = ungetc(c, stdin), f; }
static struct g* _eof(struct g*f, struct g_in*) { return g_core_of(f)->b = feof(stdin), f; }
struct g_in g_stdin = { .getc = _getc, .ungetc = _ungetc, .eof = _eof, };
struct g_out g_stdout = { .putc = _putc, .flush = _flush, };

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
