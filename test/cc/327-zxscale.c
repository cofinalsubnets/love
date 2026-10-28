/* unsigned 32-bit chains narrowed at their end, and scaled indices into arrays and through
 * pointers. bits name the failing check, 55 passes */
static unsigned lcg(unsigned s) { return 1664525u * s + 1013904223u; }
static long pick(const long *a, int i) { return a[i * 2] + a[i * 2 + 1]; }
static void put(int *a, unsigned i, int v) { a[i] = v; }
static double dpick(const double *a, long i) { return a[i]; }
int main(void)
{
	volatile unsigned s = 0xfffffff0u;
	volatile int k = 3;
	long a[8] = { 1, 2, 3, 4, 5, 6, 7, 8 };
	int b[6] = { 0 };
	double d[4] = { 0.5, 1.5, 2.5, 3.5 };
	unsigned u = s * 8u + 1u;
	int bad = 0;
	bad |= (lcg(s) != 1664525u * 0xfffffff0u + 1013904223u) << 0;
	bad |= (u != 0xffffff81u || (long)(int)u != -127) << 1;
	bad |= (pick(a, k) != 15 || pick(a, 0) != 3) << 2;
	put(b, (unsigned)k + 2u, 9);
	bad |= (b[5] != 9 || b[4] != 0) << 3;
	bad |= (dpick(d, k) != 3.5) << 4;
	bad |= ((short)(s * 4u + 7u) != -57) << 5;
	return bad ? bad : 55;
}
