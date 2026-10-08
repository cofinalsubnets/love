/* a directive reads on past a comment that spans lines (a comment is one space, C11 5.1.1.2
 * phase 3): gnulib's gettext.h comments out half of an #if's condition across two lines.
 * the lines after still count from the source. exit-code only. */
#if (1 \
     /* || this half
           is commented out */ && 1)
static int ok = 1;
#else
static int ok = 0;
#endif
#define TWO /* a comment
   inside a definition */ 2

int main(void)
{
	int bad = !ok;

	bad |= (TWO != 2) << 1;
	bad |= (__LINE__ != 19) << 2;
	return bad;
}
