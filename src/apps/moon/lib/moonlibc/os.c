/* os.c -- one binary on linux, freebsd, netbsd and macos: numbers, errnos, signals and
 * flags translate through these tables. wasm takes identity stubs */
#include "impl.h"

long __love_osv;         /* 0 unprobed, 1 linux, 2 freebsd, 3 netbsd, 4 macos, -1 inle */

/* inle's door, for a link without the kernel: ENOSYS */
__attribute__((weak))
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
long __love_sigfb(long s) { return s; }
long __love_sigcan(long s) { return s; }
void __love_sicanon(void const *n, siginfo_t *o) { memcpy(o, n, sizeof *o); }
unsigned long __love_maskfb(unsigned long m) { return m; }
unsigned long __love_maskcan(unsigned long m) { return m; }
long __love_ofb(long f) { return f; }
long __love_ocan(long f) { return f; }
long __love_mapfb(long f) { return f; }
long __love_safb(long f) { return f; }
long __love_sacan(long f) { return f; }
void __love_tiofb(struct termios const *t, struct __fb_termios *f) { }
void __love_tiocan(struct __fb_termios const *f, struct termios *t) { }
void __love_tiokeep(struct __fb_termios *f, struct __fb_termios const *cur) { }
long __love_affb(long a) { return a; }
long __love_afcan(long a) { return a; }
long __love_sotype(long t) { return t; }
long __love_msgfb(long f) { return f; }
long __love_msgcan(long f) { return f; }
int __love_sofb(long *lv, long *op) { return 0; }
unsigned int __love_sain(void const *a, unsigned int n, void *out) { memcpy(out, a, n); return n; }
void __love_saout(void *a, unsigned int n) { }
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
  /* getrusage: netbsd's __getrusage50 narrows suseconds_t. statfs: no row, the shapes disagree */
  {NR_getrusage,     NR_fb_getrusage,    -1,  117},
  {NR_getrlimit,     NR_fb_getrlimit,   194,  194},
  {NR_setrlimit,     NR_fb_setrlimit,   195,  195},
  {NR_setpriority,   NR_fb_setpriority,  96,   96},
  {NR_kill,          NR_fb_kill,         37,   37},
  {NR_fcntl,         NR_fb_fcntl,        92,   92},
  {NR_fsync,         NR_fb_fsync,        95,   95},
  {NR_fdatasync,     NR_fb_fdatasync,   241,  187},
  {NR_ftruncate,     NR_fb_ftruncate,   201,  201},   /* nb: (fd PAD len) */
  {NR_getcwd,        NR_fb_getcwd,      296,   -1},   /* __getcwd answers 0 */
  {NR_chdir,         NR_fb_chdir,        12,   12},
  {NR_fchmod,        NR_fb_fchmod,      124,  124},
  {NR_fchown,        NR_fb_fchown,      123,  123},
  {NR_umask,         NR_fb_umask,        60,   60},
  {NR_getuid,        NR_fb_getuid,       24,   24},
  {NR_getgid,        NR_fb_getgid,       47,   47},
  {NR_setuid,        NR_fb_setuid,       23,   23},
  {NR_setgid,        NR_fb_setgid,      181,  181},
  {NR_geteuid,       NR_fb_geteuid,      25,   25},
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
LvLs(int, getpid, "getpid", void);
LvLs(int, setuid, "setuid", unsigned);
LvLs(unsigned, getuid, "getuid", void);
LvLs(unsigned, geteuid, "geteuid", void);
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

/* sigaction by libSystem, its own tramp doing the sigreturn: the user's shape both ways */
long __love_macsigact(long sig, struct __mac_osigact const *a, struct __mac_osigact *old) {
  if (!__ls_usigaction) return LvNoDoor;
  return __ls_usigaction((int) sig, a, old) ? -(*__ls_error() + 4096L) : 0; }

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
  case 20: r = __ls_getpid(); break;
  case 23: r = __ls_setuid((unsigned) a); break;
  case 24: r = __ls_getuid(); break;
  case 25: r = __ls_geteuid(); break;
  case 27: r = __ls_recvmsg(ia, pb, ic); break;
  case 28: r = __ls_sendmsg(ia, pb, ic); break;
  case 29: r = __ls_recvfrom(ia, pb, (unsigned long) c, id, pe, (void *) f); break;
  case 30: r = __ls_accept(ia, pb, pc); break;
  case 31: r = __ls_getpeername(ia, pb, pc); break;
  case 32: r = __ls_getsockname(ia, pb, pc); break;
  case 37: r = __ls_kill(ia, ib); break;
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

