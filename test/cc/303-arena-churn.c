/* blocks under the mapping line fill arena after arena, free in every order, and fill them
 * again: an arena empty again goes back to the kernel (one kept spare), and none of it may
 * cost a byte. the exit counts the blocks that came back wrong */
#include <stdlib.h>
#include <string.h>

enum { N = 400 };

int main(void) {
	static unsigned char *p[N];
	static size_t sz[N];
	int bad = 0;
	unsigned r = 12345;
	for (int round = 0; round < 12; round++) {
		for (int i = 0; i < N; i++) {
			r = r * 1103515245 + 12345;
			sz[i] = 1 + (r >> 8) % 60000;
			p[i] = malloc(sz[i]);
			if (!p[i]) return 99;
			memset(p[i], (i + round) & 255, sz[i]);
		}
		for (int i = 0; i < N; i++) {
			int k = round % 3 == 0 ? i : round % 3 == 1 ? N - 1 - i : (i * 7) % N;
			for (size_t j = 0; j < sz[k]; j += 997)
				if (p[k][j] != ((k + round) & 255)) { bad++; break; }
			free(p[k]);
		}
	}
	return bad;
}
