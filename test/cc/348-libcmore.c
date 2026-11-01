/* the libc the kernel's host tools reach for: memmem, memccpy, strlcpy/strlcat, putenv,
   posix_fallocate, and the tsearch tree, an in-order walk after deletes */
#define _GNU_SOURCE
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <search.h>
#include <sys/stat.h>

static int cmp(void const *a, void const *b) { return *(int const *) a - *(int const *) b; }
static int seen[64], nseen;
static void visit(void const *n, VISIT v, int d) {
	(void) d;
	if (v == postorder || v == leaf) seen[nseen++] = **(int *const *) n; }
static void nofree(void *p) { (void) p; }

int main(void) {
	char const hay[] = "objtool\0livepatch=Y";
	if (memmem(hay, sizeof hay, "\0livepatch=Y", 12) != hay + 7) return 1;
	if (memmem(hay, 7, "tool", 4) != hay + 3) return 2;
	if (memmem(hay, 7, "x", 1) || memmem(hay, 3, "tool", 4)) return 3;
	if (memmem(hay, 7, "", 0) != hay) return 4;

	char d[16];
	char *e = memccpy(d, "ab/cd", '/', 16);
	if (e != d + 3 || d[2] != '/') return 5;
	if (memccpy(d, "abc", '/', 3)) return 6;

	if (strlcpy(d, "hello", sizeof d) != 5 || strcmp(d, "hello")) return 7;
	if (strlcpy(d, "hello", 3) != 5 || strcmp(d, "he")) return 8;
	if (strlcat(d, "llo!", 6) != 6 || strcmp(d, "hello")) return 9;

	static char kv[] = "HEARTS_PROBE=1";
	if (putenv(kv) || strcmp(getenv("HEARTS_PROBE"), "1")) return 10;
	kv[13] = '2';                              /* the string itself is the variable */
	if (strcmp(getenv("HEARTS_PROBE"), "2")) return 11;

	char path[] = "/tmp/mooncc-falloc-XXXXXX";
	int fd = mkstemp(path);
	if (fd < 0) return 12;
	unlink(path);
	struct stat st;
	if (posix_fallocate(fd, 0, 4096) || fstat(fd, &st) || st.st_size != 4096) return 13;
	if (posix_fallocate(fd, 0, 16) || fstat(fd, &st) || st.st_size != 4096) return 14;
	close(fd);

	static int keys[40];
	void *root = 0;
	for (int i = 0; i < 40; i++) {
		keys[i] = (i * 17) % 40;
		if (*(int **) tsearch(&keys[i], &root, cmp) != &keys[i]) return 15; }
	int k = 17;
	if (**(int **) tsearch(&k, &root, cmp) != 17) return 16;     /* found, not added */
	if (!tfind(&k, &root, cmp)) return 17;
	for (int i = 0; i < 40; i += 3) {
		k = i;
		if (!tdelete(&k, &root, cmp)) return 18; }
	k = 3;
	if (tfind(&k, &root, cmp) || tdelete(&k, &root, cmp)) return 19;
	twalk(root, visit);
	if (nseen != 26) return 20;
	for (int i = 1; i < nseen; i++) if (seen[i - 1] >= seen[i] || seen[i] % 3 == 0) return 21;
	tdestroy(root, nofree);
	return 42;
}
