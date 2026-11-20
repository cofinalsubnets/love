#pragma once
typedef long ssize_t;
#include <sys/types.h>
long read(int, void*, long), write(int, void const*, long);
int close(int);
off_t lseek(int, off_t, int);
int open(char const*, int, ...);   /* repeated from fcntl.h */
long sysconf(int);
const char *getprogname(void);
#define _SC_PAGESIZE 30
#define _SC_PAGE_SIZE _SC_PAGESIZE
#define _SC_NPROCESSORS_CONF 83
#define _SC_NPROCESSORS_ONLN 84
#define _SC_PHYS_PAGES 85
#define _SC_AVPHYS_PAGES 86
#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2
int unlink(char const*), rmdir(char const*), link(char const*, char const*),
    symlink(char const*, char const*);
long readlink(char const*, char*, unsigned long);
int chown(char const*, unsigned int, unsigned int), fchown(int, unsigned int, unsigned int),
    lchown(char const*, unsigned int, unsigned int), setuid(unsigned int), setgid(unsigned int),
    setresuid(unsigned int, unsigned int, unsigned int),
    setresgid(unsigned int, unsigned int, unsigned int), seteuid(unsigned int),
    setegid(unsigned int), chdir(char const*), fchdir(int), chroot(char const*);
char *getcwd(char*, unsigned long);
int  access(char const*, int);
#define F_OK 0
#define X_OK 1
#define W_OK 2
#define R_OK 4
int dup(int), dup2(int, int), pipe(int*), fork(void), execvp(char const*, char *const*),
    execv(char const*, char *const*), execve(char const*, char *const*, char *const*),
    fexecve(int, char *const*, char *const*), dup3(int, int, int), pipe2(int*, int),
    execvpe(char const*, char *const*, char *const*), vfork(void), daemon(int, int),
    lockf(int, int, off_t), getpagesize(void), getentropy(void*, size_t);
long syscall(long, ...);
#define F_ULOCK 0
#define F_LOCK  1
#define F_TLOCK 2
#define F_TEST  3
extern char **environ, *optarg;
extern int optind, opterr, optopt;
int getopt(int, char *const *, char const *), execl(char const*, char const*, ...),
    execlp(char const*, char const*, ...), execle(char const*, char const*, ...);
void _exit(int);
unsigned int getuid(void), geteuid(void), getegid(void), getgid(void);
int getpid(void), getppid(void), setsid(void), isatty(int), ttyname_r(int, char*, size_t);
char *ttyname(int);
unsigned int alarm(unsigned int);
int pause(void), gethostname(char*, unsigned long), ftruncate(int, off_t),
    truncate(char const*, off_t), getlogin_r(char*, size_t);
char *getlogin(void);
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
int fsync(int), fdatasync(int);
void sync(void);
int  unlinkat(int, char const*, int), linkat(int, char const*, int, char const*, int),
     symlinkat(char const*, int, char const*), faccessat(int, char const*, int, int),
     fchownat(int, char const*, unsigned int, unsigned int, int);
unsigned int sleep(unsigned int);
int  usleep(unsigned int);
long pread(int, void*, unsigned long, off_t);
ssize_t copy_file_range(int, off_t*, int, off_t*, unsigned long, unsigned int);
long pwrite(int, void const*, unsigned long, off_t);
int getpgrp(void), setpgid(pid_t, pid_t), getsid(pid_t), getpgid(pid_t);
pid_t tcgetpgrp(int);
int  tcsetpgrp(int, pid_t);
