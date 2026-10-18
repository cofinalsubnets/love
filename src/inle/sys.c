// src/inle/sys.c -- inle's syscall door: moonlibc's __love_call lands here when __love_osv < 0
// (set at kmain). the numbers are linux's per arch (impl.h's NR_*); an unmapped one is -ENOSYS
#include "../apps/moon/lib/moonlibc/impl.h"
#include <stdint.h>
#include <sys/utsname.h>

// what a hosted __love_start would arm: the environment (seat.l's envt starts as a copy) and
// stdout/stderr write-through on fds 1 and 2. kmain calls this after the osv
static char *k_env0[] = { "COLORTERM=truecolor", 0 };   // quay keeps 24-bit colour
void k_seat_init(void) {
  environ = k_env0;
  stdout->fd = 1; stdout->wr = 1;
  stderr->fd = 2; stderr->wr = 1; }

// a kernel-side fd is an absolute row: a task's `write(1, ..)` reaches row 1, not what its parent
// handed it; redirection lives in the task's ports. the faces below are kmain.c's
extern void *kmallocw(uintptr_t n), *kmallocwa(uintptr_t n, uintptr_t a), *k_grab(uintptr_t n);
extern void kfree(void *p), k_drop(void *p);

// the ramfs path faces, each 0 or a negative errno
struct k_st { uintptr_t size, ms, mode; };
extern int
 k_fs_open(char const *p, uintptr_t pn, char m),
 k_fs_stat(char const *p, uintptr_t pn, struct k_st *st, bool follow),
 k_fs_mkdir(char const *p, uintptr_t pn, uintptr_t mode),
 k_fs_rmdir(char const *p, uintptr_t pn),
 k_fs_unlink(char const *p, uintptr_t pn),
 k_fs_rename(char const *o, uintptr_t on, char const *n, uintptr_t nn),
 k_fs_symlink(char const *t, uintptr_t tn, char const *p, uintptr_t pn),
 k_fs_chdir(char const *p, uintptr_t pn),
 k_fs_getcwd(char *b, uintptr_t n),
 k_fs_chmod(char const *p, uintptr_t pn, uintptr_t mode),
 k_fs_utime(char const *p, uintptr_t pn, uintptr_t ms);
// readlink answers a count, not a status
extern intptr_t k_fs_readlink(char const *p, uintptr_t pn, char *b, uintptr_t n);
extern uintptr_t k_clock_ms(void);     // ms since the epoch, the kernel's one scale

// the fd faces, g-free: which task runs never crosses this seam
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
 k_fd_lseek(int fd, long off, int whence),
 k_fd_truncate(int fd, long n);

// a dirfd is honored as AT_FDCWD only: the ramfs has one cwd
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
         : (fl & O_APPEND) ? 'a'
         : (fl & O_TRUNC) ? 'w'
         : (fl & O_CREAT) ? 'c' : 'o';
  if (!m) return -EINVAL;                       // the ramfs has no O_RDWR door
  r = k_fs_open(p, strlen(p), m);
  // a directory opened read-only: the face keeps 'r' misses cheap, so it is found here,
  // -EISDIR for an explicit entry, a stat for a synthesized one
  if (r == -EISDIR && m == 'r') return k_fs_opendir(p, strlen(p));
  if (r == -ENOENT && m == 'r') {
    struct k_st t;
    if (!k_fs_stat(p, strlen(p), &t, true) && (t.mode & 040000))
      return k_fs_opendir(p, strlen(p)); }
  return r; }

// ino/nlink/uid/dev are invented here; the ramfs knows none of them
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
 // AT_SYMLINK_NOFOLLOW tells lstat from stat
 if ((r = k_fs_stat(p, strlen(p), &t, !(fl & AT_SYMLINK_NOFOLLOW)))) return r;
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


