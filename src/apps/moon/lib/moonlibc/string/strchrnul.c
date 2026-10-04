#include "../impl.h"

/* strchr's, but a miss answers the terminating NUL rather than null */
char *strchrnul(char const *s, int c) {
  while (*s && *s != (char) c) s++;
  return (char *) s; }
