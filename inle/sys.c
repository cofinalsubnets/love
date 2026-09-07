// inle/sys.c -- inle's syscall door, and the whole of it. nolibc's 76 sys/* members reach
// one seam (impl.h's sc0..sc6 -> __ai_call), and __ai_call parts its callers by __ai_osv:
// a hosted kernel takes the mksys.l lay that issues `syscall` or `svc`, a negative osv --
// written at kmain, where we are the kernel -- takes __ai_inle, this file's C answer.
// the numbers are linux's, per arch, straight off impl.h's NR_*: the tree carries those
// tables already and inle owes compatibility to nobody, so nothing is translated.
// an unmapped number answers -ENOSYS, the same refusal mount and unshare wear off linux.
#include "../apps/moon/lib/nolibc/impl.h"
#include <stdint.h>

// the C runtime is nolibc's core.c: errno, the streams, the mmap-arena malloc. what a
// hosted __ai_start would arm the kernel arms here -- an empty environment and the std
// streams write-through on fds 1 and 2 at cap 0. a task's C-level printf reaches the
// console where its own port reaches the pipe. kmain calls this after the osv.
static char *k_env0[] = { 0 };
void k_seat_init(void) {
  environ = k_env0;
  stdout->fd = 1; stdout->wr = 1;
  stderr->fd = 2; stderr->wr = 1; }

// the kernel side (kmain.c): a raw fd through the k_sources row, no port above it. an fd
// spelled in love is an absolute row, exactly as a real kernel's trap number is already
// the calling process's own -- redirection lives in the port a task wears, never here.
// the divergence that buys, named so it is not rediscovered as a bug: a task spelling
// `write(1, ..)` reaches row 1 where POSIX would reach whatever its parent handed it.
// nothing does -- love's stdio goes through the folded ports and posix.c touches an
// implicit fd only at three terminal-control calls.
// the kernel free list (kmain.c), the page supply under the mmap arm below
extern void *kmallocw(uintptr_t n), kfree(void *p);

// the ramfs path faces (kmain.c), each 0 or a negative errno. k_st is what the ramfs knows
// about a path; ino/nlink/uid/dev have no answer down there and are invented in the stat
// arm below, where the invention shows.
struct k_st { uintptr_t size, ms, mode; };
extern int
 k_fs_open(char const *p, uintptr_t pn, char m),
 k_fs_stat(char const *p, uintptr_t pn, struct k_st *st),
 k_fs_mkdir(char const *p, uintptr_t pn, uintptr_t mode),
 k_fs_rmdir(char const *p, uintptr_t pn),
 k_fs_unlink(char const *p, uintptr_t pn),
 k_fs_rename(char const *o, uintptr_t on, char const *n, uintptr_t nn),
 k_fs_symlink(char const *t, uintptr_t tn, char const *p, uintptr_t pn),
 k_fs_chdir(char const *p, uintptr_t pn),
 k_fs_getcwd(char *b, uintptr_t n),
 k_fs_chmod(char const *p, uintptr_t pn, uintptr_t mode),
 k_fs_utime(char const *p, uintptr_t pn, uintptr_t ms);
// readlink alone answers a COUNT and not a status, so it stands outside the block.
extern intptr_t k_fs_readlink(char const *p, uintptr_t pn, char *b, uintptr_t n);
extern uintptr_t k_clock_ms(void);     // ms since the epoch, the kernel's one scale

// the fd faces (kmain.c), g-free by construction: rows, pipe queues and the dents cursor
// are kernel memory. what g knows -- which task runs -- never crosses this seam, since the
// syscall door is the process's and per-task questions stay with the nifs.
extern long
 k_fd_pipe(int fds[2]),
 k_fd_dup(int src, int at),
 k_fd_dup3(int src, int dst),
 k_fd_stat(int fd, struct k_st *st),
 k_fd_dents(int fd, void *buf, long cap),
 k_fs_opendir(char const *p, uintptr_t pn),
 k_fd_write(int fd, void const *b, long n),
 k_fd_read(int fd, void *b, long n),
 k_fd_close(int fd),
 k_fd_lseek(int fd, long off, int whence);

// a dirfd is honored as AT_FDCWD only: the ramfs has one cwd, and an absolute
// path ignores its dirfd by POSIX's own rule. any other seat refuses loudly.
static long at_ok(long dfd, char const *p) {
  if (!p) return -EFAULT;
  return (dfd == AT_FDCWD || p[0] == '/') ? 0 : -ENOTSUP; }