// the argument-refusal arms have no caller in the tree: defensive, not covered
static long k_term_ioctl(long pid, int kf, unsigned long q, void *arg);
long __love_inle(long n, long a, long b, long c, long d, long e, long f) {
 long r;
 switch (n) {
  case NR_write: return k_fd_write((int) a, (void const*) b, c);
  case NR_read:  return k_fd_read((int) a, (void *) b, c);
  case NR_close: return k_fd_close((int) a);
  case NR_lseek: return k_fd_lseek((int) a, b, (int) c);
  case NR_ftruncate: return k_fd_truncate((int) a, b);
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
  // riscv's only rename; any flag asks for semantics this fs lacks, so it is refused
  case NR_renameat2:
   if (e) return -EINVAL;
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
    case F_DUPFD: case F_DUPFD_CLOEXEC: return k_fd_dup((int) a, (int) c);   // nothing execs
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
  // malloc's arenas over kmallocwa: anonymous, kernel-placed, munmap frees the whole block.
  // zeroed, as MAP_ANONYMOUS promises and calloc trusts
  case NR_mmap: {
   if (a || (int) e != -1 || b <= 0) return -38;         // ENOSYS: not our shape
   void *p = kmallocwa(((uintptr_t) b + 4095) / 4096 * (4096 / sizeof(uintptr_t)), 4096);
   if (!p) return -12;                                   // ENOMEM
   memset(p, 0, (size_t) b);
   return (long) p; }
  case NR_munmap:
   if (!a || (a & 4095)) return -22;                     // EINVAL
   kfree((void *) a);
   return 0;
  // the hhdm is NX in 2 MiB entries shared with the exec window: every heap page is already
  // R/W, and an exec ask is refused rather than faked
  case NR_mprotect: return (c & 4) ? -EACCES : 0;
  // the one clock: love_clock (posix.c) reads it here
  case NR_clock_gettime: {
   if (a) return -EINVAL;                    // CLOCK_REALTIME only
   if (!b) return -EFAULT;
   struct timespec *ts = (struct timespec *) b;
   uintptr_t ms = k_clock_ms();
   ts->tv_sec = (long) (ms / 1000);
   ts->tv_nsec = (long) (ms % 1000) * 1000000;
   return 0; }
  // the kernel is one process, its tasks threads; a task's pid is its nif's
  case NR_getpid: return 1;
  case NR_ioctl: return k_term_ioctl(1, (int) a, (unsigned long) b, (void *) c);
  case NR_uname: {
   struct utsname *u = (struct utsname *) a;
   if (!u) return -EFAULT;
   memset(u, 0, sizeof *u);
   strcpy(u->sysname, "Inle");
   strcpy(u->nodename, "inle");
#if defined(__x86_64__)
   strcpy(u->machine, "x86_64");
#elif defined(__aarch64__)
   strcpy(u->machine, "aarch64");
#elif defined(__riscv)
   strcpy(u->machine, "riscv64");
#elif defined(__wasm__)
   strcpy(u->machine, "wasm32");
#endif
   return 0; }
  default:       return -38; } }                       // ENOSYS

// processes: a wasm instance, or on x64 an address space (x64/proc.c), calling k_proc_call.
// the kernel keeps its pid, parent, cwd and fds; status as wait4 lays it, the signal in the low byte
extern void k_fs_cwd_swap(char *cwd, uintptr_t *n);
extern bool k_fd_blocks(int fd);
extern int k_fd_term(int fd, int set, int *raw, uintptr_t *rows, uintptr_t *cols);
extern bool k_ready(int fd, int events);

#define k_proc_fds 64
struct k_proc { int pid, ppid, live, status, exitw; uint64_t cx, nb; uintptr_t cwd_n; char cwd[256];
                int fd[k_proc_fds];                 // the process's fd -> the kernel's, -1 none
                void *m; };                         // cx: close-on-exec, nb: nonblocking bits;
                                                    // m: the seat's machine
static struct k_proc *k_procs;
static int k_procs_n, k_pid_next = 2;               // pid 1 is the kernel's own answer

// a call that must wait: the seat holds it and asks again, the process none the wiser
#define K_RESTART -512

// the seat's doors: start pid's program on NUL-ended words, love's or code's -> -errno to refuse
__attribute__((weak)) long k_proc_start(long pid, char const *av, uintptr_t an,
                                        char const *ev, uintptr_t en,
                                        char const *code, uintptr_t cn) {
  return (void) pid, (void) av, (void) an, (void) ev, (void) en, (void) code, (void) cn, -ENOSYS; }
__attribute__((weak)) void k_proc_stop(long pid) { (void) pid; }
__attribute__((weak)) long k_proc_run(void *m) { return (void) m, 0; }
__attribute__((weak)) void k_proc_drop(void *m) { (void) m; }

static struct k_proc *k_proc_of(long pid) {
  for (int i = 0; i < k_procs_n; i++) if (k_procs[i].pid == pid) return &k_procs[i];
  return NULL; }

// where the seat keeps pid's machine
void **k_proc_seat(long pid) {
  struct k_proc *p = k_proc_of(pid);
  return p ? &p->m : NULL; }

