/* errno, a member of its own: a bare link that sets it pulls no entry */
#include "impl.h"

int __errno_v;   /* one int: love is single-threaded */
int *__errno_location(void) { return &__errno_v; }
