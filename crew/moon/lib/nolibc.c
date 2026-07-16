/* crew/moon/lib/nolibc.c -- the raw-syscall libc under the gcc-free ai (rung 4).
 * Everything the host objects ask of glibc, answered straight off the Linux
 * syscall table through __ai_sys (crew/moon/lib/mksys.l lays that leaf,
 * with __sigsetjmp/siglongjmp/__ai_sigret beside it; crew/moon/lib/math/
 * carries the math floor, crew/moon/lib/math/am.c -- ours). One file, mooncc-compiled, our own linker binds it:
 *   mooncc ai.o (host objects) nolibc.o (math objects) sys.o -o ai
 * Two arches, one body: every call below speaks the modern forms BOTH tables
 * carry (openat / newfstatat / ppoll / pipe2 / dup3 / clone / the *at file
 * ops) -- aarch64's asm-generic table dropped the legacy names outright, so
 * the NR block under this comment is the only thing that gates. The shapes
 * MATCH crew/moon/include/: struct stat and dirent are the kernel layouts
 * verbatim (stat.h arch-gates the struct), termios rides TCGETS raw the way
 * musl does, and only sigaction needs a real translation (glibc's 152-byte
 * struct to the kernel's -- x86-64 supplies a restorer, aarch64's kernel
 * lays its own vdso return trampoline). Single-threaded by design, like
 * ai itself: errno is one int, no locks anywhere. */
#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <setjmp.h>
#include <poll.h>
#include <time.h>
#include <utime.h>
#include <dirent.h>
#include <termios.h>
#include <netdb.h>
#include <pwd.h>
#include <grp.h>
#include <link.h>
#include <sched.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/mount.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <sys/signalfd.h>

extern long __ai_sys(long n, long a, long b, long c, long d, long e, long f);
extern void __ai_sigret(void);
extern int main(int, char**);

/* ---- the syscall numbers, the one arch gate ---- */
#ifdef __aarch64__
#define NR_getcwd          17
#define NR_dup3            24
#define NR_fcntl           25
#define NR_ioctl           29
#define NR_mkdirat         34
#define NR_mknodat         33
#define NR_unlinkat        35
#define NR_nanosleep      101
#define NR_setgid         144
#define NR_setuid         146
#define NR_geteuid        175
#define NR_symlinkat       36
#define NR_linkat          37
#define NR_renameat        38
#define NR_mount           40
#define NR_ftruncate       46
#define NR_chdir           49
#define NR_fchmod          52
#define NR_fchmodat        53
#define NR_fchownat        54
#define NR_faccessat       48
#define NR_openat          56
#define NR_close           57
#define NR_pipe2           59
#define NR_getdents64      61
#define NR_lseek           62
#define NR_read            63
#define NR_write           64
#define NR_pwrite64        68
#define NR_ppoll           73
#define NR_signalfd4       74
#define NR_readlinkat      78
#define NR_newfstatat      79
#define NR_fstat           80
#define NR_fsync           82
#define NR_utimensat       88
#define NR_exit_group      94
#define NR_unshare         97
#define NR_clock_gettime  113
#define NR_kill           129
#define NR_rt_sigaction   134
#define NR_rt_sigprocmask 135
#define NR_setpgid        154
#define NR_getpgid        155
#define NR_setsid         157
#define NR_umask          166
#define NR_getpid         172
#define NR_getuid         174
#define NR_getgid         176
#define NR_socket         198
#define NR_bind           200
#define NR_listen         201
#define NR_accept         202
#define NR_connect        203
#define NR_sendto         206
#define NR_recvfrom       207
#define NR_setsockopt     208
#define NR_shutdown       210
#define NR_sendmsg        211
#define NR_recvmsg        212
#define NR_munmap         215
#define NR_clone          220
#define NR_execve         221
#define NR_mmap           222
#define NR_mprotect       226
#define NR_wait4          260
#define NR_memfd_create   279
#else
#define NR_read             0
#define NR_write            1
#define NR_close            3
#define NR_fstat            5
#define NR_lseek            8
#define NR_nanosleep       35
#define NR_mmap             9
#define NR_mprotect        10
#define NR_munmap          11
#define NR_rt_sigaction    13
#define NR_rt_sigprocmask  14
#define NR_ioctl           16
#define NR_pwrite64        18
#define NR_getpid          39
#define NR_setuid         105
#define NR_setgid         106
#define NR_geteuid        107
#define NR_socket          41
#define NR_connect         42
#define NR_accept          43
#define NR_sendto          44
#define NR_recvfrom        45
#define NR_sendmsg         46
#define NR_recvmsg         47
#define NR_shutdown        48
#define NR_bind            49
#define NR_listen          50
#define NR_setsockopt      54
#define NR_clone           56
#define NR_execve          59
#define NR_wait4           61
#define NR_kill            62
#define NR_fcntl           72
#define NR_fsync           74
#define NR_ftruncate       77
#define NR_getcwd          79
#define NR_chdir           80
#define NR_fchmod          91
#define NR_umask           95
#define NR_getuid         102
#define NR_getgid         104
#define NR_setpgid        109
#define NR_setsid         112
#define NR_getpgid        121
#define NR_mount          165
#define NR_getdents64     217
#define NR_clock_gettime  228
#define NR_exit_group     231
#define NR_openat         257
#define NR_mkdirat        258
#define NR_mknodat        259
#define NR_fchownat       260
#define NR_faccessat      269
#define NR_newfstatat     262
#define NR_unlinkat       263
#define NR_renameat       264
#define NR_linkat         265
#define NR_symlinkat      266
#define NR_readlinkat     267
#define NR_fchmodat       268
#define NR_ppoll          271
#define NR_unshare        272
#define NR_utimensat      280
#define NR_signalfd4      289
#define NR_dup3           292
#define NR_pipe2          293
#define NR_memfd_create   319
#endif

char **environ;
static long *__auxv;

/* ---- errno: one int (ai is single-threaded), kernel -errno unwrapped ---- */
static int __errno_v;
int *__errno_location(void) { return &__errno_v; }
static long er(long r) {
  if ((unsigned long) r > (unsigned long) -4096L) { __errno_v = (int) -r; return -1; }
  return r; }

static long sc0(long n) { return __ai_sys(n, 0, 0, 0, 0, 0, 0); }
static long sc1(long n, long a) { return __ai_sys(n, a, 0, 0, 0, 0, 0); }
static long sc2(long n, long a, long b) { return __ai_sys(n, a, b, 0, 0, 0, 0); }
static long sc3(long n, long a, long b, long c) { return __ai_sys(n, a, b, c, 0, 0, 0); }
static long sc4(long n, long a, long b, long c, long d) { return __ai_sys(n, a, b, c, d, 0, 0); }
static long sc5(long n, long a, long b, long c, long d, long e) { return __ai_sys(n, a, b, c, d, e, 0); }
static long sc6(long n, long a, long b, long c, long d, long e, long f) { return __ai_sys(n, a, b, c, d, e, f); }

/* ---- memory/string: word-wide where the pointers agree (the GC image and
 * string lanes move real volume through these) ---- */
void *memcpy(void *d, void const *s, size_t n) {
  unsigned char *dp = d; unsigned char const *sp = s;
  if ((((unsigned long) dp | (unsigned long) sp) & 7) == 0)
    while (n >= 8) { *(unsigned long *) dp = *(unsigned long const *) sp; dp += 8; sp += 8; n -= 8; }
  while (n--) *dp++ = *sp++;
  return d; }
void *memmove(void *d, void const *s, size_t n) {
  unsigned char *dp = d; unsigned char const *sp = s;
  if (dp == sp || n == 0) return d;
  if (dp < sp) return memcpy(d, s, n);
  dp += n; sp += n;
  while (n--) *--dp = *--sp;
  return d; }
