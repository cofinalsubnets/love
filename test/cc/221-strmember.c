/* a string initializing a char array that is a member or an element of a LOCAL aggregate
 * lays its bytes there, with the rest zero (6.7.9p14) -- braced or bare, designated, nested,
 * and one exactly as long as the array, which keeps no NUL. held to gcc. */
#include <stdio.h>

struct mid { int x; char s[13]; long y; };
struct one { char s[8]; };
struct two { struct one a[2]; char t[2][4]; };

int main(void)
{
	struct mid m = { 7, "abcdefghijkl", 11 };
	struct mid mb = { 7, { "abc" }, 11 };
	struct one o = { "xyz" };
	struct mid d = { .y = 2, .s = "hey", .x = 1 };
	char t[2][4] = { "ab", "cd" };
	struct two w = { { { "p" }, { "qr" } }, { "uv", "w" } };
	char e[3] = "abc";
	printf("m[%s %d %ld] mb[%s] o[%s] d[%s %d %ld] t[%s %s] w[%s %s %s %s] e[%.3s]\n",
	       m.s, m.x, m.y, mb.s, o.s, d.s, d.x, d.y, t[0], t[1], w.a[0].s, w.a[1].s, w.t[0], w.t[1], e);
	int z = 0;
	for (int i = 4; i < 13; i++) z += mb.s[i];
	for (int i = 2; i < 8; i++) z += w.a[1].s[i];
	printf("tail zeros: %d\n", z);
	return 0;
}
