/* an asm inside a statement expression (the kernel's BITMAP_WEIGHT over hweight_long) pins
 * its operand's register: a param arriving there is no longer there after. held to gcc. */
#include <stdio.h>

#if defined(__x86_64__)
register unsigned long current_stack_pointer asm("rsp");
asm(".text\n.globl sq279\nsq279: mov %rdi, %rax\n imul %rax, %rax\n ret\n");
static inline __attribute__((always_inline)) unsigned long sq(unsigned long w) {
  unsigned long r;
  asm volatile("call sq279" : "=a"(r), "+r"(current_stack_pointer) : "D"(w));
  return r;
}
#else
static unsigned long sq(unsigned long w) { return w * w; }
#endif

__attribute__((noinline)) unsigned wsum(const unsigned long *b, unsigned n) {
  return ({ unsigned i, w = 0;
            for (i = 0; i < n / 64; i++) w += sq(b[i]);
            if (n % 64) w += sq(b[i] & (~0UL >> (-n & 63)));
            w; });
}

int main(void) {
  unsigned long a[3] = { 1, 2, 3 };
  unsigned w = wsum(a, 64 * 2 + 3);
  printf("%u\n", w);
  return w;
}
