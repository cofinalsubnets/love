#include "../impl.h"

/* a forked child becomes sh -c cmd: $LOVE_SH's words when set (love lush -a), else /bin/sh */
static void __love_shc(char const *cmd) {
  char const *e = getenv("LOVE_SH");
  char b[1024], *av[20];
  int n = 0;
  if (e && *e && strlen(e) < sizeof b) {
    char *p = strcpy(b, e);
    while (*p && n < 16) {
      while (*p == ' ') *p++ = 0;
      if (*p) av[n++] = p;
      while (*p && *p != ' ') p++; } }
  char const *sh = n ? av[0] : "/bin/sh";
  if (!n) av[n++] = "sh";
  av[n] = "-c"; av[n + 1] = (char *) cmd; av[n + 2] = 0;
  execv(sh, av);
  _exit(127); }
/* no signal juggling: love is single-threaded */
int system(char const *cmd) {
  if (!cmd) return 1;                          /* a shell is available */
  int pid = fork();
  if (pid < 0) return -1;
  if (pid == 0) __love_shc(cmd);
  int st = 0;
  while (waitpid(pid, &st, 0) < 0) if (errno != EINTR) return -1;
  return st; }
/* the child pid rides the FILE for pclose's wait */
FILE *popen(char const *cmd, char const *mode) {
  int fds[2];
  int rd = mode[0] == 'r';
  if (pipe(fds) < 0) return 0;
  int pid = fork();
  if (pid < 0) { close(fds[0]); close(fds[1]); return 0; }
  if (pid == 0) {
    dup2(rd ? fds[1] : fds[0], rd ? 1 : 0);
    close(fds[0]); close(fds[1]);
    __love_shc(cmd); }
  close(rd ? fds[1] : fds[0]);
  FILE *f = malloc(sizeof(FILE) + 4096);
  if (!f) { close(rd ? fds[0] : fds[1]); return 0; }
  memset(f, 0, sizeof(FILE));
  f->fd = rd ? fds[0] : fds[1];
  f->wr = !rd;
  f->heap = 1;
  f->pid = pid;
  if (!rd) { f->buf = (unsigned char *) (f + 1); f->cap = 4096; }
  else { f->rb = (unsigned char *) (f + 1); f->rcap = 4096; }
  __love_fopened(f);
  return f; }
int pclose(FILE *f) {
  int pid = f->pid, st = 0;
  int r = fclose(f);
  if (r == EOF) return -1;
  while (waitpid(pid, &st, 0) < 0) if (errno != EINTR) return -1;
  return st; }
