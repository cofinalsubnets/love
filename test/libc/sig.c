/* the signal floor: the sets, the numbers, and the SHAPE of siginfo. moonlibc
 * lays its own canonical siginfo so a handler reads one layout on every kernel,
 * and on linux the native record is taken verbatim -- so every lane must land
 * exactly where glibc puts it. a SIGCHLD for a real child is what asks: the pid,
 * the status and the code all come from the kernel, and a lane at the wrong
 * offset reads its neighbour. the pid and uid are REPORTED AS A MATCH, never as
 * a value: they differ between two runs of the same program, the match does not. */
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>
#include <string.h>
#include "say.h"

static volatile sig_atomic_t k_signo, k_code, k_status, k_pid, k_uid;

static void on_chld(int s, siginfo_t *si, void *ctx) {
	(void) s; (void) ctx;
	k_signo = si->si_signo;
	k_code = si->si_code;
	k_pid = (sig_atomic_t) si->si_pid;
	k_uid = (sig_atomic_t) si->si_uid;
	k_status = si->si_status; }

int main(void)
{
	/* --- the sets: an empty one holds nothing, and add/test agree over the
	   whole range --- */
	sigset_t s;
	sigemptyset(&s);
	for (int i = 1; i <= 32; i++) say_n("empty", sigismember(&s, i));
	sigaddset(&s, SIGINT);
	sigaddset(&s, SIGCHLD);
	sigaddset(&s, SIGSYS);
	for (int i = 1; i <= 32; i++) say_n("added", sigismember(&s, i));

	/* --- the numbers. several of these permute on the BSDs, so what the header
	   names is the canonical value every translation table is cut against --- */
	say_n("SIGILL", SIGILL);
	say_n("SIGTRAP", SIGTRAP);
	say_n("SIGCHLD", SIGCHLD);
	say_n("SIGSTKFLT", SIGSTKFLT);
	say_n("SIGURG", SIGURG);
	say_n("SIGXCPU", SIGXCPU);
	say_n("SIGXFSZ", SIGXFSZ);
	say_n("SIGVTALRM", SIGVTALRM);
	say_n("SIGPROF", SIGPROF);
	say_n("SIGIO", SIGIO);
	say_n("SIGPWR", SIGPWR);
	say_n("SIGSYS", SIGSYS);

	/* --- the lanes, read off a real delivery. the handler runs before waitpid
	   returns: a pending signal is delivered on the way out of the syscall, so
	   the flags are set by the time the reap is in hand --- */
	struct sigaction sa;
	memset(&sa, 0, sizeof sa);
	sa.sa_sigaction = on_chld;
	sa.sa_flags = SA_SIGINFO;
	sigemptyset(&sa.sa_mask);
	say_n("sigaction", sigaction(SIGCHLD, &sa, NULL));

	int kid = fork();
	if (!kid) _exit(7);
	int st = 0;
	while (waitpid(kid, &st, 0) < 0) ;
	say_n("reaped", WEXITSTATUS(st));
	say_n("si_signo", k_signo);
	say_n("si_code", k_code);                  /* CLD_EXITED */
	say_n("si_status", k_status);
	say_n("si_pid.match", k_pid == kid);
	say_n("si_uid.match", k_uid == (sig_atomic_t) getuid());
	return 0;
}
