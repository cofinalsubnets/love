#ifndef _LOVE_SYS_WAIT_H
#define _LOVE_SYS_WAIT_H
#include <sys/types.h>
#define WNOHANG 1
#define WUNTRACED 2
#define WIFEXITED(s)   (((s) & 127) == 0)
#define WEXITSTATUS(s) (((s) >> 8) & 255)
#define WTERMSIG(s)    ((s) & 127)
#define WIFSTOPPED(s)  (((s) & 255) == 127)
#define WSTOPSIG(s)    (((s) >> 8) & 255)
/* glibc's signed-char trick: stopped (0x7f) must not read as signaled */
#define WIFSIGNALED(s) ((((signed char)(((s) & 127) + 1)) >> 1) > 0)
int waitpid(int, int*, int);
int wait(int*);
#endif
