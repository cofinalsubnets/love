/* a size past PTRDIFF_MAX is refused, never a small block passed off as the large one: the
 * unit count and the page rounding wrapped, so malloc(SIZE_MAX) came back as one page. glibc
 * refuses all of these; the exit counts the ones that were not */
#include <stdlib.h>
#include <stdint.h>

int main(void) {
	volatile size_t huge[] = { SIZE_MAX, SIZE_MAX - 8, SIZE_MAX - 4096, SIZE_MAX / 2 + 1 };
	int bad = 0;
	for (int i = 0; i < 4; i++) {
		void *p = malloc(huge[i]);
		if (p) bad++, free(p);
		p = realloc(0, huge[i]);
		if (p) bad++, free(p);
	}
	volatile size_t n = SIZE_MAX / 2 + 1;
	void *q = calloc(n, 2);
	if (q) bad++, free(q);
	char *ok = malloc(100);
	if (!ok) bad += 16;
	else ok[99] = 1, free(ok);
	return bad;
}