/* the socket type's two flag bits, which xnu never took, set on the new fd */
void __love_macsofl(int fd, long t) {
  if (t & 0x80000) fcntl(fd, F_SETFD, FD_CLOEXEC);
  if (t & 0x800) fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK); }

/* its stat64 and termios (freebsd's bits, each word a long) */
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
void __love_tiomac(struct __fb_termios const *f, struct __mac_termios *m) {
  memset(m, 0, sizeof *m);
  m->c_iflag = f->c_iflag, m->c_oflag = f->c_oflag, m->c_cflag = f->c_cflag, m->c_lflag = f->c_lflag;
  memcpy(m->c_cc, f->c_cc, 20);
  m->c_ispeed = f->c_ispeed, m->c_ospeed = f->c_ospeed; }
void __love_tiounmac(struct __mac_termios const *m, struct __fb_termios *f) {
  memset(f, 0, sizeof *f);
  f->c_iflag = (unsigned int) m->c_iflag, f->c_oflag = (unsigned int) m->c_oflag;
  f->c_cflag = (unsigned int) m->c_cflag, f->c_lflag = (unsigned int) m->c_lflag;
  memcpy(f->c_cc, m->c_cc, 20);
  f->c_ispeed = (unsigned int) m->c_ispeed, f->c_ospeed = (unsigned int) m->c_ospeed; }
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

/* signals, canonical <-> freebsd; -1 has no twin. freebsd 17 is SIGSTOP, canonical
 * SIGCHLD's number: a lost translation stops a child */
static signed char const os_sigfb[32] = {
   0,  1,  2,  3,  4,  5,  6, 10,  8,  9, 30, 11, 31, 13, 14, 15,
  -1, 20, 19, 17, 18, 21, 22, 16, 24, 25, 26, 27, 28, 23, -1, 12 };
static signed char const os_sigcan[32] = {
   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  7, 11, 31, 13, 14, 15,
  23, 19, 20, 18, 17, 21, 22, 29, 24, 25, 26, 27, 28, 29, 10, 12 };
long __love_sigfb(long s) { return (s >= 0 && s < 32) ? os_sigfb[s] : -1; }
long __love_sigcan(long s) { return (s >= 0 && s < 32) ? os_sigcan[s] : s; }

/* native siginfo heads: freebsd lays the lanes flat; netbsd swaps code and errno */
struct __fb_siginfo { int signo, err, code, pid; unsigned uid; int status; void *addr; };
struct __nb_siginfo { int signo, code, err;
#ifndef __i386__
  int pad;                            /* the union holds 64-bit words: on 8, but on i386 */
#endif
  union { void *addr; struct { int pid; unsigned uid; int status; } chld; } u; };
/* the address lane: a fault signal with a kernel code; a sent one carries its sender */
static int os_faultlane(int s, long code) {
  return (s == SIGILL || s == SIGTRAP || s == SIGFPE || s == SIGBUS || s == SIGSEGV)
         && code > 0 && code < 0x80; }
/* si_code's sender band; the fault codes agree on all three kernels */
static long os_sicode(long c) {
  if (__love_osv == 2 || __love_osv == 4) switch (c) {
    case 0x10001: return 0;      /* SI_USER */
    case 0x10002: return -1;     /* SI_QUEUE */
    case 0x10003: return -2;     /* SI_TIMER */
    case 0x10004: return -4;     /* SI_ASYNCIO */
    case 0x10005: return -3;     /* SI_MESGQ */
    case 0x10006: return 0x80;   /* SI_KERNEL */
    case 0x10007: return -6;     /* SI_LWP; linux's nearest is SI_TKILL */
    default: return c; }
  if (__love_osv == 3) switch (c) {
    case -3: return -4;          /* SI_ASYNCIO */
    case -4: return -3;          /* SI_MESGQ */
    case -5: return -6;          /* SI_LWP; linux's -5 is SI_SIGIO, a different thing */
    default: return c; }         /* USER, QUEUE and TIMER already agree */
  return c; }
