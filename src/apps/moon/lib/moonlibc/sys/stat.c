#include "../impl.h"

int stat(char const *p, struct stat *st) {
  if (__love_osv == 2) {
    struct __fb_stat f;
    long r = er(sc4(NR_newfstatat, AT_FDCWD, (long) p, (long) &f, 0));
    if (r >= 0) __love_fbstat(&f, st);
    return (int) r; }
  if (__love_osv == 3) {
    struct __nb_stat f;
    long r = er(sc4(NR_newfstatat, AT_FDCWD, (long) p, (long) &f, 0));
    if (r >= 0) __love_nbstat(&f, st);
    return (int) r; }
  return (int) er(sc4(NR_newfstatat, AT_FDCWD, (long) p, (long) st, 0)); }
