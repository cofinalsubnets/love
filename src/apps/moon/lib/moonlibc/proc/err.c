#include "../impl.h"
#include <err.h>

/* the program's name as glibc prints it here: argv[0] past its last slash */
static char const *__errname(void) {
  char const *p = __love_progname, *s = p;
  for (; *p; p++) if (*p == '/') s = p + 1;
  return s; }
static void __errsay(int e, int with, char const *fmt, va_list ap) {
  fflush(stdout);
  fprintf(stderr, "%s: ", __errname());
  if (fmt) { vfprintf(stderr, fmt, ap); if (with) fputs(": ", stderr); }
  if (with) fputs(strerror(e), stderr);
  fputc('\n', stderr); }
void vwarn(char const *fmt, va_list ap) { __errsay(__errno_v, 1, fmt, ap); }
void vwarnx(char const *fmt, va_list ap) { __errsay(0, 0, fmt, ap); }
void verr(int st, char const *fmt, va_list ap) { vwarn(fmt, ap); exit(st); }
void verrx(int st, char const *fmt, va_list ap) { vwarnx(fmt, ap); exit(st); }
void warn(char const *fmt, ...) { va_list ap; va_start(ap, fmt); vwarn(fmt, ap); va_end(ap); }
void warnx(char const *fmt, ...) { va_list ap; va_start(ap, fmt); vwarnx(fmt, ap); va_end(ap); }
void err(int st, char const *fmt, ...) { va_list ap; va_start(ap, fmt); vwarn(fmt, ap); va_end(ap); exit(st); }
void errx(int st, char const *fmt, ...) { va_list ap; va_start(ap, fmt); vwarnx(fmt, ap); va_end(ap); exit(st); }
