#include "../impl.h"
/* linux only */
int unshare(int fl) { return (int) er(sc1(NR_unshare, fl)); }
