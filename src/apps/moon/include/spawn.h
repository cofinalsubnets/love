#ifndef _LOVE_SPAWN_H
#define _LOVE_SPAWN_H
#include <sys/types.h>
#include <signal.h>
#define POSIX_SPAWN_RESETIDS   1
#define POSIX_SPAWN_SETPGROUP  2
#define POSIX_SPAWN_SETSIGDEF  4
#define POSIX_SPAWN_SETSIGMASK 8
/* an action: 1 dup2 src to fd, 2 close fd, 3 open path at fd */
struct __spawn_act { int kind, fd, src, flags; mode_t mode; char *path; };
typedef struct { int n, cap; struct __spawn_act *a; } posix_spawn_file_actions_t;
typedef struct { short flags; pid_t pgroup; sigset_t def, mask; } posix_spawnattr_t;
int posix_spawn_file_actions_init(posix_spawn_file_actions_t*);
int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t*);
int posix_spawn_file_actions_adddup2(posix_spawn_file_actions_t*, int, int);
int posix_spawn_file_actions_addclose(posix_spawn_file_actions_t*, int);
int posix_spawn_file_actions_addopen(posix_spawn_file_actions_t*, int, char const*, int, mode_t);
int posix_spawnattr_init(posix_spawnattr_t*);
int posix_spawnattr_destroy(posix_spawnattr_t*);
int posix_spawnattr_setflags(posix_spawnattr_t*, short);
int posix_spawnattr_getflags(posix_spawnattr_t const*, short*);
int posix_spawnattr_setpgroup(posix_spawnattr_t*, pid_t);
int posix_spawnattr_getpgroup(posix_spawnattr_t const*, pid_t*);
int posix_spawnattr_setsigdefault(posix_spawnattr_t*, sigset_t const*);
int posix_spawnattr_getsigdefault(posix_spawnattr_t const*, sigset_t*);
int posix_spawnattr_setsigmask(posix_spawnattr_t*, sigset_t const*);
int posix_spawnattr_getsigmask(posix_spawnattr_t const*, sigset_t*);
int posix_spawn(pid_t*, char const*, posix_spawn_file_actions_t const*, posix_spawnattr_t const*,
                char *const[], char *const[]);
int posix_spawnp(pid_t*, char const*, posix_spawn_file_actions_t const*, posix_spawnattr_t const*,
                 char *const[], char *const[]);
#endif