void *memset(void *d, int c, size_t n) {
  unsigned char *dp = d;
  unsigned char b = (unsigned char) c;
  unsigned long w = b; w |= w << 8; w |= w << 16; w |= w << 32;
  if (((unsigned long) dp & 7) == 0)
    while (n >= 8) { *(unsigned long *) dp = w; dp += 8; n -= 8; }
  while (n--) *dp++ = b;
  return d; }
int memcmp(void const *a, void const *b, size_t n) {
  unsigned char const *x = a, *y = b;
  while (n--) { if (*x != *y) return (int) *x - (int) *y; x++; y++; }
  return 0; }
size_t strlen(char const *s) { size_t n = 0; while (*s++) n++; return n; }
int strcmp(char const *a, char const *b) {
  while (*a && *a == *b) { a++; b++; }
  return (int) (unsigned char) *a - (int) (unsigned char) *b; }
int strncmp(char const *a, char const *b, size_t n) {
  while (n && *a && *a == *b) { a++; b++; n--; }
  return n ? (int) (unsigned char) *a - (int) (unsigned char) *b : 0; }
char *strcpy(char *d, char const *s) { char *r = d; while ((*d++ = *s++)) ; return r; }
char *strncpy(char *d, char const *s, size_t n) {
  char *r = d;
  while (n && *s) { *d++ = *s++; n--; }
  while (n) { *d++ = 0; n--; }
  return r; }
char *strcat(char *d, char const *s) {
  char *r = d;
  while (*d) d++;
  while ((*d++ = *s++)) ;
  return r; }
char *strrchr(char const *s, int c) {
  char const *last = 0;
  do { if (*s == (char) c) last = s; } while (*s++);
  return (char *) last; }
size_t strspn(char const *s, char const *set) {
  size_t n = 0;
  for (; s[n]; n++) { char const *p = set; while (*p && *p != s[n]) p++; if (!*p) break; }
  return n; }
size_t strcspn(char const *s, char const *set) {
  size_t n = 0;
  for (; s[n]; n++) { char const *p = set; while (*p && *p != s[n]) p++; if (*p) break; }
  return n; }
int isupper(int c) { return c >= 65 && c <= 90; }
int isalpha(int c) { return (c >= 65 && c <= 90) || (c >= 97 && c <= 122); }
int isspace(int c) { return c == 32 || (c >= 9 && c <= 13); }
int isprint(int c) { return c >= 32 && c < 127; }
int tolower(int c) { return (c >= 65 && c <= 90) ? c + 32 : c; }
char *strchr(char const *s, int c) { for (;; s++) { if (*s == (char) c) return (char *) s; if (!*s) return 0; } }
char *strerror(int e) { static char b[24]; snprintf(b, sizeof b, "error %d", e); return b; }
int strcasecmp(char const *a, char const *b) {
  while (*a && tolower((unsigned char) *a) == tolower((unsigned char) *b)) { a++; b++; }
  return tolower((unsigned char) *a) - tolower((unsigned char) *b); }
int strncasecmp(char const *a, char const *b, size_t n) {
  while (n && *a && tolower((unsigned char) *a) == tolower((unsigned char) *b)) { a++; b++; n--; }
  return n ? tolower((unsigned char) *a) - tolower((unsigned char) *b) : 0; }

/* ---- the plain syscall tail: one line each ---- */
long read(int fd, void *b, long n) { return er(sc3(NR_read, fd, (long) b, n)); }
long write(int fd, void const *b, long n) { return er(sc3(NR_write, fd, (long) b, n)); }
int close(int fd) { return (int) er(sc1(NR_close, fd)); }
long lseek(int fd, long off, int wh) { return er(sc3(NR_lseek, fd, off, wh)); }
int open(char const *p, int fl, ...) {
  va_list ap; va_start(ap, fl);
  int mode = va_arg(ap, int);
  va_end(ap);
  return (int) er(sc4(NR_openat, AT_FDCWD, (long) p, fl, mode)); }
int creat(char const *p, unsigned int mode) { return open(p, O_WRONLY | O_CREAT | O_TRUNC, (int) mode); }
int fcntl(int fd, int cmd, ...) {
  va_list ap; va_start(ap, cmd);
  long arg = va_arg(ap, long);
  va_end(ap);
  return (int) er(sc3(NR_fcntl, fd, cmd, arg)); }
int ioctl(int fd, unsigned long req, ...) {
  va_list ap; va_start(ap, req);
  long arg = va_arg(ap, long);
  va_end(ap);
  return (int) er(sc3(NR_ioctl, fd, (long) req, arg)); }
int stat(char const *p, struct stat *st) { return (int) er(sc4(NR_newfstatat, AT_FDCWD, (long) p, (long) st, 0)); }
int fstat(int fd, struct stat *st) { return (int) er(sc2(NR_fstat, fd, (long) st)); }
int lstat(char const *p, struct stat *st) { return (int) er(sc4(NR_newfstatat, AT_FDCWD, (long) p, (long) st, 256)); }   /* AT_SYMLINK_NOFOLLOW */
int poll(struct pollfd *fds, nfds_t n, int ms) {
  struct timespec ts;
  ts.tv_sec = ms / 1000;
  ts.tv_nsec = (long) (ms % 1000) * 1000000;
  return (int) er(sc5(NR_ppoll, (long) fds, (long) n, ms < 0 ? 0 : (long) &ts, 0, 8)); }
int pipe(int *fds) { return (int) er(sc2(NR_pipe2, (long) fds, 0)); }
int dup2(int a, int b) {
  if (a == b) return fcntl(a, F_GETFD, 0) < 0 ? -1 : b;   /* dup3 refuses a==b; dup2 answers b if a lives */
  return (int) er(sc3(NR_dup3, a, b, 0)); }
int getpid(void) { return (int) sc0(NR_getpid); }
unsigned int getuid(void) { return (unsigned int) sc0(NR_getuid); }
unsigned int getgid(void) { return (unsigned int) sc0(NR_getgid); }
int fork(void) { return (int) er(sc5(NR_clone, 17, 0, 0, 0, 0)); }   /* clone(SIGCHLD): the fork nobody dropped */
int waitpid(int pid, int *st, int opt) { return (int) er(sc4(NR_wait4, pid, (long) st, opt, 0)); }
int kill(pid_t pid, int sig) { return (int) er(sc2(NR_kill, pid, sig)); }
int raise(int sig) { return kill(getpid(), sig); }
int fsync(int fd) { return (int) er(sc1(NR_fsync, fd)); }
int ftruncate(int fd, long n) { return (int) er(sc2(NR_ftruncate, fd, n)); }
char *getcwd(char *b, unsigned long n) {
  long r = sc2(NR_getcwd, (long) b, (long) n);
  if (r < 0) { __errno_v = (int) -r; return 0; }
  return b; }
