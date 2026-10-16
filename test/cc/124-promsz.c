/* sizeof over promoted arithmetic answers C's type: char+int is 4, shorts, ~ and
 * unary minus promote, a shift takes its left type, ?: arms meet, float wins.
 * each check adds 1: the exit code is the pass count. */

char c; short s; unsigned short us; int x; unsigned u; long l; float f;

int main(void)
{
	__typeof__(c + x) tx;             /* typeof over arithmetic types now too */

	int r = 0;
	r += sizeof(c + x) == 4;
	r += sizeof(s + s) == 4;
	r += sizeof(us + us) == 4;        /* ushort fits in int: SIGNED promote */
	r += sizeof(~c) == 4;
	r += sizeof(-s) == 4;
	r += sizeof(c << 1) == 4;
	r += sizeof(l << c) == sizeof(long);   /* the left side alone */
	r += sizeof(x ? c : s) == 4;
	r += sizeof(f + c) == 4;          /* float wins the lane, c converts IN */
	r += sizeof(f + 1.0) == 8;        /* double wins over float */
	r += sizeof(u + c) == 4;
	r += sizeof(l + u) == sizeof(long);
	r += sizeof(&c + 1) == sizeof(void *);  /* ptr + int decays and stays a pointer */
	r += sizeof(tx) == 4;
	r += (char)(c + 1) == 1 && (~c | 1) == -1;   /* the values ride unchanged */
	return r;
}
