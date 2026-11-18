#include "../impl.h"
#include <sys/random.h>

/* the kernel's random bytes: linux's and freebsd's getrandom, netbsd's kern.arandom sysctl
 * and macos's getentropy, each at most 256 bytes a call there */
long getrandom(void *b, size_t n, unsigned int fl) {
  if (__love_osv == 2) return er(fb3(563, (long) b, (long) n, fl));
  if (__love_osv >= 3) {
    size_t k = n > 256 ? 256 : n;
    if (__love_osv == 4) return er(fb2(500, (long) b, (long) k)) < 0 ? -1 : (long) k;
    int mib[2] = { 1, 81 };                /* CTL_KERN, KERN_ARND */
    unsigned long len = k;
    return er(__love_fb(202, (long) mib, 2, (long) b, (long) &len, 0, 0)) < 0 ? -1 : (long) len; }
  return er(sc3(NR_getrandom, (long) b, (long) n, fl)); }

/* all n bytes or none: glibc's limit of 256, an interrupted read asked again */
int getentropy(void *b, size_t n) {
  if (n > 256) { errno = EIO; return -1; }
  for (size_t d = 0; d < n; ) {
    long r = getrandom((char *) b + d, n - d, 0);
    if (r < 0) { if (errno == EINTR) continue; return -1; }
    d += (size_t) r; }
  return 0; }
