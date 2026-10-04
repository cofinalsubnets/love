#include "../impl.h"

/* bit 0 of each page's byte is resident; freebsd sets more bits beside it, which linux leaves clear */
int mincore(void *p, unsigned long n, unsigned char *vec) {
  int r = (int) er(sc3(NR_mincore, (long) p, (long) n, (long) vec));
  if (r == 0 && __love_osv >= 2) {
    unsigned long ps = (unsigned long) sysconf(_SC_PAGESIZE);
    for (unsigned long i = 0; i < (n + ps - 1) / ps; i++) vec[i] &= 1; }
  return r; }
