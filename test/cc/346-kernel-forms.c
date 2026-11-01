/* linux forms mooncc refused: typeof(*f) of a function (RCU_INIT_POINTER), an __auto_type over
 * __builtin_expect (data_race(likely(..))), a word-sized integer laid as an address plus a constant
 * (cpu_current_top_of_stack), and on x64 a constant asm operand named by its C type ("a"(3 * 8)
 * is %eax, load_segments) and a word immediate (vmware's movw $port, %dx). exit-code only (55) */
static int f(int x) { return x + 1; }
static char st[64];
unsigned long p1 = (unsigned long)&st + 8 - 0;
unsigned long p2 = (unsigned long)st + (unsigned long)16;

#ifdef __x86_64__
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
#ifdef __x86_64__
	unsigned long rd = 0xffffffffffff0000ul;
	unsigned int ea;
	asm volatile("movw %[p], %%dx" : "+d"(rd) : [p] "i"(0x5658));
	asm volatile("movl %1, %0" : "=r"(ea) : "a"(24));
	bad |= rd != 0xffffffffffff5658ul || ea != 24;
#endif
	return bad ? 1 : 55;
}
