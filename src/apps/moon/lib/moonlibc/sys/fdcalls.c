#include "../impl.h"
#include <sys/file.h>

/* the flags a call without them gives by fcntl: O_CLOEXEC and O_NONBLOCK, one fd */
static int fdfl(int fd, int fl) {
  if ((fl & O_CLOEXEC) && fcntl(fd, F_SETFD, FD_CLOEXEC) < 0) return -1;
  if ((fl & O_NONBLOCK) && fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) < 0) return -1;
  return 0; }

int pipe2(int *fds, int fl) {
  if (__love_osv == 4) {                   /* macos has no pipe2 */
    if (pipe(fds) < 0) return -1;
    if (fdfl(fds[0], fl) < 0 || fdfl(fds[1], fl) < 0) { close(fds[0]), close(fds[1]); return -1; }
    return 0; }
  return (int) er(sc2(NR_pipe2, (long) fds, __love_osv >= 2 ? __love_ofb(fl) : fl)); }

int dup3(int a, int b, int fl) {
  if (a == b || (fl & ~O_CLOEXEC)) { errno = EINVAL; return -1; }
  if (__love_osv == 2) return (int) er(fb3(NR_fb_fcntl, a, fl ? 18 : 10, b));   /* F_DUP2FD(_CLOEXEC) */
  if (__love_osv == 3) return (int) er(fb3(454, a, b, __love_ofb(fl)));          /* netbsd's dup3 */
  if (__love_osv == 4) {
    if (dup2(a, b) < 0) return -1;
    return fl && fdfl(b, fl) < 0 ? (close(b), -1) : b; }
  return (int) er(sc3(NR_dup3, a, b, fl)); }

int flock(int fd, int op) { return (int) er(sc2(NR_flock, fd, op)); }   /* the LOCK_ bits agree */

/* glibc's, on fcntl's record locks from the offset on */
int lockf(int fd, int cmd, off_t len) {
  struct flock l = { 0 };
  l.l_whence = SEEK_CUR, l.l_start = 0, l.l_len = len, l.l_type = F_WRLCK;
  if (cmd == F_TEST) {
    l.l_type = F_RDLCK;
    if (fcntl(fd, F_GETLK, &l) < 0) return -1;
    if (l.l_type == F_UNLCK || l.l_pid == getpid()) return 0;
    errno = EACCES;
    return -1; }
  if (cmd == F_ULOCK) l.l_type = F_UNLCK;
  else if (cmd != F_LOCK && cmd != F_TLOCK) { errno = EINVAL; return -1; }
  return fcntl(fd, cmd == F_LOCK ? F_SETLKW : F_SETLK, &l); }
