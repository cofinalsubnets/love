#include "../impl.h"

/* linux's statx buffer, read here and nowhere else: the mask and stx_btime, the tail
 * the kernel's. it lives in this member because impl.h is parsed by every board too. */
#define STATX_BTIME            2048
#define AT_STATX_SYNC_AS_STAT     0
struct __lx_stxts { long tv_sec; unsigned int tv_nsec, __r; };
struct __lx_statx {
  unsigned int stx_mask, stx_blksize;
  unsigned long stx_attributes;
  unsigned int stx_nlink, stx_uid, stx_gid;
  unsigned short stx_mode, __p0;
  unsigned long stx_ino, stx_size, stx_blocks, stx_attributes_mask;
  struct __lx_stxts stx_atime, stx_btime, stx_ctime, stx_mtime;
  unsigned long __rest[16];           /* rdev/dev pairs, mnt id, dio -- unread here */
};
_Static_assert(sizeof(struct __lx_statx) == 256, "statx buffer is the kernel's 256");

/* the birth time, which no struct stat here has a seat for: the BSDs carry it in the
 * stat they already do, linux needs statx. 0 filled | 1 none kept | -1, errno set.
 * "none" READS AS A DATE on both BSDs -- freebsd VNOVAL (-1, 1969), netbsd 0 (1970, an
 * FFSv1 inode having no field) -- and nofollow is 0x200 there where linux's is 0x100. */
int __ai_birth(char const *p, int follow, struct timespec *out) {
  if (__ai_osv == 2) {
    struct __fb_stat f;
    if (er(sc4(NR_newfstatat, AT_FDCWD, (long) p, (long) &f, follow ? 0 : 0x200)) < 0) return -1;
    if (f.st_birthtim.tv_sec < 0) return 1;
    return *out = f.st_birthtim, 0; }
  if (__ai_osv == 3) {
    struct __nb_stat f;
    if (er(sc4(NR_newfstatat, AT_FDCWD, (long) p, (long) &f, follow ? 0 : 0x200)) < 0) return -1;
    if (!f.btime) return 1;
    out->tv_sec = f.btime, out->tv_nsec = f.btimensec;
    return 0; }
  { struct __lx_statx sx;                 /* linux; a seat whose door lacks the number refuses */
    long fl = follow ? 0 : AT_SYMLINK_NOFOLLOW;
    if (er(sc5(NR_statx, AT_FDCWD, (long) p, fl | AT_STATX_SYNC_AS_STAT,
               STATX_BTIME, (long) &sx)) < 0) return -1;
    if (!(sx.stx_mask & STATX_BTIME)) return 1;
    out->tv_sec = sx.stx_btime.tv_sec, out->tv_nsec = sx.stx_btime.tv_nsec;
    return 0; } }
