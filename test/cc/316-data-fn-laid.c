/* a static fn named only by a static initializer is laid whatever its body holds: a large
 * negative constant sinks its form's net, and a form is no truth value. exit-code only (55) */
struct ops { long (*a)(long); };

static long fa(long x);
static const struct ops O = { .a = fa };

static long fa(long x)
{
	long k = -100000000000L;
	return k + x;
}

int main(void)
{
	const struct ops *volatile p = &O;
	return (int) p->a(100000000055L);
}
