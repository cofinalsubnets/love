/* a tentative definition completes an earlier `extern T x[];` (C 6.2.7): the
 * object is laid at full size, so a write through one array leaves the other alone
 * and the trailing scalars catch one laid short. */
#include <stdio.h>

extern char a[];
extern char b[];
extern int  tail;

char a[1024];
char b[1024];
int  tail = 0x5a5a;

/* the same shape the other way round: complete FIRST, then the open
 * declaration, which must not shrink what is already known. */
char c[256];
extern char c[];

int main(void)
{
	int i, bad = 0;

	for (i = 0; i < 1024; i++) { a[i] = 0; b[i] = 0; }
	for (i = 0; i < 256; i++) c[i] = 0;

	/* fill a entirely; b and the scalar past it must not move */
	for (i = 0; i < 1024; i++) a[i] = (char)(i & 0x7f);
	for (i = 0; i < 1024; i++) if (b[i] != 0) bad++;
	if (tail != 0x5a5a) bad += 1000;

	/* now fill b entirely; a must still read back what it was given */
	for (i = 0; i < 1024; i++) b[i] = (char)((i * 3) & 0x7f);
	for (i = 0; i < 1024; i++) if (a[i] != (char)(i & 0x7f)) bad++;
	if (tail != 0x5a5a) bad += 1000;

	/* and the complete-then-open direction */
	for (i = 0; i < 256; i++) c[i] = (char)(i & 0x3f);
	for (i = 0; i < 256; i++) if (c[i] != (char)(i & 0x3f)) bad++;

	printf("%d %d %d %d %d\n", bad, (int)a[7], (int)b[7], (int)c[7], tail);
	return bad;
}
