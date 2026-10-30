/* a static body is parsed only once the unit reaches it: through a call, a chain of calls, a
 * pointer in an initializer, a prototype ahead of it; one that names a tag or a typedef is
 * parsed where it stands, and a local may take a name a later typedef takes */
struct pt { int x, y; };
static int twice(int v);
static int chain2(int v) { return twice(v) + 1; }
static int chain1(int v) { return chain2(v) * 3; }
static int viaptr(int v) { return v - 4; }
static int (*const tab[])(int) = { viaptr };
static int shade(int v) { int T = v; T = T * 2; return T; }
typedef int T;
static int tagged(int v) { struct loc { int a; } l = { v }; typedef int U; U u = l.a; return u + 1; }
static int addp(int *restrict a, const int *restrict b) { *a += *b; return *a; }
static inline int unused(int v) { return twice(v) + chain2(v); }
static int twice(int v) { return v * 2; }

int main(void)
{
	struct pt p = { 1, 2 };
	T t = 5;
	int a = 3, b = 4;
	return chain1(p.x) + tab[0](10) + shade(t) + tagged(p.y) + addp(&a, &b) - 34;
}
