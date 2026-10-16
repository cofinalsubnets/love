/* __extension__ is a no-op at a declaration's head (file, block, member, before
 * typedef) and as a cast prefix; a typedef declarator takes a trailing attribute run.
 * each check adds 1: the exit code is the pass count. */

__extension__ unsigned long long v = 40;
__extension__ typedef unsigned long long ull;
struct S { __extension__ ull w; int a; };
union U { __extension__ long long a; int b; };
typedef struct TT { int x; } TT __attribute__((__aligned__));

int main(void)
{
	__extension__ long long b = 2;
	ull y = __extension__ 3;
	__extension__ int arr[2] = {4, 5};
	struct S s = { 6, 7 };
	union U u;
	TT t = { 9 };
	__extension__ typedef int bt;
	bt z = 11;
	int r = 0;
	u.a = 8;
	r += v == 40;
	r += b == 2;
	r += y == 3;
	r += arr[0] + arr[1] == 9;
	r += s.w == 6 && s.a == 7;
	r += u.a == 8;
	r += t.x == 9;
	r += z == 11;
	r += (__extension__ 1 + 2) == 3;
	r += (int)(__extension__ (long long)10) == 10;
	return r;
}