int chdir(char const *p) { return (int) er(sc1(NR_chdir, (long) p)); }
int rename(char const *a, char const *b) { return (int) er(sc4(NR_renameat, AT_FDCWD, (long) a, AT_FDCWD, (long) b)); }
int mkdir(char const *p, unsigned int m) { return (int) er(sc3(NR_mkdirat, AT_FDCWD, (long) p, m)); }
int rmdir(char const *p) { return (int) er(sc3(NR_unlinkat, AT_FDCWD, (long) p, 512)); }   /* AT_REMOVEDIR */
int link(char const *a, char const *b) { return (int) er(sc5(NR_linkat, AT_FDCWD, (long) a, AT_FDCWD, (long) b, 0)); }
int unlink(char const *p) { return (int) er(sc3(NR_unlinkat, AT_FDCWD, (long) p, 0)); }
int symlink(char const *a, char const *b) { return (int) er(sc3(NR_symlinkat, (long) a, AT_FDCWD, (long) b)); }
long readlink(char const *p, char *b, unsigned long n) { return er(sc4(NR_readlinkat, AT_FDCWD, (long) p, (long) b, (long) n)); }
int chmod(char const *p, unsigned int m) { return (int) er(sc4(NR_fchmodat, AT_FDCWD, (long) p, m, 0)); }
int fchmod(int fd, unsigned int m) { return (int) er(sc2(NR_fchmod, fd, m)); }
int chown(char const *p, unsigned int u, unsigned int g) { return (int) er(sc5(NR_fchownat, AT_FDCWD, (long) p, u, g, 0)); }
int lchown(char const *p, unsigned int u, unsigned int g) { return (int) er(sc5(NR_fchownat, AT_FDCWD, (long) p, u, g, 256)); }   /* AT_SYMLINK_NOFOLLOW */
int access(char const *p, int m) { return (int) er(sc4(NR_faccessat, AT_FDCWD, (long) p, m, 0)); }
int dup(int fd) { return (int) er(sc3(NR_fcntl, fd, 0, 0)); }                          /* F_DUPFD */
unsigned int geteuid(void) { return (unsigned int) sc0(NR_geteuid); }
int setuid(unsigned int u) { return (int) er(sc1(NR_setuid, u)); }
int setgid(unsigned int g) { return (int) er(sc1(NR_setgid, g)); }
int mknod(char const *p, unsigned int mode, unsigned long dev) { return (int) er(sc4(NR_mknodat, AT_FDCWD, (long) p, mode, (long) dev)); }
int mkfifo(char const *p, unsigned int mode) { return mknod(p, mode | 4096U, 0); }     /* S_IFIFO = 010000 */
int wait(int *st) { return waitpid(-1, st, 0); }
int usleep(unsigned int us) {
  struct timespec ts;
  ts.tv_sec = us / 1000000;
  ts.tv_nsec = (long) (us % 1000000) * 1000;
  return (int) er(sc2(NR_nanosleep, (long) &ts, 0)); }
time_t time(time_t *t) {
  struct timespec ts;
  clock_gettime(0, &ts);                       /* CLOCK_REALTIME */
  if (t) *t = ts.tv_sec;
  return ts.tv_sec; }
unsigned int umask(unsigned int m) { return (unsigned int) sc1(NR_umask, m); }
int setpgid(pid_t p, pid_t g) { return (int) er(sc2(NR_setpgid, p, g)); }
int getpgrp(void) { return (int) sc1(NR_getpgid, 0); }
int setsid(void) { return (int) er(sc0(NR_setsid)); }
int mount(char const *src, char const *tgt, char const *ty, unsigned long fl, void const *d) {
  return (int) er(sc5(NR_mount, (long) src, (long) tgt, (long) ty, (long) fl, (long) d)); }
int unshare(int fl) { return (int) er(sc1(NR_unshare, fl)); }
int clock_gettime(int ck, struct timespec *ts) { return (int) er(sc2(NR_clock_gettime, ck, (long) ts)); }
long pwrite(int fd, void const *b, unsigned long n, long off) { return er(sc4(NR_pwrite64, fd, (long) b, (long) n, off)); }
int memfd_create(char const *name, unsigned int fl) { return (int) er(sc2(NR_memfd_create, (long) name, fl)); }
int utimensat(int dfd, char const *p, struct timespec const *ts, int fl) {
  return (int) er(sc4(NR_utimensat, dfd, (long) p, (long) ts, fl)); }
int utime(char const *path, struct utimbuf const *t) {
  if (!t) return utimensat(AT_FDCWD, path, 0, 0);
  struct timespec ts[2];
  ts[0].tv_sec = t->actime;  ts[0].tv_nsec = 0;
  ts[1].tv_sec = t->modtime; ts[1].tv_nsec = 0;
  return utimensat(AT_FDCWD, path, ts, 0); }

/* ---- the calendar: no timezone database, so localtime IS gmtime (UTC). the
 * civil-from-days is Hinnant's exact integer algorithm (1970-01-01 = Thursday,
 * wday 4). asctime lays glibc's fixed 26-byte "Www Mmm dd hh:mm:ss yyyy\n". ---- */
struct tm *gmtime(time_t const *tp) {
  static struct tm tm;
  long t = *tp;
  long days = t / 86400, secs = t % 86400;
  if (secs < 0) { secs += 86400; days -= 1; }
  tm.tm_hour = (int) (secs / 3600);
  tm.tm_min = (int) (secs % 3600 / 60);
  tm.tm_sec = (int) (secs % 60);
  tm.tm_wday = (int) (((days % 7) + 4 + 7) % 7);
  long z = days + 719468;
  long era = (z >= 0 ? z : z - 146096) / 146097;
  long doe = z - era * 146097;
  long yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
  long y = yoe + era * 400;
  long doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
  long mp = (5 * doy + 2) / 153;
  long d = doy - (153 * mp + 2) / 5 + 1;
  long m = mp < 10 ? mp + 3 : mp - 9;
  y += (m <= 2);
  tm.tm_year = (int) (y - 1900);
  tm.tm_mon = (int) (m - 1);
  tm.tm_mday = (int) d;
  tm.tm_yday = 0;
  tm.tm_isdst = 0;
  tm.tm_gmtoff = 0;
  tm.tm_zone = "UTC";
  return &tm; }
struct tm *localtime(time_t const *tp) { return gmtime(tp); }
static void __d2(char *p, int v) { p[0] = (char) (48 + v / 10 % 10); p[1] = (char) (48 + v % 10); }
char *asctime(struct tm const *tm) {
  static char b[26];
  static char const *wd = "SunMonTueWedThuFriSat";
  static char const *mo = "JanFebMarAprMayJunJulAugSepOctNovDec";
  int i;
  int w = tm->tm_wday, mn = tm->tm_mon, y = tm->tm_year + 1900;
  if (w < 0 || w > 6) w = 0;
  if (mn < 0 || mn > 11) mn = 0;
  for (i = 0; i < 3; i++) b[i] = wd[w * 3 + i];
  b[3] = ' ';
  for (i = 0; i < 3; i++) b[4 + i] = mo[mn * 3 + i];
  b[7] = ' ';
  __d2(b + 8, tm->tm_mday); if (b[8] == '0') b[8] = ' ';
  b[10] = ' ';
  __d2(b + 11, tm->tm_hour); b[13] = ':';
  __d2(b + 14, tm->tm_min);  b[16] = ':';
  __d2(b + 17, tm->tm_sec);  b[19] = ' ';
  __d2(b + 20, y / 100); __d2(b + 22, y % 100);
  b[24] = 10; b[25] = 0;
  return b; }
char *ctime(time_t const *tp) { return asctime(gmtime(tp)); }
void *mmap(void *a, long n, int prot, int fl, int fd, long off) {
  long r = sc6(NR_mmap, (long) a, n, prot, fl, fd, off);
  if ((unsigned long) r > (unsigned long) -4096L) { __errno_v = (int) -r; return (void *) -1; }
  return (void *) r; }
int munmap(void *a, long n) { return (int) er(sc2(NR_munmap, (long) a, n)); }
int mprotect(void *a, long n, int prot) { return (int) er(sc3(NR_mprotect, (long) a, n, prot)); }
long sysconf(int name) {
  if (name == _SC_PAGESIZE) return 4096;
  __errno_v = EINVAL; return -1; }

/* ---- exit: the atexit chain, the stdio flush, then exit_group ---- */
typedef void (*__exitfn)(void);
static __exitfn __atex[32];
static int __natex;
int atexit(void (*f)(void)) {
  if (__natex >= 32) return -1;
  __atex[__natex++] = f;
  return 0; }
