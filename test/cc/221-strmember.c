/* a string initializing a char array that is a member or an element of a LOCAL aggregate
 * lays its bytes there, with the rest zero (6.7.9p14) -- braced or bare, designated, nested,
 * and one exactly as long as the array, which keeps no NUL. freestanding, exit-code only:
 * each wrong case sets its own bit. */

struct mid { int x; char s[13]; long y; };
struct one { char s[8]; };
struct two { struct one a[2]; char t[2][4]; };

/* n bytes of p against the string w, then zeros to the end of the n-byte array */
static int is(char const *p, char const *w, int n)
{
	int i = 0;
	for (; w[i]; i++) if (i >= n || p[i] != w[i]) return 0;
	for (; i < n; i++) if (p[i]) return 0;
	return 1;
}

int main(void)
{
	struct mid m = { 7, "abcdefghijkl", 11 };
	struct mid mb = { 7, { "abc" }, 11 };
	struct one o = { "xyz" };
	struct mid d = { .y = 2, .s = "hey", .x = 1 };
	char t[2][4] = { "ab", "cd" };
	struct two w = { { { "p" }, { "qr" } }, { "uv", "w" } };
	char e[3] = "abc";
	int bad = 0;
	if (!(is(m.s, "abcdefghijkl", 13) && m.x == 7 && m.y == 11)) bad |= 1;
	if (!(is(mb.s, "abc", 13) && mb.y == 11)) bad |= 2;
	if (!is(o.s, "xyz", 8)) bad |= 4;
	if (!(is(d.s, "hey", 13) && d.x == 1 && d.y == 2)) bad |= 8;
	if (!(is(t[0], "ab", 4) && is(t[1], "cd", 4))) bad |= 16;
	if (!(is(w.a[0].s, "p", 8) && is(w.a[1].s, "qr", 8) && is(w.t[0], "uv", 4) && is(w.t[1], "w", 4))) bad |= 32;
	if (!(e[0] == 'a' && e[1] == 'b' && e[2] == 'c')) bad |= 64;
	return bad;
}
