/* thumb-2 inline asm on A-profile: a 64-bit operand rides a register pair, %Q its low register
 * and %R its high, as an input, an output and both at once; barriers with an option, and yield.
 * targets without a template compute the same. */
typedef unsigned long long u64;
typedef unsigned int u32;

#if defined(__thumb2__) && !defined(__ARM_ARCH_7EM__) && !defined(__ARM_ARCH_7M__)
static u64 add64(u64 a, u64 b) {
  u64 r;
  asm("adds %Q0, %Q1, %Q2\n adc %R0, %R1, %R2" : "=&r"(r) : "r"(a), "r"(b) : "cc");
  return r;
}
static u64 swap(u64 a) { u64 r; asm("mov %Q0, %R1\n mov %R0, %Q1" : "=&r"(r) : "r"(a)); return r; }
static void inc(u64 *p) { asm("adds %Q0, %Q0, #1\n adc %R0, %R0, #0" : "+r"(*p) : : "cc"); }
static u32 hi(u64 a) { u32 r; asm("mov %0, %R1" : "=r"(r) : "r"(a)); return r; }
static u64 join(u32 l, u32 h) { u64 r; asm("mov %Q0, %1\n mov %R0, %2" : "=&r"(r) : "r"(l), "r"(h)); return r; }
static void bar(void) { asm volatile("dmb ish\n dmb ishld\n dsb\n yield" : : : "memory"); }
#else
static u64 add64(u64 a, u64 b) { return a + b; }
static u64 swap(u64 a) { return a >> 32 | a << 32; }
static void inc(u64 *p) { ++*p; }
static u32 hi(u64 a) { return a >> 32; }
static u64 join(u32 l, u32 h) { return (u64)h << 32 | l; }
static void bar(void) {}
#endif

int main(void) {
  u64 a = 0x00000001ffffffffULL, b = 0x0000000200000001ULL, c = 0xffffffffffffffffULL, d = 0x7fffffffULL;
  inc(&c);
  inc(&d);
  bar();
  return (add64(a, b) != 0x0000000400000000ULL) + 2 * (swap(0x1122334455667788ULL) != 0x5566778811223344ULL)
         + 4 * (c != 0) + 8 * (d != 0x80000000ULL) + 16 * (hi(0xabcdef0123456789ULL) != 0xabcdef01)
         + 32 * (join(0x89abcdef, 0x01234567) != 0x0123456789abcdefULL);
}
