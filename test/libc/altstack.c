/* an alternate signal stack, and the context a handler is handed: a fault taken on the
 * alt stack reports the faulting stack pointer out of ucontext_t's register set, where
 * gnulib's c-stack reads it to tell a stack overflow from any other fault */
#define _GNU_SOURCE
#include <signal.h>
#include <setjmp.h>
#include <stddef.h>
#include <ucontext.h>
#include "say.h"

static char alt[16384];
static sigjmp_buf jb;
static volatile long k_onalt, k_sp;
static long main_sp;

static void on_segv(int s, siginfo_t *si, void *uc) {
  (void) s; (void) si;
  char here;
  k_onalt = &here >= alt && &here < alt + sizeof alt;
#if defined(__x86_64__)
  long sp = (long) ((ucontext_t *) uc)->uc_mcontext.gregs[REG_RSP];
#elif defined(__aarch64__)
  long sp = (long) ((ucontext_t *) uc)->uc_mcontext.sp;
#else
  long sp = main_sp;
#endif
  k_sp = main_sp - sp < 65536 && sp - main_sp < 65536;   /* the fault's sp is main's, not the alt stack's */
  siglongjmp(jb, 1); }

int main(void) {
  char mark; main_sp = (long) &mark;
  stack_t st = {alt, 0, sizeof alt}, o;
  say_n("sigaltstack", sigaltstack(&st, 0));
  say_n("query", sigaltstack(0, &o));
  say_n("query.sp", o.ss_sp == alt); say_n("query.flags", o.ss_flags);
  struct sigaction sa = {0};
  sa.sa_sigaction = on_segv; sa.sa_flags = SA_SIGINFO | SA_ONSTACK;
  say_n("sigaction", sigaction(SIGSEGV, &sa, 0));
  if (!sigsetjmp(jb, 1)) *(volatile int *) 8 = 1;
  say_n("onalt", k_onalt); say_n("fault.sp", k_sp);
  stack_t d = {0, SS_DISABLE, 0};
  say_n("disable", sigaltstack(&d, 0));
  say_n("disabled", sigaltstack(0, &o) == 0 && (o.ss_flags & SS_DISABLE) != 0);
  return 0; }
