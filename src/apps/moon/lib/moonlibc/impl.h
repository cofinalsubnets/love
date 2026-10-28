/* impl.h -- the shared head of every moonlibc member. members link by need, so one
 * reaches another's state by its public name (errno, not __errno_v) or through here */
#ifndef LvMoonlibcImplH
#define LvMoonlibcImplH
#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <limits.h>
#include <signal.h>
#include <setjmp.h>
#include <poll.h>
#include <sys/select.h>
#include <locale.h>
#include <time.h>
#include <sys/time.h>
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

#include <netinet/in.h>

extern long __love_sys(long n, long a, long b, long c, long d, long e, long f);
/* the tables compile everywhere but wasm; without the sigtramp netbsd's sigaction refuses by name */
#if !defined(__wasm__)   /* wasm's one kernel is the page's loader */
# define LvOsTranslate 1        /* os.c's tables, and the leaves they call */
# define LvNbTramp 1            /* netbsd's signal return path */
#endif
#if defined(__x86_64__) && defined(LvOsTranslate)
# define LvMac 1                /* macos: mksys's xnu leaves, a mach-o's kernel */
#endif
#if defined(__ARM_EABI__) || defined(__i386__)
extern long __love_sys8(long n, long a, long b, long c, long d, long e, long f, long g, long h);   /* a BSD's mmap: 8 words */
extern long long __love_sysw(long n, long a, long b, long c, long d, long e, long f);   /* ..and its lseek, r0:r1 */
#ifdef __ARM_EABI__
extern long __love_fbfork(void);         /* freebsd's fork, made from arm state */
# define LvFbPad 1                       /* freebsd pads a 64-bit arg to an even slot here; netbsd does everywhere */
#else
# define LvFbPad 0
#endif
#elif defined(LvOsTranslate)
extern long __love_sys7(long n, long a, long b, long c, long d, long e, long f, long g);   /* the 7th arg rides the stack (netbsd mmap) */
#endif
extern void __love_sigret(void);
#ifdef __i386__
extern void __love_sigret0(void);          /* the old frame's sigreturn */
#endif
extern int main(int, char**);

/* FILE's layout, opaque in stdio.h */
struct _IO_FILE {
  int fd;
  int wr;                                    /* open for writing */
  int line;                                  /* flush on newline */
  int err;
  int eof;                                   /* a read hit end-of-file (feof) */
  int heap;                                  /* buf and FILE both off malloc (fopen) */
  int pid;                                   /* popen's child, for pclose's wait */
  int un;                                    /* ungetc's pushback byte + 1 (0 = none) */
  int len, cap;
  unsigned char *buf;
  int rp, rl, rcap;                          /* a read-only stream's buffer: rb[rp..rl) is read ahead */
  unsigned char *rb;
  struct _IO_FILE *next;                     /* the open streams past the standard three (stdio/fflush.c) */
  char **mp; size_t *ms;                     /* open_memstream's: buf grows, and every write lays it here */
};

/* freebsd's syscall numbers, machine-independent; os.c pairs them with the canonical.
 * a canonical name absent here is a mechanism that differs, owed a freebsd body */
