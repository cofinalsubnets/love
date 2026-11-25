/* the types of a suffixed literal, size_t and a wide enumerator, read by _Generic and by a compare
 * that only an unsigned type answers. bits name the failing check, 55 passes */
enum { WIDE = 4000000000u };
#define IS(e, T) _Generic((e), T: 1, default: 0)
int main(void)
{
	volatile int t = -1;
	int bad = 0;
	bad |= !IS(1u, unsigned) << 0;
	bad |= !IS(5, int) << 1;
	bad |= !IS(1ul, unsigned long) << 2;
	bad |= !IS(1ull, unsigned long long) << 3;
	bad |= !IS(sizeof 1, __SIZE_TYPE__) << 4;
	bad |= (sizeof(int) > t) << 5;
	bad |= (sizeof(sizeof 1) != sizeof(__SIZE_TYPE__)) << 6;
	bad |= !IS(WIDE, unsigned) << 7;
	bad |= (t < WIDE) << 8;
	return bad ? 1 : 55;
}
