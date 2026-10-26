/* a struct or union a register holds whole is an asm output ("=&r"(lockval), the kernel's
 * hyp_spin_lock): it stores as the integer its size is. exit-code only */
typedef union sl { unsigned int v; struct { unsigned short owner, next; }; } sl;
struct p2 { unsigned char a, b; };

static int f(unsigned int x)
{
	sl lv;
	struct p2 q;
#if defined(__x86_64__)
	asm volatile("movl %1, %0\n\taddl $0x10000, %0" : "=&r" (lv) : "r" (x));
	asm volatile("movl $0x0705, %k0" : "=r" (q));
#elif defined(__aarch64__)
	asm volatile("add %w0, %w1, #0x10000" : "=&r" (lv) : "r" (x));
	asm volatile("mov %w0, #0x0705" : "=r" (q));
#else
	lv.v = x + 0x10000;
	q.a = 5, q.b = 7;
#endif
	return lv.next * 100 + lv.owner + q.a + q.b * 1000;
}

int main(int argc, char **argv)
{
	(void)argv;
	return f(argc + 2) & 0xff;
}
