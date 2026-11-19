/* errno and h_errno, a member of their own: a bare link that sets one pulls no entry.
 * the process's own until a thread starts; then pthread_create's hook answers the
 * calling thread's (0 errno, 1 h_errno) */
#include "impl.h"

int __errno_v, __h_errno_v;
int *(*__love_errat)(int);
int *__errno_location(void) { return __love_errat ? __love_errat(0) : &__errno_v; }
int *__h_errno_location(void) { return __love_errat ? __love_errat(1) : &__h_errno_v; }