// a record reaped while its machine is held stays taken until the pump lets it go
static struct k_proc *k_proc_slot(void) {
  for (int i = 0; i < k_procs_n; i++) if (!k_procs[i].pid && !k_procs[i].m) return &k_procs[i];
  int m = k_procs_n ? 2 * k_procs_n : 8;
  struct k_proc *t = k_grab((uintptr_t) m * sizeof *t);
  if (!t) return NULL;
  for (int i = 0; i < m; i++) t[i] = i < k_procs_n ? k_procs[i] : (struct k_proc) {0};
  k_drop(k_procs);
  struct k_proc *p = &t[k_procs_n];
  k_procs = t, k_procs_n = m;
  return p; }

static void k_pbit(uint64_t *m, long fd, bool on) { *m = on ? *m | 1ull << fd : *m & ~(1ull << fd); }
static void k_pcx(struct k_proc *p, long fd, bool on) { k_pbit(&p->cx, fd, on); }

// kf at the lowest free fd from `at`; with none, kf closed and -EMFILE
static long k_pfd_put(struct k_proc *p, long kf, long at, bool cx) {
  if (kf < 0) return kf;
  for (long i = at < 0 ? 0 : at; i < k_proc_fds; i++)
    if (p->fd[i] < 0) return p->fd[i] = (int) kf, k_pcx(p, i, cx), k_pbit(&p->nb, i, 0), i;
  k_fd_close((int) kf);
  return -EMFILE; }

static long k_pfd(struct k_proc const *p, long fd) {
  return fd >= 0 && fd < k_proc_fds ? p->fd[fd] : -1; }

// the exit pipe's close wakes the task standing in for the process; orphans are reaped by none
static void k_proc_end(struct k_proc *p, int status) {
  for (int i = 0; i < k_proc_fds; i++) if (p->fd[i] >= 0) k_fd_close(p->fd[i]), p->fd[i] = -1;
  p->live = 0, p->status = status, p->cx = p->nb = 0;
  if (p->exitw >= 0) k_fd_close(p->exitw), p->exitw = -1;
  for (int i = 0; i < k_procs_n; i++) {
    struct k_proc *q = &k_procs[i];
    if (q->pid && q != p && q->ppid == p->pid) q->live ? (q->ppid = 0) : (q->pid = 0); }
  if (!p->ppid) p->pid = 0; }

// path's bytes under p's cwd when they are a program here (wasm, or ELF on metal), else NULL
static char *k_proc_code(struct k_proc *p, char const *path, uintptr_t pn, uintptr_t *n) {
#if defined(__wasm__)
  static unsigned char const magic[4] = { 0, 'a', 's', 'm' };
#else
  static unsigned char const magic[4] = { 0x7f, 'E', 'L', 'F' };
#endif
  unsigned char h[4];
  struct k_st st;
  char *b = NULL;
  k_fs_cwd_swap(p->cwd, &p->cwd_n);
  int fd = k_fs_stat(path, pn, &st, true) || (st.mode & 040000) || st.size < 8 ? -1 : k_fs_open(path, pn, 'r');
  if (fd >= 0 && k_fd_read(fd, h, 4) == 4 && !memcmp(h, magic, 4)
      && (b = kmallocw((st.size + sizeof(uintptr_t) - 1) / sizeof(uintptr_t)))) {
    memcpy(b, h, 4);
    uintptr_t at = 4;
    for (long r = 1; at < st.size && r > 0; at += r > 0 ? (uintptr_t) r : 0)
      r = k_fd_read(fd, b + at, (long) (st.size - at));
    if (at < st.size) kfree(b), b = NULL;
    *n = at; }
  if (fd >= 0) k_fd_close(fd);
  k_fs_cwd_swap(p->cwd, &p->cwd_n);
  return b; }

// a path to a program runs as itself; anything else, a bare word above all, is love's,
// woken from /proc/image where there is one
static long k_proc_go(struct k_proc *p, char const *f, char const *av, uintptr_t an,
                      char const *ev, uintptr_t en) {
  uintptr_t cn = 0, fn = strlen(f);
  char *code = memchr(f, '/', fn) ? k_proc_code(p, f, fn, &cn) : NULL;
  if (code) {
    long r = k_proc_start(p->pid, av, an, ev, en, code, cn);
    kfree(code);
    return r; }
  static char const wake[] = "love\0wake\0/proc/image";
  struct k_st st;
  uintptr_t a0 = an ? strlen(av) + 1 : 0,
            pn = k_fs_stat("/proc/image", 11, &st, true) ? 5 : sizeof wake, n = pn + fn + 1 + an - a0;
  char *b = k_grab(n);
  if (!b) return -ENOMEM;
  memcpy(b, wake, pn), memcpy(b + pn, f, fn + 1), memcpy(b + pn + fn + 1, av + a0, an - a0);
  long r = k_proc_start(p->pid, b, n, ev, en, NULL, 0);
  k_drop(b);
  return r; }

