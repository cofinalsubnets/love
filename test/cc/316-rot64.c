/* the rotate idiom on a long long rotates all 64 bits, by a constant and by a variable count,
 * rotl and rotr, and on an unsigned long and an unsigned int at their own widths. 0 when all agree */
#include <stdint.h>

static unsigned long long rl(unsigned long long a, unsigned n) { return a << n | a >> (64 - n); }
static unsigned long long rr(unsigned long long a, unsigned n) { return a >> n | a << (64 - n); }
static unsigned long ul(unsigned long a) { return a << 5 | a >> (sizeof a * 8 - 5); }
static unsigned u(unsigned a, unsigned n) { return a >> n | a << (32 - n); }

int main(void) {
	volatile unsigned long long a = 0x0123456789abcdefull;
	volatile unsigned n = 13;
	int bad = 0;
	bad |= (a << 31 | a >> 33) != 0xc4d5e6f78091a2b3ull;
	bad |= (a << 32 | a >> 32) != 0x89abcdef01234567ull;
	bad |= (a >> 24 | a << 40) != 0xabcdef0123456789ull;
	bad |= rl(a, n) != 0x68acf13579bde024ull;
	bad |= rr(a, n) != 0x6f78091a2b3c4d5eull;
	bad |= rl(a, 63) != rr(a, 1);
	bad |= ul((unsigned long) a) != (sizeof (unsigned long) == 8 ? 0x2468acf13579bde0ul : (unsigned long) 0x3579bdf1ul);
	bad |= u((unsigned) a, n) != 0x6f7c4d5eu;
	return bad; }
