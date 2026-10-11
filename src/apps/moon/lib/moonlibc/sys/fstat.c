#include "../impl.h"

#ifdef __i386__
/* i386 asks statx and lays its answer across: no stat64 call fills a 64-bit time */
static dev_t lxdev(unsigned int ma, unsigned int mi) {
  return (dev_t) ((mi & 0xff) | (ma << 8) | ((mi & ~0xffu) << 12)); }

int __love_statx(int dirfd, char const *p, int fl, struct stat *st) {
  struct __lx_statx sx;
  if (er(sc5(NR_statx, dirfd, (long) p, fl, STATX_BASIC_STATS, (long) &sx)) < 0) return -1;
  memset(st, 0, sizeof *st);
  st->st_dev = lxdev(sx.stx_dev_major, sx.stx_dev_minor);
  st->st_ino = sx.stx_ino;
  st->st_nlink = sx.stx_nlink;
  st->st_mode = sx.stx_mode;
  st->st_uid = sx.stx_uid;
  st->st_gid = sx.stx_gid;
  st->st_rdev = lxdev(sx.stx_rdev_major, sx.stx_rdev_minor);
  st->st_size = (off_t) sx.stx_size;
  st->st_blksize = sx.stx_blksize;
  st->st_blocks = (blkcnt_t) sx.stx_blocks;
  st->st_atim.tv_sec = sx.stx_atime.tv_sec;  st->st_atim.tv_nsec = sx.stx_atime.tv_nsec;
  st->st_mtim.tv_sec = sx.stx_mtime.tv_sec;  st->st_mtim.tv_nsec = sx.stx_mtime.tv_nsec;
  st->st_ctim.tv_sec = sx.stx_ctime.tv_sec;  st->st_ctim.tv_nsec = sx.stx_ctime.tv_nsec;
  return 0; }

int fstat(int fd, struct stat *st) { return __love_statx(fd, "", AT_EMPTY_PATH, st); }
#else

/* the freebsd branch fills the ino64 twin and translates -- shared with
 * stat.c/lstat.c through __love_fbstat (this member is their floor). */
void __love_fbstat(struct __fb_stat const *f, struct stat *st) {
  memset(st, 0, sizeof *st);
  st->st_dev = f->st_dev;
  st->st_ino = f->st_ino;
  st->st_nlink = f->st_nlink;
  st->st_mode = f->st_mode;
  st->st_uid = f->st_uid;
  st->st_gid = f->st_gid;
  st->st_rdev = f->st_rdev;
  st->st_size = f->st_size;
  st->st_blksize = f->st_blksize;
  st->st_blocks = f->st_blocks;
  st->st_atim = f->st_atim;
  st->st_mtim = f->st_mtim;
  st->st_ctim = f->st_ctim; }

/* ..and the netbsd twin (__fstat50's shape), same sharing */
void __love_nbstat(struct __nb_stat const *f, struct stat *st) {
  memset(st, 0, sizeof *st);
  st->st_dev = f->dev;
  st->st_ino = f->ino;
  st->st_nlink = f->nlink;
  st->st_mode = f->mode;
  st->st_uid = f->uid;
  st->st_gid = f->gid;
  st->st_rdev = f->rdev;
  st->st_size = f->size;
  st->st_blksize = f->blksize;
  st->st_blocks = f->blocks;
  st->st_atim.tv_sec = f->atime;  st->st_atim.tv_nsec = f->atimensec;
  st->st_mtim.tv_sec = f->mtime;  st->st_mtim.tv_nsec = f->mtimensec;
  st->st_ctim.tv_sec = f->ctime;  st->st_ctim.tv_nsec = f->ctimensec; }

int fstat(int fd, struct stat *st) {
  if (__love_osv == 2) {
    struct __fb_stat f;
    long r = er(sc2(NR_fstat, fd, (long) &f));
    if (r >= 0) __love_fbstat(&f, st);
    return (int) r; }
  if (__love_osv == 3) {
    struct __nb_stat f;
    long r = er(sc2(NR_fstat, fd, (long) &f));
    if (r >= 0) __love_nbstat(&f, st);
    return (int) r; }
  return (int) er(sc2(NR_fstat, fd, (long) st)); }
#endif
