/* a function declared inside a block is an extern function, not a local --
 * including the K&R `void f(), g();` list. each check adds 1: the exit code is the pass count. */

static int add1(char *p)  { return *p + 1; }
static long twice(long n) { return n + n; }

/* declared block-scope below and defined here, so nothing at file scope says it */
int blockonly(int n);
int blockonly(int n) { return n * 3; }

int seven(void)  { return 7; }
int eleven(void) { return 11; }

static int deep(void)
{
	int blockonly(int);      /* an inner block's declaration, under a local of its own */
	int n = 4;
	return blockonly(n) == 12;
}

int main(void)
{
	char s = 1;
	int v[16];
	int r = 0;
	int (*fp)(char *) = add1;   /* a function POINTER stays a local */

	{
		int add1(char *);           /* the 00078 shape */
		long twice(long), t = 7;    /* mixed with an object sharing the base type */

		r += add1(&s) == 2;
		r += twice(t) == 14;
		r += t == 7;                /* the object beside it is still an object */
	}
	{
		/* the K&R spelling: empty parens, comma-listed. Both take no argument,
		   because a C23 gcc reads `f()` as `f(void)` and the battery's control
		   is gcc at its default standard. */
		int seven(), eleven();

		r += seven() == 7;
		r += eleven() == 11;
	}

	r += deep();
	r += fp(&s) == 2;
	v[0] = r;
	return v[0];
}
