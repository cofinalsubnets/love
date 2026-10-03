#include "../impl.h"

int setuid(unsigned int u) { return (int) er(sc1(NR_setuid, u)); }
int setresuid(unsigned int r, unsigned int e, unsigned int s) { return (int) er(sc3(NR_setresuid, r, e, s)); }
int setresgid(unsigned int r, unsigned int e, unsigned int s) { return (int) er(sc3(NR_setresgid, r, e, s)); }
