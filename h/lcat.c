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

static struct g *lcat_putc(struct g*f, int c, struct g_out*) {
  if (c == '\n') { fputs("\\n", stdout); return f; }
  if (c == '\\' || c == '"') putc('\\', stdout);  // C-escape backslash & quote
  putc(c, stdout);
  return f; }
static struct g* lcat_flush(struct g*f, struct g_out*) { fflush(stdout); return f; }

static struct g*lcat_getc(struct g*f, struct g_in *i) {
  if (i->ungetc_buf != EOF) {
    int c = i->ungetc_buf;
    i->ungetc_buf = EOF;
    return g_core_of(f)->b = c, f; }
  int c = getc(stdin);
  if (c == EOF) i->eof_seen = true;
  return g_core_of(f)->b = c, f; }
static struct g* lcat_ungetc(struct g*f, int c, struct g_in *i) {
  i->ungetc_buf = c;
  i->eof_seen = false;
  return g_core_of(f)->b = c, f; }
static struct g* lcat_eof(struct g*f, struct g_in *i) {
  return g_core_of(f)->b = (i->ungetc_buf == EOF) && i->eof_seen, f; }
struct g_in _g_stdin = { .getc = lcat_getc, .ungetc = lcat_ungetc, .eof = lcat_eof,
                         .fd = STDIN_FILENO, .ungetc_buf = EOF, .eof_seen = false, },
            *g_stdin = &_g_stdin;
struct g_out _g_stdout = { .putc = lcat_putc, .flush = lcat_flush, },
             *g_stdout = &_g_stdout;;

int main(int argc, char const **argv) {
 putc('"', stdout);
 enum g_status s = g_fin(g_evals_(g_ini(),
  "(:(g x e)(: r(read e)(?(= e r)0(: _(? x (puts \" \"))_(. r)(g 1 e))))(g 0 (sym 0)))"));
 putc('"', stdout);
 putc('\n', stdout);
 fflush(stdout);
 return s; }
