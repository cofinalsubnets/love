/* small blocks of every size, across each size class's edges and past the last class: no two
 * overlap, a block keeps its bytes through realloc up and down the classes, and a churn of
 * slots freed and taken again hands back nothing written over. the exit counts the bad */
#include <stdlib.h>
#include <string.h>

enum { Top = 3000, N = 4000 };

static int check(unsigned char *p, size_t n, int v) {
	for (size_t j = 0; j < n; j++)
		if (p[j] != (v & 255)) return 1;
	return 0;
}

int main(void) {
	static unsigned char *p[Top + 1][2];
	int bad = 0;
	for (int n = 1; n <= Top; n++)
		for (int k = 0; k < 2; k++) {
			if (!(p[n][k] = malloc(n))) return 99;
			memset(p[n][k], n * 2 + k, n);
		}
	for (int n = 1; n <= Top; n++)
		for (int k = 0; k < 2; k++) bad += check(p[n][k], n, n * 2 + k);
	for (int n = 1; n <= Top; n += 2) free(p[n][0]), free(p[n][1]);
	for (int n = 2; n <= Top; n += 2) bad += check(p[n][0], n, n * 2) + check(p[n][1], n, n * 2 + 1);
	for (int n = 2; n <= Top; n += 2) free(p[n][0]), free(p[n][1]);

	/* one block grown a byte at a time through every class, then shrunk */
	unsigned char *q = malloc(1);
	q[0] = 1;
	for (size_t n = 2; n <= Top; n++) {
		if (!(q = realloc(q, n))) return 98;
		q[n - 1] = (unsigned char) n;
	}
	for (size_t n = 2; n <= Top; n++) bad += q[n - 1] != (unsigned char) n;
	for (size_t n = Top; n > 7; n -= 7) {
		if (!(q = realloc(q, n))) return 97;
		bad += q[n - 1] != (unsigned char) n;
	}
	free(q);

	/* a live set replaced at random */
	static unsigned char *l[N];
	static size_t ls[N];
	unsigned r = 7;
	for (long i = 0; i < 200000; i++) {
		r = r * 1103515245 + 12345;
		unsigned k = (r >> 9) % N;
		if (l[k]) bad += check(l[k], ls[k], (int) k), free(l[k]);
		ls[k] = 1 + (r >> 3) % 2600;
		if (!(l[k] = malloc(ls[k]))) return 96;
		memset(l[k], (int) k, ls[k]);
	}
	for (int k = 0; k < N; k++)
		if (l[k]) bad += check(l[k], ls[k], k), free(l[k]);
	return bad < 90 ? bad : 90;
}
