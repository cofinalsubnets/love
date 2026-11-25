#include "../impl.h"

pid_t tcgetpgrp(int fd) { int p = 0; return ioctl(fd, LvTIOCGPGRP, &p) ? -1 : (pid_t) p; }  /* ioctl translates */
