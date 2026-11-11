#include "../impl.h"

int sigfillset(sigset_t *s) { memset(s, 0xff, sizeof *s); return 0; }
