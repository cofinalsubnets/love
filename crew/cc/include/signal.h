#ifndef _AI_SIGNAL_H
#define _AI_SIGNAL_H
typedef int sig_atomic_t;
typedef struct { long __v[16]; } sigset_t;   /* 128 bytes, glibc-sized */
struct sigaction {
  void (*sa_handler)(int);
  sigset_t sa_mask;
  int sa_flags;
  void (*sa_restorer)(void);
};
#define SIG_DFL ((void(*)(int))0)
#define SIG_IGN ((void(*)(int))1)
#define SIGINT   2
#define SIGILL   4
#define SIGABRT  6
#define SIGFPE   8
#define SIGSEGV 11
#define SIGBUS   7
#define SA_NODEFER 1073741824
void *signal(int, void*);        /* returns the old handler; ai.c ignores it */
int raise(int);
int sigaction(int, struct sigaction const*, struct sigaction*);
int sigemptyset(sigset_t*);
#endif
