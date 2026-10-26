#include "../impl.h"

/* the BSDs' and xnu's own calls share their numbers; netbsd has no setresuid */
int seteuid(unsigned int u) { return __love_osv >= 2 ? (int) er(fb1(183, u)) : setresuid(-1, u, -1); }
int setegid(unsigned int g) { return __love_osv >= 2 ? (int) er(fb1(182, g)) : setresgid(-1, g, -1); }
