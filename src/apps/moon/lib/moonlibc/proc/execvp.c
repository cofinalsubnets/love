#include "../impl.h"

/* PATH's search, each candidate run under e */
int execvpe(char const *f, char *const *av, char *const *e) {
  char const *s = f;
  while (*s) { if (*s == '/') return execve(f, av, e); s++; }
  char const *path = getenv("PATH");
  if (!path) path = "/usr/local/bin:/usr/bin:/bin";
  char buf[4096];
  size_t fn = strlen(f);
  while (*path) {
    size_t i = 0;
    while (path[i] && path[i] != ':') i++;
    if (i + 1 + fn + 1 < sizeof buf) {
      memcpy(buf, path, i);
      buf[i] = '/';
      memcpy(buf + i + 1, f, fn + 1);
      execve(buf, av, e); }
    path += i;
    if (*path == ':') path++; }
  errno = ENOENT;
  return -1; }
int execvp(char const *f, char *const *av) { return execvpe(f, av, environ); }
