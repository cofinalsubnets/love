#include "../impl.h"
#include <dirent.h>
#include <sys/stat.h>

/* the device file in dir whose rdev is the fd's, into b */
static int tyscan(char const *dir, struct stat const *fs, char *b, size_t n) {
  DIR *d = opendir(dir);
  if (!d) return ENOTTY;
  char p[256];
  int e = ENOTTY;
  for (struct dirent *de; e == ENOTTY && (de = readdir(d)); ) {
    struct stat s;
    if (de->d_name[0] == '.') continue;
    if ((size_t) snprintf(p, sizeof p, "%s/%s", dir, de->d_name) >= sizeof p) continue;
    if (stat(p, &s) || !S_ISCHR(s.st_mode) || s.st_rdev != fs->st_rdev) continue;
    e = strlen(p) < n ? (strcpy(b, p), 0) : ERANGE; }
  closedir(d);
  return e; }

/* a terminal's path into b: 0, EBADF, ENOTTY off a terminal, ERANGE short. linux reads
 * /proc's link and checks the device is the fd's; the BSDs scan /dev/pts and /dev */
int ttyname_r(int fd, char *b, size_t n) {
  struct stat fs, s;
  if (fstat(fd, &fs) < 0) return errno;
  if (!isatty(fd)) return ENOTTY;
  if (__love_osv < 2) {
    char lp[32], t[256];
    snprintf(lp, sizeof lp, "/proc/self/fd/%d", fd);
    long l = readlink(lp, t, sizeof t - 1);
    if (l > 0) {
      t[l] = 0;
      if (!stat(t, &s) && s.st_rdev == fs.st_rdev && s.st_ino == fs.st_ino) {
        if ((size_t) l >= n) return ERANGE;
        memcpy(b, t, (size_t) l + 1);
        return 0; } } }
  int e = tyscan("/dev/pts", &fs, b, n);
  return e == ENOTTY ? tyscan("/dev", &fs, b, n) : e; }
/* ..and into libc's own */
char *ttyname(int fd) {
  static char nb[128];
  int e = ttyname_r(fd, nb, sizeof nb);
  return e ? (errno = e, (char *) 0) : nb; }
