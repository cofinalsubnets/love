/* free aborts on what it never handed out and on a block freed already, where a silent
 * free would corrupt the list: each in a child, which must die of SIGABRT. glibc aborts on
 * both too. the exit counts the children that did not; with no fork (wasm) the check is not made */
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <sys/wait.h>

static int aborts(int how) {
	pid_t c = fork();
	if (c < 0) return 1;
	if (c == 0) {
		close(2);
		char *p = malloc(64);
		memset(p, 0, 64);
		if (how == 0) free(p), free(p);
		else { volatile int off = 32; free(p + off); }
		_exit(0);
	}
	int st = 0;
	waitpid(c, &st, 0);
	return WIFSIGNALED(st) && WTERMSIG(st) == SIGABRT;
}

int main(void) {
	char *ok = malloc(64);
	free(ok);
	return !aborts(0) + !aborts(1);
}
