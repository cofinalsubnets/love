/* the kernel's process asm: the cache-line flushes (clflush over memory and through a register,
 * under a ds prefix as the alternatives pad it, clflushopt/clwb where cpuid has them), push and
 * pop through memory (pushf; pop to a flags word), movnti, a call and a jump through memory, and
 * the privileged lane laid but not run: wbinvd/invd, monitor/mwait, verw, str/sldt/lldt, the
 * fs/gs base reads and writes, rdpmc. the asm is x64's. held to gcc. */

#if defined(__x86_64__)
static void flush(volatile int *p) { asm volatile("clflush %0" : "+m"(*p)); }
static void flushr(volatile int *p) { asm volatile("clflush (%[addr])" : : [addr] "r"(p) : "memory"); }
static void flushds(volatile int *p) { asm volatile("ds clflush %0" : "+m"(*p)); }
static unsigned leaf7b(void) {
  unsigned a = 7, b, c = 0, d;
  asm("cpuid" : "+a"(a), "=b"(b), "+c"(c), "=d"(d));
  return b;
}
static void flushopt(volatile int *p) {
  if (leaf7b() >> 23 & 1) asm volatile("clflushopt %0" : "+m"(*p));
}
static void wb(volatile int *p) {
  if (leaf7b() >> 24 & 1) asm volatile("clwb %0" : "+m"(*p));
}
static unsigned long flags(void) {
  unsigned long f;
  asm volatile("pushf ; pop %0" : "=m"(f));
  return f;
}
static unsigned long through(unsigned long v) {
  unsigned long r;
  asm volatile("push %1 ; pop %0" : "=m"(r) : "m"(v));
  return r;
}
static void nt(unsigned long *d, unsigned long v) {
  asm volatile("movntiq %1, %0\n\tsfence" : "=m"(*d) : "r"(v));
}
static int seven(void) { return 7; }
static int callm(int (*f)(void)) {
  int r;
  asm volatile("call *%1" : "=a"(r) : "m"(f) : "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11", "memory");
  return r;
}
void laid(unsigned long *p, unsigned short *s, unsigned long x) {
  asm volatile("wbinvd; invd; rdpmc" : : "c"(0) : "rax", "rdx");
  asm volatile("monitor %%rax, %%ecx, %%edx" : : "a"(p), "c"(0), "d"(0));
  asm volatile("mwait %%eax, %%ecx" : : "a"(0), "c"(0));
  asm volatile("verw %0" : : "m"(*s));
  asm volatile("str %0; sldt %0; lldt %0" : "+m"(*s));
  asm volatile("str %0" : "=r"(x));
  asm volatile("wrfsbase %0; wrgsbase %0; rdfsbase %0; rdgsbase %0" : "+r"(x));
  asm volatile("jmp *%0" : : "m"(*p));
}
#else
static void flush(volatile int *p) { (void)p; }
static void flushr(volatile int *p) { (void)p; }
static void flushds(volatile int *p) { (void)p; }
static void flushopt(volatile int *p) { (void)p; }
static void wb(volatile int *p) { (void)p; }
static unsigned long flags(void) { return 2; }
static unsigned long through(unsigned long v) { return v; }
static void nt(unsigned long *d, unsigned long v) { *d = v; }
static int seven(void) { return 7; }
static int callm(int (*f)(void)) { return f(); }
#endif

int main(void) {
  static volatile int a[64];
  int bad = 0;
  for (int i = 0; i < 64; i++) a[i] = i * 7;
  flush(&a[0]);
  flushr(&a[16]);
  flushds(&a[32]);
  flushopt(&a[48]);
  wb(&a[63]);
  for (int i = 0; i < 64; i++)
    if (a[i] != i * 7) bad |= 1;
  a[5] = 99;
  flush(&a[5]);
  if (a[5] != 99) bad |= 2;
  if (!(flags() & 2)) bad |= 4;                      /* bit 1 of rflags is always set */
  if (through(0x123456789abcdefUL) != 0x123456789abcdefUL) bad |= 8;
  unsigned long d = 0;
  nt(&d, 42);
  if (d != 42) bad |= 16;
  if (callm(seven) != 7) bad |= 32;
  return bad;
}
