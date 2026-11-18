/* os.c -- one binary on linux, freebsd, netbsd and macos: the call door, its numbers and
 * errnos. wasm takes identity stubs */
#include "impl.h"

long __love_osv;         /* 0 unprobed, 1 linux, 2 freebsd, 3 netbsd, 4 macos, -1 inle */

long __love_call(long n, long a, long b, long c, long d, long e, long f) {
  long v = __love_osv;
  if (!v) v = __love_osv = __love_osdetect();
  if (v < 0) return __love_inle(n, a, b, c, d, e, f);   /* inle translates nothing, before the BSD read */
#ifdef __i386__
  if (v >= 2 && __love_tbsdn(n)) {
    long r = __love_tbsd(n, a, b, c, d, e, f);
    return __love_parked(r) ? -__love_errfb(-r - 4096) : r; }
#endif
  if (v >= 2) {
#ifdef LvMac
    if (v == 4) {                                     /* AT_FDCWD and the AT_ bits, in a copy: no arg's address is taken */
      long w[5] = {a, b, c, d, e};
      if (__love_macat(n, w)) a = w[0], b = w[1], c = w[2], d = w[3], e = w[4]; }
#endif
    n = __love_nrfb(n);
    if (n < 0) return -38;                            /* ENOSYS, canonically */
#ifdef LvMac
    if (v == 4) {
      long r = __love_door(n, a, b, c, d, e, f);
      if (r != LvNoDoor) return __love_parked(r) ? -__love_errfb(-r - 4096) : r; }
#endif
  }
#ifdef __ARM_EABI__
  if (v == 1 && __love_t32k && __love_t64(n)) return __love_t32(n, a, b, c, d, e, f);
#endif
  long r = __love_sys(n, a, b, c, d, e, f);
#ifdef __ARM_EABI__
  if (r == -38 && v == 1 && __love_t64(n)) __love_t32k = 1, r = __love_t32(n, a, b, c, d, e, f);
#endif
#ifdef LvOsTranslate                                     /* a parked BSD answer */
  if (__love_parked(r)) r = -__love_errfb(-r - 4096);
#endif
  if (r == -14 && __love_efault()) {                     /* EFAULT, and the address woke: again */
    r = __love_sys(n, a, b, c, d, e, f);
#ifdef LvOsTranslate
    if (__love_parked(r)) r = -__love_errfb(-r - 4096);
#endif
  }
  return r; }
long __love_fb(long n, long a, long b, long c, long d, long e, long f) {
#ifdef LvMac
  long r = __love_osv == 4 ? __love_door(n, a, b, c, d, e, f) : LvNoDoor;
  if (r == LvNoDoor) r = __love_sys(__love_osv == 4 ? n | LvMacUnix : n, a, b, c, d, e, f);
#else
  long r = __love_sys(n, a, b, c, d, e, f);
#endif
#ifdef LvOsTranslate
  return __love_parked(r) ? -__love_errfb(-r - 4096) : r; }
#else
  return r; }
#endif

/* inle's door, for a link without the kernel: ENOSYS. aligned for the jump a kernel patches in */
__attribute__((weak, aligned(16)))
long __love_inle(long n, long a, long b, long c, long d, long e, long f) {
  return -38; }

/* a refused address the program can make good: 1 retries the call */
__attribute__((weak))
int __love_efault(void) { return 0; }

#ifdef __ARM_EABI__
/* arm's *_time64 calls need linux 5.1: before it the 32-bit twin answers, records
 * narrowed and widened. a time past 2038 is EOVERFLOW */
int __love_t32k;

struct __ts32 { long s, ns; };
static int nar(long p, struct __ts32 *o, int n) {
  struct timespec const *t = (struct timespec const *) p;
  for (int i = 0; i < n; i++) {
    if (t[i].tv_sec != (long) t[i].tv_sec) return -75;
    o[i].s = (long) t[i].tv_sec, o[i].ns = t[i].tv_nsec; }
  return 0; }
static void wid(struct __ts32 const *o, long p) {
  struct timespec *t = (struct timespec *) p;
  t->tv_sec = o->s, t->tv_nsec = o->ns; }

