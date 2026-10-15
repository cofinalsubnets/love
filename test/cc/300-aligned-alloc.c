/* aligned_alloc, posix_memalign, memalign and malloc_usable_size: every alignment honoured,
 * the whole size writable, free and realloc taking the aligned pointer (the block's own
 * header lies further back), and a bad alignment refused. the exit counts what failed */
#include <stdlib.h>
#include <malloc.h>
#include <string.h>
#include <errno.h>
#include <stdint.h>

int main(void) {
	int bad = 0;
	size_t sizes[] = { 0, 1, 24, 100, 4000, 200000 };
	for (size_t al = 1; al <= (1u << 20); al *= 2)
		for (int i = 0; i < 6; i++) {
			size_t n = sizes[i];
			char *p = aligned_alloc(al, n);
			if (!p || (uintptr_t) p % al) { bad++; continue; }
			memset(p, 0x5a, n);
			if (malloc_usable_size(p) < n) bad++;
			char *q = realloc(p, n + 300);
			if (!q) { bad++; free(p); continue; }
			for (size_t k = 0; k < n; k++) if (q[k] != 0x5a) { bad++; break; }
			free(q);
			void *r = 0;
			if (posix_memalign(&r, al < sizeof(void *) ? sizeof(void *) : al, n) || (uintptr_t) r % al) bad++;
			free(r);
			char *m = memalign(al, n);
			if (!m || (uintptr_t) m % al) bad++;
			else memset(m, 1, n), free(m);
		}
	void *r = 0;
	if (posix_memalign(&r, 24, 8) != EINVAL) bad++;
	if (posix_memalign(&r, 4, 8) != EINVAL) bad++;
	if (aligned_alloc(3, 8)) bad++;
	if (malloc_usable_size(0) != 0) bad++;
	return bad;
}
