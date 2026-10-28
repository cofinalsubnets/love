/* ms_abi (x64): definitions reached directly and through ms pointers of each spelling, the
 * fifth and sixth words on the stack above the shadow. bits name the failing check, 55 passes */
#if defined(__x86_64__)
#define MS __attribute__((ms_abi))
typedef long (MS *ms6)(long, long, long, long, long, long);
typedef unsigned long fn2(void *, int);
struct tab { ms6 f; fn2 MS *g; long (MS *h)(int); };
long MS six(long a, long b, long c, long d, long e, long f)
{ return a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f; }
static unsigned long MS two(void *p, int k) { return (unsigned long)p + k; }
static long MS one(int x) { return x < 2 ? 1 : x * one(x - 1); }
static long sysv(long a, long b) { return a - b; }
int main(void)
{
	volatile long k = 7;
	struct tab t = { six, two, one };
	struct tab *volatile pt = &t;
	int bad = 0;
	bad |= (six(1, 2, 3, 4, 5, 6) != 91) << 0;
	bad |= (pt->f(k, 1, 1, 1, 1, 1) != 27) << 1;
	bad |= (pt->g((void *)16, 3) != 19) << 2;
	bad |= (pt->h(5) != 120 || one(4) != 24) << 3;
	bad |= (sysv(k, 2) != 5) << 4;
	bad |= (t.f != six) << 5;
	return bad ? bad : 55;
}
#else
int main(void) { return 55; }
#endif
