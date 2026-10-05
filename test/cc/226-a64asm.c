/* a64's inline asm as the kernel spells it: Q/Qo/+Q/=Q memory operands, "rZ", cbnz in an
 * exclusive loop and to an asm goto's label, bic/rbit/adc, the unprivileged store, .inst, a
 * sysreg EL0 may read, and an alternative's out-of-line replacement in .subsection 1 under
 * its .org size checks. a target with no template here computes the same in C. */
typedef unsigned int u32;
typedef unsigned long u64;

#if defined(__aarch64__)
static void wl(u32 val, volatile void *addr) {
  volatile u32 *ptr = addr;
  asm volatile("str %w0, %1" : : "rZ"(val), "Qo"(*ptr));
}
static int addret(int i, int *v) {
  int r; u32 t;
  asm volatile("1: ldxr %w0, %2\n add %w0, %w0, %w3\n stxr %w1, %w0, %2\n cbnz %w1, 1b"
               : "=&r"(r), "=&r"(t), "+Q"(*v) : "r"(i));
  return r;
}
static u64 rd(u64 *p) { u64 v; asm("ldr %0, %1" : "=r"(v) : "Q"(*p)); return v; }
static void wr(u64 *p, u64 v) { asm("str %1, %0" : "=Q"(*p) : "r"(v)); }
static u64 bic(u64 a, u64 b) { u64 r; asm("bic %0, %1, %2" : "=r"(r) : "r"(a), "r"(b)); return r; }
static u32 rbit(u32 a) { u32 r; asm("rbit %w0, %w1" : "=r"(r) : "r"(a)); return r; }
static u64 add2(u64 a, u64 b) {      /* the low words carry into the high pair */
  u64 lo, hi;
  asm("adds %0, %2, %3\n adc %1, xzr, xzr" : "=&r"(lo), "=&r"(hi) : "r"(a), "r"(b) : "cc");
  return hi;
}
static void ust(u64 *p, u64 v) { asm volatile("sttr %1, [%0]" : : "r"(p), "r"(v) : "memory"); }
static u64 one(void) { u64 r; asm(".inst 0xd2800021\n mov %0, x1" : "=r"(r) : : "x1"); return r; }
static u64 tp(void) { u64 r; asm volatile("yield\n sev\n mrs %0, tpidr_el0" : "=r"(r)); return r; }
static int nz(u32 x) {
  asm goto("cbnz %w0, %l[yes]" : : "r"(x) : : yes);
  return 0;
yes:
  return 1;
}
static int alt(void) {
  int r;
  asm volatile("661: mov %w0, #1\n662:\n"
               ".subsection 1\n663: mov %w0, #2\n664:\n"
               ".org . - (664b-663b) + (662b-661b)\n.org . - (662b-661b) + (664b-663b)\n"
               ".previous\n" : "=r"(r));
  return r;
}
#endif

int main(void) {
  u32 x = 5; u64 y = 7, z = 0, w = 0; int c = 1, s = 0;
#if defined(__aarch64__)
  wl(0, &x); s += x;
  wl(9, &x); s += x;
  s += addret(4, &c); s += c;
  z = rd(&y); wr(&y, 11); s += (int)(z + y);
  s += (int)bic(0xff, 0x0f) + (int)(rbit(1) >> 28) + (int)add2(~0ul, 2);
  ust(&w, 13); s += (int)w;
  s += (int)one();
  s += tp() == tp();
  s += alt();
  s += nz(3) + nz(0);
#else
  x = 0; s += x; x = 9; s += x;
  c += 4; s += c; s += c;
  z = y; y = 11; s += (int)(z + y);
  s += (0xff & ~0x0f) + 8 + 1;
  w = 13; s += (int)w;
  s += 1;
  s += 1;
  s += 1;
  s += 1;
#endif
  return s == 303 ? 0 : 1;
}
