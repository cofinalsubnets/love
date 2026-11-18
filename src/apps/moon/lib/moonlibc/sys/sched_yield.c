#include "../impl.h"
#include <sched.h>

int sched_yield(void) { return __love_osv == 4 ? 0 : (int) er(sc0(NR_sched_yield)); }   /* xnu: a no-op */
