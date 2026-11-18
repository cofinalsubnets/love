#include "../impl.h"

/* accept with SOCK_CLOEXEC and SOCK_NONBLOCK on the new fd: freebsd's accept4, netbsd's
 * paccept (a sigmask fourth), macos's accept then fcntl */
int accept4(int fd, struct sockaddr *a, socklen_t *n, int fl) {
  if (fl & ~(SOCK_CLOEXEC | SOCK_NONBLOCK)) { errno = EINVAL; return -1; }
  int r;
  if (__love_osv == 4) {
    if ((r = accept(fd, a, n)) < 0) return -1;
    if (((fl & SOCK_CLOEXEC) && fcntl(r, F_SETFD, FD_CLOEXEC) < 0)
        || ((fl & SOCK_NONBLOCK) && fcntl(r, F_SETFL, fcntl(r, F_GETFL) | O_NONBLOCK) < 0)) { close(r); return -1; }
    return r; }
  if (__love_osv == 3) r = (int) er(__love_fb(456, fd, (long) a, (long) n, 0, __love_sotype(fl), 0));
  else if (__love_osv == 2) r = (int) er(__love_fb(541, fd, (long) a, (long) n, __love_sotype(fl), 0, 0));
  else r = (int) er(sc4(NR_accept4, fd, (long) a, (long) n, fl));
  if (r >= 0 && __love_osv >= 2 && a && n) __love_saout(a, *n);
  return r; }
