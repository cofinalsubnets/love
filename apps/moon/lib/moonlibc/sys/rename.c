#include "../impl.h"

/* renameat2 with no flags is renameat, one argument longer -- riscv's kernel has only it */
#if defined(__riscv)
int rename(char const *a, char const *b) { return (int) er(sc5(NR_renameat2, AT_FDCWD, (long) a, AT_FDCWD, (long) b, 0)); }
#else
int rename(char const *a, char const *b) { return (int) er(sc4(NR_renameat, AT_FDCWD, (long) a, AT_FDCWD, (long) b)); }
#endif