long __love_t32(long n, long a, long b, long c, long d, long e, long f) {
  struct __ts32 o[2];
  long r;
  if (n == NR_clock_gettime) {
    r = __love_sys(NR_clock_gettime_32, a, (long) o, 0, 0, 0, 0);
    if (!r) wid(o, b);
    return r; }
  if (n == NR_clock_nanosleep) {
    if ((r = nar(c, o, 1))) return r;
    r = __love_sys(NR_clock_nanosleep_32, a, b, (long) o, d ? (long) (o + 1) : 0, 0, 0);
    if (r == -4 && d) wid(o + 1, d);                     /* EINTR: the time left */
    return r; }
  if (n == NR_ppoll || n == NR_pselect6) {
    long t = n == NR_ppoll ? c : e;
    if (t && (r = nar(t, o, 1))) return r;
    r = n == NR_ppoll ? __love_sys(NR_ppoll_32, a, b, t ? (long) o : 0, d, e, 0)
                      : __love_sys(NR_pselect6_32, a, b, c, d, t ? (long) o : 0, f);
    if (t && r >= 0) wid(o, t);
    return r; }
  if (n == NR_utimensat) {
    if (c && (r = nar(c, o, 2))) return r;
    return __love_sys(NR_utimensat_32, a, b, c ? (long) o : 0, d, 0, 0); }
  if (n == NR_futex) {
    if (d && ((b & 127) == 0 || (b & 127) == 9)) {     /* FUTEX_WAIT, _WAIT_BITSET: d is a time */
      if ((r = nar(d, o, 1))) return r;
      d = (long) o; }
    return __love_sys(NR_futex_32, a, b, c, d, e, f); }
  return -38; }

/* an android app's seccomp filter traps a call it does not list, new ones among them:
 * as on a kernel without it, the caller reads ENOSYS. 8 is r0 in arm's ucontext */
static void refused(int sig, void *si, long *uc) { uc[8] = -38; }
void __love_refusals(void) {
  struct __ksigaction ka = { (void *) refused, 4 };      /* SA_SIGINFO */
  __love_sys(NR_rt_sigaction, 31, (long) &ka, 0, 8, 0, 0); }
#endif

#ifdef __i386__
/* a timespec in a BSD's own shape: freebsd's 32-bit time_t cannot say past 2038, EOVERFLOW */
union __bts { __fbts f; __nbts n; };
static long bnar(long p, union __bts *o, int k) {
  struct timespec const *t = (struct timespec const *) p;
  for (int i = 0; i < k; i++) {
    if (__love_osv == 3) o[i].n.tv_sec = t[i].tv_sec, o[i].n.tv_nsec = (long) t[i].tv_nsec;
    else if (t[i].tv_sec != (int) t[i].tv_sec) return -75;
    else o[i].f.tv_sec = (int) t[i].tv_sec, o[i].f.tv_nsec = (long) t[i].tv_nsec; }
  return 0; }
static void bwid(union __bts const *o, long p) {
  *(struct timespec *) p = __love_osv == 3 ? __love_nbts(o->n) : __love_fbts(o->f); }

long __love_tbsd(long n, long a, long b, long c, long d, long e, long f) {
  union __bts o[2];
  long nr = __love_nrfb(n), r;
  if (nr < 0) return -38;
  if (n == NR_clock_gettime) {
    r = __love_sys(nr, a, (long) o, 0, 0, 0, 0);
    if (!r) bwid(o, b);
    return r; }
  if (n == NR_nanosleep) {
    if ((r = bnar(a, o, 1))) return r;
    r = __love_sys(nr, (long) o, b ? (long) (o + 1) : 0, 0, 0, 0, 0);
    if (b && __love_parked(r)) bwid(o + 1, b);           /* EINTR: the time left */
    return r; }
  if (n == NR_ppoll || n == NR_pselect6) {
    long t = n == NR_ppoll ? c : e;
    if (t && (r = bnar(t, o, 1))) return r;
    return n == NR_ppoll ? __love_sys(nr, a, b, t ? (long) o : 0, d, e, f)
                         : __love_sys(nr, a, b, c, d, t ? (long) o : 0, f); }
  if (c && (r = bnar(c, o, 2))) return r;                /* utimensat: two */
  return __love_sys(nr, a, b, c ? (long) o : 0, d, e, f); }
#endif

/* the running binary's path, which macos keeps out of any /proc: proc_info's
 * PROC_PIDPATHINFO. 0 on every other kernel, whose /proc or sysctl answers */
unsigned long __love_selfpath(char *b, unsigned long n) {
#ifdef LvMac
  if (__love_osv == 4) {
    char t[4096];
    memset(t, 0, sizeof t);
    if (__love_fb(336, 2, getpid(), 11, 0, (long) t, sizeof t) < 0) return 0;   /* pidinfo, pathinfo */
    unsigned long k = strlen(t);
    if (!k || k >= n) return 0;
    memcpy(b, t, k + 1);
    return k; }
#endif
  (void) b, (void) n;
  return 0; }

