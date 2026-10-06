/* the lse atomics as the kernel spells them (ldadd, stset, cas, swp and their orders and
 * sizes), run only where ID_AA64ISAR0_EL1 says the core has them; an asm goto with an
 * output that holds on the jump as well as the fall-through; .inst over gas's `!!`; a
 * "p" address prefetched through %a. a target with no template here computes the same in C. */
typedef unsigned int u32;
typedef unsigned long u64;

#if defined(__aarch64__)
static int lse(void) { u64 r; asm("mrs %0, id_aa64isar0_el1" : "=r"(r)); return (r >> 20 & 15) >= 2; }
static u64 fadd(u64 *p, u64 i) {
  u64 r;
  asm volatile("prfm pstl1keep, %a0" : : "p"(p));
  if (!lse()) { r = *p; *p += i; return r; }
  asm volatile(".arch_extension lse\n ldaddal %1, %0, %2" : "=r"(r) : "r"(i), "Q"(*p) : "memory");
  return r;
}
static u32 lse32(u32 *p) {
  u32 o = 9, n = 40;
  if (!lse()) { p[0] |= 6; p[1] = 40; p[2] = 40; return 9; }
  asm volatile("stset %w1, %0" : "+Q"(p[0]) : "r"(6u));
  asm volatile("casal %w0, %w2, %1" : "+r"(o), "+Q"(p[1]) : "r"(n));
  asm volatile("swpl %w1, %w1, %0" : "+Q"(p[2]), "+r"(n) :);
  return o;
}
static u32 ldclrb(unsigned char *p) {
  u32 r;
  if (!lse()) { r = *p; *p &= ~3; return r; }
  asm volatile("ldclrb %w1, %w0, %2" : "=r"(r) : "r"(3), "Q"(*p) : "memory");
  return r;
}
static int vis(int x) {
  int r;
  asm goto("mov %w0, %w1\n add %w0, %w0, #7\n cbz %w1, %l[zero]" : "=r"(r) : "r"(x) : : zero);
  return r + 100;
zero:
  return r;
}
static u32 pan(void) { u32 r; asm(".inst 0xd2800000 | ((!!(3)) << 5) | ((!(0)) << 10) \n mov %w0, w0" : "=r"(r) : : "x0"); return r; }
#elif defined(__x86_64__)
static u64 fadd(u64 *p, u64 i) { u64 r = *p; *p += i; return r; }
static u32 lse32(u32 *p) { p[0] |= 6; p[1] = 40; p[2] = 40; return 9; }
static u32 ldclrb(unsigned char *p) { u32 r = *p; *p &= ~3; return r; }
static int vis(int x) {
  int r;
  asm goto("movl %1, %0\n addl $7, %0\n testl %1, %1\n jz %l[zero]" : "=r"(r) : "r"(x) : "cc" : zero);
  return r + 100;
zero:
  return r;
}
static u32 pan(void) { return 0x21; }
#else
static u64 fadd(u64 *p, u64 i) { u64 r = *p; *p += i; return r; }
static u32 lse32(u32 *p) { p[0] |= 6; p[1] = 40; p[2] = 40; return 9; }
static u32 ldclrb(unsigned char *p) { u32 r = *p; *p &= ~3; return r; }
static int vis(int x) { return x ? x + 107 : 7; }
static u32 pan(void) { return 0x21; }
#endif

int main(void) {
  u64 c = 5;
  u32 w[3] = {1, 9, 30};
  unsigned char b = 7;
  int s = 0;
  s += fadd(&c, 3) == 5 && c == 8;
  s += lse32(w) == 9 && w[0] == 7 && w[1] == 40 && w[2] == 40;
  s += ldclrb(&b) == 7 && b == 4;
  s += vis(0) == 7 && vis(2) == 109;
  s += pan() == 0x21;
  return s == 5 ? 0 : 1;
}
