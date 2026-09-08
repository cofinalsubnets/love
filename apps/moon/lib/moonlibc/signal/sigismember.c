#include "../impl.h"

int sigismember(sigset_t const *s, int n) {
  return (int) ((s->__v[(n - 1) / 64] >> ((unsigned) (n - 1) % 64)) & 1); }