long __love_osdetect(void) {
#ifndef LvOsTranslate
  /* no tables on this arch: the kernel is whichever -os named */
# if defined(__linux__)
  return 1;
# elif defined(__FreeBSD__)
#  error "moonlibc: -os freebsd wants the translation tables, and this arch has no machine tail for them"
# elif defined(__NetBSD__)
#  error "moonlibc: -os netbsd wants the translation tables, and this arch has no machine tail for them"
# else
#  error "moonlibc: no OS predefine -- -os named a kernel os.c cannot speak for"
# endif
#else
  /* 20 is getpid on the BSDs and a refusal on linux; kern.ostype parts the BSDs
   * (__sysctl 202, {CTL_KERN, KERN_OSTYPE}). a64 and rv64 ask through impl.h's leaves,
   * where asking freebsd blind is SIGILL: crt0's entry parts it out first */
# if defined(__ARM_EABI__)
  /* crt0 parted netbsd out by the entry; close(-1) is -EBADF on linux, +EBADF on freebsd */
  return __love_sys(6, -1, 0, 0, 0, 0, 0) > 0 ? 2 : 1;
# elif defined(__i386__)
  /* crt0 asks only when ebx said a BSD: both take stack args, so the door is set first */
  __love_osv = 2;
  { int mib[2] = {1, 1};
    char b[16] = {0};
    unsigned long len = sizeof b;
    __love_sys(202, (long) mib, 2, (long) b, (long) &len, 0, 0);
    return b[0] == 'N' ? 3 : 2; }
# elif defined(__aarch64__) || defined(__riscv)
  long r = __love_nbp20(-1);
  if (r <= 0) return 1;
  { int mib[2] = {1, 1};
    char b[16] = {0};
    unsigned long len = sizeof b;
    __love_nbp202((long) mib, 2, (long) b, (long) &len, 0, 0);
    return b[0] == 'N' ? 3 : 2; }
# else
  long r = __love_sys(20, -1, 0, 0, 0, 0, 0);
  if (r <= 0) return 1;
  { int mib[2] = {1, 1};
    char b[16] = {0};
    unsigned long len = sizeof b;
    __love_sys(202, (long) mib, 2, (long) b, (long) &len, 0, 0);
    return b[0] == 'N' ? 3 : 2; }
# endif
#endif
}

#ifndef LvOsTranslate
long __love_nrfb(long n) { return n; }      /* no second kernel on this arch */
long __love_errfb(long e) { return e; }
#else
/* canonical -> {freebsd, netbsd, macos}; -1 refuses (ENOSYS), an absent call is linux's own.
 * netbsd's padded classics keep their numbers while the members slide the args */