#define NR_fb_read            3
#define NR_fb_write           4
#define NR_fb_close           6
#define NR_fb_fstat         551   /* ino64; another struct stat */
#define NR_fb_lseek         478
#define NR_fb_nanosleep     240
#define NR_fb_mmap          477
#define NR_fb_mprotect       74
#define NR_fb_munmap         73
#define NR_fb_madvise        75
#define NR_fb_msync          65
#define NR_fb_copy_file_range 569
#define NR_fb_mincore        78
#define NR_fb_rt_sigaction  416   /* sigaction; no restorer, another ksigaction */
#define NR_fb_rt_sigprocmask 340  /* sigprocmask; 16-byte set, no size arg */
#define NR_fb_ioctl          54   /* the requests are another encoding */
#define NR_fb_pread64       475
#define NR_fb_pwrite64      476
#define NR_fb_getpid         20
#define NR_fb_getppid        39
#define NR_fb_setuid         23
#define NR_fb_setgid        181
#define NR_fb_setgroups      80
#define NR_fb_setresuid     311
#define NR_fb_sigaltstack    53   /* stack_t orders size before flags */
#define NR_fb_setresgid     312
#define NR_fb_geteuid        25
#define NR_fb_getegid        43
#define NR_fb_sendfile      393   /* another signature */
#define NR_fb_pselect6      522   /* pselect; the 6th arg is a plain sigset* */
#define NR_fb_socket         97
#define NR_fb_socketpair    135
#define NR_fb_connect        98
#define NR_fb_accept         30
#define NR_fb_sendto        133
#define NR_fb_getsockname    32
#define NR_fb_getpeername    31
#define NR_fb_recvfrom       29
#define NR_fb_sendmsg        28
#define NR_fb_recvmsg        27
#define NR_fb_shutdown      134
#define NR_fb_bind          104
#define NR_fb_listen        106
#define NR_fb_getsockopt    118
#define NR_fb_setsockopt    105
#define NR_fb_fork            2   /* fork(2) is real here */
#define NR_fb_execve         59
#define NR_fb_fexecve       492   /* netbsd: 465 */
#define NR_fb_wait4           7
#define NR_fb_getrusage     117
#define NR_fb_getrlimit     194
#define NR_fb_setrlimit     195
#define NR_fb_getpriority   100   /* the nice itself, where linux answers 20 - nice */
#define NR_fb_setpriority    96
#define NR_fb_kill           37
#define NR_fb_fcntl          92
#define NR_fb_fsync          95
#define NR_fb_fdatasync     550
#define NR_fb_fchown        123
#define NR_fb_ftruncate     480
#define NR_fb_getcwd        326   /* __getcwd */
#define NR_fb_chdir          12
#define NR_fb_fchdir         13
#define NR_fb_chroot         61
#define NR_fb_fchmod        124
#define NR_fb_umask          60
#define NR_fb_getuid         24
#define NR_fb_getgid         47
#define NR_fb_setpgid        82
#define NR_fb_setsid        147
#define NR_fb_getpgid       207
#define NR_fb_mount          21   /* (type dir flags data) */
#define NR_fb_getdirentries 554   /* ino64; the record IS the freebsd dirent (readdir.c) */
#define NR_fb___sysctl      202   /* sysctl(3)'s door (selfpath's KERN_PROC_PATHNAME) */
#define NR_fb_posix_openpt  504   /* a real syscall here; linux opens /dev/ptmx */
#define NR_fb_kqueue        362   /* netbsd: 344 */
#define NR_fb_kevent        560   /* post-12 record, ext[4] (netbsd: __kevent50 435) */
#define NR_fb_clock_gettime 232
#define NR_fb_exit            1   /* exit: one thread here, so one exit is the whole act */
#define NR_fb_openat        499
#define NR_fb_mkdirat       496
#define NR_fb_mknodat       559
#define NR_fb_fchownat      491
#define NR_fb_faccessat     489
#define NR_fb_newfstatat    552   /* fstatat; another struct stat */
#define NR_fb_unlinkat      503
#define NR_fb_renameat      501
#define NR_fb_linkat        495
#define NR_fb_symlinkat     502
#define NR_fb_readlinkat    500
#define NR_fb_fchmodat      490
#define NR_fb_ppoll         545   /* 4 args; our trailing sigsetsize rides an ignored register */
/*      unshare: none */
#define NR_fb_utimensat     547
/*      signalfd4: none -- kqueue / kevent, EVFILT_SIGNAL */
/*      dup3: none -- fcntl F_DUP2FD_CLOEXEC */
#define NR_fb_pipe2         542
/*      memfd_create: none -- shm_open2 571 + SHM_ANON */

/* the canonical NR_* the members say: linux's, per arch */
#if defined(__aarch64__) || defined(__riscv)
#define NR_getcwd          17
#define NR_dup3            24
#define NR_fcntl           25
#define NR_ioctl           29
#define NR_mkdirat         34
#define NR_mknodat         33
#define NR_unlinkat        35
#define NR_nanosleep      101
#define NR_setgid         144
#define NR_setgroups      159
#define NR_setresuid      147
#define NR_sigaltstack    132
#define NR_setresgid      149
#define NR_setuid         146
#define NR_geteuid        175
#define NR_symlinkat       36
#define NR_linkat          37
#define NR_renameat        38
#define NR_renameat2      276   /* riscv is the one asm-generic port without __ARCH_WANT_RENAMEAT */
#define NR_umount2         39
#define NR_mount           40
#define NR_reboot         142
#define NR_ftruncate       46
#define NR_sync            81
#define NR_chdir           49
#define NR_fchdir          50
#define NR_chroot          51
#define NR_fchmod          52
#define NR_fchmodat        53
#define NR_fchownat        54
#define NR_faccessat       48
#define NR_openat          56
#define NR_close           57
#define NR_pipe2           59
#define NR_getdents64      61
#define NR_lseek           62
#define NR_fchown          55
#define NR_read            63
#define NR_write           64
#define NR_pread64         67
#define NR_pwrite64        68
#define NR_ppoll           73
#define NR_signalfd4       74
#define NR_readlinkat      78
#define NR_newfstatat      79
#define NR_fstat           80
#define NR_fsync           82
#define NR_fdatasync       83
#define NR_utimensat       88
#define NR_exit_group      94
#define NR_exit            93    /* this thread alone */
#define NR_futex           98
#define NR_sched_yield    124
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
#define NR_getppid        173
#define NR_getegid        177
#define NR_uname          160
#define NR_sysinfo        179
#define NR_getuid         174
#define NR_getgid         176
#define NR_sendfile        71
#define NR_pselect6        72
#define NR_socket         198
#define NR_socketpair     199
#define NR_bind           200
#define NR_getsockname    204
#define NR_getpeername    205
#define NR_listen         201
#define NR_accept         202
#define NR_connect        203
#define NR_sendto         206
#define NR_recvfrom       207
#define NR_getsockopt     209
#define NR_setsockopt     208
#define NR_shutdown       210
#define NR_sendmsg        211
#define NR_recvmsg        212
#define NR_munmap         215
#define NR_mremap         216
#define NR_clone          220
#define NR_execve         221
#define NR_mmap           222
#define NR_mprotect       226
#define NR_madvise        233
#define NR_msync          227
#define NR_copy_file_range 285
#define NR_mincore        232
#define NR_wait4          260
#define NR_getrusage      165
#define NR_getrlimit      163
#define NR_setrlimit      164
#define NR_getpriority    141
#define NR_setpriority    140
#define NR_statx          291
#define NR_statfs          43
#define NR_fstatfs         44
#define NR_memfd_create   279
#define NR_execveat       281
#elif defined(__ARM_EABI__)
/* arm eabi: 64-bit off_t and time_t through the *64 and *_time64 calls; before linux 5.1
 * the 32-bit twins named beside them answer */
