/* an asm output whose address takes computing: a global, a member behind a pointer, an element,
   a call's element, a local's array member through a cast (the kernel's smp_load_acquire). no libc */
long G;
struct s { long a, b; };

static void global(long v) { asm volatile("" : "=r"(G) : "0"(v)); }
static void member(struct s **pp, long v) { asm volatile("" : "=r"((*pp)->b) : "0"(v)); }

static int calls;
static long *pick(long *a) { calls++; return a; }

static long acquire(long *p)
{
	union { long v; char c[1]; } u;
	asm volatile("" : "=r"(*(long *)u.c) : "0"(*p) : "memory");
	return u.v;
}

int main(void)
{
	long a[4];
	long i = 1;
	struct s st, *sp = &st;
	a[0] = 1; a[1] = 2; a[2] = 3; a[3] = 4;
	st.a = 10; st.b = 20;
	global(77);
	member(&sp, 88);
	asm volatile("" : "=r"(a[i]) : "0"(99L));
	asm volatile("" : "=r"(a[i + 1]) : "0"(55L));
	asm volatile("" : "=r"(pick(a)[3]) : "0"(66L));
	asm volatile("" : "+r"(a[0]));
	if (G != 77) return 1;
	if (st.a != 10 || st.b != 88) return 2;
	if (a[0] != 1 || a[1] != 99 || a[2] != 55 || a[3] != 66) return 3;
	if (acquire(&a[3]) != 66) return 4;
	if (calls != 1) return 5;
	return 0;
}
