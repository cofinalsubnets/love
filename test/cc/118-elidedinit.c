/* an elided initializer fills whole elements and an implied [] bound counts them
 * (C 6.7.9p20): struct elements, a union takes one, a bitfield one, a char array
 * one string. each check adds 1: the exit code is the pass count. */

typedef struct { int a, b, c, d, e, f, g; } PT;
PT cases[] = { 1,2,3,4,5,6,7, 8,9,10,11,12,13,14 };

struct N { int x; struct { int y, z; } n; };
struct N nest[] = { 1,2,3, 4,5,6 };

struct B { unsigned a:1; unsigned b:1; };
struct B bits[] = { 1,0, 1,1, 0,1 };

union U { int a; int b; };
union U uni[] = { 1, 2, 3 };

char names[][8] = { "ab", "cd", "ef" };

struct S { char n[4]; int v; };
struct S tab[] = { "ab", 1, "cd", 2 };

int rows[][2] = { 1,2,3,4,5,6 };          /* the array lane, unregressed */
int deep[][2][3] = { 1,2,3,4,5,6,7,8,9,10,11,12 };
PT braced[] = { {1,2,3,4,5,6,7}, {8,9,10,11,12,13,14} };   /* an item an element */

#define N(a) ((int)(sizeof(a) / sizeof(*(a))))

int main(void)
{
	int r = 0;

	r += N(cases) == 2;
	r += cases[1].a == 8 && cases[1].g == 14;   /* the bytes were never the wrong half */
	r += N(nest) == 2;
	r += nest[1].n.z == 6;
	r += N(bits) == 3;
	r += bits[2].b == 1;    /* the bits themselves are 120-bfinit's */
	r += N(uni) == 3;
	r += uni[2].a == 3;
	r += N(names) == 3;
	r += names[2][0] == 'e' && names[2][1] == 'f' && names[2][2] == 0;
	r += N(tab) == 2;
	r += tab[1].n[0] == 'c' && tab[1].v == 2;
	r += N(rows) == 3;
	r += N(deep) == 2;
	r += N(braced) == 2;
	return r;
}
