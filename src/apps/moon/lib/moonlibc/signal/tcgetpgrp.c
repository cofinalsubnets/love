#include "../impl.h"

pid_t tcgetpgrp(int fd) { int p = 0; return ioctl(fd, 21519, &p) ? -1 : (pid_t) p; }  /* TIOCGPGRP; ioctl translates */
