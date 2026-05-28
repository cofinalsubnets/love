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

static struct g *lcat_putc(struct g*f, int c) {
  if (c == '\n') { fputs("\\n", stdout); return f; }
  if (c == '\\' || c == '"') putc('\\', stdout);  // C-escape backslash & quote
  putc(c, stdout);
  return f; }
static struct g* lcat_flush(struct g*f) { fflush(stdout); return f; }

static struct g*lcat_getc(struct g*f) {
  struct g_io *i = g_core_of(f)->io;
  if (g_getnum(i->ungetc_buf) != EOF) {
    int c = g_getnum(i->ungetc_buf);
    i->ungetc_buf = g_putnum(EOF);
    return g_core_of(f)->b = c, f; }
  int c = getc(stdin);
  if (c == EOF) i->eof_seen = g_putnum(true);
  return g_core_of(f)->b = c, f; }
static struct g* lcat_ungetc(struct g*f, int c) {
  struct g_io *i = g_core_of(f)->io;
  i->ungetc_buf = g_putnum(c);
  i->eof_seen = g_putnum(false);
  return g_core_of(f)->b = c, f; }
static struct g* lcat_eof(struct g*f) {
  struct g_io *i = g_core_of(f)->io;
  return g_core_of(f)->b = (g_getnum(i->ungetc_buf) == EOF) && g_getnum(i->eof_seen), f; }
struct g_io g_stdin = { .ap = g_vm_port_io,
                        .fd = g_putnum(STDIN_FILENO), .ungetc_buf = g_putnum(EOF), .eof_seen = g_putnum(false), };
struct g_io g_stdout = { .ap = g_vm_port_io,
                         .fd = g_putnum(STDOUT_FILENO), .ungetc_buf = g_putnum(EOF), .eof_seen = g_putnum(false), };

struct g_port_vt const g_fd_port_vt = { lcat_getc, lcat_ungetc, lcat_eof, lcat_putc, lcat_flush };

int main(int argc, char const **argv) {
 putc('"', stdout);
 enum g_status s = g_fin(g_evals_(g_ini(),
  "(:(g x e)(: r(fread in e)(?(= e r)0(: _(? x (puts \" \"))_(. r)(g 1 e))))(g 0 (sym 0)))"));
 putc('"', stdout);
 putc('\n', stdout);
 fflush(stdout);
 return s; }
