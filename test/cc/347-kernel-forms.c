/* linux forms mooncc refused: typeof(*f) of a function (RCU_INIT_POINTER), an __auto_type over
 * __builtin_expect (data_race(likely(..))), a word-sized integer laid as an address plus a constant
 * (cpu_current_top_of_stack), and on x64 a constant asm operand named by its C type ("a"(3 * 8)
 * is %eax, load_segments) and a word immediate (vmware's movw $port, %dx); noinstr's __no_profile
 * names its attribute only where __has_attribute says so; a call behind && and a hint on an inline
 * that folds to 0 is never laid (dm_zone_endio, undefined: the link is the check); cpuid's unused
 * rbx output still saves the caller's rbx. exit-code only (55) */
#if !__has_attribute(__no_profile_instrument_function__)
#error no_profile_instrument_function
#endif
static int f(int x) { return x + 1; }
static inline int g(int x) { return x * 3; }
__attribute__((__no_profile_instrument_function__)) static int np(int x) { return g(x) + 1; }
static char st[64];
unsigned long p1 = (unsigned long)&st + 8 - 0;
unsigned long p2 = (unsigned long)st + (unsigned long)16;

#ifdef __mooncc__
void never_defined(void);
struct zq { int f; };
static inline __attribute__((always_inline)) int zoned(struct zq *q) { return 0 && q->f; }
__attribute__((noinline)) int deadcall(struct zq *q, int c) {
	if (c && __builtin_expect(!!(zoned(q)), 0)) never_defined();
	return c; }
#else
#define deadcall(q, c) (c)
#endif

#ifdef __x86_64__
__attribute__((noinline)) unsigned leaf_eax(unsigned op) {
	unsigned a = op, b, c = 0, d;
	asm volatile("cpuid" : "=a"(a), "=b"(b), "=c"(c), "=d"(d) : "0"(a), "2"(c));
	return a; }
/* laid, never run: a segment load faults in user mode */
__attribute__((noinline, used)) void loadseg(void) { asm volatile("movl %0,%%ds" : : "a"(3 * 8) : "memory"); }
#endif

int main(void)
{
	int (*q)(int) = (typeof(*(f)) *)(f);
	typeof(*f) *q2 = f;
	int x = 2, bad = 0;
	__auto_type v = (__builtin_expect(!!(x == 2), 1));
	bad |= q(1) != 2 || q2(2) != 3 || v != 1 || sizeof v != sizeof(long);
	bad |= p1 - (unsigned long)st != 8 || p2 - (unsigned long)st != 16;
	bad |= np(x) != 7 || deadcall((struct zq *)st, 3) != 3;
#ifdef __x86_64__
	unsigned long rd = 0xffffffffffff0000ul;
	unsigned int ea;
	asm volatile("movw %[p], %%dx" : "+d"(rd) : [p] "i"(0x5658));
	asm volatile("movl %1, %0" : "=r"(ea) : "a"(24));
	bad |= rd != 0xffffffffffff5658ul || ea != 24;
	unsigned long kept;
	asm volatile("mov $0x1234, %%ebx\n xor %%edi, %%edi\n call leaf_eax\n mov %%rbx, %0"
	             : "=m"(kept) : : "rax", "rbx", "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11", "memory", "cc");
	bad |= kept != 0x1234;
#endif
	return bad ? 1 : 55;
}
