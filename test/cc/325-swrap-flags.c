/* shrink-wrap: the frame laid where the entry's frameless run falls out sits between a compare and
 * the setcc that reads it, so it must leave the flags be. exit-code only (55) */
_Bool en = 1, ini = 1;
struct mnt { void *root; };
int rootv;
struct mnt m0 = { &rootv };
struct mnt *mt = &m0;
int cnt;

__attribute__((noinline)) int pin(void *t, struct mnt **m, int *c) { (void)t; (void)m; return (*c)++ < 0; }
__attribute__((noinline)) void *mk(void *p, const char *n) { return p == &rootv && *n == 'a' ? (void *)n : (void *)-17L; }
__attribute__((noinline)) void rel(struct mnt **m, int *c) { (void)m; (*c)--; }

static inline _Bool iserr(const void *p) { return __builtin_expect(!!((unsigned long)p >= (unsigned long)-4095), 0); }

__attribute__((noinline)) void *sw(const char *name, void *parent)
{
	void *d;
	int error;
	if (!en) return (void *)-1L;
	if (!ini) return (void *)-2L;
	if (iserr(parent)) return parent;
	error = pin(0, &mt, &cnt);
	if (error) return (void *)(long)error;
	if (!parent) parent = mt->root;
	d = mk(parent, name);
	if (iserr(d)) rel(&mt, &cnt);
	return d;
}

int main(void)
{
	const char *a = "a";
	int bad = 0;
	bad |= sw(a, 0) != a;
	bad |= sw(a, (void *)-5L) != (void *)-5L;
	bad |= sw("b", 0) != (void *)-17L || cnt != 1;
	return bad ? 1 : 55;
}