// a turn for each process -> 0 none, 1 all waiting, 2 one wants another turn. a turn may
// spawn, and the table move under it
long k_proc_pump(void) {
  long r = 0;
  for (int i = 0; i < k_procs_n; i++) {
    void *m = k_procs[i].m;
    if (!m) continue;
    long t = k_procs[i].live ? k_proc_run(m) : 0;
    if (!k_procs[i].live) k_proc_drop(m), k_procs[i].m = NULL;
    else r = r > t ? r : t ? t : 1; }
  return r; }

// -> its pid, *wr the read end of the pipe that ends when it does; -errno to refuse
long k_proc_new(char const *av, uintptr_t an, char const *ev, uintptr_t en,
                int const fds[3], int *wr) {
  struct k_proc *p = k_proc_slot();
  if (!p) return -ENOMEM;
  *p = (struct k_proc) { .pid = k_pid_next, .ppid = 1, .live = 1, .exitw = -1 };
  for (int i = 0; i < k_proc_fds; i++) p->fd[i] = -1;
  char b[258];
  if (k_fs_getcwd(b, sizeof b)) b[0] = '/', b[1] = 0;
  p->cwd_n = strlen(b + 1), memcpy(p->cwd, b + 1, p->cwd_n);
  int w[2] = { -1, -1 };
  long r = k_fd_pipe(w);
  if (!r) p->exitw = w[1];
  for (int i = 0; !r && i < 3; i++) {
    long kf = k_fd_dup(fds[i], 3);
    if (kf < 0) r = kf;
    else p->fd[i] = (int) kf; }
  if (!r) r = an ? k_proc_go(p, av, av, an, ev, en) : -EINVAL;
  if (r) {
    k_proc_end(p, 0);
    if (w[0] >= 0) k_fd_close(w[0]);
    p->pid = 0;
    return r; }
  *wr = w[0];
  return k_pid_next++; }

// -> the status as a shell reads it, the slot freed; -EAGAIN while it runs
long k_proc_reap(long pid) {
  struct k_proc *p = k_proc_of(pid);
  if (!p) return -ECHILD;
  if (p->live) return -EAGAIN;
  p->pid = 0;
  return p->status & 0x7f ? 128 + (p->status & 0x7f) : p->status >> 8 & 255; }

// posix_spawn's actions, (op fd src) triples, 1 a dup2 and 2 a close; then close-on-exec
static long k_proc_acts(struct k_proc *q, int const *op, long n) {
  for (long i = 0; i < n; i++, op += 3) {
    int fd = op[1], src = op[2];
    if (fd < 0 || fd >= k_proc_fds) return -EBADF;
    if (op[0] == 2) { if (q->fd[fd] >= 0) k_fd_close(q->fd[fd]), q->fd[fd] = -1, k_pcx(q, fd, 0); continue; }
    if (op[0] != 1 || src < 0 || src >= k_proc_fds || q->fd[src] < 0) return -EBADF;
    if (src != fd) {
      long kf = k_fd_dup(q->fd[src], 3);
      if (kf < 0) return kf;
      if (q->fd[fd] >= 0) k_fd_close(q->fd[fd]);
      q->fd[fd] = (int) kf;
      k_pbit(&q->nb, fd, q->nb >> src & 1); }
    k_pcx(q, fd, 0); }
  for (int i = 0; i < k_proc_fds; i++)
    if (q->cx >> i & 1 && q->fd[i] >= 0) k_fd_close(q->fd[i]), q->fd[i] = -1;
  q->cx = 0;
  return 0; }