#define NR_read             3
#define NR_write            4
#define NR_close            6
#define NR_mmap           192   /* mmap2 */
#define NR_mprotect       125
#define NR_munmap          91
#define NR_mremap         163
#define NR_madvise        220
#define NR_msync          144
#define NR_copy_file_range 391
#define NR_mincore        219
#define NR_rt_sigaction   174
#define NR_rt_sigprocmask 175
#define NR_ioctl           54
#define NR_pread64        180
#define NR_pwrite64       181
#define NR_getpid          20
#define NR_getppid         64
#define NR_getegid        202   /* getegid32 */
#define NR_uname          122
#define NR_sysinfo        116
#define NR_setuid         213   /* setuid32 */
#define NR_setgid         214   /* setgid32 */
#define NR_setgroups      206   /* setgroups32 */
#define NR_setresuid      208   /* setresuid32 */
#define NR_sigaltstack    186
#define NR_setresgid      210   /* setresgid32 */
#define NR_geteuid        201   /* geteuid32 */
#define NR_sendfile       239   /* sendfile64 */
#define NR_pselect6       413   /* pselect6_time64 */
#define NR_pselect6_32    335
#define NR_socket         281
#define NR_socketpair     288
#define NR_connect        283
#define NR_accept         366   /* accept4 */
#define NR_sendto         290
#define NR_getsockname    286
#define NR_getpeername    287
#define NR_recvfrom       292
#define NR_sendmsg        296
#define NR_recvmsg        297
#define NR_shutdown       293
#define NR_bind           282
#define NR_listen         284
#define NR_getsockopt     295
#define NR_setsockopt     294
#define NR_clone          120
#define NR_execve          11
#define NR_execveat       387
#define NR_wait4          114
#define NR_getrusage       77
#define NR_getrlimit      191   /* ugetrlimit */
#define NR_setrlimit       75
#define NR_getpriority     96
#define NR_setpriority     97
#define NR_statx          397
#define NR_kill            37
#define NR_fcntl          221   /* fcntl64 */
#define NR_fsync          118
#define NR_fdatasync      148
#define NR_fchown         207   /* fchown32 */
#define NR_ftruncate      194   /* ftruncate64 */
#define NR_getcwd         183
#define NR_chdir           12
#define NR_fchdir         133
#define NR_chroot          61
#define NR_fchmod          94
#define NR_umask           60
#define NR_getuid         199   /* getuid32 */
#define NR_getgid         200   /* getgid32 */
#define NR_setpgid         57
#define NR_setsid          66
#define NR_getpgid        132
#define NR_sync            36
#define NR_mount           21
#define NR_reboot          88
#define NR_umount2         52
#define NR_getdents64     217
#define NR_clock_gettime  403   /* clock_gettime64 */
#define NR_clock_gettime_32 263
#define NR_exit_group     248
#define NR_exit             1
#define NR_futex          422   /* futex_time64 */
#define NR_futex_32       240
#define NR_sched_yield    158
#define NR_openat         322
#define NR_mkdirat        323
#define NR_mknodat        324
#define NR_fchownat       325
#define NR_faccessat      334
#define NR_unlinkat       328
#define NR_renameat       329
#define NR_renameat2      382
#define NR_linkat         330
#define NR_symlinkat      331
#define NR_readlinkat     332
#define NR_fchmodat       333
#define NR_ppoll          414   /* ppoll_time64 */
#define NR_ppoll_32       336
#define NR_unshare        337
#define NR_utimensat      412   /* utimensat_time64 */
#define NR_utimensat_32   348
#define NR_signalfd4      355
#define NR_dup3           358
#define NR_pipe2          359
#define NR_memfd_create   385
#define NR__llseek        140
#define NR_clock_nanosleep 407   /* clock_nanosleep_time64 */
#define NR_clock_nanosleep_32 265
#define NR_statfs64       266
#define NR_fstatfs64      267
#define NR_fstatat64      327
#define NR_lseek           19    /* the BSDs' keys in os.c's map: linux's members say _llseek, */
#define NR_fstat          197    /* statx or fstatat64, and clock_nanosleep */
#define NR_newfstatat     327
#define NR_nanosleep      162
#elif defined(__i386__)
/* i386: 64-bit time_t and off_t through the *64 / *_time64 calls; lseek, nanosleep,
 * fstat, statfs and mmap's offset are spelled by their members */
