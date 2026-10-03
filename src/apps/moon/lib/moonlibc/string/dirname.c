#include "../impl.h"
#include <libgen.h>

/* ---- dirname: posix's, which may write into its argument. a path that opens with exactly
 * two slashes keeps them in an all-slash answer, as glibc does ---- */
char *dirname(char *p) {
  if (!p || !*p) return ".";
  size_t n = strlen(p), lead = strspn(p, "/");
  while (n > 1 && p[n - 1] == '/') n--;
  while (n > 0 && p[n - 1] != '/') n--;
  if (!n) return ".";
  while (n > 1 && p[n - 1] == '/') n--;
  if (n == 1 && lead == 2) n = 2;
  p[n] = 0;
  return p; }