static short const os_nr[][4] = {
  {NR_read,          NR_fb_read,          3,    3},
  {NR_write,         NR_fb_write,         4,    4},
  {NR_close,         NR_fb_close,         6,    6},
  {NR_fstat,         NR_fb_fstat,       440,  339},   /* the member fills the OS twin */
  {NR_lseek,         NR_fb_lseek,       199,  199},   /* nb: (fd PAD off whence) */
  {NR_mmap,          NR_fb_mmap,        197,  197},   /* nb: 7 args, pos on the stack */
  {NR_mprotect,      NR_fb_mprotect,     74,   74},
  {NR_munmap,        NR_fb_munmap,       73,   73},
  {NR_rt_sigaction,  NR_fb_rt_sigaction, -1,   -1},   /* the member builds the OS shape */
  {NR_rt_sigprocmask, NR_fb_rt_sigprocmask, 293,   48},/* 16-byte set, how+1 */
  {NR_ioctl,         NR_fb_ioctl,        54,   54},   /* the member translates requests */
  {NR_pread64,       NR_fb_pread64,     173,  153},   /* nb: (fd buf n PAD off) */
  {NR_pwrite64,      NR_fb_pwrite64,    174,  154},
  {NR_mincore,       NR_fb_mincore,      78,   78},
  {NR_madvise,       NR_fb_madvise,      75,   75},
  {NR_msync,         NR_fb_msync,       277,   65},   /* nb: __msync13; the member maps the flags */
  {NR_copy_file_range, NR_fb_copy_file_range, -1,   -1},   /* netbsd has none */
  {NR_nanosleep,     NR_fb_nanosleep,   430,   -1},
  {NR_getpid,        NR_fb_getpid,       20,   20},
  {NR_getppid,       NR_fb_getppid,      39,   39},
  {NR_socket,        NR_fb_socket,      394,   97},
  {NR_socketpair,    NR_fb_socketpair,  135,  135},
  {NR_connect,       NR_fb_connect,      98,   98},
  {NR_accept,        NR_fb_accept,       30,   30},
  {NR_sendto,        NR_fb_sendto,      133,  133},
  {NR_recvfrom,      NR_fb_recvfrom,     29,   29},
  {NR_sendmsg,       NR_fb_sendmsg,      28,   28},
  {NR_recvmsg,       NR_fb_recvmsg,      27,   27},
  {NR_shutdown,      NR_fb_shutdown,    134,  134},
  {NR_bind,          NR_fb_bind,        104,  104},
  {NR_listen,        NR_fb_listen,      106,  106},
  {NR_getsockname,   NR_fb_getsockname,  32,   32},
  {NR_getpeername,   NR_fb_getpeername,  31,   31},
  {NR_setsockopt,    NR_fb_setsockopt,  105,  105},
  {NR_getsockopt,    NR_fb_getsockopt,  118,  118},
  {NR_execve,        NR_fb_execve,       59,   59},
  {NR_execveat,      NR_fb_fexecve,     465,   -1},   /* the member builds fexecve(fd av ev) */
  {NR_exit,          NR_fb_exit,          1,    1},   /* exit and exit_group are one act here */
  {NR_wait4,         NR_fb_wait4,       449,    7},
  /* getrusage: netbsd goes to its __getrusage50 in sys/getrusage.c. statfs: no row, the shapes disagree */
  {NR_getrusage,     NR_fb_getrusage,    -1,  117},
  {NR_getrlimit,     NR_fb_getrlimit,   194,  194},
  {NR_setrlimit,     NR_fb_setrlimit,   195,  195},
  {NR_setpriority,   NR_fb_setpriority,  96,   96},
  {NR_kill,          NR_fb_kill,         37,   37},
  {NR_setitimer,     NR_fb_setitimer,   425,   83},   /* nb: __setitimer50 */
  {NR_getitimer,     NR_fb_getitimer,   426,   86},
  {NR_fcntl,         NR_fb_fcntl,        92,   92},
  {NR_fsync,         NR_fb_fsync,        95,   95},
  {NR_fdatasync,     NR_fb_fdatasync,   241,  187},
  {NR_ftruncate,     NR_fb_ftruncate,   201,  201},   /* nb: (fd PAD len) */
  {NR_getcwd,        NR_fb_getcwd,      296,   -1},   /* __getcwd answers 0 */
  {NR_chdir,         NR_fb_chdir,        12,   12},
  {NR_fchdir,        NR_fb_fchdir,       13,   13},
  {NR_fchmod,        NR_fb_fchmod,      124,  124},
  {NR_fchown,        NR_fb_fchown,      123,  123},
  {NR_umask,         NR_fb_umask,        60,   60},
  {NR_getuid,        NR_fb_getuid,       24,   24},
  {NR_getgid,        NR_fb_getgid,       47,   47},
  {NR_setuid,        NR_fb_setuid,       23,   23},
  {NR_setgid,        NR_fb_setgid,      181,  181},
  {NR_geteuid,       NR_fb_geteuid,      25,   25},
  {NR_getegid,       NR_fb_getegid,      43,   43},
  {NR_setpgid,       NR_fb_setpgid,      82,   82},
  {NR_setsid,        NR_fb_setsid,      147,  147},
  {NR_setgroups,     NR_fb_setgroups,    80,   80},
  {NR_setresuid,     NR_fb_setresuid,    -1,   -1},   /* netbsd has none */
  {NR_setresgid,     NR_fb_setresgid,    -1,   -1},
  {NR_getpgid,       NR_fb_getpgid,     207,  151},
  {NR_sigaltstack,   NR_fb_sigaltstack, 281,   53},   /* the member builds the OS shape */
  {NR_chroot,        NR_fb_chroot,       61,   61},
  {NR_getdents64,    NR_fb_getdirentries, 390,  344}, /* the member repacks the record */
  {NR_clock_gettime, NR_fb_clock_gettime, 427,   -1}, /* the member translates the id */
  {NR_exit_group,    NR_fb_exit,          1,    1},
  {NR_openat,        NR_fb_openat,      468,  463},
  {NR_mkdirat,       NR_fb_mkdirat,     461,  475},
  {NR_mknodat,       NR_fb_mknodat,     460,   -1},
  {NR_fchownat,      NR_fb_fchownat,    464,  468},
  {NR_newfstatat,    NR_fb_newfstatat,  466,  470},   /* the member fills the OS twin */
  {NR_unlinkat,      NR_fb_unlinkat,    471,  472},
  {NR_renameat,      NR_fb_renameat,    458,  465},
#ifdef __riscv
  {NR_renameat2,     NR_fb_renameat,    458,  465},   /* riscv's rename: flags 0, one argument the BSDs ignore */
#endif
  {NR_linkat,        NR_fb_linkat,      457,  471},
  {NR_symlinkat,     NR_fb_symlinkat,   470,  474},
  {NR_readlinkat,    NR_fb_readlinkat,  469,  473},
  {NR_fchmodat,      NR_fb_fchmodat,    463,  467},
  {NR_faccessat,     NR_fb_faccessat,   462,  466},
  {NR_pselect6,      NR_fb_pselect6,    436,   -1},   /* the member hands a bare sigset* 6th */
  {NR_ppoll,         NR_fb_ppoll,       437,   -1},   /* __pollts50: same first four args */
  {NR_utimensat,     NR_fb_utimensat,   467,   -1},
  {NR_pipe2,         NR_fb_pipe2,       453,   -1},
  {NR_futex,         -1,                166,   -1},   /* netbsd's __futex speaks linux's; freebsd's is _umtx_op's, the member's */
  {NR_sched_yield,   331,               350,   -1},
  {NR_flock,         131,               131,  131},
  {NR_getsid,        310,               286,  310},
  {NR_getpgid,       207,               207,  151},
};

/* a plain scan: the keys ascend on x64 but not on the asm-generic arches */
long __love_nrfb(long n) {
  int col = __love_osv == 4 ? 3 : __love_osv == 3 ? 2 : 1;
  for (unsigned i = 0; i < sizeof os_nr / sizeof *os_nr; i++)
    if (os_nr[i][0] == n) return os_nr[i][col] < 0 || col < 3 ? os_nr[i][col] : LvMacUnix | os_nr[i][col];
  return -1; }