static long k_openat(long dfd, char const *p, long fl, long mode) {   // mode is not ours:
  long r = at_ok(dfd, p);                                            // the ramfs mints 0644
  if (r) return r;
  long acc = fl & 3;
  if (fl & O_DIRECTORY) {                       // opendir's lane, read-only by nature
    if (acc != O_RDONLY) return -EINVAL;
    return k_fs_opendir(p, strlen(p)); }
  char m = acc == O_RDONLY ? 'r'
         : acc != O_WRONLY ? 0
         : (fl & O_APPEND) ? 'a' : 'w';
  if (!m) return -EINVAL;                       // the ramfs has no O_RDWR door
  r = k_fs_open(p, strlen(p), m);
  // POSIX opens a directory read-only; the face keeps its 'r' misses cheap
  // (one k_find), so the directory answer is assembled on this slow path --
  // -EISDIR for an explicit entry, a stat for a synthesized one.
  if (r == -EISDIR && m == 'r') return k_fs_opendir(p, strlen(p));
  if (r == -ENOENT && m == 'r') {
    struct k_st t;
    if (!k_fs_stat(p, strlen(p), &t) && (t.mode & 040000))
      return k_fs_opendir(p, strlen(p)); }
  return r; }

// what the ramfs knows lands as it is; ino/nlink/uid/dev are invented here,
// where the invention shows. fstat and newfstatat share the one shape.
static void stat_fab(struct stat *st, struct k_st const *t) {
  *st = (struct stat) {0};
  st->st_mode = (unsigned) t->mode;
  st->st_nlink = 1;
  st->st_size = (long) t->size;
  st->st_blksize = 4096;
  st->st_blocks = (long) ((t->size + 511) / 512);
  st->st_mtim.tv_sec = (long) (t->ms / 1000);
  st->st_mtim.tv_nsec = (long) (t->ms % 1000) * 1000000;
  st->st_atim = st->st_ctim = st->st_mtim; }

static long k_statat(long dfd, char const *p, struct stat *st, long fl) {
 long r = at_ok(dfd, p);
 if (r || !st) return r ? r : -EFAULT;
 struct k_st t;
 if ((r = k_fs_stat(p, strlen(p), &t))) return r;
 stat_fab(st, &t);
 return 0; }

static long k_utimeat(long dfd, char const *p, struct timespec const *ts, long fl) {
 long r = at_ok(dfd, p);
 if (r) return r;
 uintptr_t ms;
 if (!ts || ts[1].tv_nsec == UTIME_NOW) ms = k_clock_ms();
 else if (ts[1].tv_nsec == UTIME_OMIT) return 0;   // nothing asked of the mtime
 else ms = (uintptr_t) ts[1].tv_sec * 1000 + (uintptr_t) ts[1].tv_nsec / 1000000;
 return k_fs_utime(p, strlen(p), ms); }


