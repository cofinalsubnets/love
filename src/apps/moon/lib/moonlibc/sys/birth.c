#include "../impl.h"


/* the birth time, which no struct stat here has a place for: the BSDs and macos carry
 * it in the stat they already do, linux needs statx. 0 filled | 1 none kept | -1, errno set.
 * "none" READS AS A DATE on both BSDs -- freebsd VNOVAL (-1, 1969), netbsd 0 (1970, an
 * FFSv1 inode having no field) -- and nofollow is 0x200 there where linux's is 0x100. */
int __love_birth(char const *p, int follow, struct timespec *out) {
#ifdef LvOsTranslate
  if (__love_osv == 2) {
    struct __fb_stat f;
    if (er(sc4(NR_newfstatat, AT_FDCWD, (long) p, (long) &f, follow ? 0 : 0x200)) < 0) return -1;
    if (f.st_birthtim.tv_sec < 0) return 1;
    return *out = __love_fbts(f.st_birthtim), 0; }
  if (__love_osv == 4) {
    struct __mac_stat f;
    if (er(sc4(NR_newfstatat, AT_FDCWD, (long) p, (long) &f, follow ? 0 : 0x200)) < 0) return -1;
    if (f.btim.tv_sec <= 0) return 1;
    return *out = f.btim, 0; }
  if (__love_osv == 3) {
    struct __nb_stat f;
    if (er(sc4(NR_newfstatat, AT_FDCWD, (long) p, (long) &f, follow ? 0 : 0x200)) < 0) return -1;
    if (!f.btim.tv_sec) return 1;
    return *out = __love_nbts(f.btim), 0; }
#endif
  { struct __lx_statx sx;                 /* linux; a seat whose door lacks the number refuses */
    long fl = follow ? 0 : AT_SYMLINK_NOFOLLOW;
    if (er(sc5(NR_statx, AT_FDCWD, (long) p, fl | AT_STATX_SYNC_AS_STAT,
               STATX_BTIME, (long) &sx)) < 0) return -1;
    if (!(sx.stx_mask & STATX_BTIME)) return 1;
    out->tv_sec = sx.stx_btime.tv_sec, out->tv_nsec = sx.stx_btime.tv_nsec;
    return 0; } }