#ifdef LvMac
/* an *at call's args, made xnu's: AT_FDCWD is -2, and the AT_ bits (freebsd's 0x100..0x800)
 * sit four places lower. w holds a..e */
int __love_macat(long n, long *w) {
  int fd = 0, fd2 = -1, fl = -1;
  if (n == NR_openat || n == NR_mkdirat || n == NR_readlinkat) ;
  else if (n == NR_fchownat) fl = 4;
  else if (n == NR_newfstatat || n == NR_fchmodat || n == NR_faccessat) fl = 3;
  else if (n == NR_unlinkat) fl = 2;
  else if (n == NR_renameat) fd2 = 2;
  else if (n == NR_linkat) fd2 = 2, fl = 4;
  else if (n == NR_symlinkat) fd = 1;
  else return 0;
  if (w[fd] == -100) w[fd] = -2;
  if (fd2 >= 0 && w[fd2] == -100) w[fd2] = -2;
  if (fl >= 0) w[fl] = (w[fl] & 0xf00) >> 4;
  return 1; }

/* dyld's exe asks xnu through libSystem by name, a weak import each ("libsys." keeps it
 * apart from our own read; macho.l binds the bare name): 0 in a static link, where the raw
 * trap stays. -1 reads errno through __error() and parks as the trap's carry */
#define LvLs(t, nm, sym, ...) extern t __ls_##nm(__VA_ARGS__) __asm__("libsys." sym) __attribute__((weak))
LvLs(int *, error, "__error", void);
LvLs(void, exit, "_exit", int);
LvLs(int, fork, "fork", void);
LvLs(long, read, "read", int, void *, unsigned long);
LvLs(long, write, "write", int, void const *, unsigned long);
LvLs(int, close, "close", int);
LvLs(int, wait4, "wait4", int, int *, int, void *);
LvLs(int, chdir, "chdir", char const *);
LvLs(int, fchdir, "fchdir", int);
LvLs(int, getpid, "getpid", void);
LvLs(int, getppid, "getppid", void);
LvLs(int, setuid, "setuid", unsigned);
LvLs(unsigned, getuid, "getuid", void);
LvLs(unsigned, geteuid, "geteuid", void);
LvLs(unsigned, getegid, "getegid", void);
LvLs(long, recvmsg, "recvmsg", int, void *, int);
LvLs(long, sendmsg, "sendmsg", int, void const *, int);
LvLs(long, recvfrom, "recvfrom", int, void *, unsigned long, int, void *, void *);
LvLs(int, accept, "accept", int, void *, void *);
LvLs(int, getpeername, "getpeername", int, void *, void *);
LvLs(int, getsockname, "getsockname", int, void *, void *);
LvLs(int, kill, "kill", int, int);
LvLs(int, pipe, "pipe", int *);
LvLs(int, sigaction, "__sigaction", int, void const *, void *);
LvLs(unsigned, getgid, "getgid", void);
LvLs(int, sigprocmask, "sigprocmask", int, void const *, void *);
LvLs(int, sigaltstack, "__sigaltstack", void const *, void *);
LvLs(int, ioctl, "ioctl", int, unsigned long, ...);
LvLs(int, execve, "execve", char const *, char *const *, char *const *);
LvLs(unsigned short, umask, "umask", unsigned short);
LvLs(int, chroot, "chroot", char const *);
LvLs(int, msync, "msync", void *, unsigned long, int);
LvLs(int, munmap, "munmap", void *, unsigned long);
LvLs(int, mprotect, "mprotect", void *, unsigned long, int);
LvLs(int, madvise, "madvise", void *, unsigned long, int);
LvLs(int, mincore, "mincore", void const *, unsigned long, char *);
LvLs(int, setgroups, "setgroups", int, unsigned const *);
LvLs(int, setpgid, "setpgid", int, int);
LvLs(int, fcntl, "fcntl", int, int, ...);
LvLs(int, select, "select", int, void *, void *, void *, void *);
LvLs(int, fsync, "fsync", int);
LvLs(int, setpriority, "setpriority", int, unsigned, int);
LvLs(int, socket, "socket", int, int, int);
LvLs(int, connect, "connect", int, void const *, unsigned);
LvLs(int, getpriority, "getpriority", int, unsigned);
LvLs(int, bind, "bind", int, void const *, unsigned);
LvLs(int, setsockopt, "setsockopt", int, int, int, void const *, unsigned);
LvLs(int, listen, "listen", int, int);
LvLs(int, getrusage, "getrusage", int, void *);
LvLs(int, getsockopt, "getsockopt", int, int, int, void *, void *);
LvLs(int, fchown, "fchown", int, unsigned, unsigned);
LvLs(int, fchmod, "fchmod", int, unsigned short);
LvLs(long, sendto, "sendto", int, void const *, unsigned long, int, void const *, unsigned);
LvLs(int, shutdown, "shutdown", int, int);
LvLs(int, socketpair, "socketpair", int, int, int, int *);
LvLs(int, setsid, "setsid", void);
LvLs(int, getpgid, "getpgid", int);
LvLs(long, pread, "pread", int, void *, unsigned long, long);
LvLs(long, pwrite, "pwrite", int, void const *, unsigned long, long);
LvLs(int, setgid, "setgid", unsigned);
LvLs(int, fdatasync, "fdatasync", int);
LvLs(int, getrlimit, "getrlimit", int, void *);
LvLs(int, setrlimit, "setrlimit", int, void const *);
LvLs(void *, mmap, "mmap", void *, unsigned long, int, int, int, long);
LvLs(long, lseek, "lseek", int, long, int);
LvLs(int, ftruncate, "ftruncate", int, long);
LvLs(int, sysctl, "sysctl", int *, unsigned, void *, unsigned long *, void *, unsigned long);
LvLs(int, poll, "poll", void *, unsigned, int);
LvLs(int, fstat64, "fstat64", int, void *);
LvLs(long, getdirentries64, "__getdirentries64", int, void *, unsigned long, long *);
LvLs(int, kqueue, "kqueue", void);
LvLs(int, openat, "openat", int, char const *, int, ...);
LvLs(int, renameat, "renameat", int, char const *, int, char const *);
LvLs(int, faccessat, "faccessat", int, char const *, int, int);
LvLs(int, fchmodat, "fchmodat", int, char const *, unsigned short, int);
LvLs(int, fchownat, "fchownat", int, char const *, unsigned, unsigned, int);
LvLs(int, fstatat64, "fstatat64", int, char const *, void *, int);
LvLs(int, linkat, "linkat", int, char const *, int, char const *, int);
LvLs(int, unlinkat, "unlinkat", int, char const *, int);
LvLs(long, readlinkat, "readlinkat", int, char const *, char *, unsigned long);
LvLs(int, symlinkat, "symlinkat", char const *, int, char const *);
LvLs(int, mkdirat, "mkdirat", int, char const *, unsigned short);
LvLs(int, getentropy, "getentropy", void *, unsigned long);
LvLs(int, dup2, "dup2", int, int);
LvLs(int, proc_info, "__proc_info", int, int, int, unsigned long, void *, int);
LvLs(int, kevent, "kevent", int, void const *, int, void *, int, void const *);
LvLs(int, clock_gettime, "clock_gettime", int, void *);
LvLs(int, usigaction, "sigaction", int, void const *, void *);
LvLs(long, slide, "_dyld_get_image_vmaddr_slide", unsigned);

