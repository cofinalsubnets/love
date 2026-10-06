/* a switch laid as a table whose default arm two ways reach: the bounds check, before any
 * frame, and the table jump, after it (lua's lcode.c validop, a frame needed by the calls in
 * one arm). the default must return through the same frame on both. exit-code only. */
typedef struct { union { long long i; double n; } v; unsigned char tt; } TV;

static int toint(TV *v, long long *p, int mode)
{
	if (v->tt == 3) { *p = v->v.i; return 1; }
	if (v->tt == 19 && mode) { *p = (long long)v->v.n; return v->v.n == *p; }
	return 0;
}

static int validop(int op, TV *v1, TV *v2)
{
	switch (op) {
	case 7: case 8: case 9:
	case 10: case 11: case 13: {
		long long i;
		return toint(v1, &i, 0) && toint(v2, &i, 0);
	}
	case 3: case 5: case 6:
		return (v2->tt == 3 ? (double)v2->v.i : v2->v.n) != 0;
	default:
		return 1;
	}
}

int main(void)
{
	TV a = {{.i = 3}, 3}, z = {{.n = 0.0}, 19}, f = {{.n = 1.5}, 19};
	int r = 0;
	for (int op = -2; op < 16; op++)
		r = r * 3 + validop(op, &a, &z) * 2 + validop(op, &f, &a);
	return (int)((unsigned)r % 251);
}
