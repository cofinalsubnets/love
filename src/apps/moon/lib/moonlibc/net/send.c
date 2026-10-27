#include "../impl.h"

long send(int fd, void const *b, unsigned long n, int fl) { return sendto(fd, b, n, fl, 0, 0); }
long recv(int fd, void *b, unsigned long n, int fl) { return recvfrom(fd, b, n, fl, 0, 0); }