// w: the file, then argv -> the child's pid
static long k_proc_spawn(long pid, char const *w, long wn, char const *ev, long en,
                         int const *op, long on) {
  if (!w || wn < 1 || w[wn - 1] || (en && (!ev || ev[en - 1]))) return -EINVAL;
  long fn = (long) strlen(w) + 1;
  struct k_proc *q = k_proc_slot(), *p = k_proc_of(pid);   // the slot may move the table
  if (!q) return -ENOMEM;
  *q = (struct k_proc) { .pid = k_pid_next, .ppid = p->pid, .live = 1, .exitw = -1,
                         .cx = p->cx, .nb = p->nb, .cwd_n = p->cwd_n };
  memcpy(q->cwd, p->cwd, p->cwd_n);
  long r = 0;
  for (int i = 0; i < k_proc_fds; i++) {
    long kf = p->fd[i] < 0 || r ? -1 : k_fd_dup(p->fd[i], 3);
    if (kf < -1) r = kf;
    q->fd[i] = kf < 0 ? -1 : (int) kf; }
  if (!r) r = k_proc_acts(q, op, on / 12);
  if (!r) r = k_proc_go(q, w, w + fn, (uintptr_t) (wn - fn), ev, (uintptr_t) en);
  if (r) { q->ppid = 1, k_proc_end(q, 0), q->pid = 0; return r; }
  return k_pid_next++; }

// the console and a pty keep only raw or cooked and their size
static long k_term_ioctl(long pid, int kf, unsigned long q, void *arg) {
  int raw;
  uintptr_t rows, cols;
  long r = k_fd_term(kf, -1, &raw, &rows, &cols);
  if (r) return r;
  if (!arg) return -EFAULT;
  switch (q) {
   case 21505: {                                     // TCGETS
    struct termios *t = arg;
    *t = (struct termios) { .c_iflag = raw ? 0 : ICRNL, .c_oflag = OPOST, .c_cflag = 0277,
                            .c_lflag = raw ? 0 : ISIG | ICANON | ECHO | IEXTEN };
    t->c_cc[0] = 3, t->c_cc[2] = 127, t->c_cc[4] = 4, t->c_cc[VMIN] = 1;   // VINTR VERASE VEOF
    return 0; }
   case 21506: case 21507: case 21508:               // TCSETS, TCSETSW, TCSETSF
    return k_fd_term(kf, !(((struct termios*) arg)->c_lflag & ICANON), &raw, &rows, &cols);
   case TIOCGWINSZ:
    *(struct winsize*) arg = (struct winsize) { (unsigned short) rows, (unsigned short) cols, 0, 0 };
    return 0;
   case TIOCSWINSZ: return 0;
   case 21519: *(int*) arg = (int) pid; return 0;   // TIOCGPGRP: the process leads its own
   case 21520: return 0;                             // TIOCSPGRP
   default: return -EINVAL; } }

