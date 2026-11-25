#include "../impl.h"

int tcsetpgrp(int fd, pid_t pg) { int p = (int) pg; return ioctl(fd, LvTIOCSPGRP, &p); }  /* ioctl translates */
