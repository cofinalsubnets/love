#include "../impl.h"
#include <pwd.h>

/* the login name into b: 0, or ENXIO/ENOTTY with no login known, ERANGE short. linux
 * keeps the login's uid in /proc/self/loginuid (unset is -1); utmp is not read. the BSDs
 * and macos answer getlogin(2) */
int getlogin_r(char *b, size_t n) {
  if (__love_osv >= 2) {
    char k[256] = {0};
    long r = fb2(49, (long) k, sizeof k);
    if (r < 0) return (int) -r;
    if (!k[0]) return ENXIO;
    if (strlen(k) >= n) return ERANGE;
    strcpy(b, k);
    return 0; }
  int fd = open("/proc/self/loginuid", O_RDONLY | O_CLOEXEC);
  char t[16];
  long m = fd < 0 ? -1 : read(fd, t, sizeof t - 1);
  if (fd >= 0) close(fd);
  unsigned long u = 0;
  int ok = m > 0;
  for (long i = 0; ok && i < m && t[i] != '\n'; i++) ok = t[i] >= '0' && t[i] <= '9', u = u * 10 + (unsigned long) (t[i] - '0');
  if (!ok || u >= 4294967295UL) return isatty(0) ? ENXIO : ENOTTY;
  struct passwd pw, *p = 0;
  char pb[1024];
  if (getpwuid_r((uid_t) u, &pw, pb, sizeof pb, &p) || !p) return ENXIO;
  if (strlen(pw.pw_name) >= n) return ERANGE;
  strcpy(b, pw.pw_name);
  return 0; }
/* ..and into libc's own */
char *getlogin(void) {
  static char nb[256];
  int e = getlogin_r(nb, sizeof nb);
  return e ? (errno = e, (char *) 0) : nb; }
