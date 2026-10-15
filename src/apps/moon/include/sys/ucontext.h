#ifndef _LOVE_SYS_UCONTEXT_H
#define _LOVE_SYS_UCONTEXT_H
#include <signal.h>
/* the context a SA_SIGINFO handler's third argument points at: linux's frame, laid as the kernel
   lays it, up to the register set (a BSD kernel hands its own shape). no getcontext/makecontext */
#if defined(__x86_64__)
typedef long long greg_t;
#define NGREG 23
typedef greg_t gregset_t[NGREG];
enum { REG_R8, REG_R9, REG_R10, REG_R11, REG_R12, REG_R13, REG_R14, REG_R15, REG_RDI, REG_RSI,
       REG_RBP, REG_RBX, REG_RDX, REG_RAX, REG_RCX, REG_RSP, REG_RIP, REG_EFL, REG_CSGSFS,
       REG_ERR, REG_TRAPNO, REG_OLDMASK, REG_CR2 };
typedef struct { gregset_t gregs; void *fpregs; unsigned long long __reserved1[8]; } mcontext_t;
typedef struct ucontext_t {
  unsigned long uc_flags;
  struct ucontext_t *uc_link;
  stack_t uc_stack;
  mcontext_t uc_mcontext;
  sigset_t uc_sigmask;
} ucontext_t;
#elif defined(__i386__)
typedef int greg_t;
#define NGREG 19
typedef greg_t gregset_t[NGREG];
enum { REG_GS, REG_FS, REG_ES, REG_DS, REG_EDI, REG_ESI, REG_EBP, REG_ESP, REG_EBX, REG_EDX,
       REG_ECX, REG_EAX, REG_TRAPNO, REG_ERR, REG_EIP, REG_CS, REG_EFL, REG_UESP, REG_SS };
typedef struct { gregset_t gregs; void *fpregs; unsigned long oldmask, cr2; } mcontext_t;
typedef struct ucontext_t {
  unsigned long uc_flags;
  struct ucontext_t *uc_link;
  stack_t uc_stack;
  mcontext_t uc_mcontext;
  sigset_t uc_sigmask;
} ucontext_t;
#elif defined(__aarch64__)
typedef struct {
  unsigned long long fault_address;
  unsigned long long regs[31];
  unsigned long long sp, pc, pstate;
  _Alignas(16) unsigned char __reserved[4096];
} mcontext_t;
typedef struct ucontext_t {
  unsigned long uc_flags;
  struct ucontext_t *uc_link;
  stack_t uc_stack;
  sigset_t uc_sigmask;
  mcontext_t uc_mcontext;
} ucontext_t;
#elif defined(__riscv)
#define NGREG 32
enum { REG_PC, REG_RA, REG_SP, REG_TP = 4, REG_S0 = 8, REG_A0 = 10 };
typedef unsigned long greg_t;
typedef greg_t gregset_t[NGREG];
typedef struct { gregset_t __gregs; _Alignas(16) unsigned char __fpregs[528]; } mcontext_t;
typedef struct ucontext_t {
  unsigned long uc_flags;
  struct ucontext_t *uc_link;
  stack_t uc_stack;
  sigset_t uc_sigmask;
  mcontext_t uc_mcontext;
} ucontext_t;
#elif defined(__ARM_EABI__)
typedef struct {
  unsigned long trap_no, error_code, oldmask;
  unsigned long arm_r0, arm_r1, arm_r2, arm_r3, arm_r4, arm_r5, arm_r6, arm_r7, arm_r8, arm_r9, arm_r10;
  unsigned long arm_fp, arm_ip, arm_sp, arm_lr, arm_pc, arm_cpsr, fault_address;
} mcontext_t;
typedef struct ucontext_t {
  unsigned long uc_flags;
  struct ucontext_t *uc_link;
  stack_t uc_stack;
  mcontext_t uc_mcontext;
  sigset_t uc_sigmask;
} ucontext_t;
#endif
#endif
