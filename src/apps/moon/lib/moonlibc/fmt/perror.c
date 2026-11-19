#include "../impl.h"

void perror(char const *s) {
  int e = errno;
  if (s && *s) fprintf(stderr, "%s: ", s);
  fprintf(stderr, "errno %d\n", e); }