#define NR_read             3
#define NR_write            4
#define NR_close            6
#define NR_mmap           192   /* mmap2 */
#define NR_mprotect       125
#define NR_munmap          91
#define NR_mremap         163
#define NR_madvise        219
#define NR_msync          144
#define NR_copy_file_range 377
#define NR_mincore        218
#define NR_rt_sigaction   174
#define NR_rt_sigprocmask 175
#define NR_ioctl           54
#define NR_pread64        180
#define NR_pwrite64       181
#define NR_getpid          20
#define NR_getppid         64
#define NR_getegid        202   /* getegid32 */
#define NR_uname          122
#define NR_sysinfo        116
#define NR_setuid         213   /* setuid32 */
#define NR_setgid         214   /* setgid32 */
#define NR_setgroups      206   /* setgroups32 */
#define NR_setresuid      208   /* setresuid32 */
#define NR_sigaltstack    186
#define NR_setresgid      210   /* setresgid32 */
#define NR_geteuid        201   /* geteuid32 */
#define NR_sendfile       239   /* sendfile64 */
#define NR_pselect6       413   /* pselect6_time64 */
#define NR_socket         359
#define NR_socketpair     360
#define NR_connect        362
#define NR_accept         364   /* accept4 */
#define NR_sendto         369
#define NR_getsockname    367
#define NR_getpeername    368
#define NR_recvfrom       371
#define NR_sendmsg        370
#define NR_recvmsg        372
#define NR_shutdown       373
#define NR_bind           361
#define NR_listen         363
#define NR_getsockopt     365
#define NR_setsockopt     366
#define NR_clone          120
#define NR_execve          11
#define NR_execveat       358
#define NR_wait4          114
#define NR_getrusage       77
#define NR_getrlimit      191   /* ugetrlimit */
#define NR_setrlimit       75
#define NR_getpriority     96
#define NR_setpriority     97
#define NR_statx          383
#define NR_kill            37
#define NR_fcntl          221   /* fcntl64 */
#define NR_fsync          118
#define NR_fdatasync      148
#define NR_fchown         207   /* fchown32 */
#define NR_ftruncate      194   /* ftruncate64 */
#define NR_getcwd         183
#define NR_chdir           12
#define NR_fchdir         133
#define NR_chroot          61
#define NR_fchmod          94
#define NR_umask           60
#define NR_getuid         199   /* getuid32 */
#define NR_getgid         200   /* getgid32 */
#define NR_setpgid         57
#define NR_setsid          66
#define NR_getpgid        132
#define NR_sync            36
#define NR_mount           21
#define NR_reboot          88
#define NR_umount2         52
#define NR_getdents64     220
#define NR_clock_gettime  403   /* clock_gettime64 */
#define NR_exit_group     252
#define NR_exit             1
#define NR_futex          422   /* futex_time64 */
#define NR_sched_yield    158
#define NR_openat         295
#define NR_mkdirat        296
#define NR_mknodat        297
#define NR_fchownat       298
#define NR_faccessat      307
#define NR_unlinkat       301
#define NR_renameat       302
#define NR_renameat2      353
#define NR_linkat         303
#define NR_symlinkat      304
#define NR_readlinkat     305
#define NR_fchmodat       306
#define NR_ppoll          414   /* ppoll_time64 */
#define NR_unshare        310
#define NR_utimensat      412   /* utimensat_time64 */
#define NR_signalfd4      327
#define NR_dup3           330
#define NR_pipe2          331
#define NR_memfd_create   356
#define NR__llseek        140
#define NR_clock_nanosleep 407   /* clock_nanosleep_time64 */
#define NR_statfs64       268
#define NR_fstatfs64      269
#define NR_lseek           19    /* the BSDs' keys in os.c's map, as arm's */
#define NR_fstat          197
#define NR_newfstatat     300
#define NR_nanosleep      162
#define NR_set_thread_area 243
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
#define NR_mremap          25
#define NR_madvise         28
#define NR_msync           26
#define NR_copy_file_range 326
#define NR_mincore         27
#define NR_rt_sigaction    13
#define NR_rt_sigprocmask  14
#define NR_ioctl           16
#define NR_pread64         17
#define NR_pwrite64        18
#define NR_getpid          39
#define NR_getppid        110
#define NR_getegid        108
#define NR_uname           63
#define NR_sysinfo         99
#define NR_setuid         105
#define NR_setgid         106
#define NR_setgroups      116
#define NR_setresuid      117
#define NR_sigaltstack    131
#define NR_setresgid      119
#define NR_geteuid        107
#define NR_sendfile        40
#define NR_pselect6       270
#define NR_socket          41
#define NR_socketpair      53
#define NR_connect         42
#define NR_accept          43
#define NR_sendto          44
#define NR_getsockname     51
#define NR_getpeername     52
#define NR_recvfrom        45
#define NR_sendmsg         46
#define NR_recvmsg         47
#define NR_shutdown        48
#define NR_bind            49
#define NR_listen          50
#define NR_getsockopt      55
#define NR_setsockopt      54
#define NR_clone           56
#define NR_execve          59
#define NR_execveat       322
#define NR_wait4           61
#define NR_getrusage       98
#define NR_getrlimit       97
#define NR_setrlimit      160
#define NR_getpriority    140
#define NR_setpriority    141
#define NR_statx          332
#define NR_statfs         137
#define NR_fstatfs        138
#define NR_kill            62
#define NR_fcntl           72
#define NR_fsync           74
#define NR_fdatasync       75
#define NR_fchown          93
#define NR_ftruncate       77
#define NR_getcwd          79
#define NR_chdir           80
#define NR_fchdir          81
#define NR_chroot         161
#define NR_fchmod          91
#define NR_umask           95
#define NR_getuid         102
#define NR_getgid         104
#define NR_setpgid        109
#define NR_setsid         112
#define NR_getpgid        121
#define NR_sync           162
#define NR_mount          165
#define NR_reboot         169
#define NR_umount2        166
#define NR_getdents64     217
#define NR_clock_gettime  228
#define NR_exit_group     231
#define NR_exit            60    /* this thread alone */
#define NR_futex          202
#define NR_sched_yield     24
#define NR_arch_prctl     158
#define NR_openat         257
#define NR_mkdirat        258
#define NR_mknodat        259
#define NR_fchownat       260
#define NR_faccessat      269
#define NR_newfstatat     262
#define NR_unlinkat       263
#define NR_renameat       264
#define NR_renameat2      316
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
/* inle's own, outside every kernel's table: a process asks for a child (posix_spawn) */
#define NR_inle_spawn  0x4100


