#include "../impl.h"
#include <libgen.h>

/* posix's dirname, which may write into its argument; exactly two leading slashes
 * survive in an all-slash answer, as in glibc */
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
