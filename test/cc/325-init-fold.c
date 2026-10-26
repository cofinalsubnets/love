/* a floating constant expression initializes an integer object as by assignment, truncating
 * toward zero: the clk tables' F(f, s, 4.5, m, n) halves. and a table's initializer may take
 * its own sizeof, acpica's TABLE_SIZE, or a literal's address, 8250's REPORT_CONFIG. exit-code
 * only (255) */
struct ftbl { unsigned long freq; unsigned char src, pre; unsigned short m, n; };
#define F(f, s, h, m, n) { (f), (s), (2 * (h) - 1), (m), (n) }

static const struct ftbl tb[] = { F(19200000, 0, 1, 0, 0), F(177780000, 1, 4.5, 0, 0), F(1, 2, 2.5, 3, 4) };
static const int i79 = 7.9;
static const signed char sneg = -2.5;
static const _Bool bhalf = 0.5;
static const unsigned short us = 65535.0;
int g3 = 1.5 * 2;
static const unsigned long rep = 0 ? 0 : (unsigned long)&"PARPORT";
static const char (*lit)[3] = &"ab";
static struct ftbl self[2] = { { 0, 0, sizeof(self) / sizeof(struct ftbl), 0, 0 }, { 1 } };

int main(void)
{
	static const long lk = 1e3 / 8;
	int r = 0;
	r |= (tb[0].pre == 1) << 0;
	r |= (tb[1].pre == 8 && tb[2].pre == 4 && tb[2].n == 4) << 1;
	r |= (i79 == 7) << 2;
	r |= (sneg == -2) << 3;
	r |= (bhalf == 1 && us == 65535) << 4;
	r |= (g3 == 3 && lk == 125) << 5;
	r |= (self[0].pre == 2 && self[1].freq == 1) << 6;
	r |= (((const char *)rep)[1] == 'A' && (*lit)[1] == 'b' && sizeof *lit == 3) << 7;
	return r;
}
