#ifndef _AI_SIGNAL_H
#define _AI_SIGNAL_H
typedef int sig_atomic_t;
#include <sys/types.h>
typedef struct { long __v[16]; } sigset_t;   /* 128 bytes, glibc-sized */
/* the canonical (linux) siginfo, 128 bytes: the head, then a union whose lanes
 * are the faulting address and the child that stopped. the BSDs order the head
 * differently -- and netbsd unions the same two lanes where freebsd lays them
 * flat -- so sigaction.c's shim translates into this one shape and a handler
 * reads the same layout on every kernel. the head pads to 16, where every LP64
 * seat here puts the union. */
typedef struct {
  int si_signo, si_errno, si_code, __si_pad;
  union {
    void *__addr;
    struct { int __pid; unsigned __uid; int __status; } __chld;
    char __pad[112];
  } __sifields;
} siginfo_t;
/* the lanes overlap, so a handler reads the one its signal names: an address for
 * a fault, a sender otherwise, and a status only for SIGCHLD. */
#define si_addr   __sifields.__addr
#define si_pid    __sifields.__chld.__pid
#define si_uid    __sifields.__chld.__uid
#define si_status __sifields.__chld.__status
struct sigaction {
  /* a union, so `sa.sa_handler = h` keeps working unchanged: both spellings are
   * one pointer slot, which is what every kernel's shape holds here too. */
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
/* sa_flags, Linux's values (the same on every arch we speak) */
#define SA_NOCLDSTOP 1
#define SA_NOCLDWAIT 2
#define SA_SIGINFO   4
#define SA_ONSTACK   0x08000000
#define SA_RESTART   0x10000000
#define SA_NODEFER 1073741824
#define SA_RESETHAND 0x80000000
void *signal(int, void*);        /* returns the old handler; love.c ignores it */
int raise(int);
int sigaction(int, struct sigaction const*, struct sigaction*);
int sigemptyset(sigset_t*);
/* the host seam's tail (rung 2) */
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
/* the rest of the 32 the permutation in os.c covers. SIGSYS is the sharp one --
 * 31 here and 12 on the BSDs -- so the name translates where a bare number does
 * not. STKFLT and PWR have no BSD twin, and a sigaction on them refuses there. */
#define SIGSTKFLT 16
#define SIGURG    23
#define SIGXCPU   24
#define SIGXFSZ   25
#define SIGVTALRM 26
#define SIGPROF   27
#define SIGIO     29
#define SIGPWR    30
#define SIGSYS    31
int kill(pid_t, int);
int sigaddset(sigset_t*, int);
int sigismember(sigset_t const*, int);
int sigprocmask(int, sigset_t const*, sigset_t*);
#endif