// the rows are exercised through the ordinary nifs, which issue them -- (open)
// openat, (stat) newfstatat and fstat, (readdir) getdents64, (dup) fcntl. the
// argument-refusal arms below have no caller in the tree: defensive, not covered.
long __ai_inle(long n, long a, long b, long c, long d, long e, long f) {
 long r;
 switch (n) {
  case NR_write: return k_fd_write((int) a, (void const*) b, c);
  case NR_read:  return k_fd_read((int) a, (void *) b, c);
  case NR_close: return k_fd_close((int) a);
  case NR_lseek: return k_fd_lseek((int) a, b, (int) c);
  case NR_openat:     return k_openat(a, (char const*) b, c, d);
  case NR_newfstatat: return k_statat(a, (char const*) b, (struct stat *) c, d);
  case NR_utimensat:  return k_utimeat(a, (char const*) b, (struct timespec const*) c, d);
  case NR_mkdirat:
   if ((r = at_ok(a, (char const*) b))) return r;
   return k_fs_mkdir((char const*) b, strlen((char const*) b), (uintptr_t) c & 07777);
  case NR_unlinkat:
   if ((r = at_ok(a, (char const*) b))) return r;
   return (c & AT_REMOVEDIR)
    ? k_fs_rmdir((char const*) b, strlen((char const*) b))
    : k_fs_unlink((char const*) b, strlen((char const*) b));
  case NR_symlinkat:                          // (target, dfd, linkpath)
   if (!a) return -EFAULT;
   if ((r = at_ok(b, (char const*) c))) return r;
   return k_fs_symlink((char const*) a, strlen((char const*) a),
                       (char const*) c, strlen((char const*) c));
  case NR_readlinkat:                         // (dfd, path, buf, size) -> the byte count
   if ((r = at_ok(a, (char const*) b))) return r;
   if (!c) return -EFAULT;
   return k_fs_readlink((char const*) b, strlen((char const*) b), (char*) c, (uintptr_t) d);
  case NR_renameat:
   if ((r = at_ok(a, (char const*) b)) || (r = at_ok(c, (char const*) d))) return r;
   return k_fs_rename((char const*) b, strlen((char const*) b),
                      (char const*) d, strlen((char const*) d));
  case NR_chdir:
   if (!a) return -EFAULT;
   return k_fs_chdir((char const*) a, strlen((char const*) a));
  case NR_getcwd:
   if (!a) return -EFAULT;
   if ((r = k_fs_getcwd((char*) a, (uintptr_t) b))) return r;
   return (long) strlen((char*) a) + 1;     // getcwd(2)'s answer: the length, NUL counted
  case NR_fchmodat:
   if ((r = at_ok(a, (char const*) b))) return r;
   return k_fs_chmod((char const*) b, strlen((char const*) b), (uintptr_t) c);
  case NR_pipe2:
   if (!a) return -EFAULT;
   if (b) return -EINVAL;                    // no close-on-exec where nothing execs
   return k_fd_pipe((int*) a);
  case NR_dup3:
   if (c) return -EINVAL;
   return k_fd_dup3((int) a, (int) b);
  case NR_fcntl:
   switch (b) {
    case F_DUPFD: return k_fd_dup((int) a, (int) c);
    case F_GETFD: case F_SETFD: case F_GETFL: {   // flag words this seat does not keep
     struct k_st t;
     return k_fd_stat((int) a, &t) ? -EBADF : 0; }
    default: return -EINVAL; }
  case NR_fstat: {
   if (!b) return -EFAULT;
   struct k_st t;
   if ((r = k_fd_stat((int) a, &t))) return r;
   stat_fab((struct stat*) b, &t);
   return 0; }
  case NR_getdents64:
   if (!b) return -EFAULT;
   return k_fd_dents((int) a, (void *) b, c);
  // the allocator's page door: nolibc's malloc runs its mmap arenas here as anywhere,
  // kmallocw supplying the pages. anonymous and kernel-placed only; the true base rides
  // the word below the aligned block, where munmap reads it back. zeroed, since
  // MAP_ANONYMOUS promises that and calloc's direct lane trusts it.
  case NR_mmap: {
   if (a || (int) e != -1 || b <= 0) return -38;         // ENOSYS: not our shape
   void *m = kmallocw(((uintptr_t) b + 2 * 4096) / sizeof(uintptr_t));
   if (!m) return -12;                                   // ENOMEM
   uintptr_t p = ((uintptr_t) m + sizeof(void *) + 4095) & ~4095ull;
   ((void **) p)[-1] = m;
   memset((void *) p, 0, (size_t) b);
   return (long) p; }
  case NR_munmap:
   if (!a || (a & 4095)) return -22;                     // EINVAL
   kfree(((void **) a)[-1]);
   return 0;
  // the map is not flat: mkboot.l puts NX on the hhdm and these are 2 MiB entries the
  // identity window shares, so nothing here lifts it off one page. R/W is what every heap
  // page already is, so answer that and refuse the exec ask rather than tell a caller
  // whose next move is a jump that it succeeded.
  case NR_mprotect: return (c & 4) ? -EACCES : 0;
  // one clock, the wall: ai_clock's body is clock_gettime now (host/posix.c),
  // so this arm is where the kernel's scale becomes a timespec.
  case NR_clock_gettime: {
   if (a) return -EINVAL;                    // CLOCK_REALTIME only
   if (!b) return -EFAULT;
   struct timespec *ts = (struct timespec *) b;
   uintptr_t ms = k_clock_ms();
   ts->tv_sec = (long) (ms / 1000);
   ts->tv_nsec = (long) (ms % 1000) * 1000000;
   return 0; }
  // inle is one process and love tasks are its threads, so getpid answers the machine's
  // constant. the task pid is love's question, and its nif keeps the g that holds it.
  case NR_getpid: return 1;
  default:       return -38; } }                       // ENOSYS, canonically