void _exit(int c) { for (;;) sc1(NR_exit_group, c); }
void exit(int c) {
  while (__natex > 0) __atex[--__natex]();
  fflush(0);
  _exit(c); }
void abort(void) { raise(SIGABRT); _exit(127); }

/* ---- execvp: execve + the PATH walk ---- */
int execv(char const *p, char *const *av) {
  return (int) er(sc3(NR_execve, (long) p, (long) av, (long) environ)); }
int execvp(char const *f, char *const *av) {
  char const *s = f;
  while (*s) { if (*s == '/') return execv(f, av); s++; }
  char const *path = getenv("PATH");
  if (!path) path = "/usr/local/bin:/usr/bin:/bin";
  char buf[4096];
  size_t fn = strlen(f);
  while (*path) {
    size_t i = 0;
    while (path[i] && path[i] != ':') i++;
    if (i + 1 + fn + 1 < sizeof buf) {
      memcpy(buf, path, i);
      buf[i] = '/';
      memcpy(buf + i + 1, f, fn + 1);
      execv(buf, av); }                     /* returns only on failure; keep walking */
    path += i;
    if (*path == ':') path++; }
  __errno_v = ENOENT;
  return -1; }

/* ---- malloc: K&R's first-fit free list over 1MB mmap arenas. 16-byte units,
 * 16-byte alignment, coalescing free. ai mallocs pools (big, rare) and codec /
 * line buffers (small, freed) -- this shape covers both without ceremony. ---- */
typedef struct __mhdr { struct __mhdr *next; size_t size; } __mhdr;   /* size in units */
static __mhdr __mbase;
static __mhdr *__mfree;
void free(void *p) {
  if (!p) return;
  __mhdr *b = (__mhdr *) p - 1, *q = __mfree;
  for (; !(b > q && b < q->next); q = q->next)
    if (q >= q->next && (b > q || b < q->next)) break;   /* at the arena's wrap point */
  if (b + b->size == q->next) { b->size += q->next->size; b->next = q->next->next; }
  else b->next = q->next;
  if (q + q->size == b) { q->size += b->size; q->next = b->next; }
  else q->next = b;
  __mfree = q; }
