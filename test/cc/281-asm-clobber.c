/* an asm operand never sits in a register the asm clobbers (the x86 kernel's call_on_irqstack
 * calls out before it reads its args): past the scratch file it takes a callee-saved one. held to gcc. */
#include <stdio.h>

#if defined(__x86_64__)
asm(".text\n.globl trash281\ntrash281: mov $1, %r9\n mov $2, %r10\n mov $3, %r8\n mov $4, %rcx\n ret\n");
asm(".globl take281\ntake281: lea (%rdi,%rsi,8), %rax\n ret\n");
__attribute__((noinline)) long run(long a, long b) {
  long r;
  asm volatile("call trash281\n\tmovq %[a2], %%rsi\n\tmovq %[a1], %%rdi\n\tcall take281"
               : "=a"(r) : [a1] "r"(a), [a2] "r"(b)
               : "cc", "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11", "memory");
  return r;
}
#else
__attribute__((noinline)) long run(long a, long b) { return a + b * 8; }
#endif

int main(void) {
  long r = run(100, 3);
  printf("%ld\n", r);
  return (int)(r & 255);
}
