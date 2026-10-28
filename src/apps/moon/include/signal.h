#pragma once
typedef int sig_atomic_t;
#include <sys/types.h>
typedef struct { unsigned long long __v[16]; } sigset_t;   /* 128 bytes, glibc-sized; the kernel's 64 signals in __v[0] */
/* linux's 128-byte siginfo on every kernel: the bsds' differ, and the sigaction shim
 * translates. the head pads to 16 where a pointer is 8; i386's union follows at 12 */
typedef struct {
  int si_signo, si_errno, si_code;
#ifndef __ILP32__
  int __si_pad;
#endif
  union {
    void *__addr;
    struct { int __pid; unsigned __uid; int __status; } __chld;
#ifdef __ILP32__
    char __pad[116];
#else
    char __pad[112];
#endif
  } __sifields;
} siginfo_t;
/* overlapping: si_addr for a fault, si_pid otherwise, si_status only for SIGCHLD */
#define si_addr   __sifields.__addr
#define si_pid    __sifields.__chld.__pid
#define si_uid    __sifields.__chld.__uid
#define si_status __sifields.__chld.__status
/* si_code, linux's numbers on every kernel (the sigaction shim translates): who sent it.. */
#define SI_USER    0
#define SI_KERNEL  0x80
#define SI_QUEUE   (-1)
#define SI_TIMER   (-2)
#define SI_MESGQ   (-3)
#define SI_ASYNCIO (-4)
#define SI_SIGIO   (-5)
#define SI_TKILL   (-6)
/* ..or what faulted */
#define ILL_ILLOPC 1
#define ILL_ILLOPN 2
#define ILL_ILLADR 3
#define ILL_ILLTRP 4
#define ILL_PRVOPC 5
#define ILL_PRVREG 6
#define ILL_COPROC 7
#define ILL_BADSTK 8
#define FPE_INTDIV 1
#define FPE_INTOVF 2
#define FPE_FLTDIV 3
#define FPE_FLTOVF 4
#define FPE_FLTUND 5
#define FPE_FLTRES 6
#define FPE_FLTINV 7
#define FPE_FLTSUB 8
#define SEGV_MAPERR 1
#define SEGV_ACCERR 2
#define BUS_ADRALN 1
#define BUS_ADRERR 2
#define BUS_OBJERR 3
#define TRAP_BRKPT 1
#define TRAP_TRACE 2
struct sigaction {
  union {
    void (*sa_handler)(int);
    void (*sa_sigaction)(int, siginfo_t *, void *);
  } __sa_un;
  sigset_t sa_mask;
  int sa_flags;
  void (*sa_restorer)(void);
};
#define sa_handler   __sa_un.sa_handler
#define sa_sigaction __sa_un.sa_sigaction
#define SIG_DFL ((void(*)(int))0)
#define SIG_IGN ((void(*)(int))1)
#define SIG_ERR ((void(*)(int))-1)
#define SIGINT   2
#define SIGILL   4
#define SIGTRAP  5
#define SIGABRT  6
#define SIGFPE   8
#define SIGSEGV 11
#define SIGBUS   7
/* sa_flags: linux's values, the same on every arch */
#define SA_NOCLDSTOP 1
#define SA_NOCLDWAIT 2
#define SA_SIGINFO   4
#define SA_ONSTACK   0x08000000
#define SA_RESTART   0x10000000
#define SA_NODEFER 1073741824
#define SA_RESETHAND 0x80000000
void *signal(int, void*);
int raise(int);
int sigaction(int, struct sigaction const*, struct sigaction*);
int sigemptyset(sigset_t*);
#define SIGHUP   1
#define SIGQUIT  3
#define SIGKILL  9
#define SIGPIPE 13
#define SIGALRM 14
#define SIGTERM 15
#define SIGTTIN 21
#define SIGTTOU 22
#define SIGWINCH 28
#define SIGUSR1 10
#define SIGUSR2 12
#define SIGCHLD 17
#define SIGCONT 18
#define SIGSTOP 19
#define SIGTSTP 20
#define SIG_BLOCK   0
#define SIG_UNBLOCK 1
#define SIG_SETMASK 2
/* linux numbers, translated for the bsds: SIGSYS is 12 there, STKFLT and PWR are absent */
#define SIGSTKFLT 16
#define SIGURG    23
#define SIGXCPU   24
#define SIGXFSZ   25
#define SIGVTALRM 26
#define SIGPROF   27
#define SIGIO     29
#define SIGPWR    30
#define SIGSYS    31
/* one past the highest signal, real-time ones included, as glibc counts */
#define NSIG      65
#define _NSIG     NSIG
int kill(pid_t, int);
int sigaddset(sigset_t*, int);
int sigismember(sigset_t const*, int);
int sigprocmask(int, sigset_t const*, sigset_t*);
/* linux's shape on every kernel; reordered for the bsds underneath */
typedef struct { void *ss_sp; int ss_flags; size_t ss_size; } stack_t;
#define SS_ONSTACK  1
#define SS_DISABLE  2
#define MINSIGSTKSZ 2048
#define SIGSTKSZ    8192
int sigaltstack(stack_t const*, stack_t*);