/* sigaction by libSystem, its own tramp doing the sigreturn: the user's shape both ways */
long __love_macsigact(long sig, struct __mac_osigact const *a, struct __mac_osigact *old) {
  if (!__ls_usigaction) return LvNoDoor;
  return __ls_usigaction((int) sig, a, old) ? -(*__ls_error() + 4096L) : 0; }

/* the main image's slide from its linked base: dyld's, 0 for -static */
unsigned long __love_macslide(void) { return __ls_slide ? (unsigned long) __ls_slide(0) : 0; }

/* sigsetjmp's and siglongjmp's mask (mksys) */
long __love_macmask(long how, long set, long oset) { return __love_fb(48, how, set, oset, 0, 0, 0); }

/* clock_gettime by libSystem: our ids 0-3 are its 0 6 12 16 */
long __love_macclock(int ck, struct timespec *ts) {
  if (!__ls_clock_gettime || ck < 0 || ck > 3) return LvNoDoor;
  static int const id[4] = {0, 6, 12, 16};
  int r = __ls_clock_gettime(id[ck], ts);
  return r ? -(*__ls_error() + 4096L) : 0; }

/* n is xnu's unix number (its class bit aside), the args as the trap takes them */
long __love_door(long n, long a, long b, long c, long d, long e, long f) {
  if (!__ls_error) return LvNoDoor;
  int *ep = __ls_error();
  void *pa = (void *) a, *pb = (void *) b, *pc = (void *) c, *pd = (void *) d, *pe = (void *) e;
  char const *sa = pa, *sb = pb, *sd = pd;
  int ia = (int) a, ib = (int) b, ic = (int) c, id = (int) d;
  long r;
  *ep = 0;
  switch (n & 0xffffff) {
  case 1: __ls_exit(ia); return 0;
  case 2: r = __ls_fork(); break;
  case 3: r = __ls_read(ia, pb, (unsigned long) c); break;
  case 4: r = __ls_write(ia, pb, (unsigned long) c); break;
  case 6: r = __ls_close(ia); break;
  case 7: r = __ls_wait4(ia, pb, ic, pd); break;
  case 12: r = __ls_chdir(sa); break;
  case 13: r = __ls_fchdir(ia); break;
  case 20: r = __ls_getpid(); break;
  case 23: r = __ls_setuid((unsigned) a); break;
  case 24: r = __ls_getuid(); break;
  case 25: r = __ls_geteuid(); break;
  case 43: r = __ls_getegid(); break;
  case 27: r = __ls_recvmsg(ia, pb, ic); break;
  case 28: r = __ls_sendmsg(ia, pb, ic); break;
  case 29: r = __ls_recvfrom(ia, pb, (unsigned long) c, id, pe, (void *) f); break;
  case 30: r = __ls_accept(ia, pb, pc); break;
  case 31: r = __ls_getpeername(ia, pb, pc); break;
  case 32: r = __ls_getsockname(ia, pb, pc); break;
  case 37: r = __ls_kill(ia, ib); break;
  case 39: r = __ls_getppid(); break;
  case 42: r = __ls_pipe(pa); break;
  case 46: r = __ls_sigaction(ia, pb, pc); break;
  case 47: r = __ls_getgid(); break;
  case 48: r = __ls_sigprocmask(ia, pb, pc); break;
  case 53: r = __ls_sigaltstack(pa, pb); break;
  case 54: r = __ls_ioctl(ia, (unsigned long) b, c); break;
  case 59: r = __ls_execve(sa, pb, pc); break;
  case 60: r = __ls_umask((unsigned short) a); break;
  case 61: r = __ls_chroot(sa); break;
  case 65: r = __ls_msync(pa, (unsigned long) b, ic); break;
  case 73: r = __ls_munmap(pa, (unsigned long) b); break;
  case 74: r = __ls_mprotect(pa, (unsigned long) b, ic); break;
  case 75: r = __ls_madvise(pa, (unsigned long) b, ic); break;
  case 78: r = __ls_mincore(pa, (unsigned long) b, pc); break;
  case 80: r = __ls_setgroups(ia, pb); break;
  case 82: r = __ls_setpgid(ia, ib); break;
  case 90: r = __ls_dup2(ia, ib); break;
  case 92: r = __ls_fcntl(ia, ib, c); break;
  case 93: r = __ls_select(ia, pb, pc, pd, pe); break;
  case 95: r = __ls_fsync(ia); break;
  case 96: r = __ls_setpriority(ia, (unsigned) b, ic); break;
  case 97: r = __ls_socket(ia, ib, ic); break;
  case 98: r = __ls_connect(ia, pb, (unsigned) c); break;
  case 100: r = __ls_getpriority(ia, (unsigned) b); break;
  case 104: r = __ls_bind(ia, pb, (unsigned) c); break;
  case 105: r = __ls_setsockopt(ia, ib, ic, pd, (unsigned) e); break;
  case 106: r = __ls_listen(ia, ib); break;
  case 117: r = __ls_getrusage(ia, pb); break;
  case 118: r = __ls_getsockopt(ia, ib, ic, pd, pe); break;
  case 123: r = __ls_fchown(ia, (unsigned) b, (unsigned) c); break;
  case 124: r = __ls_fchmod(ia, (unsigned short) b); break;
  case 133: r = __ls_sendto(ia, pb, (unsigned long) c, id, pe, (unsigned) f); break;
  case 134: r = __ls_shutdown(ia, ib); break;
  case 135: r = __ls_socketpair(ia, ib, ic, pd); break;
  case 147: r = __ls_setsid(); break;
  case 151: r = __ls_getpgid(ia); break;
  case 153: r = __ls_pread(ia, pb, (unsigned long) c, d); break;
  case 154: r = __ls_pwrite(ia, pb, (unsigned long) c, d); break;
  case 181: r = __ls_setgid((unsigned) a); break;
  case 187: r = __ls_fdatasync(ia); break;
  case 194: r = __ls_getrlimit(ia, pb); break;
  case 195: r = __ls_setrlimit(ia, pb); break;
  case 197: r = (long) __ls_mmap(pa, (unsigned long) b, ic, id, (int) e, f); break;
  case 199: r = __ls_lseek(ia, b, ic); break;
  case 201: r = __ls_ftruncate(ia, b); break;
  case 202: r = __ls_sysctl(pa, (unsigned) b, pc, pd, pe, (unsigned long) f); break;
  case 230: r = __ls_poll(pa, (unsigned) b, ic); break;
  case 336: r = __ls_proc_info(ia, ib, ic, (unsigned long) d, pe, (int) f); break;
  case 339: r = __ls_fstat64(ia, pb); break;
  case 344: r = __ls_getdirentries64(ia, pb, (unsigned long) c, pd); break;
  case 362: r = __ls_kqueue(); break;
  case 363: r = __ls_kevent(ia, pb, ic, pd, (int) e, (void *) f); break;
  case 463: r = __ls_openat(ia, sb, ic, d); break;
  case 465: r = __ls_renameat(ia, sb, ic, sd); break;
  case 466: r = __ls_faccessat(ia, sb, ic, id); break;
  case 467: r = __ls_fchmodat(ia, sb, (unsigned short) c, id); break;
  case 468: r = __ls_fchownat(ia, sb, (unsigned) c, (unsigned) d, (int) e); break;
  case 470: r = __ls_fstatat64(ia, sb, pc, id); break;
  case 471: r = __ls_linkat(ia, sb, ic, sd, (int) e); break;
  case 472: r = __ls_unlinkat(ia, sb, ic); break;
  case 473: r = __ls_readlinkat(ia, sb, pc, (unsigned long) d); break;
  case 474: r = __ls_symlinkat(sa, ib, (char const *) c); break;
  case 475: r = __ls_mkdirat(ia, sb, (unsigned short) c); break;
  case 500: r = __ls_getentropy(pa, (unsigned long) b); break;
  default: return LvNoDoor; }
  return r == -1 && *ep ? -(*ep + 4096L) : r; }

