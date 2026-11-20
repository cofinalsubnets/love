#include "../impl.h"

int getsid(int p) { return (int) er(sc1(NR_getsid, p)); }
int getpgid(int p) { return (int) er(sc1(NR_getpgid, p)); }
