// host/proc.h -- process helpers shared by the host apps that fork children:
// pty.c (bao's pty wrapper) and init.c (the init supervisor). main.c's run/exec
// inline the same decode, but main.c is CORE -- an app file can't reach in -- so
// this is the ONE copy bao and init share, keeping them agreed on what a child's
// exit code MEANS. A `static inline` in a header gives each TU its own copy (no
// multiple-definition); both users call it, so -Wunused stays quiet.
#ifndef AI_HOST_PROC_H
#define AI_HOST_PROC_H
#include <sys/wait.h>   // WIFEXITED WEXITSTATUS WIFSIGNALED WTERMSIG

// A wait(2) status word -> the value a reaper hands back: the exit code, or
// 128+signal for a signalled death (the shell convention), or -1 for the
// (shouldn't-happen) neither case. The way host_run (main.c) decodes it.
static inline int proc_status(int st) {
 return WIFEXITED(st) ? WEXITSTATUS(st)
       : WIFSIGNALED(st) ? 128 + WTERMSIG(st) : -1; }

#endif