/* its stat64 */
void __love_macstat(struct __mac_stat const *f, struct stat *st) {
  memset(st, 0, sizeof *st);
  st->st_dev = (dev_t) f->dev;
  st->st_ino = f->ino;
  st->st_nlink = f->nlink;
  st->st_mode = f->mode;
  st->st_uid = f->uid;
  st->st_gid = f->gid;
  st->st_rdev = (dev_t) f->rdev;
  st->st_size = f->size;
  st->st_blksize = f->blksize;
  st->st_blocks = f->blocks;
  st->st_atim = f->atim;
  st->st_mtim = f->mtim;
  st->st_ctim = f->ctim; }
#endif

/* freebsd errno -> canonical. one with no canonical twin maps to 41, a blank in linux's numbering */
static unsigned char const os_err[] = {
  0,   1,   2,   3,   4,   5,   6,   7,   8,   9,     /* 0..9 as linux */
  10,  35,  12,  13,  14,  15,  16,  17,  18,  19,    /* 11 EDEADLK */
  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,
  30,  31,  32,  33,  34,  11,  115, 114, 88,  89,    /* 35 EAGAIN, 36 EINPROGRESS,
                                                       * 37 EALREADY, 38 ENOTSOCK,
                                                       * 39 EDESTADDRREQ */
  90,  91,  92,  93,  94,  95,  96,  97,  98,  99,    /* the socket band, shifted */
  100, 101, 102, 103, 104, 105, 106, 107, 108, 109,
  110, 111, 40,  36,  112, 113, 39,  67,  87,  122,   /* 62 ELOOP, 63 ENAMETOOLONG,
                                                       * 66 ENOTEMPTY, 68 EUSERS,
                                                       * 69 EDQUOT */
  116, 66,  41,  41,  41,  41,  41,  37,  38,  41,    /* 70 ESTALE, 71 EREMOTE,
                                                       * 77 ENOLCK, 78 ENOSYS */
  41,  41,  43,  42,  75,  125, 84,  41,  41,  74,    /* 82 EIDRM, 83 ENOMSG,
                                                       * 84 EOVERFLOW, 85 ECANCELED,
                                                       * 86 EILSEQ, 89 EBADMSG */
  72,  67,  71,  41,  41,  131, 130, 41,              /* 90 EMULTIHOP, 91 ENOLINK,
                                                       * 92 EPROTO, 95 ENOTRECOVERABLE,
                                                       * 96 EOWNERDEAD */
};

