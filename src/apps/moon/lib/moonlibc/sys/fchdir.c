#include "../impl.h"

int fchdir(int fd) { return (int) er(sc1(NR_fchdir, fd)); }
