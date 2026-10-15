/* realloc keeps every byte as a block grows: in place into a freed neighbour, past one
 * that is still live, across the line where a block gets a mapping of its own, and as that
 * mapping grows. the exit counts the bytes that moved wrong */
#include <stdlib.h>
#include <string.h>

static int check(unsigned char *p, size_t n, unsigned seed) {
	int bad = 0;
	for (size_t i = 0; i < n; i++) if (p[i] != (unsigned char) (i * 31 + seed)) { bad++; break; }
	return bad;
}
static void fill(unsigned char *p, size_t from, size_t n, unsigned seed) {
	for (size_t i = from; i < n; i++) p[i] = (unsigned char) (i * 31 + seed);
}

int main(void) {
	int bad = 0;
	/* a neighbour freed: the block can take its room */
	unsigned char *a = malloc(100), *b = malloc(100), *c = malloc(100);
	fill(a, 0, 100, 1), fill(c, 0, 100, 3);
	free(b);
	a = realloc(a, 180);
	bad += check(a, 100, 1), fill(a, 100, 180, 1), bad += check(a, 180, 1), bad += check(c, 100, 3);
	/* a live neighbour: it moves */
	unsigned char *d = malloc(64), *e = malloc(64);
	fill(d, 0, 64, 4), fill(e, 0, 64, 5);
	d = realloc(d, 4000);
	bad += check(d, 64, 4), bad += check(e, 64, 5);
	/* doubling across the mapping line and on through mremap */
	size_t n = 16;
	unsigned char *s = malloc(n);
	fill(s, 0, n, 7);
	while (n < (8u << 20)) {
		size_t m = n * 2;
		s = realloc(s, m);
		if (!s) return 99;
		bad += check(s, n, 7);
		fill(s, n, m, 7);
		n = m;
	}
	bad += check(s, n, 7);
	free(s), free(a), free(c), free(d), free(e);
	return bad;
}
