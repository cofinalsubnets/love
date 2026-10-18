#include <sys/utsname.h>
#include <sys/sysctl.h>
#include "../impl.h"

/* a kern.* or hw.* string into a field, cut to 64. freebsd's version carries a newline and
 * tabs, which its libc turns to spaces; macos's runs past the field */
static void uts_mib(int a, int b, char *out) {
  int mib[2] = { a, b };
  char t[256];
  size_t n = sizeof t;
  if (sysctl(mib, 2, t, &n, 0, 0)) n = 0;
  if (n > 64) n = 64;
  memcpy(out, t, n);
  out[n] = 0;
  for (char *p = out; *p; p++) if (*p == '\n' || *p == '\t') *p = ' ';
  for (size_t k = strlen(out); k && out[k - 1] == ' '; k--) out[k - 1] = 0; }

/* the BSDs have no uname call */
int uname(struct utsname *u) {
  long v = __love_osv;
  if (!v) v = __love_osv = __love_osdetect();
  if (v < 2) return (int) er(sc1(NR_uname, (long) u));
  if (!u) { __errno_v = EFAULT; return -1; }
  memset(u, 0, sizeof *u);
  uts_mib(CTL_KERN, KERN_OSTYPE, u->sysname);
  uts_mib(CTL_KERN, KERN_HOSTNAME, u->nodename);
  uts_mib(CTL_KERN, KERN_OSRELEASE, u->release);
  uts_mib(CTL_KERN, KERN_VERSION, u->version);
  uts_mib(CTL_HW, HW_MACHINE, u->machine);
  return 0; }
