#include "../impl.h"

int execve(char const *p, char *const *av, char *const *ev) {
  return (int) er(sc3(NR_execve, (long) p, (long) av, (long) ev)); }
