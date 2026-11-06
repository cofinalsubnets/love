/* an asm output whose address takes computing: a global, a member behind a pointer, an element,
   a local's array member through a cast, the kernel's smp_load_acquire shape */
#include <stdio.h>

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
	long a[4] = { 1, 2, 3, 4 };
	long i = 1, r = 0;
	struct s st = { 10, 20 }, *sp = &st;
	global(77);
	member(&sp, 88);
	asm volatile("" : "=r"(a[i]) : "0"(99L));
	asm volatile("" : "=r"(a[i + 1]) : "0"(55L));
	asm volatile("" : "=r"(pick(a)[3]) : "0"(66L));
	asm volatile("" : "+r"(a[0]));
	r = acquire(&a[3]);
	printf("%ld %ld %ld %ld %ld %ld %ld %ld %ld %d\n", G, st.a, st.b,
	       a[0], a[1], a[2], a[3], i, r, calls);
	return 0;
}
