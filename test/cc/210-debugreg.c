/* the debug registers: mov to and from db0..db3, db6 and db7, spelled %db and %dr, as the
 * kernel's hw_breakpoint and debugreg.h lay them, and invpcid over its descriptor, as its tlb
 * code does. privileged, so laid and read back through objdump, never run; main holds only
 * what any lane can say. the asm is x64's. held to gcc. */

#if defined(__x86_64__)
unsigned long rd(void) {
  unsigned long a, b, c, d, s, t;
  asm("mov %%db0, %0" : "=r"(a));
  asm("mov %%db1, %0" : "=r"(b));
  asm("mov %%db2, %0" : "=r"(c));
  asm("mov %%db3, %0" : "=r"(d));
  asm("mov %%db6, %0" : "=r"(s));
  asm volatile("mov %%dr7, %0" : "=r"(t));
  return a + b + c + d + s + t;
}
void wr(unsigned long v) {
  asm("mov %0, %%db0" : : "r"(v));
  asm("mov %0, %%db3" : : "r"(v));
  asm("mov %0, %%dr6" : : "r"(v));
  asm volatile("mov %0, %%db7" : : "r"(v));
}
void inv(unsigned long type, unsigned long pcid, unsigned long addr) {
  struct { unsigned long d; unsigned long a; } desc = {pcid, addr};
  asm volatile("invpcid %[desc], %[type]" : : [desc] "m"(desc), [type] "r"(type) : "memory");
}
#endif

int main(void) {
  volatile int n = 3;
  return n - 3;
}
