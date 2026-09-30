#include <sys/utsname.h>
#include <sys/sysctl.h>
#include "../impl.h"

/* one kern.* or hw.* string into a field. freebsd's version ends in a newline and
 * carries tabs, which its own libc turns to spaces; so does this */
static void uts_mib(int a, int b, char *out) {
  int mib[2] = { a, b };
  size_t n = 64;
  if (sysctl(mib, 2, out, &n, 0, 0)) n = 0;
  out[n < 64 ? n : 64] = 0;
  for (char *p = out; *p; p++) if (*p == '\n' || *p == '\t') *p = ' ';
  for (size_t k = strlen(out); k && out[k - 1] == ' '; k--) out[k - 1] = 0; }

/* linux and inle answer the call; the BSDs have no such door, so it is read by sysctl */
int uname(struct utsname *u) {
  long v = __ai_osv;
  if (!v) v = __ai_osv = __ai_osdetect();
  if (v < 2) return (int) er(sc1(NR_uname, (long) u));
  if (!u) { __errno_v = EFAULT; return -1; }
  memset(u, 0, sizeof *u);
  uts_mib(CTL_KERN, KERN_OSTYPE, u->sysname);
  uts_mib(CTL_KERN, KERN_HOSTNAME, u->nodename);
  uts_mib(CTL_KERN, KERN_OSRELEASE, u->release);
  uts_mib(CTL_KERN, KERN_VERSION, u->version);
  uts_mib(CTL_HW, HW_MACHINE, u->machine);
  return 0; }
