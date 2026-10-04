#include "../impl.h"
#include <libgen.h>

/* ---- basename: posix's, which may write into its argument ---- */
char *basename(char *p) {
  if (!p || !*p) return ".";
  size_t n = strlen(p);
  while (n > 1 && p[n - 1] == '/') n--;
  if (n == 1 && *p == '/') { p[1] = 0; return p; }
  p[n] = 0;
  char *s = strrchr(p, '/');
  return s ? s + 1 : p; }
