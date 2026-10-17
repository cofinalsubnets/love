#include "../impl.h"

#ifdef LvMac
/* macos has no utimensat: utimes(2) on the path, dfd's own path ahead of a
 * relative one, each special read here -- NOW off the clock, OMIT off the file */
static int macutimes(int dfd, char const *p, struct timespec const *ts) {
  char b[2048];
  if (dfd != AT_FDCWD && p[0] != '/') {
    if (fb3(92, dfd, 50, (long) b) < 0) { __errno_v = EBADF; return -1; }   /* F_GETPATH */
    size_t k = strlen(b);
    if (k + strlen(p) + 2 > sizeof b) { __errno_v = ENAMETOOLONG; return -1; }
    b[k] = '/', strcpy(b + k + 1, p), p = b; }
  if (!ts) return (int) er(fb2(138, (long) p, 0));
  struct timeval tv[2];
  struct stat st;
  int got = 0;
  for (int i = 0; i < 2; i++)
    if (ts[i].tv_nsec == UTIME_NOW) gettimeofday(tv + i, 0);
    else if (ts[i].tv_nsec == UTIME_OMIT) {
      if (!got && stat(p, &st) < 0) return -1;
      got = 1;
      struct timespec o = i ? st.st_mtim : st.st_atim;
      tv[i].tv_sec = o.tv_sec, tv[i].tv_usec = o.tv_nsec / 1000; }
    else tv[i].tv_sec = ts[i].tv_sec, tv[i].tv_usec = ts[i].tv_nsec / 1000;
  return (int) er(fb2(138, (long) p, (long) tv)); }
#endif

int utimensat(int dfd, char const *p, struct timespec const *ts, int fl) {
#ifdef LvMac
  if (__love_osv == 4) return macutimes(dfd, p, ts);
#endif
  if (__love_osv == 2) {
    /* freebsd spells the specials -1/-2 where linux says 2^30-1/2^30-2, and
     * AT_SYMLINK_NOFOLLOW wears its bit */
    struct timespec t2[2];
    long a = ts ? (long) ts : 0;
    if (ts && (ts[0].tv_nsec == UTIME_NOW || ts[0].tv_nsec == UTIME_OMIT
            || ts[1].tv_nsec == UTIME_NOW || ts[1].tv_nsec == UTIME_OMIT)) {
      t2[0] = ts[0]; t2[1] = ts[1];
      for (int i = 0; i < 2; i++)
        if (t2[i].tv_nsec == UTIME_NOW) t2[i].tv_nsec = -1;
        else if (t2[i].tv_nsec == UTIME_OMIT) t2[i].tv_nsec = -2;
      a = (long) t2; }
    long f2 = (fl & AT_SYMLINK_NOFOLLOW) ? 0x200 : 0;
    return (int) er(sc4(NR_utimensat, dfd, (long) p, a, f2)); }
  if (__love_osv == 3 && (fl & AT_SYMLINK_NOFOLLOW))
    fl = (fl & ~AT_SYMLINK_NOFOLLOW) | 0x200;   /* netbsd's bit; its specials are linux's */
  return (int) er(sc4(NR_utimensat, dfd, (long) p, (long) ts, fl)); }
