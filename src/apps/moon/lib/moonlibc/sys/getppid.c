#include "../impl.h"

int getppid(void) { return (int) sc0(NR_getppid); }
