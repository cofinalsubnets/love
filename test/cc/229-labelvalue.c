/* labels as values (gcc's &&L, goto *p): a label's address, a computed jump through one, a
 * static table of them, an interpreter's threaded dispatch, and _THIS_IP_'s shape, which
 * takes one only to say where it is. exit-code only. */

static int table(int i)
{
	static void *const t[] = { &&a, &&b, &&c };
	int r = 0;
	goto *t[i];
a:	r += 1;
b:	r += 10;
c:	r += 100;
	return r;
}

static int pick(int n)
{
	void *p = n > 3 ? &&big : &&small;
	int s = 0;
	for (int i = 0; i < n; i++)
		s += i;
	goto *p;
small:	return s;
big:	return -s;
}

/* the kernel's _THIS_IP_ */
#define here() ({ __label__ h; h: (unsigned long)&&h; })
static inline unsigned long where(void) { return here(); }

static int run(const unsigned char *code)
{
	static void *const op[] = { &&halt, &&inc, &&dbl };
	int acc = 0;
	goto *op[*code++];
inc:	acc += 1;
	goto *op[*code++];
dbl:	acc *= 2;
	goto *op[*code++];
halt:	return acc;
}

int main(void)
{
	static const unsigned char prog[] = { 1, 1, 2, 1, 2, 0 };
	if (table(0) != 111 || table(1) != 110 || table(2) != 100) return 1;
	if (pick(3) != 3 || pick(5) != -10) return 2;
	if (here() == 0 || where() == 0) return 3;
	if (run(prog) != 10) return 4;
	return 0;
}
