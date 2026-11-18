#include "../impl.h"

/* path 2: execle, the environment after the NULL */
static int __execl(char const *p, char const *a0, va_list ap, int path) {
  va_list c; va_copy(c, ap);
  size_t n = 1;
  while (va_arg(c, char *)) n++;
  va_end(c);
  char *av[n + 1];
  av[0] = (char *) a0;
  for (size_t i = 1; i <= n; i++) av[i] = va_arg(ap, char *);   /* the last is the NULL */
  if (path == 2) return execve(p, av, va_arg(ap, char **));
  return path ? execvp(p, av) : execv(p, av); }
int execl(char const *p, char const *a0, ...) {
  va_list ap; va_start(ap, a0);
  int r = __execl(p, a0, ap, 0);
  va_end(ap);
  return r; }
int execlp(char const *f, char const *a0, ...) {
  va_list ap; va_start(ap, a0);
  int r = __execl(f, a0, ap, 1);
  va_end(ap);
  return r; }
int execle(char const *p, char const *a0, ...) {
  va_list ap; va_start(ap, a0);
  int r = __execl(p, a0, ap, 2);
  va_end(ap);
  return r; }