// a process's call, its pointers already in kernel memory. ppoll's third word is whether it may
// wait, not a timeout: the seat keeps the clock and asks with 0 past the deadline
long k_proc_call(long pid, long n, long a, long b, long c, long d, long e, long f) {
  struct k_proc *p = k_proc_of(pid);
  if (!p || !p->live) return -ESRCH;
  long kf = k_pfd(p, a), r;
  switch (n) {
   case NR_exit: case NR_exit_group: k_proc_end(p, (int) (a & 255) << 8); return 0;
   case NR_getpid: return p->pid;
   case 110: return p->ppid ? p->ppid : 1;           // getppid: an orphan's is the kernel
   case NR_inle_spawn:
    return k_proc_spawn(pid, (char const*) a, b, (char const*) c, d, (int const*) e, f);
   case NR_wait4: {                                  // a child, or any; WNOHANG asks without waiting
    bool kids = false;
    for (int i = 0; i < k_procs_n; i++) {
     struct k_proc *q = &k_procs[i];
     if (!q->pid || q == p || q->ppid != p->pid || (a > 0 && q->pid != a)) continue;
     if (q->live) { kids = true; continue; }
     if (b) *(int*) b = q->status;
     r = q->pid, q->pid = 0;
     return r; }
    return !kids ? -ECHILD : c & 1 ? 0 : K_RESTART; }
   case NR_kill: {                                   // a group is its leader's pid
    struct k_proc *q = !a ? p : k_proc_of(a < 0 ? -a : a);
    if (!q || !q->live) return -ESRCH;
    if (b < 0 || b > 64) return -EINVAL;
    if (!b || b == 17 || b == 18 || b == 28 || (19 <= b && b <= 23)) return 0;   // none ends it
    k_proc_stop(q->pid);
    k_proc_end(q, (int) b);
    return 0; }
   case NR_mmap: case NR_munmap: case NR_mprotect: return -ENOSYS;   // its memory is its own
   case NR_read:
    if (kf < 0) return -EBADF;
    if (k_fd_blocks((int) kf)) return p->nb >> a & 1 ? -EAGAIN : K_RESTART;
    return k_fd_read((int) kf, (void*) b, c);
   case NR_write:
    if (kf < 0) return -EBADF;
    r = k_fd_write((int) kf, (void const*) b, c);
    return !r && c > 0 ? (p->nb >> a & 1 ? -EAGAIN : K_RESTART) : r;
   case NR_close:
    if (kf < 0) return -EBADF;
    p->fd[a] = -1, k_pcx(p, a, 0), k_pbit(&p->nb, a, 0);
    return k_fd_close((int) kf);
   case NR_lseek: case NR_ftruncate: case NR_fstat: case NR_getdents64:
    return kf < 0 ? -EBADF : __love_inle(n, kf, b, c, d, e, f);
   case NR_fcntl:
    if (kf < 0) return -EBADF;
    if (b == F_DUPFD || b == F_DUPFD_CLOEXEC) return k_pfd_put(p, k_fd_dup((int) kf, 3), c, b != F_DUPFD);
    if (b == F_GETFD) return p->cx >> a & 1;
    if (b == F_SETFL) return k_pbit(&p->nb, a, c & O_NONBLOCK), 0;
    if (b == F_GETFL) {
     r = __love_inle(n, kf, b, c, d, e, f);
     return r < 0 ? r : (r & ~O_NONBLOCK) | (p->nb >> a & 1 ? O_NONBLOCK : 0); }
    if (b == F_SETFD) return k_pcx(p, a, c & FD_CLOEXEC), 0;
    return __love_inle(n, kf, b, c, d, e, f);
   case NR_dup3:
    if (kf < 0 || b < 0 || b >= k_proc_fds) return -EBADF;
    if (a == b || c & ~O_CLOEXEC) return -EINVAL;
    if ((r = k_fd_dup((int) kf, 3)) < 0) return r;
    if (p->fd[b] >= 0) k_fd_close(p->fd[b]);
    return p->fd[b] = (int) r, k_pcx(p, b, c), k_pbit(&p->nb, b, p->nb >> a & 1), b;
   case NR_pipe2: {
    if (!a) return -EFAULT;
    if (b & ~(O_CLOEXEC | O_NONBLOCK)) return -EINVAL;
    int k[2];
    if ((r = k_fd_pipe(k))) return r;
    long r0 = k_pfd_put(p, k[0], 0, b & O_CLOEXEC), r1 = r0 < 0 ? (k_fd_close(k[1]), r0) : k_pfd_put(p, k[1], 0, b & O_CLOEXEC);
    if (r1 < 0) { if (r0 >= 0) p->fd[r0] = -1, k_fd_close(k[0]); return r1; }
    k_pbit(&p->nb, r0, b & O_NONBLOCK), k_pbit(&p->nb, r1, b & O_NONBLOCK);
    ((int*) a)[0] = (int) r0, ((int*) a)[1] = (int) r1;
    return 0; }
   case NR_ioctl: return kf < 0 ? -EBADF : k_term_ioctl(p->pid, (int) kf, (unsigned long) b, (void*) c);
   case NR_ppoll: {
    struct pollfd *q = (struct pollfd*) a;
    long k = 0;
    for (long i = 0; i < b; i++) {
     long qf = k_pfd(p, q[i].fd);
     short ev = q[i].events, rv = 0;
     if (q[i].fd < 0) { q[i].revents = 0; continue; }
     if (qf < 0) rv = POLLNVAL;
     else {
      if ((ev & POLLIN) && k_ready((int) qf, POLLIN)) rv |= POLLIN;   // love's wait_in is poll's own 1
      if (ev & POLLOUT) rv |= POLLOUT; }
     q[i].revents = rv;
     k += !!rv; }
    return !k && c ? K_RESTART : k; }
   default:                                          // a path's call, under its own cwd
    k_fs_cwd_swap(p->cwd, &p->cwd_n);
    r = __love_inle(n, a, b, c, d, e, f);
    k_fs_cwd_swap(p->cwd, &p->cwd_n);
    if (n == NR_openat && r >= 0 && (r = k_pfd_put(p, r, 0, c & O_CLOEXEC)) >= 0)
     k_pbit(&p->nb, r, c & O_NONBLOCK);
    return r; } }
