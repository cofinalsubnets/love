/* mooncc's half of the ms_abi check: answers 0 when every call agrees with gcc's half */
#define MS __attribute__((ms_abi))
long MS peer6(long, long, long, long, long, long);
typedef long (MS *ms8)(long, long, long, long, long, long, long, long);
ms8 peer_get8(void);
long peer_calls(void);
long MS host6(long a, long b, long c, long d, long e, long f)
{ return a - b + c - d + e - f; }
unsigned MS host1(unsigned x) { return x * 10u; }
int main(void)
{
	long (MS *volatile p)(long, long, long, long, long, long) = peer6;
	int bad = 0;
	bad |= (peer6(1, 2, 3, 4, 5, 6) != 91) << 0;
	bad |= (p(6, 5, 4, 3, 2, 1) != 56) << 1;
	bad |= (peer_get8()(1, 2, 3, 4, 5, 6, 7, 8) != 204) << 2;
	bad |= (peer_calls() != 30) << 3;
	return bad;
}
