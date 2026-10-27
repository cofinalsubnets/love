/* a name's scope begins at its declarator: a file-scope object types in its own initializer
 * (the kernel's DEFINE_KFIFO), and a parameter named like a typedef hides it in the body
 * (ax25_dev *ax25_dev, phandle phandle). exit-code only */
struct k { int in, out, mask; int *data; };
static struct { struct k f; int buf[8]; } q = (typeof(q)) { { 0, 0, sizeof(q.buf) / sizeof(q.buf[0]) - 1, q.buf } };
int x = sizeof(x);

typedef struct d { int r; long pad; int rcu; } d;
typedef unsigned int ph;

static int put(d *d)
{
	typeof (d) p = (d);
	return p->r + (int)__builtin_offsetof(typeof(*(d)), rcu) + (int)sizeof(*(d));
}

static unsigned int swap(ph ph) { return (unsigned int)(ph) >> 1; }

int main(void)
{
	struct d v = { 3 };
	ph h = 6;
	return q.f.mask + (q.f.data == q.buf) * 10 + x + put(&v) + swap(h);
}
