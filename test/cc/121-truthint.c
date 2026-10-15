/* a truth value is an int: !, the relations, && and || (sizeof 4, and it folds
 * in an array bound). each check adds 1: the exit code is the pass count. */

char c = 1;
long l = 2;
double d = 0.5;
char *p = &c;

char pad[sizeof(0 == 0) + 1];             /* a truth value folds into a bound now */

int main(void)
{
	int r = 0;

	r += sizeof(!c) == sizeof(int);
	r += sizeof(!l) == sizeof(int);
	r += sizeof(!d) == sizeof(int);   /* a double's truth is an int too */
	r += sizeof(!p) == sizeof(int);   /* and a pointer's */
	r += sizeof(c == l) == sizeof(int);
	r += sizeof(c != d) == sizeof(int);
	r += sizeof(l < c) == sizeof(int);
	r += sizeof(l >= l) == sizeof(int);
	r += sizeof(c && d) == sizeof(int);
	r += sizeof(p || l) == sizeof(int);
	r += sizeof(pad) == 5;
	r += (!0) == 1;                   /* the values, unregressed */
	r += (!5) == 0;
	r += (l < c) == 0;
	r += (c && l) == 1;
	return r;
}
