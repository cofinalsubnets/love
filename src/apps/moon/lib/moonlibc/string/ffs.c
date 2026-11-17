#include "../impl.h"
#include <strings.h>

/* the lowest set bit, counted from 1; 0 for none */
int ffsll(long long v) {
  unsigned long long u = (unsigned long long) v;
  if (!u) return 0;
  int i = 1;
  while (!(u & 1)) u >>= 1, i++;
  return i; }
int ffsl(long v) { return ffsll((long long) (unsigned long) v); }
int ffs(int v) { return ffsll((long long) (unsigned int) v); }
