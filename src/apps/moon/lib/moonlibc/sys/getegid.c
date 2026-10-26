#include "../impl.h"

unsigned int getegid(void) { return (unsigned int) sc0(NR_getegid); }
