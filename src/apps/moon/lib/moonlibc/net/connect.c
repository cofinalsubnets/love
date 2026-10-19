#include "../impl.h"

int connect(int fd, struct sockaddr const *a, socklen_t n) { return (int) er(sc_sa(NR_connect, fd, a, n)); }