void __love_sicanon(void const *n, siginfo_t *o) {
  memset(o, 0, sizeof *o);
  if (__love_osv == 2 || __love_osv == 4) {   /* macos keeps freebsd's head and its sender band */
    struct __fb_siginfo const *f = n;
    o->si_signo = (int) __love_sigcan(f->signo), o->si_errno = f->err;
    o->si_code = (int) os_sicode(f->code);
    if (os_faultlane(o->si_signo, o->si_code)) o->si_addr = f->addr;
    else { o->si_pid = f->pid, o->si_uid = f->uid;
           if (o->si_signo == SIGCHLD) o->si_status = f->status; } }
  else if (__love_osv == 3) {
    struct __nb_siginfo const *b = n;
    o->si_signo = (int) __love_sigcan(b->signo), o->si_errno = b->err;
    o->si_code = (int) os_sicode(b->code);
    if (os_faultlane(o->si_signo, o->si_code)) o->si_addr = b->u.addr;
    else { o->si_pid = b->u.chld.pid, o->si_uid = b->u.chld.uid;
           if (o->si_signo == SIGCHLD) o->si_status = b->u.chld.status; } }
  else memcpy(o, n, sizeof *o); }         /* linux: the native record IS canonical */

/* a mask, bit (sig-1), signals 1..31; the rt band has no freebsd twin and drops */
static unsigned long os_mask(unsigned long m, signed char const *to) {
  unsigned long o = 0;
  for (int s = 1; s < 32; s++)
    if (m & (1UL << (s - 1))) { long t = to[s]; if (t > 0) o |= 1UL << (t - 1); }
  return o; }
unsigned long __love_maskfb(unsigned long m) { return os_mask(m, os_sigfb); }
unsigned long __love_maskcan(unsigned long m) { return os_mask(m, os_sigcan); }

/* open flags: the access mode rides, named bits translate, the rest drop. the BSDs agree
 * but for NOCTTY (macos 0x20000), DIRECTORY and CLOEXEC */
static long const os_odir[] = {0x20000, 0x200000, 0x100000};
static long const os_oclo[] = {0x100000, 0x400000, 0x1000000};
static long os_ok(void) { return __love_osv == 4 ? 2 : __love_osv == 3; }
long __love_ofb(long f) {
  long o = f & 3, k = os_ok();
  if (f & O_CREAT)     o |= 0x200;
  if (f & O_EXCL)      o |= 0x800;
  if (f & O_NOCTTY)    o |= k == 2 ? 0x20000 : 0x8000;
  if (f & O_TRUNC)     o |= 0x400;
  if (f & O_APPEND)    o |= 8;
  if (f & O_NONBLOCK)  o |= 4;
  if (f & O_DIRECTORY) o |= os_odir[k];
  if (f & O_NOFOLLOW)  o |= 0x100;
  if (f & O_CLOEXEC)   o |= os_oclo[k];
  return o; }
long __love_ocan(long f) {
  long o = f & 3, k = os_ok();
  if (f & 0x200)    o |= O_CREAT;
  if (f & 0x800)    o |= O_EXCL;
  if (f & (k == 2 ? 0x20000 : 0x8000)) o |= O_NOCTTY;
  if (f & 0x400)    o |= O_TRUNC;
  if (f & 8)        o |= O_APPEND;
  if (f & 4)        o |= O_NONBLOCK;
  if (f & os_odir[k]) o |= O_DIRECTORY;
  if (f & 0x100)    o |= O_NOFOLLOW;
  if (f & os_oclo[k]) o |= O_CLOEXEC;
  return o; }

