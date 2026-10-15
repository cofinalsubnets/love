/* a register variable whose value folds to a constant still reaches the asm in its register
 * (an sbi call's a6 and a7). held to gcc. */

#if defined(__riscv)
#define R1 "a6"
#define R2 "a7"
#define ADD "add %0, a6, a7"
#elif defined(__aarch64__)
#define R1 "x6"
#define R2 "x7"
#define ADD "add %0, x6, x7"
#elif defined(__x86_64__)
#define R1 "r8"
#define R2 "r9"
#define ADD "mov %%r8, %0\n\tadd %%r9, %0"
#endif

static __attribute__((noinline)) long pick(long ext, long fn) {
#ifdef ADD
  register long x16 asm(R1) = fn, x17 asm(R2) = ext;
  long r;
  asm volatile (ADD : "=&r"(r) : "r"(x16), "r"(x17));
  return r;
#else
  return ext + fn;
#endif
}

int main(void) { return (int) (pick(40, 2) + pick(1, 2)); }   /* 42 + 3 = 45 */
