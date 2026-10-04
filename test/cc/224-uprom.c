/* an unsigned char or short promotes to int before ~ and unary minus (C11 6.3.1.1), so both
 * answer an int: ~(unsigned char) 0 is -1, not 255, and -(unsigned short) 1 is -1, not 65535.
 * unsigned int is its own promoted type and wraps. freestanding, exit-code only. */

unsigned char uc0, uc1 = 1;
unsigned short us0, us1 = 1;
unsigned int ui1 = 1;

int main(void)
{
	volatile unsigned char a = uc0, b = uc1;
	volatile unsigned short c = us0, d = us1;
	int bad = 0;
	if (~a != -1 || (~a | 1) != -1) bad |= 1;
	if (-b != -1) bad |= 2;
	if (~c != -1 || -d != -1) bad |= 4;
	if (~uc0 >= 0 || -us1 >= 0) bad |= 8;          /* signed answers, so negative */
	if (-ui1 != 4294967295u || ~ui1 != 4294967294u) bad |= 16;
	if (sizeof(~a) != sizeof(int) || sizeof(-c) != sizeof(int)) bad |= 32;
	return bad;
}