static __mhdr *__mcore(size_t nu) {
  size_t need = (nu + 1) * sizeof(__mhdr);
  size_t len = need < (1UL << 20) ? (1UL << 20) : ((need + 4095UL) & ~4095UL);
  void *m = mmap(0, (long) len, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (m == (void *) -1) return 0;
  __mhdr *u = m;
  u->size = len / sizeof(__mhdr);
  free((void *) (u + 1));
  return __mfree; }
void *malloc(size_t n) {
  size_t nu = (n + sizeof(__mhdr) - 1) / sizeof(__mhdr) + 1;
  __mhdr *prev = __mfree;
  if (!prev) { __mbase.next = __mfree = prev = &__mbase; __mbase.size = 0; }
  for (__mhdr *q = prev->next; ; prev = q, q = q->next) {
    if (q->size >= nu) {
      if (q->size == nu) prev->next = q->next;
      else { q->size -= nu; q += q->size; q->size = nu; }
      __mfree = prev;
      return (void *) (q + 1); }
    if (q == __mfree)
      if (!(q = __mcore(nu))) { __errno_v = ENOMEM; return 0; } } }

void *calloc(size_t n, size_t sz) {
  size_t t = n * sz;
  void *p = malloc(t);
  if (p) memset(p, 0, t);
  return p; }
void *realloc(void *p, size_t n) {
  if (!p) return malloc(n);
  if (n == 0) { free(p); return 0; }
  size_t old = (((__mhdr *) p - 1)->size - 1) * sizeof(__mhdr);   /* payload bytes */
  if (old >= n) return p;
  void *q = malloc(n);
  if (!q) return 0;
  memcpy(q, p, old);
  free(p);
  return q; }
/* alloca: no native / __builtin form, so gnulib's C_ALLOCA scheme by hand --
 * malloc-backed, reclaimed by stack depth. both arches grow DOWN, so a frame
 * that has returned sits at a HIGHER address than the current probe; on each
 * call we free every block whose mark sits BELOW `here` (its frame unwound
 * past). blocks from the same or an ancestor frame (mark >= here) stay.
 * leak-free without a stack-direction probe. */
typedef struct __ablk { struct __ablk *next; char *mark; } __ablk;
static __ablk *__ahead;
void *alloca(size_t n) {
  char here;
  while (__ahead && __ahead->mark < &here) { __ablk *d = __ahead; __ahead = d->next; free(d); }
  if (n == 0) return 0;                         /* alloca(0): reclaim only */
  __ablk *b = malloc(sizeof(__ablk) + n);
  if (!b) return 0;
  b->mark = &here;
  b->next = __ahead;
  __ahead = b;
  return (void *) (b + 1); }
int atoi(char const *s) {
  int sign = 1, v = 0;
  while (*s == ' ' || *s == 9) s++;
  if (*s == '-') { sign = -1; s++; } else if (*s == '+') s++;
  while (*s >= '0' && *s <= '9') { v = v * 10 + (*s - '0'); s++; }
  return sign * v; }
long atol(char const *s) {
  long sign = 1, v = 0;
  while (*s == ' ' || *s == 9) s++;
  if (*s == '-') { sign = -1; s++; } else if (*s == '+') s++;
  while (*s >= '0' && *s <= '9') { v = v * 10 + (*s - '0'); s++; }
  return sign * v; }

/* ---- env ---- */
char *getenv(char const *k) {
  size_t n = strlen(k);
  if (!environ) return 0;
  for (char **e = environ; *e; e++)
    if (memcmp(*e, k, n) == 0 && (*e)[n] == '=') return *e + n + 1;
  return 0; }
static int __env_ours;                       /* the array itself came off our malloc */
int setenv(char const *k, char const *v, int ov) {
  size_t kn = strlen(k), vn = strlen(v);
  char *kv = malloc(kn + 1 + vn + 1);
  if (!kv) return -1;
  memcpy(kv, k, kn); kv[kn] = '=';
  memcpy(kv + kn + 1, v, vn + 1);
  size_t cnt = 0;
  if (environ)
    for (char **e = environ; *e; e++, cnt++)
      if (memcmp(*e, k, kn) == 0 && (*e)[kn] == '=') {
        if (!ov) { free(kv); return 0; }
        *e = kv;                             /* the old string may be the kernel's; leak it */
        return 0; }
  char **ne = malloc((cnt + 2) * sizeof(char *));
  if (!ne) { free(kv); return -1; }
  for (size_t i = 0; i < cnt; i++) ne[i] = environ[i];
  ne[cnt] = kv;
  ne[cnt + 1] = 0;
  if (__env_ours) free(environ);
  environ = ne;
  __env_ours = 1;
  return 0; }
int unsetenv(char const *k) {
  size_t kn = strlen(k);
  if (!environ) return 0;
  char **w = environ;
  for (char **e = environ; *e; e++)
    if (!(memcmp(*e, k, kn) == 0 && (*e)[kn] == '=')) *w++ = *e;
  *w = 0;
  return 0; }

/* ---- stdio: FILE is a fd plus (for write streams) a flush buffer. stdout is
 * the one hot stream -- ai's fd_putc sends EVERY output byte through fputc, so
 * it buffers 8KB (line-flushed on a tty, glibc's shape); stderr never buffers;
 * fopen'd streams buffer 4KB. reads are unbuffered (image.c freads whole
 * files), which keeps fseek/ftell honest as plain lseek. ---- */
struct _IO_FILE {
  int fd;
  int wr;                                    /* open for writing */
  int line;                                  /* flush on newline */
  int err;
  int heap;                                  /* buf and FILE both off malloc (fopen) */
  int len, cap;
  unsigned char *buf;
};
static unsigned char __obuf[8192];
static FILE __stdf[3];
FILE *stdin = &__stdf[0], *stdout = &__stdf[1], *stderr = &__stdf[2];

static long __wall(int fd, unsigned char const *p, long n) {
  long i = 0;
  while (i < n) {
    long k = write(fd, p + i, n - i);
    if (k < 0) { if (__errno_v == EINTR) continue; return -1; }
    i += k; }
  return i; }
static int __fdrain(FILE *f) {
  if (f->len == 0) return 0;
  long n = f->len;
  f->len = 0;
  if (__wall(f->fd, f->buf, n) < 0) { f->err = 1; return EOF; }
  return 0; }
int fflush(FILE *f) {
  if (!f) {
    int r = __fdrain(stdout);
    return __fdrain(stderr) || r ? EOF : 0; }
  return __fdrain(f); }
int fputc(int c, FILE *f) {
  unsigned char b = (unsigned char) c;
  if (!f->cap) { if (__wall(f->fd, &b, 1) < 0) { f->err = 1; return EOF; } return b; }
  f->buf[f->len++] = b;
  if (f->len == f->cap || (f->line && b == 10))
    if (__fdrain(f)) return EOF;
  return b; }
size_t fwrite(void const *p, size_t sz, size_t n, FILE *f) {
  size_t total = sz * n;
  if (total == 0) return 0;
  if (!f->cap || total >= (size_t) f->cap) {
    if (__fdrain(f)) return 0;
    if (__wall(f->fd, p, (long) total) < 0) { f->err = 1; return 0; }
    return n; }
  if ((size_t) (f->cap - f->len) < total && __fdrain(f)) return 0;
  memcpy(f->buf + f->len, p, total);
  f->len += (int) total;
  if (f->line) { unsigned char const *q = p; for (size_t i = 0; i < total; i++) if (q[i] == 10) { __fdrain(f); break; } }
  return n; }
size_t fread(void *p, size_t sz, size_t n, FILE *f) {
  size_t total = sz * n, got = 0;
  unsigned char *d = p;
  while (got < total) {
    long k = read(f->fd, d + got, (long) (total - got));
    if (k < 0) { if (__errno_v == EINTR) continue; f->err = 1; break; }
    if (k == 0) break;
    got += (size_t) k; }
  return sz ? got / sz : 0; }
FILE *fopen(char const *path, char const *mode) {
  int fl = O_RDONLY, wr = 0;
  if (mode[0] == 'w') { fl = O_WRONLY | O_CREAT | O_TRUNC; wr = 1; }
  else if (mode[0] == 'a') { fl = O_WRONLY | O_CREAT | O_APPEND; wr = 1; }
  for (char const *m = mode + 1; *m; m++)
    if (*m == '+') { fl = (fl & ~3) | O_RDWR; wr = 1; }
  int fd = open(path, fl, 438);              /* 0666, the umask trims it */
  if (fd < 0) return 0;
  FILE *f = malloc(sizeof(FILE) + 4096);
  if (!f) { close(fd); return 0; }
  memset(f, 0, sizeof(FILE));
  f->fd = fd;
  f->wr = wr;
  f->heap = 1;
  if (wr) { f->buf = (unsigned char *) (f + 1); f->cap = 4096; }
  return f; }
int fclose(FILE *f) {
  int r = __fdrain(f);
  if (close(f->fd) < 0) r = EOF;
  if (f->heap) free(f);
  return r; }
int fseek(FILE *f, long off, int wh) {
  if (__fdrain(f)) return -1;
  return lseek(f->fd, off, wh) < 0 ? -1 : 0; }
long ftell(FILE *f) {
  if (__fdrain(f)) return -1;
  return lseek(f->fd, 0, SEEK_CUR); }
int fileno(FILE *f) { return f->fd; }

/* ---- the one formatter under fprintf and snprintf: %s %c %d %u %x with the
 * l/z widths -- the shapes the host actually speaks (no floats anywhere; ai
 * prints its own numbers). sink+ctx so neither caller stages a bound buffer. */
static void __femit(void *ctx, int c) { fputc(c, (FILE *) ctx); }
struct __sctx { char *p; size_t n, at; };
static void __semit(void *ctx, int c) {
  struct __sctx *s = ctx;
  if (s->at + 1 < s->n) s->p[s->at] = (char) c;
  s->at++; }
static void __pad(void (*put)(void *, int), void *ctx, int n, int ch) { while (n-- > 0) put(ctx, ch); }
/* one integer field with %[-0]WIDTH: digits reversed into tmp, then sign +
 * pad (zeros hug the digits, spaces sit outside) + digits, or left-justified. */
static void __fmtnum(void (*put)(void *, int), void *ctx, unsigned long v, unsigned base,
                     int neg, int width, int zero, int left) {
  char tmp[24];
  int nd = 0;
  do { unsigned d = (unsigned) (v % base); tmp[nd++] = (char) (d < 10 ? 48 + d : 87 + d); v /= base; } while (v);
  int len = nd + (neg ? 1 : 0);
  int pad = width > len ? width - len : 0;
  if (!left && !zero) __pad(put, ctx, pad, 32);
  if (neg) put(ctx, 45);
  if (!left && zero) __pad(put, ctx, pad, 48);
  while (nd) put(ctx, tmp[--nd]);
  if (left) __pad(put, ctx, pad, 32); }
static void __fmt(void (*put)(void *, int), void *ctx, char const *fmt, va_list ap) {
  for (; *fmt; fmt++) {
    if (*fmt != '%') { put(ctx, *fmt); continue; }
    fmt++;
    int left = 0, zero = 0, width = 0, prec = -1, wide = 0;
    for (; ; fmt++) {                        /* flags: - and 0 act; + space # ignored */
      if (*fmt == '-') left = 1;
      else if (*fmt == '0') zero = 1;
      else if (*fmt == '+' || *fmt == ' ' || *fmt == '#') ;
      else break; }
    while (*fmt >= '0' && *fmt <= '9') { width = width * 10 + (*fmt - 48); fmt++; }
    if (*fmt == '.') { fmt++; prec = 0; while (*fmt >= '0' && *fmt <= '9') { prec = prec * 10 + (*fmt - 48); fmt++; } }
    while (*fmt == 'l' || *fmt == 'z' || *fmt == 'h') { if (*fmt != 'h') wide = 1; fmt++; }
    if (left) zero = 0;
    if (*fmt == 's') {
      char const *s = va_arg(ap, char const *);
      if (!s) s = "(null)";
      int len = 0;
      while (s[len] && (prec < 0 || len < prec)) len++;
      int pad = width > len ? width - len : 0;
      if (!left) __pad(put, ctx, pad, 32);
      for (int i = 0; i < len; i++) put(ctx, s[i]);
      if (left) __pad(put, ctx, pad, 32); }
    else if (*fmt == 'c') {
      int pad = width > 1 ? width - 1 : 0;
      if (!left) __pad(put, ctx, pad, 32);
      put(ctx, va_arg(ap, int));
      if (left) __pad(put, ctx, pad, 32); }
    else if (*fmt == 'd' || *fmt == 'i') {
      long v = wide ? va_arg(ap, long) : (long) va_arg(ap, int);
      unsigned long u = (unsigned long) v;
      int neg = v < 0;
      if (neg) u = 0UL - u;
      __fmtnum(put, ctx, u, 10, neg, width, zero, left); }
    else if (*fmt == 'u')
      __fmtnum(put, ctx, wide ? va_arg(ap, unsigned long) : (unsigned long) va_arg(ap, unsigned int), 10, 0, width, zero, left);
    else if (*fmt == 'x' || *fmt == 'X')
      __fmtnum(put, ctx, wide ? va_arg(ap, unsigned long) : (unsigned long) va_arg(ap, unsigned int), 16, 0, width, zero, left);
    else if (*fmt == 'o')
      __fmtnum(put, ctx, wide ? va_arg(ap, unsigned long) : (unsigned long) va_arg(ap, unsigned int), 8, 0, width, zero, left);
    else if (*fmt == 'p') { put(ctx, 48); put(ctx, 120); __fmtnum(put, ctx, (unsigned long) va_arg(ap, void *), 16, 0, 0, 0, 0); }
    else if (*fmt == '%') put(ctx, 37);
    else { put(ctx, 37); if (*fmt) put(ctx, *fmt); else fmt--; } }
}
int fprintf(FILE *f, char const *fmt, ...) {
  va_list ap; va_start(ap, fmt);
  __fmt(__femit, f, fmt, ap);
  va_end(ap);
  return 0; }
int snprintf(char *p, size_t n, char const *fmt, ...) {
  struct __sctx s;
  s.p = p; s.n = n; s.at = 0;
  va_list ap; va_start(ap, fmt);
  __fmt(__semit, &s, fmt, ap);
  va_end(ap);
  if (n) p[s.at < n ? s.at : n - 1] = 0;
  return (int) s.at; }
int printf(char const *fmt, ...) {
  va_list ap; va_start(ap, fmt);
  __fmt(__femit, stdout, fmt, ap);
  va_end(ap);
  return 0; }
/* the v-variants: __fmt already threads a va_list, so these just forward it. */
int vfprintf(FILE *f, char const *fmt, va_list ap) {
  __fmt(__femit, f, fmt, ap); return 0; }
int vprintf(char const *fmt, va_list ap) {
  __fmt(__femit, stdout, fmt, ap); return 0; }
int vsnprintf(char *p, size_t n, char const *fmt, va_list ap) {
  struct __sctx s; s.p = p; s.n = n; s.at = 0;
  __fmt(__semit, &s, fmt, ap);
  if (n) p[s.at < n ? s.at : n - 1] = 0;
  return (int) s.at; }
int vsprintf(char *p, char const *fmt, va_list ap) {
  return vsnprintf(p, (size_t) -1, fmt, ap); }
int sprintf(char *p, char const *fmt, ...) {
  va_list ap; va_start(ap, fmt);
  int r = vsprintf(p, fmt, ap);
  va_end(ap); return r; }
int putc(int c, FILE *f) { return fputc(c, f); }
void perror(char const *s) {
  int e = __errno_v;
  if (s && *s) fprintf(stderr, "%s: ", s);
  fprintf(stderr, "errno %d\n", e); }
char *fgets(char *buf, int n, FILE *f) {
  int i = 0;
  while (i < n - 1) {
    char c;
    long k = read(f->fd, &c, 1);
    if (k <= 0) { if (i == 0) return 0; break; }
    buf[i++] = c;
    if (c == 10) break; }
  buf[i] = 0;
  return buf; }

/* ---- signals: glibc's 152-byte sigaction folded onto the kernel's 32-byte
 * one. BOTH arches carry the restorer slot (aarch64 is the odd asm-generic
 * arch that kept SA_RESTORER in its uapi) -- but only x86-64 needs it filled
 * (sys.o's __ai_sigret); aarch64 leaves flag+slot zero and the kernel lays
 * its vdso return trampoline. ---- */
struct __ksigaction { void *h; unsigned long flags; void *restorer; unsigned long mask; };
int sigemptyset(sigset_t *s) { memset(s, 0, sizeof *s); return 0; }
int sigaddset(sigset_t *s, int n) {
  s->__v[(n - 1) / 64] |= 1UL << ((unsigned) (n - 1) % 64);
  return 0; }
int sigaction(int sig, struct sigaction const *a, struct sigaction *old) {
  struct __ksigaction ka, ko;
  memset(&ko, 0, sizeof ko);
  if (a) {
    ka.h = (void *) a->sa_handler;
#ifdef __aarch64__
    ka.flags = (unsigned long) (unsigned int) a->sa_flags;
    ka.restorer = 0;
#else
    ka.flags = (unsigned long) (unsigned int) a->sa_flags | 67108864UL;   /* SA_RESTORER */
    ka.restorer = (void *) __ai_sigret;
#endif
    ka.mask = (unsigned long) a->sa_mask.__v[0]; }
  long r = sc4(NR_rt_sigaction, sig, a ? (long) &ka : 0, old ? (long) &ko : 0, 8);
  if (r < 0) { __errno_v = (int) -r; return -1; }
  if (old) {
    memset(old, 0, sizeof *old);
    old->sa_handler = (void (*)(int)) ko.h;
    old->sa_flags = (int) ko.flags;
    old->sa_mask.__v[0] = (long) ko.mask; }
  return 0; }
void *signal(int sig, void *h) {
  struct sigaction sa, old;
  memset(&sa, 0, sizeof sa);
  sa.sa_handler = (void (*)(int)) h;
  sa.sa_flags = 268435456;                   /* SA_RESTART: glibc signal() semantics */
  if (sigaction(sig, &sa, &old)) return (void *) -1;
  return (void *) old.sa_handler; }
int sigprocmask(int how, sigset_t const *s, sigset_t *o) {
  unsigned long ks = s ? (unsigned long) s->__v[0] : 0, ko = 0;
  long r = sc4(NR_rt_sigprocmask, how, s ? (long) &ks : 0, o ? (long) &ko : 0, 8);
  if (r < 0) { __errno_v = (int) -r; return -1; }
  if (o) { memset(o, 0, sizeof *o); o->__v[0] = (long) ko; }
  return 0; }
int signalfd(int fd, sigset_t const *m, int fl) {
  unsigned long km = (unsigned long) m->__v[0];
  return (int) er(sc4(NR_signalfd4, fd, (long) &km, 8, fl)); }

/* ---- the terminal ---- */
int tcgetattr(int fd, struct termios *t) { return ioctl(fd, 21505, t); }            /* TCGETS */
int tcsetattr(int fd, int act, struct termios const *t) {
  if (act < 0 || act > 2) { __errno_v = EINVAL; return -1; }
  return ioctl(fd, (unsigned long) (21506 + act), t); }                             /* TCSETS/W/F */
int tcsetpgrp(int fd, pid_t pg) { int p = (int) pg; return ioctl(fd, 21520, &p); }  /* TIOCSPGRP */
int isatty(int fd) {
  struct termios t;
  return tcgetattr(fd, &t) == 0; }

/* ---- the pty quartet ---- */
int posix_openpt(int fl) { return open("/dev/ptmx", fl, 0); }
int grantpt(int fd) { (void) fd; return 0; }                    /* devpts grants at open */
int unlockpt(int fd) { int z = 0; return ioctl(fd, 1074025521UL, &z); }   /* TIOCSPTLCK */
char *ptsname(int fd) {
  static char nb[32];
  int n = 0;
  if (ioctl(fd, 2147767344UL, &n) < 0) return 0;                /* TIOCGPTN */
  snprintf(nb, sizeof nb, "/dev/pts/%d", n);
  return nb; }

/* ---- dirent over getdents64: the kernel record IS our struct dirent ---- */
struct __dirstream { int fd; int pos; int len; char buf[4096]; };
DIR *opendir(char const *p) {
  int fd = open(p, O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0);
  if (fd < 0) return 0;
  DIR *d = malloc(sizeof(DIR));
  if (!d) { close(fd); return 0; }
  d->fd = fd; d->pos = 0; d->len = 0;
  return d; }
struct dirent *readdir(DIR *d) {
  if (d->pos >= d->len) {
    long n = sc3(NR_getdents64, d->fd, (long) d->buf, sizeof d->buf);
    if (n <= 0) { if (n < 0) __errno_v = (int) -n; return 0; }
    d->len = (int) n; d->pos = 0; }
  struct dirent *e = (struct dirent *) (d->buf + d->pos);
  d->pos += e->d_reclen;
  return e; }
int closedir(DIR *d) {
  int r = close(d->fd);
  free(d);
  return r; }

/* ---- byte order ---- */
unsigned short htons(unsigned short v) { return (unsigned short) ((v << 8) | (v >> 8)); }
unsigned short ntohs(unsigned short v) { return htons(v); }
unsigned int htonl(unsigned int v) {
  return (v << 24) | ((v & 65280U) << 8) | ((v >> 8) & 65280U) | (v >> 24); }
unsigned int ntohl(unsigned int v) { return htonl(v); }

/* ---- getaddrinfo, the numeric slice: dotted-quad IPv4 + localhost + a decimal
 * port -- exactly what the host seam speaks (host/net.c resolves numbers; DNS
 * stays a post-rung nicety). one malloc'd block carries result + address. ---- */
struct __sain { unsigned short fam; unsigned short port; unsigned int addr; char pad[8]; };   /* sockaddr_in, 16 bytes */
struct __gai { struct addrinfo ai; struct __sain sa; };
static int __quad(char const *s, unsigned int *out) {
  unsigned int a = 0;
  for (int i = 0; i < 4; i++) {
    unsigned int b = 0, any = 0;
    while (*s >= 48 && *s <= 57) { b = b * 10 + (unsigned) (*s++ - 48); any = 1; if (b > 255) return -1; }
    if (!any) return -1;
    a = (a << 8) | b;
    if (i < 3 && *s++ != 46) return -1; }
  if (*s) return -1;
  *out = a;
  return 0; }
int getaddrinfo(char const *host, char const *serv, struct addrinfo const *hints, struct addrinfo **res) {
  unsigned int a4 = 2130706433U;             /* 127.0.0.1 */
  if (host) {
    if (strcmp(host, "localhost") != 0 && __quad(host, &a4) < 0) return -2;   /* EAI_NONAME */
  } else if (hints && (hints->ai_flags & AI_PASSIVE)) a4 = 0;                 /* INADDR_ANY */
  unsigned int port = 0;
  if (serv) {
    char const *s = serv;
    if (!*s) return -2;
    while (*s >= 48 && *s <= 57) port = port * 10 + (unsigned) (*s++ - 48);
    if (*s || port > 65535) return -2; }
  struct __gai *g = malloc(sizeof(struct __gai));
  if (!g) return -10;                        /* EAI_MEMORY */
  memset(g, 0, sizeof *g);
  g->sa.fam = AF_INET;
  g->sa.port = htons((unsigned short) port);
  g->sa.addr = htonl(a4);
  g->ai.ai_family = AF_INET;
  g->ai.ai_socktype = hints && hints->ai_socktype ? hints->ai_socktype : SOCK_STREAM;
  g->ai.ai_protocol = hints ? hints->ai_protocol : 0;
  g->ai.ai_addrlen = 16;
  g->ai.ai_addr = (struct sockaddr *) &g->sa;
  *res = &g->ai;
  return 0; }
void freeaddrinfo(struct addrinfo *r) { free(r); }

/* ---- sockets ---- */
int socket(int d, int t, int p) { return (int) er(sc3(NR_socket, d, t, p)); }
int connect(int fd, struct sockaddr const *a, socklen_t n) { return (int) er(sc3(NR_connect, fd, (long) a, n)); }
int accept(int fd, struct sockaddr *a, socklen_t *n) { return (int) er(sc3(NR_accept, fd, (long) a, (long) n)); }
long sendto(int fd, void const *b, unsigned long n, int fl, struct sockaddr const *a, socklen_t an) {
  return er(sc6(NR_sendto, fd, (long) b, (long) n, fl, (long) a, an)); }
long recvfrom(int fd, void *b, unsigned long n, int fl, struct sockaddr *a, socklen_t *an) {
  return er(sc6(NR_recvfrom, fd, (long) b, (long) n, fl, (long) a, (long) an)); }
long sendmsg(int fd, struct msghdr const *m, int fl) { return er(sc3(NR_sendmsg, fd, (long) m, fl)); }
long recvmsg(int fd, struct msghdr *m, int fl) { return er(sc3(NR_recvmsg, fd, (long) m, fl)); }
int shutdown(int fd, int how) { return (int) er(sc2(NR_shutdown, fd, how)); }
int bind(int fd, struct sockaddr const *a, socklen_t n) { return (int) er(sc3(NR_bind, fd, (long) a, n)); }
int listen(int fd, int bl) { return (int) er(sc2(NR_listen, fd, bl)); }
int setsockopt(int fd, int lv, int op, void const *v, socklen_t n) {
  return (int) er(sc5(NR_setsockopt, fd, lv, op, (long) v, n)); }

/* ---- strtol / strtod: the reader's number path. the bodies keep libc/str.c's
 * exact semantics (the kernel corpus runs them; the naive strtod measured
 * corpus-green against glibc's in the rung-4 differential). ---- */
static int __digval(int c) {
  if (c >= 48 && c <= 57) return c - 48;
  if (c >= 97 && c <= 122) return c - 87;
  if (c >= 65 && c <= 90) return c - 55;
  return 99; }
long strtol(char const *s, char **endptr, int base) {
  char const *p = s;
  int sign = 1;
  while (*p == 32 || (*p >= 9 && *p <= 13)) p++;
  if (*p == '-') { sign = -1; p++; }
  else if (*p == '+') p++;
  if (*p == '0') {
    ++p;
    if ((base == 0 || base == 16) && (*p == 'x' || *p == 'X')) {
      base = 16;
      ++p;
      if (__digval(*p) >= base) p -= 2; }
    else if (base == 0) { base = 8; --p; }
    else --p; }
  else if (!base) base = 10;
  if (base < 2 || base > 36) return 0;
  int any = 0;
  long rc = 0;
  for (int d; (d = __digval(*p)) < base; p++) { any = 1; rc = rc * base + d; }
  if (endptr) *endptr = (char *) (any ? p : s);
  return any ? sign * rc : 0; }
double strtod(char const *s, char **end) {
  char const *p = s;
  int sign = 1;
  if (*p == '-') { sign = -1; p++; }
  else if (*p == '+') p++;
  int any = 0;
  double v = 0;
  while (*p >= 48 && *p <= 57) { v = v * 10 + (*p++ - 48); any = 1; }
  if (*p == '.') {
    p++;
    double scale = 0.1;
    while (*p >= 48 && *p <= 57) { v += (*p++ - 48) * scale; scale *= 0.1; any = 1; } }
  if (!any) { if (end) *end = (char *) s; return 0; }
  if (*p == 'e' || *p == 'E') {
    char const *q = p++;
    int esign = 1;
    if (*p == '-') { esign = -1; p++; }
    else if (*p == '+') p++;
    if (!(*p >= 48 && *p <= 57)) p = q;
    else {
      int e = 0;
      while (*p >= 48 && *p <= 57) e = e * 10 + (*p++ - 48);
      double scale = 1;
      while (e--) scale *= 10;
      v = esign > 0 ? v * scale : v / scale; } }
  if (end) *end = (char *) p;
  return sign * v; }
/* the unsigned twin: strtol's digit walk, no sign, wrapping like glibc's. */
static unsigned long __strtoux(char const *s, char **endptr, int base) {
  char const *p = s;
  int neg = 0;
  while (*p == 32 || (*p >= 9 && *p <= 13)) p++;
  if (*p == '-') { neg = 1; p++; } else if (*p == '+') p++;
  if (*p == '0') {
    ++p;
    if ((base == 0 || base == 16) && (*p == 'x' || *p == 'X')) { base = 16; ++p; if (__digval(*p) >= base) p -= 2; }
    else if (base == 0) { base = 8; --p; }
    else --p; }
  else if (!base) base = 10;
  if (base < 2 || base > 36) return 0;
  int any = 0;
  unsigned long rc = 0;
  for (int d; (d = __digval(*p)) < base; p++) { any = 1; rc = rc * (unsigned) base + (unsigned) d; }
  if (endptr) *endptr = (char *) (any ? p : s);
  return neg ? 0UL - rc : rc; }
unsigned long strtoul(char const *s, char **endptr, int base) { return __strtoux(s, endptr, base); }
unsigned long strtoull(char const *s, char **endptr, int base) { return __strtoux(s, endptr, base); }
unsigned long strtoumax(char const *s, char **endptr, int base) { return __strtoux(s, endptr, base); }

/* qsort: shellsort (Ciura-ish 3x gaps would be nicer, but n/2 halving is small
 * and tar's arrays are short). in-place byte swap of size-sz elements. */
void qsort(void *base, size_t n, size_t sz, int (*cmp)(void const *, void const *)) {
  char *a = base;
  for (size_t gap = n / 2; gap > 0; gap /= 2)
    for (size_t i = gap; i < n; i++)
      for (size_t j = i; j >= gap && cmp(a + (j - gap) * sz, a + j * sz) > 0; j -= gap) {
        char *x = a + (j - gap) * sz, *y = a + j * sz;
        for (size_t k = 0; k < sz; k++) { char t = x[k]; x[k] = y[k]; y[k] = t; } } }

/* exec's variadic pair: gather (arg0, .., NULL) off the stack, then execv[p]. */
int execl(char const *p, char const *a0, ...) {
  char *av[256]; int n = 0;
  va_list ap; va_start(ap, a0);
  av[n++] = (char *) a0;
  while (n < 255 && (av[n] = va_arg(ap, char *))) n++;
  av[n] = 0;
  va_end(ap);
  return execv(p, av); }
int execlp(char const *f, char const *a0, ...) {
  char *av[256]; int n = 0;
  va_list ap; va_start(ap, a0);
  av[n++] = (char *) a0;
  while (n < 255 && (av[n] = va_arg(ap, char *))) n++;
  av[n] = 0;
  va_end(ap);
  return execvp(f, av); }
/* system: fork, /bin/sh -c, wait. no signal juggling (ai is single-threaded). */
int system(char const *cmd) {
  if (!cmd) return 1;                          /* a shell is available */
  int pid = fork();
  if (pid < 0) return -1;
  if (pid == 0) {
    char *av[4]; av[0] = "sh"; av[1] = "-c"; av[2] = (char *) cmd; av[3] = 0;
    execv("/bin/sh", av);
    _exit(127); }
  int st = 0;
  while (waitpid(pid, &st, 0) < 0) if (__errno_v != EINTR) return -1;
  return st; }
/* one fixed "C" locale, so setlocale just answers its name. */
char *setlocale(int cat, char const *loc) { (void) cat; (void) loc; return (char *) "C"; }

/* getc/fputs/ferror over the unbuffered read streams; fscanf reads char-by-char
 * (no ungetc, so it consumes the field terminator -- tar's lone use is "%d"). */
int getc(FILE *f) {
  unsigned char c;
  long k = read(f->fd, &c, 1);
  if (k <= 0) { if (k < 0) f->err = 1; return EOF; }
  return c; }
int fputs(char const *s, FILE *f) { size_t n = strlen(s); return fwrite(s, 1, n, f) == n ? 0 : EOF; }
int ferror(FILE *f) { return f->err; }
int fscanf(FILE *f, char const *fmt, ...) {
  va_list ap; va_start(ap, fmt);
  int got = 0, c;
  for (; *fmt; fmt++) {
    if (*fmt == '%') {
      fmt++;
      if (*fmt == 'd' || *fmt == 'u' || *fmt == 'x' || *fmt == 's')
        do { c = getc(f); } while (c == 32 || (c >= 9 && c <= 13));
      if (*fmt == 'd' || *fmt == 'u' || *fmt == 'x') {
        int base = *fmt == 'x' ? 16 : 10, sign = 1, any = 0, d;
        if (*fmt == 'd' && (c == '-' || c == '+')) { if (c == '-') sign = -1; c = getc(f); }
        long v = 0;
        while ((d = __digval(c)) < base) { v = v * base + d; any = 1; c = getc(f); }
        if (!any) break;
        *va_arg(ap, int *) = (int) (sign * v);
        got++; }
      else if (*fmt == 's') {
        char *out = va_arg(ap, char *); int i = 0;
        while (c != EOF && !(c == 32 || (c >= 9 && c <= 13))) { out[i++] = (char) c; c = getc(f); }
        out[i] = 0; got++; }
      else if (*fmt == 'c') { c = getc(f); if (c == EOF) break; *va_arg(ap, char *) = (char) c; got++; } }
    else if (*fmt == 32 || (*fmt >= 9 && *fmt <= 13)) ;   /* fmt whitespace: no peek, skip */
    else { c = getc(f); if (c != (unsigned char) *fmt) break; } }
  va_end(ap);
  return got; }

/* no name database yet: every passwd/group lookup misses, so tar prints numeric
 * owner/group (its own fallback). a real /etc/passwd walk is a later rung. */
struct passwd *getpwuid(uid_t u) { (void) u; return 0; }
struct passwd *getpwnam(char const *n) { (void) n; return 0; }
struct group *getgrgid(gid_t g) { (void) g; return 0; }
struct group *getgrnam(char const *n) { (void) n; return 0; }
void setgrent(void) { }

/* ---- dl_iterate_phdr off the auxv (AT_PHDR/AT_PHNUM): our exes are ET_EXEC,
 * so the bias is 0 and one callback covers "the main program" -- all image.c's
 * bake walk wants. ---- */
int dl_iterate_phdr(int (*cb)(struct dl_phdr_info *, unsigned long, void *), void *data) {
  unsigned long phdr = 0, phnum = 0;
  for (long *a = __auxv; a && a[0]; a += 2) {
    if (a[0] == 3) phdr = (unsigned long) a[1];        /* AT_PHDR */
    if (a[0] == 5) phnum = (unsigned long) a[1]; }     /* AT_PHNUM */
  if (!phdr) return 0;
  struct dl_phdr_info in;
  memset(&in, 0, sizeof in);
  in.dlpi_addr = 0;
  in.dlpi_name = "";
  in.dlpi_phdr = (Elf64_Phdr const *) phdr;
  in.dlpi_phnum = (Elf64_Half) phnum;
  return cb(&in, sizeof in, data); }

/* ---- the entry: crt0 hands us the OS stack pointer (argc at [sp]); unpack
 * argv/envp/auxv, arm stdio, run main, exit with its answer. this STRONG
 * definition overrides crt0's weak call-main tail (the linker's weak machinery
 * is the whole switch -- no flags anywhere). ---- */
void __ai_start(long *sp) {
  long argc = sp[0];
  char **argv = (char **) (sp + 1);
  char **e = argv + argc + 1;
  environ = e;
  while (*e) e++;
  __auxv = (long *) (e + 1);
  stdout->fd = 1;
  stdout->wr = 1;
  stdout->buf = __obuf;
  stdout->cap = sizeof __obuf;
  stdout->line = isatty(1);
  stderr->fd = 2;
  stderr->wr = 1;
  exit(main((int) argc, argv)); }
