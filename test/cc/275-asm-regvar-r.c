/* a64 register variables under gcc's other names for x0..x30, as arm-smccc.h spells them:
 * asm("r0") is x0, which the template reads by its own name, and a clobber of "r2" is x2.
 * a target with no template here computes the same in C. */
typedef unsigned long u64;

#if defined(__aarch64__)
static u64 smc(u64 a, u64 b) {
  register u64 r0 asm("r0") = a;
  register u64 r1 asm("r1") = b;
  asm volatile("add x0, x0, x1\n\tmov x2, #7\n\tadd x0, x0, x2" : "+r"(r0) : "r"(r1) : "r2");
  return r0;
}
#else
static u64 smc(u64 a, u64 b) { return a + b + 7; }
#endif

int main(void) { return smc(30, 5) == 42 ? 0 : 1; }
