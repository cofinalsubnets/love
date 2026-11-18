#include "../impl.h"

/* off the terminal: a child in a session of its own, at / and on /dev/null unless asked not */
int daemon(int nochdir, int noclose) {
  int p = fork();
  if (p < 0) return -1;
  if (p) _exit(0);
  if (setsid() < 0) return -1;
  if (!nochdir && chdir("/") < 0) return -1;
  if (!noclose) {
    int fd = open("/dev/null", O_RDWR);
    if (fd < 0) return -1;
    dup2(fd, 0), dup2(fd, 1), dup2(fd, 2);
    if (fd > 2) close(fd); }
  return 0; }