/* mmap flags: SHARED 1 / PRIVATE 2 / FIXED 0x10 agree; ANON moves to 0x1000;
 * POPULATE and the other linux hints have no twin and drop. */
long __love_mapfb(long f) {
  long o = f & 0x13;
  if (f & MAP_ANON) o |= 0x1000;
  return o; }


long __love_safb(long f) {
  long o = 0;
  if (f & SA_ONSTACK)   o |= 1;
  if (f & SA_RESTART)   o |= 2;
  if (f & SA_RESETHAND) o |= 4;
  if (f & SA_NOCLDSTOP) o |= 8;
  if (f & SA_NODEFER)   o |= 16;
  if (f & SA_NOCLDWAIT) o |= 32;
  if (f & SA_SIGINFO)   o |= 64;
  return o; }
long __love_sacan(long f) {
  long o = 0;
  if (f & 1)  o |= SA_ONSTACK;
  if (f & 2)  o |= SA_RESTART;
  if (f & 4)  o |= SA_RESETHAND;
  if (f & 8)  o |= SA_NOCLDSTOP;
  if (f & 16) o |= SA_NODEFER;
  if (f & 32) o |= SA_NOCLDWAIT;
  if (f & 64) o |= SA_SIGINFO;
  return o; }

/* termios rows are {canonical bit, freebsd bit}; an unnamed bit drops. speeds copy verbatim */
static unsigned int const os_tio_i[][2] = {   /* c_iflag */
  {1, 1}, {2, 2}, {4, 4}, {8, 8}, {16, 16}, {32, 32}, {64, 64}, {128, 128},
  {256, 256}, {0x400, 0x200} /* IXON */, {0x1000, 0x400} /* IXOFF */,
  {0x800, 0x800}, {0x2000, 0x2000} };
static unsigned int const os_tio_o[][2] = {   /* c_oflag */
  {1, 1} /* OPOST */, {4, 2} /* ONLCR */ };
static unsigned int const os_tio_c[][2] = {   /* c_cflag: freebsd is linux<<4 */
  {0x10, 0x100}, {0x20, 0x200} /* CSIZE */, {0x40, 0x400} /* CSTOPB */,
  {0x80, 0x800} /* CREAD */, {0x100, 0x1000} /* PARENB */,
  {0x200, 0x2000} /* PARODD */, {0x400, 0x4000} /* HUPCL */,
  {0x800, 0x8000} /* CLOCAL */, {0x80000000, 0x30000} /* CRTSCTS */ };
static unsigned int const os_tio_l[][2] = {   /* c_lflag */
  {1, 0x80} /* ISIG */, {2, 0x100} /* ICANON */, {8, 8} /* ECHO */,
  {0x10, 2} /* ECHOE */, {0x20, 4} /* ECHOK */, {0x40, 0x10} /* ECHONL */,
  {0x80, 0x80000000} /* NOFLSH */, {0x100, 0x400000} /* TOSTOP */,
  {0x200, 0x40} /* ECHOCTL */, {0x400, 0x20} /* ECHOPRT */,
  {0x800, 1} /* ECHOKE */, {0x1000, 0x800000} /* FLUSHO */,
  {0x4000, 0x20000000} /* PENDIN */, {0x8000, 0x400} /* IEXTEN */ };
static signed char const os_tio_cc[17] = {    /* canonical index -> freebsd's */
  8, 9, 3, 5, 0, 17, 16, -1, 12, 13, 10, 1, 6, 15, 4, 14, 2 };
static unsigned int os_tiow(unsigned int v, unsigned int const (*row)[2], int n, int can) {
  unsigned int o = 0;
  for (int i = 0; i < n; i++)
    if (v & row[i][can ? 1 : 0]) o |= row[i][can ? 0 : 1];
  return o; }
