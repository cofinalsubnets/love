#include "../impl.h"

/* the *at calls by their own names. linux's AT_ bits become the BSDs' (freebsd's and
 * netbsd's agree; os.c shifts them for macos): eacc reads 0x200 as AT_EACCESS */
static int atfb(int fl, int eacc) {
  if (__love_osv < 2) return fl;
  int r = fl & AT_SYMLINK_FOLLOW;
  if (eacc) r |= fl & AT_EACCESS ? 0x100 : 0;
  else r |= (fl & AT_SYMLINK_NOFOLLOW ? 0x200 : 0) | (fl & AT_REMOVEDIR ? 0x800 : 0);
  if (fl & AT_EMPTY_PATH) r |= 0x4000;
  return r; }

/* stat.c's shape: each kernel's own record, made ours */
int fstatat(int d, char const *p, struct stat *st, int fl) {
#ifdef __ILP32__
  return __love_statx(d, p, fl, st);
#else
  long f = atfb(fl, 0), r;
  if (__love_osv == 2) {
    struct __fb_stat k;
    if ((r = er(sc4(NR_newfstatat, d, (long) p, (long) &k, f))) >= 0) __love_fbstat(&k, st);
    return (int) r; }
#ifdef LvMac
  if (__love_osv == 4) {
    struct __mac_stat k;
    if ((r = er(sc4(NR_newfstatat, d, (long) p, (long) &k, f))) >= 0) __love_macstat(&k, st);
    return (int) r; }
#endif
  if (__love_osv == 3) {
    struct __nb_stat k;
    if ((r = er(sc4(NR_newfstatat, d, (long) p, (long) &k, f))) >= 0) __love_nbstat(&k, st);
    return (int) r; }
  return (int) er(sc4(NR_newfstatat, d, (long) p, (long) st, fl));
#endif
}
int linkat(int a, char const *p, int b, char const *q, int fl) {
  return (int) er(sc5(NR_linkat, a, (long) p, b, (long) q, atfb(fl, 0))); }
int symlinkat(char const *t, int d, char const *p) { return (int) er(sc3(NR_symlinkat, (long) t, d, (long) p)); }
int mkdirat(int d, char const *p, unsigned int m) { return (int) er(sc3(NR_mkdirat, d, (long) p, m)); }
int faccessat(int d, char const *p, int m, int fl) { return (int) er(sc4(NR_faccessat, d, (long) p, m, atfb(fl, 1))); }
int fchmodat(int d, char const *p, unsigned int m, int fl) { return (int) er(sc4(NR_fchmodat, d, (long) p, m, atfb(fl, 0))); }
int fchownat(int d, char const *p, unsigned int u, unsigned int g, int fl) {
  return (int) er(sc5(NR_fchownat, d, (long) p, u, g, atfb(fl, 0))); }
#if defined(__riscv)
int renameat(int a, char const *p, int b, char const *q) { return (int) er(sc5(NR_renameat2, a, (long) p, b, (long) q, 0)); }
#else
int renameat(int a, char const *p, int b, char const *q) { return (int) er(sc4(NR_renameat, a, (long) p, b, (long) q)); }
#endif
