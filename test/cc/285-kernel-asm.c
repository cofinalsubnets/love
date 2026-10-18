/* x64 templates: bare registers in a basic asm, a named tied input, alu over memory (adcq), a
 * symbol's word by address, lar, an "i" made constant past inlining, __int128 in registers and
 * cmpxchg16b, a file-scope asm naming registers. held to gcc. */

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
static int cx16(unsigned __int128 *p, unsigned __int128 o, unsigned __int128 n) {
  unsigned long lo = (unsigned long)o, hi = (unsigned long)(o >> 64);
  unsigned char e;
  asm volatile("lock cmpxchg16b %[ptr]\n\tsete %[e]"
               : [e] "=q"(e), [ptr] "+m"(*p), "+a"(lo), "+d"(hi)
               : "b"((unsigned long)n), "c"((unsigned long)(n >> 64)) : "memory", "cc");
  return e;
}
asm(".pushsection .text\n.globl fs_twice\nfs_twice:\n\tleaq (%rdi,%rdi), %rax\n\tret\n.popsection");
extern long fs_twice(long);
#else
static long percpu(void) { return 41; }
static unsigned long csum(const unsigned long *p, unsigned long seed) {
  unsigned long s = seed + p[0], c = s < seed; unsigned long t = s + p[1] + c;
  c = t < s || (c && t == s); return t + c;
}
static int bare(void) { return 1; }
static unsigned ss_rights(void) { return 0x80; }
static int tbit(long nr, const unsigned long *a) { return (a[nr / 64] >> (nr % 64)) & 1; }
static long fs_twice(long x) { return 2 * x; }
#endif

int main(void) {
  unsigned long w[2] = { ~0UL, 5 }, bits = 0x24;
  volatile long n = 5;
  int t1 = tbit(n, &bits), t2 = tbit(2, &bits), t3 = tbit(3, &bits);
  int t = t1 + 2 * t2 + 4 * t3;
  unsigned long c = csum(w, 3);
  int r = (int)(percpu() + c + bare() + (ss_rights() != 0) + t);
#if defined(__x86_64__)
  unsigned __int128 x = wide(((unsigned __int128)3 << 64) | 7, n, 9);
  static unsigned __int128 slot __attribute__((aligned(16)));
  slot = x;
  int ok = cx16(&slot, x, 77) + 2 * cx16(&slot, x, 5);
  r += (int)(x >> 64) + (int)x + (int)slot + ok;
#else
  r += 55 + 77 + 1;
#endif
  r += fs_twice(4);
  return r & 255;
}