void __love_tiofb(struct termios const *t, struct __fb_termios *f) {
  memset(f, 0, sizeof *f);
  f->c_iflag = os_tiow(t->c_iflag, os_tio_i, sizeof os_tio_i / 8, 0);
  f->c_oflag = os_tiow(t->c_oflag, os_tio_o, sizeof os_tio_o / 8, 0);
  f->c_cflag = os_tiow(t->c_cflag, os_tio_c, sizeof os_tio_c / 8, 0);
  f->c_lflag = os_tiow(t->c_lflag, os_tio_l, sizeof os_tio_l / 8, 0);
  /* a disabled slot is 0 in the canonical spelling and 0xff here; vmin and vtime
   * (5, 6) are counts, where 0 is a value. a slot linux has no name for stays off */
  memset(f->c_cc, 0xff, sizeof f->c_cc);
  for (int i = 0; i < 17; i++)
    if (os_tio_cc[i] >= 0)
      f->c_cc[(int) os_tio_cc[i]] = t->c_cc[i] || i == 5 || i == 6 ? t->c_cc[i] : 0xff;
  /* netbsd spells CRTSCTS as the low bit alone; the high one is foreign there */
  if (__love_osv == 3 && (f->c_cflag & 0x30000)) f->c_cflag = (f->c_cflag & ~0x30000u) | 0x10000;
  f->c_ispeed = t->c_ispeed; f->c_ospeed = t->c_ospeed; }
/* the slots linux has no name for (status, dsusp) kept as the terminal has them */
void __love_tiokeep(struct __fb_termios *f, struct __fb_termios const *cur) {
  unsigned char named[20] = {0};
  for (int i = 0; i < 17; i++) if (os_tio_cc[i] >= 0) named[(int) os_tio_cc[i]] = 1;
  for (int k = 0; k < 20; k++) if (!named[k]) f->c_cc[k] = cur->c_cc[k]; }
void __love_tiocan(struct __fb_termios const *f, struct termios *t) {
  memset(t, 0, sizeof *t);
  t->c_iflag = os_tiow(f->c_iflag, os_tio_i, sizeof os_tio_i / 8, 1);
  t->c_oflag = os_tiow(f->c_oflag, os_tio_o, sizeof os_tio_o / 8, 1);
  t->c_cflag = os_tiow(f->c_cflag, os_tio_c, sizeof os_tio_c / 8, 1);
  t->c_lflag = os_tiow(f->c_lflag, os_tio_l, sizeof os_tio_l / 8, 1);
  for (int i = 0; i < 17; i++)
    if (os_tio_cc[i] >= 0) {
      unsigned char c = f->c_cc[(int) os_tio_cc[i]];
      t->c_cc[i] = c == 0xff && i != 5 && i != 6 ? 0 : c; }
  t->c_ispeed = f->c_ispeed; t->c_ospeed = f->c_ospeed; }

/* inet6 moves; the BSD sockaddr fronts a length byte where linux's 16-bit family sits */
long __love_affb(long a) { return a == 10 ? (__love_osv == 4 ? 30 : __love_osv == 3 ? 24 : 28) : a; }
long __love_afcan(long a) { return a == (__love_osv == 4 ? 30 : __love_osv == 3 ? 24 : 28) ? 10 : a; }
unsigned int __love_sain(void const *a, unsigned int n, void *out) {
  unsigned char const *s = a;
  unsigned char *b = out;
  memcpy(out, a, n);
  if (n >= 2) {
    long fam = s[0] | s[1] << 8;
    /* a unix name's length follows its path: freebsd refuses past its 106 bytes */
    if (fam == 1 && n > 2) {
      unsigned int k = 2;
      while (k < n && b[k]) k++;
      n = k + (k < n); }
    b[0] = (unsigned char) n;
    b[1] = (unsigned char) __love_affb(fam); }
  return n; }
void __love_saout(void *a, unsigned int n) {
  unsigned char *b = a;
  if (n >= 2) {
    unsigned int fam = (unsigned int) __love_afcan(b[1]);
    b[0] = (unsigned char) (fam & 255);
    b[1] = (unsigned char) (fam >> 8); } }
