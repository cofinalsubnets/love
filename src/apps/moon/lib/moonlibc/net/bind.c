#include "../impl.h"

int bind(int fd, struct sockaddr const *a, socklen_t n) { return (int) er(sc_sa(NR_bind, fd, a, n)); }