/* errno is one object, defined beside __errno_location */
extern int __errno_v;
static long er(long r) {
  if ((unsigned long) r > (unsigned long) -4096L) { __errno_v = (int) -r; return -1; }
  return r; }

/* __love_sys parks a BSD carry answer below linux's band, as -(errno+4096).
 * __love_call translates canonical numbers; fb1..fb6 take NR_fb_* untranslated */
extern long __love_osv;
unsigned long getauxval(unsigned long t);
extern long __love_osdetect(void);
/* inle's door: it answers the canonical numbers, so a negative osv reads as linux */
extern long __love_inle(long n, long a, long b, long c, long d, long e, long f);
extern int __love_efault(void);
extern long __love_nrfb(long n);
extern long __love_errfb(long e);
extern long __love_sigfb(long sig);
extern long __love_sigcan(long sig);
/* a native siginfo -> the canonical one signal.h spells */
extern void __love_sicanon(void const *native, siginfo_t *out);
extern unsigned long __love_maskfb(unsigned long m);
extern unsigned long __love_maskcan(unsigned long m);
extern long __love_ofb(long fl);
extern long __love_ocan(long fl);
extern long __love_mapfb(long fl);
extern long __love_safb(long fl);
extern long __love_sacan(long fl);
extern long __love_affb(long af);          /* socket family: inet6 moves, the rest agree */
extern long __love_afcan(long af);
extern long __love_sotype(long t);         /* SOCK_* flag bits move high */
extern long __love_msgfb(long fl);         /* send/recv flags */
extern long __love_msgcan(long fl);        /* ..and recvmsg's msg_flags back */
extern int __love_sofb(long *lv, long *op);        /* sockopt level+name; -1 unmapped */
extern unsigned int __love_sain(void const *a, unsigned int n, void *out);   /* sockaddr head, in; answers the namelen */
extern void __love_saout(void *a, unsigned int n);                   /* ..and back out */
#ifdef __ARM_EABI__
/* a time64 call before linux 5.1: ENOSYS once, then the 32-bit twin answers */
extern int __love_t32k;
long __love_t32(long n, long a, long b, long c, long d, long e, long f);
static int __love_t64(long n) {
  return n == NR_clock_gettime || n == NR_clock_nanosleep || n == NR_ppoll || n == NR_pselect6
      || n == NR_utimensat || n == NR_futex; }
#endif
/* a BSD's error as the tail parks it, -(errno+4096): the band and not the sign, since a
 * 32-bit address above 2G reads negative */
static int __love_parked(long r) { return r < -4096L && r >= -4096L - 256; }
#ifdef __i386__
/* i386's BSDs keep their own timespec (__fbts, __nbts): a call carrying one narrows it going
 * in and widens it coming back (os.c), its answer parked as any BSD's */
long __love_tbsd(long n, long a, long b, long c, long d, long e, long f);
static int __love_tbsdn(long n) {
  return n == NR_clock_gettime || n == NR_nanosleep || n == NR_ppoll || n == NR_pselect6
      || n == NR_utimensat; }
