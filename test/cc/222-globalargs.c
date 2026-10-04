/* a global as every argument position: each loads into its own argument register. on a64 the
 * fifth is x4, and a load based on r4 reads the frame there -- so a call taking a global fifth
 * must not stage it as one. freestanding, exit-code only: each wrong position sets its bit. */

int g1 = 1, g2 = 2, g3 = 3, g4 = 4, g5 = 256, g6 = 6, g7 = 7, g8 = 8;
long gl = 5000000000;
unsigned char gc = 200;
short gs = -12;

__attribute__((noinline)) static int eight(int a, int b, int c, int d, int e, int f, int g, int h)
{
	return (a != 1) | (b != 2) << 1 | (c != 3) << 2 | (d != 4) << 3
	     | (e != 256) << 4 | (f != 6) << 5 | (g != 7) << 6 | (h != 8) << 7;
}

__attribute__((noinline)) static int kinds(int a, int b, int c, int d, long e, int f, unsigned char g, short h)
{
	return (e != 5000000000) | (g != 200) << 1 | (h != -12) << 2 | (a + b + c + d + f != 16) << 3;
}

int main(void)
{
	return eight(g1, g2, g3, g4, g5, g6, g7, g8) | kinds(g1, g2, g3, g4, gl, g6, gc, gs) << 8;
}