/* socket type: CLOEXEC and NONBLOCK move high */
long __love_sotype(long t) {
  long o = t & 0xff;
  if (__love_osv == 4) return o;        /* macos has neither: __love_macsofl sets them after */
  if (t & 0x800)   o |= 0x20000000;
  if (t & 0x80000) o |= 0x10000000;
  return o; }
/* send/recv flags: the named bits translate, the rest drop */
long __love_msgfb(long f) {
  long o = f & 3;                       /* OOB 1, PEEK 2 agree */
  if (f & 0x40)   o |= 0x80;            /* MSG_DONTWAIT */
  if (f & 0x100)  o |= 0x40;            /* MSG_WAITALL */
  if (f & 0x4000) o |= __love_osv == 4 ? 0x80000 : __love_osv == 3 ? 0x400 : 0x20000;   /* MSG_NOSIGNAL */
  return o; }
/* recvmsg's msg_flags come back the other way */
long __love_msgcan(long f) {
  long o = f & 1;                       /* MSG_OOB agrees */
  if (f & 0x8)  o |= 0x80;              /* MSG_EOR */
  if (f & 0x10) o |= 0x20;              /* MSG_TRUNC */
  if (f & 0x20) o |= 0x8;               /* MSG_CTRUNC */
  return o; }
/* sockopt: SOL_SOCKET, IP and IPV6 names permute, other levels ride. 0 ok, -1 unmapped,
 * never a different option: linux's IP_TTL is a bsd's IP_HDRINCL */
int __love_sofb(long *lv, long *op) {
  if (*lv == 0) switch (*op) {
    case 2: *op = 4; return 0;          /* IP_TTL */
    case 12: *op = __love_osv == 4 ? 24 : __love_osv == 3 ? 23 : 65; return 0;   /* IP_RECVTTL */
    default: return -1; }
  if (*lv == 41) switch (*op) {
    case 16: *op = 4; return 0;         /* IPV6_UNICAST_HOPS */
    case 26: *op = 27; return 0;        /* IPV6_V6ONLY */
    case 20: *op = 12; return 0;        /* IPV6_JOIN_GROUP */
    case 21: *op = 13; return 0;        /* IPV6_LEAVE_GROUP */
    case 51: *op = 37; return 0;        /* IPV6_RECVHOPLIMIT */
    case 52: *op = 47; return 0;        /* IPV6_HOPLIMIT */
    default: return -1; }
  if (*lv != 1) return 0;
  *lv = 0xffff;
  switch (*op) {
    case 1: *op = 1; return 0;          /* SO_DEBUG */
    case 2: *op = 4; return 0;          /* SO_REUSEADDR */
    case 3: *op = 0x1008; return 0;     /* SO_TYPE */
    case 4: *op = 0x1007; return 0;     /* SO_ERROR */
    case 5: *op = 0x10; return 0;       /* SO_DONTROUTE */
    case 6: *op = 0x20; return 0;       /* SO_BROADCAST */
    case 7: *op = 0x1001; return 0;     /* SO_SNDBUF */
    case 8: *op = 0x1002; return 0;     /* SO_RCVBUF */
    case 9: *op = 8; return 0;          /* SO_KEEPALIVE */
    case 10: *op = 0x100; return 0;     /* SO_OOBINLINE */
    case 13: *op = 0x80; return 0;      /* SO_LINGER */
    case 18: *op = 0x1004; return 0;    /* SO_RCVLOWAT */
    case 19: *op = 0x1003; return 0;    /* SO_SNDLOWAT */
    case 20: *op = __love_osv == 3 ? 0x100c : 0x1006; return 0;   /* SO_RCVTIMEO */
    case 21: *op = __love_osv == 3 ? 0x100b : 0x1005; return 0;   /* SO_SNDTIMEO */
    case 30: *op = 2; return 0;         /* SO_ACCEPTCONN */
    case 38: if (__love_osv != 2) return -1; *op = 0x1016; return 0;   /* SO_PROTOCOL: freebsd's alone */
    case 39: if (__love_osv != 2) return -1; *op = 0x1019; return 0; } /* SO_DOMAIN */
  return -1; }
#endif