/* netbsd's errnos part from freebsd's only at 85..98 */
static unsigned char const os_err_nb[] = {
  84, 95, 125, 74, 61, 63, 60, 62, 41, 72, 67, 71, 130, 131 };
/* ..and macos from 82 to its ELAST 106: the exec and power family takes the blank */
static unsigned char const os_err_mac[] = {
  41, 41, 75, 41, 41, 41, 41, 125, 43, 42, 84, 41, 74, 72, 61, 67, 63, 60, 71, 62,
  95, 41, 131, 130, 41 };
long __love_errfb(long e) {
  if (__love_osv == 3 && e >= 85 && e <= 98) return os_err_nb[e - 85];
  if (__love_osv == 4 && e >= 82 && e <= 106) return os_err_mac[e - 82];
  return (e > 0 && e < (long) (sizeof os_err)) ? os_err[e] : e; }
#endif

#ifdef __ARM_EABI__
/* fresh code to the i-cache: linux's cacheflush, the BSDs' sysarch(ARM_SYNC_ICACHE) */
void __love_codesync(char *a, char *b) {
  long span[2] = { (long) a, b - a };
  if (__love_osv == 1) __love_sys(0xf0002, (long) a, (long) b, 0, 0, 0, 0);
  else if (__love_osv == 2 || __love_osv == 3) __love_fb(165, 0, (long) span, 0, 0, 0, 0); }
#endif

#ifdef __riscv
/* fence.i reaches this hart alone; linux's call reaches them all */
void __love_codesync(char *a, char *b) {
  __love_fencei();
  if (__love_osv == 1) __love_sys(259, (long) a, (long) b, 0, 0, 0, 0); }
#endif
