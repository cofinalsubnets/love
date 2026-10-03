#include "../impl.h"

int getpagesize(void) { return (int) sysconf(_SC_PAGESIZE); }
