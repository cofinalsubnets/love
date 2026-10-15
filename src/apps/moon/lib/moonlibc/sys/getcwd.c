#include "../impl.h"

/* glibc's: a null buffer is allocated -- size bytes, or as many as the name needs when size is 0 */
char *getcwd(char *b, unsigned long n) {
  if (!b) {
    char *m = malloc(n ? n : 4096);
    if (!m) return 0;
    if (!getcwd(m, n ? n : 4096)) { free(m); return 0; }
    if (!n) { char *t = realloc(m, strlen(m) + 1); if (t) m = t; }
    return m; }
  if (!n) { __errno_v = EINVAL; return 0; }
#ifdef LvMac
  if (__love_osv == 4) {                   /* no getcwd: the path of an open "." (F_GETPATH) */
    char p[1024];
    int fd = open(".", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0) return 0;
    long r = fb3(92, fd, 50, (long) p);
    close(fd);
    if (r < 0) { __errno_v = (int) -r; return 0; }
    if (strlen(p) >= n) { __errno_v = ERANGE; return 0; }
    return strcpy(b, p); }
#endif
  long r = sc2(NR_getcwd, (long) b, (long) n);
  if (r < 0) { __errno_v = (int) -r; return 0; }
  return b; }