#endif
#ifdef LvMac
/* dyld's exe: xnu's unix call n through libSystem, LvNoDoor where none answers (os.c) */
#define LvNoDoor (-0x7fffffffL)
extern long __love_door(long n, long a, long b, long c, long d, long e, long f);
extern long __love_macclock(int ck, struct timespec *ts);   /* LvNoDoor without libSystem */
extern unsigned long __love_macslide(void);
struct __mac_osigact;
extern long __love_macsigact(long sig, struct __mac_osigact const *a, struct __mac_osigact *old);
#endif
static long __love_call(long n, long a, long b, long c, long d, long e, long f) {
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
/* xnu's unix calls answer in their class: the BSD number with this bit */
#define LvMacUnix 0x2000000L
static long __love_fb(long n, long a, long b, long c, long d, long e, long f) {
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
#if defined(__ARM_EABI__) || defined(__i386__)
static long __love_fb8(long n, long a, long b, long c, long d, long e, long f, long g, long h) {
  long r = __love_sys8(n, a, b, c, d, e, f, g, h);
  return __love_parked(r) ? -__love_errfb(-r - 4096) : r; }
#elif defined(LvOsTranslate)
static long __love_fb7(long n, long a, long b, long c, long d, long e, long f, long g) {
  long r = __love_sys7(n, a, b, c, d, e, f, g);
  return __love_parked(r) ? -__love_errfb(-r - 4096) : r; }
#endif

static long sc0(long n) { return __love_call(n, 0, 0, 0, 0, 0, 0); }
static long sc1(long n, long a) { return __love_call(n, a, 0, 0, 0, 0, 0); }
static long sc2(long n, long a, long b) { return __love_call(n, a, b, 0, 0, 0, 0); }
static long sc3(long n, long a, long b, long c) { return __love_call(n, a, b, c, 0, 0, 0); }
static long sc4(long n, long a, long b, long c, long d) { return __love_call(n, a, b, c, d, 0, 0); }
static long sc5(long n, long a, long b, long c, long d, long e) { return __love_call(n, a, b, c, d, e, 0); }
static long sc6(long n, long a, long b, long c, long d, long e, long f) { return __love_call(n, a, b, c, d, e, f); }
static long fb1(long n, long a) { return __love_fb(n, a, 0, 0, 0, 0, 0); }
static long fb2(long n, long a, long b) { return __love_fb(n, a, b, 0, 0, 0, 0); }
static long fb3(long n, long a, long b, long c) { return __love_fb(n, a, b, c, 0, 0, 0); }
static long fb6(long n, long a, long b, long c, long d, long e, long f) { return __love_fb(n, a, b, c, d, e, f); }
/* bind's and connect's: the address through __love_sain where the kernel's head differs */
static long sc_sa(long n, int fd, void const *a, unsigned int len) {
  if (__love_osv >= 2) {
    struct sockaddr_storage s;
    if (len > sizeof s) return -EINVAL;
    len = __love_sain(a, len, &s);
    return sc3(n, fd, (long) &s, len); }
  return sc3(n, fd, (long) a, len); }
/* static in a header: the dead-static sweep drops the bodies a member does not use */

/* the shapes the public headers keep opaque, and the fmt members' limb geometry. */
typedef void (*__exitfn)(void);
typedef struct __mhdr { struct __mhdr *next; size_t size; } __mhdr;   /* size in units */
#define __MDirect ((__mhdr *) 1)   /* in an allocated block's `next': a mapping of its own, pages fresh from the kernel */
#define __MLive ((__mhdr *) 3)     /* ..an arena block */
#define __MAlign ((__mhdr *) 5)    /* ..a stand-in before an aligned pointer: size is the units back to the block's payload */
#define __MArena ((__mhdr *) 7)    /* an arena's first unit, never handed out: size is the arena's units, its last a sentinel (__MLive, 1) */
#define __MSlot ((__mhdr *) 9)     /* ..a size class's slot: size is its units, and its index in its slab << 16 */
static size_t __munits(__mhdr const *b) { return b->next == __MSlot ? b->size & 0xffff : b->size; }
__mhdr *__mblock(void *p, char const *who);   /* the block behind p, or an abort naming who */
int __mgrow(__mhdr *b, size_t nu);            /* realloc's growth in place: 1 when b now holds nu units */
struct __sctx { char *p; size_t n, at; };
struct __ksigaction { void *h; unsigned long flags; void *restorer; unsigned long mask[8 / sizeof(long)]; };   /* the mask in words: 4-aligned on arm */
/* ent: readdir's repack of the BSD record */
struct __dirstream { int fd; int pos; int len; struct dirent ent; char buf[4096]; };

/* linux's statx buffer, the same on every arch */
#define STATX_BASIC_STATS      2047
#define STATX_BTIME            2048
#define AT_STATX_SYNC_AS_STAT     0
struct __lx_stxts { long long tv_sec; unsigned int tv_nsec, __r; };
struct __lx_statx {
  unsigned int stx_mask, stx_blksize;
  unsigned long long stx_attributes;
  unsigned int stx_nlink, stx_uid, stx_gid;
  unsigned short stx_mode, __p0;
  unsigned long long stx_ino, stx_size, stx_blocks, stx_attributes_mask;
  struct __lx_stxts stx_atime, stx_btime, stx_ctime, stx_mtime;
  unsigned int stx_rdev_major, stx_rdev_minor, stx_dev_major, stx_dev_minor;
  unsigned long long __rest[14];      /* mnt id, dio -- unread here */
};
_Static_assert(sizeof(struct __lx_statx) == 256, "statx buffer is the kernel's 256");
#ifdef __ILP32__
int __love_statx(int dirfd, char const *p, int fl, struct stat *st);   /* fstat.c's, the stat trio's floor */
#endif
/* a BSD's own timespec. i386's: freebsd keeps a 32-bit time_t, netbsd a 64-bit one on 4
 * with a 32-bit nsec; everywhere else both are ours */
#ifdef __i386__
typedef struct { int tv_sec; long tv_nsec; } __fbts;
typedef struct { long long tv_sec; long tv_nsec; } __nbts;
#else
typedef struct timespec __fbts, __nbts;
#endif
static struct timespec __love_fbts(__fbts t) { struct timespec r = { t.tv_sec, t.tv_nsec }; return r; }
static struct timespec __love_nbts(__nbts t) { struct timespec r = { t.tv_sec, t.tv_nsec }; return r; }
struct __fb_stat {                    /* ino64, 224 bytes (208 on i386); mode is 16-BIT */
  unsigned long long st_dev;
  unsigned long long st_ino;
  unsigned long long st_nlink;
  unsigned short st_mode;
  short         st_bsdflags;
  unsigned int  st_uid;
  unsigned int  st_gid;
  int           __pad0;
  unsigned long long st_rdev;
#ifdef __i386__
  int st_atim_ext; __fbts st_atim;     /* i386's 32-bit time_t, a pad word ahead of each */
  int st_mtim_ext; __fbts st_mtim;
  int st_ctim_ext; __fbts st_ctim;
  int st_birthtim_ext; __fbts st_birthtim;
#else
  __fbts st_atim, st_mtim, st_ctim, st_birthtim;
#endif
  long long     st_size;
  long long     st_blocks;
  int           st_blksize;
  unsigned int  st_flags;
  unsigned long long st_gen;
  unsigned long long st_filerev;
  unsigned long long __spare[9];
};
#if defined(LvOsTranslate) && (defined(__ARM_EABI__) || !defined(__arm__))   /* bare thumb speaks no BSD */
#ifdef __i386__
_Static_assert(sizeof(struct __fb_stat) == 208, "freebsd's stat is 208 bytes on i386");
#else
_Static_assert(sizeof(struct __fb_stat) == 224, "freebsd's stat is 224 bytes");
#endif
#endif
struct __fb_dirent {                  /* the ino64 record getdirentries fills */
  unsigned long long d_ino;
  long long      d_off;
  unsigned short d_reclen;
  unsigned char  d_type;
  unsigned char  __pad0;
  unsigned short d_namlen;
  unsigned short __pad1;
  char           d_name[256];
};
struct __fb_sigact { void *h; int flags; unsigned int mask[4]; };   /* sigaction(416): no restorer */
struct __fb_msghdr {                  /* BOTH BSDs: int-wide lengths, 48 bytes (28 on ILP32) */
  void *name;
  unsigned int namelen;
#ifndef __ILP32__
  unsigned int _p0;
#endif
  void *iov;
  int iovlen;
#ifndef __ILP32__
  int _p1;
#endif
  void *control;
  unsigned int controllen;
  int flags;
};
/* a BSD's cmsg: the 12-byte head (len level type, all ints), its data at the head rounded
 * up to the kernel's alignment -- 8 on 64-bit and netbsd's arm, 4 on i386, freebsd's arm and macos */
#ifdef __ARM_EABI__
static unsigned long __love_cmh(void) { return __love_osv == 3 ? 16 : 12; }
static unsigned long __love_cma(void) { return __love_osv == 3 ? 8 : 4; }
#else
static unsigned long __love_cmh(void) { return sizeof(long) == 8 && __love_osv != 4 ? 16 : 12; }
static unsigned long __love_cma(void) { return __love_osv == 4 ? 4 : sizeof(long); }   /* macos aligns on 4 */
#endif
struct __fb_termios {                 /* 44 bytes: 4 flag words, 20 chars, 2 speeds, no c_line */
  unsigned int c_iflag, c_oflag, c_cflag, c_lflag;
  unsigned char c_cc[20];
  unsigned int c_ispeed, c_ospeed;
};
extern void __love_fbstat(struct __fb_stat const *f, struct stat *st);   /* fstat.c's, shared by the stat trio */
extern void __love_tiofb(struct termios const *t, struct __fb_termios *f);   /* os.c's termios rows */
extern void __love_tiokeep(struct __fb_termios *f, struct __fb_termios const *cur);
extern void __love_tiocan(struct __fb_termios const *f, struct termios *t);

/* netbsd reuses freebsd's classic numbers and tables; its own are these shapes, the
 * versioned numbers, the padded args and the sigtramp the kernel does not provide */
#define NR_nb_sigaction_sigtramp 340   /* (sig, nsa, osa, tramp, 2) */
struct __nb_stat {                    /* the timespec quartet mid-struct, each time_t 64-bit */
  unsigned long long dev;
  unsigned int mode;
#ifndef __i386__
  unsigned int _p0;                   /* a 64-bit word sits on 8, but on i386 */
#endif
  unsigned long long ino;
  unsigned int nlink, uid, gid;
#ifndef __i386__
  unsigned int _p1;
#endif
  unsigned long long rdev;
  __nbts atim, mtim, ctim, btim;
  long long size, blocks;
  int blksize;
  unsigned int flags, gen, spare0, spare1;
};
#if defined(LvOsTranslate) && (defined(__ARM_EABI__) || !defined(__arm__))   /* bare thumb speaks no BSD */
#ifdef __i386__
_Static_assert(sizeof(struct __nb_stat) == 124, "netbsd's stat is 124 bytes on i386");
#else
_Static_assert(sizeof(struct __nb_stat) == 152, "netbsd's stat is 152 bytes");
#endif
#endif
struct __nb_dirent {                  /* __getdents30's record: name at byte 13 */
  unsigned long long fileno;
  unsigned short reclen, namlen;
  unsigned char type;
  char name[512];
};
struct __nb_sigact { void *h; unsigned int mask[4]; int flags; };   /* mask BEFORE flags */
struct __nb_kevent {                  /* __kevent50's record: 40 bytes, no ext,
                                       * filter WIDE and positive (= -canon - 1) */
  unsigned long ident;
  unsigned int filter, flags, fflags;
#ifndef __ILP32__
  unsigned int _p0;
#endif
  long long data;
  void *udata;
};
extern void __love_nbstat(struct __nb_stat const *f, struct stat *st);
#ifdef LvNbTramp
extern void __love_nb_sigtramp(void);   /* mksys: the ucontext register; setcontext */
#endif
/* ---- the fourth kernel: macos (xnu), the only one a mach-o meets. crt0 says so
 * (osv 4) and nothing is probed. its unix calls are the classic BSD band in a
 * class of their own (LvMacUnix); signals, sa flags, the siginfo head, termios
 * bits and msghdr are freebsd's. its own: these records, AT_FDCWD -2 and the AT_
 * bits, the calls it never had (clock_gettime, nanosleep, pipe2, getcwd,
 * utimensat), fork and pipe answering in two registers, and a userland sigtramp
 * that hands sigreturn a token. */
struct __mac_stat {                   /* stat64, 144 bytes: a birth time after ctime */
  int dev;
  unsigned short mode, nlink;
  unsigned long long ino;
  unsigned int uid, gid;
  int rdev;
  struct timespec atim, mtim, ctim, btim;
  long long size, blocks;
  int blksize;
  unsigned int flags, gen;
  int lspare;
  long long qspare[2];
};
struct __mac_dirent {                 /* getdirentries64's record: namlen before type */
  unsigned long long ino, seekoff;
  unsigned short reclen, namlen;
  unsigned char type;
  char name[1024];
};
struct __mac_sigact { void *h, *tramp; unsigned int mask; int flags; };   /* the tramp rides in.. */
struct __mac_osigact { void *h; unsigned int mask; int flags; };          /* ..and not back out */
struct __mac_kevent {                 /* 32 bytes: freebsd's head with no ext */
  unsigned long ident;
  short filter;
  unsigned short flags;
  unsigned int fflags;
  long data;
  void *udata;
};
struct __mac_termios {                /* freebsd's bits in long-wide words: 72 bytes */
  unsigned long c_iflag, c_oflag, c_cflag, c_lflag;
  unsigned char c_cc[20];
  unsigned long c_ispeed, c_ospeed;
};
#ifdef LvMac
_Static_assert(sizeof(struct __mac_stat) == 144, "macos's stat64 is 144 bytes");
_Static_assert(sizeof(struct __mac_termios) == 72, "macos's termios is 72 bytes");
_Static_assert(sizeof(struct __mac_kevent) == 32, "macos's kevent is 32 bytes");
extern long __love_macfork(void);
extern long __love_macpipe(void);          /* the ends as one word, the second high */
extern void __love_mac_sigtramp(void);
#endif
extern void __love_macstat(struct __mac_stat const *f, struct stat *st);
extern void __love_macsofl(int fd, long t);   /* SOCK_CLOEXEC/NONBLOCK, by fcntl */
extern int __love_macat(long n, long *w);   /* an *at call's args, made xnu's: 1 if it was one */
extern void __love_tiomac(struct __fb_termios const *f, struct __mac_termios *m);
extern void __love_tiounmac(struct __mac_termios const *m, struct __fb_termios *f);

#if defined(__aarch64__) || defined(__riscv)
/* the probe's leaves: netbsd/aarch64 reads the svc immediate and SIGSYSes the register
 * form, so these set x8 and the immediate (a7 and t6 on riscv). freebsd, which SIGILLs
 * any nonzero immediate, is parted out by crt0 first */
extern long __love_nbp20(long);
extern long __love_nbp202(long, long, long, long, long, long);
#endif
#define FfLeft 1
#define FfZero 2
#define FfAlt  4
#define FfPlus 8
#define FfSpc  16
#define BdB 1000000000ULL
#define BdI 36                        /* integer limbs: 324 digits >= 309 */
#define BdF 121                       /* fraction limbs: 1089 digits >= 1074 */
#define BdN (BdI + BdF)
#define BdD (BdN * 9)                /* every digit index the array holds */
#define BdU (BdI * 9 - 1)            /* the index of the units place */

/* (w - LvOnes) & ~w & LvHighs is nonzero iff some byte of w is zero. written out:
 * mooncc does not fold ~0UL / 255; the cast truncates right on 32-bit */
#define LvOnes  ((unsigned long) 0x0101010101010101ULL)
#define LvHighs ((unsigned long) 0x8080808080808080ULL)

extern char **environ;
extern char const *__love_progname;

/* helpers a sibling member calls or passes as a pointer: one definition, named here. */
void __fmtnum(void (*put)(void *, int), void *ctx, unsigned long long v, unsigned base,
              int neg, int prec, int width, int fl, int up);
int __fmtsgn(int neg, int fl);
void __pad(void (*put)(void *, int), void *ctx, int n, int ch);
void __femit(void *ctx, int c);
void __semit(void *ctx, int c);
int (*__ctclass(char const *nm, size_t n))(int);
int __ctname(char const *nm, size_t n);            /* wctype's index for a name not nul-ended */
int __ctwide(int t, unsigned w);                    /* class t past ascii, whatever the locale */
int __utf8(char const *s, size_t n, unsigned *w);   /* one whole utf-8 character -> its length | -1 */

/* the three standard streams' storage: core.c's entry wires stdout's buffer, and
 * the stream table is named by whoever opens one. */
extern FILE __stdf[3];
extern unsigned char __obuf[8192];
/* threads: the clone leaf starts the child calling sp[0](sp[1]); __love_tp reads the
 * thread pointer clone set */
struct __love_mt { int threads, lock, klock, tls; void (*dtor[128])(void *); unsigned char key[128]; void *tsd[128]; };   /* klock guards the keys; tls is i386's GDT entry, 0 before the first thread */
extern struct __love_mt __love_mt;
long __love_clone(long flags, void *sp, int *ptid, int *ctid, void *tls);
void *__love_tp(void);
extern unsigned char __ibuf[4096];
/* the read side (stdio/rbuf.c): fill an empty read buffer -> bytes now ahead (0 at end, -1 on error);
 * how far the stream sits behind its fd; and putting the fd back at the stream's position */
void __love_fopened(FILE *f);
long __rfill(FILE *f);
long __rahead(FILE *f);
int __rsync(FILE *f);
#endif
