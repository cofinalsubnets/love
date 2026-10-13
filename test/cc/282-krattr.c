/* a K&R parameter declaration may carry an attribute after its declarator (tar's getdate.c:
 * `char *s __attribute__ ((__unused__));`) */
static int
quiet (s, n, m)
	char *s __attribute__ ((__unused__));
	int n __attribute__ ((__unused__)), m;
{
	return 3;
}

static int
len (s)
	const char *s __attribute__ ((__unused__));
{
	int n = 0;
	while (s[n]) n++;
	return n;
}

int main(void) {
	return quiet ("x", 1, 2) + len ("four");
}
