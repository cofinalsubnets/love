/* the x86-64 kernel's templates: a basic asm's bare registers (io_delay's `outb %al`), an
 * input tied to an output by name (csum_ipv6_magic's "[sum]"), the ALU over a word in
 * memory (csum_partial's adcq), a symbol's word read by its address (a uniprocessor
 * percpu read), lar over a selector, an "i" only __builtin_constant_p makes constant past
 * an inlined body, and an __int128 passed and taken in registers. held to gcc. */
#include <stdio.h>

#if defined(__x86_64__)
static long cur = 41;
static long percpu(void) {
  long v;
  asm("movq %a[var], %[val]" : [val] "=r"(v) : [var] "i"(&cur));
  return v;
}
static unsigned long csum(const unsigned long *p, unsigned long seed) {
  unsigned long s;
  asm("addq (%[p]),%[sum]\n\tadcq 8(%[p]),%[sum]\n\tadcq $0,%[sum]"
      : [sum] "=r"(s) : "[sum]"(seed), [p] "r"(p) : "cc");
  return s;
}
static int bare(void) {
  asm volatile("xchg %ax, %ax");
  return 1;
}
static unsigned ss_rights(void) {
  unsigned sel, ar;
  asm("mov %%ss, %0" : "=r"(sel));
  asm("lar %[s], %[ar]\n\tjz 1f\n\txorl %[ar], %[ar]\n1:" : [ar] "=r"(ar) : [s] "r"(sel) : "cc");
  return (ar >> 8) & 0x80;   /* present */
}
static inline __attribute__((always_inline)) int cbit(long nr, const unsigned long *a) {
  unsigned char o;
  asm("testb %2,%1\n\tsetnz %0" : "=q"(o) : "m"(((const unsigned char *)a)[nr >> 3]), "i"(1 << (nr & 7)));
  return o;
}
static inline __attribute__((always_inline)) int vbit(long nr, const unsigned long *a) {
  unsigned char o;
  asm("btq %2,%1\n\tsetc %0" : "=q"(o) : "m"(*a), "Ir"(nr));
  return o;
}
static inline __attribute__((always_inline)) int tbit(long nr, const unsigned long *a) {
  return __builtin_constant_p(nr) ? cbit(nr, a) : vbit(nr, a);
}
static __attribute__((noinline)) unsigned __int128 wide(unsigned __int128 a, long k, unsigned __int128 b) {
  return a + b * k;
}
#else
static long percpu(void) { return 41; }
static unsigned long csum(const unsigned long *p, unsigned long seed) {
  unsigned long s = seed + p[0], c = s < seed; unsigned long t = s + p[1] + c;
  c = t < s || (c && t == s); return t + c;
}
static int bare(void) { return 1; }
static unsigned ss_rights(void) { return 0x80; }
static int tbit(long nr, const unsigned long *a) { return (a[nr / 64] >> (nr % 64)) & 1; }
#endif

int main(void) {
  unsigned long w[2] = { ~0UL, 5 }, bits = 0x24;
  volatile long n = 5;
  int t1 = tbit(n, &bits), t2 = tbit(2, &bits), t3 = tbit(3, &bits);
  int t = t1 + 2 * t2 + 4 * t3;
  unsigned long c = csum(w, 3);
  printf("%ld %lu %d %u %d\n", percpu(), c, bare(), ss_rights(), t);
  int r = (int)(percpu() + c + bare() + (ss_rights() != 0) + t);
#if defined(__x86_64__)
  unsigned __int128 x = wide(((unsigned __int128)3 << 64) | 7, n, 9);
  printf("%lu %lu\n", (unsigned long)(x >> 64), (unsigned long)x);
  r += (int)(x >> 64) + (int)x;
#else
  printf("3 52\n");
  r += 55;
#endif
  return r & 255;
}
