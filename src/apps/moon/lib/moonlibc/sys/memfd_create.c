#include "../impl.h"
/* linux only; a BSD answers ENOSYS */
int memfd_create(char const *name, unsigned int fl) { return (int) er(sc2(NR_memfd_create, (long) name, fl)); }
