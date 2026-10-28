#pragma once
typedef long ssize_t;
#include <sys/types.h>
long read(int, void*, long);
long write(int, void const*, long);
int close(int);
off_t lseek(int, off_t, int);
int open(char const*, int, ...);   /* repeated from fcntl.h */
long sysconf(int);
const char *getprogname(void);
#define _SC_PAGESIZE 30
#define _SC_NPROCESSORS_CONF 83
#define _SC_NPROCESSORS_ONLN 84
#define _SC_PHYS_PAGES 85
#define _SC_AVPHYS_PAGES 86
#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2
int  unlink(char const*);
int  rmdir(char const*);
int  link(char const*, char const*);
int  symlink(char const*, char const*);
long readlink(char const*, char*, unsigned long);
int  chown(char const*, unsigned int, unsigned int);
int  fchown(int, unsigned int, unsigned int);
int  lchown(char const*, unsigned int, unsigned int);
int  setuid(unsigned int);
int  setgid(unsigned int);
int  setresuid(unsigned int, unsigned int, unsigned int);
int  setresgid(unsigned int, unsigned int, unsigned int);
int  seteuid(unsigned int);
int  setegid(unsigned int);
int  chdir(char const*);
int  fchdir(int);
int  chroot(char const*);
char *getcwd(char*, unsigned long);
int  access(char const*, int);
#define F_OK 0
#define X_OK 1
#define W_OK 2
#define R_OK 4
int  dup(int);
int  dup2(int, int);
int  pipe(int*);
int  fork(void);
int  execvp(char const*, char *const*);
int  execv(char const*, char *const*);
int  execve(char const*, char *const*, char *const*);
int  fexecve(int, char *const*, char *const*);
extern char **environ;
extern char *optarg;
extern int optind, opterr, optopt;
int getopt(int, char *const *, char const *);
int  execl(char const*, char const*, ...);
int  execlp(char const*, char const*, ...);
int  execle(char const*, char const*, ...);
void _exit(int);
unsigned int getuid(void);
unsigned int geteuid(void);
unsigned int getegid(void);
unsigned int getgid(void);
int  getpid(void);
int  getppid(void);
int  setsid(void);
int  isatty(int);
int  ftruncate(int, off_t);
int  truncate(char const*, off_t);
long pathconf(char const*, int);
/* glibc's numbers */
#define _PC_LINK_MAX         0
#define _PC_MAX_CANON        1
#define _PC_MAX_INPUT        2
#define _PC_NAME_MAX         3
#define _PC_PATH_MAX         4
#define _PC_PIPE_BUF         5
#define _PC_CHOWN_RESTRICTED 6
#define _PC_NO_TRUNC         7
#define _PC_VDISABLE         8
long fpathconf(int, int);
int  fsync(int);
int  fdatasync(int);
void sync(void);
int  unlinkat(int, char const*, int);
unsigned int sleep(unsigned int);
int  usleep(unsigned int);
long pread(int, void*, unsigned long, off_t);
ssize_t copy_file_range(int, off_t*, int, off_t*, unsigned long, unsigned int);
long pwrite(int, void const*, unsigned long, off_t);
int  getpgrp(void);
int  setpgid(pid_t, pid_t);
pid_t tcgetpgrp(int);
int  tcsetpgrp(int, pid_t);
