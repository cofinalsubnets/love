#include "../impl.h"

/* birth time: 0 filled | 1 none kept | -1, errno set. the BSDs keep it in stat, where
 * none reads as a date (freebsd -1, netbsd 0); linux needs statx */
int __love_birth(char const *p, int follow, struct timespec *out) {
#ifdef LvOsTranslate
  if (__love_osv == 2) {
    struct __fb_stat f;
    if (er(sc4(NR_newfstatat, AT_FDCWD, (long) p, (long) &f, follow ? 0 : 0x200)) < 0) return -1;
    if (f.st_birthtim.tv_sec < 0) return 1;
    return *out = f.st_birthtim, 0; }
  if (__love_osv == 3) {
    struct __nb_stat f;
    if (er(sc4(NR_newfstatat, AT_FDCWD, (long) p, (long) &f, follow ? 0 : 0x200)) < 0) return -1;
    if (!f.btime) return 1;
    out->tv_sec = f.btime, out->tv_nsec = f.btimensec;
    return 0; }
#endif
  { struct __lx_statx sx;
    long fl = follow ? 0 : AT_SYMLINK_NOFOLLOW;
    if (er(sc5(NR_statx, AT_FDCWD, (long) p, fl | AT_STATX_SYNC_AS_STAT,
               STATX_BTIME, (long) &sx)) < 0) return -1;
    if (!(sx.stx_mask & STATX_BTIME)) return 1;
    out->tv_sec = sx.stx_btime.tv_sec, out->tv_nsec = sx.stx_btime.tv_nsec;
    return 0; } }
