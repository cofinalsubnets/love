/* an lvalue that steps steps once under ++/--: `++*p++` bumps the byte p points
 * at and advances p by one. each check adds 1: the exit code is the pass count. */

#include <stdio.h>

static char buf[8];

/* carry into a digit string, right to left */
static void carry(char *s, int n)
{
	char *p = s + n;
	for (;;) {
		if (p == s) {
			*p++ = '1';
			break;
		}
		if (*--p != '9') {
			++*p++;
			break;
		}
	}
	*p = '\0';
}

int main(void)
{
	char *p;
	int v[4];
	int i;
	int r = 0;

	buf[0] = '8'; buf[1] = 'X'; buf[2] = '\0';
	p = buf;
	++*p++;
	r += buf[0] == '9';          /* the byte p pointed AT, not the next one */
	r += buf[1] == 'X';
	r += (p - buf) == 1;         /* advanced once, not twice */

	buf[0] = '8'; p = buf;
	--*p++;
	r += buf[0] == '7';
	r += (p - buf) == 1;

	buf[0] = '8'; p = buf;
	(*p++)++;                    /* the post spelling, which was always right */
	r += buf[0] == '9';
	r += (p - buf) == 1;

	/* an indexed lvalue whose index steps */
	v[0] = 10; v[1] = 20; v[2] = 30; v[3] = 40;
	i = 0;
	++v[i++];
	r += v[0] == 11;
	r += v[1] == 20;
	r += i == 1;

	/* and the calm lvalues, which must not have moved */
	i = 5;
	++i;
	r += i == 6;
	v[2] = 7;
	++v[2];
	r += v[2] == 8;
	buf[0] = '8'; p = buf;
	++*p;
	r += buf[0] == '9';

	printf("%c%c %d %d %d %d\n", buf[0], buf[1], v[0], v[1], i, (int)(p - buf));

	buf[0] = '3'; buf[1] = '1'; buf[2] = '4'; buf[3] = '8'; buf[4] = '\0';
	carry(buf, 4);
	r += buf[3] == '9';          /* rounding the last digit */
	r += buf[4] == '\0';
	printf("%s\n", buf);

	buf[0] = '9'; buf[1] = '9'; buf[2] = '\0';
	carry(buf, 2);
	r += buf[0] == '1';          /* the all-nines lane: carry off the end */
	printf("%s\n", buf);

	return r;
}
